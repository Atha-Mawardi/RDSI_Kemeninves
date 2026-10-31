/* Halaman IO dan IRIO: peta aliran, keterkaitan, peta pengganda, dampak skenario. */
(function () {
  const $ = (id) => document.getElementById(id);
  const J = (id) => JSON.parse($(id).textContent);
  const SEK = J("d-sektor"), WIL = J("d-wilayah"), PULAU = J("d-pulau");
  const NM = Object.fromEntries(WIL.map((w) => [String(w.kode), w.nama]));
  const PL = Object.fromEntries(WIL.map((w) => [String(w.kode), w.pulau]));
  const NSEK = Object.fromEntries(SEK.map((s) => [s.kode, s.nama]));
  const WPULAU = Object.fromEntries(PULAU.map((p, i) => [p, PALET[i % PALET.length]]));
  const fmt = (v, d = 1) => fmtID(v, d);
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const q = () => `tahun=${$("io-tahun").value}&metode=${$("io-metode").value}`;
  async function ambil(url) {
    const r = await fetch(url);
    const d = await r.json();
    if (!r.ok) throw new Error(d.galat || r.statusText);
    return d;
  }
  const warnaSkala = (skema, t) => { const w = SKALA[skema]; return w[Math.max(0, Math.min(w.length - 1, Math.floor(t * w.length)))]; };
  const WARNA17 = SEK.map((_, i) => `hsl(${Math.round((i * 360) / 17)}, 55%, 45%)`);

  /* Tabel panas kecil: baris × kolom dengan total. */
  function tabelPanas(el, labelBaris, labelKolom, M, opsi = {}) {
    const semua = M.flat().filter((v) => v > 0), maks = Math.max(...semua, 1e-9);
    const d = opsi.digit ?? 1;
    let h = `<table class="tabel rapat"><thead><tr><th>${esc(opsi.sudut || "")}</th>${labelKolom.map((c) => `<th class="n">${esc(c)}</th>`).join("")}<th class="n">Total</th></tr></thead><tbody>`;
    M.forEach((baris, i) => {
      h += `<tr><td class="label-baris">${esc(labelBaris[i])}</td>` + baris.map((v, j) => {
        const t = Math.sqrt(Math.max(v, 0) / maks);
        const diag = opsi.diagonal && i === j;
        return `<td class="n" style="background:${diag ? "#f3f5f8" : `rgba(46,110,158,${(t * 0.85).toFixed(3)})`};color:${t > 0.55 && !diag ? "#fff" : "inherit"}">${fmt(v, d)}</td>`;
      }).join("") + `<td class="n"><b>${fmt(baris.reduce((a, b) => a + b, 0), d)}</b></td></tr>`;
    });
    const kol = labelKolom.map((_, j) => M.reduce((a, r) => a + r[j], 0));
    h += `</tbody><tfoot><tr class="total"><td>Total</td>${kol.map((v) => `<td class="n">${fmt(v, d)}</td>`).join("")}<td class="n">${fmt(kol.reduce((a, b) => a + b, 0), d)}</td></tr></tfoot></table>`;
    el.innerHTML = h;
  }

  function pulauMatriks(M, wil) {
    const ip = (k) => PULAU.indexOf(PL[String(k)]);
    const P = PULAU.map(() => PULAU.map(() => 0));
    M.forEach((baris, i) => baris.forEach((v, j) => { P[ip(wil[i])][ip(wil[j])] += v; }));
    return P;
  }

  // ======================================================================= Peta aliran
  let petaA = null, lapisLatar = null, lapisBusur = null, lapisSimpul = null, dataA = null;
  const pusat = {}, cacheInd = {};

  function titikPusat(geom) {
    const poli = geom.type === "Polygon" ? [geom.coordinates] : geom.coordinates;
    let terbaik = null, luasMaks = -1;
    poli.forEach((p) => {
      const c = p[0];
      let a = 0, cx = 0, cy = 0;
      for (let i = 0; i < c.length - 1; i++) {
        const f = c[i][0] * c[i + 1][1] - c[i + 1][0] * c[i][1];
        a += f; cx += (c[i][0] + c[i + 1][0]) * f; cy += (c[i][1] + c[i + 1][1]) * f;
      }
      if (Math.abs(a) > luasMaks) { luasMaks = Math.abs(a); terbaik = a ? [cy / (3 * a), cx / (3 * a)] : [c[0][1], c[0][0]]; }
    });
    return terbaik;
  }

  async function siapkanPeta() {
    if (petaA) return;
    const geo = await (await fetch(window.GEO_URL)).json();
    petaA = L.map("peta-aliran", { zoomSnap: 0.1, attributionControl: false, scrollWheelZoom: false });
    lapisLatar = L.geoJSON(geo, { style: { fillColor: "#d3dce6", weight: 0.8, color: "#fff", fillOpacity: 1 } }).addTo(petaA);
    lapisLatar.eachLayer((l) => {
      const k = String(l.feature.properties.kode);
      pusat[k] = titikPusat(l.feature.geometry);
      l.on("click", () => { $("al-fokus").value = $("al-fokus").value === k ? "" : k; gambarBusur(); });
    });
    const pas = () => { petaA.invalidateSize(); petaA.fitBounds(lapisLatar.getBounds(), { padding: [10, 10] }); };
    pas();
    new ResizeObserver(pas).observe($("peta-aliran"));
    lapisBusur = L.layerGroup().addTo(petaA);
    lapisSimpul = L.layerGroup().addTo(petaA);
    new ResizeObserver(() => petaA.invalidateSize()).observe($("peta-aliran"));
  }

  async function indikator(sektor = "") {
    const kunci = `${q()}&sektor=${sektor}`;
    if (!cacheInd[kunci]) cacheInd[kunci] = ambil(`${IO_API.indikator}?${kunci}`);
    return cacheInd[kunci];
  }

  async function latar() {
    const k = $("al-latar").value;
    if (!k) { lapisLatar.setStyle({ fillColor: "#d3dce6", fillOpacity: 1 }); lapisLatar.eachLayer((l) => l.unbindTooltip().bindTooltip(NM[l.feature.properties.kode] || "", { sticky: true })); return; }
    const d = (await indikator()).nilai[k];
    const v = Object.values(d).filter((x) => x !== null);
    const div = k === "neraca_antar", m = Math.max(...v.map(Math.abs)) || 1;
    const urut = [...v].sort((a, b) => a - b);
    lapisLatar.eachLayer((l) => {
      const kd = String(l.feature.properties.kode), x = d[kd];
      const t = div ? (x / m + 1) / 2 : urut.indexOf(x) / Math.max(urut.length - 1, 1);
      l.setStyle({ fillColor: x === undefined ? "#eee" : warnaSkala(div ? "div" : (k === "bocoran" ? "merah" : "seq"), t), fillOpacity: 0.55 });
      l.unbindTooltip().bindTooltip(`<b>${NM[kd]}</b><br>${$("al-latar").selectedOptions[0].text}: ${fmt(x, k === "bocoran" ? 1 : 1)}`, { sticky: true });
    });
  }

  function busur(a, b, lengkung) {
    const [la, lo] = a, [lb, lob] = b;
    const dx = lob - lo, dy = lb - la;
    const c = [(la + lb) / 2 + dx * lengkung, (lo + lob) / 2 - dy * lengkung];
    const titik = (t) => [(1 - t) ** 2 * la + 2 * (1 - t) * t * c[0] + t * t * lb, (1 - t) ** 2 * lo + 2 * (1 - t) * t * c[1] + t * t * lob];
    return { titik, garis: Array.from({ length: 25 }, (_, i) => titik(i / 24)), jarak: Math.hypot(dx, dy) };
  }

  async function muatAliran() {
    const u = `${IO_API.aliran}?${q()}&asal=${$("al-asal").value}&tujuan=${$("al-tujuan").value}`;
    dataA = await ambil(u);
    gambarBusur();
  }

  function gambarBusur() {
    if (!dataA || !petaA) return;
    $("al-n-v").textContent = " " + $("al-n").value;
    lapisBusur.clearLayers(); lapisSimpul.clearLayers();
    const M = dataA.matriks, W = dataA.wil.map(String);
    const fokus = $("al-fokus").value, arah = $("al-arah").value;
    const ambang = parseFloat($("al-ambang").value) || 0, n = +$("al-n").value;
    let pasang = [];
    M.forEach((baris, i) => baris.forEach((v, j) => {
      if (i === j || v <= ambang) return;
      if (fokus && !((arah !== "masuk" && W[i] === fokus) || (arah !== "keluar" && W[j] === fokus))) return;
      pasang.push([W[i], W[j], v]);
    }));
    pasang.sort((a, b) => b[2] - a[2]);
    const totalPilih = pasang.reduce((a, p) => a + p[2], 0);
    pasang = pasang.slice(0, n);
    const vmax = pasang.length ? pasang[0][2] : 1;
    const tebal = +$("al-tebal").value, lengkung = +$("al-lengkung").value / 100, op = +$("al-opasitas").value / 100;
    const mode = $("al-warna").value, w1 = $("al-warna-1").value;
    [...pasang].reverse().forEach(([a, b, v]) => {
      if (!pusat[a] || !pusat[b]) return;
      const t = Math.sqrt(v / vmax);
      const warna = mode === "pulau" ? WPULAU[PL[a]] : mode === "tunggal" ? w1 : warnaSkala("merah", 0.25 + t * 0.75);
      const bs = busur(pusat[a], pusat[b], lengkung);
      const w = 1 + (tebal - 1) * t;
      L.polyline(bs.garis, { color: warna, weight: w, opacity: op, lineCap: "round" })
        .bindTooltip(`<b>${NM[a]} → ${NM[b]}</b><br>${fmt(v, 2)} T Rp (${fmt((v / dataA.total) * 100, 2)}% aliran antara)`, { sticky: true })
        .addTo(lapisBusur);
      if ($("al-panah").checked) {
        const p1 = bs.titik(0.8), p2 = bs.titik(0.86);
        const ang = Math.atan2(p2[0] - p1[0], p2[1] - p1[1]);
        const s = Math.max(0.12, Math.min(0.5, bs.jarak * 0.035)) * (0.6 + 0.6 * t);
        const ujung = bs.titik(0.88);
        const kiri = [ujung[0] - s * Math.sin(ang - 0.45), ujung[1] - s * Math.cos(ang - 0.45)];
        const kanan = [ujung[0] - s * Math.sin(ang + 0.45), ujung[1] - s * Math.cos(ang + 0.45)];
        L.polygon([ujung, kiri, kanan], { color: warna, weight: 0, fillColor: warna, fillOpacity: Math.min(1, op + 0.15), interactive: false }).addTo(lapisBusur);
      }
    });
    // simpul: besar = total aliran keluar+masuk (antarprovinsi) pada pilihan sektor
    const kel = W.map((_, i) => M[i].reduce((a, v, j) => a + (i === j ? 0 : v), 0));
    const mas = W.map((_, j) => M.reduce((a, r, i) => a + (i === j ? 0 : r[j]), 0));
    const smax = Math.max(...kel.map((v, i) => v + mas[i]), 1e-9);
    W.forEach((k, i) => {
      if (!pusat[k]) return;
      const aktif = !fokus || k === fokus || pasang.some((p) => p[0] === k || p[1] === k);
      const m = L.circleMarker(pusat[k], { radius: 3 + 11 * Math.sqrt((kel[i] + mas[i]) / smax), color: "#fff", weight: 1,
        fillColor: k === fokus ? "#c0392b" : WPULAU[PL[k]], fillOpacity: aktif ? 0.95 : 0.25 })
        .bindTooltip(`<b>${NM[k]}</b><br>keluar ${fmt(kel[i], 1)} T · masuk ${fmt(mas[i], 1)} T<br>intra ${fmt(M[i][i], 1)} T`, { sticky: true, permanent: false })
        .on("click", () => { $("al-fokus").value = $("al-fokus").value === k ? "" : k; gambarBusur(); })
        .addTo(lapisSimpul);
      if ($("al-label").checked && aktif) m.bindTooltip(NM[k], { permanent: true, direction: "right", className: "label-peta", offset: [6, 0] });
    });
    // panel samping
    const antar = dataA.total - dataA.intra;
    $("al-judul").textContent = fokus ? `Aliran ${arah === "masuk" ? "ke" : arah === "keluar" ? "dari" : "dari/ke"} ${NM[fokus]}` : "Aliran antarprovinsi terbesar";
    const sAsal = $("al-asal").value ? `sektor ${$("al-asal").value}` : "semua sektor";
    $("al-stat").innerHTML = [
      ["Aliran antara total", fmt(dataA.total, 0) + " T", `IRIO ${dataA.tabel}, ${sAsal}`],
      ["Antarprovinsi", fmt((antar / dataA.total) * 100, 1) + "%", fmt(antar, 0) + " T"],
      ["Pilihan ini", fmt(totalPilih, 0) + " T", `${pasang.length} busur ditampilkan`],
      ["Terbesar", pasang.length ? fmt(pasang[0][2], 1) + " T" : "–", pasang.length ? `${NM[pasang[0][0]]} → ${NM[pasang[0][1]]}` : ""],
    ].map(([a, b, c]) => `<div><span>${a}</span><b>${b}</b><small title="${esc(c)}">${esc(c)}</small></div>`).join("");
    $("al-daftar").innerHTML = `<ol class="peringkat">${pasang.slice(0, 25).map(([a, b, v], i) =>
      `<li class="klik" data-kode="${a}"><span class="no">${i + 1}</span><span class="nm" title="${esc(NM[a])} → ${esc(NM[b])}">${esc(NM[a])} → ${esc(NM[b])}</span><span class="br"><i style="width:${(v / vmax) * 100}%;background:${WPULAU[PL[a]]}"></i></span><span class="v">${fmt(v, 1)}</span></li>`).join("")}</ol>`;
    tabelPanas($("al-pulau"), PULAU, PULAU.map((p) => p.replace("-", "-\u200b")), pulauMatriks(M, dataA.wil), { digit: 0, diagonal: true, sudut: "asal \\ tujuan" });
  }
  $("al-daftar").addEventListener("click", (e) => { const li = e.target.closest("li[data-kode]"); if (li) { $("al-fokus").value = li.dataset.kode; gambarBusur(); } });
  ["al-asal", "al-tujuan"].forEach((id) => $(id).addEventListener("change", muatAliran));
  ["al-fokus", "al-arah", "al-n", "al-ambang", "al-warna", "al-warna-1", "al-tebal", "al-lengkung", "al-opasitas", "al-panah", "al-label"]
    .forEach((id) => $(id).addEventListener("input", gambarBusur));
  $("al-latar").addEventListener("change", latar);

  // ======================================================================= Keterkaitan
  let K = null;
  function kuadran() {
    const el = $("g-kuadran");
    if (el._grafik) el._grafik.destroy();
    const omax = Math.max(...K.output);
    const warna = K.bl.map((b, i) => (b >= 1 && K.fl[i] >= 1 ? "#c0392b" : b >= 1 ? "#e07b39" : K.fl[i] >= 1 ? "#2e6e9e" : "#7f8c8d"));
    const garis = {
      id: "garisKuadran",
      afterDatasetsDraw(ch) {
        const { ctx, chartArea: a, scales: { x, y } } = ch;
        ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = "#9aa7b4";
        ctx.beginPath(); ctx.moveTo(x.getPixelForValue(1), a.top); ctx.lineTo(x.getPixelForValue(1), a.bottom);
        ctx.moveTo(a.left, y.getPixelForValue(1)); ctx.lineTo(a.right, y.getPixelForValue(1)); ctx.stroke();
        ctx.setLineDash([]); ctx.fillStyle = "#33475b"; ctx.font = "600 11px sans-serif";
        ch.getDatasetMeta(0).data.forEach((p, i) => ctx.fillText(K.sek[i], p.x + 7, p.y - 6));
        ctx.fillStyle = "#9aa7b4"; ctx.font = "11px sans-serif";
        ctx.fillText("sektor kunci", a.right - 70, a.top + 12); ctx.fillText("dorong ke depan", a.left + 6, a.top + 12);
        ctx.fillText("tarik ke belakang", a.right - 95, a.bottom - 6); ctx.fillText("lemah", a.left + 6, a.bottom - 6);
        ctx.restore();
      },
    };
    el._grafik = new Chart(el, {
      type: "bubble",
      data: { datasets: [{ label: "Sektor", data: K.bl.map((b, i) => ({ x: b, y: K.fl[i], r: 4 + 16 * Math.sqrt(K.output[i] / omax) })),
        backgroundColor: warna.map((w) => w + "aa"), borderColor: warna }] },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false },
        tooltip: { callbacks: { label: (c) => `${K.sek[c.dataIndex]} ${NSEK[K.sek[c.dataIndex]]}: BL ${fmt(c.raw.x, 2)}, FL ${fmt(c.raw.y, 2)}, output ${fmt(K.output[c.dataIndex], 0)} T` } } },
        scales: { x: { title: { display: true, text: "Keterkaitan ke belakang (BL)" } }, y: { title: { display: true, text: "Keterkaitan ke depan (FL)" } } } },
      plugins: [garis],
    });
  }

  function pengganda() {
    const ix = K.sek.map((_, i) => i).sort((a, b) => K.pengganda_output[b] - K.pengganda_output[a]);
    const ds = [{ label: "Pengganda output", data: ix.map((i) => K.pengganda_output[i]), warna: "#2e6e9e" },
                { label: "Pengganda NTB", data: ix.map((i) => K.pengganda_ntb[i]), warna: "#2e8b57" }];
    if (K.bocoran) ds.push({ label: "Bocoran ke provinsi lain (×10)", data: ix.map((i) => K.bocoran[i] * 10), warna: "#e07b39" });
    grafik("g-pengganda", "bar", ix.map((i) => `${K.sek[i]} ${NSEK[K.sek[i]]}`.slice(0, 34)), ds, { horizontal: true, digit: 3 });
  }

  function heat() {
    const M = K[$("kt-matriks").value];
    const n = M.length, off = M.flatMap((r, i) => r.filter((_, j) => i !== j)), maks = Math.max(...off, 1e-9);
    let h = `<table class="tabel rapat" style="font-size:11.5px"><thead><tr><th>pemasok \\ pembeli</th>${K.sek.map((s) => `<th class="n" title="${esc(NSEK[s])}">${s}</th>`).join("")}<th class="n">Jumlah</th></tr></thead><tbody>`;
    M.forEach((r, i) => {
      h += `<tr><td class="label-baris" title="${esc(NSEK[K.sek[i]])}">${K.sek[i]} ${esc(NSEK[K.sek[i]].slice(0, 22))}</td>` + r.map((v, j) => {
        const t = i === j ? 0 : Math.sqrt(v / maks);
        return `<td class="n" style="background:${i === j ? "#eef1f5" : `rgba(192,57,43,${(t * 0.85).toFixed(3)})`};color:${t > 0.6 ? "#fff" : "inherit"}">${fmt(v, 3)}</td>`;
      }).join("") + `<td class="n"><b>${fmt(r.reduce((a, b) => a + b, 0), 3)}</b></td></tr>`;
    });
    const kol = K.sek.map((_, j) => M.reduce((a, r) => a + r[j], 0));
    h += `</tbody><tfoot><tr class="total"><td>Jumlah kolom</td>${kol.map((v) => `<td class="n">${fmt(v, 3)}</td>`).join("")}<td></td></tr></tfoot></table>`;
    $("kt-heat").innerHTML = h;
  }

  function jaringan() {
    const svg = $("jaringan"), A = K.A, n = A.length;
    const thr = +$("jr-ambang").value / 1000;
    $("jr-ambang-v").textContent = " " + fmt(thr, 3);
    const cx = 280, cy = 210, R = 165;
    const pos = K.sek.map((_, i) => { const a = -Math.PI / 2 + (2 * Math.PI * i) / n; return [cx + R * Math.cos(a), cy + R * Math.sin(a)]; });
    const omax = Math.max(...K.output), pmax = Math.max(...K.pengganda_output), pmin = Math.min(...K.pengganda_output);
    const warna = K.sek.map((_, i) => $("jr-warna").value === "kuadran"
      ? (K.bl[i] >= 1 && K.fl[i] >= 1 ? "#c0392b" : K.bl[i] >= 1 ? "#e07b39" : K.fl[i] >= 1 ? "#2e6e9e" : "#7f8c8d")
      : warnaSkala("seq", (K.pengganda_output[i] - pmin) / (pmax - pmin || 1) * 0.99));
    const amax = Math.max(...A.flat().filter((v, k) => Math.floor(k / n) !== k % n), 1e-9);
    const jari = K.output.map((o) => 7 + 15 * Math.sqrt(o / omax));
    let tepi = "";
    A.forEach((r, i) => r.forEach((v, j) => {
      if (v < thr || (i === j && !$("jr-diri").checked)) return;
      const w = 0.6 + 7 * Math.sqrt(v / amax);
      if (i === j) {
        const [x, y] = pos[i], dx = (x - cx) / R * 26, dy = (y - cy) / R * 26;
        tepi += `<circle cx="${x + dx}" cy="${y + dy}" r="13" fill="none" stroke="${warna[i]}" stroke-opacity=".5" stroke-width="${w}"><title>${K.sek[i]} → dirinya: A = ${fmt(v, 3)}</title></circle>`;
        return;
      }
      const [x1, y1] = pos[i], [xj, yj] = pos[j];
      const mx = (x1 + xj) / 2 + (cx - (x1 + xj) / 2) * 0.35, my = (y1 + yj) / 2 + (cy - (y1 + yj) / 2) * 0.35;
      const dl = Math.hypot(xj - mx, yj - my) || 1, x2 = xj - (xj - mx) / dl * (jari[j] + 2), y2 = yj - (yj - my) / dl * (jari[j] + 2);
      tepi += `<path d="M${x1},${y1} Q${mx},${my} ${x2},${y2}" fill="none" stroke="${warna[i]}" stroke-opacity=".45" stroke-width="${w}" marker-end="url(#panah)"><title>${K.sek[i]} → ${K.sek[j]}: A = ${fmt(v, 3)} (input ${NSEK[K.sek[i]]} per Rp output ${NSEK[K.sek[j]]})</title></path>`;
    }));
    const simpul = K.sek.map((s, i) => {
      const [x, y] = pos[i], r = jari[i];
      const lx = cx + (R + r + 14) * Math.cos(-Math.PI / 2 + (2 * Math.PI * i) / n), ly = cy + (R + r + 14) * Math.sin(-Math.PI / 2 + (2 * Math.PI * i) / n);
      return `<g><circle cx="${x}" cy="${y}" r="${r}" fill="${warna[i]}" stroke="#fff" stroke-width="1.5"><title>${s} ${NSEK[s]}\nBL ${fmt(K.bl[i], 2)} · FL ${fmt(K.fl[i], 2)}\nPengganda output ${fmt(K.pengganda_output[i], 2)}\nOutput ${fmt(K.output[i], 0)} T</title></circle>` +
        `<text x="${lx}" y="${ly + 4}" text-anchor="middle" font-size="11" font-weight="600" fill="#33475b">${s}</text></g>`;
    }).join("");
    svg.innerHTML = `<defs><marker id="panah" viewBox="0 0 10 10" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#5d6d7e"/></marker></defs>${tepi}${simpul}`;
  }

  async function tren() {
    const s = $("kt-sumber").value;
    const u = `${IO_API.tren}?metode=${$("io-metode").value}&sumber=${s === "nasional" ? "nasional" : "irio"}${s === "prov" ? "&wilayah=" + $("kt-wil").value : ""}`;
    const d = await ambil(u), uk = $("kt-tren-ukuran").value;
    grafik("g-tren", "line", d.tahun, K.sek.map((sk, i) => ({ label: sk, data: d.seri.map((t) => t[uk][i]), warna: WARNA17[i], pointRadius: 2 })),
      { digit: uk === "output" || uk === "ntb" ? 3 : 2 });
  }

  async function gambarKait() {
    const s = $("kt-sumber").value;
    $("kt-wil").disabled = s !== "prov";
    const u = `${IO_API.kait}?${q()}&sumber=${s === "nasional" ? "nasional" : "irio"}${s === "prov" ? "&wilayah=" + $("kt-wil").value : ""}`;
    try { K = await ambil(u); } catch (e) { $("kt-info").textContent = e.message; return; }
    $("kt-info").textContent = `${K.tabel}${s === "prov" ? " · keterkaitan sektor di " + NM[$("kt-wil").value] + " memakai L antarwilayah (dampak ke semua provinsi)" : ""}`;
    $("kt-catatan-pengganda").textContent = s === "prov"
      ? "Pengganda dihitung dari L antarwilayah: tambahan output di semua provinsi per Rp permintaan akhir sektor di provinsi ini. Bocoran = bagian yang jatuh di provinsi lain."
      : "Pengganda output = tambahan output seluruh ekonomi per Rp1 permintaan akhir sektor; pengganda NTB = tambahan nilai tambah.";
    kuadran(); pengganda(); heat(); jaringan(); tren();
  }
  ["kt-sumber", "kt-wil"].forEach((id) => $(id).addEventListener("change", gambarKait));
  $("kt-matriks").addEventListener("change", heat);
  $("kt-tren-ukuran").addEventListener("change", tren);
  ["jr-ambang", "jr-warna", "jr-diri"].forEach((id) => $(id).addEventListener("input", jaringan));

  // ======================================================================= Peta pengganda
  const DIGIT = { pengganda_output: 3, pengganda_ntb: 3, bocoran: 1, kemandirian: 1, bl: 2, fl: 2, ekspor_antar: 1, impor_antar: 1, neraca_antar: 1, output: 0 };
  const SKEMA = { bocoran: "merah", kemandirian: "hijau", neraca_antar: "div", pengganda_ntb: "hijau" };
  async function gambarPengganda() {
    const d = (await indikator($("pm-sek").value)).nilai, k = $("pm-ind").value;
    const opt = $("pm-ind").selectedOptions[0].text, sat = (opt.match(/\(([^)]+)\)/) || [])[1] || "";
    const skema = $("pm-skema").value || SKEMA[k] || "seq";
    petaChoropleth("peta-pengganda", d[k], { label: opt.replace(/\s*\(.*\)$/, ""), satuan: sat, skema, digit: DIGIT[k], nama: NM });
    ringkasanSebaran("ringkas-pengganda", d[k], { digit: DIGIT[k], satuan: sat === "%" ? "%" : sat === "T Rp" ? "T" : "" });
    const baris = WIL.map((w) => { const kd = String(w.kode); return { nama: w.nama, pulau: w.pulau, ...Object.fromEntries(Object.keys(d).map((x) => [x, d[x][kd]])) }; });
    const B = { bobot: "output" };
    tabelNeraca("pm-tabel", [
      { kunci: "nama", label: "Provinsi", teks: true },
      { kunci: "pengganda_output", label: "Pengganda output", digit: 3, agregat: B },
      { kunci: "pengganda_ntb", label: "Pengganda NTB", digit: 3, agregat: B },
      { kunci: "bocoran", label: "Limpahan %", digit: 1, agregat: B },
      { kunci: "neraca_antar", label: "Neraca antar (T)", digit: 0, agregat: "jumlah" },
      { kunci: "output", label: "Output (T)", digit: 0, agregat: "jumlah" },
    ], baris, { grup: "pulau", rapat: true, lipat: true, total: "Indonesia" });
  }
  ["pm-ind", "pm-sek", "pm-skema"].forEach((id) => $(id).addEventListener("change", gambarPengganda));

  // ======================================================================= Dampak skenario
  let D = null, dpCatatan = "";
  async function gambarDampak() {
    const th = $("dp-th").value;
    const u = `${IO_API.dampak}?${q()}&skenario=${$("dp-sk").value}&sumber=${$("dp-sumber").value}${th ? "&th=" + th : ""}`;
    try { D = await ambil(u); } catch (e) { $("dp-kpi").innerHTML = `<div class="kartu sorot" style="grid-column:1/-1">${esc(e.message)}</div>`; return; }
    if (!D.ringkasan.investasi && $("dp-sumber").value === "a2") {
      $("dp-sumber").value = "a1a2"; dpCatatan = `${D.skenario} tidak menambah investasi di atas tren (investasi tambahan = 0); ditampilkan investasi dasar + tambahan.`;
      return gambarDampak();
    }
    const pil = $("dp-th"), simpan = pil.value;
    pil.innerHTML = '<option value="">Kumulatif ' + (D.tahun_ada.length ? `${D.tahun_ada[0]}–${D.tahun_ada[D.tahun_ada.length - 1]}` : "") + "</option>" + D.tahun_ada.map((t) => `<option>${t}</option>`).join("");
    pil.value = simpan;
    const r = D.ringkasan, T = (v) => v / 1000;
    $("dp-kpi").innerHTML = [
      ["Investasi dialirkan", fmt(T(r.investasi), 0) + " T", dpCatatan || `${D.skenario} · IRIO ${D.tabel}`],
      ["ΔOutput", fmt(T(r.d_output), 0) + " T", `pengganda ${fmt(r.pengganda_output, 2)} per Rp`],
      ["ΔNTB (PDRB)", fmt(T(r.d_ntb), 0) + " T", `${fmt(r.pct_ntb_nasional, 1)}% NTB nasional tabel`],
      ["Pengganda NTB", fmt(r.pengganda_ntb, 3), `bocoran impor luar negeri ${fmt(r.bocoran_impor_pct, 1)}%`],
      ["Limpahan antarprovinsi", fmt(r.limpahan_pct, 1) + "%", "bagian ΔNTB yang jatuh di luar provinsi investasi"],
    ].map(([a, b, c]) => `<div class="kpi"><div class="label">${a}</div><div class="nilai">${b}</div><div class="ket">${esc(c)}</div></div>`).join("");
    petaDampak();
    // per sektor, ditumpuk menurut pulau penerima
    const ip = D.wil.map((k) => PULAU.indexOf(PL[String(k)]));
    const perSek = D.sek.map((_, s) => D.d_ntb.reduce((a, row) => a + row[s], 0));
    const ix = D.sek.map((_, i) => i).sort((a, b) => perSek[b] - perSek[a]);
    grafik("g-dampak-sek", "bar", ix.map((i) => `${D.sek[i]} ${NSEK[D.sek[i]]}`.slice(0, 32)), PULAU.map((p, pi) => ({
      label: p, warna: WPULAU[p], data: ix.map((s) => D.d_ntb.reduce((a, row, r) => a + (ip[r] === pi ? row[s] : 0), 0) / 1000),
    })), { horizontal: true, tumpuk: true, digit: 1, satuan: "T" });
    // pulau asal × penerima: matriks_ntb[penerima][asal] -> transpos
    const Mt = D.wil.map((_, a) => D.wil.map((__, p) => D.matriks_ntb[p][a] / 1000));
    tabelPanas($("dp-pulau"), PULAU, PULAU, pulauMatriks(Mt, D.wil), { digit: 0, diagonal: true, sudut: "asal \\ penerima" });
    // tabel provinsi
    const baris = D.wil.map((k, i) => ({
      nama: D.nama[i], pulau: D.pulau[i], inv: D.investasi[i] / 1000, dom: D.permintaan_domestik[i] / 1000,
      dipicu: D.ntb_dipicu[i] / 1000, sendiri: D.ntb_sendiri[i] / 1000, limpahan: D.limpahan_pct[i],
      diterima: D.ntb_diterima[i] / 1000, bersih: (D.ntb_diterima[i] - D.ntb_dipicu[i]) / 1000, pct: D.pct_ntb[i],
      output: D.d_output[i].reduce((a, b) => a + b, 0) / 1000,
    }));
    const kolom = [
      { kunci: "nama", label: "Provinsi", teks: true },
      { kunci: "inv", label: "Investasi (T)", digit: 1, agregat: "jumlah" },
      { kunci: "dom", label: "Permintaan domestik (T)", digit: 1, agregat: "jumlah" },
      { kunci: "dipicu", label: "ΔNTB dipicu (T)", digit: 1, agregat: "jumlah" },
      { kunci: "sendiri", label: "… di provinsi sendiri (T)", digit: 1, agregat: "jumlah" },
      { kunci: "limpahan", label: "Limpahan %", digit: 1, agregat: { bobot: "dipicu" } },
      { kunci: "diterima", label: "ΔNTB diterima (T)", digit: 1, agregat: "jumlah" },
      { kunci: "bersih", label: "Diterima − dipicu (T)", digit: 1, agregat: "jumlah" },
      { kunci: "pct", label: "% NTB provinsi", digit: 2, agregat: "rata" },
      { kunci: "output", label: "ΔOutput diterima (T)", digit: 1, agregat: "jumlah" },
    ];
    tabelNeraca("dp-tabel", kolom, baris, { grup: "pulau", rapat: true, lipat: true, total: "Indonesia" });
    $("dp-csv").onclick = () => unduhCSV(`dampak_io_${D.skenario}.csv`, kolom.map((k) => k.label), baris.map((b) => kolom.map((k) => b[k.kunci])));
  }
  function petaDampak() {
    if (!D) return;
    const k = $("dp-peta").value, nilai = {};
    D.wil.forEach((w, i) => {
      const v = k === "bersih" ? (D.ntb_diterima[i] - D.ntb_dipicu[i]) / 1000 : k === "pct_ntb" || k === "limpahan_pct" ? D[k][i] : D[k][i] / 1000;
      nilai[String(w)] = v;
    });
    const sat = k === "pct_ntb" || k === "limpahan_pct" ? "%" : "T Rp";
    petaChoropleth("peta-dampak", nilai, { label: $("dp-peta").selectedOptions[0].text.replace(/\s*\(.*\)$/, ""), satuan: sat,
      skema: k === "bersih" ? "div" : k === "limpahan_pct" ? "merah" : "hijau", digit: k === "pct_ntb" ? 2 : 1, nama: NM });
    ringkasanSebaran("ringkas-dampak", nilai, { digit: k === "pct_ntb" ? 2 : 1, satuan: sat === "%" ? "%" : "T" });
  }
  ["dp-sk", "dp-sumber", "dp-th"].forEach((id) => $(id).addEventListener("change", () => { dpCatatan = ""; gambarDampak(); }));
  $("dp-peta").addEventListener("change", petaDampak);

  // ======================================================================= tab & pemilih bersama
  const GAMBAR = { "io-aliran": async () => { await siapkanPeta(); await muatAliran(); await latar(); }, "io-kait": gambarKait, "io-peta": gambarPengganda, "io-dampak": gambarDampak };
  const kotor = new Set(Object.keys(GAMBAR));
  const aktifTab = () => document.querySelector('.panel-tab.aktif[data-grup="io"]').id;
  async function segarkan() {
    const t = aktifTab();
    if (kotor.has(t) && GAMBAR[t]) { kotor.delete(t); try { await GAMBAR[t](); } catch (e) { console.error(e); } }
  }
  ["io-tahun", "io-metode"].forEach((id) => $(id).addEventListener("change", () => { Object.keys(GAMBAR).forEach((k) => kotor.add(k)); segarkan(); }));
  document.querySelector('.tab[data-grup="io"]').addEventListener("click", () => setTimeout(segarkan, 30));
  window.addEventListener("load", () => setTimeout(segarkan, 50));
})();
