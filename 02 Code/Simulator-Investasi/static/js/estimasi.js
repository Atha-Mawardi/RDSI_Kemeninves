/* Meja kerja estimasi: spesifikasi -> /estimasi/hitung/ -> koefisien, efek tetap, residual, perbandingan set. */
(function () {
  const $ = (id) => document.getElementById(id);
  const fmt = (v, d) => window.fmtID(v, d);
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const SET = JSON.parse($("d-set").textContent), PROV = JSON.parse($("d-prov").textContent);
  const PULAU_K = Object.fromEntries(PROV.map((p) => [p.kode, p.pulau]));
  const NAMA_K = Object.fromEntries(PROV.map((p) => [String(p.kode), p.nama]));
  const WARNA_P = { Sumatera: "#1f3b57", Jawa: "#e07b39", "Bali-Nusra": "#2e8b57", Kalimantan: "#8e44ad", Sulawesi: "#c0392b", "Maluku-Papua": "#2e6e9e" };
  let H = null, tunda = null, grafikBanding = null, grafikResid = null;

  /* ------------------------------------------------------------------ pil tahun dan provinsi */
  function isiTahun() {
    const o = $("es-versi").selectedOptions[0];
    const awal = +o.dataset.awal, akhir = +o.dataset.akhir, lama = new Set(tahunDipilih());
    let h = "";
    for (let t = awal; t <= akhir; t++) h += `<button type="button" class="pil-es${!lama.size || lama.has(t) ? " aktif" : ""}" data-t="${t}">${t}</button>`;
    $("es-tahun").innerHTML = h;
    $("es-tahun").querySelectorAll("button").forEach((b) => b.addEventListener("click", () => { b.classList.toggle("aktif"); ubah(); }));
  }
  const tahunDipilih = () => [...$("es-tahun").querySelectorAll(".aktif")].map((b) => +b.dataset.t);
  const provDipilih = () => [...$("es-prov").querySelectorAll(".pil-es.aktif")].map((b) => +b.dataset.kode);
  document.querySelectorAll("[data-th]").forEach((b) => b.addEventListener("click", () => {
    $("es-tahun").querySelectorAll("button").forEach((x) => {
      const t = +x.dataset.t;
      x.classList.toggle("aktif", b.dataset.th === "semua" || (b.dataset.th === "covid" && t !== 2020) || (b.dataset.th === "vintage" && t >= 2017 && t <= 2024));
    });
    ubah();
  }));
  $("es-prov").querySelectorAll(".pil-es").forEach((b) => b.addEventListener("click", () => { b.classList.toggle("aktif"); ubah(); }));
  $("es-prov").querySelectorAll(".es-pulau-btn").forEach((b) => b.addEventListener("click", () => {
    const pil = b.nextElementSibling.querySelectorAll(".pil-es"), semua = [...pil].every((x) => x.classList.contains("aktif"));
    pil.forEach((x) => x.classList.toggle("aktif", !semua));
    ubah();
  }));
  document.querySelectorAll("[data-prov]").forEach((b) => b.addEventListener("click", () => {
    $("es-prov").querySelectorAll(".pil-es").forEach((x) => {
      const p = PULAU_K[+x.dataset.kode];
      if (b.dataset.prov === "semua") x.classList.add("aktif");
      if (b.dataset.prov === "luar-jawa") x.classList.toggle("aktif", p !== "Jawa");
      if (b.dataset.prov === "balik") x.classList.toggle("aktif");
    });
    ubah();
  }));
  $("es-modal").addEventListener("change", () => { $("es-delta").disabled = $("es-modal").value !== "stok"; ubah(); });
  ["es-efek-tahun", "es-crs", "es-delta"].forEach((id) => $(id).addEventListener("change", ubah));
  $("es-versi").addEventListener("change", () => { isiTahun(); ubah(); });

  function spek() {
    return { versi: +$("es-versi").value, tahun: tahunDipilih(), provinsi: provDipilih(), crs: $("es-crs").checked,
             efek_tahun: $("es-efek-tahun").checked, modal: $("es-modal").value, delta: +$("es-delta").value };
  }
  function ubah() {
    $("es-n-tahun").textContent = `${tahunDipilih().length} tahun`;
    $("es-n-prov").textContent = `${provDipilih().length} dari ${PROV.length}`;
    document.querySelectorAll(".es-pulau-btn").forEach((b) => {
      const pil = [...b.nextElementSibling.querySelectorAll(".pil-es")];
      b.classList.toggle("sebagian", pil.some((x) => x.classList.contains("aktif")) && !pil.every((x) => x.classList.contains("aktif")));
      b.classList.toggle("mati", !pil.some((x) => x.classList.contains("aktif")));
    });
    clearTimeout(tunda);
    tunda = setTimeout(hitung, 150);
  }

  /* ------------------------------------------------------------------ hitung dan tampilkan */
  async function kirim(url, isi) {
    const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json", "X-CSRFToken": window.ES.csrf }, body: JSON.stringify(isi) });
    const d = await r.json();
    if (!r.ok) throw new Error(d.galat || r.statusText);
    return d;
  }
  async function hitung() {
    document.querySelector(".es-hasil").classList.add("memuat");
    try { H = await kirim(window.ES.hitung, spek()); }
    catch (e) {
      H = null;
      $("es-kpi").innerHTML = `<div class="kartu sorot" style="grid-column:1/-1;margin:0">${esc(e.message)}</div>`;
      $("es-koef").innerHTML = ""; return;
    } finally { document.querySelector(".es-hasil").classList.remove("memuat"); }
    tampil();
  }

  function tampil() {
    const k1 = H.koefisien[0], k2 = H.koefisien[1], u = H.uji_crs;
    const rts = k1.b + k2.b;
    $("es-kpi").innerHTML = [
      ["b1 · modal", fmt(k1.b, 4), `SE ${fmt(k1.se, 4)} · p ${p(k1.p)}`, k1.p < 0.05],
      ["b2 · tenaga kerja", fmt(k2.b, 4), H.spesifikasi.crs ? "= 1 − b1 (CRS dipaksa)" : `SE ${fmt(k2.se, 4)} · p ${p(k2.p)}`, k2.p < 0.05],
      ["b1 + b2", fmt(rts, 3), u ? `uji CRS: F ${fmt(u.F, 2)} · p ${p(u.p)}` : "dipaksa = 1", u ? u.p >= 0.05 : true],
      ["R² within", fmt(H.r2_within, 3), `R² total ${fmt(H.r2_total, 4)} · RMSE ${fmt(H.rmse, 4)}`, null],
      ["Observasi", fmt(H.n_obs, 0), `${H.n_provinsi} provinsi × ${H.n_tahun} tahun${H.dibuang.length ? ` · ${H.dibuang.length} baris tak lengkap dibuang` : ""}`, null],
    ].map(([a, b, c, baik]) => `<div class="kpi${baik === true ? " baik" : baik === false ? " buruk" : ""}"><div class="label">${a}</div><div class="nilai">${b}</div><div class="ket">${esc(c)}</div></div>`).join("");
    let t = `<table class="tabel es-koef"><thead><tr><th>Regresor</th><th class="n">Koefisien</th><th class="n">SE klaster</th><th class="n">t</th><th class="n">p</th><th class="n">95% CI</th></tr></thead><tbody>`;
    H.koefisien.forEach((c) => {
      t += `<tr><td>${esc(c.label)}</td><td class="n"><b>${fmt(c.b, 4)}</b><sup>${c.bintang}</sup></td><td class="n">${fmt(c.se, 4)}</td><td class="n">${fmt(c.t, 2)}</td><td class="n">${p(c.p)}</td><td class="n">[${fmt(c.lo, 3)}; ${fmt(c.hi, 3)}]</td></tr>`;
    });
    t += `<tr class="grup"><td colspan="6">Efek tetap dan uji</td></tr>`;
    t += `<tr><td class="inden">Efek tetap provinsi</td><td class="n" colspan="5">${H.n_provinsi}, diserap transformasi within</td></tr>`;
    t += `<tr><td class="inden">Efek tetap tahun</td><td class="n" colspan="5">${H.spesifikasi.efek_tahun ? H.n_tahun - 1 + " dummy" : "tidak dipakai"}</td></tr>`;
    if (u) t += `<tr><td class="inden">Uji CRS: b1 + b2 = 1</td><td class="n">${fmt(u.rts, 3)}</td><td class="n">${fmt(u.se, 4)}</td><td class="n">${fmt(u.t, 2)}</td><td class="n">${p(u.p)}</td><td class="n">${u.p < 0.05 ? "ditolak" : "tidak ditolak"}</td></tr>`;
    t += `</tbody><tfoot><tr class="total"><td>N · G · df uji</td><td class="n" colspan="5">${H.n_obs} obs · ${H.n_provinsi} klaster · t(${H.df_klaster}), t kritis ${fmt(H.t_kritis, 3)}</td></tr></tfoot></table>`;
    $("es-koef").innerHTML = t;
    const sp = H.spesifikasi;
    $("es-catatan").textContent = `*** p<0,01 · ** p<0,05 · * p<0,1. Galat baku klaster provinsi (HC1, setara plm arellano). ` +
      `Tahun ${sp.tahun_awal}–${sp.tahun_akhir}${sp.kecuali_tahun.length ? " tanpa " + sp.kecuali_tahun.join(", ") : ""}; ` +
      `${sp.provinsi ? sp.provinsi.length + " provinsi terpilih" : "semua provinsi"}; K = ${sp.modal === "stok" ? "stok PIM δ=" + fmt(sp.delta, 2) : "PMTB riil (arus)"}.` +
      (H.dibuang.length ? ` Dibuang karena data kosong: ${H.dibuang.slice(0, 6).map(([k, t]) => NAMA_K[k] + " " + t).join(", ")}${H.dibuang.length > 6 ? ", …" : ""}.` : "");
    // efek tahun
    const et = H.efek_tahun;
    grafik("es-g-tahun", "bar", et.map((e) => e.tahun), [
      { label: "d_t", data: et.map((e) => e.d), warna: "#2e6e9e" },
      { label: "Observasi", type: "line", data: et.map((e) => e.n), warna: "#e07b39", yAxisID: "y2", borderDash: [4, 3] },
    ], { digit: 4, digitSumbu: 3, sumbuKanan: { judul: "observasi", min: 0 } });
    // peta efek provinsi
    petaChoropleth("es-peta", H.efek_provinsi, { label: "a_i relatif", skema: "div", digit: 3, nama: NAMA_K });
    // residual
    const titik = {};
    H.residual.forEach(([k, th, f, r]) => (titik[PULAU_K[k]] = titik[PULAU_K[k]] || []).push({ x: f, y: r, k, th }));
    if (grafikResid) grafikResid.destroy();
    grafikResid = new Chart($("es-g-resid"), {
      type: "scatter",
      data: { datasets: Object.entries(titik).map(([pl, d]) => ({ label: pl, data: d, backgroundColor: WARNA_P[pl] + "bb", pointRadius: 3 })) },
      options: { responsive: true, maintainAspectRatio: false,
        plugins: { legend: { position: "bottom", labels: { boxWidth: 10, font: { size: 11 } } },
                   tooltip: { callbacks: { label: (c) => `${NAMA_K[c.raw.k]} ${c.raw.th}: suaian ${fmt(c.raw.x, 3)}, residual ${fmt(c.raw.y, 4)}` } } },
        scales: { x: { title: { display: true, text: H.spesifikasi.crs ? "suaian ln(Y/L)" : "suaian ln Y" } }, y: { title: { display: true, text: "residual" } } } },
    });
    // baris pratinjau dan perbandingan
    const br = $("es-baris-pratinjau");
    br.querySelector('[data-k="b1"]').innerHTML = `<b>${fmt(k1.b, 4)}</b><div class="kecil abu">(${fmt(k1.se, 4)})</div>`;
    br.querySelector('[data-k="b2"]').innerHTML = `<b>${fmt(k2.b, 4)}</b><div class="kecil abu">(${fmt(k2.se, 4)})</div>`;
    br.querySelector('[data-k="rts"]').textContent = fmt(rts, 3);
    br.querySelector('[data-k="n"]').textContent = H.n_obs;
    br.querySelector('[data-k="spek"]').textContent = `${sp.tahun_awal}–${sp.tahun_akhir}${sp.kecuali_tahun.length ? " · tanpa " + sp.kecuali_tahun.join(", ") : ""}${sp.provinsi ? " · " + sp.provinsi.length + " provinsi" : ""}${sp.modal === "stok" ? " · stok PIM" : ""}${sp.crs ? " · CRS" : ""}`;
    banding();
    if (!$("es-nama").value || $("es-nama").dataset.auto) {
      $("es-nama").value = `TWFE ${sp.tahun_awal}–${sp.tahun_akhir}${sp.kecuali_tahun.length ? " tanpa " + sp.kecuali_tahun.join(",") : ""}${sp.provinsi ? " (" + sp.provinsi.length + " prov)" : ""}${sp.modal === "stok" ? " stok PIM" : ""}${sp.crs ? " CRS" : ""}`;
      $("es-nama").dataset.auto = "1";
    }
  }
  const p = (x) => (x < 0.001 ? "<0,001" : fmt(x, 3));
  $("es-nama").addEventListener("input", () => delete $("es-nama").dataset.auto);

  function banding() {
    const t = window.fmtID;
    const semua = [{ nama: "Pratinjau", b1: H.b1, se_b1: H.se_b1, b2: H.b2, se_b2: H.se_b2 }, ...SET];
    const lbl = semua.map((s) => (s.nama.length > 26 ? s.nama.slice(0, 25) + "…" : s.nama));
    const ci = (b, se) => [b - 1.96 * se, b + 1.96 * se];
    if (grafikBanding) grafikBanding.destroy();
    grafikBanding = new Chart($("es-g-banding"), {
      type: "bar",
      data: { labels: lbl, datasets: [
        { label: "b1 (modal) 95% CI", data: semua.map((s) => ci(s.b1, s.se_b1 || 0)), backgroundColor: "#2e6e9e55", borderColor: "#2e6e9e", borderWidth: 1, barPercentage: 0.5 },
        { label: "b2 (TK) 95% CI", data: semua.map((s) => ci(s.b2, s.se_b2 || 0)), backgroundColor: "#e07b3955", borderColor: "#e07b39", borderWidth: 1, barPercentage: 0.5 },
        { label: "b1", type: "scatter", data: semua.map((s, i) => ({ x: s.b1, y: lbl[i] })), backgroundColor: "#1f3b57", pointRadius: 4, pointStyle: "rectRot" },
        { label: "b2", type: "scatter", data: semua.map((s, i) => ({ x: s.b2, y: lbl[i] })), backgroundColor: "#a6501f", pointRadius: 4, pointStyle: "rectRot" },
      ] },
      options: { indexAxis: "y", responsive: true, maintainAspectRatio: false,
        plugins: { legend: { position: "bottom", labels: { boxWidth: 10, font: { size: 11 }, filter: (i) => i.text.includes("CI") } },
                   tooltip: { callbacks: { label: (c) => Array.isArray(c.raw) ? `${c.dataset.label}: [${t(c.raw[0], 3)}; ${t(c.raw[1], 3)}]` : `${c.dataset.label}: ${t(c.raw.x, 4)}` } } },
        scales: { x: { title: { display: true, text: "elastisitas" } }, y: { grid: { display: false }, ticks: { font: { size: 11 } } } } },
    });
  }

  $("es-simpan").addEventListener("click", async () => {
    if (!H) return;
    $("es-simpan").disabled = true;
    try {
      const d = await kirim(window.ES.simpan, { ...spek(), nama: $("es-nama").value, bawaan: $("es-bawaan").checked });
      location.href = d.url;
    } catch (e) { alert(e.message); $("es-simpan").disabled = false; }
  });

  isiTahun();
  ubah();
})();
