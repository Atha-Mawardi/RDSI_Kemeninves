/* Peta choropleth (Leaflet tanpa ubin daring) dan grafik (Chart.js). */
(function () {
  const fmt = (v, d = 1) =>
    v === null || v === undefined || Number.isNaN(v)
      ? "–"
      : Number(v).toLocaleString("id-ID", { minimumFractionDigits: d, maximumFractionDigits: d });
  window.fmtID = fmt;

  const SKALA = {
    seq: ["#eff3ff", "#c6dbef", "#9ecae1", "#6baed6", "#3182bd", "#08519c"],
    hijau: ["#f7fcf5", "#c7e9c0", "#a1d99b", "#74c476", "#31a354", "#006d2c"],
    merah: ["#fff5eb", "#fdd0a2", "#fdae6b", "#fd8d3c", "#e6550d", "#a63603"],
    div: ["#b2182b", "#ef8a62", "#fddbc7", "#d1e5f0", "#67a9cf", "#2166ac"],
    peluang: ["#d73027", "#fc8d59", "#fee08b", "#d9ef8b", "#91cf60", "#1a9850"],
  };
  window.SKALA = SKALA;

  const geoCache = {};
  async function ambilGeo(url) {
    if (!geoCache[url]) geoCache[url] = fetch(url).then((r) => r.json());
    return geoCache[url];
  }
  // nilai berkunci kode provinsi pemekaran Papua -> pakai batas 38 provinsi
  const KODE_PEMEKARAN = ["92", "95", "96", "97"];
  const urlGeo = (nilai, opsi) =>
    opsi.geo || (KODE_PEMEKARAN.some((k) => k in nilai) ? window.GEO38_URL : window.GEO_URL);

  function batas(nilai, skema, opsi) {
    const v = Object.values(nilai).filter((x) => x !== null && !Number.isNaN(x)).sort((a, b) => a - b);
    if (!v.length) return [];
    if (opsi.batas) return opsi.batas;
    if (skema === "div") {
      const m = Math.max(Math.abs(v[0]), Math.abs(v[v.length - 1])) || 1;
      return [-m * 0.6, -m * 0.25, 0, m * 0.25, m * 0.6];
    }
    const q = (p) => v[Math.min(v.length - 1, Math.floor(p * v.length))];
    return [q(1 / 6), q(2 / 6), q(3 / 6), q(4 / 6), q(5 / 6)];
  }

  window.petaChoropleth = async function (elId, nilai, opsi = {}) {
    const el = document.getElementById(elId);
    if (!el) return null;
    if (el._peta) { el._peta.remove(); }
    const geo = await ambilGeo(urlGeo(nilai, opsi));
    const skema = opsi.skema || "seq";
    const warna = SKALA[skema];
    const b = batas(nilai, skema, opsi);
    const d = opsi.digit ?? 1;
    const warnaDari = (x) => {
      if (x === null || x === undefined || Number.isNaN(x)) return "#d9d9d9";
      let i = 0;
      while (i < b.length && x > b[i]) i++;
      return warna[i];
    };
    const peta = L.map(el, { zoomSnap: 0.25, attributionControl: false, scrollWheelZoom: false });
    el._peta = peta;
    const lapis = L.geoJSON(geo, {
      style: (f) => ({ fillColor: warnaDari(nilai[f.properties.kode]), weight: 0.7, color: "#fff", fillOpacity: 0.92 }),
      onEachFeature: (f, layer) => {
        const k = String(f.properties.kode);
        const nama = (opsi.nama || window.NAMA_PROV || {})[k] || k;
        layer.bindTooltip(`<b>${nama}</b><br>${opsi.label || ""}: ${fmt(nilai[k], d)} ${opsi.satuan || ""}`, { sticky: true });
        layer.on("mouseover", () => layer.setStyle({ weight: 2, color: "#1f3b57" }));
        layer.on("mouseout", () => layer.setStyle({ weight: 0.7, color: "#fff" }));
        if (opsi.onClick) layer.on("click", () => opsi.onClick(k));
      },
    }).addTo(peta);
    peta.fitBounds(lapis.getBounds(), { padding: [6, 6] });
    // kartu bisa memanjang mengikuti tetangganya di grid; peta menyesuaikan ukuran wadah
    if (el._ro) el._ro.disconnect();
    let ukuran = [el.clientWidth, el.clientHeight];
    el._ro = new ResizeObserver(() => {
      if (!el.clientWidth || (el.clientWidth === ukuran[0] && el.clientHeight === ukuran[1])) return;
      ukuran = [el.clientWidth, el.clientHeight];
      peta.invalidateSize();
      peta.fitBounds(lapis.getBounds(), { padding: [6, 6] });
    });
    el._ro.observe(el);
    const leg = L.control({ position: "bottomleft" });
    leg.onAdd = () => {
      const div = L.DomUtil.create("div", "legenda-peta");
      let html = `<b>${opsi.label || ""}</b>${opsi.satuan ? " (" + opsi.satuan + ")" : ""}<br>`;
      const tepi = [-Infinity, ...b, Infinity];
      for (let i = 0; i < warna.length && i < tepi.length - 1; i++) {
        const lo = tepi[i] === -Infinity ? "≤" : fmt(tepi[i], d);
        const hi = tepi[i + 1] === Infinity ? "+" : fmt(tepi[i + 1], d);
        html += `<i style="background:${warna[i]}"></i>${tepi[i] === -Infinity ? "≤ " + hi : tepi[i + 1] === Infinity ? "> " + lo : lo + " – " + hi}<br>`;
      }
      div.innerHTML = html;
      return div;
    };
    leg.addTo(peta);
    return peta;
  };

  const PALET = ["#1f3b57", "#e07b39", "#2e8b57", "#8e44ad", "#c0392b", "#2e6e9e", "#7f8c8d", "#d4ac0d"];
  window.PALET = PALET;

  window.grafik = function (elId, tipe, labels, datasets, opsi = {}) {
    const el = document.getElementById(elId);
    if (!el) return null;
    if (el._grafik) el._grafik.destroy();
    datasets.forEach((ds, i) => {
      const w = ds.warna || PALET[i % PALET.length];
      const garis = (ds.type || tipe) === "line";
      ds.borderColor = ds.borderColor || w;
      ds.backgroundColor = ds.backgroundColor || (garis && !ds.fill ? w : w + (garis ? "33" : "cc"));
      ds.borderWidth = ds.borderWidth ?? (garis ? 2 : 0);
      ds.pointRadius = ds.pointRadius ?? (garis ? 2.5 : 0);
      ds.tension = ds.tension ?? 0.15;
    });
    const d = opsi.digit ?? 1;
    const digitTick = (ticks) => {
      if (opsi.digitSumbu !== undefined) return opsi.digitSumbu;
      const step = ticks.length > 1 ? Math.abs(ticks[1].value - ticks[0].value) : 1;
      return step >= 1 ? 0 : step >= 0.1 ? 1 : 2;
    };
    const sumbuNilai = { stacked: !!opsi.tumpuk, ticks: { callback: (v, i, ticks) => fmt(v, digitTick(ticks)) } };
    const sumbuKategori = { stacked: !!opsi.tumpuk, grid: { display: false },
                            ticks: opsi.horizontal ? { autoSkip: false, font: { size: 11 } } : {} };
    const [sx, sy] = opsi.horizontal ? [sumbuNilai, sumbuKategori] : [sumbuKategori, sumbuNilai];
    el._grafik = new Chart(el, {
      type: tipe,
      data: { labels, datasets },
      options: {
        responsive: true, maintainAspectRatio: false, indexAxis: opsi.horizontal ? "y" : "x",
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: opsi.legenda ?? true, position: "bottom",
                    labels: { boxWidth: 12, font: { size: 11.5 }, filter: (item, data) => !data.datasets[item.datasetIndex].tanpaLegenda } },
          tooltip: { callbacks: { label: (c) => `${c.dataset.label}: ${fmt(c.parsed[opsi.horizontal ? "x" : "y"], d)} ${opsi.satuan || ""}` } },
          title: opsi.judul ? { display: true, text: opsi.judul, font: { size: 13 } } : undefined,
        },
        scales: {
          x: { ...sx, title: { display: !!opsi.judulX, text: opsi.judulX } },
          y: { ...sy, title: { display: !!opsi.judulY, text: opsi.judulY } },
          ...(opsi.sumbuKanan ? { y2: { position: "right", min: opsi.sumbuKanan.min, max: opsi.sumbuKanan.max,
                                        grid: { display: false }, title: { display: true, text: opsi.sumbuKanan.judul } } } : {}),
        },
      },
    });
    return el._grafik;
  };

  /* Ringkasan sebaran satu indikator: ubin statistik + peringkat atas dan bawah. Dipasang di bawah peta. */
  window.ringkasanSebaran = function (elId, nilai, opsi = {}) {
    const el = document.getElementById(elId);
    if (!el) return;
    const nama = opsi.nama || window.NAMA_PROV || {};
    const d = opsi.digit ?? 1;
    const sat = opsi.satuan ? ` <small class="sat">${opsi.satuan}</small>` : "";
    const isi = Object.entries(nilai || {})
      .filter(([, v]) => v !== null && v !== undefined && !Number.isNaN(v))
      .sort((a, b) => b[1] - a[1]);
    if (!isi.length) { el.innerHTML = '<p class="kecil abu">Tidak ada nilai untuk indikator ini.</p>'; return; }
    const v = isi.map(([, x]) => x), n = v.length;
    const rata = v.reduce((a, b) => a + b, 0) / n;
    const med = n % 2 ? v[(n - 1) / 2] : (v[n / 2 - 1] + v[n / 2]) / 2;
    const sd = Math.sqrt(v.reduce((a, b) => a + (b - rata) ** 2, 0) / Math.max(n - 1, 1));
    const k = Math.min(opsi.k ?? 5, Math.floor(n / 2));
    const skala = Math.max(...v.map(Math.abs)) || 1;
    const nm = (kd) => nama[kd] || kd;
    const daftar = (arr, mulai) => arr.map(([kd, x], i) =>
      `<li data-kode="${kd}"${opsi.onClick ? ' class="klik"' : ""}><span class="no">${mulai + i}</span>` +
      `<span class="nm" title="${nm(kd)}">${nm(kd)}</span>` +
      `<span class="br"><i class="${x < 0 ? "neg" : ""}" style="width:${(Math.abs(x) / skala) * 100}%"></i></span>` +
      `<span class="v">${fmt(x, d)}</span></li>`).join("");
    const kedua = opsi.agregat && opsi.agregat[1] !== null && opsi.agregat[1] !== undefined
      ? [opsi.agregat[0], fmt(opsi.agregat[1], d) + sat, opsi.agregat[2] || ""]
      : ["Simpangan baku", fmt(sd, d), rata ? `koefisien variasi ${fmt(Math.abs(sd / rata) * 100, 0)}%` : ""];
    const ubin = [
      ["Rata-rata provinsi", fmt(rata, d) + sat, `median ${fmt(med, d)} · ${n} provinsi`],
      kedua,
      ["Tertinggi", fmt(v[0], d) + sat, nm(isi[0][0])],
      ["Terendah", fmt(v[n - 1], d) + sat, nm(isi[n - 1][0])],
    ];
    el.innerHTML =
      `<div class="ringkas-stat">${ubin.map(([a, b, c]) => `<div><span>${a}</span><b>${b}</b><small>${c}</small></div>`).join("")}</div>` +
      `<div class="ringkas-dua"><div><h4>${k} tertinggi</h4><ol class="peringkat">${daftar(isi.slice(0, k), 1)}</ol></div>` +
      `<div><h4>${k} terendah</h4><ol class="peringkat">${daftar(isi.slice(n - k), n - k + 1)}</ol></div></div>`;
    el.onclick = opsi.onClick ? (e) => { const li = e.target.closest("li[data-kode]"); if (li) opsi.onClick(li.dataset.kode); } : null;
  };

  document.addEventListener("click", (e) => {
    const t = e.target.closest("[data-tab]");
    if (!t) return;
    const grup = t.closest(".tab").dataset.grup;
    document.querySelectorAll(`.tab[data-grup="${grup}"] button`).forEach((b) => b.classList.toggle("aktif", b === t));
    document.querySelectorAll(`.panel-tab[data-grup="${grup}"]`).forEach((p) => p.classList.toggle("aktif", p.id === t.dataset.tab));
    const panel = document.getElementById(t.dataset.tab);
    panel.querySelectorAll(".peta").forEach((m) => m._peta && m._peta.invalidateSize());
    window.dispatchEvent(new Event("resize"));
  });

  window.urutkanTabel = function (tabel) {
    tabel.querySelectorAll("th").forEach((th, i) => {
      th.style.cursor = "pointer";
      th.title = "Klik untuk mengurutkan";
      th.addEventListener("click", () => {
        const tbody = tabel.tBodies[0];
        const baris = Array.from(tbody.rows);
        const naik = th.dataset.arah !== "naik";
        th.dataset.arah = naik ? "naik" : "turun";
        const nilai = (r) => {
          const dv = r.cells[i].dataset.v;
          const t = dv ?? r.cells[i].innerText;
          const n = dv !== undefined && dv !== ""
            ? parseFloat(dv.replace(",", "."))
            : parseFloat(String(t).replace(/\./g, "").replace(",", "."));
          return Number.isNaN(n) ? t : n;
        };
        baris.sort((a, b) => {
          const x = nilai(a), y = nilai(b);
          return (x > y ? 1 : x < y ? -1 : 0) * (naik ? 1 : -1);
        });
        baris.forEach((r) => tbody.appendChild(r));
      });
    });
  };
  document.addEventListener("DOMContentLoaded", () => document.querySelectorAll("table.urut").forEach(urutkanTabel));
  // tautan langsung ke tab: halaman#id-panel membuka tab itu
  window.addEventListener("load", () => {
    const b = location.hash && document.querySelector(`[data-tab="${CSS.escape(location.hash.slice(1))}"]`);
    if (b) b.click();
  });
})();
