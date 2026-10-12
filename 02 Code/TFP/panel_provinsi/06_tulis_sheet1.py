# Tulis kolom panel ke Sheet1 + Keterangan (geografi 34 provinsi).
# Isi juga upah sektoral 2025.

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from openpyxl import load_workbook
from pengaturan import SEKTOR
from tulis_bantuan import (
    NEW_COLS, XLSX_INP, XLSX_ROOT, load_panel, bundle, style_like, upah_agregat_dari_sheet,
)


def isi_upah_2025(ws, col, by_key):
    n_upah = n_tk = 0
    for code, year in list(by_key):
        if year != 2025:
            continue
        r25, r24 = by_key[(code, 2025)], by_key.get((code, 2024))
        if r24 is None:
            continue
        u24 = ws.cell(r24, col["UMP_Prov"]).value
        u25 = ws.cell(r25, col["UMP_Prov"]).value
        g = (float(u25) / float(u24)) if u24 and u25 and float(u24) > 0 else 1.05
        for s in SEKTOR:
            c_w, c_t = col[f"{s}_RataUpah"], col[f"{s}_TenagaKerja"]
            if ws.cell(r25, c_w).value in (None, "") and ws.cell(r24, c_w).value not in (None, ""):
                ws.cell(r25, c_w).value = float(ws.cell(r24, c_w).value) * g
                n_upah += 1
            if ws.cell(r25, c_t).value in (None, "") and ws.cell(r24, c_t).value not in (None, ""):
                ws.cell(r25, c_t).value = ws.cell(r24, c_t).value
                n_tk += 1
    return n_upah, n_tk


def tambah_kolom(ws, col):
    if "Upah_Agregat" in col:
        return {name: col[name] for name, *_ in NEW_COLS if name in col}
    start = ws.max_column + 1
    name_to_col = {}
    for j, (name, *_rest) in enumerate(NEW_COLS):
        c = start + j
        cell = ws.cell(1, c, name)
        style_like(ws.cell(1, 1), cell)
        name_to_col[name] = c
    return name_to_col


def isi_nilai_baru(ws, col, name_to_col, panel):
    proto = ws.cell(2, col["PMA_1"])
    n_new = 0
    for r in range(2, ws.max_row + 1):
        code, year = ws.cell(r, col["Code_Prov"]).value, ws.cell(r, col["Year"]).value
        if code is None:
            continue
        vals = bundle(panel, int(code), int(year))
        ua = upah_agregat_dari_sheet(ws, r, col) or vals.get("upah_agregat")
        mapping = {"Upah_Agregat": ua}
        for name, *_ in NEW_COLS:
            if name == "Upah_Agregat":
                continue
            mapping[name] = vals.get(name)
        for name, val in mapping.items():
            cell = ws.cell(r, name_to_col[name], val)
            style_like(proto, cell)
            if val is not None:
                n_new += 1
    return n_new


def isi_keterangan(ws):
    for row in ws.iter_rows(min_row=1, max_row=ws.max_row, max_col=1, values_only=True):
        if row[0] == "Upah_Agregat":
            return
    r = ws.max_row + 2
    ws.cell(r, 1, "Variabel (panel 2017-2025)")
    ws.cell(r, 2, "Keterangan")
    ws.cell(r, 3, "Satuan")
    ws.cell(r, 4, "Metode Agregasi Papua")
    r += 1
    for name, ket, satuan, metode in NEW_COLS:
        ws.cell(r, 1, name)
        ws.cell(r, 2, ket)
        ws.cell(r, 3, satuan)
        ws.cell(r, 4, metode)
        r += 1
    ws.cell(r, 1, "*Upah 2025")
    ws.cell(r, 2, "Sakernas 2025 belum terbit; *_RataUpah = 2024 × (UMP_2025/UMP_2024); TK disalin 2024")
    r += 1
    ws.cell(r, 1, "*Pemekaran")
    ws.cell(r, 2, "Sheet1 tetap 34 provinsi. Kolom baru 2023+ kode 91/94 = gabungan induk+anak.")


def tulis_satu(path, panel, with_keterangan=True):
    wb = load_workbook(path)
    ws = wb["Sheet1"]
    hdr = [c.value for c in next(ws.iter_rows(min_row=1, max_row=1))]
    col = {h: i + 1 for i, h in enumerate(hdr) if h}
    by_key = {}
    for r in range(2, ws.max_row + 1):
        code, year = ws.cell(r, col["Code_Prov"]).value, ws.cell(r, col["Year"]).value
        if code is None:
            continue
        by_key[(int(code), int(year))] = r
    n_upah, n_tk = isi_upah_2025(ws, col, by_key)
    name_to_col = tambah_kolom(ws, col)
    n_new = isi_nilai_baru(ws, col, name_to_col, panel)
    if with_keterangan and "Keterangan" in wb.sheetnames:
        isi_keterangan(wb["Keterangan"])
    wb.save(path)
    print(f"{path.name}: upah2025={n_upah}, TK2025={n_tk}, sel baru={n_new}")


def main():
    panel = load_panel()
    tulis_satu(XLSX_INP, panel)
    if XLSX_ROOT.exists():
        tulis_satu(XLSX_ROOT, panel)


if __name__ == "__main__":
    main()
