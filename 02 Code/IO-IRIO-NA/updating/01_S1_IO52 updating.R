###---------------------------------------------------------<
### 01. IO Updating — Stage 1: Update the 52x52 IO Table  
###                                                        
### Goal: Update the national Input-Output table's         
### technical coefficients (A matrix) from the 2020 base  
### year (185 products) to the 2024 target year            
### (52 subsectors), using RAS biproportional updating.    
###                                                        
### Workflow overview:                                     
### 1) Aggregate IO 2020 from 185 products -> 52 subsectors
###    The 2020 IO is only available in 17-sector and      
###    185-product formats, so a 52-subsector version must 
###    be constructed before it can be updated.            
### 2) Reconstruct subsector I-46 (Other Financial Services)
###    I-46 is absent from IO 2020; its values are         
###    estimated from the I-46 share within I-43/44/45/46  
###    as observed in IO 2016.                             
### 3) Prepare target vectors: U (intermediate output),    
###    V (intermediate input), and X (total output) for    
###    2024, derived from GDP growth rates.                
### 4) Iterative RAS to produce an A matrix and Z matrix   
###    consistent with the 2024 target vectors.            
###                                                        
### Output: v2_io_2024(52x52).xlsx                        
### Next step: 02_S2_IO52_to_IO185_v3.R                   
### Full documentation: Technical notes.Rmd               
###---------------------------------------------------------<


#-> Import libraries
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)


#-> Import data
# - pdrb: national GDP per 52 subsectors, contains growth rate column (upd)
# - io185_raw: IO 2020 in 185-product format (CSV)
# - io52.16_raw: IO 2016 in 52-subsector format — used as reference for
#   reconstructing I-46 proportions
# - concord52_185: concordance between 185-product codes and 52 subsectors
# - concord17_52: concordance between 17 sectors and 52 subsectors
pdrb          <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx", sheet = "nat_gr")
io185_raw     <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io20.csv", header = T)
io52.16_raw   <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io16(52).csv", header = T)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "Full_Concordance")
concord17_52  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "sec17-52")


###---------------------------------------------------------
### STAGE 1: Aggregate IO 2020 from 185 products -> 52 subs
###                                                        
### The available IO 2020 only exists in 17-sector and     
### 185-product formats. To use it as the RAS base for 52  
### subsectors, both dimensions (rows and columns) must be 
### aggregated from 185 -> 52 using the concordance table. 
### Total rows (codes 2100, 3100) are handled separately   
### so they are not aggregated together with sector rows.  
###---------------------------------------------------------

# 1.1 Separate sector rows (product codes) from total rows (2100, 3100)
#     Total rows will be re-joined at the end without aggregation
sector_rows <- io185_raw %>% filter(Kode %in% concord52_185$prod185)
total_rows  <- io185_raw %>% filter(!Kode %in% concord52_185$prod185) %>%
  mutate(Kode = as.character(Kode))

# 1.2 Attach the 52-subsector code to each sector row
sector_rows <- sector_rows %>%
  left_join(concord52_185 %>% dplyr::select(prod185, sec52), by = c("Kode" = "prod185"))

# 1.3 Identify column types: sector columns (185 products) vs total columns
sector_cols <- as.character(concord52_185$prod185)
total_cols  <- setdiff(names(io185_raw), c("Kode", sector_cols))

# 1.4 Aggregate ROWS: sum values by sec52 (collapsing 185 rows -> 52)
agg_rows <- sector_rows %>%
  group_by(sec52) %>%
  summarise(across(all_of(c(sector_cols, total_cols)), sum), .groups = "drop")

# 1.5 Aggregate COLUMNS: rename each 185-product column to its sec52 code, then sum
#     This collapses 185 columns into 52 sector columns
col_map <- setNames(concord52_185$sec52, as.character(concord52_185$prod185))

agg_matrix <- agg_rows %>%
  pivot_longer(cols = all_of(sector_cols), names_to = "old_col", values_to = "val") %>%
  mutate(new_col = col_map[old_col]) %>%
  group_by(sec52, new_col) %>%
  summarise(val = sum(val), .groups = "drop") %>%
  pivot_wider(names_from = new_col, values_from = val, values_fill = 0)

# 1.6 Re-join total columns to the aggregated matrix (untouched)
io_52 <- agg_matrix %>%
  left_join(agg_rows %>% select(sec52, all_of(total_cols)), by = "sec52")

# 1.7 Process total rows: only sector columns need aggregation
#     Total columns (e.g. 3100 for total output) are kept as-is
total_agg <- total_rows %>%
  pivot_longer(cols = all_of(sector_cols), names_to = "old_col", values_to = "val") %>%
  mutate(new_col = col_map[old_col]) %>%
  group_by(Kode, new_col) %>%
  summarise(val = sum(val), .groups = "drop") %>%
  pivot_wider(names_from = new_col, values_from = val, values_fill = 0) %>%
  left_join(total_rows %>% select(Kode, all_of(total_cols)), by = "Kode") %>%
  rename(sec52 = Kode)

# 1.8 Combine: 52 sector rows + total rows
io_final <- bind_rows(io_52, total_agg) %>% rename(kode = sec52)


###---------------------------------------------------------
### STAGE 2: Reconstruct I-46 (Other Financial Services)  
###                                                        
### IO 2020 does not include subsector I-46. In IO 2016,   
### I-46 exists alongside I-43, I-44, I-45 within the      
### "Financial and Insurance Services" sector group.       
###                                                        
### Approach: use I-46's share of the total               
### (I-43+I-44+I-45+I-46) from IO 2016 as a proxy for its 
### structure in IO 2020. Shares are computed separately   
### for rows (intermediate output) and columns (intermediate
### input), then I-43/44/45 values are reduced             
### proportionally to accommodate the new I-46 entry.      
###---------------------------------------------------------

# 2.1 Prepare two matrices: IO 2016 (52 subsectors) and IO 2020 (52 subsectors)
io16_mat    <- io52.16_raw %>% column_to_rownames("kode") %>% select(-sec17) %>% as.matrix()
io20_mat    <- io_final %>% column_to_rownames("kode") %>% as.matrix()
common_cols <- intersect(colnames(io16_mat), colnames(io20_mat))
common_rows <- intersect(rownames(io16_mat), rownames(io20_mat))

# 2.2 Compute I-46 share per COLUMN from IO 2016
#     i.e. of total I-43+I-44+I-45+I-46 received by column j,
#     what fraction comes from I-46?
#     If total = 0, share = 0 (no transactions at all)
prop_row <- ifelse(
  rowSums(t(io16_mat[c("I-43","I-44","I-45","I-46"), common_cols])) == 0, 0,
  io16_mat["I-46", common_cols] /
    (io16_mat["I-43", common_cols] + io16_mat["I-44", common_cols] +
       io16_mat["I-45", common_cols] + io16_mat["I-46", common_cols]))

# 2.3 Compute I-46 share per ROW from IO 2016
#     i.e. of total I-43+I-44+I-45+I-46 sent by row i,
#     what fraction goes to I-46?
prop_col <- ifelse(
  rowSums(io16_mat[common_rows, c("I-43","I-44","I-45","I-46")]) == 0, 0,
  io16_mat[common_rows, "I-46"] /
    (io16_mat[common_rows, "I-43"] + io16_mat[common_rows, "I-44"] +
       io16_mat[common_rows, "I-45"] + io16_mat[common_rows, "I-46"]))

# 2.4 Apply shares to IO 2020 to estimate I-46 values
#     I-46 value = 2016 share * (I-43+I-44+I-45) total in IO 2020
val_i46_row <- prop_row * (io20_mat["I-43", common_cols] + io20_mat["I-44", common_cols] + io20_mat["I-45", common_cols])
val_i46_col <- prop_col * (io20_mat[common_rows, "I-43"] + io20_mat[common_rows, "I-44"] + io20_mat[common_rows, "I-45"])

# 2.5 Reduce I-43/44/45 proportionally to accommodate the newly introduced I-46
#     This ensures the total I-43+I-44+I-45+I-46 remains unchanged
io20_new <- io20_mat

# Reduction by COLUMN (I-46 row introduced; each column j is reduced)
for (j in common_cols) {
  tot <- io20_mat["I-43", j] + io20_mat["I-44", j] + io20_mat["I-45", j]
  if (tot == 0) next
  io20_new[c("I-43","I-44","I-45"), j] <- io20_mat[c("I-43","I-44","I-45"), j] -
    (io20_mat[c("I-43","I-44","I-45"), j] / tot) * val_i46_row[j]
}

# Reduction by ROW (I-46 column introduced; each row i is reduced)
delta_col <- sapply(common_rows, function(i) {
  tot <- io20_mat[i, "I-43"] + io20_mat[i, "I-44"] + io20_mat[i, "I-45"]
  if (tot == 0) return(c(0, 0, 0))
  (io20_mat[i, c("I-43","I-44","I-45")] / tot) * val_i46_col[i]
}) %>% t()

io20_new[common_rows, c("I-43","I-44","I-45")] <-
  io20_new[common_rows, c("I-43","I-44","I-45")] - delta_col

# 2.6 Insert I-46 row and column immediately after I-45 (preserving subsector order)
pos_r <- which(rownames(io20_new) == "I-45")
pos_c <- which(colnames(io20_new) == "I-45")

row_i46 <- matrix(0, 1, ncol(io20_new), dimnames = list("I-46", colnames(io20_new)))
row_i46[1, common_cols] <- val_i46_row
io20_new <- rbind(io20_new[1:pos_r, , drop = FALSE], row_i46,
                  io20_new[(pos_r + 1):nrow(io20_new), , drop = FALSE])

col_i46 <- matrix(0, nrow(io20_new), 1, dimnames = list(rownames(io20_new), "I-46"))
col_i46[common_rows, 1] <- val_i46_col
io20_new <- cbind(io20_new[, 1:pos_c, drop = FALSE], col_i46,
                  io20_new[, (pos_c + 1):ncol(io20_new), drop = FALSE])

# 2.7 Convert back to tibble for easier downstream manipulation
io_final_53 <- io20_new %>% as.data.frame() %>% rownames_to_column("kode") %>% as_tibble()

# 2.8 Verification: confirm that inserting I-46 does not change overall totals
#     colSums of I-43+I-44+I-45+I-46 in io_final_53 should equal
#     colSums of I-43+I-44+I-45 in io_final (before I-46 existed)
excl <- setdiff(common_cols, c("I-43","I-44","I-45"))
cat("colSums diff :", max(abs(
  colSums(io_final_53 %>% filter(kode %in% c("I-43","I-44","I-45","I-46")) %>% select(all_of(excl))) -
    colSums(io_final   %>% filter(kode %in% c("I-43","I-44","I-45"))         %>% select(all_of(excl)))
)), "\n")
cat("total output :", sum(io20_mat[rownames(io20_mat) != "2100", "3100"], na.rm = TRUE),
    "->", sum(io_final_53 %>% filter(kode != "2100") %>% pull(`3100`), na.rm = TRUE), "\n")
cat("total input  :", sum(io20_mat["2100", colnames(io20_mat) != "3100"], na.rm = TRUE),
    "->", sum(io_final_53 %>% filter(kode == "2100") %>% select(-kode, -`3100`), na.rm = TRUE), "\n")

# 2.9 Save intermediate outputs: IO 2020 with I-46 (52 entries) and without (51)
rio::export(io_final_53, "01 Data/IO-IRIO-NA/output/updating_2024/v1_io20(52x52).csv")
rio::export(io_final,    "01 Data/IO-IRIO-NA/output/updating_2024/v1_io20(51x51).csv")

# 2.10 Check intermediate consistency: total U must equal total V
z_matrix <- io_final_53[1:52, 2:53]
int_consistency <- data.frame(
  total_intermediate_output = sum(rowSums(z_matrix)),
  total_intermediate_input  = sum(colSums(z_matrix))
)


###---------------------------------------------------------
### STAGE 3: Prepare Target Vectors for RAS               
###                                                        
### RAS requires three 2024 target vectors:               
### - U (intermediate output): total sales by each        
###   subsector to all other sectors                      
### - V (intermediate input): total purchases by each     
###   subsector from all other sectors                    
### - X (total output): total production per subsector    
###                                                        
### U and V are obtained by multiplying 2020 values by    
### the GDP growth rate per subsector. For RAS to be       
### mathematically valid, sum(U) must equal sum(V) —      
### V is rescaled to match U.                             
###---------------------------------------------------------

#-> Attach growth rates to subsector order from IO table
pdrb     <- pdrb %>% select(kode, upd)
pdrb_adj <- io_final_53 %>% select(kode) %>% inner_join(pdrb, by = "kode")

# Convert io_final_53 to matrix format with rownames
io52 <- io_final_53
rn   <- io52$kode
rownames(io52) <- rn
io52 <- io52 %>% dplyr::select(-kode)

# Extract Z matrix (52 sectors, in rupiah = values x 1 million)
sec52_codes <- rn[rn != "2100"]

zmatr       <- io52[1:52, 1:52] %>% as.matrix() %>% apply(., 2, as.numeric)
zmatr       <- zmatr * 1e6
rownames(zmatr) <- sec52_codes
colnames(zmatr) <- sec52_codes

# Extract Total Output (X) and Total Input per column (in rupiah)
totaloutput <- as.numeric(unlist(io52[1:52, 53])) * 1e6
totalinput  <- as.numeric(unlist(io52[53, 1:52])) * 1e6
names(totaloutput) <- sec52_codes
names(totalinput)  <- sec52_codes

# Compute U (intermediate output, row sums) and V (intermediate input, column sums)
intinp_hor <- colSums(zmatr)   # V: total purchases per subsector (columns)
intout_ver <- rowSums(zmatr)   # U: total sales per subsector (rows)

# Compute A matrix (technology matrix): a_kl = z_kl / x_l
# Each column is divided by its respective total output
amatr <- sweep(zmatr, 2, totaloutput, "/")
rownames(amatr) <- sec52_codes
colnames(amatr) <- sec52_codes

# Growth rate vector per subsector (ordered to match sec52_codes)
update1624 <- pdrb_adj$upd

# U target 2024 = U 2020 * growth rate
intout_ver_up     <- intout_ver * update1624
tot_intout_ver_up <- sum(intout_ver_up)

# V target 2024 = V 2020 * growth rate, then rescaled so that sum(V) = sum(U)
# This rescaling is mandatory: even small imbalances will prevent RAS convergence
intinp_hor_up <- intinp_hor * update1624
intinp_hor_up <- (intinp_hor_up / sum(intinp_hor_up)) * tot_intout_ver_up

# X target 2024 = X 2020 * growth rate
totaloutput_up <- totaloutput * update1624
names(totaloutput_up) <- sec52_codes


###---------------------------------------------------------
### STAGE 4: RAS Biproportional Updating                  
###                                                        
### RAS works by iteratively scaling the A matrix:        
### - ROW scaling (R): forces rowSums(A*X) = U target     
### - COLUMN scaling (S): forces colSums(A*X) = V target  
### Iteration stops when both row and column errors < tol. 
###                                                        
### Only sectors with X>0, U>0, and V>0 are included in   
### the iteration (idx_pos). All others remain 0.          
###                                                        
### Seed A matrix: sectors that are active in 2024 but    
### whose entire A column is zero in 2020 (new sectors)   
### are given a small initial value (1% of average sector  
### structure). Without this, RAS cannot grow values from  
### a structurally empty column.                           
###---------------------------------------------------------

# Prepare RAS inputs as matrices
x1 <- as.matrix(totaloutput_up)
u1 <- as.matrix(intout_ver_up)
v1 <- as.matrix(intinp_hor_up)
A  <- amatr

# idx_pos: only sectors that are mathematically defined for RAS
idx_pos <- which(x1 > 0 & u1 > 0 & v1 > 0)

A_seed <- A

# Handle new sectors: active in 2024 but structurally empty in 2020
# Seed with 1% of the average structure across active sectors
new_sectors <- which(x1 > 0 & colSums(A) == 0)

if (length(new_sectors) > 0) {
  ref_structure <- colMeans(A[, idx_pos, drop = FALSE])
  for (j in new_sectors) {
    A_seed[, j] <- 0.01 * ref_structure
    A_seed[j, ] <- 0.01 * ref_structure
  }
}

# Subset to active sectors only
A_sub <- A_seed[idx_pos, idx_pos, drop = FALSE]
x_sub <- x1[idx_pos, , drop = FALSE]
u_sub <- u1[idx_pos, , drop = FALSE]
v_sub <- v1[idx_pos, , drop = FALSE]

# Iteration parameters
maxiter <- 10000
tol     <- 1e-20

for (iter in 1:maxiter) {
  
  # ROW scaling: adjust A so that rowSums(A*X) approaches U target
  u_hat <- A_sub %*% x_sub
  u_hat[u_hat == 0] <- 1             # avoid division by zero
  r  <- as.vector(u_sub / u_hat)
  R  <- diag(r)
  A1 <- R %*% A_sub
  
  # COLUMN scaling: adjust A so that colSums(A*X) approaches V target
  v_hat <- colSums(sweep(A1, 2, as.vector(x_sub), "*"))
  v_hat[v_hat == 0] <- 1             # avoid division by zero
  s     <- as.vector(v_sub / v_hat)
  S     <- diag(s)
  A_new <- A1 %*% S
  
  # Convergence check: relative error against targets
  row_err <- max(abs(A_new %*% x_sub - u_sub) / u_sub)
  col_err <- max(abs(
    colSums(sweep(A_new, 2, as.vector(x_sub), "*")) - as.vector(v_sub)
  ) / as.vector(v_sub))
  
  if (row_err < tol && col_err < tol) break
  A_sub <- A_new
}

cat("Converged at iter:", iter, "| row_err:", row_err, "| col_err:", col_err, "\n")

# Reconstruct full 52x52 A matrix (sectors outside idx_pos remain 0)
A_IO52_2024 <- matrix(0, nrow = nrow(A), ncol = ncol(A),
                      dimnames = list(sec52_codes, sec52_codes))
A_IO52_2024[idx_pos, idx_pos] <- A_sub

# Z matrix 2024: Z = A * diag(X)
Z_IO52_2024 <- sweep(A_IO52_2024, 2, as.vector(totaloutput_up), "*")

# Final U and V from the updated Z matrix
intout_ver_up_final <- rowSums(Z_IO52_2024)   # U final
intinp_hor_up_final <- colSums(Z_IO52_2024)   # V final

# Internal consistency evaluation:
# row_consistency: how far A*X deviates from U target (should approach 0)
# column_consistency: how far colSums(A*X) deviates from V target
evaluate <- data.frame(
  row_consistency    = max(abs(A_IO52_2024 %*% x1 - u1)),
  column_consistency = max(abs(
    colSums(A_IO52_2024 * matrix(x1, nrow = nrow(A_IO52_2024),
                                 ncol = ncol(A_IO52_2024), byrow = TRUE)) - v1
  ))
)


###---------------------------------------------------------
### Export                                                 
### Standard format: every sheet has a "kode" column as   
### the first identifier, followed by data columns.       
### Sheets: A matrix, Z matrix, base A matrix, U, V, X,  
###         and the consistency evaluation table.         
###---------------------------------------------------------

# Helper: matrix -> data.frame with leading kode column
mat_to_df <- function(mat, kode_vec) {
  df <- as.data.frame(mat)
  cbind(kode = kode_vec, df)
}

# Helper: named vector -> data.frame with kode and single value column
vec_to_df <- function(vec, col_name) {
  data.frame(kode = names(vec), value = as.numeric(vec)) %>%
    rename(!!col_name := value)
}

matlist <- list(
  # A matrix 2024: updated technical coefficients
  "a_io52_2024"        = mat_to_df(A_IO52_2024, sec52_codes),
  
  # Z matrix 2024: inter-sector transactions in rupiah
  "z_io52_2024"        = mat_to_df(Z_IO52_2024, sec52_codes),
  
  # A matrix 2020: base-year technical coefficients (before updating)
  "a_io52_2020"        = mat_to_df(amatr, sec52_codes),
  
  # U: intermediate output 2024 per subsector (row totals)
  "interm_output_2024" = vec_to_df(intout_ver_up_final, "interm_output_2024"),
  
  # V: intermediate input 2024 per subsector (column totals)
  "interm_input_2024"  = vec_to_df(intinp_hor_up_final, "interm_input_2024"),
  
  # X: total output 2024 per subsector
  "totaloutput_2024"   = vec_to_df(totaloutput_up, "totaloutput_2024"),
  
  # Evaluation: deviation from RAS targets (should be near zero)
  "eval"               = evaluate
)

openxlsx::write.xlsx(matlist, "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx")