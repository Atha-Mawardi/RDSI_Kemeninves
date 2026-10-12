# =============================================================================
# 05_benchmark elastisitas lintas negara.R
#
# Menyusun tabel pembanding elastisitas output modal (b1) dan tenaga kerja (b2)
# lintas negara, untuk menilai posisi angka kajian ini (b1 = 0,400; b2 = 0,191).
#
# ATURAN MASUK, versi 2026-08-04 (revisi):
#   Hanya studi yang MENGESTIMASI b1 DAN b2 SEKALIGUS tanpa memaksakan imbal
#   hasil konstan. Studi yang memaksakan restriksi itu DIBUANG, karena b2-nya
#   bukan hasil estimasi melainkan 1 - b1, sehingga tidak menjawab apa pun soal
#   posisi b2 = 0,191 maupun soal jumlah 0,591.
#
#   Versi pertama skrip ini memakai 66 negara Senhadji (2000) sebagai lapisan
#   dasar. Seluruh lapisan itu dicabut karena CRS dipaksakan di sana.
#
# ATURAN PEMILIHAN BARIS per_negara:
#   1. Satu baris per negara, dipilih studi dengan TAHUN DATA paling akhir.
#   2. Studi yang kalah tetap tersimpan di sheet semua_studi beserta alasannya.
#
# Angka di bawah SALINAN dari studi terbitan; tidak ada estimasi baru di sini.
# Kolom notes membawa status periksa tiap angka.
#
# Litrev pendukung: 00 Docs/litrev-elastisitas-lintas-negara.md
# =============================================================================

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
})

if (!dir.exists("03 Output")) stop("Jalankan skrip ini dari folder 'TFP analysis (07182026)'.")

# -----------------------------------------------------------------------------
# 1. Estimasi non-restricted, satu baris per studi
# -----------------------------------------------------------------------------
STUDI <- tribble(
  ~negara, ~b1, ~b2, ~tahun_data_akhir, ~unit, ~estimator, ~modal, ~tier, ~source, ~notes,

  "Indonesia", 0.400, 0.191, 2025L, "34 provinsi", "two-way fixed effects", "arus PMTB", "kajian ini",
  "Kajian ini (2026), 02 Code/01_estimasi tfp.R, log 03 Output/log_01_estimasi.txt",
  paste0("data 2017-2025; 272 observasi; SE Driscoll-Kraay; jumlah b1+b2 = 0,591; ",
         "CRS ditolak p<0,001; angka: teks asli; sumber: perhitungan sendiri"),

  "China", 0.170, 0.230, 2009L, "31 provinsi", "LSDV efek provinsi + tahun", "arus investasi aset tetap", "T2",
  "Heshmati, A. & Su, B. (2013), Development and Sources of Labor Productivity in Chinese Provinces, China Economic Policy Review 2(2), DOI 10.1142/s1793969013500052",
  paste0("data 2000-2009; 310 observasi; jumlah b1+b2 = 0,40, disebut sendiri 'decreasing returns to scale'; ",
         "spesifikasinya memuat empat regresor tambahan di luar modal dan tenaga kerja; ",
         "angka: teks asli (versi IZA DP 6263, bagian 6.1); sumber: DOI"),

  "China", 0.433, 0.190, 2005L, "28 provinsi", "two-way fixed effects", "stok", "T1",
  "Hao, R. & Wei, Z. (2009), Sources of Income Differences Across Chinese Provinces During the Reform Period, The Developing Economies 47(1), DOI 10.1111/j.1746-1049.2009.00074.x",
  paste0("data 1982-2005; bentuk per-pekerja dengan suku ln L; jumlah b1+b2 = 0,623; ",
         "uji F terhadap CRS = 31,67, ditolak kuat, penulis menyebut 'high decreasing returns to scale'; ",
         "tanpa modal manusia b1 = 0,430 dan b2 = 0,200; varian CRS pada data sama memberi b1 = 0,481-0,503; ",
         "angka: teks asli (versi CERDI E 2007.23); sumber: DOI"),

  "Indonesia", 0.4895, 0.3251, 2000L, "26 provinsi", "stochastic frontier translog", "arus pembentukan modal", "T1",
  "Margono, H., Sharma, S.C., Sylwester, K. & Al-Qalawi, U. (2011), Technical efficiency and productivity analysis in Indonesian provincial economies, Applied Economics 43(6), 663-672, DOI 10.1080/00036840802599834",
  paste0("data 1993-2000; elastisitas rata-rata seluruh provinsi, dihitung di titik rata-rata input; ",
         "jumlah b1+b2 = 0,815; per provinsi jumlahnya 0,677 (Jawa Timur) - 0,945 (Kalimantan Tengah); ",
         "b1 per provinsi 0,289 (NTT) - 0,769 (Jakarta); b2 per provinsi 0,076 (Jakarta) - 0,589 (Bengkulu); ",
         "angka: teks asli (versi kertas kerja SIU); sumber: DOI"),

  "Russia", 0.350, 0.490, 2010L, "79 region", "two-way fixed effects", "stok aset tetap", "T4",
  "Pembangunan fungsi produksi untuk region Rusia dengan data panel, Molodoy Uchenyy (2013), edisi 58, moluch.ru/archive/58/8236",
  paste0("data 2002-2010; VRP region, nilai aset tetap, penduduk aktif ekonomi; ",
         "efek tetap region dan periode, F = 1546,69; jumlah b1+b2 = 0,84, dinyatakan sendiri di bawah satu; ",
         "angka: teks asli; sumber: jurnal mahasiswa Rusia tanpa DOI, tier rendah, dipakai sebagai jejak saja"),

  "India", 0.191, 0.703, 2011L, "16 negara bagian, manufaktur", "stochastic frontier translog", "stok (perpetual inventory)", "T4",
  "Efficiency of Indian Organized Manufacturing, publishingindia.com/storage/PDFBrochures/5698.pdf",
  paste0("data 1993-2011; elastisitas rata-rata antar negara bagian, dihitung di titik rata-rata; ",
         "jumlah b1+b2 = 0,887, menurun di hampir semua negara bagian kecuali Orissa; ",
         "CAKUPANNYA MANUFAKTUR TERORGANISIR, bukan seluruh ekonomi; ",
         "angka: teks asli; sumber: tanpa DOI, tier rendah"),

  "Italy", 0.520, 0.460, 1994L, "20 wilayah x 17 sektor", "kointegrasi panel (LSDV)", "stok", "T4",
  "Marrocu, E., Paci, R. & Pala, R. (2001), Estimation of Total Factor Productivity for Regions and Sectors in Italy: A Panel Cointegration Approach, DOI 10.2139/ssrn.254390",
  paste0("data 1970-1994; 8.500 observasi, 340 efek tetap wilayah dan sektor; jumlah b1+b2 ~ 0,98, mendekati CRS; ",
         "koreksi Engle-Granger-Yoo memberi 0,51 dan 0,46; ",
         "b1 per wilayah 0,21 (Basilicata) - 0,69 (Veneto), b2 per wilayah 0,10 (Calabria) - 0,84 (Molise); ",
         "angka: teks asli; sumber: SSRN tanpa versi terbit, tidak boleh masuk daftar pustaka"),

  "United States", 0.310, 0.590, 1986L, "48 negara bagian", "pooled OLS", "stok", "T2",
  "Munnell, A.H. (1990), How Does Public Infrastructure Affect Regional Economic Performance?, New England Economic Review, Federal Reserve Bank of Boston, Sep 1990, 11-33",
  paste0("data 1970-1986; ada INPUT KETIGA, modal publik, dengan elastisitas 0,15; ",
         "jumlah ketiga elastisitas 1,05; jumlah b1+b2 saja 0,90; ",
         "karena input ketiga itu, b1 dan b2 di sini tidak sebanding langsung dengan model dua input; ",
         "angka: teks asli (Tabel 5, persamaan 3); sumber: terbitan lembaga, tanpa DOI"),

  "Jordan", 0.3804, 0.6385, 2019L, "negara", "ARDL jangka panjang", "stok (pendekatan ICOR)", "T2",
  "Al-Bess, M.N. & Malawi, A.I. (2025), Food Security and Marginal Productivity of Labor in Jordan, Dirasat: Human and Social Sciences, DOI 10.35516/hum.2025.8061",
  paste0("data 1992-2019; deret satu negara; ARDL(4,5,5), kedua koefisien bermakna p<0,01; ",
         "jumlah b1+b2 = 1,019, praktis CRS; stok modal diestimasi lewat ICOR karena datanya tidak ada; ",
         "angka: teks asli (Tabel 10); sumber: DOI"),

  "Jordan", 0.490, 0.580, 2015L, "enam sektor swasta", "regresi deret", "stok", "T4",
  "Bakeer & Rfoa (2020), dikutip dalam Al-Bess & Malawi (2025)",
  paste0("data 2000-2015; jumlah b1+b2 = 1,07; ",
         "angka: kutipan sekunder, belum dibuka sumber aslinya; sumber: belum ditelusuri"),

  "North Macedonia", 0.0713, -0.0139, 2024L, "negara", "ARDL bounds", "arus pembentukan modal bruto", "T4",
  "Cobb-Douglas Production Function in North Macedonia: An ARDL Analysis, Ekonomski Institut, Univerzitet Sv. Kiril i Metodij (2026)",
  paste0("data kuartalan 2005-2024, 75 observasi; koefisien tenaga kerja TIDAK BERMAKNA (p = 0,46); ",
         "jumlah b1+b2 = 0,058, uji Wald menolak CRS; ",
         "angka b2 negatif dan tidak bermakna membuat jumlahnya tidak bisa ditafsirkan sebagai imbal hasil; ",
         "dimuat sebagai kasus ekstrem, bukan sebagai pembanding yang setara; ",
         "angka: teks asli (Tabel 1); sumber: jurnal lembaga tanpa DOI"),

  "Bangladesh", 0.490, 0.510, 2013L, "enam industri manufaktur", "weighted least squares", "total kewajiban sebagai proksi", "T4",
  "Husain, S. & Islam, S.M. (2016), A test for the Cobb-Douglas production function in manufacturing sector: The case of Bangladesh, International Journal of Business and Economics Research 5(5), 149-154",
  paste0("cakupannya manufaktur; modal DIPROKSI TOTAL KEWAJIBAN, bukan aset atau investasi, sehingga ",
         "b1-nya sukar ditafsirkan sebagai elastisitas modal; jumlah b1+b2 = 1,00 tetapi penulis menyebut imbal hasil meningkat; ",
         "angka: abstrak; sumber: tanpa DOI, tier rendah")
)

# -----------------------------------------------------------------------------
# 2. Angka tingkat kelompok, juga non-restricted
# -----------------------------------------------------------------------------
# Miller & Upadhyay memakai bentuk per-pekerja dengan suku ln L, jadi CRS diuji
# bukan dipaksakan. b2 dihitung sebagai jumlah dikurangi b1.
KELOMPOK <- tribble(
  ~kelompok, ~b1, ~b2, ~jumlah, ~source, ~notes,
  "83 negara, semua",              0.4756, 0.4256, 0.9012, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989; efek tetap negara dan tahun; koefisien ln L = -0,0988",
  "Negara berpendapatan tinggi",   0.1683, 0.3207, 0.4890, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989; jumlah 0,489, LEBIH RENDAH daripada 0,591 kajian ini",
  "Negara berpendapatan menengah", 0.5694, 0.2526, 0.8220, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989; kelompok tempat Indonesia berada; b2 = 0,253",
  "Negara berpendapatan rendah",   0.4604, 1.3346, 1.7950, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989; imbal hasil meningkat tajam",
  "Asia",                          0.3657, 0.6467, 1.0124, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989",
  "Eropa",                         0.5408, 0.4102, 0.9510, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989",
  "Amerika Latin",                 0.5112, 0.5698, 1.0810, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989",
  "Afrika",                        0.4452, 1.2589, 1.7041, "Miller & Upadhyay, kertas kerja UNLV", "data 1960-1989",
  "MENA (negara berkembang)",      0.680,  NA_real_, NA_real_, "Abou Hamia, M.A. (2020), Review of Development Economics 24(3)", "pangsa modal terestimasi, efek tetap; pooled 0,602; rata-rata enam penduga 0,643; b2 tidak dilaporkan terpisah"
)

# -----------------------------------------------------------------------------
# 3. Rakit sheet
# -----------------------------------------------------------------------------
semua_studi <- STUDI %>%
  arrange(negara, desc(tahun_data_akhir)) %>%
  mutate(jumlah_b1_b2 = round(b1 + b2, 3))

per_negara <- semua_studi %>%
  group_by(negara) %>%
  arrange(desc(tahun_data_akhir), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  arrange(negara) %>%
  select(negara, b1, b2, source, notes, jumlah_b1_b2, tahun_data_akhir, unit, estimator, modal, tier)

semua_studi <- semua_studi %>%
  mutate(dipakai_di_per_negara = ifelse(
    paste(negara, tahun_data_akhir) %in% paste(per_negara$negara, per_negara$tahun_data_akhir),
    "ya", "tidak — ada studi dengan tahun data lebih akhir untuk negara yang sama")) %>%
  select(negara, b1, b2, source, notes, jumlah_b1_b2, tahun_data_akhir, unit, estimator, modal,
         tier, dipakai_di_per_negara)

stopifnot(!any(duplicated(per_negara$negara)))
stopifnot(all(nzchar(per_negara$source)), all(nzchar(per_negara$notes)))

# -----------------------------------------------------------------------------
# 4. Diagnostik posisi Indonesia
# -----------------------------------------------------------------------------
idn <- per_negara %>% filter(negara == "Indonesia")
cat(sprintf("Baris per_negara: %d negara, seluruhnya non-restricted\n", nrow(per_negara)))
cat(sprintf("Baris semua_studi: %d estimasi\n", nrow(semua_studi)))
cat(sprintf("Indonesia: b1 = %.3f, b2 = %.3f, jumlah = %.3f\n", idn$b1, idn$b2, idn$jumlah_b1_b2))

urut <- function(x, v) sprintf("%d dari %d (1 = terendah)", rank(x)[which(v == "Indonesia")], length(x))
cat(sprintf("Peringkat b1 Indonesia: %s\n", urut(per_negara$b1, per_negara$negara)))
cat(sprintf("Peringkat b2 Indonesia: %s\n", urut(per_negara$b2, per_negara$negara)))
cat(sprintf("Peringkat jumlah Indonesia: %s\n", urut(per_negara$jumlah_b1_b2, per_negara$negara)))

cat("\nSebaran per_negara:\n")
for (kol in c("b1", "b2", "jumlah_b1_b2")) {
  v <- per_negara[[kol]]
  cat(sprintf("  %-12s min %.3f | median %.3f | maks %.3f\n", kol, min(v), median(v), max(v)))
}

cat("\nSemua estimasi, diurutkan menurut b2:\n")
print(as.data.frame(semua_studi %>% arrange(b2) %>%
                      select(negara, b1, b2, jumlah_b1_b2, unit, tahun_data_akhir)))

cat("\nDitambah kelompok Miller & Upadhyay, jumlah di bawah 0,7:\n")
print(as.data.frame(KELOMPOK %>% filter(jumlah < 0.7) %>% select(kelompok, b1, b2, jumlah)))

# -----------------------------------------------------------------------------
# 5. Tulis Excel
# -----------------------------------------------------------------------------
berkas <- file.path("03 Output", "Benchmarking Elastisitas Lintas Negara_0804.xlsx")
write.xlsx(
  list(per_negara = per_negara,
       semua_studi = semua_studi,
       agregat_kelompok = KELOMPOK),
  file = berkas, overwrite = TRUE, colWidths = "auto"
)

# openxlsx 4.2.8 menulis relasi ke drawings/vmlDrawing yang berkasnya tidak ada.
# Excel mengabaikannya, pembaca ketat (openpyxl, pandas) berhenti dengan galat.
bersihkan_relasi <- function(path) {
  tmp <- file.path(tempdir(), "xlsxfix"); unlink(tmp, recursive = TRUE); dir.create(tmp)
  utils::unzip(path, exdir = tmp)
  for (f in list.files(file.path(tmp, "xl", "worksheets", "_rels"), full.names = TRUE)) {
    x <- readLines(f, warn = FALSE)
    x <- gsub("<Relationship [^>]*(drawings/drawing|drawings/vmlDrawing)[^>]*/>", "", x)
    writeLines(x, f)
  }
  wd <- setwd(tmp); on.exit(setwd(wd), add = TRUE)
  utils::zip(path, files = list.files(".", recursive = TRUE, all.files = TRUE), flags = "-rq")
}
bersihkan_relasi(normalizePath(berkas))

cat(sprintf("\nDitulis: %s\n", berkas))
