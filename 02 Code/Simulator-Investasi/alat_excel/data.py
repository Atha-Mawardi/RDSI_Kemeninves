"""Lembar Data (panel provinsi x tahun yang bisa diperbarui) dan Ref (daftar acuan)."""

import math

import datapanel.variabel as V
from openpyxl.worksheet.datavalidation import DataValidation

from . import gaya as G
from .konteks import KEL, KELOMPOK, MAKS_BARIS_DATA, NAMA_PILAR, PROVINSI, PULAU, SEKTOR

R0 = 6  # baris data pertama
R1 = R0 + MAKS_BARIS_DATA - 1
INTI = ["PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB", "PMA", "PMDN", "PAD", "APBD_PENDAPATAN", "APBD_BELANJA"]
TVA = ["H", "J", "K", "MN"]

# Posisi petak peta (baris, kolom) yang kira-kira mengikuti letak geografis.
PETAK = {
    11: (1, 1), 12: (2, 2), 21: (2, 4), 13: (3, 2), 14: (3, 3), 19: (3, 5), 15: (4, 3), 17: (4, 2), 16: (5, 3),
    18: (6, 3), 61: (2, 7), 65: (1, 9), 64: (2, 9), 62: (3, 8), 63: (3, 9), 31: (6, 5), 36: (6, 4), 32: (7, 5),
    33: (7, 6), 34: (8, 6), 35: (7, 7), 51: (8, 8), 52: (8, 9), 53: (8, 10), 71: (1, 12), 75: (2, 12), 72: (2, 11),
    76: (3, 10), 73: (4, 10), 74: (4, 11), 82: (2, 14), 81: (4, 13), 92: (3, 15), 91: (3, 16), 96: (4, 16),
    94: (3, 17), 97: (4, 17), 95: (5, 17),
}


def kolom_mentah(kolom_panel):
    sektor = [s for s, _, _ in SEKTOR]
    urut = [k for k in INTI if k in kolom_panel]
    for s in sektor:
        urut += [k for k in (f"VA_{s}", f"TK_{s}", f"PMA_{s}", f"PMDN_{s}") if k in kolom_panel]
    return urut + [k for k in kolom_panel if k not in urut]


class TataData:
    """Kolom lembar Data: mentah (diisi pengguna) dan bantu (rumus)."""

    def __init__(self, mentah):
        self.mentah = mentah
        self.c = {"kode": 1, "provinsi": 2, "pulau": 3, "tahun": 4}
        for i, k in enumerate(mentah):
            self.c[k] = 5 + i
        self.c_akhir_mentah = 4 + len(mentah)
        self.bantu = []
        self._n = self.c_akhir_mentah + 2

    def tambah(self, kunci):
        self.c[kunci] = self._n
        self.bantu.append(kunci)
        self._n += 1
        return self._n - 1

    def sel(self, kunci, r):
        return f"${G.kol(self.c[kunci])}{r}"

    def rentang(self, kunci):
        return f"${G.kol(self.c[kunci])}${R0}:${G.kol(self.c[kunci])}${R1}"


def _f(v):
    if v is None:
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    return None if math.isnan(x) else x


def lembar_data(wb, ctx):
    ws = wb.create_sheet("Data")
    G.warna_tab(ws, G.HIJAU)
    mentah = kolom_mentah(ctx.kolom_data)
    T = TataData(mentah)
    G.pita(ws, "Data panel provinsi × tahun",
           f"{ctx.versi_label}. Tambah tahun baru di bawah baris terakhir dengan kode provinsi yang sama; kolom bantu di kanan dihitung sendiri.")
    G.tulis(ws, 3, 1, "Satuan uang miliar Rp, tenaga kerja jiwa. Sel kosong = tidak tersedia (jangan isi '-' atau teks).",
            font=G.T_KECIL)

    judul = ["Kode", "Provinsi", "Pulau", "Tahun"] + mentah
    G.header(ws, 5, 1, judul, tinggi=30)
    for i, k in enumerate(mentah):
        c = ws.cell(row=4, column=5 + i, value=f"{V.label(k)} ({V.satuan(k)})")
        c.font, c.alignment = G.T_KECIL, G.KIRI_BUNGKUS
    ws.row_dimensions[4].height = 42

    nama_prov = {k: (n, p) for k, n, p in PROVINSI(ctx.kode)}
    df = ctx.panel.reset_index()
    r = R0
    for _, b in df.iterrows():
        k = int(b["kode"])
        ws.cell(row=r, column=1, value=k)
        ws.cell(row=r, column=2, value=nama_prov[k][0])
        ws.cell(row=r, column=3, value=nama_prov[k][1])
        ws.cell(row=r, column=4, value=int(b["tahun"]))
        for i, kk in enumerate(mentah):
            v = _f(b.get(kk))
            if v is not None:
                ws.cell(row=r, column=5 + i, value=v).number_format = G.FMT_T
        r += 1
    for rr in range(R0, R1 + 1):
        for c in range(1, T.c_akhir_mentah + 1):
            ws.cell(row=rr, column=c).fill = G.F_ISIAN if rr >= r else G.F_PUTIH

    # ---- kolom bantu
    sektor = [s for s, _, _ in SEKTOR]
    kel_sektor = {s: k for s, _, k in SEKTOR}
    for k in ["INV", "TKT", "VATOT", "VATVA", "TKTVA"] + [f"S_{s}" for s in sektor] + [f"G_{g}" for g in KEL] + \
            ["lnY", "lnK", "lnL", "dY", "dK", "dL", "ok", "YY", "KK", "LL", "YK", "YL", "KL",
             "eok", "yt", "kt", "lt", "eyy", "eyk", "eyl", "ekk", "ell", "ekl", "e", "eek", "eel", "eee"]:
        T.tambah(k)
    c0 = T.c["INV"]
    G.tulis(ws, 4, c0, "Kolom bantu (rumus, jangan disunting)", font=G.T_KECIL)
    G.header(ws, 5, c0, T.bantu, fill=G.PatternFill("solid", fgColor=G.ABU))

    S = lambda k, rr: T.sel(k, rr)  # noqa: E731
    tk = [f"TK_{s}" for s in sektor]
    va = [f"VA_{s}" for s in sektor]
    for rr in range(R0, R1 + 1):
        a = f"$A{rr}"
        jika = lambda isi: f'=IF({a}="","",{isi})'  # noqa: E731
        f = {
            "INV": jika(f'IF(AND({S("PMA", rr)}="",{S("PMDN", rr)}=""),"",N({S("PMA", rr)})+N({S("PMDN", rr)}))'),
            "TKT": jika(f'IF(COUNT({",".join(S(x, rr) for x in tk)})=17,SUM({",".join(S(x, rr) for x in tk)}),"")'),
            "VATOT": jika(f'IF(COUNT({",".join(S(x, rr) for x in va)})=17,SUM({",".join(S(x, rr) for x in va)}),"")'),
            "VATVA": jika(f'SUM({",".join(S("VA_" + x, rr) for x in TVA)})'),
            "TKTVA": jika(f'SUM({",".join(S("TK_" + x, rr) for x in TVA)})'),
        }
        for s in sektor:
            f[f"S_{s}"] = jika(f'MAX(N({S("PMA_" + s, rr)}),0)+MAX(N({S("PMDN_" + s, rr)}),0)')
        for g in KEL:
            f[f"G_{g}"] = jika("+".join(S(f"S_{s}", rr) for s in sektor if kel_sektor[s] == g))
        f["lnY"] = jika(f'IF(N({S("PDRB_ADHK", rr)})>0,LN({S("PDRB_ADHK", rr)}),"")')
        f["lnK"] = jika(f'IF(N({S("PMTB_ADHK", rr)})>0,LN({S("PMTB_ADHK", rr)}),"")')
        f["lnL"] = jika(f'IF(N({S("TKT", rr)})>0,LN({S("TKT", rr)}),"")')
        for d, ln, var in (("dY", "lnY", "PDRB_ADHK"), ("dK", "lnK", "PMTB_ADHK"), ("dL", "lnL", "TKT")):
            f[d] = jika(f'IFERROR({S(ln, rr)}-LN(SUMIFS(D_{var},D_kode,$A{rr},D_tahun,$D{rr}-1)),"")')
        f["ok"] = jika(f'IF(AND(ISNUMBER({S("dY", rr)}),ISNUMBER({S("dK", rr)}),ISNUMBER({S("dL", rr)}),'
                       f'$D{rr}>=HA,$D{rr}<=HZ,OR(KECUALI_2020=0,$D{rr}<>2020)),1,0)')
        for kk, (x, y) in {"YY": ("dY", "dY"), "KK": ("dK", "dK"), "LL": ("dL", "dL"), "YK": ("dY", "dK"),
                           "YL": ("dY", "dL"), "KL": ("dK", "dL")}.items():
            f[kk] = jika(f'IF({S("ok", rr)}=1,{S(x, rr)}*{S(y, rr)},"")')
        f["eok"] = jika(f'IF(AND(ISNUMBER({S("lnY", rr)}),ISNUMBER({S("lnK", rr)}),ISNUMBER({S("lnL", rr)}),'
                        f'$D{rr}>=EA,$D{rr}<=EZ,OR(EST_2020=0,$D{rr}<>2020)),1,0)')
        for t, ln, m in (("yt", "lnY", "EST_mY"), ("kt", "lnK", "EST_mK"), ("lt", "lnL", "EST_mL")):
            f[t] = jika(f'IF({S("eok", rr)}=1,{S(ln, rr)}-AVERAGEIFS(D_{ln},D_kode,$A{rr},D_eok,1)'
                        f'-AVERAGEIFS(D_{ln},D_tahun,$D{rr},D_eok,1)+{m},"")')
        for kk, (x, y) in {"eyy": ("yt", "yt"), "eyk": ("yt", "kt"), "eyl": ("yt", "lt"), "ekk": ("kt", "kt"),
                           "ell": ("lt", "lt"), "ekl": ("kt", "lt")}.items():
            f[kk] = jika(f'IF({S("eok", rr)}=1,{S(x, rr)}*{S(y, rr)},"")')
        f["e"] = jika(f'IF({S("eok", rr)}=1,{S("yt", rr)}-EST_b1*{S("kt", rr)}-EST_b2*{S("lt", rr)},"")')
        f["eek"] = jika(f'IF({S("eok", rr)}=1,{S("e", rr)}*{S("kt", rr)},"")')
        f["eel"] = jika(f'IF({S("eok", rr)}=1,{S("e", rr)}*{S("lt", rr)},"")')
        f["eee"] = jika(f'IF({S("eok", rr)}=1,{S("e", rr)}^2,"")')
        for k, v in f.items():
            c = ws.cell(row=rr, column=T.c[k], value=v)
            c.fill = G.F_RUMUS

    G.nama(wb, "D_kode", "Data", f"$A${R0}:$A${R1}")
    G.nama(wb, "D_pulau", "Data", f"$C${R0}:$C${R1}")
    G.nama(wb, "D_tahun", "Data", f"$D${R0}:$D${R1}")
    for k in mentah + T.bantu:
        G.nama(wb, f"D_{k}", "Data", T.rentang(k))
    G.nama(wb, "D_ISI", "Data", f"$E${R0}:${G.kol(T.c_akhir_mentah)}${R1}")
    G.nama(wb, "D_JUDUL", "Data", f"$E$5:${G.kol(T.c_akhir_mentah)}$5")
    ws.freeze_panes = "E6"
    G.lebar(ws, [7, 22, 12, 7] + [12] * len(mentah))
    for k in T.bantu:
        ws.column_dimensions[G.kol(T.c[k])].width = 9
        ws.column_dimensions[G.kol(T.c[k])].outlineLevel = 1
    ws.auto_filter.ref = f"A5:{G.kol(T.c_akhir_mentah)}{R1}"
    return ws, T


def lembar_ref(wb, ctx, mentah):
    ws = wb.create_sheet("Ref")
    G.warna_tab(ws, G.ABU)
    G.pita(ws, "Tabel acuan", "Dipakai daftar pilihan dan rumus. Tidak untuk disunting.")
    G.header(ws, 4, 1, ["Kode", "Provinsi", "Pulau", "Petak baris", "Petak kolom"])
    for i, (k, n, p) in enumerate(PROVINSI(ctx.kode)):
        r = 5 + i
        for c, v in enumerate([k, n, p, *PETAK.get(k, (9, 1 + i % 17))], 1):
            ws.cell(row=r, column=c, value=v)
    n = len(ctx.kode)
    G.nama(wb, "REF_kode", "Ref", f"$A$5:$A${4 + n}")
    G.nama(wb, "REF_nama", "Ref", f"$B$5:$B${4 + n}")
    G.nama(wb, "REF_pulau", "Ref", f"$C$5:$C${4 + n}")

    daftar = {
        "L_pulau": PULAU,
        "L_kel": KEL,
        "L_kel_nama": [nm for _, nm in KELOMPOK],
        "L_mode_sasaran": ["seragam", "proporsional", "manual"],
        "L_mode_hist": ["historis", "nasional"],
        "L_alokasi": ["kebutuhan", "pdrb", "investasi", "manual"],
        "L_mode_a2": ["angka", "kebutuhan x skala"],
        "L_tujuan": ["C", "tva"],
        "L_shock": ["TFP (level)", "PDRB langsung", "Tenaga kerja", "Realisasi PMA+PMDN"],
        "L_ya": ["ya", "tidak"],
        "L_pilar": list(NAMA_PILAR),
        "L_var": mentah,
        "L_var_label": [f"{V.label(k)} ({V.satuan(k)})" for k in mentah],
        "L_sektor": [s for s, _, _ in SEKTOR],
        "L_sektor_nama": [nm for _, nm, _ in SEKTOR],
        "L_sektor_kel": [kl for _, _, kl in SEKTOR],
    }
    c = 7
    for nm, isi in daftar.items():
        G.tulis(ws, 4, c, nm, font=G.T_HEADER, fill=G.F_HEADER)
        for i, v in enumerate(isi):
            ws.cell(row=5 + i, column=c, value=v)
        G.nama(wb, nm, "Ref", f"${G.kol(c)}$5:${G.kol(c)}${4 + len(isi)}")
        ws.column_dimensions[G.kol(c)].width = 18
        c += 1
    G.lebar(ws, [7, 22, 12, 6, 6])
    return ws


def validasi(ws, rumus, ref):
    dv = DataValidation(type="list", formula1=rumus, allow_blank=True)
    dv.error, dv.errorTitle = "Pilih dari daftar.", "Isian tidak sah"
    ws.add_data_validation(dv)
    dv.add(ref)
    return dv
