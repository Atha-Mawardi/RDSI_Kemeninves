"""
Determinan TFP: log TFP provinsi pada indikator terstandar (z), satu regresi per pilar.

Koefisien = perubahan log TFP bila indikator (setelah transformasi) naik 1 standard deviation.
`sd` adalah standard deviation indikator setelah transformasi pada sampel estimasi 2017-2024
(34 provinsi, N = 272); `rata` rata-rata nilai asli, dipakai untuk menerjemahkan 1 SD ke satuan asli.
Transformasi: ln = ln(x + 1), -ln = -ln(x + 1), neg = -x, lin = x, sln = tanda(x) ln(|x| + 1),
lnx = ln(x).
"""

import math

PILAR = [("pendidikan", "Pendidikan"), ("equity", "Equity"), ("institusi", "Institusi"),
         ("konektivitas", "Konektivitas"), ("lingkungan", "Lingkungan"), ("keamanan", "Keamanan")]
NAMA_PILAR = dict(PILAR)

# jeda (tahun sebelum efek mulai) dan masa menuju efek penuh (tahun), asumsi awal per pilar
JEDA_AWAL = {"pendidikan": (3, 3), "equity": (2, 2), "institusi": (1, 2), "konektivitas": (1, 2),
             "lingkungan": (2, 2), "keamanan": (1, 1)}


def _i(kode, pilar, label, satuan, transformasi, koef, se, sd, rata):
    return {"kode": kode, "pilar": pilar, "label": label, "satuan": satuan, "transformasi": transformasi,
            "koef": koef, "se": se, "sd": sd, "rata": rata}


AWAL = [
    _i("ln_lama_sekolah_mean", "pendidikan", "Rata-rata lama sekolah", "tahun", "ln", 0.0592221, 0.0092319, 0.0982, 8.665),
    _i("ln_lama_sekolah_harapan", "pendidikan", "Harapan lama sekolah", "tahun", "ln", 0.1595007, 0.0193747, 0.0528, 13.165),
    _i("db_sd", "pendidikan", "APK SD (dibalik)", "poin", "neg", 0.0728173, 0.0065805, 3.9509, 107.287),
    _i("db_smp", "pendidikan", "APK SMP (dibalik)", "poin", "neg", 0.0038462, 0.005385, 4.4990, 90.563),
    _i("db_sma", "pendidikan", "APK SMA (dibalik)", "poin", "neg", 0.0553687, 0.0085259, 6.4350, 86.887),
    _i("db_kampus", "pendidikan", "APK perguruan tinggi (dibalik)", "poin", "neg", 0.2795585, 0.0119026, 10.4744, 34.030),
    _i("ln_p1", "equity", "Indeks kedalaman kemiskinan P1 (dibalik)", "indeks", "-ln", 0.1061731, 0.004859, 0.3858, 1.851),
    _i("ln_ipm", "equity", "Indeks Pembangunan Manusia", "indeks", "ln", 0.358278, 0.0103475, 0.0541, 71.542),
    _i("gini", "equity", "Rasio Gini", "rasio", "lin", 0.1784019, 0.0045988, 0.0411, 0.349),
    _i("ln_upah_rata", "equity", "Upah rata-rata", "Rp/bulan", "ln", -0.0331674, 0.008942, 0.3582, 1857029.28),
    _i("ln_indeks_demokrasi", "equity", "Indeks Demokrasi Indonesia", "indeks", "ln", 0.0350831, 0.0081916, 0.0880, 74.145),
    _i("price", "institusi", "Deflator PDRB (dibalik)", "indeks", "-ln", -0.0056631, 0.0036601, 0.0993, 153.342),
    _i("ln_rasio_pad", "institusi", "Rasio PAD", "rasio", "ln", 0.1719226, 0.0045132, 0.0989, 0.210),
    _i("ln_pertumbuhan_pdrb_adhb", "institusi", "Pertumbuhan PDRB ADHB", "%", "sln", -0.0140598, 0.0038353, 1.1791, 7.580),
    _i("ln_apbd_belanja", "institusi", "Belanja APBD", "miliar Rp", "ln", 0.3963639, 0.0031058, 0.7318, 34373.12),
    _i("ln_jalan_mantap", "konektivitas", "Jalan mantap", "km", "ln", 0.052738, 0.0055003, 0.5460, 1466.13),
    _i("ln_kargo_udara", "konektivitas", "Kargo udara", "juta ton", "ln", 0.039501, 0.0116776, 0.0248, 0.019),
    _i("ln_kargo_kapal", "konektivitas", "Kargo kapal", "juta ton", "ln", 0.2879663, 0.0195438, 1.0140, 17.574),
    _i("ln_kargo_kereta", "konektivitas", "Kargo kereta", "juta ton", "ln", 0.1664568, 0.0098406, 0.7711, 1.320),
    _i("ln_penumpang_total", "konektivitas", "Penumpang total", "orang", "lnx", -0.120262, 0.018081, 1.4648, 21165441.18),
    _i("ln_airport_logistik", "konektivitas", "Bandara logistik", "unit", "ln", 0.0374581, 0.0050536, 0.4163, 1.165),
    _i("ln_airport_komersil", "konektivitas", "Bandara komersial", "unit", "ln", 0.020801, 0.0052347, 0.3785, 0.989),
    _i("ln_indeks_lingkungan", "lingkungan", "Indeks Kualitas Lingkungan Hidup", "indeks", "ln", 0.0480204, 0.0110881, 0.1018, 69.531),
    _i("ln_indeks_hijau", "lingkungan", "Indeks hijau (tutupan lahan)", "indeks", "ln", -0.2204679, 0.0089747, 0.3282, 61.917),
    _i("ln_indeks_biru", "lingkungan", "Indeks biru (kualitas air)", "indeks", "ln", 0.0057704, 0.0089454, 0.0954, 52.655),
    _i("ln_crime_risk", "keamanan", "Risiko kejahatan (dibalik)", "per 100 rb", "-ln", -0.0268228, 0.0062895, 0.6033, 176.978),
    _i("ln_crime_rate", "keamanan", "Tingkat kejahatan (dibalik)", "per 100 rb", "-ln", 0.0013168, 0.0073373, 0.5589, 57.484),
]


def satu_sd(ind):
    """Arti +1 SD dalam satuan asli di sekitar rata-rata sampel: (perubahan, persen terhadap rata-rata)."""
    sd, m, t = float(ind.get("sd") or 0), float(ind.get("rata") or 0), ind.get("transformasi")
    if t in ("ln", "sln"):
        d = (m + 1) * math.expm1(sd)
    elif t == "lnx":
        d = m * math.expm1(sd)
    elif t == "-ln":
        d = -(m + 1) * -math.expm1(-sd)
    elif t == "neg":
        d = -sd
    else:
        d = sd
    return d, (d / m * 100 if m else None)


def per_pilar(indikator):
    """{pilar: [indikator...]} dalam urutan PILAR."""
    out = {p: [] for p, _ in PILAR}
    for ind in indikator:
        out.setdefault(ind["pilar"], []).append(ind)
    return out
