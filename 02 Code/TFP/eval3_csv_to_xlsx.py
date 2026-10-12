#!/usr/bin/env python3
"""Stacked esttab CSV → xlsx, one sheet per equation."""
import csv
import re
import sys
from pathlib import Path

try:
    from openpyxl import Workbook
    from openpyxl.styles import Font
    from openpyxl.utils import get_column_letter
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "-q"])
    from openpyxl import Workbook
    from openpyxl.styles import Font
    from openpyxl.utils import get_column_letter

EST = (
    "POLS|FE2W|FEAR1|FELDV|OLSLDV|IVSS|IVAH|RE2W|LSDVC|"
    "FGLS|CRE|DK|LAG|SYS|FE|RA|RB|RC|RD|RQ|RT"
)
HEADER = re.compile(rf"^({EST})_(.+)$")
ROBUST = {"RA", "RB", "RC", "RD", "RQ", "RT"}


def sheet_name(header_row):
    h = header_row[1] if len(header_row) > 1 else "sheet"
    m = HEADER.match(h or "")
    if not m:
        return (h or "sheet")[:31]
    est, rest = m.group(1), m.group(2)
    name = f"{rest}_R" if est in ROBUST else rest
    return name[:31]


def is_header(row):
    if len(row) < 2:
        return False
    if (row[0] or "").strip():
        return False
    return bool(HEADER.match(row[1] or ""))


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    tables, cur = [], []
    with src.open(newline="", encoding="utf-8") as f:
        for row in csv.reader(f):
            if is_header(row) and cur:
                tables.append(cur)
                cur = [row]
            else:
                cur.append(row)
        if cur:
            tables.append(cur)

    wb = Workbook()
    ws = wb.active
    ws.title = "README"
    ws["A1"] = "eval3 — semua model (pengganti eval3_tables - all models.csv)"
    ws["A2"] = "Tiap sheet = satu persamaan (outcome_spec). Sheet *_R = robustness RA–RT."
    ws["A3"] = "Baris koefisien lalu standard error; * p<0.10 ** p<0.05 *** p<0.01"
    ws["A4"] = "Headline estimator = FGLS. FE2W hanya pembanding."
    ws["A5"] = f"Jumlah tabel: {len(tables)}"
    ws.column_dimensions["A"].width = 90

    used = {"README"}
    for t in tables:
        raw = sheet_name(t[0])
        name, i = raw, 2
        while name in used:
            name = f"{raw}_{i}"[:31]
            i += 1
        used.add(name)
        ws = wb.create_sheet(name)
        widths = {}
        for r_i, row in enumerate(t, 1):
            for c_i, val in enumerate(row, 1):
                cell = ws.cell(r_i, c_i, val)
                if r_i == 1:
                    cell.font = Font(bold=True)
                widths[c_i] = max(widths.get(c_i, 8), min(len(str(val)), 28))
        for c_i, w in widths.items():
            ws.column_dimensions[get_column_letter(c_i)].width = w + 1

    dst.parent.mkdir(parents=True, exist_ok=True)
    wb.save(dst)
    print(f"wrote {dst} ({len(tables)} sheets)")


if __name__ == "__main__":
    main()
