"""Recheck spatial TFP: variance, island-W tautology, between Moran.

The panel SAR on two-way residuals has almost no leftover variation.
Island W is a clique: Wy is the island mean. That is not a spillover.

This script:
  1. Variance decomposition of log TFP vs Wy under island / queen / knn4.
  2. How much of mean TFP is just 6 island dummies.
  3. Moran I (999 permutations) on province MEANS (the map) and on FE2W
     residuals, and on mean TFP after absorbing island FE.
  4. Cross-section SAR on N=34 means with queen and knn4 (honest map model).

Run from root: python3 "02 Code/TFP/docs/06 Review/spatial_recheck.py"
"""
from __future__ import annotations

from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
from numpy.linalg import slogdet
from scipy.optimize import minimize
from scipy.stats import chi2

REV = Path("02 Code/TFP/docs/06 Review")
OUT = Path("01 Data/TFP/output/luaran 2")
OUT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(11)

NAME2CODE = {
    "Aceh": 11, "SumateraUtara": 12, "SumateraBarat": 13, "Riau": 14,
    "Jambi": 15, "SumateraSelatan": 16, "Bengkulu": 17, "Lampung": 18,
    "BangkaBelitung": 19, "KepulauanRiau": 21, "JakartaRaya": 31,
    "JawaBarat": 32, "JawaTengah": 33, "Yogyakarta": 34, "JawaTimur": 35,
    "Banten": 36, "Bali": 51, "NusaTenggaraBarat": 52,
    "NusaTenggaraTimur": 53, "KalimantanBarat": 61, "KalimantanTengah": 62,
    "KalimantanSelatan": 63, "KalimantanTimur": 64, "KalimantanUtara": 65,
    "SulawesiUtara": 71, "SulawesiTengah": 72, "SulawesiSelatan": 73,
    "SulawesiTenggara": 74, "Gorontalo": 75, "SulawesiBarat": 76,
    "Maluku": 81, "MalukuUtara": 82, "PapuaBarat": 91, "Papua": 94,
}
XVARS = ["idx_hr", "idx_inst", "idx_conn", "ln_wage",
         "IKLH_Prov", "Hijau_Prov", "Biru_Prov"]


def row_std(W):
    s = W.sum(1, keepdims=True)
    s[s == 0] = 1
    return W / s


def moran(z, W):
    z = z - z.mean()
    den = z @ z
    return float((z @ (W @ z)) / den) if den > 0 else np.nan


def moran_perm(z, W, n=999):
    I0 = moran(z, W)
    hits = 0
    for _ in range(n):
        zp = RNG.permutation(z)
        if abs(moran(zp, W)) >= abs(I0):
            hits += 1
    return I0, (hits + 1) / (n + 1)


def double_demean(df, cols, idcol, tcol):
    d = df.copy()
    for c in cols:
        d[c] = (d[c]
                - d.groupby(idcol)[c].transform("mean")
                - d.groupby(tcol)[c].transform("mean")
                + d[c].mean())
    return d


def weights(codes, pulau):
    g = gpd.read_file(REV / "assets/gadm41_IDN_1.json")[["NAME_1", "geometry"]]
    g["Code_Prov"] = g.NAME_1.map(NAME2CODE).astype(int)
    g = g.set_index("Code_Prov").loc[codes].to_crs(3857)
    g["geometry"] = g.geometry.simplify(2000, preserve_topology=True)
    n = len(codes)
    xy = np.column_stack([g.centroid.x.values, g.centroid.y.values])
    dist = np.sqrt(((xy[:, None, :] - xy[None, :, :]) ** 2).sum(2))
    np.fill_diagonal(dist, np.inf)

    Wq = np.zeros((n, n))
    for i, ci in enumerate(codes):
        gi = g.loc[ci].geometry
        for j in range(i + 1, n):
            if gi.distance(g.loc[codes[j]].geometry) < 1000:
                Wq[i, j] = Wq[j, i] = 1
    for i in range(n):
        if Wq[i].sum() == 0:
            j = int(np.argmin(dist[i]))
            Wq[i, j] = Wq[j, i] = 1

    Wknn = np.zeros((n, n))
    for i in range(n):
        nn = np.argsort(dist[i])[:4]
        Wknn[i, nn] = 1
    Wknn = np.maximum(Wknn, Wknn.T)  # make symmetric

    Wi = np.zeros((n, n))
    for i, ci in enumerate(codes):
        for j, cj in enumerate(codes):
            if i != j and pulau[ci] == pulau[cj]:
                Wi[i, j] = 1

    # inverse-distance among k=8 nearest, then row-std
    Wid = np.zeros((n, n))
    for i in range(n):
        nn = np.argsort(dist[i])[:8]
        Wid[i, nn] = 1.0 / np.maximum(dist[i, nn] / 1000.0, 1.0)

    return {
        "queen": row_std(Wq),
        "knn4": row_std(Wknn),
        "invdist8": row_std(Wid),
        "island": row_std(Wi),
    }, dist, g


def sar_nll(rho, y, X, W):
    rho = float(np.asarray(rho).reshape(-1)[0])
    if not (-0.95 < rho < 0.95):
        return 1e12
    n = W.shape[0]
    sign, ld = slogdet(np.eye(n) - rho * W)
    if sign <= 0:
        return 1e12
    Ay = y - rho * (W @ y)
    b, *_ = np.linalg.lstsq(X, Ay, rcond=None)
    e = Ay - X @ b
    sig2 = float(e @ e / n)
    if sig2 <= 1e-12:
        return 1e12
    return 0.5 * n * np.log(2 * np.pi * sig2) - ld + 0.5 * n


def fit_sar(y, X, W):
    X = np.column_stack([np.ones(len(y)), X]) if X.ndim == 2 else X
    res = minimize(lambda r: sar_nll(r, y, X, W), [0.2],
                    method="L-BFGS-B", bounds=[(-0.9, 0.9)])
    rho = float(res.x[0])
    Ay = y - rho * (W @ y)
    b, *_ = np.linalg.lstsq(X, Ay, rcond=None)
    e = Ay - X @ b
    n, k = X.shape
    sig2 = float(e @ e / n)
    eps = 1e-4
    f0 = sar_nll(rho, y, X, W)
    hess = (sar_nll(rho + eps, y, X, W) - 2 * f0 + sar_nll(rho - eps, y, X, W)) / eps ** 2
    se = float(np.sqrt(1 / hess)) if hess > 0 else np.nan
    ll = -float(res.fun)
    return rho, se, b, sig2, ll, k


def main():
    peta = pd.read_csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv")
    peta = peta.dropna(subset=["Code_Prov", "Pulau"]).drop_duplicates("Code_Prov")
    peta["Code_Prov"] = peta["Code_Prov"].astype(int)
    dta = pd.read_stata("01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                        convert_categoricals=False)
    dta["Code_Prov"] = dta["Code_Prov"].astype(int)
    dta = dta.merge(peta[["Code_Prov", "Pulau"]], on="Code_Prov")
    dta = dta.sort_values(["Year", "Code_Prov"]).reset_index(drop=True)
    codes = sorted(dta.Code_Prov.unique())
    pulau = dict(zip(peta.Code_Prov, peta.Pulau))
    Ws, dist, g = weights(codes, pulau)

    y_full = dta["logtfp_it"].to_numpy()
    print("=== 1. Variance of log TFP ===")
    print(f"  overall var           {y_full.var():.4f}")
    between = dta.groupby("Code_Prov")["logtfp_it"].transform("mean")
    print(f"  between-province share {(between.var() / y_full.var()):.3f}")
    dd = double_demean(dta, ["logtfp_it"] + XVARS, "Code_Prov", "Year")
    print(f"  after two-way demean  {dd['logtfp_it'].var():.5f}  "
          f"({100 * dd['logtfp_it'].var() / y_full.var():.1f}% of overall)")

    X = dd[XVARS].to_numpy()
    ydd = dd["logtfp_it"].to_numpy()
    b, *_ = np.linalg.lstsq(X, ydd, rcond=None)
    e = ydd - X @ b
    print(f"  FE2W residual         {e.var():.5f}  "
          f"({100 * e.var() / y_full.var():.1f}% of overall)")

    # one year of residual for Wy scale
    e2024 = e[dta.Year.to_numpy() == 2024]
    print("\n=== 2. var(Wy) / var(y) on 2024 FE2W residual (leftover) ===")
    for name, W in Ws.items():
        wy = W @ e2024
        print(f"  {name:10s}  var(Wy)/var(y)={wy.var() / e2024.var():.3f}  "
              f"sd(y)={e2024.std():.4f}  sd(Wy)={wy.std():.4f}")

    pm = (dta.groupby("Code_Prov")
          .agg(logtfp=("logtfp_it", "mean"),
               Pulau=("Pulau", "first"),
               **{v: (v, "mean") for v in XVARS})
          .loc[codes])
    yb = pm["logtfp"].to_numpy()
    print("\n=== 3. Island dummies on the MAP (N=34 means) ===")
    D = pd.get_dummies(pm["Pulau"], drop_first=True).to_numpy(float)
    Xisl = np.column_stack([np.ones(len(yb)), D])
    bb, *_ = np.linalg.lstsq(Xisl, yb, rcond=None)
    r2_isl = 1 - ((yb - Xisl @ bb) ** 2).sum() / ((yb - yb.mean()) ** 2).sum()
    print(f"  R² of 6 island groups on mean log TFP = {r2_isl:.3f}")
    y_demean_isl = yb - Xisl @ bb
    print(f"  leftover after island FE: var share {y_demean_isl.var() / yb.var():.3f}")

    print("\n=== 4. Island W is the island mean ===")
    Wy_isl = Ws["island"] @ yb
    corr = np.corrcoef(Wy_isl, Xisl @ bb)[0, 1]
    print(f"  corr(W_island y, fitted island dummies) = {corr:.3f}")
    print("  (a clique W cannot distinguish spillover from a group intercept)")

    print("\n=== 5. Moran I on MEAN log TFP (the map), 999 permutations ===")
    moran_rows = []
    for label, z in [
        ("mean_logTFP", yb),
        ("mean_TFP_after_island_FE", y_demean_isl),
        ("FE2W_resid_2024", e2024),
    ]:
        print(f"  -- {label} --")
        for name, W in Ws.items():
            I, p = moran_perm(z, W)
            moran_rows.append({"series": label, "W": name, "I": I, "p_perm": p})
            print(f"     {name:10s}  I={I:7.3f}  p={p:.3f}")

    print("\n=== 6. Cross-section SAR on N=34 means (connectivity + inst) ===")
    # keep the two pillars that have a between story; full X is 7 + const on N=34
    Xb = pm[["idx_inst", "idx_conn"]].to_numpy()
    sar_rows = []
    for name, W in Ws.items():
        rho, se, bhat, sig2, ll, k = fit_sar(yb, Xb, W)
        z = rho / se if se == se and se > 0 else np.nan
        # nonspatial OLS R2 for comparison
        Xols = np.column_stack([np.ones(len(yb)), Xb])
        bols, *_ = np.linalg.lstsq(Xols, yb, rcond=None)
        r2 = 1 - ((yb - Xols @ bols) ** 2).sum() / ((yb - yb.mean()) ** 2).sum()
        print(f"  {name:10s}  rho={rho:6.3f} (SE {se:.3f}) z={z:5.2f}  "
              f"ll={ll:.1f}  OLS R2 inst+conn={r2:.3f}")
        print(f"             const={bhat[0]:.3f} inst={bhat[1]:.3f} conn={bhat[2]:.3f}")
        sar_rows.append({"W": name, "rho": rho, "se": se, "z": z,
                         "b_inst": bhat[1], "b_conn": bhat[2], "ll": ll, "ols_r2": r2})

    # OLS vs SAR LR on queen and knn only
    print("\n=== 7. If we absorb island FE, does queen leftover still cluster? ===")
    I, p = moran_perm(y_demean_isl, Ws["queen"])
    print(f"  Moran queen on TFP | island FE: I={I:.3f} p={p:.3f}")
    I, p = moran_perm(y_demean_isl, Ws["knn4"])
    print(f"  Moran knn4  on TFP | island FE: I={I:.3f} p={p:.3f}")

    pd.DataFrame(moran_rows).to_csv(OUT / "spatial_recheck_moran.csv", index=False)
    pd.DataFrame(sar_rows).to_csv(OUT / "spatial_recheck_sar_between.csv", index=False)
    print("\nwrote", OUT / "spatial_recheck_moran.csv")


if __name__ == "__main__":
    main()
