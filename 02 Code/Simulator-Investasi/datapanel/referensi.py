"""
Daftar acuan: 34 provinsi sebelum pemekaran Papua, enam pulau, 17 lapangan usaha.

Kode provinsi mengikuti `Code_Prov` dataset agregasi. Empat provinsi hasil
pemekaran Papua 2022 dilipat ke induknya lewat NAMA, bukan kode, sebab sebagian
berkas memakai kode induk (91/94) di kolom kode untuk baris provinsi baru.
"""

import re
import unicodedata

PROVINSI = [
    (11, "Aceh", "Sumatera"),
    (12, "Sumatera Utara", "Sumatera"),
    (13, "Sumatera Barat", "Sumatera"),
    (14, "Riau", "Sumatera"),
    (15, "Jambi", "Sumatera"),
    (16, "Sumatera Selatan", "Sumatera"),
    (17, "Bengkulu", "Sumatera"),
    (18, "Lampung", "Sumatera"),
    (19, "Kep. Bangka Belitung", "Sumatera"),
    (21, "Kep. Riau", "Sumatera"),
    (31, "DKI Jakarta", "Jawa"),
    (32, "Jawa Barat", "Jawa"),
    (33, "Jawa Tengah", "Jawa"),
    (34, "DI Yogyakarta", "Jawa"),
    (35, "Jawa Timur", "Jawa"),
    (36, "Banten", "Jawa"),
    (51, "Bali", "Bali-Nusra"),
    (52, "Nusa Tenggara Barat", "Bali-Nusra"),
    (53, "Nusa Tenggara Timur", "Bali-Nusra"),
    (61, "Kalimantan Barat", "Kalimantan"),
    (62, "Kalimantan Tengah", "Kalimantan"),
    (63, "Kalimantan Selatan", "Kalimantan"),
    (64, "Kalimantan Timur", "Kalimantan"),
    (65, "Kalimantan Utara", "Kalimantan"),
    (71, "Sulawesi Utara", "Sulawesi"),
    (72, "Sulawesi Tengah", "Sulawesi"),
    (73, "Sulawesi Selatan", "Sulawesi"),
    (74, "Sulawesi Tenggara", "Sulawesi"),
    (75, "Gorontalo", "Sulawesi"),
    (76, "Sulawesi Barat", "Sulawesi"),
    (81, "Maluku", "Maluku-Papua"),
    (82, "Maluku Utara", "Maluku-Papua"),
    (91, "Papua Barat", "Maluku-Papua"),
    (94, "Papua", "Maluku-Papua"),
]

# Pemekaran 2022: tidak disimpan di versi data (34 provinsi), hanya dipakai untuk
# rincian 38 provinsi di simulasi, beranda, dan jelajah data (lihat datapanel/papua.py).
PROVINSI_PEMEKARAN = [
    (92, "Papua Barat Daya", "Maluku-Papua", 91),
    (95, "Papua Selatan", "Maluku-Papua", 94),
    (96, "Papua Tengah", "Maluku-Papua", 94),
    (97, "Papua Pegunungan", "Maluku-Papua", 94),
]

KODE_PROVINSI = [p[0] for p in PROVINSI]
KODE_PROVINSI_38 = sorted(KODE_PROVINSI + [p[0] for p in PROVINSI_PEMEKARAN])
NAMA_PROVINSI = {p[0]: p[1] for p in PROVINSI} | {p[0]: p[1] for p in PROVINSI_PEMEKARAN}
PULAU_PROVINSI = {p[0]: p[2] for p in PROVINSI} | {p[0]: p[2] for p in PROVINSI_PEMEKARAN}
INDUK_PEMEKARAN = {p[0]: p[3] for p in PROVINSI_PEMEKARAN}
PULAU = ["Sumatera", "Jawa", "Bali-Nusra", "Kalimantan", "Sulawesi", "Maluku-Papua"]

# (kode, nama, kelompok model sektoral 13_Sectoral.do)
SEKTOR = [
    ("A", "Pertanian, Kehutanan, dan Perikanan", "primer"),
    ("B", "Pertambangan dan Penggalian", "primer"),
    ("C", "Industri Pengolahan", "sekunder"),
    ("D", "Pengadaan Listrik dan Gas", "sekunder"),
    ("E", "Pengadaan Air dan Pengelolaan Sampah", "sekunder"),
    ("F", "Konstruksi", "sekunder"),
    ("G", "Perdagangan Besar dan Eceran", "tlain"),
    ("H", "Transportasi dan Pergudangan", "tva"),
    ("I", "Akomodasi dan Makan Minum", "tlain"),
    ("J", "Informasi dan Komunikasi", "tva"),
    ("K", "Jasa Keuangan dan Asuransi", "tva"),
    ("L", "Real Estat", "tlain"),
    ("MN", "Jasa Perusahaan", "tva"),
    ("O", "Administrasi Pemerintahan", "tlain"),
    ("P", "Jasa Pendidikan", "tlain"),
    ("Q", "Jasa Kesehatan", "tlain"),
    ("RSTU", "Jasa Lainnya", "tlain"),
]
KODE_SEKTOR = [s[0] for s in SEKTOR]
NAMA_SEKTOR = {s[0]: s[1] for s in SEKTOR}
KELOMPOK_SEKTOR = {s[0]: s[2] for s in SEKTOR}

KELOMPOK = [
    ("primer", "Primer (A, B)"),
    ("sekunder", "Sekunder (C-F)"),
    ("tva", "Tersier bernilai tambah (H, J, K, MN)"),
    ("tlain", "Tersier lainnya (basis)"),
]
NAMA_KELOMPOK = dict(KELOMPOK)

PEMEKARAN_PAPUA = {
    "papua selatan": 94,
    "papua tengah": 94,
    "papua pegunungan": 94,
    "papua barat daya": 91,
}
KODE_PEMEKARAN = {
    "papua selatan": 95,
    "papua tengah": 96,
    "papua pegunungan": 97,
    "papua barat daya": 92,
}


def _kunci(teks):
    teks = unicodedata.normalize("NFKD", str(teks)).encode("ascii", "ignore").decode()
    teks = teks.lower().replace("&", " dan ")
    teks = re.sub(r"\bprov(insi)?\b\.?", " ", teks)
    teks = re.sub(r"[^a-z0-9]+", " ", teks)
    return re.sub(r"\s+", " ", teks).strip()


_ALIAS = {
    "sumatra utara": 12,
    "sumut": 12,
    "sumatra barat": 13,
    "sumbar": 13,
    "sumatra selatan": 16,
    "sumsel": 16,
    "bangka belitung": 19,
    "kep bangka belitung": 19,
    "kepulauan bangka belitung": 19,
    "babel": 19,
    "kep riau": 21,
    "kepulauan riau": 21,
    "kepri": 21,
    "dki": 31,
    "jakarta": 31,
    "jakarta raya": 31,
    "dki jakarta": 31,
    "jakartaraya": 31,
    "di yogyakarta": 34,
    "d i yogyakarta": 34,
    "yogyakarta": 34,
    "diy": 34,
    "daerah istimewa yogyakarta": 34,
    "jabar": 32,
    "jateng": 33,
    "jatim": 35,
    "ntb": 52,
    "ntt": 53,
    "kalbar": 61,
    "kalteng": 62,
    "kalsel": 63,
    "kaltim": 64,
    "kaltara": 65,
    "sulut": 71,
    "sulteng": 72,
    "sulsel": 73,
    "sultra": 74,
    "sulbar": 76,
    "malut": 82,
    "pabar": 91,
}
for _kode, _nama, _ in PROVINSI:
    _ALIAS[_kunci(_nama)] = _kode
    _ALIAS[_kunci(_nama).replace(" ", "")] = _kode


def kode_pemekaran(nama):
    """Kode BPS provinsi pemekaran Papua (92, 95-97) dari nama, atau None."""
    return None if nama is None else KODE_PEMEKARAN.get(_kunci(nama))


def cari_kode_provinsi(nama):
    """Kembalikan (kode, catatan). Kode None bila nama tidak dikenali."""
    if nama is None:
        return None, None
    k = _kunci(nama)
    if k in PEMEKARAN_PAPUA:
        induk = PEMEKARAN_PAPUA[k]
        return induk, f"'{nama}' dilipat ke {NAMA_PROVINSI[induk]}"
    if k in _ALIAS:
        return _ALIAS[k], None
    if k.replace(" ", "") in _ALIAS:
        return _ALIAS[k.replace(" ", "")], None
    return None, None
