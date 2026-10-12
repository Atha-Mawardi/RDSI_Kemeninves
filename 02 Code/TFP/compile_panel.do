* compile_panel.do — satu DTA panel 34×2017–2024 dari konstruksi + determinan + eval1 + eval2
* Atha Bintang Wahyu M. | PSE UGM
*
* Indeks (logtfp, pilar_*, idx_*) ada di semua provinsi-tahun.
* xb / residual FGLS grup dihitung ulang di sini supaya ikut spesifikasi terakhir.
*
* Syarat: eval1.do (eval_panel.dta). Determinan + eval2 dipakai kalau filenya ada.
* Jalankan dari root:  do "02 Code/TFP/compile_panel.do"

version 17
set more off

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

global konstruksi "${proj}/01 Data/TFP/output/konstruksi/TFP Provinsi 2017-2024.dta"
global determinan "${proj}/01 Data/TFP/output/determinan/Determinan TFP Provinsi 2017-2024.dta"
global evalpanel  "${proj}/01 Data/TFP/output/eval/eval_panel.dta"
global evalW      "${proj}/01 Data/TFP/output/eval/eval_panel_W.dta"
global between    "${proj}/01 Data/TFP/output/eval/eval2_between.csv"
global outdta     "${proj}/01 Data/TFP/processed/Panel TFP Provinsi 2017-2024.dta"

if !fileexists("${evalpanel}") {
	display as error "eval_panel.dta missing — run eval1.do first"
	exit 601
}

use "${evalpanel}", clear
xtset Code_Prov Year
isid Code_Prov Year

* CRS per pekerja (konstruksi); di-gen ulang biar ada meski konstruksi.keep lama
capture drop log_y_l log_k_l
gen double log_y_l = log_Y - log_L
gen double log_k_l = log_K - log_L
label variable log_y_l "ln (Y/L)"
label variable log_k_l "ln (K/L)"

* upah primer/sekunder/tersier dari Determinan (nama sektor, bukan kode A/B/C)
if fileexists("${determinan}") {
	preserve
	use "${determinan}", clear
	keep Code_Prov Year ///
		ln_upah_pertanian ln_upah_pertambangan ///
		ln_upah_industri ln_upah_listrik ln_upah_air ln_upah_konstruksi ///
		ln_upah_perdagangan ln_upah_transportasi ln_upah_akomodasi ///
		ln_upah_informasi ln_upah_keuangan ln_upah_real_estat ///
		ln_upah_jasa_perusahaan ln_upah_pemerintah ln_upah_pendidikan ///
		ln_upah_kesehatan ln_upah_jasa_lainnya ///
		ln_upah_primer ln_upah_sekunder ln_upah_tersier ///
		z_ln_upah_primer z_ln_upah_sekunder z_ln_upah_tersier
	tempfile det
	save `det'
	restore
	merge 1:1 Code_Prov Year using `det', nogen keep(master match)
}

* lag spasial queen / pulau
if fileexists("${evalW}") {
	preserve
	use "${evalW}", clear
	unab wvars : Wq_* Wi_*
	keep Code_Prov Year `wvars'
	tempfile ww
	save `ww'
	restore
	merge 1:1 Code_Prov Year using `ww', nogen keep(master match)
}

* kantong / LISA: satu nilai per provinsi, di-copy ke semua tahun
if fileexists("${between}") {
	preserve
	import delimited "${between}", varnames(1) case(preserve) clear
	capture confirm variable Code_Prov
	if _rc rename code_prov Code_Prov
	keep Code_Prov kantong_lemah kantong_kuat n_bot5 n_top5 ///
		lisa_idx_solow lisa_idx_fiskal lisa_logtfp_it_crs ///
		lisa_indeks_hijau lisa_pilar_equity lisa_pilar_pendidikan lisa_rasio_pad
	duplicates drop Code_Prov, force
	tempfile kt
	save `kt'
	restore
	merge m:1 Code_Prov using `kt', nogen keep(master match)
	label variable kantong_lemah "kantong lemah (bot5≥2 atau LISA LL solow+CRS)"
	label variable kantong_kuat  "kantong kuat (top5≥2 atau LISA HH solow)"
}

* ---------------------- FGLS grup: xb + residual (spesifikasi Determinan) ------
* dihitung ulang di panel gabungan supaya tes lanjutan pakai angka yang sama

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

foreach g in pendidikan equity institusi konektivitas lingkungan keamanan {
	capture drop xb_fgls_`g' e_fgls_`g'
	quietly xtgls logtfp_it $`g', panels(heteroskedastic) igls nolog
	predict double xb_fgls_`g', xb
	gen double e_fgls_`g' = logtfp_it - xb_fgls_`g'
	label variable xb_fgls_`g' "xb FGLS grup `g' (logtfp_it)"
	label variable e_fgls_`g'  "residual FGLS grup `g' (logtfp_it)"
}

capture confirm variable z_ln_upah_primer
if !_rc {
	capture drop xb_fgls_upah_kelompok e_fgls_upah_kelompok
	quietly xtgls logtfp_it z_ln_upah_primer z_ln_upah_sekunder z_ln_upah_tersier, ///
		panels(heteroskedastic) igls nolog
	predict double xb_fgls_upah_kelompok, xb
	gen double e_fgls_upah_kelompok = logtfp_it - xb_fgls_upah_kelompok
	label variable xb_fgls_upah_kelompok "xb FGLS upah primer/sekunder/tersier"
	label variable e_fgls_upah_kelompok  "residual FGLS upah primer/sekunder/tersier"
}

quietly count if missing(logtfp_it) | missing(idx_solow) | missing(pilar_pendidikan)
if r(N) > 0 display as error "warning: missing indeks pada " r(N) " baris"

isid Code_Prov Year
xtset Code_Prov Year
order Code_Prov Pre_Prov Pulau Year ///
	logtfp_it logtfp_it_crs z_logtfp z_logtfp_crs ///
	pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas pilar_lingkungan pilar_keamanan ///
	idx_solow idx_hard idx_fiskal ///
	log_Y log_K log_L log_y_l log_k_l
compress
save "${outdta}", replace

quietly describe
display as text _n "panel gabungan -> ${outdta}"
display as text "N = " _N "  vars = " r(k) "  provinsi × tahun = 34 × 2017–2024"
