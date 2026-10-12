
###------------------------------------------------------###
### 01. IO updating                                      ###
### performing RAS to update the technical coefficients  ###
### using two-stage approach. This script only           ###
### covers for the first stage. Full explanation can be  ###
### accessed through "Technical notes.Rmd"               ###
###------------------------------------------------------###

#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data
pdrb <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx",sheet = "nat_gr")
io185_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io20.csv",header = T)
io52.16_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io16(52).csv",header = T)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx",sheet = "Full_Concordance")
concord17_52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx",sheet = "sec17-52")

#-> data prep: aggregating io 185 products into 52 subsectors. 
#   in 2020, IO table only available for 17 sectors & 185 products.

# 1. Separate total rows (code 2100, 3100) from the sector row
sector_rows <- io185_raw %>% filter(Kode %in% concord52_185$prod185)
total_rows  <- io185_raw %>% filter(!Kode %in% concord52_185$prod185) %>%
  mutate(Kode = as.character(Kode))

# 2. Attach mapping ke baris sektor
sector_rows <- sector_rows %>% left_join(concord52_185 %>% dplyr::select(prod185, sec52), by = c("Kode" = "prod185"))

# 3. Identifikasi kolom: kolom sektor vs kolom total
sector_cols <- as.character(concord52_185$prod185)   # "1","2",...,"185"
total_cols  <- setdiff(names(io185_raw), c("Kode", sector_cols))  # misal "2100","3100"

# 4. Agregasi BARIS: sum by sec52
agg_rows <- sector_rows %>%
  group_by(sec52) %>%
  summarise(across(all_of(c(sector_cols, total_cols)), sum), .groups = "drop")

# 5. Agregasi KOLOM sektor: rename tiap kolom sektor ke sec52-nya, lalu sum
col_map <- setNames(concord52_185$sec52, as.character(concord52_185$prod185))

agg_matrix <- agg_rows %>%
  pivot_longer(cols = all_of(sector_cols), names_to = "old_col", values_to = "val") %>%
  mutate(new_col = col_map[old_col]) %>%
  group_by(sec52, new_col) %>%
  summarise(val = sum(val), .groups = "drop") %>%
  pivot_wider(names_from = new_col, values_from = val, values_fill = 0)

# 6. Reattach kolom total (tidak diagregasi)
io_52 <- agg_matrix %>%
  left_join(agg_rows %>% select(sec52, all_of(total_cols)), by = "sec52")

# 7. Handle baris total: agregasi kolom sektor saja, pertahankan kolom total
total_agg <- total_rows %>%
  pivot_longer(cols = all_of(sector_cols), names_to = "old_col", values_to = "val") %>%
  mutate(new_col = col_map[old_col]) %>%
  group_by(Kode, new_col) %>%
  summarise(val = sum(val), .groups = "drop") %>%
  pivot_wider(names_from = new_col, values_from = val, values_fill = 0) %>%
  left_join(total_rows %>% select(Kode, all_of(total_cols)), by = "Kode") %>%
  rename(sec52 = Kode)

# 8. Bind: sektor 52 + baris total
io_final <- bind_rows(io_52, total_agg) %>% rename(kode = sec52)

# 9. Estimate the value of I-46 using the fraction of subsectors 
# within Jasa Keuangan dan Asuransi sector's intermediate trade in IO 2016 data

# 9.1 prepare matrices
io16_mat <- io52.16_raw %>% column_to_rownames("kode") %>% select(-sec17) %>% as.matrix()
io20_mat <- io_final %>% column_to_rownames("kode") %>% as.matrix()
common_cols <- intersect(colnames(io16_mat), colnames(io20_mat))
common_rows <- intersect(rownames(io16_mat), rownames(io20_mat))

# 9.2 compute I-46 proportions from IO 2016
prop_row <- ifelse(
  rowSums(t(io16_mat[c("I-43","I-44","I-45","I-46"), common_cols])) == 0, 0,
  io16_mat["I-46", common_cols] /
    (io16_mat["I-43", common_cols] + io16_mat["I-44", common_cols] +
       io16_mat["I-45", common_cols] + io16_mat["I-46", common_cols]))

prop_col <- ifelse(
  rowSums(io16_mat[common_rows, c("I-43","I-44","I-45","I-46")]) == 0, 0,
  io16_mat[common_rows, "I-46"] /
    (io16_mat[common_rows, "I-43"] + io16_mat[common_rows, "I-44"] +
       io16_mat[common_rows, "I-45"] + io16_mat[common_rows, "I-46"]))

# 9.3 derive I-46 values in IO 2020
val_i46_row <- prop_row * (io20_mat["I-43", common_cols] + io20_mat["I-44", common_cols] + io20_mat["I-45", common_cols])
val_i46_col <- prop_col * (io20_mat[common_rows, "I-43"] + io20_mat[common_rows, "I-44"] + io20_mat[common_rows, "I-45"])

# 9.4 reduce I-43/44/45 pro-rata, deltas computed from original matrix
io20_new <- io20_mat

for (j in common_cols) {
  tot <- io20_mat["I-43", j] + io20_mat["I-44", j] + io20_mat["I-45", j]
  if (tot == 0) next
  io20_new[c("I-43","I-44","I-45"), j] <- io20_mat[c("I-43","I-44","I-45"), j] -
    (io20_mat[c("I-43","I-44","I-45"), j] / tot) * val_i46_row[j]
}

delta_col <- sapply(common_rows, function(i) {
  tot <- io20_mat[i, "I-43"] + io20_mat[i, "I-44"] + io20_mat[i, "I-45"]
  if (tot == 0) return(c(0, 0, 0))
  (io20_mat[i, c("I-43","I-44","I-45")] / tot) * val_i46_col[i]
}) %>% t()

io20_new[common_rows, c("I-43","I-44","I-45")] <-
  io20_new[common_rows, c("I-43","I-44","I-45")] - delta_col

# 9.5 insert I-46 row and column after I-45
pos_r <- which(rownames(io20_new) == "I-45")
pos_c <- which(colnames(io20_new) == "I-45")

row_i46 <- matrix(0, 1, ncol(io20_new), dimnames = list("I-46", colnames(io20_new)))
row_i46[1, common_cols] <- val_i46_row
io20_new <- rbind(io20_new[1:pos_r, , drop = FALSE], row_i46,io20_new[(pos_r + 1):nrow(io20_new), , drop = FALSE])

col_i46 <- matrix(0, nrow(io20_new), 1, dimnames = list(rownames(io20_new), "I-46"))
col_i46[common_rows, 1] <- val_i46_col
io20_new <- cbind(io20_new[, 1:pos_c, drop = FALSE], col_i46,io20_new[, (pos_c + 1):ncol(io20_new), drop = FALSE])

# 9.6 back to tibble
io_final_53 <- io20_new %>% as.data.frame() %>% rownames_to_column("kode") %>% as_tibble()

# 9.7 verify totals are preserved
excl <- setdiff(common_cols, c("I-43","I-44","I-45"))
cat("colSums diff :", max(abs(
  colSums(io_final_53 %>% filter(kode %in% c("I-43","I-44","I-45","I-46")) %>% select(all_of(excl))) -
    colSums(io_final   %>% filter(kode %in% c("I-43","I-44","I-45"))         %>% select(all_of(excl)))
)), "\n")
cat("total output :", sum(io20_mat[rownames(io20_mat) != "2100", "3100"], na.rm = TRUE),
    "->", sum(io_final_53 %>% filter(kode != "2100") %>% pull(`3100`), na.rm = TRUE), "\n")
cat("total input  :", sum(io20_mat["2100", colnames(io20_mat) != "3100"], na.rm = TRUE),
    "->", sum(io_final_53 %>% filter(kode == "2100") %>% select(-kode, -`3100`), na.rm = TRUE), "\n")



head(io_final_53[, 51:54], 5) 
tail(io_final_53[, 1:3], 3)

rio::export(io_final_53,"01 Data/IO-IRIO-NA/output/updating_2024/v1_io20(52x52).csv")
rio::export(io_final,"01 Data/IO-IRIO-NA/output/updating_2024/v1_io20(51x51).csv")

# 10. check intermediate input and output consistency
# Z matrix: baris 1:52, kolom 2:53
z_matrix <- io_final_53[1:52, 2:53]

int_consistency <- data.frame(total_intermediate_output = sum(rowSums(z_matrix)),
                              total_intermediate_input = sum(colSums(z_matrix)))

#-> data prep: attach growth target
pdrb <- pdrb %>% select(., c(kode,upd))
pdrb_adj <- io_final_53 %>% select(., c(kode)) %>% inner_join(.,pdrb,by=c("kode"))

io52 <- io_final_53
rn <- io52$kode
rownames(io52) <- rn
io52 <- io52 %>% dplyr::select(., -c(kode))


### <------- IO 52 update
### Prep IO data
# <- Z matrix
zmatr <- io52[,c(1:52)][c(1:52),]
zmatr <- as.matrix(sapply(zmatr, as.numeric))
zmatr <- zmatr * 1e6

# <- Total Output and Total Input (X)
totaloutput <- as.numeric(unlist(io52[c(1:52), 53])) * 1e6
totalinput <- as.numeric(unlist(io52[53, c(1:52)])) * 1e6

# <- Total Intermediate Input (U) and Intermediate Output (V)
intinp_hor <- colSums(zmatr)
intout_ver <- rowSums(zmatr)

# <- Technology Matrix (A Matrix) z_i/U
amatr <- sweep(zmatr, 2, totaloutput, "/")

# <- Update vector
update1624 <- pdrb_adj$upd

### RAS Update
# <- U = Total Intermediate Output
intout_ver_up <- intout_ver*update1624
tot_intout_ver_up <- sum(intout_ver_up)

# <- V = Total Intermediate Input
intinp_hor_up <- intinp_hor*update1624
tot_intinp_hor_up <- sum(intinp_hor_up)

intinp_hor_up2 <- intinp_hor_up/tot_intinp_hor_up
intinp_hor_up <- intinp_hor_up2*tot_intout_ver_up

# <- X = Total Output
totaloutput_up <- totaloutput*update1624

# <- RAS Update func
x1 <- as.matrix(totaloutput_up)
u1 <- as.matrix(intout_ver_up)
v1 <- as.matrix(intinp_hor_up)
A <- amatr

# <- sectors where RAS is mathematically defined
idx_pos <- which(x1 > 0 & u1 > 0 & v1 > 0)

A_seed <- A

# <- sectors active in 2024 but structurally empty in base year
new_sectors <- which(x1 > 0 & colSums(A) == 0)

if (length(new_sectors) > 0) {
  ref_structure <- colMeans(A[, idx_pos, drop = FALSE])
  
  for (j in new_sectors) {
    A_seed[, j] <- 0.01 * ref_structure
    A_seed[j, ] <- 0.01 * ref_structure  # tambahkan ini
  }
}

A_sub <- A_seed[idx_pos, idx_pos, drop = FALSE]
x_sub <- x1[idx_pos, , drop = FALSE]
u_sub <- u1[idx_pos, , drop = FALSE]
v_sub <- v1[idx_pos, , drop = FALSE]

maxiter <- 10000
tol <- 1e-20

for (iter in 1:maxiter) {
  
  ## ---- Row scaling (match u) ----
  u_hat <- A_sub %*% x_sub
  
  # proteksi numerik
  u_hat[u_hat == 0] <- 1
  
  r <- as.vector(u_sub / u_hat)
  R <- diag(r)
  
  A1 <- R %*% A_sub
  
  ## ---- Column scaling (match v) ----
  v_hat <- colSums(sweep(A1, 2, as.vector(x_sub), "*"))
  
  # proteksi numerik
  v_hat[v_hat == 0] <- 1
  
  s <- as.vector(v_sub / v_hat)
  S <- diag(s)
  
  A_new <- A1 %*% S
  ## ---- Constraint-based convergence check ----
  row_err <- max(abs(A_new %*% x_sub - u_sub) / u_sub)
  col_err <- max(abs(
    colSums(sweep(A_new, 2, as.vector(x_sub), "*")) - as.vector(v_sub)
  ) / as.vector(v_sub))
  
  if (row_err < tol && col_err < tol) break
  A_sub <- A_new
}

A_IO52_2024 <- matrix(0, nrow = nrow(A), ncol = ncol(A))
A_IO52_2024[idx_pos, idx_pos] <- A_sub

# <- res eval
evaluate <- data.frame("row_consistency" = max(abs(A_IO52_2024 %*% x1 - u1)),
                       "column_consistency" = max(abs(colSums(A_IO52_2024 * matrix(x1, nrow=nrow(A_IO52_2024), ncol=ncol(A_IO52_2024), byrow=TRUE)) - v1)))


matlist <- list("a_irio_2024" = A_IO52_2024,
                "a_irio_2016" = amatr,
                "interm_input_2024" = intinp_hor_up,
                "interm_output_2024" = intout_ver_up,
                "totaloutput_2024" = totaloutput_up,
                "matr eval" = evaluate)

openxlsx::write.xlsx(matlist,"01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx")

