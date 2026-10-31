"""Lembar tampilan: Petunjuk, Beranda, Hasil, Perbandingan, Jelajah, Kelengkapan, Pivot."""

from datetime import date

from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.chart.shapes import GraphicalProperties
from openpyxl.drawing.line import LineProperties
from openpyxl.formatting.rule import CellIsRule, ColorScaleRule, DataBarRule, FormulaRule
from openpyxl.styles import Font

from . import gaya as G
from .data import PETAK, validasi
from .hitung import JUDUL_PROV_KUMPUL
from .konteks import KEL, KELOMPOK, PROVINSI, SEKTOR
from .mesin import MAKS_H

SINGKAT_PROV = {
    11: "Aceh", 12: "Sumut", 13: "Sumbar", 14: "Riau", 15: "Jambi", 16: "Sumsel", 17: "Bengkulu", 18: "Lampung",
    19: "Babel", 21: "Kepri", 31: "DKI", 32: "Jabar", 33: "Jateng", 34: "DIY", 35: "Jatim", 36: "Banten", 51: "Bali",
    52: "NTB", 53: "NTT", 61: "Kalbar", 62: "Kalteng", 63: "Kalsel", 64: "Kaltim", 65: "Kaltara", 71: "Sulut",
    72: "Sulteng", 73: "Sulsel", 74: "Sultra", 75: "Gorontalo", 76: "Sulbar", 81: "Maluku", 82: "Malut", 91: "Pabar",
    92: "PBD", 94: "Papua", 95: "Pasel", 96: "Papteng", 97: "Papeg",
}
WARNA = {"tanpa": G.ABU, "dengan": G.BIRU, "sasaran": G.ORANYE, "tambahan": G.HIJAU, "keb": G.MERAH, "navy": G.NAVY}
T_KECIL_HITAM = Font(size=8, color="333333")


# ------------------------------------------------------------------ pembantu
def _pilih(wb, ws, r, c1, c2, nama, bawaan, judul="Skenario"):
    G.tulis(ws, r, c1 - 1, judul, font=G.T_TEBAL, align=G.KANAN)
    G.gabung(ws, r, c1, c2, bawaan, font=Font(bold=True, size=12, color=G.NAVY), fill=G.F_ISIAN, align=G.KIRI)
    for c in range(c1, c2 + 1):
        ws.cell(row=r, column=c).border = G.KOTAK
    validasi(ws, "=SK_NAMA", f"{G.kol(c1)}{r}")
    G.nama(wb, nama, ws.title, f"${G.kol(c1)}${r}")
    return f"MATCH({nama},SK_NAMA,0)"


def _garis(ws, judul, kat, seri, jangkar, lebar=16, tinggi=7.5, y_judul=None, fmt=None):
    ch = LineChart()
    ch.title, ch.style, ch.height, ch.width = judul, 2, tinggi, lebar
    ch.legend.position = "b"
    if y_judul:
        ch.y_axis.title = y_judul
    if fmt:
        ch.y_axis.number_format = fmt
    ch.y_axis.majorGridlines.spPr = GraphicalProperties(ln=LineProperties(solidFill="E5E8EC"))
    for ref, warna, putus, tebal in seri:
        ch.add_data(ref, titles_from_data=True)
        s = ch.series[-1]
        s.smooth = False
        s.graphicalProperties.line.solidFill = warna
        s.graphicalProperties.line.width = tebal
        if putus:
            s.graphicalProperties.line.dashStyle = "dash"
        s.marker.symbol = "none"
    if kat is not None:
        ch.set_categories(kat)
    ch.x_axis.delete = False
    ch.y_axis.delete = False
    ws.add_chart(ch, jangkar)
    return ch


def _batang(ws, judul, kat, seri, jangkar, lebar=16, tinggi=7.5, arah="col", tumpuk=False, fmt=None, y_judul=None):
    ch = BarChart()
    ch.type, ch.title, ch.style, ch.height, ch.width = arah, judul, 2, tinggi, lebar
    ch.legend.position = "b"
    if tumpuk:
        ch.grouping, ch.overlap = "stacked", 100
    else:
        ch.gapWidth = 60
    if fmt:
        ch.y_axis.number_format = fmt
    if y_judul:
        ch.y_axis.title = y_judul
    ch.y_axis.majorGridlines.spPr = GraphicalProperties(ln=LineProperties(solidFill="E5E8EC"))
    for ref, warna in seri:
        ch.add_data(ref, titles_from_data=True)
        s = ch.series[-1]
        s.graphicalProperties.solidFill = warna
        s.graphicalProperties.line.solidFill = warna
    if kat is not None:
        ch.set_categories(kat)
    ch.x_axis.delete = False
    ch.y_axis.delete = False
    ws.add_chart(ch, jangkar)
    return ch


def _tabel_kepala(ws, r, c, judul, tinggi=30):
    G.header(ws, r, c, judul, tinggi=tinggi)


def _bantu_judul(ws, r, c, teks):
    G.tulis(ws, r, c, teks, font=G.T_KECIL)


# ------------------------------------------------------------------ Petunjuk
def petunjuk(wb, ctx):
    ws = wb.create_sheet("Petunjuk")
    G.warna_tab(ws, G.NAVY)
    G.pita(ws, "Simulator Investasi", f"Versi Excel ringan · data {ctx.versi_label} · dibuat {date.today():%d-%m-%Y}")
    r = 4
    G.bagian(ws, r, 1, 8, "Cara pakai")
    langkah = [
        "1. Beranda: pilih skenario untuk melihat laju, sasaran, investasi tambahan, kebutuhan, dan confidence.",
        "2. Skenario: ubah asumsi di sel kuning. Satu kolom = satu slot; Kustom 1 dan Kustom 2 bebas dipakai. "
        "Pengecualian per provinsi diisi di AsumsiProv.",
        "3. Hasil: rincian per provinsi (dengan peta petak), per tahun, dan per sektor untuk satu skenario.",
        "4. Perbandingan: semua slot yang bertanda \"ya\" pada baris Tampil di Perbandingan.",
        "5. Jelajah dan Kelengkapan: telusuri data panel; Pivot: ringkasan bebas dari hasil semua slot.",
    ]
    for i, t in enumerate(langkah):
        G.gabung(ws, r + 1 + i, 1, 8, t, align=G.KIRI_BUNGKUS)
        ws.row_dimensions[r + 1 + i].height = 28
    r += len(langkah) + 2

    G.bagian(ws, r, 1, 8, "Lembar")
    daftar = [
        ("Beranda", "Ringkasan satu skenario"), ("Skenario", "Asumsi semua slot"),
        ("AsumsiProv", "Sasaran, laju TFP, laju TK, dan bobot investasi tambahan per provinsi"),
        ("Hasil", "Rincian satu skenario"), ("Perbandingan", "Semua slot berdampingan"),
        ("Jelajah", "Nilai data per provinsi dan per tahun"), ("Pivot", "PivotTable hasil semua slot"),
        ("Data", "Panel provinsi × tahun; tempat menambah tahun baru"),
        ("Kelengkapan", "Ketersediaan data per variabel dan tahun"),
        ("Estimasi", "Estimasi ulang elastisitas dan semua tabel koefisien"),
        ("Hitung", "Besaran dasar dan kumpulan hasil semua slot"),
        ("M_…", "Mesin per slot (rumus lengkap, tidak perlu disunting)"),
    ]
    for i, (nm, ket) in enumerate(daftar):
        rr = r + 1 + i
        c = G.tulis(ws, rr, 1, nm, font=G.T_TAUTAN if nm in wb.sheetnames or nm in ("Petunjuk",) else G.T_TEBAL)
        if not nm.startswith("M_"):
            c.hyperlink = f"#'{nm}'!A1"
        G.gabung(ws, rr, 2, 8, ket)
    r += len(daftar) + 2

    G.bagian(ws, r, 1, 8, "Warna sel")
    for i, (fill, ket) in enumerate([(G.F_ISIAN, "Isian: boleh diubah"), (G.F_RUMUS, "Rumus: dihitung otomatis"),
                                     (G.F_HEADER, "Judul tabel")]):
        G.tulis(ws, r + 1 + i, 1, "", fill=fill, border=G.KOTAK)
        G.gabung(ws, r + 1 + i, 2, 8, ket)
    r += 5

    G.bagian(ws, r, 1, 8, "Memperbarui data dan model")
    teks = [
        "Tahun baru: tambahkan baris di lembar Data (kode provinsi, tahun, nilai) di bawah baris terakhir, lalu ubah "
        "tahun dasar, tahun target, dan jendela historis di lembar Skenario.",
        "Studi pendahuluan: ganti angka di Data atau di tabel koefisien Estimasi; seluruh slot dihitung ulang.",
        "Elastisitas: atur jendela di Estimasi, lalu pilih set \"Estimasi Excel\" pada baris Set elastisitas di Skenario. "
        "Set \"Manual\" bisa diisi angka sendiri.",
        "Koefisien sektoral, koefisien determinan TFP, serta jeda dan masa menuju efek penuh disunting di Estimasi.",
        "Batas: horizon 10 tahun, 600 baris data, 2 shock nasional per slot.",
    ]
    for i, t in enumerate(teks):
        G.gabung(ws, r + 1 + i, 1, 8, "• " + t, align=G.KIRI_BUNGKUS)
        ws.row_dimensions[r + 1 + i].height = 30
    r += len(teks) + 2

    G.bagian(ws, r, 1, 8, "Catatan tampilan")
    teks = [
        f"Grafik dan tabel tahunan disusun untuk horizon saat berkas dibuat ({ctx.umum['tahun_dasar']}-"
        f"{ctx.umum['tahun_target']}). Bila tahun target diubah, perluas rentang grafik lewat Select Data.",
        "Grafik Perbandingan memuat slot bertanda \"ya\"; slot yang disembunyikan meninggalkan kategori kosong di ujung "
        "grafik sampai rentangnya disesuaikan.",
        "Pivot tidak ikut berubah otomatis: pakai Data > Refresh All setelah mengubah asumsi.",
        "Warna, ukuran huruf, dan jenis grafik bebas diubah (klik kanan > Format). Peta petak di Hasil mengikuti besaran "
        "yang dipilih.",
    ]
    for i, t in enumerate(teks):
        G.gabung(ws, r + 1 + i, 1, 8, "• " + t, align=G.KIRI_BUNGKUS)
        ws.row_dimensions[r + 1 + i].height = 30
    r += len(teks) + 2

    G.bagian(ws, r, 1, 8, "Catatan model")
    teks = [
        "Jalur tanpa dan dengan penambahan investasi, kebutuhan, dan kontribusi dihitung dengan rumus yang sama dengan "
        "aplikasi. Confidence, P10/P90, dan Kebutuhan batas aman memakai pendekatan analitis, sehingga dapat sedikit "
        "berbeda dari aplikasi.",
        "Hanya di aplikasi: shock per pulau atau provinsi, determinan yang didanai investasi tambahan, komposisi sektor "
        "per provinsi. Slot yang memakainya diberi keterangan di baris Catatan pada lembar Skenario.",
        "Estimasi Excel memakai demean dua arah satu langkah, tepat untuk panel seimbang.",
    ]
    for i, t in enumerate(teks):
        G.gabung(ws, r + 1 + i, 1, 8, "• " + t, align=G.KIRI_BUNGKUS)
        ws.row_dimensions[r + 1 + i].height = 30
    G.lebar(ws, [16, 14, 14, 14, 14, 14, 14, 14])
    return ws


# ------------------------------------------------------------------ Beranda
def beranda(wb, ctx, H):
    ws = wb.create_sheet("Beranda")
    G.warna_tab(ws, G.ORANYE)
    G.pita(ws, "Simulator Investasi", f"Ringkasan skenario · data {ctx.versi_label}")
    bawaan = next((s.nama for s in ctx.slot if s.singkat.startswith("Bertahap")), ctx.slot[0].nama)
    no = _pilih(wb, ws, 4, 3, 7, "BR_PILIH", bawaan)
    G.tulis(ws, 4, 9, "No", font=G.T_KECIL)
    G.tulis(ws, 4, 10, f"={no}", font=G.T_KECIL)
    G.nama(wb, "BR_NO", "Beranda", "$J$4")
    G.gabung(ws, 5, 2, 13, "=INDEX(SK_DESK,BR_NO)", font=G.T_SUBJUDUL, align=G.KIRI_BUNGKUS)
    ws.row_dimensions[5].height = 30

    kartu = [
        ("Laju tanpa penambahan investasi", "=INDEX(KS_g_rata_dasar,BR_NO)/100", G.FMT_PCT1, "rata-rata per tahun"),
        ("Laju dengan penambahan investasi", "=INDEX(KS_g_rata_skenario,BR_NO)/100", G.FMT_PCT1, "rata-rata per tahun"),
        ("Sasaran", "=INDEX(KS_g_rata_sasaran,BR_NO)/100", G.FMT_PCT1, "rata-rata per tahun"),
        ("Confidence", "=INDEX(KS_prob_nas,BR_NO)", G.FMT_PCT, "peluang mencapai sasaran"),
        ("Investasi tambahan", "=INDEX(KS_a2_kum,BR_NO)", G.FMT_T, "triliun Rp, kumulatif"),
        ("Kebutuhan tambahan", "=INDEX(KS_keb_kum,BR_NO)", G.FMT_T, "triliun Rp, kumulatif"),
        ("Kebutuhan batas aman", "=INDEX(KS_keb_p80,BR_NO)", G.FMT_T, "triliun Rp, P80"),
        ("Provinsi yakin", "=INDEX(KS_n_yakin,BR_NO)", "0", "confidence ≥ 80%"),
    ]
    for i, (j, f, fmt, ket) in enumerate(kartu):
        r = 7 + (i // 4) * 4
        c = 2 + (i % 4) * 3
        G.kartu(ws, r, c, c + 2, j, f, fmt, ket)

    # data grafik (kanan)
    cb = 16
    th = list(range(0, H + 1))
    G.bagian(ws, 4, cb, cb + 8, "Data grafik")
    kol = [("Tahun", None), ("Laju tanpa penambahan investasi", "KT_gd"), ("Laju dengan penambahan investasi", "KT_gs"),
           ("Sasaran", "KT_gt"), ("Tren PMA+PMDN", "KT_inv_tren"), ("Investasi dasar", "KT_inv_a1"),
           ("Investasi tambahan", "KT_inv_a2r"), ("Kebutuhan", "KT_inv_keb")]
    for j, (lb, _) in enumerate(kol):
        G.tulis(ws, 5, cb + j, lb, font=G.T_KECIL, align=G.TENGAH)
    for i, h in enumerate(th):
        r = 6 + i
        G.tulis(ws, r, cb, f"=TD+{h}", font=G.T_KECIL)
        for j, (_, nm) in enumerate(kol[1:], 1):
            G.tulis(ws, r, cb + j, f"=IFERROR(INDEX({nm},BR_NO,{h + 1}),NA())", font=G.T_KECIL, fmt=G.FMT_P)
    r_akhir = 6 + H
    kat = Reference(ws, min_col=cb, min_row=7, max_row=r_akhir)
    ch = _garis(ws, "Laju PDRB per tahun (%)", kat, [], "B16", lebar=17.5, tinggi=8)
    for j, warna, putus in ((1, WARNA["tanpa"], False), (2, WARNA["dengan"], False), (3, WARNA["sasaran"], True)):
        _tambah_seri(ch, ws, cb + j, 5, 7, r_akhir, warna, putus)
    ch2 = _batang(ws, "Investasi per tahun (triliun Rp)", Reference(ws, min_col=cb, min_row=7, max_row=r_akhir), [],
                  "H16", lebar=17.5, tinggi=8)
    for j, warna in ((4, WARNA["tanpa"]), (6, WARNA["tambahan"]), (7, WARNA["keb"])):
        _tambah_seri(ch2, ws, cb + j, 5, 7, r_akhir, warna, batang=True)

    # kontribusi
    r = 33
    G.bagian(ws, r, 2, 13, "Sumber pertumbuhan (poin persen per tahun, jalur dengan penambahan investasi)")
    kontr = [("Modal", "KS_k_modal"), ("Tenaga kerja", "KS_k_tk"), ("Tren TFP", "KS_k_tfp"),
             ("Bonus sektoral", "KS_k_sektoral"), ("Realokasi tenaga kerja", "KS_k_realokasi"),
             ("Determinan TFP", "KS_k_determinan"), ("Shock", "KS_k_kejutan")]
    G.tulis(ws, r + 1, 2, "Sumber", font=G.T_HEADER, fill=G.F_HEADER)
    G.tulis(ws, r + 1, 4, "pp", font=G.T_HEADER, fill=G.F_HEADER, align=G.TENGAH)
    ws.merge_cells(start_row=r + 1, start_column=2, end_row=r + 1, end_column=3)
    for i, (lb, nm) in enumerate(kontr):
        rr = r + 2 + i
        G.gabung(ws, rr, 2, 3, lb, align=G.KIRI)
        G.tulis(ws, rr, 4, f"=INDEX({nm},BR_NO)", fmt=G.FMT_P, border=G.GARIS)
    rr = r + 2 + len(kontr)
    G.gabung(ws, rr, 2, 3, "Jumlah", font=G.T_TEBAL)
    G.tulis(ws, rr, 4, f"=SUM(D{r + 2}:D{rr - 1})", font=G.T_TEBAL, fmt=G.FMT_P)
    ws.conditional_formatting.add(f"D{r + 2}:D{rr - 1}", DataBarRule(start_type="min", end_type="max", color=G.BIRU))
    chk = _batang(ws, None, Reference(ws, min_col=2, min_row=r + 2, max_row=rr - 1), [], f"F{r + 1}", lebar=15.5,
                  tinggi=5.2, arah="bar")
    _tambah_seri(chk, ws, 4, None, r + 2, rr - 1, WARNA["dengan"], batang=True)
    chk.legend = None
    G.lebar(ws, [2] + [10.5] * 12 + [2, 2] + [10] * 8)
    return ws


def _tambah_seri(ch, ws, c, r_judul, r0, r1, warna, putus=False, batang=False, judul=None):
    from openpyxl.chart import Series
    ref = Reference(ws, min_col=c, min_row=r0, max_row=r1)
    s = Series(ref, title_from_data=False)
    if r_judul:
        from openpyxl.chart.series import SeriesLabel
        from openpyxl.chart.data_source import StrRef
        s.tx = SeriesLabel(strRef=StrRef(f"'{ws.title}'!${G.kol(c)}${r_judul}"))
    elif judul:
        from openpyxl.chart.series import SeriesLabel
        s.tx = SeriesLabel(v=judul)
    if batang:
        s.graphicalProperties.solidFill = warna
        s.graphicalProperties.line.solidFill = warna
    else:
        s.smooth = False
        s.graphicalProperties.line.solidFill = warna
        s.graphicalProperties.line.width = 28000
        if putus:
            s.graphicalProperties.line.dashStyle = "dash"
        s.marker.symbol = "none"
    ch.series.append(s)
    return s


# ------------------------------------------------------------------ Hasil
METRIK_PETA = [("Laju dengan penambahan investasi (%)", 5), ("Laju tanpa penambahan investasi (%)", 4),
               ("Sasaran (%)", 6), ("Confidence", 7), ("Kebutuhan tambahan (T)", 8), ("Investasi tambahan (T)", 9),
               ("Selisih (T)", 10)]


def hasil(wb, ctx, H):
    ws = wb.create_sheet("Hasil")
    G.warna_tab(ws, G.ORANYE)
    G.pita(ws, "Hasil skenario", "Rincian per provinsi, per tahun, dan per sektor")
    _pilih(wb, ws, 4, 3, 7, "HS_PILIH", "=BR_PILIH")
    G.tulis(ws, 4, 9, "No", font=G.T_KECIL)
    G.tulis(ws, 4, 10, "=MATCH(HS_PILIH,SK_NAMA,0)", font=G.T_KECIL)
    G.nama(wb, "HS_NO", "Hasil", "$J$4")
    prov = PROVINSI(ctx.kode)
    P = len(prov)

    # ---- tabel provinsi
    r0 = 6
    G.bagian(ws, r0, 1, 11, "Per provinsi")
    judul = ["Kode", "Provinsi", "Pulau", "Laju tanpa penambahan investasi (%)", "Laju dengan penambahan investasi (%)",
             "Sasaran (%)", "Confidence", "Kebutuhan tambahan (T)", "Investasi tambahan (T)", "Selisih (T)",
             "Bobot investasi tambahan"]
    _tabel_kepala(ws, r0 + 1, 1, judul, tinggi=44)
    sumber = ["g_dasar", "g_skenario", "g_sasaran", "prob", "keb_kum", "a2_kum", "selisih", "bobot"]
    fmt = [G.FMT_P, G.FMT_P, G.FMT_P, G.FMT_PCT, G.FMT_T, G.FMT_T, G.FMT_T, G.FMT_PCT1]
    for i, (kd, nm, pl) in enumerate(prov):
        r = r0 + 2 + i
        G.tulis(ws, r, 1, kd, font=G.T_KECIL)
        G.tulis(ws, r, 2, nm)
        G.tulis(ws, r, 3, pl, font=G.T_KECIL)
        for j, (k, f) in enumerate(zip(sumber, fmt)):
            G.tulis(ws, r, 4 + j, f"=INDEX(KP_{k},(HS_NO-1)*{P}+{i + 1})", fmt=f, border=G.GARIS)
    rp1 = r0 + 1 + P
    rn = rp1 + 1
    G.tulis(ws, rn, 2, "Nasional", font=G.T_TEBAL)
    for c, f, fm in ((4, "=INDEX(KS_g_rata_dasar,HS_NO)", G.FMT_P), (5, "=INDEX(KS_g_rata_skenario,HS_NO)", G.FMT_P),
                     (6, "=INDEX(KS_g_rata_sasaran,HS_NO)", G.FMT_P), (7, "=INDEX(KS_prob_nas,HS_NO)", G.FMT_PCT),
                     (8, f"=SUM(H{r0 + 2}:H{rp1})", G.FMT_T), (9, f"=SUM(I{r0 + 2}:I{rp1})", G.FMT_T),
                     (10, f"=SUM(J{r0 + 2}:J{rp1})", G.FMT_T), (11, f"=SUM(K{r0 + 2}:K{rp1})", G.FMT_PCT)):
        G.tulis(ws, rn, c, f, font=G.T_TEBAL, fmt=fm, fill=G.F_BAGIAN)
    for c in (1, 2, 3):
        ws.cell(row=rn, column=c).fill = G.F_BAGIAN
    rr = f"{r0 + 2}:{rp1}"
    a, b = rr.split(":")
    ws.conditional_formatting.add(f"E{a}:E{b}", ColorScaleRule(start_type="min", start_color="FDE9D9",
                                                                mid_type="percentile", mid_value=50, mid_color="FFFFFF",
                                                                end_type="max", end_color="C6E0F5"))
    ws.conditional_formatting.add(f"G{a}:G{b}", CellIsRule(operator="greaterThanOrEqual", formula=["0.8"],
                                                           font=Font(color=G.HIJAU, bold=True)))
    ws.conditional_formatting.add(f"G{a}:G{b}", CellIsRule(operator="lessThan", formula=["0.5"],
                                                           font=Font(color=G.MERAH)))
    for col, warna in (("H", G.MERAH), ("I", G.HIJAU)):
        ws.conditional_formatting.add(f"{col}{a}:{col}{b}", DataBarRule(start_type="num", start_value=0,
                                                                        end_type="max", color=warna))

    # ---- peta petak
    cm = 13
    G.bagian(ws, r0, cm, cm + 16, "Peta petak")
    G.tulis(ws, r0 + 1, cm, "Besaran", font=G.T_TEBAL)
    G.gabung(ws, r0 + 1, cm + 2, cm + 8, METRIK_PETA[0][0], font=G.T_TEBAL, fill=G.F_ISIAN)
    validasi(ws, '"' + ",".join(m for m, _ in METRIK_PETA) + '"', f"{G.kol(cm + 2)}{r0 + 1}")
    G.nama(wb, "HS_METRIK", "Hasil", f"${G.kol(cm + 2)}${r0 + 1}")
    # kolom indeks besaran
    pilihan = ",".join(f'"{m}"' for m, _ in METRIK_PETA)
    G.tulis(ws, r0 + 1, cm + 10, f"=MATCH(HS_METRIK,{{{pilihan}}},0)", font=G.T_KECIL)
    G.tulis(ws, r0 + 1, cm + 11, f"=CHOOSE({G.kol(cm + 10)}{r0 + 1},{','.join(str(c) for _, c in METRIK_PETA)})",
            font=G.T_KECIL)
    kolom_m = f"${G.kol(cm + 11)}${r0 + 1}"
    rm = r0 + 3
    nilai_sel = []
    for i, (kd, nm, pl) in enumerate(prov):
        pr, pc = PETAK[kd]
        r_lbl = rm + (pr - 1) * 2
        c = cm + pc - 1
        G.tulis(ws, r_lbl, c, SINGKAT_PROV.get(kd, nm[:7]), font=T_KECIL_HITAM, fill=G.F_BAGIAN, align=G.TENGAH)
        rumus = f"=INDEX($A${r0 + 2}:$K${rp1},{i + 1},{kolom_m})"
        G.tulis(ws, r_lbl + 1, c, rumus, font=Font(size=9, bold=True), align=G.TENGAH, fmt="0.0;-0.0")
        nilai_sel.append(f"{G.kol(c)}{r_lbl + 1}")
    ws.conditional_formatting.add(" ".join(nilai_sel), ColorScaleRule(
        start_type="min", start_color="F8696B", mid_type="percentile", mid_value=50, mid_color="FFEB84",
        end_type="max", end_color="63BE7B"))
    for c in range(cm, cm + 17):
        ws.column_dimensions[G.kol(c)].width = 7.2
    r_bawah_peta = rm + 16
    G.tulis(ws, r_bawah_peta, cm, "Merah = nilai terendah, hijau = tertinggi di antara provinsi. Confidence ditampilkan "
                                  "sebagai pecahan (0-1).", font=G.T_KECIL)

    # ---- per tahun (di bawah peta)
    rt = r_bawah_peta + 2
    G.bagian(ws, rt, cm, cm + 16, "Per tahun (nasional)")
    kol = [("Tahun", None, "0"), ("PDRB tanpa (T)", "KT_Yd", G.FMT_T), ("PDRB dengan (T)", "KT_Ys", G.FMT_T),
           ("PDRB sasaran (T)", "KT_Yt", G.FMT_T), ("Laju tanpa (%)", "KT_gd", G.FMT_P),
           ("Laju dengan (%)", "KT_gs", G.FMT_P), ("Laju sasaran (%)", "KT_gt", G.FMT_P),
           ("Tren PMA+PMDN (T)", "KT_inv_tren", G.FMT_T), ("Investasi dasar (T)", "KT_inv_a1", G.FMT_T),
           ("Investasi tambahan (T)", "KT_inv_a2r", G.FMT_T), ("Kebutuhan (T)", "KT_inv_keb", G.FMT_T),
           ("Indeks TFP", "KT_tfp_s", G.FMT_P1), ("PDRB dengan P10 (T)", "KT_Ys_lo", G.FMT_T),
           ("PDRB dengan P90 (T)", "KT_Ys_hi", G.FMT_T)]
    _tabel_kepala(ws, rt + 1, cm, [k for k, _, _ in kol], tinggi=44)
    for i in range(H + 1):
        r = rt + 2 + i
        G.tulis(ws, r, cm, f"=TD+{i}", font=G.T_TEBAL)
        for j, (_, nm, fm) in enumerate(kol[1:], 1):
            bagi = "/1000" if nm in ("KT_Yd", "KT_Ys", "KT_Yt", "KT_Ys_lo", "KT_Ys_hi") else ""
            G.tulis(ws, r, cm + j, f'=IFERROR(INDEX({nm},HS_NO,{i + 1}){bagi},"")', fmt=fm, border=G.GARIS)
    r_akhir = rt + 2 + H
    ch = _garis(ws, "PDRB nasional (triliun Rp) dan rentang P10-P90", None, [], f"{G.kol(cm)}{r_akhir + 2}",
                lebar=20, tinggi=7.5)
    for c, warna, putus in ((cm + 12, "9DC3E6", True), (cm + 13, "9DC3E6", True), (cm + 1, WARNA["tanpa"], False),
                            (cm + 2, WARNA["dengan"], False), (cm + 3, WARNA["sasaran"], True)):
        _tambah_seri(ch, ws, c, rt + 1, rt + 2, r_akhir, warna, putus)
    ch.set_categories(Reference(ws, min_col=cm, min_row=rt + 2, max_row=r_akhir))
    ch.y_axis.number_format = "#,##0"
    ch.y_axis.scaling.min = None

    # ---- sektor (di bawah tabel provinsi)
    rs = rn + 3
    G.bagian(ws, rs, 1, 11, "Arah sektor (triliun Rp, kumulatif)")
    _tabel_kepala(ws, rs + 1, 1, ["Kode", "Sektor", "Kelompok", "Kebutuhan tambahan", "Investasi tambahan"])
    for j, (s, nm, kl) in enumerate(SEKTOR):
        r = rs + 2 + j
        G.tulis(ws, r, 1, s, font=G.T_KECIL)
        G.tulis(ws, r, 2, nm)
        G.tulis(ws, r, 3, kl, font=G.T_KECIL)
        G.tulis(ws, r, 4, f"=INDEX(KK_keb,(HS_NO-1)*{len(SEKTOR)}+{j + 1})", fmt=G.FMT_T1, border=G.GARIS)
        G.tulis(ws, r, 5, f"=INDEX(KK_a2,(HS_NO-1)*{len(SEKTOR)}+{j + 1})", fmt=G.FMT_T1, border=G.GARIS)
    rs1 = rs + 1 + len(SEKTOR)
    ws.conditional_formatting.add(f"D{rs + 2}:D{rs1}", DataBarRule(start_type="num", start_value=0, end_type="max",
                                                                   color=G.MERAH))
    ws.conditional_formatting.add(f"E{rs + 2}:E{rs1}", DataBarRule(start_type="num", start_value=0, end_type="max",
                                                                   color=G.HIJAU))
    # kelompok
    G.header(ws, rs + 1, 7, ["Kelompok", "", "Pangsa historis", "Pangsa investasi tambahan", "Bonus TFP (pp)"],
             tinggi=30)
    ws.merge_cells(start_row=rs + 1, start_column=7, end_row=rs + 1, end_column=8)
    for j, (g, nm) in enumerate(KELOMPOK):
        r = rs + 2 + j
        G.gabung(ws, r, 7, 8, nm, align=G.KIRI_BUNGKUS)
        ws.row_dimensions[r].height = 26
        for c, src, fm in ((9, "KG_hist", G.FMT_PCT1), (10, "KG_a2", G.FMT_PCT1), (11, "KG_bonus", "0.000")):
            G.tulis(ws, r, c, f"=INDEX({src},(HS_NO-1)*{len(KEL)}+{j + 1})", fmt=fm, border=G.GARIS)

    G.lebar(ws, [6, 24, 11, 11, 11, 11, 11, 11, 11, 11, 11, 2])
    ws.freeze_panes = "A6"
    return ws


# ------------------------------------------------------------------ Perbandingan
KOLOM_BANDING = [("Laju tanpa penambahan investasi (%)", "g_rata_dasar", G.FMT_P),
                 ("Laju dengan penambahan investasi (%)", "g_rata_skenario", G.FMT_P),
                 ("Sasaran (%)", "g_rata_sasaran", G.FMT_P), ("Confidence", "prob_nas", G.FMT_PCT),
                 ("Laju P10 (%)", "p10", G.FMT_P), ("Laju P90 (%)", "p90", G.FMT_P),
                 ("Investasi tambahan (T)", "a2_kum", G.FMT_T), ("Kebutuhan tambahan (T)", "keb_kum", G.FMT_T),
                 ("Kebutuhan batas aman (T)", "keb_p80", G.FMT_T), ("Selisih (T)", "selisih", G.FMT_T),
                 ("Indeks TFP", "tfp_T_skenario", G.FMT_P1), ("Tambahan PDRB tahun target (T)", "pdrb_tambahan_T", G.FMT_T)]


def perbandingan(wb, ctx, H):
    ws = wb.create_sheet("Perbandingan")
    G.warna_tab(ws, G.ORANYE)
    G.pita(ws, "Perbandingan skenario", "Slot bertanda \"ya\" pada baris Tampil di Perbandingan (lembar Skenario)")
    ns = len(ctx.slot)
    n_tampil = sum(1 for s in ctx.slot if s.nilai.get("tampil", "ya") == "ya")
    # pembantu urutan
    cb = 18 + len(KOLOM_BANDING)
    G.tulis(ws, 4, cb, "Urutan", font=G.T_KECIL)
    for i in range(ns):
        G.tulis(ws, 5 + i, cb, f'=IF(INDEX(KS_tampil,{i + 1})="ya",COUNTIF(INDEX(KS_tampil,1):INDEX(KS_tampil,{i + 1}),'
                               f'"ya"),"")', font=G.T_KECIL)
    urut = f"${G.kol(cb)}$5:${G.kol(cb)}${4 + ns}"
    r0 = 4
    _tabel_kepala(ws, r0, 1, ["Skenario", "Singkat"] + [k for k, _, _ in KOLOM_BANDING], tinggi=44)
    for k in range(ns):
        r = r0 + 1 + k
        G.tulis(ws, r, cb + 1, f"=IFERROR(MATCH({k + 1},{urut},0),\"\")", font=G.T_KECIL)
        no = f"${G.kol(cb + 1)}{r}"
        G.tulis(ws, r, 1, f'=IF({no}="","",INDEX(KS_nama,{no}))', align=G.KIRI_BUNGKUS)
        G.tulis(ws, r, 2, f'=IF({no}="","",INDEX(KS_singkat,{no}))', font=G.T_TEBAL)
        for j, (_, nm, fm) in enumerate(KOLOM_BANDING):
            G.tulis(ws, r, 3 + j, f'=IF({no}="","",INDEX(KS_{nm},{no}))', fmt=fm, border=G.GARIS)
        ws.row_dimensions[r].height = 28
    r1 = r0 + ns
    a, b = r0 + 1, r1
    for j, (_, nm, _) in enumerate(KOLOM_BANDING):
        L = G.kol(3 + j)
        if nm in ("a2_kum", "keb_kum", "keb_p80"):
            ws.conditional_formatting.add(f"{L}{a}:{L}{b}", DataBarRule(start_type="num", start_value=0,
                                                                        end_type="max", color=G.BIRU))
        elif nm == "g_rata_skenario":
            ws.conditional_formatting.add(f"{L}{a}:{L}{b}", ColorScaleRule(
                start_type="min", start_color="FDE9D9", end_type="max", end_color="C6E0F5"))
    ws.conditional_formatting.add(f"F{a}:F{b}", CellIsRule(operator="greaterThanOrEqual", formula=["0.8"],
                                                           font=Font(color=G.HIJAU, bold=True)))

    # grafik
    rg = r1 + 2
    r_kat = r0 + n_tampil
    kat = Reference(ws, min_col=2, min_row=r0 + 1, max_row=r_kat)
    ch = _batang(ws, "Laju rata-rata per tahun (%)", kat, [], f"A{rg}", lebar=19, tinggi=8)
    for c, warna in ((3, WARNA["tanpa"]), (4, WARNA["dengan"]), (5, WARNA["sasaran"])):
        _tambah_seri(ch, ws, c, r0, r0 + 1, r_kat, warna, batang=True)
    ch2 = _batang(ws, "Investasi tambahan dan kebutuhan (triliun Rp)", kat, [], f"H{rg}", lebar=19, tinggi=8)
    for c, warna in ((9, WARNA["tambahan"]), (10, WARNA["keb"]), (11, "F4B183")):
        _tambah_seri(ch2, ws, c, r0, r0 + 1, r_kat, warna, batang=True)

    # laju per tahun
    ry = rg + 18
    G.bagian(ws, ry, 1, 3 + H, "Laju dengan penambahan investasi per tahun (%)")
    _tabel_kepala(ws, ry + 1, 1, ["Skenario", "Singkat"] + [f"=TD+{h}" for h in range(1, H + 1)], tinggi=22)
    for k in range(ns):
        r = ry + 2 + k
        no = f"${G.kol(cb + 1)}{r0 + 1 + k}"
        G.tulis(ws, r, 1, f'=IF({no}="","",INDEX(KS_nama,{no}))', font=G.T_KECIL)
        G.tulis(ws, r, 2, f'=IF({no}="","",INDEX(KS_singkat,{no}))', font=G.T_TEBAL)
        for h in range(1, H + 1):
            G.tulis(ws, r, 2 + h, f'=IF({no}="","",INDEX(KT_gs,{no},{h + 1}))', fmt=G.FMT_P, border=G.GARIS)
    ws.conditional_formatting.add(f"C{ry + 2}:{G.kol(2 + H)}{ry + 1 + ns}", ColorScaleRule(
        start_type="min", start_color="FDE9D9", mid_type="percentile", mid_value=50, mid_color="FFFFFF",
        end_type="max", end_color="C6E0F5"))
    G.lebar(ws, [30, 13] + [12] * len(KOLOM_BANDING))
    ws.freeze_panes = "C5"
    return ws


# ------------------------------------------------------------------ Jelajah
def jelajah(wb, ctx, mentah):
    ws = wb.create_sheet("Jelajah")
    G.warna_tab(ws, G.HIJAU)
    G.pita(ws, "Jelajah data", "Nilai satu variabel per provinsi atau per tahun, langsung dari lembar Data")
    prov = PROVINSI(ctx.kode)
    P = len(prov)
    import datapanel.variabel as V
    lb0 = f"{V.label('PDRB_ADHK')} ({V.satuan('PDRB_ADHK')})"

    # ---- per provinsi
    G.bagian(ws, 4, 1, 8, "Per provinsi")
    G.tulis(ws, 5, 1, "Variabel", font=G.T_TEBAL)
    G.gabung(ws, 5, 2, 5, lb0, font=G.T_TEBAL, fill=G.F_ISIAN)
    validasi(ws, "=L_var_label", "B5")
    G.tulis(ws, 6, 1, "Tahun", font=G.T_TEBAL)
    G.tulis(ws, 6, 2, "=TD", fill=G.F_ISIAN, font=G.T_TEBAL, align=G.TENGAH)
    G.tulis(ws, 5, 7, "=MATCH(B5,L_var_label,0)", font=G.T_KECIL)
    G.nama(wb, "JL_J", "Jelajah", "$G$5")
    _tabel_kepala(ws, 8, 1, ["Peringkat", "Provinsi", "Pulau", "Nilai", "Pangsa", "", "Urut", ""])
    for i, (kd, nm, pl) in enumerate(prov):
        r = 9 + i
        # tabel bantu (tak terurut) di kolom K:N
        G.tulis(ws, r, 11, kd, font=G.T_KECIL)
        G.tulis(ws, r, 12, nm, font=G.T_KECIL)
        G.tulis(ws, r, 13, pl, font=G.T_KECIL)
        ada = f"COUNTIFS(D_kode,$K{r},D_tahun,$B$6,INDEX(D_ISI,0,JL_J),\">-1E+300\")"
        G.tulis(ws, r, 14, f'=IF({ada}=0,"",SUMIFS(INDEX(D_ISI,0,JL_J),D_kode,$K{r},D_tahun,$B$6))', font=G.T_KECIL,
                fmt=G.FMT_T)
        G.tulis(ws, r, 15, f'=IF(N{r}="","",N{r}+ROW()*1E-9)', font=G.T_KECIL)
        # terurut
        G.tulis(ws, r, 1, i + 1, font=G.T_KECIL, align=G.TENGAH)
        k = f"IFERROR(MATCH(LARGE($O$9:$O${8 + P},{i + 1}),$O$9:$O${8 + P},0),\"\")"
        G.tulis(ws, r, 7, f"={k}", font=G.T_KECIL)
        G.tulis(ws, r, 2, f'=IF($G{r}="","",INDEX($L$9:$L${8 + P},$G{r}))')
        G.tulis(ws, r, 3, f'=IF($G{r}="","",INDEX($M$9:$M${8 + P},$G{r}))', font=G.T_KECIL)
        G.tulis(ws, r, 4, f'=IF($G{r}="","",INDEX($N$9:$N${8 + P},$G{r}))', fmt="#,##0.00", border=G.GARIS)
        G.tulis(ws, r, 5, f'=IF($G{r}="","",D{r}/SUM($D$9:$D${8 + P}))', fmt=G.FMT_PCT1, border=G.GARIS)
    ws.conditional_formatting.add(f"D9:D{8 + P}", DataBarRule(start_type="min", end_type="max", color=G.HIJAU))
    ch = _batang(ws, "Per provinsi (terurut)", Reference(ws, min_col=2, min_row=9, max_row=8 + P), [], "Q4",
                 lebar=15, tinggi=19, arah="bar")
    _tambah_seri(ch, ws, 4, None, 9, 8 + P, G.HIJAU, batang=True, judul="Nilai")
    ch.legend = None
    ch.x_axis.scaling.orientation = "maxMin"
    ch.gapWidth = 30

    # ---- per tahun
    rt = 9 + P + 2
    G.bagian(ws, rt, 1, 8, "Per tahun")
    G.tulis(ws, rt + 1, 1, "Provinsi", font=G.T_TEBAL)
    G.gabung(ws, rt + 1, 2, 5, prov[0][1] if prov else "", font=G.T_TEBAL, fill=G.F_ISIAN)
    validasi(ws, "=REF_nama", f"B{rt + 1}")
    G.tulis(ws, rt + 1, 7, f"=INDEX(REF_kode,MATCH(B{rt + 1},REF_nama,0))", font=G.T_KECIL)
    G.tulis(ws, rt + 2, 1, "Variabel", font=G.T_TEBAL)
    G.gabung(ws, rt + 2, 2, 5, lb0, font=G.T_TEBAL, fill=G.F_ISIAN)
    validasi(ws, "=L_var_label", f"B{rt + 2}")
    G.tulis(ws, rt + 2, 7, f"=MATCH(B{rt + 2},L_var_label,0)", font=G.T_KECIL)
    kd, jj = f"$G${rt + 1}", f"$G${rt + 2}"
    _tabel_kepala(ws, rt + 4, 1, ["Tahun", "Provinsi", "Laju (%)", "Nasional", "Pangsa"])
    n_th = 21
    for i in range(n_th):
        r = rt + 5 + i
        G.tulis(ws, r, 1, f"=MIN(D_tahun)+{i}", font=G.T_TEBAL)
        ada = f"COUNTIFS(D_kode,{kd},D_tahun,$A{r},INDEX(D_ISI,0,{jj}),\">-1E+300\")"
        G.tulis(ws, r, 2, f'=IF({ada}=0,NA(),SUMIFS(INDEX(D_ISI,0,{jj}),D_kode,{kd},D_tahun,$A{r}))', fmt="#,##0.00",
                border=G.GARIS)
        G.tulis(ws, r, 3, "" if i == 0 else f'=IFERROR((B{r}/B{r - 1}-1)*100,"")', fmt=G.FMT_P, border=G.GARIS)
        G.tulis(ws, r, 4, f'=IF(COUNTIFS(D_tahun,$A{r},INDEX(D_ISI,0,{jj}),">-1E+300")=0,NA(),'
                          f'SUMIFS(INDEX(D_ISI,0,{jj}),D_tahun,$A{r}))', fmt="#,##0", border=G.GARIS)
        G.tulis(ws, r, 5, f'=IFERROR(B{r}/D{r},"")', fmt=G.FMT_PCT1, border=G.GARIS)
    ws.conditional_formatting.add(f"B{rt + 5}:E{rt + 4 + n_th}", FormulaRule(formula=[f"ISNA(B{rt + 5})"],
                                                                             font=Font(color="FFFFFF")))
    ch2 = _garis(ws, "Per tahun", None, [], f"Q{rt}", lebar=15, tinggi=7)
    _tambah_seri(ch2, ws, 2, None, rt + 5, rt + 4 + n_th, G.HIJAU, judul="Provinsi")
    ch2.set_categories(Reference(ws, min_col=1, min_row=rt + 5, max_row=rt + 4 + n_th))
    ch2.legend = None
    G.tulis(ws, rt + 4 + n_th + 1, 1, "Nasional = jumlah semua provinsi; bermakna untuk variabel uang dan jiwa.",
            font=G.T_KECIL)
    G.lebar(ws, [10, 24, 12, 14, 10, 2, 6, 2, 2, 2, 6, 18, 10, 12, 8])
    for L in ("G", "K", "L", "M", "N", "O"):
        ws.column_dimensions[L].hidden = True
    return ws


# ------------------------------------------------------------------ Kelengkapan
def kelengkapan(wb, ctx, mentah):
    import datapanel.variabel as V
    ws = wb.create_sheet("Kelengkapan")
    G.warna_tab(ws, G.HIJAU)
    G.pita(ws, "Kelengkapan data", "Persentase provinsi yang punya nilai, per variabel dan tahun")
    n_th = 16
    _tabel_kepala(ws, 4, 1, ["Variabel", "Satuan"] + [f"=MIN(D_tahun)+{i}" for i in range(n_th)] + ["Terakhir lengkap"],
                  tinggi=22)
    for j, k in enumerate(mentah):
        r = 5 + j
        G.tulis(ws, r, 1, V.label(k))
        G.tulis(ws, r, 2, V.satuan(k), font=G.T_KECIL)
        for i in range(n_th):
            c = 3 + i
            y = f"{G.kol(c)}$4"
            G.tulis(ws, r, c, f'=IF(COUNTIF(D_tahun,{y})=0,"",COUNTIFS(D_tahun,{y},INDEX(D_ISI,0,{j + 1}),'
                              f'">-1E+300")/N_PROV)', fmt=G.FMT_PCT, align=G.TENGAH)
        rng = f"$C{r}:${G.kol(2 + n_th)}{r}"
        G.tulis(ws, r, 3 + n_th, f'=IFERROR(LOOKUP(2,1/(ISNUMBER({rng})*({rng}>=1)),$C$4:${G.kol(2 + n_th)}$4),"")',
                font=G.T_TEBAL,
                align=G.TENGAH)
    r1 = 4 + len(mentah)
    ws.conditional_formatting.add(f"C5:{G.kol(2 + n_th)}{r1}", ColorScaleRule(
        start_type="num", start_value=0, start_color="F8696B", mid_type="num", mid_value=0.5, mid_color="FFEB84",
        end_type="num", end_value=1, end_color="63BE7B"))
    G.lebar(ws, [38, 10] + [6.5] * n_th + [10])
    ws.freeze_panes = "C5"
    return ws


# ------------------------------------------------------------------ Pivot
def pivot(wb, ctx, kump):
    from openpyxl.pivot.cache import CacheDefinition, CacheField, CacheSource, SharedItems, WorksheetSource
    from openpyxl.pivot.record import Text
    from openpyxl.pivot.table import (DataField, FieldItem, Location, PageField, PivotField, PivotTableStyle,
                                      RowColField, TableDefinition)

    ws = wb.create_sheet("Pivot")
    G.warna_tab(ws, G.BIRU)
    G.pita(ws, "Pivot", "Dari kumpulan hasil semua slot. Segarkan dengan Data > Refresh All setelah mengubah asumsi; "
                        "susunan bebas diubah lewat PivotTable Fields.")
    prov = PROVINSI(ctx.kode)
    singkat = [s.singkat for s in ctx.slot]
    nama = [s.nama for s in ctx.slot]

    def teks(xs):
        xs = list(dict.fromkeys(xs))
        return SharedItems(_fields=[Text(v=x) for x in xs], count=len(xs)), len(xs)

    def angka():
        return SharedItems(containsSemiMixedTypes=False, containsString=False, containsNumber=True)

    def cache(ref, kolom, teks_kolom):
        fields = []
        for k in kolom:
            if k in teks_kolom:
                si, _ = teks(teks_kolom[k])
                fields.append(CacheField(name=k, sharedItems=si))
            else:
                fields.append(CacheField(name=k, sharedItems=angka()))
        return CacheDefinition(refreshOnLoad=True, saveData=False, recordCount=0,
                               cacheSource=CacheSource(type="worksheet",
                                                       worksheetSource=WorksheetSource(ref=ref, sheet="Hitung")),
                               cacheFields=fields)

    def bidang(kolom, teks_kolom, sumbu, data):
        out = []
        for k in kolom:
            if k in sumbu:
                n = len(dict.fromkeys(teks_kolom[k]))
                out.append(PivotField(axis=sumbu[k], showAll=False,
                                      items=[FieldItem(x=i) for i in range(n)] + [FieldItem(t="default")]))
            elif k in data:
                out.append(PivotField(dataField=True, showAll=False))
            else:
                out.append(PivotField(showAll=False))
        return out

    def tabel(nama_pt, cache_id, cd, kolom, teks_kolom, baris, halaman, nilai, lokasi, kol=None):
        sumbu = {k: "axisRow" for k in baris} | {k: "axisPage" for k in halaman} | ({kol: "axisCol"} if kol else {})
        ix = {k: i for i, k in enumerate(kolom)}
        pt = TableDefinition(
            name=nama_pt, cacheId=cache_id, dataCaption="Nilai", updatedVersion=6, minRefreshableVersion=3,
            createdVersion=6, outline=True, outlineData=True, compact=True, compactData=True, indent=0,
            location=Location(ref=lokasi, firstHeaderRow=1, firstDataRow=2, firstDataCol=1,
                              rowPageCount=len(halaman) or None, colPageCount=1 if halaman else None),
            pivotFields=bidang(kolom, teks_kolom, sumbu, {k for _, k, _ in nilai}),
            rowFields=[RowColField(x=ix[k]) for k in baris],
            colFields=[RowColField(x=ix[kol])] if kol else ([RowColField(x=-2)] if len(nilai) > 1 else []),
            pageFields=[PageField(fld=ix[k], hier=-1) for k in halaman],
            dataFields=[DataField(name=nm, fld=ix[k], subtotal=fn, baseField=0, baseItem=0) for nm, k, fn in nilai],
            pivotTableStyleInfo=PivotTableStyle(name="PivotStyleMedium2", showRowHeaders=True, showColHeaders=True,
                                                showRowStripes=False, showColStripes=False, showLastColumn=True),
        )
        if halaman:
            pt.pageFields = [PageField(fld=ix[k], hier=-1) for k in halaman]
        pt.cache = cd
        ws.add_pivot(pt)

    # sumber 1: hasil provinsi
    rh, rp1, nk = kump["prov"]
    from .hitung import PROV_KUMPUL
    kolom1 = ["No", "Skenario", "Singkat", "Kode", "Provinsi", "Pulau", "Tampil"] + \
             [JUDUL_PROV_KUMPUL[k] for k in PROV_KUMPUL]
    tk1 = {"Skenario": nama, "Singkat": singkat, "Provinsi": [p[1] for p in prov],
           "Pulau": [p[2] for p in prov], "Tampil": ["ya", "tidak"]}
    ref1 = f"A{rh}:{G.kol(nk)}{rp1}"
    c1 = cache(ref1, kolom1, tk1)
    G.bagian(ws, 4, 1, 6, "Investasi tambahan dan kebutuhan per pulau dan provinsi")
    tabel("PivotProvinsi", 1, c1, kolom1, tk1, ["Pulau", "Provinsi"], ["Skenario"],
          [("Jumlah kebutuhan tambahan (T)", JUDUL_PROV_KUMPUL["keb_kum"], "sum"),
           ("Jumlah investasi tambahan (T)", JUDUL_PROV_KUMPUL["a2_kum"], "sum"),
           ("Jumlah selisih (T)", JUDUL_PROV_KUMPUL["selisih"], "sum")], "A8:D52")

    G.bagian(ws, 4, 8, 20, "Investasi tambahan per skenario dan pulau (T)")
    tabel("PivotSkenarioPulau", 1, c1, kolom1, tk1, ["Singkat"], [],
          [("Investasi tambahan per pulau", JUDUL_PROV_KUMPUL["a2_kum"], "sum")], "H6:O22", kol="Pulau")

    # sumber 2: arah sektor
    rh2, rs1, nk2 = kump["sektor"]
    kolom2 = ["No", "Skenario", "Singkat", "Sektor", "Nama sektor", "Kelompok", "Kebutuhan (T)",
              "Investasi tambahan (T)"]
    tk2 = {"Skenario": nama, "Singkat": singkat, "Sektor": [s for s, _, _ in SEKTOR],
           "Nama sektor": [n for _, n, _ in SEKTOR], "Kelompok": [k for _, _, k in SEKTOR]}
    c2 = cache(f"A{rh2}:{G.kol(nk2)}{rs1}", kolom2, tk2)
    G.bagian(ws, 26, 8, 20, "Arah sektor (T)")
    tabel("PivotSektor", 2, c2, kolom2, tk2, ["Kelompok", "Nama sektor"], ["Skenario"],
          [("Jumlah kebutuhan (T)", "Kebutuhan (T)", "sum"), ("Jumlah investasi tambahan (T)", "Investasi tambahan (T)", "sum")],
          "H30:J55")
    G.lebar(ws, [30, 14, 14, 14, 2, 2, 2, 30] + [12] * 10)
    return ws


# ------------------------------------------------------------------ semua
def _cetak(ws, tegak=False):
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 1
    ws.page_setup.orientation = "portrait" if tegak else "landscape"
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.print_options.horizontalCentered = True
    ws.page_margins.left = ws.page_margins.right = 0.4
    ws.page_margins.top = ws.page_margins.bottom = 0.5


def semua(wb, ctx, rk, peta, kump, tata_data):
    H = max(1, min(ctx.umum["tahun_target"] - ctx.umum["tahun_dasar"], MAKS_H))
    _cetak(petunjuk(wb, ctx), tegak=True)
    _cetak(beranda(wb, ctx, H))
    _cetak(hasil(wb, ctx, H))
    _cetak(perbandingan(wb, ctx, H))
    _cetak(jelajah(wb, ctx, tata_data.mentah))
    _cetak(pivot(wb, ctx, kump))
    _cetak(kelengkapan(wb, ctx, tata_data.mentah))
