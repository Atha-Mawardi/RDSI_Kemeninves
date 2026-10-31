"""Bahan workbook dari basis data aplikasi: panel 38 provinsi, slot skenario, dan kumpulan koefisien."""

import re
from dataclasses import dataclass, field

from datapanel.referensi import KELOMPOK, KELOMPOK_SEKTOR, KODE_SEKTOR, NAMA_PROVINSI, NAMA_SEKTOR, PULAU, PULAU_PROVINSI
from estimasi.determinan import AWAL as DET_AWAL, JEDA_AWAL, NAMA_PILAR
from estimasi.models import KoefisienSektoral, SetDeterminan, SetParameter
from simulasi.models import Skenario

MAKS_H = 10
MAKS_BARIS_DATA = 600
N_KUSTOM_KOSONG = 2
KEL = ["primer", "sekunder", "tva", "tlain"]
JENIS_SHOCK = {"tfp": "TFP (level)", "pdrb": "PDRB langsung", "tk": "Tenaga kerja", "investasi": "Realisasi PMA+PMDN"}


@dataclass
class Slot:
    nama: str
    singkat: str
    sheet: str
    deskripsi: str = ""
    nilai: dict = field(default_factory=dict)  # kunci baris Skenario -> nilai
    prov: dict = field(default_factory=dict)  # kode -> {sasaran, tfp, tk, bobot}
    catatan: list = field(default_factory=list)


@dataclass
class Konteks:
    versi: object
    panel: object
    kode: list
    slot: list
    set_param: list
    set_sektoral: list
    det: list
    jeda: dict
    umum: dict
    kolom_data: list

    @property
    def versi_label(self):
        return f"{self.versi.nama} (#{self.versi.pk})"


def _nama_sheet(singkat, dipakai):
    kata = re.split(r"[^A-Za-z0-9]+", singkat)
    dasar = "M_" + "".join(k[:1].upper() + k[1:] for k in kata)[:20]
    nama, i = dasar, 2
    while nama in dipakai:
        nama, i = f"{dasar}{i}", i + 1
    dipakai.add(nama)
    return nama


def _isi_slot(sk, kode, det):
    v = {
        "nama": sk.nama, "singkat": sk.singkat or sk.nama[:14], "deskripsi": sk.deskripsi or "",
        "tampil": "ya",
        "set_param": sk.set_parameter.nama if sk.set_parameter_id else "Manual",
        "set_sektoral": sk.koef_sektoral.nama if sk.koef_sektoral_id else "Tanpa bonus sektoral",
        "sasaran": sk.sasaran, "mode_sasaran": sk.mode_sasaran, "lambda": sk.lambda_proporsional,
        "mode_tfp": "nasional" if sk.mode_tfp == "nasional" else "historis", "tfp_nasional": sk.tfp_nasional, "faktor_tfp": sk.faktor_tfp,
        "mode_tk": sk.mode_tk, "tk_nasional": sk.tk_nasional,
        "mode_pmtb": sk.mode_pmtb, "g_pmtb_nasional": sk.g_pmtb_nasional, "g_investasi": sk.g_investasi,
        "inflasi_pmtb": sk.inflasi_pmtb, "pass_through": sk.pass_through, "rasio_realisasi": sk.rasio_realisasi,
        "apbd_persen": sk.apbd_persen, "pass_through_apbd": sk.pass_through_apbd,
        "mode_a2": "angka", "skala_a2": 1.0, "alokasi_a2": sk.alokasi_a2,
        "realokasi_pp": sk.realokasi_pp, "tujuan_realokasi": sk.tujuan_realokasi,
        "skala_se": sk.skala_se, "volatilitas_tfp": sk.volatilitas_tfp,
    }
    th0 = sk.tahun_dasar
    for h in range(1, MAKS_H + 1):
        th = str(th0 + h)
        v[f"a1_{h}"] = (sk.a1 or {}).get(th)
        v[f"a2_{h}"] = (sk.a2 or {}).get(th)
        for kunci in ("sasaran", "faktor_tfp", "g_investasi"):
            v[f"j_{kunci}_{h}"] = ((sk.jalur or {}).get(kunci) or {}).get(th)
    for k in KEL:
        v[f"komp_{k}"] = (sk.komposisi_a2 or {}).get(k)
    catatan = []
    shock = [s for s in (sk.kejutan or []) if str(s.get("cakupan") or "nasional") == "nasional"]
    if len(shock) < len(sk.kejutan or []):
        catatan.append("Shock pulau/provinsi hanya ada di aplikasi.")
    if len(shock) > 2:
        catatan.append("Hanya dua shock pertama yang dibawa.")
    for i, s in enumerate(shock[:2], 1):
        v[f"s{i}_jenis"] = JENIS_SHOCK.get(s.get("jenis"), "")
        v[f"s{i}_tahun"] = s.get("tahun")
        v[f"s{i}_besar"] = s.get("besar")
        v[f"s{i}_rho"] = s.get("persistensi", 1)
    for pilar, d in (sk.determinan or {}).items():
        if not isinstance(d, dict):
            continue
        v[f"dp_{pilar}"] = d.get("dz") if d.get("dz") not in ("",) else None
        v[f"dj_{pilar}"] = d.get("jeda") if d.get("jeda") not in ("",) else None
        v[f"dr_{pilar}"] = d.get("penuh") if d.get("penuh") not in ("",) else None
        for kd, dz in (d.get("indikator") or {}).items():
            v[f"di_{kd}"] = dz
        if d.get("porsi") and d.get("biaya"):
            catatan.append(f"Determinan {NAMA_PILAR.get(pilar, pilar)} didanai dari investasi tambahan di aplikasi; "
                           "di sini perubahannya diisi langsung.")
        if str(d.get("cakupan") or "nasional") != "nasional":
            catatan.append(f"Cakupan determinan {NAMA_PILAR.get(pilar, pilar)} dibaca nasional.")
    prov = {}
    for k, o in (sk.override_provinsi or {}).items():
        k = int(k)
        if k in kode:
            prov[k] = {"sasaran": o.get("sasaran"), "tfp": o.get("tfp"), "tk": o.get("tk"), "bobot": o.get("bobot_a2")}
            if all(o.get(x) not in (None, "") for x in KEL):
                catatan.append("Komposisi sektor per provinsi hanya ada di aplikasi.")
    return v, prov, sorted(set(catatan))


def kumpulkan(versi=None):
    paket = list(Skenario.objects.filter(kelompok=Skenario.Kelompok.BAWAAN).order_by("templat"))
    kustom = list(Skenario.objects.filter(kelompok=Skenario.Kelompok.KUSTOM).order_by("pk"))
    semua = paket + kustom
    if not semua:
        raise ValueError("Belum ada skenario; buat paket bawaan dulu di halaman Skenario.")
    acuan = paket[0] if paket else semua[0]
    versi = versi or acuan.versi_data
    if not versi.bisa_rinci_papua:
        raise ValueError("Versi data belum punya pangsa pemekaran Papua (38 provinsi).")
    panel = versi.ke_dataframe_38().sort_index()
    kode = sorted(int(k) for k in set(panel.index.get_level_values("kode")))
    det = list((SetDeterminan.utama().indikator if SetDeterminan.utama() else DET_AWAL))

    dipakai, slot = set(), []
    for sk in semua:
        v, prov, cat = _isi_slot(sk, kode, det)
        slot.append(Slot(nama=v["nama"], singkat=v["singkat"], sheet=_nama_sheet(v["singkat"], dipakai),
                         deskripsi=v["deskripsi"], nilai=v, prov=prov, catatan=cat))
    dasar = next((s for s in slot if s.singkat == "BAU"), slot[0])
    for i in range(1, N_KUSTOM_KOSONG + 1):
        v = dict(dasar.nilai, nama=f"Kustom {i}", singkat=f"Kustom{i}",
                 deskripsi="Slot bebas, awalnya salinan BAU.", tampil="tidak")
        slot.append(Slot(nama=v["nama"], singkat=v["singkat"], sheet=_nama_sheet(f"Kustom{i}", dipakai),
                         deskripsi=v["deskripsi"], nilai=v, prov={}))

    kolom = [c for c in panel.columns]
    umum = {"tahun_dasar": acuan.tahun_dasar, "tahun_target": acuan.tahun_target, "hist_awal": acuan.hist_awal,
            "hist_akhir": acuan.hist_akhir, "kecualikan_2020": acuan.kecualikan_2020}
    return Konteks(
        versi=versi, panel=panel, kode=kode, slot=slot,
        set_param=list(SetParameter.objects.order_by("-bawaan", "pk")),
        set_sektoral=list(KoefisienSektoral.objects.order_by("-bawaan", "pk")),
        det=det, jeda=dict(JEDA_AWAL), umum=umum, kolom_data=kolom)


PROVINSI = lambda kode: [(k, NAMA_PROVINSI[k], PULAU_PROVINSI[k]) for k in kode]  # noqa: E731
SEKTOR = [(s, NAMA_SEKTOR[s], KELOMPOK_SEKTOR[s]) for s in KODE_SEKTOR]
__all__ = ["Konteks", "Slot", "kumpulkan", "MAKS_H", "KEL", "KELOMPOK", "PULAU", "SEKTOR", "PROVINSI", "NAMA_PILAR",
           "JENIS_SHOCK", "MAKS_BARIS_DATA"]
