"""
Kamus variabel kanonik.

Setiap kolom yang masuk aplikasi dipetakan ke satu kode kanonik di sini. Alias
memuat nama kolom dataset agregasi tim (`9_ADHK`, `A_PMA`, `PAD_Prov2`, ...)
sehingga workbook tim bisa diunggah apa adanya. Urutan alias = urutan prioritas
bila satu berkas memuat dua kolom yang sama-sama cocok.
"""

from dataclasses import dataclass, field

from .referensi import KODE_SEKTOR, NAMA_SEKTOR


@dataclass(frozen=True)
class Variabel:
    kode: str
    label: str
    satuan: str
    grup: str
    alias: tuple = field(default_factory=tuple)
    # "jumlah": boleh dijumlahkan lintas provinsi dan saat melipat pemekaran
    agregasi: str = "jumlah"
    wajib: bool = False


_INTI = [
    Variabel("PDRB_ADHK", "PDRB harga konstan 2010", "miliar Rp", "Output",
             ("9_ADHK", "PDRB_ADHK", "ADHK_LU"), wajib=True),
    Variabel("PDRB_ADHB", "PDRB harga berlaku", "miliar Rp", "Output",
             ("9_ADHB", "PDRB_ADHB", "ADHB_LU")),
    Variabel("PMTB_ADHK", "PMTB harga konstan 2010", "miliar Rp", "Modal",
             ("4_ADHK", "PMTB_ADHK", "PMTB ADHK"), wajib=True),
    Variabel("PMTB_ADHB", "PMTB harga berlaku", "miliar Rp", "Modal",
             ("4_ADHB", "PMTB_ADHB", "PMTB ADHB", "pmtb"), wajib=True),
    Variabel("PMA", "Realisasi PMA", "miliar Rp", "Investasi BKPM",
             ("PMA", "PMA_1"), wajib=True),
    Variabel("PMDN", "Realisasi PMDN", "miliar Rp", "Investasi BKPM",
             ("PMDN", "PMDN_1"), wajib=True),
    Variabel("PAD", "Pendapatan Asli Daerah", "miliar Rp", "Fiskal daerah",
             ("PAD", "PAD_Miliar", "PAD_Prov2")),
    Variabel("APBD_PENDAPATAN", "Pendapatan APBD", "miliar Rp", "Fiskal daerah",
             ("APBD_PENDAPATAN", "Pendapatan_APBD_Prov")),
    Variabel("APBD_BELANJA", "Belanja APBD", "miliar Rp", "Fiskal daerah",
             ("APBD_BELANJA", "Belanja_APBD_Prov")),
]

_SEKTORAL = []
for _s in KODE_SEKTOR:
    _n = NAMA_SEKTOR[_s]
    _SEKTORAL += [
        Variabel(f"VA_{_s}", f"Nilai tambah {_s} ({_n}), ADHK", "miliar Rp",
                 "PDRB sektoral", (f"VA_{_s}", f"{_s}_ADHK"), wajib=True),
        Variabel(f"TK_{_s}", f"Tenaga kerja {_s} ({_n})", "jiwa",
                 "Tenaga kerja", (f"TK_{_s}", f"{_s}_TenagaKerja"), wajib=True),
        Variabel(f"PMA_{_s}", f"PMA {_s} ({_n})", "miliar Rp",
                 "Investasi sektoral", (f"PMA_{_s}", f"{_s}_PMA")),
        Variabel(f"PMDN_{_s}", f"PMDN {_s} ({_n})", "miliar Rp",
                 "Investasi sektoral", (f"PMDN_{_s}", f"{_s}_PMDN")),
    ]
# Dataset tim salah eja satu kolom: PMDN sektor O tertulis `O_PMA.1`.
_SEKTORAL = [
    Variabel(v.kode, v.label, v.satuan, v.grup, v.alias + ("O_PMA.1",), v.agregasi, v.wajib)
    if v.kode == "PMDN_O" else v
    for v in _SEKTORAL
]

# Indikator determinan TFP (sheet "Analisis Luaran 2" dataset tim). Belanja APBD dan rasio PAD sudah ada di atas.
_D = "Determinan TFP: "
_DETERMINAN = [
    Variabel("LAMA_SEKOLAH", "Rata-rata lama sekolah", "tahun", _D + "Pendidikan", ("Educ_Prov",), "rata"),
    Variabel("HARAPAN_SEKOLAH", "Harapan lama sekolah", "tahun", _D + "Pendidikan", ("Heduc_Prov",), "rata"),
    Variabel("APK_SD", "APK sekolah dasar", "%", _D + "Pendidikan", ("APK_Primer",), "rata"),
    Variabel("APK_SMP", "APK SMP", "%", _D + "Pendidikan", ("APK_Sekunder1",), "rata"),
    Variabel("APK_SMA", "APK SMA", "%", _D + "Pendidikan", ("APK_Sekunder2",), "rata"),
    Variabel("APK_PT", "APK perguruan tinggi", "%", _D + "Pendidikan", ("APK_Tersier",), "rata"),
    Variabel("P1_KEMISKINAN", "Indeks kedalaman kemiskinan (P1)", "indeks", _D + "Equity", ("Ikk_Prov",), "rata"),
    Variabel("IPM", "Indeks Pembangunan Manusia", "indeks", _D + "Equity", ("IPM_Prov_Nm",), "rata"),
    Variabel("GINI", "Rasio Gini", "rasio", _D + "Equity", ("Gini_Prov",), "rata"),
    Variabel("UPAH_RATA", "Upah rata-rata", "Rp/bulan", _D + "Equity", ("Upah_Agr_Prov",), "rata"),
    Variabel("IDI", "Indeks Demokrasi Indonesia", "indeks", _D + "Equity", ("IDI_Prov2",), "rata"),
    Variabel("DEFLATOR_PDRB", "Deflator PDRB", "indeks", _D + "Institusi", ("PDBDeflator",), "rata"),
    Variabel("G_PDRB_ADHB", "Pertumbuhan PDRB harga berlaku", "%", _D + "Institusi", ("Grwth1_Prov",), "rata"),
    Variabel("JALAN_NASIONAL", "Panjang jalan nasional", "km", _D + "Konektivitas", ("Road_Prov_National",)),
    Variabel("KARGO_UDARA", "Kargo udara", "juta ton", _D + "Konektivitas", ("Cargo_Udara_Prov",)),
    Variabel("KARGO_KAPAL", "Kargo kapal", "juta ton", _D + "Konektivitas", ("Cargo_Kapal_Prov",)),
    Variabel("KARGO_KERETA", "Kargo kereta", "juta ton", _D + "Konektivitas", ("Cargo_KA_Prov",)),
    Variabel("PAX_UDARA", "Penumpang udara", "orang", _D + "Konektivitas", ("PAX_Udara",)),
    Variabel("PAX_KERETA", "Penumpang kereta", "orang", _D + "Konektivitas", ("PAX_KA",)),
    Variabel("PAX_KAPAL", "Penumpang kapal", "orang", _D + "Konektivitas", ("PAX_Kapal",)),
    Variabel("PAX_BUS", "Penumpang bus", "orang", _D + "Konektivitas", ("PAX_Bus", "PAX_Bis")),
    Variabel("BANDARA_LOGISTIK", "Bandara logistik", "unit", _D + "Konektivitas", ("Airpot_Logis",)),
    Variabel("BANDARA_KOMERSIAL", "Bandara komersial", "unit", _D + "Konektivitas", ("Airpot_Commer",)),
    Variabel("IKLH", "Indeks Kualitas Lingkungan Hidup", "indeks", _D + "Lingkungan", ("IKLH_Prov",), "rata"),
    Variabel("INDEKS_HIJAU", "Indeks kualitas tutupan lahan", "indeks", _D + "Lingkungan", ("Hijau_Prov",), "rata"),
    Variabel("INDEKS_BIRU", "Indeks kualitas air", "indeks", _D + "Lingkungan", ("Biru_Prov",), "rata"),
    Variabel("RISIKO_KEJAHATAN", "Risiko kejahatan", "per 100 ribu penduduk", _D + "Keamanan",
             ("CrimeRisk_BPS",), "rata"),
    Variabel("TINGKAT_KEJAHATAN", "Tingkat kejahatan", "per 100 ribu penduduk", _D + "Keamanan", ("CR_Prov",), "rata"),
]

DAFTAR = _INTI + _SEKTORAL + _DETERMINAN
PER_KODE = {v.kode: v for v in DAFTAR}
GRUP = list(dict.fromkeys(v.grup for v in DAFTAR))
WAJIB = [v.kode for v in DAFTAR if v.wajib]

# Variabel yang ditampilkan di jelajah data dan peta beranda.
INDIKATOR_TURUNAN = {
    "TK_TOTAL": ("Tenaga kerja total", "jiwa"),
    "PMAPMDN": ("Realisasi PMA + PMDN", "miliar Rp"),
    "RASIO_INV_PMTB": ("Rasio (PMA+PMDN) / PMTB harga berlaku", "rasio"),
    "G_PDRB": ("Pertumbuhan PDRB riil", "%"),
    "G_PMTB": ("Pertumbuhan PMTB riil", "%"),
    "PDRB_PER_TK": ("Produktivitas tenaga kerja", "juta Rp/pekerja"),
    "RASIO_PAD": ("Rasio PAD / Pendapatan APBD", "rasio"),
    "PAX_TOTAL": ("Penumpang total", "orang"),
}
GRUP_TURUNAN = {"PAX_TOTAL": _D + "Konektivitas"}


def peta_alias():
    """Kunci alias (huruf kecil, tanpa spasi tepi) -> kode kanonik."""
    peta = {}
    for v in DAFTAR:
        for a in (v.kode,) + v.alias:
            peta.setdefault(a.strip().lower(), v.kode)
    return peta


def label(kode):
    if kode in PER_KODE:
        return PER_KODE[kode].label
    if kode in INDIKATOR_TURUNAN:
        return INDIKATOR_TURUNAN[kode][0]
    return kode


def satuan(kode):
    if kode in PER_KODE:
        return PER_KODE[kode].satuan
    if kode in INDIKATOR_TURUNAN:
        return INDIKATOR_TURUNAN[kode][1]
    return ""
