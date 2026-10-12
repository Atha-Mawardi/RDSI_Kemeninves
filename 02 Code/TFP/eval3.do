*** Investment (PMTB, PMA, PMDN) and provincial development outcomes
*** eval3 = Determinan TFP Provinsi BKPM (legacy).do, panel compile_panel.
* Atha Bintang Wahyu M. | PSE UGM
*
* Data     : 01 Data/TFP/processed/Panel TFP Provinsi 2017-2024.dta (compile_panel.do)
* Sample   : 34 provinces x 2017-2024
* Outcomes / investment / estimators: sama legacy. Yang diganti cuma sumber data dan pilar.
*            Enam pilar (nama Determinan / compile_panel):
*            pilar_pendidikan  pilar_equity  pilar_institusi
*            pilar_konektivitas  pilar_lingkungan  pilar_keamanan
*            pilar_equity dibuang di IPM / Gini / P0 / ln upah
*            pilar_institusi dibuang di rasio PAD
* Headline : FGLS heteroskedastik (xtgls igls), bukan FE2W.

version 17
clear all
set more off
set seed 12345
set matsize 2000
capture log close

*** 0. Setup ---------------------------------------------------------------------
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
global root "${proj}/01 Data/TFP/output/eval"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "$root"
global out  "$root/eval3_results.xlsx"
global tab  "$root/eval3_tables"
global tabcsv  "$tab - all models.csv"
global tabxlsx "$tab - all models.xlsx"
global dta  "$root/eval3_panel.dta"
global panel "${proj}/01 Data/TFP/processed/Panel TFP Provinsi 2017-2024.dta"
log using "$root/eval3.log", replace text

do "${proj}/02 Code/TFP/compile_panel.do"
use "${panel}", clear

** analysis switches (change here, rerun everything)
global first_year 2017
global last_year  2024
global run_dyn    1
global lsdvc_reps 100
global run_iv     1
global ss_window  2
global run_boot   1
global boot_reps  999
global run_rw     1
global rw_reps    500
global run_robust 1
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

*** 1–2. Panel from compile_panel ----------------------------------------------
keep if inrange(Year, $first_year, $last_year)
capture confirm variable Prov
if _rc gen str32 Prov = Pre_Prov
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
	if `y' > `y0'     global yrd_dyn  $yrd_dyn  yr`y'
	if `y' > `y0' + 1 global yrd_dyn2 $yrd_dyn2 yr`y'
	if `y' > `y0' + 2 global yrd_dyn3 $yrd_dyn3 yr`y'
}
global yrdA
foreach v of global yrd {
	if "`v'" != "yr$last_year" global yrdA $yrdA `v'
}
display as text "year dummies: $yrd | wave 2+: $yrd_dyn | wave 3+: $yrd_dyn2 | wave 4+: $yrd_dyn3 | without last wave: $yrdA"

*** 4. Variable construction (nama lama = alias ke panel baru) -----------------
capture confirm variable PMA_1
if _rc {
	display as error "PMA_1 missing on compiled panel"
	exit 111
}
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

gen double y_ipm    = ipm
gen double y_tpt    = TPT_Prov+1
gen double y_gini   = -gini
gen double y_p0     = p0
gen double y_lnwage = ln(upah_rata)
gen double y_padr   = 100 * rasio_pad
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

capture confirm variable serapan_belanja
if _rc gen double serapan_belanja = apbd_serapan

* nama sama Determinan / compile_panel: enam pilar, deflator, log_L
capture confirm variable deflator
if _rc gen double deflator = PDBDeflator
label variable deflator "PDB deflator menurut provinsi"
label variable log_L "ln tenaga kerja 17 sektor"
label variable pilar_pendidikan  "pilar pendidikan (z rata penyusun)"
label variable pilar_equity      "pilar equity (IPM, -P1, -gini, upah, IDI)"
label variable pilar_institusi   "pilar institusi (harga, PAD, belanja, serapan)"
label variable pilar_konektivitas "pilar konektivitas"
label variable pilar_lingkungan  "pilar lingkungan (IKLH + hijau + biru)"
label variable pilar_keamanan    "pilar keamanan (risk & rate dibalik)"

global Xidx pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas pilar_lingkungan pilar_keamanan
global X $Xidx deflator log_L
display as text _n "controls X: $X"
display as text "pilar_equity dibuang di y = ipm, gini, p0, lnwage (penyusun pilar)"
display as text "pilar_institusi dibuang di y = padr (penyusun rasio_pad)"
correlate $Xidx

foreach v in $invall $X {
	capture drop m_`v'
	bysort Code_Prov: egen double m_`v' = mean(`v')
	label variable m_`v' "province mean of `v'"
}

capture erase "$out"
putexcel set "$out", sheet("README") replace
putexcel A1 = "eval3 — investasi-pembangunan, panel compile_panel, enam pilar bukan PCA"
putexcel A2 = "pendidikan, equity, institusi, konektivitas, lingkungan, keamanan. equity drop di ipm/gini/p0/lnwage; institusi drop di padr"
putexcel A3 = "Sheet Headline: koefisien investasi; headline estimator = FGLS (xtgls heteroskedastic igls)"
putexcel A4 = "Sheet Diagnostics: post-estimation tests"
putexcel A5 = "sample = $first_year-$last_year"
putexcel A6 = "Semua model (b/se, semua estimator): eval3_tables - all models.xlsx (satu sheet per persamaan; *_R = RA–RT)"


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
keep if inrange(Year, $first_year, $last_year)
local secs A B C D E F G H I J K L MN O P Q RSTU
local keep Code_Prov Year
foreach s of local secs {
	capture confirm variable `s'_PMA `s'_PMDN
	if _rc {
		display as error "panel: sector columns `s'_PMA / `s'_PMDN not found"
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
summarize y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X, separator(0)
xtsum y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X
correlate y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X
table Year, statistic(mean ln_pmtb ln_pma ln_pmdn y_ipm y_tpt y_p0) nformat(%9.3f)
capture noisily {
	xtline ln_pma, overlay legend(off) title("ln PMA by province, $first_year-$last_year") name(pma_lines, replace)
	graph export "$root/eval3_pma_lines.png", replace width(1600)
	xtline ln_pmdn, overlay legend(off) title("ln PMDN by province, $first_year-$last_year") name(pmdn_lines, replace)
	graph export "$root/eval3_pmdn_lines.png", replace width(1600)
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
qui regress y_ipm $inv2 $X
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
global hlfile "$root/eval3_headline.dta"
capture postclose hl
postfile hl str12 est str8 y byte k str14 var double(b se p) int N using "$hlfile", replace
** table files are appended to inside the loop: remove stale copies first
foreach y of global Ylist {
	capture erase "$tab - `y'.rtf"
}
capture erase "$tabcsv"
capture erase "$tabxlsx"
local lnTK log_L

foreach y of global Ylist {
	local yv y_`y'
	forvalues k = 1/3 {
		local inv ${inv`k'}
		local ss  ${ss`k'}
		local Xk $X
		if inlist("`y'", "ipm", "gini", "p0", "lnwage") local Xk : list Xk - pilar_equity
		if "`y'" == "padr" local Xk : list Xk - pilar_institusi
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

		** 9.3 two-way FE (pembanding); FGLS = headline
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
		if $stash_rc == 0 & $run_boot & $have_boottest {
			local j = 0
			foreach v of local inv {
				local ++j
				capture noisily boottest `v', reps($boot_reps) cluster(Code_Prov) seed(12345) nograph
				if _rc == 0 dg_set `tag' p_wild`j' `=r(p)'
			}
		}
		stash FGLS_`tag' : xtgls `yv' `inv' `Xk', panels(heteroskedastic) igls nolog
		hl_post FGLS `y' `k' `inv'
		if $stash_rc == 0 & `k' == 2 {
			test ln_pma = ln_pmdn
			dg_set `tag' p_eqPMA `=r(p)'
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
			** log_L predetermined (t-1, t-2), other controls exogenous, year dummies in the
			** level equation; collapsed so that the instrument count stays below N = 34
			if $have_xtabond2 {
				stash SYS_`tag' : xtabond2 `yv' L.`yv' `inv' `Xk' $yrd_dyn, gmm(L.`yv', lag(1 2) collapse) gmm(`inv', lag(2 3) collapse) gmm(log_L, lag(1 2) collapse) iv(`Xex') iv($yrd_dyn, equation(level)) twostep robust small
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
					keep(`inv' `invL' `dinv' L.y_`y' $X, relax) order(`inv' `invL' `dinv' L.y_`y') ///
					indicate("Year dummies = yr2*") ///
					stats(N N_g r2_w widstat estatp jp j hansenp ar2p, labels("N" "Provinces" "R2 within" "KP rk F" "endogeneity p" "Hansen J p (IV)" "Instruments" "Hansen p" "AR(2) p")) ///
					mtitles nonotes title("${Ylabel_`y'}: spec `k' (`inv')") ///
					addnotes("POLS/FE/FE2W/RE2W/CRE/LAG/FELDV: cluster-robust SE by province; DK: Driscoll-Kraay; FEAR1: xtregar; IVSS: xtivreg2 fe, Bartik instruments, sample from $ss_start; IVAH: ivreg2 on first differences, instruments = levels t-2, t-3; SYS: xtabond2 two-step robust small, collapsed, investment endogenous; LSDVC: xtlsdvc initial(ab) bias(1), bootstrap SE" "b on ln investment = change in Y per log point (x 0.693 for a doubling, /100 for +1 percent); ln wage: elasticity" "* p<0.10 ** p<0.05 *** p<0.01")
				capture noisily esttab ${stored_`tag'} using "$tabcsv", append b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
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
egen byte _ok = rowmiss(y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X)
qui replace _ok = (_ok == 0)
foreach v in y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X {
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
	display as text _n "{hline 78}" _n "PANEL SUR / SUEST, spec `k' (`inv')" _n "{hline 78}"
	local eqs
	local dlist
	foreach y of global Ylist {
		local Xy `wX'
		if inlist("`y'", "ipm", "gini", "p0", "lnwage") local Xy : list Xy - w_pilar_equity
		if "`y'" == "padr" local Xy : list Xy - w_pilar_institusi
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
				if inlist("`y'", "ipm", "gini", "p0", "lnwage") local Xy : list Xy - w_pilar_equity
				if "`y'" == "padr" local Xy : list Xy - w_pilar_institusi
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

*** 12. Robustness (headline FGLS on every equation) ----------------------------
* RA  drops the last wave
* RB  without Papua and Papua Barat (parent-province series across the 2022 split)
* RC  investment = two-year mean of ln investment (t, t-1): smooths lumpy realisations
* RD  investment = ln cumulative nominal realisation since first_year
* RQ  same six pillars (z rata penyusun, bukan PCA)
* RT  without log_L
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
	foreach y of global Ylist {
		local yv y_`y'
		forvalues k = 1/3 {
			local inv ${inv`k'}
			local Xk $X
			if inlist("`y'", "ipm", "gini", "p0", "lnwage") local Xk : list Xk - pilar_equity
			if "`y'" == "padr" local Xk : list Xk - pilar_institusi
			local XnoL : list Xk - lnTK
			local invS
			local invC
			foreach v of local inv {
				local invS `invS' sm_`v'
				local invC `invC' cum_`v'
			}
			local tag `y'_`k'
			global stored
			display as text _n "ROBUSTNESS `tag' (FGLS)"
			stash RA_`tag' : xtgls `yv' `inv' `Xk' if Year < $last_year, panels(heteroskedastic) igls nolog
			hl_post RA `y' `k' `inv'
			stash RB_`tag' : xtgls `yv' `inv' `Xk' if !inlist(Code_Prov, 91, 94), panels(heteroskedastic) igls nolog
			hl_post RB `y' `k' `inv'
			stash RC_`tag' : xtgls `yv' `invS' `Xk' if Year > $first_year, panels(heteroskedastic) igls nolog
			hl_post RC `y' `k' `invS'
			stash RD_`tag' : xtgls `yv' `invC' `Xk', panels(heteroskedastic) igls nolog
			hl_post RD `y' `k' `invC'
			stash RQ_`tag' : xtgls `yv' `inv' `Xk', panels(heteroskedastic) igls nolog
			hl_post RQ `y' `k' `inv'
			stash RT_`tag' : xtgls `yv' `inv' `XnoL', panels(heteroskedastic) igls nolog
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
						keep(`inv' `invS' `invC' pilar_* deflator log_L, relax) ///
						stats(N, labels("N")) mtitles nonotes ///
						title("${Ylabel_`y'}: spec `k' robustness FGLS (RA drop last year, RB no Papua, RC two-year mean, RD cumulative, RQ same pillars, RT without log_L)")
					capture noisily esttab ${storedR_`tag'} using "$tabcsv", append b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
						stats(N) plain
				}
			}
		}
		forvalues k = 1/3 {
			capture estimates drop ${storedR_`y'_`k'}
		}
	}

	** leave-one-province-out: headline FGLS re-estimated 34 times, dropping one
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
			if inlist("`y'", "ipm", "gini", "p0", "lnwage") local Xk : list Xk - pilar_equity
			if "`y'" == "padr" local Xk : list Xk - pilar_institusi
			local nv : word count `inv'
			local ng : word count `codes'
			matrix B = J(`ng', `nv', .)
			qui xtgls `yv' `inv' `Xk', panels(heteroskedastic) igls nolog
			local j = 0
			foreach v of local inv {
				local ++j
				local bfull`j' = _b[`v']
			}
			local c = 0
			foreach code of local codes {
				local ++c
				capture qui xtgls `yv' `inv' `Xk' if Code_Prov != `code', panels(heteroskedastic) igls nolog
				if _rc continue
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
	display as text _n "LEAVE-ONE-PROVINCE-OUT (FGLS): full-sample b, min / max b over the 34 drops, province codes at the min / max, number of drops that flip the sign"
	matlist LOO, format(%9.3f)
	capture noisily putexcel set "$out", sheet("LeaveOneOut") modify
	capture noisily putexcel A1 = "FGLS investment coefficients when each province is dropped in turn: full b, min, max, Code_Prov at min / max, number of the 34 drops that flip the sign"
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
display as text _n "{hline 78}" _n "HEADLINE: FGLS heteroskedastik IGLS (b per log point, se, p)" _n "{hline 78}"
list y k var b b_dbl se p stars N if est == "FGLS", sepby(y) noobs abbreviate(12)
display as text _n "FE2W (pembanding; p_wild = wild cluster bootstrap):"
list y k var b b_dbl se p stars p_wild stars_wild N if est == "FE2W", sepby(y) noobs abbreviate(12)
display as text _n "IV (shift-share, Anderson-Hsiao), system GMM and LSDVC coefficients; rows whose identification checks fail (ident = 0) are listed separately and must not be read"
list y k est var b se p stars N if inlist(est, "IVSS", "IVAH", "SYS", "LSDVC") & ident == 1, sepby(y k) noobs abbreviate(12)
display as text _n "not identified (KP F < 10, or system GMM outside its validity checks):"
list y k est var b se if ident == 0, sepby(y k) noobs abbreviate(12)
display as text _n "robustness (FGLS): RA drop last year, RB no Papua, RC two-year mean, RD cumulative, RQ same pillars, RT without log_L"
list y k est var b se p stars N if inlist(est, "RA", "RB", "RC", "RD", "RQ", "RT"), sepby(y k) noobs abbreviate(12)
restore

** 13b. diagnostics matrix and its legend
capture noisily putexcel set "$out", sheet("Diagnostics") modify
capture noisily putexcel A1 = matrix(DIAG), names
local r = `nrow' + 3
capture noisily putexcel A`r' = "Column legend (p = p-value)"
local legend `" "p_Fui|F test all u_i = 0 (one-way FE); <0.05 province effects exist" "p_bplm|Breusch-Pagan LM var(u_i) = 0 (RE vs POLS); <0.05 RE beats POLS" "p_haus2w|classic Hausman FE vs RE, two-way, non-robust (prefer p_mundlak)" "p_mundlak|joint test on province means (CRE, cluster-robust); <0.05 RE inconsistent, use FE or CRE" "p_overid|xtoverid Sargan-Hansen after RE; numerically the same test as p_mundlak (one piece of evidence, reported twice for reference)" "p_year|joint test of year dummies; <0.05 keep two-way FE" "p_serial|Wooldridge AR(1) test (xtserial); <0.05 serial correlation, cluster SE or FEAR1" "p_wald|modified Wald groupwise heteroskedasticity (xttest3); <0.05 cluster SE" "cd_pes1 p_cd1|Pesaran CD statistic and p, one-way FE" "cd_pes2 p_cd2 p_fried2|Pesaran CD and Friedman p after year dummies (two-way FE); <0.05 dependence, read DK" "dw_bh lbi_bw rho_ar1|Bhargava DW, Baltagi-Wu LBI, AR(1) rho from xtregar (well below 2 = AR(1))" "p_eqPMA|spec 2: test PMA coefficient = PMDN coefficient (FGLS)" "kpF_ss swF1 swF2 p_arF_ss p_endog_ss|shift-share IV: Kleibergen-Paap rk Wald F (>10 strong), Sanderson-Windmeijer F per regressor, Anderson-Rubin p (weak-IV robust), endogeneity test p" "kpF_ah p_hansen_ah p_endog_ah|Anderson-Hsiao FD-IV: KP F, Hansen J p (>0.10 instruments valid), endogeneity test p" "rho_ols rho_fe rho_sys rho_lsdvc|lagged-outcome coefficient: OLS (upper bound), FE (lower bound), system GMM, LSDVC" "j_sys p_ar1_sys p_ar2_sys p_hansen_sys p_sargan_sys|system GMM: instruments (< 34), AR(1) p (<0.10 expected), AR(2) p (>0.10 required), Hansen p (0.10-0.25+), Sargan p" "p_wild1 p_wild2|wild cluster bootstrap p (boottest) of the first / second investment coefficient, FE2W" "N N_g|observations and provinces (FE2W)" "'
foreach item of local legend {
	local ++r
	tokenize `"`item'"', parse("|")
	capture noisily putexcel A`r' = "`1'" B`r' = `"`3'"'
}

** 13c. indices, instruments and analysis variables; full dataset
preserve
keep Code_Prov Prov Year y_ipm y_tpt y_gini y_p0 y_lnwage y_padr $invall $X ///
	pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas pilar_lingkungan pilar_keamanan ///
	ss_pmtb ss_pma ss_pmdn ss_pmapmdn hhi_PMA hhi_PMDN bkpm_share
order Code_Prov Prov Year
capture noisily export excel using "$out", sheet("Indices", replace) firstrow(variables) nolabel
if _rc display as error "could not write the Indices sheet to $out rc = " _rc
restore
capture drop __0*                      // temporary variables of the do-file must not end up in the .dta
capture noisily save "$dta", replace
if _rc display as error "could not save $dta rc = " _rc

** 13d. printed summary
display as text _n "{hline 78}" _n "SUMMARY" _n "{hline 78}"
display as text "enam pilar (nama Determinan): pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas pilar_lingkungan pilar_keamanan"
display as text "     drop: pilar_equity di ipm/gini/p0/lnwage ; pilar_institusi di padr ; sample = $first_year-$last_year"
display as text "HOW TO READ (see the Diagnostics sheet and the companion note):"
display as text " - headline estimator = FGLS (xtgls panels(heteroskedastic) igls), FE2W is the comparison"
display as text " - p_Fui / p_bplm < 0.05: province effects exist, pooled OLS rejected"
display as text " - p_mundlak / p_overid < 0.05: RE inconsistent, two-way FE or CRE"
display as text " - p_year < 0.05: year dummies jointly significant in FE2W; p_serial / p_wald < 0.05: cluster-robust SE (used in FE)"
display as text " - p_cd2 < 0.05 after year dummies: cross-sectional dependence, read DK; T = 8 makes DK indicative"
display as text " - IVSS / IVAH: need kpF > 10 (and swF per regressor). With irrelevant instruments neither the coefficient,"
display as text "   the endogeneity test nor the Anderson-Rubin p can be read as an investment effect (an AR rejection then"
display as text "   only says the instrument itself moves the outcome, an exclusion failure); Headline column ident flags this"
display as text " - SYS: instruments < 34, AR(2) p > 0.10, Hansen p 0.10-0.25+, rho_sys between rho_fe and rho_ols (ident = 0 otherwise)"
display as text " - LeaveOneOut sheet: a headline FGLS coefficient whose sign flips when one province is dropped is carried by that province"
display as text " - p_wild (boottest, FE2W only) and the Romano-Wolf output guard against 34-cluster and six-outcome multiplicity"
display as text " - b on ln investment = change in Y per log point: x 0.693 for a doubling, / 100 for +1 percent;"
display as text "   ln wage: elasticity"

** stacked esttab csv → xlsx (satu sheet per persamaan)
if fileexists("$tabcsv") {
	shell python3 "${proj}/02 Code/TFP/eval3_csv_to_xlsx.py" "$tabcsv" "$tabxlsx"
	if fileexists("$tabxlsx") {
		display as text "all-models workbook: $tabxlsx"
		capture erase "$tabcsv"
	}
	else display as error "could not write $tabxlsx (python3 / openpyxl)"
}

display as text _n "done. results: $out ; tables: $tab - *.rtf + all models.xlsx ; headline: $hlfile ; data: $dta"
log close
