# Evaluation of the TFP analysis and implications for BKPM

Review date: 5 September 2026  
Scope: current project code, logs, workbooks, figures, determinant results, BKPM–PMTB analysis, IO/IRIO outputs, the National Productivity Master Plan, and targeted external literature checks through Scite and primary sources.

## Executive judgment

The project contains a useful **descriptive investment–productivity diagnostic**, but it does not yet contain a defensible structural estimate of technology, capital stranding, or the causal determinants of TFP.

The strongest policy conclusion that the evidence supports is:

> Recent growth and investment data reveal a possible weakness in the transmission of capital expenditure into productivity, labor capability, domestic supplier development, and technology diffusion. BKPM should test that transmission directly and make verified productivity additionality—not investment value alone—a central project KPI.

It is not yet defensible to conclude:

> “Capital is stranded because 64% of growth came from capital and TFP grew only 0.81%.”

That statement comes from an older report version. The current outputs produce materially different results, and neither version observes asset utilization or impairment.

## 1. First resolve the version conflict

The report and current output were generated from different vintages.

| Item | Older report | Current output |
|---|---:|---:|
| Production elasticity of PMTB | 0.400 | 0.402 |
| Production elasticity of labor | 0.191 | 0.147 |
| Estimated returns to scale | 0.591 | 0.549 |
| Main estimated TFP trend | 0.81%/year | 1.92%/year |
| Capital share of 2018–2024 growth | 64% | 34.2% in the unrestricted model |
| Residual share of 2018–2024 growth | 26% | 57.8% in the unrestricted model |

The older values are in `Report TFP.md`, modified at 02:58. The main estimation code and output workbook were updated at about 11:15 and 11:13 on the same date. The determinant workbook predates the new TFP run and contains 306 province-years through 2025, whereas the current TFP estimation has 272 usable observations for 34 provinces in 2017–2024. For example, the determinant workbook's Aceh 2017 TFP values do not equal either current TFP series. The determinant results are therefore not results for the present TFP measure.

Before any substantive revision, freeze a release folder containing the code, input hashes, output files, report, and creation time. No determinant-model generator was found in the repository; only its result workbook and table were found. This prevents replication and must be corrected.

## 2. What the current TFP model actually estimates

The model is a province panel production regression:

\[
\log Y_{it}=\alpha_i+\lambda_t+\beta_K\log I_{it}+\beta_L\log L_{it}+\varepsilon_{it},
\]

where:

- \(Y\) is real PDRB (ADHK);
- \(I\) is real PMTB, an annual **investment flow**;
- \(L\) is number of employed workers;
- \(\alpha_i\) is a province fixed effect;
- \(\lambda_t\) is a year fixed effect; and
- reported uncertainty uses Driscoll–Kraay standard errors.

The selected unrestricted model gives \(\beta_K=0.4019\), \(\beta_L=0.1472\), and \(\beta_K+\beta_L=0.5491\). The calculated province-year “TFP” is the residual quantity

\[
\log \widehat A_{it}=\log Y_{it}-\widehat\beta_K\log I_{it}-\widehat\beta_L\log L_{it}.
\]

This is best described as a **production-function residual using PMTB as a capital proxy**, not as a clean measure of Hicks-neutral technology.

### Current growth decomposition

Average annual log growth in 2018–2024 is 3.83% for real PDRB, 3.26% for real PMTB, and 2.08% for employment. The result depends heavily on how factor weights and capital are defined.

| Scenario | Capital contribution | Labor contribution | Residual | Residual share |
|---|---:|---:|---:|---:|
| Unrestricted two-way FE, current “main” | 1.31 pp | 0.31 pp | 2.21 pp | 57.8% |
| Estimated model constrained to CRS | 1.47 pp | 1.14 pp | 1.22 pp | 31.8% |
| Growth regression normalized to CRS | 0.94 pp | 1.48 pp | 1.41 pp | 36.8% |
| Measured income share | 2.74 pp | 0.33 pp | 0.76 pp | 19.7% |
| Conventional capital share of one third | 1.09 pp | 1.38 pp | 1.36 pp | 35.4% |
| Short-series PIM sensitivity, CRS | 1.64 pp | 1.14 pp | 1.05 pp | 27.3% |

The interval—roughly 0.76 to 2.21 percentage points for the residual—is the finding. Selecting one endpoint as “the” TFP estimate is not warranted.

The current code also reverses the official 8-4-2-2 allocation. It defines the target as 4 percentage points from capital, 2 from labor, and 2 from TFP. The official master plan defines 8% growth as **4 points from labor, 2 from capital, and 2 from TFP**. Consequently, the current gap table and strategy chart should not be used until corrected.

## 3. Method evaluation

| Component | What was done well | Main problem | Defensible use |
|---|---|---|---|
| Real output | ADHK is used in the main model; ADHB is retained only as a contrast | Aggregated provincial PDRB is not identical to national PDB | Descriptive provincial panel |
| Panel structure | Province effects and common year shocks are recognized | Only eight usable years; most variation is removed by FE | Short-run within-province association |
| Error covariance | Heteroskedasticity, serial correlation, and cross-sectional dependence are tested | Driscoll–Kraay relies on a time dimension that is not persuasive at T=8; cross-dependence remains significant | Sensitivity only |
| Returns to scale | CRS is explicitly tested and alternative scenarios are shown | The estimated DRS can be caused by PMTB measurement error, aggregation, omitted inputs, or endogeneity; it is not evidence of a technological law | A warning that the specification is unstable |
| Functional form | Cobb–Douglas is transparent | RESET rejects the FE and RE specifications; translog/nonlinearity is omitted | Baseline comparison only |
| Robustness | Weighted, lagged-PMTB, CRS, PIM, and growth versions are shown | Coefficients vary substantially: e.g. capital 0.321 weighted, 0.419 lagged, and 0.112 in growth form | Report a specification envelope |
| Province results | Both raw and CRS trends are produced | Non-CRS TFP levels mechanically retain scale; large provinces dominate the rankings | Use within-province CRS change, not raw level rank |
| Annual results | Annual decompositions are produced | The method note warns against annual interpretation, while another script produces annual contributions | Use multi-year averages |

### The central theoretical issue: PMTB is not capital stock or capital services

BPS defines PMTB as acquisitions less disposals of fixed assets during a period. It is a flow. A production function requires the productive stock or service flow generated by accumulated assets. A province with a large inherited stock and little new investment can produce much output with low PMTB; a province building a large unfinished plant can record high PMTB before producing output. Treating PMTB as \(K\) therefore mixes accumulation, gestation lags, asset composition, and utilization.

The literature used in the project recognizes three distinct approaches:

1. **Growth accounting** uses capital stock/services and time-varying factor-income shares under CRS and competitive-factor assumptions.
2. **Estimated production functions** estimate elasticities but must address endogenous input choice, measurement error, omitted inputs, and functional form.
3. **DEA/SFA frontier methods** estimate relative efficiency and technical change, but answer a different question from contribution-to-growth accounting.

The project currently combines the language of approach 1 with a regression closer to approach 2 and a capital variable that is neither capital stock nor services. Production-function work since Olley–Pakes, Levinsohn–Petrin, Wooldridge, and Ackerberg–Caves–Frazer shows why input choices correlated with latent productivity make ordinary FE/OLS coefficients inconsistent. Driscoll–Kraay changes standard errors; it does not fix that endogeneity.

### Why the non-CRS province ranking is not a productivity ranking

With \(\beta_K+\beta_L=0.549\), proportionally scaling output and inputs adds a scale term to the residual. Thus the raw residual level contains province size. This explains why DKI Jakarta and the large Java provinces lead the level ranking. It should not be presented as “most productive province.” Use:

- growth or within-province change in the CRS residual;
- output per worker and capital intensity;
- a properly estimated frontier; or
- sector-adjusted productivity.

The province trend regressions also have only eight observations each. The claim that 29 of 34 trends are significant is an upper bound because autocorrelation and common shocks are not adequately represented in those province-by-province OLS standard errors.

## 4. Evaluation of the five-pillar determinant analysis

The five-pillar taxonomy is not a “BPS model.” BPS supplies much of the data. The substantive framework in the master-plan material is institutions, education, innovation, physical infrastructure, and efficiency. The exact taxonomy closely tracks Kim and Loayza's World Bank productivity framework. One presentation instead cites Adler et al. (2017); that citation trail should be corrected.

The implemented determinant variables do not reproduce the five pillars:

- `idx_hr` approximates education/human resources;
- `idx_inst` combines inflation, local fiscal capacity, spending absorption, crime, and democracy;
- `idx_conn` combines roads and allocated transport volumes;
- `idx_ind` combines wages and firm counts;
- environmental indexes are entered separately;
- there is no direct innovation pillar; and
- “industry” is not a defensible measure of market efficiency.

### PCA construct-validity audit

| Index | PC1 share | KMO | Reliability / loading issue | Judgment |
|---|---:|---:|---|---|
| Human resources | 48.3% | 0.495 | Two eigenvalues exceed one; negative-Gini indicator loads with the wrong sign | Weak one-factor construct |
| Institutions | 42.7% | 0.491 | Three indicators have mixed theoretical polarity; two eigenvalues exceed one | Not interpretable as institutional quality |
| Connectivity | 52.6% | 0.445 | Airport loading is only 0.089; cargo and road dominate | Narrow transport/output proxy |
| Industry | 53.9% | 0.500 | Bartlett p=0.179 and alpha=0.143; only wage and firm count | PCA is not justified |

The result workbook's own interpretation column says KMO values below 0.5 are adequate and the industry Bartlett result is meaningful, even though those values fail its stated thresholds. More importantly, several constructed transport volumes are allocated to provinces in proportion to transport PDRB. Using those variables to explain a PDRB-derived TFP residual introduces mechanical endogeneity.

The newer panel-construction scripts also produce a different institution index from the determinant workbook. Two parallel index systems are therefore circulating under similar names.

### What is actually stable across the model table?

Counting stars over 20 estimators is not a robustness test: the models estimate different objects, share the same measurement problems, and create a multiple-testing problem.

| Variable | Pattern across models | Interpretation |
|---|---|---|
| Human resources | Positive in some static FE/RE models; negative and significant in several dynamic GMM models; near zero in two-way FE/DK | Sign-unstable; no robust conclusion |
| Institutions | Positive and significant in about 11 specifications, but insignificant in two-way FE and several GMM models | Most promising association, but the index itself is not valid enough for policy |
| Connectivity | Positive, significant in about six specifications | Sporadic association; partly mechanically constructed |
| Industry | Significant only in simple/static models; disappears with year FE and dynamics | Not robust to common shocks |
| IKLH / blue | Generally insignificant | No evidence in this design |
| Green | Negative in many static models; disappears in dynamic models | Likely composition, imputation, or trend artifact—not evidence that environmental quality reduces TFP |

The dynamic estimates are also unstable: lagged TFP ranges from about 0.53 in FE to 0.98 in OLS; Anderson–Hsiao has a first-stage F of 5.1; one GMM estimate exceeds the OLS upper bound; and instrument counts are large relative to 34 groups. These results should not be used to select “important” covariates.

## 5. VAR and cointegration: do not proceed with the current panel

Standard VAR/VECM or panel cointegration is not justified by 8–9 annual observations.

- Most variables appear nonstationary under the only test designed for short T in the workbook.
- The cointegration tests conflict at the 5% threshold: Kao p=0.051, while Pedroni and Westerlund reject. These tests do not become reliable merely because one rejects with T=9.
- Cross-sectional dependence is present under the Frees test and in the main TFP model.
- The indexes contain imputation, projections, and common trends; cointegration can capture their construction rather than an economic equilibrium.
- VAR parameter counts grow rapidly, leaving virtually no degrees of freedom.

If a long-run system is required, first extend a consistently measured panel to at least roughly two decades, then use second-generation unit-root and cointegration methods that allow common factors (for example Pesaran CIPS and a bootstrap Westerlund test). A national quarterly VECM is a separate possible design, but it requires a quarterly productivity measure consistent with the inputs. For the present short panel, use transparent changes and multi-year averages, or treat results as descriptive screening.

## 6. “Stranded capital” is a hypothesis to test

In the stranded-assets literature, an asset is stranded when it suffers an unanticipated/premature write-down, devaluation, conversion to a liability, underutilization, or early retirement. A large contribution of capital accumulation to growth does not establish any of those states.

The present data can reveal **weak capital-to-productivity transmission**, but cannot distinguish among:

| Possible condition | Evidence required |
|---|---|
| Announced but not built | Project milestones and realized fixed-asset expenditure |
| Built but not operating | Commercial operation date and operating status |
| Operating below capacity | Installed versus utilized capacity, machine hours, electricity use |
| Financially stranded | Impairment, write-down, debt distress, expected asset life, resale value |
| Misallocated capital | Dispersion in marginal products or firm/project returns within a comparable sector |
| Long-gestation investment | Construction-to-operation lag and sector-specific commissioning periods |
| Productive but embodied technology | Output, quality, energy efficiency, exports, patents/process improvements |

A high PMA+PMDN/PMTB ratio is not a conversion-efficiency measure. It exceeds 100% in some provinces, which is possible because the numerator is an administrative LKPM concept and the denominator is a national-accounts fixed-asset concept with different institutional and expenditure coverage. The ratio is useful as a **coverage and diagnostic flag**, not as proof of capital efficiency or stranding.

Likewise, the low measured labor-income share (15.9% on average) is not evidence that the workforce multiplier is stagnant. The wage-times-worker proxy omits or incompletely captures mixed income, self-employment, employer contributions, hours, and skill quality. The IO workbook explicitly reports that employment and labor-income multipliers are unavailable because sector labor data are missing.

Finally, TKDN is domestic content in goods/services, not investor ownership. PMA/PMDN cannot be used as a TKDN proxy. In 2025, the project data and the official BKPM total show PMDN at approximately 53.4% and PMA at 46.6% nationally, although manufacturing and ICT are strongly PMA-oriented.

## 7. How PMA and PMDN should be displayed against productivity

Do not compute “PMA or PMDN as a share of TFP.” Currency divided by a dimensionless residual has no economic interpretation. Instead, place the variables in a transmission chain:

\[
\text{PMA/PMDN flow}
\rightarrow \text{operational fixed capital}
\rightarrow \text{supplier, worker, and technology channels}
\rightarrow \text{output/value added}
\rightarrow \text{TFP change}.
\]

The current 2025 sector screen is:

| Sector | Share of PMA+PMDN | PMA share within sector | IO output multiplier | Linkage classification | Policy reading |
|---|---:|---:|---:|---|---|
| Manufacturing | 40.5% | 69.1% | 2.06 | Strong backward | Highest leverage for supplier and technology conditions |
| Mining | 10.3% | 38.0% | 1.66 | Strong forward | Require downstream and local-capability transmission |
| Transport & storage | 8.5% | 11.9% | 2.02 | Key in both directions | Network complement that can activate other assets |
| Real estate | 7.3% | 29.0% | 1.46 | Neither | Scrutinize additionality and land-heavy expenditure |
| Trade & repair | 6.1% | 24.4% | 1.54 | Strong forward | Distribution efficiency rather than technology by itself |
| ICT | 5.7% | 70.4% | 1.71 | Strong forward | Tie PMA to diffusion, local engineering, and adoption |
| Electricity & gas | 4.7% | 47.3% | 2.83 | Key in both directions | Strong complement for capacity activation |
| Health & social | 1.6% | 16.4% | 2.19 | Strong backward | Candidate for selective crowd-in; validate employment effects first |

These IO values are fixed-coefficient, estimated cross-entropy results. They show static demand propagation, not productivity, utilization, prices, substitution, technology transfer, or causal employment. The investment-induced value-added share is also influenced by the observed size of each sector's shock. For portfolio targeting, use the per-rupiah multipliers and compare RAS versus cross-entropy estimates.

The accompanying exhibit plots the valid comparison: sector PMA/PMDN composition alongside normalized IO multipliers, and a province screen comparing the CRS TFP trend with the BKPM/PMTB coverage ratio. Papua Barat, Nusa Tenggara Barat, East Kalimantan, and Kepulauan Riau are diagnostic candidates because the investment coverage ratio is comparatively high while the CRS residual trend is near zero or negative. Central Sulawesi and North Maluku are useful counterexamples: high investment intensity is accompanied by positive TFP-residual trends, so high intensity is not itself evidence of stranding.

## 8. The orchestration the analysis should follow

| Layer | Question | Metric | Decision |
|---|---|---|---|
| National | Is growth driven by inputs or productivity? | CRS growth-accounting range using capital stock/services and quality-adjusted labor | Set the national productivity gap |
| Province | Where is transmission weak or strong? | Within-province CRS TFP change, utilization, project activation, labor and supplier outcomes | Diagnose place-specific constraints |
| Sector | Which mechanisms and linkages matter? | Sector TFP change, IO/IRIO per-rupiah BL/FL, value added, employment and wage multipliers | Select sector intervention, not only sector volume |
| Ownership | What does foreign/domestic capital add? | PMA/PMDN split plus actual domestic procurement, training, R&D, management and technology transfer | Design conditionalities; do not proxy TKDN with ownership |
| Project | Did the investment become productive capacity? | Milestone, operating date, capacity utilization, export/output, wage, supplier, and technology KPIs | Release facilitation/incentives by verified milestones |
| Evaluation | Did BKPM action cause additional outcomes? | Matched comparison, staggered event study, or randomized/threshold design where feasible | Continue, change, or terminate the intervention |

This structure preserves the user's national → province → action → sector → PMA/PMDN/PMTB logic while preventing incompatible quantities from being mixed.

## 9. Quick wins for BKPM with long-run productivity value

### 1. Project Activation and Utilization Sprint

Select the largest completed or near-completed projects in high-investment/weak-transmission provinces. Within 90 days, classify each as permitting-, infrastructure-, skills-, supplier-, finance-, or demand-constrained. Publish a “committed → constructed → commercial operation → utilized capacity” dashboard. This directly tests the stranded-capital hypothesis and creates a visible delivery story.

### 2. Productivity Additionality Compact for incentives

Attach measurable covenants to tax holidays, facilitation, and strategic-project support:

- time to commercial operation and capacity-utilization milestones;
- Indonesian technical/managerial positions and verified training/certification;
- wage progression rather than job count alone;
- local supplier contracts, quality certification, and supplier productivity;
- machinery/software/R&D adoption and Indonesian engineering participation; and
- exports, energy efficiency, or other sector-relevant output outcomes.

Report “skills, supplier contracts, and operating capacity per Rp trillion facilitated,” not only realized investment.

### 3. Anchor-firm supplier deepening

Start with PMA-heavy manufacturing and ICT. Use the IRIO/SPA pathways to identify the domestic inputs with the largest indirect value-added channels. Pair anchor firms with qualified local suppliers, standards laboratories, financing, and purchase-order commitments. Evidence from Javorcik and from Blalock–Gertler shows that backward linkages to local suppliers are a plausible FDI productivity channel; horizontal spillovers are not guaranteed.

### 4. Skills-to-production compact

For manufacturing, electricity, transport, ICT, and health, require a jointly signed skill plan among the investor, local training provider, and DPMPTSP. Measure completion, placement, retention, occupational level, and real wage change. This replaces the “tahunya kerja” mindset with “verified capability used in production.”

### 5. Brownfield productivity window

New capital is not the only route. Offer fast facilitation for retrofits, maintenance, digital systems, energy upgrades, and production-line redesign at existing plants, conditional on capacity, supplier, skill, and output improvements. If underutilized capital is the concern, activating existing assets can yield a quicker productivity return than attracting another greenfield commitment.

### 6. Portfolio rebalancing rule

- Preserve manufacturing as the main supplier/technology platform, but condition support on spillovers.
- Treat electricity and transport as activation complements because their linkages are strong in both directions.
- Pilot selective crowd-in for health and business services, after building labor satellite coefficients.
- Subject mining and real-estate projects to stronger downstream, supplier, utilization, and additionality tests rather than blanket incentives.

## 10. Recommended analytical rebuild

1. **Freeze one data vintage and regenerate everything**, including determinants, from code.
2. **Correct the 8-4-2-2 allocation** and regenerate the strategy tables/figures.
3. **Make CRS growth accounting the primary national decomposition.** Use a longer PMTB series to construct capital stocks by asset with alternative depreciation rates; use hours and education-adjusted labor; construct labor shares from compensation plus an explicit mixed-income adjustment.
4. **Retain the current regression as a sensitivity case**, relabeled “PMTB-based production residual.” Add translog tests, lag structures, common-factor controls, and explicit endogeneity discussion.
5. **Build national 17-sector TFP first.** Sector PDRB and labor are available, but sector capital/PMTB by industry is not. Do not substitute PMA/PMDN for the missing capital stock.
6. **Decompose aggregate productivity into within-sector and reallocation terms.** This matches the master plan's two channels: productive efficiency within firms/sectors and allocative efficiency across them.
7. **Rebuild the five pillars from a measurement model.** Define the construct and expected direction first, use observed—not output-allocated—indicators, report missing/imputed shares, validate across time/provinces, and run leave-one-indicator-out sensitivity.
8. **Use a pre-specified determinant model.** With the current short panel, focus on changes, lags, and descriptive partial associations. Do not select covariates by star counts. For causal policy claims, use project/firm panels and quasi-experimental variation.
9. **Add IO labor satellites.** Sector × province employment, hours, compensation, occupation/skill, and wage data are prerequisites for direct/indirect employment and labor-income multipliers.
10. **Validate the stranded-capital mechanism at project level** before adopting the term in the headline.

## Selected methodological sources

- Solow, “Technical Change and the Aggregate Production Function,” 1957, <https://doi.org/10.2307/1926047>.
- Olley and Pakes, “The Dynamics of Productivity in the Telecommunications Equipment Industry,” 1996, <https://doi.org/10.2307/2171831>.
- Levinsohn and Petrin, “Estimating Production Functions Using Inputs to Control for Unobservables,” 2003, <https://doi.org/10.1111/1467-937X.00246>.
- Wooldridge, “On Estimating Firm-Level Production Functions Using Proxy Variables,” 2009, <https://doi.org/10.1016/j.econlet.2009.04.026>.
- Ackerberg, Caves, and Frazer, “Identification Properties of Recent Production Function Estimators,” 2015, <https://doi.org/10.3982/ECTA13408>.
- Collard-Wexler and De Loecker, “Production Function Estimation and Capital Measurement Error,” <https://doi.org/10.3386/w22437>.
- Burnside, Eichenbaum, and Rebelo, “Capital Utilization and Returns to Scale,” 1995, <https://doi.org/10.1086/654266>.
- Hsieh and Klenow, “Misallocation and Manufacturing TFP in China and India,” 2009, <https://doi.org/10.1162/qjec.2009.124.4.1403>.
- Kim and Loayza, “Productivity Growth: Patterns and Determinants across the World,” 2019, <https://doi.org/10.18800/economia.201902.003>.
- OECD/JRC, *Handbook on Constructing Composite Indicators*, 2008, <https://doi.org/10.1787/9789264043466-en>.
- Pesaran, “A Simple Panel Unit Root Test in the Presence of Cross-Section Dependence,” 2007, <https://doi.org/10.1002/jae.951>.
- Westerlund, “Testing for Error Correction in Panel Data,” 2007, <https://doi.org/10.1111/j.1468-0084.2007.00477.x>.
- Javorcik, “Does Foreign Direct Investment Increase the Productivity of Domestic Firms?”, 2004, <https://doi.org/10.1257/0002828041464605>.
- Blalock and Gertler, “Welfare Gains from Foreign Direct Investment through Technology Transfer to Local Suppliers,” 2008, <https://doi.org/10.1016/j.jinteco.2007.05.011>.
- Amiti and Konings, “Trade Liberalization, Intermediate Inputs, and Productivity: Evidence from Indonesia,” 2007, <https://doi.org/10.1257/aer.97.5.1611>.

## Official sources checked

- [Indonesia's National Productivity Master Plan 2025–2029](https://komens.bappenas.go.id/public/storage/files/Dt.01.04_Master_Plan_Produktivitas_Nasional_2025.pdf).
- [BPS metadata defining PMTB](https://sirusa.bps.go.id/metadata/kegiatan/76025).
- [BKPM 2025 investment realization](https://bkpm.go.id/id/info/siaran-pers/realisasi-investasi-2025-lampaui-target-hilirisasi-melompat-43-3-persen).
- [BKPM administrative investment coverage note](https://data.bkpm.go.id/visualisasi-detail/statistik-realisasi-investasi-2023).
- [Kemenperin TKDN information](https://ikm.kemenperin.go.id/tingkat-komponen-dalam-negeri-tkdn).

## Generated review artifacts

- `tfp_bkpm_transmission_screen.png` — sector and province exhibit.
- `sector_investment_transmission_2025.csv` — full 17-sector screen.
- `province_investment_transmission_2024.csv` — full 34-province screen.
- `build_review_exhibits.py` — reproducible generator.
