# ==============================================================================
# Analisis TFP Provinsi BKPM
# Terjemahan dari Stata: "Analisis Data Provinsi BKPM (2).do"
# Model dasar (Solow): log(Y) = a + b1*log(pmtb) + b2*log(labour) + u_i + e_it
#
# Data lama (.do)  : D:\Kurang Duit\Kemen Inves-BKPM\Dataset BKPM Provinsi 3.xlsx
# Data baru (ini)  : Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx (Sheet1)
#
# Catatan penting (lihat juga komentar inline di lokasi masing-masing):
# - PMA_Tot/PMDN_Tot memakai kolom agregat siap pakai PMA_1/PMDN_1 (0 missing),
#   BUKAN penjumlahan manual 17 kolom sektoral A_PMA..RSTU_PMA/A_PMDN..RSTU_PMDN
#   yang sangat sparse (sampai 303/306 baris blank di O_PMA) - dikonfirmasi user.
# - Multiplier skala (1e9 utk ADHB/govspend, 1e6 utk ADHK/pmtb/PMA/PMDN, 1e3 utk
#   Exp/Inc) dipertahankan persis seperti .do asli meski dataset baru menyebut
#   semua "Milliar Rp" di sheet Keterangan - ini hanya menggeser level TFP
#   secara konstan, tidak mengubah koefisien elastisitas (dikonfirmasi user).
# - Section MLE (RE) dan modified Wald groupwise heteroskedasticity (xttest3) tidak
#   punya padanan 1:1 di R - ditandai eksplisit sebagai APROKSIMASI di komentar masing-masing.
# - Section IV/GMM (.do baris 406-500) sengaja TIDAK diterjemahkan - di luar scope,
#   analisis dibatasi pada FE/RE saja (dikonfirmasi user).
# ==============================================================================

library(tidyverse)
library(openxlsx)
library(plm)
library(lmtest)
library(sandwich)
library(clubSandwich)
library(AER)
library(car)
library(boot)
library(nlme)

output_dir <- "TFP calc/Output"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

robust_vcov <- function(model) vcovHC(model, method = "arellano", type = "HC1")

# ==============================================================================
# 1. Import & persiapan data (.do baris 1-28)
# ==============================================================================
df <- read.xlsx(
  "TFP calc/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx",
  sheet = "Sheet1"
)

# Grwth1_Prov/Grwth2_Prov masuk sebagai character - cell Excel-nya tersimpan sbg teks
# float noise (mis. "8.2799999999999994"), bukan cell numerik asli. Coercion aman selama
# tidak menambah NA baru (dicek eksplisit di bawah, bukan diasumsikan).
n_na_before <- sum(is.na(df$Grwth1_Prov)) + sum(is.na(df$Grwth2_Prov))
df <- df %>%
  mutate(
    Grwth1_Prov = as.numeric(Grwth1_Prov),
    Grwth2_Prov = as.numeric(Grwth2_Prov)
  )
n_na_after <- sum(is.na(df$Grwth1_Prov)) + sum(is.na(df$Grwth2_Prov))
cat("Cek coercion Grwth1/Grwth2_Prov -> numeric: NA sebelum =", n_na_before, "| NA sesudah =", n_na_after, "\n")
if (n_na_after > n_na_before) stop("Coercion Grwth1/Grwth2_Prov menghasilkan NA baru - cek nilai non-numerik di source data")

df <- df %>%
  arrange(Code_Prov, Year) %>%
  mutate(
    labours_primer   = A_TenagaKerja + B_TenagaKerja,
    labours_sekunder = C_TenagaKerja + D_TenagaKerja + E_TenagaKerja + F_TenagaKerja,
    labours_tersier  = G_TenagaKerja + H_TenagaKerja + I_TenagaKerja + J_TenagaKerja +
                        K_TenagaKerja + L_TenagaKerja + MN_TenagaKerja + O_TenagaKerja +
                        P_TenagaKerja + Q_TenagaKerja + RSTU_TenagaKerja,
    labours_total    = labours_primer + labours_sekunder + labours_tersier,
    log_lab_tot      = log(labours_total),

    log_pmtb     = log(pmtb * 1e6),
    log_ADHB_Tot = log(`9_ADHB` * 1e9),
    log_ADHK_Tot = log(`9_ADHK` * 1e6),

    # PMA_Tot/PMDN_Tot: pakai kolom agregat siap pakai (bukan jumlah manual sektor)
    PMA_Tot      = PMA_1,
    PMDN_Tot     = PMDN_1,
    log_PMA_Tot  = log(PMA_Tot * 1e6),
    log_PMDN_Tot = log(PMDN_Tot * 1e6),

    log_GovSpend = log(govspend * 1e9),
    log_Exp_Prov = log(Exp_Prov * 1e3),
    log_Inc_Prov = log(Inc_Prov * 1e3)
  ) %>%
  group_by(Code_Prov) %>%
  mutate(
    # growth-form (.do baris 271-276): 100*log-difference, hilang di tahun pertama tiap provinsi
    # dplyr::lag() eksplisit - library(plm) memask lag() dan akan diam-diam menghasilkan 0
    gr_pmtb = 100 * (log_pmtb - dplyr::lag(log_pmtb)),
    gr_lab  = 100 * (log_lab_tot - dplyr::lag(log_lab_tot)),
    # Mundlak (.do baris 178-187): rata-rata provinsi dari regressor
    m_log_pmtb = mean(log_pmtb, na.rm = TRUE),
    m_log_lab  = mean(log_lab_tot, na.rm = TRUE)
  ) %>%
  ungroup()

pdata <- pdata.frame(df, index = c("Code_Prov", "Year"))

# helper: gabungkan efek acak/tetap per-provinsi kembali ke data asli
join_province_effect <- function(named_vec) {
  tibble(Code_Prov = as.numeric(names(named_vec)), value = as.numeric(named_vec))
}

cat("\n================ 1. Data loaded ================\n")
cat("N obs:", nrow(df), "| N provinsi:", n_distinct(df$Code_Prov), "| Tahun:", paste(range(df$Year), collapse = "-"), "\n")

# ==============================================================================
# 3. Random-effects (RE) - model utama, TFP nominal ADHB (.do baris 32-76)
# ==============================================================================
cat("\n================ 3. RE - log_ADHB_Tot ================\n")
re_adhb <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "random")
print(coeftest(re_adhb, vcov = robust_vcov(re_adhb)))

u_i_re  <- join_province_effect(ranef(re_adhb)) %>% rename(u_i = value)
df <- df %>% left_join(u_i_re, by = "Code_Prov")

b0 <- coef(re_adhb)["(Intercept)"]
b1 <- coef(re_adhb)["log_pmtb"]
b2 <- coef(re_adhb)["log_lab_tot"]

df <- df %>%
  mutate(
    ue_it_re = log_ADHB_Tot - (b0 + b1 * log_pmtb + b2 * log_lab_tot),
    e_it_re  = ue_it_re - u_i,
    cons_i   = b0 + u_i,
    cons_it  = b0 + ue_it_re,
    tfp_i    = exp(cons_i),
    tfp_it   = exp(cons_it),
    b_pmtb   = b1,
    b_lab_tot = b2
  )

cat(sprintf("b1 (log_pmtb)    = %9.6f\n", b1))
cat(sprintf("b2 (log_lab_tot) = %9.6f\n", b2))

re_export <- df %>%
  select(Code_Prov, Pre_Prov, Year, cons_i, tfp_i, cons_it, tfp_it, b_pmtb, b_lab_tot) %>%
  arrange(Code_Prov, Year)
write.xlsx(re_export, file.path(output_dir, "RE Constants per Province-Year.xlsx"))

# ==============================================================================
# 4. Fixed-effects (FE) - within estimation (.do baris 79-143)
# ==============================================================================
cat("\n================ 4. FE - log_ADHB_Tot ================\n")
fe_adhb <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "within")
print(coeftest(fe_adhb, vcov = robust_vcov(fe_adhb)))

cons_i_fe_vec <- join_province_effect(fixef(fe_adhb, type = "level")) %>% rename(cons_i_fe = value)
df <- df %>% left_join(cons_i_fe_vec, by = "Code_Prov")

fe_idx <- index(fe_adhb)
fe_resid <- tibble(Code_Prov = as.numeric(as.character(fe_idx[[1]])),
                    Year = as.numeric(as.character(fe_idx[[2]])),
                    e_it_fe = as.numeric(residuals(fe_adhb)))
df <- df %>% left_join(fe_resid, by = c("Code_Prov", "Year")) %>%
  mutate(
    cons_it_fe = cons_i_fe + e_it_fe,
    tfp_i_fe   = exp(cons_i_fe),
    tfp_it_fe  = exp(cons_it_fe)
  )

# -- Jackknife SE: leave-one-province-out (.do baris 103-104) -------------------
jackknife_panel <- function(formula, data, model_type, index_var = "Code_Prov") {
  groups <- unique(data[[index_var]])
  coef_list <- lapply(groups, function(g) {
    sub <- data[data[[index_var]] != g, ]
    sub_p <- pdata.frame(sub, index = c("Code_Prov", "Year"))
    m <- plm(formula, data = sub_p, model = model_type)
    coef(m)
  })
  coef_mat <- do.call(rbind, coef_list)
  n <- length(groups)
  theta_bar <- colMeans(coef_mat)
  dev <- sweep(coef_mat, 2, theta_bar, "-")
  se <- sqrt((n - 1) / n * colSums(dev^2))
  se
}
cat("\n-- FE jackknife SE (leave-one-province-out) --\n")
print(jackknife_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "within"))

# -- Bootstrap SE: resample provinces with replacement, 500 reps (.do baris 107) -
bootstrap_panel <- function(formula, data, model_type, reps = 500, seed = 12345, index_var = "Code_Prov") {
  set.seed(seed)
  groups <- unique(data[[index_var]])
  n <- length(groups)
  coef_list <- vector("list", reps)
  base_coef <- coef(plm(formula, data = pdata.frame(data, index = c(index_var, "Year")), model = model_type))
  for (r in seq_len(reps)) {
    samp_groups <- sample(groups, n, replace = TRUE)
    pieces <- lapply(seq_along(samp_groups), function(i) {
      sub <- data[data[[index_var]] == samp_groups[i], ]
      sub[[index_var]] <- i
      sub
    })
    boot_data <- do.call(rbind, pieces)
    boot_p <- tryCatch(pdata.frame(boot_data, index = c(index_var, "Year")), error = function(e) NULL)
    m <- if (!is.null(boot_p)) tryCatch(plm(formula, data = boot_p, model = model_type), error = function(e) NULL) else NULL
    coef_list[[r]] <- if (!is.null(m)) coef(m) else rep(NA_real_, length(base_coef))
  }
  coef_mat <- do.call(rbind, coef_list)
  apply(coef_mat, 2, sd, na.rm = TRUE)
}
cat("\n-- FE bootstrap SE (500 reps, resample provinsi) --\n")
print(bootstrap_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "within"))

# -- Hausman test FE vs RE (.do baris 110-115) ---------------------------------
cat("\n-- Hausman test (FE vs RE, ADHB) --\n")
print(phtest(fe_adhb, re_adhb))

# -- Coefficients per provinsi (OLS terpisah per provinsi) (.do baris 118-131) -
prov_coef <- df %>%
  group_by(Code_Prov, Pre_Prov) %>%
  group_modify(~ {
    m <- lm(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = .x)
    tibble(cons_prov = coef(m)[1], b_pmtb_prov = coef(m)[2], b_lab_prov = coef(m)[3])
  }) %>%
  ungroup()
df <- df %>% left_join(prov_coef, by = c("Code_Prov", "Pre_Prov"))

cat("\n-- Mean-group average (Pesaran-Smith) koefisien province-specific --\n")
print(prov_coef %>% summarise(across(c(b_pmtb_prov, b_lab_prov),
      list(mean = ~mean(.x, na.rm = TRUE), sd = ~sd(.x, na.rm = TRUE),
           min = ~min(.x, na.rm = TRUE), max = ~max(.x, na.rm = TRUE)))))

fe_export <- df %>%
  select(Code_Prov, Pre_Prov, Year, cons_i_fe, tfp_i_fe, cons_it_fe, tfp_it_fe,
         cons_prov, b_pmtb_prov, b_lab_prov) %>%
  arrange(Code_Prov, Year)
write.xlsx(fe_export, file.path(output_dir, "FE Constants and Coefficients per Province.xlsx"))

# ==============================================================================
# 5. Robustness varian RE (.do baris 146-197)
# titik estimasi (koefisien) sama dengan RE utama di atas; yang berubah hanya SE
# atau cara menangani komponen varian - lihat catatan .do baris 146
# ==============================================================================
cat("\n================ 5. Robustness varian RE ================\n")

pooled_adhb <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "pooling")
cat("\n-- (1) Breusch-Pagan LM test (xttest0): H0 = tidak ada random effect --\n")
print(plmtest(pooled_adhb, type = "bp"))

cat("\n-- (2) RE jackknife SE --\n")
print(jackknife_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "random"))

cat("\n-- (3) RE bootstrap SE (500 reps) --\n")
print(bootstrap_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "random"))

# (4) Swamy-Arora: model default plm(model="random") SUDAH memakai Swamy-Arora
# (random.method="swar" adalah default) - identik dengan re_adhb di atas, tidak
# perlu model terpisah.
cat("\n-- (4) Swamy-Arora = model RE utama (default plm), lihat section 3 --\n")

# (5) MLE - APROKSIMASI: plm tidak punya RE-MLE, dipakai random-intercept ML
# lewat nlme::lme sebagai padanan konseptual (bukan replikasi identik xtreg mle)
cat("\n-- (5) RE via ML (aproksimasi, nlme::lme) --\n")
re_mle <- lme(log_ADHB_Tot ~ log_pmtb + log_lab_tot, random = ~1 | Code_Prov, data = df, method = "ML", na.action = na.omit)
print(summary(re_mle))

# (6) two-way: tahun sebagai dummy di dalam RE satu-arah
cat("\n-- (6) Two-way RE (dummy tahun) --\n")
re_2way <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot + factor(Year), data = pdata, model = "random")
print(coeftest(re_2way, vcov = robust_vcov(re_2way))[1:3, ])

# (7) Mundlak correlated random effects
cat("\n-- (7) Mundlak CRE --\n")
re_mundlak <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot + m_log_pmtb + m_log_lab, data = pdata, model = "random")
print(coeftest(re_mundlak, vcov = robust_vcov(re_mundlak)))
cat("Joint test m_log_pmtb = m_log_lab = 0 (alternatif Hausman robust):\n")
print(linearHypothesis(re_mundlak, c("m_log_pmtb = 0", "m_log_lab = 0"), vcov. = robust_vcov(re_mundlak)))

# (8) benchmark: pooled OLS cluster & between estimator
cat("\n-- (8a) Pooled OLS, cluster-robust SE --\n")
print(coeftest(pooled_adhb, vcov = vcovCR(pooled_adhb, cluster = df$Code_Prov, type = "CR1")))

cat("\n-- (8b) Between estimator --\n")
between_adhb <- plm(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "between")
print(coeftest(between_adhb))

cat("\n-- Perbandingan koefisien semua varian RE --\n")
compare_re <- list(re_gls = re_adhb, re_2way = re_2way, re_mundlak = re_mundlak,
                    pooled = pooled_adhb, betw = between_adhb)
print(sapply(compare_re, function(m) coef(m)[c("(Intercept)", "log_pmtb", "log_lab_tot")]))

# ==============================================================================
# 6. Real-output (ADHK) - ulangi RE & FE (.do baris 204-266)
# sampel sama dgn ADHB karena log_lab_tot hilang di 2025 utk kedua model
# ==============================================================================
cat("\n================ 6. RE & FE - log_ADHK_Tot (riil) ================\n")

re_adhk <- plm(log_ADHK_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "random")
cat("\n-- RE (ADHK), cluster-robust --\n")
print(coeftest(re_adhk, vcov = robust_vcov(re_adhk)))

u_i_re_k <- join_province_effect(ranef(re_adhk)) %>% rename(u_i_k = value)
df <- df %>% left_join(u_i_re_k, by = "Code_Prov")
b0k <- coef(re_adhk)["(Intercept)"]; b1k <- coef(re_adhk)["log_pmtb"]; b2k <- coef(re_adhk)["log_lab_tot"]
df <- df %>% mutate(
  ue_it_k = log_ADHK_Tot - (b0k + b1k * log_pmtb + b2k * log_lab_tot),
  cons_i_k  = b0k + u_i_k,
  cons_it_k = b0k + ue_it_k,
  tfp_i_k   = exp(cons_i_k),
  tfp_it_k  = exp(cons_it_k)
)

cat("\n-- RE (ADHK) jackknife & bootstrap SE --\n")
print(jackknife_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "random"))
print(bootstrap_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "random"))

cat("\n-- Two-way RE (ADHK) --\n")
k_re2way <- plm(log_ADHK_Tot ~ log_pmtb + log_lab_tot + factor(Year), data = pdata, model = "random")
print(coeftest(k_re2way, vcov = robust_vcov(k_re2way))[1:3, ])

fe_adhk <- plm(log_ADHK_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "within")
cat("\n-- FE (ADHK), cluster-robust --\n")
print(coeftest(fe_adhk, vcov = robust_vcov(fe_adhk)))

cons_i_k_fe_vec <- join_province_effect(fixef(fe_adhk, type = "level")) %>% rename(cons_i_k_fe = value)
df <- df %>% left_join(cons_i_k_fe_vec, by = "Code_Prov")
fe_idx_k <- index(fe_adhk)
fe_resid_k <- tibble(Code_Prov = as.numeric(as.character(fe_idx_k[[1]])),
                      Year = as.numeric(as.character(fe_idx_k[[2]])),
                      e_it_k_fe = as.numeric(residuals(fe_adhk)))
df <- df %>% left_join(fe_resid_k, by = c("Code_Prov", "Year")) %>%
  mutate(
    cons_it_k_fe = cons_i_k_fe + e_it_k_fe,
    tfp_i_k_fe   = exp(cons_i_k_fe),
    tfp_it_k_fe  = exp(cons_it_k_fe)
  )

cat("\n-- FE (ADHK) jackknife & bootstrap SE --\n")
print(jackknife_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "within"))
print(bootstrap_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "within"))

cat("\n-- Hausman test (FE vs RE, ADHK) --\n")
print(phtest(fe_adhk, re_adhk))

adhk_export <- df %>%
  select(Code_Prov, Pre_Prov, Year, cons_i_k, tfp_i_k, cons_it_k, tfp_it_k,
         cons_i_k_fe, tfp_i_k_fe, cons_it_k_fe, tfp_it_k_fe) %>%
  arrange(Code_Prov, Year)
write.xlsx(adhk_export, file.path(output_dir, "ADHK TFP per Province-Year.xlsx"))

# ==============================================================================
# 7. Growth-form (first-difference) - consistency check (.do baris 269-298)
# ==============================================================================
cat("\n================ 7. Growth-form (first-difference) ================\n")

g1_re <- plm(Grwth1_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "random")
g1_fe <- plm(Grwth1_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "within")
g2_re <- plm(Grwth2_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "random")
g2_fe <- plm(Grwth2_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "within")

cat("\n-- Growth nominal (Grwth1) RE --\n"); print(coeftest(g1_re, vcov = robust_vcov(g1_re)))
cat("\n-- Growth nominal (Grwth1) FE --\n"); print(coeftest(g1_fe, vcov = robust_vcov(g1_fe)))
cat("\n-- Growth riil (Grwth2) RE --\n");    print(coeftest(g2_re, vcov = robust_vcov(g2_re)))
cat("\n-- Growth riil (Grwth2) FE --\n");    print(coeftest(g2_fe, vcov = robust_vcov(g2_fe)))

cat("\n-- Ringkasan konsistensi: level (ADHB vs ADHK) --\n")
print(sapply(list(ADHB_RE = re_adhb, ADHK_RE = re_adhk, ADHB_FE = fe_adhb, ADHK_FE = fe_adhk),
             function(m) coef(m)))
cat("\n-- Ringkasan konsistensi: growth (nominal vs riil) --\n")
print(sapply(list(Grwth1_RE = g1_re, Grwth2_RE = g2_re, Grwth1_FE = g1_fe, Grwth2_FE = g2_fe),
             function(m) coef(m)))

# ==============================================================================
# 8. Diagnostics (.do baris 301-403)
# ==============================================================================
cat("\n================ 8. Diagnostics ================\n")

# (a) Wooldridge test AR(1) serial correlation (xtserial)
cat("\n-- (a) Wooldridge test AR(1), tiap spesifikasi --\n")
cat("ADHB:\n");   print(pwartest(log_ADHB_Tot ~ log_pmtb + log_lab_tot, data = pdata))
cat("ADHK:\n");   print(pwartest(log_ADHK_Tot ~ log_pmtb + log_lab_tot, data = pdata))
cat("Grwth1:\n"); print(pwartest(Grwth1_Prov ~ gr_pmtb + gr_lab, data = pdata))
cat("Grwth2:\n"); print(pwartest(Grwth2_Prov ~ gr_pmtb + gr_lab, data = pdata))

# (b) Modified Wald test groupwise heteroskedasticity (xttest3)
# APROKSIMASI: plm tidak punya fungsi built-in setara xttest3; diimplementasi
# manual mengikuti formula Greene (Wald statistic ~ chi2(N))
modified_wald_test <- function(fe_model, index_ids) {
  e <- as.numeric(residuals(fe_model))
  d <- tibble(group = index_ids, e = e) %>%
    group_by(group) %>% summarise(T_i = n(), sigma2_i = sum(e^2) / T_i, .groups = "drop")
  sigma2_pooled <- sum(e^2) / length(e)
  W <- sum((d$sigma2_i - sigma2_pooled)^2 / (2 * sigma2_pooled^2 / d$T_i))
  list(statistic = W, df = nrow(d), p.value = pchisq(W, df = nrow(d), lower.tail = FALSE))
}
cat("\n-- (b) Modified Wald groupwise heteroskedasticity (aproksimasi xttest3) --\n")
cat("ADHB FE:\n"); print(modified_wald_test(fe_adhb, as.character(index(fe_adhb)[[1]])))
cat("ADHK FE:\n"); print(modified_wald_test(fe_adhk, as.character(index(fe_adhk)[[1]])))
cat("Grwth1 FE:\n"); print(modified_wald_test(g1_fe, as.character(index(g1_fe)[[1]])))
cat("Grwth2 FE:\n"); print(modified_wald_test(g2_fe, as.character(index(g2_fe)[[1]])))

# (c) Pesaran CD test cross-sectional dependence
cat("\n-- (c) Pesaran CD test --\n")
cat("ADHB RE:\n"); print(pcdtest(re_adhb, test = "cd"))
cat("ADHB FE:\n"); print(pcdtest(fe_adhb, test = "cd"))
cat("ADHK RE:\n"); print(pcdtest(re_adhk, test = "cd"))
cat("ADHK FE:\n"); print(pcdtest(fe_adhk, test = "cd"))
cat("ADHK two-way RE:\n"); print(pcdtest(k_re2way, test = "cd"))

# (d) Breusch-Pagan LM (xttest0) untuk model lain
pooled_adhk <- plm(log_ADHK_Tot ~ log_pmtb + log_lab_tot, data = pdata, model = "pooling")
pooled_g1   <- plm(Grwth1_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "pooling")
pooled_g2   <- plm(Grwth2_Prov ~ gr_pmtb + gr_lab, data = pdata, model = "pooling")
cat("\n-- (d) Breusch-Pagan LM (sisanya) --\n")
cat("ADHK:\n");   print(plmtest(pooled_adhk, type = "bp"))
cat("Grwth1:\n"); print(plmtest(pooled_g1, type = "bp"))
cat("Grwth2:\n"); print(plmtest(pooled_g2, type = "bp"))

# (e) Mundlak robust Hausman untuk ADHK
cat("\n-- (e) Mundlak robust Hausman (ADHK) --\n")
k_mundlak <- plm(log_ADHK_Tot ~ log_pmtb + log_lab_tot + m_log_pmtb + m_log_lab, data = pdata, model = "random")
print(coeftest(k_mundlak, vcov = robust_vcov(k_mundlak)))
print(linearHypothesis(k_mundlak, c("m_log_pmtb = 0", "m_log_lab = 0"), vcov. = robust_vcov(k_mundlak)))

# (f) RESET test fungsional form
reset_test_panel <- function(formula, data, model_type) {
  m <- plm(formula, data = data, model = model_type)
  b <- coef(m)
  slope_names <- setdiff(names(b), "(Intercept)")
  rhs_vars <- all.vars(formula)[-1]
  xbh <- as.matrix(as.data.frame(data)[, rhs_vars]) %*% b[slope_names]
  if ("(Intercept)" %in% names(b)) xbh <- xbh + b["(Intercept)"]
  xbh <- as.numeric(xbh) - mean(as.numeric(xbh), na.rm = TRUE)
  data2 <- as.data.frame(data)
  data2$xbh2 <- xbh^2
  data2$xbh3 <- xbh^3
  data2_p <- pdata.frame(data2, index = c("Code_Prov", "Year"))
  new_formula <- update(formula, . ~ . + xbh2 + xbh3)
  m2 <- plm(new_formula, data = data2_p, model = model_type)
  linearHypothesis(m2, c("xbh2 = 0", "xbh3 = 0"), vcov. = robust_vcov(m2))
}
cat("\n-- (f) RESET test (H0 = tidak ada omitted nonlinearity) --\n")
cat("ADHB RE:\n"); print(reset_test_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "random"))
cat("ADHB FE:\n"); print(reset_test_panel(log_ADHB_Tot ~ log_pmtb + log_lab_tot, df, "within"))
cat("ADHK RE:\n"); print(reset_test_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "random"))
cat("ADHK FE:\n"); print(reset_test_panel(log_ADHK_Tot ~ log_pmtb + log_lab_tot, df, "within"))

# (g) fit summary 8 model utama (.do baris 386-403, matrix FIT)
# R2_within/between/overall mengikuti definisi Stata xtreg = kuadrat korelasi antara
# y dan xb (masing-masing dalam transformasi within / between / apa adanya), BUKAN
# R2 bawaan plm yang definisinya berbeda antar model - supaya angkanya sebanding
# dengan matrix FIT di .do.
stata_r2 <- function(m) {
  grp <- as.character(index(m)[[1]])
  y   <- as.numeric(m$model[[1]])
  # xb dihitung ulang di skala level dari model matrix untransformed - TIDAK boleh
  # pakai y - residuals(): untuk model within residualnya sudah ter-demean, jadi
  # selisihnya bukan fitted value di skala asli. Untuk within, coef tidak punya
  # intercept sehingga xb otomatis mengecualikan u_i (persis definisi Stata).
  mm   <- model.matrix(m, model = "pooling")
  b    <- coef(m)
  cols <- intersect(colnames(mm), names(b))
  xb   <- as.numeric(mm[, cols, drop = FALSE] %*% b[cols])
  gm  <- function(v) ave(v, grp, FUN = mean)                  # rata-rata per provinsi
  sq_cor <- function(a, b) if (sd(a) == 0 || sd(b) == 0) NA_real_ else cor(a, b)^2
  bet <- !duplicated(grp)
  c(R2_within  = sq_cor(y - gm(y), xb - gm(xb)),
    R2_between = sq_cor(gm(y)[bet], gm(xb)[bet]),
    R2_overall = sq_cor(y, xb))
}

# sigma_u/sigma_e: RE mengambil komponen varian dari ercomp; FE tidak punya ercomp
# (inilah sumber crash run sebelumnya - NULL[1] lolos tryCatch lalu jadi list), jadi
# dihitung langsung dari sebaran fixed effect dan residual.
stata_sigma <- function(m) {
  if (m$args$model == "random") {
    # plm menamai komponennya "id" dan "idios" (bukan "individual"/"idiosyncratic"
    # seperti yang tercetak di summary) - salah nama menghasilkan NA diam-diam
    s2 <- summary(m)$ercomp$sigma2
    su <- sqrt(unname(s2["id"])); se <- sqrt(unname(s2["idios"]))
  } else {
    su <- sd(as.numeric(fixef(m))); se <- sd(as.numeric(residuals(m)))
  }
  c(sigma_u = su, sigma_e = se, rho = su^2 / (su^2 + se^2))
}

fit_summary <- function(m) {
  as.numeric(c(stata_r2(m), stata_sigma(m), N = nobs(m)))
}
fit_models <- list(ADHB_RE = re_adhb, ADHB_FE = fe_adhb, ADHK_RE = re_adhk, ADHK_FE = fe_adhk,
                   Grw1_RE = g1_re, Grw1_FE = g1_fe, Grw2_RE = g2_re, Grw2_FE = g2_fe)
fit_tab <- t(sapply(fit_models, fit_summary))
colnames(fit_tab) <- c("R2_within", "R2_between", "R2_overall", "sigma_u", "sigma_e", "rho", "N")
cat("\n-- (g) Fit summary 8 model utama --\n")
cat("(bandingkan hanya dalam satu variabel dependen; R2 lintas-y tidak sebanding)\n")
print(round(fit_tab, 3))

# ==============================================================================
# 9. Visualisasi TFP (tambahan, tidak ada di .do)
# Semua grafik memakai log TFP (cons_*), bukan level exp(cons_*): level TFP sangat
# besar dan skewed karena multiplier unit yang dipertahankan dari .do, sehingga bar
# chart level tidak terbaca. Perbandingan antar provinsi tidak berubah.
# ==============================================================================
cat("\n================ 9. Visualisasi ================\n")

theme_tfp <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(colour = "grey35", size = 9),
        plot.caption = element_text(colour = "grey45", size = 7.5, hjust = 0))

# -- (1) Ranking TFP per provinsi: ADHK (riil) vs ADHB (nominal), model RE --------
# Ditampilkan sbg deviasi dari rata-rata 34 provinsi, bukan level absolut: level log TFP
# ADHB (~1,6) dan ADHK (~14,8) berbeda jauh karena multiplier unit, sehingga bar-dari-nol
# membuat panel ADHK rata semua. Deviasi menyamakan skala & langsung terbaca
# "berapa persen di atas/bawah rata-rata nasional".
rank_df <- df %>%
  distinct(Code_Prov, Pre_Prov, cons_i_k, cons_i) %>%
  pivot_longer(c(cons_i_k, cons_i), names_to = "dasar", values_to = "log_tfp") %>%
  # dplyr::recode dipanggil eksplisit - library(car) memask recode() dgn signature berbeda
  mutate(dasar = dplyr::recode(dasar, cons_i_k = "ADHK (riil)", cons_i = "ADHB (nominal)")) %>%
  group_by(dasar) %>%
  mutate(dev = log_tfp - mean(log_tfp)) %>%
  ungroup()
urutan <- rank_df %>% filter(dasar == "ADHK (riil)") %>% arrange(dev) %>% pull(Pre_Prov)

p_rank <- ggplot(rank_df, aes(x = dev, y = factor(Pre_Prov, levels = urutan))) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_segment(aes(x = 0, xend = dev, yend = factor(Pre_Prov, levels = urutan)),
               colour = "grey70", linewidth = 0.4) +
  geom_point(colour = "grey20", size = 1.8) +
  facet_wrap(~dasar) +
  labs(title = "Peringkat TFP Provinsi, model Random Effects",
       subtitle = "Deviasi log TFP time-invariant (a + u_i) dari rata-rata 34 provinsi; urutan mengikuti basis ADHK",
       x = "deviasi log TFP dari rata-rata nasional", y = NULL,
       caption = "Sumber: perhitungan atas Dataset Agregasi Provinsi. TFP = residual Solow; 0,10 ≈ 10% di atas rata-rata.") +
  theme_tfp
ggsave(file.path(output_dir, "Ranking TFP Provinsi (ADHK vs ADHB).png"), p_rank,
       width = 9, height = 7, dpi = 300)

# -- (2) Tren TFP per provinsi-tahun (ADHK, RE) ---------------------------------
tren_df <- df %>% filter(!is.na(cons_it_k))
tren_nas <- tren_df %>% group_by(Year) %>% summarise(cons_it_k = mean(cons_it_k), .groups = "drop")

# sorot penggerak terbesar (perubahan log TFP awal->akhir) supaya garis-garis abu punya cerita
gerak <- tren_df %>% group_by(Pre_Prov) %>%
  summarise(delta = cons_it_k[which.max(Year)] - cons_it_k[which.min(Year)], .groups = "drop")
sorot <- c(gerak %>% slice_max(delta, n = 2) %>% pull(Pre_Prov),
           gerak %>% slice_min(delta, n = 2) %>% pull(Pre_Prov))
tren_sorot <- tren_df %>% filter(Pre_Prov %in% sorot)

p_tren <- ggplot(tren_df, aes(Year, cons_it_k)) +
  geom_line(aes(group = Pre_Prov), colour = "grey80", linewidth = 0.3) +
  geom_line(data = tren_sorot, aes(group = Pre_Prov, colour = Pre_Prov), linewidth = 0.6) +
  # rata-rata nasional dibuat putus-putus, bukan sekadar tebal: kalau sama-sama solid
  # hitam ia tak terbedakan dari provinsi yang disorot
  geom_line(data = tren_nas, colour = "black", linewidth = 1, linetype = "22") +
  scale_colour_grey(start = 0.25, end = 0.65, name = NULL) +
  scale_x_continuous(breaks = sort(unique(tren_df$Year))) +
  labs(title = "Tren TFP Provinsi (ADHK, Random Effects)",
       subtitle = "Abu tipis = tiap provinsi; putus-putus = rata-rata 34 provinsi; solid tebal = 2 kenaikan & 2 penurunan terbesar",
       x = NULL, y = "log TFP per provinsi-tahun",
       caption = "2025 tidak masuk: pmtb & tenaga kerja belum tersedia.") +
  theme_tfp
ggsave(file.path(output_dir, "Tren TFP Provinsi.png"), p_tren,
       width = 8, height = 5, dpi = 300)

# -- (3) TFP vs output: seberapa jauh TFP sekadar mencerminkan ukuran ekonomi ----
sc_df <- df %>%
  group_by(Code_Prov, Pre_Prov) %>%
  summarise(cons_i_k = first(cons_i_k),
            log_adhk_mean = mean(log_ADHK_Tot, na.rm = TRUE), .groups = "drop")
ekstrem <- sc_df %>% filter(rank(cons_i_k) <= 3 | rank(-cons_i_k) <= 3 |
                              rank(log_adhk_mean) <= 3 | rank(-log_adhk_mean) <= 3)

p_sc <- ggplot(sc_df, aes(log_adhk_mean, cons_i_k)) +
  geom_point(colour = "grey30", size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "grey55", linewidth = 0.5) +
  # check_overlap: label provinsi berdekatan (mis. Maluku/Maluku Utara) saling tumpuk
  geom_text(data = ekstrem, aes(label = Pre_Prov), size = 2.6, vjust = -0.9,
            colour = "grey20", check_overlap = TRUE) +
  labs(title = "TFP vs Skala Ekonomi Provinsi",
       subtitle = "Rata-rata log PDRB riil (ADHK) vs log TFP time-invariant",
       x = "rata-rata log PDRB ADHK", y = "log TFP (ADHK, RE)",
       caption = "Kemiringan positif = provinsi besar cenderung ber-TFP tinggi; perlu hati-hati menafsirkan TFP sbg efisiensi murni.") +
  theme_tfp
ggsave(file.path(output_dir, "TFP vs Skala Ekonomi.png"), p_sc,
       width = 7, height = 5.5, dpi = 300)

cat("3 grafik tersimpan.\n")

# -- Tabel TFP ringkas untuk report --------------------------------------------
tfp_tabel <- df %>%
  distinct(Code_Prov, Pre_Prov, cons_i_k, cons_i_k_fe, cons_i, cons_i_fe) %>%
  arrange(desc(cons_i_k))
write.xlsx(tfp_tabel, file.path(output_dir, "Ringkasan TFP per Provinsi.xlsx"))
cat("\n-- TFP per provinsi (log, ADHK-RE), urut tertinggi --\n")
print(as.data.frame(tfp_tabel %>% mutate(across(where(is.numeric), ~round(.x, 3)))), row.names = FALSE)

cat("\n-- Rata-rata TFP nasional per tahun (ADHK-RE) --\n")
print(as.data.frame(tren_nas %>% mutate(cons_it_k = round(cons_it_k, 3))), row.names = FALSE)

cat("\n================ SELESAI ================\n")
cat("Output tersimpan di:", normalizePath(output_dir), "\n")
