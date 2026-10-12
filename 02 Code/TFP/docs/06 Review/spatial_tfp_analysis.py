# ==============================================================================
# spatial_tfp_analysis.py — Phase 1 (spatial contrast) + Phase 3 (mean-play)
#
# Companion to "TFP construction and vintage mismatch.md" in this folder.
# Run from project root:  python3 "02 Code/TFP/docs/06 Review/spatial_tfp_analysis.py"
#
# Phase 1 (production side, vintage B: b1=0.401899 b2=0.147184, 2017-2024):
#   Track A: one national technology applied to island aggregates and provinces.
#            Island residual index; province CRS trends (from Hasil Estimasi TFP).
#   Track B: TWFE Cobb-Douglas re-estimated INSIDE each island. Levels are then
#            NOT comparable across islands; only the elasticities are contrasted.
#
# Phase 3 (determinant side, on the Stata DV = vintage C, labelled as such):
#   - Replicate Stata FE2W (validation against Determinan TFP Tables).
#   - Between regression on 34 province means (the "map").
#   - Mean-play: equalize connectivity/HR/institution means to the national and
#     island mean; report how much of the between-island TFP gap closes.
#   - Leave-one-island-out FE2W; island-stratified FE2W (Sumatera, Jawa).
#
# Outputs: CSVs next to this script (prefix spatial_ / meanplay_).
# ==============================================================================
import numpy as np
import pandas as pd

ROOT = "."
OUT = "02 Code/TFP/docs/06 Review"

B1_NAT, B2_NAT = 0.401899, 0.147184  # vintage B, parameter_terpilih.rds (modal_riil)

# ------------------------------------------------------------------ data ----
src = pd.read_excel(
    "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx",
    sheet_name="Sheet1")
tk_cols = [c for c in src.columns if str(c).endswith("_TenagaKerja")]
assert len(tk_cols) == 17
src["L"] = src[tk_cols].sum(axis=1)

peta = pd.read_csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv")[
    ["Code_Prov", "Pulau"]].dropna().drop_duplicates()

est = src.merge(peta, on="Code_Prov")
est = est[(est["Year"] <= 2024) & (est["L"] > 0)].copy()   # vintage B sample
est["logY"] = np.log(est["9_ADHK"])
est["logK"] = np.log(est["4_ADHK"])
est["logL"] = np.log(est["L"])
assert len(est) == 272, len(est)


def twfe(df, ycol, xcols, cluster):
    """Two-way FE via within-province demeaning + year dummies, cluster-robust SE."""
    d = df.copy()
    yrs = sorted(d["Year"].unique())[1:]
    for y in yrs:
        d[f"yr{y}"] = (d["Year"] == y).astype(float)
    cols = xcols + [f"yr{y}" for y in yrs]
    for c in [ycol] + cols:
        d[c + "_w"] = d[c] - d.groupby(cluster)[c].transform("mean")
    X = d[[c + "_w" for c in cols]].to_numpy()
    yv = d[ycol + "_w"].to_numpy()
    XtX_inv = np.linalg.pinv(X.T @ X)
    beta = XtX_inv @ X.T @ yv
    resid = yv - X @ beta
    # cluster-robust (CR1) sandwich, df correction as in Stata xtreg, fe vce(cluster)
    G = d[cluster].nunique()
    n, k = X.shape
    meat = np.zeros((k, k))
    for _, idx in d.groupby(cluster).indices.items():
        Xg, ug = X[idx], resid[idx]
        s = Xg.T @ ug
        meat += np.outer(s, s)
    dfc = (G / (G - 1)) * ((n - 1) / (n - k - G))  # absorb G province means
    V = dfc * XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(V))
    return dict(zip(cols, beta)), dict(zip(cols, se)), len(d), G


# ================================================================= PHASE 1 ==
print("=" * 78)
print("PHASE 1 — TRACK A: national technology applied spatially")
print("=" * 78)

# national check: must reproduce vintage B
b, se, n, g = twfe(est, "logY", ["logK", "logL"], "Code_Prov")
print(f"national TWFE check: b1={b['logK']:.6f} (SE {se['logK']:.4f}) "
      f"b2={b['logL']:.6f} (SE {se['logL']:.4f}) N={n} G={g}")

# island aggregate residual under NATIONAL b's
agg = (est.groupby(["Pulau", "Year"])
          .agg(Y=("9_ADHK", "sum"), K=("4_ADHK", "sum"), L=("L", "sum"),
               n_prov=("Code_Prov", "nunique")).reset_index())
agg["logtfp_isl"] = np.log(agg["Y"]) - B1_NAT * np.log(agg["K"]) - B2_NAT * np.log(agg["L"])
base = agg[agg["Year"] == 2017].set_index("Pulau")["logtfp_isl"]
agg["indeks_100"] = 100 * np.exp(agg["logtfp_isl"] - agg["Pulau"].map(base))
trackA_island = agg.pivot(index="Year", columns="Pulau", values="indeks_100").round(2)
print("\nTrack A island residual index (2017=100, national b1,b2):")
print(trackA_island.to_string())
agg.to_csv(f"{OUT}/spatial_trackA_island_residual.csv", index=False)

# island CAGR of the residual 2017-2024
cagr = (agg.pivot(index="Year", columns="Pulau", values="logtfp_isl")
           .agg(lambda s: 100 * (s.loc[2024] - s.loc[2017]) / 7))
print("\nTrack A island residual growth 2017-2024 (log pts/yr x100):")
print(cagr.round(2).sort_values(ascending=False).to_string())

# province layer: reuse published tren_provinsi (CRS trend is the rankable one)
tren = pd.read_excel("01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx",
                     sheet_name="tren_provinsi")
tren = tren.merge(peta, on="Code_Prov")
prov_isl = (tren.groupby("Pulau")
                .agg(n=("Code_Prov", "count"),
                     tren_crs_med=("tren_pp_thn_crs", "median"),
                     tren_crs_min=("tren_pp_thn_crs", "min"),
                     tren_crs_max=("tren_pp_thn_crs", "max"))
                .sort_values("tren_crs_med", ascending=False))
print("\nTrack A province CRS residual trends grouped by island (pp/yr):")
print(prov_isl.round(2).to_string())
tren.to_csv(f"{OUT}/spatial_trackA_province_trends.csv", index=False)

print()
print("=" * 78)
print("PHASE 1 — TRACK B: island-specific Cobb-Douglas (sensitivity only)")
print("=" * 78)
rows = []
for isl, d in est.groupby("Pulau"):
    bi, sei, ni, gi = twfe(d, "logY", ["logK", "logL"], "Code_Prov")
    rows.append({"Pulau": isl, "n_prov": gi, "N": ni,
                 "b1": bi["logK"], "se_b1": sei["logK"],
                 "b2": bi["logL"], "se_b2": sei["logL"],
                 "RTS": bi["logK"] + bi["logL"]})
trackB = pd.DataFrame(rows).sort_values("b1", ascending=False)
nat_row = pd.DataFrame([{"Pulau": "NASIONAL", "n_prov": g, "N": n,
                         "b1": b["logK"], "se_b1": se["logK"],
                         "b2": b["logL"], "se_b2": se["logL"],
                         "RTS": b["logK"] + b["logL"]}])
trackB = pd.concat([nat_row, trackB], ignore_index=True)
print(trackB.round(3).to_string(index=False))
print("\nNOTE: cluster counts per island are 3-10; SEs are indicative. Levels of")
print("log A are NOT comparable across islands in Track B (different b1, b2).")
trackB.to_csv(f"{OUT}/spatial_trackB_island_elasticities.csv", index=False)

# ================================================================= PHASE 3 ==
print()
print("=" * 78)
print("PHASE 3 — mean-play on the determinant DV (vintage C, as regressed in Stata)")
print("=" * 78)
dta = pd.read_stata("01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                    convert_categoricals=False)
dta = dta.merge(peta, on="Code_Prov")
XVARS = ["idx_hr", "idx_inst", "idx_conn", "ln_wage",
         "IKLH_Prov", "Hijau_Prov", "Biru_Prov"]

# validation: replicate Stata FE2W (Determinan TFP Tables - all models.csv)
bv, sev, nv, gv = twfe(dta, "logtfp_it", XVARS, "Code_Prov")
print("FE2W replication vs Stata (idx_inst should be 0.0488 / SE 0.0299):")
for v in ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]:
    print(f"  {v:10s} b={bv[v]: .4f}  SE={sev[v]:.4f}")

# between regression: 34 province means (the map)
pm = dta.groupby(["Code_Prov", "Pulau"])[["logtfp_it"] + XVARS].mean().reset_index()
Xb = np.column_stack([np.ones(len(pm))] + [pm[v] for v in XVARS])
yb = pm["logtfp_it"].to_numpy()
bb = np.linalg.pinv(Xb.T @ Xb) @ Xb.T @ yb
fit = Xb @ bb
r2b = 1 - ((yb - fit) ** 2).sum() / ((yb - yb.mean()) ** 2).sum()
resb = yb - fit
seb = np.sqrt(np.diag(((resb ** 2).sum() / (len(pm) - len(bb)))
                      * np.linalg.pinv(Xb.T @ Xb)))
between = pd.DataFrame({"var": ["const"] + XVARS, "b": bb, "se": seb})
print(f"\nBetween regression on 34 province means: R2 = {r2b:.3f}")
print(between.round(4).to_string(index=False))
between.to_csv(f"{OUT}/meanplay_between_regression.csv", index=False)

# island means of DV and pillar means
isl_means = pm.groupby("Pulau")[["logtfp_it", "idx_hr", "idx_inst", "idx_conn",
                                 "ln_wage"]].mean().sort_values("logtfp_it",
                                                                ascending=False)
print("\nIsland means (DV and pillar means, vintage C DV):")
print(isl_means.round(3).to_string())

# mean-play: set each pillar's province mean to the national mean (=0 for z
# indexes); predicted change = -b_between * m_i. Aggregate by island.
CONN_B = float(between.loc[between["var"] == "idx_conn", "b"].iloc[0])
CRE_CONN = 0.4180  # published CRE m_idx_conn, Determinan TFP Tables - static.rtf
plays = []
for v, bcoef in [("idx_conn", CONN_B), ("idx_hr", float(between.loc[between['var']=='idx_hr','b'].iloc[0])),
                 ("idx_inst", float(between.loc[between['var']=='idx_inst','b'].iloc[0]))]:
    for isl, d in pm.groupby("Pulau"):
        gap = d["logtfp_it"].mean() - pm["logtfp_it"].mean()
        delta = -bcoef * d[v].mean()          # move island's mean of v to 0
        plays.append({"pillar": v, "b_between": bcoef, "Pulau": isl,
                      "tfp_gap_vs_nat": gap, "delta_if_equalized": delta,
                      "share_of_gap_closed": np.nan if abs(gap) < 1e-9
                      else delta / (-gap)})
meanplay = pd.DataFrame(plays)
print("\nMean-play: equalize each pillar's island mean to the national mean")
print("(between coefficients; CRE m_idx_conn published = 0.418 for comparison)")
print(meanplay.round(3).to_string(index=False))
meanplay.to_csv(f"{OUT}/meanplay_equalize_island_means.csv", index=False)

# leave-one-island-out FE2W
rows = []
for isl in sorted(dta["Pulau"].unique()):
    d = dta[dta["Pulau"] != isl]
    bl, sl, nl, gl = twfe(d, "logtfp_it", XVARS, "Code_Prov")
    rows.append({"dropped": isl, "G": gl,
                 **{v: bl[v] for v in ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]},
                 **{"se_" + v: sl[v] for v in ["idx_inst", "idx_conn"]}})
loio = pd.DataFrame(rows)
print("\nLeave-one-island-out FE2W (pillar coefficients):")
print(loio.round(4).to_string(index=False))
loio.to_csv(f"{OUT}/meanplay_leave_one_island_out.csv", index=False)

# island-stratified FE2W where N_g allows
print("\nIsland-stratified FE2W (only Sumatera and Jawa have enough provinces):")
for isl in ["Sumatera", "Jawa"]:
    d = dta[dta["Pulau"] == isl]
    bs, ss, ns, gs = twfe(d, "logtfp_it", XVARS, "Code_Prov")
    print(f"  {isl} (G={gs}, N={ns}): " +
          "  ".join(f"{v}={bs[v]: .3f}" for v in
                    ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]))

print("\ndone; CSVs written to", OUT)
