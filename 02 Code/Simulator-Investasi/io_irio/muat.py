"""Pemuat tabel IO dari folder 01 Data/IO-IRIO-NA/processed ke TabelIO."""

import re
from pathlib import Path

import numpy as np
import pandas as pd
from django.conf import settings

from datapanel.referensi import KODE_PROVINSI, KODE_SEKTOR, NAMA_PROVINSI

from .models import TabelIO

SUMBER = settings.REPO_DIR / "01 Data" / "IO-IRIO-NA" / "processed"
METODE = {"RAS": "RAS", "CROSS_ENTROPY": "CE"}


def _angka(s):
    return pd.to_numeric(s.replace("-", 0), errors="coerce").fillna(0).to_numpy(float)


def berkas_irio():
    for f in sorted((SUMBER / "UPDATING IRIO").glob("*/IRIO_Estimasi_*_*.xlsx")):
        m = re.match(r"IRIO_Estimasi_(\d{4})_(RAS|CROSS_ENTROPY)\.xlsx", f.name)
        if m:
            yield int(m[1]), METODE[m[2]], f


def berkas_nasional():
    for f in sorted((SUMBER / "UPDATING IO NASIONAL").glob("*/IO_Nasional_Estimasi_*_*.xlsx")):
        m = re.match(r"IO_Nasional_Estimasi_(\d{4})_(RAS|CROSS_ENTROPY)\.xlsx", f.name)
        if m:
            yield int(m[1]), METODE[m[2]], f


def muat_irio(tahun, metode, berkas):
    z = pd.read_excel(berkas, "Z_IRIO")
    label = z["origin_element"].astype(str).tolist()
    Z = z[label].to_numpy(float)  # kolom tujuan berurutan sama dengan baris asal
    tg = pd.read_excel(berkas, "Targets").set_index("element_label").loc[label]
    wil = list(dict.fromkeys(int(k) for k in z["origin_province_code"]))
    sek = list(dict.fromkeys(str(s) for s in z["origin_sector_code"]))
    if sek != KODE_SEKTOR or sorted(wil) != sorted(KODE_PROVINSI):
        raise ValueError(f"{berkas.name}: susunan wilayah/sektor tidak dikenal")
    x, va = tg["target_output"].to_numpy(float), tg["target_va"].to_numpy(float)
    cek = pd.read_excel(berkas, "Checks").iloc[0].to_dict()
    t, _ = TabelIO.objects.get_or_create(jenis=TabelIO.Jenis.IRIO, tahun=tahun, metode=metode)
    t.simpan_larik(Z=Z, x=x, va=va, wil=np.array(wil), sek=np.array(sek))
    t.sumber = str(berkas.relative_to(settings.REPO_DIR))
    t.ringkasan = {
        "output_T": float(x.sum() / 1e6), "va_T": float(va.sum() / 1e6), "antara_T": float(Z.sum() / 1e6),
        "antar_wilayah_pct": float(_antar_wilayah(Z, len(wil), len(sek)) / Z.sum() * 100),
        "konvergen": bool(cek.get("converged", True)), "satuan": "juta Rp",
        "kepadatan": float(cek.get("density", np.nan)) if "density" in cek else None,
    }
    t.save()
    return t


def _antar_wilayah(Z, R, S):
    blok = Z.reshape(R, S, R, S).sum(axis=(1, 3))
    return blok.sum() - np.trace(blok)


def muat_nasional(tahun, metode, berkas):
    z = pd.read_excel(berkas, "Z_Intermediate").set_index("sector")
    Z = z.to_numpy(float)
    tg = pd.read_excel(berkas, "Targets")
    x, va = tg["output_target"].to_numpy(float), tg["value_added_target"].to_numpy(float)
    if Z.shape != (17, 17):
        raise ValueError(f"{berkas.name}: Z bukan 17×17")
    t, _ = TabelIO.objects.get_or_create(jenis=TabelIO.Jenis.NASIONAL, tahun=tahun, metode=metode)
    t.simpan_larik(Z=Z, x=x, va=va, wil=np.array([0]), sek=np.array(KODE_SEKTOR))
    t.sumber = str(berkas.relative_to(settings.REPO_DIR))
    t.ringkasan = {"output_T": float(x.sum() / 1e6), "va_T": float(va.sum() / 1e6),
                   "antara_T": float(Z.sum() / 1e6), "satuan": "juta Rp"}
    t.save()
    return t


def _kode_dari_lembar(nama):
    kunci = re.sub(r"[^a-z]", "", nama.lower())
    alias = {"ntb": 52, "ntt": 53}
    if kunci in alias:
        return alias[kunci]
    for k in KODE_PROVINSI:
        if re.sub(r"[^a-z]", "", NAMA_PROVINSI[k].lower()) == kunci:
            return k
    raise ValueError(f"Lembar provinsi tidak dikenal: {nama!r}")


def muat_pmtb():
    """Komposisi produk PMTB (kolom 3030) tiap provinsi dari IO provinsi 2016, transaksi domestik."""
    berkas = next((SUMBER / "Tabel Input-Ouput" / "Provinsi").glob("*2016*.xlsx"))
    xl = pd.ExcelFile(berkas)
    lokal, impor_ln, impor_ap = {}, {}, {}
    for lembar in xl.sheet_names:
        k = _kode_dari_lembar(lembar)
        d = pd.read_excel(xl, lembar, header=None)
        kode_kol = d.iloc[4].astype(str).str.replace(".0", "", regex=False).tolist()
        j = kode_kol.index("3030")
        baris = d.iloc[:, 1].astype(str).str.strip().tolist()
        nilai = _angka(d.iloc[:, j].astype(object))
        lokal[k] = np.array([nilai[baris.index(s)] for s in KODE_SEKTOR])
        impor_ln[k] = nilai[baris.index("2000")]
        impor_ap[k] = nilai[baris.index("2001")]
    wil = sorted(lokal)
    L = np.array([lokal[k] for k in wil])
    t, _ = TabelIO.objects.get_or_create(jenis=TabelIO.Jenis.PMTB, tahun=2016, metode="")
    t.simpan_larik(lokal=L, impor_ln=np.array([impor_ln[k] for k in wil]),
                   impor_ap=np.array([impor_ap[k] for k in wil]), wil=np.array(wil), sek=np.array(KODE_SEKTOR))
    t.sumber = str(Path(berkas).relative_to(settings.REPO_DIR))
    tot = L.sum() + sum(impor_ln.values()) + sum(impor_ap.values())
    t.ringkasan = {"pmtb_T": float(tot / 1e6), "pangsa_impor_ln": float(sum(impor_ln.values()) / tot),
                   "pangsa_konstruksi": float(L[:, KODE_SEKTOR.index("F")].sum() / L.sum()), "satuan": "juta Rp"}
    t.save()
    return t
