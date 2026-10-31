"""Pemeriksaan kelengkapan dan kewajaran satu versi data (setara lembar Kelengkapan di alat Excel, diperluas).

Setiap pemeriksaan menghasilkan status ok | periksa | info, satu angka ringkas, dan rincian sel
(provinsi, tahun, variabel, nilai, keterangan) supaya pengguna bisa langsung menuju sel bermasalah.
"""

import numpy as np
import pandas as pd

from . import variabel as V
from .panel import tambah_turunan
from .referensi import KODE_PROVINSI, KODE_SEKTOR, NAMA_PROVINSI, PULAU, PULAU_PROVINSI

MAKS_RINCI = 200
TAHUN_DASAR = ["PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB"]
PANEL_ESTIMASI = ["PDRB_ADHK", "PMTB_ADHK", "TK_TOTAL"]


def _rinci(df, mask, kol, ket=None):
    out = []
    for (kode, tahun), ok in mask.items():
        if ok:
            v = df.at[(kode, tahun), kol] if kol in df.columns else None
            out.append({"prov": NAMA_PROVINSI.get(kode, kode), "kode": int(kode), "tahun": int(tahun), "var": kol,
                        "nilai": None if v is None or pd.isna(v) else float(v),
                        "ket": ket(kode, tahun) if ket else ""})
    return out


def _cek(label, status, nilai, rincian=(), saran="", nilai_fmt=None):
    rincian = list(rincian)
    return {"label": label, "status": status, "nilai": nilai if nilai_fmt is None else nilai_fmt,
            "n_rinci": len(rincian), "rincian": rincian[:MAKS_RINCI], "saran": saran}


def periksa(versi):
    df, catatan = versi.ke_dataframe(dengan_catatan=True)
    df = tambah_turunan(df)
    kode_ada = sorted(int(k) for k in df.index.get_level_values("kode").unique())
    tahun = sorted(int(t) for t in df.index.get_level_values("tahun").unique())
    n_prov = len(KODE_PROVINSI)
    hasil = []

    hasil.append(_cek("Jumlah baris provinsi × tahun", "ok" if len(df) else "periksa", len(df)))
    hasil.append(_cek("Rentang tahun data", "ok" if tahun else "periksa", f"{tahun[0]}–{tahun[-1]}" if tahun else "–"))

    hilang = [k for k in KODE_PROVINSI if k not in kode_ada]
    hasil.append(_cek("Provinsi tanpa baris sama sekali", "ok" if not hilang else "periksa", len(hilang),
                      [{"prov": NAMA_PROVINSI[k], "kode": k, "tahun": None, "var": "", "nilai": None, "ket": ""} for k in hilang]))

    tidak_lengkap = [t for t in tahun
                     if "PDRB_ADHK" not in df or df.xs(t, level="tahun")["PDRB_ADHK"].notna().sum() < n_prov]
    hasil.append(_cek(f"Tahun dengan PDRB < {n_prov} provinsi", "ok" if not tidak_lengkap else "periksa",
                      len(tidak_lengkap),
                      [{"prov": "", "kode": None, "tahun": t, "var": "PDRB_ADHK", "nilai": None,
                        "ket": f"{int(df.xs(t, level='tahun')['PDRB_ADHK'].notna().sum()) if 'PDRB_ADHK' in df else 0} provinsi terisi"}
                       for t in tidak_lengkap]))

    wajib_hilang = [k for k in V.WAJIB if k not in df.columns]
    hasil.append(_cek("Variabel wajib simulasi yang tidak ada", "ok" if not wajib_hilang else "periksa", len(wajib_hilang),
                      [{"prov": "", "kode": None, "tahun": None, "var": k, "nilai": None, "ket": V.label(k)} for k in wajib_hilang]))

    rin = []
    for k in ("PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB", "PMA", "PMDN"):
        if k in df:
            rin += _rinci(df, df[k] < 0, k)
    hasil.append(_cek("Nilai negatif di PDRB, PMTB, PMA, PMDN", "ok" if not rin else "periksa", len(rin), rin))

    rin = _rinci(df, df["G_PDRB"].abs() > 30, "G_PDRB", lambda k, t: "laju PDRB riil %") if "G_PDRB" in df else []
    hasil.append(_cek("Laju PDRB riil di luar ±30% (cek lonjakan)", "ok" if not rin else "periksa", len(rin), rin,
                      "Biasanya salah satuan atau tahun dasar berbeda; periksa sel PDRB tahun itu dan sebelumnya."))

    if tahun:
        t_akhir = max(t for t in tahun if "PDRB_ADHK" in df and df.xs(t, level="tahun")["PDRB_ADHK"].notna().any())
        sub = df.xs(t_akhir, level="tahun")
        ada = [k for k in TAHUN_DASAR if k in sub]
        lengkap = sub[ada].notna().all(axis=1) if len(ada) == len(TAHUN_DASAR) else pd.Series(False, index=sub.index)
        kurang = [{"prov": NAMA_PROVINSI[k], "kode": int(k), "tahun": t_akhir, "var": ", ".join(c for c in ada if pd.isna(sub.at[k, c])),
                   "nilai": None, "ket": "kosong"} for k in sub.index if not lengkap.get(k, False)]
        hasil.append(_cek(f"Provinsi dengan data tahun dasar {t_akhir} lengkap (PDRB, PMTB riil & nominal)",
                          "ok" if lengkap.sum() >= n_prov else "periksa", f"{int(lengkap.sum())} / {n_prov}", kurang))

    tk = [f"TK_{s}" for s in KODE_SEKTOR]
    th_tk = [t for t in tahun if all(c in df for c in tk) and df.xs(t, level="tahun")[tk].notna().all().all()]
    hasil.append(_cek("Tahun TK sektoral lengkap terakhir (dipakai realokasi)", "ok" if th_tk else "periksa",
                      th_tk[-1] if th_tk else "–"))

    ada = [k for k in PANEL_ESTIMASI if k in df]
    if len(ada) == len(PANEL_ESTIMASI):
        lengkap = df[ada].notna().all(axis=1)
        per_prov = lengkap.groupby(level="kode").sum()
        seimbang = lengkap.all()
        rin = [{"prov": NAMA_PROVINSI[k], "kode": int(k), "tahun": None, "var": "", "nilai": None,
                "ket": f"{int(n)} dari {len(tahun)} tahun lengkap"} for k, n in per_prov.items() if n < len(tahun)]
        hasil.append(_cek("Panel estimasi seimbang (PDRB riil, PMTB riil, TK total)", "ok" if seimbang else "info",
                          "ya" if seimbang else "tidak", rin,
                          "Estimasi tetap jalan pada panel tidak seimbang; tahun yang kosong dikeluarkan dari regresi."))

    # ---- konsistensi antarvariabel (tambahan, tidak ada di Excel)
    va = [f"VA_{s}" for s in KODE_SEKTOR]
    if "PDRB_ADHK" in df and all(c in df for c in va):
        jml = df[va].sum(axis=1, min_count=len(va))
        sel = (jml / df["PDRB_ADHK"] - 1) * 100
        m = sel.abs() > 2
        rin = _rinci(df, m.fillna(False), "PDRB_ADHK", lambda k, t: f"Σ VA sektor selisih {sel.at[(k, t)]:+.1f}%")
        hasil.append(_cek("Jumlah VA 17 sektor ≠ PDRB ADHK (selisih > 2%)", "ok" if not rin else "periksa", len(rin), rin,
                          "PDRB lapangan usaha mestinya sama dengan jumlah nilai tambah sektor (selisih kecil karena pembulatan)."))
    for total in ("PMA", "PMDN"):
        kol = [f"{total}_{s}" for s in KODE_SEKTOR if f"{total}_{s}" in df]
        if total in df and kol:
            jml = df[kol].sum(axis=1, min_count=1)
            sel = (jml / df[total].replace(0, np.nan) - 1) * 100
            m = (sel.abs() > 5).fillna(False)
            rin = _rinci(df, m, total, lambda k, t, sel=sel: f"Σ sektor selisih {sel.at[(k, t)]:+.1f}%")
            hasil.append(_cek(f"Jumlah {total} sektoral ≠ {total} total (selisih > 5%)", "ok" if not rin else "info", len(rin), rin))
    if {"PMTB_ADHB", "PMTB_ADHK"} <= set(df.columns):
        defl = df["PMTB_ADHB"] / df["PMTB_ADHK"]
        g = defl.groupby(level="kode").pct_change(fill_method=None) * 100
        rin = _rinci(df, (g.abs() > 25).fillna(False), "PMTB_ADHB", lambda k, t: f"deflator PMTB berubah {g.at[(k, t)]:+.1f}%")
        hasil.append(_cek("Deflator implisit PMTB melonjak > 25%/tahun", "ok" if not rin else "periksa", len(rin), rin,
                          "Rasio PMTB nominal/riil mestinya bergerak mulus; lonjakan biasanya salah ketik di salah satu seri."))
    if "PMAPMDN" in df:
        g = df["PMAPMDN"].groupby(level="kode").pct_change(fill_method=None) * 100
        rin = _rinci(df, (g > 300).fillna(False), "PMAPMDN", lambda k, t: f"naik {g.at[(k, t)]:+.0f}%")
        hasil.append(_cek("PMA+PMDN naik > 300% dalam setahun", "ok" if not rin else "info", len(rin), rin,
                          "Bisa wajar untuk proyek besar; pastikan bukan salah satuan (juta vs miliar)."))

    imp = sum(1 for c in catatan.values() for v in c.values() if "imputasi" in str(v))
    lon = sum(1 for c in catatan.values() for v in c.values() if "lonjakan" in str(v))
    sun = sum(1 for c in catatan.values() for v in c.values() if "disunting" in str(v))
    hasil.append(_cek("Sel bertanda pembersihan (imputasi · lonjakan · disunting)", "info", f"{imp} · {lon} · {sun}"))
    hasil.append(_cek("Rincian 38 provinsi (pangsa pemekaran Papua)", "ok" if versi.bisa_rinci_papua else "info",
                      "tersedia" if versi.bisa_rinci_papua else "belum ada"))
    return hasil


def matriks(versi):
    """Kelengkapan: variabel × tahun (bagian provinsi berdata), provinsi × tahun (bagian variabel wajib berdata)."""
    df = tambah_turunan(versi.ke_dataframe())
    tahun = sorted(int(t) for t in df.index.get_level_values("tahun").unique())
    kode = [k for k in KODE_PROVINSI]
    full = df.reindex(pd.MultiIndex.from_product([kode, tahun], names=["kode", "tahun"]))
    terisi = full.notna().groupby(level="tahun").mean() * 100
    var = []
    for v in V.DAFTAR:
        nilai = [float(terisi.at[t, v.kode]) if v.kode in terisi else 0.0 for t in tahun]
        var.append({"kode": v.kode, "label": v.label, "satuan": v.satuan, "grup": v.grup, "wajib": v.wajib,
                    "nilai": nilai, "rata": float(np.mean(nilai)) if nilai else 0.0})
    wajib = [k for k in V.WAJIB]
    ada = [k for k in wajib if k in full]
    per_prov = (full[ada].notna().sum(axis=1) / len(wajib) * 100) if ada else pd.Series(0.0, index=full.index)
    prov = []
    for k in kode:
        nilai = [float(per_prov.at[(k, t)]) for t in tahun]
        prov.append({"kode": k, "nama": NAMA_PROVINSI[k], "pulau": PULAU_PROVINSI[k], "nilai": nilai,
                     "rata": float(np.mean(nilai)) if nilai else 0.0})
    def kelompok(baris, kunci, urutan):
        out = []
        for g in urutan:
            isi = [b for b in baris if b[kunci] == g]
            if isi:
                nilai = [float(np.mean([b["nilai"][i] for b in isi])) for i in range(len(tahun))]
                out.append({"nama": g, "isi": isi, "nilai": nilai, "rata": float(np.mean(nilai)) if nilai else 0.0})
        return out

    semua = [float(np.mean([b["nilai"][i] for b in var])) for i in range(len(tahun))]
    wajib_th = [float(np.mean([b["nilai"][i] for b in prov])) for i in range(len(tahun))]
    return {"tahun": tahun, "grup": kelompok(var, "grup", V.GRUP), "pulau": kelompok(prov, "pulau", PULAU), "wajib_th": wajib_th,
            "n_wajib": len(wajib), "total": semua, "total_rata": float(np.mean(semua)) if semua else 0.0}
