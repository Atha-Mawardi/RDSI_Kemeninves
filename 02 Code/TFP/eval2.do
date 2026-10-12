* eval2.do — Moran/kantong + FGLS grup pada K, L, residual, SLX fiskal
* Atha Bintang Wahyu M. | PSE UGM
*
* Syarat: eval1.do sudah dijalankan (eval_panel.dta). Residual konstruksi D.
* Island W = rata-rata pulau, bukan spillover. Moran pada mean provinsi (N=34).
* Regresi: xtgls panels(heteroskedastic) igls, globals sama Determinan.
* Bukan FE2W, bukan lincom komposit, bukan CD x share.
*
* Jalankan dari root:  do "02 Code/TFP/eval2.do"

version 17
clear all
set more off
set matsize 2000
capture log close

if `"${proj}"' == "" {
	if fileexists("2026bkpm.Rproj") global proj "`c(pwd)'"
	else if fileexists("../2026bkpm.Rproj") global proj "`c(pwd)'/.."
	else if fileexists("../../2026bkpm.Rproj") global proj "`c(pwd)'/../.."
	else global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"
}

global outdir "${proj}/01 Data/TFP/output/eval"
global panel  "${outdir}/eval_panel.dta"

if !fileexists("${panel}") {
	display as error "eval_panel.dta missing — run eval1.do first"
	exit 601
}

log using "${outdir}/eval2.log", replace text
display as text "proj  = $proj"
display as text "panel = $panel"

use "${panel}", clear
xtset Code_Prov Year
isid Code_Prov Year

* =============================================================================
* 1. BOBOT SPASIAL queen (darat + jembatan laut yang dipakai EDA2) + pulau
* =============================================================================

preserve
clear
input int i int j
11 12
12 13
13 14
13 15
13 16
14 15
14 16
14 21
15 16
15 17
16 17
16 18
16 19
17 18
31 32
31 36
32 33
32 36
33 34
33 35
35 51
51 52
52 53
61 62
61 63
62 63
62 64
63 64
64 65
71 72
71 75
71 82
72 73
72 74
72 75
72 76
73 74
73 76
81 82
81 94
91 94
end
expand 2
bysort i j: keep if _n == 1
* symmetrise
tempfile one
save `one'
use `one', clear
rename (i j) (j i)
append using `one'
drop if i == j
duplicates drop i j, force
rename (i j) (Code_Prov nb)
tempfile edges
save `edges'
restore

* spatial lag queen = rata-rata tetangga, per tahun
tempfile main
save `main'
use `main', clear
rename Code_Prov nb
keep nb Year pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas ///
	pilar_lingkungan pilar_keamanan idx_solow idx_hard idx_fiskal ///
	logtfp_it logtfp_it_crs indeks_hijau rasio_pad ln_apbd_belanja apbd_serapan ///
	share_inv_padat_karya share_tk_primer share_tk_ekstraktif pad
foreach v in pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas ///
	pilar_lingkungan pilar_keamanan idx_solow idx_hard idx_fiskal ///
	logtfp_it logtfp_it_crs indeks_hijau rasio_pad ln_apbd_belanja apbd_serapan ///
	share_inv_padat_karya share_tk_primer share_tk_ekstraktif pad {
	rename `v' nb_`v'
}
tempfile nby
save `nby'

use `main', clear
joinby Code_Prov using `edges'
rename nb nb
joinby nb Year using `nby'
* rata tetangga
foreach v in pendidikan equity institusi konektivitas lingkungan keamanan {
	bysort Code_Prov Year: egen double Wq_pilar_`v' = mean(nb_pilar_`v')
}
foreach v in idx_solow idx_hard idx_fiskal logtfp_it logtfp_it_crs indeks_hijau ///
	rasio_pad ln_apbd_belanja apbd_serapan share_inv_padat_karya share_tk_primer ///
	share_tk_ekstraktif pad {
	bysort Code_Prov Year: egen double Wq_`v' = mean(nb_`v')
}
bysort Code_Prov Year: keep if _n == 1
drop nb nb_*
* island lag = rata pulau leave-one-out
foreach v in pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas ///
	pilar_lingkungan pilar_keamanan idx_solow idx_fiskal logtfp_it logtfp_it_crs ///
	indeks_hijau rasio_pad {
	bysort Pulau Year: egen double _sum = total(`v')
	bysort Pulau Year: egen byte _nisl = count(`v')
	gen double Wi_`v' = (_sum - `v') / (_nisl - 1) if _nisl > 1
	drop _sum _nisl
}

xtset Code_Prov Year
save "${outdir}/eval_panel_W.dta", replace

* =============================================================================
* 2. MORAN pada mean provinsi (N=34) — objek yang boleh dikutip
* =============================================================================

preserve
keep if Year == 2024
keep Code_Prov Pre_Prov Pulau m_* Wq_* Wi_* d_high_fiskal d_high_solow ///
	top5_* bot5_* dominan_tk d_ekstraktif d_sawit d_hilir
* Moran I = z'Wz / z'z dengan W row-standardised (Wq sudah mean tetangga)
foreach v in m_logtfp_it m_logtfp_it_crs m_pilar_pendidikan m_pilar_equity ///
	m_pilar_institusi m_pilar_konektivitas m_pilar_lingkungan m_pilar_keamanan ///
	m_idx_solow m_idx_fiskal m_indeks_hijau m_rasio_pad m_share_tk_primer {
	capture confirm variable `v'
}

* hitung Moran dari Wq pada level 2024 (Wq_ adalah lag level, bukan mean —
* untuk between pakai rata Wq)
tempfile y2024
save `y2024'
restore

preserve
collapse (mean) ///
	pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas ///
	pilar_lingkungan pilar_keamanan idx_solow idx_hard idx_fiskal ///
	logtfp_it logtfp_it_crs indeks_hijau rasio_pad ln_apbd_belanja apbd_serapan ///
	share_tk_primer share_tk_ekstraktif share_inv_padat_karya share_inv_A ///
	Wq_pilar_pendidikan Wq_pilar_equity Wq_pilar_institusi Wq_pilar_konektivitas ///
	Wq_pilar_lingkungan Wq_pilar_keamanan Wq_idx_solow Wq_idx_fiskal ///
	Wq_logtfp_it Wq_logtfp_it_crs Wq_indeks_hijau Wq_rasio_pad ///
	Wq_share_tk_primer Wq_ln_apbd_belanja Wq_apbd_serapan ///
	Wi_pilar_pendidikan Wi_pilar_equity Wi_pilar_institusi Wi_idx_solow ///
	Wi_idx_fiskal Wi_logtfp_it Wi_logtfp_it_crs Wi_indeks_hijau Wi_rasio_pad ///
	(first) Pre_Prov Pulau d_high_fiskal d_high_solow d_ekstraktif d_sawit ///
	d_hilir d_dom_primer d_dom_sekunder ///
	top5_pendidikan top5_equity top5_institusi top5_konektivitas top5_lingkungan top5_keamanan ///
	bot5_pendidikan bot5_equity bot5_institusi bot5_konektivitas bot5_lingkungan bot5_keamanan, ///
	by(Code_Prov)

postfile mor str16 var str8 W float I p N using "${outdir}/eval2_moran.dta", replace
foreach v in logtfp_it logtfp_it_crs pilar_pendidikan pilar_equity ///
	pilar_institusi pilar_konektivitas pilar_lingkungan pilar_keamanan ///
	idx_solow idx_fiskal indeks_hijau rasio_pad share_tk_primer {
	foreach w in Wq Wi {
		if "`w'" == "Wq" {
			if inlist("`v'", "pilar_pendidikan", "pilar_equity", "pilar_institusi", ///
				"pilar_konektivitas", "pilar_lingkungan", "pilar_keamanan") {
				local wv Wq_`v'
			}
			else local wv Wq_`v'
		}
		else {
			capture confirm variable Wi_`v'
			if _rc continue
			local wv Wi_`v'
		}
		capture confirm variable `wv'
		if _rc continue
		quietly summarize `v'
		local n = r(N)
		quietly correlate `v' `wv'
		local I = r(rho)
		quietly regress `v' `wv'
		local p = 2 * ttail(e(df_r), abs(_b[`wv']/_se[`wv']))
		post mor ("`v'") ("`w'") (`I') (`p') (`n')
	}
}
postclose mor

* kuadran LISA: z vs Wz, median
foreach v in idx_solow idx_fiskal logtfp_it_crs indeks_hijau pilar_equity pilar_pendidikan rasio_pad {
	capture confirm variable Wq_`v'
	if _rc {
		if inlist("`v'", "pilar_pendidikan", "pilar_equity") local wv Wq_`v'
		else local wv Wq_`v'
	}
	else local wv Wq_`v'
	if inlist("`v'", "pilar_pendidikan", "pilar_equity", "pilar_institusi", ///
		"pilar_konektivitas", "pilar_lingkungan", "pilar_keamanan") {
		local wv Wq_`v'
	}
	capture confirm variable `wv'
	if _rc continue
	quietly summarize `v', detail
	local med = r(p50)
	quietly summarize `wv', detail
	local medw = r(p50)
	gen str8 lisa_`v' = "LH"
	replace lisa_`v' = "HH" if `v' >= `med' & `wv' >= `medw'
	replace lisa_`v' = "LL" if `v' <  `med' & `wv' <  `medw'
	replace lisa_`v' = "HL" if `v' >= `med' & `wv' <  `medw'
	replace lisa_`v' = "LH" if `v' <  `med' & `wv' >= `medw'
}

* kantong: LL fiskal atau LL solow, atau bot5 ≥ 3 pilar
egen byte n_bot5 = rowtotal(bot5_pendidikan bot5_equity bot5_institusi ///
	bot5_konektivitas bot5_keamanan)
egen byte n_top5 = rowtotal(top5_pendidikan top5_equity top5_institusi ///
	top5_konektivitas top5_keamanan)
* lingkungan dibuang dari hitungan kantong: Jawa selalu bot5 hijau
gen byte kantong_lemah = (n_bot5 >= 2) | ///
	((lisa_idx_solow == "LL") & (lisa_logtfp_it_crs == "LL"))
gen byte kantong_kuat  = (n_top5 >= 2) | (lisa_idx_solow == "HH")

gsort Code_Prov
export excel using "${outdir}/eval2_between.xlsx", sheet("between") firstrow(variables) replace
export delimited using "${outdir}/eval2_between.csv", replace
list Code_Prov Pre_Prov Pulau n_bot5 n_top5 kantong_lemah lisa_idx_solow ///
	lisa_idx_fiskal lisa_logtfp_it_crs if kantong_lemah, noobs ab(12)
restore

use "${outdir}/eval2_moran.dta", clear
export delimited using "${outdir}/eval2_moran.csv", replace

* =============================================================================
* 3. GLOBALS — sama Determinan; FGLS grup pada K, L, residual
* =============================================================================

use "${outdir}/eval_panel_W.dta", clear
xtset Code_Prov Year

global pendidikan ///
	z_ln_lama_sekolah_mean ///
	z_ln_lama_sekolah_harapan ///
	z_db_sd z_db_smp z_db_sma z_db_kampus

global equity ///
	z_ln_p1 ///
	z_ln_ipm ///
	z_gini ///
	z_ln_upah_rata ///
	z_ln_indeks_demokrasi

global institusi ///
	z_price ///
	z_ln_rasio_pad ///
	z_ln_pertumbuhan_pdrb_adhb ///
	z_ln_apbd_belanja

global konektivitas ///
	z_ln_jalan_mantap ///
	z_ln_kargo_udara ///
	z_ln_kargo_kapal ///
	z_ln_kargo_kereta ///
	z_ln_penumpang_total ///
	z_ln_airport_logistik ///
	z_ln_airport_komersil

global lingkungan ///
	z_ln_indeks_lingkungan ///
	z_ln_indeks_hijau ///
	z_ln_indeks_biru

global keamanan ///
	z_ln_crime_risk ///
	z_ln_crime_rate

* ----- F  pendidikan / equity / institusi pada log K dan log L ---------------

xtgls log_K $pendidikan, panels(heteroskedastic) igls nolog
estimates store FGLS_K_pendidikan
xtgls log_K $equity, panels(heteroskedastic) igls nolog
estimates store FGLS_K_equity
xtgls log_K $institusi, panels(heteroskedastic) igls nolog
estimates store FGLS_K_institusi
xtgls log_K $konektivitas, panels(heteroskedastic) igls nolog
estimates store FGLS_K_konektivitas
xtgls log_K $keamanan, panels(heteroskedastic) igls nolog
estimates store FGLS_K_keamanan

xtgls log_L $pendidikan, panels(heteroskedastic) igls nolog
estimates store FGLS_L_pendidikan
xtgls log_L $equity, panels(heteroskedastic) igls nolog
estimates store FGLS_L_equity
xtgls log_L $institusi, panels(heteroskedastic) igls nolog
estimates store FGLS_L_institusi
xtgls log_L $konektivitas, panels(heteroskedastic) igls nolog
estimates store FGLS_L_konektivitas
xtgls log_L $keamanan, panels(heteroskedastic) igls nolog
estimates store FGLS_L_keamanan

estimates table ///
	FGLS_K_pendidikan FGLS_K_equity FGLS_K_institusi FGLS_K_konektivitas FGLS_K_keamanan, ///
	star stats(N) b(%7.3f)
estimates table ///
	FGLS_L_pendidikan FGLS_L_equity FGLS_L_institusi FGLS_L_konektivitas FGLS_L_keamanan, ///
	star stats(N) b(%7.3f)

* ----- G / H  investasi sektoral pada residual (bukan CD x share) ------------

xtgls logtfp_it share_inv_padat_karya share_inv_padat_modal, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_inv_pk

xtgls logtfp_it share_inv_primer share_inv_sekunder share_inv_C, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_inv_sektor

xtgls logtfp_it share_inv_primer d_dom_primer share_inv_sekunder d_dom_sekunder, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_inv_dom

xtgls logtfp_it share_inv_C share_tk_C, panels(heteroskedastic) igls nolog
estimates store FGLS_invC_tkC

xtgls indeks_hijau share_inv_hijau_inv share_tk_ekstraktif, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_hijinv

xtgls logtfp_it share_inv_A d_sawit, panels(heteroskedastic) igls nolog
estimates store FGLS_sawit

estimates table ///
	FGLS_inv_pk FGLS_inv_sektor FGLS_inv_dom FGLS_invC_tkC FGLS_hijinv FGLS_sawit, ///
	star stats(N) b(%7.3f)

* ----- J / K  SLX: X + WX, xtgls; island W = geografi ------------------------
* PAD vs belanja: apakah "institusi" = skala fiskal

xtgls logtfp_it z_ln_rasio_pad z_ln_apbd_belanja z_ln_apbd_serapan, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_pad_belanja

xtgls logtfp_it z_ln_rasio_pad z_ln_apbd_belanja ///
	Wq_rasio_pad Wq_ln_apbd_belanja, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_fiskal_q

xtgls logtfp_it z_ln_rasio_pad z_ln_apbd_belanja ///
	Wi_rasio_pad, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_fiskal_i

xtgls logtfp_it $pendidikan Wq_pilar_pendidikan, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_pend_q

xtgls logtfp_it $equity Wq_pilar_equity, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_eq_q

xtgls logtfp_it $institusi Wq_pilar_institusi, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_inst_q

xtgls logtfp_it_crs z_ln_rasio_pad z_ln_apbd_belanja ///
	Wq_rasio_pad Wq_ln_apbd_belanja, panels(heteroskedastic) igls nolog
estimates store FGLS_SLX_crs_fiskal

estimates table ///
	FGLS_pad_belanja FGLS_SLX_fiskal_q FGLS_SLX_fiskal_i ///
	FGLS_SLX_pend_q FGLS_SLX_eq_q FGLS_SLX_inst_q FGLS_SLX_crs_fiskal, ///
	star stats(N) b(%7.3f)

* ----- L  kantong (dari between) ---------------------------------------------

preserve
import delimited "${outdir}/eval2_between.csv", clear
keep code_prov kantong_lemah kantong_kuat n_bot5 n_top5 lisa_idx_solow lisa_idx_fiskal lisa_logtfp_it_crs
rename code_prov Code_Prov
tempfile kantong
save `kantong'
restore
merge m:1 Code_Prov using `kantong', nogen
save "${outdir}/eval_panel_W.dta", replace

xtgls logtfp_it kantong_lemah, panels(heteroskedastic) igls nolog
estimates store FGLS_kantong
xtgls logtfp_it_crs kantong_lemah, panels(heteroskedastic) igls nolog
estimates store FGLS_kantong_crs

estimates table FGLS_kantong FGLS_kantong_crs, star stats(N) b(%7.3f)

* =============================================================================
* 4. COEF FGLS → csv
* =============================================================================

tempname H
postfile `H' str40 model str40 var float b se t p n using "${outdir}/eval2_coef.dta", replace

foreach m in ///
	FGLS_K_pendidikan FGLS_K_equity FGLS_K_institusi FGLS_K_konektivitas FGLS_K_keamanan ///
	FGLS_L_pendidikan FGLS_L_equity FGLS_L_institusi FGLS_L_konektivitas FGLS_L_keamanan ///
	FGLS_inv_pk FGLS_inv_sektor FGLS_inv_dom FGLS_invC_tkC FGLS_hijinv FGLS_sawit ///
	FGLS_pad_belanja FGLS_SLX_fiskal_q FGLS_SLX_fiskal_i ///
	FGLS_SLX_pend_q FGLS_SLX_eq_q FGLS_SLX_inst_q FGLS_SLX_crs_fiskal ///
	FGLS_kantong FGLS_kantong_crs {
	capture noisily estimates restore `m'
	if _rc continue
	quietly count if e(sample)
	local n = r(N)
	local vars : colnames e(b)
	foreach v of local vars {
		if "`v'" == "_cons" continue
		capture {
			local bi = _b[`v']
			local se = _se[`v']
			local tt = `bi' / `se'
			local pp = 2 * (1 - normal(abs(`tt')))
			post `H' ("`m'") ("`v'") (`bi') (`se') (`tt') (`pp') (`n')
		}
	}
}
postclose `H'

use "${outdir}/eval2_coef.dta", clear
gen str8 star = ""
replace star = "*"    if p < 0.05
replace star = "**"   if p < 0.01
replace star = "***"  if p < 0.001
export excel using "${outdir}/eval2_coef.xlsx", sheet("coef") firstrow(variables) replace
export delimited using "${outdir}/eval2_coef.csv", replace
export delimited using "${outdir}/eval2_coef_fgls.csv", replace

use "${outdir}/eval_panel_W.dta", clear
export excel using "${outdir}/eval_panel_W.xlsx", sheet("panel") firstrow(variables) replace

do "${proj}/02 Code/TFP/compile_panel.do"

display as text _n "eval2 done."
display as text "between -> ${outdir}/eval2_between.csv"
display as text "moran   -> ${outdir}/eval2_moran.csv"
display as text "coef    -> ${outdir}/eval2_coef.csv"
display as text "panel gabungan -> ${proj}/01 Data/TFP/processed/Panel TFP Provinsi 2017-2024.dta"
log close
