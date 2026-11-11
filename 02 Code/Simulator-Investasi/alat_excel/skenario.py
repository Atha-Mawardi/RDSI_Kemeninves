"""Lembar Skenario (kolom = slot, baris = asumsi) dan AsumsiProv (pengecualian per provinsi)."""

from . import gaya as G
from .data import validasi
from .konteks import KEL, MAKS_H, NAMA_PILAR, PROVINSI, PULAU

C_SLOT = 5  # kolom slot pertama
R_JUDUL = 12  # baris judul slot
N_PROV_BARIS = 6  # baris provinsi pertama di AsumsiProv
KOLOM_PROV = [("sasaran", "Sasaran %"), ("tfp", "Laju TFP %"), ("tk", "Laju TK %"), ("bobot", "Bobot investasi tambahan")]


def baris_asumsi(ctx):
    """Daftar baris: (kunci, label, satuan, jenis, daftar_pilihan, format). jenis: grup|teks|angka|pilih|rumus."""
    b = [("_identitas", "Identitas", "", "grup", None, None),
         ("nama", "Nama skenario", "", "teks", None, None),
         ("singkat", "Nama singkat", "", "teks", None, None),
         ("deskripsi", "Deskripsi", "", "teks", None, None),
         ("tampil", "Tampil di Perbandingan", "ya/tidak", "pilih", "=L_ya", None),
         ("_param", "Elastisitas dan bonus sektoral", "", "grup", None, None),
         ("set_param", "Set elastisitas", "dari lembar Estimasi", "pilih", "=EP_nama", None),
         ("b1", "Elastisitas modal", "", "rumus", None, G.FMT_4),
         ("b2", "Elastisitas tenaga kerja", "", "rumus", None, G.FMT_4),
         ("se_b1", "SE elastisitas modal", "", "rumus", None, G.FMT_4),
         ("se_b2", "SE elastisitas tenaga kerja", "", "rumus", None, G.FMT_4),
         ("set_sektoral", "Set koefisien sektoral", "dari lembar Estimasi", "pilih", "=ES_nama", None)]
    b += [(f"beta_{k}", f"Bonus sektoral {k}", "pp TFP per pangsa", "rumus", None, G.FMT_4) for k in KEL[:3]]
    b += [("_sasaran", "Sasaran pertumbuhan", "", "grup", None, None),
          ("sasaran", "Sasaran nasional", "%/thn", "angka", None, G.FMT_P),
          ("mode_sasaran", "Pembagian sasaran", "seragam / proporsional / manual", "pilih", "=L_mode_sasaran", None),
          ("lambda", "Lambda proporsional", "×", "angka", None, G.FMT_P)]
    b += [(f"j_sasaran_{h}", f'="Sasaran "&(TD+{h})', "%; kosong = sasaran nasional", "angka", None, G.FMT_P)
          for h in range(1, MAKS_H + 1)]
    b += [("_tfp", "TFP dan tenaga kerja", "", "grup", None, None),
          ("mode_tfp", "Laju TFP", "historis / nasional", "pilih", "=L_mode_hist", None),
          ("tfp_nasional", "Laju TFP nasional", "%/thn (mode nasional)", "angka", None, G.FMT_P),
          ("faktor_tfp", "Faktor laju TFP", "× laju", "angka", None, G.FMT_P)]
    b += [(f"j_faktor_tfp_{h}", f'="Faktor TFP "&(TD+{h})', "×; kosong = 1", "angka", None, G.FMT_P)
          for h in range(1, MAKS_H + 1)]
    b += [("mode_tk", "Laju tenaga kerja", "historis / nasional", "pilih", "=L_mode_hist", None),
          ("tk_nasional", "Laju TK nasional", "%/thn (mode nasional)", "angka", None, G.FMT_P),
          ("_pmtb", "Modal dan realisasi", "", "grup", None, None),
          ("mode_pmtb", "Laju PMTB tren", "historis / nasional", "pilih", "=L_mode_hist", None),
          ("g_pmtb_nasional", "Laju PMTB nasional", "%/thn; kosong = historis nasional", "angka", None, G.FMT_P),
          ("g_investasi", "Laju tren PMA+PMDN", "%/thn; kosong = historis", "angka", None, G.FMT_P)]
    b += [(f"j_g_investasi_{h}", f'="Laju tren PMA+PMDN "&(TD+{h})', "%; kosong = nilai di atas", "angka", None,
           G.FMT_P) for h in range(1, MAKS_H + 1)]
    b += [("inflasi_pmtb", "Inflasi deflator PMTB", "%/thn; kosong = historis", "angka", None, G.FMT_P),
          ("pass_through", "Pass-through realisasi ke PMTB", "×", "angka", None, G.FMT_P),
          ("rasio_realisasi", "Rasio realisasi", "×", "angka", None, G.FMT_P),
          ("apbd_persen", "Belanja modal APBD tambahan", "% belanja APBD", "angka", None, G.FMT_P),
          ("pass_through_apbd", "Pass-through APBD ke PMTB", "×", "angka", None, G.FMT_P),
          ("_a1", "Investasi dasar", "", "grup", None, None)]
    b += [(f"a1_{h}", f'="Investasi dasar "&(TD+{h})', "triliun Rp; kosong = tren", "angka", None, G.FMT_T1)
          for h in range(1, MAKS_H + 1)]
    b += [("_a2", "Investasi tambahan", "", "grup", None, None),
          ("mode_a2", "Cara mengisi", "angka / kebutuhan x skala", "pilih", "=L_mode_a2", None),
          ("skala_a2", "Skala kebutuhan", "× kebutuhan tambahan (mode kebutuhan x skala)", "angka", None, G.FMT_P)]
    b += [(f"a2_{h}", f'="Investasi tambahan "&(TD+{h})', "triliun Rp", "angka", None, G.FMT_T1)
          for h in range(1, MAKS_H + 1)]
    b += [("alokasi_a2", "Alokasi antarprovinsi", "kebutuhan / pdrb / investasi / manual (bobot di AsumsiProv)",
           "pilih", "=L_alokasi", None)]
    b += [(f"komp_{k}", f"Komposisi sektor: {k}", "%; kosong semua = historis provinsi", "angka", None, G.FMT_P1)
          for k in KEL]
    b += [("realokasi_pp", "Realokasi TK dari pertanian", "poin persen sampai tahun target", "angka", None, G.FMT_P),
          ("tujuan_realokasi", "Tujuan realokasi", "C = industri / tva = jasa bernilai tambah", "pilih", "=L_tujuan",
           None),
          ("_shock", "Shock (nasional)", "", "grup", None, None)]
    for i in (1, 2):
        b += [(f"s{i}_jenis", f"Shock {i}: jenis", "", "pilih", "=L_shock", None),
              (f"s{i}_tahun", f"Shock {i}: tahun", "", "angka", None, "0"),
              (f"s{i}_besar", f"Shock {i}: besar", "% level", "angka", None, G.FMT_P),
              (f"s{i}_rho", f"Shock {i}: persistensi", "0-1 per tahun", "angka", None, G.FMT_P)]
    b += [("_det", "Determinan TFP (perubahan di atas tren, SD)", "", "grup", None, None)]
    for pilar, nama in NAMA_PILAR.items():
        b += [(f"dp_{pilar}", f"{nama}: semua indikator", "SD", "angka", None, G.FMT_P),
              (f"dj_{pilar}", f"{nama}: jeda", "tahun; kosong = default", "angka", None, "0"),
              (f"dr_{pilar}", f"{nama}: masa menuju penuh", "tahun (1-6); kosong = default", "angka", None, "0")]
    for ind in ctx.det:
        b += [(f"di_{ind['kode']}", f"   {ind['label']}", f"SD; kosong = isian pilar ({NAMA_PILAR[ind['pilar']]})",
               "angka", None, G.FMT_P)]
    b += [("_ktp", "Ketidakpastian", "", "grup", None, None),
          ("skala_se", "Skala standard error", "×", "angka", None, G.FMT_P),
          ("volatilitas_tfp", "Volatilitas TFP tahunan", "× SD residual", "angka", None, G.FMT_P),
          ("catatan", "Catatan", "", "teks", None, None)]
    return b


def lembar_skenario(wb, ctx):
    ws = wb.create_sheet("Skenario")
    G.warna_tab(ws, G.ORANYE)
    G.pita(ws, "Skenario", "Kolom = slot skenario, baris = asumsi. Sel kuning dapat diubah; sel abu dihitung.")
    umum = [("TD", "Tahun dasar", ctx.umum["tahun_dasar"]), ("TT", "Tahun target", ctx.umum["tahun_target"]),
            ("HA", "Jendela historis: awal", ctx.umum["hist_awal"]),
            ("HZ", "Jendela historis: akhir", ctx.umum["hist_akhir"]),
            ("KECUALI_2020", "Kecualikan 2020 (1 = ya)", 1 if ctx.umum["kecualikan_2020"] else 0)]
    for i, (nm, lb, v) in enumerate(umum):
        r = 4 + i
        G.tulis(ws, r, 2, lb, font=G.T_TEBAL)
        G.tulis(ws, r, 3, v, fill=G.F_ISIAN, align=G.TENGAH, border=G.KOTAK)
        G.nama(wb, nm, "Skenario", f"$C${r}")
    G.tulis(ws, 9, 2, "Horizon (tahun)", font=G.T_TEBAL)
    G.tulis(ws, 9, 3, f"=MAX(1,MIN(TT-TD,{MAKS_H}))", fill=G.F_RUMUS, align=G.TENGAH, border=G.KOTAK)
    G.nama(wb, "H_", "Skenario", "$C$9")
    G.tulis(ws, 9, 4, f"maks. {MAKS_H} tahun; semua slot memakai horizon dan jendela historis yang sama", font=G.T_KECIL)

    baris = baris_asumsi(ctx)
    rk = {}
    G.tulis(ws, R_JUDUL, 2, "Asumsi", font=G.T_HEADER, fill=G.F_HEADER)
    G.tulis(ws, R_JUDUL, 3, "Satuan / keterangan", font=G.T_HEADER, fill=G.F_HEADER)
    ns = len(ctx.slot)
    for s in range(ns):
        G.tulis(ws, R_JUDUL, C_SLOT + s, f"Slot {s + 1}", font=G.T_HEADER, fill=G.F_HEADER, align=G.TENGAH)
    r = R_JUDUL + 1
    for kunci, label, satuan, jenis, pilihan, fmt in baris:
        rk[kunci] = r
        if jenis == "grup":
            G.bagian(ws, r, 2, C_SLOT + ns - 1, label)
            r += 1
            continue
        G.tulis(ws, r, 2, label, font=G.T_BIASA)
        G.tulis(ws, r, 3, satuan, font=G.T_KECIL)
        r += 1
    r_akhir = r - 1

    for s, sl in enumerate(ctx.slot):
        c = C_SLOT + s
        L = G.kol(c)
        for kunci, label, satuan, jenis, pilihan, fmt in baris:
            if jenis == "grup":
                continue
            rr = rk[kunci]
            if jenis == "rumus":
                v = _rumus_turunan(kunci, L, rk)
                G.tulis(ws, rr, c, v, fill=G.F_RUMUS, fmt=fmt, align=G.KANAN)
                continue
            v = "\n".join(sl.catatan) if kunci == "catatan" else sl.nilai.get(kunci)
            if kunci == "nama":
                v = sl.nama
            cell = G.tulis(ws, rr, c, v, fill=G.F_ISIAN, fmt=fmt)
            if jenis == "teks":
                cell.alignment = G.KIRI_BUNGKUS if kunci in ("deskripsi", "catatan") else G.KIRI
        for kunci, _, _, jenis, pilihan, _ in baris:
            if jenis == "pilih":
                pass
    for kunci, _, _, jenis, pilihan, _ in baris:
        if jenis == "pilih":
            validasi(ws, pilihan, f"{G.kol(C_SLOT)}{rk[kunci]}:{G.kol(C_SLOT + ns - 1)}{rk[kunci]}")
    for kunci in ("deskripsi", "catatan"):
        ws.row_dimensions[rk[kunci]].height = 60
    G.lebar(ws, [2, 34, 30, 2] + [16] * ns)
    ws.freeze_panes = ws.cell(row=R_JUDUL + 1, column=C_SLOT)
    G.nama(wb, "SK_NAMA", "Skenario", f"${G.kol(C_SLOT)}${rk['nama']}:${G.kol(C_SLOT + ns - 1)}${rk['nama']}")
    G.nama(wb, "SK_SINGKAT", "Skenario",
           f"${G.kol(C_SLOT)}${rk['singkat']}:${G.kol(C_SLOT + ns - 1)}${rk['singkat']}")
    G.nama(wb, "SK_TAMPIL", "Skenario", f"${G.kol(C_SLOT)}${rk['tampil']}:${G.kol(C_SLOT + ns - 1)}${rk['tampil']}")
    G.nama(wb, "SK_DESK", "Skenario",
           f"${G.kol(C_SLOT)}${rk['deskripsi']}:${G.kol(C_SLOT + ns - 1)}${rk['deskripsi']}")
    return ws, rk


def _rumus_turunan(kunci, L, rk):
    sp, ss = f"{L}{rk['set_param']}", f"{L}{rk['set_sektoral']}"
    peta = {"b1": "EP_b1", "b2": "EP_b2", "se_b1": "EP_se1", "se_b2": "EP_se2"}
    if kunci in peta:
        return f"=IFERROR(INDEX({peta[kunci]},MATCH({sp},EP_nama,0)),0)"
    k = kunci.split("_", 1)[1]
    return f"=IFERROR(INDEX(ES_{k},MATCH({ss},ES_nama,0)),0)"


def lembar_asumsi_prov(wb, ctx):
    ws = wb.create_sheet("AsumsiProv")
    G.warna_tab(ws, G.ORANYE)
    G.pita(ws, "Asumsi per provinsi",
           "Kosong = ikut aturan slot. Sasaran dikunci (mode manual mengunci provinsi yang diisi), TFP/TK mengganti laju "
           "historis, bobot dipakai pada alokasi manual.")
    G.header(ws, 5, 1, ["Kode", "Provinsi", "Pulau"])
    prov = PROVINSI(ctx.kode)
    for i, (k, n, p) in enumerate(prov):
        r = N_PROV_BARIS + i
        for c, v in enumerate((k, n, p), 1):
            ws.cell(row=r, column=c, value=v)
    for s, sl in enumerate(ctx.slot):
        c0 = 5 + s * len(KOLOM_PROV)
        G.gabung(ws, 4, c0, c0 + len(KOLOM_PROV) - 1, f"=INDEX(SK_NAMA,{s + 1})", font=G.T_HEADER, fill=G.F_SUB,
                 align=G.TENGAH)
        G.header(ws, 5, c0, [lb for _, lb in KOLOM_PROV], tinggi=30)
        for i, (k, _, _) in enumerate(prov):
            r = N_PROV_BARIS + i
            o = sl.prov.get(k, {})
            for j, (kk, _) in enumerate(KOLOM_PROV):
                G.tulis(ws, r, c0 + j, o.get(kk), fill=G.F_ISIAN, fmt=G.FMT_P)
    G.lebar(ws, [7, 22, 12, 2] + [10] * (len(ctx.slot) * len(KOLOM_PROV)))
    ws.freeze_panes = "E6"
    return ws


def sel_prov(s, kunci, i):
    """Alamat AsumsiProv untuk slot s (0-based), kolom kunci, provinsi ke-i (0-based)."""
    j = [k for k, _ in KOLOM_PROV].index(kunci)
    return f"AsumsiProv!${G.kol(5 + s * len(KOLOM_PROV) + j)}${N_PROV_BARIS + i}"
