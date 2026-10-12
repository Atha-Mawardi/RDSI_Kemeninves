* Konstruksi TFP provinsi
* Atha Bintang Wahyu M. | PSE UGM
*
* Data   : 01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
*          sheet Sheet1 
* Sample : 34 provinsi x 2017-2024 (N = 272). Tahun 2025 punya PDRB/PMTB, tenaga kerja kosong.
* Y      : PDRB ADHK (9_ADHK)
* K      : PMTB ADHK (4_ADHK)  — arus riil, bukan pmtb harga berlaku
* L      : 17 Sektor *_TenagaKerja
* Model  : two-way FE (provinsi + tahun), SE cluster provinsi
* Residual: logtfp_it = log Y - b1 log K - b2 log L
*           (= a + u_i + lambda_t + e_it). 
*           Level log TFP bukan indeks; jangan di-exp().
* CRS    : logtfp_it_crs = log(Y/L) - b1_crs log(K/L)

version 17
clear all
set more off
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

global xlsx   "${proj}/01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"
global outdir "${proj}/01 Data/TFP/output/konstruksi"
capture mkdir "${proj}/01 Data/TFP/output"
capture mkdir "${outdir}"

if !fileexists("${data}") {
	display as error "data not found: $data"
	exit 601
}

log using "${outdir}/Konstruksi TFP Provinsi.log", replace text
display as text "proj = $proj"
display as text "data = $data"

*** Import 
import excel "$data", sheet("Sheet1") firstrow clear
* Label variabel tetap nama Excel. Residual logtfp di sheet pake paste lama; dibuang.
foreach v of varlist _all {
	local lab : variable label `v'
	if "`lab'" == "9_ADHK" rename `v' pdrb_adhk
	if "`lab'" == "4_ADHK" rename `v' pmtb_adhk
}
capture drop logtfp_it logtfp_it_crs log_ADHK_Tot log_pmtb log_lab_tot

drop if missing(Code_Prov) | missing(Year)
keep if inrange(Year, 2017, 2024)

egen double labours_total = rowtotal(*_TenagaKerja)
drop if missing(pdrb_adhk) | missing(pmtb_adhk) | labours_total <= 0

isid Code_Prov Year
xtset Code_Prov Year
xtdescribe

*** Logs 
gen double log_Y = ln(pdrb_adhk)
gen double log_K = ln(pmtb_adhk)
gen double log_L = ln(labours_total)
label variable pdrb_adhk "PDRB ADHK (kolom 9_ADHK)"
label variable pmtb_adhk "PMTB ADHK (kolom 4_ADHK)"
label variable log_Y "ln PDRB ADHK"
label variable log_K "ln PMTB ADHK"
label variable log_L "ln tenaga kerja 17 sektor"
label variable labours_total "tenaga kerja total (jiwa)"

*** Fungsi produksi 
* Pembanding singkat --> model yang dipakai: FE2W
regress log_Y log_K log_L, vce(cluster Code_Prov)
estimates store POLS

xtreg log_Y log_K log_L, fe vce(cluster Code_Prov)
estimates store FE

xtreg log_Y log_K log_L, re vce(cluster Code_Prov)
estimates store RE

xtreg log_Y log_K log_L i.Year, fe vce(cluster Code_Prov)
estimates store FE2W
test log_K + log_L = 1
display as text "FE2W  b1 = " %6.4f _b[log_K] "  b2 = " %6.4f _b[log_L] ///
	"  b1+b2 = " %6.4f (_b[log_K] + _b[log_L])

scalar b1 = _b[log_K]
scalar b2 = _b[log_L]

gen double logtfp_it = log_Y - b1*log_K - b2*log_L
label variable logtfp_it "ln residual PMTB riil (DRS, two-way FE)"

*** CRS (peringkat antarprovinsi)
gen double log_y_l = log_Y - log_L
gen double log_k_l = log_K - log_L
xtreg log_y_l log_k_l i.Year, fe vce(cluster Code_Prov)
scalar b1_crs = _b[log_k_l]
gen double logtfp_it_crs = log_y_l - b1_crs*log_k_l
label variable logtfp_it_crs "ln residual per pekerja (CRS)"
display as text "CRS   b1 = " %6.4f b1_crs "  b2 = " %6.4f (1 - b1_crs)

egen double z_logtfp = std(logtfp_it)
egen double z_logtfp_crs = std(logtfp_it_crs)
label variable z_logtfp "z-score logtfp_it (seluruh sampel)"
label variable z_logtfp_crs "z-score logtfp_it_crs (seluruh sampel)"

*** Cek
summarize log_Y log_K log_L logtfp_it logtfp_it_crs z_logtfp, separator(0)
correlate logtfp_it logtfp_it_crs log_Y
xtsum logtfp_it logtfp_it_crs
table Year, statistic(mean logtfp_it) statistic(sd logtfp_it) nformat(%9.3f)

*** Save
keep Code_Prov Pre_Prov Year pdrb_adhk pmtb_adhk labours_total ///
	log_Y log_K log_L log_y_l log_k_l logtfp_it logtfp_it_crs z_logtfp z_logtfp_crs
order Code_Prov Pre_Prov Year
compress
save "${outdir}/TFP Provinsi 2017-2024.dta", replace
export excel using "${outdir}/TFP Provinsi 2017-2024.xlsx", sheet("tfp") firstrow(variables) replace

display as text _n "b1 (FE2W) = " %8.6f b1 "  b2 = " %8.6f b2
display as text "b1_crs    = " %8.6f b1_crs
display as text "saved: $outdir"
log close
