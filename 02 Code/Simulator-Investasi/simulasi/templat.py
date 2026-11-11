"""
Paket skenario investasi default: dari BAU ke kebutuhan penuh sasaran 8%.

Setiap paket menimpa isian paket `dasar`-nya, sehingga perbedaan antarpaket dapat
dibaca sebagai efek satu kelompok kebijakan. Angka rupiah dalam triliun Rp nominal.
Kode P0-P7 hanya kunci internal (field `templat`); pengguna melihat `nama` dan `singkat`.

Angka di sini adalah nilai awal. Perubahan pengguna pada paket default disimpan di
`Skenario.penyesuaian` dan ditimpakan pada tingkat paket itu, sehingga ikut diwariskan ke
paket turunannya dan tetap berlaku saat paket dibangun ulang dengan data baru.

Isian khusus (bukan field Skenario):
    a1_laju      : investasi dasar = realisasi PMA+PMDN tahun dasar x (1 + laju)^h
    bobot_pulau  : bobot alokasi investasi tambahan per pulau (override bobot tiap provinsi)
    a2_kebutuhan : investasi tambahan per tahun diskalakan dari kebutuhan tambahan sampai laju nasional
                   dengan penambahan investasi = sasaran
"""

from dataclasses import replace

import numpy as np

from datapanel.referensi import PULAU_PROVINSI

from . import layanan
from .mesin import GalatSimulasi, MesinSimulasi
from .models import Skenario

# Sumber angka rupiah (triliun Rp nominal):
# - Renstra Kementerian Investasi dan Hilirisasi/BKPM 2025-2029 (Permen Investasi dan Hilirisasi/Kepala BKPM
#   No. 6 Tahun 2025), Tabel 4.1: target nilai PMA+PMDN dan target realisasi penanaman modal bidang hilirisasi;
#   Bab I: Peta Jalan Hilirisasi Investasi Strategis 2023-2040 dengan kebutuhan USD 618,0 miliar; Bab III: target
#   pertumbuhan ekonomi RPJMN 2025-2029.
# - Realisasi PMA+PMDN BKPM pada data panel: 692,8 (2017), 809,6 (2019), 826,3 (2020), 901,0 (2021), 1.931,1 (2025).
TARGET_RENSTRA = {"2026": 2175.3, "2027": 2567.5, "2028": 2969.6, "2029": 3414.8}
TARGET_HILIRISASI = {"2026": 586.6, "2027": 675.6, "2028": 779.3, "2029": 901.6}
PETA_JALAN_USD, PETA_JALAN_TAHUN = 618.0, 18  # miliar USD, 2023-2040
KURS = 16500  # Rp/USD, asumsi dasar ekonomi makro APBN 2026
A2_HILIRISASI = {th: round(PETA_JALAN_USD / PETA_JALAN_TAHUN * KURS / 1000, 1) for th in TARGET_RENSTRA}
LAJU_REALISASI_LAMBAT = 6.8  # %/thn, rata-rata realisasi 2017-2021 (692,8 -> 901,0)
KOMPOSISI_HILIRISASI = {"primer": 10, "sekunder": 60, "tva": 25, "tlain": 5}
BOBOT_KTI = {"Sumatera": 1, "Jawa": 1, "Bali-Nusra": 2, "Kalimantan": 2, "Sulawesi": 2, "Maluku-Papua": 2}

# Kejutan realisasi meniru 2020: realisasi 5,6% di bawah laju 2017-2019 (8,1%/thn) dan 2021 masih 4,8% di bawah.
KEJUTAN_PERLAMBATAN = [
    {"nama": "Penundaan proyek", "jenis": "investasi", "tahun": 2026, "besar": -5.6, "persistensi": 0.85,
     "cakupan": "nasional"},
    {"nama": "Pelemahan permintaan global", "jenis": "tfp", "tahun": 2026, "besar": -1.0, "persistensi": 0.7,
     "cakupan": "nasional"},
]
SASARAN_BERTAHAP = {"2026": 6.3, "2027": 7.5, "2028": 7.7, "2029": 8.0}


def determinan(*bagian):
    """Gabungkan perubahan indikator determinan (SD di atas tren) per pilar; bagian belakang menimpa."""
    hasil = {}
    for b in bagian:
        for pilar, ind in b.items():
            hasil.setdefault(pilar, {"indikator": {}})["indikator"].update(ind)
    return hasil


# Laju historis 2017-2024 (median provinsi, SD/thn): lama sekolah +0,11; P1 +0,04; rasio PAD +0,05;
# belanja APBD +0,03; jalan mantap dan kargo ~0. Nilai paket adalah tambahan di atas laju itu; paket
# mewarisi determinan paket dasarnya dan indikator yang sama ditimpa.
DET_EFISIENSI = {"institusi": {"ln_apbd_belanja": -0.03}}
DET_PSN = {"konektivitas": {"ln_jalan_mantap": 0.05, "ln_kargo_kapal": 0.02}}
DET_HILIRISASI = {"konektivitas": {"ln_kargo_kapal": 0.04, "ln_kargo_kereta": 0.04}}
DET_PEMERATAAN = {"institusi": {"ln_apbd_belanja": 0.02}, "equity": {"ln_p1": 0.08}}
DET_REFORMASI = {"pendidikan": {"ln_lama_sekolah_mean": 0.20, "ln_lama_sekolah_harapan": 0.10},
                 "institusi": {"ln_rasio_pad": 0.05}, "konektivitas": {"ln_kargo_kereta": 0.08}}

TEMPLAT = [
    {"kode": "P0", "nama": "Business as Usual", "singkat": "BAU",
     "ringkas": "Realisasi PMA+PMDN mengikuti tren historis, tanpa investasi tambahan.",
     "deskripsi": "Investasi dasar = tren historis realisasi PMA+PMDN; tanpa investasi tambahan; TFP dan tenaga kerja "
                  "rata-rata historis. Laju tanpa dan dengan penambahan investasi sama, menunjukkan laju yang "
                  "dicapai tanpa kebijakan baru, dan kebutuhan "
                  "tambahan menunjukkan celah ke sasaran 8%.",
     "isian": {"sasaran": 8.0, "mode_sasaran": "seragam", "a1": {}, "a2": {}, "jalur": {}, "kejutan": []}},
    {"kode": "P1", "nama": "Risiko Perlambatan", "singkat": "Perlambatan", "dasar": "P0",
     "ringkas": "Realisasi 6,8%/thn seperti 2017-2021, kejutan ala 2020, TFP 75% dari tren.",
     "deskripsi": "Uji risiko: realisasi PMA+PMDN tumbuh 6,8%/thn, laju terlemah dalam data BKPM (2017-2021: "
                  "Rp692,8 T menjadi Rp901,0 T). Kejutan 2026 meniru 2020: realisasi 5,6% di bawah jalurnya dan baru "
                  "pulih perlahan (persistensi 0,85, seperti 2021 yang masih 4,8% di bawah). Asumsi: laju TFP 75% dari "
                  "rata-rata historis, level TFP turun 1% (persistensi 0,7), dan efisiensi anggaran memangkas belanja "
                  "APBD sekitar 2% di bawah tren (-0,03 standard deviation).",
     "isian": {"a1_laju": LAJU_REALISASI_LAMBAT, "faktor_tfp": 0.75, "kejutan": KEJUTAN_PERLAMBATAN,
               "determinan": determinan(DET_EFISIENSI)}},
    {"kode": "P2", "nama": "Percepatan Realisasi", "singkat": "Percepatan", "dasar": "P0",
     "ringkas": "Realisasi PMA+PMDN mencapai target Renstra BKPM: Rp2.175 T (2026) sampai Rp3.415 T (2029).",
     "deskripsi": "Investasi dasar = target nilai PMA+PMDN Renstra Kementerian Investasi dan Hilirisasi/BKPM 2025-2029: "
                  "Rp2.175,3 T (2026), Rp2.567,5 T (2027), Rp2.969,6 T (2028), Rp3.414,8 T (2029); bersama target 2025 "
                  "Rp1.905,6 T berjumlah Rp13.032,8 T, angka yang disebut Renstra sebagai kebutuhan untuk pertumbuhan 8%. "
                  "Realisasi 2025 Rp1.931,1 T. Belum ada investasi tambahan. Asumsi determinan: proyek strategis menambah "
                  "jalan mantap (+0,05 standard deviation, sekitar +3%) dan kargo kapal (+0,02, sekitar +2%).",
     "isian": {"a1": TARGET_RENSTRA, "determinan": determinan(DET_PSN)}},
    {"kode": "P3", "nama": "Hilirisasi", "singkat": "Hilirisasi", "dasar": "P2",
     "ringkas": "Target Renstra + Peta Jalan Hilirisasi Rp566,5 T/thn, 60% ke industri.",
     "deskripsi": "Di atas Percepatan Realisasi, investasi tambahan = laju Peta Jalan Hilirisasi Investasi Strategis "
                  "2023-2040 (USD 618,0 miliar menurut Renstra BKPM; USD 34,3 miliar/thn x Rp16.500 = Rp566,5 T/thn, "
                  "Rp2.266 T untuk 2026-2029). Sebagai pembanding, target realisasi bidang hilirisasi Renstra Rp586,6 T "
                  "(2026) sampai Rp901,6 T (2029). Diarahkan 60% sekunder, 25% jasa bernilai tambah, 10% primer, "
                  "5% tersier lain; dialokasikan menurut kebutuhan provinsi. Asumsi determinan: logistik smelter dan "
                  "kawasan industri menaikkan kargo kapal (total +0,04 standard deviation) dan kargo kereta (+0,04).",
     "isian": {"a2": A2_HILIRISASI, "komposisi_a2": KOMPOSISI_HILIRISASI, "alokasi_a2": "kebutuhan",
               "determinan": determinan(DET_HILIRISASI)}},
    {"kode": "P4", "nama": "Pemerataan KTI dan Fiskal Daerah", "singkat": "Pemerataan", "dasar": "P3",
     "ringkas": "Hilirisasi + investasi tambahan berbobot 2x untuk KTI, belanja modal APBD +3%, realokasi TK 2 poin, P1 turun.",
     "deskripsi": "Di atas Hilirisasi, investasi tambahan dialokasikan dengan bobot dua kali untuk provinsi Kalimantan, Sulawesi, "
                  "Bali-Nusra, dan Maluku-Papua, sejalan dengan target Renstra BKPM agar porsi realisasi luar Jawa naik "
                  "dari 52,4% (2026) ke 53,2% (2029). Asumsi: belanja modal APBD tambahan 3% belanja; 2 poin tenaga kerja "
                  "pertanian pindah ke industri pengolahan; belanja APBD +0,02 standard deviation (separuh tambahan belanja "
                  "modal bersifat neto, sekitar +1,5%) dan kedalaman kemiskinan P1 turun 0,08 standard deviation (sekitar 5%).",
     "isian": {"alokasi_a2": "manual", "bobot_pulau": BOBOT_KTI, "apbd_persen": 3.0,
               "realokasi_pp": 2.0, "tujuan_realokasi": "C",
               "determinan": determinan(DET_PEMERATAAN)}},
    {"kode": "P5", "nama": "Reformasi Produktivitas", "singkat": "Reformasi", "dasar": "P4",
     "ringkas": "Pemerataan + reformasi SDM, fiskal daerah, dan logistik; TFP 10% lebih cepat; sasaran proporsional.",
     "deskripsi": "Di atas Pemerataan, reformasi struktural diukur lewat determinan TFP (dalam standard deviation): "
                  "rata-rata lama sekolah +0,20 (sekitar +0,2 tahun), harapan lama sekolah +0,10, rasio PAD +0,05, "
                  "dan kargo kereta total +0,08. Reformasi regulasi yang tidak tercakup indikator menaikkan laju "
                  "TFP 10% di atas tren. Sasaran dibagi proporsional (provinsi cepat tetap lebih cepat, nasional 8%).",
     "isian": {"faktor_tfp": 1.10, "mode_sasaran": "proporsional",
               "determinan": determinan(DET_REFORMASI)}},
    {"kode": "P6", "nama": "Kebutuhan Penuh 8%", "singkat": "Penuh 8%", "dasar": "P5",
     "ringkas": "Asumsi Reformasi dengan investasi tambahan sebesar yang dibutuhkan agar laju nasional = 8%.",
     "deskripsi": "Asumsi Reformasi Produktivitas, tetapi investasi tambahan tiap tahun mengikuti pola kebutuhan tambahan dan "
                  "diskalakan sampai laju nasional dengan penambahan investasi tepat 8%; dialokasikan menurut kebutuhan. Menunjukkan besar "
                  "investasi yang konsisten dengan sasaran 8%. Nilainya disimpan sebagai angka biasa, sehingga tidak ikut "
                  "berubah bila asumsi lain disunting.",
     "isian": {"a2_kebutuhan": True, "alokasi_a2": "kebutuhan", "bobot_pulau": None}},
    {"kode": "P7", "nama": "Sasaran Bertahap", "singkat": "Bertahap", "dasar": "P6",
     "ringkas": "Sasaran naik bertahap 6,3% → 8,0% (2026-2029) dengan investasi tambahan sebesar kebutuhannya.",
     "deskripsi": "Asumsi Kebutuhan Penuh 8%, tetapi sasaran nasional naik bertahap 6,3; 7,5; 7,7; 8,0% per tahun, "
                  "sesuai target pertumbuhan RPJMN 2025-2029 yang dikutip Renstra BKPM (5,3% pada 2025). Investasi "
                  "tambahan diskalakan sampai laju rata-rata sama dengan rata-rata jalur sasaran.",
     "isian": {"jalur": {"sasaran": SASARAN_BERTAHAP}}},
]
PER_KODE = {t["kode"]: t for t in TEMPLAT}
KHUSUS = ("a1_laju", "bobot_pulau", "a2_kebutuhan")
# Identitas dan basis tidak diwariskan lewat penyesuaian; disimpan langsung pada paketnya.
TIDAK_DIWARISKAN = ("nama", "singkat", "deskripsi", "versi_data", "set_parameter", "koef_sektoral", "set_determinan")


def _timpa(dasar, lapis, tambah_determinan=False):
    """`tambah_determinan`: determinan paket menambah determinan warisan per pilar dan indikator;
    penyesuaian pengguna berisi keadaan lengkap sehingga menimpa seluruhnya."""
    out = dict(dasar)
    if "a1" in lapis:
        out.pop("a1_laju", None)
    if "a1_laju" in lapis:
        out.pop("a1", None)
    out.update(lapis)
    if tambah_determinan and "determinan" in lapis:
        dt = {p: {**v, "indikator": dict(v.get("indikator") or {})} for p, v in (dasar.get("determinan") or {}).items()}
        for p, v in lapis["determinan"].items():
            lama = dt.get(p, {"indikator": {}})
            dt[p] = {**lama, **v, "indikator": {**lama["indikator"], **(v.get("indikator") or {})}}
        out["determinan"] = dt
    return out


def isian(kode, sesuai=None):
    """Isian gabungan paket dan semua paket dasarnya; `sesuai` = {kode: penyesuaian pengguna} per tingkat."""
    t = PER_KODE[kode]
    gabung = isian(t["dasar"], sesuai) if t.get("dasar") else {}
    return _timpa(_timpa(gabung, t["isian"], tambah_determinan=True), (sesuai or {}).get(kode) or {})


A2_DIHITUNG = {k for k in PER_KODE if isian(k).get("a2_kebutuhan")}


def tersimpan():
    """Penyesuaian pengguna pada paket default: {kode: {field: nilai}}."""
    return {s.templat: s.penyesuaian for s in Skenario.objects.filter(kelompok=Skenario.Kelompok.BAWAAN)
            if s.penyesuaian}


def sesuaikan(kode, sebelum, sesudah):
    """Penyesuaian baru paket `kode` setelah isiannya berubah dari `sebelum` ke `sesudah`.

    Field yang kembali ke nilai paket (warisan paket dasar + isian paket) dihapus dari penyesuaian.
    """
    sesuai = tersimpan()
    acuan = isian(kode, {k: v for k, v in sesuai.items() if k != kode})
    hasil = dict(sesuai.get(kode) or {})
    for f, v in sesudah.items():
        if f in TIDAK_DIWARISKAN or v == sebelum.get(f) or (f == "a2" and kode in A2_DIHITUNG):
            continue
        if v == acuan.get(f, Skenario._meta.get_field(f).get_default()):
            hasil.pop(f, None)
        else:
            hasil[f] = v
    return hasil


def terdampak(kode_kode):
    """Paket yang perlu dibangun ulang (paket itu dan semua turunannya), dalam urutan tangga."""
    kena = set(kode_kode)
    for t in TEMPLAT:
        if t.get("dasar") in kena:
            kena.add(t["kode"])
    return [t["kode"] for t in TEMPLAT if t["kode"] in kena]


def _realisasi_dasar(versi, tahun):
    df = versi.ke_dataframe()
    sub = df.xs(tahun, level="tahun")
    return float(sub[["PMA", "PMDN"]].sum().sum() / 1000)


def _terapkan(sk, isi):
    for k, v in isi.items():
        if k not in KHUSUS:
            setattr(sk, k, v)
    if isi.get("a1_laju") is not None:
        r0 = _realisasi_dasar(sk.versi_data, sk.tahun_dasar)
        sk.a1 = {str(th): round(r0 * (1 + isi["a1_laju"] / 100) ** (th - sk.tahun_dasar), 1)
                 for th in sk.tahun_proyeksi}
    if isi.get("bobot_pulau"):
        sk.override_provinsi = {str(k): {"bobot_a2": isi["bobot_pulau"][PULAU_PROVINSI[k]]}
                                for k in sk.kode_provinsi}
    else:
        sk.override_provinsi = {}


def _a2_untuk_sasaran(sk, iterasi=12):
    """Jalur A2 (triliun/thn) yang membuat Xn nasional = sasaran.

    Bentuk jalur mengikuti kebutuhan tambahan per tahun; skalanya dicari dengan secant. Kebutuhan
    tambahan nasional saja tidak cukup karena surplus A1 di provinsi yang sudah melampaui sasaran
    mengurangi angka nasional, padahal A2 hanya dialokasikan ke provinsi yang kekurangan.
    """
    panel = sk.versi_data.ke_dataframe_38() if sk.rinci_papua else sk.versi_data.ke_dataframe()
    cfg = replace(layanan.konfigurasi_dari(sk), a2={}, n_simulasi=0)
    n = MesinSimulasi(panel, cfg).jalankan(dengan_mc=False)["nasional"]
    tahun = [str(th) for th in n["tahun"][1:]]
    bentuk = np.maximum(n["tambahan_rencana"], 0)
    if bentuk.sum() <= 0:
        return {}

    def selisih(s):
        a2 = {th: float(v) for th, v in zip(tahun, s * bentuk)}
        r = MesinSimulasi(panel, replace(cfg, a2=a2)).jalankan(dengan_mc=False)["nasional"]["ringkasan"]
        return r["g_rata_skenario"] - r["g_rata_sasaran"]

    s0, s1 = 1.0, 1.2
    f0, f1 = selisih(s0), selisih(s1)
    for _ in range(iterasi):
        if abs(f1) < 1e-4 or f1 == f0:
            break
        s0, s1, f0 = s1, max(s1 - f1 * (s1 - s0) / (f1 - f0), 0.0), f1
        f1 = selisih(s1)
    return {th: round(float(v), 0) for th, v in zip(tahun, s1 * bentuk)}


def buat(kode, versi, set_parameter, koef_sektoral, dibuat_oleh=None, jalankan=True):
    """Buat (dan jalankan) satu paket beserta penyesuaian pengguna. Kembalikan (Skenario, error | None)."""
    t = PER_KODE[kode]
    isi = isian(kode, tersimpan())
    sk = Skenario(nama=t["nama"], singkat=t["singkat"], kelompok=Skenario.Kelompok.BAWAAN, templat=kode,
                  deskripsi=t["deskripsi"], versi_data=versi, set_parameter=set_parameter,
                  koef_sektoral=koef_sektoral, dibuat_oleh=dibuat_oleh)
    lama = Skenario.objects.select_related("hasil").filter(kelompok=Skenario.Kelompok.BAWAAN, templat=kode).first()
    if lama:
        sk.pk, sk.dibuat, sk.penyesuaian = lama.pk, lama.dibuat, lama.penyesuaian
        sk.set_determinan_id = lama.set_determinan_id
    _terapkan(sk, isi)
    if isi.get("a2_kebutuhan"):
        try:
            sk.a2 = _a2_untuk_sasaran(sk)
        except GalatSimulasi as e:
            sk.save()
            return sk, str(e)
    if not jalankan:
        sk.status = Skenario.Status.USANG if lama and hasattr(lama, "hasil") else Skenario.Status.BARU
        sk.save()
        return sk, None
    sk.save()
    _, error = layanan.jalankan(sk)
    return sk, error


def buat_semua(versi, set_parameter, koef_sektoral, dibuat_oleh=None):
    hasil = [buat(t["kode"], versi, set_parameter, koef_sektoral, dibuat_oleh) for t in TEMPLAT]
    return [sk for sk, _ in hasil], [f"{sk.nama}: {g}" for sk, g in hasil if g]


def bangun_ulang(kode_kode, jalankan=True):
    """Bangun ulang paket `kode_kode` dan turunannya dengan versi data dan parameter masing-masing."""
    hasil = []
    for kode in terdampak(kode_kode):
        lama = Skenario.objects.filter(kelompok=Skenario.Kelompok.BAWAAN, templat=kode).first()
        if lama:
            hasil.append(buat(kode, lama.versi_data, lama.set_parameter, lama.koef_sektoral,
                              lama.dibuat_oleh, jalankan=jalankan))
    return hasil


# Rekomendasi jalur: skenario kustom bergaya Sasaran Bertahap dengan sasaran dan fokus berbeda.
# Dasar: skrining transmisi sektor 2025 (multiplier output IO, klasifikasi keterkaitan), aturan penyeimbangan
# portofolio pada telaah TFP-BKPM, dan triangulasi kuadran bukti-perencanaan Bagian 6.1.6.
REKOMENDASI = [
    {"nama": "Rekomendasi Jalur Basis Industri dan Aktivasi", "singkat": "Jalur Industri",
     "deskripsi": "Seperti Sasaran Bertahap, dengan sasaran 6,0; 7,0; 7,8; 8,2% (2026-2029). Investasi tambahan 65% ke "
                  "sekunder: industri pengolahan menyerap 40,5% realisasi PMA+PMDN 2025 dengan multiplier output 2,06, "
                  "listrik dan gas 2,83, konstruksi 2,12. Sebanyak 25% ke jasa bernilai tambah, dengan transportasi "
                  "2,02 sebagai sektor kunci dua arah. Primer hanya 5% dan disyaratkan masuk ke hilir. "
                  "Determinan (dalam standard deviation) menekankan jalan mantap (+0,15, sekitar +9%), kargo kereta (+0,08), "
                  "kargo kapal (+0,04), dan rata-rata lama sekolah (+0,15) untuk keterampilan yang dipakai di produksi.",
     "isian": {"jalur": {"sasaran": {"2026": 6.0, "2027": 7.0, "2028": 7.8, "2029": 8.2}},
               "komposisi_a2": {"primer": 5, "sekunder": 65, "tva": 25, "tlain": 5},
               "alokasi_a2": "kebutuhan", "bobot_pulau": None, "realokasi_pp": 2.0, "tujuan_realokasi": "C",
               "a2_kebutuhan": True,
               "determinan": determinan({"konektivitas": {"ln_jalan_mantap": 0.15, "ln_kargo_kereta": 0.08,
                                                          "ln_kargo_kapal": 0.04},
                                         "pendidikan": {"ln_lama_sekolah_mean": 0.15},
                                         "institusi": {"ln_rasio_pad": 0.03}, "equity": {"ln_p1": 0.05}})}},
    {"nama": "Rekomendasi Jalur SDM dan Pemerataan", "singkat": "Jalur SDM",
     "deskripsi": "Seperti Sasaran Bertahap, dengan sasaran 5,8; 6,8; 7,6; 8,4%: lebih landai di awal karena efek "
                  "pendidikan baru terasa setelah jeda sekitar 3 tahun. Determinan (dalam standard deviation) bertumpu pada "
                  "pengungkit yang didukung bukti dan sudah direncanakan: rata-rata lama sekolah +0,35 (sekitar +0,35 "
                  "tahun di atas tren +0,1 tahun per tahun), harapan lama sekolah +0,15, kedalaman kemiskinan P1 turun "
                  "0,20 (sekitar 11%), dan IPM +0,05. Investasi tambahan berbobot dua kali untuk KTI, 35% ke jasa bernilai tambah "
                  "dan 15% ke tersier lain termasuk kesehatan (multiplier 2,19, crowd-in selektif); 2 poin tenaga kerja "
                  "pertanian pindah ke jasa bernilai tambah.",
     "isian": {"jalur": {"sasaran": {"2026": 5.8, "2027": 6.8, "2028": 7.6, "2029": 8.4}},
               "komposisi_a2": {"primer": 5, "sekunder": 45, "tva": 35, "tlain": 15},
               "alokasi_a2": "manual", "bobot_pulau": BOBOT_KTI, "realokasi_pp": 2.0, "tujuan_realokasi": "tva",
               "a2_kebutuhan": True,
               "determinan": determinan({"pendidikan": {"ln_lama_sekolah_mean": 0.35, "ln_lama_sekolah_harapan": 0.15},
                                         "equity": {"ln_p1": 0.20, "ln_ipm": 0.05},
                                         "institusi": {"ln_apbd_belanja": 0.02},
                                         "konektivitas": {"ln_jalan_mantap": 0.08}})}},
    {"nama": "Rekomendasi Jalur Tata Kelola Fiskal Daerah", "singkat": "Jalur Fiskal",
     "deskripsi": "Seperti Sasaran Bertahap, dengan sasaran 6,5; 7,2; 7,6; 8,0%: lebih tinggi di awal karena "
                  "perbaikan fiskal dan layanan daerah bekerja dengan jeda sekitar 1 tahun. Belanja modal APBD tambahan "
                  "5% belanja. Determinan (dalam standard deviation): rasio PAD +0,15 (sekitar 0,21 menjadi 0,24), belanja "
                  "APBD +0,04 (sekitar +3%), jalan mantap +0,10, P1 turun 0,08, dan lama sekolah +0,10. Investasi "
                  "tambahan mengikuti komposisi Hilirisasi dengan 10% tersier lain, dialokasikan menurut kebutuhan. "
                  "Efek belanja dibaca bersyarat pada komposisi dan keluaran layanan, bukan besar anggaran.",
     "isian": {"jalur": {"sasaran": {"2026": 6.5, "2027": 7.2, "2028": 7.6, "2029": 8.0}},
               "komposisi_a2": {"primer": 10, "sekunder": 55, "tva": 25, "tlain": 10},
               "alokasi_a2": "kebutuhan", "bobot_pulau": None, "apbd_persen": 5.0, "a2_kebutuhan": True,
               "determinan": determinan({"institusi": {"ln_rasio_pad": 0.15, "ln_apbd_belanja": 0.04},
                                         "konektivitas": {"ln_jalan_mantap": 0.10},
                                         "equity": {"ln_p1": 0.08},
                                         "pendidikan": {"ln_lama_sekolah_mean": 0.10}})}},
]


# Skenario contoh mandiri (tidak mewarisi paket). `a2_selisih_renstra`: investasi tambahan = target nilai PMA+PMDN
# Renstra dikurangi tren historis realisasi (nol bila tren sudah di atas target).
CONTOH = [
    {"nama": "Sasaran 8% dengan tren historis", "singkat": "Tren 8%",
     "deskripsi": "Semua provinsi tumbuh 8%. TFP dan tenaga kerja mengikuti rata-rata 2018-2024. Investasi dasar = tren "
                  "historis realisasi PMA+PMDN; investasi tambahan = selisih target nilai PMA+PMDN Renstra BKPM "
                  "2025-2029 di atas tren itu, dialokasikan menurut kebutuhan.",
     "isian": {"a2_selisih_renstra": True}},
    {"nama": "Masterplan 8-4-2-2 (TFP 2%, hilirisasi)", "singkat": "Masterplan",
     "deskripsi": "TFP 2%/thn di semua provinsi sesuai alokasi Masterplan. Investasi tambahan setara target realisasi "
                  "bidang hilirisasi Renstra BKPM: Rp586,6 T (2026), Rp675,6 T (2027), Rp779,3 T (2028), Rp901,6 T "
                  "(2029), diarahkan 60% ke sekunder dan 25% ke jasa bernilai tambah; realokasi 3 poin tenaga kerja "
                  "pertanian ke industri.",
     "isian": {"mode_tfp": "nasional", "tfp_nasional": 2.0, "mode_sasaran": "proporsional", "a2": TARGET_HILIRISASI,
               "komposisi_a2": KOMPOSISI_HILIRISASI, "realokasi_pp": 3.0}},
]


def _a2_selisih_renstra(sk):
    panel = sk.versi_data.ke_dataframe_38() if sk.rinci_papua else sk.versi_data.ke_dataframe()
    n = MesinSimulasi(panel, replace(layanan.konfigurasi_dari(sk), a2={}, n_simulasi=0)).jalankan(
        dengan_mc=False)["nasional"]
    tren = dict(zip((str(th) for th in n["tahun"][1:]), n["inv_tren"]))
    return {th: round(max(v - tren[th], 0.0), 1) for th, v in TARGET_RENSTRA.items() if th in tren}


def buat_contoh(versi, set_parameter, koef_sektoral, jalankan=True):
    """Buat atau perbarui skenario contoh berdasarkan nama. Kembalikan error."""
    error = []
    for c in CONTOH:
        isi = dict(c["isian"])
        selisih = isi.pop("a2_selisih_renstra", False)
        sk = Skenario.objects.filter(kelompok=Skenario.Kelompok.KUSTOM, nama=c["nama"]).first()
        if sk is None:
            sk = Skenario(nama=c["nama"], kelompok=Skenario.Kelompok.KUSTOM, versi_data=versi,
                          set_parameter=set_parameter, koef_sektoral=koef_sektoral)
        sk.singkat, sk.deskripsi = c["singkat"], c["deskripsi"]
        for k, v in isi.items():
            setattr(sk, k, v)
        try:
            if selisih:
                sk.a2 = _a2_selisih_renstra(sk)
        except GalatSimulasi as e:
            error.append(f"{sk.nama}: {e}")
        sk.status = Skenario.Status.BARU
        sk.save()
        if jalankan:
            _, g = layanan.jalankan(sk)
            if g:
                error.append(f"{sk.nama}: {g}")
    return error


def buat_rekomendasi(jalankan=True):
    """Buat atau perbarui skenario kustom Rekomendasi jalur dari paket Sasaran Bertahap. Kembalikan error."""
    dasar = Skenario.objects.filter(kelompok=Skenario.Kelompok.BAWAAN, templat="P7").first()
    if not dasar:
        return ["Paket Sasaran Bertahap belum ada."]
    error = []
    for r in REKOMENDASI:
        lama = Skenario.objects.filter(kelompok=Skenario.Kelompok.KUSTOM, nama=r["nama"]).first()
        sk = Skenario.objects.get(pk=dasar.pk)
        sk.pk, sk.id = (lama.pk, lama.pk) if lama else (None, None)
        sk._state.adding = lama is None
        sk.kelompok, sk.templat, sk.penyesuaian = Skenario.Kelompok.KUSTOM, "", {}
        sk.nama, sk.singkat, sk.deskripsi = r["nama"], r["singkat"], r["deskripsi"]
        if lama:
            sk.dibuat, sk.dibuat_oleh = lama.dibuat, lama.dibuat_oleh
        _terapkan(sk, r["isian"])
        try:
            sk.a2 = _a2_untuk_sasaran(sk)
        except GalatSimulasi as e:
            error.append(f"{sk.nama}: {e}")
        sk.status = Skenario.Status.BARU
        sk.save()
        if jalankan:
            _, g = layanan.jalankan(sk)
            if g:
                error.append(f"{sk.nama}: {g}")
    return error
