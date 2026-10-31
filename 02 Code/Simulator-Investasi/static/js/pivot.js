/* Pivot bebas: sumber dari /pivot/data/, agregasi, tampilan, grafik, dan ekspor di klien. */
(function () {
  const $ = (id) => document.getElementById(id);
  const fmt = (v, d) => window.fmtID(v, d);
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const ada = (x) => x !== null && x !== undefined && !Number.isNaN(x);

  const AGREGAT = { jumlah: "Jumlah", rata: "Rata-rata", bobot: "Rata-rata berbobot", median: "Median", min: "Min", maks: "Maks", sd: "Simpangan baku", hitung: "Hitung" };
  const OP = { "/": "÷", "-": "−", "+": "+", "*": "×" };
  const SIMPAN = "pivot-tata", TERAKHIR = "pivot-terakhir", MAKS_BARIS = 4000;

  /* ------------------------------------------------------------------ tata letak bawaan */
  const PRESET = {
    "PDRB per pulau × tahun": { sumber: "panel", baris: ["pulau", "provinsi"], kolom: ["tahun"], nilai: [{ kunci: "PDRB_ADHK", agregat: "jumlah" }] },
    "Laju PDRB provinsi × tahun (panas)": { sumber: "panel", baris: ["pulau", "provinsi"], kolom: ["tahun"], nilai: [{ kunci: "G_PDRB", agregat: "bobot" }], opsi: { warna: "panas", subtotal: "atas" } },
    "Pangsa PMA+PMDN per sektor × tahun": { sumber: "sektoral", baris: ["kelompok", "sektor"], kolom: ["tahun"], nilai: [{ kunci: "INV", agregat: "jumlah" }], opsi: { tampil: "pct_kolom" } },
    "Produktivitas sektor: NTB per pekerja": { sumber: "sektoral", baris: ["kelompok", "sektor"], kolom: ["pulau"], filter: {}, nilai: [{ rumus: { a: "VA", op: "/", b: "TK", k: 1000 }, label: "NTB per pekerja (juta Rp)", digit: 1 }], opsi: { warna: "panas" } },
    "Investasi tambahan per pulau × skenario": { sumber: "skenario", param: { sk: "semua" }, baris: ["pulau", "provinsi"], kolom: ["skenario"], nilai: [{ kunci: "A2_real", agregat: "jumlah" }], opsi: { warna: "batang" } },
    "Laju dengan penambahan investasi per pulau × skenario": { sumber: "skenario", param: { sk: "semua" }, baris: ["pulau"], kolom: ["skenario"], nilai: [{ kunci: "g_skenario", agregat: "bobot" }], opsi: { warna: "panas" } },
    "PDRB dengan penambahan investasi vs sasaran (skenario aktif)": { sumber: "skenario", baris: ["tahun"], kolom: [], nilai: [{ kunci: "PDRB_skenario", agregat: "jumlah" }, { kunci: "PDRB_sasaran", agregat: "jumlah" }, { rumus: { a: "PDRB_skenario", op: "/", b: "PDRB_sasaran", k: 100 }, label: "Capaian PDRB terhadap sasaran (%)", digit: 1 }] },
    "Aliran antarpulau (IRIO)": { sumber: "io_aliran", baris: ["pulau_asal"], kolom: ["pulau_tujuan"], nilai: [{ kunci: "aliran", agregat: "jumlah" }], opsi: { warna: "panas" } },
    "Pengganda per sektor × pulau (IRIO)": { sumber: "io_sektor", baris: ["kelompok", "sektor"], kolom: ["pulau"], nilai: [{ kunci: "po", agregat: "bobot" }], opsi: { warna: "panas", subtotal: "atas" } },
  };
  const BAWAAN_SUMBER = {
    panel: "PDRB per pulau × tahun", sektoral: "Pangsa PMA+PMDN per sektor × tahun",
    skenario: "PDRB dengan penambahan investasi vs sasaran (skenario aktif)", io_sektor: "Pengganda per sektor × pulau (IRIO)", io_aliran: "Aliran antarpulau (IRIO)",
  };
  const OPSI0 = { tampil: "nilai", urut: "label", subtotal: "bawah", warna: "", topn: 0, digit: 0, total: true, kosong: false };

  let SRC = null, ST = null, POHON = null, MATRIKS = null;
  const cache = {};

  /* ------------------------------------------------------------------ status dan sumber */
  function paramSumber(sumber) {
    const p = { sumber };
    if (sumber === "panel" || sumber === "sektoral") p.versi = $("pv-versi").value;
    if (sumber === "skenario") p.sk = skDipilih();
    if (sumber.startsWith("io_")) { p.tahun = $("pv-io-tahun").value; p.metode = $("pv-io-metode").value; }
    return p;
  }
  function skDipilih() {
    const cb = [...document.querySelectorAll("#pv-sk input:checked")].map((c) => c.value);
    return cb.join(",");
  }
  function setSk(nilai) {
    const semua = [...document.querySelectorAll("#pv-sk input:not(:disabled)")];
    if (nilai === "semua") semua.forEach((c) => (c.checked = true));
    else if (nilai === "bawaan") semua.forEach((c) => (c.checked = c.dataset.grup === "Bawaan"));
    else if (nilai === "aktif" || !nilai) semua.forEach((c) => (c.checked = +c.value === window.PV.skAwal));
    else { const s = new Set(String(nilai).split(",")); semua.forEach((c) => (c.checked = s.has(c.value))); }
    const n = semua.filter((c) => c.checked);
    $("pv-sk-ringkas").textContent = n.length === 0 ? "Pilih skenario" : n.length === 1 ? n[0].parentElement.textContent.trim() : `${n.length} skenario`;
  }
  function tampilkanParam() {
    const s = $("pv-sumber").value;
    document.querySelectorAll(".pv-sumber [data-untuk]").forEach((el) => (el.hidden = !el.dataset.untuk.split(" ").includes(s)));
  }

  async function muat() {
    const p = paramSumber($("pv-sumber").value);
    const url = window.PV.data + "?" + new URLSearchParams(p);
    $("pv-tabel").innerHTML = '<p class="abu kecil">Memuat…</p>';
    try {
      if (!cache[url]) {
        const r = await fetch(url);
        const d = await r.json();
        if (!r.ok) throw new Error(d.galat || r.statusText);
        cache[url] = d;
      }
      SRC = cache[url];
    } catch (e) {
      SRC = null;
      $("pv-tabel").innerHTML = `<div class="sorot">${esc(e.message)}</div>`;
      return false;
    }
    SRC.dimIx = Object.fromEntries(SRC.dimensi.map((d, i) => [d.kunci, i]));
    SRC.ukIx = Object.fromEntries(SRC.ukuran.map((u, j) => [u.kunci, SRC.dimensi.length + j]));
    SRC.ukDef = Object.fromEntries(SRC.ukuran.map((u) => [u.kunci, u]));
    return true;
  }

  function rapikanStatus() {
    const dim = new Set(SRC.dimensi.map((d) => d.kunci));
    ST.baris = ST.baris.filter((k) => dim.has(k));
    ST.kolom = ST.kolom.filter((k) => dim.has(k) && !ST.baris.includes(k));
    ST.filterZona = (ST.filterZona || []).filter((k) => dim.has(k) && !ST.baris.includes(k) && !ST.kolom.includes(k));
    ST.filter = Object.fromEntries(Object.entries(ST.filter || {}).filter(([k]) => dim.has(k)));
    ST.nilai = ST.nilai.filter((n) => (n.rumus ? SRC.ukDef[n.rumus.a] && SRC.ukDef[n.rumus.b] : SRC.ukDef[n.kunci]));
    ST.nilai.forEach((n) => { if (!n.rumus && n.agregat === "bobot" && !bobotDari(n.kunci)) n.agregat = "rata"; });
    if (!ST.nilai.length) ST.nilai = [{ kunci: SRC.ukuran[0].kunci, agregat: agregatBawaan(SRC.ukuran[0].kunci) }];
    ST.opsi = { ...OPSI0, ...(ST.opsi || {}) };
  }
  const bobotDari = (k) => { const a = SRC.ukDef[k]?.agregat; return a && a.bobot && SRC.ukIx[a.bobot] !== undefined ? a.bobot : null; };
  const agregatBawaan = (k) => { const a = SRC.ukDef[k]?.agregat; return a && a.bobot ? "bobot" : a || "jumlah"; };

  /* ------------------------------------------------------------------ agregasi */
  function nilaiAgregat(idxs, n) {
    if (n.rumus) {
      const A = nilaiAgregat(idxs, { kunci: n.rumus.a, agregat: "jumlah" }), B = nilaiAgregat(idxs, { kunci: n.rumus.b, agregat: "jumlah" });
      if (!ada(A) || !ada(B)) return null;
      const k = +n.rumus.k || 1;
      if (n.rumus.op === "/") return B ? (A / B) * k : null;
      if (n.rumus.op === "-") return (A - B) * k;
      if (n.rumus.op === "+") return (A + B) * k;
      return A * B * k;
    }
    const j = SRC.ukIx[n.kunci], D = SRC.data;
    if (n.agregat === "hitung") { let c = 0; for (const i of idxs) if (ada(D[i][j])) c++; return c; }
    if (n.agregat === "bobot") {
      const w = SRC.ukIx[bobotDari(n.kunci)];
      let sw = 0, s = 0;
      for (const i of idxs) { const v = D[i][j], b = D[i][w]; if (ada(v) && ada(b)) { sw += b; s += v * b; } }
      return sw ? s / sw : null;
    }
    const v = [];
    for (const i of idxs) { const x = D[i][j]; if (ada(x)) v.push(x); }
    if (!v.length) return null;
    switch (n.agregat) {
      case "rata": return v.reduce((a, b) => a + b, 0) / v.length;
      case "min": return Math.min(...v);
      case "maks": return Math.max(...v);
      case "median": { v.sort((a, b) => a - b); const m = v.length; return m % 2 ? v[(m - 1) / 2] : (v[m / 2 - 1] + v[m / 2]) / 2; }
      case "sd": { if (v.length < 2) return null; const r = v.reduce((a, b) => a + b, 0) / v.length; return Math.sqrt(v.reduce((a, b) => a + (b - r) ** 2, 0) / (v.length - 1)); }
      default: return v.reduce((a, b) => a + b, 0);
    }
  }

  function bangunPohon() {
    const D = SRC.data, rd = ST.baris.map((k) => SRC.dimIx[k]), cd = ST.kolom.map((k) => SRC.dimIx[k]);
    const kecuali = Object.entries(ST.filter).map(([k, vs]) => {
      const nilai = SRC.dimensi[SRC.dimIx[k]].nilai;
      return [SRC.dimIx[k], new Set(vs.map((v) => nilai.findIndex((x) => String(x) === String(v))).filter((i) => i >= 0))];
    }).filter(([, s]) => s.size);
    const kolomMap = new Map();
    const lolos = [];
    for (let i = 0; i < D.length; i++) {
      const r = D[i];
      if (kecuali.some(([d, s]) => s.has(r[d]))) continue;
      lolos.push(i);
      const kk = cd.map((d) => r[d]).join("|");
      if (!kolomMap.has(kk)) kolomMap.set(kk, cd.map((d) => r[d]));
    }
    const kolom = [...kolomMap.values()].sort((a, b) => { for (let x = 0; x < a.length; x++) if (a[x] !== b[x]) return a[x] - b[x]; return 0; });
    const posKol = new Map(kolom.map((k, c) => [k.join("|"), c]));
    const nc = cd.length ? kolom.length : 0;
    const simpul = (tingkat, nilai, induk) => ({ tingkat, nilai, induk, anak: new Map(), idxs: [], perKol: Array.from({ length: nc }, () => []), cache: {} });
    const akar = simpul(-1, null, null);
    for (const i of lolos) {
      const r = D[i], c = nc ? posKol.get(cd.map((d) => r[d]).join("|")) : -1;
      let s = akar;
      s.idxs.push(i); if (c >= 0) s.perKol[c].push(i);
      rd.forEach((d, l) => {
        let a = s.anak.get(r[d]);
        if (!a) { a = simpul(l, r[d], s); s.anak.set(r[d], a); }
        a.idxs.push(i); if (c >= 0) a.perKol[c].push(i);
        s = a;
      });
    }
    return { akar, kolom, nc, rd, cd, lolos: lolos.length };
  }

  function sel(s, c, m) {
    const kunci = c + ":" + m;
    if (!(kunci in s.cache)) s.cache[kunci] = nilaiAgregat(c < 0 ? s.idxs : s.perKol[c], ST.nilai[m]);
    return s.cache[kunci];
  }

  /* nilai setelah "tampilkan sebagai"; c = -1 berarti kolom total */
  function tampil(s, c, m) {
    const v = sel(s, c, m), t = ST.opsi.tampil;
    if (!ada(v) || t === "nilai") return v;
    const bagi = (a, b) => (ada(a) && ada(b) && b !== 0 ? (a / b) * 100 : null);
    if (t === "pct_total") return bagi(v, sel(POHON.akar, -1, m));
    if (t === "pct_kolom") return bagi(v, sel(POHON.akar, c, m));
    if (t === "pct_baris") return bagi(v, sel(s, -1, m));
    if (t === "pct_induk") return s.induk ? bagi(v, sel(s.induk, c, m)) : 100;
    if (c < 0) return null;
    if (t === "indeks") return bagi(v, sel(s, 0, m));
    if (c === 0) return null;
    const p = sel(s, c - 1, m);
    if (t === "selisih") return ada(p) ? v - p : null;
    if (t === "tumbuh") return ada(p) && p !== 0 ? (v / p - 1) * 100 : null;
    return v;
  }

  function digit(m) {
    const n = ST.nilai[m], t = ST.opsi.tampil;
    let d = t !== "nilai" && t !== "selisih" ? 1 : n.rumus ? n.digit ?? 2 : n.agregat === "hitung" ? 0 : SRC.ukDef[n.kunci]?.digit ?? 1;
    if (t === "nilai" && !n.rumus && ["rata", "median", "sd", "bobot"].includes(n.agregat) && d === 0) d = 1;
    return Math.max(0, d + (+ST.opsi.digit || 0));
  }

  function labelNilai(n) {
    if (n.rumus) return n.label || `${SRC.ukDef[n.rumus.a]?.label} ${OP[n.rumus.op]} ${SRC.ukDef[n.rumus.b]?.label}`;
    const u = SRC.ukDef[n.kunci];
    const ag = n.agregat === agregatBawaan(n.kunci) ? "" : ` (${AGREGAT[n.agregat].toLowerCase()})`;
    return u.label + ag + (u.satuan ? `, ${u.satuan}` : "");
  }
  const labelDim = (k) => SRC.dimensi[SRC.dimIx[k]].label;
  const nilaiDim = (d, i) => SRC.dimensi[d].nilai[i];

  /* ------------------------------------------------------------------ susun baris */
  function urutkanAnak(s) {
    let a = [...s.anak.values()];
    const u = ST.opsi.urut;
    if (u === "turun" || u === "naik") {
      const f = (x) => sel(x, -1, 0) ?? -Infinity;
      a.sort((x, y) => (u === "turun" ? f(y) - f(x) : f(x) - f(y)));
    } else if (u === "abjad") {
      const d = POHON.rd[a[0]?.tingkat];
      a.sort((x, y) => String(nilaiDim(d, x.nilai)).localeCompare(String(nilaiDim(d, y.nilai)), "id"));
    } else a.sort((x, y) => x.nilai - y.nilai);
    const n = +ST.opsi.topn;
    if (n > 0 && a.length > n) {
      const atas = [...a].sort((x, y) => (sel(y, -1, 0) ?? -Infinity) - (sel(x, -1, 0) ?? -Infinity)).slice(0, n);
      const pilih = new Set(atas);
      const sisa = a.filter((x) => !pilih.has(x));
      a = a.filter((x) => pilih.has(x));
      const lain = { tingkat: sisa[0].tingkat, induk: s, anak: new Map(), idxs: sisa.flatMap((x) => x.idxs), cache: {},
                     perKol: Array.from({ length: POHON.nc }, (_, c) => sisa.flatMap((x) => x.perKol[c])), lainnya: sisa.length };
      a.push(lain);
    }
    return a;
  }

  function susunBaris() {
    const L = POHON.rd.length, out = [];
    const jalan = (s, jalur) => {
      for (const a of urutkanAnak(s)) {
        const label = a.lainnya ? `Lainnya (${a.lainnya})` : String(nilaiDim(POHON.rd[a.tingkat], a.nilai));
        const kunci = jalur + "/" + (a.lainnya ? "~" : a.nilai);
        if (a.tingkat < L - 1 && !a.lainnya) {
          const lipat = ST.lipat.has(kunci);
          const nilaiDiGrup = lipat || ST.opsi.subtotal === "atas";
          out.push({ jenis: "grup", tingkat: a.tingkat, label, s: a, kunci, lipat, nilai: nilaiDiGrup });
          if (!lipat) {
            jalan(a, kunci);
            if (ST.opsi.subtotal === "bawah") out.push({ jenis: "subtotal", tingkat: a.tingkat, label: `Jumlah ${label}`, s: a, nilai: true });
          }
        } else out.push({ jenis: a.lainnya ? "lainnya" : "daun", tingkat: a.tingkat, label, s: a, nilai: true });
        if (out.length > MAKS_BARIS) return;
      }
    };
    if (L) jalan(POHON.akar, "");
    else out.push({ jenis: "daun", tingkat: 0, label: "Semua", s: POHON.akar, nilai: true });
    return out;
  }

  /* ------------------------------------------------------------------ render */
  function kolomTampil() {
    const M = ST.nilai.length, K = [];
    for (let c = 0; c < POHON.nc; c++) for (let m = 0; m < M; m++) K.push({ c, m });
    if (!POHON.nc || ST.opsi.total) for (let m = 0; m < M; m++) K.push({ c: -1, m });
    return K;
  }

  function skalaWarna(rows, K) {
    if (!ST.opsi.warna) return null;
    const per = ST.nilai.map(() => ({ min: Infinity, max: -Infinity, absMax: 0 }));
    rows.filter((r) => r.jenis === "daun" || r.jenis === "lainnya").forEach((r) => K.forEach(({ c, m }) => {
      if (c < 0 && POHON.nc) return;
      const v = tampil(r.s, c, m);
      if (!ada(v)) return;
      const p = per[m]; p.min = Math.min(p.min, v); p.max = Math.max(p.max, v); p.absMax = Math.max(p.absMax, Math.abs(v));
    }));
    return per;
  }

  function gayaSel(v, m, skala, tot) {
    if (!skala || !ada(v) || tot) return ["", "", ""];
    const p = skala[m];
    if (ST.opsi.warna === "batang") {
      const w = p.absMax ? Math.abs(v) / p.absMax * 100 : 0;
      return [" pv-batang", "", `<span class="pv-bar${v < 0 ? " neg" : ""}" style="width:${w.toFixed(1)}%"></span>`];
    }
    const div = p.min < 0 && p.max > 0;
    let t, warna;
    if (div) { t = Math.abs(v) / (p.absMax || 1); warna = v < 0 ? [192, 57, 43] : [46, 110, 158]; }
    else { t = p.max > p.min ? (v - p.min) / (p.max - p.min) : 0.5; warna = [46, 110, 158]; }
    const a = (0.08 + 0.62 * t).toFixed(2);
    return ["", ` style="background:rgba(${warna.join(",")},${a})${t > 0.75 ? ";color:#fff" : ""}"`, ""];
  }

  function render() {
    if (!SRC) return;
    POHON = bangunPohon();
    const rows = susunBaris(), K = kolomTampil(), M = ST.nilai.length, nc = POHON.nc;
    const kolomLabel = (c) => POHON.cd.map((d, h) => String(nilaiDim(d, POHON.kolom[c][h])));
    const nLevelKol = POHON.cd.length, multiM = M > 1;
    const sudut = ST.baris.map(labelDim).join(" / ") || "";
    // ---- tajuk
    let th = "", ekspor = [];
    const nBarisTajuk = Math.max(1, nLevelKol + (multiM ? 1 : 0));
    for (let h = 0; h < nLevelKol; h++) {
      let tr = h === 0 ? `<th rowspan="${nBarisTajuk}" class="pv-sudut">${esc(sudut || (M === 1 ? labelNilai(ST.nilai[0]) : ""))}</th>` : "";
      const ex = [h === 0 ? sudut : ""];
      let c = 0;
      while (c < nc) {
        let e = c + 1;
        const awal = POHON.kolom[c].slice(0, h + 1).join("|");
        while (e < nc && POHON.kolom[e].slice(0, h + 1).join("|") === awal) e++;
        const teks = String(nilaiDim(POHON.cd[h], POHON.kolom[c][h]));
        tr += `<th class="n" colspan="${(e - c) * M}">${esc(teks)}</th>`;
        ex.push({ t: teks, n: (e - c) * M });
        c = e;
      }
      if (h === 0 && ST.opsi.total) { tr += `<th class="n pv-tot" colspan="${M}" rowspan="${nLevelKol}">Total</th>`; ex.push({ t: "Total", n: M }); }
      else if (ST.opsi.total) ex.push({ t: "", n: M });
      th += `<tr>${tr}</tr>`;
      ekspor.push(ex);
    }
    if (multiM || !nLevelKol) {
      let tr = nLevelKol ? "" : `<th class="pv-sudut">${esc(sudut)}</th>`;
      const ex = [nLevelKol ? "" : sudut];
      K.forEach(({ m }) => { tr += `<th class="n">${esc(labelNilai(ST.nilai[m]))}</th>`; ex.push(labelNilai(ST.nilai[m])); });
      th += `<tr>${tr}</tr>`;
      ekspor.push(ex);
    }
    // ---- isi
    const skala = skalaWarna(rows, K);
    const sel1 = (s, c, m, tot) => {
      const v = tampil(s, c, m);
      if (!ada(v)) return `<td class="n kosong">${ST.opsi.kosong ? "–" : ""}</td>`;
      const [kls, gaya, isi] = gayaSel(v, m, skala, tot || (c < 0 && nc > 0));
      return `<td class="n${v < 0 ? " negatif" : ""}${kls}"${gaya}>${isi}${fmt(v, digit(m))}</td>`;
    };
    const exBaris = [];
    let tb = "";
    rows.forEach((r, i) => {
      const ind = ` t${Math.min(r.tingkat + (r.jenis === "daun" || r.jenis === "lainnya" ? 1 : 0), 4)}`;
      if (r.jenis === "grup") {
        tb += `<tr class="grup" data-kunci="${esc(r.kunci)}"><td class="label-baris${ind}"><span class="pv-togel">${r.lipat ? "▸" : "▾"}</span>${esc(r.label)} <span class="abu kecil">(${r.s.anak.size})</span></td>` +
          (r.nilai ? K.map(({ c, m }) => sel1(r.s, c, m, true)).join("") : `<td colspan="${K.length}"></td>`) + "</tr>";
      } else {
        const kls = r.jenis === "subtotal" ? "subtotal" : r.jenis === "lainnya" ? "pv-lainnya" : "";
        tb += `<tr class="${kls}"><td class="label-baris${ind}">${esc(r.label)}</td>${K.map(({ c, m }) => sel1(r.s, c, m, r.jenis === "subtotal")).join("")}</tr>`;
      }
      exBaris.push({ label: r.label, jenis: r.jenis === "lainnya" ? "" : r.jenis === "daun" ? "" : r.jenis, tingkat: r.tingkat,
                     nilai: r.nilai ? K.map(({ c, m }) => bulat(tampil(r.s, c, m), digit(m))) : [] });
    });
    let tf = "";
    if (ST.opsi.total && ST.baris.length) {
      tf = `<tfoot><tr class="total"><td>Total</td>${K.map(({ c, m }) => sel1(POHON.akar, c, m, true)).join("")}</tr></tfoot>`;
      exBaris.push({ label: "Total", jenis: "total", tingkat: 0, nilai: K.map(({ c, m }) => bulat(tampil(POHON.akar, c, m), digit(m))) });
    }
    const potong = rows.length > MAKS_BARIS ? `<p class="sorot kecil">Ditampilkan ${MAKS_BARIS} baris pertama; tambahkan filter atau lipat kelompok.</p>` : "";
    $("pv-tabel").innerHTML = `${potong}<table class="tabel pv"><thead>${th}</thead><tbody>${tb}</tbody>${tf}</table>`;
    $("pv-tabel").querySelectorAll("tr.grup").forEach((tr) => tr.addEventListener("click", () => {
      const k = tr.dataset.kunci;
      ST.lipat.has(k) ? ST.lipat.delete(k) : ST.lipat.add(k);
      simpanTerakhir(); render();
    }));
    const nSel = rows.length * K.length;
    $("pv-info").textContent = `${fmt(POHON.lolos, 0)} dari ${fmt(SRC.data.length, 0)} baris sumber · ${fmt(rows.length, 0)} baris × ${fmt(K.length, 0)} kolom (${fmt(nSel, 0)} sel)`;
    $("pv-judul").textContent = ST.nilai.length === 1 ? labelNilai(ST.nilai[0]) : ST.nilai.map(labelNilai).join(" · ");
    const tf2 = Object.entries(ST.filter).filter(([, v]) => v.length).map(([k, v]) => `${labelDim(k)} tanpa ${v.length > 3 ? v.length + " nilai" : v.join(", ")}`);
    $("pv-ket").textContent = SRC.judul + (tf2.length ? " · Filter: " + tf2.join("; ") : "") + (ST.opsi.tampil !== "nilai" ? " · " + $("pv-tampil").selectedOptions[0].text : "");
    // ---- matriks ekspor
    const header = ekspor;
    const headerCsv = ["" + sudut, ...K.map(({ c, m }) => [...(c < 0 ? (nc ? ["Total"] : []) : kolomLabel(c)), multiM || !nc ? labelNilai(ST.nilai[m]) : ""].filter(Boolean).join(" · "))];
    MATRIKS = { header, headerCsv, baris: exBaris, digit: K.map(({ m }) => digit(m)) };
    grafikPivot();
  }
  const bulat = (v, d) => (ada(v) ? +v.toFixed(Math.min(d + 2, 8)) : null);

  /* ------------------------------------------------------------------ grafik */
  function grafikPivot() {
    const jenis = $("pv-g-jenis").value;
    $("pv-g-wadah").hidden = !jenis;
    const pTk = $("pv-g-tingkat"), pUk = $("pv-g-ukuran");
    const tk = Math.min(+pTk.value || 0, Math.max(ST.baris.length - 1, 0));
    pTk.innerHTML = (ST.baris.length ? ST.baris : ["(semua)"]).map((k, i) => `<option value="${i}">${ST.baris.length ? esc(labelDim(k)) : k}</option>`).join("");
    pTk.value = tk;
    const um = Math.min(+pUk.value || 0, ST.nilai.length - 1);
    pUk.innerHTML = ST.nilai.map((n, i) => `<option value="${i}">${esc(labelNilai(n))}</option>`).join("");
    pUk.value = um;
    if (!jenis) return;
    const simpul = [];
    const kumpul = (s, jalur) => urutkanAnak(s).forEach((a) => {
      const lbl = a.lainnya ? `Lainnya (${a.lainnya})` : String(nilaiDim(POHON.rd[a.tingkat], a.nilai));
      const p = jalur ? `${jalur} › ${lbl}` : lbl;
      if (a.tingkat === tk || a.lainnya) simpul.push([p, a]);
      else kumpul(a, p);
    });
    if (ST.baris.length) kumpul(POHON.akar, ""); else simpul.push(["Semua", POHON.akar]);
    const lbl = simpul.map(([p]) => (tk > 0 ? p.split(" › ").slice(-2).join(" › ") : p));
    let ds;
    const MAKS_SERI = 14;
    if (POHON.nc) {
      ds = POHON.kolom.slice(0, MAKS_SERI).map((kk, c) => ({ label: POHON.cd.map((d, h) => nilaiDim(d, kk[h])).join(" · "), data: simpul.map(([, s]) => tampil(s, c, um)) }));
    } else {
      ds = ST.nilai.map((n, m) => ({ label: labelNilai(n), data: simpul.map(([, s]) => tampil(s, -1, m)) }));
    }
    const tipe = jenis === "line" ? "line" : "bar";
    const hex = (h) => {
      const f = (n) => { const k = (n + h / 30) % 12, a = 0.55 * Math.min(0.45, 0.55); return Math.round(255 * (0.45 - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))).toString(16).padStart(2, "0"); };
      return "#" + f(0) + f(8) + f(4);
    };
    const palet = ds.length > 8 ? ds.map((_, i) => hex((i * 360) / ds.length)) : null;
    if (palet) ds.forEach((d, i) => (d.warna = palet[i]));
    const h = jenis === "hbar" ? Math.max(320, simpul.length * (ds.length > 3 ? 22 : 16) + 80) : 360;
    $("pv-g-wadah").style.height = h + "px";
    window.grafik("pv-grafik", tipe, lbl, ds, { horizontal: jenis === "hbar", tumpuk: jenis === "tumpuk", digit: digit(um) });
    $("pv-g-ket").textContent = (POHON.nc > MAKS_SERI ? `Hanya ${MAKS_SERI} kolom pertama yang digambar. ` : "") +
      (POHON.nc ? `Seri = ${ST.kolom.map(labelDim).join(" · ")}; ukuran: ${labelNilai(ST.nilai[um])}.` : "Seri = ukuran.");
  }

  /* ------------------------------------------------------------------ panel bidang */
  function chip(k, zona) {
    const f = (ST.filter[k] || []).length, n = SRC.dimensi[SRC.dimIx[k]].nilai.length;
    return `<span class="pv-chip${f ? " tersaring" : ""}" draggable="true" data-kunci="${k}" data-dari="${zona}">` +
      `<span class="pv-chip-label">${esc(labelDim(k))}${f ? ` <small>${n - f}/${n}</small>` : ""}</span>` +
      `<button type="button" class="pv-saring" title="Saring nilai">⛉</button>` +
      (zona !== "bidang" ? `<button type="button" class="pv-x" title="Keluarkan">✕</button>` : "") + "</span>";
  }
  function gambarBidang() {
    const dipakai = new Set([...ST.baris, ...ST.kolom, ...ST.filterZona]);
    $("pv-z-bidang").innerHTML = SRC.dimensi.filter((d) => !dipakai.has(d.kunci)).map((d) => chip(d.kunci, "bidang")).join("") || '<span class="abu kecil">Semua bidang terpakai</span>';
    $("pv-z-filter").innerHTML = ST.filterZona.map((k) => chip(k, "filter")).join("");
    $("pv-z-baris").innerHTML = ST.baris.map((k) => chip(k, "baris")).join("");
    $("pv-z-kolom").innerHTML = ST.kolom.map((k) => chip(k, "kolom")).join("");
    $("pv-z-nilai").innerHTML = ST.nilai.map((n, i) => {
      const opsi = n.rumus ? "" : Object.entries(AGREGAT).filter(([a]) => a !== "bobot" || bobotDari(n.kunci))
        .map(([a, t]) => `<option value="${a}" ${a === n.agregat ? "selected" : ""}>${t}</option>`).join("");
      return `<div class="pv-nilai-item" data-i="${i}"><span class="pv-nilai-label" title="${esc(labelNilai(n))}">${esc(n.rumus ? labelNilai(n) : SRC.ukDef[n.kunci].label)}</span>` +
        (n.rumus ? `<span class="lencana kustom">rumus</span>` : `<select class="pv-ag">${opsi}</select>`) +
        `<button type="button" class="pv-naik" title="Naikkan" ${i ? "" : "disabled"}>↑</button><button type="button" class="pv-x" title="Hapus">✕</button></div>`;
    }).join("");
    const grup = {};
    SRC.ukuran.forEach((u) => (grup[u.grup] = grup[u.grup] || []).push(u));
    const og = Object.entries(grup).map(([g, us]) => `<optgroup label="${esc(g)}">${us.map((u) => `<option value="${u.kunci}">${esc(u.label)}${u.satuan ? ` (${esc(u.satuan)})` : ""}</option>`).join("")}</optgroup>`).join("");
    $("pv-tambah-ukuran").innerHTML = `<option value="">＋ Tambah ukuran…</option>${og}`;
    $("pv-r-a").innerHTML = og; $("pv-r-b").innerHTML = og;
    if (SRC.ukuran[1]) $("pv-r-b").value = SRC.ukuran[1].kunci;
    pasangChip();
  }

  function pasangChip() {
    document.querySelectorAll(".pv-chip").forEach((el) => {
      const k = el.dataset.kunci, dari = el.dataset.dari;
      el.addEventListener("dragstart", (e) => { e.dataTransfer.setData("text/plain", JSON.stringify({ k, dari })); el.classList.add("seret"); });
      el.addEventListener("dragend", () => el.classList.remove("seret"));
      el.querySelector(".pv-saring").addEventListener("click", (e) => { e.stopPropagation(); bukaSaring(k, el); });
      el.querySelector(".pv-x")?.addEventListener("click", (e) => { e.stopPropagation(); pindah(k, "bidang"); });
      el.querySelector(".pv-chip-label").addEventListener("click", () => (dari === "bidang" ? pindah(k, "baris") : bukaSaring(k, el)));
    });
    document.querySelectorAll(".pv-nilai-item").forEach((el) => {
      const i = +el.dataset.i;
      el.querySelector(".pv-ag")?.addEventListener("change", (e) => { ST.nilai[i].agregat = e.target.value; ubah(); });
      el.querySelector(".pv-x").addEventListener("click", () => { if (ST.nilai.length > 1) { ST.nilai.splice(i, 1); ubah(); } });
      el.querySelector(".pv-naik").addEventListener("click", () => { if (i) { [ST.nilai[i - 1], ST.nilai[i]] = [ST.nilai[i], ST.nilai[i - 1]]; ubah(); } });
    });
  }

  function daftarZona(z) { return z === "baris" ? ST.baris : z === "kolom" ? ST.kolom : z === "filter" ? ST.filterZona : null; }
  function pindah(k, ke, posisi) {
    ["baris", "kolom", "filter"].forEach((z) => { const a = daftarZona(z); const i = a.indexOf(k); if (i >= 0) a.splice(i, 1); });
    const a = daftarZona(ke);
    if (a) a.splice(posisi ?? a.length, 0, k);
    ubah();
  }
  document.querySelectorAll(".pv-zona").forEach((z) => {
    z.addEventListener("dragover", (e) => { e.preventDefault(); z.classList.add("di-atas"); });
    z.addEventListener("dragleave", () => z.classList.remove("di-atas"));
    z.addEventListener("drop", (e) => {
      e.preventDefault(); z.classList.remove("di-atas");
      let d; try { d = JSON.parse(e.dataTransfer.getData("text/plain")); } catch { return; }
      const chips = [...z.querySelectorAll(".pv-chip")].filter((c) => c.dataset.kunci !== d.k);
      let pos = chips.length;
      for (let i = 0; i < chips.length; i++) {
        const b = chips[i].getBoundingClientRect();
        if (e.clientY < b.top + b.height / 2 && e.clientY >= b.top - 4 ? e.clientX < b.left + b.width / 2 : e.clientY < b.top) { pos = i; break; }
      }
      pindah(d.k, z.dataset.zona, pos);
    });
  });

  /* ------------------------------------------------------------------ saring nilai */
  let popKunci = null;
  function bukaSaring(k, jangkar) {
    popKunci = k;
    const pop = $("pv-pop"), b = jangkar.getBoundingClientRect();
    $("pv-pop-judul").textContent = labelDim(k);
    $("pv-pop-cari").value = "";
    isiSaring();
    pop.hidden = false;
    pop.style.top = window.scrollY + b.bottom + 4 + "px";
    pop.style.left = Math.min(window.scrollX + b.left, window.scrollX + document.documentElement.clientWidth - 300) + "px";
    $("pv-pop-cari").focus();
  }
  function isiSaring() {
    const k = popKunci, q = $("pv-pop-cari").value.toLowerCase(), keluar = new Set((ST.filter[k] || []).map(String));
    const nilai = SRC.dimensi[SRC.dimIx[k]].nilai;
    $("pv-pop-daftar").innerHTML = nilai.filter((v) => String(v).toLowerCase().includes(q))
      .map((v) => `<label><input type="checkbox" value="${esc(v)}" ${keluar.has(String(v)) ? "" : "checked"}> ${esc(v)}</label>`).join("");
    $("pv-pop-daftar").querySelectorAll("input").forEach((c) => c.addEventListener("change", () => {
      const s = new Set((ST.filter[k] || []).map(String));
      c.checked ? s.delete(c.value) : s.add(c.value);
      ST.filter[k] = [...s];
      ubah(false);
    }));
  }
  $("pv-pop-cari").addEventListener("input", isiSaring);
  $("pv-pop-tutup").addEventListener("click", () => ($("pv-pop").hidden = true));
  document.querySelectorAll(".pv-pop-alat button").forEach((b) => b.addEventListener("click", () => {
    const k = popKunci, nilai = SRC.dimensi[SRC.dimIx[k]].nilai.map(String), q = $("pv-pop-cari").value.toLowerCase();
    const terlihat = nilai.filter((v) => v.toLowerCase().includes(q));
    const s = new Set((ST.filter[k] || []).map(String));
    if (b.dataset.aksi === "semua") terlihat.forEach((v) => s.delete(v));
    if (b.dataset.aksi === "kosong") terlihat.forEach((v) => s.add(v));
    if (b.dataset.aksi === "balik") terlihat.forEach((v) => (s.has(v) ? s.delete(v) : s.add(v)));
    ST.filter[k] = [...s];
    isiSaring(); ubah(false);
  }));
  document.addEventListener("click", (e) => {
    const pop = $("pv-pop");
    if (!pop.hidden && !pop.contains(e.target) && !e.target.closest(".pv-chip")) pop.hidden = true;
  });

  /* ------------------------------------------------------------------ opsi */
  const OPSI_EL = { tampil: "pv-tampil", urut: "pv-urut", subtotal: "pv-subtotal", warna: "pv-warna", topn: "pv-topn", digit: "pv-digit" };
  function opsiKeForm() {
    Object.entries(OPSI_EL).forEach(([k, id]) => ($(id).value = ST.opsi[k]));
    $("pv-total").checked = ST.opsi.total; $("pv-kosong").checked = ST.opsi.kosong;
  }
  Object.entries(OPSI_EL).forEach(([k, id]) => $(id).addEventListener("change", () => { ST.opsi[k] = $(id).type === "number" ? +$(id).value : $(id).value; ubah(false); }));
  $("pv-total").addEventListener("change", (e) => { ST.opsi.total = e.target.checked; ubah(false); });
  $("pv-kosong").addEventListener("change", (e) => { ST.opsi.kosong = e.target.checked; ubah(false); });
  ["pv-g-jenis", "pv-g-tingkat", "pv-g-ukuran"].forEach((id) => $(id).addEventListener("change", grafikPivot));
  $("pv-tukar").addEventListener("click", () => { [ST.baris, ST.kolom] = [ST.kolom, ST.baris]; ST.lipat.clear(); ubah(); });
  $("pv-buka").addEventListener("click", () => { ST.lipat.clear(); ubah(false); });
  $("pv-lipat").addEventListener("click", () => {
    const kunci = [];
    const jalan = (s, j) => s.anak.forEach((a) => { if (a.tingkat < ST.baris.length - 1) { const k = j + "/" + a.nilai; kunci.push(k); jalan(a, k); } });
    if (POHON) jalan(POHON.akar, "");
    ST.lipat = new Set(kunci.filter((k) => k.split("/").length === 2));
    ubah(false);
  });
  $("pv-tambah-ukuran").addEventListener("change", (e) => {
    const k = e.target.value;
    if (k) { ST.nilai.push({ kunci: k, agregat: agregatBawaan(k) }); ubah(); }
  });
  $("pv-r-tambah").addEventListener("click", () => {
    const r = { a: $("pv-r-a").value, op: $("pv-r-op").value, b: $("pv-r-b").value, k: +$("pv-r-k").value || 1 };
    ST.nilai.push({ rumus: r, label: $("pv-r-nama").value.trim() || null, digit: r.op === "/" ? 2 : 0 });
    $("pv-r-nama").value = "";
    ubah();
  });

  /* ------------------------------------------------------------------ simpan, muat, bagikan */
  const tersimpan = () => { try { return JSON.parse(localStorage.getItem(SIMPAN) || "{}"); } catch { return {}; } };
  function salinStatus() {
    return { sumber: $("pv-sumber").value, param: paramSumber($("pv-sumber").value), baris: [...ST.baris], kolom: [...ST.kolom],
             filterZona: [...ST.filterZona], filter: ST.filter, nilai: ST.nilai, opsi: ST.opsi, lipat: [...ST.lipat],
             grafik: { jenis: $("pv-g-jenis").value } };
  }
  function simpanTerakhir() { try { localStorage.setItem(TERAKHIR, JSON.stringify(salinStatus())); } catch { /* penuh */ } }
  function isiTata(pilih) {
    const s = tersimpan();
    $("pv-tata").innerHTML = `<option value="">— pilih —</option><optgroup label="Bawaan">${Object.keys(PRESET).map((n) => `<option value="p:${esc(n)}">${esc(n)}</option>`).join("")}</optgroup>` +
      (Object.keys(s).length ? `<optgroup label="Tersimpan">${Object.keys(s).map((n) => `<option value="s:${esc(n)}">${esc(n)}</option>`).join("")}</optgroup>` : "");
    if (pilih) $("pv-tata").value = pilih;
  }
  async function terapkan(t) {
    t = JSON.parse(JSON.stringify(t));
    $("pv-sumber").value = t.sumber;
    const p = t.param || {};
    if (p.versi) $("pv-versi").value = p.versi;
    if (t.sumber === "skenario") setSk(p.sk || "aktif");
    if (p.tahun) $("pv-io-tahun").value = p.tahun;
    if (p.metode) $("pv-io-metode").value = p.metode;
    if (t.grafik?.jenis !== undefined) $("pv-g-jenis").value = t.grafik.jenis;
    tampilkanParam();
    ST = { baris: t.baris || [], kolom: t.kolom || [], filterZona: t.filterZona || [], filter: t.filter || {}, nilai: t.nilai || [], opsi: t.opsi || {}, lipat: new Set(t.lipat || []) };
    if (await muat()) { rapikanStatus(); opsiKeForm(); gambarBidang(); render(); simpanTerakhir(); }
  }
  $("pv-tata").addEventListener("change", (e) => {
    const v = e.target.value;
    if (v.startsWith("p:")) terapkan(PRESET[v.slice(2)]);
    if (v.startsWith("s:")) terapkan(tersimpan()[v.slice(2)]);
  });
  $("pv-simpan").addEventListener("click", () => {
    const awal = $("pv-tata").value.startsWith("s:") ? $("pv-tata").value.slice(2) : "";
    const nama = prompt("Nama tata letak:", awal);
    if (!nama) return;
    const s = tersimpan(); s[nama] = salinStatus();
    localStorage.setItem(SIMPAN, JSON.stringify(s));
    isiTata("s:" + nama);
  });
  $("pv-hapus-tata").addEventListener("click", () => {
    const v = $("pv-tata").value;
    if (!v.startsWith("s:")) { alert("Pilih tata letak tersimpan untuk dihapus (bawaan tidak bisa dihapus)."); return; }
    if (!confirm(`Hapus tata letak "${v.slice(2)}"?`)) return;
    const s = tersimpan(); delete s[v.slice(2)];
    localStorage.setItem(SIMPAN, JSON.stringify(s));
    isiTata();
  });
  $("pv-tautan").addEventListener("click", async () => {
    const url = location.origin + location.pathname + "#t=" + encodeURIComponent(JSON.stringify(salinStatus()));
    history.replaceState(null, "", url);
    try { await navigator.clipboard.writeText(url); $("pv-tautan").textContent = "Tersalin"; } catch { prompt("Salin tautan:", url); }
    setTimeout(() => ($("pv-tautan").textContent = "Tautan"), 1500);
  });

  /* ------------------------------------------------------------------ ekspor */
  const namaBerkas = () => "pivot_" + ($("pv-judul").textContent || "tabel").toLowerCase().replace(/[^a-z0-9]+/g, "_").slice(0, 40);
  $("pv-csv").addEventListener("click", () => {
    if (!MATRIKS) return;
    const rows = MATRIKS.baris.map((b) => ["  ".repeat(b.tingkat) + b.label, ...(b.nilai.length ? b.nilai : MATRIKS.headerCsv.slice(1).map(() => ""))]);
    window.unduhCSV(namaBerkas() + ".csv", MATRIKS.headerCsv, rows);
  });
  $("pv-xlsx").addEventListener("click", async () => {
    if (!MATRIKS) return;
    const r = await fetch(window.PV.xlsx, {
      method: "POST", headers: { "Content-Type": "application/json", "X-CSRFToken": window.PV.csrf },
      body: JSON.stringify({ judul: $("pv-judul").textContent, keterangan: $("pv-ket").textContent, header: MATRIKS.header,
                             baris: MATRIKS.baris, digit: MATRIKS.digit, berkas: namaBerkas() }),
    });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(await r.blob());
    a.download = namaBerkas() + ".xlsx";
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  });

  /* ------------------------------------------------------------------ alur */
  let tunda = null;
  function ubah(bidang = true) {
    if (bidang) gambarBidang();
    clearTimeout(tunda);
    tunda = setTimeout(() => { render(); simpanTerakhir(); }, 30);
  }
  async function gantiSumber() {
    tampilkanParam();
    const lama = ST;
    ST = { ...lama, lipat: new Set() };
    if (!(await muat())) return;
    const dim = new Set(SRC.dimensi.map((d) => d.kunci));
    const nilaiCocok = (ST.nilai || []).some((n) => SRC.ukDef[n.kunci] || (n.rumus && SRC.ukDef[n.rumus.a]));
    if (!nilaiCocok || !ST.baris.some((k) => dim.has(k))) {
      const p = PRESET[BAWAAN_SUMBER[$("pv-sumber").value]];
      ST = { baris: [...p.baris], kolom: [...p.kolom], filterZona: [], filter: {}, nilai: JSON.parse(JSON.stringify(p.nilai)), opsi: { ...OPSI0, ...(p.opsi || {}) }, lipat: new Set() };
    }
    rapikanStatus(); opsiKeForm(); gambarBidang(); render(); simpanTerakhir();
  }
  $("pv-sumber").addEventListener("change", gantiSumber);
  ["pv-versi", "pv-io-tahun", "pv-io-metode"].forEach((id) => $(id).addEventListener("change", gantiSumber));
  document.querySelectorAll("#pv-sk input").forEach((c) => c.addEventListener("change", () => { setSk(skDipilih()); gantiSumber(); }));
  document.querySelectorAll("[data-sk]").forEach((b) => b.addEventListener("click", () => { setSk(b.dataset.sk); gantiSumber(); }));

  isiTata();
  setSk("aktif");
  let awal = null;
  if (location.hash.startsWith("#t=")) { try { awal = JSON.parse(decodeURIComponent(location.hash.slice(3))); } catch { /* abaikan */ } }
  if (!awal) { try { awal = JSON.parse(localStorage.getItem(TERAKHIR) || "null"); } catch { /* abaikan */ } }
  terapkan(awal || PRESET["PDRB per pulau × tahun"]);
})();
