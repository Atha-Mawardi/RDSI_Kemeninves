
###---------------------------------------------------------<
### 03. IRIO updating                                    
### performing RAS to update the technical coefficients. 
### Different from IO, this requires careful up and      
### downscaling procedure within the province's sector.  
### short description as follows:                        
### 1) agregating 2016 IRIO 52 -> 17. calculate          
###    intermediate output, intermediate input, and      
###    total output w.r.t the 17 sectors' growth. 
###    The rationale is to perceive the subsectors'
###    structures with their respective sectoral 
###    categories.
### 2) disaggregating each of the u,v, and x on 17 
###    sectors with target year's subsectoral proportion 
###    (GDP).
### 3) Estimate the updated 52 IRIO matrix with the 
###    obtained u,v,and x.
### Full explanation: Technical notes.Rmd                
###---------------------------------------------------------<


#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data
pdrb     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx", sheet = "main_dat")
irio_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/irio16.csv", header = TRUE)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "sec17-52")

#-> agregasi PDRB 52 -> 17
pdrb <- pdrb %>%
  left_join(concord52_185 %>% select(sec52, sec17), by = c("kodeIO" = "sec52"))

pdrb_17 <- pdrb %>%
  group_by(kode_prov, sec17) %>%
  summarise(base_17 = sum(base, na.rm=TRUE), target_17 = sum(target, na.rm=TRUE), .groups="drop") %>%
  mutate(upd_17 = target_17 / base_17)  # growth multiplier; Inf jika base=0

pdrb <- pdrb %>%
  left_join(pdrb_17, by = c("kode_prov", "sec17")) %>%
  mutate(prop_target = ifelse(target_17 > 0, target / target_17, 0))

#-> Ekstrak Z, X, U, V dari IRIO
sec_codes <- irio_raw$kode[1:1768]


Z <- irio_raw[1:1768, 2:1769] %>% as.matrix() %>% apply(., 2, as.numeric) * 1e6
rownames(Z) <- sec_codes
colnames(Z) <- sec_codes

X <- setNames(as.numeric(irio_raw[1:1768, 1780]) * 1e6, sec_codes)
U <- setNames(rowSums(Z), sec_codes)
V <- setNames(colSums(Z), sec_codes)

# Tabel bantu: kode -> kode_prov + sec17
meta <- data.frame(kode = sec_codes) %>%
  mutate(kode_prov = as.integer(sub("^([0-9]+)-.*", "\\1", kode)),
         kodeIO    = sub("^[0-9]+-", "", kode)) %>%
  left_join(concord52_185 %>% select(sec52, sec17), by = c("kodeIO" = "sec52"))

#-> Ekstrak Z, X, U, V ke 17 sektor per provinsi

agg <- meta %>%
  mutate(X = X[kode], U = U[kode], V = V[kode]) %>%
  group_by(kode_prov, sec17) %>%
  summarise(X_17 = sum(X), U_17 = sum(U), V_17 = sum(V), .groups = "drop")

#-> Update X, U, V dengan growth rate 17 sektor

agg <- agg %>%
  left_join(pdrb_17, by = c("kode_prov", "sec17")) %>%
  mutate(
    X_17_upd = ifelse(is.finite(upd_17), X_17 * upd_17, 0),
    U_17_upd = ifelse(is.finite(upd_17), U_17 * upd_17, 0),
    V_17_upd = ifelse(is.finite(upd_17), V_17 * upd_17, 0))

#-> Disagregasi 17 -> 52 menggunakan prop_target
target_52 <- pdrb %>%
  select(kode, kode_prov, sec17, prop_target) %>%
  left_join(agg %>% select(kode_prov, sec17, X_17_upd, U_17_upd, V_17_upd),
            by = c("kode_prov", "sec17")) %>%
  mutate(
    X_upd = prop_target * X_17_upd,
    U_upd = prop_target * U_17_upd,
    V_upd = prop_target * V_17_upd
  )

#-> Selaraskan urutan + rekonsiliasi sum(U) = sum(V)

# Urutan harus identik dengan sec_codes untuk RAS
target_52 <- data.frame(kode = sec_codes) %>%
  left_join(target_52 %>% select(kode, X_upd, U_upd, V_upd), by = "kode")

# Rescale V agar sum(V) = sum(U)
target_52 <- target_52 %>%
  mutate(V_upd = V_upd * (sum(U_upd, na.rm=TRUE) / sum(V_upd, na.rm=TRUE)))

cat("sum(U):", sum(target_52$U_upd, na.rm=TRUE), "\n")
cat("sum(V):", sum(target_52$V_upd, na.rm=TRUE), "\n")
cat("NA pada X_upd:", sum(is.na(target_52$X_upd)), "\n")
cat("Zero pada X_upd:", sum(target_52$X_upd == 0, na.rm=TRUE), "\n")

###---------------------------------------------------------
### A matrix seed untuk sektor dengan totalinput 2016 = 0  
### tapi punya target X_upd > 0 di 2024.                   
###                                                         
### Masalah: RAS mengalikan A matrix dengan skalar iteratif.
### Jika kolom DAN baris A suatu sektor seluruhnya nol,     
### tidak ada struktur yang bisa diskala — RAS tidak bisa   
### "menumbuhkan" nilai dari kekosongan.                    
###                                                         
### Solusi: isi kolom dan baris A dengan rata-rata struktur 
### provinsi lain di pulau yang sama untuk kodeIO yang sama.
### Pulau digunakan karena struktur produksi lebih homogen  
### secara geografis dibanding rata-rata nasional.          
### Jika tidak ada donor di pulau, fallback ke nasional.    
###                                                         
### Mapping pulau: kode_prov < 30 = Sumatera, < 40 = Jawa, 
### < 60 = Bali-Nusra, < 70 = Kalimantan, < 80 = Sulawesi, 
### < 90 = Maluku, >= 90 = Papua.                           
###---------------------------------------------------------

# Total input 2016 per sektor dari baris 2100
totalinput_2016 <- setNames(
  as.numeric(irio_raw[which(irio_raw$kode == "2100"), 2:1769]),
  sec_codes
)

# A matrix 2016
A_2016 <- sweep(Z, 2, pmax(X, 1), "/")

# Mapping pulau
get_pulau <- function(kode_prov) case_when(
  kode_prov < 30 ~ "Sumatera",
  kode_prov < 40 ~ "Jawa",
  kode_prov < 60 ~ "Bali-Nusra",
  kode_prov < 70 ~ "Kalimantan",
  kode_prov < 80 ~ "Sulawesi",
  kode_prov < 90 ~ "Maluku",
  TRUE           ~ "Papua"
)

meta <- meta %>% mutate(pulau = get_pulau(kode_prov))

# Identifikasi sektor yang perlu seed
needs_seed <- meta %>%
  filter(totalinput_2016[kode] == 0) %>%
  filter(kode %in% (target_52 %>% filter(X_upd > 0) %>% pull(kode))) %>%
  select(kode, kode_prov, kodeIO, pulau)

# Isi seed per sektor
A_seed <- A_2016

for (i in seq_len(nrow(needs_seed))) {
  kd <- needs_seed$kode[i]
  io <- needs_seed$kodeIO[i]
  pl <- needs_seed$pulau[i]
  
  # Donor: pulau sama, kodeIO sama, totalinput > 0
  donors <- meta %>%
    filter(kodeIO == io, pulau == pl, totalinput_2016[kode] > 0) %>%
    pull(kode)
  
  # Fallback nasional jika tidak ada donor di pulau
  if (length(donors) == 0)
    donors <- meta %>%
    filter(kodeIO == io, totalinput_2016[kode] > 0) %>%
    pull(kode)
  
  if (length(donors) == 0) next
  
  A_seed[, kd] <- rowMeans(A_2016[, donors, drop = FALSE])
  A_seed[kd, ] <- colMeans(A_2016[donors, , drop = FALSE])
}

###---------------------------------------------------------
### RAS updating IRIO 2016 -> 2024                         
### Seed A matrix sudah mencakup sektor baru (totalinput=0  
### tapi X_upd>0). idx_pos mengecualikan sektor dengan      
### X_upd=0 dari iterasi untuk menghindari divisi nol.      
### Evaluasi: internal consistency (row & col residual).    
###---------------------------------------------------------

# Vektor target dari target_52 (urutan identik dengan sec_codes)
x1 <- setNames(target_52$X_upd, sec_codes)
u1 <- setNames(target_52$U_upd, sec_codes)
v1 <- setNames(target_52$V_upd, sec_codes)

# idx_pos: hanya sektor dengan target positif
idx_pos <- which(x1 > 0 & u1 > 0 & v1 > 0)

A_sub <- A_seed[idx_pos, idx_pos]
x_sub <- x1[idx_pos]
u_sub <- u1[idx_pos]
v_sub <- v1[idx_pos]

# RAS iterasi
maxiter <- 10000
tol     <- 1e-10

for (iter in 1:maxiter) {
  u_hat <- as.vector(A_sub %*% x_sub); u_hat[u_hat == 0] <- 1
  r     <- u_sub / u_hat
  A_sub <- A_sub * r
  
  v_hat <- colSums(A_sub * x_sub); v_hat[v_hat == 0] <- 1
  s     <- v_sub / v_hat
  A_sub <- sweep(A_sub, 2, s, "*")
  
  row_err <- max(abs(r[u_sub > 0] - 1))
  col_err <- max(abs(s[v_sub > 0] - 1))
  if (row_err < tol && col_err < tol) break
}

cat("Converged at iter:", iter, "| row_err:", row_err, "| col_err:", col_err, "\n")

# Rekonstruksi A dan Z full 1768x1768
A_2024 <- matrix(0, 1768, 1768, dimnames = list(sec_codes, sec_codes))
A_2024[idx_pos, idx_pos] <- A_sub

Z_2024 <- sweep(A_2024, 2, x1, "*")
u_final <- rowSums(Z_2024)
v_final <- colSums(Z_2024)

# Evaluasi internal consistency
eval_res <- data.frame(
  row_consistency = max(abs(A_2024 %*% x1 - u1)),
  col_consistency = max(abs(colSums(A_2024 * x1) - v1)),
  total_X         = sum(x1)
)
print(eval_res)

###---------------------------------------------------------
### Export                                                  
###---------------------------------------------------------

mat_to_df <- function(mat) cbind(kode = rownames(mat), as.data.frame(mat))
vec_to_df <- function(vec, col) data.frame(kode = names(vec), setNames(list(vec), col))

matlist <- list(
  a_irio_2024        = mat_to_df(A_2024),
  z_irio_2024        = mat_to_df(Z_2024),
  a_irio_2016        = mat_to_df(A_2016),
  interm_output_2024 = vec_to_df(u_final, "interm_output_2024"),
  interm_input_2024  = vec_to_df(v_final, "interm_input_2024"),
  totaloutput_2024   = vec_to_df(x1,      "totaloutput_2024"),
  eval               = eval_res
)

openxlsx::write.xlsx(matlist, "01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx")








