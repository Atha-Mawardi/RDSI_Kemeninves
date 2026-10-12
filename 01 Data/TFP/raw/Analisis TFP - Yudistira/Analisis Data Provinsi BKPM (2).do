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

** export the real-TFP constants (RE and FE) to Excel
preserve
keep Code_Prov Pre_Prov Year cons_i_k tfp_i_k cons_it_k tfp_it_k cons_i_k_fe tfp_i_k_fe cons_it_k_fe tfp_it_k_fe
order Code_Prov Pre_Prov Year cons_i_k tfp_i_k cons_it_k tfp_it_k cons_i_k_fe tfp_i_k_fe cons_it_k_fe tfp_it_k_fe
export excel using "D:\Kurang Duit\Kemen Inves-BKPM\ADHK TFP per Province-Year.xlsx", firstrow(variables) replace
restore


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


*** Post-estimation diagnostics: which model explains the dataset best
* community-contributed tests, installed once if missing (needs internet the first time)
capture which xttest3
if _rc ssc install xttest3
capture which xtcsd
if _rc ssc install xtcsd
capture which xtserial
if _rc net install st0039, from(http://www.stata-journal.com/software/sj3-2)
* (normality of u_i and e_it: your own check slots in here, e.g. predict the
* residuals after each model and run sktest / swilk)

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
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe
estimates store iv_b_fe

** panel IV on real output (ADHK): RE (G2SLS) then FE (within IV)
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re first
estimates store iv_k_re
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fe
estimates store iv_k_fe

** IV diagnostics (after ivregress, which xtivreg does not provide):
* weak instruments (first-stage F), overidentification, endogeneity of ln K
ivregress 2sls log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_pool
estat firststage
estat endogenous
* the overid test valid under clustering is Hansen's J, from the GMM estimator
qui ivregress gmm log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov)
estat overid

ivregress 2sls log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
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
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls
estimates store iv_b_ec
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa
estimates store iv_b_ecbc
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be
estimates store iv_b_be
xtivreg log_ADHB_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd
estimates store iv_b_fd

xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls
estimates store iv_k_ec
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, re ec2sls nosa
estimates store iv_k_ecbc
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, be
estimates store iv_k_be
xtivreg log_ADHK_Tot (log_pmtb = log_PMA_Tot log_PMDN_Tot) log_lab_tot, fd
estimates store iv_k_fd

** pooled IV variants: LIML is less biased than 2SLS when instruments are
* weak; two-step GMM is more efficient under heteroskedasticity/clustering
ivregress liml log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_liml
ivregress gmm log_ADHB_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_b_gmm
ivregress liml log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), vce(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_k_liml
ivregress gmm log_ADHK_Tot log_lab_tot (log_pmtb = log_PMA_Tot log_PMDN_Tot), wmatrix(cluster Code_Prov) cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)
estimates store iv_k_gmm

** all IV variants side by side
estimates table iv_b_re iv_b_ec iv_b_ecbc iv_b_be iv_b_fd iv_b_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB: panel IV variants")
estimates table iv_b_pool iv_b_liml iv_b_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHB: pooled IV variants, clustered")
estimates table iv_k_re iv_k_ec iv_k_ecbc iv_k_be iv_k_fd iv_k_fe, keep(log_pmtb log_lab_tot _cons D.log_pmtb D.log_lab_tot) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK: panel IV variants")
estimates table iv_k_pool iv_k_liml iv_k_gmm, keep(log_pmtb log_lab_tot _cons) b(%9.3f) se(%9.3f) stats(N) modelwidth(10) title("ADHK: pooled IV variants, clustered")

