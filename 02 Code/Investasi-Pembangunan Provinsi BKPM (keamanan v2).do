*** Investment (PMTB, PMA, PMDN) and provincial development outcomes, Indonesia
*** 34 provinces x 2017-2025 (balanced panel, 306 province-years)
*
* Data     : 01 Data/TFP/AI-Pak_Yudis/
*            "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
*            sheet "Analisis Luaran 2" (main panel) and sheet "Sheet1" (17-sector
*            PMA / PMDN realisations, used only to build shift-share instruments)
* Output   : 01 Data/TFP/output/investasi-pembangunan/
* Outcomes : IPM_Prov_Nm (col Y), TPT_Prov (Z), Gini_Prov (AE, x100), P0_Prov (AD),
*            ln Upah_Agr_Prov (BX), RasioPAD_Prov (CB, x100)
* Investment (all Rp miliar, entered in natural logs):
*            spec 1  Y = f(ln PMTB, X)                     pmtb  (col K)
*            spec 2  Y = f(ln PMA, ln PMDN, X)             PMA_1 (I), PMDN_1 (J)
*            spec 3  Y = f(ln(PMA + PMDN), X)
* Controls X: idx_educ (PCA: Educ_Prov, Campus_Prov, ABC1-3_Prov), idx_conn (PCA:
*            RoadC_Prov_National, Airpot_Total, Cargo_Total), idx_vuln (PCA: -IDI_Prov2,
*            IKG_Prov; higher = more vulnerable), idx_safe (PCA: Victim_Prov [Susenas
*            victimisation], 100 - CR_Prov [unresolved crimes], ln CrimeRisk_BPS; higher =
*            less safe; the BPS security columns come from the "(keamanan)" workbook),
*            PDBDeflator (col CM), ln TK_Prov (col BW). An institution index (PDBDeflator,
*            rasio_pad, serapan_belanja) is computed and reported but enters X only if
*            use_inst = 1, because rasio_pad is itself one of the outcomes.
*
* Sections : 0 setup | 1 import + labels | 2 panel structure | 3 data checks and
*            repairs | 4 variable construction | 5 PCA indices | 6 shift-share (Bartik)
*            instruments | 7 descriptives + unit roots | 8 helper programs |
*            9 estimation loop (6 outcomes x 3 specs x 14 stored models, 13 posted) |
*            10 panel SUR / suest | 11 multiple testing (wild cluster bootstrap,
*            Romano-Wolf) | 12 robustness + leave-one-province-out | 13 summary + export
*
* Estimators per equation (see the companion markdown note for the survey):
*  POLS   pooled OLS + year dummies, cluster SE    benchmark, ignores province effects
*  FE     one-way within (province)               u_i correlated with regressors
*  FE2W   two-way within (province + year)        + common shocks (COVID-19, policy) HEADLINE
*  RE2W   random effects + year dummies           efficient only if u_i uncorrelated
*  CRE    Mundlak correlated RE                   RE + province means; test = robust Hausman
*  DK     FE2W with Driscoll-Kraay SE (xtscc)     cross-sectional dependence (T = 9: indicative)
*  FEAR1  FE with AR(1) errors (xtregar)          serial correlation; Bhargava DW, Baltagi-Wu LBI
*  LAG    FE2W with investment lagged one year    effects with delay; softens simultaneity
*  IVSS   FE2W-IV, shift-share (Bartik) instrument reverse causality: base-window sector shares x
*                                                 leave-one-out national sector growth (Goldsmith-
*                                                 Pinkham et al. 2020; Borusyak et al. 2022);
*                                                 sample starts after the share window
*  IVAH   Anderson-Hsiao first-difference IV      D.investment instrumented by the levels t-2, t-3
*                                                 (valid under sequential exogeneity; Hansen J)
*  FELDV  FE2W with lagged outcome                dynamic; Nickell bias (lower bound for rho);
*                                                 investment strictly exogenous
*  SYS    Blundell-Bond system GMM (xtabond2)     collapsed instruments < N = 34; investment
*                                                 ENDOGENOUS (lags t-2, t-3), ln_TK predetermined,
*                                                 year dummies in the level equation; Hansen J,
*                                                 difference-in-Hansen, AR(2), Windmeijer SE
*  LSDVC  bias-corrected LSDV (xtlsdvc)           small-N dynamic panel (Bruno 2005); assumes
*                                                 strictly exogenous regressors (robustness only)
*  SUR    panel SUR across the six outcomes       Zellner (1962) sureg for the Breusch-Pagan
*                                                 independence test; with identical regressors
*                                                 SUR = OLS, so the cross-equation tests use suest
*                                                 with province clusters
*  Reading a coefficient on ln investment: change in Y (its units) per 1 log point of
*  investment; x ln 2 = 0.693 for a doubling; / 100 for a 1 percent increase; for
*  ln wage the coefficient is an elasticity.

version 17
clear all
set more off
set seed 12345
set matsize 2000
capture log close

*** 0. Setup ---------------------------------------------------------------------
* Run from the project root:
*   do "02 Code/Investasi-Pembangunan Provinsi BKPM (keamanan v2).do"
* Override: global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"

if `"${proj}"' == "" {
	local _here "`c(pwd)'"
	local _found 0
	forvalues _i = 1/8 {
		if fileexists("`_here'/02 Code/BKPM/2026bkpm.Rproj") {
			global proj "`_here'"
			local _found 1
			continue, break
		}
		local _here "`_here'/.."
	}
	if !_found global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"
}

global datadir "${proj}/01 Data/TFP/AI-Pak_Yudis"
global outdir  "${proj}/01 Data/TFP/output/investasi-pembangunan"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "${outdir}"

global data "${datadir}/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
global out  "${outdir}/Investasi-Pembangunan Results (keamanan v2).xlsx"
global tab  "${outdir}/Investasi-Pembangunan Tables (keamanan v2)"
global dta  "${outdir}/Investasi-Pembangunan Provinsi BKPM (keamanan v2).dta"

display as text "proj = $proj"
display as text "data = $data"
display as text "out  = $outdir"
if !fileexists("${data}") {
	display as error "data file not found: $data"
	exit 601
}
log using "${outdir}/Investasi-Pembangunan Provinsi BKPM (keamanan v2).log", replace text

** analysis switches (change here, rerun everything)
global first_year 2017          // sample window (data: 2017-2025)
global last_year  2025          // 2025: TK_Prov = 2024 carried forward, Upah = UMP projection
global pca_mode   pooled        // pooled : standardise over the whole panel (keeps time variation)
                                // byyear : standardise within each year first
                                // within : province-demeaned inputs (loadings from within variation)
global idx_scale  z             // z : PC1 scores mean 0 sd 1 | 100 : min-max 0-100
global use_logs   1             // 1: log skewed count/level PCA inputs (campus, airports, cargo, crime)
global mixed_rule pca           // pca : always PC1 | eq : equal-weight index when PC1 has mixed polarity
global use_inst   0             // 1: add the institution PCA index to X (dropped in the rasio_pad equation)
global crime_src  bps           // bps : ln crime = ln CrimeRisk_BPS (official risk per 100.000 by Polda; Metro Jaya -> DKI)
                                // sheet : ln crime = ln Crime2_Prov (the sheet's recomputed rate; corr with BPS only 0.38)
global use_safe   1             // 1: add the safety pillar idx_safe (Victim_Prov, unresolved crimes, ln crime) to X
global safe_rule  pca           // pca    : PC1 of the safety inputs (the data show no common factor: KMO 0.50, alpha 0.28)
                                // eq     : equal-weight z-index, polarity enforced (higher = more victimisation,
                                //          more unresolved crimes, more recorded crime)
                                // inputs : enter Victim_Prov and unresolved directly (ln crime stays in idx_vuln)
global fix_data   1             // 1: repair out-of-range / missing PCA inputs by within-province
                                //    interpolation (ABC1_Prov = 2135 Papua Barat 2024; ABC2_Prov
                                //    missing Banten 2025, Kalimantan Timur 2025); 0: leave as is
global run_dyn    1             // 1: run FELDV / SYS / LSDVC (slow part: LSDVC bootstrap)
global lsdvc_reps 100           // bootstrap replications for the LSDVC VCE
global run_iv     1             // 1: run the IV models (shift-share FE-IV and Anderson-Hsiao FD-IV)
global ss_window  2             // years of the share window for the Bartik instrument (2017-2018);
                                //   the IVSS sample starts after the window so that the instrument
                                //   is never identical to the endogenous regressor
global run_boot   1             // 1: wild cluster bootstrap p-values (boottest) for FE2W
global boot_reps  999
global run_rw     1             // 1: Romano-Wolf step-down p-values across the six outcomes (rwolf2)
global rw_reps    500
global run_robust 1             // 1: robustness block (section 12)
global fmt cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** user-written packages (installed once; capture keeps the file running offline)
foreach pkg in xtscc xtabond2 xtserial xtcsd xttest3 xtoverid xtlsdvc estout ivreg2 xtivreg2 ranktest boottest rwolf2 {
	local cmd `pkg'
	if "`pkg'" == "estout" local cmd esttab
	capture which `cmd'
	if _rc {
		display as text "installing `pkg' from SSC ..."
		capture ssc install `pkg', replace
	}
}
foreach pkg in xtscc xtabond2 xtoverid esttab xtlsdvc xtivreg2 boottest rwolf2 xtserial xtcsd xttest3 {
	capture which `pkg'
	global have_`pkg' = (_rc == 0)
	if _rc display as error "package `pkg' is not available: the models that need it are skipped"
}

*** 1. Import and labels --------------------------------------------------------
import excel "$data", sheet("Analisis Luaran 2") firstrow clear
drop if missing(Code_Prov) | missing(Year)
display as text "imported: " c(k) " variables, " c(N) " observations (empty Code_Prov/Year rows dropped)"
keep if inrange(Year, $first_year, $last_year)

label variable Code_Prov        "Kode Provinsi"
label variable Year             "Tahun"
label variable Prov             "Nama Provinsi"
label variable PMA_1            "Penanaman Modal Asing menurut provinsi (Rp miliar)"
label variable PMDN_1           "Penanaman Modal Dalam Negeri menurut provinsi (Rp miliar)"
label variable pmtb             "PDRB Pembentukan Modal Tetap Bruto, ADHB (Rp miliar)"
label variable IPM_Prov_Nm      "Indeks Pembangunan Manusia, metode baru"
label variable TPT_Prov         "Tingkat Pengangguran Terbuka, Agustus (%)"
label variable Gini_Prov        "Indeks Gini, kota+desa, Maret (0-1)"
label variable P0_Prov          "Persentase penduduk miskin (%)"
label variable Upah_Agr_Prov    "Upah bersih/bulan, rata-rata tertimbang 17 sektor; 2025 proyeksi UMP (Rp)"
label variable RasioPAD_Prov    "Rasio PAD / pendapatan daerah (0-1)"
label variable Educ_Prov        "Rata-rata Lama Sekolah (tahun)"
label variable Campus_Prov      "Jumlah kampus (unit)"
label variable ABC1_Prov        "Angka buta huruf usia 15+ (%)"
label variable ABC2_Prov        "Angka buta huruf usia 15-44 (%)"
label variable ABC3_Prov        "Angka buta huruf usia 45+ (%)"
label variable RoadC_Prov_National "Persentase kemantapan jalan nasional (%)"
label variable Airpot_Total     "Jumlah bandara (unit)"
label variable Cargo_Total      "Total kargo kapal+udara+KA (juta ton)"
label variable Crime2_Prov      "Tindak pidana per 100 ribu penduduk"
label variable IDI_Prov2        "Indeks Demokrasi Indonesia, proxy metode baru (0-100)"
label variable IKG_Prov         "Indeks Ketimpangan Gender (0-1, lebih tinggi = lebih timpang)"
label variable PDBDeflator      "PDB deflator menurut provinsi (poin)"
label variable TK_Prov          "Total pekerja 17 lapangan usaha (jiwa)"
label variable Serapan_Prov     "Serapan belanja: realisasi/anggaran (%)"
capture confirm variable CR_Prov CrimeRisk_BPS Victim_Prov
if _rc {
	display as error "the security columns CR_Prov / CrimeRisk_BPS / Victim_Prov are missing: use the (keamanan) workbook"
	exit 111
}
label variable CR_Prov          "Persentase penyelesaian tindak pidana per Polda (clearance rate, %; BPS/Polri)"
label variable CrimeRisk_BPS    "Risiko penduduk terkena tindak pidana per 100.000 (BPS/Polri, per Polda)"
label variable Victim_Prov      "Persentase penduduk korban kejahatan setahun terakhir (Susenas, %)"
label variable CR_flag          "1 = CR_Prov imputed (Kaltara 2017 = Kaltim; 2025 = 2024)"
label variable CrimeRisk_flag   "1 = CrimeRisk_BPS imputed (Kaltara 2017 = Kaltim; 2025 = 2024)"
label variable Victim_flag      "1 = Victim_Prov imputed (2025 = 2024)"

*** 2. Panel structure ----------------------------------------------------------
isid Code_Prov Year
qui levelsof Code_Prov, local(codes)
foreach c of local codes {
	qui levelsof Prov if Code_Prov == `c', local(nm)
	if `: word count `nm'' > 1 display as error "warning: several spellings of Prov for Code_Prov `c': `nm'"
	local nm : word 1 of `nm'
	label define prov_lbl `c' `"`nm'"', add
}
label values Code_Prov prov_lbl
xtset Code_Prov Year
xtdescribe
local y0 = $first_year + 1
forvalues y = `y0'/$last_year {
	gen byte yr`y' = (Year == `y')
	label variable yr`y' "Year = `y'"
}
global yrd
global yrd_dyn
global yrd_dyn2
global yrd_dyn3
forvalues y = `y0'/$last_year {
	global yrd $yrd yr`y'
	if `y' > `y0'     global yrd_dyn  $yrd_dyn  yr`y'   // samples that start in wave 2 (lags, AR(1), LAG)
	if `y' > `y0' + 1 global yrd_dyn2 $yrd_dyn2 yr`y'   // samples that start in wave 3 (IVSS after the share window)
	if `y' > `y0' + 2 global yrd_dyn3 $yrd_dyn3 yr`y'   // samples that start in wave 4 (Anderson-Hsiao with t-3 instruments)
}
global yrdA
foreach v of global yrd {
	if "`v'" != "yr$last_year" global yrdA $yrdA `v'    // robustness RA drops the last wave: no dummy for it
}
display as text "year dummies: $yrd | wave 2+: $yrd_dyn | wave 3+: $yrd_dyn2 | wave 4+: $yrd_dyn3 | without last wave: $yrdA"

*** 3. Data checks and repairs --------------------------------------------------
** 3a. known artefacts in the 2025-08 sheet (printed, then repaired if fix_data = 1)
display as text _n "{hline 78}" _n "DATA CHECKS" _n "{hline 78}"
foreach v in ABC1_Prov ABC2_Prov ABC3_Prov TPT_Prov P0_Prov RoadC_Prov_National IDI_Prov2 Serapan_Prov CR_Prov Victim_Prov {
	qui count if missing(`v') | `v' < 0 | `v' > 120
	if r(N) > 0 {
		display as error "warning: `v' has " r(N) " missing / out-of-range value(s):"
		list Code_Prov Prov Year `v' if missing(`v') | `v' < 0 | `v' > 120, noobs abbreviate(12)
	}
}
foreach v in Gini_Prov RasioPAD_Prov IKG_Prov {
	qui count if missing(`v') | `v' < 0 | `v' > 1
	if r(N) > 0 display as error "warning: `v' outside 0-1 or missing in " r(N) " row(s)"
}
** the security series carry imputed cells (flags): report how many
foreach v in CR_flag CrimeRisk_flag Victim_flag {
	qui count if `v' == 1
	display as text "`v' = 1 in " r(N) " province-years (imputed: see sheet Keamanan (BPS))"
}
local nbad = 0
foreach v in PMA_1 PMDN_1 pmtb TK_Prov Upah_Agr_Prov Campus_Prov Airpot_Total Cargo_Total Crime2_Prov CrimeRisk_BPS PDBDeflator {
	qui count if missing(`v') | `v' <= 0
	if r(N) > 0 {
		display as error "warning: `v' missing or non-positive in " r(N) " row(s): its log is missing there and the PCA / regressions drop those rows"
		local nbad = `nbad' + r(N)
	}
}
if `nbad' == 0 display as text "all logged inputs are positive and complete: no observation is lost to logs"
** carried-forward / projected 2025 values
qui count if Year == $last_year & TK_Prov == L.TK_Prov
display as text "TK_Prov equal to the previous year in the last wave: " r(N) " provinces (2025 = 2024 carried forward)"
qui gen double _wr = Upah_Agr_Prov / L.Upah_Agr_Prov if Year == $last_year
qui summarize _wr
display as text "Upah_Agr_Prov(last)/Upah(last-1): min " %6.4f r(min) " max " %6.4f r(max) " (uniform UMP projection -> no cross-province information in the last wave)"
drop _wr
** pemekaran (Papua 2022, Papua Barat 2022): the sheet carries the parent-province series
display as text _n "Papua (94) and Papua Barat (91): parent-province series around the 2022 split"
list Code_Prov Year PMA_1 PMDN_1 pmtb TK_Prov IPM_Prov_Nm TPT_Prov P0_Prov if inlist(Code_Prov, 91, 94), noobs sepby(Code_Prov) abbreviate(10)
** largest year-on-year swings in the investment series (realisations are lumpy in small provinces)
foreach v in PMA_1 PMDN_1 {
	qui gen double _d = abs(ln(`v') - ln(L.`v'))
	gsort -_d
	display as text _n "largest |dlog `v'| year-on-year (top 8):"
	list Code_Prov Prov Year `v' _d in 1/8, noobs abbreviate(12)
	drop _d
	sort Code_Prov Year
}

** 3b. repairs (fix_data = 1): out-of-range or missing PCA inputs are replaced by the
**     within-province linear interpolation; gaps at the edge of the series take the
**     nearest available year. Every replacement is printed and flagged in fix_flag.
gen byte fix_flag = 0
label variable fix_flag "1 = at least one PCA input repaired in this row"
if $fix_data {
	foreach v in ABC1_Prov ABC2_Prov ABC3_Prov {
		qui gen double _orig = `v'
		qui replace `v' = . if `v' < 0 | `v' > 100
		qui bysort Code_Prov (Year): ipolate `v' Year, gen(_ip)
		qui replace `v' = _ip if missing(`v')
		qui bysort Code_Prov (Year): replace `v' = `v'[_n-1] if missing(`v')     // forward fill at the end
		gsort Code_Prov -Year
		qui by Code_Prov: replace `v' = `v'[_n-1] if missing(`v')     // backward fill at the start
		sort Code_Prov Year
		qui count if `v' != _orig & !missing(`v')
		if r(N) > 0 {
			display as text "`v': " r(N) " value(s) repaired"
			list Code_Prov Prov Year _orig `v' if `v' != _orig & !missing(`v'), noobs abbreviate(12)
			qui replace fix_flag = 1 if `v' != _orig & !missing(`v')
		}
		drop _orig _ip
	}
}

*** 4. Variable construction ----------------------------------------------------
** 4a. investment measures (Rp miliar -> natural logs). A coefficient b on ln(investment)
**     is the change in Y (in its units) per 1 log point of investment: b x ln 2 = 0.693 b
**     for a doubling, b / 100 for a 1 percent increase. For ln(wage) b is an elasticity.
gen double pmapmdn      = PMA_1 + PMDN_1
gen double ln_pmtb      = ln(pmtb)
gen double ln_pma       = ln(PMA_1)
gen double ln_pmdn      = ln(PMDN_1)
gen double ln_pmapmdn   = ln(pmapmdn)
label variable pmapmdn    "PMA + PMDN (Rp miliar)"
label variable ln_pmtb    "ln PMTB (ADHB, Rp miliar)"
label variable ln_pma     "ln PMA (Rp miliar)"
label variable ln_pmdn    "ln PMDN (Rp miliar)"
label variable ln_pmapmdn "ln (PMA + PMDN) (Rp miliar)"
global inv1 ln_pmtb
global inv2 ln_pma ln_pmdn
global inv3 ln_pmapmdn
global invall ln_pmtb ln_pma ln_pmdn ln_pmapmdn

** 4b. outcomes. Rates in percentage points, Gini and the PAD ratio x 100 so that
**     coefficients are readable; wage in logs.
gen double y_ipm    = IPM_Prov_Nm
gen double y_tpt    = TPT_Prov
gen double y_gini   = 100 * Gini_Prov
gen double y_p0     = P0_Prov
gen double y_lnwage = ln(Upah_Agr_Prov)
gen double y_padr   = 100 * RasioPAD_Prov
label variable y_ipm    "IPM (poin)"
label variable y_tpt    "TPT (%)"
label variable y_gini   "Gini x 100"
label variable y_p0     "Kemiskinan P0 (%)"
label variable y_lnwage "ln upah rata-rata (Rp/bulan)"
label variable y_padr   "Rasio PAD / pendapatan daerah (%)"
global Ylist ipm tpt gini p0 lnwage padr
global Ylabel_ipm    "IPM"
global Ylabel_tpt    "TPT"
global Ylabel_gini   "Gini x100"
global Ylabel_p0     "Kemiskinan"
global Ylabel_lnwage "ln Upah"
global Ylabel_padr   "Rasio PAD"

** 4c. controls entered directly
gen double ln_TK = ln(TK_Prov)
label variable ln_TK "ln total pekerja 17 lapangan usaha"
capture confirm variable rasio_pad
if _rc gen double rasio_pad = RasioPAD_Prov
capture confirm variable serapan_belanja
if _rc gen double serapan_belanja = Serapan_Prov
label variable rasio_pad       "Rasio PAD / pendapatan daerah (0-1)"
label variable serapan_belanja "Serapan belanja (%)"

** 4d. PCA inputs: skewed counts/levels logged (switch use_logs); indicators whose higher
**     value points the 'wrong' way for the pillar are negated so that every input of a
**     pillar points the same way (education: higher = better; connectivity: higher =
**     better; vulnerability: higher = MORE vulnerable; institution: higher = better)
** crime rate: the official BPS/Polri risk per 100.000 by default (crime_src = bps); the
** sheet's Crime2_Prov uses inconsistent population denominators (corr with BPS 0.38)
local crimevar CrimeRisk_BPS
if "$crime_src" == "sheet" local crimevar Crime2_Prov
display as text "crime rate used in the indices: `crimevar'"
correlate Crime2_Prov CrimeRisk_BPS
if $use_logs {
	gen double ln_campus  = ln(Campus_Prov)
	gen double ln_airport = ln(Airpot_Total)
	gen double ln_cargo   = ln(Cargo_Total)
	gen double ln_crime   = ln(`crimevar')
}
else {
	gen double ln_campus  = Campus_Prov
	gen double ln_airport = Airpot_Total
	gen double ln_cargo   = Cargo_Total
	gen double ln_crime   = `crimevar'
}
** safety pillar inputs (all coded higher = less safe): self-reported victimisation
** (Susenas), share of reported crimes not cleared by the police, recorded crime risk
gen double unresolved = 100 - CR_Prov
label variable unresolved "100 - clearance rate: share of reported crimes not resolved (%)"
gen double neg_abc1     = -ABC1_Prov
gen double neg_abc2     = -ABC2_Prov
gen double neg_abc3     = -ABC3_Prov
gen double neg_idi      = -IDI_Prov2
gen double neg_deflator = -PDBDeflator
label variable ln_campus    "ln jumlah kampus"
label variable ln_airport   "ln jumlah bandara"
label variable ln_cargo     "ln total kargo"
label variable ln_crime     "ln tindak pidana per 100 ribu penduduk"
label variable neg_abc1     "minus buta huruf 15+ (higher = more literate)"
label variable neg_abc2     "minus buta huruf 15-44"
label variable neg_abc3     "minus buta huruf 45+"
label variable neg_idi      "minus IDI (higher = less democratic)"
label variable neg_deflator "minus PDB deflator"

global educ_vars   Educ_Prov ln_campus neg_abc1 neg_abc2 neg_abc3
global educ_anchor Educ_Prov
global conn_vars   RoadC_Prov_National ln_airport ln_cargo
global conn_anchor RoadC_Prov_National
** vulnerability = gender inequality and (lack of) democracy only; the crime rate belongs to
** the safety pillar (user's decision, 13 September 2026), so it is not counted twice
global vuln_vars   neg_idi IKG_Prov
global vuln_anchor IKG_Prov
global inst_vars   neg_deflator rasio_pad serapan_belanja
global inst_anchor rasio_pad
global safe_vars   Victim_Prov unresolved ln_crime
global safe_anchor ln_crime

*** 5. PCA indices --------------------------------------------------------------
capture erase "$out"
putexcel set "$out", sheet("README") replace
putexcel A1 = "Investasi-Pembangunan Provinsi BKPM - results workbook"
putexcel A2 = "Sheets PCA_*: eigenvalues, loadings, KMO, Bartlett, alpha per index"
putexcel A3 = "Sheet Headline: investment coefficients (b, se, p, N) of every equation and estimator (long format)"
putexcel A4 = "Sheet Diagnostics: post-estimation tests per equation (outcome x spec)"
putexcel A5 = "Sheet SUR: panel SUR system tests per spec; sheet Bartik: instrument checks"
putexcel A6 = "Sheet Indices: Code_Prov Prov Year, outcomes, investment logs, PCA indices, instruments"
putexcel A7 = "switches: pca_mode = $pca_mode, idx_scale = $idx_scale, use_inst = $use_inst, fix_data = $fix_data, sample = $first_year-$last_year"
putexcel A8 = "Headline columns ident / p_wild: ident = 0 marks IV or system-GMM rows whose identification checks fail (KP F < 10; rho outside [FE, OLS], AR(2) or Hansen p < 0.10): do not read those coefficients; p_wild = wild cluster bootstrap p for the FE2W rows"
putexcel A9 = "Pillars: idx_vuln = PC1 of (-IDI, IKG), higher = more vulnerable; idx_safe = PC1 of (Victim_Prov, 100 - clearance rate, ln BPS crime risk), higher = less safe; the crime rate enters the safety pillar only. Robustness RQ uses the equal-weight indices. Sheet LeaveOneOut: FE2W investment coefficients when each province is dropped in turn"

capture program drop build_index
program define build_index
	* syntax: build_index name, vars(varlist) anchor(varname) title(string)
	syntax name(name=idx), vars(varlist) anchor(varname) [title(string)]
	display as text _n "{hline 78}" _n "PCA index: `idx'  (`title')" _n "inputs: `vars'" _n "{hline 78}"
	local zvars
	foreach v of varlist `vars' {
		capture drop z_`v'
		if "$pca_mode" == "byyear" {
			tempvar m s
			bysort Year: egen double `m' = mean(`v')
			bysort Year: egen double `s' = sd(`v')
			gen double z_`v' = (`v' - `m') / `s'
		}
		else if "$pca_mode" == "within" {
			* province-demeaned inputs: the loadings then reflect the within variation
			* that the FE models use (pooled loadings are dominated by between variation)
			tempvar m
			bysort Code_Prov: egen double `m' = mean(`v')
			gen double z_`v' = `v' - `m'
			qui summarize z_`v'
			qui replace z_`v' = z_`v' / r(sd)
		}
		else egen double z_`v' = std(`v')
		local zvars `zvars' z_`v'
	}
	local p : word count `zvars'
	qui correlate `zvars'
	matrix R = r(C)
	local n = r(N)
	local chi2 = -(`n' - 1 - (2*`p' + 5)/6) * ln(det(R))
	local df   = `p'*(`p' - 1)/2
	local pb   = chi2tail(`df', `chi2')
	display as text "Bartlett sphericity: chi2(`df') = " as result %9.2f `chi2' as text "  p = " as result %6.4f `pb'
	if `pb' > 0.05 display as error "warning: Bartlett does not reject sphericity for `idx'"
	qui alpha `zvars', std
	local calpha = r(alpha)
	display as text "Cronbach alpha (std items): " as result %6.3f `calpha'
	pca `zvars', components(1)
	estat kmo
	local kmo = r(kmo)
	matrix EV = e(Ev)
	matrix L  = e(L)
	local ev1 = EV[1,1]
	local prop1 = `ev1' / `p'
	local nkaiser = 0
	forvalues j = 1/`p' {
		if EV[1,`j'] > 1 local ++nkaiser
	}
	display as text "eigenvalue PC1 = " as result %6.3f `ev1' as text "  share = " as result %5.1f 100*`prop1' "%" ///
		as text "  eigen>1: " as result `nkaiser' as text "  KMO = " as result %5.3f `kmo'
	if `prop1' < 0.5 display as error "warning: PC1 explains less than half of the variance of `idx'"
	if `kmo' < 0.5  display as error "warning: KMO below 0.5 for `idx'"
	capture noisily {
		screeplot, name(scree_`idx', replace) title("Scree plot: `idx'")
		graph export "$outdir/Investasi-Pembangunan - scree `idx'.png", replace width(1200)
	}
	capture drop sc_`idx'
	predict double sc_`idx', score
	local r = rownumb(L, "z_`anchor'")
	local sgn = 1
	if L[`r',1] < 0 {
		local sgn = -1
		qui replace sc_`idx' = -sc_`idx'
		display as text "PC1 sign flipped so that `anchor' loads positively"
	}
	matrix L1 = L[1..`p', 1] * `sgn'
	matrix colnames L1 = PC1_loading
	display as text "oriented PC1 loadings (`idx'):"
	matlist L1, format(%8.3f)
	local nneg = 0
	forvalues j = 1/`p' {
		if L1[`j',1] < 0 local ++nneg
	}
	global pca_`idx'_nneg = `nneg'
	if `nneg' > 0 display as error "warning: `nneg' input(s) of `idx' load against the anchor (mixed polarity); compare idx_`idx'_eq"
	* polarity check on the raw inputs: the oriented score should correlate positively with
	* every input, pooled and within province (the FE models use the within variation only)
	qui correlate sc_`idx' `vars'
	matrix RC = r(C)
	local nneg_w = 0
	local q = 0
	foreach v of varlist `vars' {
		local ++q
		tempvar dv ds
		qui bysort Code_Prov: egen double `dv' = mean(`v')
		qui bysort Code_Prov: egen double `ds' = mean(sc_`idx')
		qui correlate sc_`idx' `v'
		local rp = r(rho)
		tempvar wv ws
		qui gen double `wv' = `v' - `dv'
		qui gen double `ws' = sc_`idx' - `ds'
		qui correlate `ws' `wv'
		local rw = r(rho)
		display as text "  corr(score, `v'): pooled = " as result %6.3f `rp' as text "  within province = " as result %6.3f `rw'
		if `rw' < 0 local ++nneg_w
	}
	global pca_`idx'_nneg_w = `nneg_w'
	if `nneg_w' > 0 display as error "warning: `nneg_w' input(s) of `idx' correlate negatively with the score WITHIN province"
	capture drop idx_`idx' idx_`idx'_100 idx_`idx'_eq
	egen double idx_`idx' = std(sc_`idx')
	qui summarize sc_`idx'
	gen double idx_`idx'_100 = 100 * (sc_`idx' - r(min)) / (r(max) - r(min))
	tempvar zsum
	egen double `zsum' = rowmean(`zvars')
	egen double idx_`idx'_eq = std(`zsum')
	label variable sc_`idx'      "PC1 score `idx' (raw, oriented)"
	label variable idx_`idx'     "Index `idx' (PC1, mean 0 sd 1)"
	label variable idx_`idx'_100 "Index `idx' (PC1, 0-100)"
	label variable idx_`idx'_eq  "Index `idx' (equal-weight mean of z inputs)"
	putexcel set "$out", sheet("PCA_`idx'") modify
	putexcel A1 = "Index `idx': `title'"
	putexcel A2 = "inputs" B2 = "`vars'"
	putexcel A3 = "pca_mode" B3 = "$pca_mode"
	putexcel A4 = "N" B4 = `n'
	putexcel A5 = "Bartlett chi2" B5 = `chi2' C5 = "df" D5 = `df' E5 = "p" F5 = `pb'
	putexcel A6 = "KMO" B6 = `kmo'
	putexcel A7 = "Cronbach alpha" B7 = `calpha'
	putexcel A8 = "eigenvalue PC1" B8 = `ev1' C8 = "share" D8 = `prop1' E8 = "n eigen>1" F8 = `nkaiser'
	putexcel A10 = "Eigenvalues"
	putexcel A11 = matrix(EV), names
	putexcel A14 = "Oriented PC1 loadings"
	putexcel A15 = matrix(L1), names
	global pca_`idx'_ev1 = `ev1'
	global pca_`idx'_prop = `prop1'
	global pca_`idx'_kmo = `kmo'
	global pca_`idx'_bart_p = `pb'
	global pca_`idx'_alpha = `calpha'
end

build_index educ, vars($educ_vars) anchor($educ_anchor) title("Education")
build_index conn, vars($conn_vars) anchor($conn_anchor) title("Connectivity")
build_index vuln, vars($vuln_vars) anchor($vuln_anchor) title("Social vulnerability: gender inequality and lack of democracy (higher = more vulnerable)")
build_index inst, vars($inst_vars) anchor($inst_anchor) title("Institution (reported; in X only if use_inst = 1)")
build_index safe, vars($safe_vars) anchor($safe_anchor) title("Safety (higher = less safe: victimisation, unresolved crimes, crime risk)")

** regressors actually used
global X
local pillars educ conn vuln
if $use_safe local pillars educ conn vuln safe
foreach p of local pillars {
	local v idx_`p'
	if "$idx_scale" == "100" local v idx_`p'_100
	if "$mixed_rule" == "eq" & ${pca_`p'_nneg} > 0 {
		local v idx_`p'_eq
		display as text "mixed_rule = eq: index `p' uses the additive index `v'"
	}
	if "`p'" == "safe" & "$safe_rule" == "eq"     local v idx_safe_eq
	if "`p'" == "safe" & "$safe_rule" == "inputs" local v Victim_Prov unresolved
	global X $X `v'
}
global Xidx $X
global X $X PDBDeflator ln_TK
global Xinst
if $use_inst {
	local v idx_inst
	if "$idx_scale" == "100" local v idx_inst_100
	if "$mixed_rule" == "eq" & ${pca_inst_nneg} > 0 local v idx_inst_eq
	global Xinst `v'
}
display as text _n "controls X: $X  (+ $Xinst except in the rasio_pad equation)"
correlate idx_educ idx_conn idx_vuln idx_safe idx_inst
** the vulnerability and safety pillars share the crime rate: report their within-province
** correlation (the FE models use only that variation) and the VIF of the two indices
tempvar dv ds
bysort Code_Prov: egen double `dv' = mean(idx_vuln)
bysort Code_Prov: egen double `ds' = mean(idx_safe)
tempvar wv wsf
gen double `wv' = idx_vuln - `dv'
gen double `wsf' = idx_safe - `ds'
qui correlate `wv' `wsf'
display as text "within-province correlation idx_vuln vs idx_safe = " as result %6.3f r(rho)
** Mundlak province means for every candidate regressor (CRE model)
foreach v in $invall $X $Xinst {
	capture drop m_`v'
	bysort Code_Prov: egen double m_`v' = mean(`v')
	label variable m_`v' "province mean of `v'"
}

*** 6. Shift-share (Bartik) instruments -----------------------------------------
* Realised investment is not exogenous to the outcomes (better provinces attract
* investment). The instrument predicts province investment from (a) the province's
* sector composition of PMA / PMDN in a base window (first ss_window years) and (b) the
* national growth of each of the 17 sectors relative to that window, computed leaving
* the province itself out:
*     pred_it = Ibar_i,base * sum_k s_ik * G_ikt,
*     G_ikt   = sum_{j!=i} I_jkt / [ sum_{j!=i} sum_{base} I_jk / ss_window ]
* Identification comes from differential exposure of provinces to sector-specific
* national investment cycles (Goldsmith-Pinkham, Sorkin & Swift 2020: shares design;
* Borusyak, Hull & Jaravel 2022: shocks design). The IV sample starts AFTER the share
* window (ss_start), so the instrument is never mechanically equal to the regressor.
* PMTB has no sector detail in the sheet, so the (PMA + PMDN) Bartik instruments ln PMTB
* and ln(PMA + PMDN): for spec 1 the estimand is the PMTB effect identified from
* BKPM-realisation shocks only (a LATE-type reading).
global ss_start = $first_year + $ss_window
preserve
import excel "$data", sheet("Sheet1") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, $first_year, $last_year)
capture noisily isid Code_Prov Year
if _rc {
	display as error "Sheet1: duplicate province-year rows; keeping the first of each"
	duplicates report Code_Prov Year
	bysort Code_Prov Year: keep if _n == 1
}
local secs A B C D E F G H I J K L MN O P Q RSTU
local keep Code_Prov Year
foreach s of local secs {
	capture confirm variable `s'_PMA `s'_PMDN
	if _rc {
		display as error "Sheet1: sector columns `s'_PMA / `s'_PMDN not found (header renamed?)"
		exit 111
	}
	rename `s'_PMA  PMA_`s'
	rename `s'_PMDN PMDN_`s'
	local keep `keep' PMA_`s' PMDN_`s'
}
keep `keep'
reshape long PMA_ PMDN_, i(Code_Prov Year) j(sec) string
rename (PMA_ PMDN_) (vPMA vPMDN)
local base0 = $first_year
local base1 = $first_year + $ss_window - 1
foreach v in PMA PMDN {
	qui replace v`v' = 0 if missing(v`v') | v`v' < 0
	bysort Code_Prov sec: egen double b_`v'  = total(cond(inrange(Year, `base0', `base1'), v`v', 0))   // province-sector base-window total
	bysort Code_Prov:     egen double bi_`v' = total(cond(inrange(Year, `base0', `base1'), v`v', 0))   // province base-window total
	gen double s_`v' = cond(bi_`v' > 0, b_`v' / bi_`v', 0)                                               // base-window sector shares
	bysort sec Year: egen double nat_`v' = total(v`v')                                                    // national sector total, year t
	gen double loo_`v' = nat_`v' - v`v'                                                                   // leave-one-out
	bysort sec: egen double natb_`v' = total(cond(inrange(Year, `base0', `base1'), v`v', 0))
	gen double loob_`v' = (natb_`v' - b_`v') / $ss_window                                                 // LOO base-window average per year
	gen double G_`v' = cond(loob_`v' > 0, loo_`v' / loob_`v', 1)                                         // LOO sector growth factor
	gen double c_`v' = s_`v' * G_`v'
	bysort Code_Prov Year: egen double bart_`v' = total(c_`v')                                            // share-weighted growth
	gen double pred_`v' = (bi_`v' / $ss_window) * bart_`v'                                                // predicted level (Rp miliar)
	gen double s2_`v' = s_`v'^2
	bysort Code_Prov Year: egen double hhi_`v'  = total(s2_`v')                                           // share concentration (HHI)
	bysort Code_Prov Year: egen double npos_`v' = total(s_`v' > 0)                                        // sectors with a positive share
}
bysort Code_Prov Year: keep if _n == 1
keep Code_Prov Year pred_PMA pred_PMDN bart_PMA bart_PMDN hhi_PMA hhi_PMDN npos_PMA npos_PMDN
tempfile bartik
save `bartik'
restore
merge 1:1 Code_Prov Year using `bartik', assert(match using) keep(match) nogenerate
gen double ss_pma     = ln(pred_PMA)
gen double ss_pmdn    = ln(pred_PMDN)
gen double ss_pmapmdn = ln(pred_PMA + pred_PMDN)
gen double ss_pmtb    = ss_pmapmdn
gen double bkpm_share = pmapmdn / pmtb
label variable ss_pma     "Bartik-predicted ln PMA (base-window sector shares x LOO national sector growth)"
label variable ss_pmdn    "Bartik-predicted ln PMDN"
label variable ss_pmapmdn "Bartik-predicted ln (PMA + PMDN)"
label variable ss_pmtb    "instrument for ln PMTB (= Bartik ln (PMA + PMDN))"
label variable hhi_PMA    "HHI of base-window PMA sector shares"
label variable hhi_PMDN   "HHI of base-window PMDN sector shares"
label variable npos_PMA   "sectors with positive PMA base-window share"
label variable npos_PMDN  "sectors with positive PMDN base-window share"
label variable bkpm_share "(PMA + PMDN) / PMTB"
global ss1 ss_pmtb
global ss2 ss_pma ss_pmdn
global ss3 ss_pmapmdn
** instrument diagnostics: share concentration, relevance in the IV sample (Year >= ss_start)
display as text _n "shift-share instruments: share concentration (HHI) and number of positive base sectors"
summarize hhi_PMA hhi_PMDN npos_PMA npos_PMDN bkpm_share if Year == $first_year, separator(0)
xtsum bkpm_share
display as text "correlation with the actual series, IV sample"
correlate ln_pma ss_pma ln_pmdn ss_pmdn ln_pmapmdn ss_pmapmdn ln_pmtb if Year >= $ss_start
putexcel set "$out", sheet("Bartik") modify
putexcel A1 = "Shift-share instruments: within (two-way FE) first stages on the IV sample (Year >= $ss_start), cluster-robust by province"
local r = 2
foreach pair in "ln_pma ss_pma" "ln_pmdn ss_pmdn" "ln_pmapmdn ss_pmapmdn" "ln_pmtb ss_pmtb" {
	tokenize `pair'
	qui xtreg `1' `2' $X $yrd_dyn2 if Year >= $ss_start, fe vce(cluster Code_Prov)
	local b = _b[`2']
	local t = _b[`2'] / _se[`2']
	display as text "first stage `1' on `2' (FE2W, cluster): b = " as result %7.3f `b' as text "  t = " as result %6.2f `t'
	putexcel A`r' = "`1' on `2'" B`r' = "b" C`r' = `b' D`r' = "t" E`r' = `t' F`r' = "F(1,33)" G`r' = `=`t'^2'
	local ++r
}
** spec 2 first stages with both instruments (the two Bartiks share the national shocks)
foreach dep in ln_pma ln_pmdn {
	qui xtreg `dep' ss_pma ss_pmdn $X $yrd_dyn2 if Year >= $ss_start, fe vce(cluster Code_Prov)
	testparm ss_pma ss_pmdn
	display as text "joint first stage `dep' on ss_pma ss_pmdn: F = " as result %7.2f r(F) as text "  p = " as result %6.4f r(p)
	putexcel A`r' = "`dep' on ss_pma ss_pmdn (joint)" B`r' = "F" C`r' = `=r(F)' D`r' = "p" E`r' = `=r(p)'
	local ++r
}
putexcel A`r' = "Share concentration, first year: mean HHI PMA / PMDN and mean number of positive sectors"
qui summarize hhi_PMA if Year == $first_year
putexcel B`r' = `=r(mean)'
qui summarize hhi_PMDN if Year == $first_year
putexcel C`r' = `=r(mean)'
qui summarize npos_PMA if Year == $first_year
putexcel D`r' = `=r(mean)'
qui summarize npos_PMDN if Year == $first_year
putexcel E`r' = `=r(mean)'

*** 7. Descriptive statistics and unit roots ------------------------------------
summarize y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X $Xinst, separator(0)
xtsum y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X
correlate y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X
table Year, statistic(mean ln_pmtb ln_pma ln_pmdn y_ipm y_tpt y_p0) nformat(%9.3f)
capture noisily {
	xtline ln_pma, overlay legend(off) title("ln PMA by province, $first_year-$last_year") name(pma_lines, replace)
	graph export "$outdir/Investasi-Pembangunan - PMA lines.png", replace width(1600)
	xtline ln_pmdn, overlay legend(off) title("ln PMDN by province, $first_year-$last_year") name(pmdn_lines, replace)
	graph export "$outdir/Investasi-Pembangunan - PMDN lines.png", replace width(1600)
}
** panel unit roots (descriptive only): Harris-Tzavalis is the test whose asymptotics hold
** for fixed T = 9; IPS / Fisher need T -> infinity. All are first-generation tests, so the
** cross-sectional means are removed (demean) to soften the common-shock problem. Two-way
** FE with cluster SE does not rely on stationarity when N-asymptotics carry the inference.
local urvars y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall
local nv : word count `urvars'
matrix UR = J(`nv', 4, .)
matrix rownames UR = `urvars'
matrix colnames UR = HT_p HT_trend_p IPS_p FisherADF_p
local i = 0
foreach v of local urvars {
	local ++i
	capture xtunitroot ht `v', demean
	if _rc == 0 matrix UR[`i',1] = r(p)
	capture xtunitroot ht `v', trend demean
	if _rc == 0 matrix UR[`i',2] = r(p)
	capture xtunitroot ips `v', demean
	if _rc == 0 matrix UR[`i',3] = r(p_wtbar)
	capture xtunitroot fisher `v', dfuller lags(0) demean
	if _rc == 0 matrix UR[`i',4] = r(p_P)
}
display as text _n "panel unit-root tests, p-values (H0: unit root), cross-sectionally demeaned; HT suited to T = 9"
matlist UR, format(%8.3f)
putexcel set "$out", sheet("UnitRoot") modify
putexcel A1 = "Panel unit-root p-values, demeaned; HT = Harris-Tzavalis (fixed T); IPS / Fisher need large T; descriptive only"
putexcel A2 = matrix(UR), names
** VIF among the regressors (pooled, spec 2 has the most regressors)
qui regress y_ipm $inv2 $X $Xinst
estat vif

*** 8. Helper programs ----------------------------------------------------------
** stash NAME : command   -> runs the command, stores the estimates as NAME if it succeeds;
**                           $stash_rc carries the command's return code
capture program drop stash
program define stash
	gettoken name 0 : 0, parse(":")
	gettoken colon 0 : 0, parse(":")
	capture noisily `0'
	global stash_rc = _rc
	if _rc == 0 {
		capture estimates store `name'
		if _rc {
			global stash_rc = _rc
			display as error "`name': estimates store failed (rc = " _rc ")"
		}
		else global stored $stored `name'
	}
	else display as error "`name' failed (rc = " _rc "): command skipped"
end
** hl_post EST Y K varlist -> appends the investment coefficients of the current e() to the
**                            headline file; does nothing when the preceding stash failed
**                            (otherwise the previous model would be posted under a wrong label)
capture program drop hl_post
program define hl_post
	if "$stash_rc" != "0" exit
	gettoken est 0 : 0
	gettoken y 0 : 0
	gettoken k 0 : 0
	foreach v of local 0 {
		capture local b = _b[`v']
		if _rc | missing(`b') continue
		local se = _se[`v']
		local p = .
		if `se' > 0 & `se' < . {
			local t = `b' / `se'
			capture local df = e(df_r)
			if _rc == 0 & `df' < . local p = 2 * ttail(`df', abs(`t'))
			else local p = 2 * normal(-abs(`t'))
		}
		post hl ("`est'") ("`y'") (`k') ("`v'") (`b') (`se') (`p') (e(N))
	}
end
** dg_set ROW COL VALUE -> writes one cell of the diagnostics matrix
capture program drop dg_set
program define dg_set
	args row col val
	local r = rownumb(DIAG, "`row'")
	local c = colnumb(DIAG, "`col'")
	if "`val'" != "" & "`val'" != "." & `r' < . & `c' < . matrix DIAG[`r', `c'] = `val'
end

*** 9. Estimation loop ----------------------------------------------------------
global dgcols p_Fui p_bplm p_haus2w p_mundlak p_overid p_year p_serial p_wald cd_pes1 p_cd1 ///
	cd_pes2 p_cd2 p_fried2 dw_bh lbi_bw rho_ar1 p_eqPMA kpF_ss swF1 swF2 p_arF_ss p_endog_ss ///
	kpF_ah p_hansen_ah p_endog_ah rho_ols rho_fe rho_sys rho_lsdvc j_sys p_ar1_sys p_ar2_sys ///
	p_hansen_sys p_sargan_sys p_wild1 p_wild2 N N_g
local ncol : word count $dgcols
local rows
foreach y of global Ylist {
	forvalues k = 1/3 {
		local rows `rows' `y'_`k'
	}
}
local nrow : word count `rows'
matrix DIAG = J(`nrow', `ncol', .)
matrix rownames DIAG = `rows'
matrix colnames DIAG = $dgcols
global hlfile "$outdir/Investasi-Pembangunan headline (keamanan v2).dta"
capture postclose hl
postfile hl str12 est str8 y byte k str14 var double(b se p) int N using "$hlfile", replace
** table files are appended to inside the loop: remove stale copies first
foreach y of global Ylist {
	capture erase "$tab - `y'.rtf"
}
capture erase "$tab - all models.csv"
local lnTK ln_TK

foreach y of global Ylist {
	local yv y_`y'
	forvalues k = 1/3 {
		local inv ${inv`k'}
		local ss  ${ss`k'}
		local Xk $X
		if $use_inst & "`y'" != "padr" local Xk $X $Xinst
		local Xex : list Xk - lnTK
		local xbar
		local invL
		local dinv
		local Linv23
		foreach v of local inv {
			local xbar `xbar' m_`v'
			local invL `invL' L.`v'
			local dinv `dinv' D.`v'
			local Linv23 `Linv23' L2.`v' L3.`v'
		}
		foreach v of local Xk {
			local xbar `xbar' m_`v'
		}
		local tag `y'_`k'
		global stored
		display as text _n "{hline 78}" _n "EQUATION `tag': `yv' = f(`inv', `Xk')" _n "{hline 78}"

		** 9.1 pooled OLS with year dummies, cluster-robust
		stash POLS_`tag' : regress `yv' `inv' `Xk' $yrd, vce(cluster Code_Prov) $fmt
		hl_post POLS `y' `k' `inv'
		capture xtserial `yv' `inv' `Xk' $yrd
		if _rc == 0 dg_set `tag' p_serial `=r(p)'

		** 9.2 one-way FE: F test for u_i, groupwise heteroskedasticity, CD
		qui xtreg `yv' `inv' `Xk', fe
		dg_set `tag' p_Fui `=Ftail(e(df_a), e(df_r), e(F_f))'
		capture xttest3
		if _rc == 0 dg_set `tag' p_wald `=r(p)'
		capture xtcsd, pesaran abs
		if _rc == 0 {
			dg_set `tag' cd_pes1 `=r(pesaran)'
			dg_set `tag' p_cd1 `=2 * (1 - normal(abs(r(pesaran))))'
		}
		stash FE_`tag' : xtreg `yv' `inv' `Xk', fe vce(cluster Code_Prov) $fmt
		hl_post FE `y' `k' `inv'

		** 9.3 two-way FE (headline)
		qui xtreg `yv' `inv' `Xk' $yrd, fe
		estimates store _fe2w_nr
		dg_set `tag' N `=e(N)'
		dg_set `tag' N_g `=e(N_g)'
		qui testparm $yrd
		dg_set `tag' p_year `=r(p)'
		capture xtcsd, pesaran abs
		if _rc == 0 {
			dg_set `tag' cd_pes2 `=r(pesaran)'
			dg_set `tag' p_cd2 `=2 * (1 - normal(abs(r(pesaran))))'
		}
		capture xtcsd, friedman
		if _rc == 0 dg_set `tag' p_fried2 `=chi2tail(e(g_max) - 1, r(fried))'
		stash FE2W_`tag' : xtreg `yv' `inv' `Xk' $yrd, fe vce(cluster Code_Prov) $fmt
		hl_post FE2W `y' `k' `inv'
		if $stash_rc == 0 & `k' == 2 {
			test ln_pma = ln_pmdn                       // is the PMA effect different from the PMDN effect?
			dg_set `tag' p_eqPMA `=r(p)'
		}
		if $stash_rc == 0 & $run_boot & $have_boottest {
			local j = 0
			foreach v of local inv {
				local ++j
				capture noisily boottest `v', reps($boot_reps) cluster(Code_Prov) seed(12345) nograph
				if _rc == 0 dg_set `tag' p_wild`j' `=r(p)'
			}
		}

		** 9.4 RE with year dummies; BP-LM, Hausman, robust Hausman (xtoverid)
		qui xtreg `yv' `inv' `Xk' $yrd, re
		estimates store _re2w_nr
		capture xttest0
		if _rc == 0 {
			local pbp = r(p)
			if missing(`pbp') local pbp = chi2tail(1, r(lm))
			dg_set `tag' p_bplm `pbp'
		}
		capture hausman _fe2w_nr _re2w_nr, sigmamore
		if _rc == 0 dg_set `tag' p_haus2w `=r(p)'
		stash RE2W_`tag' : xtreg `yv' `inv' `Xk' $yrd, re vce(cluster Code_Prov) $fmt
		hl_post RE2W `y' `k' `inv'
		if $stash_rc == 0 & $have_xtoverid {
			capture xtoverid
			if _rc == 0 dg_set `tag' p_overid `=r(jp)'
		}

		** 9.5 Mundlak correlated random effects
		stash CRE_`tag' : xtreg `yv' `inv' `Xk' `xbar' $yrd, re vce(cluster Code_Prov) $fmt
		hl_post CRE `y' `k' `inv'
		if $stash_rc == 0 {
			capture test `xbar'
			if _rc == 0 dg_set `tag' p_mundlak `=r(p)'
		}

		** 9.6 Driscoll-Kraay SE (cross-sectional dependence), FE with year dummies
		if $have_xtscc {
			stash DK_`tag' : xtscc `yv' `inv' `Xk' $yrd, fe lag(2)
			hl_post DK `y' `k' `inv'
		}

		** 9.7 FE with AR(1) disturbances
		stash FEAR1_`tag' : xtregar `yv' `inv' `Xk' $yrd_dyn, fe lbi $fmt
		if $stash_rc == 0 {
			dg_set `tag' dw_bh `=e(d1)'
			dg_set `tag' lbi_bw `=e(LBI)'
			dg_set `tag' rho_ar1 `=e(rho_ar)'
			hl_post FEAR1 `y' `k' `inv'
		}

		** 9.8 investment lagged one year
		stash LAG_`tag' : xtreg `yv' `invL' `Xk' $yrd_dyn, fe vce(cluster Code_Prov) $fmt
		hl_post LAG `y' `k' `invL'

		** 9.9 IV: (a) FE2W with the shift-share instruments on the post-window sample (just
		**     identified; KP rk F, Sanderson-Windmeijer F per regressor, Anderson-Rubin p);
		**     (b) Anderson-Hsiao first-difference IV, D.investment instrumented by the levels
		**     t-2 and t-3 (valid if investment is sequentially exogenous; Hansen J tests the
		**     extra lag). Own lagged levels inside the within transformation are NOT valid
		**     instruments (they are correlated with the province mean of the error), which is
		**     why the FD form is used.
		if $run_iv & $have_xtivreg2 {
			stash IVSS_`tag' : xtivreg2 `yv' (`inv' = `ss') `Xk' $yrd_dyn2 if Year >= $ss_start, fe cluster(Code_Prov) small ffirst endog(`inv')
			if $stash_rc == 0 {
				dg_set `tag' kpF_ss `=e(widstat)'
				dg_set `tag' p_arF_ss `=e(arfp)'
				dg_set `tag' p_endog_ss `=e(estatp)'
				capture matrix F1 = e(first)
				if _rc == 0 {
					local j = 0
					foreach v of local inv {
						local ++j
						capture local sw = F1["SWF", "`v'"]
						if _rc == 0 dg_set `tag' swF`j' `sw'
					}
				}
				hl_post IVSS `y' `k' `inv'
			}
			stash IVAH_`tag' : ivreg2 D.`yv' (`dinv' = `Linv23') D.(`Xk') $yrd_dyn3, cluster(Code_Prov) small ffirst endog(`dinv')
			if $stash_rc == 0 {
				dg_set `tag' kpF_ah `=e(widstat)'
				dg_set `tag' p_hansen_ah `=e(jp)'
				dg_set `tag' p_endog_ah `=e(estatp)'
				hl_post IVAH `y' `k' `dinv'
			}
		}

		** 9.10 dynamic models: OLS / FE bounds, system GMM, bias-corrected LSDV
		if $run_dyn {
			stash OLSLDV_`tag' : regress `yv' L.`yv' `inv' `Xk' $yrd_dyn, vce(cluster Code_Prov) $fmt
			if $stash_rc == 0 dg_set `tag' rho_ols `=_b[L.`yv']'
			stash FELDV_`tag' : xtreg `yv' L.`yv' `inv' `Xk' $yrd_dyn, fe vce(cluster Code_Prov) $fmt
			if $stash_rc == 0 {
				dg_set `tag' rho_fe `=_b[L.`yv']'
				hl_post FELDV `y' `k' `inv'
			}
			** system GMM: lagged outcome and investment endogenous (GMM-style lags t-2, t-3),
			** ln_TK predetermined (t-1, t-2), other controls exogenous, year dummies in the
			** level equation; collapsed so that the instrument count stays below N = 34
			if $have_xtabond2 {
				stash SYS_`tag' : xtabond2 `yv' L.`yv' `inv' `Xk' $yrd_dyn, gmm(L.`yv', lag(1 2) collapse) gmm(`inv', lag(2 3) collapse) gmm(ln_TK, lag(1 2) collapse) iv(`Xex') iv($yrd_dyn, equation(level)) twostep robust small
				if $stash_rc == 0 {
					dg_set `tag' rho_sys `=_b[L.`yv']'
					dg_set `tag' j_sys `=e(j)'
					dg_set `tag' p_ar1_sys `=e(ar1p)'
					dg_set `tag' p_ar2_sys `=e(ar2p)'
					dg_set `tag' p_hansen_sys `=e(hansenp)'
					dg_set `tag' p_sargan_sys `=e(sarganp)'
					if e(j) >= e(N_g) display as error "warning: SYS_`tag' uses " e(j) " instruments for " e(N_g) " provinces"
					hl_post SYS `y' `k' `inv'
				}
			}
			** LSDVC assumes strictly exogenous regressors: a dynamic counterpart of FE2W
			** (bounds on rho), not an endogeneity-robust estimator
			if $have_xtlsdvc {
				stash LSDVC_`tag' : xtlsdvc `yv' `inv' `Xk' $yrd_dyn, initial(ab) bias(1) vcov($lsdvc_reps)
				if $stash_rc == 0 {
					dg_set `tag' rho_lsdvc `=_b[L.`yv']'
					hl_post LSDVC `y' `k' `inv'
				}
			}
		}
		global stored_`tag' $stored
		estimates drop _fe2w_nr _re2w_nr
		local kp `inv' `invL' `dinv'
		if $run_dyn local kp `kp' L.`yv'
		capture noisily estimates table $stored, keep(`kp') b(%9.3f) se(%9.3f) p(%5.3f) stats(N N_g) modelwidth(8) ///
			title("Equation `tag': investment coefficients across estimators")
	}

	** tables for this outcome are written now and the estimates dropped: Stata holds at
	** most 300 stored results and the full design has 18 x 15 models + robustness
	if $have_esttab {
		local f "$tab - `y'.rtf"
		forvalues k = 1/3 {
			local tag `y'_`k'
			local inv ${inv`k'}
			local invL
			local dinv
			foreach v of local inv {
				local invL `invL' L.`v'
				local dinv `dinv' D.`v'
			}
			if "${stored_`tag'}" != "" {
				capture noisily esttab ${stored_`tag'} using "`f'", append b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
					keep(`inv' `invL' `dinv' L.y_`y' $X $Xinst, relax) order(`inv' `invL' `dinv' L.y_`y') ///
					indicate("Year dummies = yr2*") ///
					stats(N N_g r2_w widstat estatp jp j hansenp ar2p, labels("N" "Provinces" "R2 within" "KP rk F" "endogeneity p" "Hansen J p (IV)" "Instruments" "Hansen p" "AR(2) p")) ///
					mtitles nonotes title("${Ylabel_`y'}: spec `k' (`inv')") ///
					addnotes("POLS/FE/FE2W/RE2W/CRE/LAG/FELDV: cluster-robust SE by province; DK: Driscoll-Kraay; FEAR1: xtregar; IVSS: xtivreg2 fe, Bartik instruments, sample from $ss_start; IVAH: ivreg2 on first differences, instruments = levels t-2, t-3; SYS: xtabond2 two-step robust small, collapsed, investment endogenous; LSDVC: xtlsdvc initial(ab) bias(1), bootstrap SE" "b on ln investment = change in Y per log point (x 0.693 for a doubling, /100 for +1 percent); ln wage: elasticity" "* p<0.10 ** p<0.05 *** p<0.01")
				capture noisily esttab ${stored_`tag'} using "$tab - all models.csv", append b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
					stats(N N_g r2_w widstat estatp jp j hansenp ar2p) plain
			}
		}
	}
	forvalues k = 1/3 {
		capture estimates drop ${stored_`y'_`k'}
	}
}
display as text _n "DIAGNOSTICS MATRIX (rows = outcome_spec)"
matlist DIAG, format(%8.3f)

*** 10. Panel SUR across the six outcomes (per spec) ----------------------------
* The six outcomes respond to the same shocks, so their errors are correlated. With the
* SAME regressor list in every equation, Zellner's SUR coefficients equal equation-by-
* equation OLS: sureg is kept only for the Breusch-Pagan test of residual independence.
* The cross-equation tests (investment = 0 in all six equations; PMA = PMDN in all six)
* therefore use suest with province clusters, which stacks the six FE2W equations and
* gives a cluster-robust joint covariance. Province effects are removed by demeaning on
* the common estimation sample; year dummies stay explicit. sureg/suest ignore the 34
* absorbed province effects in their degrees of freedom (SE slightly understated).
egen byte _ok = rowmiss(y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X $Xinst)
qui replace _ok = (_ok == 0)
foreach v in y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X $Xinst {
	capture drop w_`v'
	bysort Code_Prov: egen double _m = mean(`v') if _ok
	gen double w_`v' = `v' - _m if _ok
	drop _m
}
capture noisily putexcel set "$out", sheet("SUR") modify
capture noisily putexcel A1 = "Panel SUR / suest on province-demeaned data with year dummies (common sample)"
capture noisily putexcel A2 = "spec" B2 = "Breusch-Pagan chi2 (sureg)" C2 = "df" D2 = "p" E2 = "suest: investment = 0 in all six equations, chi2" F2 = "df" G2 = "p" H2 = "suest: PMA = PMDN in all six equations, p" I2 = "suest: PMA = PMDN jointly, chi2"
local r = 3
forvalues k = 1/3 {
	local inv ${inv`k'}
	local winv
	foreach v of local inv {
		local winv `winv' w_`v'
	}
	local wX
	foreach v in $X {
		local wX `wX' w_`v'
	}
	local wXi
	foreach v in $Xinst {
		local wXi `wXi' w_`v'
	}
	display as text _n "{hline 78}" _n "PANEL SUR / SUEST, spec `k' (`inv')" _n "{hline 78}"
	local eqs
	local dlist
	foreach y of global Ylist {
		local Xy `wX'
		if $use_inst & "`y'" != "padr" local Xy `wX' `wXi'
		local eqs `eqs' (`y': w_y_`y' `winv' `Xy' $yrd)
		qui regress w_y_`y' `winv' `Xy' $yrd
		estimates store d_`y'
		local dlist `dlist' d_`y'
	}
	local bp = .
	local dfbp = .
	local pbp = .
	capture noisily sureg `eqs', corr $fmt
	if _rc == 0 {
		local bp = e(chi2_bp)
		local dfbp = e(df_bp)
		local pbp = chi2tail(`dfbp', `bp')
		display as text "Breusch-Pagan independence: chi2(`dfbp') = " as result %8.2f `bp' as text "  p = " as result %6.4f `pbp'
	}
	local cj = .
	local dj = .
	local pj = .
	local peq = .
	local ceq = .
	local pF = .
	capture noisily suest `dlist', vce(cluster Code_Prov)
	if _rc == 0 {
		local tl
		foreach y of global Ylist {
			foreach v of local winv {
				local tl `tl' [d_`y'_mean]`v'
			}
		}
		test `tl'
		local pj = r(p)
		local cj = r(chi2)
		local dj = r(df)
		* with 34 clusters the stacked covariance has rank at most 33: the chi2 form over-rejects
		* for 6-12 restrictions; the F-form (chi2/q against F(q, 33)) is the conservative reading
		local pF = Ftail(`dj', 33, `cj' / `dj')
		display as text "suest joint test, investment = 0 in all six equations: chi2(`dj') = " as result %8.2f `cj' as text "  p = " as result %6.4f `pj' as text "  F-form p (F(`dj',33)) = " as result %6.4f `pF'
		if `k' == 2 {
			local tl
			foreach y of global Ylist {
				local tl `tl' ([d_`y'_mean]w_ln_pma = [d_`y'_mean]w_ln_pmdn)
			}
			test `tl'
			local peq = r(p)
			local ceq = r(chi2)
			local pFeq = Ftail(r(df), 33, `ceq' / r(df))
			display as text "suest: PMA = PMDN in all six equations: chi2(" r(df) ") = " as result %8.2f `ceq' as text "  p = " as result %6.4f `peq' as text "  F-form p = " as result %6.4f `pFeq'
			foreach y of global Ylist {
				qui test [d_`y'_mean]w_ln_pma = [d_`y'_mean]w_ln_pmdn
				display as text "   `y': PMA = PMDN p = " as result %6.4f r(p)
			}
		}
	}
	capture noisily putexcel A`r' = `k' B`r' = `bp' C`r' = `dfbp' D`r' = `pbp' E`r' = `cj' F`r' = `dj' G`r' = `pj' H`r' = `peq' I`r' = `ceq' J`r' = `pF'
	if `r' == 3 capture noisily putexcel J2 = "F-form p of the joint test (chi2/q vs F(q,33))"
	local ++r
	capture estimates drop `dlist'
}

*** 11. Multiple testing: Romano-Wolf step-down across the six outcomes ---------
* Six outcomes per investment measure = six hypotheses tested at once; the Romano-Wolf
* correction (Clarke, Romano & Wolf 2020, rwolf2) controls the family-wise error rate
* with a cluster bootstrap. rwolf2 resamples clusters with bsample and re-runs the model
* verbatim, so the models are run as OLS on the province-demeaned data (section 10)
* rather than xtreg fe (a province drawn twice must not collapse into one panel), and
* idcluster() gives each resampled province a fresh cluster id for the vce(). The wild
* cluster bootstrap p-values per equation (boottest, section 9.3) are in the diagnostics.
if $run_rw & $have_rwolf2 {
	local wX
	foreach v in $X {
		local wX `wX' w_`v'
	}
	local wXi
	foreach v in $Xinst {
		local wXi `wXi' w_`v'
	}
	forvalues k = 1/3 {
		local inv ${inv`k'}
		local winv
		foreach v of local inv {
			local winv `winv' w_`v'
		}
		foreach v of local inv {
			local cmds
			local ivs
			foreach y of global Ylist {
				local Xy `wX'
				if $use_inst & "`y'" != "padr" local Xy `wX' `wXi'
				local cmds `cmds' (regress w_y_`y' `winv' `Xy' $yrd, vce(cluster Code_Prov))
				local ivs `ivs' w_`v',
			}
			local ivs = substr("`ivs'", 1, length("`ivs'") - 1)
			display as text _n "Romano-Wolf step-down p-values, spec `k', variable `v', six demeaned FE2W equations (reps = $rw_reps)"
			capture noisily rwolf2 `cmds', indepvars(`ivs') cluster(Code_Prov) idcluster(_cid) reps($rw_reps) seed(12345)
			if _rc == 0 {
				capture noisily matlist e(RW), format(%8.4f)
			}
			else display as error "rwolf2 failed (rc = " _rc ") for spec `k' `v'"
			capture drop _cid
		}
	}
}
else display as text "Romano-Wolf block skipped (run_rw = $run_rw, rwolf2 available = $have_rwolf2)"

*** 12. Robustness (headline FE2W on every equation) ----------------------------
* RA  2017-2024: drops the last wave (TK_Prov carried forward, wages = UMP projection)
* RB  without Papua and Papua Barat (parent-province series across the 2022 split)
* RC  investment = two-year mean of ln investment (t, t-1): smooths lumpy realisations
* RD  investment = ln cumulative nominal realisation since first_year (stock-like; its
*     within variation is largely a common trend absorbed by the year dummies)
* RQ  equal-weight additive indices instead of PC1 (polarity enforced by construction)
* RT  without ln_TK: employment is a channel of the investment effect (and near-
*     mechanically related to TPT), so this row gives the total effect not conditional
*     on employment; the main rows (with ln_TK, as specified) give the direct effect
if $run_robust {
	foreach v in $invall {
		gen double sm_`v' = (`v' + L.`v') / 2
		label variable sm_`v' "two-year mean of `v'"
	}
	bysort Code_Prov (Year): gen double cum_pmtb    = sum(pmtb)
	bysort Code_Prov (Year): gen double cum_pma     = sum(PMA_1)
	bysort Code_Prov (Year): gen double cum_pmdn    = sum(PMDN_1)
	bysort Code_Prov (Year): gen double cum_pmapmdn = sum(pmapmdn)
	foreach v in pmtb pma pmdn pmapmdn {
		gen double cum_ln_`v' = ln(cum_`v')
		label variable cum_ln_`v' "ln cumulative nominal `v' since $first_year"
	}
	local Xeq idx_educ_eq idx_conn_eq idx_vuln_eq PDBDeflator ln_TK
	if $use_safe local Xeq idx_educ_eq idx_conn_eq idx_vuln_eq idx_safe_eq PDBDeflator ln_TK
	foreach y of global Ylist {
		local yv y_`y'
		forvalues k = 1/3 {
			local inv ${inv`k'}
			local Xk $X
			local Xe `Xeq'
			if $use_inst & "`y'" != "padr" {
				local Xk $X $Xinst
				local Xe `Xeq' idx_inst_eq
			}
			local XnoTK : list Xk - lnTK
			local invS
			local invC
			foreach v of local inv {
				local invS `invS' sm_`v'
				local invC `invC' cum_`v'
			}
			local tag `y'_`k'
			global stored
			display as text _n "ROBUSTNESS `tag'"
			stash RA_`tag' : xtreg `yv' `inv' `Xk' $yrdA if Year < $last_year, fe vce(cluster Code_Prov) $fmt
			hl_post RA `y' `k' `inv'
			stash RB_`tag' : xtreg `yv' `inv' `Xk' $yrd if !inlist(Code_Prov, 91, 94), fe vce(cluster Code_Prov) $fmt
			hl_post RB `y' `k' `inv'
			stash RC_`tag' : xtreg `yv' `invS' `Xk' $yrd_dyn, fe vce(cluster Code_Prov) $fmt
			hl_post RC `y' `k' `invS'
			stash RD_`tag' : xtreg `yv' `invC' `Xk' $yrd, fe vce(cluster Code_Prov) $fmt
			hl_post RD `y' `k' `invC'
			stash RQ_`tag' : xtreg `yv' `inv' `Xe' $yrd, fe vce(cluster Code_Prov) $fmt
			hl_post RQ `y' `k' `inv'
			stash RT_`tag' : xtreg `yv' `inv' `XnoTK' $yrd, fe vce(cluster Code_Prov) $fmt
			hl_post RT `y' `k' `inv'
			global storedR_`tag' $stored
		}
		if $have_esttab {
			local f "$tab - `y'.rtf"
			forvalues k = 1/3 {
				local tag `y'_`k'
				local inv ${inv`k'}
				local invS
				local invC
				foreach v of local inv {
					local invS `invS' sm_`v'
					local invC `invC' cum_`v'
				}
				if "${storedR_`tag'}" != "" {
					capture noisily esttab ${storedR_`tag'} using "`f'", append b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
						keep(`inv' `invS' `invC' idx_* PDBDeflator ln_TK, relax) indicate("Year dummies = yr2*") ///
						stats(N N_g r2_w, labels("N" "Provinces" "R2 within")) mtitles nonotes ///
						title("${Ylabel_`y'}: spec `k' robustness (RA 2017-24, RB no Papua, RC two-year mean, RD cumulative, RQ equal-weight indices, RT without ln_TK)")
					capture noisily esttab ${storedR_`tag'} using "$tab - all models.csv", append b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
						stats(N N_g r2_w) plain
				}
			}
		}
		forvalues k = 1/3 {
			capture estimates drop ${storedR_`y'_`k'}
		}
	}

	** leave-one-province-out: the headline FE2W re-estimated 34 times, dropping one
	** province each time; a coefficient whose range straddles zero or whose sign depends
	** on one province is carried by that province (34 clusters is few)
	local lrows
	foreach y of global Ylist {
		forvalues k = 1/3 {
			foreach v in ${inv`k'} {
				local lrows `lrows' `y'_`k'_`v'
			}
		}
	}
	local nl : word count `lrows'
	matrix LOO = J(`nl', 6, .)
	matrix rownames LOO = `lrows'
	matrix colnames LOO = b_full b_min b_max prov_min prov_max n_signflip
	local i = 0
	foreach y of global Ylist {
		local yv y_`y'
		forvalues k = 1/3 {
			local inv ${inv`k'}
			local Xk $X
			if $use_inst & "`y'" != "padr" local Xk $X $Xinst
			local nv : word count `inv'
			local ng : word count `codes'
			matrix B = J(`ng', `nv', .)
			qui xtreg `yv' `inv' `Xk' $yrd, fe vce(cluster Code_Prov)
			local j = 0
			foreach v of local inv {
				local ++j
				local bfull`j' = _b[`v']
			}
			local c = 0
			foreach code of local codes {
				local ++c
				qui xtreg `yv' `inv' `Xk' $yrd if Code_Prov != `code', fe vce(cluster Code_Prov)
				local j = 0
				foreach v of local inv {
					local ++j
					matrix B[`c', `j'] = _b[`v']
				}
			}
			local j = 0
			foreach v of local inv {
				local ++j
				local ++i
				local bmin = .
				local bmax = .
				local cmin = .
				local cmax = .
				local nflip = 0
				local c = 0
				foreach code of local codes {
					local ++c
					local b = B[`c', `j']
					if `b' < `bmin' {
						local bmin = `b'
						local cmin = `code'
					}
					if `bmax' == . | `b' > `bmax' {
						local bmax = `b'
						local cmax = `code'
					}
					if sign(`b') != sign(`bfull`j'') local ++nflip
				}
				matrix LOO[`i', 1] = `bfull`j''
				matrix LOO[`i', 2] = `bmin'
				matrix LOO[`i', 3] = `bmax'
				matrix LOO[`i', 4] = `cmin'
				matrix LOO[`i', 5] = `cmax'
				matrix LOO[`i', 6] = `nflip'
			}
		}
	}
	display as text _n "LEAVE-ONE-PROVINCE-OUT (FE2W): full-sample b, min / max b over the 34 drops, province codes at the min / max, number of drops that flip the sign"
	matlist LOO, format(%9.3f)
	capture noisily putexcel set "$out", sheet("LeaveOneOut") modify
	capture noisily putexcel A1 = "FE2W investment coefficients when each province is dropped in turn: full b, min, max, Code_Prov at min / max, number of the 34 drops that flip the sign"
	capture noisily putexcel A2 = matrix(LOO), names
}
postclose hl

*** 13. Summary tables and export ----------------------------------------------
** 13a. headline file: every investment coefficient of every model, long format
preserve
** the diagnostics matrix as a small dataset keyed by outcome and spec, to flag rows whose
** identification checks fail and to put the wild-bootstrap p next to the FE2W rows
clear
qui svmat double DIAG, names(col)
gen str8 y = ""
gen byte k = .
local i = 0
foreach rname of local rows {
	local ++i
	local yy = substr("`rname'", 1, strpos("`rname'", "_") - 1)
	local kk = substr("`rname'", -1, 1)
	qui replace y = "`yy'" in `i'
	qui replace k = `kk' in `i'
}
keep y k kpF_ss kpF_ah rho_fe rho_ols rho_sys p_ar2_sys p_hansen_sys p_wild1 p_wild2
tempfile dgd
save `dgd'
use "$hlfile", clear
merge m:1 y k using `dgd', nogenerate keep(master match)
gen byte ident = 1
qui replace ident = (kpF_ss >= 10) if est == "IVSS"
qui replace ident = (kpF_ah >= 10) if est == "IVAH"
qui replace ident = (rho_sys >= rho_fe & rho_sys <= rho_ols & p_ar2_sys >= 0.10 & p_hansen_sys >= 0.10) if est == "SYS"
gen double p_wild = .
qui replace p_wild = p_wild1 if est == "FE2W" & (k != 2 | var == "ln_pma")
qui replace p_wild = p_wild2 if est == "FE2W" & k == 2 & var == "ln_pmdn"
gen str3 stars_wild = cond(p_wild < 0.01, "***", cond(p_wild < 0.05, "**", cond(p_wild < 0.10, "*", ""))) if est == "FE2W"
label variable ident      "1 = identification checks passed (IVSS/IVAH: KP F >= 10; SYS: rho in [FE, OLS], AR(2) and Hansen p >= 0.10); 1 by construction for the other estimators"
label variable p_wild     "wild cluster bootstrap p (boottest), FE2W rows"
label variable stars_wild "stars from the wild cluster bootstrap p"
drop kpF_ss kpF_ah rho_fe rho_ols rho_sys p_ar2_sys p_hansen_sys p_wild1 p_wild2
gen double b_dbl  = b * ln(2)
gen double b_1pct = b / 100
gen str3 stars = cond(p < 0.01, "***", cond(p < 0.05, "**", cond(p < 0.10, "*", "")))
label variable est    "estimator"
label variable y      "outcome (ipm tpt gini p0 lnwage padr)"
label variable k      "spec (1 PMTB, 2 PMA+PMDN separately, 3 PMA+PMDN summed)"
label variable var    "investment regressor"
label variable b      "coefficient: change in Y per 1 log point of investment (ln wage: elasticity)"
label variable b_dbl  "effect of doubling investment (b x ln 2)"
label variable b_1pct "effect of a 1 percent increase in investment (b / 100)"
label variable se     "standard error"
label variable p      "p-value (model's own distribution)"
sort y k est var
capture noisily export excel using "$out", sheet("Headline", replace) firstrow(variables) nolabel
if _rc display as error "could not write the Headline sheet to $out (is the workbook open in Excel?) rc = " _rc
display as text _n "{hline 78}" _n "HEADLINE: two-way FE with province-clustered SE (b per log point, se, cluster p, wild bootstrap p)" _n "{hline 78}"
list y k var b b_dbl se p stars p_wild stars_wild N if est == "FE2W", sepby(y) noobs abbreviate(12)
display as text _n "IV (shift-share, Anderson-Hsiao), system GMM and LSDVC coefficients; rows whose identification checks fail (ident = 0) are listed separately and must not be read"
list y k est var b se p stars N if inlist(est, "IVSS", "IVAH", "SYS", "LSDVC") & ident == 1, sepby(y k) noobs abbreviate(12)
display as text _n "not identified (KP F < 10, or system GMM outside its validity checks):"
list y k est var b se if ident == 0, sepby(y k) noobs abbreviate(12)
display as text _n "robustness (FE2W): RA 2017-24, RB no Papua, RC two-year mean, RD cumulative, RQ equal-weight indices, RT without ln_TK"
list y k est var b se p stars N if inlist(est, "RA", "RB", "RC", "RD", "RQ", "RT"), sepby(y k) noobs abbreviate(12)
restore

** 13b. diagnostics matrix and its legend
capture noisily putexcel set "$out", sheet("Diagnostics") modify
capture noisily putexcel A1 = matrix(DIAG), names
local r = `nrow' + 3
capture noisily putexcel A`r' = "Column legend (p = p-value)"
local legend `" "p_Fui|F test all u_i = 0 (one-way FE); <0.05 province effects exist" "p_bplm|Breusch-Pagan LM var(u_i) = 0 (RE vs POLS); <0.05 RE beats POLS" "p_haus2w|classic Hausman FE vs RE, two-way, non-robust (prefer p_mundlak)" "p_mundlak|joint test on province means (CRE, cluster-robust); <0.05 RE inconsistent, use FE or CRE" "p_overid|xtoverid Sargan-Hansen after RE; numerically the same test as p_mundlak (one piece of evidence, reported twice for reference)" "p_year|joint test of year dummies; <0.05 keep two-way FE" "p_serial|Wooldridge AR(1) test (xtserial); <0.05 serial correlation, cluster SE or FEAR1" "p_wald|modified Wald groupwise heteroskedasticity (xttest3); <0.05 cluster SE" "cd_pes1 p_cd1|Pesaran CD statistic and p, one-way FE" "cd_pes2 p_cd2 p_fried2|Pesaran CD and Friedman p after year dummies (two-way FE); <0.05 dependence, read DK" "dw_bh lbi_bw rho_ar1|Bhargava DW, Baltagi-Wu LBI, AR(1) rho from xtregar (well below 2 = AR(1))" "p_eqPMA|spec 2: test PMA coefficient = PMDN coefficient (FE2W)" "kpF_ss swF1 swF2 p_arF_ss p_endog_ss|shift-share IV: Kleibergen-Paap rk Wald F (>10 strong), Sanderson-Windmeijer F per regressor, Anderson-Rubin p (weak-IV robust), endogeneity test p" "kpF_ah p_hansen_ah p_endog_ah|Anderson-Hsiao FD-IV: KP F, Hansen J p (>0.10 instruments valid), endogeneity test p" "rho_ols rho_fe rho_sys rho_lsdvc|lagged-outcome coefficient: OLS (upper bound), FE (lower bound), system GMM, LSDVC" "j_sys p_ar1_sys p_ar2_sys p_hansen_sys p_sargan_sys|system GMM: instruments (< 34), AR(1) p (<0.10 expected), AR(2) p (>0.10 required), Hansen p (0.10-0.25+), Sargan p" "p_wild1 p_wild2|wild cluster bootstrap p (boottest) of the first / second investment coefficient, FE2W" "N N_g|observations and provinces (FE2W)" "'
foreach item of local legend {
	local ++r
	tokenize `"`item'"', parse("|")
	capture noisily putexcel A`r' = "`1'" B`r' = `"`3'"'
}

** 13c. indices, instruments and analysis variables; full dataset
preserve
keep Code_Prov Prov Year y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X $Xinst ///
	idx_educ_eq idx_conn_eq idx_vuln_eq idx_safe idx_safe_eq idx_inst idx_inst_eq ///
	CR_Prov CrimeRisk_BPS Victim_Prov unresolved CR_flag CrimeRisk_flag Victim_flag ///
	ss_pmtb ss_pma ss_pmdn ss_pmapmdn hhi_PMA hhi_PMDN bkpm_share fix_flag
order Code_Prov Prov Year
capture noisily export excel using "$out", sheet("Indices", replace) firstrow(variables) nolabel
if _rc display as error "could not write the Indices sheet to $out rc = " _rc
restore
capture drop __0*                      // temporary variables of the do-file must not end up in the .dta
capture noisily save "$dta", replace
if _rc display as error "could not save $dta rc = " _rc

** 13d. printed summary
display as text _n "{hline 78}" _n "SUMMARY" _n "{hline 78}"
display as text "PCA: PC1 share  educ=" %5.2f ${pca_educ_prop} " conn=" %5.2f ${pca_conn_prop} " vuln=" %5.2f ${pca_vuln_prop} " safe=" %5.2f ${pca_safe_prop} " inst=" %5.2f ${pca_inst_prop}
display as text "     KMO        educ=" %5.2f ${pca_educ_kmo}  " conn=" %5.2f ${pca_conn_kmo}  " vuln=" %5.2f ${pca_vuln_kmo}  " safe=" %5.2f ${pca_safe_kmo}  " inst=" %5.2f ${pca_inst_kmo}
display as text "     inputs loading against the anchor (pooled): educ=" ${pca_educ_nneg} " conn=" ${pca_conn_nneg} " vuln=" ${pca_vuln_nneg} " safe=" ${pca_safe_nneg} " inst=" ${pca_inst_nneg}
display as text "     inputs correlating negatively with the score within province: educ=" ${pca_educ_nneg_w} " conn=" ${pca_conn_nneg_w} " vuln=" ${pca_vuln_nneg_w} " safe=" ${pca_safe_nneg_w} " inst=" ${pca_inst_nneg_w}
display as text "     crime rate source = $crime_src ; safety pillar in X = $use_safe"
display as text "HOW TO READ (see the Diagnostics sheet and the companion note):"
display as text " - p_Fui / p_bplm < 0.05: province effects exist, pooled OLS rejected"
display as text " - p_mundlak / p_overid < 0.05: RE inconsistent, two-way FE (headline) or CRE"
display as text " - p_year < 0.05: keep year dummies; p_serial / p_wald < 0.05: cluster-robust SE (used)"
display as text " - p_cd2 < 0.05 after year dummies: cross-sectional dependence, read DK; T = 9 makes DK indicative"
display as text " - IVSS / IVAH: need kpF > 10 (and swF per regressor). With irrelevant instruments neither the coefficient,"
display as text "   the endogeneity test nor the Anderson-Rubin p can be read as an investment effect (an AR rejection then"
display as text "   only says the instrument itself moves the outcome, an exclusion failure); Headline column ident flags this"
display as text " - SYS: instruments < 34, AR(2) p > 0.10, Hansen p 0.10-0.25+, rho_sys between rho_fe and rho_ols (ident = 0 otherwise)"
display as text " - LeaveOneOut sheet: a headline coefficient whose sign flips when one province is dropped is carried by that province"
display as text " - p_wild (boottest) and the Romano-Wolf output guard against 34-cluster and six-outcome multiplicity"
display as text " - b on ln investment = change in Y per log point: x 0.693 for a doubling, / 100 for +1 percent;"
display as text "   ln wage: elasticity"
display as text _n "done. results: $out ; tables: $tab - *.rtf/.csv ; headline: $hlfile ; data: $dta"
log close
