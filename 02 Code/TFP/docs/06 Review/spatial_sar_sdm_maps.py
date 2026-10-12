"""Choropleths for the SAR/SDM TFP layer. Run from repo root."""
from __future__ import annotations

import json
from pathlib import Path

import geopandas as gpd
import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import Patch
from shapely.geometry import MultiPolygon, Polygon
from shapely.ops import transform as shp_transform

REV = Path("02 Code/TFP/docs/06 Review")
OUT = Path("01 Data/TFP/output/luaran 2/maps")
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
SHORT = {
    11: "Aceh", 12: "Sumut", 13: "Sumbar", 14: "Riau", 15: "Jambi",
    16: "Sumsel", 17: "Bengkulu", 18: "Lampung", 19: "Babel", 21: "Kepri",
    31: "DKI", 32: "Jabar", 33: "Jateng", 34: "DIY", 35: "Jatim", 36: "Banten",
    51: "Bali", 52: "NTB", 53: "NTT", 61: "Kalbar", 62: "Kalteng",
    63: "Kalsel", 64: "Kaltim", 65: "Kaltara", 71: "Sulut", 72: "Sulteng",
    73: "Sulsel", 74: "Sultra", 75: "Gorontalo", 76: "Sulbar",
    81: "Maluku", 82: "Malut", 91: "Pabar", 94: "Papua",
}

XVARS = ["idx_hr", "idx_inst", "idx_conn", "ln_wage",
         "IKLH_Prov", "Hijau_Prov", "Biru_Prov"]


def largest_poly(geom):
    if isinstance(geom, Polygon):
        return geom
    if isinstance(geom, MultiPolygon):
        return max(geom.geoms, key=lambda p: p.area)
    return geom


def double_demean(df, cols, idcol, tcol):
    d = df.copy()
    for c in cols:
        d[c] = (
            d[c]
            - d.groupby(idcol)[c].transform("mean")
            - d.groupby(tcol)[c].transform("mean")
            + d[c].mean()
        )
    return d


peta = pd.read_csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv")
peta = peta.dropna(subset=["Code_Prov", "Pulau"]).drop_duplicates("Code_Prov")
peta["Code_Prov"] = peta["Code_Prov"].astype(int)

dta = pd.read_stata("01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                    convert_categoricals=False)
dta["Code_Prov"] = dta["Code_Prov"].astype(int)
dta = dta.merge(peta[["Code_Prov", "Pulau"]], on="Code_Prov")
dd = double_demean(dta, ["logtfp_it"] + XVARS, "Code_Prov", "Year")
y = dd["logtfp_it"].to_numpy()
X = dd[XVARS].to_numpy()
b, *_ = np.linalg.lstsq(X, y, rcond=None)
dta["e_fe2w"] = y - X @ b

prov = (dta.groupby("Code_Prov")
        .agg(logtfp=("logtfp_it", "mean"),
             e_fe2w=("e_fe2w", "mean"),
             Pulau=("Pulau", "first"))
        .reset_index())
prov["z_tfp"] = (prov.logtfp - prov.logtfp.mean()) / prov.logtfp.std()
prov["z_e"] = (prov.e_fe2w - prov.e_fe2w.mean()) / prov.e_fe2w.std()

# island-block Wy of mean log TFP (the object SAR is using)
codes = sorted(prov.Code_Prov)
pulau = dict(zip(prov.Code_Prov, prov.Pulau))
n = len(codes)
Wi = np.zeros((n, n))
for i, ci in enumerate(codes):
    for j, cj in enumerate(codes):
        if i != j and pulau[ci] == pulau[cj]:
            Wi[i, j] = 1
Wi = Wi / np.maximum(Wi.sum(1, keepdims=True), 1)
zt = dict(zip(prov.Code_Prov, prov.z_tfp))
zvec = np.array([zt[c] for c in codes])
Wy = Wi @ zvec
prov["z_Wy"] = [Wy[codes.index(c)] for c in prov.Code_Prov]

g = gpd.read_file(REV / "assets/gadm41_IDN_1.json")[["NAME_1", "geometry"]]
g["Code_Prov"] = g.NAME_1.map(NAME2CODE).astype(int)
gm = g.merge(prov, on="Code_Prov").to_crs(epsg=3857)

ISLAND_COLORS = {
    "Sumatera": "#3d6b8a",
    "Jawa": "#c45c26",
    "Kalimantan": "#2e6f5e",
    "Sulawesi": "#8455a1",
    "Bali-Nusra": "#c98a19",
    "Maluku-Papua": "#6b4f3a",
}


def choro(col, title, sub, fname, cmap="viridis", diverging=False):
    fig, ax = plt.subplots(figsize=(11, 5.2))
    if diverging:
        vmax = max(abs(gm[col].min()), abs(gm[col].max()), 0.01)
        norm = mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax)
        gm.plot(column=col, cmap=cmap, norm=norm, ax=ax,
                edgecolor="white", linewidth=0.4, legend=True,
                legend_kwds={"shrink": 0.55, "label": col})
    else:
        gm.plot(column=col, cmap=cmap, ax=ax, edgecolor="white",
                linewidth=0.4, legend=True,
                legend_kwds={"shrink": 0.55, "label": col})
    ax.set_title(title, fontsize=13, loc="left", fontweight="bold")
    ax.text(0, 1.01, sub, transform=ax.transAxes, fontsize=8.5, color="0.35")
    ax.set_axis_off()
    fig.tight_layout()
    fig.savefig(OUT / fname, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print("saved", fname)


choro("z_tfp",
      "Rata-rata log residual TFP (z) — geografi Jawa vs timur, vintage C",
      "95,9% varians TFP adalah antarprovinsi. Moran queen I=0,49 hilang setelah FE pulau (I=−0,10, p=0,56).",
      "map_sar_mean_logtfp.png", cmap="RdBu_r", diverging=True)
choro("z_e",
      "Sisa FE2W (z) — 0,7% varians log TFP; bukan objek spillover",
      "Moran 2024 queen I=−0,28 (p=0,09). Jangan meregresi SAR pada leftover two-way.",
      "map_sar_fe2w_residual.png", cmap="RdBu_r", diverging=True)
choro("z_Wy",
      "Wy pulau = rata-rata pulau lain (korelasi dengan dummy pulau 0,98)",
      "Bukan lag tetanggan. ρ panel ≈0,25 pada W ini adalah intersep kelompok, jangan dikutip.",
      "map_sar_island_lag.png", cmap="RdBu_r", diverging=True)

fig, ax = plt.subplots(figsize=(11, 5.2))
gm.plot(color=gm.Pulau.map(ISLAND_COLORS), ax=ax, edgecolor="white", linewidth=0.4)
ax.legend(handles=[Patch(facecolor=c, label=k) for k, c in ISLAND_COLORS.items()],
          loc="lower left", fontsize=8.5, frameon=False, ncol=2)
ax.set_title("W pulau: w_ij=1 jika pulau sama (klik, bukan contiguity)",
             fontsize=13, loc="left", fontweight="bold")
ax.text(0, 1.01,
        "Setelah row-standardise ini = dummy pulau. Queen (batas darat) ρ panel ≈0,05 (ns). Jangan kutip ρ pulau.",
        transform=ax.transAxes, fontsize=8.5, color="0.35")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(OUT / "map_sar_island_W.png", dpi=160, bbox_inches="tight")
plt.close(fig)
print("saved map_sar_island_W.png")

# compact SVG paths for the canvas
gm_s = gm.copy()
gm_s["geometry"] = gm.geometry.simplify(18000, preserve_topology=True)
minx, miny, maxx, maxy = gm_s.total_bounds
pad = (maxx - minx) * 0.02
minx, maxx = minx - pad, maxx + pad
miny, maxy = miny - pad, maxy + pad
W, H = 900.0, 380.0


def xy(x, y):
    return ((x - minx) / (maxx - minx) * W,
            H - (y - miny) / (maxy - miny) * H)


feats = []
for _, r in gm_s.iterrows():
    poly = largest_poly(r.geometry)
    if poly is None or poly.is_empty:
        continue
    coords = list(poly.exterior.coords)
    parts = []
    for i, (x, y) in enumerate(coords):
        px, py = xy(x, y)
        parts.append(f"{'M' if i == 0 else 'L'}{px:.1f},{py:.1f}")
    feats.append({
        "c": int(r.Code_Prov),
        "n": SHORT[int(r.Code_Prov)],
        "p": r.Pulau,
        "zt": round(float(r.z_tfp), 2),
        "ze": round(float(r.z_e), 2),
        "zw": round(float(r.z_Wy), 2),
        "d": "".join(parts) + "Z",
    })

(OUT / "canvas_polygons.json").write_text(json.dumps(feats))
print("n polygons", len(feats), "json bytes", (OUT / "canvas_polygons.json").stat().st_size)
print(prov.sort_values("z_tfp", ascending=False)[
    ["Code_Prov", "Pulau", "z_tfp", "z_e", "z_Wy"]].round(2).to_string(index=False))
