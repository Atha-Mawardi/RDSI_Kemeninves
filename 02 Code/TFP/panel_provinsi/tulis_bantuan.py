# Bantuan tulis xlsx (kolom baru, gabung pemekaran). Dipakai 06 dan 07.

from copy import copy
from pengaturan import HERE, ROOT, INP, RAW, OUT, GROUPS, SEKTOR, num, read_csv

PANEL = OUT / "panel_provinsi_tahun_2017_2025.csv"
DJPK = RAW / "djpk" / "apbd_panel.csv"
XLSX_INP = ROOT / "01 Data" / "TFP" / "processed" / "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
XLSX_ROOT = XLSX_INP  # satu lokasi saja setelah reorg

NEW_COLS = [
    ("Upah_Agregat", "Upah sebulan tertimbang 17 sektor; 2025 diproyeksi UMP", "Rp", "Rata-rata tertimbang TK"),
    ("panjang_jalan_km", "Panjang jalan nasional", "km", "Dijumlahkan"),
    ("jalan_mantap_pct", "Persentase jalan nasional mantap", "%", "Rata-rata tertimbang PDRB"),
    ("pax_udara", "Penumpang udara (alokasi)", "orang", "Dijumlahkan"),
    ("pax_ka", "Penumpang KA", "orang", "Dijumlahkan"),
    ("pax_laut", "Penumpang laut (alokasi)", "orang", "Dijumlahkan"),
    ("pax_bus", "Penumpang bus (alokasi)", "orang", "Dijumlahkan"),
    ("cargo_udara_juta_ton", "Kargo udara", "juta ton", "Dijumlahkan"),
    ("cargo_laut_juta_ton", "Kargo laut", "juta ton", "Dijumlahkan"),
    ("cargo_ka_juta_ton", "Kargo KA", "juta ton", "Dijumlahkan"),
    ("cargo_total_juta_ton", "Kargo udara+laut+KA", "juta ton", "Dijumlahkan"),
    ("indeks_konektivitas", "PC1 PCA konektivitas, 0-100", "indeks", "Rata-rata tertimbang PDRB"),
    ("pad_miliar", "PAD realisasi DJPK", "miliar Rp", "Dijumlahkan"),
    ("pendapatan_apbd_miliar", "Pendapatan daerah DJPK", "miliar Rp", "Dijumlahkan"),
    ("belanja_apbd_miliar", "Belanja daerah DJPK", "miliar Rp", "Dijumlahkan"),
    ("rasio_pad", "PAD / pendapatan daerah", "rasio", "Dihitung ulang"),
    ("serapan_belanja", "Realisasi/anggaran belanja", "%", "Rata-rata tertimbang PDRB"),
    ("idi", "Indeks Demokrasi Indonesia", "0-100", "Rata-rata tertimbang PDRB"),
    ("tindak_pidana", "Perkiraan jumlah tindak pidana", "kasus", "Dijumlahkan"),
    ("tindak_pidana_per_100rb", "Tindak pidana per 100 ribu", "rasio", "Dihitung ulang"),
    ("ikg", "Indeks Ketimpangan Gender", "0-1", "Rata-rata tertimbang PDRB"),
    ("iklh", "Indeks Kualitas Lingkungan Hidup", "0-100", "Rata-rata tertimbang PDRB"),
    ("indeks_hijau_iktl", "Indeks hijau (tutupan lahan)", "0-100", "Rata-rata tertimbang PDRB"),
    ("indeks_biru_ika", "Indeks biru (kualitas air)", "0-100", "Rata-rata tertimbang PDRB"),
    ("indeks_institusi", "PC1 PCA institusi, 0-100", "indeks", "Rata-rata tertimbang PDRB"),
]

SUM_KEYS = [
    "panjang_jalan_km", "pax_udara", "pax_ka", "pax_laut", "pax_bus",
    "cargo_udara_juta_ton", "cargo_laut_juta_ton", "cargo_ka_juta_ton", "cargo_total_juta_ton",
    "pad_miliar", "pendapatan_apbd_miliar", "belanja_apbd_miliar", "tindak_pidana",
]
MEAN_KEYS = [
    "upah_agregat", "jalan_mantap_pct", "rasio_pad", "serapan_belanja", "idi",
    "ikg", "iklh", "indeks_hijau_iktl", "indeks_biru_ika",
    "indeks_konektivitas", "indeks_institusi", "tindak_pidana_per_100rb",
]


def load_panel():
    out = {}
    for r in read_csv(PANEL):
        out[(int(r["code_prov"]), int(r["year"]))] = r
    return out


def wmean(rows, key, wkey="pdrb_miliar"):
    nume = den = 0.0
    for r in rows:
        v, w = num(r.get(key)), num(r.get(wkey))
        if v is None:
            continue
        ww = w if w and w > 0 else 1.0
        nume += v * ww
        den += ww
    return None if den == 0 else nume / den


def wsum(rows, key):
    vals = [num(r.get(key)) for r in rows]
    vals = [v for v in vals if v is not None]
    return None if not vals else sum(vals)


def bundle(panel, code, year):
    keys = GROUPS.get(code) if year >= 2023 and code in GROUPS else [code]
    rows = [panel[c, year] for c in keys
            if (c, year) in panel and panel[c, year].get("status_observasi") == "berdiri"]
    if not rows:
        return {}
    out = {k: wsum(rows, k) for k in SUM_KEYS}
    out.update({k: wmean(rows, k) for k in MEAN_KEYS})
    if out.get("pendapatan_apbd_miliar") and out.get("pad_miliar") is not None:
        out["rasio_pad"] = out["pad_miliar"] / out["pendapatan_apbd_miliar"]
    return out


def style_like(src, dest):
    if src.has_style:
        dest.font = copy(src.font)
        dest.border = copy(src.border)
        dest.fill = copy(src.fill)
        dest.number_format = src.number_format
        dest.protection = copy(src.protection)
        dest.alignment = copy(src.alignment)


def upah_agregat_dari_sheet(ws, row, col):
    wsum = tw = 0.0
    for s in SEKTOR:
        w = ws.cell(row, col[f"{s}_RataUpah"]).value
        t = ws.cell(row, col[f"{s}_TenagaKerja"]).value if f"{s}_TenagaKerja" in col else None
        if w is not None and t is not None and float(t) > 0:
            wsum += float(w) * float(t)
            tw += float(t)
    return (wsum / tw) if tw > 0 else None
