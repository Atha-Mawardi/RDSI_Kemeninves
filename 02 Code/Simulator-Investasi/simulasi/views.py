import copy
import csv

from django import forms
from django.contrib import messages
from django.http import HttpResponse
from django.utils.http import url_has_allowed_host_and_scheme
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from datapanel.models import VersiData
from estimasi.determinan import PILAR
from estimasi.models import KoefisienSektoral, SetParameter

from datapanel.panel import historis_lima_tahun, tambah_turunan
from datapanel.pivot import HITUNG
from datapanel.papua import KELUARGA, tahun_teramati
from datapanel.referensi import KELOMPOK, KODE_SEKTOR, NAMA_PROVINSI, NAMA_SEKTOR, PULAU_PROVINSI

from . import aktif, excel_skenario, layanan, templat
from .excel_skenario import KOLOM_ASUMSI
from .forms import FormAsumsiProvinsi, FormSkenario
from .mesin import JALUR, JENIS_KEJUTAN
from .models import HasilSkenario, Skenario

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def _unduh(isi, nama):
    resp = HttpResponse(isi, content_type=XLSX)
    resp["Content-Disposition"] = f'attachment; filename="{nama}"'
    return resp


# Baris kisi ruang skenario: (kelompok, [(label, nama isian)] | awalan isian per tahun[, kunci kelompok]).
BARIS_RUANG = [
    ("Identitas", [("Nama", "nama"), ("Nama singkat", "singkat")]),
    ("Sasaran", [("Sasaran pertumbuhan nasional (%/tahun)", "sasaran"), ("Pembagian ke provinsi", "mode_sasaran"),
                 ("Porsi selisih historis", "lambda_proporsional")]),
    ("Produktivitas dan tenaga kerja", [
        ("Asumsi laju TFP", "mode_tfp"), ("Laju TFP satu nilai (%/tahun)", "tfp_nasional"),
        ("Pengali laju TFP (1 = tren)", "faktor_tfp"), ("Asumsi laju tenaga kerja", "mode_tk"),
        ("Laju tenaga kerja satu nilai (%/tahun)", "tk_nasional"),
        ("Tenaga kerja pindah dari pertanian (poin persen)", "realokasi_pp"), ("Tujuan perpindahan", "tujuan_realokasi")]),
    ("Investasi dan konversi", [
        ("Laju tren PMA+PMDN (%/tahun)", "g_investasi"), ("Rasio realisasi", "rasio_realisasi"),
        ("Pass-through ke PMTB", "pass_through"), ("Belanja modal APBD (% APBD)", "apbd_persen"),
        ("Alokasi investasi tambahan ke provinsi", "alokasi_a2")]),
    ("Investasi Dasar per tahun (triliun Rp)", "a1"),
    ("Investasi Tambahan per tahun (triliun Rp)", "a2"),
    ("Komposisi sektor investasi tambahan", [(nama, f"komp_{k}") for k, nama in KELOMPOK]),
] + [(f"Jalur per tahun: {label[0].lower()}{label[1:]}", f"jl_{kunci}") for kunci, label in JALUR.items()] + [
    (f"Determinan TFP: {judul}", [(nama, f"dt_{p}_{k}") for p, nama in PILAR], f"dt_{k}")
    for k, judul in (("dz", "perubahan indikator (× standard deviation)"), ("jeda", "jeda sebelum efek (tahun)"),
                     ("penuh", "lama menuju efek penuh (tahun)"), ("porsi", "porsi investasi tambahan (%)"),
                     ("biaya", "biaya menaikkan 1 standard deviation (triliun Rp)"))]

# Penjelasan kelompok baris kisi (tooltip), per kunci kelompok.
BANTUAN_RUANG = {
    "sasaran": "Target laju PDRB riil rata-rata per tahun dan cara membaginya ke provinsi.",
    "a1": "Realisasi PMA+PMDN dasar per tahun, misalnya target Renstra BKPM. Kosong = tren historis.",
    "a2": "Investasi di atas investasi dasar yang ingin diuji; menghasilkan laju dengan penambahan investasi.",
    "jl_sasaran": "Sasaran berbeda per tahun; tahun kosong memakai sasaran nasional. Rata-ratanya menjadi sasaran periode.",
    "jl_faktor_tfp": "Mengalikan laju TFP tahun itu: 1 = sesuai tren historis, 0,5 = separuhnya, 1,2 = 20% lebih cepat.",
    "jl_g_investasi": "Menggantikan laju tren nominal realisasi PMA+PMDN pada tahun yang diisi.",
    "dt_dz": "Seberapa jauh indikator pilar (pendidikan, konektivitas, dan lainnya) naik di atas tren historis. "
             "Satuannya standard deviation antarprovinsi: 1 = selisih khas antara satu provinsi dan rata-rata provinsi.",
    "dt_jeda": "Berapa tahun sampai perbaikan indikator mulai menaikkan TFP. Kosong = asumsi awal pilar.",
    "dt_penuh": "Berapa tahun efek naik bertahap sampai penuh setelah jeda. Kosong = asumsi awal pilar.",
    "dt_porsi": "Bagian investasi tambahan yang dibelanjakan untuk pilar ini. Diisi bersama biaya agar perubahan "
                "indikator dihitung dari dana.",
    "dt_biaya": "Dana yang dibutuhkan untuk menaikkan indikator pilar sebesar 1 standard deviation. Perubahan = porsi × "
                "total investasi tambahan ÷ biaya.",
}


BIDANG_ISIAN = [f.name for f in Skenario._meta.concrete_fields if f.name not in (
    "id", "kelompok", "templat", "status", "dibuat", "diubah", "dibuat_oleh", "penyesuaian", "override_provinsi")]


def _isian_dari(sk):
    return copy.deepcopy({f: getattr(sk, f) for f in BIDANG_ISIAN})


def _kunci_paket(form, sk):
    """Paket default: nama tetap; investasi tambahan paket kebutuhan dihitung otomatis dari sasaran."""
    if not sk.bawaan:
        return form
    for f in ("nama", "singkat"):
        form.fields[f].disabled = True
    if sk.templat in templat.A2_DIHITUNG:
        for th in form.tahun:
            fa = form.fields[f"a2_{th}"]
            fa.disabled = True
            fa.widget.attrs.update(title="Dihitung otomatis agar laju dengan penambahan investasi mencapai sasaran", placeholder="otomatis")
    return form


def _simpan_paket(sk, sebelum, baru):
    """Perubahan paket default disimpan sebagai penyesuaian paket itu (diwariskan ke paket turunannya)."""
    Skenario.objects.filter(pk=sk.pk).update(
        penyesuaian=templat.sesuaikan(sk.templat, sebelum, _isian_dari(baru)), deskripsi=baru.deskripsi,
        versi_data=baru.versi_data, set_parameter=baru.set_parameter, koef_sektoral=baru.koef_sektoral,
        set_determinan=baru.set_determinan)


def _bangun_ulang_paket(request, kode_kode, jalankan_):
    hasil = templat.bangun_ulang(kode_kode, jalankan=jalankan_)
    for s, g in hasil:
        if g:
            messages.error(request, f"{s.label}: {g}")
    if hasil:
        messages.success(request, f"{len(hasil)} paket default diperbarui{' dan dijalankan' if jalankan_ else ''}: "
                                  + ", ".join(s.label for s, _ in hasil) + ".")
    return hasil


def _form_kolom(sk, post=None):
    """FormSkenario berawalan per kolom; isian yang tidak tampil di kisi diisi dari nilai tersimpan."""
    awal = _kunci_paket(FormSkenario(instance=sk, prefix=f"s{sk.pk}"), sk)
    if post is None:
        return awal
    data = {}
    for nama, f in awal.fields.items():
        v = awal[nama].value()
        if isinstance(f, forms.BooleanField):
            if v:
                data[awal.add_prefix(nama)] = "on"
        elif v is not None:
            data[awal.add_prefix(nama)] = v
    data.update({k: v for k, v in post.items() if k.startswith(f"s{sk.pk}-")})
    return _kunci_paket(FormSkenario(data, instance=sk, prefix=f"s{sk.pk}"), sk)


def _ringkas_kejutan(sk):
    return [f"{k.get('nama') or JENIS_KEJUTAN.get(k['jenis'], k['jenis'])}: {k['besar']:+g}% "
            f"{k['tahun']}, ρ {k.get('persistensi', 1):g}, {k.get('cakupan', 'nasional')}" for k in sk.kejutan or []]


def _kisi(kolom):
    """Baris kisi: {jenis: grup|isian|tahun|teks|hasil, label, sel: [...] per kolom}."""
    tahun = sorted({th for _, f in kolom for th in f.tahun})
    baris = []
    for judul, isi, *kunci in BARIS_RUANG:
        if isinstance(isi, str):
            baris.append({"jenis": "grup", "label": judul, "grup": isi, "bantuan": BANTUAN_RUANG.get(isi)})
            field = "jalur" if isi.startswith("jl_") else isi
            for th in tahun:
                nama = f"{isi}_{th}"
                baris.append({"jenis": "tahun", "label": str(th), "grup": isi, "field": field,
                              "sel": [f[nama] if nama in f.fields else None for _, f in kolom]})
            continue
        kode = kunci[0] if kunci else judul.split()[0].lower()
        baris.append({"jenis": "grup", "label": judul, "grup": kode, "bantuan": BANTUAN_RUANG.get(kode)})
        for label, nama in isi:
            field = "komposisi_a2" if nama.startswith("komp_") else "determinan" if nama.startswith("dt_") else nama
            baris.append({"jenis": "isian", "label": label, "grup": kode, "sel": [f[nama] for _, f in kolom],
                          "field": field})
    baris.append({"jenis": "grup", "label": "Shock dan Basis", "grup": "kejutan"})
    baris.append({"jenis": "teks", "label": "Shock", "grup": "kejutan", "sel": [
        "; ".join(_ringkas_kejutan(sk)) or "–" for sk, _ in kolom]})
    baris.append({"jenis": "teks", "label": "Horizon", "grup": "kejutan",
                  "sel": [f"{sk.tahun_dasar}→{sk.tahun_target}" for sk, _ in kolom]})
    baris.append({"jenis": "teks", "label": "Data / parameter", "grup": "kejutan",
                  "sel": [f"#{sk.versi_data_id} · {sk.set_parameter.nama[:22]}" for sk, _ in kolom]})
    hasil = [
        ("Laju tanpa penambahan investasi (%/tahun)", "g_rata_dasar", 2),
        ("Laju dengan penambahan investasi (%/tahun)", "g_rata_skenario", 2),
        ("Sasaran rata-rata (%/tahun)", "g_rata_sasaran", 2), ("Selisih laju − sasaran (poin persen)", "selisih", 2),
        ("Kontribusi determinan TFP (poin persen/tahun)", "determinan", 2),
        ("Total Investasi Tambahan (triliun Rp)", "a2_kumulatif", 0),
        ("Kebutuhan tambahan (triliun Rp)", "kebutuhan_tambahan_kumulatif", 0),
        ("Peluang capai sasaran", "prob", "%")]
    baris.append({"jenis": "grup", "label": "Hasil", "grup": "hasil"})
    for label, kunci, dig in hasil:
        sel = []
        for sk, _ in kolom:
            d = sk.hasil.data if hasattr(sk, "hasil") else None
            if not d:
                sel.append(None)
                continue
            r = d["nasional"]["ringkasan"]
            if kunci == "prob":
                v = d.get("ketidakpastian", {}).get("prob_nasional")
            elif kunci == "determinan":
                v = r.get("kontribusi", {}).get("determinan")
            elif kunci == "selisih":
                v = r["g_rata_skenario"] - r.get("g_rata_sasaran", sk.sasaran)
            else:
                v = r.get(kunci)
            sel.append((0.0 if v is not None and abs(v) < 0.005 else v, dig))
        baris.append({"jenis": "hasil", "label": label, "grup": "hasil", "sel": sel})
    for b in baris:
        if "sel" in b:
            b["sel"] = [(sk.pk, c, b.get("field") in (sk.penyesuaian or {})) for (sk, _), c in zip(kolom, b["sel"])]
    return baris


def daftar(request):
    """Ruang skenario: kisi seperti lembar Skenario Excel, kolom = skenario, baris = asumsi."""
    semua = list(Skenario.objects.select_related("versi_data", "set_parameter", "hasil")
                 .order_by("kelompok", "templat", "nama"))
    if request.method == "POST":
        return _simpan_ruang(request, semua)
    kolom = [(sk, _form_kolom(sk)) for sk in semua]
    sesuai = templat.tersimpan()
    paket = [(t, [_label_field(f) for f in sesuai.get(t["kode"], {})]) for t in templat.TEMPLAT]
    return render(request, "simulasi/daftar.html", {
        "kolom": kolom, "baris": _kisi(kolom), "paket": paket,
        "ada_default": any(sk.bawaan for sk in semua)})


def _label_field(f):
    if f == "determinan":
        return "Determinan TFP"
    for judul, isi, *_ in BARIS_RUANG:
        if isi == f or (f == "jalur" and isinstance(isi, str) and isi.startswith("jl_")):
            return "Jalur per tahun" if f == "jalur" else judul
        if f == "komposisi_a2" and judul.startswith("Komposisi"):
            return judul
        if isinstance(isi, list):
            for label, nama in isi:
                if nama == f:
                    return label
    return "Shock" if f == "kejutan" else str(Skenario._meta.get_field(f).verbose_name).capitalize()


def _simpan_ruang(request, semua):
    jalankan_ = "jalankan" in request.POST
    disimpan, gagal, paket = [], [], []
    for sk in semua:
        if not any(k.startswith(f"s{sk.pk}-") for k in request.POST):
            continue
        sebelum = _isian_dari(sk)
        form = _form_kolom(sk, request.POST)
        if not form.has_changed():
            continue
        if not form.is_valid():
            gagal.append(f"{sk.label}: " + "; ".join(f"{k}: {' '.join(v)}" for k, v in form.errors.items()))
            continue
        baru = form.save(commit=False)
        if sk.bawaan:
            _simpan_paket(sk, sebelum, baru)
            paket.append(sk.templat)
            continue
        baru.save()
        disimpan.append(baru)
    if paket:
        _bangun_ulang_paket(request, paket, jalankan_)
    for g in gagal:
        messages.error(request, g)
    for sk in disimpan:
        if jalankan_:
            _, error = layanan.jalankan(sk)
            if error:
                messages.error(request, f"{sk.label}: {error}")
    if disimpan:
        kustom_baru = [sk.label for sk in disimpan if sk.kelompok == Skenario.Kelompok.KUSTOM]
        messages.success(request, f"{len(disimpan)} skenario disimpan{' dan dijalankan' if jalankan_ else ''}: "
                                  + ", ".join(kustom_baru or [sk.label for sk in disimpan]) + ".")
    elif not gagal and not paket:
        messages.info(request, "Tidak ada perubahan.")
    return redirect("simulasi:daftar")


def _ringkas_determinan(data):
    """Ringkasan determinan untuk Hasil; pilar dengan efek per Rp 100 T terbesar ditandai."""
    dt = data["nasional"].get("determinan") or {}
    pilar = [dict(p) for p in dt.get("pilar") or []]
    if not pilar:
        return None
    didanai = [p for p in pilar if p.get("pp_per_100T") is not None]
    if len(didanai) > 1:
        max(didanai, key=lambda p: p["pp_per_100T"])["terbaik"] = True
    return {**dt, "pilar": pilar}


def _jadikan_kustom(sk, asal_nama, asal_singkat):
    """Perubahan pada paket default disimpan sebagai salinan kustom; paket default tetap sebagai acuan."""
    sk.pk = None
    sk._state.adding = True
    sk._state.fields_cache = {}
    sk.kelompok = Skenario.Kelompok.KUSTOM
    sk.templat = ""
    sk.status = Skenario.Status.BARU
    if sk.nama == asal_nama:
        sk.nama = f"{asal_nama} (ubah)"
    if sk.singkat == asal_singkat:
        sk.singkat = f"{asal_singkat or asal_nama} ubah"[:24]
    return sk


@require_POST
def pilih_aktif(request):
    sk = get_object_or_404(Skenario, pk=request.POST.get("pk"))
    if not hasattr(sk, "hasil"):
        messages.warning(request, f"{sk.label} belum dijalankan; jalankan dulu agar bisa menjadi skenario aktif.")
    else:
        aktif.tetapkan(request, sk)
    lanjut = request.POST.get("next") or "/"
    if not url_has_allowed_host_and_scheme(lanjut, {request.get_host()}):
        lanjut = "/"
    if hasattr(sk, "hasil") and lanjut.startswith("/skenario/") and lanjut.split("/")[2].isdigit() \
            and "/edit" not in lanjut and "/asumsi" not in lanjut:
        return redirect("simulasi:detail", pk=sk.pk)
    return redirect(lanjut)


def hasil_aktif(request):
    sk = aktif.ambil(request)
    if not sk:
        messages.info(request, "Belum ada skenario yang dijalankan.")
        return redirect("simulasi:daftar")
    return redirect("simulasi:detail", pk=sk.pk)


@require_POST
def simpan_kustom(request, pk):
    asal = get_object_or_404(Skenario.objects.select_related("hasil"), pk=pk)
    sk = Skenario.objects.get(pk=pk)
    nama = (request.POST.get("nama_kustom") or "").strip()
    _jadikan_kustom(sk, asal.nama, asal.singkat)
    if nama:
        sk.nama, sk.singkat = nama, nama[:24]
    elif sk.nama.endswith("(ubah)"):
        sk.nama, sk.singkat = f"{asal.nama} (kustom)", f"{asal.label} kustom"[:24]
    sk.status = asal.status
    sk.save()
    if hasattr(asal, "hasil"):
        HasilSkenario.objects.create(skenario=sk, data=asal.hasil.data, durasi_detik=asal.hasil.durasi_detik)
    messages.success(request, f"Disimpan sebagai skenario kustom “{sk.nama}”.")
    return redirect(request.POST.get("next") or reverse("simulasi:detail", args=[sk.pk]))


@require_POST
def ganti_nama(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    nama = (request.POST.get("nama") or "").strip()
    if sk.bawaan:
        messages.error(request, "Paket default tidak diganti namanya; simpan sebagai kustom dulu.")
    elif nama:
        sk.nama = nama[:120]
        sk.singkat = (request.POST.get("singkat") or "").strip()[:24]
        sk.save(update_fields=["nama", "singkat", "diubah"])
        messages.success(request, "Nama skenario diperbarui.")
    return redirect(request.POST.get("next") or reverse("simulasi:detail", args=[sk.pk]))


def unduh_hitung(request, pk):
    """Tabel panjang provinsi × tahun dari langkah perhitungan (setara lembar Hitung/Kumpulan Excel)."""
    sk = get_object_or_404(Skenario.objects.select_related("hasil"), pk=pk)
    h = sk.hasil.data.get("hitung") if hasattr(sk, "hasil") else None
    if not h:
        messages.error(request, "Jalankan ulang skenario untuk membuat tabel hitung.")
        return redirect("simulasi:detail", pk=pk)
    resp = HttpResponse(content_type="text/csv; charset=utf-8")
    resp["Content-Disposition"] = f'attachment; filename="skenario_{sk.pk}_hitung.csv"'
    resp.write("\ufeff")
    w = csv.writer(resp)
    w.writerow([f"{HITUNG[k][0]} ({HITUNG[k][1]})" if k in HITUNG else k for k in h["kolom"]])
    w.writerows(h["baris"])
    return resp


def _default_templat():
    versi = VersiData.aktif()
    p = SetParameter.objects.filter(bawaan=True).first()
    if not versi or not p:
        return None
    return versi, p, KoefisienSektoral.objects.filter(bawaan=True).first()


@require_POST
def templat_buat(request, kode):
    default = _default_templat()
    if kode not in templat.PER_KODE or not default:
        messages.error(request, "Paket tidak dikenal atau belum ada versi data aktif / set parameter default.")
        return redirect("simulasi:daftar")
    sk, error = templat.buat(kode, *default, dibuat_oleh=request.user if request.user.is_authenticated else None)
    if error:
        messages.error(request, f"{sk.nama}: {error}")
    else:
        messages.success(request, f"{sk.nama} dibuat dan dijalankan. Ubah asumsinya bila perlu.")
    return redirect("simulasi:detail", pk=sk.pk)


@require_POST
def templat_kembalikan(request, kode):
    sk = get_object_or_404(Skenario, kelompok=Skenario.Kelompok.BAWAAN, templat=kode)
    Skenario.objects.filter(pk=sk.pk).update(penyesuaian={})
    messages.info(request, f"Penyesuaian {sk.label} dihapus; paket kembali ke nilai awal.")
    _bangun_ulang_paket(request, [kode], True)
    return redirect("simulasi:daftar")


@require_POST
def templat_semua(request):
    default = _default_templat()
    if not default:
        messages.error(request, "Belum ada versi data aktif atau set parameter default.")
        return redirect("simulasi:daftar")
    sks, error = templat.buat_semua(*default, dibuat_oleh=request.user if request.user.is_authenticated else None)
    for g in error:
        messages.error(request, g)
    messages.success(request, f"{len(sks)} paket skenario dibuat dan dijalankan.")
    return redirect(reverse("simulasi:bandingkan") + "?" + "&".join(f"id={s.pk}" for s in sks))


def edit(request, pk=None):
    sk = get_object_or_404(Skenario, pk=pk) if pk else None
    sebelum = _isian_dari(sk) if sk else None
    form = FormSkenario(request.POST or None, instance=sk)
    if sk:
        _kunci_paket(form, sk)
    if request.method == "POST" and form.is_valid():
        if sk and sk.bawaan:
            _simpan_paket(sk, sebelum, form.save(commit=False))
            _bangun_ulang_paket(request, [sk.templat], "jalankan" in request.POST)
            return redirect("simulasi:detail", pk=sk.pk)
        sk = form.save(commit=False)
        if not sk.pk and request.user.is_authenticated:
            sk.dibuat_oleh = request.user
        sk.save()
        if "jalankan" in request.POST:
            return _jalankan_dan_arahkan(request, sk)
        messages.success(request, "Skenario disimpan.")
        return redirect("simulasi:detail", pk=sk.pk)
    return render(request, "simulasi/form.html", {"form": form, "sk": sk})


def _jalankan_dan_arahkan(request, sk):
    hasil, error = layanan.jalankan(sk)
    if error:
        messages.error(request, f"Simulasi gagal: {error}")
    else:
        for p in hasil.data["meta"].get("peringatan", []):
            messages.warning(request, p)
        messages.success(request, f"Simulasi selesai dalam {hasil.durasi_detik:.1f} detik.")
    return redirect("simulasi:detail", pk=sk.pk)


@require_POST
def jalankan(request, pk):
    return _jalankan_dan_arahkan(request, get_object_or_404(Skenario, pk=pk))


@require_POST
def duplikat(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    _jadikan_kustom(sk, sk.nama, sk.singkat)
    sk.nama = sk.nama.replace(" (ubah)", " (salinan)")
    sk.save()
    messages.success(request, "Skenario disalin. Ubah asumsinya lalu jalankan.")
    return redirect("simulasi:edit", pk=sk.pk)


@require_POST
def hapus(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    if sk.bawaan:
        messages.error(request, "Paket default tidak dihapus; perbarui dari daftar paket bila perlu.")
        return redirect("simulasi:detail", pk=pk)
    if request.session.get(aktif.KUNCI) == sk.pk:
        request.session.pop(aktif.KUNCI)
    sk.delete()
    messages.info(request, f"Skenario “{sk.nama}” dihapus.")
    return redirect("simulasi:daftar")


def detail(request, pk):
    sk = get_object_or_404(Skenario.objects.select_related("versi_data", "set_parameter", "koef_sektoral"), pk=pk)
    data = sk.hasil.data if hasattr(sk, "hasil") else None
    konteks = {"sk": sk, "data": data, "jenis_kejutan": JENIS_KEJUTAN, "nama_jalur": JALUR}
    if data:
        prov = data["provinsi"]
        u = data.get("ketidakpastian", {})
        for p in prov:
            p["prob"] = u.get("prob_provinsi", {}).get(str(p["kode"]))
            p["p10"] = u.get("g_prov_p10", {}).get(str(p["kode"]))
            p["p90"] = u.get("g_prov_p90", {}).get(str(p["kode"]))
        peta = {
            "kebutuhan": {str(p["kode"]): p["kebutuhan_tambahan_kumulatif"] / 1000 for p in prov},
            "rasio": {str(p["kode"]): p["rasio_kebutuhan_pdrb"] for p in prov},
            "g_skenario": {str(p["kode"]): p["g_skenario"] for p in prov},
            "gap": {str(p["kode"]): p["g_skenario"] - p["g_sasaran"] for p in prov},
            "prob": {str(p["kode"]): p["prob"] for p in prov},
            "g_K": {str(p["kode"]): p["g_K_kebutuhan"] for p in prov},
            "tfp": {str(p["kode"]): p["tfp_T_skenario"] for p in prov},
        }
        matriks = data["sektoral"]["matriks"]
        konteks.update({
            "prov": sorted(prov, key=lambda p: -p["kebutuhan_tambahan_kumulatif"]),
            "peta": peta, "u": u,
            "sektor": data["sektoral"]["sektor"], "kelompok": data["sektoral"]["kelompok"],
            "determinan": _ringkas_determinan(data),
            "matriks": [(NAMA_PROVINSI[int(k)], [v[s] / 1000 for s in KODE_SEKTOR], sum(v.values()) / 1000)
                        for k, v in sorted(matriks.items(), key=lambda kv: -sum(kv[1].values()))],
            "kode_sektor": KODE_SEKTOR, "nama_sektor": NAMA_SEKTOR,
            "rg": data["nasional"]["ringkasan"],
            "capai": data["nasional"]["ringkasan"]["g_rata_skenario"]
            >= data["nasional"]["ringkasan"].get("g_rata_sasaran", sk.sasaran) - 0.005,
            "nama_prov": {str(k): v for k, v in NAMA_PROVINSI.items()},
            "seri_prov": {str(p["kode"]): p["seri"] for p in prov},
        })
        if data["meta"].get("rinci_papua"):
            konteks["papua"] = _baris_papua(prov)
            konteks["pangsa_papua"] = data["meta"].get("pangsa_papua", {})
    return render(request, "simulasi/detail.html", konteks)


def _baris_papua(prov):
    """Induk 34 provinsi (jumlah anggota) diikuti anggota keluarganya."""
    per_kode = {p["kode"]: p for p in prov}
    baris = []
    for induk, kel in KELUARGA.items():
        anggota = [per_kode[k] for k in kel if k in per_kode]
        if not anggota:
            continue
        pdrb = sum(p["pdrb0"] for p in anggota)
        bobot = lambda kunci: sum(p[kunci] * p["pdrb0"] for p in anggota) / pdrb
        baris.append({
            "nama": f"{NAMA_PROVINSI[induk]} (34 provinsi)", "induk": NAMA_PROVINSI[induk],
            "pdrb0_T": pdrb / 1000, "inv0_T": sum(p["inv0"] for p in anggota) / 1000,
            "g_tfp": bobot("g_tfp"), "g_sasaran": bobot("g_sasaran"), "g_dasar": bobot("g_dasar"),
            "g_skenario": bobot("g_skenario"), "prob": None, "g_K_kebutuhan": bobot("g_K_kebutuhan"),
            "keb_T": sum(p["kebutuhan_tambahan_kumulatif"] for p in anggota) / 1000,
            "rasio_kebutuhan_pdrb": bobot("rasio_kebutuhan_pdrb"),
            "a2_T": sum(p["a2_kumulatif"] for p in anggota) / 1000,
        })
        for p in anggota:
            baris.append({**p, "induk": "", "pdrb0_T": p["pdrb0"] / 1000, "inv0_T": p["inv0"] / 1000,
                          "keb_T": p["kebutuhan_tambahan_kumulatif"] / 1000, "a2_T": p["a2_kumulatif"] / 1000})
    return baris


def unduh_hasil(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    if not hasattr(sk, "hasil"):
        messages.error(request, "Jalankan skenario dulu.")
        return redirect("simulasi:detail", pk=pk)
    return _unduh(excel_skenario.ekspor_hasil(sk, sk.hasil.data), f"skenario_{sk.pk}_hasil.xlsx")


def asumsi_provinsi(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    form = FormAsumsiProvinsi(request.POST or None, override=sk.override_provinsi, kode=sk.kode_provinsi)
    if request.method == "POST" and form.is_valid():
        sk.override_provinsi = form.ke_override()
        if hasattr(sk, "hasil"):
            sk.status = Skenario.Status.USANG
        sk.save()
        messages.success(request, f"Asumsi {len(sk.override_provinsi)} provinsi disimpan.")
        return redirect("simulasi:detail", pk=pk)
    ref = {p["kode"]: p for p in sk.hasil.data["provinsi"]} if hasattr(sk, "hasil") else {}
    return render(request, "simulasi/asumsi_provinsi.html", {
        "sk": sk, "form": form, "kolom": KOLOM_ASUMSI, "ref": ref, "kelompok": KELOMPOK})


def unduh_asumsi(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    data = sk.hasil.data if hasattr(sk, "hasil") else None
    return _unduh(excel_skenario.lembar_asumsi(sk, data), f"skenario_{sk.pk}_asumsi_provinsi.xlsx")


@require_POST
def unggah_asumsi(request, pk):
    sk = get_object_or_404(Skenario, pk=pk)
    berkas = request.FILES.get("berkas")
    if not berkas:
        messages.error(request, "Pilih berkas lembar asumsi.")
        return redirect("simulasi:asumsi_provinsi", pk=pk)
    try:
        override, pesan = excel_skenario.baca_lembar_asumsi(berkas)
    except Exception as e:  # workbook rusak atau bukan lembar asumsi
        messages.error(request, f"Lembar asumsi tidak terbaca: {e}")
        return redirect("simulasi:asumsi_provinsi", pk=pk)
    sk.override_provinsi = override
    if hasattr(sk, "hasil"):
        sk.status = Skenario.Status.USANG
    sk.save()
    for p in pesan[:10]:
        messages.warning(request, p)
    messages.success(request, f"Asumsi {len(override)} provinsi dimuat dari Excel. Jalankan ulang skenario.")
    return redirect("simulasi:asumsi_provinsi", pk=pk)


def bandingkan(request):
    semua = list(Skenario.objects.filter(hasil__isnull=False).select_related("hasil", "versi_data")
                 .order_by("kelompok", "templat", "nama"))
    dipilih = [int(i) for i in request.GET.getlist("id") if i.isdigit()]
    per_pk = {s.pk: s for s in semua}
    terpilih = [per_pk[i] for i in dict.fromkeys(dipilih) if i in per_pk]
    if not terpilih:
        terpilih = [s for s in semua if s.bawaan]
        ak = aktif.ambil(request)
        if ak and ak.pk in per_pk and ak not in terpilih:
            terpilih.append(per_pk[ak.pk])
    seri = []
    for s in terpilih:
        n = s.hasil.data["nasional"]
        seri.append({"nama": s.label, "nama_lengkap": s.nama, "pk": s.pk, "tahun": n["tahun"], "g": n["g_skenario"],
                     "g_sasaran": n["g_sasaran"], "keb": n["tambahan_kebutuhan"], "a2": n["inv_a2"],
                     "tfp": n["tfp_skenario"], "rg": n["ringkasan"],
                     "prob": s.hasil.data.get("ketidakpastian", {}).get("prob_nasional"),
                     "p80": s.hasil.data.get("ketidakpastian", {}).get("kebutuhan_tambahan_kum", {}).get("p80"),
                     "status": s.get_status_display()})
    konteks = {"semua": semua, "terpilih": [s.pk for s in terpilih], "seri": seri}
    if terpilih:
        konteks.update(_peta_banding(terpilih))
    return render(request, "simulasi/bandingkan.html", konteks)


def _peta_banding(terpilih):
    """Peta historis lima tahun dan peta per skenario untuk indikator yang sepadan."""
    acuan = terpilih[0]
    versi = acuan.versi_data
    rinci = any(s.hasil.data["meta"].get("rinci_papua") for s in terpilih) and versi.bisa_rinci_papua
    df = tambah_turunan(versi.ke_dataframe_38() if rinci else versi.ke_dataframe())
    akhir = acuan.tahun_dasar
    hist = historis_lima_tahun(df, akhir, acuan.sasaran)
    hist["g_dasar"] = hist["g"]
    per_skenario = []
    for s in terpilih:
        d = s.hasil.data
        prov = d["provinsi"]
        u = d.get("ketidakpastian", {}).get("prob_provinsi", {})
        per_skenario.append({
            "nama": s.label, "pk": s.pk, "sasaran": s.sasaran,
            "nilai": {
                "g": {str(p["kode"]): p["g_skenario"] for p in prov},
                "g_dasar": {str(p["kode"]): p["g_dasar"] for p in prov},
                "pmtb": {str(p["kode"]): p["g_K_kebutuhan"] for p in prov},
                "inv": {str(p["kode"]): sum(p["seri"]["kebutuhan"]) / len(p["seri"]["kebutuhan"]) for p in prov},
                "peluang": {str(p["kode"]): u.get(str(p["kode"])) for p in prov},
            },
        })
    a, b = hist["tahun"]
    indikator = [
        {"kode": "g", "label": "Laju PDRB riil", "satuan": "%/thn", "digit": 2, "skema": "seq",
         "hist": f"rata-rata majemuk {a}–{b}", "skenario": "laju dengan penambahan investasi"},
        {"kode": "g_dasar", "label": "Laju PDRB riil", "satuan": "%/thn", "digit": 2, "skema": "seq",
         "hist": f"rata-rata majemuk {a}–{b}", "skenario": "laju tanpa penambahan investasi"},
        {"kode": "pmtb", "label": "Laju PMTB riil", "satuan": "%/thn", "digit": 1, "skema": "merah",
         "hist": f"rata-rata majemuk {a}–{b}", "skenario": "dibutuhkan untuk sasaran"},
        {"kode": "inv", "label": "PMA+PMDN per tahun", "satuan": "T Rp", "digit": 1, "skema": "hijau",
         "hist": f"rata-rata realisasi {a}–{b}", "skenario": "rata-rata realisasi dibutuhkan"},
        {"kode": "peluang", "label": "Peluang mencapai sasaran", "satuan": "%", "digit": 0, "skema": "peluang",
         "hist": f"bagian tahun {a}–{b} dengan laju ≥ {acuan.sasaran:g}%".replace(".", ","),
         "skenario": "Monte Carlo"},
    ]
    beda_versi = sorted({s.versi_data.nama for s in terpilih if s.versi_data_id != versi.pk})
    return {"peta_banding": {"hist": hist, "skenario": per_skenario, "indikator": indikator},
            "versi_hist": versi, "rinci_hist": rinci, "beda_versi": beda_versi,
            "pulau_prov": {str(k): v for k, v in PULAU_PROVINSI.items()},
            "tahun_pangsa": tahun_teramati(versi.pangsa_pemekaran) if rinci else []}

