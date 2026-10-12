# Pengaturan bersama: jalur, daftar provinsi, baca/tulis CSV.
# Diimpor skrip 02–07. Bukan pipeline — tidak dijalankan sendiri.

from pathlib import Path
import csv
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]  # project root (02 Code/TFP/panel_provinsi)
RAW = ROOT / "01 Data" / "TFP" / "processed" / "panel_raw"
OUT = ROOT / "01 Data" / "TFP" / "processed" / "panel"
INP = ROOT / "01 Data" / "00 sumber"
BKPM_PROC = ROOT / "01 Data" / "BKPM" / "processed"
TFP_PROC = ROOT / "01 Data" / "TFP" / "processed"
TABEL = INP / "tabel"
OUT.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)

YEARS = list(range(2017, 2026))
NEW_PAPUA = {92, 95, 96, 97}
RAIL_PROV = {12, 16, 18, 31, 32, 33, 34, 35, 36, 73}
JAWA = {32, 33, 34, 35, 36}

# (kode_induk, kode_bps, nama, pulau, tahun_berdiri)
PROV = [
    (11, 11, "Aceh", "Sumatera", 2017),
    (12, 12, "Sumatera Utara", "Sumatera", 2017),
    (13, 13, "Sumatera Barat", "Sumatera", 2017),
    (14, 14, "Riau", "Sumatera", 2017),
    (15, 15, "Jambi", "Sumatera", 2017),
    (16, 16, "Sumatera Selatan", "Sumatera", 2017),
    (17, 17, "Bengkulu", "Sumatera", 2017),
    (18, 18, "Lampung", "Sumatera", 2017),
    (19, 19, "Kep. Bangka Belitung", "Sumatera", 2017),
    (21, 21, "Kep. Riau", "Sumatera", 2017),
    (31, 31, "DKI Jakarta", "Jawa", 2017),
    (32, 32, "Jawa Barat", "Jawa", 2017),
    (33, 33, "Jawa Tengah", "Jawa", 2017),
    (34, 34, "DI Yogyakarta", "Jawa", 2017),
    (35, 35, "Jawa Timur", "Jawa", 2017),
    (36, 36, "Banten", "Jawa", 2017),
    (51, 51, "Bali", "Bali-Nusra", 2017),
    (52, 52, "Nusa Tenggara Barat", "Bali-Nusra", 2017),
    (53, 53, "Nusa Tenggara Timur", "Bali-Nusra", 2017),
    (61, 61, "Kalimantan Barat", "Kalimantan", 2017),
    (62, 62, "Kalimantan Tengah", "Kalimantan", 2017),
    (63, 63, "Kalimantan Selatan", "Kalimantan", 2017),
    (64, 64, "Kalimantan Timur", "Kalimantan", 2017),
    (65, 65, "Kalimantan Utara", "Kalimantan", 2017),
    (71, 71, "Sulawesi Utara", "Sulawesi", 2017),
    (72, 72, "Sulawesi Tengah", "Sulawesi", 2017),
    (73, 73, "Sulawesi Selatan", "Sulawesi", 2017),
    (74, 74, "Sulawesi Tenggara", "Sulawesi", 2017),
    (75, 75, "Gorontalo", "Sulawesi", 2017),
    (76, 76, "Sulawesi Barat", "Sulawesi", 2017),
    (81, 81, "Maluku", "Maluku-Papua", 2017),
    (82, 82, "Maluku Utara", "Maluku-Papua", 2017),
    (91, 91, "Papua Barat", "Maluku-Papua", 2017),
    (91, 92, "Papua Barat Daya", "Maluku-Papua", 2023),
    (94, 94, "Papua", "Maluku-Papua", 2017),
    (94, 95, "Papua Selatan", "Maluku-Papua", 2023),
    (94, 96, "Papua Tengah", "Maluku-Papua", 2023),
    (94, 97, "Papua Pegunungan", "Maluku-Papua", 2023),
]
META = {r[1]: r for r in PROV}

SEKTOR = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "MN", "O", "P", "Q", "RSTU"]
GROUPS = {91: [91, 92], 94: [94, 95, 96, 97]}

PANEL_FIELDS = [
    "code_prov", "code_prov_induk", "prov_nama", "pulau", "year",
    "provinsi_berdiri", "status_observasi",
    "pma_miliar", "pmdn_miliar", "pma_pmdn_miliar", "pmtb_miliar",
    "upah_agregat", "ump",
    "panjang_jalan_km", "jalan_mantap_pct",
    "pax_udara", "pax_ka", "pax_laut", "pax_bus",
    "cargo_udara_juta_ton", "cargo_laut_juta_ton", "cargo_ka_juta_ton", "cargo_total_juta_ton",
    "indeks_konektivitas",
    "pad_miliar", "pendapatan_apbd_miliar", "belanja_apbd_miliar", "rasio_pad", "serapan_belanja",
    "idi", "tindak_pidana", "tindak_pidana_per_100rb", "ikg",
    "iklh", "indeks_hijau_iktl", "indeks_biru_ika", "indeks_institusi",
    "h_adhb", "pdrb_miliar",
]

NOTES = []


def note(code, year, var, method, detail):
    NOTES.append({
        "code_prov": code, "year": year, "variabel": var,
        "metode": method, "keterangan": detail,
    })


def num(x):
    if x is None:
        return None
    s = str(x).strip().replace("\xa0", " ")
    if s in ("", ".", "-", "NA", "na", "None", "null"):
        return None
    s = s.replace(" ", "")
    if "," in s and "." in s:
        s = s.replace(".", "").replace(",", ".") if s.rfind(",") > s.rfind(".") else s.replace(",", "")
    elif "," in s:
        a, b = s.split(",", 1)
        s = s.replace(",", ".") if len(b) <= 3 and a.replace("-", "").isdigit() else s.replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def exists(code, year):
    return year >= META[code][4]


def read_csv(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: ("" if r.get(k) is None else r.get(k)) for k in fieldnames})


def load_nested(path):
    """CSV code_prov, year, nilai → {code: {year: float}}"""
    out = {}
    for r in read_csv(path):
        code, y = int(r["code_prov"]), int(r["year"])
        out.setdefault(code, {})[y] = num(r["nilai"])
    return out


def load_code_value(path):
    return {int(r["code_prov"]): num(r["nilai"]) for r in read_csv(path)}


def load_nasional():
    out = {}
    for r in read_csv(TABEL / "nasional.csv"):
        out.setdefault(r["series"], {})[int(r["year"])] = num(r["nilai"])
    return out


def lookup(tbl, code, year):
    return tbl.get(code, {}).get(year)


def norm_name(s):
    s = str(s).lower().strip()
    s = s.replace(".", " ").replace(",", " ")
    s = re.sub(r"\s+", " ", s)
    s = s.replace("provinsi ", "").replace("nanggroe aceh darussalam", "aceh")
    s = s.replace("nangroe aceh darussalam", "aceh").replace("d i yogyakarta", "di yogyakarta")
    s = s.replace("daerah istimewa yogyakarta", "di yogyakarta")
    s = s.replace("kepulauan ", "kep. ").replace("kep ", "kep. ")
    s = s.replace("sumatra ", "sumatera ")
    return s.strip()


NAME2CODE = {norm_name(nama): code for _, code, nama, _, _ in PROV}
NAME2CODE.update({
    "nad": 11, "aceh": 11, "sumut": 12, "sumbar": 13, "sumsel": 16,
    "babel": 19, "kep. bangka belitung": 19, "kep. riau": 21, "kepri": 21,
    "jakarta": 31, "dki jakarta": 31, "jabar": 32, "jateng": 33,
    "diy": 34, "di yogyakarta": 34, "d.i. yogyakarta": 34, "jatim": 35,
    "ntb": 52, "ntt": 53, "kalbar": 61, "kalteng": 62, "kalsel": 63,
    "kaltim": 64, "kaltara": 65, "sulut": 71, "sulteng": 72, "sulsel": 73,
    "sultra": 74, "sulbar": 76, "malut": 82, "papua barat": 91,
    "papua barat daya": 92, "papua": 94, "papua selatan": 95,
    "papua tengah": 96, "papua pegunungan": 97,
})


def code_of(nama, kode=None):
    if kode not in (None, "", "xxx"):
        k = int(float(str(kode).replace(",", "."))) if str(kode).replace(".", "").isdigit() else None
        if k in META and k not in (91, 92, 93, 94, 95, 96, 97):
            return k
    n = norm_name(nama)
    if n in NAME2CODE:
        return NAME2CODE[n]
    for alias, c in NAME2CODE.items():
        if alias in n or n in alias:
            return c
    return None
