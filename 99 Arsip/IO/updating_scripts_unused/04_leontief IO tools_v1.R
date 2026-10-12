###------------------------------------------------------
### 04. Leontief Multiplier, Backward & Forward Linkage  
### Input: output dari script 01, 02, 03                 
### Coverage: IO52, IO185, IRIO52 (per provinsi)         
###------------------------------------------------------

library(openxlsx)
library(dplyr)
library(tidyverse)

###----------------------------------------------------------
### FUNGSI UTAMA
###----------------------------------------------------------

# Leontief Inverse: L = (I - A)^(-1)
compute_leontief <- function(A_mat) {
  n <- nrow(A_mat)
  I <- diag(n)
  solve(I - A_mat)
}

# Output Multiplier (kolom sum dari L)
compute_output_multiplier <- function(L) {
  colSums(L)
}

# Income Multiplier Type I
# m_j = (sum_i w_i * L_ij) / w_j
# w = wage coefficient = W_i / X_i
compute_income_multiplier_type1 <- function(L, W_vec, X_vec) {
  w <- W_vec / ifelse(X_vec == 0, 1, X_vec)   # wage coefficient per sektor
  numerator   <- as.vector(w %*% L)            # 1xn %*% nxn -> 1xn
  denominator <- w
  ifelse(denominator == 0, NA_real_, numerator / denominator)
}

# Backward Linkage (Power of Dispersion) — Rasmussen
# BL_j = (1/n * colSum_j(L)) / (1/n^2 * totalSum(L))
compute_backward_linkage <- function(L) {
  n          <- nrow(L)
  col_means  <- colSums(L) / n
  grand_mean <- sum(L) / n^2
  col_means / grand_mean
}

# Forward Linkage (Sensitivity of Dispersion) — Rasmussen
# FL_i = (1/n * rowSum_i(L)) / (1/n^2 * totalSum(L))
compute_forward_linkage <- function(L) {
  n          <- nrow(L)
  row_means  <- rowSums(L) / n
  grand_mean <- sum(L) / n^2
  row_means / grand_mean
}

# Klasifikasi sektor berdasarkan BL dan FL
classify_linkage <- function(BL, FL) {
  case_when(
    BL >= 1 & FL >= 1 ~ "Key sector",
    BL >= 1 & FL <  1 ~ "Demand-driven",
    BL <  1 & FL >= 1 ~ "Supply-driven",
    TRUE               ~ "Independent"
  )
}

# Wrapper: hitung semua indikator untuk satu A matrix
run_linkage_analysis <- function(A_mat, X_vec, sector_codes,
                                 W_vec = NULL,
                                 label = "IO") {
  
  cat("\n===", label, "===\n")
  cat("Dimensi A:", dim(A_mat), "\n")
  
  # Leontief inverse
  L <- compute_leontief(A_mat)
  
  # Output multiplier
  output_mult <- compute_output_multiplier(L)
  
  # Backward & Forward Linkage
  BL <- compute_backward_linkage(L)
  FL <- compute_forward_linkage(L)
  klasifikasi <- classify_linkage(BL, FL)
  
  result <- data.frame(
    kode            = sector_codes,
    output_mult     = output_mult,
    backward_linkage = BL,
    forward_linkage  = FL,
    klasifikasi      = klasifikasi
  )
  
  # Type I income multiplier (opsional, butuh W_vec)
  if (!is.null(W_vec)) {
    result$income_mult_type1 <- compute_income_multiplier_type1(L, W_vec, X_vec)
    cat("Income multiplier Type I: tersedia\n")
  } else {
    cat("Income multiplier Type I: dilewati (W_vec tidak disediakan)\n")
  }
  
  # Summary
  cat("Key sectors (BL>=1, FL>=1):", sum(result$klasifikasi == "Key sector"), "\n")
  cat("Output multiplier max:", round(max(output_mult), 4),
      "| sektor:", sector_codes[which.max(output_mult)], "\n")
  
  return(list(result = result, leontief = L))
}

###----------------------------------------------------------
### 1. IO 52x52 2024
###----------------------------------------------------------

A52_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "a_io52_2024")
X52_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "totaloutput_2024")

sec52_codes <- A52_raw$kode
A52_mat     <- A52_raw %>% select(-kode) %>% as.matrix()
X52_vec     <- setNames(X52_raw$totaloutput_2024, X52_raw$kode)

rownames(A52_mat) <- sec52_codes
colnames(A52_mat) <- sec52_codes

# W_vec: isi dari IO BPS jika tersedia, default NULL
# W52_vec <- ...  # baris "Upah dan Gaji" dari tabel IO 52

res52 <- run_linkage_analysis(
  A_mat        = A52_mat,
  X_vec        = X52_vec,
  sector_codes = sec52_codes,
  W_vec        = NULL,      # ganti dengan W52_vec jika punya
  label        = "IO 52x52 2024"
)

###----------------------------------------------------------
### 2. IO 185x185 2024
###----------------------------------------------------------

A185_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx", sheet = "a_io185_2024")
X185_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx", sheet = "totaloutput_2024")

prod185_codes <- A185_raw$kode
A185_mat      <- A185_raw %>% select(-kode) %>% as.matrix()
X185_vec      <- setNames(X185_raw$totaloutput_2024, X185_raw$kode)

rownames(A185_mat) <- prod185_codes
colnames(A185_mat) <- prod185_codes

res185 <- run_linkage_analysis(
  A_mat        = A185_mat,
  X_vec        = X185_vec,
  sector_codes = prod185_codes,
  W_vec        = NULL,
  label        = "IO 185x185 2024"
)

###----------------------------------------------------------
### 3. IRIO 52x52 2024 — per provinsi
###----------------------------------------------------------

A_irio_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "a_irio_2024")
X_irio_raw <- read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "totaloutput_2024")

irio_codes <- A_irio_raw$kode
A_irio_mat <- A_irio_raw %>% select(-kode) %>% as.matrix()
X_irio_vec <- setNames(X_irio_raw$totaloutput_2024, X_irio_raw$kode)

rownames(A_irio_mat) <- irio_codes
colnames(A_irio_mat) <- irio_codes

# Daftar provinsi dari kode (format: "11-I-01", "11-I-02", dst.)
prov_list <- unique(sub("-.*", "", irio_codes))
cat("Jumlah provinsi:", length(prov_list), "\n")

# Linkage per provinsi (diagonal block saja)
res_irio_list <- list()

for (prov in prov_list) {
  
  idx  <- grep(paste0("^", prov, "-"), irio_codes)
  if (length(idx) == 0) next
  
  A_prov <- A_irio_mat[idx, idx]
  X_prov <- X_irio_vec[idx]
  codes  <- irio_codes[idx]
  
  # Cek jika matriks singular / near-singular
  tryCatch({
    res_prov <- run_linkage_analysis(
      A_mat        = A_prov,
      X_vec        = X_prov,
      sector_codes = codes,
      label        = paste("IRIO prov", prov)
    )
    res_prov$result$kode_prov <- prov
    res_irio_list[[prov]] <- res_prov$result
    
  }, error = function(e) {
    cat("ERROR provinsi", prov, ":", conditionMessage(e), "\n")
  })
}

res_irio_all <- bind_rows(res_irio_list)

###----------------------------------------------------------
### CATATAN: Linkage IRIO full (inter-regional)
### Jika ingin FL/BL dengan spillover antar-provinsi,
### gunakan A_irio_mat penuh (1768x1768) tanpa partisi.
### Komputasi solve(I - A) pada 1768x1768 berat di RAM.
### Gunakan Matrix::solve() dari package Matrix jika perlu.
###----------------------------------------------------------

# res_full_irio <- run_linkage_analysis(
#   A_mat        = A_irio_mat,
#   X_vec        = X_irio_vec,
#   sector_codes = irio_codes,
#   label        = "IRIO full 1768x1768"
# )

###----------------------------------------------------------
### EXPORT
###----------------------------------------------------------

out <- list(
  "io52_linkage"   = res52$result,
  "io185_linkage"  = res185$result,
  "irio_linkage"   = res_irio_all
)

write.xlsx(out, "01 Data/IO-IRIO-NA/output/updating_2024/v1_linkage_multiplier.xlsx")
cat("\nExport selesai: 01 Data/IO-IRIO-NA/output/updating_2024/v1_linkage_multiplier.xlsx\n")