"""Workbook dataset: hasil pembersihan dan templat unggah.

Baris 1 sheet `Data` memakai kode kanonik, jadi workbook keluaran dapat
diunggah ulang tanpa pemetaan. Label dan satuan ada di komentar header dan di
sheet `Kamus`.
"""

import io

import pandas as pd
from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.worksheet.datavalidation import DataValidation

from . import gaya_excel as G
from . import variabel as V
from .referensi import KODE_PROVINSI, NAMA_PROVINSI, PULAU_PROVINSI

PETUNJUK_DATA = [
    "Workbook ini keluaran Simulator Investasi dan TFP Provinsi. Sheet Data dapat disunting lalu "
    "diunggah kembali lewat menu Data > Unggah, dengan mode 'Perbarui versi yang ada' supaya sel "
    "yang tidak diubah tetap diwarisi dari versi induk.",
    ("Baris 1", "Kode kanonik variabel. Jangan diganti; label dan satuan ada di komentar sel "
                "header dan di sheet Kamus."),
    ("Kolom A-D", "Kunci: kode provinsi BPS (34 provinsi sebelum pemekaran Papua), nama, pulau, "
                  "tahun. Nama dan pulau hanya keterangan; aplikasi membaca kode dan tahun."),
    ("Menambah tahun", "Salin blok 34 baris tahun terakhir ke bawah, ganti tahunnya, isi angka "
                       "yang sudah terbit. Sel kosong dibiarkan kosong, jangan diisi nol."),
    ("Satuan", "Uang dalam miliar rupiah, tenaga kerja dalam jiwa. Bila berkas sumber memakai juta "
               "rupiah atau rupiah penuh, aplikasi mengenali dan mengonversinya, lalu mencatatnya "
               "di laporan pembersihan."),
    ("Provinsi pemekaran", "Data 38 provinsi boleh diunggah. Papua Selatan, Papua Tengah, dan "
                           "Papua Pegunungan dijumlahkan ke Papua; Papua Barat Daya ke Papua Barat."),
    ("Format angka", "Angka bertipe teks, format 1.234,5, dan tanda '-' dikonversi otomatis."),
]


def _isi_kamus(ws):
    G.header(ws, 1, 1, ["Kode", "Label", "Satuan", "Kelompok", "Wajib untuk simulasi", "Alias kolom yang dikenali"])
    for i, v in enumerate(V.DAFTAR, start=2):
        for j, val in enumerate([v.kode, v.label, v.satuan, v.grup, "ya" if v.wajib else "",
                                 ", ".join(v.alias)], start=1):
            ws.cell(row=i, column=j, value=val)
    G.lebar(ws, [14, 60, 12, 20, 12, 50])
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = f"A1:F{len(V.DAFTAR) + 1}"


def _header_data(ws, kolom):
    G.header(ws, 1, 1, ["kode", "provinsi", "pulau", "tahun"] + kolom)
    for j, k in enumerate(kolom, start=5):
        ws.cell(row=1, column=j).comment = Comment(f"{V.label(k)}\nSatuan: {V.satuan(k)}", "Simulator")
    ws.freeze_panes = "E2"
    G.lebar(ws, [7, 24, 13, 7] + [14] * len(kolom))
    ws.row_dimensions[1].height = 30


def tulis_dataset(df, catatan=None, temuan=None, judul="Dataset panel provinsi"):
    catatan = catatan or {}
    wb = Workbook()
    ws_p = wb.active
    ws_p.title = "Petunjuk"
    r = G.tulis_petunjuk(ws_p, judul, PETUNJUK_DATA)
    G.legenda(ws_p, r)

    ws = wb.create_sheet("Data")
    kolom = [v.kode for v in V.DAFTAR if v.kode in df.columns]
    _header_data(ws, kolom)
    for i, ((kode, tahun), row) in enumerate(df[kolom].iterrows(), start=2):
        for j, val in enumerate([int(kode), NAMA_PROVINSI.get(int(kode), ""),
                                 PULAU_PROVINSI.get(int(kode), ""), int(tahun)], start=1):
            ws.cell(row=i, column=j, value=val).fill = G.FILL_KUNCI
        cat = catatan.get((kode, tahun), {})
        for j, k in enumerate(kolom, start=5):
            v = row[k]
            c = ws.cell(row=i, column=j, value=None if pd.isna(v) else float(v))
            c.number_format = "#,##0" if V.satuan(k) == "jiwa" else G.FMT_MILIAR
            teks = cat.get(k)
            if teks:
                c.fill = (G.FILL_IMPUTASI if teks.startswith("imputasi") else
                          G.FILL_LONJAKAN if teks.startswith("lonjakan") else G.FILL_DIPERBARUI)
                c.comment = Comment(teks, "Pembersihan")
    ws.auto_filter.ref = f"A1:{ws.cell(row=1, column=4 + len(kolom)).column_letter}{len(df) + 1}"

    _isi_kamus(wb.create_sheet("Kamus"))
    if temuan:
        ws_l = wb.create_sheet("Laporan pembersihan")
        G.header(ws_l, 1, 1, ["Tingkat", "Langkah", "Pesan", "Detail"])
        for i, t in enumerate(temuan, start=2):
            ws_l.cell(row=i, column=1, value=t["tingkat"])
            ws_l.cell(row=i, column=2, value=t["langkah"])
            ws_l.cell(row=i, column=3, value=t["pesan"]).alignment = G.BUNGKUS
            ws_l.cell(row=i, column=4, value="; ".join(map(str, t.get("detail", [])))).alignment = G.BUNGKUS
        G.lebar(ws_l, [12, 18, 70, 70])
    wb.active = 1
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def templat(tahun, kolom=None):
    """Templat kosong 34 provinsi x tahun dengan validasi angka."""
    kolom = kolom or [v.kode for v in V.DAFTAR]
    wb = Workbook()
    ws_p = wb.active
    ws_p.title = "Petunjuk"
    r = G.tulis_petunjuk(ws_p, "Templat unggah data provinsi", PETUNJUK_DATA)
    G.legenda(ws_p, r)
    ws = wb.create_sheet("Data")
    _header_data(ws, kolom)
    n = 0
    for th in tahun:
        for kode in KODE_PROVINSI:
            n += 1
            for j, val in enumerate([kode, NAMA_PROVINSI[kode], PULAU_PROVINSI[kode], th], start=1):
                ws.cell(row=n + 1, column=j, value=val).fill = G.FILL_KUNCI
            for j in range(5, 5 + len(kolom)):
                ws.cell(row=n + 1, column=j).fill = G.FILL_INPUT
    akhir = ws.cell(row=1, column=4 + len(kolom)).column_letter
    dv = DataValidation(type="decimal", operator="greaterThanOrEqual", formula1="-1000000000000",
                        allow_blank=True, showErrorMessage=True,
                        errorTitle="Harus angka", error="Isi dengan angka (miliar Rp atau jiwa).")
    dv.add(f"E2:{akhir}{n + 1}")
    ws.add_data_validation(dv)
    dv_th = DataValidation(type="whole", operator="between", formula1="2000", formula2="2100",
                           showErrorMessage=True, error="Tahun 2000-2100")
    dv_th.add(f"D2:D{n + 1 + 500}")
    ws.add_data_validation(dv_th)
    _isi_kamus(wb.create_sheet("Kamus"))
    wb.active = 1
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
