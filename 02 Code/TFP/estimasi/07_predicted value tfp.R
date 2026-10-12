# SCRIPT OVERVIEW ---------------------------------------------------------------
# 07_predicted value tfp.R
#
# Menyusun satu workbook berisi TFP dan kontribusi faktor per provinsi-tahun,
# 2017-2025, untuk DUA basis harga sekaligus. Tidak mengestimasi apa pun: seluruh
# angkanya turunan dari keluaran skrip 01 dan parameter yang ditulis skrip 01.
#
# Input :
#   01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx      sheet data_tfp
#   01 Data/TFP/output/modal_riil/parameter_terpilih.rds
#   01 Data/TFP/output/adhb/Hasil Estimasi TFP.xlsx            sheet data_tfp
#   01 Data/TFP/output/adhb/parameter_terpilih.rds
#   ../../../All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
#       sheet "Analisis Luaran 2", kolom A:C — dibaca untuk mengunci urutan baris
#
# Output:
#   01 Data/TFP/output/adhb/Predicted Value TFP 2017-2025.xlsx
#   ../../../All Dataset/Predicted Value TFP 2017-2025.xlsx
#
# Jalankan dari root project (.Rproj):
#   Rscript "02 Code/TFP/estimasi/07_predicted value tfp.R" > "01 Data/TFP/output/adhb/log_16_predicted.txt" 2>&1
#
# BEDANYA DENGAN SKRIP 13. Skrip 13 melayani satu basis, berhenti di 2024, dan
# memasok tautan luar Excel yang rentangnya terkunci di 272 baris. Skrip ini
# menggabung dua basis, memuat 2025, dan berdiri di luar rantai tautan itu.
#
# KENAPA BERKASNYA DITULIS DUA KALI. Salinan di 01 Data/TFP/output/adhb mengikuti
# preseden keluaran lintas basis; salinan di All Dataset dipakai Eqi menempel
# kolom CD:CL. Keduanya ditulis dari satu objek yang sama di dalam sesi ini, jadi
# tidak ada peluang keduanya menyimpang.
# -------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
})

stopifnot(dir.exists("01 Data/TFP/output/modal_riil"), dir.exists("01 Data/TFP/output/adhb"))

DIR_UMUM <- "01 Data/TFP/processed"
F_UMUM   <- file.path(DIR_UMUM, "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx")
NAMA     <- "Predicted Value TFP 2017-2025.xlsx"

# Urutan sembilan kolom hasil MENGIKUTI CD:CL di sheet "Analisis Luaran 2", bukan
# urutan alami sheet data_tfp. Eqi menempelnya sebagai satu blok tanpa XLOOKUP,
# jadi urutan kolom di sini adalah bagian dari kebenaran keluarannya.
KOL_HASIL <- c("log_lab_tot", "logtfp_it", "logtfp_it_crs",
               "g_Y", "g_K", "g_L",
               "kontrib_modal", "kontrib_tk", "kontrib_tfp")

# 1) Susun panel satu basis ----
# Laju = selisih log x 100 = poin persen per tahun, sama seperti skrip 02 dan 13.
# Baris 2017 ber-NA karena tahun basis, dan itu dipertahankan apa adanya.
susun <- function(dir_out, label) {
  f_est <- file.path(dir_out, "Hasil Estimasi TFP.xlsx")
  f_par <- file.path(dir_out, "parameter_terpilih.rds")
  stopifnot(file.exists(f_est), file.exists(f_par))

  par_tfp <- readRDS(f_par)
  b1 <- unname(par_tfp$b1_un)
  b2 <- unname(par_tfp$b2_un)

  dat <- read.xlsx(f_est, sheet = "data_tfp")
  kol_y <- if (label == "ADHB") "log_ADHB_Tot" else "log_ADHK_Tot"
  stopifnot(kol_y %in% names(dat))

  panel <- dat %>%
    arrange(Code_Prov, Year) %>%
    group_by(Code_Prov) %>%
    mutate(g_Y = 100 * (.data[[kol_y]] - lag(.data[[kol_y]])),
           g_K = 100 * (log_pmtb       - lag(log_pmtb)),
           g_L = 100 * (log_lab_tot    - lag(log_lab_tot))) %>%
    ungroup() %>%
    mutate(kontrib_modal = b1 * g_K,
           kontrib_tk    = b2 * g_L,
           kontrib_tfp   = g_Y - kontrib_modal - kontrib_tk) %>%
    select(Code_Prov, Year, Prov = Pre_Prov, all_of(KOL_HASIL))

  cat(sprintf("%-5s | b1 = %.6f  b2 = %.6f  | baris %d\n",
              label, b1, b2, nrow(panel)))
  list(panel = panel, b1 = b1, b2 = b2)
}

cat("=============== 1. Panel per basis ===============\n")
adhk <- susun("01 Data/TFP/output/modal_riil", "ADHK")
adhb <- susun("01 Data/TFP/output/adhb",       "ADHB")

# 2) Kunci baris dari workbook dataset umum ----
# Sheet tempel diurutkan mengikuti sheet tujuan, bukan mengikuti urutan alami.
# Kalau suatu saat Eqi menyortir "Analisis Luaran 2", skrip ini ikut menyesuaikan
# tanpa disunting - dan assertion 3 di bawah yang membuktikannya.
cat("\n=============== 2. Kunci baris tujuan ===============\n")
stopifnot(file.exists(F_UMUM))
kunci <- read.xlsx(F_UMUM, sheet = "Analisis Luaran 2", cols = 1:3) %>%
  select(Code_Prov, Year, Prov)
cat(sprintf("Kunci terbaca dari 'Analisis Luaran 2': %d baris\n", nrow(kunci)))

tempel <- kunci %>%
  left_join(adhb$panel, by = c("Code_Prov", "Year", "Prov")) %>%
  select(all_of(KOL_HASIL))

# 3) Tiga pemeriksaan ----
cat("\n=============== 3. Pemeriksaan ===============\n")

# (1) Bentuk panel. 34 provinsi x 9 tahun, tanpa lubang, di kedua basis.
stopifnot(
  nrow(adhk$panel) == 306, nrow(adhb$panel) == 306,
  n_distinct(adhk$panel$Code_Prov) == 34, n_distinct(adhb$panel$Code_Prov) == 34,
  identical(as.integer(sort(unique(adhk$panel$Year))), 2017:2025),
  identical(as.integer(sort(unique(adhb$panel$Year))), 2017:2025)
)
cat("1. Bentuk panel 306 x 34 x 2017-2025 di kedua basis: lolos\n")

# (2) Identitas dekomposisi per baris. Bukan aljabar kosong: ia menangkap kolom
#     yang tergeser dan lag yang bocor lintas provinsi.
sisa <- c(with(adhk$panel, kontrib_modal + kontrib_tk + kontrib_tfp - g_Y),
          with(adhb$panel, kontrib_modal + kontrib_tk + kontrib_tfp - g_Y))
maks <- max(abs(sisa), na.rm = TRUE)
stopifnot(maks < 1e-12)
cat(sprintf("2. Identitas kontribusi = g_Y, simpangan maks %.3e: lolos\n", maks))

# (3) Urutan sheet tempel. Yang paling menentukan, sebab penempelannya blok utuh.
#     Dijoin ulang lalu dibandingkan elemen demi elemen, bukan diasumsikan sama.
banding <- kunci %>%
  left_join(adhb$panel %>% mutate(ada = TRUE),
            by = c("Code_Prov", "Year", "Prov"))
stopifnot(
  nrow(tempel) == nrow(kunci),
  all(banding$ada),
  identical(paste(kunci$Code_Prov, kunci$Year), paste(banding$Code_Prov, banding$Year)),
  identical(names(tempel), KOL_HASIL)
)
cat(sprintf("3. Urutan %d baris sheet tempel sama dengan 'Analisis Luaran 2': lolos\n",
            nrow(tempel)))

# 4) Sheet penjelas ----
catatan <- tibble::tribble(
  ~kolom,            ~arti,
  "Code_Prov",       "Kode provinsi BPS, 34 provinsi sebelum pemekaran Papua",
  "Year",            "Tahun, 2017-2025",
  "Prov",            "Nama provinsi; sama dengan kolom Prov di 'Analisis Luaran 2'",
  "log_lab_tot",     "ln tenaga kerja total, jumlah 17 kolom sektoral. Sama di kedua basis",
  "logtfp_it",       "ln TFP, residual model tak-terestriksi (non-CRS/DRS)",
  "logtfp_it_crs",   "ln TFP, model per-pekerja skala hasil konstan",
  "g_Y",             "Laju PDRB, selisih ln x 100 (poin persen per tahun)",
  "g_K",             "Laju PMTB, selisih ln x 100",
  "g_L",             "Laju tenaga kerja, selisih ln x 100",
  "kontrib_modal",   "b1 x g_K",
  "kontrib_tk",      "b2 x g_L",
  "kontrib_tfp",     "g_Y - kontrib_modal - kontrib_tk, residual per definisi"
)

basis <- tibble::tribble(
  ~sheet, ~output,   ~modal,    ~b1,        ~b2,        ~sumber,
  "ADHK", "9_ADHK",  "4_ADHK",  adhk$b1,    adhk$b2,    "01 Data/TFP/output/modal_riil",
  "ADHB", "9_ADHB",  "4_ADHB",  adhb$b1,    adhb$b2,    "01 Data/TFP/output/adhb"
)

kaveat <- tibble::tribble(
  ~hal, ~isi,
  "Tenaga kerja 2025",
  paste("Sakernas 2025 belum terbit. Kolom *_TenagaKerja 2025 disalin dari 2024",
        "(LOCF) dan *_RataUpah 2025 = 2024 x (UMP_2025/UMP_2024). Sumbernya sheet",
        "Keterangan workbook data, baris 181."),
  "Akibatnya pada 2025",
  paste("g_L 2025 nyaris nol di seluruh provinsi, sehingga kontrib_tk 2025 nyaris",
        "nol dan kontrib_tfp 2025 menyerap hampir seluruh g_Y. Baris 2025 adalah",
        "artefak imputasi, bukan lonjakan produktivitas."),
  "Elastisitas ikut bergeser",
  paste("Ke-34 observasi 2025 menaikkan b1 dan menurunkan b2, sebab modal bertambah",
        "sementara tenaga kerja diam. Basis riil: b1 0,401899 -> 0,475304."),
  "Residual ADHB bukan TFP",
  paste("Pada basis ADHB kedua sisi persamaan harga berlaku, jadi residualnya memuat",
        "inflasi harga output. Sebut 'sisa nominal', bukan TFP."),
  "Jangan disajikan tahun-per-tahun",
  paste("g(PMTB) ~ g(stok modal) menuntut rasio investasi terhadap stok yang stabil,",
        "dan itu terlanggar telak pada 2020-2021. Pakai rata-rata periode."),
  "Baris 2017 kosong",
  "Tahun basis tidak punya laju, jadi enam kolom laju dan kontribusinya NA."
)

# 5) Tulis dua salinan ----
cat("\n=============== 4. Penulisan ===============\n")
isi <- list(ADHK              = adhk$panel,
            ADHB              = adhb$panel,
            tempel_CD_CL_adhb = tempel,
            basis             = basis,
            catatan           = catatan,
            kaveat            = kaveat)

for (tujuan in c(file.path("01 Data/TFP/output/adhb", NAMA), file.path(DIR_UMUM, NAMA))) {
  write.xlsx(isi, tujuan, overwrite = TRUE)
  cat(sprintf("tersimpan: %s (%.0f KB)\n", tujuan, file.size(tujuan) / 1024))
}

cat("\n=============== SELESAI ===============\n")
