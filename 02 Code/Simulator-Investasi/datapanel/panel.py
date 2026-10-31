"""Indikator turunan dan agregasi nasional dari panel kanonik."""

import numpy as np
import pandas as pd

from . import variabel as V
from .referensi import KELOMPOK_SEKTOR, KODE_SEKTOR, NAMA_PROVINSI, PULAU_PROVINSI


def tambah_turunan(df):
    df = df.copy()
    tk = [f"TK_{s}" for s in KODE_SEKTOR if f"TK_{s}" in df]
    if len(tk) == len(KODE_SEKTOR):
        df["TK_TOTAL"] = df[tk].sum(axis=1, min_count=len(tk))
    if {"PMA", "PMDN"} <= set(df.columns):
        df["PMAPMDN"] = df["PMA"].fillna(0) + df["PMDN"].fillna(0)
        df.loc[df["PMA"].isna() & df["PMDN"].isna(), "PMAPMDN"] = np.nan
        if "PMTB_ADHB" in df:
            df["RASIO_INV_PMTB"] = df["PMAPMDN"] / df["PMTB_ADHB"]
    per_prov = df.groupby(level="kode")
    if "PDRB_ADHK" in df:
        df["G_PDRB"] = per_prov["PDRB_ADHK"].pct_change(fill_method=None) * 100
    if "PMTB_ADHK" in df:
        df["G_PMTB"] = per_prov["PMTB_ADHK"].pct_change(fill_method=None) * 100
    if "TK_TOTAL" in df and "PDRB_ADHK" in df:
        df["PDRB_PER_TK"] = df["PDRB_ADHK"] * 1e3 / df["TK_TOTAL"]
    if {"PAD", "APBD_PENDAPATAN"} <= set(df.columns):
        df["RASIO_PAD"] = df["PAD"] / df["APBD_PENDAPATAN"]
    pax = ["PAX_UDARA", "PAX_KERETA", "PAX_KAPAL", "PAX_BUS"]
    if set(pax) <= set(df.columns):
        df["PAX_TOTAL"] = df[pax].sum(axis=1, min_count=len(pax))
    return df


def aditif(kode):
    """Variabel yang boleh dijumlahkan lintas provinsi (uang, orang, panjang, tonase)."""
    if kode in V.PER_KODE:
        return V.PER_KODE[kode].agregasi == "jumlah"
    return V.satuan(kode) in ("miliar Rp", "jiwa", "orang")


def nilai_nasional(df, tahun):
    """Angka nasional satu tahun per variabel: jumlah, laju dari jumlah, atau rasio dari jumlah.

    Jumlah hanya dihitung bila semua provinsi terisi, agar provinsi yang kosong tidak menurunkan total.
    """
    thn = set(df.index.get_level_values("tahun"))
    if tahun not in thn:
        return {}
    sub = df.xs(tahun, level="tahun")
    jml = lambda s, k: s[k].sum(min_count=len(s)) if k in s else np.nan
    out = {k: jml(sub, k) for k in df.columns if aditif(k)}
    out.update({k: sub[k].mean() if sub[k].notna().all() else np.nan
                for k in df.columns if k in V.PER_KODE and not aditif(k)})
    if tahun - 1 in thn:
        lalu = df.xs(tahun - 1, level="tahun")
        for g, k in (("G_PDRB", "PDRB_ADHK"), ("G_PMTB", "PMTB_ADHK")):
            out[g] = (jml(sub, k) / jml(lalu, k) - 1) * 100
    for r, a, b, f in (("RASIO_INV_PMTB", "PMAPMDN", "PMTB_ADHB", 1), ("PDRB_PER_TK", "PDRB_ADHK", "TK_TOTAL", 1e3),
                       ("RASIO_PAD", "PAD", "APBD_PENDAPATAN", 1)):
        out[r] = jml(sub, a) * f / jml(sub, b)
    return {k: (None if pd.isna(v) or np.isinf(v) else float(v)) for k, v in out.items()}


def seri_nasional(df):
    """Jumlah 34 provinsi per tahun untuk variabel aditif, ditambah laju riil."""
    kol = [c for c in ("PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB", "PMA", "PMDN",
                       "PMAPMDN", "TK_TOTAL", "PAD", "APBD_BELANJA") if c in df]
    nas = df[kol].groupby(level="tahun").sum(min_count=1)
    if "PDRB_ADHK" in nas:
        nas["G_PDRB"] = nas["PDRB_ADHK"].pct_change(fill_method=None) * 100
    if "PMTB_ADHK" in nas:
        nas["G_PMTB"] = nas["PMTB_ADHK"].pct_change(fill_method=None) * 100
    return nas


def historis_lima_tahun(df, akhir, sasaran, n=5):
    """Indikator historis per provinsi untuk n tahun laju yang berakhir di `akhir`.

    df harus sudah melalui tambah_turunan. Kembalikan {indikator: {kode: nilai}}:
      g, pmtb : laju majemuk PDRB / PMTB riil akhir-n .. akhir (%/thn)
      inv     : rata-rata realisasi PMA+PMDN akhir-n+1 .. akhir (triliun Rp/thn)
      peluang : bagian tahun dengan laju PDRB riil >= sasaran
    """
    awal = akhir - n
    th = list(range(awal + 1, akhir + 1))

    def bersih(s):
        return {str(int(k)): (None if pd.isna(v) else float(v)) for k, v in s.items()}

    def majemuk(kol):
        if kol not in df:
            return {}
        w = df[kol].unstack("tahun")
        if awal not in w or akhir not in w:
            return {}
        return bersih(((w[akhir] / w[awal]) ** (1 / n) - 1) * 100)

    def per_tahun(kol):
        if kol not in df:
            return None
        w = df[kol].unstack("tahun")
        return w[[t for t in th if t in w]]

    inv = per_tahun("PMAPMDN")
    g = per_tahun("G_PDRB")
    return {
        "g": majemuk("PDRB_ADHK"),
        "pmtb": majemuk("PMTB_ADHK"),
        "inv": bersih(inv.mean(axis=1) / 1000) if inv is not None else {},
        "peluang": bersih((g >= sasaran).where(g.notna()).mean(axis=1)) if g is not None else {},
        "tahun": [awal + 1, akhir],
    }


def pangsa_kelompok_investasi(df, tahun):
    """Pangsa PMA+PMDN per kelompok sektor (negatif dipotong nol), rata-rata `tahun`.

    Kembalikan DataFrame kode provinsi x kelompok, baris berjumlah satu.
    """
    sub = df[df.index.get_level_values("tahun").isin(tahun)]
    per_kel = {}
    for s in KODE_SEKTOR:
        nilai = sub.get(f"PMA_{s}", 0).fillna(0).clip(lower=0) + sub.get(f"PMDN_{s}", 0).fillna(0).clip(lower=0)
        k = KELOMPOK_SEKTOR[s]
        per_kel[k] = per_kel.get(k, 0) + nilai
    tab = pd.DataFrame(per_kel).groupby(level="kode").sum()
    tab = tab[["primer", "sekunder", "tva", "tlain"]]
    total = tab.sum(axis=1)
    nas = tab.sum() / tab.sum().sum()
    pangsa = tab.div(total.replace(0, np.nan), axis=0)
    return pangsa.apply(lambda r: nas if r.isna().any() else r, axis=1)


def pangsa_sektor_investasi(df, tahun):
    """Pangsa PMA+PMDN per 17 sektor di dalam kelompoknya, per provinsi."""
    sub = df[df.index.get_level_values("tahun").isin(tahun)]
    nilai = pd.DataFrame({
        s: sub.get(f"PMA_{s}", 0).fillna(0).clip(lower=0) + sub.get(f"PMDN_{s}", 0).fillna(0).clip(lower=0)
        for s in KODE_SEKTOR
    }).groupby(level="kode").sum()
    nas = nilai.sum()
    out = nilai.copy().astype(float)
    for kel in ("primer", "sekunder", "tva", "tlain"):
        cols = [s for s in KODE_SEKTOR if KELOMPOK_SEKTOR[s] == kel]
        tot = nilai[cols].sum(axis=1)
        nas_kel = nas[cols] / nas[cols].sum()
        for kode in out.index:
            out.loc[kode, cols] = (nilai.loc[kode, cols] / tot[kode]) if tot[kode] > 0 else nas_kel
    return out


def tabel_provinsi(df, tahun, kolom):
    """Baris per provinsi untuk satu tahun: kode, nama, pulau, dan kolom diminta."""
    sub = df.xs(tahun, level="tahun") if tahun in df.index.get_level_values("tahun") else pd.DataFrame()
    baris = []
    for kode in sub.index:
        r = {"kode": int(kode), "nama": NAMA_PROVINSI.get(int(kode), str(kode)),
             "pulau": PULAU_PROVINSI.get(int(kode), "")}
        for k in kolom:
            v = sub.at[kode, k] if k in sub.columns else np.nan
            r[k] = None if pd.isna(v) else float(v)
        baris.append(r)
    return baris
