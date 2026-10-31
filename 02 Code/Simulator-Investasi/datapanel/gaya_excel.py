"""Gaya Excel bersama: warna legenda sama di semua workbook keluaran aplikasi."""

from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

BIRU_TUA = "1F3B57"
FILL_HEADER = PatternFill("solid", fgColor=BIRU_TUA)
FILL_INPUT = PatternFill("solid", fgColor="FFF2CC")      # kuning muda: boleh diubah
FILL_RUMUS = PatternFill("solid", fgColor="DDEBF7")      # biru muda: rumus, jangan ditimpa
FILL_IMPUTASI = PatternFill("solid", fgColor="F8CBAD")   # oranye: hasil imputasi
FILL_LONJAKAN = PatternFill("solid", fgColor="FFE699")   # kuning tua: lonjakan, cek
FILL_DIPERBARUI = PatternFill("solid", fgColor="C6E0B4")  # hijau: diperbarui dari unggahan
FILL_KUNCI = PatternFill("solid", fgColor="EDEDED")      # abu: kunci, jangan diubah
FONT_HEADER = Font(bold=True, color="FFFFFF")
FONT_JUDUL = Font(bold=True, size=14, color=BIRU_TUA)
FONT_TEBAL = Font(bold=True)
TIPIS = Side(style="thin", color="BFBFBF")
BINGKAI = Border(left=TIPIS, right=TIPIS, top=TIPIS, bottom=TIPIS)
TENGAH = Alignment(horizontal="center", vertical="center", wrap_text=True)
BUNGKUS = Alignment(wrap_text=True, vertical="top")

FMT_MILIAR = '#,##0.0'
FMT_PERSEN = '0.00'
FMT_RASIO = '0.000'


def header(ws, baris, kolom_awal, judul):
    for j, teks in enumerate(judul):
        c = ws.cell(row=baris, column=kolom_awal + j, value=teks)
        c.fill, c.font, c.alignment, c.border = FILL_HEADER, FONT_HEADER, TENGAH, BINGKAI


def lebar(ws, lebar_kolom):
    for j, w in enumerate(lebar_kolom, start=1):
        ws.column_dimensions[get_column_letter(j)].width = w


def legenda(ws, baris, kolom=1):
    item = [
        (FILL_INPUT, "Sel input: boleh diubah"),
        (FILL_RUMUS, "Sel rumus: dihitung ulang otomatis, jangan ditimpa"),
        (FILL_KUNCI, "Kunci (provinsi/tahun): jangan diubah"),
        (FILL_IMPUTASI, "Hasil imputasi pembersihan"),
        (FILL_LONJAKAN, "Lonjakan tahunan: perlu dicek"),
        (FILL_DIPERBARUI, "Diperbarui dari unggahan terakhir"),
    ]
    ws.cell(row=baris, column=kolom, value="Legenda warna").font = FONT_TEBAL
    for i, (fill, teks) in enumerate(item, start=1):
        ws.cell(row=baris + i, column=kolom).fill = fill
        ws.cell(row=baris + i, column=kolom).border = BINGKAI
        ws.cell(row=baris + i, column=kolom + 1, value=teks)
    return baris + len(item) + 1


def tulis_petunjuk(ws, judul, paragraf, baris_awal=1):
    ws.cell(row=baris_awal, column=1, value=judul).font = FONT_JUDUL
    r = baris_awal + 2
    for p in paragraf:
        if isinstance(p, tuple):
            ws.cell(row=r, column=1, value=p[0]).font = FONT_TEBAL
            ws.cell(row=r, column=2, value=p[1]).alignment = BUNGKUS
        else:
            ws.cell(row=r, column=1, value=p).alignment = BUNGKUS
            ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=6)
            ws.row_dimensions[r].height = max(15, 15 * (len(p) // 95 + 1))
        r += 1
    ws.column_dimensions["A"].width = 28
    ws.column_dimensions["B"].width = 90
    return r + 1
