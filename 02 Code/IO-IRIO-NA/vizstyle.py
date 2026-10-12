"""Figure chrome shared by the IO–IRIO notebooks.

Headers, palette, and save rules follow 02 Code/TFP/02_viz_peringkat.ipynb.
"""

from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

NAVY, TEAL, RUST, GRAY, CREAM, PAPER = (
    "#0E2440", "#46A694", "#D9042B", "#797F8C", "#F2E6CE", "#FFFFFF",
)
GRID = "#EEF0F3"
CMAP_RANK = LinearSegmentedColormap.from_list("rank", ["#F4EFE4", "#8FA8C4", NAVY])
CMAP_LEAVE = LinearSegmentedColormap.from_list("leave", ["#F4EFE4", "#E7A08A", RUST])
CMAP_FLOW = LinearSegmentedColormap.from_list("flow", ["#F7F4EF", "#8FA8C4", NAVY])

# Workbook unit is million rupiah. Divide by 1e6 for trillion rupiah.
TRILLION = 1e6

ISLAND_ORDER = [
    "Java", "Sumatra", "Kalimantan", "Sulawesi",
    "Bali and Nusa Tenggara", "Maluku", "Papua",
]
ISLAND_COLOR = {
    "Java": NAVY,
    "Sumatra": TEAL,
    "Kalimantan": "#8FA8C4",
    "Sulawesi": "#C47B4A",
    "Bali and Nusa Tenggara": GRAY,
    "Maluku": RUST,
    "Papua": "#2F6F8F",
}
ISLAND_SHORT = {
    "Java": "Jawa",
    "Sumatra": "Sumatera",
    "Kalimantan": "Kalimantan",
    "Sulawesi": "Sulawesi",
    "Bali and Nusa Tenggara": "Bali–Nusa",
    "Maluku": "Maluku",
    "Papua": "Papua",
}
ISLAND = {
    "Aceh": "Sumatra", "Sumatera Utara": "Sumatra", "Sumatera Barat": "Sumatra",
    "Riau": "Sumatra", "Jambi": "Sumatra", "Sumatera Selatan": "Sumatra",
    "Bengkulu": "Sumatra", "Lampung": "Sumatra",
    "Kep. Bangka Belitung": "Sumatra", "Kep. Riau": "Sumatra",
    "DKI Jakarta": "Java", "Jawa Barat": "Java", "Jawa Tengah": "Java",
    "DI Yogyakarta": "Java", "Jawa Timur": "Java", "Banten": "Java",
    "Bali": "Bali and Nusa Tenggara",
    "Nusa Tenggara Barat": "Bali and Nusa Tenggara",
    "Nusa Tenggara Timur": "Bali and Nusa Tenggara",
    "Kalimantan Barat": "Kalimantan", "Kalimantan Tengah": "Kalimantan",
    "Kalimantan Selatan": "Kalimantan", "Kalimantan Timur": "Kalimantan",
    "Kalimantan Utara": "Kalimantan",
    "Sulawesi Utara": "Sulawesi", "Sulawesi Tengah": "Sulawesi",
    "Sulawesi Selatan": "Sulawesi", "Sulawesi Tenggara": "Sulawesi",
    "Gorontalo": "Sulawesi", "Sulawesi Barat": "Sulawesi",
    "Maluku": "Maluku", "Maluku Utara": "Maluku",
    "Papua": "Papua", "Papua Barat": "Papua",
}
SHORT = {
    "Aceh": "Aceh", "Sumatera Utara": "Sumatera Utara", "Sumatera Barat": "Sumatera Barat",
    "Riau": "Riau", "Jambi": "Jambi", "Sumatera Selatan": "Sumatera Selatan",
    "Bengkulu": "Bengkulu", "Lampung": "Lampung",
    "Kep. Bangka Belitung": "Bangka Belitung", "Kep. Riau": "Kepulauan Riau",
    "DKI Jakarta": "Jakarta", "Jawa Barat": "Jawa Barat", "Jawa Tengah": "Jawa Tengah",
    "DI Yogyakarta": "Yogyakarta", "Jawa Timur": "Jawa Timur", "Banten": "Banten",
    "Bali": "Bali", "Nusa Tenggara Barat": "Nusa Tenggara Barat",
    "Nusa Tenggara Timur": "Nusa Tenggara Timur",
    "Kalimantan Barat": "Kalimantan Barat", "Kalimantan Tengah": "Kalimantan Tengah",
    "Kalimantan Selatan": "Kalimantan Selatan", "Kalimantan Timur": "Kalimantan Timur",
    "Kalimantan Utara": "Kalimantan Utara",
    "Sulawesi Utara": "Sulawesi Utara", "Sulawesi Tengah": "Sulawesi Tengah",
    "Sulawesi Selatan": "Sulawesi Selatan", "Sulawesi Tenggara": "Sulawesi Tenggara",
    "Gorontalo": "Gorontalo", "Sulawesi Barat": "Sulawesi Barat",
    "Maluku": "Maluku", "Maluku Utara": "Maluku Utara",
    "Papua": "Papua", "Papua Barat": "Papua Barat",
}
SECTOR = {
    1: "Pertanian", 2: "Pertambangan", 3: "Industri pengolahan", 4: "Listrik dan gas",
    5: "Air dan limbah", 6: "Konstruksi", 7: "Perdagangan", 8: "Transportasi dan pergudangan",
    9: "Akomodasi dan makan minum", 10: "Informasi dan komunikasi", 11: "Jasa keuangan",
    12: "Real estat", 13: "Jasa perusahaan", 14: "Administrasi pemerintahan",
    15: "Pendidikan", 16: "Kesehatan", 17: "Jasa lainnya",
}
SECTOR_LABEL = {
    "A": "Pertanian", "B": "Pertambangan", "C": "Industri pengolahan",
    "D": "Listrik dan gas", "E": "Air dan limbah", "F": "Konstruksi",
    "G": "Perdagangan", "H": "Transportasi dan pergudangan", "I": "Akomodasi dan makan minum",
    "J": "Informasi dan komunikasi", "K": "Jasa keuangan", "L": "Real estat",
    "MN": "Jasa perusahaan", "O": "Administrasi pemerintahan", "P": "Pendidikan",
    "Q": "Kesehatan", "RSTU": "Jasa lainnya",
}
SECTOR_ORDER = list(SECTOR_LABEL)
GADM_NAME = {
    "Aceh": "Aceh", "Sumatera Utara": "SumateraUtara", "Sumatera Barat": "SumateraBarat",
    "Riau": "Riau", "Jambi": "Jambi", "Sumatera Selatan": "SumateraSelatan",
    "Bengkulu": "Bengkulu", "Lampung": "Lampung",
    "Kep. Bangka Belitung": "BangkaBelitung", "Kep. Riau": "KepulauanRiau",
    "DKI Jakarta": "JakartaRaya", "Jawa Barat": "JawaBarat", "Jawa Tengah": "JawaTengah",
    "DI Yogyakarta": "Yogyakarta", "Jawa Timur": "JawaTimur", "Banten": "Banten",
    "Bali": "Bali", "Nusa Tenggara Barat": "NusaTenggaraBarat",
    "Nusa Tenggara Timur": "NusaTenggaraTimur",
    "Kalimantan Barat": "KalimantanBarat", "Kalimantan Tengah": "KalimantanTengah",
    "Kalimantan Selatan": "KalimantanSelatan", "Kalimantan Timur": "KalimantanTimur",
    "Kalimantan Utara": "KalimantanUtara",
    "Sulawesi Utara": "SulawesiUtara", "Sulawesi Tengah": "SulawesiTengah",
    "Sulawesi Selatan": "SulawesiSelatan", "Sulawesi Tenggara": "SulawesiTenggara",
    "Gorontalo": "Gorontalo", "Sulawesi Barat": "SulawesiBarat",
    "Maluku": "Maluku", "Maluku Utara": "MalukuUtara",
    "Papua": "Papua", "Papua Barat": "PapuaBarat",
}
PATH_YLIM = (60, 580)


def find_root():
    here = Path.cwd().resolve()
    for cand in [here, *here.parents]:
        if (cand / "2026bkpm.Rproj").exists():
            return cand
    return Path("/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves")


ROOT = find_root()
DATA = ROOT.parent / "DATA" / "IO:IRIO-Network_Analysis"
OUT = ROOT / "01 Data" / "IO-IRIO-NA" / "output"
CACHE = ROOT / "01 Data" / "IO-IRIO-NA" / "processed" / "cache"
GADM = ROOT / "02 Code" / "TFP" / "docs" / "06 Review" / "assets" / "gadm41_IDN_1.json"
OUT.mkdir(parents=True, exist_ok=True)
CACHE.mkdir(parents=True, exist_ok=True)


def apply_style():
    plt.rcParams.update({
        "figure.facecolor": PAPER, "axes.facecolor": PAPER, "savefig.facecolor": PAPER,
        "font.family": "sans-serif",
        "font.sans-serif": ["Helvetica Neue", "Arial", "DejaVu Sans"],
        "axes.unicode_minus": False, "axes.titlecolor": NAVY, "text.color": NAVY,
        "axes.labelcolor": NAVY, "xtick.color": GRAY, "ytick.color": NAVY,
        "axes.labelsize": 11, "xtick.labelsize": 10, "ytick.labelsize": 10,
    })


def clean(ax, grid="x"):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#E2E5EA")
    ax.spines["bottom"].set_color("#E2E5EA")
    ax.tick_params(length=0)
    if grid:
        ax.set_axisbelow(True)
        ax.grid(True, axis=grid, color=GRID, lw=0.8)


def head(fig, title, subtitle, top=0.88):
    """Store the header; position it after the final subplot layout."""
    fig._report_header = (title, subtitle)
    fig.tight_layout(rect=(0, 0, 1, top))


def _finish_header(fig):
    """Wrap and separate text using rendered sizes, independent of figure height."""
    for artist in getattr(fig, "_report_header_artists", []):
        artist.remove()
    fig._report_header_artists = []
    if not hasattr(fig, "_report_header"):
        return
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    dpi = fig.dpi
    height_px = fig.bbox.height
    width_px = fig.bbox.width * 0.96
    bounds = [ax.get_tightbbox(renderer) for ax in fig.axes if ax.get_visible()]
    bounds += [a.get_window_extent(renderer) for a in fig.legends + fig.texts
               if a.get_visible()]
    content_top = max((b.y1 for b in bounds if b is not None), default=height_px * .9)

    def wrapped(text, size):
        probe = fig.text(0, 0, "", fontsize=size)
        lines = []
        for paragraph in str(text).split("\n"):
            line = ""
            for word in paragraph.split():
                trial = (line + " " + word).strip()
                probe.set_text(trial)
                if line and probe.get_window_extent(renderer).width > width_px:
                    lines.append(line)
                    line = word
                else:
                    line = trial
            lines.append(line)
        probe.remove()
        return "\n".join(lines)

    title, subtitle = fig._report_header
    gap = 10 * dpi / 72
    sub = fig.text(.01, (content_top + gap) / height_px,
                   wrapped(subtitle, 11), ha="left", va="bottom",
                   fontsize=11, color=GRAY, linespacing=1.35)
    fig.canvas.draw()
    sub_box = sub.get_window_extent(fig.canvas.get_renderer())
    main = fig.text(.01, (sub_box.y1 + gap) / height_px,
                    wrapped(title, 16), ha="left", va="bottom",
                    fontsize=16, color=NAVY, fontweight="medium", linespacing=1.25)
    fig._report_header_artists = [main, sub]
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    assert main.get_window_extent(renderer).y0 > sub.get_window_extent(renderer).y1
    assert sub.get_window_extent(renderer).y0 > content_top


def save(fig, name):
    _finish_header(fig)
    fig.savefig(OUT / name, dpi=180, bbox_inches="tight", facecolor=PAPER)
    print(name)
    plt.show()


def ink_for(cmap, val, vmin, vmax):
    t = 0.5 if vmax == vmin else (val - vmin) / (vmax - vmin)
    t = min(1, max(0, t))
    r, g, b, _ = cmap(t)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    return "white" if lum < 0.62 else NAVY


def mark_2020(ax):
    ax.axvline(2020, color=RUST, lw=0.7, alpha=0.45, zorder=0)


def rank_desc(s):
    return s.rank(ascending=False, method="min").astype(int)


def _annotate_island(frame):
    out = frame.copy()
    out["origin_island"] = out.origin_province_name.map(ISLAND)
    out["dest_island"] = out.dest_province_name.map(ISLAND)
    if out.origin_island.isna().any() or out.dest_island.isna().any():
        missing = sorted(set(out.loc[out.origin_island.isna(), "origin_province_name"]))
        raise KeyError(f"province missing from island map: {missing}")
    out["same_province"] = out.origin_province_name.eq(out.dest_province_name)
    out["same_island"] = out.origin_island.eq(out.dest_island) & ~out.same_province
    out["other_island"] = out.origin_island.ne(out.dest_island)
    out["product"] = np.where(
        out.origin_sector_code.isin(["A", "B"]), "Primary",
        np.where(out.origin_sector_code.eq("C"), "Manufacturing", "Other"),
    )
    return out


def load_flows():
    """2025 RAS intermediate flows, province-sector to province-sector.

    Primary products are agriculture and mining. Manufacturing is processing.
    A sale is local when the buying province is the selling province.
    """
    cache = CACHE / "z_long_2025_ras.parquet"
    if not cache.exists():
        zpath = DATA / "IRIO" / "2025" / "IRIO_Estimasi_2025_RAS.xlsx"
        z = pd.read_excel(zpath, sheet_name="Z_IRIO")
        id_cols = [
            "origin_element", "origin_province_code", "origin_province_name",
            "origin_sector_code", "origin_sector_name",
        ]
        dest_cols = [c for c in z.columns if c not in id_cols]
        long = z.melt(id_vars=id_cols, value_vars=dest_cols,
                      var_name="dest_element", value_name="value")
        parts = long.dest_element.str.rsplit("_", n=1)
        long["dest_province_code"] = parts.str[0].astype(int)
        long["dest_sector_code"] = parts.str[1]
        names = dict(zip(z.origin_province_code, z.origin_province_name))
        secs = dict(zip(z.origin_sector_code, z.origin_sector_name))
        long["dest_province_name"] = long.dest_province_code.map(names)
        long["dest_sector_name"] = long.dest_sector_code.map(secs)
        long = long.drop(columns=["origin_element", "dest_element"])
        long.to_parquet(cache, index=False)
    return _annotate_island(pd.read_parquet(cache))


def load_strength_panel():
    """Provincial transaction strength, RAS, 2017–2025.

    Out-strength is intermediate sales to other provinces.
    In-strength is intermediate purchases from other provinces.
    Indexes equal 100 in 2017.
    """
    cache = CACHE / "strength_panel_ras.parquet"
    if cache.exists():
        return pd.read_parquet(cache)
    frames = []
    for year in range(2017, 2026):
        path = (DATA / "Network-Analysis" / str(year) / "RAS"
                / "01_v2_pipeline" / "tables" / "Q1_province_metrics_all_graphs.xlsx")
        df = pd.read_excel(path)
        df = df.loc[df.graph.eq("Full"), [
            "province", "region", "strength_out", "strength_in",
            "strength_total", "pagerank", "betweenness",
        ]].copy()
        df["year"] = year
        frames.append(df)
    panel = pd.concat(frames, ignore_index=True)
    base = panel.loc[panel.year.eq(2017), ["province", "strength_out", "strength_in"]]
    base = base.rename(columns={"strength_out": "out_2017", "strength_in": "in_2017"})
    panel = panel.merge(base, on="province", how="left")
    panel["out_i"] = 100 * panel.strength_out / panel.out_2017
    panel["in_i"] = 100 * panel.strength_in / panel.in_2017
    panel["island"] = panel.province.map(ISLAND)
    if panel.island.isna().any():
        raise KeyError("network province missing from island map")
    panel.to_parquet(cache, index=False)
    return panel


def province_absorption(flows):
    """Where each province's intermediate sales are bought."""
    rows = []
    for (prov, island), sub in flows.groupby(["origin_province_name", "origin_island"], sort=False):
        total = sub.value.sum()
        rec = {
            "province": prov,
            "island": island,
            "total": total,
            "local": sub.loc[sub.same_province, "value"].sum(),
            "intra": sub.loc[sub.same_island, "value"].sum(),
            "inter": sub.loc[sub.other_island, "value"].sum(),
        }
        for product in ("Primary", "Manufacturing"):
            part = sub.loc[sub["product"].eq(product)]
            sold = part.value.sum()
            away = part.loc[~part.same_province, "value"].sum()
            rec[f"{product.lower()}_total"] = sold
            rec[f"{product.lower()}_away"] = away
            rec[f"{product.lower()}_leave"] = away / sold if sold else np.nan
        rows.append(rec)
    out = pd.DataFrame(rows)
    out["local_share"] = out.local / out.total
    out["intra_share"] = out.intra / out.total
    out["inter_share"] = out.inter / out.total
    out["leave_share"] = 1 - out.local_share
    return out


def top_buyer(flows, product):
    """Largest other-province buyer of a product group's intermediate sales."""
    sub = flows.loc[flows["product"].eq(product) & ~flows.same_province]
    pair = (sub.groupby(["origin_province_name", "dest_province_name"], as_index=False)
            .value.sum())
    away = pair.groupby("origin_province_name").value.transform("sum")
    pair["share_of_outflow"] = pair.value / away
    idx = pair.groupby("origin_province_name").value.idxmax()
    return pair.loc[idx].rename(columns={
        "origin_province_name": "province",
        "dest_province_name": "buyer",
        "value": "buyer_value",
    })


def _spill_from_long(long, year):
    """Collapse province-sector flows to sector × where the buyer sits."""
    frame = long if "same_province" in long.columns else _annotate_island(long)
    rows = []
    for (code, name), sub in frame.groupby(["origin_sector_code", "origin_sector_name"], sort=False):
        local = sub.loc[sub.same_province, "value"].sum()
        intra = sub.loc[sub.same_island, "value"].sum()
        inter = sub.loc[sub.other_island, "value"].sum()
        rows.append({
            "year": year,
            "origin_sector_code": code,
            "origin_sector_name": name,
            "local": local,
            "intra": intra,
            "inter": inter,
        })
    out = pd.DataFrame(rows)
    out["total"] = out.local + out.intra + out.inter
    out["away"] = out.intra + out.inter
    out["leave"] = out.away / out.total
    out["intra_of_away"] = out.intra / out.away
    out["inter_of_away"] = out.inter / out.away
    return out


def _read_z(year):
    zpath = DATA / "IRIO" / str(year) / f"IRIO_Estimasi_{year}_RAS.xlsx"
    z = pd.read_excel(zpath, sheet_name="Z_IRIO")
    id_cols = [
        "origin_element", "origin_province_code", "origin_province_name",
        "origin_sector_code", "origin_sector_name",
    ]
    dest_cols = [c for c in z.columns if c not in id_cols]
    long = z.melt(id_vars=id_cols, value_vars=dest_cols, var_name="dest_element", value_name="value")
    parts = long.dest_element.str.rsplit("_", n=1)
    long["dest_province_code"] = parts.str[0].astype(int)
    names = dict(zip(z.origin_province_code, z.origin_province_name))
    long["dest_province_name"] = long.dest_province_code.map(names)
    return long.drop(columns=["origin_element", "dest_element"])


def load_sector_spillover():
    """Sector sales by buyer location, RAS IRIO, 2020–2025.

    The IRIO workbooks start in 2020. `intra` is another province on the same
    island. `inter` is another island. `away` is everything sold off the province.
    """
    cache = CACHE / "sector_spill_2020_2025.parquet"
    if cache.exists():
        return pd.read_parquet(cache)
    frames = []
    z2025 = CACHE / "z_long_2025_ras.parquet"
    for year in range(2020, 2026):
        if year == 2025 and z2025.exists():
            frames.append(_spill_from_long(pd.read_parquet(z2025), year))
        else:
            frames.append(_spill_from_long(_read_z(year), year))
        print("spillover", year, flush=True)
    out = pd.concat(frames, ignore_index=True)
    out.to_parquet(cache, index=False)
    return out


def path_figure(panel, names, ncols, title, subtitle, fname, ylim=PATH_YLIM):
    """Small-multiple index paths. Every call uses the same axis scale."""
    nrows = int(np.ceil(len(names) / ncols))
    fig, axes = plt.subplots(
        nrows, ncols, figsize=(11.2, 2.7 * nrows + 0.55),
        sharex=True, sharey=True, squeeze=False,
    )
    flat = axes.ravel()
    for ax, name in zip(flat, names):
        sub = panel.loc[panel.province.eq(name)].sort_values("year")
        ax.axhline(100, color="#E2E5EA", lw=0.8, zorder=0)
        mark_2020(ax)
        ax.plot(sub.year, sub.out_i, color=NAVY, marker="o", ms=4.2, lw=1.8,
                label="Dijual ke provinsi lain")
        ax.plot(sub.year, sub.in_i, color=TEAL, marker="D", ms=4.0, lw=1.6,
                label="Dibeli dari provinsi lain")
        ax.set_title(SHORT[name], loc="left", fontsize=12, color=NAVY)
        ax.set_xticks([2017, 2020, 2025])
        clean(ax, grid="y")
    for ax in flat[len(names):]:
        ax.set_visible(False)
    flat[0].set_ylim(*ylim)
    flat[0].legend(frameon=False, fontsize=8.5, loc="upper left")
    for ax in axes[:, 0]:
        if ax.get_visible():
            ax.set_ylabel("Indeks, 2017 = 100")
    head(fig, title, subtitle, top=0.84)
    save(fig, fname)
    return fig


def sector_grid(codes, draw, title, subtitle, fname, ncols=6, sharey=False, ylabel=""):
    """One panel per sector. `draw(ax, code)` plots that sector and nothing else."""
    nrows = int(np.ceil(len(codes) / ncols))
    fig, axes = plt.subplots(
        nrows, ncols, figsize=(12.4, 2.05 * nrows + 0.85),
        sharex=True, sharey=sharey, squeeze=False,
    )
    flat = axes.ravel()
    for ax, code in zip(flat, codes):
        draw(ax, code)
        ax.set_title(SECTOR_LABEL[code], loc="left", fontsize=10, color=NAVY)
        clean(ax, grid="y")
    for ax in flat[len(codes):]:
        ax.set_visible(False)
    if ylabel:
        for ax in axes[:, 0]:
            if ax.get_visible():
                ax.set_ylabel(ylabel)
    head(fig, title, subtitle, top=0.88)
    save(fig, fname)
    return fig


MAP_LABEL = {
    "Aceh": "Aceh", "Sumatera Utara": "Sumut", "Sumatera Barat": "Sumbar",
    "Riau": "Riau", "Jambi": "Jambi", "Sumatera Selatan": "Sumsel",
    "Bengkulu": "Bengkulu", "Lampung": "Lampung",
    "Kep. Bangka Belitung": "Babel", "Kep. Riau": "Kepri",
    "DKI Jakarta": "Jakarta", "Jawa Barat": "Jabar", "Jawa Tengah": "Jateng",
    "DI Yogyakarta": "Yogya", "Jawa Timur": "Jatim", "Banten": "Banten",
    "Bali": "Bali", "Nusa Tenggara Barat": "NTB", "Nusa Tenggara Timur": "NTT",
    "Kalimantan Barat": "Kalbar", "Kalimantan Tengah": "Kalteng",
    "Kalimantan Selatan": "Kalsel", "Kalimantan Timur": "Kaltim",
    "Kalimantan Utara": "Kaltara",
    "Sulawesi Utara": "Sulut", "Sulawesi Tengah": "Sulteng",
    "Sulawesi Selatan": "Sulsel", "Sulawesi Tenggara": "Sultra",
    "Gorontalo": "Gorontalo", "Sulawesi Barat": "Sulbar",
    "Maluku": "Maluku", "Maluku Utara": "Malut",
    "Papua": "Papua", "Papua Barat": "Pabar",
}


def rp(trn):
    """Rupiah in trillion, with an Indonesian decimal comma."""
    text = f"{trn:.0f}" if abs(trn) >= 10 else f"{trn:.1f}"
    return text.replace(".", ",")
# Label offset in degrees, away from the point and toward open water where possible.
_NUDGE_DEG = {
    "Aceh": (-2.2, 0.7), "Sumatera Utara": (-2.6, 0.9), "Sumatera Barat": (-2.8, 0.1),
    "Riau": (1.6, 0.8), "Jambi": (1.6, -0.5), "Sumatera Selatan": (1.5, -0.9),
    "Bengkulu": (-2.6, -0.5), "Lampung": (-2.2, -0.9),
    "Kep. Bangka Belitung": (1.4, 0.7), "Kep. Riau": (1.6, 0.9),
    "DKI Jakarta": (-2.4, 1.0), "Banten": (-2.8, -0.7), "Jawa Barat": (0.2, -1.15),
    "Jawa Tengah": (0.2, 0.9), "DI Yogyakarta": (0.5, -1.15), "Jawa Timur": (1.6, -0.45),
    "Bali": (1.1, -0.8), "Nusa Tenggara Barat": (0.8, -0.85), "Nusa Tenggara Timur": (1.2, -0.55),
    "Kalimantan Barat": (-2.0, 0.7), "Kalimantan Tengah": (0.8, -0.9),
    "Kalimantan Selatan": (1.2, -0.8), "Kalimantan Timur": (1.6, 0.45),
    "Kalimantan Utara": (1.5, 0.7),
    "Sulawesi Utara": (1.5, 0.55), "Gorontalo": (-2.2, 0.55),
    "Sulawesi Tengah": (1.6, 0.25), "Sulawesi Barat": (-2.2, -0.15),
    "Sulawesi Selatan": (1.5, -0.7), "Sulawesi Tenggara": (1.6, -0.25),
    "Maluku": (1.5, -0.45), "Maluku Utara": (1.5, 0.6),
    "Papua": (1.8, 0.35), "Papua Barat": (-2.0, 0.7),
}


def _province_buyers(edges):
    """Buyers to draw for one commodity.

    Every selling province keeps its two largest buyers, and any buyer that
    takes at least a fifth of that province's off-province sales. Outside Java,
    a corridor of at least Rp 5 trillion is also kept, so a third eastern buyer
    is not dropped behind two larger ones. Corridors under Rp 0.05 trillion
    are not drawn.
    """
    parts = []
    floor = 0.05 * TRILLION
    for _, psub in edges.groupby("origin_province_name", sort=False):
        psub = psub.loc[psub.value.ge(floor)].sort_values("value", ascending=False)
        if psub.empty:
            continue
        share = psub.value / psub.value.sum()
        rank = psub.value.rank(ascending=False, method="first")
        extra = (psub.value >= 5 * TRILLION) & psub.origin_island.ne("Java")
        mask = (rank <= 2) | (share >= 0.20) | extra
        parts.append(psub.loc[mask])
    if not parts:
        return edges.iloc[0:0]
    return pd.concat(parts, ignore_index=True)


def _spread_labels(items, scale=1.0):
    """Push labels apart in degrees. Each item is [name, x, y, lx, ly]."""
    near_x = 2.8 * scale
    near_y = 0.78 * scale
    step_x = 1.5 * scale
    step_y = 0.48 * scale
    for _ in range(12):
        for i in range(len(items)):
            for j in range(i):
                dx = items[i][3] - items[j][3]
                dy = items[i][4] - items[j][4]
                if abs(dx) < near_x and abs(dy) < near_y:
                    if abs(dx) <= abs(dy) * 2.2:
                        items[i][3] += step_x if dx >= 0 else -step_x
                    else:
                        items[i][4] += step_y if dy >= 0 else -step_y
    return items




def _near(origin, dest, cent, limit=11.0):
    ax, ay = cent[origin]
    bx, by = cent[dest]
    return max(abs(ax - bx), abs(ay - by)) <= limit


def _zoom_bounds(names, cent, pad=0.7):
    xs = [cent[n][0] for n in names]
    ys = [cent[n][1] for n in names]
    x0, x1 = min(xs) - pad, max(xs) + pad
    y0, y1 = min(ys) - pad, max(ys) + pad
    if x1 - x0 < 5.5:
        mid = (x0 + x1) / 2
        x0, x1 = mid - 2.75, mid + 2.75
    if y1 - y0 < 3.2:
        mid = (y0 + y1) / 2
        y0, y1 = mid - 1.6, mid + 1.6
    return x0, x1, y0, y1


def _ray_box(cx, cy, tx, ty, box):
    """Where the ray from (cx, cy) toward (tx, ty) meets the rectangle."""
    x0, x1, y0, y1 = box
    dx, dy = tx - cx, ty - cy
    hits = []
    if abs(dx) > 1e-9:
        for edge in (x0, x1):
            t = (edge - cx) / dx
            y = cy + t * dy
            if t > 0 and y0 <= y <= y1:
                hits.append((t, edge, y))
    if abs(dy) > 1e-9:
        for edge in (y0, y1):
            t = (edge - cy) / dy
            x = cx + t * dx
            if t > 0 and x0 <= x <= x1:
                hits.append((t, x, edge))
    if not hits:
        return tx, ty
    hits.sort(key=lambda item: item[0])
    return hits[0][1], hits[0][2]


def _spread_on_box(points, box, gap=0.95):
    """Separate labels that landed on the same edge. Each point is [name, x, y]."""
    x0, x1, y0, y1 = box
    for _ in range(len(points) + 1):
        moved = False
        for i in range(len(points)):
            for j in range(i):
                pi, pj = points[i], points[j]
                same_x = abs(pi[1] - pj[1]) < 0.4 and min(abs(pi[1] - x0), abs(pi[1] - x1)) < 0.4
                same_y = abs(pi[2] - pj[2]) < 0.4 and min(abs(pi[2] - y0), abs(pi[2] - y1)) < 0.4
                if same_x and abs(pi[2] - pj[2]) < gap:
                    mid = (pi[2] + pj[2]) / 2
                    hi, lo = mid + gap / 2, mid - gap / 2
                    if pi[2] >= pj[2]:
                        pi[2], pj[2] = hi, lo
                    else:
                        pi[2], pj[2] = lo, hi
                    pi[2] = min(max(pi[2], y0), y1)
                    pj[2] = min(max(pj[2], y0), y1)
                    moved = True
                elif same_y and abs(pi[1] - pj[1]) < gap:
                    mid = (pi[1] + pj[1]) / 2
                    hi, lo = mid + gap / 2, mid - gap / 2
                    if pi[1] >= pj[1]:
                        pi[1], pj[1] = hi, lo
                    else:
                        pi[1], pj[1] = lo, hi
                    pi[1] = min(max(pi[1], x0), x1)
                    pj[1] = min(max(pj[1], x0), x1)
                    moved = True
        if not moved:
            break
    return points


# Primer is agriculture and mining. Sekunder is processing, utilities, and
# construction. Tersier is trade and services. A corridor is kept when it is
# one of a commodity's main buyers, then every commodity in the group is drawn
# together so the island's web is one picture.
FLOW_GROUPS = (
    ("primer", "Primer", ("A", "B"),
     "Pertanian dan pertambangan."),
    ("sekunder", "Sekunder", ("C", "D", "E", "F"),
     "Industri pengolahan, listrik, air, dan konstruksi."),
    ("tersier", "Tersier", ("G", "H", "I", "J", "K", "L", "MN", "O", "P", "Q", "RSTU"),
     "Perdagangan dan jasa."),
)


def group_flow_maps(flows):
    """Three maps: primary, secondary, and tertiary.

    Each panel is one selling island. Every commodity in the group contributes
    its main buyers, and those corridors are drawn together, including the long
    ones. Width is the group's rupiah on that corridor, scaled inside the panel.
    Arrow color is the buying island.
    """
    import geopandas as gpd
    from matplotlib.lines import Line2D

    g = gpd.read_file(GADM)[["NAME_1", "geometry"]]
    g["province"] = g.NAME_1.map({v: k for k, v in GADM_NAME.items()})
    if g.province.isna().any():
        raise KeyError("GADM name missing from the province map")
    pts = g.geometry.representative_point()
    cent = {prov: (float(x), float(y)) for prov, x, y in zip(g.province, pts.x, pts.y)}
    away = flows.loc[~flows.same_province & flows.value.gt(0)].copy()
    edges = (away.groupby(
        ["origin_sector_code", "origin_province_name", "dest_province_name",
         "origin_island", "dest_island"],
        as_index=False,
    ).value.sum())

    def arrows(ax, frame, vmax, coord, zorder=3):
        ordered = frame.sort_values("value")
        for i, r in enumerate(ordered.itertuples(index=False)):
            a = coord[r.origin_province_name]
            b = coord[r.dest_province_name]
            span = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
            sign = 1 if i % 2 == 0 else -1
            bend = 0.02 if span >= 4.5 else (0.16 + 0.05 * (i % 3))
            lw = 0.7 + 3.6 * (r.value / vmax)
            ax.annotate(
                "", xy=b, xytext=a,
                arrowprops=dict(
                    arrowstyle="-|>", color=ISLAND_COLOR[r.dest_island], lw=lw,
                    mutation_scale=7 + lw,
                    connectionstyle=f"arc3,rad={bend * sign}",
                    shrinkA=7, shrinkB=7,
                ),
                zorder=zorder,
            )

    def dots(ax, names, bounds):
        x0, x1, y0, y1 = bounds
        scale = max((x1 - x0) / 46.0, (y1 - y0) / 17.0, 0.28)
        items = []
        for name in names:
            x, y = cent[name]
            dx, dy = _NUDGE_DEG.get(name, (0.8, 0.4))
            items.append([name, x, y, x + dx * scale, y + dy * scale])
        _spread_labels(items, scale)
        mx = 0.06 * (x1 - x0)
        my = 0.07 * (y1 - y0)
        for name, x, y, lx, ly in items:
            lx = min(max(lx, x0 + mx), x1 - mx)
            ly = min(max(ly, y0 + my), y1 - my)
            ax.scatter([x], [y], s=22, color=ISLAND_COLOR[ISLAND[name]], zorder=4, linewidths=0)
            ax.annotate(
                MAP_LABEL[name], (lx, ly), fontsize=8.5, color=NAVY, ha="center", va="center",
                zorder=5, bbox=dict(facecolor="white", edgecolor="none", alpha=0.9, pad=0.15),
            )

    kept_frames = []
    for slug, title, codes, blurb in FLOW_GROUPS:
        selected = []
        for code in codes:
            part = _province_buyers(edges.loc[edges.origin_sector_code.eq(code)])
            if not part.empty:
                selected.append(part)
        if not selected:
            continue
        pairs = pd.concat(selected, ignore_index=True)
        keys = ["origin_province_name", "dest_province_name"]
        link = (edges.loc[edges.origin_sector_code.isin(codes)]
                .groupby(keys + ["origin_island", "dest_island"], as_index=False)
                .value.sum())
        kept = pairs[keys].drop_duplicates().merge(link, on=keys, how="left")
        kept["group"] = slug
        kept_frames.append(kept)
        islands = [i for i in ISLAND_ORDER if (kept.origin_island == i).any()]
        ncols = 2 if len(islands) > 1 else 1
        nrows = int(np.ceil(len(islands) / ncols))
        fig, axes = plt.subplots(nrows, ncols, figsize=(15.8, 6.15 * nrows + 0.7), squeeze=False)
        flat = list(axes.ravel())
        for ax, island in zip(flat, islands):
            panel = kept.loc[kept.origin_island.eq(island)].sort_values("value", ascending=False)
            poly = g.loc[g.province.map(ISLAND).eq(island)]
            minx, miny, maxx, maxy = (float(v) for v in poly.total_bounds)
            ix0, iy0, ix1, iy1 = minx - 0.35, miny - 0.35, maxx + 0.35, maxy + 0.35
            intra = panel.loc[panel.dest_island.eq(island)]
            inter = panel.loc[~panel.dest_island.eq(island)]
            ext = (inter.groupby(["dest_province_name", "dest_island"], as_index=False).value.sum()
                   if not inter.empty else inter.iloc[0:0])
            icx, icy = (minx + maxx) / 2, (miny + maxy) / 2
            groups = {"east": [], "west": [], "north": [], "south": []}
            amounts = {}
            for r in ext.itertuples(index=False):
                tx, ty = cent[r.dest_province_name]
                hx, hy = _ray_box(icx, icy, tx, ty, (minx, maxx, miny, maxy))
                dist = {
                    "west": abs(hx - minx), "east": abs(hx - maxx),
                    "south": abs(hy - miny), "north": abs(hy - maxy),
                }
                groups[min(dist, key=dist.get)].append(r.dest_province_name)
                amounts[r.dest_province_name] = float(r.value)
            x0, x1, y0, y1 = ix0, ix1, iy0, iy1
            if groups["west"]:
                x0 -= 7.4
            if groups["east"]:
                x1 += 7.4
            if groups["south"]:
                y0 -= 3.3
            if groups["north"]:
                y1 += 3.3
            coord = {
                name: cent[name]
                for name in set(panel.origin_province_name) | set(intra.dest_province_name)
            }

            def slots(n, lo, hi):
                if n == 1:
                    return [(lo + hi) / 2]
                a, b = lo + 0.08 * (hi - lo), hi - 0.08 * (hi - lo)
                return [a + (b - a) * i / (n - 1) for i in range(n)]

            placed = []
            face = {
                "east": (iy0, iy1, 1.25),
                "west": (iy0, iy1, 1.25),
                "north": (ix0, ix1, 2.8),
                "south": (ix0, ix1, 2.8),
            }
            for side, names in groups.items():
                if not names:
                    continue
                lo, hi, gap = face[side]
                inset = 1.15
                if side in ("south", "north"):
                    if groups["west"]:
                        lo += inset
                    if groups["east"]:
                        hi -= inset
                else:
                    if groups["south"]:
                        lo += inset
                    if groups["north"]:
                        hi -= inset
                if hi - lo < gap:
                    lo, hi, _gap = face[side]
                need = len(names) * gap
                if need > hi - lo:
                    extra = need - (hi - lo)
                    lo -= extra / 2
                    hi += extra / 2
                    if side in ("east", "west"):
                        y0, y1 = min(y0, lo - 0.25), max(y1, hi + 0.25)
                    else:
                        x0, x1 = min(x0, lo - 0.4), max(x1, hi + 0.4)
                if side in ("east", "west"):
                    ordered = sorted(names, key=lambda n: cent[n][1])
                    xs = ix0 - 1.35 if side == "west" else ix1 + 1.35
                    for name, y in zip(ordered, slots(len(ordered), lo, hi)):
                        coord[name] = (xs, y)
                        placed.append((name, xs, y, side))
                else:
                    ordered = sorted(names, key=lambda n: cent[n][0])
                    ys = iy1 + 1.45 if side == "north" else iy0 - 1.45
                    for name, x in zip(ordered, slots(len(ordered), lo, hi)):
                        coord[name] = (x, ys)
                        placed.append((name, x, ys, side))
            poly.plot(ax=ax, color="#F7F4EF", edgecolor="#E2E5EA", linewidth=0.45)
            ax.set_axis_off()
            ax.set_xlim(x0, x1)
            ax.set_ylim(y0, y1)
            ax.set_aspect("equal", adjustable="box")
            vmax = float(panel.value.max())
            if not inter.empty:
                arrows(ax, inter, vmax, coord, zorder=2)
            if not intra.empty:
                arrows(ax, intra, vmax, coord, zorder=3)
            geo = sorted(set(panel.origin_province_name) | set(intra.dest_province_name))
            dots(ax, geo, (ix0, ix1, iy0, iy1))
            anchors = {
                "east": ("left", "center", (5, 0)),
                "west": ("right", "center", (-5, 0)),
                "north": ("center", "bottom", (0, 4)),
                "south": ("center", "top", (0, -5)),
            }
            for name, x, y, side in placed:
                ha, va, shift = anchors[side]
                ax.scatter([x], [y], s=18, color=ISLAND_COLOR[ISLAND[name]], zorder=4, linewidths=0)
                ax.annotate(
                    f"{MAP_LABEL[name]}  {rp(amounts[name] / TRILLION)}",
                    (x, y), fontsize=8, color=NAVY, ha=ha, va=va,
                    xytext=shift, textcoords="offset points",
                    zorder=5, bbox=dict(facecolor="white", edgecolor="none", alpha=0.92, pad=0.12),
                )
            ax.set_title(
                f"{ISLAND_SHORT[island]}, {len(panel)} koridor",
                loc="left", fontsize=10.5, color=NAVY, pad=8,
            )
        for ax in flat[len(islands):]:
            ax.set_axis_off()
        handles = [
            Line2D([0], [0], color=ISLAND_COLOR[i], lw=2.4, label=ISLAND_SHORT[i])
            for i in ISLAND_ORDER
        ]
        fig.legend(handles=handles, frameon=False, fontsize=8.5, ncol=7,
                   loc="lower center", bbox_to_anchor=(0.5, 0.0))
        head(
            fig,
            f"Aliran {title.lower()} antarprovinsi, 2025",
            f"{blurb} Penggunaan antara, transaksi RAS. "
            f"Setiap komoditas menyumbang pembeli utamanya, lalu koridor itu "
            f"digambar bersama, {len(kept)} panah. "
            "Peta hanya pulau penjual. Panah di dalam pulau memakai letak yang sebenarnya. "
            "Pembeli di pulau lain disebut di tepi, pada arah pulau itu. "
            "Angka di tepi menjumlahkan koridor ke pembeli itu, dalam triliun rupiah. "
            "Lebar panah memakai skala pulau penjual. Warna adalah pulau pembeli.",
            top=0.90,
        )
        save(fig, f"02_flow_{slug}.png")
        plt.close(fig)
    if not kept_frames:
        return edges.iloc[0:0]
    return pd.concat(kept_frames, ignore_index=True)


def commodity_purchase_bars(flows, codes=None, floor=0.05):
    """One bar chart per commodity: what each province buys from other provinces.

    A province with nothing above the floor is left off that chart.
    A commodity with no such province is not drawn.
    """
    codes = list(SECTOR_ORDER if codes is None else codes)
    bought = flows.loc[~flows.same_province & flows.value.gt(0)]
    for code in codes:
        sub = bought.loc[bought.origin_sector_code.eq(code)]
        totals = sub.groupby("dest_province_name").value.sum()
        totals = totals.loc[totals.ge(floor * TRILLION)].sort_values()
        if totals.empty:
            continue
        fig, ax = plt.subplots(figsize=(10.6, max(3.4, 0.34 * len(totals) + 1.15)))
        colors = [ISLAND_COLOR[ISLAND[name]] for name in totals.index]
        ax.barh(range(len(totals)), totals.to_numpy() / TRILLION, color=colors, height=0.72)
        ax.set_yticks(range(len(totals)))
        ax.set_yticklabels([SHORT[name] for name in totals.index], fontsize=9)
        ax.set_xlabel("Triliun rupiah")
        clean(ax, grid="x")
        head(
            fig,
            f"Pembelian antarprovinsi, {SECTOR_LABEL[code].lower()}, 2025",
            "Pembelian dari provinsi lain untuk penggunaan antara, transaksi RAS, dalam triliun rupiah. "
            "Provinsi tanpa pembelian di atas Rp 0,05 triliun tidak ditampilkan. Warna adalah pulau pembeli.",
            top=0.86,
        )
        save(fig, f"02_beli_{code}.png")
        plt.close(fig)
