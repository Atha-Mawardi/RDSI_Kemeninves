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

gen pmtb1 = pmtb*1e+6
gen log_pmtb = log(pmtb1)

gen ADHB_Tot = ADHB_9*1e+6
gen log_ADHB_Tot = log(ADHB_Tot)

gen ADHK_Tot = ADHK_9*1e+6
gen log_ADHK_Tot = log(ADHK_Tot)
	
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

*** Export the constants to Excel
preserve
keep Code_Prov Pre_Prov Year cons_i tfp_i cons_it tfp_it b_pmtb b_lab_tot
order Code_Prov Pre_Prov Year cons_i tfp_i cons_it tfp_it b_pmtb b_lab_tot
export excel using "D:\Kurang Duit\Kemen Inves-BKPM\RE Constants per Province-Year.xlsx", firstrow(variables) replace
restore


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

*** Export the FE constants (TFP) and the province-specific coefficients to Excel
preserve
keep Code_Prov Pre_Prov Year cons_i_fe tfp_i_fe cons_it_fe tfp_it_fe cons_prov b_pmtb_prov b_lab_prov
order Code_Prov Pre_Prov Year cons_i_fe tfp_i_fe cons_it_fe tfp_it_fe cons_prov b_pmtb_prov b_lab_prov
export excel using "D:\Kurang Duit\Kemen Inves-BKPM\FE Constants and Coefficients per Province.xlsx", firstrow(variables) replace
restore


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


*** Real-output (ADHK) estimation: the same Solow model on constant-price GRDP
* log_ADHK_Tot has no missing values, but log_pmtb/log_lab_tot are missing in
* 2025, so the sample stays 272 obs - directly comparable with the ADHB runs

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

** export the real-TFP constants (RE and FE) to Excel
preserve
keep Code_Prov Pre_Prov Year cons_i_k tfp_i_k cons_it_k tfp_it_k cons_i_k_fe tfp_i_k_fe cons_it_k_fe tfp_it_k_fe
order Code_Prov Pre_Prov Year cons_i_k tfp_i_k cons_it_k tfp_it_k cons_i_k_fe tfp_i_k_fe cons_it_k_fe tfp_it_k_fe
export excel using "D:\Kurang Duit\Kemen Inves-BKPM\ADHK TFP per Province-Year.xlsx", firstrow(variables) replace
restore


*** Growth-form (first-difference Solow) estimation for consistency checks
* Grwth1_Prov = nominal GRDP growth, Grwth2_Prov = real GRDP growth, both in
* percent; the Solow model in differences is
* growth_Y[i,t] = g_A + b1*growth_K[i,t] + b2*growth_L[i,t] + shocks
* the input growth rates are built as 100*log-differences so b1 and b2 remain
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

