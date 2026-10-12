# TFP construction and vintage mismatch

Date: 7 September 2026. Companion analysis: `spatial_tfp_analysis.py` (this folder),
outputs `spatial_*.csv` and `meanplay_*.csv`. All numbers below were verified
numerically against the files cited; nothing is quoted from memory.

## 1. What TFP is in this project (algebra)

The production function is Cobb–Douglas with **two distinct elasticities**:

```
Y_it = A_it * K_it^b1 * L_it^b2
log Y_it = log A_it + b1 log K_it + b2 log L_it
```

Estimation adds province effects, year effects, and noise:

```
log Y_it = a + u_i + lambda_t + b1 log K_it + b2 log L_it + e_it
```

TFP is **not** the constant `a` alone. The series written to disk is the full
Solow residual — everything output does that the two inputs do not explain:

```
logtfp_it = log Y_it - b1 log K_it - b2 log L_it  =  a + u_i + lambda_t + e_it
```

(`02 Code/TFP/estimasi/01_estimasi tfp.R`, section 8.) It therefore contains,
in one number per province-year:

| Component | Meaning | Share of variance (vintage C DV) |
|---|---|---|
| `u_i` | permanent province level ("who you are") | ~95% between provinces |
| `lambda_t` | the common national year path | rises +0.23 log pts 2017→2025 |
| `e_it` | idiosyncratic leftover | small |
| scale term | because b1+b2 ≈ 0.55 < 1, size leaks into the residual | inflates large provinces |

The CRS twin removes the scale term by construction:
`logtfp_it_crs = log(Y/L) - b1_crs * log(K/L)` with `b2 = 1 - b1`. Its **level**
is a different object (per-worker form); only changes and rankings are usable.

Why it was built this way (documented in
`02 Code/TFP/docs/00 Docs/spesifikasi-model-tfp.md`):

- **Elasticities estimated, not imposed.** Indonesian measured labour shares
  (0.13–0.18 in this data; van der Eng 2010 nationally 0.28–0.51) are
  inconsistent with the textbook alpha = 1/3; the competitive-markets + CRS
  assumptions needed to read elasticities off income shares fail here.
- **K = real PMTB flow, not capital stock.** A documented proxy; no PIM stock
  exists at province level for this window. The residual is therefore a
  *PMTB-flow production residual*, not Hicks-neutral technology.
- **Two-way FE** chosen by the pre-registered cascade S0–S6 (Mundlak rejects
  RE; year effects jointly significant; Driscoll–Kraay SEs because Pesaran CD
  still rejects after year effects).

## 2. How TFP entered the determinant models

The Stata do-file (`02 Code/TFP/Determinan TFP Provinsi BKPM.do`) **never
re-estimates b1, b2**. It imports sheet `Analisis Luaran 2` of
`Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` and takes the
pasted `logtfp_it` column as the dependent variable. That column arrived by
a manual block paste of nine columns (CD:CL — `logtfp_it`, `logtfp_it_crs`,
growth terms and contributions), the workflow described in scripts 13/16.

## 3. The vintage mismatch, verified cell by cell

Three series circulate for the same cell. Aceh 2017:

| Series | File | logtfp Aceh 2017 | Construction (recovered numerically) |
|---|---|---|---|
| **Vintage B** | `01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx`, `data_tfp` | **23.2577** | exact: b1=0.401899, b2=0.147184, 2017–2024, N=272 (R² of reconstruction = 1.000) |
| **Predicted Value** | `01 Data/TFP/processed/Predicted Value TFP 2017-2025.xlsx`, `ADHK` | **22.1398** | b1≈0.471, b2≈0.138 → the 2017–2025 run (b1=0.4753, b2=0.1358) with LOCF 2025 labour |
| **Stata DV (vintage C)** | `01 Data/TFP/Determinan TFP Provinsi BKPM.dta` | **16.0248** | see below |

Findings from the reconstruction exercise (`spatial_tfp_analysis.py` preamble
work, run 2026-09-07):

1. **The 7 September Stata run regressed exactly the vintage C series.**
   `logtfp_it` in the `.dta` equals the `Indices` sheet of
   `01 Data/TFP/processed/99 vintage_determinan/Determinan TFP Results.xlsx`
   with **max difference 0.0** across all 306 cells. The new determinant
   tables are therefore *still* determinants of the old TFP paste — not of
   vintage B, and not of the Predicted Value series.
2. **Vintage C cannot be reconstructed from any surviving dataset.** Best
   linear fit over every (Y, K, L) combination in the current and archived
   workbooks: b1≈0.47, b2≈0.08, R²≈0.985 — close, never exact. Its generator
   and input data are not in the repo (consistent with
   `01 Data/TFP/processed/99 vintage_determinan/README.md`).
3. **The series agree on rank, not on level or dynamics.** Correlations with
   vintage B: 0.99 in levels, but **0.92 within-province** — the within
   variation the FE models actually use differs materially.

## 4. A fourth vintage is already in the making

The current workbook's `Sheet1` no longer contains the data vintage B was
estimated on. Verified against the log columns embedded in
`Hasil Estimasi TFP.xlsx`:

- `9_ADHK` (Y): 237 of 272 cells differ (small revisions, sd ≈ 0.012 log pts,
  plus a unit change juta → miliar).
- `4_ADHK` (K): 248 of 272 cells differ (sd ≈ 0.023), including **three 2024
  cells revised by up to 0.31 log points (~36%)**.

Re-running the identical two-way FE on today's Sheet1 (2017–2024, N=272)
gives **b1 = 0.387, b2 = 0.193, RTS = 0.580** — not 0.402 / 0.147 / 0.549.
The implementation was validated first: on vintage B's own embedded data it
reproduces b1=0.401899, b2=0.147184 exactly. The elasticities move this much
from small input revisions alone; that fragility should be quoted alongside
any point estimate.

## 5. What this means before any freeze decision

- Do not describe the determinant tables as "determinants of the current
  TFP". They are determinants of vintage C, whose construction is
  unrecoverable.
- Any re-run of `01_estimasi tfp.R` today creates a fourth set of numbers.
  Freezing a vintage now means freezing **data + code + outputs together**
  (the SHA-256 table in `02 Code/TFP/docs/VINTAGE.md` is the right pattern).
- Until a freeze: spatial work below uses vintage B parameters (b1=0.402,
  b2=0.147) applied to clearly labelled data, and the determinant mean-play
  uses the Stata DV labelled as vintage C. The two are never mixed.

## 6. Spatial results (Phase 1) — summary

Full tables: `spatial_trackA_island_residual.csv`,
`spatial_trackA_province_trends.csv`, `spatial_trackB_island_elasticities.csv`.

**Track A (one national technology, differences are residuals).** Island
residual index 2017=100, national b1, b2, island-aggregated Y, K, L:
Sulawesi 125.0 (fastest, +3.2 log pts/yr), Jawa 118.4, Sumatera 114.5,
Maluku-Papua 114.1 (with a deep 2019–20 trough at 92), Kalimantan 110.5,
Bali-Nusra 109.1 (slowest). Province CRS trends group the same way:
Sulawesi/Jawa/Kalimantan medians ~1.4 pp/yr; Bali-Nusra and Maluku-Papua
medians ~0.4–0.5 pp/yr with negative-trend members.

**Track B (island-specific technology, sensitivity only).** Re-estimating the
TWFE Cobb–Douglas inside each island collapses it: Jawa b1≈0.01, Sumatera
b1≈−0.02, Kalimantan b1≈−0.21, Sulawesi b2≈−0.38. With 3–10 clusters and
T=8 there is not enough within-island variation to identify a production
function. Implication: the national b1=0.40 is identified mainly from
**cross-island contrast**, not from within-island time series — one more
reason to treat the elasticities as descriptive weights, not technology.
Track B levels must never be ranked across islands.

## 7. Mean-play results (Phase 3) — summary

Full tables: `meanplay_between_regression.csv`,
`meanplay_equalize_island_means.csv`, `meanplay_leave_one_island_out.csv`.
DV = vintage C (as regressed in Stata). FE2W replication matched the
published table (idx_inst 0.0488) before any experiment.

- **Between regression (34 province means):** R² = 0.72; connectivity mean
  0.431 (SE 0.09) is the only strong coefficient — consistent with the CRE
  Mundlak mean 0.418 in the Stata output. Institutions mean 0.175 (SE 0.14),
  HR and wages ≈ 0.
- **Equalize connectivity means:** closing each island's connectivity mean to
  the national mean closes **~78% of Jawa's +0.71 gap** and **~100% of
  Maluku-Papua's −0.47 gap** (Kalimantan's ratio is unstable because its gap
  is ~0). Institutions closes ~14% (Jawa) to ~38% (Maluku-Papua); HR closes
  nothing. Caveat: connectivity contains PDRB-allocated cargo, so part of
  this is mechanical.
- **Leave-one-island-out FE2W:** institutions swings 0.009–0.072 depending on
  which island is dropped (Kalimantan out → 0.009; Jawa out → 0.072); HR
  flips to −0.13 when Maluku-Papua is dropped. No pillar is stable.
- **Island-stratified FE2W** (only Sumatera G=10 and Jawa G=6 estimable):
  signs disagree between the two islands on every pillar.

Bottom line: the between/"map" layer carries the only economically large
association (connectivity ≈ 0.42–0.43 per SD), and the within layer is not
robust to any spatial perturbation. Policy language should follow the
transmission-test framing of the review note, not a determinants table.
