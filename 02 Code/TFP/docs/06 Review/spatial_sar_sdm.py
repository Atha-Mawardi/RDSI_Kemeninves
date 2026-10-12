"""Panel SAR and SDM for provincial log TFP.

Supervisor (Luaran 2): SAR and SDM with (i) queen contiguity and (ii) island
block W (w_ij = 1 if same island, 0 otherwise). Estimated on the same dependent
variable and X vector as Pak Yudhis (vintage C, 34 x 2017-2025).

Spatial analogue of two-way FE: concentrate province and year effects by
double demeaning, then ML spatial lag (Elhorst 2014). Jacobian |I-ρW|^T.

Run from project root:
  python3 "02 Code/TFP/docs/06 Review/spatial_sar_sdm.py"
"""
from __future__ import annotations

import json
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
from numpy.linalg import slogdet
from scipy.optimize import minimize

ROOT = Path(".")
REV = Path("02 Code/TFP/docs/06 Review")
OUT = Path("01 Data/TFP/output/luaran 2")
OUT.mkdir(parents=True, exist_ok=True)

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
PILLARS = ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]


def row_standardize(W: np.ndarray) -> np.ndarray:
    s = W.sum(axis=1, keepdims=True)
    s[s == 0] = 1.0
    return W / s


def connect_isolates(W: np.ndarray, dist: np.ndarray, codes: list[int]) -> tuple[np.ndarray, list]:
    """If a province has no neighbour, add its nearest centroid neighbour."""
    notes = []
    W = W.copy()
    n = W.shape[0]
    for i in range(n):
        if W[i].sum() == 0:
            d = dist[i].copy()
            d[i] = np.inf
            j = int(np.argmin(d))
            W[i, j] = 1
            W[j, i] = 1
            notes.append((int(codes[i]), int(codes[j]), float(d[j])))
    return W, notes


def build_queen(codes: list[int]) -> tuple[np.ndarray, dict]:
    """Land queen: simplified GADM polygons with distance < 1 km.

    GADM borders often fail shapely.touches (slivers). After simplify(2 km)
    in EPSG:3857, land neighbours have distance 0. Remaining isolates are
    true island provinces; each is linked to its nearest centroid so W has
    no zeros (Bali–Jatim, NTB–Bali/NTT, Kepri–Riau, Babel–Sumsel, Maluku).
    """
    g = gpd.read_file(REV / "assets/gadm41_IDN_1.json")[["NAME_1", "geometry"]]
    g["Code_Prov"] = g.NAME_1.map(NAME2CODE)
    g = g.dropna(subset=["Code_Prov"])
    g["Code_Prov"] = g["Code_Prov"].astype(int)
    g = g.set_index("Code_Prov").loc[codes]
    g_m = g.to_crs(epsg=3857)
    g_m["geometry"] = g_m.geometry.simplify(2000, preserve_topology=True)
    n = len(codes)
    W = np.zeros((n, n))
    land_links = []
    for i, ci in enumerate(codes):
        gi = g_m.loc[ci].geometry
        for j in range(i + 1, n):
            cj = codes[j]
            d = gi.distance(g_m.loc[cj].geometry)
            if d < 1000:
                W[i, j] = W[j, i] = 1
                land_links.append((int(ci), int(cj)))
    xy = np.column_stack([g_m.centroid.x.values, g_m.centroid.y.values])
    dist = np.sqrt(((xy[:, None, :] - xy[None, :, :]) ** 2).sum(axis=2))
    isolates_before = [int(c) for i, c in enumerate(codes) if W[i].sum() == 0]
    W, notes = connect_isolates(W, dist, codes)
    meta = {
        "rule": "land distance < 1 km after 2 km simplify; isolates get 1-nn centroid",
        "land_links": land_links,
        "isolates_before_knn": isolates_before,
        "knn_links_added": [
            {"from": a, "to": b, "metres": round(d, 1)} for a, b, d in notes
        ],
        "n_links": int(W.sum() / 2),
        "degree": {int(c): int(W[i].sum()) for i, c in enumerate(codes)},
    }
    return W, meta


def build_island(codes: list[int], pulau: dict[int, str]) -> np.ndarray:
    n = len(codes)
    W = np.zeros((n, n))
    for i, ci in enumerate(codes):
        for j, cj in enumerate(codes):
            if i == j:
                continue
            if pulau[ci] == pulau[cj]:
                W[i, j] = 1
    return W


def double_demean(df: pd.DataFrame, cols: list[str], idcol: str, tcol: str) -> pd.DataFrame:
    d = df.copy()
    for c in cols:
        d[c] = (
            d[c]
            - d.groupby(idcol)[c].transform("mean")
            - d.groupby(tcol)[c].transform("mean")
            + d[c].mean()
        )
    return d


def stack_WX(X: np.ndarray, W: np.ndarray, T: int) -> np.ndarray:
    """Apply W to each year's block of X (NT x K)."""
    n = W.shape[0]
    k = X.shape[1]
    out = np.zeros_like(X)
    for t in range(T):
        sl = slice(t * n, (t + 1) * n)
        out[sl] = W @ X[sl]
    return out


def apply_W(v: np.ndarray, W: np.ndarray, T: int) -> np.ndarray:
    n = W.shape[0]
    out = np.empty_like(v)
    for t in range(T):
        sl = slice(t * n, (t + 1) * n)
        out[sl] = W @ v[sl]
    return out


def logdet_I_rhoW(rho: float, W: np.ndarray) -> float:
    n = W.shape[0]
    sign, logabs = slogdet(np.eye(n) - rho * W)
    if sign <= 0:
        return -1e12
    return float(logabs)


def sar_nll(rho, y, X, W, T):
    rho = float(np.asarray(rho).reshape(-1)[0])
    n = W.shape[0]
    if not (-0.99 < rho < 0.99):
        return 1e12
    ld = logdet_I_rhoW(rho, W)
    if ld < -1e10:
        return 1e12
    Ay = y - rho * apply_W(y, W, T)
    b, *_ = np.linalg.lstsq(X, Ay, rcond=None)
    e = Ay - X @ b
    nt = len(y)
    sig2 = float(e @ e / nt)
    if sig2 <= 1e-12:
        return 1e12
    nll = 0.5 * nt * np.log(2 * np.pi * sig2) - T * ld + 0.5 * nt
    return nll


def fit_spatial(y, X, W, T, sdm=False, Xraw=None):
    """ML SAR (sdm=False) or SDM (WX appended from Xraw, pre-demean WX)."""
    if sdm:
        assert Xraw is not None
        X = np.column_stack([X, stack_WX(Xraw, W, T)])
    # drop collinear columns after demeaning (year FE already removed a direction)
    ok = np.where(np.std(X, axis=0) > 1e-10)[0]
    X = X[:, ok]
    res = minimize(lambda r: sar_nll(r, y, X, W, T), x0=[0.1],
                   method="L-BFGS-B", bounds=[(-0.95, 0.95)])
    rho = float(res.x[0])
    Ay = y - rho * apply_W(y, W, T)
    b, *_ = np.linalg.lstsq(X, Ay, rcond=None)
    e = Ay - X @ b
    nt, k = X.shape
    sig2 = float(e @ e / nt)
    ll = -float(res.fun)
    # numerical SE for rho via finite-difference Hessian of concentrated nll
    eps = 1e-4
    f0 = sar_nll(rho, y, X, W, T)
    fp = sar_nll(rho + eps, y, X, W, T)
    fm = sar_nll(rho - eps, y, X, W, T)
    hess = (fp - 2 * f0 + fm) / (eps ** 2)
    se_rho = float(np.sqrt(1 / hess)) if hess > 0 else np.nan
    # OLS-style SE for beta | rho (conditional; understates joint uncertainty)
    XtX_inv = np.linalg.pinv(X.T @ X)
    n = W.shape[0]
    meat = np.zeros((k, k))
    for i in range(n):
        idx = [t * n + i for t in range(T)]
        s = X[idx].T @ e[idx]
        meat += np.outer(s, s)
    dfc = (n / (n - 1)) * ((nt - 1) / max(nt - k - n, 1))
    V = dfc * XtX_inv @ meat @ XtX_inv
    se_b = np.sqrt(np.maximum(np.diag(V), 0))
    z_rho = rho / se_rho if se_rho and se_rho == se_rho else np.nan
    return {
        "rho": rho, "se_rho": se_rho, "z_rho": z_rho,
        "ll": ll, "sig2": sig2, "N": nt, "k": k, "ok": ok,
        "beta": b, "se_b": se_b, "X": X, "e": e, "converged": bool(res.success),
    }


def stars(z):
    if z != z:
        return ""
    a = abs(z)
    if a >= 2.576:
        return "***"
    if a >= 1.96:
        return "**"
    if a >= 1.645:
        return "*"
    return ""


def effects(W, rho, beta_k, theta_k=0.0):
    n = W.shape[0]
    S = np.linalg.inv(np.eye(n) - rho * W) @ (np.eye(n) * beta_k + W * theta_k)
    total = float(S.sum(axis=1).mean())
    direct = float(np.diag(S).mean())
    return {"direct": direct, "indirect": total - direct, "total": total}


def moran_I(z, W):
    z = z - z.mean()
    den = z @ z
    if den <= 0:
        return np.nan
    return float((z @ (W @ z)) / den)


def twfe_resid(df, ycol, xcols, idcol, tcol):
    d = double_demean(df, [ycol] + xcols, idcol, tcol)
    y = d[ycol].to_numpy()
    X = d[xcols].to_numpy()
    b, *_ = np.linalg.lstsq(X, y, rcond=None)
    return y - X @ b, b


def main():
    peta = pd.read_csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv")
    peta = peta.dropna(subset=["Code_Prov", "Pulau"]).drop_duplicates("Code_Prov")
    peta["Code_Prov"] = peta["Code_Prov"].astype(int)
    pulau_map = dict(zip(peta.Code_Prov, peta.Pulau))

    dta = pd.read_stata("01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                        convert_categoricals=False)
    dta["Code_Prov"] = dta["Code_Prov"].astype(int)
    dta = dta.merge(peta[["Code_Prov", "Pulau"]], on="Code_Prov", how="left")
    assert dta["Pulau"].notna().all()
    dta = dta.sort_values(["Year", "Code_Prov"]).reset_index(drop=True)

    codes = sorted(dta.Code_Prov.unique())
    years = sorted(dta.Year.unique())
    n, T = len(codes), len(years)
    assert len(dta) == n * T, (len(dta), n, T)

    Wq_raw, qmeta = build_queen(codes)
    Wi_raw = build_island(codes, pulau_map)
    Wq = row_standardize(Wq_raw)
    Wi = row_standardize(Wi_raw)

    # persist W
    wtab = []
    for i, ci in enumerate(codes):
        for j, cj in enumerate(codes):
            if Wq_raw[i, j] == 1:
                wtab.append({"W": "queen", "i": ci, "j": cj})
            if Wi_raw[i, j] == 1:
                wtab.append({"W": "island", "i": ci, "j": cj})
    pd.DataFrame(wtab).to_csv(OUT / "spatial_W_links.csv", index=False)
    (OUT / "spatial_W_queen_meta.json").write_text(json.dumps(qmeta, indent=2))

    # FE2W residuals for Moran
    dta = dta.copy()
    resid, b_fe2w = twfe_resid(dta, "logtfp_it", XVARS, "Code_Prov", "Year")
    dta["e_fe2w"] = resid
    moran_rows = []
    for wname, W in [("queen", Wq), ("island", Wi)]:
        for yr in years:
            z = dta.loc[dta.Year == yr, "e_fe2w"].to_numpy()
            moran_rows.append({"W": wname, "Year": int(yr), "I": moran_I(z, W)})
        # pooled: average of yearly I (same N each year)
        moran_rows.append({
            "W": wname, "Year": "pooled_mean",
            "I": float(np.mean([r["I"] for r in moran_rows if r["W"] == wname and r["Year"] != "pooled_mean"])),
        })
    moran = pd.DataFrame(moran_rows)
    print("Moran I on FE2W residuals")
    print(moran.to_string(index=False))

    dd = double_demean(dta, ["logtfp_it"] + XVARS, "Code_Prov", "Year")
    y = dd["logtfp_it"].to_numpy()
    X = dd[XVARS].to_numpy()
    Xraw = X.copy()

    names_sar = list(XVARS)
    names_sdm = XVARS + [f"W_{v}" for v in XVARS]

    fits = []
    effect_rows = []
    coef_rows = []

    for wname, W in [("queen", Wq), ("island", Wi)]:
        for model, sdm in [("SAR", False), ("SDM", True)]:
            fit = fit_spatial(y, X, W, T, sdm=sdm, Xraw=Xraw)
            names = names_sdm if sdm else names_sar
            names = [names[i] for i in fit["ok"]]
            print(f"\n{model} {wname}: rho={fit['rho']:.3f} (SE {fit['se_rho']:.3f}) "
                  f"ll={fit['ll']:.1f} conv={fit['converged']}")
            zrho = fit["z_rho"]
            coef_rows.append({
                "W": wname, "model": model, "var": "rho",
                "b": fit["rho"], "se": fit["se_rho"], "star": stars(zrho),
            })
            for nm, b, se in zip(names, fit["beta"], fit["se_b"]):
                z = b / se if se > 0 else np.nan
                coef_rows.append({
                    "W": wname, "model": model, "var": nm,
                    "b": float(b), "se": float(se), "star": stars(z),
                })
                print(f"  {nm:16s} {b:8.4f} ({se:.4f}) {stars(z)}")

            # effects for pillars (SAR: theta=0; SDM: matching W_ var)
            bmap = dict(zip(names, fit["beta"]))
            for v in PILLARS:
                theta = bmap.get(f"W_{v}", 0.0) if sdm else 0.0
                beta = bmap.get(v, np.nan)
                if beta != beta:
                    continue
                ef = effects(W, fit["rho"], beta, theta)
                effect_rows.append({"W": wname, "model": model, "var": v, **ef})

            fits.append({
                "W": wname, "model": model, "rho": fit["rho"],
                "se_rho": fit["se_rho"], "ll": fit["ll"],
                "sig2": fit["sig2"], "k": fit["k"], "converged": fit["converged"],
            })

    coef = pd.DataFrame(coef_rows)
    effects_df = pd.DataFrame(effect_rows)
    fit_df = pd.DataFrame(fits)

    # LR: SDM vs SAR (same W)
    lr_rows = []
    for wname in ["queen", "island"]:
        ll_sar = fit_df.loc[(fit_df.W == wname) & (fit_df.model == "SAR"), "ll"].iloc[0]
        ll_sdm = fit_df.loc[(fit_df.W == wname) & (fit_df.model == "SDM"), "ll"].iloc[0]
        k_sar = fit_df.loc[(fit_df.W == wname) & (fit_df.model == "SAR"), "k"].iloc[0]
        k_sdm = fit_df.loc[(fit_df.W == wname) & (fit_df.model == "SDM"), "k"].iloc[0]
        lr = 2 * (ll_sdm - ll_sar)
        df = int(k_sdm - k_sar)
        from math import erf
        # chi2 survival approx via scipy
        from scipy.stats import chi2
        p = float(chi2.sf(lr, df))
        lr_rows.append({"W": wname, "LR_SDM_vs_SAR": lr, "df": df, "p": p})
        print(f"LR SDM vs SAR ({wname}): {lr:.2f} on {df} df, p={p:.4f}")

    lr_df = pd.DataFrame(lr_rows)

    # FE2W non-spatial coefficients for the comparison table
    fe_rows = [{"W": "none", "model": "FE2W", "var": v,
                "b": float(b_fe2w[i]), "se": np.nan, "star": ""}
               for i, v in enumerate(XVARS)]

    # island degrees
    deg = pd.DataFrame({
        "Code_Prov": codes,
        "Pulau": [pulau_map[c] for c in codes],
        "queen_degree": [int(Wq_raw[i].sum()) for i in range(n)],
        "island_degree": [int(Wi_raw[i].sum()) for i in range(n)],
    })

    with pd.ExcelWriter(OUT / "SAR_SDM TFP.xlsx") as xw:
        coef.to_excel(xw, sheet_name="coefficients", index=False)
        effects_df.to_excel(xw, sheet_name="effects", index=False)
        fit_df.to_excel(xw, sheet_name="fit", index=False)
        lr_df.to_excel(xw, sheet_name="LR_SDM_vs_SAR", index=False)
        moran.to_excel(xw, sheet_name="Moran_FE2W", index=False)
        deg.to_excel(xw, sheet_name="W_degree", index=False)
        pd.DataFrame(fe_rows).to_excel(xw, sheet_name="FE2W_point", index=False)

    coef.to_csv(OUT / "spatial_sar_sdm_coefficients.csv", index=False)
    effects_df.to_csv(OUT / "spatial_sar_sdm_effects.csv", index=False)
    moran.to_csv(OUT / "spatial_moran_fe2w.csv", index=False)
    print("\nWrote", OUT / "SAR_SDM TFP.xlsx")
    print("Queen isolates before knn:", qmeta["isolates_before_knn"])
    print("knn links:", qmeta["knn_links_added"])


if __name__ == "__main__":
    main()
