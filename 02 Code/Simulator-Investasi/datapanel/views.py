import json

import numpy as np
import pandas as pd
from django.contrib import messages
from django.http import HttpResponse, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_POST

from . import diagnosa, excel_data
from . import variabel as V
from .forms import FormObservasi, FormUnggah
from .models import Observasi, VersiData
from .panel import aditif, nilai_nasional, seri_nasional, tabel_provinsi, tambah_turunan
from .papua import gabung_pangsa, tahun_teramati
from .papua import ringkasan as ringkasan_pangsa
from .pembersihan import PipelinePembersihan, gabungkan_pembaruan
from .referensi import KODE_PROVINSI, NAMA_PROVINSI, PULAU, PULAU_PROVINSI

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
INDIKATOR_PETA = ["G_PDRB", "PDRB_ADHK", "PMAPMDN", "RASIO_INV_PMTB", "PMTB_ADHK", "G_PMTB", "PDRB_PER_TK",
                  "TK_TOTAL", "PAD", "RASIO_PAD", "APBD_BELANJA"]


def _unduh(isi, nama):
    resp = HttpResponse(isi, content_type=XLSX)
    resp["Content-Disposition"] = f'attachment; filename="{nama}"'
    return resp


def _bersih(x):
    return None if x is None or (isinstance(x, float) and np.isnan(x)) else float(x)


def beranda(request):
    from simulasi import aktif
    from simulasi.models import Skenario

    versi = VersiData.aktif()
    sk = aktif.ambil(request)
    daftar = list(Skenario.objects.select_related("hasil").order_by("kelompok", "templat", "nama"))
    for s in daftar:
        r = s.hasil.data["nasional"]["ringkasan"] if hasattr(s, "hasil") else None
        s.selisih = r["g_rata_skenario"] - r.get("g_rata_sasaran", s.sasaran) if r else None
    konteks = {"skenario": daftar, "ska": sk}
    if sk:
        n = sk.hasil.data["nasional"]
        konteks["proyeksi"] = {"nama": sk.label, "tahun": n["tahun"][1:], "g_s": n["g_skenario"],
                               "g_d": n["g_dasar"], "g_k": n["g_sasaran"],
                               "inv": [a + b for a, b in zip(n["inv_a1"], n["inv_a2_realisasi"])],
                               "keb": n["inv_kebutuhan"]}
        konteks["rg_aktif"] = n["ringkasan"]
        konteks["prob_aktif"] = sk.hasil.data.get("ketidakpastian", {}).get("prob_nasional")
    if versi:
        rinci = versi.bisa_rinci_papua
        df = tambah_turunan(versi.ke_dataframe_38() if rinci else versi.ke_dataframe())
        nas = seri_nasional(df)
        tahun = [int(t) for t in nas.index]
        t_akhir = max(t for t in tahun if nas.loc[t, "PDRB_ADHK"] > 0)
        konteks.update({
            "versi": versi,
            "rinci": rinci,
            "n_prov": df.index.get_level_values("kode").nunique(),
            "tahun_pangsa": tahun_teramati(versi.pangsa_pemekaran) if rinci else [],
            "nasional": nilai_nasional(df, t_akhir),
            "tahun_akhir": t_akhir,
            "kpi": {
                "g_pdrb": nas.loc[t_akhir, "G_PDRB"],
                "pdrb": nas.loc[t_akhir, "PDRB_ADHK"],
                "inv": nas.loc[t_akhir, "PMAPMDN"],
                "pmtb": nas.loc[t_akhir, "PMTB_ADHB"],
                "rasio": nas.loc[t_akhir, "PMAPMDN"] / nas.loc[t_akhir, "PMTB_ADHB"],
            },
            "seri": {
                "tahun": tahun,
                "g_pdrb": [_bersih(v) for v in nas["G_PDRB"]],
                "g_pmtb": [_bersih(v) for v in nas["G_PMTB"]],
                "pma": [_bersih(v / 1000) for v in nas["PMA"]],
                "pmdn": [_bersih(v / 1000) for v in nas["PMDN"]],
                "pmtb": [_bersih(v / 1000) for v in nas["PMTB_ADHB"]],
            },
            "peta": _data_peta(df, t_akhir),
            "indikator": [(k, V.label(k), V.satuan(k)) for k in INDIKATOR_PETA if k in df.columns],
        })
    return render(request, "datapanel/beranda.html", konteks)


def _data_peta(df, tahun):
    sub = df.xs(tahun, level="tahun")
    return {k: {str(int(kd)): _bersih(v) for kd, v in sub[k].items()} for k in INDIKATOR_PETA if k in sub}


KELENGKAPAN = ["PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB", "PMA", "PMDN", "TK_TOTAL", "PAD",
               "APBD_PENDAPATAN", "APBD_BELANJA"]
GRUP_SEKTORAL = [("VA_", "Nilai tambah 17 sektor"), ("TK_", "Tenaga kerja 17 sektor"),
                 ("PMA_", "PMA 17 sektor"), ("PMDN_", "PMDN 17 sektor")]


def _kelengkapan(versi):
    """Persen sel terisi per variabel (atau grup sektoral) per tahun pada versi."""
    df = tambah_turunan(versi.ke_dataframe())
    tahun = sorted(int(t) for t in df.index.get_level_values("tahun").unique())
    terisi = df.notna().groupby(level="tahun").mean() * 100
    baris = [(V.label(k), [float(terisi.at[t, k]) for t in tahun]) for k in KELENGKAPAN if k in terisi]
    for awal, lbl in GRUP_SEKTORAL:
        kol = [c for c in terisi.columns if c.startswith(awal) and c[len(awal):] in V.KODE_SEKTOR]
        if kol:
            baris.append((lbl, [float(terisi.loc[t, kol].mean()) for t in tahun]))
    return {"tahun": tahun, "baris": baris, "n_prov": df.index.get_level_values("kode").nunique(),
            "n_var": len([c for c in df.columns if c in V.PER_KODE])}


def daftar_versi(request):
    versi_list = VersiData.objects.all()
    aktif = VersiData.aktif()
    S = VersiData.Status
    konteks = {"versi_list": versi_list, "n_pakai": versi_list.filter(status__in=[S.SIAP, S.AKTIF]).count(),
               "n_draf": versi_list.filter(status=S.DRAF).count(),
               "n_arsip": versi_list.filter(status__in=[S.ARSIP, S.GAGAL]).count()}
    if aktif:
        konteks["lengkap"] = _kelengkapan(aktif)
    return render(request, "datapanel/daftar_versi.html", konteks)


def _konteks_unggah(form):
    grup = {}
    for v in V.DAFTAR:
        grup.setdefault(v.grup, []).append(v)
    return {"form": form, "grup_variabel": grup}


def unggah(request):
    form = FormUnggah(request.POST or None, request.FILES or None)
    if request.method == "POST" and form.is_valid():
        d = form.cleaned_data
        opsi = {"imputasi": d["imputasi"], "ambang_lonjakan": d["ambang_lonjakan"],
                "tahun_min": d["tahun_min"], "tahun_max": d["tahun_max"]}
        berkas = d["berkas"]
        try:
            hasil = PipelinePembersihan(opsi).jalankan(berkas, berkas.name)
        except Exception as e:  # berkas rusak / format tak terbaca
            messages.error(request, f"Berkas tidak dapat dibaca: {e}")
            return render(request, "datapanel/unggah.html", _konteks_unggah(form))
        df, catatan, temuan = hasil.df, hasil.catatan, [t.ke_dict() for t in hasil.temuan]
        induk = d["induk"] if d["mode"] == "pembaruan" else None
        if induk is not None and not hasil.ada_galat:
            induk_df, induk_cat = induk.ke_dataframe(dengan_catatan=True)
            df, catatan = gabungkan_pembaruan(induk_df, induk_cat, df, catatan)
            temuan.append({"tingkat": "info", "langkah": "Pembaruan",
                           "pesan": f"Digabung dengan {induk}: sel terisi di unggahan menimpa induk.",
                           "detail": []})
        ringkasan = hasil.ringkasan()
        if induk is not None:
            ringkasan["n_baris"] = len(df)
            ringkasan["wajib_hilang"] = [k for k in V.WAJIB if k not in df.columns]
            ringkasan["lengkap_untuk_simulasi"] = not ringkasan["wajib_hilang"]
        asal = induk or VersiData.aktif()
        pangsa_baru = hasil.pangsa_pemekaran(berkas.name)
        pangsa = gabung_pangsa(asal.pangsa_pemekaran if asal else {}, pangsa_baru)
        if pangsa_baru:
            temuan.append({"tingkat": "info", "langkah": "Pemekaran Papua",
                           "pesan": "Baris enam provinsi Papua di unggahan dipakai untuk pangsa rincian 38 provinsi "
                                    f"(tahun PDRB: {', '.join(map(str, tahun_teramati(pangsa_baru))) or '-'}).",
                           "detail": []})
        elif pangsa:
            temuan.append({"tingkat": "info", "langkah": "Pemekaran Papua",
                           "pesan": f"Unggahan tanpa baris provinsi pemekaran; pangsa rincian Papua diwarisi dari {asal}.",
                           "detail": []})
        berkas.seek(0)
        versi = VersiData.objects.create(
            nama=d["nama"], keterangan=d["keterangan"], induk=induk, berkas=berkas, nama_berkas=berkas.name,
            sumber=VersiData.Sumber.PEMBARUAN if induk else VersiData.Sumber.UNGGAH,
            status=VersiData.Status.GAGAL if hasil.ada_galat else VersiData.Status.DRAF,
            opsi_pembersihan=opsi, laporan=temuan, ringkasan=ringkasan, pangsa_pemekaran=pangsa,
            dibuat_oleh=request.user if request.user.is_authenticated else None)
        if not hasil.ada_galat:
            versi.simpan_dataframe(df, catatan)
            messages.info(request, "Pembersihan selesai. Periksa laporan lalu konfirmasi untuk menyimpan versi.")
        else:
            messages.error(request, "Pembersihan gagal. Lihat laporan di bawah.")
        return redirect("datapanel:detail_versi", pk=versi.pk)
    return render(request, "datapanel/unggah.html", _konteks_unggah(form))


def detail_versi(request, pk):
    versi = get_object_or_404(VersiData, pk=pk)
    df, catatan = versi.ke_dataframe(dengan_catatan=True)
    kolom = [k for k in ("PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB", "PMA", "PMDN", "PAD", "APBD_BELANJA")
             if k in df.columns]
    pratinjau = []
    for (kode, th), row in df.head(68).iterrows():
        cat = catatan.get((kode, th), {})
        pratinjau.append({"kode": kode, "nama": NAMA_PROVINSI.get(kode, kode), "tahun": th,
                          "sel": [(row[k], cat.get(k, "")) for k in kolom]})
    return render(request, "datapanel/detail_versi.html", {
        "versi": versi, "kolom": [(k, V.label(k)) for k in kolom], "pratinjau": pratinjau,
        "dipakai": versi.skenario.count(), "pangsa": ringkasan_pangsa(versi.pangsa_pemekaran),
    })


@require_POST
def aksi_versi(request, pk, aksi):
    versi = get_object_or_404(VersiData, pk=pk)
    S = VersiData.Status
    if aksi == "konfirmasi" and versi.status == S.DRAF:
        versi.status = S.SIAP
        versi.save(update_fields=["status"])
        messages.success(request, f"{versi} disimpan dan siap dipakai.")
    elif aksi == "aktifkan" and versi.status in (S.SIAP, S.DRAF, S.ARSIP):
        if not versi.observasi.exists():
            messages.error(request, "Versi ini tidak memiliki data (pembersihan gagal); tidak dapat diaktifkan.")
            return redirect("datapanel:detail_versi", pk=pk)
        versi.aktifkan()
        messages.success(request, f"{versi} sekarang versi aktif.")
    elif aksi == "arsipkan" and versi.status != S.AKTIF:
        versi.status = S.ARSIP
        versi.save(update_fields=["status"])
        messages.info(request, f"{versi} diarsipkan.")
    elif aksi == "hapus":
        if versi.skenario.exists():
            messages.error(request, "Versi dipakai skenario; arsipkan saja.")
        elif versi.status == S.AKTIF:
            messages.error(request, "Versi aktif tidak dapat dihapus.")
        else:
            versi.delete()
            messages.info(request, "Versi dihapus.")
            return redirect("datapanel:daftar_versi")
    else:
        messages.error(request, "Aksi tidak berlaku untuk status versi ini.")
    return redirect("datapanel:detail_versi", pk=pk)


def unduh_versi(request, pk):
    versi = get_object_or_404(VersiData, pk=pk)
    df, catatan = versi.ke_dataframe(dengan_catatan=True)
    isi = excel_data.tulis_dataset(df, catatan, versi.laporan, judul=f"{versi.nama} (versi #{versi.pk})")
    return _unduh(isi, f"dataset_versi_{versi.pk}.xlsx")


def unduh_templat(request):
    versi = VersiData.aktif()
    akhir = versi.tahun_akhir if versi and versi.tahun_akhir else 2025
    return _unduh(excel_data.templat([akhir + 1]), f"templat_data_{akhir + 1}.xlsx")


def sunting_observasi(request, pk, kode, tahun):
    versi = get_object_or_404(VersiData, pk=pk)
    obs = Observasi.objects.filter(versi=versi, provinsi_id=kode, tahun=tahun).first()
    form = FormObservasi(request.POST or None, nilai=obs.nilai if obs else {})
    if request.method == "POST" and form.is_valid():
        df, catatan = versi.ke_dataframe(dengan_catatan=True)
        baru = {k: form.cleaned_data[k] for k in (v.kode for v in V.DAFTAR)}
        diubah = []
        for k, v in baru.items():
            lama = df.loc[(kode, tahun), k] if (kode, tahun) in df.index and k in df.columns else np.nan
            if (v is None and pd.isna(lama)) or (v is not None and not pd.isna(lama) and abs(v - lama) < 1e-12):
                continue
            if k not in df.columns:
                df[k] = np.nan
            df.loc[(kode, tahun), k] = np.nan if v is None else v
            catatan.setdefault((kode, tahun), {})[k] = f"disunting manual: {form.cleaned_data['alasan']}"
            diubah.append(k)
        if not diubah:
            messages.info(request, "Tidak ada nilai yang berubah.")
            return redirect("datapanel:detail_versi", pk=pk)
        turunan = _buat_turunan(request, versi, df, catatan, form.cleaned_data["alasan"],
                                f"{NAMA_PROVINSI[kode]} {tahun}: {len(diubah)} sel diubah.", diubah)
        messages.success(request, f"Versi turunan #{turunan.pk} dibuat. Aktifkan bila ingin dipakai sebagai default.")
        return redirect("datapanel:detail_versi", pk=turunan.pk)
    return render(request, "datapanel/sunting_observasi.html", {
        "versi": versi, "form": form, "kode": kode, "nama": NAMA_PROVINSI.get(kode), "tahun": tahun})


def penjelajah(request):
    versi_list = VersiData.objects.filter(status__in=[VersiData.Status.SIAP, VersiData.Status.AKTIF])
    pk = request.GET.get("versi")
    versi = versi_list.filter(pk=pk).first() if pk else VersiData.aktif()
    if not versi:
        return render(request, "datapanel/penjelajah.html", {"versi_list": versi_list})
    # checkbox tak tercentang tidak terkirim; input tersembunyi "0" mendahuluinya, default = rinci
    rinci = (request.GET.getlist("rinci") or ["1"])[-1] == "1" and versi.bisa_rinci_papua
    df = tambah_turunan(versi.ke_dataframe_38() if rinci else versi.ke_dataframe())
    pilihan = [(k, V.label(k)) for k in INDIKATOR_PETA if k in df.columns] + \
              [(v.kode, v.label) for v in V.DAFTAR if v.kode in df.columns and v.kode not in INDIKATOR_PETA]
    grup = {v.kode: v.grup for v in V.DAFTAR} | V.GRUP_TURUNAN
    pilihan += [(k, V.label(k)) for k in V.GRUP_TURUNAN if k in df.columns]
    pilihan_grup = {}
    for k, lbl in pilihan:
        pilihan_grup.setdefault("Indikator utama" if k in INDIKATOR_PETA else grup.get(k, "Lainnya"), []).append((k, lbl))
    var = request.GET.get("var") or "G_PDRB"
    if var not in df.columns:
        var = pilihan[0][0]
    tahun_list = sorted(int(t) for t in df.index.get_level_values("tahun").unique())
    tahun = int(request.GET.get("tahun") or max(t for t in tahun_list if df[var].xs(t, level="tahun").notna().any()))
    lebar = df[var].unstack("tahun")
    baris = tabel_provinsi(df, tahun, [var])
    for b in baris:
        b["seri"] = [_bersih(lebar.loc[b["kode"], t]) if t in lebar.columns else None for t in tahun_list]
    nas = {t: nilai_nasional(df, t).get(var) for t in tahun_list}
    from simulasi import aktif
    proyeksi = proyeksi_aktif(aktif.ambil(request), var)
    return render(request, "datapanel/penjelajah.html", {
        "proyeksi": proyeksi,
        "versi_list": versi_list, "versi": versi, "pilihan": pilihan_grup, "var": var, "label": V.label(var),
        "satuan": V.satuan(var), "tahun_list": tahun_list, "tahun": tahun, "baris": baris,
        "peta": {str(b["kode"]): b[var] for b in baris},
        "seri_prov": {str(b["kode"]): b["seri"] for b in baris},
        "pulau_prov": {str(b["kode"]): b["pulau"] for b in baris},
        "info": {"aditif": aditif(var), "nasional": nas.get(tahun), "seri_nasional": [nas[t] for t in tahun_list],
                 "pulau": [p for p in PULAU if any(b["pulau"] == p for b in baris)]},
        "rinci": rinci, "bisa_rinci": versi.bisa_rinci_papua,
        "tahun_pangsa": tahun_teramati(versi.pangsa_pemekaran),
    })


# indikator panel -> kolom tabel hitung skenario: [(label seri, fungsi baris)]
PROYEKSI = {
    "G_PDRB": [("Dengan penambahan investasi", lambda r: r["g_skenario"]), ("Tanpa penambahan investasi", lambda r: r["g_dasar"]), ("Sasaran", lambda r: r["g_sasaran"])],
    "PDRB_ADHK": [("Dengan penambahan investasi", lambda r: r["PDRB_skenario"]), ("Tanpa penambahan investasi", lambda r: r["PDRB_dasar"]),
                  ("Sasaran", lambda r: r["PDRB_sasaran"])],
    "PMAPMDN": [("Investasi dasar + tambahan terealisasi", lambda r: r["A1_real"] + r["A2_real"]),
                ("Kebutuhan", lambda r: r["I_kebutuhan"])],
    "PMTB_ADHK": [("Skenario", lambda r: r["PMTB_riil"]), ("Kebutuhan", lambda r: r["PMTB_kebutuhan"])],
}


def proyeksi_aktif(sk, var):
    """Seri proyeksi skenario aktif per provinsi untuk indikator yang sepadan (None bila tidak ada)."""
    if not sk or var not in PROYEKSI or not hasattr(sk, "hasil") or "hitung" not in sk.hasil.data:
        return None
    h = sk.hasil.data["hitung"]
    rows = [dict(zip(h["kolom"], b)) for b in h["baris"]]
    tahun = sorted({r["tahun"] for r in rows})
    seri = {}
    for label, f in PROYEKSI[var]:
        per = {}
        for r in rows:
            per.setdefault(str(r["kode"]), [None] * len(tahun))[tahun.index(r["tahun"])] = f(r)
        seri[label] = per
    return {"nama": sk.label, "pk": sk.pk, "tahun": tahun, "seri": seri}


def api_indikator(request):
    versi = get_object_or_404(VersiData, pk=request.GET.get("versi")) if request.GET.get("versi") \
        else VersiData.aktif()
    df = tambah_turunan(versi.ke_dataframe())
    var, tahun = request.GET.get("var", "G_PDRB"), int(request.GET.get("tahun", versi.tahun_akhir))
    if var not in df.columns:
        return JsonResponse({"error": "variabel tidak ada"}, status=400)
    sub = df.xs(tahun, level="tahun")[var]
    return JsonResponse({"var": var, "label": V.label(var), "satuan": V.satuan(var), "tahun": tahun,
                         "nilai": {str(int(k)): _bersih(v) for k, v in sub.items()}})


def _buat_turunan(request, versi, df, catatan, alasan, pesan, detail, nama=None):
    """Versi baru (sumber EDIT) dari `df` hasil suntingan; versi induk tidak diubah."""
    ringkasan = dict(versi.ringkasan or {})
    ringkasan["n_baris"] = len(df)
    ringkasan["wajib_hilang"] = [k for k in V.WAJIB if k not in df.columns or df[k].isna().all()]
    ringkasan["lengkap_untuk_simulasi"] = not ringkasan["wajib_hilang"]
    turunan = VersiData.objects.create(
        nama=nama or f"{versi.nama} (suntingan)", keterangan=alasan, induk=versi,
        sumber=VersiData.Sumber.EDIT, status=VersiData.Status.SIAP, opsi_pembersihan=versi.opsi_pembersihan,
        laporan=versi.laporan + [{"tingkat": "info", "langkah": "Suntingan manual", "pesan": pesan, "detail": detail}],
        ringkasan=ringkasan, pangsa_pemekaran=versi.pangsa_pemekaran,
        dibuat_oleh=request.user if request.user.is_authenticated else None)
    turunan.simpan_dataframe(df.sort_index(), catatan)
    return turunan


def kelengkapan(request, pk):
    versi = get_object_or_404(VersiData, pk=pk)
    cek = diagnosa.periksa(versi)
    return render(request, "datapanel/kelengkapan.html", {
        "versi": versi, "cek": cek, "matriks": diagnosa.matriks(versi),
        "n_ok": sum(c["status"] == "ok" for c in cek), "n_periksa": sum(c["status"] == "periksa" for c in cek),
        "n_info": sum(c["status"] == "info" for c in cek),
        "versi_lain": VersiData.objects.exclude(status=VersiData.Status.GAGAL).exclude(pk=pk)[:20],
    })


def grid_json(request, pk):
    """Seluruh sel versi (34 provinsi tersimpan) untuk penyunting grid: nilai[var][i_prov][i_tahun]."""
    versi = get_object_or_404(VersiData, pk=pk)
    df, catatan = versi.ke_dataframe(dengan_catatan=True)
    tahun = sorted(int(t) for t in df.index.get_level_values("tahun").unique())
    full = df.reindex(pd.MultiIndex.from_product([KODE_PROVINSI, tahun], names=["kode", "tahun"]))
    nilai = {}
    for v in V.DAFTAR:
        if v.kode in full:
            m = full[v.kode].to_numpy().reshape(len(KODE_PROVINSI), len(tahun))
            nilai[v.kode] = [[None if np.isnan(x) else float(x) for x in baris] for baris in m]
    cat = {f"{k}-{t}": c for (k, t), c in catatan.items()}
    return JsonResponse({
        "versi": versi.pk, "tahun": tahun,
        "provinsi": [{"kode": k, "nama": NAMA_PROVINSI[k], "pulau": PULAU_PROVINSI[k]} for k in KODE_PROVINSI],
        "variabel": [{"kode": v.kode, "label": v.label, "satuan": v.satuan, "grup": v.grup, "wajib": v.wajib} for v in V.DAFTAR],
        "nilai": nilai, "catatan": cat,
    })


def sunting_grid(request, pk):
    versi = get_object_or_404(VersiData, pk=pk)
    if request.method != "POST":
        return render(request, "datapanel/sunting_grid.html", {"versi": versi, "grup": V.GRUP})
    try:
        m = json.loads(request.body or "{}")
        perubahan = m.get("perubahan") or []
        alasan = (m.get("alasan") or "").strip()
        if not alasan:
            raise ValueError("Isi alasan suntingan.")
        if not perubahan:
            raise ValueError("Tidak ada sel yang berubah.")
        if len(perubahan) > 50000:
            raise ValueError("Terlalu banyak sel dalam satu simpanan.")
        df, catatan = versi.ke_dataframe(dengan_catatan=True)
        diubah = []
        for p in perubahan:
            kode, tahun, var = int(p["kode"]), int(p["tahun"]), str(p["var"])
            if kode not in NAMA_PROVINSI or kode not in KODE_PROVINSI:
                raise ValueError(f"Kode provinsi {kode} tidak dikenal.")
            if not 1990 <= tahun <= 2100:
                raise ValueError(f"Tahun {tahun} di luar rentang.")
            if var not in V.PER_KODE:
                raise ValueError(f"Variabel {var} tidak dikenal.")
            v = p.get("nilai")
            v = np.nan if v is None or v == "" else float(v)
            if var not in df.columns:
                df[var] = np.nan
            if (kode, tahun) not in df.index:
                df.loc[(kode, tahun), :] = np.nan
            df.loc[(kode, tahun), var] = v
            catatan.setdefault((kode, tahun), {})[var] = f"disunting manual: {alasan}"
            diubah.append(f"{NAMA_PROVINSI[kode]} {tahun} {var}")
    except (ValueError, KeyError, TypeError) as e:
        return JsonResponse({"error": str(e)}, status=400)
    df = df.astype(float)
    df.index = pd.MultiIndex.from_tuples([(int(k), int(t)) for k, t in df.index], names=["kode", "tahun"])
    tahun_baru = sorted({int(p["tahun"]) for p in perubahan} - set(range(versi.tahun_awal or 0, (versi.tahun_akhir or 0) + 1)))
    pesan = f"{len(diubah)} sel diubah lewat grid" + (f"; tahun baru {', '.join(map(str, tahun_baru))}" if tahun_baru else "") + "."
    turunan = _buat_turunan(request, versi, df, catatan, alasan, pesan, diubah[:500], nama=(m.get("nama") or "").strip() or None)
    if m.get("aktifkan"):
        if turunan.lengkap_untuk_simulasi:
            turunan.aktifkan()
        else:
            messages.warning(request, "Versi baru belum lengkap untuk simulasi; tidak diaktifkan.")
    messages.success(request, f"Versi #{turunan.pk} dibuat dari #{versi.pk}: {pesan}")
    return JsonResponse({"ok": True, "pk": turunan.pk, "url": f"/data/{turunan.pk}/"})
