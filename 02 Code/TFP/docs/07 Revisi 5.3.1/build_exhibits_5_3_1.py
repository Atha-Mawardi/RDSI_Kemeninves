"""Build the publication exhibits used in the replacement for subsection 5.3.1.

The figures deliberately distinguish recorded investment, PMTB, IO linkage,
and the PMTB-based production-function residual.  They are descriptive screens,
not causal estimates of investment efficiency or stranded capital.
"""

from __future__ import annotations

import os
from collections import defaultdict
from pathlib import Path

_mpl_cache = Path("/tmp/rdsi-matplotlib-cache-531")
_mpl_cache.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR", str(_mpl_cache))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from openpyxl import load_workbook


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MASTER = ROOT / "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
REVIEW = ROOT / "02 Code/TFP/docs/06 Review"
FIG = HERE / "figures"
FIG.mkdir(parents=True, exist_ok=True)

SECTOR_CSV = REVIEW / "sector_investment_transmission_2025.csv"
PROVINCE_CSV = REVIEW / "province_investment_transmission_2024.csv"

BLUE = "#2463A6"
GREEN = "#2E8B57"
NAVY = "#12304A"
TEAL = "#55BED4"
GREY = "#8A93A3"
ORANGE = "#D97706"
RED = "#C9364F"
LIGHT = "#EEF3F7"


def set_style() -> None:
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 10,
            "axes.titlesize": 15,
            "axes.labelsize": 10,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.titleweight": "bold",
            "figure.dpi": 180,
            "savefig.dpi": 240,
        }
    )


def national_series() -> pd.DataFrame:
    wb = load_workbook(MASTER, read_only=True, data_only=True)
    ws = wb["Sheet1"]
    ws.reset_dimensions()
    rows = ws.iter_rows(values_only=True)
    header = list(next(rows))
    ix = {name: i for i, name in enumerate(header)}
    out: dict[int, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    for row in rows:
        year = int(row[ix["Year"]])
        for name in ("PMA_1", "PMDN_1", "pmtb"):
            out[year][name] += float(row[ix[name]] or 0)

    data = []
    for year in sorted(out):
        item = out[year]
        total = item["PMA_1"] + item["PMDN_1"]
        data.append(
            {
                "tahun": year,
                "pma_rp_triliun": item["PMA_1"] / 1_000,
                "pmdn_rp_triliun": item["PMDN_1"] / 1_000,
                "pma_pmdn_rp_triliun": total / 1_000,
                "pmtb_rp_triliun": item["pmtb"] / 1_000,
                "pmdn_share_pct": 100 * item["PMDN_1"] / total,
                "bkpm_pmtb_coverage_pct": 100 * total / item["pmtb"],
            }
        )
    df = pd.DataFrame(data)
    df.to_csv(HERE / "data_nasional_2017_2025.csv", index=False, encoding="utf-8-sig")
    return df


def plot_national(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(11.7, 6.6))
    fig.subplots_adjust(left=0.08, right=0.91, top=0.84, bottom=0.11)
    x = np.arange(len(df))
    ax.bar(x, df["pmdn_rp_triliun"], color=GREEN, width=0.70, label="PMDN")
    ax.bar(
        x,
        df["pma_rp_triliun"],
        bottom=df["pmdn_rp_triliun"],
        color=BLUE,
        width=0.70,
        label="PMA",
    )
    ax.set_xticks(x, df["tahun"])
    ax.set_ylabel("Realisasi PMA + PMDN (Rp triliun)")
    ax.grid(axis="y", alpha=0.18)
    ax.set_axisbelow(True)

    ax2 = ax.twinx()
    ax2.spines["right"].set_visible(True)
    ax2.plot(
        x,
        df["bkpm_pmtb_coverage_pct"],
        color=ORANGE,
        marker="o",
        linewidth=2.4,
        label="Rasio cakupan BKPM/PMTB",
    )
    ax2.set_ylabel("PMA+PMDN / PMTB (%)", color=ORANGE)
    ax2.tick_params(axis="y", colors=ORANGE)
    ax2.set_ylim(0, max(32, df["bkpm_pmtb_coverage_pct"].max() * 1.2))

    first, last = df.iloc[0], df.iloc[-1]
    ax.annotate(
        f"Rp{first.pma_pmdn_rp_triliun:,.1f} T",
        (x[0], first.pma_pmdn_rp_triliun),
        xytext=(0, 8),
        textcoords="offset points",
        ha="center",
        fontsize=9,
        weight="bold",
    )
    ax.annotate(
        f"Rp{last.pma_pmdn_rp_triliun:,.1f} T",
        (x[-1], last.pma_pmdn_rp_triliun),
        xytext=(0, 8),
        textcoords="offset points",
        ha="center",
        fontsize=9,
        weight="bold",
    )
    ax2.annotate(
        f"{last.bkpm_pmtb_coverage_pct:.1f}%",
        (x[-1], last.bkpm_pmtb_coverage_pct),
        xytext=(7, -2),
        textcoords="offset points",
        color=ORANGE,
        weight="bold",
    )

    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, loc="upper left", ncol=3, frameon=False)
    fig.suptitle("Realisasi investasi meningkat, tetapi konversinya belum terukur", x=0.06, ha="left")
    ax.set_title(
        "PMA+PMDN naik dari Rp692,8 triliun (2017) menjadi Rp1.931,1 triliun (2025)",
        loc="left",
        fontsize=11,
        fontweight="normal",
        color="#4B5563",
        pad=12,
    )
    fig.savefig(FIG / "gambar_5_3_1_1_realisasi_investasi.png", bbox_inches="tight")
    plt.close(fig)


def plot_decomposition() -> None:
    scenarios = pd.DataFrame(
        [
            ("TWFE tanpa pembatasan CRS", 1.310, 0.306, 2.211),
            ("Level, dipaksa CRS", 1.470, 1.139, 1.216),
            ("Growth, dinormalisasi CRS", 0.943, 1.476, 1.409),
            ("Pangsa pendapatan terukur", 2.742, 0.330, 0.755),
            ("Pangsa modal baku 1/3", 1.087, 1.384, 1.356),
            ("Stok modal PIM pendek, CRS", 1.644, 1.139, 1.045),
        ],
        columns=["skenario", "modal", "tenaga_kerja", "residual"],
    )
    scenarios.to_csv(HERE / "data_sensitivitas_dekomposisi.csv", index=False, encoding="utf-8-sig")

    fig, ax = plt.subplots(figsize=(11.7, 6.8))
    fig.subplots_adjust(left=0.20, right=0.97, top=0.84, bottom=0.17)
    y = np.arange(len(scenarios))
    ax.barh(y, scenarios.modal, color=NAVY, label="Modal")
    ax.barh(y, scenarios.tenaga_kerja, left=scenarios.modal, color=GREY, label="Tenaga kerja")
    ax.barh(
        y,
        scenarios.residual,
        left=scenarios.modal + scenarios.tenaga_kerja,
        color=TEAL,
        label="Residual (termasuk TFP dan galat ukur)",
    )
    ax.set_yticks(y, scenarios.skenario)
    ax.invert_yaxis()
    ax.set_xlim(0, 4.15)
    ax.set_xlabel("Kontribusi pada pertumbuhan PDRB riil 2018–2024 (poin persentase per tahun)")
    ax.grid(axis="x", alpha=0.18)
    ax.set_axisbelow(True)
    for i, row in scenarios.iterrows():
        ax.text(
            row.modal + row.tenaga_kerja + row.residual - row.residual / 2,
            i,
            f"{row.residual:.2f}",
            ha="center",
            va="center",
            fontsize=9,
            weight="bold",
            color=NAVY,
        )
    ax.axvline(3.827, color=RED, linewidth=1.5, linestyle="--")
    ax.text(3.827, -0.65, "Pertumbuhan rata-rata 3,83%", color=RED, ha="right", fontsize=9)
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, -0.24), ncol=3, frameon=False)
    fig.suptitle("Besaran residual berubah ketika definisi modal dan bobot faktor berubah", x=0.06, ha="left")
    ax.set_title(
        "Residual berada pada 0,76–2,21 poin; rentang ini lebih informatif daripada satu angka TFP",
        loc="left",
        fontsize=11,
        fontweight="normal",
        color="#4B5563",
        pad=12,
    )
    fig.savefig(FIG / "gambar_5_3_1_2_sensitivitas_dekomposisi.png", bbox_inches="tight")
    plt.close(fig)


def plot_sector() -> None:
    df = pd.read_csv(SECTOR_CSV)
    chosen = [
        "Manufacturing",
        "Mining",
        "Transport & storage",
        "Real estate",
        "Trade & repair",
        "ICT",
        "Electricity & gas",
        "Agriculture",
    ]
    labels = {
        "Manufacturing": "Industri pengolahan",
        "Mining": "Pertambangan",
        "Transport & storage": "Transportasi & pergudangan",
        "Real estate": "Real estat",
        "Trade & repair": "Perdagangan & reparasi",
        "ICT": "Informasi & komunikasi",
        "Electricity & gas": "Listrik & gas",
        "Agriculture": "Pertanian",
    }
    df = df[df["sector"].isin(chosen)].copy()
    df = df.sort_values("pma_pmdn_2025_rp_trillion", ascending=True)
    df["label_id"] = df["sector"].map(labels)
    df.to_csv(HERE / "data_portofolio_sektor_terpilih.csv", index=False, encoding="utf-8-sig")

    fig, ax = plt.subplots(figsize=(11.7, 7.0))
    fig.subplots_adjust(left=0.17, right=0.91, top=0.83, bottom=0.11)
    y = np.arange(len(df))
    pmdn = df["pmdn_2025_rp_trillion"].to_numpy()
    pma = df["pma_2025_rp_trillion"].to_numpy()
    ax.barh(y, pmdn, color=GREEN, label="PMDN")
    ax.barh(y, pma, left=pmdn, color=BLUE, label="PMA")
    ax.set_yticks(y, df["label_id"])
    ax.set_xlabel("Realisasi investasi 2025 (Rp triliun)")
    ax.grid(axis="x", alpha=0.18)
    ax.set_axisbelow(True)
    ax.legend(loc="lower right", frameon=False)

    twin = ax.twiny()
    twin.spines["top"].set_visible(True)
    mult = df["output_multiplier_2025_ce"].to_numpy()
    twin.scatter(mult, y, marker="D", s=48, color=ORANGE, zorder=4, label="Pengganda output IO")
    twin.set_xlim(1.0, 3.0)
    twin.set_xlabel("Pengganda output IO 2025 (berlian)", color=ORANGE)
    twin.tick_params(axis="x", colors=ORANGE)
    for yy, mm in zip(y, mult):
        twin.annotate(f"{mm:.2f}", (mm, yy), xytext=(5, 0), textcoords="offset points", va="center", fontsize=8, color="#9A5800")

    fig.suptitle("Portofolio investasi perlu dibaca bersama potensi keterkaitan sektoral", x=0.06, ha="left")
    ax.set_title(
        "Industri pengolahan menyerap 40,5% realisasi; listrik-gas memiliki pengganda output tertinggi",
        loc="left",
        fontsize=11,
        fontweight="normal",
        color="#4B5563",
        pad=12,
    )
    fig.savefig(FIG / "gambar_5_3_1_3_portofolio_sektor.png", bbox_inches="tight")
    plt.close(fig)


def plot_province() -> None:
    df = pd.read_csv(PROVINCE_CSV)
    x = df["bkpm_to_pmtb_2024_pct"].to_numpy()
    y = df["tfp_trend_crs_pp_per_year"].to_numpy()
    size = 30 + 15 * np.sqrt(df["pma_pmdn_2024_rp_trillion"].clip(lower=0).to_numpy())
    xmed = float(df["screen_ratio_median_pct"].iloc[0])
    ymed = float(df["screen_tfp_median_pp"].iloc[0])

    fig, ax = plt.subplots(figsize=(11.7, 7.2))
    fig.subplots_adjust(left=0.10, right=0.97, top=0.84, bottom=0.11)
    ax.axvspan(xmed, max(x) * 1.08, ymin=0, ymax=(ymed - min(y) + 0.1) / (max(y) - min(y) + 0.4), color="#FFF2F2", alpha=0.8)
    ax.scatter(x, y, s=size, color=BLUE, alpha=0.67, edgecolor="white", linewidth=0.6)
    ax.axvline(xmed, color="#6B7280", linestyle="--", linewidth=1)
    ax.axhline(ymed, color="#6B7280", linestyle="--", linewidth=1)
    ax.axhline(0, color="#9CA3AF", linewidth=0.8)
    ax.set_xlabel("PMA+PMDN / PMTB 2024 (%) — rasio cakupan, bukan efisiensi")
    ax.set_ylabel("Tren residual CRS 2017–2024 (poin persentase per tahun)")
    ax.grid(alpha=0.16)
    ax.set_axisbelow(True)
    ax.text(xmed + 4, min(y) + 0.05, "Prioritas diagnosis\naktivasi & utilisasi", color=RED, fontsize=10, weight="bold")
    label_set = {
        "Maluku Utara",
        "Papua Barat",
        "Sulawesi Tengah",
        "Nusa Tenggara Barat",
        "Kalimantan Utara",
        "Kep.BangkaBelitung",
        "Kalimantan Timur",
        "Kep.Riau",
    }
    offsets = {
        "Maluku Utara": (-88, 6),
        "Papua Barat": (5, 4),
        "Sulawesi Tengah": (5, 4),
        "Nusa Tenggara Barat": (5, -12),
        "Kalimantan Utara": (5, 4),
        "Kep.BangkaBelitung": (5, 4),
        "Kalimantan Timur": (5, -12),
        "Kep.Riau": (5, 4),
    }
    for _, row in df.iterrows():
        if row["province"] in label_set:
            ax.annotate(
                row["province"],
                (row["bkpm_to_pmtb_2024_pct"], row["tfp_trend_crs_pp_per_year"]),
                xytext=offsets.get(row["province"], (5, 5)),
                textcoords="offset points",
                fontsize=8.3,
            )
    fig.suptitle("Layar provinsi untuk memilih kasus yang perlu diverifikasi", x=0.06, ha="left")
    ax.set_title(
        "Intensitas investasi tinggi dengan residual lemah adalah sinyal audit—bukan bukti stranded capital",
        loc="left",
        fontsize=11,
        fontweight="normal",
        color="#4B5563",
        pad=12,
    )
    fig.savefig(FIG / "gambar_5_3_1_4_layar_provinsi.png", bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    set_style()
    df = national_series()
    plot_national(df)
    plot_decomposition()
    plot_sector()
    plot_province()
    print(f"Generated exhibits in {FIG}")


if __name__ == "__main__":
    main()
