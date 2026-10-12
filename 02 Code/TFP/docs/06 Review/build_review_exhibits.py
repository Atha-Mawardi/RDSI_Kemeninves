"""Build review exhibits from the current TFP, BKPM, and IO workbooks.

The outputs are diagnostic screens, not causal estimates.  In particular,
PMA/PMDN is never divided by TFP: the units are incompatible.  Instead, the
script juxtaposes investment composition with IO linkage measures and places
the province-level CRS TFP trend beside the BKPM/PMTB coverage ratio.
"""

from __future__ import annotations

import csv
import os
from collections import defaultdict
from pathlib import Path

# Keep plotting caches inside a writable temporary location in restricted runs.
_mpl_cache = Path("/tmp/rdsi-matplotlib-cache")
_mpl_cache.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR", str(_mpl_cache))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from openpyxl import load_workbook


ROOT = Path(__file__).resolve().parents[4]
MASTER = ROOT / "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
TFP_RESULT = ROOT / "01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx"
IO_RESULT = ROOT / "01 Data/IO-IRIO-NA/processed/IO_Multiplier_Analysis_2025_CROSS_ENTROPY.xlsx"
IRIO_RESULT = ROOT / "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IRIO52_2024.xlsx"
OUT = Path(__file__).resolve().parent

SECTOR_CODES = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "MN", "O", "P", "Q", "RSTU"]
SECTOR_LABELS = {
    "A": "Agriculture",
    "B": "Mining",
    "C": "Manufacturing",
    "D": "Electricity & gas",
    "E": "Water & waste",
    "F": "Construction",
    "G": "Trade & repair",
    "H": "Transport & storage",
    "I": "Accommodation & food",
    "J": "ICT",
    "K": "Finance",
    "L": "Real estate",
    "MN": "Business services",
    "O": "Government",
    "P": "Education",
    "Q": "Health & social",
    "RSTU": "Other services",
}


def rows_as_dicts(workbook: Path, sheet: str) -> list[dict]:
    wb = load_workbook(workbook, read_only=True, data_only=True)
    ws = wb[sheet]
    # Several generated workbooks declare an incorrect A1:A1 dimension.
    ws.reset_dimensions()
    rows = ws.iter_rows(values_only=True)
    header = list(next(rows))
    return [dict(zip(header, row)) for row in rows]


def num(value) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def build_sector_table(master_rows: list[dict]) -> list[dict]:
    agg = {year: {code: defaultdict(float) for code in SECTOR_CODES} for year in (2017, 2024, 2025)}
    for row in master_rows:
        year = row["Year"]
        if year not in agg:
            continue
        for code in SECTOR_CODES:
            agg[year][code]["pma"] += num(row[f"{code}_PMA"])
            agg[year][code]["pmdn"] += num(row[f"{code}_PMDN"])
            agg[year][code]["pdrb_adhb"] += num(row[f"{code}_ADHB"])
            agg[year][code]["labor"] += num(row[f"{code}_TenagaKerja"])

    io_data = {int(r["sector_id"]): r for r in rows_as_dicts(IO_RESULT, "Dataset_National")}
    io_factor = {int(r["sector_id"]): r for r in rows_as_dicts(IO_RESULT, "Factor_Mult_Summary")}
    io_link = {int(r["sector_id"]): r for r in rows_as_dicts(IO_RESULT, "Sector_Linkages")}

    total_inv_2025 = sum(agg[2025][c]["pma"] + agg[2025][c]["pmdn"] for c in SECTOR_CODES)
    total_pdrb_2024 = sum(agg[2024][c]["pdrb_adhb"] for c in SECTOR_CODES)
    result = []
    for sector_id, code in enumerate(SECTOR_CODES, start=1):
        now = agg[2025][code]
        prior = agg[2024][code]
        base = agg[2017][code]
        inv_2025 = now["pma"] + now["pmdn"]
        inv_2024 = prior["pma"] + prior["pmdn"]
        inv_2017 = base["pma"] + base["pmdn"]
        cagr = (inv_2024 / inv_2017) ** (1 / 7) - 1 if inv_2017 > 0 and inv_2024 > 0 else None
        factor = io_factor[sector_id]
        link = io_link[sector_id]
        data = io_data[sector_id]
        result.append(
            {
                "sector_id": sector_id,
                "sector_code": code,
                "sector": SECTOR_LABELS[code],
                "pma_2025_rp_trillion": now["pma"] / 1000,
                "pmdn_2025_rp_trillion": now["pmdn"] / 1000,
                "pma_pmdn_2025_rp_trillion": inv_2025 / 1000,
                "investment_share_2025_pct": 100 * inv_2025 / total_inv_2025 if total_inv_2025 else None,
                "pma_share_of_sector_investment_2025_pct": 100 * now["pma"] / inv_2025 if inv_2025 else None,
                "investment_cagr_2017_2024_pct": 100 * cagr if cagr is not None else None,
                "sector_pdrb_share_2024_pct": 100 * prior["pdrb_adhb"] / total_pdrb_2024 if total_pdrb_2024 else None,
                "bkpm_investment_to_sector_pdrb_2024_pct": 100 * inv_2024 / prior["pdrb_adhb"] if prior["pdrb_adhb"] else None,
                "output_multiplier_2025_ce": factor["output_multiplier"],
                "indirect_va_multiplier_2025_ce": factor["indirect_va_multiplier"],
                "backward_linkage_normalized_2025_ce": link["BL_star"],
                "forward_linkage_normalized_2025_ce": link["FL_star"],
                "linkage_quadrant_2025_ce": link["quadrant"],
                "employment_multiplier_available": factor["employment_multiplier"] is not None,
                "io_investment_value_check": data["investment_pma_pmdn"],
            }
        )
    return result


def build_province_table(master_rows: list[dict]) -> list[dict]:
    trends = {int(r["Code_Prov"]): r for r in rows_as_dicts(TFP_RESULT, "tren_provinsi")}
    irio = {int(r["kode_prov"]): r for r in rows_as_dicts(IRIO_RESULT, "linkage_prov")}
    provincial: dict[int, dict] = defaultdict(dict)

    for row in master_rows:
        code = int(row["Code_Prov"])
        year = row["Year"]
        if code not in trends or year not in (2017, 2024):
            continue
        pma = sum(num(row[f"{s}_PMA"]) for s in SECTOR_CODES)
        pmdn = sum(num(row[f"{s}_PMDN"]) for s in SECTOR_CODES)
        provincial[code]["province"] = row["Pre_Prov"]
        provincial[code][f"investment_{year}"] = pma + pmdn
        if year == 2024:
            provincial[code]["pmtb_2024"] = num(row["pmtb"])
            provincial[code]["pma_share"] = pma / (pma + pmdn) if pma + pmdn else 0
            sector_values = {s: num(row[f"{s}_PMA"]) + num(row[f"{s}_PMDN"]) for s in SECTOR_CODES}
            provincial[code]["top_sector_code"] = max(sector_values, key=sector_values.get)

    prelim = []
    for code, values in provincial.items():
        if not {"investment_2017", "investment_2024", "pmtb_2024"}.issubset(values):
            continue
        inv_2017 = values["investment_2017"]
        inv_2024 = values["investment_2024"]
        ratio = inv_2024 / values["pmtb_2024"] if values["pmtb_2024"] else None
        cagr = (inv_2024 / inv_2017) ** (1 / 7) - 1 if inv_2017 > 0 and inv_2024 > 0 else None
        trend = trends[code]
        ir = irio.get(code, {})
        prelim.append(
            {
                "code_prov": code,
                "province": values["province"],
                "tfp_trend_crs_pp_per_year": trend["tren_pp_thn_crs"],
                "tfp_trend_noncrs_pp_per_year": trend["tren_pp_thn"],
                "bkpm_to_pmtb_2024_pct": 100 * ratio if ratio is not None else None,
                "pma_pmdn_2024_rp_trillion": inv_2024 / 1000,
                "investment_cagr_2017_2024_pct": 100 * cagr if cagr is not None else None,
                "pma_share_2024_pct": 100 * values["pma_share"],
                "top_investment_sector_2024": SECTOR_LABELS[values["top_sector_code"]],
                "irio_output_multiplier_mean_2024": ir.get("OM_mean"),
                "irio_key_subsectors_2024": ir.get("n_key"),
            }
        )

    ratio_cut = float(np.median([r["bkpm_to_pmtb_2024_pct"] for r in prelim]))
    tfp_cut = float(np.median([r["tfp_trend_crs_pp_per_year"] for r in prelim]))
    for row in prelim:
        high_ratio = row["bkpm_to_pmtb_2024_pct"] >= ratio_cut
        high_tfp = row["tfp_trend_crs_pp_per_year"] >= tfp_cut
        if high_ratio and not high_tfp:
            action = "Diagnose activation, utilization, skills, and local-supplier transmission"
        elif high_ratio and high_tfp:
            action = "Protect spillovers; condition expansion on skills and suppliers"
        elif not high_ratio and high_tfp:
            action = "Selective crowd-in around high-linkage sectors"
        else:
            action = "Build capability and project readiness before volume targets"
        row["relative_screen"] = action
        row["screen_ratio_median_pct"] = ratio_cut
        row["screen_tfp_median_pp"] = tfp_cut

    return sorted(prelim, key=lambda r: r["bkpm_to_pmtb_2024_pct"], reverse=True)


def write_csv(path: Path, rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def plot_exhibit(sectors: list[dict], provinces: list[dict]) -> None:
    plt.rcParams.update({"font.size": 9, "axes.titlesize": 12, "axes.labelsize": 9})
    fig = plt.figure(figsize=(15, 10.5), constrained_layout=True)
    grid = fig.add_gridspec(3, 1, height_ratios=(1.35, 1, 0.08))

    # Panel A: investment composition and the per-rupiah IO output response.
    ax = fig.add_subplot(grid[0])
    ordered = sorted(sectors, key=lambda r: r["pma_pmdn_2025_rp_trillion"])
    y = np.arange(len(ordered))
    pmdn = np.array([r["pmdn_2025_rp_trillion"] for r in ordered])
    pma = np.array([r["pma_2025_rp_trillion"] for r in ordered])
    ax.barh(y, pmdn, color="#2f855a", label="PMDN")
    ax.barh(y, pma, left=pmdn, color="#2b6cb0", label="PMA")
    ax.set_yticks(y, [r["sector"] for r in ordered])
    ax.set_xlabel("Recorded investment in 2025 (Rp trillion)")
    ax.set_title("A. PMA/PMDN composition and IO transmission potential")
    ax.grid(axis="x", alpha=0.2)
    ax.legend(loc="lower right", frameon=False)

    twin = ax.twiny()
    multipliers = np.array([r["output_multiplier_2025_ce"] for r in ordered])
    twin.scatter(multipliers, y, marker="D", s=28, color="#d97706", label="IO output multiplier")
    twin.set_xlim(1.0, max(3.0, multipliers.max() + 0.1))
    twin.set_xlabel("Cross-entropy IO output multiplier (diamond)", color="#9a5800")
    twin.tick_params(axis="x", colors="#9a5800")

    # Panel B: a screen for places where investment transmission deserves diagnosis.
    ax2 = fig.add_subplot(grid[1])
    x = np.array([r["bkpm_to_pmtb_2024_pct"] for r in provinces])
    y2 = np.array([r["tfp_trend_crs_pp_per_year"] for r in provinces])
    size = 25 + 10 * np.sqrt(np.array([max(r["pma_pmdn_2024_rp_trillion"], 0) for r in provinces]))
    ax2.scatter(x, y2, s=size, c="#4c78a8", alpha=0.7, edgecolor="white", linewidth=0.5)
    ratio_cut = provinces[0]["screen_ratio_median_pct"]
    tfp_cut = provinces[0]["screen_tfp_median_pp"]
    ax2.axvline(ratio_cut, color="#6b7280", linestyle="--", linewidth=1)
    ax2.axhline(tfp_cut, color="#6b7280", linestyle="--", linewidth=1)
    ax2.axhline(0, color="#9ca3af", linewidth=0.7)
    ax2.set_xlabel("Recorded PMA+PMDN / PMTB, 2024 (%) — coverage ratio, not conversion efficiency")
    ax2.set_ylabel("CRS TFP trend, 2017–2024 (percentage points/year)")
    ax2.set_title("B. Province transmission screen: where to investigate activation and utilization")
    ax2.grid(alpha=0.18)

    for row in provinces:
        should_label = (
            row["bkpm_to_pmtb_2024_pct"] >= 60
            or row["tfp_trend_crs_pp_per_year"] < 0
            or row["province"] in {"Sulawesi Tengah", "Kep.Riau", "Papua"}
        )
        if should_label:
            ax2.annotate(
                row["province"],
                (row["bkpm_to_pmtb_2024_pct"], row["tfp_trend_crs_pp_per_year"]),
                xytext=(4, 4),
                textcoords="offset points",
                fontsize=8,
            )

    fig.suptitle("Investment volume is not TFP: a transmission-oriented diagnostic", fontsize=15, weight="bold")
    note = fig.add_subplot(grid[2])
    note.axis("off")
    note.text(
        0,
        0.55,
        "Sources: project master province workbook; current TFP output; 2025 estimated cross-entropy IO; 2024 updated IRIO. "
        "The TFP trend is a generated production-function residual. Bubble size is 2024 PMA+PMDN. Employment multipliers are unavailable.",
        fontsize=8,
        color="#4b5563",
    )
    fig.savefig(OUT / "tfp_bkpm_transmission_screen.png", dpi=220, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    master_rows = rows_as_dicts(MASTER, "Sheet1")
    sectors = build_sector_table(master_rows)
    provinces = build_province_table(master_rows)
    write_csv(OUT / "sector_investment_transmission_2025.csv", sectors)
    write_csv(OUT / "province_investment_transmission_2024.csv", provinces)
    plot_exhibit(sectors, provinces)
    print(f"Wrote {len(sectors)} sector rows and {len(provinces)} province rows to {OUT}")


if __name__ == "__main__":
    main()
