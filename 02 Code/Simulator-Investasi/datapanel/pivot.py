"""Pivot bebas di peramban atas lima sumber: panel provinsi, panel sektoral, hasil skenario, IO sektor, aliran IRIO.

Server hanya mengirim tabel panjang ringkas: tiap dimensi dikodekan sebagai indeks ke daftar nilainya
(urutan daftar = urutan tampil default), ukuran sebagai angka. Agregasi, filter, subtotal, dan tampilan
dihitung di klien (static/js/pivot.js). Ekspor XLSX dibuat di server dari matriks yang sudah dirender.
"""

import io
import json
import math

import numpy as np
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render
from django.views.decorators.http import require_POST
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

from . import variabel as V
from .gaya_excel import BIRU_TUA, FILL_HEADER, FONT_HEADER
from .models import VersiData
from .panel import aditif, tambah_turunan
from .referensi import KELOMPOK, KELOMPOK_SEKTOR, KODE_SEKTOR, NAMA_KELOMPOK, NAMA_PROVINSI, NAMA_SEKTOR, PULAU, PULAU_PROVINSI

SUMBER = [
    ("panel", "Panel provinsi (data historis)"),
    ("sektoral", "Panel sektoral (VA, TK, PMA, PMDN per sektor)"),
    ("skenario", "Hasil skenario (tabel hitung)"),
    ("io_sektor", "IO: indikator provinsi × sektor"),
    ("io_aliran", "IO: aliran antara antarprovinsi"),
]
SEKTORAL = ("VA_", "TK_", "PMA_", "PMDN_")

HITUNG = {
    "I_tren": ("Tren PMA+PMDN", "miliar Rp", "Investasi", "jumlah", 0),
    "A1_real": ("Investasi dasar terealisasi", "miliar Rp", "Investasi", "jumlah", 0),
    "A2_real": ("Investasi tambahan terealisasi", "miliar Rp", "Investasi", "jumlah", 0),
    "I_kebutuhan": ("Kebutuhan PMA+PMDN", "miliar Rp", "Investasi", "jumlah", 0),
    "PMTB_nominal": ("PMTB nominal", "miliar Rp", "PMTB", "jumlah", 0),
    "PMTB_riil": ("PMTB riil", "miliar Rp", "PMTB", "jumlah", 0),
    "PMTB_kebutuhan": ("PMTB riil dibutuhkan", "miliar Rp", "PMTB", "jumlah", 0),
    "lnA_skenario": ("ln A (skenario)", "ln", "Produktivitas", {"bobot": "PDRB_skenario"}, 4),
    "bonus_sektor": ("Bonus sektor (ln)", "ln", "Produktivitas", {"bobot": "PDRB_skenario"}, 4),
    "determinan_ln": ("Efek determinan TFP (ln)", "ln", "Produktivitas", {"bobot": "PDRB_skenario"}, 4),
    "kejutan_ln": ("Shock (ln)", "ln", "Produktivitas", {"bobot": "PDRB_skenario"}, 4),
    "faktor_realisasi": ("Faktor realisasi", "rasio", "Produktivitas", {"bobot": "PDRB_skenario"}, 3),
    "PDRB_dasar": ("PDRB tanpa penambahan investasi", "miliar Rp", "PDRB", "jumlah", 0),
    "PDRB_skenario": ("PDRB dengan penambahan investasi", "miliar Rp", "PDRB", "jumlah", 0),
    "PDRB_sasaran": ("PDRB sasaran", "miliar Rp", "PDRB", "jumlah", 0),
    "g_dasar": ("Laju tanpa penambahan investasi", "%", "Laju", {"bobot": "PDRB_dasar"}, 2),
    "g_skenario": ("Laju dengan penambahan investasi", "%", "Laju", {"bobot": "PDRB_skenario"}, 2),
    "g_sasaran": ("Laju sasaran", "%", "Laju", {"bobot": "PDRB_sasaran"}, 2),
}


def _angka(v, d=4):
    if v is None:
        return None
    v = float(v)
    return None if math.isnan(v) or math.isinf(v) else round(v, d)


def _paket(judul, keterangan, dimensi, ukuran, rows):
    """dimensi: [(kunci, label, urutan|None)], ukuran: [dict], rows: [dict] -> JSON ringkas."""
    nilai = {}
    for kunci, _, urutan in dimensi:
        ada = {r[kunci] for r in rows}
        if urutan:
            nilai[kunci] = [v for v in urutan if v in ada] + sorted(ada - set(urutan), key=str)
        else:
            nilai[kunci] = sorted(ada, key=lambda v: (isinstance(v, str), v))
    indeks = {k: {v: i for i, v in enumerate(vs)} for k, vs in nilai.items()}
    data = [[indeks[k][r[k]] for k, _, _ in dimensi] + [_angka(r.get(u["kunci"]), u.get("bulat", 4)) for u in ukuran]
            for r in rows]
    return {
        "judul": judul, "keterangan": keterangan,
        "dimensi": [{"kunci": k, "label": lbl, "nilai": nilai[k]} for k, lbl, _ in dimensi],
        "ukuran": [{k: v for k, v in u.items() if k != "bulat"} for u in ukuran],
        "data": data,
    }


def _urut_provinsi(kode):
    return [NAMA_PROVINSI[k] for k in sorted(kode)]


def _dim_wilayah(kode_list):
    return [("pulau", "Pulau", PULAU), ("provinsi", "Provinsi", _urut_provinsi(kode_list))]


# ------------------------------------------------------------------ sumber
def _versi(request):
    pk = request.GET.get("versi")
    v = VersiData.objects.filter(pk=pk).first() if pk else None
    return v or VersiData.aktif()


def sumber_panel(request):
    versi = _versi(request)
    if not versi:
        return None
    df = tambah_turunan(versi.ke_dataframe_38() if versi.bisa_rinci_papua else versi.ke_dataframe())
    kol = [c for c in df.columns if not c.startswith(SEKTORAL)]
    ukuran = []
    for c in kol:
        sat = V.satuan(c)
        grup = V.PER_KODE[c].grup if c in V.PER_KODE else V.GRUP_TURUNAN.get(c, "Indikator turunan")
        ag = "jumlah" if aditif(c) else ({"bobot": "PDRB_ADHK"} if c.startswith("G_") else "rata")
        ukuran.append({"kunci": c, "label": V.label(c), "satuan": sat, "grup": grup, "agregat": ag,
                       "digit": 0 if sat in ("miliar Rp", "jiwa", "orang", "Rp/bulan", "km", "unit")
                       else 2 if sat in ("%", "tahun", "indeks", "per 100 ribu penduduk") else 3})
    rows = []
    for (kode, tahun), r in df[kol].iterrows():
        rows.append({"pulau": PULAU_PROVINSI[kode], "provinsi": NAMA_PROVINSI[kode], "tahun": int(tahun),
                     **{c: r[c] for c in kol}})
    kode = sorted({k for k, _ in df.index})
    return _paket(f"Panel provinsi · {versi}", "Satu baris per provinsi × tahun (miliar Rp kecuali disebut).",
                  _dim_wilayah(kode) + [("tahun", "Tahun", None)], ukuran, rows)


def sumber_sektoral(request):
    versi = _versi(request)
    if not versi:
        return None
    df = versi.ke_dataframe_38() if versi.bisa_rinci_papua else versi.ke_dataframe()
    rows = []
    for (kode, tahun), r in df.iterrows():
        for s in KODE_SEKTOR:
            g = lambda p: r.get(f"{p}_{s}")  # noqa: E731
            pma, pmdn = g("PMA"), g("PMDN")
            inv = None if (_angka(pma) is None and _angka(pmdn) is None) else (_angka(pma) or 0) + (_angka(pmdn) or 0)
            rows.append({"pulau": PULAU_PROVINSI[kode], "provinsi": NAMA_PROVINSI[kode], "tahun": int(tahun),
                         "kelompok": NAMA_KELOMPOK[KELOMPOK_SEKTOR[s]], "sektor": f"{s} {NAMA_SEKTOR[s]}",
                         "VA": g("VA"), "TK": g("TK"), "PMA": pma, "PMDN": pmdn, "INV": inv})
    ukuran = [
        {"kunci": "VA", "label": "Nilai tambah ADHK", "satuan": "miliar Rp", "grup": "Output", "agregat": "jumlah", "digit": 0},
        {"kunci": "TK", "label": "Tenaga kerja", "satuan": "jiwa", "grup": "Tenaga kerja", "agregat": "jumlah", "digit": 0},
        {"kunci": "PMA", "label": "PMA", "satuan": "miliar Rp", "grup": "Investasi", "agregat": "jumlah", "digit": 0},
        {"kunci": "PMDN", "label": "PMDN", "satuan": "miliar Rp", "grup": "Investasi", "agregat": "jumlah", "digit": 0},
        {"kunci": "INV", "label": "PMA + PMDN", "satuan": "miliar Rp", "grup": "Investasi", "agregat": "jumlah", "digit": 0},
    ]
    kode = sorted({k for k, _ in df.index})
    sektor = [f"{s} {NAMA_SEKTOR[s]}" for s in KODE_SEKTOR]
    return _paket(f"Panel sektoral · {versi}", "Satu baris per provinsi × tahun × sektor lapangan usaha.",
                  _dim_wilayah(kode) + [("tahun", "Tahun", None),
                                        ("kelompok", "Kelompok sektor", [n for _, n in KELOMPOK]),
                                        ("sektor", "Sektor", sektor)], ukuran, rows)


def sumber_skenario(request):
    from simulasi import aktif
    from simulasi.models import Skenario

    qs = Skenario.objects.select_related("hasil").filter(hasil__isnull=False)
    pilih = request.GET.get("sk", "")
    if pilih == "semua":
        daftar = list(qs.order_by("kelompok", "templat", "nama"))
    elif pilih:
        pk = [int(x) for x in pilih.split(",") if x.isdigit()]
        daftar = sorted(qs.filter(pk__in=pk), key=lambda s: pk.index(s.pk))
    else:
        a = aktif.ambil(request)
        daftar = [a] if a else []
    daftar = [s for s in daftar if s.hasil.data.get("hitung")]
    if not daftar:
        return None
    rows, kode = [], set()
    for s in daftar:
        h = s.hasil.data["hitung"]
        for b in h["baris"]:
            r = dict(zip(h["kolom"], b))
            kode.add(r["kode"])
            r.update(skenario=s.label, kelompok_sk="Default" if s.bawaan else "Kustom", tahun=int(r["tahun"]))
            rows.append(r)
    ukuran = [{"kunci": k, "label": lbl, "satuan": sat, "grup": g, "agregat": ag, "digit": d}
              for k, (lbl, sat, g, ag, d) in HITUNG.items()]
    return _paket("Hasil skenario · " + ", ".join(s.label for s in daftar),
                  "Tabel hitung: satu baris per skenario × provinsi × tahun proyeksi (miliar Rp riil kecuali disebut).",
                  [("kelompok_sk", "Kelompok skenario", ["Default", "Kustom"]),
                   ("skenario", "Skenario", [s.label for s in daftar])] + _dim_wilayah(kode) + [("tahun", "Tahun", None)],
                  ukuran, rows)


def _tabel_io(request):
    from io_irio.models import TabelIO

    qs = TabelIO.objects.filter(jenis="irio")
    t = qs.filter(tahun=request.GET.get("tahun") or 0, metode=request.GET.get("metode") or "RAS").first()
    return t or qs.order_by("-tahun", "metode").first()


def sumber_io_sektor(request):
    from io_irio.analisis import aliran, tabel

    t = _tabel_io(request)
    if not t:
        return None
    tb = tabel(t)
    kol = tb.L.sum(axis=0)
    ntb = tb.v @ tb.L
    B4 = tb.blok(tb.L)
    lokal = np.einsum("rsrj->rj", B4).reshape(-1)
    bocor = (1 - lokal / np.where(kol > 0, kol, 1)) * 100
    G_bar = tb.G.sum(axis=1)
    bl, fl = kol / kol.mean(), G_bar / G_bar.mean()
    Zb = tb.blok(tb.Z)
    keluar = Zb.sum(axis=(2, 3)) - np.einsum("rsrj->rs", Zb)  # (R,S) jual ke provinsi lain
    masuk = Zb.sum(axis=(0, 1)) - np.einsum("rirs->rs", Zb)   # (R,S) beli dari provinsi lain
    rows = []
    for r, kd in enumerate(tb.wil):
        for s, sk in enumerate(tb.sek):
            i = r * tb.S + s
            rows.append({"pulau": PULAU_PROVINSI[kd], "provinsi": NAMA_PROVINSI[kd],
                         "kelompok": NAMA_KELOMPOK[KELOMPOK_SEKTOR[sk]], "sektor": f"{sk} {NAMA_SEKTOR[sk]}",
                         "output": tb.x[i] / 1e6, "ntb": tb.va[i] / 1e6, "po": kol[i], "pn": ntb[i],
                         "limpahan": bocor[i], "bl": bl[i], "fl": fl[i],
                         "ekspor": keluar[r, s] / 1e6, "impor": masuk[r, s] / 1e6})
    W = {"bobot": "output"}
    ukuran = [
        {"kunci": "output", "label": "Output", "satuan": "T Rp", "grup": "Neraca", "agregat": "jumlah", "digit": 1},
        {"kunci": "ntb", "label": "Nilai tambah (NTB)", "satuan": "T Rp", "grup": "Neraca", "agregat": "jumlah", "digit": 1},
        {"kunci": "ekspor", "label": "Jual antara ke provinsi lain", "satuan": "T Rp", "grup": "Neraca", "agregat": "jumlah", "digit": 1},
        {"kunci": "impor", "label": "Beli antara dari provinsi lain", "satuan": "T Rp", "grup": "Neraca", "agregat": "jumlah", "digit": 1},
        {"kunci": "po", "label": "Multiplier output", "satuan": "", "grup": "Multiplier", "agregat": W, "digit": 3},
        {"kunci": "pn", "label": "Multiplier NTB", "satuan": "", "grup": "Multiplier", "agregat": W, "digit": 3},
        {"kunci": "limpahan", "label": "Limpahan ke provinsi lain", "satuan": "%", "grup": "Multiplier", "agregat": W, "digit": 1},
        {"kunci": "bl", "label": "Keterkaitan ke belakang (BL)", "satuan": "", "grup": "Keterkaitan", "agregat": W, "digit": 3},
        {"kunci": "fl", "label": "Keterkaitan ke depan (FL)", "satuan": "", "grup": "Keterkaitan", "agregat": W, "digit": 3},
    ]
    sektor = [f"{s} {NAMA_SEKTOR[s]}" for s in tb.sek]
    return _paket(f"IO sektor · IRIO {t.tahun} {t.metode}",
                  "Satu baris per provinsi × sektor; multiplier dan keterkaitan memakai invers Leontief antarwilayah penuh.",
                  _dim_wilayah(tb.wil) + [("kelompok", "Kelompok sektor", [n for _, n in KELOMPOK]),
                                          ("sektor", "Sektor", sektor)], ukuran, rows)


def sumber_io_aliran(request):
    from io_irio.analisis import tabel

    t = _tabel_io(request)
    if not t:
        return None
    tb = tabel(t)
    F = tb.blok(tb.Z).sum(axis=3)  # (R asal, S asal, R tujuan)
    rows = []
    for a, ka in enumerate(tb.wil):
        for s, sk in enumerate(tb.sek):
            for b, kb in enumerate(tb.wil):
                v = F[a, s, b] / 1e6
                if v <= 0:
                    continue
                rows.append({"pulau_asal": PULAU_PROVINSI[ka], "prov_asal": NAMA_PROVINSI[ka],
                             "pulau_tujuan": PULAU_PROVINSI[kb], "prov_tujuan": NAMA_PROVINSI[kb],
                             "sektor": f"{sk} {NAMA_SEKTOR[sk]}", "jenis": "Dalam provinsi" if a == b else "Antarprovinsi",
                             "aliran": v})
    prov = _urut_provinsi(tb.wil)
    return _paket(f"Aliran IRIO {t.tahun} {t.metode}",
                  "Transaksi antara: provinsi asal (penjual) × sektor asal × provinsi tujuan (pembeli), T Rp.",
                  [("pulau_asal", "Pulau asal", PULAU), ("prov_asal", "Provinsi asal", prov),
                   ("pulau_tujuan", "Pulau tujuan", PULAU), ("prov_tujuan", "Provinsi tujuan", prov),
                   ("sektor", "Sektor asal", [f"{s} {NAMA_SEKTOR[s]}" for s in tb.sek]),
                   ("jenis", "Jenis aliran", ["Antarprovinsi", "Dalam provinsi"])],
                  [{"kunci": "aliran", "label": "Aliran antara", "satuan": "T Rp", "grup": "Aliran",
                    "agregat": "jumlah", "digit": 2, "bulat": 5}], rows)


PENYEDIA = {"panel": sumber_panel, "sektoral": sumber_sektoral, "skenario": sumber_skenario,
            "io_sektor": sumber_io_sektor, "io_aliran": sumber_io_aliran}


# ------------------------------------------------------------------ views
def pivot(request):
    from io_irio.models import TabelIO
    from simulasi import aktif

    sk = aktif.ambil(request)
    io = TabelIO.objects.filter(jenis="irio").order_by("tahun", "metode")
    return render(request, "pivot.html", {
        "sumber": SUMBER,
        "versi": VersiData.objects.filter(status__in=[VersiData.Status.SIAP, VersiData.Status.AKTIF]),
        "versi_aktif": VersiData.aktif(),
        "grup_sk": aktif.grup(),
        "sk_awal": sk.pk if sk else None,
        "io_tahun": sorted({t.tahun for t in io}, reverse=True),
        "io_metode": sorted({t.metode for t in io}),
    })


def data(request):
    f = PENYEDIA.get(request.GET.get("sumber", "panel"))
    if not f:
        return JsonResponse({"error": "Sumber tidak dikenal."}, status=400)
    hasil = f(request)
    if hasil is None:
        return JsonResponse({"error": "Sumber ini belum punya data (versi data, hasil skenario, atau tabel IO)."}, status=404)
    return JsonResponse(hasil)


TIPIS = Side(style="thin", color="BFBFBF")
GANDA = Side(style="double", color=BIRU_TUA)
FILL_GRUP = PatternFill("solid", fgColor="E8EEF5")
FILL_SUB = PatternFill("solid", fgColor="F3F6FA")


@require_POST
def xlsx(request):
    """Tulis matriks pivot yang sudah dirender klien ke XLSX dengan gaya neraca."""
    m = json.loads(request.body or "{}")
    wb = Workbook()
    ws = wb.active
    ws.title = "Pivot"
    ws["A1"] = m.get("judul", "Pivot")
    ws["A1"].font = Font(bold=True, size=13, color=BIRU_TUA)
    ws["A2"] = m.get("keterangan", "")
    ws["A2"].font = Font(italic=True, color="7F8C8D", size=9)
    r0 = 4
    header = m.get("header", [])
    for i, baris in enumerate(header):
        c = 1
        for sel in baris:
            teks, rentang = (sel.get("t", ""), sel.get("n", 1)) if isinstance(sel, dict) else (sel, 1)
            cell = ws.cell(r0 + i, c, teks)
            cell.fill, cell.font = FILL_HEADER, FONT_HEADER
            cell.alignment = Alignment(horizontal="center" if c > 1 else "left", vertical="center", wrap_text=True)
            if rentang > 1:
                ws.merge_cells(start_row=r0 + i, start_column=c, end_row=r0 + i, end_column=c + rentang - 1)
            c += rentang
    r = r0 + len(header)
    digit = m.get("digit", [])
    if isinstance(digit, (int, float)):
        digit = [int(digit)] * max((len(b.get("nilai", [])) for b in m.get("baris", [])), default=0)
    for b in m.get("baris", []):
        jenis, tingkat = b.get("jenis", ""), b.get("tingkat", 0)
        cell = ws.cell(r, 1, b.get("label", ""))
        cell.alignment = Alignment(indent=tingkat * 2)
        for j, v in enumerate(b.get("nilai", [])):
            c = ws.cell(r, j + 2, v)
            d = digit[j] if j < len(digit) else 1
            c.number_format = "#,##0" if d == 0 else "#,##0." + "0" * d
        n = len(b.get("nilai", [])) + 1
        for j in range(1, n + 1):
            c = ws.cell(r, j)
            if jenis == "grup":
                c.fill, c.font = FILL_GRUP, Font(bold=True, color=BIRU_TUA)
            elif jenis == "subtotal":
                c.fill, c.font = FILL_SUB, Font(bold=True)
                c.border = Border(top=TIPIS)
            elif jenis == "total":
                c.font = Font(bold=True)
                c.border = Border(top=Side(style="thin", color=BIRU_TUA), bottom=GANDA)
        r += 1
    ws.column_dimensions["A"].width = 34
    for j in range(2, ws.max_column + 1):
        ws.column_dimensions[get_column_letter(j)].width = 14
    ws.freeze_panes = ws.cell(r0 + len(header), 2)
    buf = io.BytesIO()
    wb.save(buf)
    resp = HttpResponse(buf.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    resp["Content-Disposition"] = f'attachment; filename="{m.get("berkas", "pivot")}.xlsx"'
    return resp
