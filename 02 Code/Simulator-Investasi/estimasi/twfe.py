"""
Estimator two-way fixed effects untuk panel seimbang maupun tidak.

Padanan `plm(log Y ~ log K + log L + factor(Year), model = "within")` di
`01_estimasi tfp.R`. SE klaster provinsi mengikuti `vcovHC(method = "arellano",
type = "HC1")`: koreksi n / (n - k) dengan k = jumlah regresor termasuk dummy
tahun. Diuji mereproduksi b1 = 0,401899 dan b2 = 0,147184 pada data vintage B.
"""

import numpy as np
import pandas as pd

from datapanel.referensi import KODE_SEKTOR


def stok_pim(I, delta=0.05):
    """Stok kapital per provinsi dari arus PMTB: K_t = (1 − δ) K_{t−1} + I_t, K_0 = I_0 / (g + δ)."""
    out = []
    for _, s in I.groupby(level="kode"):
        s = s.dropna()
        if s.empty:
            continue
        v = s.to_numpy(float)
        g = np.mean(np.diff(np.log(v[:4]))) if len(v) > 1 and (v[:4] > 0).all() else 0.0
        k = [v[0] / max(g + delta, 0.02)]
        for x in v[1:]:
            k.append((1 - delta) * k[-1] + x)
        out.append(pd.Series(k, index=s.index))
    return pd.concat(out).reindex(I.index) if out else I * np.nan


def siapkan_log(df, modal="pmtb", delta=0.05):
    tk = [f"TK_{s}" for s in KODE_SEKTOR]
    out = pd.DataFrame(index=df.index)
    out["lnY"] = np.log(df["PDRB_ADHK"])
    K = stok_pim(df["PMTB_ADHK"], delta) if modal == "stok" else df["PMTB_ADHK"]
    out["lnK"] = np.log(K)
    out["lnL"] = np.log(df[tk].sum(axis=1, min_count=len(tk)))
    return out.replace([np.inf, -np.inf], np.nan)


def _demean_dua_arah(d, kolom, iterasi=200, tol=1e-12, tahun=True):
    """Transformasi within dua arah; berulang (alternating projections) supaya sah di panel tak seimbang."""
    x = d[kolom].copy()
    prov = d.index.get_level_values("kode")
    th = d.index.get_level_values("tahun")
    for _ in range(iterasi):
        lama = x.copy()
        x = x - x.groupby(prov).transform("mean")
        if not tahun:
            break
        x = x - x.groupby(th).transform("mean")
        if (x - lama).abs().to_numpy().max() < tol:
            break
    return x


def _efek_tetap(u, tahun=True, iterasi=500, tol=1e-12):
    """Pulihkan a_i dan d_t dari u = y − Xb (d_t tahun pertama = 0)."""
    prov = u.index.get_level_values("kode")
    th = u.index.get_level_values("tahun")
    a = pd.Series(0.0, index=u.index)
    d = pd.Series(0.0, index=u.index)
    for _ in range(iterasi):
        a_baru = (u - d).groupby(prov).transform("mean")
        d_baru = (u - a_baru).groupby(th).transform("mean") if tahun else d
        selesai = max((a_baru - a).abs().max(), (d_baru - d).abs().max()) < tol
        a, d = a_baru, d_baru
        if selesai:
            break
    dt = d.groupby(th).first().sort_index()
    geser = dt.iloc[0] if len(dt) else 0.0
    dt = dt - geser
    ai = a.groupby(prov).first() + geser
    return ai, dt


def estimasi_lengkap(df, tahun_awal=None, tahun_akhir=None, crs=False, kecuali_tahun=(), provinsi=None,
                     efek_tahun=True, modal="pmtb", delta=0.05):
    """Two-way FE dengan keluaran lengkap: koefisien, SE klaster, t, p, CI, uji CRS, fixed effect, residual."""
    from .statistik import bintang, p_dua_sisi, t_kritis

    d = siapkan_log(df, modal, delta)
    th = d.index.get_level_values("tahun")
    pilih = np.ones(len(d), bool)
    if tahun_awal:
        pilih &= th >= tahun_awal
    if tahun_akhir:
        pilih &= th <= tahun_akhir
    if kecuali_tahun:
        pilih &= ~th.isin([int(t) for t in kecuali_tahun])
    if provinsi:
        pilih &= d.index.get_level_values("kode").isin([int(k) for k in provinsi])
    d = d[pilih]
    dibuang = d[d.isna().any(axis=1)]
    d = d.dropna()
    if crs:
        d = pd.DataFrame({"y": d.lnY - d.lnL, "k": d.lnK - d.lnL, "lnY": d.lnY, "lnL": d.lnL}, index=d.index)
        kol_x = ["k"]
    else:
        d = pd.DataFrame({"y": d.lnY, "k": d.lnK, "l": d.lnL, "lnY": d.lnY}, index=d.index)
        kol_x = ["k", "l"]
    if len(d) < 20:
        raise ValueError("Observasi lengkap kurang dari 20; perluas rentang tahun, provinsi, atau lengkapi data.")
    G = d.index.get_level_values("kode").nunique()
    T = d.index.get_level_values("tahun").nunique()
    if G < 3:
        raise ValueError("Butuh minimal 3 provinsi untuk standard error klaster.")
    w = _demean_dua_arah(d, ["y"] + kol_x, tahun=efek_tahun)
    X, Y = w[kol_x].to_numpy(), w["y"].to_numpy()
    b, *_ = np.linalg.lstsq(X, Y, rcond=None)
    e = Y - X @ b
    n = len(d)
    k = len(kol_x) + ((T - 1) if efek_tahun else 0)
    XtXi = np.linalg.inv(X.T @ X)
    meat = np.zeros((len(kol_x), len(kol_x)))
    for idx in pd.Series(range(n)).groupby(d.index.get_level_values("kode")).indices.values():
        s = X[idx].T @ e[idx]
        meat += np.outer(s, s)
    V = XtXi @ meat @ XtXi * n / (n - k)
    se = np.sqrt(np.diag(V))
    r2_within = 1 - (e @ e) / (Y @ Y)

    u = d["y"] - pd.Series(d[kol_x].to_numpy() @ b, index=d.index)
    ai, dt = _efek_tetap(u, efek_tahun)
    th_d = d.index.get_level_values("tahun")
    fit = d[kol_x].to_numpy() @ b + ai.reindex(d.index.get_level_values("kode")).to_numpy() \
        + (dt.reindex(th_d).to_numpy() if efek_tahun else 0.0)
    res = d["y"].to_numpy() - fit
    sst = ((d["y"] - d["y"].mean()) ** 2).sum()
    r2_total = 1 - (res @ res) / sst if sst else None

    dfk = G - 1
    tk = t_kritis(dfk)
    if crs:
        b1, s1 = float(b[0]), float(se[0])
        koef = [("b1", "ln K · modal", b1, s1), ("b2", "ln L · TK (= 1 − b1)", 1 - b1, s1)]
        uji_crs = None
    else:
        b1, b2 = float(b[0]), float(b[1])
        koef = [("b1", "ln K · modal", b1, float(se[0])), ("b2", "ln L · tenaga kerja", b2, float(se[1]))]
        var_rts = V[0, 0] + V[1, 1] + 2 * V[0, 1]
        t_rts = (b1 + b2 - 1) / np.sqrt(var_rts) if var_rts > 0 else np.nan
        uji_crs = {"rts": b1 + b2, "se": float(np.sqrt(var_rts)), "t": float(t_rts), "F": float(t_rts ** 2),
                   "p": p_dua_sisi(float(t_rts), dfk)}
    tabel = []
    for kunci, label, nilai, s in koef:
        t = nilai / s if s else np.nan
        p = p_dua_sisi(float(t), dfk)
        tabel.append({"kunci": kunci, "label": label, "b": nilai, "se": s, "t": float(t), "p": p,
                      "lo": nilai - tk * s, "hi": nilai + tk * s, "bintang": bintang(p)})

    kode = d.index.get_level_values("kode")
    resid = pd.Series(res, index=d.index)
    per_prov = resid.groupby(kode).agg(lambda x: float(np.sqrt((x ** 2).mean())))
    obs_th = pd.Series(1, index=d.index).groupby(th_d).sum()
    return {
        "b1": tabel[0]["b"], "se_b1": tabel[0]["se"], "b2": tabel[1]["b"], "se_b2": tabel[1]["se"],
        "n_obs": n, "n_provinsi": G, "n_tahun": T, "r2_within": float(r2_within),
        "r2_total": None if r2_total is None else float(r2_total), "df_klaster": dfk, "t_kritis": tk,
        "koefisien": tabel, "uji_crs": uji_crs,
        "efek_tahun": [{"tahun": int(t), "d": float(v), "n": int(obs_th.get(t, 0))} for t, v in dt.items()],
        "efek_provinsi": {str(int(k)): float(v - ai.mean()) for k, v in ai.items()},
        "rmse_provinsi": {str(int(k)): float(v) for k, v in per_prov.items()},
        "residual": [[int(kk), int(tt), float(f), float(r)] for (kk, tt), f, r in zip(d.index, fit, res)],
        "dibuang": [[int(kk), int(tt)] for kk, tt in dibuang.index],
        "rmse": float(np.sqrt((res ** 2).mean())),
        "spesifikasi": {"tahun_awal": tahun_awal, "tahun_akhir": tahun_akhir, "kecuali_tahun": sorted(int(t) for t in kecuali_tahun),
                        "provinsi": sorted(int(k) for k in provinsi) if provinsi else None, "crs": bool(crs),
                        "efek_tahun": bool(efek_tahun), "modal": modal, "delta": delta},
    }


def estimasi(df, tahun_awal=None, tahun_akhir=None, crs=False):
    h = estimasi_lengkap(df, tahun_awal, tahun_akhir, crs=crs)
    return {k: h[k] for k in ("b1", "se_b1", "b2", "se_b2", "n_obs", "n_provinsi", "n_tahun", "r2_within")}


def residual_tfp(df, b1, b2):
    """log TFP (level, termasuk fixed effect) dan laju tahunannya per provinsi-tahun."""
    d = siapkan_log(df)
    d["lnA"] = d.lnY - b1 * d.lnK - b2 * d.lnL
    per = d.groupby(level="kode")
    d["gY"] = per["lnY"].diff() * 100
    d["gK"] = per["lnK"].diff() * 100
    d["gL"] = per["lnL"].diff() * 100
    d["gA"] = per["lnA"].diff() * 100
    return d
