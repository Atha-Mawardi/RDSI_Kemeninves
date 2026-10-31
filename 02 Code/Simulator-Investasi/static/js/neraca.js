/* Tabel bergaya neraca: tajuk biru tua, baris kelompok, subtotal, total bergaris ganda. */
(function () {
  const fmt = (v, d) => window.fmtID(v, d);
  const ada = (x) => x !== null && x !== undefined && x !== "" && !Number.isNaN(x);
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  /* Agregasi satu kolom atas baris objek. agregat: "jumlah" | "rata" | "min" | "maks" | "hitung" | {bobot: kunci} */
  function agregasi(rows, kunci, agregat) {
    if (!agregat) return null;
    if (agregat === "hitung") return rows.length;
    const pasang = rows.map((r) => [r[kunci], agregat.bobot ? r[agregat.bobot] : 1]).filter(([v, w]) => ada(v) && ada(w));
    if (!pasang.length) return null;
    const v = pasang.map((p) => +p[0]);
    if (agregat === "jumlah") return v.reduce((a, b) => a + b, 0);
    if (agregat === "rata") return v.reduce((a, b) => a + b, 0) / v.length;
    if (agregat === "min") return Math.min(...v);
    if (agregat === "maks") return Math.max(...v);
    if (agregat === "median") { const s = [...v].sort((a, b) => a - b), n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; }
    if (agregat.bobot) {
      const w = pasang.reduce((a, p) => a + +p[1], 0);
      return w ? pasang.reduce((a, p) => a + p[0] * p[1], 0) / w : null;
    }
    return null;
  }
  window.agregasi = agregasi;

  /* kolom: [{kunci, label, digit, agregat, teks, kelas}]; baris: [{...}]
     opsi: {grup: kunci|fn, labelGrup: fn(nilai), subtotal: true, total: "Total", lipat: false, labelSubtotal: fn} */
  window.tabelNeraca = function (el, kolom, baris, opsi = {}) {
    el = typeof el === "string" ? document.getElementById(el) : el;
    const sel = (k, v, kelas = "") => {
      if (k.teks) return `<td class="${kelas}">${esc(v)}</td>`;
      const neg = ada(v) && v < 0 ? " negatif" : "";
      return `<td class="n${neg} ${kelas}" data-v="${ada(v) ? v : ""}">${ada(v) ? fmt(v, k.digit ?? 1) : "–"}</td>`;
    };
    const barisAgg = (rows, label, kelas) => `<tr class="${kelas}">` + kolom.map((k, j) =>
      j === 0 ? `<td>${esc(label)}</td>` : k.teks ? "<td></td>" : sel(k, agregasi(rows, k.kunci, k.agregat))).join("") + "</tr>";
    let html = `<table class="tabel neraca${opsi.rapat ? " rapat" : ""}"><thead><tr>` +
      kolom.map((k) => `<th class="${k.teks ? "" : "n"}" title="${esc(k.ket || "")}">${esc(k.label)}</th>`).join("") + "</tr></thead><tbody>";
    const fGrup = typeof opsi.grup === "function" ? opsi.grup : opsi.grup ? (r) => r[opsi.grup] : null;
    if (fGrup) {
      const peta = new Map();
      baris.forEach((r) => { const g = fGrup(r); if (!peta.has(g)) peta.set(g, []); peta.get(g).push(r); });
      let gi = 0;
      for (const [g, rows] of peta) {
        const lbl = opsi.labelGrup ? opsi.labelGrup(g, rows) : g;
        html += `<tr class="grup" data-gi="${gi}"${opsi.lipat ? ' style="cursor:pointer"' : ""}><td colspan="${kolom.length}">${opsi.lipat ? '<span class="lipat">▾</span> ' : ""}${esc(lbl)} <span class="kecil abu" style="font-weight:400">(${rows.length})</span></td></tr>`;
        rows.forEach((r) => {
          html += `<tr data-anggota="${gi}">` + kolom.map((k, j) => sel(k, r[k.kunci], j === 0 ? "inden" : "")).join("") + "</tr>";
        });
        if (opsi.subtotal !== false) html += barisAgg(rows, opsi.labelSubtotal ? opsi.labelSubtotal(g) : `Jumlah ${lbl}`, "subtotal").replace('<tr class="subtotal">', `<tr class="subtotal" data-anggota="${gi}">`);
        gi++;
      }
    } else {
      baris.forEach((r) => { html += "<tr>" + kolom.map((k) => sel(k, r[k.kunci])).join("") + "</tr>"; });
    }
    html += "</tbody>";
    if (opsi.total !== false && baris.length) html += "<tfoot>" + barisAgg(baris, opsi.total || "Total", "total") + "</tfoot>";
    html += "</table>";
    el.innerHTML = html;
    if (opsi.lipat) {
      el.querySelectorAll("tr.grup").forEach((tr) => tr.addEventListener("click", () => {
        const tutup = tr.querySelector(".lipat").textContent === "▾";
        tr.querySelector(".lipat").textContent = tutup ? "▸" : "▾";
        el.querySelectorAll(`tr[data-anggota="${tr.dataset.gi}"]`).forEach((x) => { x.hidden = tutup; });
      }));
    }
    return el.querySelector("table");
  };

  /* Unduh CSV (pemisah koma, UTF-8 BOM agar terbaca Excel). */
  window.unduhCSV = function (nama, header, rows) {
    const q = (v) => { const s = v === null || v === undefined ? "" : String(v); return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
    const isi = "\ufeff" + [header, ...rows].map((r) => r.map(q).join(",")).join("\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([isi], { type: "text/csv;charset=utf-8" }));
    a.download = nama;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };

  /* Tabel server: <table data-kelompok="indeks kolom"> dengan th[data-agregat] -> tombol kelompok + subtotal + total. */
  window.kelompokkanTabel = function (tabel) {
    const iG = +tabel.dataset.kelompok;
    const th = Array.from(tabel.tHead.rows[0].cells);
    const agg = th.map((h) => {
      const a = h.dataset.agregat;
      if (!a) return null;
      return a.startsWith("bobot:") ? { bobot: +a.slice(6) } : a;
    });
    const tbody = tabel.tBodies[0];
    const nilai = (tr, i) => { const c = tr.cells[i]; const v = c && c.dataset.v; return v === undefined || v === "" ? null : parseFloat(v); };
    const hapus = () => tabel.querySelectorAll("tr.grup, tr.subtotal, tfoot").forEach((x) => x.remove());
    const baris = () => Array.from(tbody.rows).filter((r) => !r.classList.contains("grup") && !r.classList.contains("subtotal"));
    const aggRow = (rows, label, kelas) => {
      const tr = document.createElement("tr");
      tr.className = kelas;
      th.forEach((h, i) => {
        const td = document.createElement("td");
        if (i === 0) td.textContent = label;
        else if (agg[i]) {
          const objs = rows.map((r) => ({ v: nilai(r, i), w: agg[i].bobot !== undefined ? nilai(r, agg[i].bobot) : 1 }));
          const v = agregasi(objs, "v", agg[i].bobot !== undefined ? { bobot: "w" } : agg[i]);
          const d = +(h.dataset.digit ?? 1);
          td.className = "n" + (v !== null && v < 0 ? " negatif" : "");
          td.dataset.v = v ?? "";
          td.textContent = fmt(v, d);
        }
        tr.appendChild(td);
      });
      return tr;
    };
    const total = () => {
      const tf = document.createElement("tfoot");
      tf.appendChild(aggRow(baris(), "Total", "total"));
      tabel.appendChild(tf);
    };
    const kelompok = () => {
      hapus();
      const rows = baris();
      const peta = new Map();
      rows.forEach((r) => { const g = r.cells[iG].innerText.trim(); if (!peta.has(g)) peta.set(g, []); peta.get(g).push(r); });
      for (const [g, rs] of peta) {
        const kepala = document.createElement("tr");
        kepala.className = "grup";
        kepala.innerHTML = `<td colspan="${th.length}">${esc(g)} <span class="kecil abu" style="font-weight:400">(${rs.length})</span></td>`;
        tbody.appendChild(kepala);
        rs.forEach((r) => { r.cells[0].classList.add("inden"); tbody.appendChild(r); });
        tbody.appendChild(aggRow(rs, `Jumlah ${g}`, "subtotal"));
      }
      total();
    };
    const lepas = () => { hapus(); baris().forEach((r) => r.cells[0].classList.remove("inden")); total(); };
    const saklar = document.createElement("label");
    saklar.className = "kecil abu";
    saklar.style.cssText = "display:inline-flex;gap:6px;align-items:center;font-weight:400;margin:0 0 6px";
    saklar.innerHTML = `<input type="checkbox" checked> Kelompokkan menurut ${esc(th[iG].innerText.toLowerCase())} dengan subtotal`;
    const wadah = tabel.closest(".gulir") || tabel;
    wadah.parentNode.insertBefore(saklar, wadah);
    const cb = saklar.querySelector("input");
    cb.addEventListener("change", () => (cb.checked ? kelompok() : lepas()));
    tabel.addEventListener("click", (e) => { if (e.target.closest("th") && cb.checked) { cb.checked = false; lepas(); } }, true);
    kelompok();
  };
  document.addEventListener("DOMContentLoaded", () => document.querySelectorAll("table[data-kelompok]").forEach(kelompokkanTabel));
})();
