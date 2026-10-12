# SCRIPT OVERVIEW --------------------------------------
# Membuktikan hasil bedah skrip 14 terhadap cadangan sebelum bedah.
#
# Input : ../../../All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
#         ../../../All Dataset/99 Arsip/... (sebelum basis riil).xlsx
#         03 Output (modal riil)/Hasil Estimasi TFP.xlsx      sheet data_tfp
#         03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx sheet panel
# Output : tidak ada berkas; hanya cetakan dan assertion.
#
# Yang diuji ada enam, dan tiga di antaranya menguji hal yang TIDAK berubah.
# Bedah XML gagal dengan cara yang senyap: kolom lain ikut bergeser, atau baris
# tertukar pasangannya. Assertion "tidak bergerak" yang menangkapnya.
#
# Jalankan dari root sub-project TFP:
#   Rscript "02 Code/15_uji dataset umum.R"

rm(list = ls())

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
})

DIR_OUT <- "03 Output (modal riil)"
DIR_DATASET <- "../../../All Dataset"

f_baru  <- file.path(DIR_DATASET, "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx")
f_lama  <- file.path(DIR_DATASET, "99 Arsip",
                     "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar (sebelum basis riil).xlsx")
f_est   <- file.path(DIR_OUT, "Hasil Estimasi TFP.xlsx")
f_panel <- file.path(DIR_OUT, "Panel TFP Provinsi-Tahun.xlsx")
stopifnot(file.exists(f_baru), file.exists(f_lama), file.exists(f_est), file.exists(f_panel))

baru <- read.xlsx(f_baru, sheet = "Sheet1")
lama <- read.xlsx(f_lama, sheet = "Sheet1")
est  <- read.xlsx(f_est, sheet = "data_tfp")
pan  <- read.xlsx(f_panel, sheet = "panel")

KOL_GANTI <- c("log_pmtb", "logtfp_it", "logtfp_it_crs")
KOL_TETAP <- c("log_ADHK_Tot", "log_lab_tot")
KOL_BARU  <- c("g_Y", "g_K", "g_L", "kontrib_modal", "kontrib_tk", "kontrib_tfp")

# 1. Bentuk ----
stopifnot(
  ncol(lama) == 164, ncol(baru) == 170,
  nrow(lama) == 306, nrow(baru) == 306,
  identical(names(baru)[1:164], names(lama)),
  identical(names(baru)[165:170], KOL_BARU)
)
cat("1. Bentuk: 164 -> 170 kolom, 306 baris, urutan kolom lama utuh.\n")

# 2. Kunci baris tidak bergeser ----
stopifnot(identical(baru$Code_Prov, lama$Code_Prov), identical(baru$Year, lama$Year),
          identical(baru$Pre_Prov, lama$Pre_Prov))
cat("2. Kunci baris: Code_Prov, Year, dan Pre_Prov identik dengan cadangan.\n")

# 3. Kolom yang TIDAK boleh bergerak ----
# Seluruh kolom lama kecuali tiga yang memang diganti. Baris 2025 dikecualikan
# di lima kolom hasil pencarian: di sana nol berubah jadi kosong, dan itu memang
# yang diniatkan. Selebihnya harus sama persis.
kol_periksa <- setdiff(names(lama), KOL_GANTI)
KOL_LOOKUP <- c(KOL_TETAP, KOL_GANTI)
sama <- function(k) {
  a <- baru[[k]]; b <- lama[[k]]
  if (k %in% KOL_LOOKUP) { pilih <- baru$Year != 2025; a <- a[pilih]; b <- b[pilih] }
  isTRUE(all.equal(a, b))
}
beda <- kol_periksa[!vapply(kol_periksa, sama, logical(1))]
stopifnot(length(beda) == 0)
cat(sprintf("3. %d kolom lain tidak bergerak, termasuk %s.\n",
            length(kol_periksa), paste(KOL_TETAP, collapse = " dan ")))

# Nol palsu di baris 2025 memang harus hilang. Tiga kolom itu bergantung pada
# tenaga kerja, dan tenaga kerja 2025 belum terbit.
KOL_2025 <- c("log_lab_tot", "logtfp_it", "logtfp_it_crs")
b25 <- baru[baru$Year == 2025, ]
l25 <- lama[lama$Year == 2025, ]
stopifnot(nrow(b25) == 34, all(is.na(b25[, KOL_2025])), all(l25[, KOL_2025] == 0))
# Y dan K 2025 ada datanya, jadi keduanya wajib tetap terisi dan tidak bergeser.
stopifnot(!any(is.na(b25$log_ADHK_Tot)), isTRUE(all.equal(b25$log_ADHK_Tot, l25$log_ADHK_Tot)))
cat("3b. Baris 2025: nol palsu di tiga kolom jadi kosong; log PDRB tetap terisi.\n")

# 4. Tiga kolom yang diganti ----
# Pasangannya dicari lewat Code_Prov dan Year, bukan lewat urutan baris.
gab <- baru %>%
  select(Code_Prov, Year, all_of(KOL_GANTI)) %>%
  inner_join(est %>% select(Code_Prov, Year, all_of(KOL_GANTI)),
             by = c("Code_Prov", "Year"), suffix = c("_wb", "_est")) %>%
  filter(!is.na(logtfp_it_est))
stopifnot(nrow(gab) == 272)
for (k in KOL_GANTI) {
  v <- max(abs(gab[[paste0(k, "_wb")]] - gab[[paste0(k, "_est")]]))
  cat(sprintf("4. %-14s selisih maks terhadap data_tfp basis riil = %.2e\n", k, v))
  stopifnot(v < 1e-12)
}

# Sekaligus dipastikan angkanya memang BERGERAK dari versi nominal. Tanpa uji ini,
# bedah yang gagal diam-diam lolos sebagai "tidak ada selisih".
gerak <- vapply(KOL_GANTI,
                function(k) max(abs(baru[[k]] - lama[[k]]), na.rm = TRUE), numeric(1))
stopifnot(all(gerak > 1))
cat(sprintf("4b. Ketiganya memang bergerak dari versi nominal, gerak maks %.2f.\n", max(gerak)))

# 5. Enam kolom baru ----
gabb <- baru %>%
  select(Code_Prov, Year, all_of(KOL_BARU)) %>%
  inner_join(pan %>% select(Code_Prov, Year, all_of(KOL_BARU)),
             by = c("Code_Prov", "Year"), suffix = c("_wb", "_pan")) %>%
  filter(!is.na(g_Y_pan))
stopifnot(nrow(gabb) == 238)
for (k in KOL_BARU) {
  v <- max(abs(gabb[[paste0(k, "_wb")]] - gabb[[paste0(k, "_pan")]]))
  stopifnot(v < 1e-12)
}
cat("5. Enam kolom baru: 238 baris cocok dengan sheet panel, selisih maks < 1e-12.\n")

# Identitas dekomposisi dibaca ulang dari workbook, bukan dari panel.
sisa <- with(baru, kontrib_modal + kontrib_tk + kontrib_tfp - g_Y)
stopifnot(max(abs(sisa), na.rm = TRUE) < 1e-12)
cat("6. Identitas modal + tenaga kerja + TFP = g_Y berlaku di dalam workbook.\n")

# 7. Baris tanpa pasangan ----
# 2017 tahun basis, 2025 tenaga kerjanya belum terbit. Keduanya wajib kosong di
# enam kolom baru, bukan nol; nol akan terbaca sebagai laju nol yang sebenarnya.
kosong <- baru %>% filter(Year %in% c(2017, 2025))
stopifnot(nrow(kosong) == 68, all(is.na(kosong[, KOL_BARU])))
cat("7. 68 baris 2017 dan 2025 kosong di enam kolom baru, bukan nol.\n")

cat("\n=============== Contoh baris, dibaca dari workbook ===============\n")
print(as.data.frame(baru %>%
                      filter(Pre_Prov %in% c("Aceh", "DKI Jakarta"), Year %in% 2018:2020) %>%
                      select(Pre_Prov, Year, log_pmtb, logtfp_it, g_Y,
                             kontrib_modal, kontrib_tk, kontrib_tfp) %>%
                      mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

cat("\n=============== SEMUA UJI LOLOS ===============\n")
