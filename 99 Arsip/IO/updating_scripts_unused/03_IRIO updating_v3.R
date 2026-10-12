###------------------------------------------------------###
### 03. IRIO updating                                    ###
### performing RAS to update the technical coefficients. ###
### Two special treatments applied pre-RAS:              ###
###   (B) share-based imputation for sectors with        ###
###       base=0 or anomalous upd (> μ+3σ threshold),    ###
###       distributing IO national values proportionally ###
###       to provincial PDRB shares.                     ###
###   (C/D) zero-out for extinct or dummy-zero sectors.  ###
### Full explanation: Technical notes.Rmd                ###
###------------------------------------------------------###

#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data
pdrb     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx", sheet = "main_dat")
irio_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/irio16.csv", header = TRUE)
io_x     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "totaloutput_2024")
io_u     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "interm_output_2024")
io_v     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "interm_input_2024")

#-> data prep
pdrb_raw <- pdrb %>%
  filter(!is.na(kodeIO)) %>%
  select(kode, base, target = target_adj, upd)

pdrb_adj <- irio_raw %>%
  select(kode) %>%
  inner_join(pdrb_raw, by = "kode")

###------------------------------------------------------###
### Bucket classification                                ###
### A: normal RAS candidates                             ###
### B: share-based imputation (base=0 or upd anomaly)    ###
### C: extinct sectors (base>0, target=0) -> zero-out    ###
### D: dummy-zero sectors (base=0, target≈0) -> skip     ###
###------------------------------------------------------###

# <- Stage 1: rule-based classification
pdrb_class <- pdrb_adj %>%
  mutate(
    sec52  = sub("^[0-9]+-", "", kode),
    bucket = case_when(
      base == 0 & target >  1e-6 ~ "B: share-based",
      base == 0 & target <= 1e-6 ~ "D: skip",
      base >  0 & target == 0    ~ "C: zero-out",
      TRUE                       ~ "A: RAS"
    )
  )

# <- Stage 2: upgrade anomalous upd from bucket A to B
#   threshold = μ + 3σ of upd distribution within bucket A
#   rationale: growth >threshold implies base year is no longer
#   a valid structural seed for RAS; IO national shares used instead
upd_A   <- pdrb_class %>% filter(bucket == "A: RAS") %>% pull(upd)
thr_upd <- mean(upd_A) + 3 * sd(upd_A)

pdrb_class <- pdrb_class %>%
  mutate(
    bucket = case_when(
      bucket == "A: RAS" & upd > thr_upd ~ "B: share-based",
      TRUE                               ~ bucket
    )
  )

cat("=== Bucket classification (upd threshold:", round(thr_upd, 2), ") ===\n")
print(pdrb_class %>% count(bucket))

###------------------------------------------------------###
### Share-based imputation (bucket B)                    ###
### X/U/V imputed from IO national values, distributed   ###
### proportionally to provincial PDRB 2024 shares.       ###
### Structure (A-matrix seed) from national average.     ###
###------------------------------------------------------###

# <- IO national lookup
io_lookup <- io_x %>% rename(sec52 = kode, x_io = totaloutput_2024) %>%
  left_join(io_u %>% rename(sec52 = kode, u_io = interm_output_2024), by = "sec52") %>%
  left_join(io_v %>% rename(sec52 = kode, v_io = interm_input_2024),  by = "sec52")

# <- Impute X, U, V for bucket B: share = target_prov / sum(target_prov) per sec52
imputed_b <- pdrb_class %>%
  filter(bucket == "B: share-based") %>%
  group_by(sec52) %>%
  mutate(share = target / sum(target)) %>%
  ungroup() %>%
  left_join(io_lookup, by = "sec52") %>%
  mutate(
    x_imputed = x_io * share,
    u_imputed = u_io * share,
    v_imputed = v_io * share
  ) %>%
  select(kode, x_imputed, u_imputed, v_imputed)

###------------------------------------------------------###
### Prep IRIO data                                       ###
###------------------------------------------------------###

irio <- irio_raw
rn   <- irio_raw$kode
rownames(irio) <- rn
irio <- irio %>% dplyr::select(-kode)

# <- Sector codes (1768 active sectors)
sec_codes <- rn[1:1768]

# <- Z matrix (satuan rupiah)
zmatr <- irio[1:1768, 1:1768] %>% as.matrix() %>% apply(., 2, as.numeric)
zmatr <- zmatr * 1e6
rownames(zmatr) <- sec_codes
colnames(zmatr) <- sec_codes

# <- Total Output dan Input (X), satuan rupiah
totaloutput <- as.numeric(unlist(irio[1:1768, 1780])) * 1e6
totalinput  <- as.numeric(unlist(irio[1777, 1:1768])) * 1e6
names(totaloutput) <- sec_codes
names(totalinput)  <- sec_codes

# <- Total Intermediate Output (U) dan Intermediate Input (V)
intout_ver <- rowSums(zmatr)   # U: intermediate output per baris
intinp_hor <- colSums(zmatr)   # V: intermediate input per kolom

# <- Technology Matrix (A Matrix): a_kl = z_kl / x_l
#   pmax(totaloutput, 1) guards against division by zero for inactive sectors
amatr <- sweep(zmatr, 2, pmax(totaloutput, 1), "/")
rownames(amatr) <- sec_codes
colnames(amatr) <- sec_codes

###------------------------------------------------------###
### RAS Update                                           ###
###------------------------------------------------------###

# <- Update vector
update1624 <- pdrb_adj$upd

# <- U target (Intermediate Output 2024)
intout_ver_up <- intout_ver * update1624
names(intout_ver_up) <- sec_codes

# <- V target (Intermediate Input 2024) — rescaled agar total U = total V
intinp_hor_up <- intinp_hor * update1624
intinp_hor_up <- (intinp_hor_up / sum(intinp_hor_up)) * sum(intout_ver_up)
names(intinp_hor_up) <- sec_codes

# <- X target (Total Output 2024)
totaloutput_up <- totaloutput * update1624
names(totaloutput_up) <- sec_codes

# <- Override bucket B: replace with IO-share imputed values
for (i in seq_len(nrow(imputed_b))) {
  kd <- imputed_b$kode[i]
  totaloutput_up[kd] <- imputed_b$x_imputed[i]
  intout_ver_up[kd]  <- imputed_b$u_imputed[i]
  intinp_hor_up[kd]  <- imputed_b$v_imputed[i]
}

# <- Override bucket C & D: zero-out
kode_cd <- pdrb_class %>% filter(bucket %in% c("C: zero-out", "D: skip")) %>% pull(kode)
totaloutput_up[kode_cd] <- 0
intout_ver_up[kode_cd]  <- 0
intinp_hor_up[kode_cd]  <- 0

# <- Re-rescale V after overrides to ensure sum(U) = sum(V)
intinp_hor_up <- (intinp_hor_up / sum(intinp_hor_up)) * sum(intout_ver_up)

# <- RAS setup
x1 <- as.matrix(totaloutput_up)
u1 <- as.matrix(intout_ver_up)
v1 <- as.matrix(intinp_hor_up)
A  <- amatr

# <- idx_pos: sectors where RAS is mathematically defined
#   include sectors with either u1>0 or v1>0 to avoid excluding
#   sectors that only consume (u1=0) or only produce (v1=0)
idx_pos <- which(x1 > 0 & (u1 > 0 | v1 > 0))

cat("\n=== Sectors entering RAS:", length(idx_pos), "of", length(sec_codes), "===\n")

A_seed <- A

# <- Seed for new sectors: structurally empty in base year but active in 2024
#   uses 10% of national average structure as starting point
new_sectors <- which(x1 > 0 & colSums(A) == 0)
if (length(new_sectors) > 0) {
  ref_structure <- rowMeans(A[, idx_pos, drop = FALSE])
  for (j in new_sectors) {
    A_seed[, j] <- 0.1 * ref_structure
    A_seed[j, ] <- 0.1 * ref_structure
  }
}

A_sub <- A_seed[idx_pos, idx_pos, drop = FALSE]
x_sub <- x1[idx_pos, , drop = FALSE]
u_sub <- u1[idx_pos, , drop = FALSE]
v_sub <- v1[idx_pos, , drop = FALSE]

maxiter <- 10000
tol     <- 1e-6

for (iter in 1:maxiter) {
  
  # Row scaling (match U target)
  u_hat <- A_sub %*% x_sub
  u_hat[u_hat == 0] <- 1
  r     <- as.vector(u_sub / u_hat)
  A1    <- A_sub * r
  
  # Column scaling (match V target)
  v_hat <- colSums(sweep(A1, 2, as.vector(x_sub), "*"))
  v_hat[v_hat == 0] <- 1
  s     <- as.vector(v_sub / v_hat)
  A_new <- sweep(A1, 2, s, "*")
  
  # Convergence check: only over sectors with positive targets
  #   excludes u1=0 sectors from row check to prevent non-convergence
  idx_u_pos <- which(u_sub > 0)
  idx_v_pos <- which(v_sub > 0)
  row_err <- if (length(idx_u_pos) > 0) max(abs(r[idx_u_pos] - 1)) else 0
  col_err <- if (length(idx_v_pos) > 0) max(abs(s[idx_v_pos] - 1)) else 0
  
  if (row_err < tol && col_err < tol) break
  A_sub <- A_new
}

cat("RAS converged at iteration:", iter, "\n")
cat("row_err:", row_err, "| col_err:", col_err, "\n")

# <- Full 1768x1768 A matrix 2024
A_IRIO_2024 <- matrix(0, nrow = nrow(A), ncol = ncol(A),
                      dimnames = list(sec_codes, sec_codes))
A_IRIO_2024[idx_pos, idx_pos] <- A_sub

# <- Z matrix 2024 dari A * diag(X)
Z_IRIO_2024 <- sweep(A_IRIO_2024, 2, as.vector(totaloutput_up), "*")

# <- Intermediate output (U) dan input (V) final dari Z
intout_ver_up_final <- rowSums(Z_IRIO_2024)   # U final
intinp_hor_up_final <- colSums(Z_IRIO_2024)   # V final

###------------------------------------------------------###
### Evaluation                                           ###
### (1) Internal IRIO consistency: max absolute residual ###
###     between A*x and targets u1, v1.                  ###
###     Relative to total X for economic interpretation. ###
### (2) Aggregate consistency vs IO national: gap        ###
###     between IRIO provincial sums and IO 2024 values  ###
###     per subsector. Residual gap reflects base-year   ###
###     structural differences (IRIO 2016 vs IO 2020),   ###
###     not updating error.                              ###
###------------------------------------------------------###

# <- (1) Internal consistency
evaluate <- data.frame(
  row_consistency    = max(abs(A_IRIO_2024 %*% x1 - u1)),
  column_consistency = max(abs(
    colSums(A_IRIO_2024 * matrix(x1, nrow = nrow(A_IRIO_2024),
                                 ncol = ncol(A_IRIO_2024), byrow = TRUE)) - v1
  )),
  total_X            = sum(totaloutput_up),
  row_consistency_rel = max(abs(A_IRIO_2024 %*% x1 - u1)) / sum(totaloutput_up),
  col_consistency_rel = max(abs(
    colSums(A_IRIO_2024 * matrix(x1, nrow = nrow(A_IRIO_2024),
                                 ncol = ncol(A_IRIO_2024), byrow = TRUE)) - v1
  )) / sum(totaloutput_up)
)

# <- (2) Aggregate consistency vs IO national (per subsector)
irio_agg <- data.frame(kode = sec_codes, x_irio = totaloutput_up,
                       u_irio = intout_ver_up_final, v_irio = intinp_hor_up_final) %>%
  mutate(sec52 = sub("^[0-9]+-", "", kode)) %>%
  group_by(sec52) %>%
  summarise(across(c(x_irio, u_irio, v_irio), sum), .groups = "drop")

io_vs_irio <- io_x %>% rename(sec52 = kode, x_io = totaloutput_2024) %>%
  left_join(io_u %>% rename(sec52 = kode, u_io = interm_output_2024), by = "sec52") %>%
  left_join(io_v %>% rename(sec52 = kode, v_io = interm_input_2024),  by = "sec52") %>%
  left_join(irio_agg, by = "sec52") %>%
  mutate(
    gap_x_abs = x_irio - x_io,   gap_x_pct = gap_x_abs / x_io * 100,
    gap_u_abs = u_irio - u_io,   gap_u_pct = gap_u_abs / u_io * 100,
    gap_v_abs = v_irio - v_io,   gap_v_pct = gap_v_abs / v_io * 100
  )

cat("\n=== (1) Internal consistency ===\n")
print(evaluate)

cat("\n=== (2) IO vs IRIO aggregate gap (top 10 by |gap_x_pct|) ===\n")
print(io_vs_irio %>% arrange(desc(abs(gap_x_pct))) %>%
        select(sec52, x_io, x_irio, gap_x_pct, gap_u_pct, gap_v_pct) %>% head(10))

cat("\nTotal X IO  :", sum(io_vs_irio$x_io), "\n")
cat("Total X IRIO:", sum(io_vs_irio$x_irio, na.rm = TRUE), "\n")
cat("Overall gap :", round((sum(io_vs_irio$x_irio) / sum(io_vs_irio$x_io) - 1) * 100, 2), "%\n")

###------------------------------------------------------###
### EXPORT: standardized format                          ###
### Setiap sheet memiliki kolom "kode" sebagai identifier###
###------------------------------------------------------###

# Helper: matrix -> data.frame dengan kolom kode
mat_to_df <- function(mat, kode_vec) {
  df <- as.data.frame(mat)
  cbind(kode = kode_vec, df)
}

# Helper: named vector -> data.frame dengan kolom kode
vec_to_df <- function(vec, col_name) {
  data.frame(kode = names(vec), value = as.numeric(vec)) %>%
    rename(!!col_name := value)
}

matlist <- list(
  # A matrix 2024: kolom kode + 1768 kolom sektor
  "a_irio_2024"        = mat_to_df(A_IRIO_2024, sec_codes),
  
  # Z matrix 2024: kolom kode + 1768 kolom sektor
  "z_irio_2024"        = mat_to_df(Z_IRIO_2024, sec_codes),
  
  # A matrix 2016 (base): kolom kode + 1768 kolom sektor
  "a_irio_2016"        = mat_to_df(amatr, sec_codes),
  
  # Intermediate output (U): kode + nilai
  "interm_output_2024" = vec_to_df(intout_ver_up_final, "interm_output_2024"),
  
  # Intermediate input (V): kode + nilai
  "interm_input_2024"  = vec_to_df(intinp_hor_up_final, "interm_input_2024"),
  
  # Total output (X): kode + nilai
  "totaloutput_2024"   = vec_to_df(totaloutput_up, "totaloutput_2024"),
  
  # Bucket classification: treatment per sektor-provinsi
  "bucket_info"        = pdrb_class %>% select(kode, sec52, base, target, upd, bucket),
  
  # Evaluation: internal consistency + IO vs IRIO aggregate gap
  "eval_internal"      = evaluate,
  "eval_io_vs_irio"    = io_vs_irio
)

openxlsx::write.xlsx(matlist, "01 Data/IO-IRIO-NA/output/updating_2024/v3_irio_2024(1768x1768).xlsx")