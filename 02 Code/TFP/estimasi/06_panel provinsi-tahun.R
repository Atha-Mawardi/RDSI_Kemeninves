# SCRIPT OVERVIEW --------------------------------------
# Panel provinsi x tahun: log TFP dua versi + kontribusi pertumbuhan tiga faktor.
#
# Input  : 03 Output (modal riil)/Hasil Estimasi TFP.xlsx  (sheet data_tfp, tfp_provinsi)
#          03 Output (modal riil)/parameter_terpilih.rds   (b1_un, b2_un)
# Output : 03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx
#
# Skrip ini TIDAK mengestimasi apa pun. Elastisitas dibaca dari
# parameter_terpilih.rds (skenario F, tanpa CRS); log TFP dibaca apa adanya dari
# sheet data_tfp. Yang dihitung di sini hanya selisih log dan identitas
# dekomposisi, sama seperti skrip 10 tetapi per provinsi, bukan nasional.
#
# DUA KAVEAT yang ikut ditulis ke sheet catatan, karena kolomnya gampang salah pakai:
#   (1) logtfp_CRS berbentuk per-pekerja, log(Y/L) - b1_crs*log(K/L). Levelnya
#       TIDAK sebanding dengan logtfp_nonCRS yang berbentuk tiga suku penuh.
#       Yang boleh dibandingkan peringkat dan pergerakannya, bukan selisih level.
#   (2) Aturan penyajian skrip 02 melarang dekomposisi tahun-per-tahun masuk
#       laporan: PMTB itu arus, jadi kolom tahunan berayun mengikuti investasi.
#       Berkas ini alat kerja, bukan bahan tabel laporan.
#
# Path relatif dari ROOT project (.Rproj), mengikuti konvensi CLAUDE.md.
# Jalankan: Rscript "02 Code/06_panel provinsi-tahun.R" dari root.

# 1) Persiapan ----
rm(list = ls())

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
})

# Sakelar basis harga modal - sama dengan skrip 01/02/03/04/08/10.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"
dir_out <- switch(BASIS_MODAL,
                  riil    = "01 Data/TFP/output/modal_riil",
                  nominal = "01 Data/TFP/output/nominal",
                  adhb    = "01 Data/TFP/output/adhb")

f_est <- file.path(dir_out, "Hasil Estimasi TFP.xlsx")
f_par <- file.path(dir_out, "parameter_terpilih.rds")
stopifnot(file.exists(f_est), file.exists(f_par))
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, dir_out))

# Nama kolom terikat mengikuti basis harganya, sama seperti di skrip 01.
kol_y <- if (BASIS_ADHB) "log_ADHB_Tot" else "log_ADHK_Tot"

# 2) Data ----
par_tfp <- readRDS(f_par)
b1 <- unname(par_tfp$b1_un)
b2 <- unname(par_tfp$b2_un)

dat <- read.xlsx(f_est, sheet = "data_tfp")
stopifnot(kol_y %in% names(dat))

# 2025 dibuang dari panel yang diekspor. Alasannya berubah pada 20 Agustus 2026:
# dulu barisnya kosong, sekarang terisi tetapi tenaga kerjanya salinan 2024 (LOCF),
# sehingga g_L 2025 = 0 dan seluruh pertumbuhan output jatuh ke kontrib_tfp.
# Alasan kedua tetap teknis: rentang tautan luar Excel terkunci di 272 baris.
# Panel yang memuat 2025 dihasilkan skrip 16, bukan skrip ini.
dat_penuh <- dat
n_2025 <- sum(dat$Year == 2025)
dat <- dat %>% filter(Year <= 2024)
cat(sprintf("Baris 2025 dibuang dari panel ekspor (tenaga kerja LOCF): %d\n", n_2025))

# Laju dari selisih log x 100 = poin persen per tahun, sama seperti skrip 02.
# Baris 2017 ber-NA karena tahun basis, dan itu dipertahankan apa adanya.
panel <- dat %>%
  arrange(Code_Prov, Year) %>%
  group_by(Code_Prov) %>%
  mutate(g_Y = 100 * (.data[[kol_y]]  - lag(.data[[kol_y]])),
         g_K = 100 * (log_pmtb        - lag(log_pmtb)),
         g_L = 100 * (log_lab_tot     - lag(log_lab_tot))) %>%
  ungroup() %>%
  mutate(kontrib_modal = b1 * g_K,
         kontrib_tk    = b2 * g_L,
         kontrib_tfp   = g_Y - kontrib_modal - kontrib_tk) %>%
  select(Code_Prov, Pre_Prov, Pulau, Year,
         logtfp_nonCRS = logtfp_it, logtfp_CRS = logtfp_it_crs,
         g_Y, g_K, g_L, kontrib_modal, kontrib_tk, kontrib_tfp)

# 3) Uji terhadap keluaran yang sudah ada ----
# Acuan per basis harga modal, disalin dari log_02_dekomposisi.txt skenario F
# (elastisitas terestimasi tanpa restriksi CRS) dan dari acuan skrip 10.
#
# Diperbarui 20 Agustus 2026: estimasi memuat 2025, N 272 -> 306. Panel ini tetap
# berhenti di 2024, sebab rentang tautan luar Excel terkunci di 272 baris. Yang
# memuat 2025 adalah skrip 16.
acuan <- switch(BASIS_MODAL,
  riil    = list(b1 = 0.475304, b2 = 0.135782, gY = 3.83, kK = 1.55, kL = 0.28, tfp = 2.00),
  nominal = list(b1 = 0.399673, b2 = 0.191303, gY = 3.83, kK = 2.45, kL = 0.40, tfp = 0.98),
  adhb    = list(b1 = 0.506210, b2 = 0.041713, gY = 6.74, kK = 3.13, kL = 0.09, tfp = 3.52))

stopifnot(
  nrow(panel) == 272,
  n_distinct(panel$Code_Prov) == 34,
  identical(as.integer(sort(unique(panel$Year))), 2017:2024),
  abs(b1 - acuan$b1) < 1e-5,
  abs(b2 - acuan$b2) < 1e-5
)

# Identitas dekomposisi per baris. Bukan aljabar kosong: ia menangkap kolom yang
# tergeser atau lag yang bocor lintas provinsi.
sisa_identitas <- with(panel, kontrib_modal + kontrib_tk + kontrib_tfp - g_Y)
stopifnot(max(abs(sisa_identitas), na.rm = TRUE) < 1e-12)

# Jangkar nasional. Level direkonstruksi dari log, lalu dijumlahkan lintas
# provinsi persis seperti skrip 02 menjumlahkan kolom aslinya. Angkanya harus
# mendarat di log_02_dekomposisi.txt; kalau tidak, sheet data_tfp bukan panel
# yang dipakai dekomposisi nasional.
nas <- dat %>%
  group_by(Year) %>%
  summarise(Y = sum(exp(.data[[kol_y]])), K = sum(exp(log_pmtb)),
            L = sum(exp(log_lab_tot)), .groups = "drop") %>%
  arrange(Year) %>%
  mutate(g_Y = 100 * (log(Y) - lag(log(Y))),
         g_K = 100 * (log(K) - lag(log(K))),
         g_L = 100 * (log(L) - lag(log(L))),
         kontrib_modal = b1 * g_K,
         kontrib_tk    = b2 * g_L,
         kontrib_tfp   = g_Y - kontrib_modal - kontrib_tk) %>%
  filter(!is.na(g_Y))

stopifnot(
  nrow(nas) == 7,
  abs(mean(nas$g_Y)           - acuan$gY)  < 0.005,
  abs(mean(nas$kontrib_modal) - acuan$kK)  < 0.005,
  abs(mean(nas$kontrib_tk)    - acuan$kL)  < 0.005,
  abs(mean(nas$kontrib_tfp)   - acuan$tfp) < 0.005
)

# Jangkar provinsi. Rata-rata logtfp per provinsi wajib sama dengan sheet
# tfp_provinsi yang sudah diterbitkan skrip 01. Dihitung dari dat_penuh, bukan
# dari panel: skrip 01 merata-ratakan seluruh 2017-2025, sedangkan panel berhenti
# di 2024. Membandingkan dua jendela berbeda hanya menghasilkan vonis palsu.
acuan_prov <- read.xlsx(f_est, sheet = "tfp_provinsi")
banding_prov <- dat_penuh %>%
  group_by(Code_Prov) %>%
  summarise(rata_hitung = mean(logtfp_it), .groups = "drop") %>%
  inner_join(acuan_prov %>% select(Code_Prov, logtfp_rata), by = "Code_Prov")
stopifnot(
  nrow(banding_prov) == 34,
  max(abs(banding_prov$rata_hitung - banding_prov$logtfp_rata)) < 1e-9
)
cat("Lima assertion lolos: bentuk panel, elastisitas, identitas, jangkar nasional, jangkar provinsi.\n")

# 4) Ringkasan per provinsi ----
# Rata-rata 2018-2024, sejalan dengan periode dekomposisi nasional. share_tfp
# hanya ditulis bila g_Y rata-ratanya positif: pada penyebut negatif atau dekat
# nol, share bukan angka yang bisa dibaca sebagai porsi.
rata_prov <- panel %>%
  filter(Year >= 2018) %>%
  group_by(Code_Prov, Pre_Prov, Pulau) %>%
  summarise(logtfp_nonCRS_rata = mean(logtfp_nonCRS),
            logtfp_CRS_rata    = mean(logtfp_CRS),
            g_Y = mean(g_Y), g_K = mean(g_K), g_L = mean(g_L),
            kontrib_modal = mean(kontrib_modal),
            kontrib_tk    = mean(kontrib_tk),
            kontrib_tfp   = mean(kontrib_tfp), .groups = "drop") %>%
  mutate(share_tfp_pct = ifelse(g_Y > 0.5, 100 * kontrib_tfp / g_Y, NA_real_)) %>%
  arrange(desc(kontrib_tfp))

n_share_kosong <- sum(is.na(rata_prov$share_tfp_pct))

# 5) Cetak angkanya ke log ----
cat("\n=============== Elastisitas yang dipakai ===============\n")
cat(sprintf("b1 (modal) = %.6f | b2 (tenaga kerja) = %.6f | b1+b2 = %.4f\n",
            b1, b2, b1 + b2))

cat("\n=============== Jangkar nasional (poin persen) ===============\n")
print(as.data.frame(nas %>%
                      select(Year, g_Y, g_K, g_L,
                             kontrib_modal, kontrib_tk, kontrib_tfp) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)
cat(sprintf("Rata-rata 2018-2024: gPDRB %.2f | modal %.2f | TK %.2f | TFP %.2f\n",
            mean(nas$g_Y), mean(nas$kontrib_modal),
            mean(nas$kontrib_tk), mean(nas$kontrib_tfp)))

cat("\n=============== Rata-rata per provinsi 2018-2024 ===============\n")
print(as.data.frame(rata_prov %>%
                      select(Pre_Prov, Pulau, g_Y, kontrib_modal, kontrib_tk,
                             kontrib_tfp, share_tfp_pct) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)
cat(sprintf("Provinsi tanpa share_tfp_pct (g_Y rata-rata <= 0,5): %d\n", n_share_kosong))

cat("\n=============== Dua baris contoh dari sheet panel ===============\n")
print(as.data.frame(panel %>%
                      filter((Pre_Prov == "Aceh" & Year == 2018) |
                             (Code_Prov == 31 & Year == 2020)) %>%
                      mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

# 6) Ekspor ----
catatan <- tibble::tribble(
  ~kolom,               ~arti,                                                              ~sumber,
  "Code_Prov",          "kode provinsi BPS",                                                "data_tfp",
  "Pre_Prov",           "nama provinsi",                                                    "data_tfp",
  "Pulau",              "pengelompokan enam pulau",                                         "data_tfp",
  "Year",               "tahun, 2017-2024",                                                 "data_tfp",
  "logtfp_nonCRS",      "log TFP tiga suku penuh: log Y - b1 log K - b2 log L",             "data_tfp kolom logtfp_it",
  "logtfp_CRS",         "log TFP bentuk per-pekerja: log(Y/L) - b1_crs log(K/L)",           "data_tfp kolom logtfp_it_crs",
  "g_Y",                "laju PDRB harga konstan, poin persen per tahun",                   "selisih log x 100",
  "g_K",                "laju PMTB harga konstan, poin persen per tahun",                   "selisih log x 100",
  "g_L",                "laju tenaga kerja, poin persen per tahun",                         "selisih log x 100",
  "kontrib_modal",      "b1 x g_K, poin persen",                                            "hitungan skrip 13",
  "kontrib_tk",         "b2 x g_L, poin persen",                                            "hitungan skrip 13",
  "kontrib_tfp",        "g_Y - kontrib_modal - kontrib_tk, poin persen",                    "hitungan skrip 13",
  "share_tfp_pct",      "100 x kontrib_tfp / g_Y, hanya bila g_Y rata-rata > 0,5",          "sheet rata_provinsi")

kaveat <- tibble::tribble(
  ~hal, ~isi,
  "Basis harga",
  sprintf("%s. Y dan K sama-sama harga konstan 2010.", BASIS_MODAL),
  "Elastisitas",
  sprintf("b1 = %.6f, b2 = %.6f, dari two-way FE tanpa restriksi CRS (skenario F).", b1, b2),
  "Level CRS vs non-CRS",
  "logtfp_CRS berbentuk per-pekerja, jadi levelnya tidak sebanding dengan logtfp_nonCRS. Yang boleh dibandingkan peringkat dan pergerakannya.",
  "Tahun basis",
  "Baris 2017 sengaja ber-NA di kolom laju dan kontribusi. 2025 dibuang karena tenaga kerjanya belum terbit.",
  "Batas pemakaian",
  "Dekomposisi tahun-per-tahun tidak boleh masuk laporan. PMTB itu arus, bukan stok, jadi kolom tahunan berayun mengikuti investasi. Laporan memakai rata-rata periode.",
  "Modal diproksi arus",
  "Elastisitas modal bias ke bawah dan kontrib_tfp menyerap sebagian kontribusi modal yang tidak tertangkap.",
  "Penjumlahan provinsi",
  "Rata-rata lintas provinsi tidak sama dengan angka nasional. Nasional dihitung dari level yang dijumlahkan dulu, bukan dari rata-rata provinsi.")

f_keluar <- file.path(dir_out, "Panel TFP Provinsi-Tahun.xlsx")
write.xlsx(list(panel         = panel,
                rata_provinsi = rata_prov,
                catatan       = catatan,
                kaveat        = kaveat),
           f_keluar)

cat("\n=============== SELESAI ===============\n")
cat("Keluaran:", normalizePath(f_keluar), "\n")
