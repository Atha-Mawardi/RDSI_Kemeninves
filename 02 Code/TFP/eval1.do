* eval1.do — panel + FGLS grup (sama gaya Determinan TFP Provinsi.do)
* Atha Bintang Wahyu M. | PSE UGM
*
* Residual: konstruksi D. FE2W hanya di Konstruksi (b1, b2). Di sini determinan
* dikutip dari xtgls panels(heteroskedastic) igls, per grup penyusun z — bukan
* FE2W, bukan lincom komposit, bukan interaksi pilar × log K.
*
* Empat model naskah 6.1.2: FE, RE, RE2W, FGLS. FE2W full X = dummy tahun.
* FGLS grup 19 Sep: pendidikan 0,630 / equity 0,645 / institusi 0,549 /
* konektivitas 0,485 / keamanan −0,026 / lingkungan −0,167.
*
* Jalankan dari root:  do "02 Code/TFP/eval1.do"

version 17
clear all
set more off
set matsize 2000
capture log close

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

global tfp    "${proj}/01 Data/TFP/output/konstruksi/TFP Provinsi 2017-2024.dta"
global xlsx   "${proj}/01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
if !fileexists("${xlsx}") {
	global xlsx "${proj}/01 Data/TFP/AI-Pak_Yudis/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
}
global peta   "${proj}/01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv"
global outdir "${proj}/01 Data/TFP/output/eval"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "${outdir}"

if !fileexists("${tfp}") {
	display as error "TFP residual not found. Run Konstruksi TFP Provinsi.do first."
	exit 601
}
if !fileexists("${xlsx}") {
	display as error "workbook not found: $xlsx"
	exit 601
}

log using "${outdir}/eval1.log", replace text
display as text "proj = $proj"
display as text "tfp  = $tfp"
display as text "xlsx = $xlsx"

* =============================================================================
* 1. PANEL
* =============================================================================

use "${tfp}", clear
keep Code_Prov Pre_Prov Year pdrb_adhk pmtb_adhk labours_total ///
	log_Y log_K log_L logtfp_it logtfp_it_crs z_logtfp z_logtfp_crs
tempfile tfp
save `tfp'

import excel "${xlsx}", sheet("Analisis Luaran 2") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)
capture drop logtfp_it logtfp_it_crs log_lab_tot g_Y g_K g_L kontrib_modal kontrib_tk kontrib_tfp
merge 1:1 Code_Prov Year using `tfp', keep(match) nogen

preserve
import excel "${xlsx}", sheet("Sheet1") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)
keep Code_Prov Year Exp_Prov Inc_Prov PMA_1 PMDN_1 pmtb ///
	A_PMA B_PMA C_PMA D_PMA E_PMA F_PMA G_PMA H_PMA I_PMA J_PMA K_PMA L_PMA MN_PMA O_PMA P_PMA Q_PMA RSTU_PMA ///
	A_PMDN B_PMDN C_PMDN D_PMDN E_PMDN F_PMDN G_PMDN H_PMDN I_PMDN J_PMDN K_PMDN L_PMDN MN_PMDN O_PMDN P_PMDN Q_PMDN RSTU_PMDN ///
	A_ADHB B_ADHB C_ADHB D_ADHB E_ADHB F_ADHB G_ADHB H_ADHB I_ADHB J_ADHB K_ADHB L_ADHB MN_ADHB O_ADHB P_ADHB Q_ADHB RSTU_ADHB ///
	A_ADHK B_ADHK C_ADHK D_ADHK E_ADHK F_ADHK G_ADHK H_ADHK I_ADHK J_ADHK K_ADHK L_ADHK MN_ADHK O_ADHK P_ADHK Q_ADHK RSTU_ADHK
tempfile s1
save `s1'
restore
merge 1:1 Code_Prov Year using `s1', keep(master match) nogen

preserve
import delimited "${peta}", clear
keep code_prov pulau
rename code_prov Code_Prov
drop if missing(Code_Prov)
duplicates drop Code_Prov, force
replace pulau = strtrim(pulau)
replace pulau = "Bali-Nusra" if inlist(pulau, "Bali-Nusa Tenggara", "Bali-Nusra")
tempfile peta
save `peta'
restore
merge m:1 Code_Prov using `peta', keep(master match) nogen
rename pulau Pulau
replace Pulau = "Sumatera"     if missing(Pulau) & inlist(Code_Prov, 11,12,13,14,15,16,17,18,19,21)
replace Pulau = "Jawa"         if missing(Pulau) & inlist(Code_Prov, 31,32,33,34,35,36)
replace Pulau = "Bali-Nusra"   if missing(Pulau) & inlist(Code_Prov, 51,52,53)
replace Pulau = "Kalimantan"   if missing(Pulau) & inlist(Code_Prov, 61,62,63,64,65)
replace Pulau = "Sulawesi"     if missing(Pulau) & inlist(Code_Prov, 71,72,73,74,75,76)
replace Pulau = "Maluku-Papua" if missing(Pulau) & inlist(Code_Prov, 81,82,91,94)

isid Code_Prov Year
xtset Code_Prov Year

* --- rename penyusun (sama Determinan TFP Provinsi.do) -----------------------
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

rename Educ_Prov            lama_sekolah_mean
rename Heduc_Prov			lama_sekolah_harapan
rename APK_Primer 			partisipasi_sd
rename APK_Sekunder1		partisipasi_smp
rename APK_Sekunder2		partisipasi_sma
rename APK_Tersier          partisipasi_kampus

rename IPM_Prov_Nm          ipm
rename P0_Prov				p0
rename Ikk_Prov 			p1
rename Ikkk_Porv			p2
rename Gk_Prov				garis_kemiskinan
rename AHH_Prov				harapan_hidup
rename Gini_Prov            gini
rename Upah_Agr_Prov        upah_rata
rename A_RataUpah    		upah_A
rename B_RataUpah    		upah_B
rename C_RataUpah    		upah_C
rename D_RataUpah    		upah_D
rename E_RataUpah    		upah_E
rename F_RataUpah    		upah_F
rename G_RataUpah    		upah_G
rename H_RataUpah    		upah_H
rename I_RataUpah    		upah_I
rename J_RataUpah   		upah_J
rename K_RataUpah    		upah_K
rename L_RataUpah    		upah_L
rename MN_RataUpah   		upah_MN
rename O_RataUpah    		upah_O
rename P_RataUpah    		upah_P
rename Q_RataUpah    		upah_Q
rename RSTU_RataUpah 		upah_RSTU

rename PDBDeflator          deflator
rename RasioPAD_Prov        rasio_pad
rename Grwth1_Prov 			pertumbuhan_pdrb_adhb
rename Grwth2_Prov 			pertumbuhan_pdrb_adhk
rename Pendapatan_APBD_Prov	apbd_pendapatan
rename Belanja_APBD_Prov  	apbd_belanja
rename Serapan_Prov         apbd_serapan
rename IDI_Prov2            indeks_demokrasi
rename PAD_Prov             pad
rename TK_Prov              tk_sakernas

rename IKLH_Prov            indeks_lingkungan
rename Hijau_Prov			indeks_hijau
rename Biru_Prov			indeks_biru

rename Crime2_Prov          crime_case
rename CrimeRisk_BPS		crime_risk
rename CR_Prov				crime_rate

rename Exp_Prov             pengeluaran_kapita
rename Inc_Prov             pendapatan_kapita

* --- transform ----------------------------------------------------------------
foreach v in jalan_mantap_pc jalan_mantap jalan_total ///
	kargo_udara kargo_kapal kargo_kereta ///
	jml_penumpang_kapal jml_penumpang_kereta jml_penumpang_bis jml_penumpang_udara ///
	jml_airport_logistik jml_airport_komersil ///
	lama_sekolah_mean lama_sekolah_harapan ///
	ipm p0 garis_kemiskinan harapan_hidup upah_rata ///
	rasio_pad apbd_pendapatan apbd_belanja apbd_serapan indeks_demokrasi pad ///
	indeks_lingkungan indeks_hijau indeks_biru pengeluaran_kapita pendapatan_kapita {
	capture confirm variable `v'
	if !_rc gen double ln_`v' = ln(`v' + 1)
}

gen double ln_airport_logistik = ln(jml_airport_logistik + 1)
gen double ln_airport_komersil = ln(jml_airport_komersil + 1)
gen double ln_penumpang_total = ln(jml_penumpang_kapal + jml_penumpang_bis + ///
	jml_penumpang_kereta + jml_penumpang_udara + 1)
gen double ln_p1 = -ln(p1 + 1)
gen double ln_p2 = -ln(p2 + 1)
gen double equality = -gini
gen double price = -ln(deflator + 1)
gen double ln_crime_case = ln(crime_case + 1)
gen double ln_crime_risk = -ln(crime_risk + 1)
gen double ln_crime_rate = -ln(crime_rate + 1)
gen double ln_pertumbuhan_pdrb_adhb = sign(pertumbuhan_pdrb_adhb) * ln(abs(pertumbuhan_pdrb_adhb) + 1)

foreach v in sd smp sma kampus {
	gen double p_`v' = partisipasi_`v' / 100
	replace p_`v' = 0.0001 if p_`v' <= 0 & !missing(p_`v')
	replace p_`v' = 0.9999 if p_`v' >= 1 & !missing(p_`v')
	gen double logit_partisipasi_`v' = ln(p_`v' / (1 - p_`v'))
	gen double db_`v' = partisipasi_`v' * (-1)
}

foreach v in ln_lama_sekolah_mean ln_lama_sekolah_harapan ///
	logit_partisipasi_sd logit_partisipasi_smp logit_partisipasi_sma logit_partisipasi_kampus ///
	db_sd db_smp db_sma db_kampus ///
	ln_ipm ln_p0 ln_p1 ln_p2 gini equality ln_garis_kemiskinan ln_harapan_hidup ln_upah_rata ///
	price ln_rasio_pad ln_pertumbuhan_pdrb_adhb ln_apbd_pendapatan ln_apbd_belanja ln_apbd_serapan ///
	ln_indeks_demokrasi ln_pad ///
	ln_jalan_mantap ln_kargo_udara ln_kargo_kapal ln_kargo_kereta ln_penumpang_total ///
	ln_airport_logistik ln_airport_komersil ///
	ln_indeks_lingkungan ln_indeks_hijau ln_indeks_biru ///
	ln_crime_case ln_crime_risk ln_crime_rate ///
	ln_pengeluaran_kapita ln_pendapatan_kapita log_Y log_K log_L logtfp_it logtfp_it_crs {
	capture egen double z_`v' = std(`v')
}

* --- 6 pilar: untuk peta/profil saja. Angka yang dikutip = FGLS grup db_* ---
egen double raw_pendidikan = rowmean(z_ln_lama_sekolah_mean z_ln_lama_sekolah_harapan ///
	z_logit_partisipasi_sma z_logit_partisipasi_kampus)
egen double raw_equity = rowmean(z_ln_ipm z_ln_p1 z_equality z_ln_upah_rata z_ln_indeks_demokrasi)
egen double raw_institusi = rowmean(z_price z_ln_rasio_pad z_ln_apbd_belanja z_ln_apbd_serapan)
egen double raw_konektivitas = rowmean(z_ln_jalan_mantap z_ln_kargo_kapal z_ln_kargo_kereta ///
	z_ln_penumpang_total z_ln_airport_logistik)
egen double raw_lingkungan = rowmean(z_ln_indeks_lingkungan z_ln_indeks_hijau z_ln_indeks_biru)
egen double raw_keamanan = rowmean(z_ln_crime_risk z_ln_crime_rate)

foreach p in pendidikan equity institusi konektivitas lingkungan keamanan {
	egen double pilar_`p' = std(raw_`p')
}
egen double raw_solow = rowmean(pilar_pendidikan pilar_equity pilar_institusi)
egen double raw_hard  = rowmean(pilar_konektivitas pilar_keamanan)
egen double idx_solow = std(raw_solow)
egen double idx_hard  = std(raw_hard)
label variable pilar_pendidikan  "pilar pendidikan (z rata penyusun, polaritas benar)"
label variable pilar_equity      "pilar equity (IPM, -P1, -gini, upah, IDI)"
label variable pilar_institusi   "pilar institusi (harga, PAD, belanja, serapan)"
label variable pilar_konektivitas "pilar konektivitas"
label variable pilar_lingkungan  "pilar lingkungan (IKLH + hijau + biru)"
label variable pilar_keamanan    "pilar keamanan (risk & rate dibalik)"
label variable idx_solow         "rata-rata pendidikan, equity, institusi"
label variable idx_hard          "rata-rata konektivitas dan keamanan"

* --- tenaga kerja / upah / investasi / PDRB per sektor -----------------------
local secs A B C D E F G H I J K L MN O P Q RSTU
egen double tk_total = rowtotal(*_TenagaKerja)
foreach s of local secs {
	rename `s'_TenagaKerja tk_`s'
	gen double ln_upah_`s' = ln(upah_`s' + 1)
	gen double wagebill_`s' = upah_`s' * tk_`s'
	gen double inv_`s' = `s'_PMA + `s'_PMDN
	replace inv_`s' = 0 if missing(inv_`s') | inv_`s' < 0
	gen double share_tk_`s'    = tk_`s' / tk_total
	gen double share_pdrb_`s'  = `s'_ADHK / pdrb_adhk
	gen double share_inv_`s'   = .
}

egen double wagebill_total = rowtotal(wagebill_*)
egen double inv_total      = rowtotal(inv_*)
foreach s of local secs {
	replace share_inv_`s' = inv_`s' / inv_total if inv_total > 0
	gen double share_upah_`s' = wagebill_`s' / wagebill_total
}

* megasector: primer A+B ; sekunder C-F ; tersier G-RSTU
* ekstraktif A+B ; industrial C+F ; hijau-invest E (+D listrik, dicatat terpisah)
* padat karya A C F G I P Q ; padat modal B D K J L H
foreach kind in primer sekunder tersier ekstraktif industri hijau_inv padat_karya padat_modal {
	gen double tk_`kind' = 0
	gen double wagebill_`kind' = 0
	gen double inv_`kind' = 0
	gen double pdrb_`kind' = 0
}

foreach s in A B {
	replace tk_primer = tk_primer + tk_`s'
	replace wagebill_primer = wagebill_primer + wagebill_`s'
	replace inv_primer = inv_primer + inv_`s'
	replace pdrb_primer = pdrb_primer + `s'_ADHK
	replace tk_ekstraktif = tk_ekstraktif + tk_`s'
	replace wagebill_ekstraktif = wagebill_ekstraktif + wagebill_`s'
	replace inv_ekstraktif = inv_ekstraktif + inv_`s'
	replace pdrb_ekstraktif = pdrb_ekstraktif + `s'_ADHK
}
foreach s in C D E F {
	replace tk_sekunder = tk_sekunder + tk_`s'
	replace wagebill_sekunder = wagebill_sekunder + wagebill_`s'
	replace inv_sekunder = inv_sekunder + inv_`s'
	replace pdrb_sekunder = pdrb_sekunder + `s'_ADHK
}
foreach s in G H I J K L MN O P Q RSTU {
	replace tk_tersier = tk_tersier + tk_`s'
	replace wagebill_tersier = wagebill_tersier + wagebill_`s'
	replace inv_tersier = inv_tersier + inv_`s'
	replace pdrb_tersier = pdrb_tersier + `s'_ADHK
}
foreach s in C F {
	replace tk_industri = tk_industri + tk_`s'
	replace wagebill_industri = wagebill_industri + wagebill_`s'
	replace inv_industri = inv_industri + inv_`s'
	replace pdrb_industri = pdrb_industri + `s'_ADHK
}
foreach s in E {
	replace tk_hijau_inv = tk_hijau_inv + tk_`s'
	replace wagebill_hijau_inv = wagebill_hijau_inv + wagebill_`s'
	replace inv_hijau_inv = inv_hijau_inv + inv_`s'
	replace pdrb_hijau_inv = pdrb_hijau_inv + `s'_ADHK
}
foreach s in A C F G I P Q {
	replace tk_padat_karya = tk_padat_karya + tk_`s'
	replace wagebill_padat_karya = wagebill_padat_karya + wagebill_`s'
	replace inv_padat_karya = inv_padat_karya + inv_`s'
	replace pdrb_padat_karya = pdrb_padat_karya + `s'_ADHK
}
foreach s in B D H J K L {
	replace tk_padat_modal = tk_padat_modal + tk_`s'
	replace wagebill_padat_modal = wagebill_padat_modal + wagebill_`s'
	replace inv_padat_modal = inv_padat_modal + inv_`s'
	replace pdrb_padat_modal = pdrb_padat_modal + `s'_ADHK
}

foreach kind in primer sekunder tersier ekstraktif industri hijau_inv padat_karya padat_modal {
	gen double share_tk_`kind'   = tk_`kind' / tk_total
	gen double share_upah_`kind' = wagebill_`kind' / wagebill_total
	gen double share_inv_`kind'  = inv_`kind' / inv_total if inv_total > 0
	replace    share_inv_`kind'  = 0 if missing(share_inv_`kind')
	gen double share_pdrb_`kind' = pdrb_`kind' / pdrb_adhk
	gen double ln_inv_`kind'     = ln(inv_`kind' + 1)
}

* sawit: tidak ada kolom sawit. Proksi = investasi pertanian (A_PMA+A_PMDN)
* di daerah dengan pangsa PDRB A di atas median.
gen double inv_sawit = inv_A
gen double ln_inv_sawit = ln(inv_sawit + 1)
gen double share_inv_sawit = share_inv_A
label variable inv_sawit "proksi sawit/agri: A_PMA + A_PMDN (Rp, satuan sheet)"

* hilirisasi: industri pengolahan (C) — jumlah TK, upah, investasi
gen double ln_tk_C     = ln(tk_C + 1)
gen double ln_inv_C    = ln(inv_C + 1)
bysort Code_Prov (Year): gen double g_tk_C = (tk_C - tk_C[_n-1]) / tk_C[_n-1] if tk_C[_n-1] > 0
bysort Code_Prov (Year): gen double g_inv_C = (inv_C - inv_C[_n-1]) / (inv_C[_n-1] + 1)

* K/L intensity
gen double log_kl = log_K - log_L
egen double z_log_kl = std(log_kl)

* kapasitas fiskal
egen double z_rasio_pad     = std(rasio_pad)
egen double z_apbd_serapan  = std(apbd_serapan)
egen double z_ln_belanja    = std(ln_apbd_belanja)
egen double raw_fiskal = rowmean(z_rasio_pad z_apbd_serapan z_ln_belanja)
egen double idx_fiskal = std(raw_fiskal)
label variable idx_fiskal "kapasitas fiskal (PAD + serapan + ln belanja)"

* --- klasifikasi (antara-provinsi: rata 2017-2024) ---------------------------
foreach v in pilar_pendidikan pilar_equity pilar_institusi pilar_konektivitas ///
	pilar_lingkungan pilar_keamanan idx_solow idx_hard idx_fiskal ///
	logtfp_it logtfp_it_crs indeks_hijau indeks_biru indeks_lingkungan ///
	share_tk_primer share_tk_sekunder share_tk_ekstraktif share_tk_industri ///
	share_tk_C share_inv_A share_inv_C share_inv_primer share_inv_padat_karya ///
	share_pdrb_primer rasio_pad log_kl ipm gini p0 {
	bysort Code_Prov: egen double m_`v' = mean(`v')
}

* tercile antar-provinsi (dari mean), dipakai split Solow dan fiskal
foreach v in m_pilar_pendidikan m_pilar_equity m_pilar_institusi m_idx_solow ///
	m_idx_fiskal m_log_kl m_share_tk_primer m_share_inv_padat_karya m_rasio_pad {
	xtile t_`v' = `v' if Year == 2017, nq(3)
	bysort Code_Prov: egen byte terc_`v' = max(t_`v')
	drop t_`v'
}

quietly summarize m_idx_solow if Year == 2017, detail
gen byte d_high_solow = (m_idx_solow >= r(p50))

quietly summarize m_idx_fiskal if Year == 2017, detail
gen byte d_high_fiskal = (m_idx_fiskal >= r(p50))

quietly summarize m_share_tk_ekstraktif if Year == 2017, detail
gen byte d_ekstraktif = (m_share_tk_ekstraktif >= r(p75))

quietly summarize m_share_inv_A if Year == 2017, detail
gen byte d_sawit = (m_share_inv_A >= r(p75))

quietly summarize m_share_tk_C if Year == 2017, detail
gen byte d_hilir = (m_share_tk_C >= r(p75))

quietly summarize m_log_kl if Year == 2017, detail
gen byte d_padat_modal_daerah = (m_log_kl >= r(p50))
gen byte d_padat_karya_daerah = (m_log_kl <  r(p50))

* dominan megasector (TK)
gen str12 dominan_tk = "tersier"
replace dominan_tk = "primer"   if share_tk_primer   >= share_tk_sekunder & share_tk_primer   >= share_tk_tersier
replace dominan_tk = "sekunder" if share_tk_sekunder >= share_tk_primer   & share_tk_sekunder >= share_tk_tersier
gen byte d_dom_primer   = (dominan_tk == "primer")
gen byte d_dom_sekunder = (dominan_tk == "sekunder")
gen byte d_dom_tersier  = (dominan_tk == "tersier")

* first difference untuk "faktor change" lingkungan
foreach v in indeks_hijau indeks_biru indeks_lingkungan ipm gini p0 equality ///
	logtfp_it logtfp_it_crs pilar_pendidikan pilar_equity pilar_institusi ///
	pengeluaran_kapita pendapatan_kapita rasio_pad {
	gen double d_`v' = D.`v'
}

* lingkungan dibersihkan dari ukuran (log PDRB) — yang dicari faktor change
quietly regress ln_indeks_hijau log_Y i.Year, vce(cluster Code_Prov)
predict double hijau_resid_size, resid
quietly regress ln_indeks_hijau log_Y ln_pengeluaran_kapita i.Year, vce(cluster Code_Prov)
predict double hijau_resid_pc, resid
egen double z_hijau_resid_size = std(hijau_resid_size)
egen double z_hijau_resid_pc   = std(hijau_resid_pc)

* interaksi Solow (pilar x log K, log L)
foreach p in pendidikan equity institusi konektivitas keamanan solow hard {
	if "`p'" == "solow" | "`p'" == "hard" {
		gen double `p'_x_K = idx_`p' * log_K
		gen double `p'_x_L = idx_`p' * log_L
	}
	else {
		gen double `p'_x_K = pilar_`p' * log_K
		gen double `p'_x_L = pilar_`p' * log_L
	}
}
gen double educ_eq_x_K = pilar_pendidikan * pilar_equity * log_K
gen double educ_eq_x_L = pilar_pendidikan * pilar_equity * log_L
gen double educ_x_hilir = pilar_pendidikan * share_tk_C
gen double educ_x_gC    = pilar_pendidikan * g_tk_C
gen double fiskal_x_tkprimer = idx_fiskal * share_tk_primer
gen double fiskal_x_ekstr    = idx_fiskal * share_tk_ekstraktif
gen double hijau_x_ekstr     = z_ln_indeks_hijau * share_tk_ekstraktif
gen double gini_x_tersier    = z_gini * share_tk_tersier

foreach p in pendidikan equity institusi konektivitas lingkungan keamanan {
	egen int rnk_hi = rank(-m_pilar_`p') if Year == 2017, unique
	egen int rnk_lo = rank( m_pilar_`p') if Year == 2017, unique
	bysort Code_Prov: egen byte top5_`p' = max(cond(Year == 2017, rnk_hi <= 5, .))
	bysort Code_Prov: egen byte bot5_`p' = max(cond(Year == 2017, rnk_lo <= 5, .))
	drop rnk_hi rnk_lo
	gen byte ekstrem_`p' = .
	replace ekstrem_`p' = 1 if top5_`p'
	replace ekstrem_`p' = 0 if bot5_`p'
}

label variable logtfp_it     "ln residual PMTB riil (DRS)"
label variable logtfp_it_crs "ln residual per pekerja (CRS)"
label variable log_K         "ln PMTB ADHK"
label variable log_L         "ln tenaga kerja 17 sektor"

compress
save "${outdir}/eval_panel.dta", replace
export excel using "${outdir}/eval_panel.xlsx", sheet("panel") firstrow(variables) replace

* =============================================================================
* 2. PROFIL (deskriptif; bukan estimator)
* =============================================================================

preserve
keep if Year == 2024
keep Code_Prov Pre_Prov Pulau ///
	m_pilar_pendidikan m_pilar_equity m_pilar_institusi m_pilar_konektivitas ///
	m_pilar_lingkungan m_pilar_keamanan m_idx_solow m_idx_hard m_idx_fiskal ///
	m_logtfp_it m_logtfp_it_crs m_indeks_hijau m_ipm m_gini m_p0 ///
	m_share_tk_primer m_share_tk_sekunder m_share_tk_ekstraktif m_share_inv_A ///
	m_rasio_pad
foreach p in pendidikan equity institusi konektivitas lingkungan keamanan {
	gsort -m_pilar_`p'
	gen byte top5_`p' = (_n <= 5)
	gsort  m_pilar_`p'
	gen byte bot5_`p' = (_n <= 5)
}
export excel using "${outdir}/eval1_profil_pilar.xlsx", sheet("mean2024") firstrow(variables) replace
restore

display as text _n "===== top5 vs bottom5 (ttest, snapshot 2017) ====="
preserve
keep if Year == 2017
foreach p in pendidikan equity institusi konektivitas lingkungan keamanan {
	display as text _n "pilar `p'"
	ttest m_logtfp_it_crs, by(top5_`p')
	ttest m_indeks_hijau,  by(top5_`p')
	ttest m_ipm,           by(top5_`p')
	ttest m_share_tk_primer, by(top5_`p')
}
restore

* =============================================================================
* 3. GLOBALS — sama dengan Determinan TFP Provinsi.do
* =============================================================================

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

* =============================================================================
* 4. FULL SPEC — naskah 6.1.2: FE, RE, RE2W, FGLS
*    POLS/FE2W disimpan untuk banding, bukan kolom yang dikutip.
*    FGLS_crs full X tidak diulang (tidak konvergen, log 19 Sep).
* =============================================================================

regress logtfp_it $X, vce(cluster Code_Prov)
estimates store POLS

xtreg logtfp_it $X, fe vce(cluster Code_Prov)
estimates store FE

xtreg logtfp_it $X i.Year, fe vce(cluster Code_Prov)
estimates store FE2W

xtreg logtfp_it $X, re vce(cluster Code_Prov)
estimates store RE

xtreg logtfp_it $X i.Year, re vce(cluster Code_Prov)
estimates store RE2W

xtgls logtfp_it $X, panels(heteroskedastic) igls nolog
estimates store FGLS

xtreg logtfp_it_crs $X, fe vce(cluster Code_Prov)
estimates store FE_crs

estimates table POLS FE FE2W RE RE2W FGLS FE_crs, ///
	keep($X) star stats(N) b(%7.3f)

quietly xtreg logtfp_it $X, fe
estimates store FE_h
quietly xtreg logtfp_it $X, re
estimates store RE_h
capture noisily hausman FE_h RE_h, sigmamore

* =============================================================================
* 5. FGLS PER GRUP — angka yang dikutip (19 Sep)
* =============================================================================

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

* jumlah efek per grup (sama rumus Determinan; restore FGLS grup dulu)
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

* CRS: FGLS grup (bukan full X)
xtgls logtfp_it_crs $pendidikan, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_pendidikan
xtgls logtfp_it_crs $equity, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_equity
xtgls logtfp_it_crs $institusi, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_institusi
xtgls logtfp_it_crs $konektivitas, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_konektivitas
xtgls logtfp_it_crs $lingkungan, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_lingkungan
xtgls logtfp_it_crs $keamanan, panels(heteroskedastic) igls nolog
estimates store FGLS_crs_keamanan

estimates table ///
	FGLS_crs_pendidikan FGLS_crs_equity FGLS_crs_institusi ///
	FGLS_crs_konektivitas FGLS_crs_lingkungan FGLS_crs_keamanan, ///
	star stats(N) b(%7.3f)

* =============================================================================
* 6. IMPLIKASI — xtgls eksplisit, satu spesifikasi per pertanyaan
* =============================================================================

* lingkungan: hijau vs biru (bukan komposit pilar)
xtgls logtfp_it z_ln_indeks_hijau z_ln_indeks_biru, panels(heteroskedastic) igls nolog
estimates store FGLS_hijau_biru

xtgls z_ln_indeks_hijau share_tk_ekstraktif share_tk_industri share_inv_ekstraktif, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_hijau_ekstr

xtgls logtfp_it z_ln_indeks_hijau share_tk_ekstraktif, panels(heteroskedastic) igls nolog
estimates store FGLS_tfp_hijau_ekstr

* equity: gini + IPM + upah (bukan interaksi gini x tersier)
xtgls logtfp_it z_gini z_ln_ipm z_ln_upah_rata, panels(heteroskedastic) igls nolog
estimates store FGLS_gini_ipm

* institusi: PAD vs belanja vs serapan
xtgls logtfp_it z_ln_rasio_pad z_ln_apbd_belanja z_ln_apbd_serapan, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_pad_belanja

* tenaga kerja / investasi sektoral
xtgls logtfp_it share_tk_primer share_tk_sekunder share_tk_ekstraktif share_tk_C, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_tk

xtgls logtfp_it share_inv_primer share_inv_sekunder share_inv_C share_inv_padat_karya, ///
	panels(heteroskedastic) igls nolog
estimates store FGLS_inv

xtgls logtfp_it share_inv_A d_sawit, panels(heteroskedastic) igls nolog
estimates store FGLS_sawit

xtgls indeks_hijau share_tk_ekstraktif share_tk_industri, panels(heteroskedastic) igls nolog
estimates store FGLS_hijau_tk

xtgls equality idx_fiskal share_tk_primer, panels(heteroskedastic) igls nolog
estimates store FGLS_eq_fiskal_tk

estimates table ///
	FGLS_hijau_biru FGLS_hijau_ekstr FGLS_tfp_hijau_ekstr FGLS_gini_ipm ///
	FGLS_pad_belanja FGLS_tk FGLS_inv FGLS_sawit FGLS_hijau_tk FGLS_eq_fiskal_tk, ///
	star stats(N) b(%7.3f)

* =============================================================================
* 7. COEF FGLS → csv (bukan 5 estimator)
* =============================================================================

tempname H
postfile `H' str40 model str40 var float b se t p n using "${outdir}/eval1_coef.dta", replace

foreach m in ///
	FGLS_pendidikan FGLS_equity FGLS_institusi FGLS_konektivitas FGLS_lingkungan FGLS_keamanan ///
	FGLS_crs_pendidikan FGLS_crs_equity FGLS_crs_institusi FGLS_crs_konektivitas FGLS_crs_lingkungan FGLS_crs_keamanan ///
	FGLS_hijau_biru FGLS_hijau_ekstr FGLS_tfp_hijau_ekstr FGLS_gini_ipm ///
	FGLS_pad_belanja FGLS_tk FGLS_inv FGLS_sawit FGLS_hijau_tk FGLS_eq_fiskal_tk ///
	FGLS FE RE RE2W {
	capture noisily estimates restore `m'
	if _rc continue
	quietly count if e(sample)
	local n = r(N)
	local vars : colnames e(b)
	foreach v of local vars {
		if "`v'" == "_cons" continue
		if strpos("`v'", "Year") continue
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

use "${outdir}/eval1_coef.dta", clear
gen str8 star = ""
replace star = "*"    if p < 0.05
replace star = "**"   if p < 0.01
replace star = "***"  if p < 0.001
export excel using "${outdir}/eval1_coef.xlsx", sheet("coef") firstrow(variables) replace
export delimited using "${outdir}/eval1_coef.csv", replace
keep if strpos(model, "FGLS")
export delimited using "${outdir}/eval1_coef_fgls.csv", replace

do "${proj}/02 Code/TFP/compile_panel.do"

display as text _n "eval1 done. panel -> ${outdir}/eval_panel.dta"
display as text "coef  -> ${outdir}/eval1_coef.csv"
display as text "panel gabungan -> ${proj}/01 Data/TFP/processed/Panel TFP Provinsi 2017-2024.dta"
log close
