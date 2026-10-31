"""
Rincian 38 provinsi: memecah Papua Barat (91) dan Papua (94) versi 34 provinsi
menjadi enam provinsi hasil pemekaran 2022.

Versi data dan estimasi elastisitas tetap 34 provinsi, sebab provinsi baru hanya
punya data sejak 2023. Untuk simulasi, beranda, dan jelajah data, tiap variabel aditif induk
dibagi menurut pangsa anggota di keluarganya; indikator rata-rata (lama sekolah, indeks) disalin:

    X_anggota,t = X_induk34,t * s_anggota,t(kunci X)

Pangsa s dihitung dari data rincian (baris provinsi baru). Tahun sebelum data
rincian pertama memakai pangsa tahun pertama (backcast); tahun sesudah data
terakhir memakai pangsa terakhir. Total induk dan nasional tidak berubah; anggota
mewarisi dinamika historis induknya dan berbeda dalam level, kecuali pada
tahun-tahun yang pangsanya teramati.

Pangsa disimpan sebagai JSON di VersiData.pangsa_pemekaran:
    {"kunci": {variabel: {kode: {tahun: pangsa}}}, "sumber": str, "catatan": [str]}
"""

import numpy as np
import pandas as pd

from . import variabel as V
from .referensi import INDUK_PEMEKARAN, KODE_SEKTOR, NAMA_PROVINSI

KELUARGA = {91: (91, 92), 94: (94, 95, 96, 97)}
KODE_ANAK = tuple(INDUK_PEMEKARAN)
PENGELUARAN = ["PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB"]

# 23 sektor BKPM -> 17 lapangan usaha; dipakai hanya untuk pangsa antaranggota keluarga
BKPM23 = {
    "A": (1, 2, 3), "B": (4,), "C": tuple(range(5, 17)), "D": (17,), "E": (17,), "F": (18,),
    "G": (19,), "H": (21,), "I": (20,), "J": (21,), "K": (23,), "L": (22,), "MN": (23,),
    "O": (23,), "P": (23,), "Q": (23,), "RSTU": (23,),
}


def ada_pangsa(pangsa):
    return bool((pangsa or {}).get("kunci"))


# ------------------------------------------------------------------ hitung
def koreksi_geser(r, catatan):
    """Kembalikan kolom PDRB/PMTB sisi pengeluaran yang tergeser antarbaris saudara.

    Total PDRB_ADHK tiap provinsi harus sama dengan jumlah nilai tambah 17 sektor
    (yang berlabel benar). Bila total satu baris cocok dengan jumlah sektor baris
    lain di enam provinsi Papua, keempat kolom pengeluaran dipindahkan ke baris
    yang benar. Pergeseran bisa melintasi keluarga (berkas BKPM 2024-2025).
    """
    va = [f"VA_{s}" for s in KODE_SEKTOR]
    if "PDRB_ADHK" not in r or not all(c in r for c in va):
        return r
    sektor = r[va].sum(axis=1, min_count=len(va))
    kol = [c for c in PENGELUARAN if c in r]
    semua = [k for kel in KELUARGA.values() for k in kel]
    for t in sorted(set(r.index.get_level_values("tahun"))):
        idx = [(k, t) for k in semua]
        if any(i not in r.index for i in idx):
            continue
        tot = r.loc[idx, "PDRB_ADHK"].to_numpy(float)
        sk = sektor.loc[idx].to_numpy(float)
        if np.isnan(tot).any() or np.isnan(sk).any() or (sk <= 0).any():
            continue
        galat = np.abs(tot[:, None] / sk[None, :] - 1)
        tujuan = galat.argmin(axis=1)
        urut = np.sort(galat, axis=1)
        jelas = (urut[:, 0] < 0.02) & (urut[:, 1] > 3 * urut[:, 0])
        if (tujuan == np.arange(len(semua))).all() and jelas.all():
            continue
        if jelas.all() and len(set(tujuan)) == len(semua):
            lama = r.loc[idx, kol].to_numpy(float)
            baru = np.empty_like(lama)
            baru[tujuan] = lama
            r.loc[idx, kol] = baru
            pindah = [f"baris {NAMA_PROVINSI[semua[i]]} milik {NAMA_PROVINSI[semua[j]]}"
                      for i, j in enumerate(tujuan) if i != j]
            catatan.append(f"{t}: kolom PDRB/PMTB sisi pengeluaran provinsi Papua tergeser dan dikembalikan "
                           f"berdasarkan jumlah nilai tambah sektoral ({'; '.join(pindah)}).")
        else:
            r.loc[idx, kol] = np.nan
            catatan.append(f"{t}: total PDRB provinsi Papua tidak cocok dengan jumlah sektor; "
                           "pangsa PDRB/PMTB pengeluaran tahun itu tidak dipakai.")
    return r


def hitung_pangsa(rincian, sumber=""):
    """Pangsa anggota keluarga per variabel-tahun dari panel rincian (indeks kode38, tahun).

    Satu tahun dipakai bila semua anggota keluarga terisi. Untuk PMA/PMDN, sel
    kosong anggota dianggap nol asalkan ada anggota baru yang terisi.
    """
    r = rincian.astype(float).copy()
    catatan = []
    r = koreksi_geser(r, catatan)
    va = [f"VA_{s}" for s in KODE_SEKTOR]
    if all(c in r for c in va):
        r["_PDRB_SEKTORAL"] = r[va].sum(axis=1, min_count=len(va))
    tahun = sorted(set(r.index.get_level_values("tahun")))
    kunci = {}
    for kol in r.columns:
        investasi = kol.startswith(("PMA", "PMDN"))
        nilai = {}
        for kel in KELUARGA.values():
            for t in tahun:
                v = np.array([r[kol].get((k, t), np.nan) for k in kel], float)
                if investasi:
                    if np.isnan(v[1:]).all():
                        continue
                    v = np.clip(np.nan_to_num(v), 0, None)
                elif np.isnan(v).any() or (v < 0).any():
                    continue
                if v.sum() <= 0:
                    continue
                for k, x in zip(kel, v / v.sum()):
                    nilai.setdefault(str(k), {})[str(t)] = round(float(x), 6)
        if nilai:
            kunci[kol] = nilai
    sektoral = kunci.pop("_PDRB_SEKTORAL", None)
    if sektoral:
        gabung = kunci.get("PDRB_ADHK", {})
        for k, per_tahun in sektoral.items():
            gabung.setdefault(k, {}).update(per_tahun)
        kunci["PDRB_ADHK"] = gabung
    return {"kunci": kunci, "sumber": sumber, "catatan": catatan}


def gabung_pangsa(lama, baru):
    """Pangsa `baru` menimpa `lama` per variabel-anggota-tahun."""
    if not ada_pangsa(lama):
        return baru
    if not ada_pangsa(baru):
        return lama
    kunci = {v: {k: dict(t) for k, t in d.items()} for v, d in lama["kunci"].items()}
    for v, d in baru["kunci"].items():
        for k, t in d.items():
            kunci.setdefault(v, {}).setdefault(k, {}).update(t)
    return {"kunci": kunci,
            "sumber": "; ".join(s for s in (lama.get("sumber"), baru.get("sumber")) if s),
            "catatan": (lama.get("catatan") or []) + (baru.get("catatan") or [])}


# ------------------------------------------------------------------ pecah
def _calon(kol):
    if kol.startswith("TK_"):
        c = [kol, "PENDUDUK"]
    elif kol.startswith("PMA_"):
        c = [kol, "PMA", "PMDN"]
    elif kol.startswith("PMDN_"):
        c = [kol, "PMDN", "PMA"]
    elif kol in ("PMA", "PMDN"):
        c = [kol, "PMDN" if kol == "PMA" else "PMA"]
    elif kol.startswith("VA_"):
        c = [kol]
    elif kol in ("PAD", "APBD_PENDAPATAN", "APBD_BELANJA"):
        c = [kol, "APBD_BELANJA", "APBD_PENDAPATAN"]
    elif kol.startswith("PMTB"):
        c = [kol, "PMTB_ADHB" if kol.endswith("ADHK") else "PMTB_ADHK"]
    else:
        c = [kol]
    return c + ["PDRB_ADHB", "PDRB_ADHK"]


def kunci_untuk(pangsa, kol, kel):
    kunci = pangsa["kunci"]
    return next((k for k in _calon(kol) if k in kunci and all(str(a) in kunci[k] for a in kel)), None)


def _deret(per_tahun, tahun):
    s = pd.Series({int(t): v for t, v in per_tahun.items()}, dtype=float)
    penuh = s.reindex(sorted(set(s.index) | set(tahun))).ffill().bfill()
    return penuh.reindex(tahun).to_numpy(float)


def pecah(df, pangsa):
    """Panel 34 provinsi (indeks kode, tahun) -> 38 provinsi. Total per tahun tetap."""
    if not ada_pangsa(pangsa):
        raise ValueError("Versi data ini belum punya pangsa pemekaran Papua.")
    kode = df.index.get_level_values("kode")
    bagian = [df[~kode.isin(list(KELUARGA))]]
    for induk, kel in KELUARGA.items():
        if induk not in set(kode):
            continue
        X = df.xs(induk, level="kode")
        tahun = list(X.index)
        S = {a: np.ones((len(tahun), X.shape[1])) / len(kel) for a in kel}
        for j, kol in enumerate(X.columns):
            if kol in V.PER_KODE and V.PER_KODE[kol].agregasi != "jumlah":
                for a in kel:
                    S[a][:, j] = 1.0
                continue
            k = kunci_untuk(pangsa, kol, kel)
            if k is None:
                continue
            ser = np.array([_deret(pangsa["kunci"][k][str(a)], tahun) for a in kel])
            ser = ser / ser.sum(axis=0, keepdims=True)
            for i, a in enumerate(kel):
                S[a][:, j] = ser[i]
        for a in kel:
            Y = X * S[a]
            Y.index = pd.MultiIndex.from_product([[a], tahun], names=["kode", "tahun"])
            bagian.append(Y)
    return pd.concat(bagian).sort_index()


def tahun_teramati(pangsa, kol="PDRB_ADHK"):
    """Tahun yang pangsanya teramati untuk satu variabel (gabungan semua keluarga)."""
    d = (pangsa or {}).get("kunci", {}).get(kol, {})
    return sorted({int(t) for per in d.values() for t in per})


def ringkasan(pangsa, tahun=None):
    """Baris per anggota keluarga: pangsa PDRB, PMTB, PMA+PMDN, belanja APBD, penduduk."""
    if not ada_pangsa(pangsa):
        return {}
    kol = [("PDRB_ADHK", "PDRB riil"), ("PMTB_ADHK", "PMTB riil"), ("PMA", "PMA"), ("PMDN", "PMDN"),
           ("APBD_BELANJA", "Belanja APBD"), ("PENDUDUK", "Penduduk")]
    baris = []
    for induk, kel in KELUARGA.items():
        for a in kel:
            r = {"kode": a, "nama": NAMA_PROVINSI[a], "induk": NAMA_PROVINSI[induk] if a != induk else "",
                 "nilai": []}
            for k, _ in kol:
                d = pangsa["kunci"].get(k, {}).get(str(a), {})
                if not d:
                    r["nilai"].append((None, None))
                    continue
                th = str(tahun) if tahun and str(tahun) in d else max(d, key=int)
                r["nilai"].append((d[th], int(th)))
            baris.append(r)
    return {"kolom": [n for _, n in kol], "baris": baris,
            "tahun": {k: tahun_teramati(pangsa, k) for k, _ in kol}}


# ------------------------------------------------------- sumber berkas tim
BERKAS_BKPM = "01 Data/BKPM/processed/Dataset Provinsi(Database (62026)).csv"
BERKAS_PANEL = "01 Data/TFP/processed/panel_provinsi_tahun_2017_2025.csv"


def pangsa_dari_berkas_tim(repo):
    """Pangsa dari berkas kajian di repositori; {} bila berkas BKPM tidak ada."""
    bkpm, panel = repo / BERKAS_BKPM, repo / BERKAS_PANEL
    if not bkpm.exists():
        return {}
    rincian = rincian_dari_berkas(bkpm, panel if panel.exists() else None)
    sumber = BERKAS_BKPM + (f"; PAD/APBD: {BERKAS_PANEL}" if panel.exists() else "")
    return hitung_pangsa(rincian, sumber)


def rincian_dari_berkas(path_bkpm, path_panel=None):
    """Panel rincian 38 provinsi (hanya keluarga Papua) dari berkas kajian.

    path_bkpm  : 01 Data/BKPM/processed/Dataset Provinsi(Database (62026)).csv
                 (Code_Prov2022, PDRB pengeluaran 1-9, sektor A..RSTU, PMA/PMDN 23 sektor, Inc_Prov)
    path_panel : 01 Data/TFP/processed/panel_provinsi_tahun_2017_2025.csv (PAD dan APBD DJPK)
    Penduduk = PDRB ADHB (jumlah sektor) / PDRB per kapita, dipakai sebagai pangsa tenaga kerja.
    """
    d = pd.read_csv(path_bkpm, na_values=[".", ""], decimal=",", low_memory=False)
    d = d[d["Code_Prov2022"].isin([k for kel in KELUARGA.values() for k in kel])]
    out = pd.DataFrame({"kode": d["Code_Prov2022"].astype(int), "tahun": d["Year"].astype(int)})
    peta = {"PDRB_ADHK": "9_ADHK", "PDRB_ADHB": "9_ADHB", "PMTB_ADHK": "4_ADHK", "PMTB_ADHB": "4_ADHB"}
    for k, c in peta.items():
        if c in d:
            out[k] = pd.to_numeric(d[c], errors="coerce")
    for k, c in (("PMA", "PMA_1"), ("PMDN", "PMDN_1")):
        if c in d:
            out[k] = pd.to_numeric(d[c], errors="coerce") / 1000
    for s in KODE_SEKTOR:
        if f"{s}_ADHK" in d:
            out[f"VA_{s}"] = pd.to_numeric(d[f"{s}_ADHK"], errors="coerce")
        if f"{s}_TenagaKerja" in d:
            out[f"TK_{s}"] = pd.to_numeric(d[f"{s}_TenagaKerja"], errors="coerce")
        for jenis in ("PMA", "PMDN"):
            cols = [f"{n}_{jenis}" for n in BKPM23[s] if f"{n}_{jenis}" in d]
            if cols:
                blok = d[cols].apply(pd.to_numeric, errors="coerce")
                out[f"{jenis}_{s}"] = blok.sum(axis=1, min_count=1) / 1000
    adhb = [f"{s}_ADHB" for s in KODE_SEKTOR if f"{s}_ADHB" in d]
    if len(adhb) == len(KODE_SEKTOR) and "Inc_Prov" in d:
        tot = d[adhb].apply(pd.to_numeric, errors="coerce").sum(axis=1, min_count=len(adhb))
        out["PENDUDUK"] = tot * 1e6 / pd.to_numeric(d["Inc_Prov"], errors="coerce")
        # ADHB sektoral yang tidak sejalan dengan ADHK (deflator implisit jauh dari median
        # tahun itu; Papua 2023 di berkas BKPM) membuat penduduk turunan tidak dapat dipakai
        va = out[[f"VA_{s}" for s in KODE_SEKTOR if f"VA_{s}" in out]].sum(axis=1, min_count=1)
        dfl = tot / va
        median = dfl.groupby(out["tahun"]).transform("median")
        out.loc[(dfl / median - 1).abs() > 0.3, "PENDUDUK"] = np.nan
    out = out.set_index(["kode", "tahun"]).sort_index()
    if path_panel:
        p = pd.read_csv(path_panel)
        p = p[p["code_prov"].isin(out.index.get_level_values("kode").unique())]
        fis = pd.DataFrame({"kode": p["code_prov"].astype(int), "tahun": p["year"].astype(int),
                            "PAD": p.get("pad_miliar"), "APBD_PENDAPATAN": p.get("pendapatan_apbd_miliar"),
                            "APBD_BELANJA": p.get("belanja_apbd_miliar")}).set_index(["kode", "tahun"])
        out = out.join(fis, how="outer")
    return out
