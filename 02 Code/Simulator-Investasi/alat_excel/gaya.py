"""Gaya sel, warna, dan pembantu tata letak bersama."""

from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.workbook.defined_name import DefinedName

NAVY = "1F3A5F"
BIRU = "2E6DA4"
BIRU_MUDA = "E8EEF5"
ORANYE = "E07B39"
HIJAU = "2E8B57"
MERAH = "C0392B"
ABU = "7F8C8D"
KUNING = "FFF5CC"
ABU_MUDA = "F2F4F7"

FMT_P = "0.00"
FMT_P1 = "0.0"
FMT_T = "#,##0"
FMT_T1 = "#,##0.0"
FMT_PCT = "0%"
FMT_PCT1 = "0.0%"
FMT_4 = "0.0000"

F_HEADER = PatternFill("solid", fgColor=NAVY)
F_SUB = PatternFill("solid", fgColor=BIRU)
F_ISIAN = PatternFill("solid", fgColor=KUNING)
F_RUMUS = PatternFill("solid", fgColor=ABU_MUDA)
F_BAGIAN = PatternFill("solid", fgColor=BIRU_MUDA)
F_PUTIH = PatternFill("solid", fgColor="FFFFFF")

T_HEADER = Font(bold=True, color="FFFFFF", size=10)
T_JUDUL = Font(bold=True, color=NAVY, size=16)
T_SUBJUDUL = Font(color=ABU, size=10, italic=True)
T_BAGIAN = Font(bold=True, color=NAVY, size=11)
T_TEBAL = Font(bold=True, size=10)
T_BIASA = Font(size=10)
T_KECIL = Font(size=9, color=ABU)
T_ANGKA_BESAR = Font(bold=True, size=18, color=NAVY)
T_TAUTAN = Font(color=BIRU, underline="single", size=10)

TENGAH = Alignment(horizontal="center", vertical="center", wrap_text=True)
KIRI = Alignment(horizontal="left", vertical="center", wrap_text=False)
KIRI_BUNGKUS = Alignment(horizontal="left", vertical="top", wrap_text=True)
KANAN = Alignment(horizontal="right", vertical="center")
GARIS = Border(bottom=Side(style="thin", color="DDE3EA"))
KOTAK = Border(*(Side(style="thin", color="C9D3DE"),) * 4)


def kol(n):
    return get_column_letter(n)


def nama(wb, nama_, sheet, ref):
    """Nama terdefinisi tingkat workbook, mis. nama(wb, "TD", "Skenario", "$C$5")."""
    wb.defined_names[nama_] = DefinedName(nama_, attr_text=f"'{sheet}'!{ref}")


def tulis(ws, r, c, v, font=None, fill=None, fmt=None, align=None, border=None):
    cell = ws.cell(row=r, column=c, value=v)
    if font:
        cell.font = font
    if fill:
        cell.fill = fill
    if fmt:
        cell.number_format = fmt
    if align:
        cell.alignment = align
    if border:
        cell.border = border
    return cell


def pita(ws, judul, sub="", c2=14):
    """Judul lembar di baris 1-2."""
    tulis(ws, 1, 1, judul, font=T_JUDUL)
    if sub:
        tulis(ws, 2, 1, sub, font=T_SUBJUDUL)
    ws.row_dimensions[1].height = 24
    ws.sheet_view.showGridLines = False


def header(ws, r, c, judul, tinggi=None, fill=F_HEADER):
    for i, j in enumerate(judul):
        tulis(ws, r, c + i, j, font=T_HEADER, fill=fill, align=TENGAH)
    if tinggi:
        ws.row_dimensions[r].height = tinggi


def bagian(ws, r, c1, c2, teks):
    for c in range(c1, c2 + 1):
        ws.cell(row=r, column=c).fill = F_BAGIAN
    tulis(ws, r, c1, teks, font=T_BAGIAN, fill=F_BAGIAN)


def gabung(ws, r, c1, c2, v, font=None, fill=None, fmt=None, align=None):
    if c2 > c1:
        ws.merge_cells(start_row=r, start_column=c1, end_row=r, end_column=c2)
    return tulis(ws, r, c1, v, font=font, fill=fill, fmt=fmt, align=align)


def kartu(ws, r, c1, c2, judul, rumus, fmt, keterangan=""):
    """Kartu KPI tiga baris: judul kecil, angka besar, keterangan."""
    for rr in range(r, r + 3):
        for c in range(c1, c2 + 1):
            ws.cell(row=rr, column=c).fill = F_BAGIAN
    gabung(ws, r, c1, c2, judul, font=T_KECIL, fill=F_BAGIAN, align=TENGAH)
    gabung(ws, r + 1, c1, c2, rumus, font=T_ANGKA_BESAR, fill=F_BAGIAN, fmt=fmt, align=TENGAH)
    gabung(ws, r + 2, c1, c2, keterangan, font=T_KECIL, fill=F_BAGIAN, align=TENGAH)
    ws.row_dimensions[r + 1].height = 28


def lebar(ws, daftar, mulai=1):
    for i, w in enumerate(daftar):
        ws.column_dimensions[kol(mulai + i)].width = w


def warna_tab(ws, warna):
    ws.sheet_properties.tabColor = warna
