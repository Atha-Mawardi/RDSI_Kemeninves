# SCRIPT OVERVIEW --------------------------------------
# Diagnostik satuan harga variabel modal.
#
# Pertanyaannya satu: kolom `pmtb` yang dipakai seluruh analisis itu harga
# berlaku atau harga konstan? Kalau harga berlaku, maka model meregresikan
# output riil (`9_ADHK`) pada modal nominal, dan dekomposisinya salah.
#
# Input  : 01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
# Output : 01 Data/TFP/output/modal_riil/Diagnostik Modal.xlsx
#
# Skrip ini TIDAK mengubah apa pun di 01 Data/TFP/output/nominal/ (versi terbit).
#
# Jalankan dari root project:
#   Rscript "02 Code/TFP/estimasi/00_diagnostik modal.R" > "01 Data/TFP/output/modal_riil/log_00_diagnostik.txt" 2>&1
# ------------------------------------------------------

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(plm)
  library(lmtest)
  library(sandwich)
})

data_file <- "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
out_dir   <- "01 Data/TFP/output/modal_riil"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

fmt <- function(x, d = 4) formatC(x, format = "f", digits = d)

# ==============================================================================
# 1. Data
# ==============================================================================
# 2025 ada di berkas tapi kolom pmtb/tenaga kerja kosong; plm membuangnya lewat
# listwise deletion. Di sini pembuangan itu dibuat eksplisit.
df <- read.xlsx(data_file, sheet = "Sheet1") %>%
  filter(Year >= 2017, Year <= 2024)

tk_cols <- grep("_TenagaKerja$", names(df), value = TRUE)
stopifnot(length(tk_cols) == 17)

df <- df %>%
  arrange(Code_Prov, Year) %>%
  mutate(
    L = rowSums(across(all_of(tk_cols))),
    # Empat kandidat variabel modal, apa adanya dari berkas.
    K_pakai = pmtb,        # yang dipakai seluruh analisis terbit
    K_nom   = `4_ADHB`,    # PMTB harga berlaku
    K_riil  = `4_ADHK`,    # PMTB harga konstan
    Y_riil  = `9_ADHK`,
    Y_nom   = `9_ADHB`
  )

stopifnot(all(table(df$Year) == 34), nrow(df) == 34 * 8)
cat("=============== 0. Data ===============\n")
cat(sprintf("Panel: %d provinsi x %d tahun = %d observasi\n",
            n_distinct(df$Code_Prov), n_distinct(df$Year), nrow(df)))

# ==============================================================================
# 2. Satuan tiap kolom
# ==============================================================================
# Satuan di berkas ini tidak seragam, dan nama berkasnya ("Penyetaraan Satuan
# Miliar") menyesatkan. Diperiksa lewat perbandingan agregat 2017 terhadap
# angka nasional yang diketahui.
cat("\n=============== 1. Satuan kolom (agregat 2017) ===============\n")
satuan <- df %>%
  filter(Year == 2017) %>%
  summarise(across(c(K_pakai, K_nom, K_riil, Y_riil, Y_nom), sum)) %>%
  pivot_longer(everything(), names_to = "kolom", values_to = "jumlah_2017") %>%
  mutate(
    sumber = c("pmtb", "4_ADHB", "4_ADHK", "9_ADHK", "9_ADHB"),
    satuan_dugaan = c("miliar", "triliun", "juta", "juta", "triliun"),
    triliun_rupiah = jumlah_2017 / c(1e3, 1, 1e6, 1e6, 1)
  )
print(as.data.frame(satuan %>% mutate(across(where(is.numeric), ~signif(.x, 6)))),
      row.names = FALSE)
cat("\nPembanding nasional 2017: PDB riil ~9.912 triliun, PMTB nominal ~4.395 triliun.\n")

# ==============================================================================
# 3. UJI POKOK: pmtb itu harga berlaku atau harga konstan?
# ==============================================================================
# Logikanya: seri nominal dibagi PDRB nominal harusnya stabil; seri riil dibagi
# PDRB riil juga harusnya stabil. Yang tidak stabil menandakan basis harganya
# tidak cocok dengan penyebutnya.
cat("\n=============== 2. UJI POKOK: basis harga `pmtb` ===============\n")

kor <- df %>%
  summarise(
    kor_pmtb_vs_4ADHB = cor(K_pakai, K_nom),
    kor_pmtb_vs_4ADHK = cor(K_pakai, K_riil)
  )
cat(sprintf("Korelasi tingkat provinsi-tahun (n = %d):\n", nrow(df)))
cat(sprintf("  pmtb ~ 4_ADHB (harga berlaku) : %s\n", fmt(kor$kor_pmtb_vs_4ADHB, 6)))
cat(sprintf("  pmtb ~ 4_ADHK (harga konstan) : %s\n", fmt(kor$kor_pmtb_vs_4ADHK, 6)))

nas <- df %>%
  group_by(Year) %>%
  summarise(across(c(K_pakai, K_nom, K_riil, Y_riil, Y_nom), sum), .groups = "drop") %>%
  arrange(Year) %>%
  mutate(
    rasio_pmtb_thd_Ynom = K_pakai * 1e3 / (Y_nom * 1e3),   # sama-sama miliar
    rasio_pmtb_thd_Yriil = K_pakai * 1e3 / (Y_riil / 1e3), # miliar vs miliar
    rasio_Kriil_thd_Yriil = K_riil / Y_riil,
    deflator_pdrb = (Y_nom * 1e6) / Y_riil
  )

cat("\nRasio terhadap PDRB, dinormalkan 2017 = 100:\n")
rasio_tab <- nas %>%
  transmute(
    Year,
    `pmtb / PDRB nominal` = 100 * rasio_pmtb_thd_Ynom / rasio_pmtb_thd_Ynom[1],
    `pmtb / PDRB riil`    = 100 * rasio_pmtb_thd_Yriil / rasio_pmtb_thd_Yriil[1],
    `4_ADHK / PDRB riil`  = 100 * rasio_Kriil_thd_Yriil / rasio_Kriil_thd_Yriil[1],
    `deflator PDRB`       = 100 * deflator_pdrb / deflator_pdrb[1]
  )
print(as.data.frame(rasio_tab %>% mutate(across(-Year, ~round(.x, 1)))), row.names = FALSE)

drift_nom  <- rasio_tab$`pmtb / PDRB nominal`[8] - 100
drift_riil <- rasio_tab$`pmtb / PDRB riil`[8] - 100
cat(sprintf("\nHanyutan 2017->2024: pmtb/PDRB nominal %+.1f%% | pmtb/PDRB riil %+.1f%%\n",
            drift_nom, drift_riil))
cat("Seri yang basis harganya cocok dengan penyebutnya tidak hanyut jauh.\n")

# VONIS. Dijadikan assertion supaya skrip berhenti kalau dataset diganti dan
# kesimpulannya tidak lagi berlaku.
vonis_harga_berlaku <- kor$kor_pmtb_vs_4ADHB > kor$kor_pmtb_vs_4ADHK &&
  abs(drift_nom) < abs(drift_riil)
stopifnot(vonis_harga_berlaku)
cat("\nVONIS: `pmtb` adalah seri HARGA BERLAKU.\n")
cat("  Terikat model `9_ADHK` harga konstan -> model meregresikan output riil pada modal nominal.\n")

# ==============================================================================
# 4. Deflator modal: seragam antarprovinsi?
# ==============================================================================
# Ini menentukan seberapa besar dampaknya ke elastisitas. Di two-way FE, deflator
# yang sama di semua provinsi diserap habis dummy tahun, sehingga b1 tidak
# bergerak. Yang menggerakkan b1 hanya ragam deflator ANTARPROVINSI.
cat("\n=============== 3. Ragam deflator modal antarprovinsi ===============\n")
defl <- df %>%
  mutate(deflator_modal = (K_nom * 1e6) / K_riil) %>%
  group_by(Year) %>%
  summarise(
    rerata = mean(deflator_modal),
    cv_persen = 100 * sd(deflator_modal) / mean(deflator_modal),
    .groups = "drop"
  )
print(as.data.frame(defl %>% mutate(across(-Year, ~round(.x, 3)))), row.names = FALSE)
cat(sprintf("\nKoefisien variasi antarprovinsi: %.1f%% - %.1f%%.\n",
            min(defl$cv_persen), max(defl$cv_persen)))
cat("Hampir seragam, jadi dampak ke elastisitas two-way FE kecil.\n")

# ==============================================================================
# 5. Pertumbuhan agregat: nominal vs riil
# ==============================================================================
# Agregasi mengikuti 02_dekomposisi nasional.R: provinsi dijumlahkan DULU, baru
# dilogkan. Bobotnya menurut ukuran ekonomi.
g <- function(x) 100 * (log(x) - log(dplyr::lag(x)))
seri <- nas %>%
  transmute(Year,
            g_Y      = g(Y_riil),
            g_K_nom  = g(K_pakai),
            g_K_riil = g(K_riil),
            g_L      = g(df %>% group_by(Year) %>% summarise(L = sum(L), .groups = "drop") %>% pull(L)))

cat("\n=============== 4. Pertumbuhan nasional (%/thn) ===============\n")
print(as.data.frame(seri %>% mutate(across(-Year, ~round(.x, 2)))), row.names = FALSE)

rerata <- function(d, dari) {
  d %>% filter(Year >= dari) %>%
    summarise(gY = mean(g_Y), gK_nom = mean(g_K_nom),
              gK_riil = mean(g_K_riil), gL = mean(g_L))
}
r_penuh <- rerata(seri, 2018)
r_pasca <- rerata(seri, 2022)

cat("\nRata-rata per jendela:\n")
jendela <- bind_rows(
  r_penuh %>% mutate(jendela = "2018-2024 (penuh)"),
  r_pasca %>% mutate(jendela = "2022-2024 (pasca-COVID)")
) %>% select(jendela, everything())
print(as.data.frame(jendela %>% mutate(across(where(is.numeric), ~round(.x, 2)))),
      row.names = FALSE)

# ==============================================================================
# 6. Elastisitas: modal nominal vs modal riil
# ==============================================================================
pd <- pdata.frame(
  df %>% mutate(lY = log(Y_riil), lK_nom = log(K_pakai),
                lK_riil = log(K_riil), lL = log(L)),
  index = c("Code_Prov", "Year")
)
vc_dk <- function(m) vcovSCC(m, type = "HC1", maxlag = 2)

ambil <- function(f, nama_k) {
  m  <- plm(f, pd, model = "within")
  ct <- coeftest(m, vcov = vc_dk(m))
  tibble(b1 = ct[nama_k, 1], se_b1 = ct[nama_k, 2],
         b2 = ct["lL", 1],   se_b2 = ct["lL", 2]) %>%
    mutate(rts = b1 + b2)
}

cat("\n=============== 5. Elastisitas two-way FE ===============\n")
el <- bind_rows(
  ambil(lY ~ lK_nom  + lL + factor(Year), "lK_nom")  %>% mutate(modal = "nominal (pmtb)"),
  ambil(lY ~ lK_riil + lL + factor(Year), "lK_riil") %>% mutate(modal = "riil (4_ADHK)")
) %>% select(modal, everything())
print(as.data.frame(el %>% mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

# Dugaan yang diuji: karena deflator hampir seragam antarprovinsi, b1 nyaris
# tidak bergerak saat modal diganti ke seri riil.
stopifnot(abs(el$b1[1] - el$b1[2]) < 0.01)
cat("\nb1 bergeser kurang dari 0,01 poin. Sesuai dugaan: dummy tahun menyerap deflator bersama.\n")

# ==============================================================================
# 7. Tangga atenuasi, kedua versi
# ==============================================================================
tangga <- function(k) {
  f0 <- as.formula(sprintf("lY ~ %s + lL", k))
  bind_rows(lapply(c("pooling", "random", "within"), function(md) {
    m <- plm(f0, pd, model = md)
    tibble(spesifikasi = md, b1 = coef(m)[k], b2 = coef(m)["lL"])
  })) %>%
    bind_rows(tibble(spesifikasi = "two-way",
                     b1 = coef(plm(update(f0, . ~ . + factor(Year)), pd, model = "within"))[k],
                     b2 = coef(plm(update(f0, . ~ . + factor(Year)), pd, model = "within"))["lL"])) %>%
    mutate(rts = b1 + b2)
}
cat("\n=============== 6. Tangga atenuasi ===============\n")
tg <- bind_rows(
  tangga("lK_nom")  %>% mutate(modal = "nominal (pmtb)"),
  tangga("lK_riil") %>% mutate(modal = "riil (4_ADHK)")
) %>% select(modal, everything())
print(as.data.frame(tg %>% mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

# ==============================================================================
# 8. Dampak ke dekomposisi
# ==============================================================================
# Inilah yang benar-benar berubah. Elastisitas nyaris tetap, tapi gK agregat
# jatuh, sehingga kontribusi modal mengecil dan sisa membesar.
dekom <- function(gY, gK, gL, b1, b2) {
  kK <- b1 * gK; kL <- b2 * gL
  tibble(gY = gY, kontrib_modal = kK, kontrib_tk = kL, sisa = gY - kK - kL,
         pangsa_modal = 100 * kK / gY, pangsa_sisa = 100 * (gY - kK - kL) / gY)
}
b1n <- el$b1[el$modal == "nominal (pmtb)"]; b2n <- el$b2[el$modal == "nominal (pmtb)"]
b1r <- el$b1[el$modal == "riil (4_ADHK)"]; b2r <- el$b2[el$modal == "riil (4_ADHK)"]

cat("\n=============== 7. Dekomposisi: nominal vs riil ===============\n")
banding <- bind_rows(
  dekom(r_penuh$gY, r_penuh$gK_nom,  r_penuh$gL, b1n, b2n) %>% mutate(versi = "2018-2024 nominal"),
  dekom(r_penuh$gY, r_penuh$gK_riil, r_penuh$gL, b1r, b2r) %>% mutate(versi = "2018-2024 riil"),
  dekom(r_pasca$gY, r_pasca$gK_nom,  r_pasca$gL, b1n, b2n) %>% mutate(versi = "2022-2024 nominal"),
  dekom(r_pasca$gY, r_pasca$gK_riil, r_pasca$gL, b1r, b2r) %>% mutate(versi = "2022-2024 riil")
) %>% select(versi, everything())
print(as.data.frame(banding %>% mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

# Identitas dekomposisi wajib tertutup di tiap baris.
stopifnot(all(abs(banding$gY - banding$kontrib_modal - banding$kontrib_tk - banding$sisa) < 1e-10))
cat("\nIdentitas dekomposisi tertutup di keempat baris.\n")

# ==============================================================================
# 9. Tulis keluaran
# ==============================================================================
write.xlsx(
  list(satuan_kolom   = satuan,
       rasio_pdrb     = rasio_tab,
       deflator_modal = defl,
       seri_nasional  = seri,
       rerata_jendela = jendela,
       elastisitas    = el,
       tangga_atenuasi = tg,
       dekomposisi_banding = banding),
  file = file.path(out_dir, "Diagnostik Modal.xlsx"),
  overwrite = TRUE, colWidths = "auto"
)

cat(sprintf("\n=============== SELESAI ===============\nKeluaran: %s\n",
            file.path(out_dir, "Diagnostik Modal.xlsx")))
