/* Penyunting grid data panel: edit banyak sel, tempel dari Excel, tambah tahun, simpan sebagai versi baru. */
(function () {
  const $ = (id) => document.getElementById(id);
  const esc = (s) =>
    String(s ?? '').replace(
      /[&<>"]/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c],
    );
  const ada = (x) => x !== null && x !== undefined && !Number.isNaN(x);
  let D = null,
    P = [],
    VAR = {},
    TAHUN = [];
  const ubah = new Map(); // "kode|tahun|var" -> nilai baru (null = kosong)

  const digitVar = (v) =>
    VAR[v]?.satuan === 'jiwa' ? 0 : VAR[v]?.satuan === 'miliar Rp' ? 2 : 4;
  const tampil = (x, v) =>
    ada(x)
      ? Number(x).toLocaleString('id-ID', {
          minimumFractionDigits: digitVar(v),
          maximumFractionDigits: digitVar(v),
        })
      : '';
  function urai(teks) {
    let s = String(teks).trim().replace(/\s|Rp/g, '');
    if (s === '' || s === '-' || s === '–') return null;
    const titik = s.lastIndexOf('.'),
      koma = s.lastIndexOf(',');
    if (titik >= 0 && koma >= 0)
      s =
        titik > koma
          ? s.replace(/,/g, '')
          : s.replace(/\./g, '').replace(',', '.');
    else if (koma >= 0)
      s = s.match(/,/g).length > 1 ? s.replace(/,/g, '') : s.replace(',', '.');
    else if ((s.match(/\./g) || []).length > 1) s = s.replace(/\./g, '');
    const v = Number(s);
    return Number.isFinite(v) ? v : NaN;
  }

  function asli(kode, tahun, v) {
    const i = P.findIndex((p) => p.kode === kode),
      j = D.tahun.indexOf(tahun);
    if (i < 0 || j < 0 || !D.nilai[v]) return null;
    return D.nilai[v][i][j];
  }
  const kunci = (k, t, v) => `${k}|${t}|${v}`;
  function nilai(k, t, v) {
    const c = kunci(k, t, v);
    return ubah.has(c) ? ubah.get(c) : asli(k, t, v);
  }
  function kelasCatatan(k, t, v) {
    if (ubah.has(kunci(k, t, v))) return 'sel-ubah';
    const c = (D.catatan[`${k}-${t}`] || {})[v] || '';
    return c.includes('imputasi')
      ? 'sel-imputasi'
      : c.includes('lonjakan')
        ? 'sel-lonjakan'
        : c.includes('disunting')
          ? 'sel-disunting'
          : c
            ? 'sel-diperbarui'
            : '';
  }
  function judulSel(k, t, v) {
    const c = (D.catatan[`${k}-${t}`] || {})[v] || '';
    const x = nilai(k, t, v),
      p = nilai(k, t - 1, v),
      a = asli(k, t, v);
    const bag = [
      `${P.find((q) => q.kode === k).nama} ${t} · ${VAR[v].label} (${VAR[v].satuan})`,
    ];
    if (ada(x) && ada(p) && p)
      bag.push(`Δ vs ${t - 1}: ${((x / p - 1) * 100).toFixed(1)}%`);
    if (ubah.has(kunci(k, t, v)))
      bag.push(`asli: ${ada(a) ? tampil(a, v) : 'kosong'}`);
    if (c) bag.push(c);
    return bag.join('\n');
  }

  /* ------------------------------------------------------------------ gambar grid */
  function kolom() {
    const mode = $('g-mode').value;
    if (mode === 'var')
      return TAHUN.map((t) => ({ t, v: $('g-var').value, label: String(t) }));
    const g = $('g-grup').value,
      t = +$('g-tahun').value;
    return D.variabel
      .filter((v) => !g || v.grup === g)
      .map((v) => ({ t, v: v.kode, label: v.kode, title: v.label }));
  }
  function gambar() {
    const mode = $('g-mode').value;
    document
      .querySelectorAll('[data-mode]')
      .forEach((el) => (el.hidden = el.dataset.mode !== mode));
    const K = kolom();
    const aditif =
      mode === 'var' &&
      ['miliar Rp', 'jiwa'].includes(VAR[$('g-var').value]?.satuan);
    let h = `<table class="tabel g-tabel"><thead><tr><th class="g-sudut">Provinsi</th>${K.map((c) => `<th class="n${D.tahun.includes(c.t) ? '' : ' g-baru'}" title="${esc(c.title || '')}">${esc(c.label)}</th>`).join('')}</tr></thead><tbody>`;
    let r = 0;
    D.pulau.forEach((pl) => {
      const isi = P.filter((p) => p.pulau === pl);
      h += `<tr class="grup"><td>${esc(pl)}</td><td colspan="${K.length}"></td></tr>`;
      isi.forEach((p) => {
        h +=
          `<tr><td class="g-prov">${esc(p.nama)}</td>` +
          K.map((c, j) => {
            const x = nilai(p.kode, c.t, c.v);
            return `<td class="g-sel ${kelasCatatan(p.kode, c.t, c.v)}" title="${esc(judulSel(p.kode, c.t, c.v))}"><input data-r="${r}" data-c="${j}" data-k="${p.kode}" data-t="${c.t}" data-v="${c.v}" value="${esc(tampil(x, c.v))}" inputmode="decimal"></td>`;
          }).join('') +
          '</tr>';
        r++;
      });
    });
    h += '</tbody>';
    if (aditif)
      h += `<tfoot><tr class="total"><td>Jumlah ${P.length} provinsi</td>${K.map((c) => `<td class="n" data-jumlah="${c.t}"></td>`).join('')}</tr></tfoot>`;
    h += '</table>';
    $('g-wadah').innerHTML = h;
    $('g-judul').textContent =
      mode === 'var'
        ? `${VAR[$('g-var').value].label} (${VAR[$('g-var').value].satuan})`
        : `Tahun ${$('g-tahun').value}${$('g-grup').value ? ' · ' + $('g-grup').value : ''}`;
    $('g-info').textContent = `${P.length} provinsi × ${K.length} kolom`;
    jumlahKolom();
    pasang();
  }
  function jumlahKolom() {
    document.querySelectorAll('[data-jumlah]').forEach((td) => {
      const t = +td.dataset.jumlah,
        v = $('g-var').value;
      const xs = P.map((p) => nilai(p.kode, t, v));
      const n = xs.filter(ada).length;
      td.textContent = n
        ? tampil(
            xs.filter(ada).reduce((a, b) => a + b, 0),
            v,
          ) + (n < P.length ? ` (${n})` : '')
        : '';
    });
  }

  function setSel(inp, v, simpanTampil = true) {
    const k = +inp.dataset.k,
      t = +inp.dataset.t,
      vr = inp.dataset.v,
      a = asli(k, t, vr),
      c = kunci(k, t, vr);
    const sama =
      (v === null && !ada(a)) ||
      (v !== null &&
        ada(a) &&
        Math.abs(v - a) <= 1e-9 * Math.max(1, Math.abs(a)));
    sama ? ubah.delete(c) : ubah.set(c, v);
    if (simpanTampil) inp.value = tampil(v, vr);
    const td = inp.parentElement;
    td.className = 'g-sel ' + kelasCatatan(k, t, vr);
    td.title = judulSel(k, t, vr);
    td.classList.remove('salah');
  }
  function sel(r, c) {
    return $('g-wadah').querySelector(`input[data-r="${r}"][data-c="${c}"]`);
  }
  function pasang() {
    $('g-wadah')
      .querySelectorAll('input')
      .forEach((inp) => {
        inp.addEventListener('focus', () => {
          const x = nilai(+inp.dataset.k, +inp.dataset.t, inp.dataset.v);
          inp.value = ada(x) ? String(+x.toFixed(6)) : '';
          inp.select();
        });
        inp.addEventListener('blur', () => {
          const v = urai(inp.value);
          if (Number.isNaN(v)) {
            inp.parentElement.classList.add('salah');
            inp.parentElement.title = 'Bukan angka: ' + inp.value;
            return;
          }
          setSel(inp, v);
          jumlahKolom();
          status();
        });
        inp.addEventListener('keydown', (e) => {
          const r = +inp.dataset.r,
            c = +inp.dataset.c;
          const ke =
            {
              ArrowUp: [r - 1, c],
              ArrowDown: [r + 1, c],
              Enter: [e.shiftKey ? r - 1 : r + 1, c],
            }[e.key] ||
            (e.key === 'ArrowLeft' &&
            inp.selectionStart === 0 &&
            inp.selectionEnd === 0
              ? [r, c - 1]
              : null) ||
            (e.key === 'ArrowRight' && inp.selectionStart === inp.value.length
              ? [r, c + 1]
              : null);
          if (
            e.key === 'Delete' &&
            inp.selectionStart === 0 &&
            inp.selectionEnd === inp.value.length
          ) {
            inp.value = '';
            e.preventDefault();
            return;
          }
          if (e.key === 'Escape') {
            const x = nilai(+inp.dataset.k, +inp.dataset.t, inp.dataset.v);
            inp.value = ada(x) ? String(x) : '';
            inp.blur();
            return;
          }
          if (ke) {
            const s = sel(...ke);
            if (s) {
              e.preventDefault();
              s.focus();
            }
          }
        });
        inp.addEventListener('paste', (e) => {
          const teks = (e.clipboardData || window.clipboardData).getData(
            'text',
          );
          if (!/[\t\n]/.test(teks.trim())) return;
          e.preventDefault();
          const baris = teks
            .replace(/\r/g, '')
            .replace(/\n$/, '')
            .split('\n')
            .map((b) => b.split('\t'));
          const r0 = +inp.dataset.r,
            c0 = +inp.dataset.c;
          let n = 0,
            salah = 0;
          baris.forEach((b, i) =>
            b.forEach((x, j) => {
              const s = sel(r0 + i, c0 + j);
              if (!s) return;
              const v = urai(x);
              if (Number.isNaN(v)) {
                salah++;
                s.parentElement.classList.add('salah');
                return;
              }
              setSel(s, v);
              n++;
            }),
          );
          jumlahKolom();
          status();
          $('g-info').textContent =
            `${n} sel ditempel${salah ? `, ${salah} bukan angka (ditandai merah)` : ''}`;
        });
      });
  }

  /* ------------------------------------------------------------------ status dan simpan */
  function status() {
    $('g-n').textContent = ubah.size;
    $('g-simpan').disabled = !ubah.size;
    if (!$('g-daftar').hidden) daftarUbah();
  }
  function daftarUbah() {
    const rows = [...ubah.entries()]
      .map(([c, v]) => {
        const [k, t, vr] = c.split('|');
        return { k: +k, t: +t, vr, v };
      })
      .sort((a, b) => a.vr.localeCompare(b.vr) || a.k - b.k || a.t - b.t);
    $('g-daftar').innerHTML = rows.length
      ? `<div class="gulir" style="max-height:260px;margin-top:10px"><table class="tabel rapat"><thead><tr><th>Variabel</th><th>Provinsi</th><th>Tahun</th><th class="n">Asli</th><th class="n">Baru</th><th class="n">Δ%</th><th></th></tr></thead><tbody>` +
        rows
          .map((r) => {
            const a = asli(r.k, r.t, r.vr);
            return `<tr><td class="kecil">${esc(r.vr)}</td><td>${esc(P.find((p) => p.kode === r.k).nama)}</td><td>${r.t}</td><td class="n">${ada(a) ? tampil(a, r.vr) : '–'}</td><td class="n"><b>${ada(r.v) ? tampil(r.v, r.vr) : 'kosong'}</b></td><td class="n">${ada(a) && ada(r.v) && a ? ((r.v / a - 1) * 100).toFixed(1) : ''}</td><td><button type="button" class="btn garis kecil" data-hapus="${esc(kunci(r.k, r.t, r.vr))}">↺</button></td></tr>`;
          })
          .join('') +
        '</tbody></table></div>'
      : '<p class="kecil abu">Belum ada perubahan.</p>';
    $('g-daftar')
      .querySelectorAll('[data-hapus]')
      .forEach((b) =>
        b.addEventListener('click', () => {
          ubah.delete(b.dataset.hapus);
          gambar();
          status();
        }),
      );
  }
  $('g-lihat').addEventListener('click', () => {
    $('g-daftar').hidden = !$('g-daftar').hidden;
    daftarUbah();
  });
  $('g-batal').addEventListener('click', () => {
    if (ubah.size && confirm(`Batalkan ${ubah.size} perubahan?`)) {
      ubah.clear();
      gambar();
      status();
    }
  });
  $('g-simpan').addEventListener('click', async () => {
    const alasan = $('g-alasan').value.trim();
    if (!alasan) {
      $('g-alasan').focus();
      $('g-alasan').classList.add('salah');
      return;
    }
    $('g-simpan').disabled = true;
    $('g-simpan').textContent = 'Menyimpan…';
    const perubahan = [...ubah.entries()].map(([c, v]) => {
      const [kode, tahun, vr] = c.split('|');
      return { kode: +kode, tahun: +tahun, var: vr, nilai: v };
    });
    const r = await fetch(window.GRID.simpan, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRFToken': window.GRID.csrf,
      },
      body: JSON.stringify({
        perubahan,
        alasan,
        nama: $('g-nama').value,
        aktifkan: $('g-aktifkan').checked,
      }),
    });
    const d = await r.json();
    if (!r.ok) {
      alert(d.error || 'Gagal menyimpan.');
      $('g-simpan').disabled = false;
      $('g-simpan').textContent = 'Simpan sebagai versi baru';
      return;
    }
    ubah.clear();
    location.href = d.url;
  });
  window.addEventListener('beforeunload', (e) => {
    if (ubah.size) {
      e.preventDefault();
      e.returnValue = '';
    }
  });

  /* ------------------------------------------------------------------ tahun baru, ekstrapolasi */
  function tambahTahun(t) {
    if (!t || TAHUN.includes(t)) return;
    TAHUN = [...TAHUN, t].sort((a, b) => a - b);
    $('g-tahun').innerHTML = TAHUN.map(
      (x) => `<option ${x === t ? 'selected' : ''}>${x}</option>`,
    ).join('');
    $('g-th-baru').value = Math.max(...TAHUN) + 1;
    gambar();
  }
  $('g-tambah-th').addEventListener('click', () =>
    tambahTahun(+$('g-th-baru').value),
  );
  $('g-ekstra').addEventListener('click', () => {
    const v = $('g-var').value,
      t = Math.max(...TAHUN);
    let n = 0;
    P.forEach((p) => {
      if (ada(nilai(p.kode, t, v))) return;
      const seri = [t - 4, t - 3, t - 2, t - 1].map((x) => nilai(p.kode, x, v));
      const laju = [];
      for (let i = 1; i < seri.length; i++)
        if (ada(seri[i]) && ada(seri[i - 1]) && seri[i - 1] > 0 && seri[i] > 0)
          laju.push(Math.log(seri[i] / seri[i - 1]));
      const akhir = seri[3];
      if (!ada(akhir) || !laju.length) return;
      const inp = $('g-wadah').querySelector(
        `input[data-k="${p.kode}"][data-t="${t}"]`,
      );
      if (inp) {
        setSel(
          inp,
          akhir * Math.exp(laju.reduce((a, b) => a + b, 0) / laju.length),
        );
        n++;
      }
    });
    jumlahKolom();
    status();
    $('g-info').textContent =
      `${n} sel kosong ${t} diisi ekstrapolasi (laju log rata-rata hingga 3 tahun).`;
    if (n && !$('g-alasan').value)
      $('g-alasan').value =
        `Ekstrapolasi ${VAR[v].kode} ${t} dari laju rata-rata 3 tahun`;
  });

  /* ------------------------------------------------------------------ mulai */
  ['g-mode', 'g-var', 'g-tahun', 'g-grup'].forEach((id) =>
    $(id).addEventListener('change', gambar),
  );
  fetch(window.GRID.data)
    .then((r) => r.json())
    .then((d) => {
      D = d;
      P = d.provinsi;
      TAHUN = [...d.tahun];
      D.pulau = [...new Set(P.map((p) => p.pulau))];
      d.variabel.forEach((v) => (VAR[v.kode] = v));
      const grup = {};
      d.variabel.forEach((v) => (grup[v.grup] = grup[v.grup] || []).push(v));
      $('g-var').innerHTML = Object.entries(grup)
        .map(
          ([g, vs]) =>
            `<optgroup label="${esc(g)}">${vs.map((v) => `<option value="${v.kode}">${esc(v.label)}${v.wajib ? ' ★' : ''}</option>`).join('')}</optgroup>`,
        )
        .join('');
      $('g-tahun').innerHTML = TAHUN.map((t) => `<option>${t}</option>`).join(
        '',
      );
      $('g-tahun').value = TAHUN[TAHUN.length - 1];
      $('g-th-baru').value = Math.max(...TAHUN) + 1;
      const h = new URLSearchParams(location.hash.slice(1));
      if (h.get('mode')) $('g-mode').value = h.get('mode');
      if (h.get('v') && VAR[h.get('v').split(',')[0]])
        $('g-var').value = h.get('v').split(',')[0];
      if (h.get('t')) {
        if (!TAHUN.includes(+h.get('t'))) tambahTahun(+h.get('t'));
        $('g-tahun').value = h.get('t');
      }
      gambar();
      if (h.get('k') && h.get('t')) {
        const q =
          `input[data-k="${h.get('k')}"][data-t="${h.get('t')}"]` +
          ($('g-mode').value === 'tahun' && h.get('v')
            ? `[data-v="${h.get('v').split(',')[0]}"]`
            : '');
        const s = $('g-wadah').querySelector(q);
        if (s) {
          s.parentElement.classList.add('sorot-sel');
          s.scrollIntoView({ block: 'center', inline: 'center' });
          s.focus();
        }
      }
    });
})();
