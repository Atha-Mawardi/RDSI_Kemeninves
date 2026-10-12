###------------------------------------------------------###
### 03. IRIO updating                                    ###
### performing RAS to update the technical coefficients. ###
###------------------------------------------------------###

#-> Import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> Import data
pdrb     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx", sheet = "main_dat")
irio_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/irio16.csv", header = TRUE)

#-> Data prep
pdrb     <- pdrb %>% filter(!is.na(kodeIO)) %>% select(kode, upd)
pdrb_adj <- irio_raw %>% select(kode) %>% inner_join(pdrb, by = "kode")

irio <- irio_raw
rn   <- irio_raw$kode
rownames(irio) <- rn
irio <- irio %>% dplyr::select(-kode)

### <------- IRIO update
### Prep IRIO data

# <- Sektor codes (1768 active sectors)
sec_codes <- rn[1:1768]

# <- Z matrix (satuan rupiah)
zmatr <- irio[1:1768, 1:1768] %>% as.matrix() %>% apply(., 2, as.numeric)
zmatr <- (zmatr * 1e6) + 1 / 1768
rownames(zmatr) <- sec_codes
colnames(zmatr) <- sec_codes

# <- Total Output and Total Input (X), satuan rupiah
totaloutput <- (as.numeric(unlist(irio[1:1768, 1780])) * 1e6) + 1
totalinput  <- (as.numeric(unlist(irio[1777, 1:1768])) * 1e6) + 1
names(totaloutput) <- sec_codes
names(totalinput)  <- sec_codes

# <- Total Intermediate Input (U) dan Intermediate Output (V)
intinp_hor <- colSums(zmatr)   # V: intermediate input per kolom
intout_ver <- rowSums(zmatr)   # U: intermediate output per baris

# <- Technology Matrix (A Matrix): a_kl = z_kl / x_l
amatr <- sweep(zmatr, 2, totaloutput, "/")
rownames(amatr) <- sec_codes
colnames(amatr) <- sec_codes

# <- Update vector
update1624 <- pdrb_adj$upd

### RAS Update

# <- U target (Intermediate Output 2024)
intout_ver_up     <- intout_ver * update1624
tot_intout_ver_up <- sum(intout_ver_up)

# <- V target (Intermediate Input 2024) — rescaled agar total U = total V
intinp_hor_up <- intinp_hor * update1624
intinp_hor_up <- (intinp_hor_up / sum(intinp_hor_up)) * tot_intout_ver_up

# <- X target (Total Output 2024)
totaloutput_up <- totaloutput * update1624
names(totaloutput_up) <- sec_codes

# <- RAS setup
x1 <- as.matrix(totaloutput_up)
u1 <- as.matrix(intout_ver_up)
v1 <- as.matrix(intinp_hor_up)
A  <- amatr

# <- Sectors where RAS is mathematically defined
idx_pos <- which(x1 > 0 & u1 > 0 & v1 > 0)

A_seed <- A

# <- Sectors active in 2024 but structurally empty in base year
new_sectors <- which(x1 > 0 & colSums(A) == 0)

if (length(new_sectors) > 0) {
  ref_structure <- colMeans(A[, idx_pos, drop = FALSE])
  for (j in new_sectors) {
    A_seed[, j] <- 0.01 * ref_structure
    A_seed[j, ] <- 0.01 * ref_structure
  }
}

A_sub <- A_seed[idx_pos, idx_pos, drop = FALSE]
x_sub <- x1[idx_pos, , drop = FALSE]
u_sub <- u1[idx_pos, , drop = FALSE]
v_sub <- v1[idx_pos, , drop = FALSE]

maxiter <- 1000
tol     <- 1e-20

for (iter in 1:maxiter) {
  
  # Row scaling (match u)
  u_hat <- A_sub %*% x_sub
  u_hat[u_hat == 0] <- 1
  r  <- as.vector(u_sub / u_hat)
  A1 <- A_sub * r          # row scaling: r[i] * A_sub[i,j] per baris
  
  # Column scaling (match v)
  v_hat <- colSums(sweep(A1, 2, as.vector(x_sub), "*"))
  v_hat[v_hat == 0] <- 1
  s     <- as.vector(v_sub / v_hat)
  A_new <- sweep(A1, 2, s, "*")  # col scaling: s[j] * A1[i,j] per kolom
  
  # Convergence check
  row_err <- max(abs(r - 1))
  col_err <- max(abs(s - 1))
  
  if (row_err < tol && col_err < tol) break
  A_sub <- A_new
}

# Full A matrix 2024 dengan dimnames
A_IRIO_2024 <- matrix(0, nrow = nrow(A), ncol = ncol(A),
                      dimnames = list(sec_codes, sec_codes))
A_IRIO_2024[idx_pos, idx_pos] <- A_sub

# Z matrix 2024 dari A * diag(X)
Z_IRIO_2024 <- sweep(A_IRIO_2024, 2, as.vector(totaloutput_up), "*")

# Intermediate input/output 2024 dari Z (bukan dari target)
intout_ver_up_final <- rowSums(Z_IRIO_2024)   # U final
intinp_hor_up_final <- colSums(Z_IRIO_2024)   # V final

# Evaluation
evaluate <- data.frame(
  row_consistency    = max(abs(A_IRIO_2024 %*% x1 - u1)),
  column_consistency = max(abs(
    colSums(A_IRIO_2024 * matrix(x1, nrow = nrow(A_IRIO_2024),
                                 ncol = ncol(A_IRIO_2024), byrow = TRUE)) - v1
  ))
)

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
  
  # Evaluation
  "eval"               = evaluate
)

openxlsx::write.xlsx(matlist, "01 Data/IO-IRIO-NA/output/updating_2024/v1_irio_2024(1768x1768).xlsx")