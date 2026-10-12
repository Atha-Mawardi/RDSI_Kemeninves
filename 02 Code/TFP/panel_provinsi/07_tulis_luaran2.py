# Isi lubang Analisis Luaran 2 + salin kolom panel.
# Jalankan setelah 06_tulis_sheet1.py.

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from openpyxl import load_workbook
from pengaturan import SEKTOR, num, read_csv
from tulis_bantuan import (
    NEW_COLS, XLSX_INP, DJPK, load_panel, bundle, style_like, upah_agregat_dari_sheet,
)


def load_djpk_pad():
    out = {}
    for r in read_csv(DJPK):
        out[(int(r["code_prov"]), int(r["tahun"]))] = num(r["pad_realisasi"])
    return out


def main():
    panel = load_panel()
    djpk_pad = load_djpk_pad()
    wb = load_workbook(XLSX_INP)
    if "Analisis Luaran 2" not in wb.sheetnames:
        print("sheet Analisis Luaran 2 tidak ada")
        return
    ws = wb["Analisis Luaran 2"]
    hdr = [c.value for c in next(ws.iter_rows(min_row=1, max_row=1))]
    col = {h: i + 1 for i, h in enumerate(hdr) if h}
    by_key = {}
    for r in range(2, ws.max_row + 1):
        code, year = ws.cell(r, col["Code_Prov"]).value, ws.cell(r, col["Year"]).value
        if code is None:
            continue
        by_key[(int(code), int(year))] = r

    n_crime = n_pad = n_upah = 0
    for code, year in list(by_key):
        if year != 2025:
            continue
        r25, r24 = by_key[(code, 2025)], by_key.get((code, 2024))
        if r24 is None:
            continue
        if "Crime_Prov" in col and ws.cell(r25, col["Crime_Prov"]).value in (None, ""):
            ws.cell(r25, col["Crime_Prov"]).value = ws.cell(r24, col["Crime_Prov"]).value
            n_crime += 1
        p24, p25 = panel.get((code, 2024)), panel.get((code, 2025))
        g = 1.05
        if p24 and p25 and num(p24.get("ump")) and num(p25.get("ump")):
            g = num(p25["ump"]) / num(p24["ump"])
        for s in SEKTOR:
            key = f"{s}_RataUpah"
            if key not in col:
                continue
            if ws.cell(r25, col[key]).value in (None, "") and ws.cell(r24, col[key]).value not in (None, ""):
                ws.cell(r25, col[key]).value = float(ws.cell(r24, col[key]).value) * g
                n_upah += 1
            tk = f"{s}_TenagaKerja"
            if tk in col and ws.cell(r25, col[tk]).value in (None, "") and ws.cell(r24, col[tk]).value not in (None, ""):
                ws.cell(r25, col[tk]).value = ws.cell(r24, col[tk]).value

    if "PAD_Prov" in col:
        for year in range(2017, 2026):
            r = by_key.get((31, year))
            if r is None or ws.cell(r, col["PAD_Prov"]).value not in (None, ""):
                continue
            pad = djpk_pad.get((31, year))
            if pad is None:
                continue
            ws.cell(r, col["PAD_Prov"]).value = f"{pad:.2f}".replace(".", ",")
            n_pad += 1

    extra = [c for c, *_ in NEW_COLS if c not in col]
    start = ws.max_column + 1
    name_to_col = {}
    for j, name in enumerate(extra):
        c = start + j
        cell = ws.cell(1, c, name)
        style_like(ws.cell(1, 1), cell)
        name_to_col[name] = c
        col[name] = c
    proto = ws.cell(2, 4)
    for r in range(2, ws.max_row + 1):
        code, year = ws.cell(r, col["Code_Prov"]).value, ws.cell(r, col["Year"]).value
        if code is None:
            continue
        vals = bundle(panel, int(code), int(year))
        ua = upah_agregat_dari_sheet(ws, r, col) or vals.get("upah_agregat")
        for name in extra:
            val = ua if name == "Upah_Agregat" else vals.get(name)
            cell = ws.cell(r, name_to_col[name], val)
            style_like(proto, cell)

    wb.save(XLSX_INP)
    print(f"Luaran2: crime2025={n_crime}, PAD DKI={n_pad}, upah2025={n_upah}")


if __name__ == "__main__":
    main()
