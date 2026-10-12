*** This is to analyse dataset from BKPM

clear
cls

qui {
import excel "D:\Kurang Duit\Kemen Inves-BKPM\Dataset BKPM Provinsi 3.xlsx", sheet("Sheet1") firstrow

gen labours_primer = A_TenagaKerja+B_TenagaKerja
gen labours_sekunder = C_TenagaKerja+D_TenagaKerja+E_TenagaKerja+F_TenagaKerja
gen labours_tersier = G_TenagaKerja+H_TenagaKerja+I_TenagaKerja+J_TenagaKerja+K_TenagaKerja+L_TenagaKerja+MN_TenagaKerja+O_TenagaKerja+P_TenagaKerja+Q_TenagaKerja+RSTU_TenagaKerja
gen labours_total = labours_primer+labours_sekunder+labours_tersier
gen log_lab_tot = log(labours_total)

gen log_pmtb = log(pmtb*1e+6)
gen log_ADHB_Tot = log(ADHB_9*1e+9)
gen log_ADHK_Tot = log(ADHK_9*1e+6)

gen PMA_Tot  = A_PMA+B_PMA+C_PMA+D_PMA+E_PMA+F_PMA+G_PMA+H_PMA+I_PMA+J_PMA+K_PMA+L_PMA+MN_PMA+O_PMA+P_PMA+Q_PMA+RSTU_PMA
gen PMDN_Tot = A_PMDN+B_PMDN+C_PMDN+D_PMDN+E_PMDN+F_PMDN+G_PMDN+H_PMDN+I_PMDN+J_PMDN+K_PMDN+L_PMDN+MN_PMDN+O_PMDN+P_PMDN+Q_PMDN+RSTU_PMDN
gen log_PMA_Tot  = log(PMA_Tot*1e+6)
gen log_PMDN_Tot = log(PMDN_Tot*1e+6)

egen wage_avg = rowmean(A_RataUpah B_RataUpah C_RataUpah D_RataUpah E_RataUpah F_RataUpah G_RataUpah H_RataUpah I_RataUpah J_RataUpah K_RataUpah L_RataUpah MN_RataUpah O_RataUpah P_RataUpah Q_RataUpah RSTU_RataUpah)
gen log_wage = log(wage_avg)

gen log_GovSpend = log(govspend*1e+9)
gen log_Exp_Prov = log(Exp_Prov*1e+3)
gen log_Inc_Prov = log(Inc_Prov*1e+3)
	
}

xtset Code_Prov Year

**** Lets do the regression
***Random-effect estimation; I don't know why but I'm sure RE is better than FE in intuition for this one
** Random-effects estimation (re is xtreg's default, stated explicitly here)
xtreg log_ADHB_Tot log_pmtb log_lab_tot, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
* The result is the same if I do vce(cluster) so no need to control the cluster of a new estimation

** Extract the constant for each cross section (province) in every period (year)
* RE model: log_ADHB_Tot[i,t] = a + b1*log_pmtb[i,t] + b2*log_lab_tot[i,t] + u[i] + e[i,t] so the constant for province i in year t is: a + u[i] + e[i,t]
predict u_i, u        // BLUP of the province random effect u[i] (time-invariant)
predict e_it, e       // idiosyncratic residual e[i,t]
predict ue_it, ue     // combined residual u[i] + e[i,t]

gen cons_i  = _b[_cons] + u_i     // constant per province (same across years)
gen cons_it = _b[_cons] + ue_it   // constant per province per year

label variable cons_i  "RE constant per province: _cons + u_i"
label variable cons_it "RE constant per province-year: _cons + u_i + e_it"

* the constants above are log TFP; antilog them for TFP at raw level
gen tfp_i  = exp(cons_i)
gen tfp_it = exp(cons_it)
label variable tfp_i  "RE TFP level per province: exp(cons_i)"
label variable tfp_it "RE TFP level per province-year: exp(cons_it)"

** Extract the coefficient of each independent variable
* In RE the slope coefficients are pooled: one b1 and one b2 apply to all provinces and years (only the constant varies via u[i] + e[i,t])
gen b_pmtb    = _b[log_pmtb]      // capital (investment) elasticity b1
gen b_lab_tot = _b[log_lab_tot]   // labour elasticity b2

label variable b_pmtb    "RE coefficient of log_pmtb"
label variable b_lab_tot "RE coefficient of log_lab_tot"

display "b1 (log_pmtb)    = " %9.6f _b[log_pmtb]
display "b2 (log_lab_tot) = " %9.6f _b[log_lab_tot]

* equivalently: cons_it = log_ADHB_Tot - _b[log_pmtb]*log_pmtb - _b[log_lab_tot]*log_lab_tot

list Code_Prov Pre_Prov Year cons_i cons_it in 1/18, sepby(Code_Prov) abbreviate(12)

* (all TFP exports are consolidated in one workbook: see the section "TFP extraction for every model" below)


*** Fixed-effects (within) estimation: controls for each province's fixed effect
* the within transformation absorbs the province effects; it is equivalent to OLS with a full set of province dummies (LSDV): reg log_ADHB_Tot log_pmtb log_lab_tot i.Code_Prov, vce(robust)

** FE with cluster-robust SE
xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** Extract the constant (log TFP) of each province in every year, based on FE
* FE model: log_ADHB_Tot[i,t] = a + b1*log_pmtb[i,t] + b2*log_lab_tot[i,t] + u[i] + e[i,t] with u[i] now a fixed effect, so log TFP of province i in year t is: a + u[i] + e[i,t]
predict u_i_fe, u        // province fixed effect u[i] (deviation from _cons)
predict e_it_fe, e       // idiosyncratic residual e[i,t]
predict ue_it_fe, ue     // combined u[i] + e[i,t]

gen cons_i_fe  = _b[_cons] + u_i_fe     // log TFP per province (time-invariant part)
gen cons_it_fe = _b[_cons] + ue_it_fe   // log TFP per province per year

label variable cons_i_fe  "FE constant (log TFP) per province: _cons + u_i"
label variable cons_it_fe "FE constant (log TFP) per province-year: _cons + u_i + e_it"

* antilog for TFP at raw level
gen tfp_i_fe  = exp(cons_i_fe)
gen tfp_it_fe = exp(cons_it_fe)
label variable tfp_i_fe  "FE TFP level per province: exp(cons_i_fe)"
label variable tfp_it_fe "FE TFP level per province-year: exp(cons_it_fe)"

** FE with jackknife SE: re-estimates 34 times, leaving one province out each time
xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe vce(jackknife) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** FE with panel bootstrap SE: resamples provinces with replacement, 500 reps
xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe vce(bootstrap, reps(500) seed(12345)) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
* note: the point estimates are identical across the three FE runs above; jackknife/bootstrap only change the standard errors (the inference)

** Hausman test, FE vs RE (the classical test needs the non-robust VCE)
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe
estimates store fe_m
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, re
estimates store re_m
hausman fe_m re_m, sigmamore


*** Coefficients of the independent variables for each province
* FE pools the slopes, so province-specific b1 and b2 require a separate regression per province: 8 usable years each, only 5 residual dof - interpret with caution
tempfile provcoef
preserve
statsby cons_prov=_b[_cons] b_pmtb_prov=_b[log_pmtb] b_lab_prov=_b[log_lab_tot], by(Code_Prov) clear: reg log_ADHB_Tot log_pmtb log_lab_tot
save `provcoef'
restore
merge m:1 Code_Prov using `provcoef', nogenerate

label variable cons_prov   "constant, province-specific OLS"
label variable b_pmtb_prov "coefficient of log_pmtb, province-specific OLS"
label variable b_lab_prov  "coefficient of log_lab_tot, province-specific OLS"

list Code_Prov Pre_Prov b_pmtb_prov b_lab_prov cons_prov if Year==2017, abbreviate(14) noobs

* mean-group average of the province-specific coefficients (Pesaran-Smith)
tabstat b_pmtb_prov b_lab_prov if Year==2017, stats(mean sd min max) format(%9.3f)

* alternative for province-specific slopes in one command (Swamy random coefficients): xtrc log_ADHB_Tot log_pmtb log_lab_tot, betas



*** Robustness of the RE (Solow) model: alternative estimators and inference the Solow structure log_Y = a + b1*log_K + b2*log_L + u[i] + e[i,t] is kept throughout; variants (2)-(3) change only the inference, (4)-(7) change how the variance components / common shocks / correlation with X are handled

** (1) baseline RE-GLS with conventional SE, theta reported
xtreg log_ADHB_Tot log_pmtb log_lab_tot, re theta cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store re_gls
* Breusch-Pagan LM test: H0 = no random effect (pooled OLS is enough); rejection supports using RE
xttest0

** (2) RE with jackknife SE: re-estimates 34 times, leaving one province out each time
xtreg log_ADHB_Tot log_pmtb log_lab_tot, re vce(jackknife) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** (3) RE with panel bootstrap SE: resamples provinces with replacement, 500 reps
xtreg log_ADHB_Tot log_pmtb log_lab_tot, re vce(bootstrap, reps(500) seed(12345)) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
* (2)-(3) keep the RE-GLS point estimates; only the SEs change with only 34 clusters the wild cluster bootstrap gives the most reliable p-values (needs the user-written boottest once, then it stays installed): 
* ssc install boottest 
* qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, re vce(robust)
* boottest log_pmtb
* boottest log_lab_tot

** (4) Swamy-Arora small-sample estimator of the variance components
xtreg log_ADHB_Tot log_pmtb log_lab_tot, re sa vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store re_sa

** (5) RE estimated by maximum likelihood instead of GLS
xtreg log_ADHB_Tot log_pmtb log_lab_tot, mle nolog cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store re_mle

** (6) two-way RE: year dummies absorb common shocks (COVID-19, commodity cycles)
xtreg log_ADHB_Tot log_pmtb log_lab_tot i.Year, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store re_2way
* Solow-consistent TFP for this variant keeps the year effects inside TFP: gen cons_it_2way = log_ADHB_Tot - _b[log_pmtb]*log_pmtb - _b[log_lab_tot]*log_lab_tot

** (7) Mundlak correlated random effects: RE plus province means of the regressors keeps the RE framework but allows u[i] to be correlated with X; testing the
* means is a cluster-robust alternative to the Hausman test
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, re
gen byte esamp = e(sample)
egen m_log_pmtb = mean(log_pmtb) if esamp, by(Code_Prov)
egen m_log_lab  = mean(log_lab_tot) if esamp, by(Code_Prov)

xtreg log_ADHB_Tot log_pmtb log_lab_tot m_log_pmtb m_log_lab, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store re_mundlak
test m_log_pmtb m_log_lab

** (8) benchmarks: pooled OLS with clustered SE, and the between estimator
reg log_ADHB_Tot log_pmtb log_lab_tot, vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store pooled

xtreg log_ADHB_Tot log_pmtb log_lab_tot, be cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store betw

** side-by-side comparison of all variants
estimates table re_gls re_sa re_mle re_2way re_mundlak pooled betw, keep(log_pmtb log_lab_tot _cons log_ADHB_Tot:log_pmtb log_ADHB_Tot:log_lab_tot log_ADHB_Tot:_cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10)

* substantive note for the paper: TFP is normally computed on real output -
* consider re-running with log(ADHK_9*1e+6) (constant prices) as the dependent
* variable; ADHB (current prices) mixes true TFP with price/deflator changes


*** Real-output (ADHK) estimation: the same Solow model on constant-price GRDP log_ADHK_Tot has no missing values, but log_pmtb/log_lab_tot are missing in 2025, so the sample stays 272 obs - directly comparable with the ADHB runs

** RE on real output, cluster-robust
xtreg log_ADHK_Tot log_pmtb log_lab_tot, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store k_re

** extract real TFP per province-year from the RE model
predict u_i_k, u
predict ue_it_k, ue
gen cons_i_k  = _b[_cons] + u_i_k     // real log TFP per province (time-invariant part)
gen cons_it_k = _b[_cons] + ue_it_k   // real log TFP per province per year
label variable cons_i_k  "RE real TFP (ADHK) per province: _cons + u_i"
label variable cons_it_k "RE real TFP (ADHK) per province-year: _cons + u_i + e_it"

* antilog for real TFP at raw level
gen tfp_i_k  = exp(cons_i_k)
gen tfp_it_k = exp(cons_it_k)
label variable tfp_i_k  "RE real TFP level per province: exp(cons_i_k)"
label variable tfp_it_k "RE real TFP level per province-year: exp(cons_it_k)"

** RE inference variations
xtreg log_ADHK_Tot log_pmtb log_lab_tot, re vce(jackknife) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
xtreg log_ADHK_Tot log_pmtb log_lab_tot, re vce(bootstrap, reps(500) seed(12345)) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** two-way RE on real output: year dummies absorb common shocks
xtreg log_ADHK_Tot log_pmtb log_lab_tot i.Year, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store k_re2way

** FE on real output, cluster-robust
xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store k_fe

** extract real TFP per province-year from the FE model
predict u_i_k_fe, u
predict ue_it_k_fe, ue
gen cons_i_k_fe  = _b[_cons] + u_i_k_fe
gen cons_it_k_fe = _b[_cons] + ue_it_k_fe
label variable cons_i_k_fe  "FE real TFP (ADHK) per province: _cons + u_i"
label variable cons_it_k_fe "FE real TFP (ADHK) per province-year: _cons + u_i + e_it"

* antilog for real TFP at raw level
gen tfp_i_k_fe  = exp(cons_i_k_fe)
gen tfp_it_k_fe = exp(cons_it_k_fe)
label variable tfp_i_k_fe  "FE real TFP level per province: exp(cons_i_k_fe)"
label variable tfp_it_k_fe "FE real TFP level per province-year: exp(cons_it_k_fe)"

** FE inference variations
xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe vce(jackknife) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe vce(bootstrap, reps(500) seed(12345)) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** Hausman test on real output, FE vs RE
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe
estimates store k_fe_h
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, re
estimates store k_re_h
hausman k_fe_h k_re_h, sigmamore



*** Growth-form (first-difference Solow) estimation for consistency checks Grwth1_Prov = nominal GRDP growth, Grwth2_Prov = real GRDP growth, both in percent; the Solow model in differences is growth_Y[i,t] = g_A + b1*growth_K[i,t] + b2*growth_L[i,t] + shocks the input growth rates are built as 100*log-differences so b1 and b2 remain
* elasticities, comparable with the level regressions
sort Code_Prov Year
gen gr_pmtb = 100*D.log_pmtb
gen gr_lab  = 100*D.log_lab_tot
label variable gr_pmtb "investment growth, 100*dlog(pmtb)"
label variable gr_lab  "labour growth, 100*dlog(labours_total)"
* differencing loses 2017 (no lag) and 2025 (missing inputs): 238 obs

** nominal growth - the consistency partner of the ADHB level runs
xtreg Grwth1_Prov gr_pmtb gr_lab, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store g1_re
xtreg Grwth1_Prov gr_pmtb gr_lab, fe vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store g1_fe

** real growth - the consistency partner of the ADHK level runs
xtreg Grwth2_Prov gr_pmtb gr_lab, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store g2_re
xtreg Grwth2_Prov gr_pmtb gr_lab, fe vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store g2_fe
* here the constant = average TFP growth in percentage points per year, and
* _cons + u_i + e_it (predict ue) = TFP growth per province-year

** consistency overview: nominal vs real, levels vs growth
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, re vce(robust)
estimates store b_re
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe vce(robust)
estimates store b_fe
estimates table b_re k_re b_fe k_fe, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("Levels: ADHB (nominal) vs ADHK (real)")
estimates table g1_re g2_re g1_fe g2_fe, keep(gr_pmtb gr_lab _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("Growth: Grwth1 (nominal) vs Grwth2 (real)")


*** TFP extraction for every model: one workbook, one sheet per model
* level models : lnTFP[i,t] = logY - b1*log_pmtb - b2*log_lab_tot and tfp = exp(lnTFP)
*                (year effects and Mundlak means fold into TFP, keeping Solow's structure)
* growth models: TFP growth in percentage points = growth - b1*gr_pmtb - b2*gr_lab
* the Swamy-Arora variant is omitted: on this balanced panel it duplicates ADHB_RE exactly
local tfpfile "D:\Kurang Duit\Kemen Inves-BKPM\TFP per Province-Year by Model.xlsx"
capture erase "`tfpfile'"

** level models with pooled slopes: sheet name and estimation command
local M = 0
local ++M
local name`M' ADHB_RE
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot, re
local ++M
local name`M' ADHB_RE_MLE
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot, mle
local ++M
local name`M' ADHB_RE_2WAY
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot i.Year, re
local ++M
local name`M' ADHB_MUNDLAK
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot m_log_pmtb m_log_lab, re
local ++M
local name`M' ADHB_POLS
local cmd`M'  reg log_ADHB_Tot log_pmtb log_lab_tot
local ++M
local name`M' ADHB_BETWEEN
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot, be
local ++M
local name`M' ADHB_FE
local cmd`M'  xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe
local ++M
local name`M' ADHK_RE
local cmd`M'  xtreg log_ADHK_Tot log_pmtb log_lab_tot, re
local ++M
local name`M' ADHK_RE_2WAY
local cmd`M'  xtreg log_ADHK_Tot log_pmtb log_lab_tot i.Year, re
local ++M
local name`M' ADHK_MUNDLAK
local cmd`M'  xtreg log_ADHK_Tot log_pmtb log_lab_tot m_log_pmtb m_log_lab, re
local ++M
local name`M' ADHK_FE
local cmd`M'  xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe

forvalues i = 1/`M' {
	qui `cmd`i''
	local y = e(depvar)
	qui gen double lntfp = `y' - _b[log_pmtb]*log_pmtb - _b[log_lab_tot]*log_lab_tot
	qui gen double tfp   = exp(lntfp)
	qui gen double b1_pmtb    = _b[log_pmtb]      // capital elasticity of this model
	qui gen double b2_lab_tot = _b[log_lab_tot]   // labour elasticity of this model
	preserve
	keep Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	order Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	qui export excel using "`tfpfile'", sheet("`name`i''", replace) firstrow(variables)
	restore
	drop lntfp tfp b1_pmtb b2_lab_tot
	display as text "sheet written: `name`i''"
}

** province-specific OLS: uses each province's own slopes from the statsby step
qui gen double lntfp = log_ADHB_Tot - b_pmtb_prov*log_pmtb - b_lab_prov*log_lab_tot
qui gen double tfp   = exp(lntfp)
preserve
keep Code_Prov Pre_Prov Year lntfp tfp b_pmtb_prov b_lab_prov
order Code_Prov Pre_Prov Year lntfp tfp b_pmtb_prov b_lab_prov
qui export excel using "`tfpfile'", sheet("ADHB_PROV_OLS", replace) firstrow(variables)
restore
drop lntfp tfp
display as text "sheet written: ADHB_PROV_OLS"

** growth models: TFP growth in percentage points per year (no antilog applies)
local G = 0
local ++G
local gname`G' GRW1_RE
local gcmd`G'  xtreg Grwth1_Prov gr_pmtb gr_lab, re
local ++G
local gname`G' GRW1_FE
local gcmd`G'  xtreg Grwth1_Prov gr_pmtb gr_lab, fe
local ++G
local gname`G' GRW2_RE
local gcmd`G'  xtreg Grwth2_Prov gr_pmtb gr_lab, re
local ++G
local gname`G' GRW2_FE
local gcmd`G'  xtreg Grwth2_Prov gr_pmtb gr_lab, fe

forvalues i = 1/`G' {
	qui `gcmd`i''
	local y = e(depvar)
	qui gen double tfp_growth = `y' - _b[gr_pmtb]*gr_pmtb - _b[gr_lab]*gr_lab
	qui gen double b1_gr_pmtb = _b[gr_pmtb]   // capital-growth elasticity of this model
	qui gen double b2_gr_lab  = _b[gr_lab]    // labour-growth elasticity of this model
	preserve
	keep Code_Prov Pre_Prov Year tfp_growth b1_gr_pmtb b2_gr_lab
	order Code_Prov Pre_Prov Year tfp_growth b1_gr_pmtb b2_gr_lab
	qui export excel using "`tfpfile'", sheet("`gname`i''", replace) firstrow(variables)
	restore
	drop tfp_growth b1_gr_pmtb b2_gr_lab
	display as text "sheet written: `gname`i''"
}


*** Province- and time-varying elasticities of ln(K) and ln(L)
* a fully free coefficient per province-year is not identified (one observation
* per cell), so the three estimable designs are used, on real output (ADHK):
*  (1) ADHK_XTRC     - Swamy random coefficients: b1, b2 vary by PROVINCE,
*                      shrunken toward the panel mean (statistically safer
*                      than the raw province-by-province OLS)
*  (2) ADHK_BY_YEAR  - year-by-year cross-section OLS: b1, b2 vary by YEAR
*  (3) ADHK_INTERACT - two-way interaction LSDV: b1[i,t] = b + province
*                      deviation + year deviation, so the multipliers vary by
*                      province AND year (additively)
* each sheet also carries the Solow TFP implied by its own coefficients

** (1) Swamy random coefficients: e(beta_ps) holds each province's b1 b2 cons
xtrc log_ADHK_Tot log_pmtb log_lab_tot, betas
matrix BPS = e(beta_ps)
qui gen double b1K_i = .
qui gen double b2L_i = .
qui levelsof Code_Prov, local(PP)
local r = 0
foreach p of local PP {
	local ++r
	qui replace b1K_i = BPS[`r',1] if Code_Prov == `p'
	qui replace b2L_i = BPS[`r',2] if Code_Prov == `p'
}
qui gen double lntfp = log_ADHK_Tot - b1K_i*log_pmtb - b2L_i*log_lab_tot
qui gen double tfp   = exp(lntfp)
preserve
keep Code_Prov Pre_Prov Year b1K_i b2L_i lntfp tfp
order Code_Prov Pre_Prov Year b1K_i b2L_i lntfp tfp
qui export excel using "`tfpfile'", sheet("ADHK_XTRC", replace) firstrow(variables)
restore
drop b1K_i b2L_i lntfp tfp
display as text "sheet written: ADHK_XTRC"

** (2) year-by-year cross-section OLS: 34 provinces per year
tempfile ycoef
preserve
statsby b1K_t=_b[log_pmtb] b2L_t=_b[log_lab_tot], by(Year) clear: reg log_ADHK_Tot log_pmtb log_lab_tot
save `ycoef'
restore
merge m:1 Year using `ycoef', nogenerate
qui gen double lntfp = log_ADHK_Tot - b1K_t*log_pmtb - b2L_t*log_lab_tot
qui gen double tfp   = exp(lntfp)
preserve
keep Code_Prov Pre_Prov Year b1K_t b2L_t lntfp tfp
order Code_Prov Pre_Prov Year b1K_t b2L_t lntfp tfp
qui export excel using "`tfpfile'", sheet("ADHK_BY_YEAR", replace) firstrow(variables)
restore
drop b1K_t b2L_t lntfp tfp
display as text "sheet written: ADHK_BY_YEAR"

** (3) two-way interaction LSDV: slope = base + province deviation + year deviation
qui reg log_ADHK_Tot i.Code_Prov i.Year c.log_pmtb c.log_lab_tot i.Code_Prov#c.log_pmtb i.Year#c.log_pmtb i.Code_Prov#c.log_lab_tot i.Year#c.log_lab_tot, vce(cluster Code_Prov)
* is the slope heterogeneity jointly significant?
display _n "joint test: province deviations of b1 and b2"
testparm i.Code_Prov#c.log_pmtb i.Code_Prov#c.log_lab_tot
display _n "joint test: year deviations of b1 and b2"
testparm i.Year#c.log_pmtb i.Year#c.log_lab_tot
qui gen byte __es2 = e(sample)
qui levelsof Code_Prov if __es2, local(PP2)
qui levelsof Year if __es2, local(YY2)
qui gen double b1K_it = .
qui gen double b2L_it = .
foreach p of local PP2 {
	foreach t of local YY2 {
		qui replace b1K_it = _b[log_pmtb] + _b[`p'.Code_Prov#c.log_pmtb] + _b[`t'.Year#c.log_pmtb] if Code_Prov==`p' & Year==`t'
		qui replace b2L_it = _b[log_lab_tot] + _b[`p'.Code_Prov#c.log_lab_tot] + _b[`t'.Year#c.log_lab_tot] if Code_Prov==`p' & Year==`t'
	}
}
qui gen double lntfp = log_ADHK_Tot - b1K_it*log_pmtb - b2L_it*log_lab_tot
qui gen double tfp   = exp(lntfp)
tabstat b1K_it b2L_it, stats(mean sd min max) format(%9.3f)
preserve
keep Code_Prov Pre_Prov Year b1K_it b2L_it lntfp tfp
order Code_Prov Pre_Prov Year b1K_it b2L_it lntfp tfp
qui export excel using "`tfpfile'", sheet("ADHK_INTERACT", replace) firstrow(variables)
restore
drop b1K_it b2L_it lntfp tfp __es2
display as text "sheet written: ADHK_INTERACT"


*** Post-estimation diagnostics: which model explains the dataset best
* community-contributed tests, installed once if missing (needs internet the first time)
capture which xttest3
if _rc ssc install xttest3
capture which xtcsd
if _rc ssc install xtcsd
capture which xtserial
if _rc net install st0039, from(http://www.stata-journal.com/software/sj3-2)
* (normality of u_i and e_it is tested in block (h) below: Shapiro-Wilk and
* skewness-kurtosis on both error components of every model, exported to the
* POSTESTIMATION sheet)

** (a) Wooldridge test for AR(1) serial correlation in the idiosyncratic error
* H0: no first-order autocorrelation; one test per specification, the verdict
* applies to both the RE and the FE version of that specification
xtserial log_ADHB_Tot log_pmtb log_lab_tot
xtserial log_ADHK_Tot log_pmtb log_lab_tot
xtserial Grwth1_Prov gr_pmtb gr_lab
xtserial Grwth2_Prov gr_pmtb gr_lab

** (b) modified Wald test for groupwise heteroskedasticity, after each FE model
* H0: the error variance is the same in every province
display _n "-- ADHB FE --"
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe
xttest3
display _n "-- ADHK FE --"
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe
xttest3
display _n "-- Grwth1 FE --"
qui xtreg Grwth1_Prov gr_pmtb gr_lab, fe
xttest3
display _n "-- Grwth2 FE --"
qui xtreg Grwth2_Prov gr_pmtb gr_lab, fe
xttest3

** (c) Pesaran CD test for cross-sectional dependence (the right test when N>T)
* H0: residuals are independent across provinces
display _n "-- ADHB RE --"
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, re
xtcsd, pesaran abs
display _n "-- ADHB FE --"
qui xtreg log_ADHB_Tot log_pmtb log_lab_tot, fe
xtcsd, pesaran abs
display _n "-- ADHK RE --"
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, re
xtcsd, pesaran abs
display _n "-- ADHK FE --"
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, fe
xtcsd, pesaran abs
display _n "-- ADHK two-way RE: do the year dummies absorb the dependence? --"
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot i.Year, re
xtcsd, pesaran abs

** (d) Breusch-Pagan LM test for random effects on the remaining models
* H0: Var(u)=0, pooled OLS is enough; the ADHB version is in the RE robustness section
display _n "-- ADHK --"
qui xtreg log_ADHK_Tot log_pmtb log_lab_tot, re
xttest0
display _n "-- Grwth1 --"
qui xtreg Grwth1_Prov gr_pmtb gr_lab, re
xttest0
display _n "-- Grwth2 --"
qui xtreg Grwth2_Prov gr_pmtb gr_lab, re
xttest0

** (e) Mundlak robust Hausman for the ADHK model (ADHB version is above)
xtreg log_ADHK_Tot log_pmtb log_lab_tot m_log_pmtb m_log_lab, re vce(robust) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
test m_log_pmtb m_log_lab

** (f) RESET-type functional form test for the level models
* powers of the fitted values added back; H0: no omitted nonlinearity
foreach y in log_ADHB_Tot log_ADHK_Tot {
	foreach mdl in re fe {
		qui xtreg `y' log_pmtb log_lab_tot, `mdl'
		qui predict double xbh, xb
		qui summarize xbh, meanonly
		qui replace xbh = xbh - r(mean)   // centring stops xb^2 and xb^3 being collinear
		qui gen double xbh2 = xbh^2
		qui gen double xbh3 = xbh^3
		qui xtreg `y' log_pmtb log_lab_tot xbh2 xbh3, `mdl' vce(robust)
		display _n "RESET (`y', `mdl'): H0 = no omitted nonlinearity"
		test xbh2 xbh3
		drop xbh xbh2 xbh3
	}
}

** (g) fit summary of the eight main models
* compare only within the same dependent variable - R2 across different y's is not comparable
matrix FIT = J(8,7,.)
matrix rownames FIT = ADHB_RE ADHB_FE ADHK_RE ADHK_FE Grw1_RE Grw1_FE Grw2_RE Grw2_FE
matrix colnames FIT = R2_within R2_between R2_overall sigma_u sigma_e rho N
local i = 1
foreach m in b_re b_fe k_re k_fe g1_re g1_fe g2_re g2_fe {
	qui estimates restore `m'
	matrix FIT[`i',1] = e(r2_w)
	matrix FIT[`i',2] = e(r2_b)
	matrix FIT[`i',3] = e(r2_o)
	matrix FIT[`i',4] = e(sigma_u)
	matrix FIT[`i',5] = e(sigma_e)
	matrix FIT[`i',6] = e(rho)
	matrix FIT[`i',7] = e(N)
	local ++i
}
matlist FIT, format(%9.3f)

** (h) collect every model's postestimation results into one sheet of the workbook
* rows = the 8 main models; columns = fit statistics and diagnostic tests with
* p-values; spec-level tests (Wooldridge, Hausman, Mundlak) repeat on both the
* RE and FE row of that specification; the CD p-value uses the N(0,1) reference
local tfpfile "D:\Kurang Duit\Kemen Inves-BKPM\TFP per Province-Year by Model.xlsx"
matrix POST = J(8,29,.)
matrix rownames POST = ADHB_RE ADHB_FE ADHK_RE ADHK_FE GRW1_RE GRW1_FE GRW2_RE GRW2_FE
matrix colnames POST = R2_within R2_between R2_overall sigma_u sigma_e rho N wooldridge_F wooldridge_p wald_het_chi2 wald_het_p cd_stat cd_p lm_stat lm_p hausman_chi2 hausman_p mundlak_chi2 mundlak_p reset_stat reset_p swilk_e_W swilk_e_p sktest_e_chi2 sktest_e_p swilk_u_W swilk_u_p sktest_u_chi2 sktest_u_p
egen byte __tag = tag(Code_Prov)   // one row per province, for the u_i tests

local specs "log_ADHB_Tot log_ADHK_Tot Grwth1_Prov Grwth2_Prov"
forvalues j = 1/4 {
	local y : word `j' of `specs'
	if `j' <= 2 local xs log_pmtb log_lab_tot
	else        local xs gr_pmtb gr_lab
	local rRE = 2*`j' - 1
	local rFE = 2*`j'

	* RE row: fit statistics, Pesaran CD, Breusch-Pagan LM
	qui xtreg `y' `xs', re
	matrix POST[`rRE',1] = e(r2_w)
	matrix POST[`rRE',2] = e(r2_b)
	matrix POST[`rRE',3] = e(r2_o)
	matrix POST[`rRE',4] = e(sigma_u)
	matrix POST[`rRE',5] = e(sigma_e)
	matrix POST[`rRE',6] = e(rho)
	matrix POST[`rRE',7] = e(N)
	estimates store __re
	qui xtcsd, pesaran
	matrix POST[`rRE',12] = r(pesaran)
	matrix POST[`rRE',13] = 2*(1 - normal(abs(r(pesaran))))
	qui xttest0
	matrix POST[`rRE',14] = r(lm)
	matrix POST[`rRE',15] = r(p)
	* normality of the two error components (e_it over the sample, u_i one per province)
	qui predict double __e, e
	qui predict double __u, u
	qui swilk __e
	matrix POST[`rRE',22] = r(W)
	matrix POST[`rRE',23] = r(p)
	qui sktest __e
	matrix POST[`rRE',24] = r(chi2)
	matrix POST[`rRE',25] = r(p_chi2)
	return clear
	capture qui swilk __u if __tag
	matrix POST[`rRE',26] = r(W)
	matrix POST[`rRE',27] = r(p)
	return clear
	capture qui sktest __u if __tag
	matrix POST[`rRE',28] = r(chi2)
	matrix POST[`rRE',29] = r(p_chi2)
	drop __e __u

	* FE row: fit statistics, Pesaran CD, modified Wald heteroskedasticity
	qui xtreg `y' `xs', fe
	matrix POST[`rFE',1] = e(r2_w)
	matrix POST[`rFE',2] = e(r2_b)
	matrix POST[`rFE',3] = e(r2_o)
	matrix POST[`rFE',4] = e(sigma_u)
	matrix POST[`rFE',5] = e(sigma_e)
	matrix POST[`rFE',6] = e(rho)
	matrix POST[`rFE',7] = e(N)
	estimates store __fe
	qui xtcsd, pesaran
	matrix POST[`rFE',12] = r(pesaran)
	matrix POST[`rFE',13] = 2*(1 - normal(abs(r(pesaran))))
	qui xttest3
	matrix POST[`rFE',10] = r(wald)
	matrix POST[`rFE',11] = r(p)
	* normality of the two error components
	qui predict double __e, e
	qui predict double __u, u
	qui swilk __e
	matrix POST[`rFE',22] = r(W)
	matrix POST[`rFE',23] = r(p)
	qui sktest __e
	matrix POST[`rFE',24] = r(chi2)
	matrix POST[`rFE',25] = r(p_chi2)
	return clear
	capture qui swilk __u if __tag
	matrix POST[`rFE',26] = r(W)
	matrix POST[`rFE',27] = r(p)
	return clear
	capture qui sktest __u if __tag
	matrix POST[`rFE',28] = r(chi2)
	matrix POST[`rFE',29] = r(p_chi2)
	drop __e __u

	* spec-level tests, written to both rows: Wooldridge AR(1) and Hausman
	qui xtserial `y' `xs'
	matrix POST[`rRE',8] = r(F)
	matrix POST[`rRE',9] = r(p)
	matrix POST[`rFE',8] = r(F)
	matrix POST[`rFE',9] = r(p)
	capture hausman __fe __re, sigmamore
	if !_rc {
		matrix POST[`rRE',16] = r(chi2)
		matrix POST[`rRE',17] = r(p)
		matrix POST[`rFE',16] = r(chi2)
		matrix POST[`rFE',17] = r(p)
	}

	* level specifications only: Mundlak robust Hausman and centred RESET
	if `j' <= 2 {
		qui xtreg `y' `xs' m_log_pmtb m_log_lab, re vce(robust)
		qui test m_log_pmtb m_log_lab
		matrix POST[`rRE',18] = r(chi2)
		matrix POST[`rRE',19] = r(p)
		matrix POST[`rFE',18] = r(chi2)
		matrix POST[`rFE',19] = r(p)
		foreach mdl in re fe {
			qui xtreg `y' `xs', `mdl'
			qui predict double xbh, xb
			qui summarize xbh, meanonly
			qui replace xbh = xbh - r(mean)
			qui gen double xbh2 = xbh^2
			qui gen double xbh3 = xbh^3
			qui xtreg `y' `xs' xbh2 xbh3, `mdl' vce(robust)
			qui test xbh2 xbh3
			local rr = cond("`mdl'"=="re", `rRE', `rFE')
			matrix POST[`rr',20] = cond("`mdl'"=="re", r(chi2), r(F))
			matrix POST[`rr',21] = r(p)
			drop xbh xbh2 xbh3
		}
	}
}
estimates drop __re __fe
drop __tag

* write the POSTESTIMATION sheet into the TFP workbook
preserve
clear
qui svmat double POST, names(col)
qui gen model = ""
local rnames ADHB_RE ADHB_FE ADHK_RE ADHK_FE GRW1_RE GRW1_FE GRW2_RE GRW2_FE
forvalues r = 1/8 {
	qui replace model = word("`rnames'", `r') in `r'
}
order model
qui export excel using "`tfpfile'", sheet("POSTESTIMATION", replace) firstrow(variables)
restore
display as text "sheet written: POSTESTIMATION"


*** IV estimation: instrument capital with realised PMA (FDI) and PMDN (domestic investment)
* first stage : log_pmtb = alpha + beta1*log_PMA_Tot + beta2*log_PMDN_Tot (+ log_lab_tot)
* second stage: log Y    = ln(A) + B1*log_pmtb_hat + B2*log_lab_tot
* notes: 2SLS automatically adds the included exogenous regressor log_lab_tot
* to the first stage; with 2 instruments for 1 endogenous variable the model is
* overidentified, so the Sargan/Hansen overid test is available;
* PMA_Tot/PMDN_Tot (summed over sectors) match the PMA_1/PMDN_1 columns

** first-stage relevance, seen directly
reg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** panel IV on nominal output (ADHB): RE (G2SLS) then FE (within IV)
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re first
estimates store iv_b_re
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe first
estimates store iv_b_fe

** panel IV on real output (ADHK): RE (G2SLS) then FE (within IV)
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re first
estimates store iv_k_re
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe first
estimates store iv_k_fe

** IV diagnostics (after ivregress, which xtivreg does not provide):
* weak instruments (first-stage F), overidentification, endogeneity of ln K
ivregress 2sls log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_pool
estat firststage
estat endogenous
* the overid test valid under clustering is Hansen's J, from the GMM estimator
qui ivregress gmm log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov)
estat overid

ivregress 2sls log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_k_pool
estat firststage
estat endogenous
qui ivregress gmm log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov)
estat overid

** FE-IV with clustered SE via LSDV (xtivreg has no cluster option); the
* point estimates equal xtivreg, fe
ivregress 2sls log_ADHK_Tot log_lab_tot i.Code_Prov (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estat firststage

** side-by-side: GLS/within vs IV, nominal and real
estimates table b_re iv_b_re b_fe iv_b_fe, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB: OLS vs IV")
estimates table k_re iv_k_re k_fe iv_k_fe, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK: OLS vs IV")

* if an IV model becomes the preferred one, TFP extracts exactly as before:
* predict u/ue after xtivreg, build _b[_cons]+u/ue, and antilog with exp()


*** Variations of the IV model, to compare before choosing
** panel IV variants: how the error component is handled
* re (G2SLS, above) = Balestra-Varadharajan-Krishnakumar two-stage GLS;
* ec2sls = Baltagi's error-component 2SLS, which uses the within and between
* projections of the instruments separately (more instruments, usually
* tighter SEs); nosa = Baltagi-Chang variance components instead of
* Swamy-Arora; be = between 2SLS (cross-section information only);
* fd = first-differenced 2SLS (differencing removes u_i, loses 2017)
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls first
estimates store iv_b_ec
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa first
estimates store iv_b_ecbc
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be first
estimates store iv_b_be
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd first
estimates store iv_b_fd

xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls first
estimates store iv_k_ec
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa first
estimates store iv_k_ecbc
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be first
estimates store iv_k_be
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd first
estimates store iv_k_fd

** pooled IV variants: LIML is less biased than 2SLS when instruments are
* weak; two-step GMM is more efficient under heteroskedasticity/clustering
ivregress liml log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_liml
ivregress gmm log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_gmm
ivregress liml log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_k_liml
ivregress gmm log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_k_gmm

** all IV variants side by side
estimates table iv_b_re iv_b_ec iv_b_ecbc iv_b_be iv_b_fd iv_b_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB: panel IV variants")
estimates table iv_b_pool iv_b_liml iv_b_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB: pooled IV variants, clustered")
estimates table iv_k_re iv_k_ec iv_k_ecbc iv_k_be iv_k_fd iv_k_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK: panel IV variants")
estimates table iv_k_pool iv_k_liml iv_k_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK: pooled IV variants, clustered")


*** IV results export: TFP, K/L coefficients, first stage, and diagnostics
* everything goes to its own workbook, separate from the TFP one
capture which xtoverid
if _rc ssc install xtoverid
local ivfile "D:\Kurang Duit\Kemen Inves-BKPM\IV Results and Diagnostics.xlsx"
capture erase "`ivfile'"
sort Code_Prov Year

** TFP and the K/L coefficients per province-year, one sheet per IV model
* level IV models: lnTFP = logY - b1*log_pmtb - b2*log_lab_tot, tfp = exp(lnTFP)
local M = 0
foreach y in log_ADHB_Tot log_ADHK_Tot {
	local t = cond("`y'"=="log_ADHB_Tot","IVB","IVK")
	local ++M
	local name`M' `t'_RE
	local cmd`M'  xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re
	local ++M
	local name`M' `t'_EC2SLS
	local cmd`M'  xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls
	local ++M
	local name`M' `t'_EC2SLS_BC
	local cmd`M'  xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa
	local ++M
	local name`M' `t'_BE
	local cmd`M'  xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be
	local ++M
	local name`M' `t'_FE
	local cmd`M'  xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe
	local ++M
	local name`M' `t'_2SLS
	local cmd`M'  ivregress 2sls `y' log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov)
	local ++M
	local name`M' `t'_LIML
	local cmd`M'  ivregress liml `y' log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov)
	local ++M
	local name`M' `t'_GMM
	local cmd`M'  ivregress gmm `y' log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov)
}
forvalues i = 1/`M' {
	qui `cmd`i''
	local y = e(depvar)
	qui gen double lntfp = `y' - _b[log_pmtb]*log_pmtb - _b[log_lab_tot]*log_lab_tot
	qui gen double tfp   = exp(lntfp)
	qui gen double b1_pmtb    = _b[log_pmtb]
	qui gen double b2_lab_tot = _b[log_lab_tot]
	preserve
	keep Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	order Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	qui export excel using "`ivfile'", sheet("`name`i''", replace) firstrow(variables)
	restore
	drop lntfp tfp b1_pmtb b2_lab_tot
	display as text "sheet written: `name`i''"
}

* FD IV models are in first differences, so they deliver TFP growth
* (in percentage points, 100*dlog) rather than a TFP level
foreach y in log_ADHB_Tot log_ADHK_Tot {
	local t = cond("`y'"=="log_ADHB_Tot","IVB","IVK")
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd
	qui gen double tfp_growth = 100*(D.`y' - _b[D.log_pmtb]*D.log_pmtb - _b[D.log_lab_tot]*D.log_lab_tot)
	qui gen double b1_pmtb    = _b[D.log_pmtb]
	qui gen double b2_lab_tot = _b[D.log_lab_tot]
	preserve
	keep Code_Prov Pre_Prov Year tfp_growth b1_pmtb b2_lab_tot
	order Code_Prov Pre_Prov Year tfp_growth b1_pmtb b2_lab_tot
	qui export excel using "`ivfile'", sheet("`t'_FD", replace) firstrow(variables)
	restore
	drop tfp_growth b1_pmtb b2_lab_tot
	display as text "sheet written: `t'_FD"
}

** FIRST_STAGE sheet: the first stage per estimator family
* the first stage does not involve the dependent variable, so one first stage
* per family (pooled, RE, FE, BE, FD) covers both the ADHB and the ADHK models
matrix FS = J(5,11,.)
matrix rownames FS = POOLED RE FE BE FD
matrix colnames FS = b_PMA se_PMA b_PMDN se_PMDN b_lab se_lab b_cons se_cons instr_stat instr_p N

qui reg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, vce(cluster Code_Prov)
matrix FS[1,1] = _b[log_PMA_Tot]
matrix FS[1,2] = _se[log_PMA_Tot]
matrix FS[1,3] = _b[log_PMDN_Tot]
matrix FS[1,4] = _se[log_PMDN_Tot]
matrix FS[1,5] = _b[log_lab_tot]
matrix FS[1,6] = _se[log_lab_tot]
matrix FS[1,7] = _b[_cons]
matrix FS[1,8] = _se[_cons]
matrix FS[1,11] = e(N)
qui test log_PMA_Tot log_PMDN_Tot
matrix FS[1,9]  = r(F)
matrix FS[1,10] = r(p)

qui xtreg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, re vce(robust)
matrix FS[2,1] = _b[log_PMA_Tot]
matrix FS[2,2] = _se[log_PMA_Tot]
matrix FS[2,3] = _b[log_PMDN_Tot]
matrix FS[2,4] = _se[log_PMDN_Tot]
matrix FS[2,5] = _b[log_lab_tot]
matrix FS[2,6] = _se[log_lab_tot]
matrix FS[2,7] = _b[_cons]
matrix FS[2,8] = _se[_cons]
matrix FS[2,11] = e(N)
qui test log_PMA_Tot log_PMDN_Tot
matrix FS[2,9]  = r(chi2)
matrix FS[2,10] = r(p)

qui xtreg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, fe vce(robust)
matrix FS[3,1] = _b[log_PMA_Tot]
matrix FS[3,2] = _se[log_PMA_Tot]
matrix FS[3,3] = _b[log_PMDN_Tot]
matrix FS[3,4] = _se[log_PMDN_Tot]
matrix FS[3,5] = _b[log_lab_tot]
matrix FS[3,6] = _se[log_lab_tot]
matrix FS[3,7] = _b[_cons]
matrix FS[3,8] = _se[_cons]
matrix FS[3,11] = e(N)
qui test log_PMA_Tot log_PMDN_Tot
matrix FS[3,9]  = r(F)
matrix FS[3,10] = r(p)

qui xtreg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, be
matrix FS[4,1] = _b[log_PMA_Tot]
matrix FS[4,2] = _se[log_PMA_Tot]
matrix FS[4,3] = _b[log_PMDN_Tot]
matrix FS[4,4] = _se[log_PMDN_Tot]
matrix FS[4,5] = _b[log_lab_tot]
matrix FS[4,6] = _se[log_lab_tot]
matrix FS[4,7] = _b[_cons]
matrix FS[4,8] = _se[_cons]
matrix FS[4,11] = e(N)
qui test log_PMA_Tot log_PMDN_Tot
matrix FS[4,9]  = r(F)
matrix FS[4,10] = r(p)

qui reg D.log_pmtb D.log_PMA_Tot D.log_PMDN_Tot D.log_lab_tot, vce(cluster Code_Prov)
matrix FS[5,1] = _b[D.log_PMA_Tot]
matrix FS[5,2] = _se[D.log_PMA_Tot]
matrix FS[5,3] = _b[D.log_PMDN_Tot]
matrix FS[5,4] = _se[D.log_PMDN_Tot]
matrix FS[5,5] = _b[D.log_lab_tot]
matrix FS[5,6] = _se[D.log_lab_tot]
matrix FS[5,7] = _b[_cons]
matrix FS[5,8] = _se[_cons]
matrix FS[5,11] = e(N)
qui test D.log_PMA_Tot D.log_PMDN_Tot
matrix FS[5,9]  = r(F)
matrix FS[5,10] = r(p)

matlist FS, format(%9.3f)
preserve
clear
qui svmat double FS, names(col)
qui gen family = ""
local fn POOLED RE FE BE FD
forvalues r = 1/5 {
	qui replace family = word("`fn'", `r') in `r'
}
order family
qui export excel using "`ivfile'", sheet("FIRST_STAGE", replace) firstrow(variables)
restore
display as text "sheet written: FIRST_STAGE"

** POSTEST_IV sheet: diagnostics of every IV model
* fs_stat/fs_p    = joint instrument significance in that family's first stage
*                   (F for pooled/FE/BE/FD, chi2 for the RE family)
* partial_R2      = first-stage partial R2 (pooled families, estat firststage)
* endog_stat/p    = endogeneity of ln K: estat endogenous for the pooled rows,
*                   control-function test (first-stage residual added to the
*                   structural model) for the panel rows
* overid_stat/p   = Sargan-Hansen via xtoverid for panel rows, Hansen J via
*                   GMM for the pooled rows
matrix IVPOST = J(18,8,.)
matrix rownames IVPOST = IVB_RE IVB_EC2SLS IVB_EC2SLS_BC IVB_BE IVB_FE IVB_FD IVB_2SLS IVB_LIML IVB_GMM IVK_RE IVK_EC2SLS IVK_EC2SLS_BC IVK_BE IVK_FE IVK_FD IVK_2SLS IVK_LIML IVK_GMM
matrix colnames IVPOST = fs_stat fs_p partial_R2 endog_stat endog_p overid_stat overid_p N

* first-stage residuals for the control-function endogeneity tests
qui reg log_pmtb log_PMA_Tot log_PMDN_Tot log_lab_tot, vce(cluster Code_Prov)
qui predict double __v, resid
qui reg D.log_pmtb D.log_PMA_Tot D.log_PMDN_Tot D.log_lab_tot, vce(cluster Code_Prov)
qui predict double __vd, resid

local off = 0
foreach y in log_ADHB_Tot log_ADHK_Tot {
	* first-stage stat, p, and N from the family first stages
	forvalues k = 1/3 {
		matrix IVPOST[`off'+`k',1] = FS[2,9]
		matrix IVPOST[`off'+`k',2] = FS[2,10]
		matrix IVPOST[`off'+`k',8] = FS[2,11]
	}
	matrix IVPOST[`off'+4,1] = FS[4,9]
	matrix IVPOST[`off'+4,2] = FS[4,10]
	matrix IVPOST[`off'+4,8] = FS[4,11]
	matrix IVPOST[`off'+5,1] = FS[3,9]
	matrix IVPOST[`off'+5,2] = FS[3,10]
	matrix IVPOST[`off'+5,8] = FS[3,11]
	matrix IVPOST[`off'+6,1] = FS[5,9]
	matrix IVPOST[`off'+6,2] = FS[5,10]
	matrix IVPOST[`off'+6,8] = FS[5,11]
	forvalues k = 7/9 {
		matrix IVPOST[`off'+`k',1] = FS[1,9]
		matrix IVPOST[`off'+`k',2] = FS[1,10]
		matrix IVPOST[`off'+`k',8] = FS[1,11]
	}

	* pooled rows: partial R2, endogeneity, Hansen J
	qui ivregress 2sls `y' log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov)
	qui estat firststage
	matrix __S = r(singleresults)
	qui estat endogenous
	local eF = r(regF)
	local ep = r(p_regF)
	forvalues k = 7/9 {
		matrix IVPOST[`off'+`k',3] = __S[1,3]
		matrix IVPOST[`off'+`k',4] = `eF'
		matrix IVPOST[`off'+`k',5] = `ep'
	}
	qui ivregress gmm `y' log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov)
	qui estat overid
	forvalues k = 7/9 {
		matrix IVPOST[`off'+`k',6] = r(HansenJ)
		matrix IVPOST[`off'+`k',7] = r(p_HansenJ)
	}

	* panel rows: control-function endogeneity test
	qui xtreg `y' log_pmtb log_lab_tot __v, re vce(robust)
	qui test __v
	forvalues k = 1/3 {
		matrix IVPOST[`off'+`k',4] = r(chi2)
		matrix IVPOST[`off'+`k',5] = r(p)
	}
	qui xtreg `y' log_pmtb log_lab_tot __v, be
	qui test __v
	matrix IVPOST[`off'+4,4] = r(F)
	matrix IVPOST[`off'+4,5] = r(p)
	qui xtreg `y' log_pmtb log_lab_tot __v, fe vce(robust)
	qui test __v
	matrix IVPOST[`off'+5,4] = r(F)
	matrix IVPOST[`off'+5,5] = r(p)
	qui reg D.`y' D.log_pmtb D.log_lab_tot __vd, vce(cluster Code_Prov)
	qui test __vd
	matrix IVPOST[`off'+6,4] = r(F)
	matrix IVPOST[`off'+6,5] = r(p)

	* panel rows: Sargan-Hansen overidentification via xtoverid
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re
	capture qui xtoverid
	matrix IVPOST[`off'+1,6] = r(j)
	matrix IVPOST[`off'+1,7] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls
	capture qui xtoverid
	matrix IVPOST[`off'+2,6] = r(j)
	matrix IVPOST[`off'+2,7] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa
	capture qui xtoverid
	matrix IVPOST[`off'+3,6] = r(j)
	matrix IVPOST[`off'+3,7] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be
	capture qui xtoverid
	matrix IVPOST[`off'+4,6] = r(j)
	matrix IVPOST[`off'+4,7] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe
	capture qui xtoverid
	matrix IVPOST[`off'+5,6] = r(j)
	matrix IVPOST[`off'+5,7] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd
	capture qui xtoverid
	matrix IVPOST[`off'+6,6] = r(j)
	matrix IVPOST[`off'+6,7] = r(jp)

	local off = `off' + 9
}
drop __v __vd

matlist IVPOST, format(%9.3f)
preserve
clear
qui svmat double IVPOST, names(col)
qui gen model = ""
local rn IVB_RE IVB_EC2SLS IVB_EC2SLS_BC IVB_BE IVB_FE IVB_FD IVB_2SLS IVB_LIML IVB_GMM IVK_RE IVK_EC2SLS IVK_EC2SLS_BC IVK_BE IVK_FE IVK_FD IVK_2SLS IVK_LIML IVK_GMM
forvalues r = 1/18 {
	qui replace model = word("`rn'", `r') in `r'
}
order model
qui export excel using "`ivfile'", sheet("POSTEST_IV", replace) firstrow(variables)
restore
display as text "sheet written: POSTEST_IV"


*** IV with two endogenous inputs: K instrumented by PMA and PMDN, L by the
*** average sectoral wage (wage_avg = row mean of the 17 x_RataUpah columns)
* structural : logY = lnA + b1*log_pmtb + b2*log_lab_tot, both inputs endogenous
* instruments: log_PMA_Tot log_PMDN_Tot log_wage
* 3 instruments, 2 endogenous -> 1 overidentifying restriction

** all variants, with the first-stage estimates displayed
foreach y in log_ADHB_Tot log_ADHK_Tot {
	local t = cond("`y'"=="log_ADHB_Tot","iv2b","iv2k")
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re first
	estimates store `t'_re
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls first
	estimates store `t'_ec
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls nosa first
	estimates store `t'_ecbc
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), be first
	estimates store `t'_be
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fe first
	estimates store `t'_fe
	xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fd first
	estimates store `t'_fd
	ivregress 2sls `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
	estimates store `t'_2sls
	ivregress liml `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), vce(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
	estimates store `t'_liml
	ivregress gmm `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), wmatrix(cluster Code_Prov) first cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
	estimates store `t'_gmm
}
estimates table iv2b_re iv2b_ec iv2b_ecbc iv2b_be iv2b_fd iv2b_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB two-endogenous IV: panel variants")
estimates table iv2b_2sls iv2b_liml iv2b_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB two-endogenous IV: pooled variants, clustered")
estimates table iv2k_re iv2k_ec iv2k_ecbc iv2k_be iv2k_fd iv2k_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK two-endogenous IV: panel variants")
estimates table iv2k_2sls iv2k_liml iv2k_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK two-endogenous IV: pooled variants, clustered")

** TFP and K/L coefficients per province-year, one sheet per model
local M = 0
foreach y in log_ADHB_Tot log_ADHK_Tot {
	local t = cond("`y'"=="log_ADHB_Tot","IV2B","IV2K")
	local ++M
	local name`M' `t'_RE
	local cmd`M'  xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re
	local ++M
	local name`M' `t'_EC2SLS
	local cmd`M'  xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls
	local ++M
	local name`M' `t'_EC2SLS_BC
	local cmd`M'  xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls nosa
	local ++M
	local name`M' `t'_BE
	local cmd`M'  xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), be
	local ++M
	local name`M' `t'_FE
	local cmd`M'  xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fe
	local ++M
	local name`M' `t'_2SLS
	local cmd`M'  ivregress 2sls `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), vce(cluster Code_Prov)
	local ++M
	local name`M' `t'_LIML
	local cmd`M'  ivregress liml `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), vce(cluster Code_Prov)
	local ++M
	local name`M' `t'_GMM
	local cmd`M'  ivregress gmm `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), wmatrix(cluster Code_Prov)
}
forvalues i = 1/`M' {
	qui `cmd`i''
	local y = e(depvar)
	qui gen double lntfp = `y' - _b[log_pmtb]*log_pmtb - _b[log_lab_tot]*log_lab_tot
	qui gen double tfp   = exp(lntfp)
	qui gen double b1_pmtb    = _b[log_pmtb]
	qui gen double b2_lab_tot = _b[log_lab_tot]
	preserve
	keep Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	order Code_Prov Pre_Prov Year lntfp tfp b1_pmtb b2_lab_tot
	qui export excel using "`ivfile'", sheet("`name`i''", replace) firstrow(variables)
	restore
	drop lntfp tfp b1_pmtb b2_lab_tot
	display as text "sheet written: `name`i''"
}
foreach y in log_ADHB_Tot log_ADHK_Tot {
	local t = cond("`y'"=="log_ADHB_Tot","IV2B","IV2K")
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fd
	qui gen double tfp_growth = 100*(D.`y' - _b[D.log_pmtb]*D.log_pmtb - _b[D.log_lab_tot]*D.log_lab_tot)
	qui gen double b1_pmtb    = _b[D.log_pmtb]
	qui gen double b2_lab_tot = _b[D.log_lab_tot]
	preserve
	keep Code_Prov Pre_Prov Year tfp_growth b1_pmtb b2_lab_tot
	order Code_Prov Pre_Prov Year tfp_growth b1_pmtb b2_lab_tot
	qui export excel using "`ivfile'", sheet("`t'_FD", replace) firstrow(variables)
	restore
	drop tfp_growth b1_pmtb b2_lab_tot
	display as text "sheet written: `t'_FD"
}

** FIRST_STAGE2 sheet: two first-stage equations (K and L) per estimator family
matrix FS2 = J(10,11,.)
matrix rownames FS2 = POOLED_K POOLED_L RE_K RE_L FE_K FE_L BE_K BE_L FD_K FD_L
matrix colnames FS2 = b_PMA se_PMA b_PMDN se_PMDN b_wage se_wage b_cons se_cons instr_stat instr_p N
local row = 0
foreach fam in POOLED RE FE BE FD {
	foreach v in log_pmtb log_lab_tot {
		local ++row
		if "`fam'"=="POOLED" qui reg `v' log_PMA_Tot log_PMDN_Tot log_wage, vce(cluster Code_Prov)
		if "`fam'"=="RE"     qui xtreg `v' log_PMA_Tot log_PMDN_Tot log_wage, re vce(robust)
		if "`fam'"=="FE"     qui xtreg `v' log_PMA_Tot log_PMDN_Tot log_wage, fe vce(robust)
		if "`fam'"=="BE"     qui xtreg `v' log_PMA_Tot log_PMDN_Tot log_wage, be
		if "`fam'"=="FD"     qui reg D.`v' D.log_PMA_Tot D.log_PMDN_Tot D.log_wage, vce(cluster Code_Prov)
		if "`fam'"=="FD" {
			matrix FS2[`row',1] = _b[D.log_PMA_Tot]
			matrix FS2[`row',2] = _se[D.log_PMA_Tot]
			matrix FS2[`row',3] = _b[D.log_PMDN_Tot]
			matrix FS2[`row',4] = _se[D.log_PMDN_Tot]
			matrix FS2[`row',5] = _b[D.log_wage]
			matrix FS2[`row',6] = _se[D.log_wage]
			matrix FS2[`row',7] = _b[_cons]
			matrix FS2[`row',8] = _se[_cons]
			matrix FS2[`row',11] = e(N)
			qui test D.log_PMA_Tot D.log_PMDN_Tot D.log_wage
		}
		else {
			matrix FS2[`row',1] = _b[log_PMA_Tot]
			matrix FS2[`row',2] = _se[log_PMA_Tot]
			matrix FS2[`row',3] = _b[log_PMDN_Tot]
			matrix FS2[`row',4] = _se[log_PMDN_Tot]
			matrix FS2[`row',5] = _b[log_wage]
			matrix FS2[`row',6] = _se[log_wage]
			matrix FS2[`row',7] = _b[_cons]
			matrix FS2[`row',8] = _se[_cons]
			matrix FS2[`row',11] = e(N)
			qui test log_PMA_Tot log_PMDN_Tot log_wage
		}
		matrix FS2[`row',9]  = cond("`fam'"=="RE", r(chi2), r(F))
		matrix FS2[`row',10] = r(p)
	}
}
matlist FS2, format(%9.3f)
preserve
clear
qui svmat double FS2, names(col)
qui gen family_eq = ""
local fn POOLED_K POOLED_L RE_K RE_L FE_K FE_L BE_K BE_L FD_K FD_L
forvalues r = 1/10 {
	qui replace family_eq = word("`fn'", `r') in `r'
}
order family_eq
qui export excel using "`ivfile'", sheet("FIRST_STAGE2", replace) firstrow(variables)
restore
display as text "sheet written: FIRST_STAGE2"

** POSTEST_IV2 sheet: diagnostics of every two-endogenous IV model
* fsK/fsL = joint instrument significance in that family's K and L first
* stages; shea = Shea partial R2 (pooled); endog = joint endogeneity test of
* both inputs (estat endogenous for pooled rows, control function for panel
* rows); overid = Sargan-Hansen (xtoverid) or Hansen J (GMM, pooled rows)
matrix IVPOST2 = J(18,11,.)
matrix rownames IVPOST2 = IV2B_RE IV2B_EC2SLS IV2B_EC2SLS_BC IV2B_BE IV2B_FE IV2B_FD IV2B_2SLS IV2B_LIML IV2B_GMM IV2K_RE IV2K_EC2SLS IV2K_EC2SLS_BC IV2K_BE IV2K_FE IV2K_FD IV2K_2SLS IV2K_LIML IV2K_GMM
matrix colnames IVPOST2 = fsK_stat fsK_p fsL_stat fsL_p sheaK_R2 sheaL_R2 endog_stat endog_p overid_stat overid_p N

* first-stage residuals for the control-function endogeneity tests
qui reg log_pmtb log_PMA_Tot log_PMDN_Tot log_wage, vce(cluster Code_Prov)
qui predict double __vK, resid
qui reg log_lab_tot log_PMA_Tot log_PMDN_Tot log_wage, vce(cluster Code_Prov)
qui predict double __vL, resid
qui reg D.log_pmtb D.log_PMA_Tot D.log_PMDN_Tot D.log_wage, vce(cluster Code_Prov)
qui predict double __vKd, resid
qui reg D.log_lab_tot D.log_PMA_Tot D.log_PMDN_Tot D.log_wage, vce(cluster Code_Prov)
qui predict double __vLd, resid

local off = 0
foreach y in log_ADHB_Tot log_ADHK_Tot {
	* first-stage stats and N by family
	forvalues k = 1/3 {
		matrix IVPOST2[`off'+`k',1] = FS2[3,9]
		matrix IVPOST2[`off'+`k',2] = FS2[3,10]
		matrix IVPOST2[`off'+`k',3] = FS2[4,9]
		matrix IVPOST2[`off'+`k',4] = FS2[4,10]
		matrix IVPOST2[`off'+`k',11] = FS2[3,11]
	}
	matrix IVPOST2[`off'+4,1] = FS2[7,9]
	matrix IVPOST2[`off'+4,2] = FS2[7,10]
	matrix IVPOST2[`off'+4,3] = FS2[8,9]
	matrix IVPOST2[`off'+4,4] = FS2[8,10]
	matrix IVPOST2[`off'+4,11] = FS2[7,11]
	matrix IVPOST2[`off'+5,1] = FS2[5,9]
	matrix IVPOST2[`off'+5,2] = FS2[5,10]
	matrix IVPOST2[`off'+5,3] = FS2[6,9]
	matrix IVPOST2[`off'+5,4] = FS2[6,10]
	matrix IVPOST2[`off'+5,11] = FS2[5,11]
	matrix IVPOST2[`off'+6,1] = FS2[9,9]
	matrix IVPOST2[`off'+6,2] = FS2[9,10]
	matrix IVPOST2[`off'+6,3] = FS2[10,9]
	matrix IVPOST2[`off'+6,4] = FS2[10,10]
	matrix IVPOST2[`off'+6,11] = FS2[9,11]
	forvalues k = 7/9 {
		matrix IVPOST2[`off'+`k',1] = FS2[1,9]
		matrix IVPOST2[`off'+`k',2] = FS2[1,10]
		matrix IVPOST2[`off'+`k',3] = FS2[2,9]
		matrix IVPOST2[`off'+`k',4] = FS2[2,10]
		matrix IVPOST2[`off'+`k',11] = FS2[1,11]
	}

	* pooled rows: Shea partial R2, endogeneity, Hansen J
	qui ivregress 2sls `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), vce(cluster Code_Prov)
	qui estat firststage
	matrix __S2 = r(multiresults)
	qui estat endogenous
	local eF = r(regF)
	local ep = r(p_regF)
	forvalues k = 7/9 {
		matrix IVPOST2[`off'+`k',5] = __S2[1,1]
		matrix IVPOST2[`off'+`k',6] = __S2[2,1]
		matrix IVPOST2[`off'+`k',7] = `eF'
		matrix IVPOST2[`off'+`k',8] = `ep'
	}
	qui ivregress gmm `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), wmatrix(cluster Code_Prov)
	qui estat overid
	forvalues k = 7/9 {
		matrix IVPOST2[`off'+`k',9]  = r(HansenJ)
		matrix IVPOST2[`off'+`k',10] = r(p_HansenJ)
	}

	* panel rows: control-function endogeneity test (both residuals jointly)
	qui xtreg `y' log_pmtb log_lab_tot __vK __vL, re vce(robust)
	qui test __vK __vL
	forvalues k = 1/3 {
		matrix IVPOST2[`off'+`k',7] = r(chi2)
		matrix IVPOST2[`off'+`k',8] = r(p)
	}
	qui xtreg `y' log_pmtb log_lab_tot __vK __vL, be
	qui test __vK __vL
	matrix IVPOST2[`off'+4,7] = r(F)
	matrix IVPOST2[`off'+4,8] = r(p)
	qui xtreg `y' log_pmtb log_lab_tot __vK __vL, fe vce(robust)
	qui test __vK __vL
	matrix IVPOST2[`off'+5,7] = r(F)
	matrix IVPOST2[`off'+5,8] = r(p)
	qui reg D.`y' D.log_pmtb D.log_lab_tot __vKd __vLd, vce(cluster Code_Prov)
	qui test __vKd __vLd
	matrix IVPOST2[`off'+6,7] = r(F)
	matrix IVPOST2[`off'+6,8] = r(p)

	* panel rows: Sargan-Hansen overidentification via xtoverid
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re
	capture qui xtoverid
	matrix IVPOST2[`off'+1,9]  = r(j)
	matrix IVPOST2[`off'+1,10] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls
	capture qui xtoverid
	matrix IVPOST2[`off'+2,9]  = r(j)
	matrix IVPOST2[`off'+2,10] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), re ec2sls nosa
	capture qui xtoverid
	matrix IVPOST2[`off'+3,9]  = r(j)
	matrix IVPOST2[`off'+3,10] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), be
	capture qui xtoverid
	matrix IVPOST2[`off'+4,9]  = r(j)
	matrix IVPOST2[`off'+4,10] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fe
	capture qui xtoverid
	matrix IVPOST2[`off'+5,9]  = r(j)
	matrix IVPOST2[`off'+5,10] = r(jp)
	return clear
	qui xtivreg `y' (log_pmtb log_lab_tot = log_PMA_Tot log_PMDN_Tot log_wage), fd
	capture qui xtoverid
	matrix IVPOST2[`off'+6,9]  = r(j)
	matrix IVPOST2[`off'+6,10] = r(jp)

	local off = `off' + 9
}
drop __vK __vL __vKd __vLd

matlist IVPOST2, format(%9.3f)
preserve
clear
qui svmat double IVPOST2, names(col)
qui gen model = ""
local rn IV2B_RE IV2B_EC2SLS IV2B_EC2SLS_BC IV2B_BE IV2B_FE IV2B_FD IV2B_2SLS IV2B_LIML IV2B_GMM IV2K_RE IV2K_EC2SLS IV2K_EC2SLS_BC IV2K_BE IV2K_FE IV2K_FD IV2K_2SLS IV2K_LIML IV2K_GMM
forvalues r = 1/18 {
	qui replace model = word("`rn'", `r') in `r'
}
order model
qui export excel using "`ivfile'", sheet("POSTEST_IV2", replace) firstrow(variables)
restore
display as text "sheet written: POSTEST_IV2"

