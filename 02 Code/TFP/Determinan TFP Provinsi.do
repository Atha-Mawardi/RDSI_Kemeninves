* Determinan residual TFP provinsi (tanpa PCA)
* Atha Bintang Wahyu M. | PSE UGM
*
* Catatan Pak Gigih:
* Regresi memakai variabel penyusun, lalu koefisien distandardisasi (z) dan
* dikelompokkan per pilar.
* FE, RE, RE2W, FGLS. FE2W = within + dummy tahun.
*
* Y  : logtfp_it (DRS); robustness logtfp_it_crs
* X  : z-score penyusun pilar, 2017-2024
*     SDM         Educ_Prov, ln Campus_Prov, IPM_Prov_Nm, -Gini_Prov
*     Institusi   -PDBDeflator, rasio_pad, serapan_belanja, -ln Crime2, IDI_Prov2
*     Konektivitas jalan_mantap, ln Airpot_Total, ln Cargo_Total
*     Industri    ln Upah_Agr_Prov
*     kontrol     IKLH_Prov (bukan Hijau sebagai kebijakan)
*

version 17
clear all
set more off
capture log close

global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"

global tfp    "${proj}/01 Data/TFP/output/konstruksi/TFP Provinsi 2017-2024.dta"
global xlsx   "${proj}/01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
global outdir "${proj}/01 Data/TFP/output/determinan"
capture mkdir "${outdir}"

log using "${outdir}/Determinan TFP Provinsi.log", replace text

use "${tfp}", clear
keep Code_Prov Pre_Prov Year logtfp_it logtfp_it_crs z_logtfp z_logtfp_crs
tempfile tfp
save `tfp'

import excel "${xlsx}", sheet("Analisis Luaran 2") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)
capture drop logtfp_it logtfp_it_crs log_lab_tot g_Y g_K g_L kontrib_modal kontrib_tk kontrib_tfp
merge 1:1 Code_Prov Year using `tfp', keep(match) nogen
isid Code_Prov Year
xtset Code_Prov Year

* ------------------------ Semua Variabel dipake --------------------

// Konektivitas
rename RoadC_Prov_National  jalan_mantap_pc
rename Road_Prov_National  	jalan_mantap
rename Road_Prov			jalan_total
rename Cargo_Udara_Prov		kargo_udara		
rename Cargo_Kapal_Prov		kargo_kapal		
rename Cargo_KA_Prov		kargo_kereta
rename PAX_Kapal			jml_penumpang_kapal
rename PAX_KA				jml_penumpang_kereta
rename PAX_Bus				jml_penumpang_bis
rename PAX_Udara			jml_penumpang_udara
rename Airpot_Logis         jml_airport_logistik
rename Airpot_Commer		jml_airport_komersil

// Pendidikan
rename Educ_Prov            lama_sekolah_mean
rename Heduc_Prov			lama_sekolah_harapan
rename APK_Primer 			partisipasi_sd
rename APK_Sekunder1		partisipasi_smp
rename APK_Sekunder2		partisipasi_sma
rename APK_Tersier          partisipasi_kampus

// Equity
rename IPM_Prov_Nm          ipm
rename P0_Prov				p0
rename Ikk_Prov 			p1
rename Ikkk_Porv			p2
rename Gk_Prov				garis_kemiskinan				
rename AHH_Prov				harapan_hidup
rename Gini_Prov            gini
rename Upah_Agr_Prov        upah_rata
rename A_RataUpah    		upah_pertanian
rename B_RataUpah    		upah_pertambangan
rename C_RataUpah    		upah_industri
rename D_RataUpah    		upah_listrik
rename E_RataUpah    		upah_air
rename F_RataUpah    		upah_konstruksi
rename G_RataUpah    		upah_perdagangan
rename H_RataUpah    		upah_transportasi
rename I_RataUpah    		upah_akomodasi
rename J_RataUpah   		upah_informasi
rename K_RataUpah    		upah_keuangan
rename L_RataUpah    		upah_real_estat
rename MN_RataUpah   		upah_jasa_perusahaan
rename O_RataUpah    		upah_pemerintah
rename P_RataUpah    		upah_pendidikan
rename Q_RataUpah    		upah_kesehatan
rename RSTU_RataUpah 		upah_jasa_lainnya

// Institusi
rename PDBDeflator          deflator
rename RasioPAD_Prov        rasio_pad
rename Grwth1_Prov 			pertumbuhan_pdrb_adhb
rename Grwth2_Prov 			pertumbuhan_pdrb_adhk
rename Pendapatan_APBD_Prov	apbd_pendapatan
rename Belanja_APBD_Prov  	apbd_belanja
rename Serapan_Prov         apbd_serapan
rename IDI_Prov2            indeks_demokrasi

// Environment
rename IKLH_Prov            indeks_lingkungan
rename Hijau_Prov			indeks_hijau
rename Biru_Prov			indeks_biru

// Keamanan
rename Crime2_Prov          crime_case
rename CrimeRisk_BPS		crime_risk
rename CR_Prov				crime_rate


* Transform for all

// Konektivitas
gen double ln_jalan_mantap_pc       = ln(jalan_mantap_pc + 1)
gen double ln_jalan_mantap          = ln(jalan_mantap + 1)
gen double ln_jalan_total           = ln(jalan_total + 1)

gen double ln_kargo_udara           = ln(kargo_udara + 1)
gen double ln_kargo_kapal           = ln(kargo_kapal + 1)
gen double ln_kargo_kereta          = ln(kargo_kereta + 1)

gen double ln_penumpang_kapal       = ln(jml_penumpang_kapal + 1)
gen double ln_penumpang_kereta      = ln(jml_penumpang_kereta + 1)
gen double ln_penumpang_bis         = ln(jml_penumpang_bis + 1)
gen double ln_penumpang_udara       = ln(jml_penumpang_udara + 1)
gen double ln_penumpang_total 		= ln(jml_penumpang_kapal+jml_penumpang_bis+jml_penumpang_kereta+jml_penumpang_udara)

gen double ln_airport_logistik      = ln(jml_airport_logistik + 1)
gen double ln_airport_komersil      = ln(jml_airport_komersil + 1)


// Pendidikan
gen double ln_lama_sekolah_mean     = ln(lama_sekolah_mean + 1)
gen double ln_lama_sekolah_harapan  = ln(lama_sekolah_harapan + 1)
foreach v in sd smp sma kampus {
	gen double db_`v' = partisipasi_`v' *(-1) 
}

foreach v in sd smp sma kampus {
	gen double p_`v' = partisipasi_`v' / 100
	
	// Hindari logit tidak terdefinisi pada APS = 0 atau APS = 100
	replace p_`v' = 0.0001 if p_`v' <= 0 & !missing(p_`v')
	replace p_`v' = 0.9999 if p_`v' >= 1 & !missing(p_`v')
	
	gen double logit_partisipasi_`v' = ///
		ln(p_`v' / (1 - p_`v'))
}


// Equity
gen double ln_ipm                    = ln(ipm + 1)
gen double ln_p0                     = ln(p0 + 1)
gen double ln_p1                     = -ln(p1 + 1)
gen double ln_p2                     = -ln(p2 + 1)
gen double ln_garis_kemiskinan       = ln(garis_kemiskinan + 1)
gen double ln_harapan_hidup          = ln(harapan_hidup + 1)

gen double equality                  = -gini

gen double ln_upah_rata             = ln(upah_rata + 1)
gen double ln_upah_pertanian         = ln(upah_pertanian + 1)
gen double ln_upah_pertambangan      = ln(upah_pertambangan + 1)
gen double ln_upah_industri          = ln(upah_industri + 1)
gen double ln_upah_listrik           = ln(upah_listrik + 1)
gen double ln_upah_air               = ln(upah_air + 1)
gen double ln_upah_konstruksi        = ln(upah_konstruksi + 1)
gen double ln_upah_perdagangan       = ln(upah_perdagangan + 1)
gen double ln_upah_transportasi      = ln(upah_transportasi + 1)
gen double ln_upah_akomodasi         = ln(upah_akomodasi + 1)
gen double ln_upah_informasi         = ln(upah_informasi + 1)
gen double ln_upah_keuangan          = ln(upah_keuangan + 1)
gen double ln_upah_real_estat        = ln(upah_real_estat + 1)
gen double ln_upah_jasa_perusahaan   = ln(upah_jasa_perusahaan + 1)
gen double ln_upah_pemerintah        = ln(upah_pemerintah + 1)
gen double ln_upah_pendidikan        = ln(upah_pendidikan + 1)
gen double ln_upah_kesehatan         = ln(upah_kesehatan + 1)
gen double ln_upah_jasa_lainnya      = ln(upah_jasa_lainnya + 1)


// Institusi
gen double ln_deflator               = ln(deflator + 1)
gen double price                     = -ln(deflator + 1)

gen double ln_rasio_pad              = ln(rasio_pad + 1)

gen double ln_pertumbuhan_pdrb_adhb  = ///
	sign(pertumbuhan_pdrb_adhb) * ln(abs(pertumbuhan_pdrb_adhb) + 1)

gen double ln_pertumbuhan_pdrb_adhk  = ///
	sign(pertumbuhan_pdrb_adhk) * ln(abs(pertumbuhan_pdrb_adhk) + 1)

gen double ln_apbd_pendapatan        = ln(apbd_pendapatan + 1)
gen double ln_apbd_belanja           = ln(apbd_belanja + 1)
gen double ln_apbd_serapan           = ln(apbd_serapan + 1)
gen double ln_indeks_demokrasi       = ln(indeks_demokrasi + 1)


// Environment
gen double ln_indeks_lingkungan      = ln(indeks_lingkungan + 1)
gen double ln_indeks_hijau           = ln(indeks_hijau + 1)
gen double ln_indeks_biru            = ln(indeks_biru + 1)


// Keamanan
gen double ln_crime_case             = ln(crime_case + 1)
gen double ln_crime_risk             = - ln(crime_risk + 1)
gen double ln_crime_rate             = - ln(crime_rate + 1)


// * ---------------------- LEGACY ------------------------------
// * z-score pada sampel regresi; beta = efek +1 SD
// foreach v in lama_sekolah_mean partisipasi_kampus ipm equality ///
// 	price rasio_pad apbd_serapan ln_crime_rate ln_idi ///
// 	jalan_mantap ln_airport_log ln_airport_kom ///
// 	ln_kargo_udara ln_kargo_kapal ln_kargo_kereta ///
// 	ln_wage_total indeks_lingkungan {
// 	egen double z_`v' = std(`v')
// }
//
// global hr    z_lama_sekolah_mean z_partisipasi_kampus z_ipm z_equality
// global inst  z_price z_rasio_pad z_apbd_serapan z_ln_crime_rate z_ln_idi
// global conn  z_jalan_mantap z_ln_airport_log z_ln_airport_kom ///
//              z_ln_kargo_udara z_ln_kargo_kapal z_ln_kargo_kereta
// global ind   z_ln_wage_total
// global env   z_indeks_lingkungan
// global X     $hr $inst $conn $ind $env
//
// egen byte _miss = rowmiss(logtfp_it $X)
// drop if _miss
// drop _miss
//
// quietly count
// display as text "N = " r(N)
//
// xtdescribe
// summarize logtfp_it logtfp_it_crs $X, separator(0)
// correlate $X
//
// *** Model (cluster provinsi). FGLS tanpa dummy tahun: dengan tahun tidak konvergen.
// regress logtfp_it $X, vce(cluster Code_Prov)
// estimates store POLS
//
// xtreg logtfp_it $X, fe vce(cluster Code_Prov)
// estimates store FE
//
// xtreg logtfp_it $X i.Year, fe vce(cluster Code_Prov)
// estimates store FE2W
//
// xtreg logtfp_it $X, re vce(cluster Code_Prov)
// estimates store RE
//
// xtreg logtfp_it $X i.Year, re vce(cluster Code_Prov)
// estimates store RE2W
//
// xtgls logtfp_it $X, panels(heteroskedastic) igls nolog
// estimates store FGLS
//
// xtreg logtfp_it_crs $X i.Year, fe vce(cluster Code_Prov)
// estimates store FE2W_crs
//
// estimates table POLS FE FE2W RE RE2W FGLS FE2W_crs, ///
// 	keep($X) star stats(N) b(%7.3f)
//
// quietly xtreg logtfp_it $X, fe
// estimates store FE_h
//
// quietly xtreg logtfp_it $X, re
// estimates store RE_h
//
// capture noisily hausman FE_h RE_h, sigmamore
//
// *** Indeks koefisien per pilar (jumlah beta z pada FGLS)
// quietly estimates restore FGLS
// display as text _n "FGLS jumlah koefisien z per pilar (indeks pasca-estimasi)"
//
// lincom z_lama_sekolah_mean + z_partisipasi_kampus + ///
// 	z_ipm + z_equality
//
// lincom z_price + z_rasio_pad + z_apbd_serapan + ///
// 	z_ln_crime_rate + z_ln_idi
//
// lincom z_jalan_mantap + z_ln_airport_log + z_ln_airport_kom + ///
// 	z_ln_kargo_udara + z_ln_kargo_kapal + z_ln_kargo_kereta
//
// lincom z_ln_wage_total
//
// keep Code_Prov Year logtfp_it logtfp_it_crs $X
//
// save "${outdir}/Determinan TFP Provinsi 2017-2024.dta", replace
//
// export excel using "${outdir}/Determinan TFP Provinsi 2017-2024.xlsx", ///
// 	sheet("sample") firstrow(variables) replace
//
// display as text "saved: $outdir"
// log close


* ---------------------- FULL SPECIFICATION ------------------------------

foreach v in ///
	ln_lama_sekolah_mean ln_lama_sekolah_harapan ///
	logit_partisipasi_sd logit_partisipasi_smp ///
	logit_partisipasi_sma logit_partisipasi_kampus ///
	db_sd db_smp db_sma db_kampus ///
	ln_ipm ln_p0 ln_p1 ln_p2 gini ///
	ln_garis_kemiskinan ln_harapan_hidup equality ///
	ln_upah_rata ln_upah_pertanian ln_upah_pertambangan ///
	ln_upah_industri ln_upah_listrik ln_upah_air ///
	ln_upah_konstruksi ln_upah_perdagangan ///
	ln_upah_transportasi ln_upah_akomodasi ///
	ln_upah_informasi ln_upah_keuangan ///
	ln_upah_real_estat ln_upah_jasa_perusahaan ///
	ln_upah_pemerintah ln_upah_pendidikan ///
	ln_upah_kesehatan ln_upah_jasa_lainnya ///
	price ln_rasio_pad ///
	ln_pertumbuhan_pdrb_adhb /// *adhb/adhk
	ln_apbd_pendapatan ln_apbd_belanja ///
	ln_apbd_serapan ln_indeks_demokrasi ///
	ln_jalan_mantap_pc ln_jalan_mantap ln_jalan_total ///
	ln_kargo_udara ln_kargo_kapal ln_kargo_kereta ///
	ln_penumpang_kapal ln_penumpang_kereta ///
	ln_penumpang_bis ln_penumpang_udara ln_penumpang_total ///
	ln_airport_logistik ln_airport_komersil ///
	ln_indeks_lingkungan ln_indeks_hijau ln_indeks_biru ///
	ln_crime_case ln_crime_risk ln_crime_rate {

	egen double z_`v' = std(`v')
}

global pendidikan ///
	z_ln_lama_sekolah_mean ///
	z_ln_lama_sekolah_harapan ///
	z_db_sd z_db_smp z_db_sma z_db_kampus
// 	z_logit_partisipasi_sd ///
// 	z_logit_partisipasi_smp ///
// 	z_logit_partisipasi_sma ///
// 	z_logit_partisipasi_kampus

global equity ///
	z_ln_p1 ///
	z_ln_ipm ///
	z_gini ///
	z_ln_upah_rata ///
	z_ln_indeks_demokrasi
// 	z_equality ///
// 	z_ln_p0 ///
// 	z_ln_p2 ///
// 	z_ln_garis_kemiskinan ///
// 	z_ln_harapan_hidup ///
// 	z_equality ///
// 	z_ln_upah_pertanian ///
// 	z_ln_upah_pertambangan ///
// 	z_ln_upah_industri ///
// 	z_ln_upah_listrik ///
// 	z_ln_upah_air ///
// 	z_ln_upah_konstruksi ///
// 	z_ln_upah_perdagangan ///
// 	z_ln_upah_transportasi ///
// 	z_ln_upah_akomodasi ///
// 	z_ln_upah_informasi ///
// 	z_ln_upah_keuangan ///
// 	z_ln_upah_real_estat ///
// 	z_ln_upah_jasa_perusahaan ///
// 	z_ln_upah_pemerintah ///
// 	z_ln_upah_pendidikan ///
// 	z_ln_upah_kesehatan ///
// 	z_ln_upah_jasa_lainnya


global institusi ///
	z_price ///
	z_ln_rasio_pad ///
	z_ln_pertumbuhan_pdrb_adhb ///
	z_ln_apbd_belanja 
// 	z_ln_apbd_serapan ///
// 	z_ln_pertumbuhan_pdrb_adhk ///
// 	z_ln_apbd_pendapatan

global konektivitas ///
	z_ln_jalan_mantap ///
	z_ln_kargo_udara ///
	z_ln_kargo_kapal ///
	z_ln_kargo_kereta ///
	z_ln_penumpang_total ///
	z_ln_airport_logistik ///
	z_ln_airport_komersil 
// 	z_ln_penumpang_kapal ///
// 	z_ln_penumpang_kereta ///
// 	z_ln_penumpang_bis ///
// 	z_ln_penumpang_udara ///
// 	z_ln_jalan_mantap_pc ///
// 	z_ln_jalan_total ///
*Jalan total included = .018*** (lower than jln mantap)

global lingkungan ///
	z_ln_indeks_lingkungan ///
	z_ln_indeks_hijau ///
	z_ln_indeks_biru

global keamanan ///
	z_ln_crime_risk ///
	z_ln_crime_rate ///
// 	z_ln_crime_case 

global X ///
	$pendidikan ///
	$equity ///
	$institusi ///
	$konektivitas ///
	$lingkungan ///
	$keamanan

quietly count
display as text "N = " r(N)

xtdescribe
summarize logtfp_it logtfp_it_crs $X, separator(0)
correlate $X

* ---------------------- FULL MODELS ------------------------------

regress logtfp_it $X, vce(cluster Code_Prov)
estimates store POLS

xtreg logtfp_it $X, fe vce(cluster Code_Prov)
estimates store FE

xtreg logtfp_it $X i.Year, fe vce(cluster Code_Prov)
estimates store FE2W

xtreg logtfp_it $X, re vce(cluster Code_Prov)
estimates store RE

xtgls logtfp_it $X, panels(heteroskedastic) igls nolog
estimates store FGLS

xtreg logtfp_it_crs $X i.Year, fe vce(cluster Code_Prov)
estimates store FE2W_crs

xtgls logtfp_it_crs $X, panels(heteroskedastic) igls nolog
estimates store FGLS_crs

estimates table POLS FE FE2W RE FGLS FE2W_crs FGLS_crs, ///
	keep($X) star stats(N) b(%7.3f)

* ---------------------- FGLS PER GROUP ------------------------------

xtgls logtfp_it $pendidikan, panels(heteroskedastic) igls nolog
estimates store FGLS_pendidikan

xtgls logtfp_it $equity, panels(heteroskedastic) igls nolog
estimates store FGLS_equity

xtgls logtfp_it $institusi, panels(heteroskedastic) igls nolog
estimates store FGLS_institusi

xtgls logtfp_it $konektivitas, panels(heteroskedastic) igls nolog
estimates store FGLS_konektivitas

xtgls logtfp_it $lingkungan, panels(heteroskedastic) igls nolog
estimates store FGLS_lingkungan

xtgls logtfp_it $keamanan, panels(heteroskedastic) igls nolog
estimates store FGLS_keamanan

estimates table ///
	FGLS_pendidikan ///
	FGLS_equity ///
	FGLS_institusi ///
	FGLS_konektivitas ///
	FGLS_lingkungan ///
	FGLS_keamanan, ///
	star stats(N) b(%7.3f)

* ---------------------- HAUSMAN TEST ------------------------------

quietly xtreg logtfp_it $X, fe
estimates store FE_h

quietly xtreg logtfp_it $X, re
estimates store RE_h

capture noisily hausman FE_h RE_h, sigmamore

* Test for total effect: choosing the significant ones only
lincom z_ln_lama_sekolah_mean + z_ln_lama_sekolah_harapan + ///
	z_db_sd + z_db_sma + z_db_kampus
lincom z_ln_p1 + z_gini + z_ln_upah_rata + ///
	z_ln_indeks_demokrasi
lincom z_ln_rasio_pad + z_ln_pertumbuhan_pdrb_adhb + ///
	z_ln_apbd_belanja
lincom z_ln_jalan_mantap + z_ln_kargo_udara + ///
	z_ln_kargo_kapal + z_ln_kargo_kereta + ///
	z_ln_penumpang_total + z_ln_airport_logistik + ///
	z_ln_airport_komersil
lincom z_ln_indeks_lingkungan + z_ln_indeks_hijau 
lincom z_ln_crime_risk + z_ln_crime_rate

* Test using margins & nlcom
estimates restore FGLS_pendidikan
margins, dydx($pendidikan) predict(xb) post
nlcom (pendidikan: ///
	_b[z_ln_lama_sekolah_mean] + ///
	_b[z_ln_lama_sekolah_harapan] + ///
	_b[z_db_sd] + ///
	_b[z_db_smp] + ///
	_b[z_db_sma] + ///
	_b[z_db_kampus])

estimates restore FGLS_equity
margins, dydx($equity) predict(xb) post
nlcom (equity: ///
	_b[z_ln_p1] + ///
	_b[z_ln_ipm] + ///
	_b[z_gini] + ///
	_b[z_ln_upah_rata] + ///
	_b[z_ln_indeks_demokrasi])

estimates restore FGLS_institusi
margins, dydx($institusi) predict(xb) post
nlcom (institusi: ///
	_b[z_price] + ///
	_b[z_ln_rasio_pad] + ///
	_b[z_ln_pertumbuhan_pdrb_adhb] + ///
	_b[z_ln_apbd_belanja])

estimates restore FGLS_konektivitas
margins, dydx($konektivitas) predict(xb) post
nlcom (konektivitas: ///
	_b[z_ln_jalan_mantap] + ///
	_b[z_ln_kargo_udara] + ///
	_b[z_ln_kargo_kapal] + ///
	_b[z_ln_kargo_kereta] + ///
	_b[z_ln_penumpang_total] + ///
	_b[z_ln_airport_logistik] + ///
	_b[z_ln_airport_komersil])

estimates restore FGLS_lingkungan
margins, dydx($lingkungan) predict(xb) post
nlcom (lingkungan: ///
	_b[z_ln_indeks_lingkungan] + ///
	_b[z_ln_indeks_hijau] + ///
	_b[z_ln_indeks_biru])

estimates restore FGLS_keamanan
margins, dydx($keamanan) predict(xb) post
nlcom (keamanan: ///
	_b[z_ln_crime_risk] + ///
	_b[z_ln_crime_rate])
	

* ---------------------- PRIMER, SEKUNDER, TERSIER ----------------------
* Rerata log upah per kelompok sektor, bukan sectoral share

egen double ln_upah_primer = rowmean( ///
	ln_upah_pertanian ///
	ln_upah_pertambangan)

egen double ln_upah_sekunder = rowmean( ///
	ln_upah_industri ///
	ln_upah_listrik ///
	ln_upah_air ///
	ln_upah_konstruksi)

egen double ln_upah_tersier = rowmean( ///
	ln_upah_perdagangan ///
	ln_upah_transportasi ///
	ln_upah_akomodasi ///
	ln_upah_informasi ///
	ln_upah_keuangan ///
	ln_upah_real_estat ///
	ln_upah_jasa_perusahaan ///
	ln_upah_pemerintah ///
	ln_upah_pendidikan ///
	ln_upah_kesehatan ///
	ln_upah_jasa_lainnya)

egen double z_ln_upah_primer   = std(ln_upah_primer)
egen double z_ln_upah_sekunder = std(ln_upah_sekunder)
egen double z_ln_upah_tersier  = std(ln_upah_tersier)

label variable ln_upah_primer   "Rerata log upah sektor primer"
label variable ln_upah_sekunder "Rerata log upah sektor sekunder"
label variable ln_upah_tersier  "Rerata log upah sektor tersier"

* ---------------------- DESKRIPTIF ----------------------

summarize ln_upah_primer ln_upah_sekunder ln_upah_tersier

tabstat ln_upah_primer ln_upah_sekunder ln_upah_tersier, ///
	by(Year) statistics(mean sd min max) columns(statistics)

pwcorr ln_upah_primer ln_upah_sekunder ln_upah_tersier logtfp_it, ///
	sig star(.05)

* ---------------------- FGLS TERPISAH ----------------------

xtgls logtfp_it z_ln_upah_primer i.Code_Prov i.Year, ///
	panels(heteroskedastic) nolog
estimates store FGLS_primer

xtgls logtfp_it z_ln_upah_sekunder i.Code_Prov i.Year, ///
	panels(heteroskedastic) nolog
estimates store FGLS_sekunder

xtgls logtfp_it z_ln_upah_tersier i.Code_Prov i.Year, ///
	panels(heteroskedastic) nolog
estimates store FGLS_tersier

* ---------------------- FGLS BERSAMA ----------------------

xtgls logtfp_it ///
	z_ln_upah_primer ///
	z_ln_upah_sekunder ///
	z_ln_upah_tersier ///
	i.Code_Prov i.Year, ///
	panels(heteroskedastic) nolog

estimates store FGLS_kelompok_sektor

margins, dydx( ///
	z_ln_upah_primer ///
	z_ln_upah_sekunder ///
	z_ln_upah_tersier)

* Uji kesamaan koefisien
test z_ln_upah_primer = z_ln_upah_sekunder
test z_ln_upah_primer = z_ln_upah_tersier
test z_ln_upah_sekunder = z_ln_upah_tersier

* Uji signifikansi bersama
test z_ln_upah_primer ///
	z_ln_upah_sekunder ///
	z_ln_upah_tersier

estimates table ///
	FGLS_primer ///
	FGLS_sekunder ///
	FGLS_tersier ///
	FGLS_kelompok_sektor, ///
	keep(z_ln_upah_primer z_ln_upah_sekunder z_ln_upah_tersier) ///
	star stats(N) b(%9.3f)

* ---------------------- POST-HOC ANTARKELOMPOK ----------------------

preserve

keep Code_Prov Year ///
	ln_upah_pertanian ln_upah_pertambangan ///
	ln_upah_industri ln_upah_listrik ln_upah_air ln_upah_konstruksi ///
	ln_upah_perdagangan ln_upah_transportasi ln_upah_akomodasi ///
	ln_upah_informasi ln_upah_keuangan ln_upah_real_estat ///
	ln_upah_jasa_perusahaan ln_upah_pemerintah ln_upah_pendidikan ///
	ln_upah_kesehatan ln_upah_jasa_lainnya

reshape long ln_upah_, i(Code_Prov Year) j(sektor) string
rename ln_upah_ ln_upah

gen byte kelompok = 3

replace kelompok = 1 if inlist(sektor, ///
	"pertanian", "pertambangan")

replace kelompok = 2 if inlist(sektor, ///
	"industri", "listrik", "air", "konstruksi")

label define kelompok_lab ///
	1 "Primer" ///
	2 "Sekunder" ///
	3 "Tersier", replace

label values kelompok kelompok_lab

tabstat ln_upah, by(kelompok) ///
	statistics(n mean sd min median max) columns(statistics)

regress ln_upah i.kelompok i.Year, ///
	vce(cluster Code_Prov)

margins kelompok

margins kelompok, ///
	pwcompare(effects) ///
	mcompare(bonferroni)

restore
	
* ---------------------- OUTPUT ------------------------------

keep Code_Prov Year logtfp_it logtfp_it_crs $X ln_upah_pertanian ln_upah_pertambangan ///
	ln_upah_industri ln_upah_listrik ln_upah_air ln_upah_konstruksi ///
	ln_upah_perdagangan ln_upah_transportasi ln_upah_akomodasi ///
	ln_upah_informasi ln_upah_keuangan ln_upah_real_estat ///
	ln_upah_jasa_perusahaan ln_upah_pemerintah ln_upah_pendidikan ///
	ln_upah_kesehatan ln_upah_jasa_lainnya z_ln_upah_primer ln_upah_primer ///
	ln_upah_sekunder z_ln_upah_sekunder ln_upah_tersier z_ln_upah_tersier
capture confirm variable Pre_Prov
if !_rc order Code_Prov Pre_Prov Year, first
	

save "${outdir}/Determinan TFP Provinsi 2017-2024.dta", replace

export excel using ///
	"${outdir}/Determinan TFP Provinsi 2017-2024.xlsx", ///
	sheet("sample") firstrow(variables) replace

display as text "saved: $outdir"
log close
