"""Workbook skenario: hasil lengkap, kalkulator berumus, dan lembar asumsi provinsi."""

import io

from openpyxl import Workbook, load_workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.comments import Comment
from openpyxl.formatting.rule import ColorScaleRule, DataBarRule
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.worksheet.datavalidation import DataValidation

from datapanel import gaya_excel as G
from datapanel.referensi import KODE_SEKTOR, NAMA_KELOMPOK, NAMA_PROVINSI, NAMA_SEKTOR, PULAU_PROVINSI

KOLOM_ASUMSI = [
    ("sasaran", "Sasaran pertumbuhan (%/thn)", -10, 30),
    ("tfp", "Laju TFP (%/thn)", -10, 15),
    ("tk", "Laju tenaga kerja (%/thn)", -10, 15),
    ("bobot_a2", "Bobot alokasi investasi tambahan (bebas, dinormalkan)", 0, 1e9),
    ("primer", "Komposisi investasi tambahan: primer", 0, 1e9),
    ("sekunder", "Komposisi investasi tambahan: sekunder", 0, 1e9),
    ("tva", "Komposisi investasi tambahan: jasa bernilai tambah", 0, 1e9),
    ("tlain", "Komposisi investasi tambahan: tersier lainnya", 0, 1e9),
]


def _simpan(wb):
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _nama(wb, nama, ref):
    wb.defined_names[nama] = DefinedName(nama, attr_text=ref)


def _teks_papua(meta):
    pp = meta.get("pangsa_papua", {})
    th = pp.get("tahun_pdrb") or []
    rentang = f"{th[0]}-{th[-1]}" if th else "tahun pemekaran"
    return (f"Papua Barat dan Papua dipecah menjadi enam provinsi menurut pangsa data {rentang}. "
            "Sebelum tahun pertama pangsa teramati dipakai pangsa tahun itu, sehingga laju historis "
            "provinsi baru sama dengan induknya sampai data rincian tersedia. Elastisitas tetap dari "
            "estimasi 34 provinsi.")


def _petunjuk(ws, sk, data):
    m = data["meta"]
    r = G.tulis_petunjuk(ws, f"Skenario: {sk.nama}", [
        f"Versi data: {sk.versi_data}. Set elastisitas: {sk.set_parameter}. Koefisien sektoral: "
        f"{sk.koef_sektoral or 'dimatikan'}. Tahun dasar {m['tahun_dasar']}, target {m['tahun_target']}.",
        ("Kalkulator", "Sheet berumus. Ubah sel kuning (elastisitas di sheet Asumsi, atau laju TFP, "
                       "tenaga kerja, sasaran per provinsi) dan kebutuhan investasi tahun target dihitung "
                       "ulang oleh Excel. Kolom 'bonus' adalah angka statis dari aplikasi."),
        ("Nasional, Provinsi", "Hasil aplikasi apa adanya, termasuk saluran komposisi sektor yang dihitung "
                               "per tahun. Sheet ini statis; jalankan ulang skenario di aplikasi untuk "
                               "memperbaruinya."),
        ("Persamaan", "ln Y_h - ln Y_0 = g_A h + B_h + R_h + b1 (ln K_h - ln K_0) + b2 g_L h. "
                      "K = PMTB harga konstan (arus). Kebutuhan: ln K_h = ln K_0 + [ln Y*_h - ln Y_0 - "
                      "g_A h - B_h - R_h - b2 g_L h] / b1."),
        ("Saluran investasi", "PMTB nominal = PMTB tren + pass-through x (realisasi investasi dasar + tambahan - tren "
                              "PMA+PMDN) + pass-through APBD x belanja modal APBD tambahan."),
        ("Satuan", "PDRB dan PMTB riil: miliar Rp harga 2010. Investasi: miliar Rp nominal di kalkulator, "
                   "triliun Rp nominal di sheet Nasional dan Provinsi."),
        ("Kaveat", "Modal diproksi arus PMTB, sehingga b1 batas bawah dan residual TFP menyerap sebagian "
                   "kontribusi modal. Koefisien sektoral adalah presedensi waktu lintas provinsi, bukan "
                   "efek kausal. Realokasi tenaga kerja memakai produk rata-rata, jadi batas atas."),
    ] + ([("Papua 6 provinsi", _teks_papua(m))] if m.get("rinci_papua") else []))
    G.legenda(ws, r)


def _asumsi(wb, sk, data):
    ws = wb.create_sheet("Asumsi")
    p = data["meta"]["parameter"]
    a = data["meta"]["asumsi"]
    baris = [
        ("b1", "Elastisitas modal (b1)", p["b1"], True),
        ("b2", "Elastisitas tenaga kerja (b2)", p["b2"], True),
        ("H_", "Horizon (tahun)", data["meta"]["H"], False),
        ("inflasi", "Inflasi deflator PMTB (%/thn)", a["inflasi_pmtb"], True),
        ("pass_through", "Pass-through realisasi ke PMTB", sk.pass_through, True),
        ("rasio_realisasi", "Rasio realisasi terhadap rencana", sk.rasio_realisasi, True),
        ("apbd_persen", "Belanja modal APBD tambahan (% belanja)", sk.apbd_persen, True),
        ("pt_apbd", "Pass-through APBD ke PMTB", sk.pass_through_apbd, True),
        (None, "Sasaran nasional (%/thn), informasi", sk.sasaran, False),
        (None, "Laju tren PMA+PMDN (%/thn), informasi", a["g_investasi_tren"], False),
    ]
    G.header(ws, 1, 1, ["Nama", "Keterangan", "Nilai"])
    for i, (nama, ket, nilai, ubah) in enumerate(baris, start=2):
        ws.cell(row=i, column=1, value=nama or "")
        ws.cell(row=i, column=2, value=ket)
        c = ws.cell(row=i, column=3, value=float(nilai))
        c.fill = G.FILL_INPUT if ubah else G.FILL_KUNCI
        c.number_format = "0.0000"
        if nama:
            _nama(wb, nama, f"Asumsi!$C${i}")
    dv = DataValidation(type="decimal", operator="between", formula1="0.01", formula2="1.5",
                        showErrorMessage=True, error="Elastisitas antara 0,01 dan 1,5")
    dv.add("C2:C3")
    ws.add_data_validation(dv)
    G.lebar(ws, [16, 48, 14])


def _kalkulator(wb, data):
    ws = wb.create_sheet("Kalkulator")
    judul = ["Kode", "Provinsi", "Pulau", "PDRB dasar (riil)", "PMTB dasar (riil)", "PMTB dasar (nominal)",
             "Deflator PMTB", "Laju TFP %", "Laju TK %", "Laju PMTB tren %", "Bonus sektoral, realokasi, determinan (pp/thn)",
             "Sasaran %", "Laju PMTB riil dibutuhkan %", "PMTB riil dibutuhkan T", "PMTB riil tren T",
             "Deflator T", "Tambahan PMTB nominal T",              "Belanja APBD dasar", "APBD tambahan T",
             "Realisasi PMA+PMDN di atas tren, T", "Rencana PMA+PMDN di atas tren, T",
             "Aplikasi: realisasi di atas tren, T"]
    G.header(ws, 1, 1, judul)
    ws.row_dimensions[1].height = 45
    prov = data["provinsi"]
    for i, p in enumerate(prov, start=2):
        bonus = p["bonus_kebutuhan_pp"]
        nilai = [p["kode"], p["nama"], p["pulau"], p["pdrb0"], p["pmtb0"], p["pmtb0_nominal"]]
        for j, v in enumerate(nilai, start=1):
            ws.cell(row=i, column=j, value=v).fill = G.FILL_KUNCI
        r = i
        rumus = {
            7: f"=F{r}/E{r}",
            13: f"=(EXP((LN(1+L{r}/100)-LN(1+H{r}/100)-K{r}/100-b2*LN(1+I{r}/100))/b1)-1)*100",
            14: f"=E{r}*(1+M{r}/100)^H_",
            15: f"=E{r}*(1+J{r}/100)^H_",
            16: f"=G{r}*(1+inflasi/100)^H_",
            17: f"=(N{r}-O{r})*P{r}",
            19: f"=apbd_persen/100*R{r}*(1+inflasi/100)^H_",
            20: f"=(Q{r}-pt_apbd*S{r})/pass_through",
            21: f"=T{r}/rasio_realisasi",
        }
        masukan = {8: p["g_tfp"], 9: p["g_tk"], 10: p["g_pmtb_tren"], 11: bonus, 12: p["g_sasaran"]}
        for j, v in masukan.items():
            c = ws.cell(row=r, column=j, value=round(v, 6))
            c.fill = G.FILL_KUNCI if j == 11 else G.FILL_INPUT
            c.number_format = G.FMT_PERSEN
        ws.cell(row=r, column=18, value=p["belanja_apbd"]).fill = G.FILL_KUNCI
        for j, f in rumus.items():
            c = ws.cell(row=r, column=j, value=f)
            c.fill = G.FILL_RUMUS
            c.number_format = G.FMT_PERSEN if j == 13 else (G.FMT_RASIO if j in (7, 16) else G.FMT_MILIAR)
        ws.cell(row=r, column=22, value=p["kebutuhan_T"] - p["inv_tren_T"]).number_format = G.FMT_MILIAR
        for j in (4, 5, 6, 18):
            ws.cell(row=r, column=j).number_format = G.FMT_MILIAR
    n = len(prov) + 1
    tot = n + 1
    ws.cell(row=tot, column=2, value="Nasional").font = G.FONT_TEBAL
    for j in (4, 5, 6, 14, 15, 17, 18, 19, 20, 21, 22):
        col = ws.cell(row=1, column=j).column_letter
        c = ws.cell(row=tot, column=j, value=f"=SUM({col}2:{col}{n})")
        c.font, c.number_format = G.FONT_TEBAL, G.FMT_MILIAR
    ws.freeze_panes = "D2"
    G.lebar(ws, [6, 22, 12] + [14] * 19)
    ws.conditional_formatting.add(f"M2:M{n}", ColorScaleRule(start_type="min", start_color="63BE7B",
                                                            mid_type="percentile", mid_value=50,
                                                            mid_color="FFEB84", end_type="max",
                                                            end_color="F8696B"))
    ws.conditional_formatting.add(f"T2:T{n}", DataBarRule(start_type="min", end_type="max", color="5B9BD5"))
    ws.cell(row=tot + 2, column=2, value=(
        "Kolom V adalah hasil aplikasi untuk tahun target. Kolom T sama dengan V selama sel kuning belum "
        "diubah; ubah sel kuning untuk menguji asumsi lain. Bila investasi dasar diisi di aplikasi, kurangi "
        "selisihnya terhadap tren untuk mendapat tambahan di atas investasi dasar."
    )).alignment = G.BUNGKUS
    ws.cell(row=1, column=11).comment = Comment(
        "Rata-rata per tahun dari bonus komposisi investasi, realokasi tenaga kerja, dan efek determinan TFP "
        "pada jalur kebutuhan, dihitung aplikasi. Statis.", "Simulator")


def _nasional(wb, data):
    ws = wb.create_sheet("Nasional")
    n = data["nasional"]
    judul = ["Tahun", "PDRB tanpa penambahan (T Rp, riil)", "PDRB dengan penambahan", "PDRB sasaran",
             "Laju tanpa penambahan %", "Laju dengan penambahan %", "Laju sasaran %", "PMTB riil dasar", "PMTB riil skenario", "PMTB riil dibutuhkan",
             "Tren PMA+PMDN (T Rp)", "Investasi dasar realisasi", "Investasi tambahan rencana", "Kebutuhan realisasi", "Tambahan dibutuhkan",
             "APBD tambahan", "Indeks TFP tanpa penambahan", "Indeks TFP dengan penambahan", "Indeks TFP jalur sasaran"]
    G.header(ws, 1, 1, judul)
    ws.row_dimensions[1].height = 45
    for i, th in enumerate(n["tahun"]):
        r = i + 2
        h = i - 1
        isi = [th, n["pdrb_dasar"][i] / 1000, n["pdrb_skenario"][i] / 1000, n["pdrb_sasaran"][i] / 1000,
               n["g_dasar"][h] if i else None, n["g_skenario"][h] if i else None, n["g_sasaran"][h] if i else None,
               n["pmtb_dasar"][i] / 1000, n["pmtb_skenario"][i] / 1000, n["pmtb_kebutuhan"][i] / 1000,
               n["inv_tren"][h] if i else None, n["inv_a1"][h] if i else None, n["inv_a2"][h] if i else None,
               n["inv_kebutuhan"][h] if i else None, n["tambahan_kebutuhan"][h] if i else None,
               n["apbd_tambahan"][h] if i else None,
               n["tfp_dasar"][i], n["tfp_skenario"][i], n["tfp_kebutuhan"][i]]
        for j, v in enumerate(isi, start=1):
            c = ws.cell(row=r, column=j, value=v)
            c.number_format = G.FMT_PERSEN if j in (5, 6, 7) else ("0.0" if j > 16 else G.FMT_MILIAR)
    G.lebar(ws, [8] + [14] * 18)
    akhir = len(n["tahun"]) + 1
    ch = LineChart()
    ch.title = "Laju pertumbuhan PDRB riil (%)"
    ch.y_axis.title = "%"
    ch.add_data(Reference(ws, min_col=5, max_col=7, min_row=1, max_row=akhir), titles_from_data=True)
    ch.set_categories(Reference(ws, min_col=1, min_row=3, max_row=akhir))
    ch.height, ch.width = 8, 16
    ws.add_chart(ch, f"B{akhir + 3}")
    bc = BarChart()
    bc.title = "Investasi PMA+PMDN (triliun Rp)"
    bc.add_data(Reference(ws, min_col=11, max_col=15, min_row=1, max_row=akhir), titles_from_data=True)
    bc.set_categories(Reference(ws, min_col=1, min_row=3, max_row=akhir))
    bc.height, bc.width = 8, 16
    ws.add_chart(bc, f"J{akhir + 3}")
    rg = n["ringkasan"]
    r0 = akhir + 21
    ws.cell(row=r0, column=1, value="Ringkasan").font = G.FONT_JUDUL
    item = [("Laju tanpa penambahan investasi (%)", rg["g_rata_dasar"]),
            ("Laju dengan penambahan investasi (%)", rg["g_rata_skenario"]),
            ("Sasaran (%)", rg["g_rata_sasaran"]), ("Total Investasi Tambahan (T Rp)", rg["a2_kumulatif"]),
            ("Tambahan realisasi dibutuhkan, kumulatif (T Rp)", rg["kebutuhan_tambahan_kumulatif"]),
            ("Tambahan rencana dibutuhkan, kumulatif (T Rp)", rg["kebutuhan_tambahan_rencana_kumulatif"]),
            ("Selisih kebutuhan - investasi tambahan terealisasi (T Rp)", rg["selisih_a2"]),
            ("Laju PMTB riil dibutuhkan (%)", rg["g_K_kebutuhan"]), ("Laju PMTB riil tren (%)", rg["g_K_tren"]),
            ("Indeks TFP target, tanpa penambahan", rg["tfp_T_dasar"]),
            ("Indeks TFP target, dengan penambahan", rg["tfp_T_skenario"])]
    for k, (ket, v) in enumerate(item, start=1):
        ws.cell(row=r0 + k, column=1, value=ket)
        ws.cell(row=r0 + k, column=4, value=v).number_format = "#,##0.00"
    ws.freeze_panes = "B2"


def _provinsi(wb, data):
    ws = wb.create_sheet("Provinsi")
    u = data.get("ketidakpastian", {})
    judul = ["Kode", "Provinsi", "Pulau", "PDRB dasar (T Rp riil)", "Laju TFP %", "Laju TK %",
             "Laju PMTB tren %", "Sasaran %", "Laju tanpa penambahan %", "Laju dengan penambahan %",
             "Laju PMTB dibutuhkan %", "Total Investasi Tambahan (T Rp)", "Tambahan dibutuhkan kumulatif (T Rp)", "Selisih (T Rp)",
             "Tambahan/thn sebagai % PDRB nominal", "Tambahan/thn dibagi belanja APBD", "Peluang capai sasaran",
             "Laju P10 %", "Laju P90 %", "Kontribusi modal pp", "Kontribusi TK pp", "TFP tren pp",
             "Bonus sektoral pp", "Realokasi pp", "Determinan TFP pp", "Rasio (PMA+PMDN)/PMTB"]
    G.header(ws, 1, 1, judul)
    ws.row_dimensions[1].height = 45
    for i, p in enumerate(data["provinsi"], start=2):
        k = p["kontribusi"]
        isi = [p["kode"], p["nama"], p["pulau"], p["pdrb0"] / 1000, p["g_tfp"], p["g_tk"], p["g_pmtb_tren"],
               p["g_sasaran"], p["g_dasar"], p["g_skenario"], p["g_K_kebutuhan"], p["a2_kumulatif"] / 1000,
               p["kebutuhan_tambahan_kumulatif"] / 1000, p["selisih"] / 1000, p["rasio_kebutuhan_pdrb"],
               p["rasio_kebutuhan_belanja"], u.get("prob_provinsi", {}).get(str(p["kode"]),
                                                                           u.get("prob_provinsi", {}).get(p["kode"])),
               u.get("g_prov_p10", {}).get(str(p["kode"]), u.get("g_prov_p10", {}).get(p["kode"])),
               u.get("g_prov_p90", {}).get(str(p["kode"]), u.get("g_prov_p90", {}).get(p["kode"])),
               k["modal"], k["tk"], k["tfp_tren"], k["sektoral"], k["realokasi"], k.get("determinan", 0.0),
               p["rasio_inv_pmtb"]]
        for j, v in enumerate(isi, start=1):
            c = ws.cell(row=i, column=j, value=v)
            c.number_format = "0%" if j == 17 else (G.FMT_MILIAR if j in (4, 12, 13, 14) else G.FMT_PERSEN)
    n = len(data["provinsi"]) + 1
    ws.auto_filter.ref = f"A1:Z{n}"
    ws.freeze_panes = "C2"
    G.lebar(ws, [6, 22, 12] + [13] * 22)
    ws.conditional_formatting.add(f"Q2:Q{n}", ColorScaleRule(start_type="num", start_value=0, start_color="F8696B",
                                                            mid_type="num", mid_value=0.5, mid_color="FFEB84",
                                                            end_type="num", end_value=1, end_color="63BE7B"))
    ws.conditional_formatting.add(f"M2:M{n}", DataBarRule(start_type="min", end_type="max", color="5B9BD5"))
    ws.conditional_formatting.add(f"J2:J{n}", ColorScaleRule(start_type="min", start_color="F8696B",
                                                            end_type="max", end_color="63BE7B"))

    wt = wb.create_sheet("Provinsi tahunan")
    G.header(wt, 1, 1, ["Kode", "Provinsi", "Tahun", "Laju tanpa penambahan %", "Laju dengan penambahan %",
                        "Tren PMA+PMDN (T Rp)", "Investasi tambahan (T Rp)", "Kebutuhan realisasi (T Rp)"])
    r = 2
    tahun = data["nasional"]["tahun"][1:]
    for p in data["provinsi"]:
        s = p["seri"]
        for h, th in enumerate(tahun):
            for j, v in enumerate([p["kode"], p["nama"], th, s["g_dasar"][h], s["g_skenario"][h], s["tren"][h],
                                   s["a2"][h], s["kebutuhan"][h]], start=1):
                wt.cell(row=r, column=j, value=v).number_format = G.FMT_PERSEN if j in (4, 5) else G.FMT_MILIAR
            r += 1
    wt.auto_filter.ref = f"A1:H{r - 1}"
    wt.freeze_panes = "D2"
    G.lebar(wt, [6, 22, 7, 13, 13, 16, 12, 18])


def _sektoral(wb, data):
    ws = wb.create_sheet("Sektoral")
    s = data["sektoral"]
    ws.cell(row=1, column=1, value="Saluran komposisi investasi (13_Sectoral)").font = G.FONT_JUDUL
    G.header(ws, 3, 1, ["Kelompok", "Koefisien", "SE", "Pangsa historis nasional", "Pangsa investasi tambahan nasional",
                        "Bonus TFP rata-rata (pp/thn)"])
    for i, k in enumerate(s["kelompok"], start=4):
        for j, v in enumerate([k["nama"], k["beta"], k["se"], k["pangsa_hist_nas"], k["pangsa_a2_nas"],
                               k["bonus_pp"]], start=1):
            c = ws.cell(row=i, column=j, value=v)
            c.number_format = "0.0%" if j in (4, 5) else "0.0000"
    r0 = 10
    G.header(ws, r0, 1, ["Sektor", "Nama", "Kelompok", "Tambahan dibutuhkan kumulatif (T Rp)", "Total Investasi Tambahan (T Rp)"])
    for i, x in enumerate(s["sektor"], start=r0 + 1):
        for j, v in enumerate([x["kode"], x["nama"], NAMA_KELOMPOK[x["kelompok"]], x["kebutuhan"] / 1000,
                               x["a2"] / 1000], start=1):
            ws.cell(row=i, column=j, value=v).number_format = G.FMT_MILIAR
    G.lebar(ws, [34, 38, 30, 20, 18, 18])
    akhir = r0 + len(s["sektor"])
    bc = BarChart()
    bc.type = "bar"
    bc.title = "Tambahan investasi dibutuhkan per sektor (T Rp)"
    bc.add_data(Reference(ws, min_col=4, min_row=r0, max_row=akhir), titles_from_data=True)
    bc.set_categories(Reference(ws, min_col=2, min_row=r0 + 1, max_row=akhir))
    bc.height, bc.width = 10, 18
    ws.add_chart(bc, "H3")

    wm = wb.create_sheet("Matriks sektor")
    G.header(wm, 1, 1, ["Kode", "Provinsi"] + [f"{k} {NAMA_SEKTOR[k]}" for k in KODE_SEKTOR] + ["Jumlah"])
    wm.row_dimensions[1].height = 60
    for i, (kode, baris) in enumerate(sorted(s["matriks"].items(), key=lambda x: int(x[0])), start=2):
        wm.cell(row=i, column=1, value=int(kode))
        wm.cell(row=i, column=2, value=NAMA_PROVINSI[int(kode)])
        for j, k in enumerate(KODE_SEKTOR, start=3):
            wm.cell(row=i, column=j, value=baris[k] / 1000).number_format = G.FMT_MILIAR
        akhir_kol = wm.cell(row=1, column=2 + len(KODE_SEKTOR)).column_letter
        c = wm.cell(row=i, column=3 + len(KODE_SEKTOR), value=f"=SUM(C{i}:{akhir_kol}{i})")
        c.number_format, c.fill = G.FMT_MILIAR, G.FILL_RUMUS
    n = len(s["matriks"]) + 1
    wm.conditional_formatting.add(f"C2:{wm.cell(row=1, column=2 + len(KODE_SEKTOR)).column_letter}{n}",
                                  ColorScaleRule(start_type="min", start_color="FFFFFF",
                                                 end_type="max", end_color="5B9BD5"))
    wm.freeze_panes = "C2"
    G.lebar(wm, [6, 22] + [11] * 18)
    wm.cell(row=n + 2, column=2, value="Satuan: triliun Rp, tambahan realisasi kumulatif seluruh horizon. "
                                       "Kelompok dibagi menurut komposisi investasi tambahan; di dalam kelompok menurut pangsa "
                                       "historis provinsi.")


def _ketidakpastian(wb, data):
    u = data.get("ketidakpastian")
    if not u:
        return
    ws = wb.create_sheet("Confidence")
    ws.cell(row=1, column=1, value=f"Monte Carlo, {u['n']} simulasi").font = G.FONT_JUDUL
    item = [("Peluang laju rata-rata nasional >= sasaran", u["prob_nasional"], "0%"),
            ("Laju rata-rata nasional P10 (%)", u["g_rata"]["p10"], G.FMT_PERSEN),
            ("Laju rata-rata nasional P50 (%)", u["g_rata"]["p50"], G.FMT_PERSEN),
            ("Laju rata-rata nasional P90 (%)", u["g_rata"]["p90"], G.FMT_PERSEN),
            ("Provinsi dengan peluang >= 80%", u["n_prov_yakin"], "0"),
            ("Kebutuhan tambahan, perkiraan tengah P50 (T Rp)", u["kebutuhan_tambahan_kum"]["p50"], G.FMT_MILIAR),
            ("Kebutuhan tambahan, batas aman P80 (T Rp)", u["kebutuhan_tambahan_kum"]["p80"], G.FMT_MILIAR),
            ("Kebutuhan tambahan, sangat aman P90 (T Rp)", u["kebutuhan_tambahan_kum"]["p90"], G.FMT_MILIAR)]
    for i, (ket, v, f) in enumerate(item, start=3):
        ws.cell(row=i, column=1, value=ket)
        ws.cell(row=i, column=2, value=v).number_format = f
    G.header(ws, 13, 1, ["Tahun", "Laju P10 %", "Laju P50 %", "Laju P90 %"])
    for h, th in enumerate(data["nasional"]["tahun"][1:]):
        for j, v in enumerate([th, u["g_tahunan"]["p10"][h], u["g_tahunan"]["p50"][h], u["g_tahunan"]["p90"][h]],
                              start=1):
            ws.cell(row=14 + h, column=j, value=v).number_format = G.FMT_PERSEN
    G.lebar(ws, [46, 14, 14, 14])


def ekspor_hasil(sk, data):
    wb = Workbook()
    ws = wb.active
    ws.title = "Petunjuk"
    _petunjuk(ws, sk, data)
    _asumsi(wb, sk, data)
    _kalkulator(wb, data)
    _nasional(wb, data)
    _provinsi(wb, data)
    _sektoral(wb, data)
    _ketidakpastian(wb, data)
    return _simpan(wb)


# --------------------------------------------------------------- lembar asumsi
def lembar_asumsi(sk, data=None):
    wb = Workbook()
    ws_p = wb.active
    ws_p.title = "Petunjuk"
    G.tulis_petunjuk(ws_p, f"Lembar asumsi provinsi: {sk.nama}", [
        "Isi sel kuning lalu unggah kembali di halaman skenario (tombol 'Unggah lembar asumsi'). Sel "
        "kosong berarti provinsi itu mengikuti asumsi umum skenario.",
        ("Sasaran", "Dipakai bila mode sasaran = Manual."),
        ("Laju TFP, TK", "Dipakai bila mode asumsi TFP / tenaga kerja = Manual. Kolom abu di kanan "
                         "menunjukkan nilai historis dari hasil terakhir sebagai pembanding."),
        ("Bobot alokasi investasi tambahan", "Dipakai bila alokasi investasi tambahan = Bobot manual. Angka bebas, dinormalkan otomatis."),
        ("Komposisi investasi tambahan", "Empat kolom komposisi berlaku bila keempatnya diisi untuk provinsi itu. Angka "
                         "bebas (misalnya persen), dinormalkan menjadi pangsa."),
    ])
    ws = wb.create_sheet("Asumsi provinsi")
    ref = {p["kode"]: p for p in (data or {}).get("provinsi", [])}
    judul = ["kode", "provinsi", "pulau"] + [k for k, *_ in KOLOM_ASUMSI] + [
        "ref_tfp_hist", "ref_tk_hist", "ref_sasaran_hasil", "ref_primer", "ref_sekunder", "ref_tva", "ref_tlain"]
    G.header(ws, 1, 1, judul)
    for j, (k, ket, *_r) in enumerate(KOLOM_ASUMSI, start=4):
        ws.cell(row=1, column=j).comment = Comment(ket, "Simulator")
    ov = {int(k): v for k, v in (sk.override_provinsi or {}).items()}
    kode_prov = sk.kode_provinsi
    for i, kode in enumerate(kode_prov, start=2):
        for j, v in enumerate([kode, NAMA_PROVINSI[kode], PULAU_PROVINSI[kode]], start=1):
            ws.cell(row=i, column=j, value=v).fill = G.FILL_KUNCI
        for j, (k, *_r) in enumerate(KOLOM_ASUMSI, start=4):
            v = ov.get(kode, {}).get(k)
            c = ws.cell(row=i, column=j, value=None if v in (None, "") else float(v))
            c.fill = G.FILL_INPUT
            c.number_format = "0.00"
        p = ref.get(kode)
        if p:
            vals = [p["g_tfp"], p["g_tk"], p["g_sasaran"]] + [p["komposisi_hist"][k] * 100
                                                               for k in ("primer", "sekunder", "tva", "tlain")]
            for j, v in enumerate(vals, start=4 + len(KOLOM_ASUMSI)):
                c = ws.cell(row=i, column=j, value=round(v, 3))
                c.fill = G.FILL_KUNCI
                c.number_format = "0.00"
    for j, (_k, _ket, lo, hi) in enumerate(KOLOM_ASUMSI, start=4):
        col = ws.cell(row=1, column=j).column_letter
        dv = DataValidation(type="decimal", operator="between", formula1=str(lo), formula2=str(hi),
                            allow_blank=True, showErrorMessage=True, error=f"Nilai antara {lo} dan {hi}")
        dv.add(f"{col}2:{col}{len(kode_prov) + 1}")
        ws.add_data_validation(dv)
    ws.freeze_panes = "D2"
    G.lebar(ws, [6, 22, 12] + [12] * (len(KOLOM_ASUMSI) + 7))
    wb.active = 1
    return _simpan(wb)


def baca_lembar_asumsi(berkas):
    """Kembalikan (override dict, daftar pesan)."""
    wb = load_workbook(berkas, data_only=True)
    ws = wb["Asumsi provinsi"] if "Asumsi provinsi" in wb.sheetnames else wb.worksheets[-1]
    judul = [str(c.value).strip().lower() if c.value is not None else "" for c in ws[1]]
    if "kode" not in judul:
        raise ValueError("Kolom 'kode' tidak ditemukan di baris 1 sheet 'Asumsi provinsi'.")
    ik = judul.index("kode")
    override, pesan = {}, []
    batas = {k: (lo, hi) for k, _ket, lo, hi in KOLOM_ASUMSI}
    for row in ws.iter_rows(min_row=2, values_only=True):
        kode = row[ik]
        try:
            kode = int(kode)
        except (TypeError, ValueError):
            continue
        if kode not in NAMA_PROVINSI:
            pesan.append(f"Kode {kode} bukan kode provinsi; baris dilewati.")
            continue
        isi = {}
        for k in batas:
            if k not in judul:
                continue
            v = row[judul.index(k)]
            if v in (None, ""):
                continue
            try:
                v = float(str(v).replace(",", "."))
            except ValueError:
                pesan.append(f"{NAMA_PROVINSI[kode]} {k}: '{v}' bukan angka; diabaikan.")
                continue
            lo, hi = batas[k]
            if not lo <= v <= hi:
                pesan.append(f"{NAMA_PROVINSI[kode]} {k}: {v} di luar rentang {lo}-{hi}; diabaikan.")
                continue
            isi[k] = v
        if isi:
            override[str(kode)] = isi
    return override, pesan
