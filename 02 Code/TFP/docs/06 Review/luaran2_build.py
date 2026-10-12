# -*- coding: utf-8 -*-
"""Luaran 2 — peta, grafik, dan tabel (versi terbit).

Semua keluaran ke: 01 Data/TFP/output/luaran 2/
Konvensi warna: merah = buruk/rendah, hijau-biru = baik/tinggi.

Peta DRS/CRS = diagnostik skala dari estimasi TFP (Luaran 1 / lampiran).
Bukan uji RTS baru dan bukan substansi 6.1. Peringkat memakai CRS.

Lapisan TFP: vintage B (Hasil Estimasi TFP.xlsx, data_tfp, 2017-2024;
DRS b1=0.402 b2=0.147; CRS b1=0.451). Pilar: data determinan Stata
(DV vintage C) + koefisien between-regression.

Jalankan dari root: python3 "02 Code/TFP/docs/06 Review/luaran2_build.py"
"""
import os
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.patches import Patch

ROOT = "."
REV = f"{ROOT}/02 Code/TFP/docs/06 Review"
OUT = f"{ROOT}/01 Data/TFP/output/luaran 2"
os.makedirs(OUT, exist_ok=True)

plt.rcParams.update({"font.size": 11, "axes.titlesize": 15,
                     "axes.titleweight": "bold"})

# ------------------------------------------------------------- data vintage B
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
snap["selisih_skala"] = snap.z_drs - snap.z_crs


def slope(g):
    x = g.Year - g.Year.mean()
    return 100 * (x * (g.logtfp_it_crs - g.logtfp_it_crs.mean())).sum() / (x * x).sum()


snap = snap.merge(d.groupby("Code_Prov").apply(slope, include_groups=False)
                  .rename("tren_crs").reset_index(), on="Code_Prov")

lm, tm = snap.z_crs.median(), snap.tren_crs.median()


def quad(r):
    if r.z_crs >= lm and r.tren_crs >= tm:
        return "Unggul"
    if r.z_crs >= lm:
        return "Tergelincir"
    if r.tren_crs >= tm:
        return "Mengejar"
    return "Prioritas"


snap["kuadran"] = snap.apply(quad, axis=1)
QORDER = ["Prioritas", "Mengejar", "Tergelincir", "Unggul"]
QCOL = {"Prioritas": "#c0392b", "Mengejar": "#e59a2f",
        "Tergelincir": "#8fa8c8", "Unggul": "#1e7d5a"}
QLBL = {"Prioritas": "Prioritas — level & tren rendah",
        "Mengejar": "Mengejar — level rendah, tren tinggi",
        "Tergelincir": "Tergelincir — level tinggi, tren rendah",
        "Unggul": "Unggul — level & tren tinggi"}

# ------------------------------------------------ pilar fokus (vintage C, dta)
s = pd.read_stata(f"{ROOT}/01 Data/TFP/Determinan TFP Provinsi BKPM.dta",
                  convert_categoricals=False)
s["Code_Prov"] = s["Code_Prov"].astype(int)
pm = s.groupby("Code_Prov")[["idx_hr", "idx_inst", "idx_conn", "ln_wage",
                             "logtfp_it"]].mean().reset_index()
bet = pd.read_csv(f"{REV}/meanplay_between_regression.csv").set_index("var")["b"]
for p in ["idx_hr", "idx_inst", "idx_conn", "ln_wage"]:
    pm[f"kontrib_{p}"] = bet[p] * (pm[p] - pm[p].mean())
pm["fokus"] = pm[["kontrib_idx_conn", "kontrib_idx_inst"]].idxmin(axis=1).map(
    {"kontrib_idx_conn": "Konektivitas", "kontrib_idx_inst": "Institusi"})
pm.loc[(pm.kontrib_idx_conn > 0) & (pm.kontrib_idx_inst > 0),
       "fokus"] = "Di atas rata-rata nasional"
master = snap.merge(pm, on="Code_Prov", how="left")

# ------------------------------------------------------------------- GADM map
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
gm = g.merge(master, on="Code_Prov").to_crs(epsg=3857)
gm["geometry"] = gm.geometry.make_valid()
assert len(gm) == 34


def peta_kontinu(col, judul, fname, center0=False, cbar_label=""):
    fig, ax = plt.subplots(figsize=(12, 5.4))
    if center0:
        vmax = max(abs(gm[col].min()), abs(gm[col].max()))
        norm = mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax)
    else:
        norm = None
    gm.plot(column=col, cmap="RdYlGn", norm=norm, ax=ax, edgecolor="white",
            linewidth=0.5, legend=True,
            legend_kwds={"shrink": 0.65, "label": cbar_label})
    ax.set_title(judul, loc="left")
    ax.set_axis_off()
    fig.tight_layout()
    fig.savefig(f"{OUT}/{fname}", dpi=200, bbox_inches="tight")
    plt.close(fig)
    print("peta:", fname)


peta_kontinu("z_crs",
             "Level efisiensi TFP (CRS, per pekerja), 2022–2024 — diagnostik peringkat",
             "Peta Level TFP Efisiensi (CRS) Provinsi.png",
             center0=True, cbar_label="z-score (hijau = lebih efisien)")
peta_kontinu("z_drs",
             "Residual produksi tanpa CRS (DRS) — hampir identik dengan ukuran ekonomi",
             "Peta Level TFP Produksi (DRS) Provinsi.png",
             center0=True, cbar_label="z-score (hijau = residual lebih tinggi)")
peta_kontinu("tren_crs", "Tren efisiensi TFP (CRS), 2017–2024",
             "Peta Tren TFP (CRS) Provinsi.png",
             center0=True, cbar_label="pp per tahun (hijau = tumbuh)")

# selisih skala: merah = terangkat skala (menyesatkan ke atas)
fig, ax = plt.subplots(figsize=(12, 5.4))
vmax = max(abs(gm.selisih_skala.min()), abs(gm.selisih_skala.max()))
gm.plot(column="selisih_skala", cmap="RdBu_r",
        norm=mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax),
        ax=ax, edgecolor="white", linewidth=0.5, legend=True,
        legend_kwds={"shrink": 0.65,
                     "label": "merah = terangkat skala · biru = terhukum skala"})
ax.set_title("Ketergantungan skala (diagnostik Luaran 1): z(DRS) − z(CRS)",
             loc="left")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(f"{OUT}/Peta Ketergantungan Skala (DRS-CRS).png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("peta: Peta Ketergantungan Skala (DRS-CRS).png")

# kuadran
fig, ax = plt.subplots(figsize=(12, 5.4))
gm.plot(color=gm.kuadran.map(QCOL), ax=ax, edgecolor="white", linewidth=0.5)
n = gm.kuadran.value_counts()
ax.legend(handles=[Patch(facecolor=QCOL[q],
                         label=f"{QLBL[q]} ({n.get(q, 0)} provinsi)")
                   for q in QORDER],
          loc="lower left", fontsize=10, frameon=False)
ax.set_title("Kuadran kebijakan: level CRS × tren CRS (bukan ranking DRS)",
             loc="left")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(f"{OUT}/Peta Kuadran Kebijakan TFP.png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("peta: Peta Kuadran Kebijakan TFP.png")

# pilar fokus
FCOL = {"Konektivitas": "#7d5ba6", "Institusi": "#c98a19",
        "Di atas rata-rata nasional": "#b9c2c9"}
fig, ax = plt.subplots(figsize=(12, 5.4))
gm.plot(color=gm.fokus.map(FCOL), ax=ax, edgecolor="white", linewidth=0.5)
nf = gm.fokus.value_counts()
ax.legend(handles=[Patch(facecolor=v, label=f"{k} ({nf.get(k, 0)} provinsi)")
                   for k, v in FCOL.items()],
          loc="lower left", fontsize=10, frameon=False)
ax.set_title("Pilar Fokus Investasi per Provinsi", loc="left")
ax.set_axis_off()
fig.tight_layout()
fig.savefig(f"{OUT}/Peta Pilar Fokus Investasi.png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("peta: Peta Pilar Fokus Investasi.png")

# ------------------------------------------------------------------- grafik
# 1. indeks TFP residual per pulau (Track A)
ta = pd.read_csv(f"{REV}/spatial_trackA_island_residual.csv")
fig, ax = plt.subplots(figsize=(10, 5.5))
ICOL = {"Jawa": "#1f77b4", "Sumatera": "#2ca02c", "Kalimantan": "#9467bd",
        "Sulawesi": "#17a2a2", "Bali-Nusra": "#e59a2f",
        "Maluku-Papua": "#c0392b"}
order = (ta[ta.Year == 2024].set_index("Pulau").indeks_100
         .sort_values(ascending=False).index)
for p in order:
    sub = ta[ta.Pulau == p]
    ax.plot(sub.Year, sub.indeks_100, marker="o", lw=2, color=ICOL[p],
            label=f"{p} ({sub.indeks_100.iloc[-1]:.0f})")
ax.axhline(100, color="0.7", lw=1, ls="--")
ax.set_title("Indeks TFP Residual per Pulau (2017 = 100)", loc="left")
ax.set_ylabel("Indeks (2017 = 100)")
ax.set_xlabel("Tahun")
ax.legend(frameon=False, fontsize=10)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig(f"{OUT}/Indeks TFP Residual per Pulau.png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("grafik: Indeks TFP Residual per Pulau.png")

# 2. TFP vs skala ekonomi
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)
for ax, ycol, ttl in [
        (axes[0], "z_drs", "TFP Produksi (DRS)"),
        (axes[1], "z_crs", "TFP Efisiensi (CRS)")]:
    r = master[ycol].corr(master.logY)
    ax.scatter(master.logY, master[ycol],
               c=master.kuadran.map(QCOL), s=55, edgecolor="white")
    b1, b0 = np.polyfit(master.logY, master[ycol], 1)
    xs = np.linspace(master.logY.min(), master.logY.max(), 10)
    ax.plot(xs, b0 + b1 * xs, color="0.4", lw=1.5, ls="--")
    ax.set_title(f"{ttl} — korelasi {r:.2f}", loc="left", fontsize=13)
    ax.set_xlabel("log PDRB riil (ukuran ekonomi)")
    ax.spines[["top", "right"]].set_visible(False)
axes[0].set_ylabel("Level TFP (z-score, 2022–2024)")
fig.suptitle("Mengapa DRS tidak untuk peringkat: korelasi dengan log PDRB",
             fontsize=15, fontweight="bold", x=0.01, ha="left")
fig.tight_layout()
fig.savefig(f"{OUT}/TFP vs Skala Ekonomi (DRS vs CRS).png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("grafik: TFP vs Skala Ekonomi (DRS vs CRS).png")

# 3. peringkat provinsi CRS
rk = master.sort_values("z_crs")
fig, ax = plt.subplots(figsize=(9, 11))
ax.barh(rk.Pre_Prov, rk.z_crs, color=rk.kuadran.map(QCOL), edgecolor="white")
ax.axvline(0, color="0.3", lw=1)
ax.set_title("Peringkat Efisiensi TFP Provinsi (CRS), 2022–2024", loc="left")
ax.set_xlabel("z-score level TFP CRS")
ax.legend(handles=[Patch(facecolor=QCOL[q], label=QLBL[q]) for q in QORDER],
          loc="lower right", fontsize=9.5, frameon=False)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig(f"{OUT}/Peringkat TFP Provinsi (CRS).png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("grafik: Peringkat TFP Provinsi (CRS).png")

# 4. dekomposisi pertumbuhan per kuadran (b regresi vintage B)
gr = d.sort_values(["Code_Prov", "Year"]).copy()
gg = gr.groupby("Code_Prov")
gr["g_Y"] = gg["log_ADHK_Tot"].diff()
gr["kontrib_K"] = 0.401899 * gg["log_pmtb"].diff()
gr["kontrib_L"] = 0.147184 * gg["log_lab_tot"].diff()
gr["kontrib_TFP"] = gr.g_Y - gr.kontrib_K - gr.kontrib_L
dek = (gr.dropna(subset=["g_Y"]).groupby("Code_Prov")
       [["g_Y", "kontrib_K", "kontrib_L", "kontrib_TFP"]].mean() * 100)
dek = dek.reset_index().merge(
    master[["Code_Prov", "Pre_Prov", "Pulau", "kuadran"]], on="Code_Prov")
dq = dek.groupby("kuadran")[["g_Y", "kontrib_K", "kontrib_L",
                             "kontrib_TFP"]].mean().reindex(QORDER)
fig, ax = plt.subplots(figsize=(9.5, 5.5))
x = np.arange(len(QORDER))
bot = np.zeros(len(QORDER))
for col, lbl, c in [("kontrib_K", "Kontribusi modal (PMTB)", "#8fa8c8"),
                    ("kontrib_L", "Kontribusi tenaga kerja", "#e59a2f"),
                    ("kontrib_TFP", "Kontribusi TFP", "#1e7d5a")]:
    ax.bar(x, dq[col], 0.6, bottom=bot, label=lbl, color=c,
           edgecolor="white")
    bot += dq[col].values
ax.scatter(x, dq.g_Y, color="black", zorder=5, s=45,
           label="Pertumbuhan PDRB riil")
for i, v in enumerate(dq.g_Y):
    ax.text(x[i] + 0.34, v, f"{v:.1f}", va="center", fontsize=10)
ax.set_xticks(x)
ax.set_xticklabels(QORDER, fontsize=11)
ax.set_ylabel("pp per tahun, rata-rata 2018–2024")
ax.set_title("Sumber Pertumbuhan per Kuadran: Modal vs Tenaga Kerja vs TFP",
             loc="left")
ax.legend(frameon=False, fontsize=10)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig(f"{OUT}/Dekomposisi Pertumbuhan per Kuadran.png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("grafik: Dekomposisi Pertumbuhan per Kuadran.png")

# 5. upah nasional per tahun (konteks COVID)
w = s.groupby("Year")["ln_wage"].mean().diff().dropna() / s["ln_wage"].std()
fig, ax = plt.subplots(figsize=(9, 4.6))
cols = ["#c0392b" if v < 0 else "#1e7d5a" for v in w.values]
ax.bar(w.index.astype(int).astype(str), w.values, color=cols,
       edgecolor="white")
ax.axhline(0, color="0.3", lw=1)
ax.set_title("Perubahan Upah Nasional per Tahun (satuan SD)", loc="left")
ax.set_ylabel("Perubahan vs tahun sebelumnya (SD)")
ax.set_xlabel("Tahun")
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig(f"{OUT}/Perubahan Upah Nasional per Tahun.png", dpi=200,
            bbox_inches="tight")
plt.close(fig)
print("grafik: Perubahan Upah Nasional per Tahun.png")

# ------------------------------------------- konektivitas tanpa kargo (cek)
pmz = s.groupby("Code_Prov")[["z_jalan_mantap_pct", "z_ln_airport",
                              "idx_hr", "idx_inst", "idx_conn", "ln_wage",
                              "IKLH_Prov", "Hijau_Prov", "Biru_Prov",
                              "logtfp_it"]].mean()
pmz["idx_conn_fix"] = pmz[["z_jalan_mantap_pct", "z_ln_airport"]].mean(axis=1)


def between(dfx, xcols):
    X = np.column_stack([np.ones(len(dfx))] + [dfx[c] for c in xcols])
    y = dfx["logtfp_it"].values
    b, *_ = np.linalg.lstsq(X, y, rcond=None)
    e = y - X @ b
    s2 = (e ** 2).sum() / (len(y) - X.shape[1])
    se = np.sqrt(np.diag(s2 * np.linalg.inv(X.T @ X)))
    r2 = 1 - (e ** 2).sum() / ((y - y.mean()) ** 2).sum()
    return pd.DataFrame({"var": ["konstanta"] + xcols, "b": b, "se": se}), r2


spec = ["idx_hr", "idx_inst", "ln_wage", "IKLH_Prov", "Hijau_Prov",
        "Biru_Prov"]
t_asli, r2_asli = between(pmz, ["idx_conn"] + spec)
t_fix, r2_fix = between(pmz, ["idx_conn_fix"] + spec)
konn = pd.DataFrame({
    "spesifikasi": ["idx_conn asli (jalan + bandara + kargo alokasi PDRB)",
                    "idx_conn_fix (hanya jalan mantap + bandara)"],
    "koefisien_konektivitas": [t_asli.set_index("var").loc["idx_conn", "b"],
                               t_fix.set_index("var").loc["idx_conn_fix", "b"]],
    "SE": [t_asli.set_index("var").loc["idx_conn", "se"],
           t_fix.set_index("var").loc["idx_conn_fix", "se"]],
    "R2_between": [r2_asli, r2_fix]})
print("\nKonektivitas tanpa kargo:")
print(konn.round(3).to_string(index=False))

# ------------------------------------------------------------------- tabel
tbl_prov = master[["Code_Prov", "Pre_Prov", "Pulau", "z_crs", "tren_crs",
                   "z_drs", "selisih_skala", "kuadran", "fokus",
                   "kontrib_idx_conn", "kontrib_idx_inst"]].copy()
tbl_prov.columns = ["Kode", "Provinsi", "Pulau", "Level CRS (z)",
                    "Tren CRS (pp/th)", "Level DRS (z)",
                    "Selisih skala (z)", "Kuadran", "Pilar fokus",
                    "Kontribusi konektivitas", "Kontribusi institusi"]
tbl_prov = tbl_prov.sort_values(
    ["Kuadran", "Level CRS (z)"],
    key=lambda c: c.map({q: i for i, q in enumerate(QORDER)})
    if c.name == "Kuadran" else c)

tbl_pulau = (master.groupby("Pulau")
             .agg(**{"Jumlah provinsi": ("Code_Prov", "count"),
                     "Level CRS (z, rata-rata)": ("z_crs", "mean"),
                     "Tren CRS (median, pp/th)": ("tren_crs", "median"),
                     "Provinsi Prioritas": ("kuadran",
                                            lambda x: (x == "Prioritas").sum())})
             .reset_index())
idx24 = ta[ta.Year == 2024][["Pulau", "indeks_100"]].rename(
    columns={"indeks_100": "Indeks residual 2024 (2017=100)"})
tbl_pulau = tbl_pulau.merge(idx24, on="Pulau").sort_values(
    "Indeks residual 2024 (2017=100)", ascending=False)

tbl_dek = dek[["Pre_Prov", "Pulau", "kuadran", "g_Y", "kontrib_K",
               "kontrib_L", "kontrib_TFP"]].copy()
tbl_dek.columns = ["Provinsi", "Pulau", "Kuadran",
                   "Pertumbuhan PDRB (pp/th)", "Kontribusi modal",
                   "Kontribusi tenaga kerja", "Kontribusi TFP"]

bu = pd.read_csv(f"{REV}/bottomup_national_aggregation.csv")
mp = pd.read_csv(f"{REV}/meanplay_equalize_island_means.csv")

tbl_fe = pd.DataFrame({
    "Pilar": ["SDM (idx_hr)", "Institusi (idx_inst)",
              "Konektivitas (idx_conn)", "ln upah"],
    "FE (provinsi saja)": ["0.065***", "0.085***", "0.021*", "0.119**"],
    "FE2W (+ tahun)": ["0.003", "0.049 (*** DK)", "0.013 (* DK)", "-0.019"],
    "Between (rata-rata provinsi)": ["-0.031", "0.175", "0.431***", "-0.009"],
    "Kesimpulan": ["ko-gerak tren nasional saja",
                   "satu-satunya sinyal within (lemah)",
                   "kuat di lapisan antarprovinsi",
                   "ko-gerak tren; jatuh saat ada dummy tahun"]})

tbl_crs = pd.DataFrame({
    "Pilar": ["SDM (idx_hr)", "Institusi (idx_inst)",
              "Konektivitas (idx_conn)"],
    "CRS FE2W": ["-0.036", "0.058*", "0.013"],
    "CRS RE2W": ["-0.006", "0.063**", "0.014"],
    "FE2W (DV DRS, utama)": ["0.003", "0.049", "0.013"],
    "Catatan": ["within, bukan uji RTS",
                "tanda sama dengan DV utama",
                "tanda sama; signifikan di between bukan within"]})

tbl_tempat = pd.DataFrame({
    "Berkas": [
        "Peta Level TFP Produksi (DRS) Provinsi.png",
        "Peta Level TFP Efisiensi (CRS) Provinsi.png",
        "Peta Tren TFP (CRS) Provinsi.png",
        "Peta Ketergantungan Skala (DRS-CRS).png",
        "TFP vs Skala Ekonomi (DRS vs CRS).png",
        "Peta Kuadran Kebijakan TFP.png",
        "Peringkat TFP Provinsi (CRS).png",
        "Peta Pilar Fokus Investasi.png",
        "Perubahan Upah Nasional per Tahun.png",
        "Indeks TFP Residual per Pulau.png",
        "Dekomposisi Pertumbuhan per Kuadran.png",
        "maps/map_sar_mean_logtfp.png",
        "maps/map_sar_island_W.png",
        "maps/map_sar_island_lag.png",
        "maps/map_sar_fe2w_residual.png",
    ],
    "Bab": [
        "Luaran 1 / lampiran RTS",
        "6.1 peta (efisiensi sebanding)",
        "6.1 peta",
        "Luaran 1 / lampiran RTS",
        "Luaran 1 / lampiran RTS",
        "6.1.2 deskriptif",
        "6.1.2 deskriptif",
        "6.1.2",
        "6.1.2 (kenapa upah/SDM drop)",
        "6.1.2 pecah pulau (deskriptif)",
        "lampiran kuadran",
        "6.1.2 geografi (bukan spillover)",
        "diagnostik: W pulau = dummy",
        "diagnostik: jangan kutip ρ",
        "diagnostik: leftover 0,7% varians",
    ]})

moran_p = f"{OUT}/spatial_recheck_moran.csv"
sar_p = f"{OUT}/spatial_recheck_sar_between.csv"
moran = pd.read_csv(moran_p) if os.path.exists(moran_p) else pd.DataFrame()
sar_b = pd.read_csv(sar_p) if os.path.exists(sar_p) else pd.DataFrame()

with pd.ExcelWriter(f"{OUT}/Tabel Hasil TFP Spasial.xlsx") as xw:
    tbl_prov.round(3).to_excel(xw, sheet_name="Kuadran Provinsi", index=False)
    tbl_pulau.round(2).to_excel(xw, sheet_name="Ringkasan Pulau", index=False)
    tbl_dek.round(2).to_excel(xw, sheet_name="Dekomposisi Provinsi",
                              index=False)
    bu.round(4).to_excel(xw, sheet_name="Bottom-Up Nasional", index=False)
    mp.round(3).to_excel(xw, sheet_name="Mean-Play Pulau", index=False)
    tbl_fe.to_excel(xw, sheet_name="Model FE vs FE2W", index=False)
    konn.round(3).to_excel(xw, sheet_name="Konektivitas Tanpa Kargo",
                           index=False)
    tbl_crs.to_excel(xw, sheet_name="CRS robustness DV", index=False)
    tbl_tempat.to_excel(xw, sheet_name="Penempatan outline", index=False)
    if len(moran):
        moran.to_excel(xw, sheet_name="Moran recheck", index=False)
    if len(sar_b):
        sar_b.round(3).to_excel(xw, sheet_name="SAR between ns", index=False)
tbl_tempat.to_csv(f"{OUT}/penempatan_berkas.csv", index=False)
print("\ntabel: Tabel Hasil TFP Spasial.xlsx + penempatan_berkas.csv")
print("Selesai. Semua file di:", OUT)
