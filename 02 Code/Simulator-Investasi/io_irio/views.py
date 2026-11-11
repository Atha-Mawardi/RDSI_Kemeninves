import numpy as np
from django.contrib import messages
from django.core.management import call_command
from django.http import JsonResponse
from django.shortcuts import redirect, render
from django.views.decorators.http import require_POST

from datapanel.referensi import KODE_PROVINSI, NAMA_PROVINSI, PULAU, PULAU_PROVINSI
from simulasi import aktif
from simulasi.models import Skenario

from . import analisis as A
from .models import TabelIO


def beranda(request):
    semua = list(TabelIO.objects.all())
    irio = [t for t in semua if t.jenis == TabelIO.Jenis.IRIO]
    sk = aktif.ambil(request)
    return render(request, "io_irio/beranda.html", {
        "tabel": semua, "ada": bool(irio),
        "tahun_irio": sorted({t.tahun for t in irio}),
        "tahun_nas": sorted({t.tahun for t in semua if t.jenis == TabelIO.Jenis.NASIONAL}),
        "metode": sorted({t.metode for t in irio}),
        "sektor": A.label_sektor(),
        "wilayah": A.label_wilayah(KODE_PROVINSI),
        "pulau": PULAU,
        "skenario": Skenario.objects.filter(hasil__isnull=False).order_by("kelompok", "templat", "nama"),
        "sk": sk,
        "jembatan": TabelIO.objects.filter(jenis=TabelIO.Jenis.PMTB).first(),
    })


@require_POST
def muat_ulang(request):
    call_command("muat_io")
    messages.success(request, "Tabel IO dan IRIO dimuat ulang dari folder 01 Data/IO-IRIO-NA/processed.")
    return redirect("io:beranda")


def _ambil(jenis, request):
    th = request.GET.get("tahun")
    metode = request.GET.get("metode") or "RAS"
    qs = TabelIO.objects.filter(jenis=jenis, metode=metode)
    t = qs.filter(tahun=th).first() if th else qs.order_by("-tahun").first()
    return t


def _galat(pesan, status=404):
    return JsonResponse({"error": pesan}, status=status)


def api_aliran(request):
    t = _ambil(TabelIO.Jenis.IRIO, request)
    if not t:
        return _galat("Tabel IRIO tidak ada untuk pilihan ini.")
    tb = A.tabel(t)
    asal = [s for s in request.GET.get("asal", "").split(",") if s in tb.sek] or None
    tujuan = [s for s in request.GET.get("tujuan", "").split(",") if s in tb.sek] or None
    F = A.aliran(tb, asal, tujuan) / 1e6  # triliun
    return JsonResponse({"tabel": t.label, "wil": tb.wil, "matriks": F.round(4).tolist(),
                         "intra": float(np.trace(F)), "total": float(F.sum())})


def api_keterkaitan(request):
    sumber = request.GET.get("sumber", "irio")
    if sumber == "nasional":
        t = _ambil(TabelIO.Jenis.NASIONAL, request)
        if not t:
            return _galat("IO nasional tersedia untuk 2021–2025 saja.")
        tb = A.tabel(t)
        hasil = A.keterkaitan(tb.Z, tb.x, tb.va)
    else:
        t = _ambil(TabelIO.Jenis.IRIO, request)
        if not t:
            return _galat("Tabel IRIO tidak ada untuk pilihan ini.")
        tb = A.tabel(t)
        kode = int(request.GET.get("wilayah") or 0)
        hasil = A.keterkaitan_wilayah(tb, kode) if kode else A.keterkaitan(*A.nasional_dari_irio(tb))
    hasil.update({"tabel": f"{t.get_jenis_display()} {t.label}", "sek": tb.sek})
    return JsonResponse(hasil)


def api_tren(request):
    """Multiplier output per sektor menurut tahun (semua tabel yang dimuat untuk satu metode)."""
    sumber = request.GET.get("sumber", "irio")
    metode = request.GET.get("metode") or "RAS"
    kode = int(request.GET.get("wilayah") or 0)
    jenis = TabelIO.Jenis.NASIONAL if sumber == "nasional" else TabelIO.Jenis.IRIO
    tahun, seri = [], []
    for t in TabelIO.objects.filter(jenis=jenis, metode=metode).order_by("tahun"):
        tb = A.tabel(t)
        if jenis == TabelIO.Jenis.NASIONAL:
            k = A.keterkaitan(tb.Z, tb.x, tb.va)
        elif kode:
            k = A.keterkaitan_wilayah(tb, kode)
        else:
            k = A.keterkaitan(*A.nasional_dari_irio(tb))
        tahun.append(t.tahun)
        seri.append({"output": k["multiplier_output"], "ntb": k["multiplier_ntb"], "bl": k["bl"], "fl": k["fl"]})
    return JsonResponse({"tahun": tahun, "seri": seri})


def api_indikator(request):
    t = _ambil(TabelIO.Jenis.IRIO, request)
    if not t:
        return _galat("Tabel IRIO tidak ada untuk pilihan ini.")
    sektor = request.GET.get("sektor") or None
    return JsonResponse({"tabel": t.label, "nilai": A.indikator_wilayah(A.tabel(t), sektor)})


def api_dampak(request):
    t = _ambil(TabelIO.Jenis.IRIO, request)
    if not t:
        return _galat("Tabel IRIO tidak ada untuk pilihan ini.")
    pk = request.GET.get("skenario")
    sk = (Skenario.objects.filter(pk=pk, hasil__isnull=False).select_related("hasil").first() if pk
          else aktif.ambil(request))
    if not sk:
        return _galat("Belum ada skenario yang dijalankan.")
    jb = A.jembatan_pmtb()
    if not jb:
        return _galat("Komposisi PMTB provinsi belum dimuat (python manage.py muat_io).")
    th = request.GET.get("th")
    inv, tahun = A.investasi_skenario(sk, request.GET.get("sumber", "a2"), int(th) if th else None)
    if inv is None:
        return _galat("Jalankan ulang skenario agar tabel hitung tersedia.")
    hasil = A.dampak(A.tabel(t), inv, jb)
    hasil.update({"tabel": t.label, "skenario": sk.label, "skenario_pk": sk.pk, "tahun_ada": tahun,
                  "pulau": [PULAU_PROVINSI[k] for k in hasil["wil"]],
                  "nama": [NAMA_PROVINSI[k] for k in hasil["wil"]]})
    return JsonResponse(hasil)
