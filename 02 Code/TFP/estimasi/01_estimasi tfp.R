# ==============================================================================
# Estimasi TFP provinsi - model dan seleksi
#
# Model Solow/Cobb-Douglas: log Y = a + b1 log K + b2 log L + u_i + e_it
# Elastisitas DIESTIMASI dari panel provinsi, bukan diimpor dari literatur.
#
# Menggantikan ../01_analisis TFP provinsi.R yang angkanya mengandung tiga
# kesalahan (lihat 00 Docs/memory_tfp.md bagian 5). Yang baru di sini:
#   (1) uji Wald returns to scale + model CRS bentuk per-pekerja
#   (2) two-way FE: efek tahun sebagai deret produktivitas agregat
#   (3) Driscoll-Kraay SE
#   (4) panel berbobot pangsa output (uji bias agregasi)
#   (5) PMTB lag-1
#   (6) kaskade seleksi model S0-S6 yang deterministik
#
# Urutan kaskade ditulis SEBELUM hasilnya dilihat - lihat bagian 4.
# ==============================================================================

library(tidyverse)
library(openxlsx)
library(plm)
library(lmtest)
library(sandwich)
library(car)

data_file <- "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"

# ==============================================================================
# SAKELAR BASIS HARGA MODAL
# ==============================================================================
# Kolom `pmtb` yang dipakai versi terbit ternyata HARGA BERLAKU, sementara
# variabel terikat `9_ADHK` harga konstan. Model lama karena itu meregresikan
# output riil pada modal nominal. Buktinya di 00_diagnostik modal.R:
#   - korelasi pmtb~4_ADHB = 0,99994 lawan pmtb~4_ADHK = 0,99538
#   - rasio pmtb terhadap PDRB riil hanyut +17,4% sepanjang 2017-2024,
#     sedangkan rasio 4_ADHK terhadap PDRB riil hanya -3,9%
#
# Sakelar ini memilih basis harga modal SEKALIGUS folder keluarannya, supaya
# kedua versi tetap direproduksi dari satu skrip yang sama - bukan dari dua
# salinan berkas yang lama-lama melenceng.
#   "riil"    -> 4_ADHK harga konstan -> 03 Output (modal riil)
#   "nominal" -> pmtb harga berlaku   -> 03 Output   (versi terbit, jangan diubah)
#   "adhb"    -> 4_ADHB harga berlaku -> 03 Output (ADHB)
#
# Basis "adhb" memindahkan SEKALIGUS variabel terikat ke `9_ADHB`, jadi kedua sisi
# persamaan konsisten harga berlaku. Ia melanggar langkah S0 kaskade dengan sengaja
# (lihat bagian 4) dan berstatus diagnostik: residualnya memuat inflasi harga output,
# jadi ia BUKAN TFP. Gunanya mengukur berapa besar deflator menggerakkan angka terbit.
#
# Ganti lewat variabel lingkungan tanpa menyunting berkas:
#   BASIS_MODAL=nominal Rscript "02 Code/01_estimasi tfp.R"
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"

# Tanpa cabang default: salah ketik nilai lingkungan berhenti di stopifnot di atas,
# bukan diam-diam menulis ke folder versi terbit.
out_dir <- switch(BASIS_MODAL,
                  riil    = "01 Data/TFP/output/modal_riil",
                  nominal = "01 Data/TFP/output/nominal",
                  adhb    = "01 Data/TFP/output/adhb")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, out_dir))

# SE cluster per provinsi, padanan vce(robust) Stata untuk panel
vc_cluster <- function(m) vcovHC(m, method = "arellano", type = "HC1")
# Driscoll-Kraay: tahan terhadap dependensi lintas provinsi, bukan hanya serial
vc_dk      <- function(m) vcovSCC(m, type = "HC1", maxlag = 2)

fmt_p <- function(p) ifelse(p < 0.001, "<0,001", formatC(p, digits = 3, format = "f"))

# ==============================================================================
# 1. Data
# ==============================================================================
df <- read.xlsx(data_file, sheet = "Sheet1")

tk_cols <- grep("_TenagaKerja$", names(df), value = TRUE)
up_cols <- grep("_RataUpah$", names(df), value = TRUE)
stopifnot(length(tk_cols) == 17, length(up_cols) == 17,
          identical(sub("_RataUpah$", "", up_cols), sub("_TenagaKerja$", "", tk_cols)))

# Peta pulau. Unit observasi tetap provinsi; pulau hanya lapisan agregasi
# penyajian, sama kedudukannya dengan nasional. Peta yang sama dipakai script 01
# dan 02 BKPM-local supaya konsisten lintas bab laporan.
# Peta pulau. Sheet `prov_name` di xlsx hilang setelah reorganisasi;
# salinannya yang andal adalah CSV di folder processed yang sama.
peta_pulau <- read.csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv") %>%
  select(Code_Prov, Pulau) %>%
  filter(!is.na(Code_Prov), !is.na(Pulau)) %>%
  distinct()

df <- df %>%
  left_join(peta_pulau, by = "Code_Prov") %>%
  arrange(Code_Prov, Year) %>%
  mutate(
    labours_total = rowSums(across(all_of(tk_cols))),
    # Pangsa pendapatan tenaga kerja dari data, bukan diasumsikan.
    # RataUpah = pendapatan bulanan per pekerja, mencakup upah, barang, kerja
    # paruh waktu, dan pemasukan wirausaha (definisi penyusun dataset), jadi ia
    # mencakup seluruh pekerja - bukan hanya buruh/karyawan.
    # Penyebutnya ADHB (harga berlaku): pendapatan nominal harus dibagi output
    # nominal. Satuan 9_ADHB adalah TRILIUN rupiah meski nama berkas menyebut
    # miliar - diverifikasi lewat jumlah 34 provinsi 2023 = 20.532 triliun
    # terhadap PDB Indonesia sekitar 20.900 triliun.
    komp_tk     = rowSums(across(all_of(up_cols)) * across(all_of(tk_cols))) * 12,
    pangsa_tk   = komp_tk / (`9_ADHB` * 1e12),
    # Variabel modal menurut sakelar BASIS_MODAL di kepala berkas. Satuannya
    # berbeda antar kolom (pmtb miliar, 4_ADHK juta, 4_ADHB triliun), tapi itu
    # hanya menggeser konstanta - elastisitas dan peringkat tidak tersentuh.
    K_modal      = switch(BASIS_MODAL,
                          riil    = `4_ADHK`,
                          nominal = pmtb * 1e6,
                          adhb    = `4_ADHB` * 1e12),
    # Nama `log_pmtb` sengaja dipertahankan supaya seluruh formula, nama baris
    # coeftest, nama kolom keluaran, dan skrip hilir tidak ikut berubah.
    log_pmtb     = log(K_modal),
    log_lab_tot  = log(labours_total),
    log_ADHK_Tot = log(`9_ADHK` * 1e6),
    log_ADHB_Tot = log(`9_ADHB` * 1e12),
    # Terikat aktif menurut basis. Kedua kolom di atas tetap dihitung: yang tidak
    # terpakai jadi kontras diagnostik di bagian 2 dan 3.
    log_Y_dep    = if (BASIS_ADHB) log_ADHB_Tot else log_ADHK_Tot,
    # Bentuk per-pekerja: dipakai untuk model CRS. Memaksakan b2 = 1 - b1 lewat
    # konstruksi variabel, bukan lewat restriksi numerik.
    log_y_per_l  = log_Y_dep - log_lab_tot,
    log_k_per_l  = log_pmtb - log_lab_tot,
    # Salinan numerik tahun. Year sendiri dipakai sebagai indeks panel dan
    # dibuang plm dari model frame, sehingga tidak bisa jadi regresor tren.
    thn = Year - min(Year)
  ) %>%
  group_by(Code_Prov) %>%
  mutate(
    # dplyr::lag eksplisit - plm memask lag() dan diam-diam mengembalikan 0
    log_pmtb_lag = dplyr::lag(log_pmtb),
    m_log_pmtb   = mean(log_pmtb, na.rm = TRUE),
    m_log_lab    = mean(log_lab_tot, na.rm = TRUE)
  ) %>%
  ungroup()

# Bobot pangsa output: rata-rata pangsa PDRB provinsi terhadap nasional, pada
# basis harga yang sama dengan variabel terikat.
# Time-invariant supaya bobot tidak ikut bergerak bersama variabel terikat.
kol_output <- if (BASIS_ADHB) "9_ADHB" else "9_ADHK"
df <- df %>%
  group_by(Year) %>%
  mutate(share_y = .data[[kol_output]] / sum(.data[[kol_output]], na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(Code_Prov) %>% mutate(w_share = mean(share_y, na.rm = TRUE)) %>%
  ungroup()

# Cek log yang gagal diam-diam: nilai <= 0 akan jadi NaN/-Inf dan memangkas sampel
neg_check <- df %>% summarise(across(c(K_modal, labours_total, `9_ADHK`, `9_ADHB`),
                                     ~ sum(.x <= 0, na.rm = TRUE)))
cat("\n=============== 1. Data ===============\n")
cat("Nilai <= 0 (harus semua nol):", paste(names(neg_check), unlist(neg_check),
                                           sep = "=", collapse = " | "), "\n")
if (any(unlist(neg_check) > 0)) stop("Ada nilai <= 0, log() akan menghasilkan NaN")

pdata <- pdata.frame(df, index = c("Code_Prov", "Year"))

cat("Observasi:", nrow(df), "| provinsi:", n_distinct(df$Code_Prov),
    "| tahun:", paste(range(df$Year), collapse = "-"), "\n")
cat("Observasi terpakai (non-NA pada K dan L):",
    sum(complete.cases(df[, c("log_Y_dep", "log_pmtb", "log_lab_tot")])), "\n")

# Cek join pulau: tidak boleh ada provinsi yang kehilangan pulau
stopifnot(!any(is.na(df$Pulau)))
cat("Pulau:", paste(sprintf("%s(%d)", names(table(peta_pulau$Pulau)),
                            table(peta_pulau$Pulau)), collapse = " "), "\n")

# -- Pangsa pendapatan tenaga kerja terukur -----------------------------------
# Dipakai untuk dua hal: menguji asumsi alfa=1/3 secara langsung dengan data
# Indonesia, dan menjadi bobot skenario growth accounting ala Rusiawan.
pangsa_nas <- df %>% filter(Year <= 2024) %>%
  group_by(Year) %>%
  summarise(komp_tri = sum(komp_tk) / 1e12, pdrb_tri = sum(`9_ADHB`),
            pangsa = komp_tri / pdrb_tri, .groups = "drop")
cat("\n-- Pangsa pendapatan tenaga kerja nasional (terukur dari data) --\n")
print(as.data.frame(pangsa_nas %>% mutate(across(where(is.numeric), ~round(.x, 3)))),
      row.names = FALSE)
q <- quantile(df$pangsa_tk[df$Year <= 2024], c(0, .25, .5, .75, 1), na.rm = TRUE)
cat(sprintf("Sebaran antar provinsi-tahun: min %.3f | Q1 %.3f | median %.3f | Q3 %.3f | maks %.3f\n",
            q[1], q[2], q[3], q[4], q[5]))
cat(sprintf("Pembanding: alfa=1/3 menyiratkan pangsa tenaga kerja %.3f\n", 2/3))

# Bobot Divisia: rata-rata dua tahun, mengikuti Rusiawan dkk. (2015)
df <- df %>% group_by(Code_Prov) %>%
  mutate(pangsa_divisia = (pangsa_tk + dplyr::lag(pangsa_tk)) / 2) %>% ungroup()
pangsa_divisia_nas <- weighted.mean(df$pangsa_divisia[df$Year <= 2024],
                                    df$`9_ADHB`[df$Year <= 2024], na.rm = TRUE)
cat(sprintf("Bobot Divisia nasional (tertimbang PDRB, 2018-2024): %.3f\n", pangsa_divisia_nas))

# ==============================================================================
# 2. Kandidat model
# ==============================================================================
f_adhk <- log_ADHK_Tot ~ log_pmtb + log_lab_tot
f_adhb <- log_ADHB_Tot ~ log_pmtb + log_lab_tot

mods <- list(
  ADHB_RE   = plm(f_adhb, pdata, model = "random"),
  ADHB_FE   = plm(f_adhb, pdata, model = "within"),
  ADHK_POOL = plm(f_adhk, pdata, model = "pooling"),
  ADHK_RE   = plm(f_adhk, pdata, model = "random"),
  ADHK_FE   = plm(f_adhk, pdata, model = "within"),
  # Two-way: dummy tahun ditulis eksplisit (bukan effect="twoways") supaya
  # koefisien tiap tahun bisa diambil beserta SE-nya di bagian 6.
  ADHK_FE2W = plm(update(f_adhk, . ~ . + factor(Year)), pdata, model = "within")
)

# Basis adhb butuh kandidat lengkap di sisi nominal. Ditambahkan hanya di cabang
# itu supaya daftar kandidat dua basis lama tetap persis seperti versi terbit.
if (BASIS_ADHB) {
  mods$ADHB_POOL <- plm(f_adhb, pdata, model = "pooling")
  mods$ADHB_FE2W <- plm(update(f_adhb, . ~ . + factor(Year)), pdata, model = "within")
}

# Formula dan model utama menurut basis. Nama objek tetap menyebut basis harga
# variabel terikatnya, jadi ADHK_FE2W selalu berarti terikat ADHK.
f_utama    <- if (BASIS_ADHB) f_adhb else f_adhk
nm_pool    <- if (BASIS_ADHB) "ADHB_POOL" else "ADHK_POOL"
nm_re      <- if (BASIS_ADHB) "ADHB_RE"   else "ADHK_RE"
nm_fe      <- if (BASIS_ADHB) "ADHB_FE"   else "ADHK_FE"
nm_fe2w    <- if (BASIS_ADHB) "ADHB_FE2W" else "ADHK_FE2W"

cat("\n=============== 2. Kandidat model ===============\n")
for (nm in names(mods)) {
  b <- coef(mods[[nm]])
  b <- b[names(b) %in% c("log_pmtb", "log_lab_tot")]
  cat(sprintf("%-10s b1=%.4f b2=%.4f b1+b2=%.4f N=%d\n", nm,
              b["log_pmtb"], b["log_lab_tot"], sum(b), nobs(mods[[nm]])))
}

# ==============================================================================
# 3. Diagnostik untuk kaskade
# ==============================================================================
diag_of <- function(m, f) {
  pooled <- plm(f, pdata, model = "pooling")
  fe     <- plm(f, pdata, model = "within")
  mundlak_f <- update(f, . ~ . + m_log_pmtb + m_log_lab)
  mund <- plm(mundlak_f, pdata, model = "random")
  mund_test <- linearHypothesis(mund, c("m_log_pmtb = 0", "m_log_lab = 0"),
                                vcov. = vc_cluster(mund))
  # Modified Wald groupwise heteroskedasticity (padanan xttest3, formula Greene)
  e  <- as.numeric(residuals(fe)); g <- as.character(index(fe)[[1]])
  d  <- tibble(g, e) %>% group_by(g) %>%
    summarise(T_i = n(), s2 = sum(e^2) / n(), .groups = "drop")
  s2p <- sum(e^2) / length(e)
  W   <- sum((d$s2 - s2p)^2 / (2 * s2p^2 / d$T_i))
  list(
    bp       = plmtest(pooled, type = "bp")$p.value,
    mundlak  = mund_test$`Pr(>Chisq)`[2],
    wald_het = pchisq(W, df = nrow(d), lower.tail = FALSE),
    ar1      = pwartest(f, data = pdata)$p.value,
    cd_fe    = pcdtest(fe, test = "cd")$p.value
  )
}

dg_adhk <- diag_of(f_adhk, f_adhk)
dg_adhb <- diag_of(f_adhb, f_adhb)
# Diagnostik yang menggerakkan kaskade adalah milik basis aktif.
dg_utama <- if (BASIS_ADHB) dg_adhb else dg_adhk
cd_2w   <- pcdtest(mods[[nm_fe2w]], test = "cd")$p.value

cat("\n=============== 3. Diagnostik ===============\n")
cat(sprintf("ADHK  BP-LM p=%s | Mundlak p=%s | Wald-het p=%s | AR(1) p=%s | CD(FE) p=%s\n",
            fmt_p(dg_adhk$bp), fmt_p(dg_adhk$mundlak), fmt_p(dg_adhk$wald_het),
            fmt_p(dg_adhk$ar1), fmt_p(dg_adhk$cd_fe)))
cat(sprintf("ADHB  BP-LM p=%s | Mundlak p=%s | Wald-het p=%s | AR(1) p=%s | CD(FE) p=%s\n",
            fmt_p(dg_adhb$bp), fmt_p(dg_adhb$mundlak), fmt_p(dg_adhb$wald_het),
            fmt_p(dg_adhb$ar1), fmt_p(dg_adhb$cd_fe)))
cat(sprintf("CD setelah efek tahun (%s) p=%s\n",
            if (BASIS_ADHB) "ADHB two-way FE" else "ADHK two-way FE", fmt_p(cd_2w)))

# Statistik z Pesaran CD per model (dikutip di laporan Sub-bagian 3.1). Nominal
# RE paling parah, riil RE mendekati nol -> dasar memilih basis riil + efek tahun.
cat("CD z-stat: ")
for (nm in c("ADHB_RE", "ADHK_RE", "ADHB_FE", "ADHK_FE")) {
  cat(sprintf("%s=%.2f  ", nm, pcdtest(mods[[nm]], test = "cd")$statistic))
}
cat(sprintf("| %s=%.2f\n", nm_fe2w, pcdtest(mods[[nm_fe2w]], test = "cd")$statistic))

# ==============================================================================
# 4. Kaskade seleksi model (S0-S6)
#
# Aturan ditetapkan lebih dulu; verdict hanyalah pembacaan atas kolom diagnostik.
#
# S0 Variabel terikat harus output riil. TFP adalah konsep riil; residual dari
#    regresi output nominal memuat perubahan harga. Restriksi a priori.
#    Basis "adhb" melanggar S0 dengan sengaja, dan verdict-nya menyatakan itu
#    terang-terangan. Basis itu berstatus diagnostik: residualnya bukan TFP.
# S1 Breusch-Pagan LM menolak -> ada efek individu, pooled OLS tidak memadai.
# S2 Bila Modified Wald ATAU Wooldridge AR(1) menolak, uji Hausman klasik tidak
#    sah: ia mensyaratkan RE efisien, yang menuntut homoskedastisitas dan tanpa
#    autokorelasi (StataCorp 2025). Pakai uji Mundlak yang tetap valid di bawah
#    cluster-robust (Mundlak 1978).
# S3 Bila Pesaran CD menolak -> tambahkan efek tahun, uji ulang.
# S4 Uji Wald b1+b2=1. Bila tidak tertolak, CRS dipaksakan untuk dekomposisi.
# S5 RESET; bila tidak tertolak, Cobb-Douglas dipertahankan.
# S6 SE cluster provinsi; pindah ke Driscoll-Kraay bila CD masih menolak.
# ==============================================================================
cat("\n=============== 4. Kaskade seleksi ===============\n")
verdict <- c(
  S0 = if (BASIS_ADHB) {
    "DIKESAMPINGKAN: terikat ADHB (output nominal) - residual memuat inflasi harga, jadi bukan TFP"
  } else {
    "ADHK (output riil) - ADHB hanya kontras diagnostik"
  },
  S1 = sprintf("BP-LM p=%s -> ada efek individu", fmt_p(dg_utama$bp)),
  S2 = sprintf("Wald-het p=%s & AR1 p=%s -> Hausman tidak sah; Mundlak p=%s -> FE",
               fmt_p(dg_utama$wald_het), fmt_p(dg_utama$ar1), fmt_p(dg_utama$mundlak)),
  S3 = sprintf("CD satu-arah p=%s -> tambah efek tahun; CD two-way p=%s",
               fmt_p(dg_utama$cd_fe), fmt_p(cd_2w)),
  S4 = "lihat uji RTS di bawah",
  S5 = "lihat uji RESET di bawah",
  S6 = "lihat perbandingan SE di bawah"
)
for (s in names(verdict)) cat(sprintf("%s: %s\n", s, verdict[s]))

# -- S4: uji returns to scale -------------------------------------------------
rts_test <- function(m, label) {
  h <- linearHypothesis(m, "log_pmtb + log_lab_tot = 1", vcov. = vc_cluster(m))
  b <- coef(m); s <- sum(b[c("log_pmtb", "log_lab_tot")])
  cat(sprintf("  %-10s b1+b2=%.4f  chisq=%.3f  p=%s\n", label, s,
              h$Chisq[2], fmt_p(h$`Pr(>Chisq)`[2])))
  c(rts = s, p = h$`Pr(>Chisq)`[2])
}
cat("\n-- S4. Uji Wald H0: b1+b2 = 1 (CRS) --\n")
rts_adhk_fe   <- rts_test(mods[[nm_fe]],   nm_fe)
rts_adhk_re   <- rts_test(mods[[nm_re]],   nm_re)
rts_adhk_fe2w <- rts_test(mods[[nm_fe2w]], nm_fe2w)
# Baris kontras: basis harga lawan, transformasi FE yang sama.
rts_adhb_fe   <- rts_test(if (BASIS_ADHB) mods$ADHK_FE else mods$ADHB_FE,
                          if (BASIS_ADHB) "ADHK_FE" else "ADHB_FE")

# -- S4b: tangga atenuasi ------------------------------------------------------
# CRS ditolak di semua spesifikasi, tetapi b1+b2 menurun rapi seiring makin
# banyak variasi yang dibuang oleh transformasi: pooling -> RE -> FE -> two-way.
# Pola monoton ini adalah tanda tangan measurement error, bukan bukti DRS:
# Griliches & Hausman (1986) menunjukkan error pengukuran pada regresor
# "gets magnified in the within dimension", dan modal di sini diproksi PMTB
# (arus), yang menurut Chen & Plotnikova (2018) membiaskan elastisitas modal
# ke bawah. Estimasi pooled - yang membuang paling sedikit variasi - justru
# yang paling dekat ke CRS.
# Arah tangganya TIDAK diklaim di sini. Pada modal nominal ia menurun monoton;
# pada modal riil ia naik dulu (pooled 1,01 -> within 1,19) baru jatuh di two-way.
cat("\n-- S4b. Tangga atenuasi: b1+b2 menurut transformasi yang dipakai --\n")
tangga <- tibble(
  spesifikasi = c("Pooled OLS", "Random effects", "Fixed effects", "Two-way FE"),
  variasi_dibuang = c("tidak ada", "sebagian antar-provinsi",
                      "seluruh antar-provinsi", "antar-provinsi + antar-tahun"),
  b1 = c(coef(mods[[nm_pool]])["log_pmtb"], coef(mods[[nm_re]])["log_pmtb"],
         coef(mods[[nm_fe]])["log_pmtb"], coef(mods[[nm_fe2w]])["log_pmtb"]),
  b2 = c(coef(mods[[nm_pool]])["log_lab_tot"], coef(mods[[nm_re]])["log_lab_tot"],
         coef(mods[[nm_fe]])["log_lab_tot"], coef(mods[[nm_fe2w]])["log_lab_tot"])
) %>% mutate(rts = b1 + b2)
print(as.data.frame(tangga %>% mutate(across(where(is.numeric), ~round(.x, 4)))),
      row.names = FALSE)

# -- S5: RESET ----------------------------------------------------------------
reset_p <- function(f, model_type) {
  m  <- plm(f, pdata, model = model_type)
  mm <- model.matrix(m, model = "pooling")
  b  <- coef(m); cols <- intersect(colnames(mm), names(b))
  xb <- as.numeric(mm[, cols, drop = FALSE] %*% b[cols])
  xb <- xb - mean(xb, na.rm = TRUE)
  # xb hanya sepanjang sampel estimasi (272), sedangkan data penuh 306 baris.
  # Digabungkan lewat indeks, bukan diasumsikan sejajar - kalau dipaksakan,
  # R akan menolak atau (lebih buruk) mendaur ulang nilai secara diam-diam.
  idx <- index(m)
  aug <- tibble(Code_Prov = as.numeric(as.character(idx[[1]])),
                Year      = as.numeric(as.character(idx[[2]])),
                xbh2 = xb^2, xbh3 = xb^3)
  d2 <- as.data.frame(pdata) %>%
    mutate(Code_Prov = as.numeric(as.character(Code_Prov)),
           Year = as.numeric(as.character(Year))) %>%
    left_join(aug, by = c("Code_Prov", "Year"))
  m2 <- plm(update(f, . ~ . + xbh2 + xbh3),
            pdata.frame(d2, index = c("Code_Prov", "Year")), model = model_type)
  linearHypothesis(m2, c("xbh2 = 0", "xbh3 = 0"),
                   vcov. = vc_cluster(m2))$`Pr(>Chisq)`[2]
}
cat("\n-- S5. RESET (H0: tidak ada nonlinearitas terabaikan) --\n")
cat(sprintf("  %s p=%s | %s p=%s\n",
            nm_fe, fmt_p(reset_p(f_utama, "within")),
            nm_re, fmt_p(reset_p(f_utama, "random"))))

# -- S6: cluster vs Driscoll-Kraay --------------------------------------------
cat(sprintf("\n-- S6. SE cluster provinsi vs Driscoll-Kraay (%s two-way FE) --\n",
            if (BASIS_ADHB) "ADHB" else "ADHK"))
ct_cl <- coeftest(mods[[nm_fe2w]], vcov = vc_cluster(mods[[nm_fe2w]]))
ct_dk <- coeftest(mods[[nm_fe2w]], vcov = vc_dk(mods[[nm_fe2w]]))
for (v in c("log_pmtb", "log_lab_tot")) {
  cat(sprintf("  %-12s b=%.4f  SE cluster=%.4f (p=%s)  SE DK=%.4f (p=%s)\n", v,
              ct_cl[v, 1], ct_cl[v, 2], fmt_p(ct_cl[v, 4]),
              ct_dk[v, 2], fmt_p(ct_dk[v, 4])))
}

# ==============================================================================
# 5. Model terpilih (UTAMA: tak-terestriksi) + versi CRS (SEKUNDER/diagnostik)
# ==============================================================================
cat("\n=============== 5. Model terpilih ===============\n")
sel <- mods[[nm_fe2w]]
cat(sprintf("Terpilih: %s, two-way fixed effects (provinsi + tahun), SE Driscoll-Kraay\n\n",
            if (BASIS_ADHB) "ADHB" else "ADHK"))
print(ct_dk[c("log_pmtb", "log_lab_tot"), ])

# Elastisitas UTAMA: dari model tak-terestriksi ADHK_FE2W apa adanya (b1+b2=0,59,
# DRS). Semua hitungan hilir - indeks tahun, TFP provinsi, per pulau, kedua xlsx -
# memakai pasangan ini. Suku skala (1-b1-b2) memang ikut masuk residual dan itu
# diterima secara terbuka.
b1_un    <- coef(sel)["log_pmtb"]
b2_un    <- coef(sel)["log_lab_tot"]
se_b1_un <- ct_dk["log_pmtb", 2]
se_b2_un <- ct_dk["log_lab_tot", 2]
cat(sprintf("\nElastisitas UTAMA (tak-terestriksi): b1=%.4f (SE DK %.4f) b2=%.4f (SE DK %.4f) b1+b2=%.4f\n",
            b1_un, se_b1_un, b2_un, se_b2_un, b1_un + b2_un))

# Versi CRS (SEKUNDER): bentuk per-pekerja. Dipertahankan untuk perbandingan model
# dan simulasi DRS-vs-CRS, BUKAN lagi sebagai basis dekomposisi utama. Elastisitas
# tenaga kerja = 1 - b1 secara konstruksi.
f_crs <- log_y_per_l ~ log_k_per_l
crs_fe2w <- plm(update(f_crs, . ~ . + factor(Year)), pdata, model = "within")
b1_crs <- coef(crs_fe2w)["log_k_per_l"]
se_crs <- sqrt(diag(vc_dk(crs_fe2w)))["log_k_per_l"]
cat(sprintf("Model CRS (per-pekerja, sekunder): b1=%.4f (SE DK %.4f), b2 = 1-b1 = %.4f\n",
            b1_crs, se_crs, 1 - b1_crs))

# ==============================================================================
# 6. Efek tahun = pergerakan produktivitas bersama seluruh provinsi
#
# Ini pengganti CAGR TFP. Deret TFP dari rata-rata residual tidak layak: sd
# residual dalam-provinsi (0,035) lebih besar daripada seluruh rentang pergerakan
# deret nasional delapan tahun, dan residualnya terautokorelasi kuat.
# Efek tahun mengestimasi komponen waktu bersama dengan SE yang benar.
#
# Dua peringatan yang harus ikut ditulis di report:
#   - level efek tahun arbitrer (relatif tahun basis); hanya perubahannya bermakna
#   - efek tahun menyerap SEMUA guncangan agregat: siklus, harga, term-of-trade
# ==============================================================================
cat("\n=============== 6. Efek tahun (produktivitas agregat) ===============\n")

# Diambil dari model UTAMA tak-terestriksi. Konsekuensinya jelas dan diterima
# terbuka: karena b1+b2 = 0,59, efek tahun ikut menyerap suku skala
# (1 - b1 - b2) x pertumbuhan input bersama, sehingga indeks ini bergerak naik
# (+0,81%/thn) sedangkan versi CRS bergerak turun (-0,26%/thn). Selisih itu
# adalah suku skala. Versi CRS tetap dihitung sebagai deret sekunder untuk
# diagnostik dan simulasi DRS-vs-CRS.
ambil_efek_tahun <- function(m, tahun_basis) {
  ct <- coeftest(m, vcov = vc_dk(m))
  rw <- grep("^factor\\(Year\\)", rownames(ct), value = TRUE)
  tibble(Year = as.numeric(sub("factor\\(Year\\)", "", rw)),
         koef = ct[rw, 1], se = ct[rw, 2]) %>%
    add_row(Year = tahun_basis, koef = 0, se = 0, .before = 1) %>%
    mutate(lo = koef - 1.96 * se, hi = koef + 1.96 * se,
           indeks_100 = 100 * exp(koef))
}
yr_tab     <- ambil_efek_tahun(sel, min(df$Year))       # UTAMA: tak-terestriksi
yr_tab_crs <- ambil_efek_tahun(crs_fe2w, min(df$Year))  # SEKUNDER: CRS

cat("-- Efek tahun, model UTAMA tak-terestriksi (dipakai sebagai indeks produktivitas) --\n")
print(as.data.frame(yr_tab %>% mutate(across(where(is.numeric), ~round(.x, 4)))),
      row.names = FALSE)

tren_dari <- function(tb) {
  m <- lm(koef ~ Year, data = tb); s <- summary(m)$coefficients
  c(slope = s["Year", 1], se = s["Year", 2], p = s["Year", 4])
}
t_unc <- tren_dari(yr_tab)      # UTAMA: tak-terestriksi
t_crs <- tren_dari(yr_tab_crs)  # SEKUNDER: CRS

# Tren yang dilaporkan diambil dari spesifikasi bertren linear, BUKAN dari lm()
# atas delapan koefisien efek tahun. Alasannya: kedelapan koefisien itu estimasi
# dengan SE yang sangat heteroskedastik (0,003-0,017) dan saling berkorelasi kuat
# karena semuanya relatif terhadap tahun basis yang sama. lm() tak berbobot
# mengabaikan keduanya dan menghasilkan SE yang terlalu kecil.
# UTAMA: spesifikasi bertren pada model tak-terestriksi. SEKUNDER: versi CRS.
unc_tren <- plm(log_Y_dep ~ log_pmtb + log_lab_tot + thn, pdata, model = "within")
ct_tren  <- coeftest(unc_tren, vcov = vc_dk(unc_tren))
crs_tren <- plm(log_y_per_l ~ log_k_per_l + thn, pdata, model = "within")
ct_tren_crs <- coeftest(crs_tren, vcov = vc_dk(crs_tren))
cat(sprintf("\nTren TFP UTAMA (tak-terestriksi, spesifikasi bertren, SE Driscoll-Kraay):\n"))
cat(sprintf("  %+.4f poin log/thn = %+.2f%%/thn (SE %.4f, p=%s)\n",
            ct_tren["thn", 1], 100 * ct_tren["thn", 1],
            ct_tren["thn", 2], fmt_p(ct_tren["thn", 4])))
cat(sprintf("  Pembanding, lm() atas koefisien efek tahun: %+.2f%%/thn (p=%s)\n",
            100 * t_unc["slope"], fmt_p(t_unc["p"])))
cat(sprintf("\nTren TFP SEKUNDER (CRS, spesifikasi bertren): %+.4f poin log/thn = %+.2f%%/thn (SE %.4f, p=%s)\n",
            ct_tren_crs["thn", 1], 100 * ct_tren_crs["thn", 1],
            ct_tren_crs["thn", 2], fmt_p(ct_tren_crs["thn", 4])))
cat(sprintf("Tren efek tahun (CRS, lm): %+.4f poin log/thn = %+.2f%%/thn\n",
            t_crs["slope"], 100 * t_crs["slope"]))
cat("Selisih keduanya adalah suku skala yang ikut terserap bila CRS tidak dipaksakan.\n")

# -- Efek tahun per pulau ------------------------------------------------------
# Model CRS yang sama diestimasi terpisah untuk tiap pulau. Presisinya turun
# tajam karena tiap pulau hanya 3-10 provinsi; selang kepercayaan dilaporkan apa
# adanya. Kalau sebagian besar tidak berbeda dari nol, itu temuan yang harus
# dinyatakan, bukan disembunyikan.
cat("\n-- Efek tahun per pulau (model UTAMA tak-terestriksi terpisah) --\n")
yr_pulau <- map_dfr(sort(unique(df$Pulau)), function(pl) {
  sub <- df %>% filter(Pulau == pl)
  pp  <- pdata.frame(sub, index = c("Code_Prov", "Year"))
  m   <- tryCatch(plm(log_Y_dep ~ log_pmtb + log_lab_tot + factor(Year), pp, model = "within"),
                  error = function(e) NULL)
  if (is.null(m)) return(tibble())
  # SE Driscoll-Kraay butuh N cukup; untuk pulau kecil pakai cluster sebagai cadangan
  v <- tryCatch(vc_dk(m), error = function(e) vc_cluster(m))
  ct <- coeftest(m, vcov = v)
  rw <- grep("^factor\\(Year\\)", rownames(ct), value = TRUE)
  tibble(Pulau = pl, n_prov = n_distinct(sub$Code_Prov),
         Year = as.numeric(sub("factor\\(Year\\)", "", rw)),
         koef = ct[rw, 1], se = ct[rw, 2]) %>%
    add_row(Pulau = pl, n_prov = n_distinct(sub$Code_Prov),
            Year = min(df$Year), koef = 0, se = 0, .before = 1)
}) %>%
  mutate(lo = koef - 1.96 * se, hi = koef + 1.96 * se,
         indeks_100 = 100 * exp(koef), signifikan = (lo > 0 | hi < 0))

n_sig <- yr_pulau %>% filter(Year > min(Year)) %>% summarise(s = sum(signifikan), n = n())
cat(sprintf("Efek tahun per pulau yang berbeda dari nol: %d dari %d\n", n_sig$s, n_sig$n))
print(as.data.frame(yr_pulau %>% filter(Year %in% c(2021, 2024)) %>%
                      select(Pulau, n_prov, Year, koef, se, indeks_100, signifikan) %>%
                      mutate(across(where(is.numeric), ~round(.x, 4)))), row.names = FALSE)

# ==============================================================================
# 7. Robustness: bobot pangsa output, PMTB lag-1
# ==============================================================================
cat("\n=============== 7. Robustness ===============\n")

# (a) Panel berbobot pangsa output. Panel biasa membobot tiap provinsi sama,
# sedangkan agregat nasional membobot pangsa output. Kalau elastisitas berbobot
# jauh berbeda, dekomposisi nasional tidak boleh memakai elastisitas panel biasa.
w_fe2w <- plm(update(f_utama, . ~ . + factor(Year)), pdata,
              model = "within", weights = df$w_share)
cat(sprintf("(a) Berbobot pangsa output: b1=%.4f b2=%.4f (vs tanpa bobot %.4f / %.4f)\n",
            coef(w_fe2w)["log_pmtb"], coef(w_fe2w)["log_lab_tot"],
            coef(sel)["log_pmtb"], coef(sel)["log_lab_tot"]))

# (b) PMTB lag-1: menghapus simultanitas kontemporer, sekaligus menguji bacaan
# time-to-build (investasi tahun t menaikkan output beberapa tahun berikutnya).
lag_fe2w <- plm(log_Y_dep ~ log_pmtb_lag + log_lab_tot + factor(Year),
                pdata, model = "within")
ct_lag <- coeftest(lag_fe2w, vcov = vc_dk(lag_fe2w))
cat(sprintf("(b) PMTB lag-1: b1=%.4f (SE %.4f, p=%s) b2=%.4f  N=%d\n",
            ct_lag["log_pmtb_lag", 1], ct_lag["log_pmtb_lag", 2],
            fmt_p(ct_lag["log_pmtb_lag", 4]), ct_lag["log_lab_tot", 1],
            nobs(lag_fe2w)))

# (c) Elastisitas bentuk growth, sebagai batas bawah rentang. Measurement error
# pada modal diperbesar dalam first-difference (Griliches & Hausman 1986),
# sehingga angka ini bias ke bawah - tapi justru karena itu berguna sebagai batas.
df_g <- df %>% group_by(Code_Prov) %>%
  mutate(g_y = 100 * (log_Y_dep - dplyr::lag(log_Y_dep)),
         g_k = 100 * (log_pmtb - dplyr::lag(log_pmtb)),
         g_l = 100 * (log_lab_tot - dplyr::lag(log_lab_tot))) %>% ungroup()
g_fe <- plm(g_y ~ g_k + g_l, pdata.frame(df_g, index = c("Code_Prov", "Year")),
            model = "within")
cat(sprintf("(c) Bentuk growth: b1=%.4f b2=%.4f  N=%d\n",
            coef(g_fe)["g_k"], coef(g_fe)["g_l"], nobs(g_fe)))

# ==============================================================================
# 8. TFP per provinsi + tren per provinsi (pengganti CAGR)
# ==============================================================================
cat("\n=============== 8. TFP provinsi ===============\n")

# TFP UTAMA dari model tak-terestriksi: residual tiga suku penuh
#   logtfp_it = log Y - b1*log K - b2*log L = a + u_i + e_it (memuat suku skala)
# Kolom pembanding _crs dari bentuk per-pekerja dipertahankan untuk perbandingan.
df <- df %>%
  mutate(logtfp_it     = log_Y_dep - b1_un * log_pmtb - b2_un * log_lab_tot,
         logtfp_it_crs = log_y_per_l - b1_crs * log_k_per_l)

prov_tfp <- df %>%
  filter(!is.na(logtfp_it)) %>%
  group_by(Code_Prov, Pre_Prov) %>%
  summarise(logtfp_rata     = mean(logtfp_it),
            logtfp_rata_crs = mean(logtfp_it_crs), .groups = "drop") %>%
  mutate(dev_nasional     = logtfp_rata - mean(logtfp_rata),
         dev_nasional_crs = logtfp_rata_crs - mean(logtfp_rata_crs)) %>%
  arrange(desc(logtfp_rata))

# Tren per provinsi dari regresi 8 titik + SE. Menggantikan selisih dua ujung:
# CAGR residual ditentukan oleh pilihan tahun awal-akhir dan mengabaikan
# autokorelasi. Di sini tren yang tidak signifikan bisa dikenali apa adanya.
# Kolom utama = tak-terestriksi; kolom _crs = pembanding CRS per-pekerja.
prov_tren <- df %>%
  filter(!is.na(logtfp_it)) %>%
  group_by(Code_Prov, Pre_Prov) %>%
  group_modify(~ {
    m  <- lm(logtfp_it ~ Year, data = .x)
    s  <- summary(m)$coefficients
    mc <- lm(logtfp_it_crs ~ Year, data = .x)
    sc <- summary(mc)$coefficients
    tibble(tren_pp_thn = 100 * s["Year", 1], se = 100 * s["Year", 2],
           p = s["Year", 4], tren_pp_thn_crs = 100 * sc["Year", 1])
  }) %>% ungroup() %>%
  mutate(signifikan = p < 0.05) %>%
  arrange(desc(tren_pp_thn))

cat(sprintf("Provinsi dengan tren TFP signifikan (p<0,05): %d dari %d\n",
            sum(prov_tren$signifikan), nrow(prov_tren)))
cat("Catatan: SE tren per provinsi dari OLS 8 titik atas residual yang\n")
cat("terautokorelasi positif, sehingga SE terlalu kecil dan angka di atas\n")
cat("adalah BATAS ATAS jumlah provinsi yang trennya benar-benar signifikan.\n")

# Komponen varian dari model terpilih - dipakai untuk argumen "peringkat kuat,
# deret waktu lemah". Diregenerasi dari model sekarang, bukan disalin dari
# perhitungan lama yang spesifikasinya sudah berbeda.
e_sel   <- as.numeric(residuals(sel))
fe_sel  <- as.numeric(fixef(sel))
sd_e    <- sd(e_sel); sd_u <- sd(fe_sel)
rho_sel <- sd_u^2 / (sd_u^2 + sd_e^2)
rentang_yr <- diff(range(yr_tab$koef))
cat(sprintf("\nKomponen varian model terpilih: sd(u_i)=%.4f  sd(e_it)=%.4f  rho=%.4f\n",
            sd_u, sd_e, rho_sel))
cat(sprintf("Rentang pergerakan efek tahun 2017-2024 = %.4f poin log\n", rentang_yr))
cat(sprintf("sd residual dalam-provinsi %s rentang deret nasional (%.4f vs %.4f)\n",
            ifelse(sd_e > rentang_yr, "LEBIH BESAR dari", "lebih kecil dari"),
            sd_e, rentang_yr))
cat("\n-- TFP provinsi (log, model UTAMA tak-terestriksi two-way FE), deviasi dari rata-rata --\n")
print(as.data.frame(prov_tfp %>% mutate(across(where(is.numeric), ~round(.x, 3)))),
      row.names = FALSE)
cat("\n-- Tren TFP per provinsi (poin log per tahun x100, dari regresi 8 titik) --\n")
print(as.data.frame(prov_tren %>% mutate(across(where(is.numeric), ~round(.x, 3)))),
      row.names = FALSE)

# ==============================================================================
# 9. Ekspor
# ==============================================================================
tab_kandidat <- map_dfr(names(mods), function(nm) {
  m <- mods[[nm]]; b <- coef(m); ct <- coeftest(m, vcov = vc_cluster(m))
  tibble(spesifikasi = nm,
         b1 = b["log_pmtb"], se_b1 = ct["log_pmtb", 2],
         b2 = b["log_lab_tot"], se_b2 = ct["log_lab_tot", 2],
         rts = b["log_pmtb"] + b["log_lab_tot"], N = nobs(m))
})

# Sheet efek_tahun UTAMA = tak-terestriksi; efek_tahun_crs = pembanding CRS.
# tfp_provinsi & tren_provinsi memuat kolom utama + kolom _crs pembanding.
write.xlsx(list(kandidat_model = tab_kandidat,
                tangga_atenuasi = tangga,
                efek_tahun     = yr_tab,
                efek_tahun_crs = yr_tab_crs,
                pangsa_tk      = pangsa_nas,
                efek_tahun_pulau = yr_pulau,
                tfp_provinsi   = prov_tfp,
                tren_provinsi  = prov_tren,
                # Nama kolom terikat mengikuti basis harganya, supaya sheet basis
                # riil dan nominal tetap berkepala `log_ADHK_Tot` seperti versi
                # terbit, dan sheet basis adhb tidak berbohong tentang isinya.
                data_tfp       = df %>%
                  select(Code_Prov, Pre_Prov, Pulau, Year, pangsa_tk,
                         log_Y_dep, log_pmtb, log_lab_tot,
                         logtfp_it, logtfp_it_crs) %>%
                  rename(!!(if (BASIS_ADHB) "log_ADHB_Tot" else "log_ADHK_Tot") := log_Y_dep)),
           file.path(out_dir, "Hasil Estimasi TFP.xlsx"))

# parameter_terpilih.rds: UTAMA (tak-terestriksi) sebagai basis hilir, plus
# SEKUNDER (CRS) untuk perbandingan dan simulasi. b1_level/b2_level = b1_un/b2_un.
saveRDS(list(
             # -- UTAMA: tak-terestriksi (DRS, b1+b2=0,59) --
             b1_un = b1_un, b2_un = b2_un, se_b1_un = se_b1_un, se_b2_un = se_b2_un,
             b1_level = b1_un, b2_level = b2_un,
             yr_tab = yr_tab, tren_dk_un = ct_tren["thn", ], tren_unc = t_unc["slope"],
             # -- SEKUNDER: CRS per-pekerja --
             b1_crs = b1_crs, se_crs = se_crs,
             yr_tab_crs = yr_tab_crs, tren_dk_crs = ct_tren_crs["thn", ],
             tren_crs_lm = t_crs["slope"],
             # -- parameter pendukung dekomposisi & robustness --
             pangsa_divisia = pangsa_divisia_nas, pangsa_nas = pangsa_nas,
             b1_growth = coef(g_fe)["g_k"], b2_growth = coef(g_fe)["g_l"],
             rts_fe2w = rts_adhk_fe2w,
             rho = rho_sel, sd_e = sd_e, sd_u = sd_u,
             b1_bobot = coef(w_fe2w)["log_pmtb"], b2_bobot = coef(w_fe2w)["log_lab_tot"]),
        file.path(out_dir, "parameter_terpilih.rds"))

cat("\n=============== SELESAI ===============\n")
cat("Keluaran:", normalizePath(out_dir), "\n")
