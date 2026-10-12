# Isi sel Agregasi yang masih kosong menurut definisi.
# Jalankan setelah 06 dan 07. Menulis xlsx di 01 Data/TFP/processed/.

import csv
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from openpyxl import load_workbook
from openpyxl.worksheet.formula import ArrayFormula
from pengaturan import SEKTOR, TABEL, num, read_csv
from tulis_bantuan import XLSX_INP, XLSX_ROOT, style_like

AHH_2025 = TABEL / "ahh_2025.csv"
CSV_SHEET1 = XLSX_INP.parent / "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar(Sheet1).csv"
COPY_TFP = [
    "log_lab_tot", "logtfp_it", "logtfp_it_crs",
    "g_Y", "g_K", "g_L", "kontrib_modal", "kontrib_tk", "kontrib_tfp",
]


def kosong(v):
    if v in (None, ""):
        return True
    if isinstance(v, ArrayFormula):
        return True
    if isinstance(v, str) and v.startswith("="):
        return True
    return False


def ln_pos(v):
    v = num(v)
    return math.log(v) if v and v > 0 else None


def header_map(ws):
    hdr = [c.value for c in next(ws.iter_rows(min_row=1, max_row=1))]
    return {h: i + 1 for i, h in enumerate(hdr) if h}


def index_baris(ws, col):
    out = {}
    for r in range(2, ws.max_row + 1):
        code, year = ws.cell(r, col["Code_Prov"]).value, ws.cell(r, col["Year"]).value
        if code is None or year is None:
            continue
        out[(int(code), int(year))] = r
    return out


def tulis(ws, r, c, val, proto=None):
    cell = ws.cell(r, c, val)
    if proto is not None:
        style_like(proto, cell)
    return 1


def load_ahh():
    return {int(r["code_prov"]): num(r["nilai"]) for r in read_csv(AHH_2025)}


def ahh_teks(v):
    return f"{v:.2f}".replace(".", ",")


def isi_identitas_sheet1(ws, col, by_key):
    n = {"deflator": 0, "log": 0, "pma0": 0, "pmdn0": 0, "ipm": 0, "ekspor": 0, "icor": 0}
    proto = ws.cell(2, col.get("PMA_1", 1))
    for (code, year), r in by_key.items():
        adhb = ws.cell(r, col["9_ADHB"]).value if "9_ADHB" in col else None
        adhk = ws.cell(r, col["9_ADHK"]).value if "9_ADHK" in col else None
        if "PDBDeflator" in col and kosong(ws.cell(r, col["PDBDeflator"]).value) and num(adhb) and num(adhk) and num(adhk) != 0:
            n["deflator"] += tulis(ws, r, col["PDBDeflator"], 100 * num(adhb) / num(adhk), proto)
        if "log_ADHK_Tot" in col and kosong(ws.cell(r, col["log_ADHK_Tot"]).value):
            v = ln_pos(adhk)
            if v is not None:
                n["log"] += tulis(ws, r, col["log_ADHK_Tot"], v, proto)
        if "log_pmtb" in col and kosong(ws.cell(r, col["log_pmtb"]).value):
            v = ln_pos(ws.cell(r, col["pmtb"]).value) or ln_pos(ws.cell(r, col["4_ADHK"]).value)
            if v is not None:
                n["log"] += tulis(ws, r, col["log_pmtb"], v, proto)
        tk = 0.0
        ada_tk = False
        for s in SEKTOR:
            ktk = f"{s}_TenagaKerja"
            if ktk not in col:
                continue
            t = num(ws.cell(r, col[ktk]).value)
            if t is not None:
                tk += t
                ada_tk = True
        if "log_lab_tot" in col and kosong(ws.cell(r, col["log_lab_tot"]).value) and ada_tk and tk > 0:
            n["log"] += tulis(ws, r, col["log_lab_tot"], math.log(tk), proto)
        if "IPM_Prov_Nm" in col and "IPM_Prov" in col and kosong(ws.cell(r, col["IPM_Prov_Nm"]).value) and not kosong(ws.cell(r, col["IPM_Prov"]).value):
            n["ipm"] += tulis(ws, r, col["IPM_Prov_Nm"], ws.cell(r, col["IPM_Prov"]).value, proto)

        for s in SEKTOR:
            cp, cd = f"{s}_PMA", f"{s}_PMDN"
            if cp in col and kosong(ws.cell(r, col[cp]).value):
                n["pma0"] += tulis(ws, r, col[cp], 0, proto)
            if cd in col and kosong(ws.cell(r, col[cd]).value):
                n["pmdn0"] += tulis(ws, r, col[cd], 0, proto)

        r0 = by_key.get((code, 2022))
        if year >= 2023 and r0 is not None:
            for pair, tot in (("7_ADHB", "9_ADHB"), ("8_ADHB", "9_ADHB"),
                              ("7_ADHK", "9_ADHK"), ("8_ADHK", "9_ADHK")):
                if pair not in col or tot not in col:
                    continue
                if not kosong(ws.cell(r, col[pair]).value):
                    continue
                v0, t0, t1 = num(ws.cell(r0, col[pair]).value), num(ws.cell(r0, col[tot]).value), num(ws.cell(r, col[tot]).value)
                if v0 is None or not t0 or t1 is None:
                    continue
                n["ekspor"] += tulis(ws, r, col[pair], v0 * (t1 / t0), proto)

        if year == 2018 and "ICORPMTB" in col and "ADHB_LU" in col and kosong(ws.cell(r, col["ICORPMTB"]).value):
            rlag = by_key.get((code, 2017))
            if rlag is not None:
                dy = num(ws.cell(r, col["ADHB_LU"]).value) - num(ws.cell(rlag, col["ADHB_LU"]).value)
                if dy and dy != 0:
                    pmtb = num(ws.cell(r, col["pmtb"]).value)
                    pma = num(ws.cell(r, col["PMA_1"]).value) or 0
                    pmdn = num(ws.cell(r, col["PMDN_1"]).value) or 0
                    if pmtb is not None:
                        n["icor"] += tulis(ws, r, col["ICORPMTB"], pmtb / dy, proto)
                    n["icor"] += tulis(ws, r, col["ICORPMA"], pma / dy, proto)
                    n["icor"] += tulis(ws, r, col["ICORPMDN"], pmdn / dy, proto)
                    n["icor"] += tulis(ws, r, col["ICORPMAPMDN"], (pma + pmdn) / dy, proto)
    return n


def salin_tfp_ke_sheet1(ws, col, by_key, luaran, col_l, by_l):
    n = 0
    proto = ws.cell(2, col["PMA_1"])
    for key, r in by_key.items():
        rl = by_l.get(key)
        if rl is None:
            continue
        for name in COPY_TFP:
            if name not in col or name not in col_l:
                continue
            if not kosong(ws.cell(r, col[name]).value):
                continue
            val = luaran.cell(rl, col_l[name]).value
            if kosong(val):
                continue
            n += tulis(ws, r, col[name], val, proto)
    return n


def adhk_dari_sheet1(col1, by1, ws1):
    out = {}
    if "ADHK_LU" not in col1:
        return out
    for key, r in by1.items():
        out[key] = num(ws1.cell(r, col1["ADHK_LU"]).value)
    return out


def isi_growth_2025(ws, col, by_key, adhk):
    n = 0
    proto = ws.cell(2, col.get("g_Y", 2))
    for (code, year), r in by_key.items():
        if year != 2025:
            continue
        r24 = by_key.get((code, 2024))
        if r24 is None:
            continue
        if "g_Y" in col and kosong(ws.cell(r, col["g_Y"]).value):
            y1, y0 = adhk.get((code, 2025)), adhk.get((code, 2024))
            if y1 and y0 and y0 > 0:
                n += tulis(ws, r, col["g_Y"], 100 * math.log(y1 / y0), proto)
        if "g_L" in col and kosong(ws.cell(r, col["g_L"]).value):
            def labour(rr):
                s = 0.0
                ada = False
                for k in SEKTOR:
                    t = num(ws.cell(rr, col[f"{k}_TenagaKerja"]).value)
                    if t is not None:
                        s += t
                        ada = True
                return s if ada else None
            l1, l0 = labour(r), labour(r24)
            if l1 and l0 and l0 > 0:
                n += tulis(ws, r, col["g_L"], 100 * math.log(l1 / l0), proto)
    return n


def isi_luaran2(ws, col, by_key, ahh, sheet1, col1, by1):
    n = {"ahh": 0, "ipm": 0, "kampus": 0, "loglab": 0}
    proto = ws.cell(2, 4)
    for (code, year), r in by_key.items():
        if year == 2025 and "AHH_Prov" in col and kosong(ws.cell(r, col["AHH_Prov"]).value):
            v = ahh.get(code)
            if v is not None:
                n["ahh"] += tulis(ws, r, col["AHH_Prov"], ahh_teks(v), proto)
        if year == 2025 and "IPM_Prov_Nm" in col and kosong(ws.cell(r, col["IPM_Prov_Nm"]).value):
            ipm = ws.cell(r, col["IPM_Prov"]).value
            if not kosong(ipm):
                n["ipm"] += tulis(ws, r, col["IPM_Prov_Nm"], ipm, proto)
        if year == 2025 and "log_lab_tot" in col and kosong(ws.cell(r, col["log_lab_tot"]).value):
            tk = 0.0
            ada = False
            for s in SEKTOR:
                t = num(ws.cell(r, col[f"{s}_TenagaKerja"]).value)
                if t is not None:
                    tk += t
                    ada = True
            if ada and tk > 0:
                n["loglab"] += tulis(ws, r, col["log_lab_tot"], math.log(tk), proto)
        if year != 2017:
            continue
        r18, r19 = by_key.get((code, 2018)), by_key.get((code, 2019))
        for name in ("Campus_Prov", "Vocational_Prov"):
            if name not in col or not kosong(ws.cell(r, col[name]).value):
                continue
            v18 = num(ws.cell(r18, col[name]).value) if r18 else None
            v19 = num(ws.cell(r19, col[name]).value) if r19 else None
            if v18 is None:
                continue
            val = max(0, round(2 * v18 - v19)) if v19 is not None else round(v18)
            n["kampus"] += tulis(ws, r, col[name], val, proto)
    n["g"] = isi_growth_2025(ws, col, by_key, adhk_dari_sheet1(col1, by1, sheet1))
    return n


def isi_keterangan(ws):
    teks = [
        ("*Sektor PMA/PMDN kosong",
         "Diisi 0: realisasi BKPM tidak tercatat di KBLI itu. PMA_1/PMDN_1 tidak diubah."),
        ("*7_ADHB/8_ADHB/7_ADHK/8_ADHK 2023-2025",
         "BPS PDRB pengeluaran 2020-2024 terbit tapi portal diblokir Cloudflare. 6_ADHB = net "
         "(termasuk residual antar-daerah), jadi 6 ≠ 7−8. Diisi porsi 2022 terhadap 9_ADHB/9_ADHK."),
        ("*PDBDeflator, log_* Sheet1",
         "Formula lama merujuk workbook data_tfp yang tidak tertaut. "
         "PDBDeflator=9_ADHB/9_ADHK×100; log_ADHK_Tot=ln(9_ADHK); log_pmtb=ln(pmtb); log_lab_tot=ln(Σ TK)."),
        ("*TFP/g_K/kontrib Sheet1",
         "Disalin dari Analisis Luaran 2 untuk 2018-2024. 2017 butuh lag 2016; 2025 TFP tidak diestimasi."),
        ("*g_Y/g_L 2025",
         "g_Y=100×ln(ADHK_LU_t/ADHK_LU_{t-1}); g_L=100×ln(ΣTK_t/ΣTK_{t-1}). TK 2025=LOCF 2024 jadi g_L≈0."),
        ("*IPM_Prov_Nm 2025", "Disalin dari IPM_Prov (seri metode baru sudah dipakai di IPM_Prov)."),
        ("*AHH_Prov 2025",
         "UHH saat lahir BPS 2025 (IPM), di-scrape dari Databoks 13 Nov 2025. "
         "Pecah metode vs AHH 2017-2024 (seri lama lebih rendah ~0–3 tahun di beberapa provinsi)."),
        ("*Campus/Vocational 2017",
         "Statistik Pendidikan Tinggi 2017 tidak terunduh (BPS/PDDikti Cloudflare). "
         "Backcast linear 2×2018−2019."),
        ("*ICOR 2017", "Butuh ADHB_LU 2016; tidak diisi. Kalsel 2018 diisi pmtb/ΔADHB_LU."),
        ("*Nol struktural vs salah input",
         "KA/cargo KA = 0 di luar jaringan rel (bukan Jawa, Sumut, Sumsel, Lampung, Sulsel). "
         "Airpot_Logis/Commer = 0 jika bandara ada tapi bukan kelas itu. PMA/PMDN sektoral 0 = tidak ada realisasi. "
         "Indeks PCA 0 = minimum skala 0–100. "
         "*_RataUpah = 0 dikosongkan (rata-rata upah tidak mungkin 0); TK = 0 yang berpasangan dengan upah kosong juga dikosongkan (Sakernas tidak teramati). "
         "Kemantapan jalan 0 padahal panjang jalan > 0 dikosongkan (Banten 2021)."),
    ]
    ada = {ws.cell(r, 1).value for r in range(1, ws.max_row + 1)}
    if "*Sektor PMA/PMDN kosong" in ada:
        return
    r = ws.max_row + 2
    for nama, ket in teks:
        ws.cell(r, 1, nama)
        ws.cell(r, 2, ket)
        r += 1


def bersih_nol(ws, col):
    """Nol salah input → kosong. Nol struktural (KA di luar jaringan, bandara, PMA) dibiarkan."""
    n = 0
    for r in range(2, ws.max_row + 1):
        for s in SEKTOR:
            cw, ct = f"{s}_RataUpah", f"{s}_TenagaKerja"
            if cw in col:
                w = num(ws.cell(r, col[cw]).value)
                if w == 0:
                    ws.cell(r, col[cw]).value = None
                    n += 1
                    w = None
            else:
                w = None
            if ct in col:
                t = num(ws.cell(r, col[ct]).value)
                if t == 0 and w in (None, 0):
                    ws.cell(r, col[ct]).value = None
                    n += 1
        for road, pct in (("panjang_jalan_km", "jalan_mantap_pct"),
                          ("Road_Prov_National", "RoadC_Prov_National"),
                          ("Road_Prov", "RoadC_Prov_National")):
            if road not in col or pct not in col:
                continue
            if num(ws.cell(r, col[pct]).value) == 0 and num(ws.cell(r, col[road]).value):
                ws.cell(r, col[pct]).value = None
                n += 1
    return n


def hapus_formula_mati(ws, col, names):
    n = 0
    for r in range(2, ws.max_row + 1):
        for name in names:
            if name not in col:
                continue
            cell = ws.cell(r, col[name])
            if isinstance(cell.value, ArrayFormula) or (isinstance(cell.value, str) and cell.value.startswith("=")):
                cell.value = None
                n += 1
    return n


def ekspor_csv(ws, path):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        for row in ws.iter_rows(values_only=True):
            if row[0] is None and all(v is None for v in row):
                continue
            w.writerow(list(row))


def tulis_file(path, ahh, with_luaran=True):
    wb = load_workbook(path)
    ws1 = wb["Sheet1"]
    col1 = header_map(ws1)
    by1 = index_baris(ws1, col1)
    n1 = isi_identitas_sheet1(ws1, col1, by1)
    n_tfp = n_g = 0
    n2 = {}
    if with_luaran and "Analisis Luaran 2" in wb.sheetnames:
        ws2 = wb["Analisis Luaran 2"]
        col2 = header_map(ws2)
        by2 = index_baris(ws2, col2)
        n_tfp = salin_tfp_ke_sheet1(ws1, col1, by1, ws2, col2, by2)
        adhk = adhk_dari_sheet1(col1, by1, ws1)
        n_g = isi_growth_2025(ws1, col1, by1, adhk)
        n2 = isi_luaran2(ws2, col2, by2, ahh, ws1, col1, by1)
        hapus_formula_mati(ws1, col1, COPY_TFP + ["PDBDeflator", "log_ADHK_Tot", "log_pmtb", "log_lab_tot"])
        hapus_formula_mati(ws2, col2, COPY_TFP)
        n2["nol"] = bersih_nol(ws2, col2)
    else:
        n_g = isi_growth_2025(ws1, col1, by1, adhk_dari_sheet1(col1, by1, ws1))
    n1_nol = bersih_nol(ws1, col1)
    if "Keterangan" in wb.sheetnames:
        isi_keterangan(wb["Keterangan"])
    wb.save(path)
    if path.resolve() == XLSX_INP.resolve():
        ekspor_csv(ws1, CSV_SHEET1)
    print(f"{path.name}: deflator={n1['deflator']} log={n1['log']} "
          f"PMA0={n1['pma0']} PMDN0={n1['pmdn0']} 7/8={n1['ekspor']} "
          f"IPM_Nm={n1['ipm']} ICOR={n1['icor']} TFP_salin={n_tfp} g2025={n_g} "
          f"luaran={n2} nol_sheet1={n1_nol}")


def main():
    ahh = load_ahh()
    tulis_file(XLSX_INP, ahh, with_luaran=True)
    if XLSX_ROOT.exists() and XLSX_ROOT.resolve() != XLSX_INP.resolve():
        tulis_file(XLSX_ROOT, ahh, with_luaran=True)


if __name__ == "__main__":
    main()
