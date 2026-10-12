###---------------------------------------------------------<
### 02. Rescaling IO 52x52 -> 185x185                     
###                                                        
### Goal: Expand the updated 2024 IO table from the        
### 52-subsector format to the 185-product format,         
### using the internal proportion structure of IO 2020.    
###                                                        
### Background: The 52-subsector IO 2024 produced by       
### script 01 contains I-46, which was constructed as a    
### standalone subsector. Before disaggregating to 185     
### products, I-46 must be reversed back into I-43/44/45   
### because the 185-product IO does not recognise I-46     
### as a separate entity.                                  
###                                                        
### Workflow overview:                                     
### 1) Read the 52x52 IO 2024 results from script 01       
### 2) Reverse I-46: redistribute I-46 values back into    
###    I-43, I-44, I-45 proportionally, then drop I-46    
###    (producing a 51x51 Z matrix)                        
### 3) Disaggregate 51x51 -> 185x185 using the internal   
###    proportion structure of IO 2020 (185 products)      
###    as disaggregation weights                           
### 4) Compute A matrix, X, U, V for the 185-product format
### 5) Evaluate consistency: re-aggregate Z185 -> Z51 and  
###    compare against the original Z51                    
###                                                        
### Output: v2_io_2024(185x185).xlsx                       
### Full documentation: Technical notes.Rmd               
###---------------------------------------------------------<


#-> Import libraries
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)


#-> Import data
# - A, Z, X from script 01 output (v2 format: "kode" column as identifier)
# - io185_raw: IO 2020 in 185-product format — used as proportion reference
# - concord52_185: concordance between 185-product codes and 52 subsectors
A_io24.52_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "a_io52_2024")
Z_io24.52_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "z_io52_2024")
X_io24.52_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "totaloutput_2024")
io185_raw     <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io20.csv", header = TRUE)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "Full_Concordance")


###---------------------------------------------------------
### STAGE 1: Read and prepare matrices from script 01      
###                                                        
### Data is read in tabular format (with a "kode" column). 
### The kode column is stripped, then row and column names 
### are assigned so that matrix operations work correctly. 
###---------------------------------------------------------

# Extract subsector code vector (I-01 through I-52)
sec52_codes <- A_io24.52_raw$kode

# Convert to numeric matrices and assign dimension names
A_mat <- A_io24.52_raw %>% select(-kode) %>% as.matrix()
Z52   <- Z_io24.52_raw %>% select(-kode) %>% as.matrix()
X_vec <- X_io24.52_raw$totaloutput_2024

rownames(A_mat) <- sec52_codes
colnames(A_mat) <- sec52_codes
rownames(Z52)   <- sec52_codes
colnames(Z52)   <- sec52_codes
names(X_vec)    <- sec52_codes

cat("Dimensions Z52:", dim(Z52), "\n")
cat("Total output (52 subsectors):", formatC(sum(X_vec), format = "e"), "\n\n")


###---------------------------------------------------------
### STAGE 2: Reverse I-46 back into I-43, I-44, I-45      
###                                                        
### I-46 was constructed in script 01 as a standalone      
### subsector. However, the 185-product IO has no          
### counterpart for I-46 — it has no product-level code.  
### Therefore, before disaggregating to 185 products,      
### I-46 values must be distributed back into I-43/44/45. 
###                                                        
### Reversal rules:                                        
### - Only I-43, I-44, I-45 values change                 
### - All other subsectors are completely unchanged        
### - The X (total output) vector is not modified          
### - Distribution weights: proportional to I-43/44/45    
###   values in Z 2024 itself. If I-43+I-44+I-45 = 0 at  
###   a given cell, distribute equally (1/3 each)         
### - Rows and columns of I-46 are processed separately   
###   to avoid double-counting                            
###---------------------------------------------------------

Z51 <- Z52  # copy Z52; will be modified during reversal

# 2.1 Reverse I-46 ROWS
# Distribute Z["I-46", j] (I-46 output to sector j) back into
# I-43/44/45 rows, weighted by their values in the original Z52
for (j in sec52_codes) {
  
  val_46 <- Z52["I-46", j]
  if (val_46 == 0) next          # nothing to redistribute
  
  v43 <- Z52["I-43", j]
  v44 <- Z52["I-44", j]
  v45 <- Z52["I-45", j]
  tot <- v43 + v44 + v45
  
  # If total = 0, distribute equally; otherwise use actual proportions
  prop <- if (tot == 0) c(1/3, 1/3, 1/3) else c(v43, v44, v45) / tot
  
  Z51["I-43", j] <- Z51["I-43", j] + prop[1] * val_46
  Z51["I-44", j] <- Z51["I-44", j] + prop[2] * val_46
  Z51["I-45", j] <- Z51["I-45", j] + prop[3] * val_46
}

# 2.2 Reverse I-46 COLUMNS
# Distribute Z[i, "I-46"] (input from sector i into I-46) back into
# I-43/44/45 columns, using the original Z52 as the proportion reference
# (not the modified Z51, to avoid double-counting from step 2.1)
for (i in sec52_codes) {
  
  val_46 <- Z52[i, "I-46"]
  if (val_46 == 0) next
  
  v43 <- Z52[i, "I-43"]
  v44 <- Z52[i, "I-44"]
  v45 <- Z52[i, "I-45"]
  tot <- v43 + v44 + v45
  
  prop <- if (tot == 0) c(1/3, 1/3, 1/3) else c(v43, v44, v45) / tot
  
  Z51[i, "I-43"] <- Z51[i, "I-43"] + prop[1] * val_46
  Z51[i, "I-44"] <- Z51[i, "I-44"] + prop[2] * val_46
  Z51[i, "I-45"] <- Z51[i, "I-45"] + prop[3] * val_46
}

# 2.3 Drop I-46 row and column — after reversal, I-46 is no longer needed
Z51 <- Z51[rownames(Z51) != "I-46", colnames(Z51) != "I-46"]

# 2.4 Update X vector: remove the I-46 entry; all other values unchanged
X51 <- X_vec[names(X_vec) != "I-46"]
sec51_codes <- names(X51)

# 2.5 Verification: confirm no changes occurred outside I-43/44/45
#     max_diff must equal 0 (no other subsector values should have changed)
idx_check  <- setdiff(sec51_codes, c("I-43","I-44","I-45"))
max_diff   <- max(abs(Z51[idx_check, idx_check] - Z52[idx_check, idx_check]))

cat("=== STAGE 2: I-46 Reversal ===\n")
cat("Dimensions Z51:", dim(Z51), "\n")
cat("Total output (51 subsectors):", formatC(sum(X51), format = "e"), "\n")
cat("Max change outside I-43/44/45:", max_diff,
    " <- must be 0\n\n")


###---------------------------------------------------------
### STAGE 3: Disaggregate 51x51 -> 185x185                
###                                                        
### Each cell Z51[K, L] (transaction value from subsector K 
### to subsector L) is split across all product combinations
### (k, l) belonging to K and L, using the internal        
### proportion structure from IO 2020 (185 products).      
###                                                        
### Formula:                                               
### Z185[k,l] = Z51[K,L] * (Z185_2020[k,l] / Z51_2020[K,L])
###                                                        
### Special cases:                                         
### - Z51[K,L] = 0: all Z185 cells in this block = 0      
###   (no transaction exists)                              
### - Z51_2020[K,L] = 0 but Z51_2024[K,L] > 0:           
###   No proportion available from 2020.                   
###   Solution: distribute equally across all (k,l) cells  
###   in block KL. This arises for sectors newly active    
###   in 2024.                                             
###---------------------------------------------------------

# 3.1 Prepare the IO 2020 Z matrix in 185-product format as proportion reference
prod185_codes <- as.character(concord52_185$prod185)

io185_sector <- io185_raw %>%
  filter(Kode %in% prod185_codes) %>%
  arrange(match(Kode, prod185_codes))

Z185_2020 <- io185_sector %>%
  select(all_of(prod185_codes)) %>%
  as.matrix()
rownames(Z185_2020) <- prod185_codes
colnames(Z185_2020) <- prod185_codes

cat("Dimensions Z185_2020:", dim(Z185_2020), "\n")

# 3.2 Concordance: 185 products -> 51 subsectors (I-46 excluded)
concord_51 <- concord52_185 %>%
  filter(sec52 != "I-46") %>%
  mutate(prod185 = as.character(prod185))

cat("Products mapped to sec51:",
    sum(prod185_codes %in% concord_51$prod185), "of 185\n")
cat("Products mapped to I-46 (excluded):",
    sum(concord52_185$sec52 == "I-46"), "\n\n")

# 3.3 Aggregate Z185_2020 -> Z51_2020 using aggregation matrix P
# P is a binary matrix: P[k, K] = 1 if product k belongs to subsector K
# Z51_2020 = P' * Z185_2020 * P (aggregates both rows and columns simultaneously)
prods_in_map <- prod185_codes[prod185_codes %in% concord_51$prod185]
prod_to_sec  <- setNames(concord_51$sec52, concord_51$prod185)
n185         <- length(prods_in_map)

secs_ordered <- sec51_codes   # ordering follows Z51 2024

P <- matrix(0, nrow = n185, ncol = length(secs_ordered),
            dimnames = list(prods_in_map, secs_ordered))
for (k in prods_in_map) P[k, prod_to_sec[k]] <- 1

Z51_2020_agg <- t(P) %*% Z185_2020[prods_in_map, prods_in_map] %*% P
Z51_2020_agg <- Z51_2020_agg[sec51_codes, sec51_codes]   # align ordering

cat("Dimensions Z51_2020_agg:", dim(Z51_2020_agg), "\n\n")

# 3.4 Compute Z185_2024 block by block (K, L)
# For each subsector pair (K, L), split Z51_2024[K,L] into product cells
# (k, l) using the proportion Z185_2020[k,l] / Z51_2020[K,L]
Z185_2024 <- matrix(0, nrow = n185, ncol = n185,
                    dimnames = list(prods_in_map, prods_in_map))

for (K in sec51_codes) {
  
  prods_K <- prods_in_map[prod_to_sec[prods_in_map] == K]
  if (length(prods_K) == 0) next
  
  for (L in sec51_codes) {
    
    prods_L <- prods_in_map[prod_to_sec[prods_in_map] == L]
    if (length(prods_L) == 0) next
    
    Z_KL_2024 <- Z51[K, L]
    Z_KL_2020 <- Z51_2020_agg[K, L]
    sub_2020  <- Z185_2020[prods_K, prods_L, drop = FALSE]
    
    if (Z_KL_2024 == 0) {
      # No transaction in 2024 -> all cells in this block = 0
      Z185_2024[prods_K, prods_L] <- 0
      
    } else if (Z_KL_2020 == 0) {
      # Transaction exists in 2024 but not in 2020 -> no proportion available
      # Solution: distribute equally across all product combinations in block KL
      n_cells <- length(prods_K) * length(prods_L)
      Z185_2024[prods_K, prods_L] <- Z_KL_2024 / n_cells
      
    } else {
      # Standard case: apply 2020 proportion weights
      Z185_2024[prods_K, prods_L] <- Z_KL_2024 * (sub_2020 / Z_KL_2020)
    }
  }
}

cat("Dimensions Z185_2024:", dim(Z185_2024), "\n")
cat("Total Z185_2024 :", formatC(sum(Z185_2024), format = "e"), "\n")
cat("Total Z51_2024  :", formatC(sum(Z51),        format = "e"), "\n\n")


###---------------------------------------------------------
### STAGE 4: Compute A matrix, X, U, V for 185 products   
###                                                        
### Once Z185_2024 is available, derive the remaining      
### variables:                                             
### - X185: total output per product — computed from the   
###   per-product share of X in IO 2020 relative to the   
###   subsector total                                      
### - A185: technical coefficients = Z185 / X185 (by col) 
### - U185: intermediate output = rowSums(Z185)            
### - V185: intermediate input  = colSums(Z185)            
###---------------------------------------------------------

# 4.1 Total Output X185 per product
# X185[k] = X51[K] * (X185_2020[k] / X51_2020[K])
# Same logic as Z disaggregation: use 2020 proportions to split 2024 values
x185_2020_raw <- io185_raw %>%
  filter(Kode %in% prods_in_map) %>%
  arrange(match(Kode, prods_in_map)) %>%
  pull(`3100`)
names(x185_2020_raw) <- prods_in_map

# Aggregate X per subsector from 2020 (used as proportion denominator)
x51_2020_agg <- tapply(x185_2020_raw, prod_to_sec[prods_in_map], sum)

X185 <- setNames(numeric(n185), prods_in_map)

for (k in prods_in_map) {
  K        <- prod_to_sec[k]
  x_K_2024 <- X51[K]
  x_k_2020 <- x185_2020_raw[k]
  x_K_2020 <- x51_2020_agg[K]
  
  if (x_K_2020 == 0) {
    # No 2020 proportion available -> distribute equally across all products in K
    n_prods_K <- sum(prod_to_sec[prods_in_map] == K)
    X185[k]   <- x_K_2024 / n_prods_K
  } else {
    X185[k] <- x_K_2024 * (x_k_2020 / x_K_2020)
  }
}

cat("Total X185:", formatC(sum(X185), format = "e"), "\n")
cat("Total X51 :", formatC(sum(X51),  format = "e"), "\n\n")

# 4.2 A matrix 185x185: technical coefficients = Z[k,l] / X[l]
#     Columns with X=0 are set to 0 (no output, no coefficients)
X185_safe <- ifelse(X185 == 0, 1, X185)     # temporarily replace 0 with 1 to avoid division by zero
A185      <- sweep(Z185_2024, 2, X185_safe, "/")
A185[, X185 == 0] <- 0                       # restore zero-output columns to 0

# 4.3 Intermediate output (U) and input (V)
U185 <- rowSums(Z185_2024)   # U: total sales per product (row sums)
V185 <- colSums(Z185_2024)   # V: total purchases per product (column sums)

cat("Total U185:", formatC(sum(U185), format = "e"), "\n")
cat("Total V185:", formatC(sum(V185), format = "e"), "\n")
cat("U == V?   ", isTRUE(all.equal(sum(U185), sum(V185))), "\n\n")


###---------------------------------------------------------
### STAGE 5: Disaggregation Consistency Evaluation        
###                                                        
### Principle: re-aggregate Z185_2024 back to Z51, then    
### compare against the original Z51_2024. If disaggregation
### is correct, both matrices must be identical (difference 
### approaches zero).                                      
###                                                        
### The function also reports the 10 subsectors with the   
### largest diagonal discrepancy — useful for identifying  
### which subsectors warrant closer inspection.            
###---------------------------------------------------------

evaluate_disaggregation <- function(Z185_2024, Z51_2024, prod_to_sec, sec51_codes) {
  
  cat("=== EVALUATION: Disaggregation Consistency ===\n\n")
  prods <- rownames(Z185_2024)
  
  # Re-aggregate Z185_2024 -> Z51_check by summing over each (K, L) block
  Z51_check <- matrix(0, length(sec51_codes), length(sec51_codes),
                      dimnames = list(sec51_codes, sec51_codes))
  
  for (K in sec51_codes) {
    prods_K <- prods[prod_to_sec[prods] == K]
    if (length(prods_K) == 0) next
    for (L in sec51_codes) {
      prods_L <- prods[prod_to_sec[prods] == L]
      if (length(prods_L) == 0) next
      Z51_check[K, L] <- sum(Z185_2024[prods_K, prods_L])
    }
  }
  
  # Compute difference between re-aggregated and original Z51
  diff_mat <- Z51_check - Z51_2024
  max_diff <- max(abs(diff_mat))
  rel_diff <- max_diff / max(abs(Z51_2024))
  
  # Diagonal check: intra-subsector transactions (self-purchases)
  diag_check <- data.frame(
    sec51     = sec51_codes,
    Z51_2024  = diag(Z51_2024),
    Z51_check = diag(Z51_check),
    abs_diff  = abs(diag(Z51_check) - diag(Z51_2024))
  ) %>% arrange(desc(abs_diff))
  
  summary_eval <- data.frame(
    metric = c("Max absolute difference (any cell)",
               "Relative max difference",
               "Total Z185 sum",
               "Total Z51 sum",
               "Sum difference"),
    value  = c(formatC(max_diff,       format = "e"),
               formatC(rel_diff,       format = "e"),
               formatC(sum(Z185_2024), format = "e"),
               formatC(sum(Z51_2024),  format = "e"),
               formatC(abs(sum(Z185_2024) - sum(Z51_2024)), format = "e"))
  )
  
  cat("Summary:\n")
  print(summary_eval, row.names = FALSE)
  cat("\nTop 10 subsectors with largest diagonal discrepancy:\n")
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


###---------------------------------------------------------
### Export                                                 
### Standard format: every sheet has a "kode" column as   
### the first identifier, followed by data columns.       
### Sheets: A matrix, Z matrix, U, V, X (185 products),  
###         evaluation summary, and diagonal detail table. 
###---------------------------------------------------------

# Helper: matrix -> data.frame with leading kode column
mat_to_df <- function(mat, kode_vec) {
  cbind(kode = kode_vec, as.data.frame(mat))
}

# Helper: named vector -> data.frame with kode and single value column
vec_to_df <- function(vec, col_name) {
  data.frame(kode = names(vec), value = as.numeric(vec)) %>%
    rename(!!col_name := value)
}

matlist_185 <- list(
  # A matrix 185x185: technical coefficients per product
  "a_io185_2024"       = mat_to_df(A185,       prods_in_map),
  
  # Z matrix 185x185: inter-product transactions in rupiah
  "z_io185_2024"       = mat_to_df(Z185_2024,  prods_in_map),
  
  # U: intermediate output 2024 per product (row totals)
  "interm_output_2024" = vec_to_df(U185, "interm_output_2024"),
  
  # V: intermediate input 2024 per product (column totals)
  "interm_input_2024"  = vec_to_df(V185, "interm_input_2024"),
  
  # X: total output 2024 per product
  "totaloutput_2024"   = vec_to_df(X185, "totaloutput_2024"),
  
  # Evaluation summary: overall disaggregation consistency metrics
  "eval_summary"       = eval_result$summary,
  
  # Evaluation detail: per-subsector diagonal discrepancy
  "eval_diag"          = eval_result$diag_check
)

openxlsx::write.xlsx(matlist_185, "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx")