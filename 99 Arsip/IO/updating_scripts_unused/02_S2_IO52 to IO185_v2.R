###------------------------------------------------------###
### 02. Rescaling updated IO (52x52) into (185x185)      ###
### Stage 1: Reattach names + Reverse I-46               ###
### Stage 2: Disaggregate 51x51 -> 185x185               ###
### Output: A matrix, X, U, V vectors + eval tools       ###
###------------------------------------------------------###

#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data
A_io24.52   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx", sheet = "a_irio_2024")
U_io24.52   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx", sheet = "interm_output_2024", colNames = FALSE)
V_io24.52   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx", sheet = "interm_input_2024",  colNames = FALSE)
X_io24.52   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx", sheet = "totaloutput_2024",   colNames = FALSE)
io185_raw   <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io20.csv", header = TRUE)
io52_raw    <- rio::import("01 Data/IO-IRIO-NA/output/updating_2024/v1_io20(52x52).csv", header = TRUE)   # IO 2020 versi 52 subsector
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "Full_Concordance")

#-> 1.Reattach nama subsector ke Z matrix 
#   Ambil urutan kode subsector dari io52_raw (I-01 ... I-52, 2100)
#   Posisi row x column sudah selaras dengan Z_ext

sector_codes <- io52_raw$kode  # panjang 53: I-01..I-52, 2100

# 1.1. Reconstruct Z matrix dari A dan X (52x52 sektor only, exclude baris/kolom 2100)
A_mat <- as.matrix(A_io24.52)                # 52x52
X_vec <- as.numeric(X_io24.52[[1]])          # panjang 52
Z52   <- sweep(A_mat, 2, X_vec, "*")         # Z = A * diag(X)

# 1.2. Attach rownames & colnames: I-01..I-52
sec52_codes <- sector_codes[sector_codes != "2100"]  # 52 kode sektor
rownames(Z52) <- sec52_codes
colnames(Z52) <- sec52_codes
names(X_vec)  <- sec52_codes

# 1.3. Verifikasi: total output sebelum reversal
total_output_before <- sum(X_vec)
cat("=== TAHAP 1: Reattach nama ===\n")
cat("Total output (52 subsector):", formatC(total_output_before, format = "e"), "\n")
cat("Dimensi Z52:", dim(Z52), "\n\n")



#-> 2. Reversal I-46 -> I-43, I-44, I-45 (no product that matches the classification)

# Prinsip:
#   - Hanya I-43, I-44, I-45 yang berubah nilainya
#   - Semua sektor lain TIDAK berubah
#   - X vector dipertahankan (total output tidak berubah)
#   - Proporsi berdasarkan nilai I-43/44/45 di Z 2024 itu sendiri
#   - Kalau I-43+I-44+I-45 = 0 di suatu sel -> bagi rata (1/3 masing-masing)
#   - Baris 2100 dihitung ulang sebagai colSum setelah reversal sektor

Z51 <- Z52  # akan dimodifikasi, copy dulu

# 2.1: Reversal BARIS I-46 (distribusi ke baris I-43/44/45 per kolom j)
# Untuk setiap kolom j: tambahkan nilai Z["I-46", j] ke baris I-43/44/45
# proporsional terhadap Z["I-43",j], Z["I-44",j], Z["I-45",j]

for (j in sec52_codes) {
  
  val_46 <- Z52["I-46", j]
  
  if (val_46 == 0) next  # tidak ada yang perlu didistribusikan
  
  v43 <- Z52["I-43", j]
  v44 <- Z52["I-44", j]
  v45 <- Z52["I-45", j]
  tot <- v43 + v44 + v45
  
  if (tot == 0) {
    # Bagi rata
    prop <- c(1/3, 1/3, 1/3)
  } else {
    prop <- c(v43, v44, v45) / tot
  }
  
  # Tambahkan ke I-43/44/45, jangan sentuh kolom lain
  Z51["I-43", j] <- Z51["I-43", j] + prop[1] * val_46
  Z51["I-44", j] <- Z51["I-44", j] + prop[2] * val_46
  Z51["I-45", j] <- Z51["I-45", j] + prop[3] * val_46
}

# 2.1: Reversal KOLOM I-46 (distribusi ke kolom I-43/44/45 per baris i) ---
# Untuk setiap baris i (SEKTOR SAJA, bukan 2100):
# tambahkan nilai Z[i, "I-46"] ke kolom I-43/44/45
# proporsional terhadap Z[i, "I-43"], Z[i, "I-44"], Z[i, "I-45"]

# Gunakan nilai dari Z51 yang sudah diupdate baris I-46-nya (2A sudah selesai)
# tapi untuk referensi proporsi kolom, kita tetap gunakan Z52 asli
# agar tidak ada double-count dari perubahan 2A

for (i in sec52_codes) {
  
  val_46 <- Z52[i, "I-46"]  # gunakan Z52 asli untuk menghindari bias dari 2A
  
  if (val_46 == 0) next
  
  v43 <- Z52[i, "I-43"]
  v44 <- Z52[i, "I-44"]
  v45 <- Z52[i, "I-45"]
  tot <- v43 + v44 + v45
  
  if (tot == 0) {
    prop <- c(1/3, 1/3, 1/3)
  } else {
    prop <- c(v43, v44, v45) / tot
  }
  
  # Tambahkan ke kolom I-43/44/45
  Z51[i, "I-43"] <- Z51[i, "I-43"] + prop[1] * val_46
  Z51[i, "I-44"] <- Z51[i, "I-44"] + prop[2] * val_46
  Z51[i, "I-45"] <- Z51[i, "I-45"] + prop[3] * val_46
}

# 2.3: Hapus baris dan kolom I-46
Z51 <- Z51[rownames(Z51) != "I-46", colnames(Z51) != "I-46"]

# 2.4: Update X vector (hapus I-46, pertahankan nilai lain)
# X untuk I-43/44/45 tidak berubah karena reversal hanya menggeser
# nilai DALAM intermediate matrix, bukan total output
X51 <- X_vec[names(X_vec) != "I-46"]

# --- 2E: Verifikasi ---
sec51_codes <- names(X51)

cat("Dimensi Z51:", dim(Z51), "\n")
cat("Panjang X51:", length(X51), "\n")
cat("Total output (51 subsector):", formatC(sum(X51), format = "e"), "\n")
cat("Total output (52 sebelum reversal, tanpa I-46):",
    formatC(sum(X_vec[names(X_vec) != "I-46"]), format = "e"), "\n")

# Pastikan tidak ada perubahan di luar I-43/44/45
idx_check <- setdiff(sec51_codes, c("I-43","I-44","I-45"))
max_diff_row <- max(abs(Z51[idx_check, idx_check] - Z52[idx_check, idx_check]))
max_diff_col <- max(abs(Z51[idx_check, idx_check] - Z52[idx_check, idx_check]))
cat("Max perubahan di sektor SELAIN I-43/44/45:", max_diff_row,
    "(harus 0 atau mendekati 0)\n\n")



#-> 3: DISAGREGASI 51x51 -> 185x185

# 3.1: Siapkan Z matrix IO 2020 versi 185 produk
# Ambil hanya baris dan kolom produk 1..185 (exclude 2100, 3100)
prod185_codes <- as.character(concord52_185$prod185)  # "1","2",...,"185"

# Filter io185_raw: hanya baris produk (bukan total)
io185_sector <- io185_raw %>%
  filter(Kode %in% prod185_codes) %>%
  arrange(match(Kode, prod185_codes))

# Z matrix 185x185 (dalam satuan yang sama dengan io185_raw)
Z185_2020 <- io185_sector %>%
  select(all_of(prod185_codes)) %>%
  as.matrix()
rownames(Z185_2020) <- prod185_codes
colnames(Z185_2020) <- prod185_codes

cat("Dimensi Z185_2020:", dim(Z185_2020), "\n")

# 3.2: Hitung Z_KL_2020 (agregasi 185 -> 51)
# Mapping: prod185 -> sec52 (yang sudah exclude I-46 = sec51)
# Pastikan tidak ada produk yang mapped ke I-46
concord_51 <- concord52_185 %>%
  filter(sec52 != "I-46") %>%
  mutate(prod185 = as.character(prod185))

# Cek apakah semua 185 produk tercakup
cat("Produk 185 yang ter-mapping ke sec51:",
    sum(prod185_codes %in% concord_51$prod185), "dari 185\n")
cat("Produk 185 yang mapped ke I-46 (akan di-exclude):",
    sum(concord52_185$sec52 == "I-46"), "\n\n")

# Fungsi agregasi: sum baris dan kolom Z185 berdasarkan mapping ke sec51
aggregate_185_to_51 <- function(Z185, concord) {
  # concord: data.frame dengan kolom prod185 (char) dan sec52 (char)
  
  prods   <- rownames(Z185)
  secs    <- unique(concord$sec52)
  n_sec   <- length(secs)
  
  # Buat aggregation matrix P (185 x 51): P[k,K] = 1 jika prod k -> sec K
  P <- matrix(0, nrow = length(prods), ncol = n_sec,
              dimnames = list(prods, secs))
  
  for (k in prods) {
    sec_k <- concord$sec52[concord$prod185 == k]
    if (length(sec_k) > 0) P[k, sec_k] <- 1
  }
  
  # Z_KL = P' Z185 P  (51 x 51)
  Z51_agg <- t(P) %*% Z185 %*% P
  return(list(Z51 = Z51_agg, P = P))
}

agg_result    <- aggregate_185_to_51(Z185_2020, concord_51)
Z51_2020_agg  <- agg_result$Z51
P_matrix      <- agg_result$P  # 185 x 51, dipakai nanti

# Reorder agar sama dengan urutan sec51_codes
Z51_2020_agg <- Z51_2020_agg[sec51_codes, sec51_codes]

cat("Dimensi Z51_2020_agg:", dim(Z51_2020_agg), "\n")
cat("Cek diagonal sum Z51_2020_agg vs Z51 (2024):\n")
cat("  Z51_2020 trace:", sum(diag(Z51_2020_agg)), "\n")
cat("  Z51_2024 trace:", sum(diag(Z51)), "\n\n")

# 3.3: Hitung rasio Z185_2020 / Z51_2020 per sel (k,l) ---
# ratio[k,l] = Z185_2020[k,l] / Z51_2020_agg[K,L]
# dimana K = sec51 untuk produk k, L = sec51 untuk produk l

# Buat lookup: prod185 -> sec51
prod_to_sec <- setNames(concord_51$sec52, concord_51$prod185)

# Hanya produk yang ada di concord_51
prods_in_map <- prod185_codes[prod185_codes %in% names(prod_to_sec)]
n185 <- length(prods_in_map)

cat("Produk yang ter-mapping (dipakai dalam disagregasi):", n185, "\n\n")

# 3.4: Hitung Z185_2024 menggunakan formula ---
# Z185_2024[k,l] = Z51_2024[K,L] * (Z185_2020[k,l] / Z51_2020[K,L])
# Jika Z51_2020[K,L] = 0 tapi Z51_2024[K,L] > 0: bagi merata ke semua k,l dalam K,L

# Inisialisasi Z185_2024
Z185_2024 <- matrix(0, nrow = n185, ncol = n185,
                    dimnames = list(prods_in_map, prods_in_map))

# Loop per pasangan subsector (K, L)
for (K in sec51_codes) {
  
  # Produk yang mapped ke K (baris)
  prods_K <- prods_in_map[prod_to_sec[prods_in_map] == K]
  if (length(prods_K) == 0) next
  
  for (L in sec51_codes) {
    
    # Produk yang mapped ke L (kolom)
    prods_L <- prods_in_map[prod_to_sec[prods_in_map] == L]
    if (length(prods_L) == 0) next
    
    Z_KL_2024 <- Z51[K, L]
    Z_KL_2020 <- Z51_2020_agg[K, L]
    
    # Sub-matrix 2020 untuk blok (K,L)
    sub_2020 <- Z185_2020[prods_K, prods_L, drop = FALSE]
    
    if (Z_KL_2024 == 0) {
      # Tidak ada alokasi, isi 0
      Z185_2024[prods_K, prods_L] <- 0
      
    } else if (Z_KL_2020 == 0) {
      # Denominator 0, tapi Z_2024 > 0: bagi merata
      n_cells <- length(prods_K) * length(prods_L)
      Z185_2024[prods_K, prods_L] <- Z_KL_2024 / n_cells
      
    } else {
      # Kasus normal: proporsi dari 2020
      ratio <- sub_2020 / Z_KL_2020
      Z185_2024[prods_K, prods_L] <- Z_KL_2024 * ratio
    }
  }
}

cat("Dimensi Z185_2024:", dim(Z185_2024), "\n")
cat("Total Z185_2024:", formatC(sum(Z185_2024), format = "e"), "\n")
cat("Total Z51_2024 :", formatC(sum(Z51), format = "e"), "\n\n")



#-> 4: Hitung A matrix, X, U, V untuk 185 produk

# 4.1: Total Output X185
# X185[k] = X51[K] * (X185_2020[k] / X51_2020_agg[K])
# Dimana X185_2020 adalah total output kolom dari io185_raw

# Total output 185 dari io185_raw (kolom 3100, hanya baris produk)
x185_2020_raw <- io185_raw %>%
  filter(Kode %in% prods_in_map) %>%
  arrange(match(Kode, prods_in_map)) %>%
  pull(`3100`)
names(x185_2020_raw) <- prods_in_map

# Total output 51 dari io185_raw (setelah agregasi)
x51_2020_agg <- tapply(x185_2020_raw, prod_to_sec[prods_in_map], sum)

# Disagregasi X
X185 <- numeric(n185)
names(X185) <- prods_in_map

for (k in prods_in_map) {
  K <- prod_to_sec[k]
  x_K_2024 <- X51[K]
  x_k_2020 <- x185_2020_raw[k]
  x_K_2020 <- x51_2020_agg[K]
  
  if (x_K_2020 == 0) {
    # Bagi merata ke semua produk dalam K
    n_prods_K <- sum(prod_to_sec[prods_in_map] == K)
    X185[k] <- x_K_2024 / n_prods_K
  } else {
    X185[k] <- x_K_2024 * (x_k_2020 / x_K_2020)
  }
}

cat("Total X185:", formatC(sum(X185), format = "e"), "\n")
cat("Total X51 :", formatC(sum(X51),  format = "e"), "\n\n")

# 4.2: A Matrix 185x185
# A185[k,l] = Z185[k,l] / X185[l]
X185_safe <- ifelse(X185 == 0, 1, X185)  # hindari pembagian nol
A185 <- sweep(Z185_2024, 2, X185_safe, "/")
A185[, X185 == 0] <- 0  # kolom dengan X=0 -> A=0

# 4.3: Intermediate Output (U) dan Intermediate Input (V) ---
U185 <- rowSums(Z185_2024)   # intermediate output per produk (baris)
V185 <- colSums(Z185_2024)   # intermediate input per produk (kolom)

cat("Total U185:", formatC(sum(U185), format = "e"), "\n")
cat("Total V185:", formatC(sum(V185), format = "e"), "\n")
cat("U == V?", isTRUE(all.equal(sum(U185), sum(V185))), "\n\n")


#-> 5: Evaluation tools

evaluate_disaggregation <- function(Z185_2024, Z51_2024, prod_to_sec, sec51_codes) {
  
  cat("=== EVALUATION: Konsistensi Disagregasi ===\n\n")
  
  prods <- rownames(Z185_2024)
  
  # 1. Re-agregasi Z185_2024 -> Z51_check
  secs   <- sec51_codes
  n_sec  <- length(secs)
  Z51_check <- matrix(0, n_sec, n_sec, dimnames = list(secs, secs))
  
  for (K in secs) {
    prods_K <- prods[prod_to_sec[prods] == K]
    if (length(prods_K) == 0) next
    for (L in secs) {
      prods_L <- prods[prod_to_sec[prods] == L]
      if (length(prods_L) == 0) next
      Z51_check[K, L] <- sum(Z185_2024[prods_K, prods_L])
    }
  }
  
  # 2. Hitung selisih
  diff_mat  <- Z51_check - Z51_2024
  max_diff  <- max(abs(diff_mat))
  rel_diff  <- max_diff / max(abs(Z51_2024))
  
  # 3. Cek per subsector
  diag_check <- data.frame(
    sec51       = secs,
    Z51_2024    = diag(Z51_2024),
    Z51_check   = diag(Z51_check),
    abs_diff    = abs(diag(Z51_check) - diag(Z51_2024))
  ) %>% arrange(desc(abs_diff))
  
  # 4. Summary
  summary_eval <- data.frame(
    metric = c("Max absolute difference (any cell)",
               "Relative max difference",
               "Total Z185 sum",
               "Total Z51 sum",
               "Sum difference"),
    value  = c(formatC(max_diff,        format = "e"),
               formatC(rel_diff,        format = "e"),
               formatC(sum(Z185_2024),  format = "e"),
               formatC(sum(Z51_2024),   format = "e"),
               formatC(abs(sum(Z185_2024) - sum(Z51_2024)), format = "e"))
  )
  
  cat("Summary:\n")
  print(summary_eval, row.names = FALSE)
  cat("\nTop 10 subsector dengan perbedaan diagonal terbesar:\n")
  print(head(diag_check, 10), row.names = FALSE)
  
  return(list(
    Z51_reaggregated = Z51_check,
    diff_matrix      = diff_mat,
    max_abs_diff     = max_diff,
    relative_diff    = rel_diff,
    diag_check       = diag_check,
    summary          = summary_eval
  ))
}

eval_result <- evaluate_disaggregation(Z185_2024, Z51, prod_to_sec, sec51_codes)

#-> 6: Arranging output and export


# Konversi ke data.frame dengan kolom kode (seperti format io_final_53)

# Z185 dengan row/col names sebagai karakter
Z185_df <- as.data.frame(Z185_2024)
Z185_df <- cbind(kode = prods_in_map, Z185_df)

# A185 dengan row/col names
A185_df <- as.data.frame(A185)
A185_df <- cbind(kode = prods_in_map, A185_df)

# Vectors sebagai single-column data.frame
U185_df <- data.frame(kode = prods_in_map, interm_output_2024 = U185)
V185_df <- data.frame(kode = prods_in_map, interm_input_2024  = V185)
X185_df <- data.frame(kode = prods_in_map, totaloutput_2024   = X185)

# Evaluation summary
eval_summary_df <- eval_result$summary
eval_diag_df    <- eval_result$diag_check

# Matlist: format serupa dengan output IO 52
matlist_185 <- list(
  "a_io185_2024"       = A185_df,
  "z_io185_2024"       = Z185_df,
  "interm_output_2024" = U185_df,
  "interm_input_2024"  = V185_df,
  "totaloutput_2024"   = X185_df,
  "eval_summary"       = eval_summary_df,
  "eval_diag"          = eval_diag_df
)

openxlsx::write.xlsx(matlist_185, "01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(185x185).xlsx")
