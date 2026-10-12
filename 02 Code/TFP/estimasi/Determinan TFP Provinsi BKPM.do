*** LEGACY copy of the Pak Yudis AI do-file. Working script:
***   02 Code/TFP/Konstruksi TFP Provinsi.do
*** Archive:
***   02 Code/TFP/Determinan TFP Provinsi BKPM (legacy Yudis).do
***
*** Determinants of provincial TFP, Indonesia 34 provinces x 2017-2025 (balanced)
*** PCA pillar indices + static and dynamic panel models with post-estimation tests
*
* Canonical runnable copy: 02 Code/TFP/Determinan TFP Provinsi BKPM.do
* Data     : 01 Data/TFP/AI-Pak_Yudis/
*            "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
*            sheet "Analisis Luaran 2" (labels from "Keterangan Data Luaran 2")
* Output   : 01 Data/TFP/output/determinan/
* Dependent: logtfp_it (log TFP level per province-year; robustness: logtfp_it_crs)
* Pillars  : (1) Human resource : Educ_Prov Campus_Prov IPM_Prov_Nm Gini_Prov
*            (2) Institution    : PDBDeflator rasio_pad serapan_belanja Crime2_Prov IDI_Prov2
*            (3) Connectivity   : jalan_mantap_pct Airpot_Total Cargo_Total
*            (4) Industry       : Upah_Agr_Prov Industry_Prov
* Controls : IKLH_Prov Hijau_Prov Biru_Prov (environmental quality)
*
* Sections : 0 setup | 1 import + labels | 2 panel structure | 3 variable
*            construction | 4 descriptives | 5 PCA indices | 6 pre-estimation
*            diagnostics | 7 static panel models | 8 dynamic panel models |
*            9 robustness | 10 summary tables + decision guide | 11 export
*
* Model survey (why each estimator is here; see the companion markdown note):
*  POLS   pooled OLS, cluster-robust SE      : benchmark; ignores province effects
*  FE     one-way fixed effects (within)    : consistent if province effects
*                                             correlate with the regressors
*  FE2W   two-way FE (province + year)      : also removes common shocks
*                                             (COVID-19 2020-21, national policy)
*  RE     random effects (Swamy-Arora GLS)  : efficient only if province effects
*                                             are uncorrelated with the regressors
*  CRE    Mundlak correlated random effects : RE + group means; the joint test on
*                                             the means is a cluster-robust Hausman
*  XTREGAR FE/RE with AR(1) disturbances    : reports Bhargava DW and Baltagi-Wu LBI
*  FGLS   xtgls, panel heteroskedastic AR(1): N=34 > T=9 so cross-panel correlation
*                                             cannot be estimated (panels(corr) infeasible)
*  PCSE   Beck-Katz PCSE on LSDV            : heteroskedastic + AR(1), with dummies
*  DK     Driscoll-Kraay (xtscc, fe)        : SE robust to cross-sectional dependence
*  FE-LDV FE with lagged TFP                : Nickell bias of order 1/T (T=9 -> sizeable)
*  AH     Anderson-Hsiao IV in differences  : consistent but inefficient (level
*                                             instrument y(t-2); first-stage F shown)
*  AB     Arellano-Bond difference GMM      : weak instruments when TFP is persistent
*  SYS    Blundell-Bond system GMM          : adds level equation; N=34 so keep the
*                                             instrument count below N (collapse)
*  LSDVC  bias-corrected LSDV (Kiviet/Bruno) : designed for small N; Monte Carlo
*                                             evidence favours it over GMM when N~34
*  OLS/FE bounds: the lagged-TFP coefficient of a valid GMM should lie between the
*                 FE (downward biased) and pooled OLS (upward biased) estimates
*
* Post-estimation tests supplied per model:
*  POLS  : VIF, Breusch-Pagan/Cook-Weisberg, RESET, Wooldridge serial corr, BP-LM
*  FE    : F test for u_i = 0, Hausman (classic + robust), modified Wald (xttest3),
*          Wooldridge (xtserial), Pesaran/Frees/Friedman CD (xtcsd), year effects,
*          residual normality; panel unit roots (HT, LLC, Breitung, IPS, Fisher) and
*          cointegration (Kao, Pedroni, Westerlund) before estimation
*  RE    : Breusch-Pagan LM (xttest0), Hausman, Sargan-Hansen overid (xtoverid),
*          Mundlak joint test, theta
*  FGLS  : LR test for groupwise heteroskedasticity
*  GMM   : Arellano-Bond AR(1)/AR(2), Sargan, Hansen, difference-in-Hansen,
*          instrument count vs N, OLS/FE bounds check, long-run multipliers

version 17
clear all
set more off
set seed 12345
capture log close

*** 0. Setup ---------------------------------------------------------------------
* Prefer the copy in 02 Code/TFP/. This file is kept so old paths still resolve.
if `"${proj}"' == "" {
	if fileexists("2026bkpm.Rproj") {
		global proj "`c(pwd)'"
	}
	else if fileexists("../2026bkpm.Rproj") {
		global proj "`c(pwd)'/.."
	}
	else if fileexists("../../2026bkpm.Rproj") {
		global proj "`c(pwd)'/../.."
	}
	else {
		global proj "/Users/athamawardi/Desktop/Research-Projects/RDSI_Kemeninves"
	}
}

global datadir "${proj}/01 Data/TFP/AI-Pak_Yudis"
global outdir  "${proj}/01 Data/TFP/output/determinan"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "${outdir}"

global data "${datadir}/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
global out  "${outdir}/Determinan TFP Results.xlsx"
global tab  "${outdir}/Determinan TFP Tables"

display as text "proj = $proj"
display as text "data = $data"
if !fileexists("${data}") {
	display as error "data file not found: $data"
	exit 601
}
log using "${outdir}/Determinan TFP Provinsi BKPM.log", replace text

** analysis switches (change here, rerun everything)
global depvar    logtfp_it      // dependent variable; alternative: logtfp_it_crs
global pca_mode  pooled         // pooled : standardise over the whole panel (keeps time variation)
                                // byyear : standardise within each year first ("z dalam tahun",
                                //          the convention of Institusi_Prov / Konektivitas_Prov)
global idx_scale z              // z   : PC1 scores with mean 0 sd 1 (coef = effect of +1 sd)
                                // 100 : min-max rescaled 0-100 (coef = effect of +1 point)
global ind_proxy C_TenagaKerja  // used ONLY if Industry_Prov (Jumlah PT) is absent from the sheet
global use_logs  1              // 1: log skewed count/level indicators before PCA, 0: raw
global mixed_rule pca           // pca : always use PC1 (as requested) even if some inputs load
                                //       against the anchor (a warning is printed)
                                // eq  : for a pillar with mixed-polarity PC1, use the equal-weight
                                //       additive index idx_*_eq instead (polarity enforced)
global fmt cformat(%9.3f) pformat(%5.3f) sformat(%8.3f)

** user-written packages (installed once; capture keeps the file running offline)
foreach pkg in xtscc xtabond2 xtserial xtcsd xttest3 xtoverid xtlsdvc estout {
	local cmd `pkg'
	if "`pkg'" == "estout" local cmd esttab
	capture which `cmd'
	if _rc {
		display as text "installing `pkg' from SSC ..."
		capture ssc install `pkg', replace
	}
}
capture which xtscc
global have_xtscc = (_rc == 0)
capture which xtabond2
global have_xtabond2 = (_rc == 0)
capture which xtoverid
global have_xtoverid = (_rc == 0)
capture which esttab
global have_esttab = (_rc == 0)
capture which xtlsdvc
global have_xtlsdvc = (_rc == 0)

*** 1. Import and labels --------------------------------------------------------
import excel "$data", sheet("Analisis Luaran 2") firstrow clear
drop if missing(Code_Prov) | missing(Year)
display as text "imported: " c(k) " variables, " c(N) " observations (empty Code_Prov/Year rows dropped)"

** variable labels from sheet "Keterangan Data Luaran 2" (trimmed to 80 chars)
label variable Code_Prov        "Kode Provinsi"
label variable Year             "Tahun"
label variable Prov             "Nama Provinsi"
label variable Airpot_Total     "Total jumlah bandara menurut provinsi (jumlah)"
label variable Airpot_Logis     "Jumlah bandara berstatus logistik (jumlah)"
label variable Airpot_Commer    "Jumlah bandara berstatus komersial (jumlah)"
label variable Campus_Prov      "Total jumlah kampus menurut provinsi (jumlah)"
label variable Vocational_Prov  "Jumlah kampus yang memiliki sekolah vokasi (jumlah)"
label variable PMA_1            "Penanaman Modal Asing menurut provinsi (Rp miliar)"
label variable PMDN_1           "Penanaman Modal Dalam Negeri menurut provinsi (Rp miliar)"
label variable pmtb             "PDRB Pembentukan Modal Tetap Bruto, ADHB (Rp miliar)"
label variable pmtb_1           "PDRB Pembentukan Modal Tetap Bruto, ADHK 2010 (Rp miliar)"
label variable APK_Primer       "Angka Partisipasi Kasar SD (%)"
label variable APK_Sekunder1    "Angka Partisipasi Kasar SMP (%)"
label variable APK_Sekunder2    "Angka Partisipasi Kasar SMA (%)"
label variable APK_Tersier      "Angka Partisipasi Kasar Perguruan Tinggi (%)"
label variable Heduc_Prov       "Harapan Lama Sekolah, metode baru (tahun)"
label variable Educ_Prov        "Rata-rata Lama Sekolah (tahun)"
label variable IDI_Prov2        "Indeks Demokrasi Indonesia, proxy penjumlahan metode baru 2021 (0-100)"
label variable IDI_Prov         "Indeks Demokrasi Indonesia (2017-20 metode lama, 2021-25 metode baru)"
label variable IKG_Prov         "Indeks Ketimpangan Gender (0-1, lebih tinggi = lebih timpang)"
label variable Grwth1_Prov      "Pertumbuhan ekonomi PDRB nominal ADHB (%)"
label variable Grwth2_Prov      "Pertumbuhan ekonomi PDRB riil ADHK 2010 (%)"
label variable IPM_Prov         "Indeks Pembangunan Manusia"
label variable IPM_Prov_Nm      "Indeks Pembangunan Manusia, metode baru"
label variable TPT_Prov         "Tingkat Pengangguran Terbuka, Agustus (%)"
label variable Ikk_Prov         "Indeks Kedalaman Kemiskinan (P1)"
label variable Ikkk_Porv        "Indeks Keparahan Kemiskinan (P2)"
label variable Gk_Prov          "Garis Kemiskinan (Rp)"
label variable P0_Prov          "Persentase penduduk miskin (%)"
label variable Gini_Prov        "Indeks Gini, kota+desa, semester 1 (Maret)"
label variable AHH_Prov         "Angka Harapan Hidup, laki-laki dan perempuan (tahun)"
label variable Road_Prov        "Total panjang jalan negara+provinsi+kab/kota (km)"
label variable Road_Prov_National "Panjang jalan nasional (km)"
label variable RoadC_Prov_National "Persentase kemantapan jalan nasional (%)"
label variable Crime_Prov       "Jumlah tindak pidana menurut Polda (kasus)"
label variable Crime2_Prov      "Tindak pidana per 100 ribu penduduk (rasio)"
label variable ABC1_Prov        "Angka buta huruf usia 15+ (%)"
label variable ABC2_Prov        "Angka buta huruf usia 15-44 (%)"
label variable ABC3_Prov        "Angka buta huruf usia 45+ (%)"
label variable TK_Prov          "Total pekerja 17 lapangan usaha (jiwa)"
label variable Upah_Agr_Prov    "Upah bersih/bulan, rata-rata tertimbang 17 sektor; 2025 proyeksi UMP (Rp)"
label variable PAD_Prov2        "PAD realisasi DJPK, agregat pemda se-provinsi (Rp)"
label variable Pendapatan_APBD_Prov "Pendapatan daerah realisasi DJPK (Rp miliar)"
label variable Belanja_APBD_Prov "Belanja daerah realisasi DJPK (Rp miliar)"
label variable RasioPAD_Prov    "Rasio PAD / pendapatan daerah"
label variable Serapan_Prov     "Serapan belanja: realisasi/anggaran belanja DJPK (%)"
label variable log_lab_tot      "log total tenaga kerja"
label variable logtfp_it        "log TFP per provinsi-tahun (dari fungsi produksi panel)"
label variable logtfp_it_crs    "log TFP per provinsi-tahun, constant returns to scale"
label variable g_Y              "Pertumbuhan output (%)"
label variable g_K              "Pertumbuhan modal (%)"
label variable g_L              "Pertumbuhan tenaga kerja (%)"
label variable kontrib_modal    "Kontribusi modal pada pertumbuhan (pp)"
label variable kontrib_tk       "Kontribusi tenaga kerja pada pertumbuhan (pp)"
label variable kontrib_tfp      "Kontribusi TFP pada pertumbuhan (pp)"
label variable PDBDeflator      "PDB deflator menurut provinsi (poin)"
label variable PAX_Udara        "Penumpang udara domestik, alokasi nasional (orang)"
label variable PAX_KA           "Penumpang kereta api, 0 jika tanpa jaringan (orang)"
label variable PAX_Kapal        "Penumpang laut domestik, alokasi (orang)"
label variable PAX_Bus          "Penumpang bus, alokasi (orang)"
label variable Cargo_Udara_Prov "Kargo udara, alokasi (juta ton)"
label variable Cargo_Kapal_Prov "Kargo laut, alokasi (juta ton)"
label variable Cargo_KA_Prov    "Kargo kereta api, alokasi (juta ton)"
label variable Cargo_Total      "Total kargo kapal+udara+KA (juta ton)"
label variable Konektivitas_Prov "PC1 PCA konektivitas, z dalam tahun (0-100)"
label variable IKLH_Prov        "Indeks Kualitas Lingkungan Hidup (0-100)"
label variable Hijau_Prov       "Indeks Kualitas Tutupan Lahan / hijau (0-100); 2017-20 = nilai 2020"
label variable Biru_Prov        "Indeks Kualitas Air / biru (0-100)"
label variable Institusi_Prov   "PC1 PCA kapasitas institusi, z dalam tahun (0-100)"
label variable PAD_Prov         "Pendapatan Asli Daerah menurut provinsi (Rp)"
** 17-sector wage and employment labels
local sec_A    "Pertanian, Kehutanan, Perikanan"
local sec_B    "Pertambangan dan Penggalian"
local sec_C    "Industri Pengolahan"
local sec_D    "Pengadaan Listrik dan Gas"
local sec_E    "Pengadaan Air, Sampah, Limbah, Daur Ulang"
local sec_F    "Konstruksi"
local sec_G    "Perdagangan Besar-Eceran, Reparasi Mobil-Motor"
local sec_H    "Transportasi dan Pergudangan"
local sec_I    "Akomodasi dan Makan Minum"
local sec_J    "Informasi dan Komunikasi"
local sec_K    "Jasa Keuangan dan Asuransi"
local sec_L    "Real Estat"
local sec_MN   "Jasa Perusahaan"
local sec_O    "Adm. Pemerintahan, Pertahanan, Jamsos Wajib"
local sec_P    "Jasa Pendidikan"
local sec_Q    "Jasa Kesehatan dan Kegiatan Sosial"
local sec_RSTU "Jasa Lainnya"
foreach s in A B C D E F G H I J K L MN O P Q RSTU {
	label variable `s'_RataUpah    "Upah rata-rata `sec_`s'' (Rp/bulan)"
	label variable `s'_TenagaKerja "Tenaga kerja `sec_`s'' (jiwa)"
}

*** 2. Panel structure ----------------------------------------------------------
isid Code_Prov Year                      // one row per province-year
** province names as value labels of the numeric id
qui levelsof Code_Prov, local(codes)
foreach c of local codes {
	qui levelsof Prov if Code_Prov == `c', local(nm)
	label define prov_lbl `c' `nm', add
}
label values Code_Prov prov_lbl
xtset Code_Prov Year
xtdescribe
** year dummies (explicit dummies so that xtoverid / xtabond2 / xtserial accept them)
forvalues y = 2018/2025 {
	gen byte yr`y' = (Year == `y')
	label variable yr`y' "Year = `y'"
}
global yrd yr2018 yr2019 yr2020 yr2021 yr2022 yr2023 yr2024 yr2025
** models that lose 2017 (lagged TFP, AR(1) transformation) use 2018 as the reference
** year; passing all eight dummies would make Stata drop a different one in each model
global yrd_dyn yr2019 yr2020 yr2021 yr2022 yr2023 yr2024 yr2025

** data sanity: out-of-range entries in the sheet are reported, not silently kept
**   (in the 2025-08 sheet ABC1_Prov = 2135 for Papua Barat 2024; Hijau_Prov is
**    back-filled with the 2020 value for 2017-2019 in every province)
foreach v in APK_Primer APK_Sekunder1 APK_Sekunder2 APK_Tersier TPT_Prov P0_Prov ///
	ABC1_Prov ABC2_Prov ABC3_Prov IKLH_Prov Hijau_Prov Biru_Prov IDI_Prov2 IDI_Prov {
	qui count if `v' < 0 | `v' > 120
	if r(N) > 0 {
		display as error "warning: `v' has " r(N) " value(s) outside 0-120:"
		list Code_Prov Prov Year `v' if `v' < 0 | `v' > 120, noobs abbreviate(12)
	}
}
qui count if Gini_Prov < 0 | Gini_Prov > 1
if r(N) > 0 display as error "warning: Gini_Prov outside 0-1 in " r(N) " row(s)"

*** 3. Variable construction ----------------------------------------------------
** 3a. the legend names the institution / connectivity inputs rasio_pad,
**     serapan_belanja and jalan_mantap_pct; the data sheet stores the same series as
**     RasioPAD_Prov, Serapan_Prov and RoadC_Prov_National. Use the legend names.
capture confirm variable rasio_pad
if _rc rename RasioPAD_Prov rasio_pad
capture confirm variable serapan_belanja
if _rc rename Serapan_Prov serapan_belanja
capture confirm variable jalan_mantap_pct
if _rc rename RoadC_Prov_National jalan_mantap_pct
label variable rasio_pad        "Rasio PAD / pendapatan daerah"
label variable serapan_belanja  "Serapan belanja: realisasi/anggaran belanja DJPK (%)"
label variable jalan_mantap_pct "Persentase jalan nasional mantap (%)"

** 3b. education gap: mean years of schooling minus expected years of schooling
gen double Educ_Heduc = Educ_Prov - Heduc_Prov
label variable Educ_Heduc "Educ_Prov - Heduc_Prov: RLS dikurangi HLS (tahun, negatif = gap)"

** 3c. industry pillar input: Industry_Prov (Jumlah PT) is described in the legend
**     but the sheet "Analisis Luaran 2" has no such column. If it is added later the
**     block below picks it up automatically; until then a proxy is used and flagged.
capture confirm variable Industry_Prov
if _rc == 0 {
	gen double ind_firms = Industry_Prov
	label variable ind_firms "Jumlah PT (Perseroan Terbatas) menurut provinsi"
	global ind_is_proxy 0
}
else {
	display as error _n "NOTE: Industry_Prov (Jumlah PT) is not in sheet 'Analisis Luaran 2'." ///
		_n "      Industry pillar uses the PROXY ${ind_proxy} instead." ///
		_n "      Add the column to the sheet (or change global ind_proxy) and rerun." _n
	gen double ind_firms = ${ind_proxy}
	label variable ind_firms "PROXY for Industry_Prov (Jumlah PT): ${ind_proxy}"
	global ind_is_proxy 1
	* with this proxy the two industry inputs are nearly uncorrelated (Bartlett p ~ 0.18,
	* alpha ~ 0.14 in the 2025-08 run), so idx_ind is weak until the real column exists
}

** 3d. PCA inputs. Skewed counts/levels are logged (switch use_logs); indicators whose
**     higher value is 'worse' are reverse-coded (negated) so that, within a pillar,
**     every input points the same way and PC1 reads as 'higher = better'.
if $use_logs {
	gen double ln_campus   = ln(Campus_Prov)
	gen double ln_airport  = ln(Airpot_Total)
	gen double ln_cargo    = ln(Cargo_Total)
	gen double ln_wage     = ln(Upah_Agr_Prov)
	gen double ln_firms    = ln(ind_firms)
	gen double ln_crime    = ln(Crime2_Prov)
}
else {
	gen double ln_campus   = Campus_Prov
	gen double ln_airport  = Airpot_Total
	gen double ln_cargo    = Cargo_Total
	gen double ln_wage     = Upah_Agr_Prov
	gen double ln_firms    = ind_firms
	gen double ln_crime    = Crime2_Prov
}
gen double neg_gini     = -Gini_Prov
gen double neg_crime    = -ln_crime
gen double neg_deflator = -PDBDeflator
label variable ln_campus    "ln jumlah kampus"
label variable ln_airport   "ln jumlah bandara"
label variable ln_cargo     "ln total kargo"
label variable ln_wage      "ln upah rata-rata tertimbang"
label variable ln_firms     "ln Industry_Prov / proxy"
label variable ln_crime     "ln tindak pidana per 100 ribu penduduk"
label variable neg_gini     "minus Gini (higher = more equal)"
label variable neg_crime    "minus ln crime rate (higher = safer)"
label variable neg_deflator "minus PDB deflator (higher = lower price level)"

** pillar definitions: inputs and the anchor used to orient the sign of PC1
global hr_vars     Educ_Prov ln_campus IPM_Prov_Nm neg_gini
global hr_anchor   IPM_Prov_Nm
global inst_vars   neg_deflator rasio_pad serapan_belanja neg_crime IDI_Prov2
global inst_anchor rasio_pad
global conn_vars   jalan_mantap_pct ln_airport ln_cargo
global conn_anchor jalan_mantap_pct
global ind_vars    ln_wage ln_firms
global ind_anchor  ln_wage

*** 4. Descriptive statistics ---------------------------------------------------
summarize $depvar logtfp_it_crs $hr_vars $inst_vars $conn_vars $ind_vars ///
	IKLH_Prov Hijau_Prov Biru_Prov Educ_Heduc, separator(0)
xtsum $depvar $hr_vars $inst_vars $conn_vars $ind_vars IKLH_Prov Hijau_Prov Biru_Prov
table Year, statistic(mean $depvar) statistic(sd $depvar) statistic(min $depvar) statistic(max $depvar) nformat(%9.3f)
correlate $hr_vars $inst_vars $conn_vars $ind_vars IKLH_Prov Hijau_Prov Biru_Prov
capture noisily {
	xtline $depvar, overlay legend(off) title("log TFP per province, 2017-2025") ///
		ytitle("$depvar") name(tfp_lines, replace)
	graph export "$outdir/Determinan TFP - TFP lines.png", replace width(1600)
}

*** 5. Pillar indices by PCA ----------------------------------------------------
* For each pillar: standardise inputs (pooled or within-year), Bartlett sphericity,
* KMO, Cronbach alpha, PCA, eigenvalues, loadings, scree plot, PC1 score oriented by
* the anchor variable, then z-score (idx_*) and 0-100 (idx_*_100) versions.
capture erase "$out"
putexcel set "$out", sheet("README") replace
putexcel A1 = "Determinan TFP Provinsi BKPM - results workbook"
putexcel A2 = "Sheets PCA_*: eigenvalues, loadings, KMO, Bartlett, alpha per pillar"
putexcel A3 = "Sheet Indices: Code_Prov Prov Year and the four pillar indices"
putexcel A4 = "Sheet Diagnostics: post-estimation test statistics of the panel models"
putexcel A5 = "pca_mode = $pca_mode, idx_scale = $idx_scale, depvar = $depvar, Industry proxy = $ind_is_proxy"

capture program drop build_index
program define build_index
	* syntax: build_index name, vars(varlist) anchor(varname) title(string)
	syntax name(name=idx), vars(varlist) anchor(varname) [title(string)]
	display as text _n "{hline 78}" _n "PCA pillar: `idx'  (`title')" _n "inputs: `vars'" _n "{hline 78}"
	* 5a. standardised inputs z_*
	local zvars
	foreach v of varlist `vars' {
		capture drop z_`v'
		if "$pca_mode" == "byyear" {
			tempvar m s
			bysort Year: egen double `m' = mean(`v')
			bysort Year: egen double `s' = sd(`v')
			gen double z_`v' = (`v' - `m') / `s'
		}
		else {
			egen double z_`v' = std(`v')
		}
		local zvars `zvars' z_`v'
	}
	local p : word count `zvars'
	* 5b. Bartlett test of sphericity: H0 correlation matrix = identity
	qui correlate `zvars'
	matrix R = r(C)
	local n = r(N)
	local chi2 = -(`n' - 1 - (2*`p' + 5)/6) * ln(det(R))
	local df   = `p'*(`p' - 1)/2
	local pb   = chi2tail(`df', `chi2')
	display as text "Bartlett sphericity: chi2(`df') = " as result %9.2f `chi2' as text "  p = " as result %6.4f `pb'
	if `pb' > 0.05 display as error "warning: Bartlett does not reject sphericity for `idx': the inputs are nearly " ///
		"uncorrelated, so PC1 is not a meaningful common factor (check the inputs / proxy)"
	* 5c. Cronbach alpha (standardised items)
	qui alpha `zvars', std
	local calpha = r(alpha)
	display as text "Cronbach alpha (std items): " as result %6.3f `calpha'
	if `calpha' < 0.5 display as error "warning: Cronbach alpha below 0.5 for `idx' (inputs share little common variance)"
	* 5d. PCA (correlation matrix), keep the first component
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
	display as text "eigenvalue PC1 = " as result %6.3f `ev1' as text "  share explained = " as result %5.1f 100*`prop1' "%" ///
		as text "  components with eigenvalue > 1 = " as result `nkaiser' as text "  KMO = " as result %5.3f `kmo'
	if `prop1' < 0.5 display as error "warning: PC1 explains less than half of the variance of `idx'"
	if `kmo' < 0.5  display as error "warning: KMO below 0.5 for `idx' (sampling adequacy is poor)"
	capture noisily {
		screeplot, name(scree_`idx', replace) title("Scree plot: `idx'")
		graph export "$outdir/Determinan TFP - scree `idx'.png", replace width(1200)
	}
	* 5e. scores, sign orientation by the anchor loading
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
	* polarity check: every input was coded so that 'higher = better'; a negative
	* oriented loading means PC1 mixes good and bad directions of that input
	local nneg = 0
	forvalues j = 1/`p' {
		if L1[`j',1] < 0 local ++nneg
	}
	global pca_`idx'_nneg = `nneg'
	if `nneg' > 0 display as error "warning: `nneg' input(s) of `idx' load with the opposite sign on PC1 " ///
		"(mixed polarity); compare with the additive index idx_`idx'_eq"
	* 5f. index versions: PC1 z-score, PC1 0-100, and an equal-weight additive
	*     z-score index (OECD/JRC fallback when PCA polarity is inconsistent)
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
	label variable idx_`idx'_eq  "Index `idx' (equal-weight mean of z inputs, mean 0 sd 1)"
	* 5g. write the PCA summary to the results workbook
	* no 'replace' on the sheet: with sheet(..., replace) the first putexcel write after
	* 'set' is discarded in Stata 17; the workbook is recreated at the start of section 5
	putexcel set "$out", sheet("PCA_`idx'") modify
	putexcel A1 = "Pillar `idx': `title'"
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
	* keep the statistics for the diagnostics sheet
	global pca_`idx'_ev1 = `ev1'
	global pca_`idx'_prop = `prop1'
	global pca_`idx'_kmo = `kmo'
	global pca_`idx'_bart_p = `pb'
	global pca_`idx'_alpha = `calpha'
end

build_index hr,   vars($hr_vars)   anchor($hr_anchor)   title("Human resource")
build_index inst, vars($inst_vars) anchor($inst_anchor) title("Institution")
build_index conn, vars($conn_vars) anchor($conn_anchor) title("Connectivity")
build_index ind,  vars($ind_vars)  anchor($ind_anchor)  title("Industry")

** the regressors actually used: z-score or 0-100 version of each index; with
** mixed_rule = eq a pillar whose PC1 has mixed polarity is replaced by its additive index
global pillars
foreach p in hr inst conn ind {
	local v idx_`p'
	if "$idx_scale" == "100" local v idx_`p'_100
	if "$mixed_rule" == "eq" & ${pca_`p'_nneg} > 0 {
		local v idx_`p'_eq
		display as text "mixed_rule = eq: pillar `p' uses the additive index `v'"
	}
	global pillars $pillars `v'
}
global env IKLH_Prov Hijau_Prov Biru_Prov
global X  $pillars $env
display as text _n "regressors: $X"
summarize $X, separator(0)
correlate $depvar $X
** how the new indices relate to the pre-built ones in the sheet
correlate idx_inst Institusi_Prov idx_conn Konektivitas_Prov
** Mundlak group means of the regressors (for the CRE model)
global Xbar
foreach v of global X {
	capture drop m_`v'
	bysort Code_Prov: egen double m_`v' = mean(`v')
	label variable m_`v' "province mean of `v'"
	global Xbar $Xbar m_`v'
}

*** 6. Pre-estimation diagnostics ----------------------------------------------
** 6a. panel unit roots. T = 9 is short: Harris-Tzavalis (fixed T, N -> inf) is the
**     most appropriate; LLC / IPS / Fisher-ADF are shown for completeness and
**     their asymptotics (T -> inf) are NOT satisfied here - read with care.
**     Level variables such as log TFP trend upward, so the 'trend' variants are
**     also shown. p close to 1 = no evidence at all against a unit root; IPS is
**     missing when an input is constant within some province (e.g. Hijau_Prov).
local urvars $depvar $X
local nv : word count `urvars'
matrix UR = J(`nv', 6, .)
matrix rownames UR = `urvars'
matrix colnames UR = HT_p HT_trend_p LLC_p Breitung_p IPS_p FisherADF_p
local i = 0
foreach v of local urvars {
	local ++i
	capture xtunitroot ht `v'
	if _rc == 0 matrix UR[`i',1] = r(p)
	capture xtunitroot ht `v', trend
	if _rc == 0 matrix UR[`i',2] = r(p)
	capture xtunitroot llc `v', lags(1)
	if _rc == 0 matrix UR[`i',3] = r(p_tds)
	capture xtunitroot breitung `v'
	if _rc == 0 matrix UR[`i',4] = r(p)
	capture xtunitroot ips `v', lags(1)
	if _rc == 0 matrix UR[`i',5] = r(p_wtbar)
	capture xtunitroot fisher `v', dfuller lags(1)
	if _rc == 0 matrix UR[`i',6] = r(p_P)
}
display as text _n "panel unit-root tests, p-values (H0: panels contain unit roots)"
matlist UR, format(%8.3f)
putexcel set "$out", sheet("UnitRoot") modify
putexcel A1 = "Panel unit-root p-values; HT = Harris-Tzavalis (suited to T=9), others need large T"
putexcel A2 = matrix(UR), names

** 6a'. panel cointegration (Kao, Pedroni, Westerlund). With T = 9 these tests, like
**      the unit-root tests, have weak asymptotic justification; they are reported so
**      that the levels regressions can be defended (or an ECM chosen) explicitly.
capture noisily xtcointtest kao $depvar $X
if _rc == 0 {
	matrix CP = r(p)                         // columns: MDF, DF, ADF, unadjusted MDF, unadjusted DF
	global p_kao_df = CP[1,2]
}
capture noisily xtcointtest pedroni $depvar $X
if _rc == 0 {
	matrix CP = r(p)                         // columns: modified PP, PP, ADF
	global p_pedroni_adf = CP[1,3]
}
capture noisily xtcointtest westerlund $depvar $X
if _rc == 0 global p_westerlund = r(p)

** 6b. multicollinearity among the regressors (pooled)
qui regress $depvar $X
estat vif

*** 7. Static panel models ------------------------------------------------------
** 7.1 Pooled OLS, cluster-robust by province
regress $depvar $X $yrd, vce(cluster Code_Prov) $fmt
estimates store POLS
qui regress $depvar $X $yrd
estat hettest                                // Breusch-Pagan / Cook-Weisberg heteroskedasticity
global p_bp_hettest = r(p)
estat ovtest                                 // Ramsey RESET functional form
global p_reset = r(p)
xtserial $depvar $X $yrd                     // Wooldridge test for AR(1) in panel data
global p_xtserial = r(p)

** 7.2 Fixed effects (within), province effects only
xtreg $depvar $X, fe $fmt                    // non-robust: carries the F test for u_i = 0
estimates store FE_nr
global F_ui = e(F_f)
global p_F_ui = Ftail(e(df_a), e(df_r), e(F_f))
display as text "F test that all u_i = 0: F(" e(df_a) ", " e(df_r) ") = " as result %8.3f e(F_f) as text "  p = " as result %6.4f ${p_F_ui}
xttest3                                      // modified Wald: groupwise heteroskedasticity in FE residuals
global p_xttest3 = r(p)
xtcsd, pesaran abs                           // Pesaran CD test for cross-sectional dependence
global cd_pesaran = r(pesaran)               // xtcsd returns the statistics only; CD ~ N(0,1)
global p_cd_pesaran = 2 * (1 - normal(abs(r(pesaran))))
xtcsd, frees                                 // Frees Q; critical values printed by xtcsd depend on T
global cd_frees = r(frees)
global cd_frees_crit01 = .
if e(g_max) == 9 & e(g_min) == 9 global cd_frees_crit01 = 0.5811   // Frees (1995) Q, T = 9, alpha = 0.01
global cd_frees_reject = cond(${cd_frees_crit01} < ., ${cd_frees} > ${cd_frees_crit01}, .)
xtcsd, friedman                              // Friedman's FR ~ chi2(T - 1), not chi2(N - 1)
global cd_friedman = r(fried)                //   (the Pr printed by xtcsd uses N - 1 and is too large)
global p_cd_friedman = chi2tail(e(g_max) - 1, r(fried))
predict double e_fe, e
sktest e_fe                                  // residual normality (skewness/kurtosis)
global p_sk_fe = r(P_chi2)
drop e_fe
xtreg $depvar $X, fe vce(cluster Code_Prov) $fmt
estimates store FE

** 7.3 Two-way fixed effects: province + year
xtreg $depvar $X $yrd, fe $fmt
estimates store FE2W_nr
testparm $yrd                                // joint significance of the year effects
global p_yeareff = r(p)
xtcsd, pesaran abs                           // CD after removing common year shocks
global cd_pesaran_2w = r(pesaran)
global p_cd_pesaran_2w = 2 * (1 - normal(abs(r(pesaran))))
xtreg $depvar $X $yrd, fe vce(cluster Code_Prov) $fmt
estimates store FE2W
testparm $yrd
global p_yeareff_cl = r(p)

** 7.4 Random effects (Swamy-Arora), one-way and two-way
xtreg $depvar $X, re theta $fmt
estimates store RE_nr
xttest0                                      // Breusch-Pagan LM: var(u_i) = 0 (pooled OLS vs RE)
global p_xttest0 = r(p)
hausman FE_nr RE_nr, sigmamore               // classic Hausman, one-way
global h_chi2 = r(chi2)
global p_hausman = r(p)
xtreg $depvar $X, re vce(cluster Code_Prov) $fmt
estimates store RE
if $have_xtoverid {
	capture noisily xtoverid                 // Sargan-Hansen overid = cluster-robust Hausman
	if _rc == 0 global p_xtoverid = r(jp)
}
xtreg $depvar $X $yrd, re $fmt
estimates store RE2W_nr
hausman FE2W_nr RE2W_nr, sigmamore           // Hausman, two-way
global p_hausman_2w = r(p)
xtreg $depvar $X $yrd, re vce(cluster Code_Prov) $fmt
estimates store RE2W
if $have_xtoverid {
	capture noisily xtoverid
	if _rc == 0 global p_xtoverid_2w = r(jp)
}

** 7.5 Mundlak correlated random effects: RE + province means of the regressors.
**     Joint test on the means is a cluster-robust Hausman test (H0: RE is adequate).
xtreg $depvar $X $Xbar $yrd, re vce(cluster Code_Prov) $fmt
estimates store CRE
test $Xbar
global p_mundlak = r(p)

** 7.6 FE and RE with AR(1) disturbances (xtregar): Bhargava et al. modified DW and
**     Baltagi-Wu LBI are reported; values far below 2 indicate serial correlation
xtregar $depvar $X $yrd_dyn, fe lbi $fmt        // first wave is lost: 2018 is the base year
estimates store FE_AR1
global dw_bhargava = e(d1)
global lbi_baltagi = e(LBI)
global rho_ar1 = e(rho_ar)
xtregar $depvar $X $yrd_dyn, re lbi $fmt
estimates store RE_AR1

** 7.7 FGLS with panel-specific heteroskedasticity and common AR(1).
**     N = 34 > T = 9, so panels(correlated) is not estimable.
xtgls $depvar $X $yrd, panels(heteroskedastic) corr(ar1) $fmt
estimates store FGLS
**     LR test for groupwise heteroskedasticity (iid vs heteroskedastic panels, iterated
**     GLS). With the year dummies the iterated heteroskedastic fit does not converge on
**     this panel (one panel variance collapses, coefficients get omitted, ll below the
**     iid model), so the test is run on the specification without year dummies and is
**     only reported when both fits have full rank and ll_het > ll_iid.
xtgls $depvar $X, igls panels(heteroskedastic) nolog
estimates store FGLS_het
local rank_het = e(rank)
local ll_het = e(ll)
xtgls $depvar $X, igls nolog
estimates store FGLS_iid
local rank_iid = e(rank)
local ll_iid = e(ll)
local df = e(N_g) - 1
if `rank_het' == `rank_iid' & `ll_het' > `ll_iid' {
	lrtest FGLS_het FGLS_iid, df(`df')
	global p_lr_het = r(p)
}
else {
	display as error "LR test for groupwise heteroskedasticity not reported: iterated GLS did not converge"
	global p_lr_het = .
}

** 7.8 Panel-corrected standard errors (Beck-Katz) on the LSDV (province + year dummies):
**     full PCSE (contemporaneous cross-panel covariance, 34x33/2 = 561 covariances estimated
**     from T = 9: feasible because the sandwich does not invert Sigma, but imprecise),
**     plus the heteroskedasticity-only variant
xtpcse $depvar $X $yrd i.Code_Prov, corr(ar1) $fmt
estimates store PCSE
xtpcse $depvar $X $yrd i.Code_Prov, hetonly corr(ar1) $fmt
estimates store PCSE_het

** 7.9 Driscoll-Kraay standard errors with fixed effects (robust to cross-sectional
**     dependence, heteroskedasticity and autocorrelation up to lag 2). The estimator
**     relies on T -> infinity; with T = 9 read it as indicative only.
if $have_xtscc {
	xtscc $depvar $X $yrd, fe lag(2)
	estimates store DK
}
else display as error "xtscc not available: Driscoll-Kraay model skipped"

*** 8. Dynamic panel models -----------------------------------------------------
** 8.1 bounds: pooled OLS with lagged TFP (upper bound) and FE-LDV (lower bound)
regress $depvar L.$depvar $X $yrd_dyn, vce(cluster Code_Prov) $fmt
estimates store OLS_LDV
global rho_ols = _b[L.$depvar]
xtreg $depvar L.$depvar $X $yrd_dyn, fe vce(cluster Code_Prov) $fmt
estimates store FE_LDV
global rho_fe = _b[L.$depvar]

** 8.2 Anderson-Hsiao: first-difference equation, D.L.y instrumented by the LEVEL y(t-2).
**     (xtivreg, fd would difference the instrument too and use y(t-2)-y(t-3), the less
**     efficient variant.) Cluster-robust SE; the first-stage F shows instrument strength.
ivregress 2sls D.$depvar D.($X) D.($yrd_dyn) (LD.$depvar = L2.$depvar), vce(cluster Code_Prov) $fmt
estimates store AH
global rho_ah = _b[LD.$depvar]
estat firststage
matrix FS = r(singleresults)
global F_ah_first = FS[1,4]

** 8.3 Arellano-Bond difference GMM (official xtabond), two-step, Windmeijer-robust
**     maxldep(3) gives 33 instruments (just below N = 34) and a stable two-step
**     estimate; maxldep(2) (28 instruments) produced a degenerate robust VCE here
xtabond $depvar $X $yrd_dyn, lags(1) maxldep(3) twostep vce(robust)
global rho_ab = _b[L.$depvar]
global j_ab = e(zrank)
if e(zrank) >= e(N_g) display as error "warning: xtabond uses " e(zrank) " instruments for " e(N_g) " provinces"
estat abond                                  // AR(1) expected, AR(2) must NOT be rejected
matrix ARM = r(arm)
global p_ar1_ab = ARM[1,3]
global p_ar2_ab = ARM[2,3]
estadd scalar j = e(zrank)                   // so the esttab rows line up with xtabond2
estadd scalar ar2p = ARM[2,3]
estimates store AB
qui xtabond $depvar $X $yrd_dyn, lags(1) maxldep(3) twostep
estat sargan                                 // Sargan (needs the non-robust two-step);
                                             // estat sargan stores no r() results: read p here

** 8.4 Blundell-Bond system GMM (official xtdpdsys)
**     maxldep(1) keeps the instrument count (29) below N = 34; maxldep(3) gives 40
**     instruments, a singular two-step weight matrix and meaningless SE
xtdpdsys $depvar $X $yrd_dyn, lags(1) maxldep(1) twostep vce(robust)
global rho_sys = _b[L.$depvar]
global j_sys = e(zrank)
if e(zrank) >= e(N_g) display as error "warning: xtdpdsys uses " e(zrank) " instruments for " e(N_g) " provinces"
estat abond
matrix ARM = r(arm)
global p_ar1_sys = ARM[1,3]
global p_ar2_sys = ARM[2,3]
estadd scalar j = e(zrank)
estadd scalar ar2p = ARM[2,3]
estimates store SYS
qui xtdpdsys $depvar $X $yrd_dyn, lags(1) maxldep(1) twostep
estat sargan

** 8.5 xtabond2: collapsed instruments (instrument count must stay below N = 34),
**     Hansen J, difference-in-Hansen, Windmeijer small-sample correction.
**     lag() limits in gmm() refer to the variable as listed: gmm(L.y, lag(1 3)) uses
**     y(t-2)..y(t-4) in the difference equation and D.y(t-1) in the level equation.
**     iv(X) without eq() instruments both equations (D.X in differences, X in levels).
**     (a) regressors treated as strictly exogenous, difference GMM
**     (b) system GMM, regressors exogenous
**     (c) system GMM, pillar indices treated as predetermined (instrumented by own lags)
if $have_xtabond2 {
	xtabond2 $depvar L.$depvar $X $yrd_dyn, gmm(L.$depvar, lag(1 3) collapse) ///
		iv($X $yrd_dyn, eq(diff)) noleveleq twostep robust small
	estimates store AB2
	global rho_ab2 = _b[L.$depvar]
	global j_ab2 = e(j)
	global p_hansen_ab2 = e(hansenp)
	global p_sargan_ab2 = e(sarganp)
	global p_ar2_ab2 = e(ar2p)
	xtabond2 $depvar L.$depvar $X $yrd_dyn, gmm(L.$depvar, lag(1 3) collapse) ///
		iv($X $yrd_dyn) twostep robust small
	estimates store SYS2
	global rho_sys2 = _b[L.$depvar]
	global j_sys2 = e(j)
	global p_hansen_sys2 = e(hansenp)
	global p_sargan_sys2 = e(sarganp)
	global p_ar2_sys2 = e(ar2p)
	xtabond2 $depvar L.$depvar $X $yrd_dyn, gmm(L.$depvar, lag(1 2) collapse) ///
		gmm($pillars, lag(1 2) collapse) iv($env $yrd_dyn) twostep robust small
	estimates store SYS3
	global rho_sys3 = _b[L.$depvar]
	global j_sys3 = e(j)
	global p_hansen_sys3 = e(hansenp)
	global p_sargan_sys3 = e(sarganp)
	global p_ar2_sys3 = e(ar2p)
	display as text _n "instrument counts (keep below N_g = " e(N_g) "): AB2 = $j_ab2, SYS2 = $j_sys2, SYS3 = $j_sys3"
	** long-run effects from the system GMM (b): b/(1 - rho)
	estimates restore SYS2
	local p1 : word 1 of $pillars
	local p2 : word 2 of $pillars
	local p3 : word 3 of $pillars
	local p4 : word 4 of $pillars
	nlcom (LR_hr:   _b[`p1'] / (1 - _b[L.$depvar])) ///
	      (LR_inst: _b[`p2'] / (1 - _b[L.$depvar])) ///
	      (LR_conn: _b[`p3'] / (1 - _b[L.$depvar])) ///
	      (LR_ind:  _b[`p4'] / (1 - _b[L.$depvar])), post
	estimates store SYS2_LR
}
else display as error "xtabond2 not available: collapsed-instrument GMM skipped"

** 8.6 Bias-corrected LSDV (Kiviet 1995 / Bruno 2005, xtlsdvc): corrects the Nickell
**     bias of FE-LDV analytically; bootstrap SE. Small-N Monte Carlo evidence
**     (Judson & Owen 1999; Bruno 2005) favours LSDVC over GMM for N around 30.
**     On this panel bias(3) is numerically unstable (rho > 1); bias(1)/(2) are stable.
if $have_xtlsdvc {
	xtlsdvc $depvar $X $yrd_dyn, initial(ab) bias(1) vcov(50)
	estimates store LSDVC
	global rho_lsdvc = _b[L.$depvar]
}
else display as error "xtlsdvc not available: bias-corrected LSDV skipped"

** 8.7 Bond (2002) bounds check on the lagged-TFP coefficient
display as text _n "lagged TFP coefficient: FE (lower) = " as result %6.3f ${rho_fe} ///
	as text "  OLS (upper) = " as result %6.3f ${rho_ols} ///
	as text _n "  AH = " as result %6.3f ${rho_ah} as text "  AB = " as result %6.3f ${rho_ab} ///
	as text "  SYS = " as result %6.3f ${rho_sys}
if $have_xtabond2 display as text "  AB2 = " as result %6.3f ${rho_ab2} as text "  SYS2 = " as result %6.3f ${rho_sys2} as text "  SYS3 = " as result %6.3f ${rho_sys3}
if $have_xtlsdvc display as text "  LSDVC = " as result %6.3f ${rho_lsdvc}
display as text "a GMM estimate outside the [FE, OLS] interval signals weak / invalid instruments"
foreach m in ah ab sys ab2 sys2 sys3 lsdvc {
	global inb_`m' = .
	capture global inb_`m' = inrange(${rho_`m'}, ${rho_fe}, ${rho_ols})
	if "${inb_`m'}" == "0" display as error "  `m': lagged-TFP coefficient outside [FE, OLS] -> do not interpret this model"
}

*** 9. Robustness ---------------------------------------------------------------
** 9a. constant-returns TFP as the dependent variable (FE2W and RE2W)
xtreg logtfp_it_crs $X $yrd, fe vce(cluster Code_Prov) $fmt
estimates store R_crs_FE2W
xtreg logtfp_it_crs $X $yrd, re vce(cluster Code_Prov) $fmt
estimates store R_crs_RE2W
** 9b. IKLH is itself a composite that contains the land-cover and water components;
**     drop it to check that Hijau / Biru are not double counted
xtreg $depvar $pillars Hijau_Prov Biru_Prov $yrd, fe vce(cluster Code_Prov) $fmt
estimates store R_noIKLH
** 9c. pillar inputs instead of indices (which component drives each pillar effect)
xtreg $depvar $hr_vars $inst_vars $conn_vars $ind_vars $env $yrd, fe vce(cluster Code_Prov) $fmt
estimates store R_inputs
** 9d. equal-weight additive indices instead of PC1 (polarity enforced by construction)
xtreg $depvar idx_hr_eq idx_inst_eq idx_conn_eq idx_ind_eq $env $yrd, fe vce(cluster Code_Prov) $fmt
estimates store R_additive
** 9e. education gap in place of the HR index
local p2 : word 2 of $pillars
local p3 : word 3 of $pillars
local p4 : word 4 of $pillars
xtreg $depvar Educ_Heduc `p2' `p3' `p4' $env $yrd, fe vce(cluster Code_Prov) $fmt
estimates store R_educgap

** 9f. Hijau_Prov is back-filled (2017-2019 = 2020 value) in the sheet, so its effect is
**     identified from 2020 onward only: re-estimate FE2W on 2020-2025
xtreg $depvar $X $yrd if Year >= 2020, fe vce(cluster Code_Prov) $fmt
estimates store R_post2020

*** 10. Summary tables and decision guide --------------------------------------
estimates table POLS FE FE2W RE RE2W CRE, keep($X) b(%9.3f) se(%9.3f) p(%5.3f) ///
	stats(N N_g r2_w r2_b r2_o) modelwidth(9) title("Static models (cluster-robust SE)")
estimates table FE_AR1 FGLS PCSE PCSE_het DK, keep($X) b(%9.3f) se(%9.3f) p(%5.3f) ///
	stats(N N_g) modelwidth(9) title("Serial-correlation and dependence-robust models")
estimates table OLS_LDV FE_LDV AB SYS AB2 SYS2 SYS3 LSDVC, keep(L.$depvar $X) b(%9.3f) se(%9.3f) p(%5.3f) ///
	stats(N N_g) modelwidth(9) title("Dynamic models")

if $have_esttab {
	esttab POLS FE FE2W RE RE2W CRE FE_AR1 FGLS PCSE PCSE_het DK using "$tab - static.rtf", replace ///
		b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) keep($X $Xbar) ///
		indicate("Year dummies = yr2*") stats(N N_g r2_w r2_o, labels("N" "Provinces" "R2 within" "R2 overall")) ///
		mtitles("POLS" "FE" "FE2W" "RE" "RE2W" "CRE" "FE-AR1" "FGLS" "PCSE" "PCSE-het" "DK") ///
		title("Determinants of log TFP: static panel models") nonotes ///
		addnotes("Cluster-robust SE by province except FGLS/PCSE/DK (their own SE)" "* p<0.10 ** p<0.05 *** p<0.01")
	* the AH model is in first differences: map D.x / LD.y onto the level names so the
	* rows line up with the other columns
	local rn LD.$depvar L.$depvar
	foreach v of global X {
		local rn `rn' D.`v' `v'
	}
	esttab OLS_LDV FE_LDV AH AB SYS AB2 SYS2 SYS3 LSDVC using "$tab - dynamic.rtf", replace ///
		b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) rename(`rn') keep(L.$depvar $X) ///
		indicate("Year dummies = *yr2*") stats(N N_g j hansenp ar2p, labels("N" "Provinces" "Instruments" "Hansen p" "AR(2) p")) ///
		mtitles("OLS-LDV" "FE-LDV" "AH" "AB" "SYS" "AB2" "SYS2" "SYS3" "LSDVC") ///
		title("Determinants of log TFP: dynamic panel models") nonotes ///
		addnotes("AB/SYS: official xtabond/xtdpdsys, two-step Windmeijer-robust" "AB2/SYS2/SYS3: xtabond2 collapsed instruments, two-step robust small" "LSDVC: xtlsdvc initial(ab) bias(1), bootstrap SE (50 reps)" "Dynamic models start in 2018 (reference year); AH/AB/AB2 use lagged levels as instruments for differences and are weak when TFP is near a unit root: read the lagged-TFP coefficient against the FE (lower) and OLS (upper) bounds" "* p<0.10 ** p<0.05 *** p<0.01")
	esttab R_crs_FE2W R_crs_RE2W R_noIKLH R_inputs R_additive R_educgap R_post2020 using "$tab - robustness.rtf", replace ///
		b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) indicate("Year dummies = yr2*") ///
		stats(N N_g r2_w, labels("N" "Provinces" "R2 within")) ///
		mtitles("CRS FE2W" "CRS RE2W" "no IKLH" "inputs" "additive" "educ gap" "2020-25") title("Robustness") nonotes
	esttab POLS FE FE2W RE RE2W CRE FE_AR1 FGLS PCSE PCSE_het DK OLS_LDV FE_LDV AH AB SYS AB2 SYS2 SYS3 LSDVC ///
		using "$tab - all models.csv", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
		rename(`rn') stats(N N_g r2_w r2_o j hansenp ar2p) plain
}

** diagnostics summary
display as text _n "{hline 78}" _n "POST-ESTIMATION TEST SUMMARY (p-values unless stated)" _n "{hline 78}"
display as text "PCA        : PC1 share  hr=" %5.2f ${pca_hr_prop} " inst=" %5.2f ${pca_inst_prop} " conn=" %5.2f ${pca_conn_prop} " ind=" %5.2f ${pca_ind_prop}
display as text "             KMO        hr=" %5.2f ${pca_hr_kmo}  " inst=" %5.2f ${pca_inst_kmo}  " conn=" %5.2f ${pca_conn_kmo}  " ind=" %5.2f ${pca_ind_kmo}
display as text "             inputs loading against the anchor (mixed polarity): hr=" ${pca_hr_nneg} " inst=" ${pca_inst_nneg} " conn=" ${pca_conn_nneg} " ind=" ${pca_ind_nneg}
display as text "Pooled OLS : BP hetero p=" %6.4f ${p_bp_hettest} "  RESET p=" %6.4f ${p_reset} "  Wooldridge AR(1) p=" %6.4f ${p_xtserial}
display as text "FE vs POLS : F(u_i=0) p=" %6.4f ${p_F_ui} "   RE vs POLS: BP-LM p=" %6.4f ${p_xttest0}
display as text "FE vs RE   : Hausman p=" %6.4f ${p_hausman} "  two-way p=" %6.4f ${p_hausman_2w} " (rank-deficient with year dummies; rely on Mundlak/xtoverid)  Mundlak p=" %6.4f ${p_mundlak}
if "${p_xtoverid}" != "" display as text "             xtoverid (robust Hausman) p=" %6.4f ${p_xtoverid} "  two-way p=" %6.4f ${p_xtoverid_2w}
display as text "FE errors  : mod. Wald hetero p=" %6.4f ${p_xttest3} "  Pesaran CD=" %6.3f ${cd_pesaran} " p=" %6.4f ${p_cd_pesaran} " (two-way CD=" %6.3f ${cd_pesaran_2w} " p=" %6.4f ${p_cd_pesaran_2w} ")"
display as text "             Friedman=" %6.3f ${cd_friedman} " p(chi2 T-1)=" %6.4f ${p_cd_friedman} "  Frees Q=" %6.3f ${cd_frees} " (1% crit. T=9: " %6.4f ${cd_frees_crit01} ", reject=" ${cd_frees_reject} ")"
display as text "             residual normality p=" %6.4f ${p_sk_fe}
display as text "Cointegr.  : Kao DF p=" %6.4f ${p_kao_df} "  Pedroni ADF p=" %6.4f ${p_pedroni_adf} "  Westerlund VR p=" %6.4f ${p_westerlund} "  (T=9: indicative only)"
display as text "Year effect: joint test p=" %6.4f ${p_yeareff_cl} "   LR groupwise hetero (xtgls, no year dummies) p=" %6.4f ${p_lr_het}
display as text "AR(1)      : Bhargava DW=" %6.3f ${dw_bhargava} "  Baltagi-Wu LBI=" %6.3f ${lbi_baltagi} "  rho=" %6.3f ${rho_ar1}
display as text "AH         : first-stage F=" %6.2f ${F_ah_first} " (F < 10: weak instrument)"
display as text "GMM        : AB  AR(1) p=" %6.4f ${p_ar1_ab} " AR(2) p=" %6.4f ${p_ar2_ab} " instruments=" ${j_ab} "   SYS AR(1) p=" %6.4f ${p_ar1_sys} " AR(2) p=" %6.4f ${p_ar2_sys} " instruments=" ${j_sys} "  (Sargan p: see estat sargan output)"
if $have_xtabond2 {
	display as text "             AB2  Hansen p=" %6.4f ${p_hansen_ab2} " Sargan p=" %6.4f ${p_sargan_ab2} " AR(2) p=" %6.4f ${p_ar2_ab2} " instruments=" ${j_ab2}
	display as text "             SYS2 Hansen p=" %6.4f ${p_hansen_sys2} " Sargan p=" %6.4f ${p_sargan_sys2} " AR(2) p=" %6.4f ${p_ar2_sys2} " instruments=" ${j_sys2}
	display as text "             SYS3 Hansen p=" %6.4f ${p_hansen_sys3} " Sargan p=" %6.4f ${p_sargan_sys3} " AR(2) p=" %6.4f ${p_ar2_sys3} " instruments=" ${j_sys3}
	display as text "             lagged TFP: FE=" %5.3f ${rho_fe} " OLS=" %5.3f ${rho_ols} " | AB=" %5.3f ${rho_ab} " SYS=" %5.3f ${rho_sys} " AB2=" %5.3f ${rho_ab2} " SYS2=" %5.3f ${rho_sys2} " SYS3=" %5.3f ${rho_sys3}
}
if $have_xtlsdvc display as text "             lagged TFP LSDVC=" %5.3f ${rho_lsdvc} "  (must lie between FE and OLS)"
display as text "{hline 78}"
display as text "HOW TO READ:"
display as text " - BP-LM p<0.05 and F(u_i) p<0.05 : province effects exist -> pooled OLS is rejected"
display as text " - Hausman / Mundlak / xtoverid p<0.05 : RE is inconsistent -> prefer FE (or CRE);"
display as text "   the classic two-way Hausman is rank-deficient (year dummies), use Mundlak/xtoverid"
display as text " - year-effect p<0.05 : keep the year dummies (two-way FE)"
display as text " - Wooldridge / DW / LBI signal AR(1); mod. Wald signals heteroskedasticity ->"
display as text "   cluster-robust SE (used), or FE-AR1 / FGLS / PCSE as alternatives"
display as text " - Frees Q above its critical value or Pesaran CD p<0.05 : cross-sectional dependence"
display as text "   (Pesaran CD has low power when correlations have mixed signs). Remedies: year"
display as text "   dummies (two-way FE), full PCSE; Driscoll-Kraay needs large T, indicative only"
display as text " - unit roots / cointegration with T=9 are not decision-relevant; year dummies and"
display as text "   province effects absorb the trends; report FE in first differences if in doubt"
display as text " - PCA: an input loading against the anchor means PC1 mixes good and bad directions;"
display as text "   set mixed_rule = eq or redefine the pillar inputs before interpreting the sign"
display as text " - GMM: AR(2) p>0.10 and Hansen p in roughly [0.10, 0.25+] with instruments < N;"
display as text "   lagged-TFP coefficient must lie between FE and OLS; with N=34 treat GMM as"
display as text "   a robustness check, not the headline model; difference GMM (AB2) fails the"
display as text "   bounds check here (persistent TFP -> weak instruments); LSDVC is the small-N choice"
display as text "{hline 78}"

** write the diagnostics sheet
putexcel set "$out", sheet("Diagnostics") modify
putexcel A1 = "Test" B1 = "Statistic / p-value" C1 = "Reading"
local r = 2
foreach item in ///
	"pca_hr_prop|PC1 share HR|>0.5 acceptable" "pca_inst_prop|PC1 share Institution|>0.5 acceptable" ///
	"pca_conn_prop|PC1 share Connectivity|>0.5 acceptable" "pca_ind_prop|PC1 share Industry|>0.5 acceptable" ///
	"pca_hr_kmo|KMO HR|>0.5 adequate" "pca_inst_kmo|KMO Institution|>0.5 adequate" ///
	"pca_conn_kmo|KMO Connectivity|>0.5 adequate" "pca_ind_kmo|KMO Industry|>0.5 adequate" ///
	"pca_hr_bart_p|Bartlett p HR|<0.05 PCA meaningful" "pca_inst_bart_p|Bartlett p Institution|<0.05" ///
	"pca_conn_bart_p|Bartlett p Connectivity|<0.05" "pca_ind_bart_p|Bartlett p Industry|<0.05" ///
	"p_bp_hettest|Breusch-Pagan hetero (POLS) p|<0.05 heteroskedastic" "p_reset|RESET (POLS) p|<0.05 misspecified" ///
	"p_xtserial|Wooldridge AR(1) p|<0.05 serial correlation" "p_F_ui|F test u_i=0 p|<0.05 FE beats POLS" ///
	"p_xttest0|Breusch-Pagan LM p|<0.05 RE beats POLS" "p_hausman|Hausman one-way p|<0.05 FE" ///
	"p_hausman_2w|Hausman two-way p|<0.05 FE" "p_mundlak|Mundlak joint test p|<0.05 FE / CRE" ///
	"p_xtoverid|xtoverid robust Hausman p|<0.05 FE" "p_xtoverid_2w|xtoverid two-way p|<0.05 FE" ///
	"p_xttest3|Modified Wald hetero p|<0.05 heteroskedastic" "p_cd_pesaran|Pesaran CD p (one-way)|<0.05 dependence" ///
	"p_cd_pesaran_2w|Pesaran CD p (two-way)|<0.05 dependence" "p_cd_friedman|Friedman p|<0.05 dependence" ///
	"cd_pesaran|Pesaran CD statistic (one-way)|~N(0,1)" "cd_pesaran_2w|Pesaran CD statistic (two-way)|~N(0,1)" ///
	"cd_friedman|Friedman statistic|chi2(T-1)" "cd_frees|Frees Q statistic|vs critical value" ///
	"cd_frees_crit01|Frees Q 1% critical value (T=9)|" "cd_frees_reject|Frees rejects independence (1=yes)|" ///
	"p_kao_df|Kao DF cointegration p|<0.05 cointegrated (T=9 caveat)" "p_pedroni_adf|Pedroni ADF p|<0.05 cointegrated" ///
	"p_westerlund|Westerlund VR p|<0.05 cointegrated" "F_ah_first|AH first-stage F|>10 strong" ///
	"j_ab|Instruments AB (xtabond)|< 34" "j_sys|Instruments SYS (xtdpdsys)|< 34" ///
	"pca_hr_nneg|Mixed-polarity inputs HR|0 = clean" "pca_inst_nneg|Mixed-polarity inputs Institution|0 = clean" ///
	"pca_conn_nneg|Mixed-polarity inputs Connectivity|0 = clean" "pca_ind_nneg|Mixed-polarity inputs Industry|0 = clean" ///
	"p_sk_fe|Residual normality p|<0.05 non-normal" ///
	"p_yeareff_cl|Year effects p|<0.05 keep year dummies" "p_lr_het|LR groupwise hetero p|<0.05 heteroskedastic" ///
	"dw_bhargava|Bhargava DW|<<2 AR(1)" "lbi_baltagi|Baltagi-Wu LBI|<<2 AR(1)" "rho_ar1|AR(1) rho (xtregar)|" ///
	"rho_ols|lagged TFP OLS (upper)|" "rho_fe|lagged TFP FE (lower)|" "rho_ah|lagged TFP AH|" ///
	"rho_ab|lagged TFP AB|" "rho_sys|lagged TFP SYS|" "rho_ab2|lagged TFP AB2|" "rho_sys2|lagged TFP SYS2|" "rho_sys3|lagged TFP SYS3|" ///
	"rho_lsdvc|lagged TFP LSDVC|between FE and OLS" ///
	"inb_ah|AH inside [FE,OLS] (1=yes)|0 = weak instruments" "inb_ab|AB inside [FE,OLS]|0 = weak instruments" ///
	"inb_sys|SYS inside [FE,OLS]|0 = weak instruments" "inb_ab2|AB2 inside [FE,OLS]|0 = weak instruments" ///
	"inb_sys2|SYS2 inside [FE,OLS]|0 = weak instruments" "inb_sys3|SYS3 inside [FE,OLS]|0 = weak instruments" ///
	"inb_lsdvc|LSDVC inside [FE,OLS]|0 = unstable correction" ///
	"p_ar1_ab|AR(1) AB p|<0.10 expected" "p_ar2_ab|AR(2) AB p|>0.10 required" ///
	"p_ar1_sys|AR(1) SYS p|<0.10 expected" "p_ar2_sys|AR(2) SYS p|>0.10 required" ///
	"p_hansen_ab2|Hansen AB2 p|0.10-0.25+" "p_sargan_ab2|Sargan AB2 p|>0.10" "p_ar2_ab2|AR(2) AB2 p|>0.10" ///
	"p_hansen_sys2|Hansen SYS2 p|0.10-0.25+" "p_sargan_sys2|Sargan SYS2 p|>0.10" "p_ar2_sys2|AR(2) SYS2 p|>0.10" ///
	"p_hansen_sys3|Hansen SYS3 p|0.10-0.25+" "p_sargan_sys3|Sargan SYS3 p|>0.10" "p_ar2_sys3|AR(2) SYS3 p|>0.10" ///
	"j_ab2|Instruments AB2|< 34" "j_sys2|Instruments SYS2|< 34" "j_sys3|Instruments SYS3|< 34" {
	tokenize "`item'", parse("|")
	local g   `1'
	local lab `3'
	local read `5'
	local val = .
	capture local val = ${`g'}
	if "${`g'}" == "" local val = .
	putexcel A`r' = "`lab'" B`r' = `val' C`r' = "`read'"
	local ++r
}

*** 11. Export the indices and the analysis dataset -----------------------------
preserve
keep Code_Prov Prov Year $depvar logtfp_it_crs idx_hr idx_inst idx_conn idx_ind ///
	idx_hr_100 idx_inst_100 idx_conn_100 idx_ind_100 idx_hr_eq idx_inst_eq idx_conn_eq idx_ind_eq ///
	Educ_Heduc IKLH_Prov Hijau_Prov Biru_Prov
order Code_Prov Prov Year
export excel using "$out", sheet("Indices", replace) firstrow(variables) nolabel
restore
save "$outdir/Determinan TFP Provinsi BKPM.dta", replace
display as text _n "done. results: $out ; tables: $tab - *.rtf/.csv ; data: Determinan TFP Provinsi BKPM.dta"
log close
