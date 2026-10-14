* 13_Sectoral.do — komposisi produktivitas sektoral, bukan koefisien upah
* Atha Bintang Wahyu M. | PSE UGM
*
* Koefisien upah di Determinan TFP Provinsi.do (FGLS bersama, z log upah
* primer / sekunder / tersier pada logtfp, dummy provinsi dan tahun) adalah
* korelasi parsial. Tanda tersier pada spesifikasi itu merata-ratakan jasa
* yang produktivitasnya jauh berbeda, sehingga tidak menjawab komposisi TFP
* dan tidak menjadi alasan untuk tidak mendorong jasa.
*
* Modal per sektor tidak ada. PMTB di residual adalah arus agregat. PMA+PMDN
* tidak dipakai sebagai stok modal dan tidak masuk fungsi produksi sektoral.
*
* Yang dihitung:
*   1. Komposisi level produktivitas tenaga kerja, 2017 dan 2024.
*      Pangsa nilai tambah = kontribusi kelompok pada level produktivitas
*      agregat, karena P = Y/L = jumlah (pangsa kerja x produktivitas kelompok).
*   2. Dekomposisi Olley-Pakes: suku kovarian alokasi.
*   3. Shift-share 2017-2024 (within, between, dinamis) pada agregat nasional.
*      Bukan dekomposisi TFP tahun-per-tahun: arus PMTB membuat residual
*      tahunan berayun.
*   4. Kontrafaktual 1 poin pangsa kerja. K agregat dan L agregat ditahan,
*      jadi perubahan log Y sama dengan perubahan logtfp (DRS maupun CRS).
*      Angka itu produk rata-rata, bukan produk marjinal. Sel dengan
*      produktivitas sangat tinggi dan pekerja sangat sedikit (tambang,
*      informasi, keuangan, real estat) bukan tujuan realokasi massal.
*   5. Model pertumbuhan residual. Pangsa investasi tahun lalu
*      (primer, sekunder, jasa bernilai tambah; basis = tersier lainnya),
*      efek tahun, pertumbuhan log K dan log L, serta logtfp tertinggal.
*      Ini presedensi waktu lintas provinsi, bukan eksperimen dalam-provinsi.
*      Kolom FE provinsi dilaporkan terpisah dan diharapkan lebih lemah:
*      komposisi bergerak lambat.
*   6. Reduced form paparan shift-share (pangsa kerja 2017 x pertumbuhan
*      nilai tambah nasional leave-one-out). First stage ke pangsa investasi
*      tidak dijadikan 2SLS bila instrumen tidak menggerakkan pangsa.
*
* Kelompok
*   primer                  A pertanian, B pertambangan
*   sekunder                C industri, D listrik, E air, F konstruksi
*   tersier                 G-RSTU
*   tersier nilai tambah    H transportasi, J informasi, K keuangan, MN jasa perusahaan
*   tersier lainnya         G perdagangan, I akomodasi, L real estat,
*                           O pemerintah, P pendidikan, Q kesehatan, RSTU
*
* Jalankan dari root:  do "02 Code/TFP/13_Sectoral.do"

version 17
clear all
set more off
set linesize 255
set varabbrev off
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
		if !`_found' global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"
}

global tfp    "${proj}/01 Data/TFP/output/konstruksi/TFP Provinsi 2017-2024.dta"
global xlsx   "${proj}/01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
if !fileexists("${xlsx}") {
	global xlsx "${proj}/01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
}
global outdir "${proj}/01 Data/TFP/output/sectoral"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "${outdir}"

if !fileexists("${tfp}") {
	display as error "residual TFP tidak ada. Jalankan Konstruksi TFP Provinsi.do dulu."
	exit 601
}
if !fileexists("${xlsx}") {
	display as error "workbook tidak ada: $xlsx"
	exit 601
}

log using "${outdir}/13_Sectoral.log", replace text
display as text "proj = $proj"
display as text "tfp  = $tfp"
display as text "xlsx = $xlsx"

* =============================================================================
* 1. PANEL
* =============================================================================

use "${tfp}", clear
keep Code_Prov Year logtfp_it logtfp_it_crs log_Y log_K log_L ///
	pdrb_adhk pmtb_adhk labours_total
tempfile tfp
save `tfp'

import excel "${xlsx}", sheet("Sheet1") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)
capture drop logtfp_it logtfp_it_crs
merge 1:1 Code_Prov Year using `tfp', keep(match) nogen
isid Code_Prov Year

local secs A B C D E F G H I J K L MN O P Q RSTU
foreach s of local secs {
	capture confirm variable `s'_ADHK
	if _rc {
		display as error "kolom `s'_ADHK tidak ada"
		exit 111
	}
	gen double Y_`s' = `s'_ADHK
	gen double L_`s' = `s'_TenagaKerja
	gen double I_`s' = max(`s'_PMA, 0) + max(`s'_PMDN, 0)
	gen double W_`s' = `s'_RataUpah
}

quietly count if missing(L_L)
display as text "sel L_TenagaKerja kosong (real estat), sebelum imputasi: " as result r(N)
bysort Code_Prov (Year): ipolate L_L Year, gen(L_L_i) epolate
replace L_L = L_L_i if missing(L_L)
drop L_L_i
quietly count if missing(L_L)
display as text "sel L_TenagaKerja masih kosong: " as result r(N)

gen double Y_primer   = Y_A + Y_B
gen double L_primer   = L_A + L_B
gen double I_primer   = I_A + I_B
gen double Y_sekunder = Y_C + Y_D + Y_E + Y_F
gen double L_sekunder = L_C + L_D + L_E + L_F
gen double I_sekunder = I_C + I_D + I_E + I_F
gen double Y_Conly    = Y_C
gen double L_Conly    = L_C
gen double I_Conly    = I_C
gen double Y_def      = Y_D + Y_E + Y_F
gen double L_def      = L_D + L_E + L_F
gen double I_def      = I_D + I_E + I_F
gen double Y_tva      = Y_H + Y_J + Y_K + Y_MN
gen double L_tva      = L_H + L_J + L_K + L_MN
gen double I_tva      = I_H + I_J + I_K + I_MN
gen double Y_tlain    = Y_G + Y_I + Y_L + Y_O + Y_P + Y_Q + Y_RSTU
gen double L_tlain    = L_G + L_I + L_L + L_O + L_P + L_Q + L_RSTU
gen double I_tlain    = I_G + I_I + I_L + I_O + I_P + I_Q + I_RSTU
gen double Y_tersier  = Y_tva + Y_tlain
gen double L_tersier  = L_tva + L_tlain
gen double I_tersier  = I_tva + I_tlain
gen double Y_hmn      = Y_H + Y_MN
gen double L_hmn      = L_H + L_MN
gen double Y_low      = Y_G + Y_I + Y_RSTU
gen double L_low      = L_G + L_I + L_RSTU

gen double Ytot = Y_primer + Y_sekunder + Y_tersier
gen double Ltot = L_primer + L_sekunder + L_tersier
gen double Itot = I_primer + I_sekunder + I_tersier

assert abs(Y_tersier - (Y_tva + Y_tlain)) < 1e-4
assert abs(I_sekunder - (I_Conly + I_def)) < 1e-4
gen double cek_y = Ytot / pdrb_adhk
gen double cek_l = Ltot / labours_total
summarize cek_y cek_l, separator(0)
display as text "Y sektoral / 9_ADHK dan L sektoral / tenaga kerja konstruksi (harus di sekitar 1)"

gen double Pprov = Ytot / Ltot
foreach g in primer sekunder tersier tva tlain Conly def hmn low A B C {
	gen double p_`g'   = Y_`g' / L_`g' if L_`g' > 0
	gen double th_`g'  = L_`g' / Ltot if Ltot > 0
	gen double va_`g'  = Y_`g' / Ytot if Ytot > 0
	gen double rel_`g' = p_`g' / Pprov if Pprov > 0
	gen double gap_`g' = va_`g' - th_`g'
}
gen double inv_primer   = I_primer / Itot if Itot > 0
gen double inv_sekunder = I_sekunder / Itot if Itot > 0
gen double inv_tva      = I_tva / Itot if Itot > 0
gen double inv_tlain    = I_tlain / Itot if Itot > 0
gen double inv_C        = I_Conly / Itot if Itot > 0
gen double inv_def      = I_def / Itot if Itot > 0

label variable th_primer   "pangsa kerja primer"
label variable va_primer   "pangsa nilai tambah primer"
label variable rel_primer  "produktivitas relatif primer"
label variable th_sekunder "pangsa kerja sekunder"
label variable va_sekunder "pangsa nilai tambah sekunder"
label variable rel_sekunder "produktivitas relatif sekunder"
label variable th_tersier  "pangsa kerja tersier"
label variable va_tersier  "pangsa nilai tambah tersier"
label variable rel_tersier "produktivitas relatif tersier"
label variable th_tva      "pangsa kerja tersier nilai tambah"
label variable va_tva      "pangsa nilai tambah tersier nilai tambah"
label variable rel_tva     "produktivitas relatif tersier nilai tambah"
label variable th_tlain    "pangsa kerja tersier lainnya"
label variable va_tlain    "pangsa nilai tambah tersier lainnya"
label variable rel_tlain   "produktivitas relatif tersier lainnya"
label variable inv_primer   "pangsa investasi PMA+PMDN primer"
label variable inv_sekunder "pangsa investasi PMA+PMDN sekunder"
label variable inv_tva      "pangsa investasi PMA+PMDN tersier nilai tambah"
label variable inv_C        "pangsa investasi industri pengolahan (C)"
label variable inv_def      "pangsa investasi listrik, air, konstruksi"
label variable logtfp_it    "ln residual TFP DRS (dari Konstruksi)"

* paparan eksternal: pangsa kerja 2017 x indeks nilai tambah nasional leave-one-out
foreach s of local secs {
	bysort Year: egen double natY_`s' = total(Y_`s')
	gen double looY_`s' = natY_`s' - Y_`s'
	bysort Code_Prov: egen double looY0_`s' = max(cond(Year==2017, looY_`s', .))
	gen double gY_`s' = looY_`s' / looY0_`s' if looY0_`s' > 0
	bysort Code_Prov: egen double sL_`s' = max(cond(Year==2017 & Ltot>0, L_`s'/Ltot, .))
}
egen double sL_cek = rowtotal(sL_A sL_B sL_C sL_D sL_E sL_F sL_G sL_H sL_I sL_J sL_K sL_L sL_MN sL_O sL_P sL_Q sL_RSTU)
quietly summarize sL_cek if Year==2017
display as text "jumlah pangsa kerja 2017 (harus 1): " as result %8.5f r(mean)

gen double BY_primer   = sL_A*gY_A + sL_B*gY_B
gen double BY_sekunder = sL_C*gY_C + sL_D*gY_D + sL_E*gY_E + sL_F*gY_F
gen double BY_tva      = sL_H*gY_H + sL_J*gY_J + sL_K*gY_K + sL_MN*gY_MN
gen double BY_tlain    = sL_G*gY_G + sL_I*gY_I + sL_L*gY_L + sL_O*gY_O + sL_P*gY_P + sL_Q*gY_Q + sL_RSTU*gY_RSTU
label variable BY_primer   "paparan primer: pangsa kerja 2017 x pertumbuhan VA nasional LOO"
label variable BY_sekunder "paparan sekunder"
label variable BY_tva      "paparan tersier nilai tambah"
label variable BY_tlain    "paparan tersier lainnya"

xtset Code_Prov Year
foreach v in inv_primer inv_sekunder inv_tva inv_tlain inv_C inv_def logtfp_it logtfp_it_crs ///
	BY_primer BY_sekunder BY_tva BY_tlain {
	gen double `v'_l1 = L.`v'
}
gen double d_logtfp = D.logtfp_it
gen double d_logK   = D.log_K
gen double d_logL   = D.log_L
label variable d_logtfp    "perubahan ln residual TFP DRS"
label variable d_logK      "perubahan ln PMTB ADHK"
label variable d_logL      "perubahan ln tenaga kerja"
label variable logtfp_it_l1 "ln residual TFP tahun lalu"
label variable inv_primer_l1   "pangsa investasi primer, t-1"
label variable inv_sekunder_l1 "pangsa investasi sekunder, t-1"
label variable inv_tva_l1      "pangsa investasi tersier nilai tambah, t-1"
label variable inv_C_l1        "pangsa investasi industri C, t-1"
label variable inv_def_l1      "pangsa investasi D+E+F, t-1"

gen byte samp = !missing(d_logtfp, d_logK, d_logL, logtfp_it_l1, ///
	inv_primer_l1, inv_sekunder_l1, inv_tva_l1, inv_C_l1, inv_def_l1)
quietly count if samp
display as text "sampel model pertumbuhan (2018-2024, lengkap): " as result r(N)

* kontrafaktual lokal, 1 poin kerja, K dan L agregat provinsi tetap
gen double dlog_A_C   = ln( (Pprov + 0.01*(p_C   - p_A)) / Pprov ) if p_A<. & p_C<.
gen double dlog_A_tva = ln( (Pprov + 0.01*(p_tva - p_A)) / Pprov ) if p_A<. & p_tva<.
label variable dlog_A_C   "d log TFP lokal, 1pp kerja A ke C, produk rata-rata"
label variable dlog_A_tva "d log TFP lokal, 1pp kerja A ke jasa nilai tambah"

* =============================================================================
* 2. KOMPOSISI NASIONAL
* =============================================================================

tempfile level_long shift_d cf_d op_d
postfile H ///
	str8 tahun str40 kelompok ///
	double pekerja va rel_lp gap ///
	using `level_long', replace
postfile S ///
	str4 skema str40 kelompok ///
	double within_level between_level dinamik_level total_level ///
	double within_share between_share dinamik_share total_share ///
	using `shift_d', replace
postfile C ///
	str72 skenario ///
	double dlog_tfp persen_P ///
	using `cf_d', replace
postfile O ///
	str8 tahun str16 agregasi str40 kelompok ///
	double pbar kovarians pangsa_dari_P ///
	using `op_d', replace

preserve
collapse (sum) ///
	Y_A Y_B Y_C Y_D Y_E Y_F Y_G Y_H Y_I Y_J Y_K Y_L Y_MN Y_O Y_P Y_Q Y_RSTU ///
	L_A L_B L_C L_D L_E L_F L_G L_H L_I L_J L_K L_L L_MN L_O L_P L_Q L_RSTU ///
	, by(Year)

gen double Y_primer   = Y_A + Y_B
gen double L_primer   = L_A + L_B
gen double Y_sekunder = Y_C + Y_D + Y_E + Y_F
gen double L_sekunder = L_C + L_D + L_E + L_F
gen double Y_tva      = Y_H + Y_J + Y_K + Y_MN
gen double L_tva      = L_H + L_J + L_K + L_MN
gen double Y_tlain    = Y_G + Y_I + Y_L + Y_O + Y_P + Y_Q + Y_RSTU
gen double L_tlain    = L_G + L_I + L_L + L_O + L_P + L_Q + L_RSTU
gen double Y_tersier  = Y_tva + Y_tlain
gen double L_tersier  = L_tva + L_tlain
gen double Y_hmn      = Y_H + Y_MN
gen double L_hmn      = L_H + L_MN
gen double Y_low      = Y_G + Y_I + Y_RSTU
gen double L_low      = L_G + L_I + L_RSTU
gen double Y_Conly    = Y_C
gen double L_Conly    = L_C
gen double Y_all      = Y_primer + Y_sekunder + Y_tersier
gen double L_all      = L_primer + L_sekunder + L_tersier
gen double P          = Y_all / L_all

local groups primer sekunder tersier tva tlain hmn low Conly A B C D E F G H I J K L MN O P Q RSTU
foreach g of local groups {
	gen double p_`g'   = Y_`g' / L_`g'
	gen double th_`g' = L_`g' / L_all
	gen double va_`g' = Y_`g' / Y_all
	gen double rel_`g' = p_`g' / P
	gen double gap_`g' = va_`g' - th_`g'
}

foreach y in 2017 2024 {
	foreach g of local groups {
		foreach stub in th va rel gap {
			quietly summarize `stub'_`g' if Year==`y', meanonly
			scalar `stub'_`g'_`y' = r(mean)
		}
		quietly summarize p_`g' if Year==`y', meanonly
		scalar p_`g'_`y' = r(mean)
	}
	quietly summarize P if Year==`y', meanonly
	scalar P_`y' = r(mean)
	quietly summarize Y_all if Year==`y', meanonly
	scalar Y_`y' = r(mean)
	quietly summarize L_all if Year==`y', meanonly
	scalar L_`y' = r(mean)
}

local namaprimer    "Primer (A+B)"
local namasekunder  "Sekunder (C-F)"
local namatersier   "Tersier (G-RSTU)"
local namatva       "Tersier nilai tambah (H J K MN)"
local namatlain     "Tersier lainnya"
local namahmn       "Jasa penghubung (H+MN)"
local namalow       "Jasa lapis bawah (G I RSTU)"
local namaConly     "Industri pengolahan (C)"
local namaA "A pertanian"
local namaB "B pertambangan"
local namaC "C industri"
local namaD "D listrik"
local namaE "E air"
local namaF "F konstruksi"
local namaG "G perdagangan"
local namaH "H transportasi"
local namaI "I akomodasi"
local namaJ "J informasi"
local namaK "K keuangan"
local namaL "L real estat"
local namaMN "MN jasa perusahaan"
local namaO "O pemerintah"
local namaP "P pendidikan"
local namaQ "Q kesehatan"
local namaRSTU "RSTU jasa lainnya"

foreach y in 2017 2024 {
	foreach g of local groups {
		post H ("`y'") ("`nama`g''") ///
			(th_`g'_`y') (va_`g'_`y') (rel_`g'_`y') (gap_`g'_`y')
	}
}

* shift-share titik ujung. Identitas: dP = within + between + dinamik
scalar dP = P_2024 - P_2017

program define _shift
	args skema g label
	scalar w = th_`g'_2017 * (p_`g'_2024 - p_`g'_2017)
	scalar b = p_`g'_2017 * (th_`g'_2024 - th_`g'_2017)
	scalar d = (th_`g'_2024 - th_`g'_2017) * (p_`g'_2024 - p_`g'_2017)
	post S ("`skema'") ("`label'") ///
		(w) (b) (d) (w+b+d) ///
		(w/dP) (b/dP) (d/dP) ((w+b+d)/dP)
	scalar wsum = wsum + w
	scalar bsum = bsum + b
	scalar dsum = dsum + d
end

scalar wsum = 0
scalar bsum = 0
scalar dsum = 0
foreach g in primer sekunder tersier {
	_shift "3" `g' "`nama`g''"
}
display as text _n "cek shift-share 3 kelompok, selisih terhadap dP: " ///
	as result %12.3e (wsum + bsum + dsum - dP)

scalar wsum = 0
scalar bsum = 0
scalar dsum = 0
foreach g in primer sekunder tva tlain {
	_shift "4" `g' "`nama`g''"
}
display as text "cek shift-share 4 kelompok, selisih terhadap dP: " ///
	as result %12.3e (wsum + bsum + dsum - dP)

scalar wsum = 0
scalar bsum = 0
scalar dsum = 0
foreach g in A B C D E F G H I J K L MN O P Q RSTU {
	_shift "17" `g' "`nama`g''"
}
display as text "cek shift-share 17 sektor, selisih terhadap dP: " ///
	as result %12.3e (wsum + bsum + dsum - dP)

* Olley-Pakes. Referensi = rerata tak tertimbang produktivitas kelompok.
* Kovarian negatif: pekerja menumpuk di kelompok yang produktivitasnya di bawah rerata.
foreach y in 2017 2024 {
	scalar Pnow = P_`y'
	scalar pbar3 = (p_primer_`y' + p_sekunder_`y' + p_tersier_`y') / 3
	scalar cov3 = 0
	foreach g in primer sekunder tersier {
		scalar covi = (th_`g'_`y' - 1/3) * (p_`g'_`y' - pbar3)
		scalar cov3 = cov3 + covi
		post O ("`y'") ("3 kelompok") ("`nama`g''") (pbar3) (covi) (covi/Pnow)
	}
	post O ("`y'") ("3 kelompok") ("Jumlah alokasi") (pbar3) (cov3) (cov3/Pnow)

	scalar pbar4 = (p_primer_`y' + p_sekunder_`y' + p_tva_`y' + p_tlain_`y') / 4
	scalar cov4 = 0
	foreach g in primer sekunder tva tlain {
		scalar covi = (th_`g'_`y' - 1/4) * (p_`g'_`y' - pbar4)
		scalar cov4 = cov4 + covi
		post O ("`y'") ("4 kelompok") ("`nama`g''") (pbar4) (covi) (covi/Pnow)
	}
	post O ("`y'") ("4 kelompok") ("Jumlah alokasi") (pbar4) (cov4) (cov4/Pnow)
}

* kontrafaktual nasional 2024. 0,01 x selisih produk rata-rata.
* K dan L agregat tetap => d log Y = d log TFP.
program define _cf
	args label src dst
	scalar dPcf = 0.01 * (p_`dst'_2024 - p_`src'_2024)
	scalar dlog = ln( (P_2024 + dPcf) / P_2024 )
	post C ("`label'") (dlog) (100 * exp(dlog) - 100)
end

_cf "1pp pertanian ke industri (A ke C)" A C
_cf "1pp pertanian ke sekunder (A ke C-F)" A sekunder
_cf "1pp pertanian ke jasa nilai tambah (A ke HJKMN)" A tva
_cf "1pp pertanian ke jasa penghubung (A ke H+MN)" A hmn
_cf "1pp pertanian ke tersier lainnya (A ke basis)" A tlain
_cf "1pp jasa lapis bawah ke industri (GIR ke C)" low C
_cf "1pp jasa lapis bawah ke jasa nilai tambah" low tva
_cf "1pp tersier lainnya ke industri" tlain C

postclose H
postclose S
postclose C
postclose O

display as text _n "produktivitas agregat 2017 = " as result %8.5f P_2017 ///
	as text "   2024 = " as result %8.5f P_2024 ///
	as text "   dP = " as result %8.5f dP
display as text "satuan: miliar rupiah ADHK per pekerja"
restore

* =============================================================================
* 3. MODEL PERTUMBUHAN RESIDUAL
* =============================================================================
* Basis yang dihilangkan: pangsa investasi tersier lainnya.
* Koefisien = selisih terhadap menggeser pangsa itu ke kelompok yang disebut.
* d_logK dan d_logL menahan saluran mekanis: residual sudah mengurangi b1 log K
* dan b2 log L, jadi volume investasi tahun yang sama tidak boleh ikut sebagai
* "dampak". Yang masuk adalah komposisi tahun lalu.

regress d_logtfp inv_primer_l1 inv_sekunder_l1 inv_tva_l1 ///
	d_logK d_logL i.Year if samp, vce(cluster Code_Prov)
estimates store M1

regress d_logtfp inv_primer_l1 inv_sekunder_l1 inv_tva_l1 ///
	d_logK d_logL logtfp_it_l1 i.Year if samp, vce(cluster Code_Prov)
estimates store M2

xtreg d_logtfp inv_primer_l1 inv_sekunder_l1 inv_tva_l1 ///
	d_logK d_logL i.Year if samp, fe vce(cluster Code_Prov)
estimates store M3

regress d_logtfp inv_primer_l1 inv_sekunder_l1 inv_tva_l1 ///
	logtfp_it_l1 i.Year if samp, vce(cluster Code_Prov)
estimates store M4

regress d_logtfp inv_primer_l1 inv_C_l1 inv_def_l1 inv_tva_l1 ///
	d_logK d_logL logtfp_it_l1 i.Year if samp, vce(cluster Code_Prov)
estimates store M5

estimates table M1 M2 M3 M4 M5, ///
	keep(inv_primer_l1 inv_sekunder_l1 inv_C_l1 inv_def_l1 inv_tva_l1 ///
		d_logK d_logL logtfp_it_l1) ///
	b(%9.4f) se(%9.4f) stats(N r2) ///
	title("Pertumbuhan residual pada pangsa investasi t-1")

display as text _n "M2, terjemahan 10 poin pangsa (relatif terhadap tersier lainnya):"
estimates restore M2
foreach v in inv_primer_l1 inv_sekunder_l1 inv_tva_l1 {
	display as text "  `v'  " as result %8.4f (0.10 * _b[`v']) ///
		as text " log poin / tahun   t = " as result %5.2f (_b[`v']/_se[`v'])
}

* paparan eksternal. Reduced form pada level residual, FE dua arah.
* Bukan 2SLS: pangsa nilai tambah dan pangsa kerja hampir tidak bergerak
* dalam provinsi, dan first stage di bawah diuji dulu.
xtreg logtfp_it BY_primer_l1 BY_sekunder_l1 BY_tva_l1 BY_tlain_l1 ///
	i.Year if Year>=2018, fe vce(cluster Code_Prov)
estimates store Paparan
test BY_primer_l1 BY_sekunder_l1 BY_tva_l1 BY_tlain_l1

display as text _n "first stage pangsa investasi pada paparan (FE dua arah)"
foreach dep in inv_primer inv_sekunder inv_tva {
	xtreg `dep' BY_primer_l1 BY_sekunder_l1 BY_tva_l1 BY_tlain_l1 ///
		i.Year if Year>=2018, fe vce(cluster Code_Prov)
	estimates store FS_`dep'
	local own = cond("`dep'"=="inv_primer", "BY_primer_l1", ///
		cond("`dep'"=="inv_sekunder", "BY_sekunder_l1", "BY_tva_l1"))
	display as text "  `dep' pada `own': b = " as result %7.3f _b[`own'] ///
		as text "  t = " as result %5.2f (_b[`own']/_se[`own'])
}
display as text "2SLS tidak diestimasi. First stage tidak dipakai sebagai instrumen bila tanda berlawanan atau t kecil. Klaim komposisi berdiri di akuntansi dan di M2, bukan di IV."

* pembanding: spesifikasi upah di Determinan TFP Provinsi.do. Bukan temuan di file ini.
* Upah diambil dari sheet yang sama (Analisis Luaran 2), bukan dari Sheet1.
preserve
import excel "${xlsx}", sheet("Analisis Luaran 2") firstrow clear
drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)
keep Code_Prov Year ///
	A_RataUpah B_RataUpah C_RataUpah D_RataUpah E_RataUpah F_RataUpah ///
	G_RataUpah H_RataUpah I_RataUpah J_RataUpah K_RataUpah L_RataUpah ///
	MN_RataUpah O_RataUpah P_RataUpah Q_RataUpah RSTU_RataUpah
foreach s of local secs {
	rename `s'_RataUpah upahsrc_`s'
}
tempfile upahsrc
save `upahsrc'
restore
merge 1:1 Code_Prov Year using `upahsrc', keep(match) nogen
foreach s of local secs {
	replace W_`s' = upahsrc_`s'
	drop upahsrc_`s'
	gen double lnW_`s' = ln(W_`s' + 1) if W_`s' < .
}
egen double lnW_primer   = rowmean(lnW_A lnW_B)
egen double lnW_sekunder = rowmean(lnW_C lnW_D lnW_E lnW_F)
egen double lnW_tersier  = rowmean(lnW_G lnW_H lnW_I lnW_J lnW_K lnW_L lnW_MN lnW_O lnW_P lnW_Q lnW_RSTU)
egen double zW_primer   = std(lnW_primer)
egen double zW_sekunder = std(lnW_sekunder)
egen double zW_tersier  = std(lnW_tersier)
xtgls logtfp_it zW_primer zW_sekunder zW_tersier i.Code_Prov i.Year, ///
	panels(heteroskedastic) nolog
estimates store Upah
display as text _n "pembanding upah (bukan temuan 13_Sectoral):"
display as text "  primer   " as result %8.4f _b[zW_primer]   as text "  t = " as result %5.2f (_b[zW_primer]/_se[zW_primer])
display as text "  sekunder " as result %8.4f _b[zW_sekunder] as text "  t = " as result %5.2f (_b[zW_sekunder]/_se[zW_sekunder])
display as text "  tersier  " as result %8.4f _b[zW_tersier]  as text "  t = " as result %5.2f (_b[zW_tersier]/_se[zW_tersier])

tempfile panel prov24
save `panel', replace

* =============================================================================
* 4. LUARAN
* =============================================================================

tempfile model_d
postfile M str12 model str24 term double b se t p N using `model_d', replace
foreach mod in M1 M2 M3 M4 M5 Paparan Upah {
	estimates restore `mod'
	local n = e(N)
	foreach term in inv_primer_l1 inv_sekunder_l1 inv_C_l1 inv_def_l1 inv_tva_l1 ///
		d_logK d_logL logtfp_it_l1 ///
		BY_primer_l1 BY_sekunder_l1 BY_tva_l1 BY_tlain_l1 ///
		zW_primer zW_sekunder zW_tersier {
		capture local bb = _b[`term']
		if _rc continue
		local ss = _se[`term']
		post M ("`mod'") ("`term'") (`bb') (`ss') (`bb'/`ss') ///
			(2*normal(-abs(`bb'/`ss'))) (`n')
	}
}
postclose M

use `level_long', clear
label variable tahun     "tahun"
label variable kelompok  "kelompok"
label variable pekerja   "pangsa tenaga kerja"
label variable va        "pangsa nilai tambah = komposisi level produktivitas"
label variable rel_lp    "produktivitas tenaga kerja relatif terhadap agregat"
label variable gap       "pangsa nilai tambah minus pangsa kerja"
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Level") firstrow(variables) replace

use `shift_d', clear
label variable skema "3 = mega, 4 = tersier dipecah, 17 = sektor"
label variable within_share  "pangsa kenaikan P dari dalam sektor"
label variable between_share "pangsa kenaikan P dari perpindahan kerja"
label variable dinamik_share "pangsa kenaikan P dari interaksi"
label variable total_share   "pangsa kenaikan P, jumlah tiga suku"
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Shiftshare") firstrow(variables) sheetreplace

use `op_d', clear
label variable kovarians    "suku (pangsa - 1/G) x (produktivitas - rerata)"
label variable pangsa_dari_P "kovarians / produktivitas agregat"
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Alokasi") firstrow(variables) sheetreplace

use `cf_d', clear
label variable dlog_tfp "perubahan log TFP bila K dan L agregat tetap"
label variable persen_P "persen terhadap produktivitas agregat 2024"
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Kontrafaktual") firstrow(variables) sheetreplace

use `model_d', clear
label variable b "koefisien"
label variable se "SE cluster provinsi"
label variable p "p dua sisi, aproksimasi normal"
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Model") firstrow(variables) sheetreplace

use `panel', clear
keep if Year == 2024
keep Code_Prov Pre_Prov Pprov ///
	th_primer va_primer rel_primer gap_primer ///
	th_sekunder va_sekunder rel_sekunder gap_sekunder ///
	th_tersier va_tersier rel_tersier gap_tersier ///
	th_tva va_tva rel_tva gap_tva ///
	th_tlain va_tlain rel_tlain gap_tlain ///
	th_A va_A rel_A gap_A ///
	th_B va_B rel_B gap_B ///
	th_C va_C rel_C gap_C ///
	dlog_A_C dlog_A_tva
order Code_Prov Pre_Prov
export excel using "${outdir}/13_Sectoral.xlsx", sheet("Provinsi_2024") firstrow(variables) sheetreplace
save `prov24', replace

use `panel', clear
keep Code_Prov Pre_Prov Year logtfp_it logtfp_it_crs log_Y log_K log_L ///
	Ytot Ltot Pprov ///
	th_primer va_primer rel_primer gap_primer ///
	th_sekunder va_sekunder rel_sekunder gap_sekunder ///
	th_tersier va_tersier rel_tersier ///
	th_tva va_tva rel_tva gap_tva ///
	th_tlain va_tlain rel_tlain gap_tlain ///
	inv_primer inv_sekunder inv_tva inv_tlain inv_C inv_def ///
	inv_primer_l1 inv_sekunder_l1 inv_tva_l1 inv_C_l1 inv_def_l1 ///
	d_logtfp d_logK d_logL logtfp_it_l1 ///
	BY_primer BY_sekunder BY_tva BY_tlain ///
	BY_primer_l1 BY_sekunder_l1 BY_tva_l1 BY_tlain_l1 ///
	dlog_A_C dlog_A_tva samp
order Code_Prov Pre_Prov Year
compress
save "${outdir}/13_Sectoral.dta", replace

display as text _n "saved: $outdir"
log close
