"""Rakit workbook Alat Excel."""

from pathlib import Path

from openpyxl import Workbook

from . import data, estimasi, hitung, mesin, skenario
from .konteks import kumpulkan

URUTAN = ["Petunjuk", "Beranda", "Skenario", "AsumsiProv", "Hasil", "Perbandingan", "Jelajah", "Pivot", "Data",
          "Kelengkapan", "Estimasi", "Hitung"]


def bangun(keluaran, versi=None, dasbor=True, ctx=None):
    ctx = ctx or kumpulkan(versi)
    wb = Workbook()
    wb.remove(wb.active)

    _, tata_data = data.lembar_data(wb, ctx)
    data.lembar_ref(wb, ctx, tata_data.mentah)
    _, rk = skenario.lembar_skenario(wb, ctx)
    skenario.lembar_asumsi_prov(wb, ctx)
    estimasi.lembar_estimasi(wb, ctx)
    ws_h, tata_h, r_bebas = hitung.lembar_hitung(wb, ctx)
    peta = [mesin.lembar_mesin(wb, ctx, s, rk, tata_h)[1] for s in range(len(ctx.slot))]
    kump = hitung.kumpulan(wb, ws_h, ctx, peta, r_bebas)

    if dasbor:
        from . import dasbor as D
        D.semua(wb, ctx, rk, peta, kump, tata_data)

    urut = [n for n in URUTAN if n in wb.sheetnames] + [s.sheet for s in ctx.slot] + ["Ref"]
    wb._sheets = [wb[n] for n in urut]
    wb.active = 1 if "Beranda" in wb.sheetnames else 0
    wb.calculation.fullCalcOnLoad = True

    keluaran = Path(keluaran)
    keluaran.parent.mkdir(parents=True, exist_ok=True)
    wb.save(keluaran)
    return keluaran, ctx
