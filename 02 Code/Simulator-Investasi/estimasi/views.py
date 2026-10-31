import json

import numpy as np
from django.contrib import messages
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from datapanel.models import VersiData
from datapanel.referensi import KODE_PROVINSI, NAMA_PROVINSI, PULAU, PULAU_PROVINSI

from . import twfe
from .determinan import AWAL, PILAR, per_pilar
from .forms import FormKoefisienSektoral, FormSetDeterminan, FormSetParameter
from .models import KoefisienSektoral, SetDeterminan, SetParameter


def daftar(request):
    """Meja kerja estimasi: spesifikasi, pratinjau keluaran regresi, dan kumpulan set tersimpan dalam satu halaman."""
    versi = VersiData.objects.filter(status__in=[VersiData.Status.SIAP, VersiData.Status.AKTIF])
    aktif = VersiData.aktif()
    parameter = list(SetParameter.objects.select_related("versi_data"))
    return render(request, "estimasi/daftar.html", {
        "parameter": parameter, "sektoral": KoefisienSektoral.objects.all(),
        "determinan": [(s, [sum(x["koef"] for x in isi) for isi in per_pilar(s.indikator).values()])
                       for s in SetDeterminan.objects.all()],
        "pilar": PILAR, "det_utama": _indikator_grafik(SetDeterminan.utama()),
        "versi": [{"pk": v.pk, "nama": str(v), "awal": v.tahun_awal, "akhir": v.tahun_akhir, "aktif": v.pk == (aktif.pk if aktif else None)}
                  for v in versi],
        "provinsi": [{"kode": k, "nama": NAMA_PROVINSI[k], "pulau": PULAU_PROVINSI[k]} for k in KODE_PROVINSI],
        "pulau": PULAU,
        "set_json": [{"pk": p.pk, "nama": p.nama, "b1": p.b1, "se_b1": p.se_b1, "b2": p.b2, "se_b2": p.se_b2,
                      "n": p.n_obs, "bawaan": p.bawaan} for p in parameter],
    })


def _spesifikasi(m):
    versi = VersiData.objects.filter(pk=m.get("versi")).first() or VersiData.aktif()
    if not versi:
        raise ValueError("Belum ada versi data.")
    tahun = sorted(int(t) for t in m.get("tahun") or [])
    if len(tahun) < 3:
        raise ValueError("Pilih minimal 3 tahun.")
    semua = list(range(tahun[0], tahun[-1] + 1))
    prov = [int(k) for k in m.get("provinsi") or []]
    kw = {"tahun_awal": tahun[0], "tahun_akhir": tahun[-1], "kecuali_tahun": [t for t in semua if t not in tahun],
          "provinsi": prov if prov and len(prov) < len(KODE_PROVINSI) else None, "crs": bool(m.get("crs")),
          "efek_tahun": m.get("efek_tahun", True) is not False, "modal": "stok" if m.get("modal") == "stok" else "pmtb",
          "delta": min(max(float(m.get("delta") or 0.05), 0.0), 0.5)}
    return versi, kw


@require_POST
def api_hitung(request):
    try:
        versi, kw = _spesifikasi(json.loads(request.body or "{}"))
        h = twfe.estimasi_lengkap(versi.ke_dataframe(), **kw)
    except (ValueError, KeyError, TypeError, np.linalg.LinAlgError) as e:
        return JsonResponse({"galat": str(e)}, status=400)
    h["versi"] = versi.pk
    return JsonResponse(h)


@require_POST
def simpan(request):
    m = json.loads(request.body or "{}")
    try:
        versi, kw = _spesifikasi(m)
        h = twfe.estimasi_lengkap(versi.ke_dataframe(), **kw)
    except (ValueError, KeyError, TypeError, np.linalg.LinAlgError) as e:
        return JsonResponse({"galat": str(e)}, status=400)
    sp = kw
    ringkas = (f"Two-way FE{'' if sp['efek_tahun'] else ' (tanpa efek tahun)'}, SE klaster provinsi (HC1). "
               f"{h['n_provinsi']} provinsi × {h['n_tahun']} tahun"
               f"{', tanpa ' + ', '.join(map(str, sp['kecuali_tahun'])) if sp['kecuali_tahun'] else ''}"
               f"{', modal = stok PIM δ=' + format(sp['delta'], '.2f') if sp['modal'] == 'stok' else ''}, "
               f"R2 within {h['r2_within']:.3f}.")
    obj = SetParameter.objects.create(
        nama=(m.get("nama") or "").strip() or f"Estimasi {sp['tahun_awal']}–{sp['tahun_akhir']}",
        sumber=SetParameter.Sumber.ESTIMASI, versi_data=versi, crs=sp["crs"], tahun_awal=sp["tahun_awal"],
        tahun_akhir=sp["tahun_akhir"], b1=h["b1"], se_b1=h["se_b1"], b2=h["b2"], se_b2=h["se_b2"], n_obs=h["n_obs"],
        catatan=ringkas, spesifikasi=h["spesifikasi"], bawaan=bool(m.get("bawaan")),
        hasil={k: h[k] for k in ("koefisien", "uji_crs", "efek_tahun", "efek_provinsi", "rmse_provinsi", "r2_within",
                                 "r2_total", "rmse", "n_provinsi", "n_tahun", "df_klaster")})
    if obj.bawaan:
        SetParameter.objects.exclude(pk=obj.pk).update(bawaan=False)
    messages.success(request, f"Set {obj.nama} disimpan: b1 = {obj.b1:.4f}, b2 = {obj.b2:.4f}.")
    return JsonResponse({"ok": True, "pk": obj.pk, "url": reverse("estimasi:detail", args=[obj.pk])})


@require_POST
def hapus(request, pk):
    sp = get_object_or_404(SetParameter, pk=pk)
    if sp.bawaan:
        messages.error(request, "Set bawaan tidak dapat dihapus; jadikan set lain bawaan dulu.")
    elif sp.skenario.exists():
        messages.error(request, "Set dipakai skenario; tidak dapat dihapus.")
    else:
        sp.delete()
        messages.info(request, "Set parameter dihapus.")
    return redirect("estimasi:daftar")


@require_POST
def jadikan_bawaan(request, pk):
    sp = get_object_or_404(SetParameter, pk=pk)
    SetParameter.objects.exclude(pk=sp.pk).update(bawaan=False)
    sp.bawaan = True
    sp.save(update_fields=["bawaan"])
    messages.success(request, f"{sp.nama} sekarang set bawaan untuk skenario baru.")
    return redirect("estimasi:daftar")


def detail(request, pk):
    sp = get_object_or_404(SetParameter, pk=pk)
    versi = sp.versi_data if sp.versi_data and sp.versi_data.bisa_dipakai else VersiData.aktif()
    konteks = {"sp": sp, "versi": versi}
    if versi:
        d = twfe.residual_tfp(versi.ke_dataframe(), sp.b1, sp.b2)
        awal, akhir = sp.tahun_awal or 2018, sp.tahun_akhir or 2024
        th = d.index.get_level_values("tahun")
        jendela = d[(th > awal) & (th <= akhir)]
        baris = []
        rata_lnA = d[(th >= awal) & (th <= akhir)].groupby(level="kode")["lnA"].mean()
        dev = rata_lnA - rata_lnA.mean()
        for kode, g in jendela.groupby(level="kode"):
            g = g.dropna(subset=["gA"])
            baris.append({
                "kode": int(kode), "nama": NAMA_PROVINSI[int(kode)], "pulau": PULAU_PROVINSI[int(kode)],
                "gY": g.gY.mean(), "gK": g.gK.mean(), "gL": g.gL.mean(), "gA": g.gA.mean(),
                "kontrib_K": sp.b1 * g.gK.mean(), "kontrib_L": sp.b2 * g.gL.mean(),
                "sd": g.gA.std(), "n": len(g), "dev": float(dev.get(kode, np.nan)),
                "share": g.gA.mean() / g.gY.mean() * 100 if g.gY.mean() else None,
            })
        baris.sort(key=lambda b: -b["gA"])
        konteks.update({
            "baris": baris,
            "peta_gA": {str(b["kode"]): b["gA"] for b in baris},
            "peta_dev": {str(b["kode"]): b["dev"] for b in baris},
            "awal": awal + 1, "akhir": akhir,
        })
    return render(request, "estimasi/detail.html", konteks)


def sunting_parameter(request, pk=None):
    sp = get_object_or_404(SetParameter, pk=pk) if pk else None
    form = FormSetParameter(request.POST or None, instance=sp)
    if request.method == "POST" and form.is_valid():
        obj = form.save(commit=False)
        if not pk:
            obj.sumber = SetParameter.Sumber.MANUAL
        obj.save()
        if obj.bawaan:
            SetParameter.objects.exclude(pk=obj.pk).update(bawaan=False)
        messages.success(request, "Set parameter disimpan.")
        return redirect("estimasi:detail", pk=obj.pk)
    return render(request, "estimasi/form.html", {"form": form, "judul": "Set elastisitas", "obj": sp})


def _indikator_grafik(sd):
    if not sd:
        return []
    return [{"label": x["label"], "pilar": x["pilar"], "koef": x["koef"], "se": x.get("se") or 0} for x in sd.indikator]


def sunting_determinan(request, pk=None):
    sd = get_object_or_404(SetDeterminan, pk=pk) if pk else None
    utama = SetDeterminan.utama()
    dasar = sd.indikator if sd else (utama.indikator if utama else AWAL)
    form = FormSetDeterminan(request.POST or None, instance=sd, indikator=dasar,
                             initial=None if sd else {"nama": f"Salinan {utama.nama}" if utama else ""})
    if request.method == "POST" and form.is_valid():
        obj = form.save()
        if obj.bawaan:
            SetDeterminan.objects.exclude(pk=obj.pk).update(bawaan=False)
        messages.success(request, f"Set determinan {obj.nama} disimpan. Jalankan ulang skenario yang memakainya.")
        return redirect("estimasi:daftar")
    return render(request, "estimasi/form_determinan.html", {"form": form, "obj": sd})


@require_POST
def hapus_determinan(request, pk):
    sd = get_object_or_404(SetDeterminan, pk=pk)
    if sd.bawaan:
        messages.error(request, "Set bawaan tidak dapat dihapus; jadikan set lain bawaan dulu.")
    elif sd.skenario.exists():
        messages.error(request, "Set dipakai skenario; tidak dapat dihapus.")
    else:
        sd.delete()
        messages.info(request, "Set determinan dihapus.")
    return redirect("estimasi:daftar")


@require_POST
def bawaan_determinan(request, pk):
    sd = get_object_or_404(SetDeterminan, pk=pk)
    SetDeterminan.objects.exclude(pk=sd.pk).update(bawaan=False)
    SetDeterminan.objects.filter(pk=sd.pk).update(bawaan=True)
    messages.success(request, f"{sd.nama} sekarang set determinan bawaan.")
    return redirect("estimasi:daftar")


def sunting_sektoral(request, pk=None):
    ks = get_object_or_404(KoefisienSektoral, pk=pk) if pk else None
    form = FormKoefisienSektoral(request.POST or None, instance=ks)
    if request.method == "POST" and form.is_valid():
        obj = form.save()
        if obj.bawaan:
            KoefisienSektoral.objects.exclude(pk=obj.pk).update(bawaan=False)
        messages.success(request, "Koefisien sektoral disimpan.")
        return redirect("estimasi:daftar")
    return render(request, "estimasi/form.html", {"form": form, "judul": "Koefisien komposisi sektor", "obj": ks})
