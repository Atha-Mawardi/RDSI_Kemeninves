"""Spatial maps for the TFP review: CRS vs real (DRS) residual, scale gap,
trend, policy quadrants, and pillar focus.

TFP layers use vintage B (Hasil Estimasi TFP.xlsx, data_tfp, 2017-2024,
b1=0.401899 b2=0.147184 DRS; b1_crs=0.451462 CRS). Pillar focus uses the
Stata determinant data (vintage C DV) and the between-regression
coefficients from meanplay_between_regression.csv. The two vintages are
never mixed inside one number.

Outputs:
  01 Data/TFP/output/exploratory/maps/*.png
  02 Code/TFP/docs/06 Review/map_master_table.csv

Run from repo root: python3 "02 Code/TFP/docs/06 Review/maps_tfp_spatial.py"
"""
import json
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.patches import Patch

ROOT = "."
REV = f"{ROOT}/02 Code/TFP/docs/06 Review"
OUT = f"{ROOT}/01 Data/TFP/output/exploratory/maps"
import os
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- vintage B
d = pd.read_excel(
    f"{ROOT}/01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx",
    sheet_name="data_tfp").dropna(subset=["logtfp_it"])
d["Code_Prov"] = d["Code_Prov"].astype(int)

snap = (d[d.Year >= 2022]
        .groupby(["Code_Prov", "Pre_Prov", "Pulau"])
        .agg(drs=("logtfp_it", "mean"), crs=("logtfp_it_crs", "mean"),
             logY=("log_ADHK_Tot", "mean")).reset_index())
snap["z_drs"] = (snap.drs - snap.drs.mean()) / snap.drs.std()
snap["z_crs"] = (snap.crs - snap.crs.mean()) / snap.crs.std()
snap["scale_gap"] = snap.z_drs - snap.z_crs


def slope(g):
    x = g.Year - g.Year.mean()
    return 100 * (x * (g.logtfp_it_crs - g.logtfp_it_crs.mean())).sum() / (x * x).sum()


tr = (d.groupby(["Code_Prov"]).apply(slope, include_groups=False)
      .rename("crs_trend").reset_index())
snap = snap.merge(tr, on="Code_Prov")

lm, tm = snap.z_crs.median(), snap.crs_trend.median()
QUADS = ["Priority", "Catching up", "Slipping", "Leader"]


def quad(r):
    if r.z_crs >= lm and r.crs_trend >= tm:
        return "Leader"
    if r.z_crs >= lm:
        return "Slipping"
    if r.crs_trend >= tm:
        return "Catching up"
    return "Priority"


snap["quadrant"] = snap.apply(quad, axis=1)

# ------------------------------------------------- pillar focus (vintage C)
s = pd.read_stata(f"{ROOT}/01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                  convert_categoricals=False)
s["Code_Prov"] = s["Code_Prov"].astype(int)
pm = (s.groupby("Code_Prov")[["idx_hr", "idx_inst", "idx_conn", "ln_wage",
                              "logtfp_it"]].mean().reset_index())
bet = pd.read_csv(f"{REV}/meanplay_between_regression.csv").set_index("var")["b"]
for p in ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]:
    pm[f"contrib_{p}"] = bet[p if p != "ln_wage" else "ln_wage"] * (
        pm[p] - pm[p].mean())
pm["tfp_gap_c"] = pm.logtfp_it - pm.logtfp_it.mean()
# focus = the reliable lever (conn, inst) with the largest shortfall
pm["focus"] = pm[["contrib_idx_conn", "contrib_idx_inst"]].idxmin(axis=1).map(
    {"contrib_idx_conn": "Connectivity", "contrib_idx_inst": "Institutions"})
# provinces already above national mean on both levers: no between-lever
pm.loc[(pm.contrib_idx_conn > 0) & (pm.contrib_idx_inst > 0),
       "focus"] = "Above mean on both"

master = snap.merge(pm, on="Code_Prov", how="left")

# ------------------------------------------------------------------- GADM
g = gpd.read_file(f"{REV}/assets/gadm41_IDN_1.json")[["NAME_1", "geometry"]]
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
g["Code_Prov"] = g.NAME_1.map(NAME2CODE)
assert g.Code_Prov.notna().all()
gm = g.merge(master, on="Code_Prov", how="left")
assert gm.z_crs.notna().all(), "unmatched provinces"
gm = gm.to_crs(epsg=3857)  # metric, keeps Indonesia proportions reasonable


def choro(col, title, sub, fname, cmap="viridis", diverging=False,
          fmt="{:+.1f}"):
    fig, ax = plt.subplots(figsize=(11, 5.2))
    if diverging:
        vmax = max(abs(gm[col].min()), abs(gm[col].max()))
        norm = mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax)
        gm.plot(column=col, cmap=cmap, norm=norm, ax=ax,
                edgecolor="white", linewidth=0.4, legend=True,
                legend_kwds={"shrink": 0.6})
    else:
        gm.plot(column=col, cmap=cmap, ax=ax, edgecolor="white",
                linewidth=0.4, legend=True, legend_kwds={"shrink": 0.6})
    ax.set_title(title, fontsize=13, loc="left", fontweight="bold")
    ax.text(0, 1.01, sub, transform=ax.transAxes, fontsize=8.5, color="0.35")
    ax.set_axis_off()
    fig.tight_layout()
    fig.savefig(f"{OUT}/{fname}", dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", fname)


choro("z_crs",
      "TFP efisiensi (CRS, per pekerja) — level 2022–24, z-score",
      "Vintage B, b1_crs=0.451; residual per pekerja, sebanding antarprovinsi. Sumber: Hasil Estimasi TFP.xlsx",
      "map1_crs_level.png", cmap="viridis")
choro("z_drs",
      "TFP 'riil' (DRS) — level 2022–24, z-score",
      "Vintage B, b1=0.402 b2=0.147 (RTS 0.55). Korelasi 0.98 dengan ukuran ekonomi: peta ini ≈ peta skala.",
      "map2_drs_level.png", cmap="viridis")
choro("scale_gap",
      "Selisih DRS − CRS (z) = kebocoran skala, bukan kedalaman masalah",
      "Positif: provinsi tampak lebih baik karena besar (Jawa). Negatif: tampak lebih buruk karena kecil (Kaltara, Papua Barat).",
      "map3_scale_gap.png", cmap="RdBu_r", diverging=True)
choro("crs_trend",
      "Tren TFP CRS 2017–24 (pp/tahun)",
      "Slope OLS log TFP CRS per provinsi. Vintage B.",
      "map4_crs_trend.png", cmap="RdBu_r", diverging=True)

# quadrant map (categorical)
qcolors = {"Priority": "#c23b22", "Catching up": "#e8a33d",
           "Slipping": "#7f9fc4", "Leader": "#2e6f5e"}
fig, ax = plt.subplots(figsize=(11, 5.2))
gm.plot(color=gm.quadrant.map(qcolors), ax=ax, edgecolor="white",
        linewidth=0.4)
ax.legend(handles=[Patch(facecolor=qcolors[q],
                         label={"Priority": "Prioritas (level & tren rendah)",
                                "Catching up": "Mengejar (level rendah, tren tinggi)",
                                "Slipping": "Tergelincir (level tinggi, tren rendah)",
                                "Leader": "Unggul (level & tren tinggi)"}[q])
                   for q in QUADS], loc="lower left", fontsize=8.5,
          frameon=False)
ax.set_title("Kuadran kebijakan: level TFP CRS × tren CRS (median split)",
             fontsize=13, loc="left", fontweight="bold")
ax.text(0, 1.01, "Kedalaman masalah dibaca dari sini — bukan dari selisih DRS−CRS. Vintage B, 2017–24.",
        transform=ax.transAxes, fontsize=8.5, color="0.35")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(f"{OUT}/map5_quadrant.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("saved map5_quadrant.png")

# pillar focus map (categorical)
fcolors = {"Connectivity": "#8455a1", "Institutions": "#c98a19",
           "Above mean on both": "#b9c2c9"}
fig, ax = plt.subplots(figsize=(11, 5.2))
gm.plot(color=gm.focus.map(fcolors), ax=ax, edgecolor="white", linewidth=0.4)
ax.legend(handles=[Patch(facecolor=v, label={
    "Connectivity": "Konektivitas (koef. antarprovinsi 0.43)",
    "Institutions": "Institusi (koef. 0.17)",
    "Above mean on both": "Di atas rata-rata nasional pada keduanya"}[k])
    for k, v in fcolors.items()], loc="lower left", fontsize=8.5,
    frameon=False)
ax.set_title("Pilar fokus per provinsi — kekurangan terbesar pada tuas antarprovinsi yang teruji",
             fontsize=13, loc="left", fontweight="bold")
ax.text(0, 1.01, "Koefisien between-regression × selisih rata-rata pilar provinsi vs nasional. HR & upah: koefisien ≈ 0, tidak dipetakan. DV vintage C.",
        transform=ax.transAxes, fontsize=8.5, color="0.35")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(f"{OUT}/map6_pillar_focus.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("saved map6_pillar_focus.png")

# island (national view): dissolve
gm["geometry"] = gm.geometry.make_valid()
isl = gm.dissolve(by="Pulau", aggfunc={"z_crs": "mean", "crs_trend": "mean"})
fig, axes = plt.subplots(1, 2, figsize=(16, 4.6))
for ax, col, ttl in [(axes[0], "z_crs", "Level TFP CRS (rata-rata z provinsi)"),
                     (axes[1], "crs_trend", "Tren TFP CRS (pp/tahun)")]:
    vmax = max(abs(isl[col].min()), abs(isl[col].max()))
    isl.plot(column=col, cmap="RdBu_r",
             norm=mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax),
             ax=ax, edgecolor="white", linewidth=0.6, legend=True,
             legend_kwds={"shrink": 0.55})
    for idx, row in isl.iterrows():
        c = row.geometry.representative_point()
        ax.annotate(f"{idx}\n{row[col]:+.2f}", (c.x, c.y), ha="center",
                    fontsize=8, fontweight="bold")
    ax.set_title(ttl, fontsize=12, loc="left", fontweight="bold")
    ax.set_axis_off()
fig.suptitle("Tampilan nasional per pulau — vintage B, 2017–24",
             fontsize=13, x=0.01, ha="left", fontweight="bold")
fig.tight_layout()
fig.savefig(f"{OUT}/map0_island_national.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("saved map0_island_national.png")

master.round(4).to_csv(f"{REV}/map_master_table.csv", index=False)
print("saved map_master_table.csv,", len(master), "provinces")
print("\nFocus counts:"); print(master.focus.value_counts().to_string())
print("\nQuadrant x Focus:")
print(pd.crosstab(master.quadrant, master.focus).to_string())
