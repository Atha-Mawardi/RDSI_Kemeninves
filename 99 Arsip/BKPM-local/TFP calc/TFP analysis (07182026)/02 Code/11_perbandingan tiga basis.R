# ==============================================================================
# Perbandingan tiga basis harga, berdampingan
#
# Ia TIDAK menghitung apa pun yang baru. Seluruh angkanya dibaca dari keluaran
# skrip 01 dan 02 di ketiga folder, lalu dijajarkan dalam satu tabel.
#
#   nominal (terbit) : terikat 9_ADHK riil, modal `pmtb` harga BERLAKU
#                      -> basis harga kedua sisi persamaan tidak sama
#   riil             : terikat 9_ADHK riil, modal 4_ADHK riil
#   adhb             : terikat 9_ADHB nominal, modal 4_ADHB nominal
#
# Peringatan yang melekat pada tabel ini: kolom `adhb` BUKAN TFP. Residual dari
# regresi output nominal memuat inflasi harga output. Ia pembanding untuk
# mengukur seberapa besar deflator menggerakkan angka versi terbit, bukan ukuran
# produktivitas. Karena itu barisnya dilabeli "sisa", bukan "TFP".
#
# Jalankan dari root sub-project TFP:
#   Rscript "02 Code/11_perbandingan tiga basis.R"
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(openxlsx)
})

BASIS <- tibble(
  kode   = c("nominal", "riil", "adhb"),
  label  = c("Nominal (terbit)", "Riil", "ADHB (nominal penuh)"),
  folder = c("03 Output", "03 Output (modal riil)", "03 Output (ADHB)"),
  terikat = c("9_ADHK (riil)", "9_ADHK (riil)", "9_ADHB (nominal)"),
  modal   = c("pmtb (nominal)", "4_ADHK (riil)", "4_ADHB (nominal)")
)

out_dir <- "03 Output (ADHB)"     # tabel pembanding tinggal bersama basis termuda
stopifnot(all(dir.exists(BASIS$folder)))

cat("=============== Perbandingan tiga basis harga ===============\n\n")

# ==============================================================================
# 1. Parameter model
# ==============================================================================
baca_par <- function(folder) {
  p <- readRDS(file.path(folder, "parameter_terpilih.rds"))
  # Sebagian field rds bukan skalar (pangsa_nas berisi satu baris per tahun),
  # jadi tiap nilai dipaksa satu angka di sini, bukan diam-diam didaur ulang.
  sk <- function(x) as.numeric(unname(x))[1]
  tibble(b1 = sk(p$b1_un), b2 = sk(p$b2_un),
         b1_crs = sk(p$b1_crs), tren = sk(p$tren_unc))
}

par_tab <- bind_cols(BASIS, map_dfr(BASIS$folder, baca_par)) %>%
  mutate(rts = b1 + b2)

cat("-- 1. Parameter model terpilih (two-way FE, tak-terestriksi) --\n")
print(as.data.frame(par_tab %>%
        select(label, terikat, modal, b1, b2, rts) %>%
        mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

# ==============================================================================
# 2. Dekomposisi nasional, skenario F (basis utama tiap basis harga)
# ==============================================================================
baca_dek <- function(folder) {
  read.xlsx(file.path(folder, "Dekomposisi Nasional.xlsx"), sheet = "dekomposisi") %>%
    filter(skenario == "F. Tanpa CRS", periode == "2018-2024 (penuh)") %>%
    select(gY, gK, gL, kontrib_K, kontrib_L, sisa,
           pangsa_K, pangsa_L, pangsa_sisa)
}

dek_tab <- bind_cols(BASIS, map_dfr(BASIS$folder, baca_dek))

cat("\n-- 2. Dekomposisi nasional 2018-2024, skenario F --\n")
print(as.data.frame(dek_tab %>%
        select(label, gY, gK, gL, kontrib_K, kontrib_L, sisa) %>%
        mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

cat("\n   Pangsa terhadap pertumbuhan (persen):\n")
print(as.data.frame(dek_tab %>%
        select(label, pangsa_K, pangsa_L, pangsa_sisa) %>%
        mutate(across(where(is.numeric), ~round(.x, 1)))), row.names = FALSE)

# Identitas dekomposisi wajib tertutup di ketiga basis.
stopifnot(max(abs(dek_tab$kontrib_K + dek_tab$kontrib_L + dek_tab$sisa - dek_tab$gY)) < 1e-9)

# ==============================================================================
# 3. Selisih antar basis - inilah yang ingin dibaca
# ==============================================================================
amb <- function(kode, kolom) dek_tab[[kolom]][dek_tab$kode == kode]

selisih <- tibble(
  besaran = c("Pertumbuhan output (gY)", "Pertumbuhan modal (gK)",
              "Elastisitas modal (b1)", "Kontribusi modal (poin)",
              "Sisa (poin)", "Pangsa sisa (persen)"),
  nominal = c(amb("nominal", "gY"), amb("nominal", "gK"),
              par_tab$b1[par_tab$kode == "nominal"],
              amb("nominal", "kontrib_K"), amb("nominal", "sisa"),
              amb("nominal", "pangsa_sisa")),
  riil    = c(amb("riil", "gY"), amb("riil", "gK"),
              par_tab$b1[par_tab$kode == "riil"],
              amb("riil", "kontrib_K"), amb("riil", "sisa"),
              amb("riil", "pangsa_sisa")),
  adhb    = c(amb("adhb", "gY"), amb("adhb", "gK"),
              par_tab$b1[par_tab$kode == "adhb"],
              amb("adhb", "kontrib_K"), amb("adhb", "sisa"),
              amb("adhb", "pangsa_sisa"))
) %>%
  mutate(riil_minus_nominal = riil - nominal,
         adhb_minus_riil    = adhb - riil)

cat("\n-- 3. Selisih antar basis --\n")
print(as.data.frame(selisih %>%
        mutate(across(where(is.numeric), ~round(.x, 3)))), row.names = FALSE)

# ==============================================================================
# 4. Deflator: berapa besar bagian harga di dalam selisihnya
# ==============================================================================
# gY dan gK basis adhb dikurangi padanan riilnya = laju deflator implisit.
defl <- tibble(
  seri = c("Output", "Modal"),
  nominal_pct = c(amb("adhb", "gY"), amb("adhb", "gK")),
  riil_pct    = c(amb("riil", "gY"), amb("riil", "gK"))
) %>% mutate(deflator_pct = nominal_pct - riil_pct)

cat("\n-- 4. Laju deflator implisit (nominal dikurangi riil, %/thn) --\n")
print(as.data.frame(defl %>% mutate(across(where(is.numeric), ~round(.x, 2)))),
      row.names = FALSE)

# ==============================================================================
# 5. Dekomposisi per pulau, ketiga basis
# ==============================================================================
baca_pulau <- function(folder) {
  read.xlsx(file.path(folder, "Dekomposisi Nasional.xlsx"), sheet = "dekomposisi_pulau") %>%
    filter(skenario == "F. Tanpa CRS") %>%
    select(Pulau, gY, kontrib_K, kontrib_L, sisa)
}

pulau_tab <- BASIS %>%
  select(kode, label, folder) %>%
  mutate(data = map(folder, baca_pulau)) %>%
  select(-folder) %>%
  unnest(data)

cat("\n-- 5. Sisa per pulau (poin persen) --\n")
print(as.data.frame(
  pulau_tab %>%
    select(kode, Pulau, sisa) %>%
    pivot_wider(names_from = kode, values_from = sisa) %>%
    mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

# ==============================================================================
# 6. Tulis workbook
# ==============================================================================
CATATAN <- tibble(butir = c(
  "Kolom adhb BUKAN TFP. Residual regresi output nominal memuat inflasi harga output.",
  "Basis nominal (terbit) mencampur basis harga: terikat riil, modal harga berlaku.",
  "Basis riil satu-satunya yang kedua sisinya harga konstan tahun dasar 2010.",
  "Basis adhb konsisten harga berlaku, tapi melanggar langkah S0 kaskade dengan sengaja.",
  "Seluruh angka di sini dibaca dari keluaran skrip 01 dan 02; tidak ada hitungan baru.",
  "Skenario F = elastisitas two-way FE apa adanya, tanpa CRS dipaksakan.",
  "Simulasi trajektori basis adhb tidak digambar: sasaran 8 persen Masterplan riil."
))

write.xlsx(list(parameter      = par_tab %>% select(-folder),
                dekomposisi    = dek_tab %>% select(-folder),
                selisih        = selisih,
                deflator       = defl,
                per_pulau      = pulau_tab,
                catatan        = CATATAN),
           file.path(out_dir, "Perbandingan Tiga Basis.xlsx"))

cat(sprintf("\n=============== SELESAI ===============\nKeluaran: %s\n",
            file.path(out_dir, "Perbandingan Tiga Basis.xlsx")))
