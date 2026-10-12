###-----------------------------------------------------------------<
### 04. Leontief & Ghosh Multipliers, BL/FL, HEM                   
###                                                                 
### This script computes demand-side and supply-side multipliers,   
### sectoral linkage indices, and Hypothetical Extraction Method    
### (HEM) total linkages for three tables:                          
### IO 52 (2024), IO 185 (2024), and IRIO 52 (2024).               
###                                                                 
### ---- CONCEPTUAL OVERVIEW ----                                   
###                                                                 
### [1] LEONTIEF MULTIPLIER (demand-pull / backward)                
###     The Leontief inverse L = (I - A)^-1 captures the total     
###     (direct + indirect) output generated in ALL sectors per     
###     unit of FINAL DEMAND injected into sector j.                
###     L_ij = unit of output in sector i required per unit of      
###     final demand in sector j.                                   
###     Output multiplier for sector j = col-sum of L[,j].          
###     Interpretation: how a demand shock in j ripples upstream    
###     (backward) through the supply chain.                        
###                                                                 
### [2] GHOSH MULTIPLIER (supply-push / forward)                    
###     Ghosh inverse G = (I - B)^-1, where B = output coefficient  
###     matrix: B_ij = z_ij / x_i (share of i's output going to j). 
###     G captures total output generated in ALL sectors per unit   
###     of PRIMARY INPUT added to sector i.                         
###     Supply multiplier for sector i = row-sum of G[i,].          
###     Interpretation: how a supply shock in i propagates          
###     downstream (forward) to users of i's output.               
###     Note: Ghosh is used here for FL measurement only, not       
###     causal supply simulation (Oosterhaven 1988 critique).       
###                                                                 
### [3] BACKWARD LINKAGE (BL) — Hirschman-Rasmussen                
###     BL_j = (col-sum of L[,j] / n) / (sum of ALL L / n^2)       
###          = normalized Leontief col-sum.                         
###     BL > 1: sector j pulls above-average demand from suppliers. 
###                                                                 
### [4] FORWARD LINKAGE (FL) — Hirschman-Rasmussen                 
###     FL_i = (row-sum of G[i,] / n) / (sum of ALL G / n^2)       
###          = normalized Ghosh row-sum.                            
###     FL > 1: sector i supplies above-average inputs to buyers.   
###                                                                 
### [5] HYPOTHETICAL EXTRACTION METHOD (HEM)                        
###     Measures how much total output the economy LOSES if sector  
###     k is entirely removed — capturing both backward and forward  
###     effects simultaneously without double-counting.             
###                                                                 
###     Procedure for each sector k:                                
###     a) Baseline: X = L %*% Y  (actual total output)            
###     b) Extract sector k: zero out row k AND col k in A          
###        -> A_ext (n x n with row k and col k = 0)               
###     c) Compute L_ext = (I - A_ext)^-1                          
###     d) Counterfactual: X_ext = L_ext %*% Y                     
###     e) Total Linkage (TL_k) = sum(X) - sum(X_ext)              
###        = total output lost if sector k is hypothetically        
###        removed from the economy.                                
###                                                                 
###     BL_HEM_k = output lost from removing k's COLUMN in A       
###                (zeroing backward linkage only — k stops buying) 
###     FL_HEM_k = output lost from removing k's ROW in A          
###                (zeroing forward linkage only — k stops selling) 
###     TL_HEM_k = BL_HEM + FL_HEM - own-sector adjustment         
###                                                                 
###     Normalized HEM: divide TL_k by mean TL across all sectors  
###     -> nTL > 1 means sector k is above-average in total        
###     structural importance.                                      
###                                                                 
### Key sector classification (HR + HEM):                          
###   BL > 1 & FL > 1  -> Key sector (high interindustry linkage)  
###   BL > 1 & FL <= 1 -> Backward-dependent (demand driver)       
###   BL <= 1 & FL > 1 -> Forward-dependent (supply driver)        
###   BL <= 1 & FL <= 1 -> Independent (weakly linked)             
###   nTL > 1           -> Structurally important (HEM criterion)  
###                                                                 
### ---- HOW THE SCRIPT WORKS ----                                  
###                                                                 
### Step 1: Load A matrices and X vectors from scripts 01-03.       
### Step 2: Compute L, G, BL, FL, multipliers for each table.       
### Step 3: Run HEM loop across all sectors for each table.         
### Step 4: Assemble sector-level summary tables.                   
### Step 5: Export 3 xlsx files (IO52, IO185, IRIO).                
###                                                                 
### Full explanation: Technical notes.Rmd                           
###-----------------------------------------------------------------<


#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data: raw sheets from upstream script outputs
io52_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",       sheet = "a_io52_2024")
x52_raw   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",       sheet = "totaloutput_2024")
io185_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "a_io185_2024")
x185_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "totaloutput_2024")
irio_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "a_irio_2024")
xirio_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "totaloutput_2024")

# <- final demand vector: needed for HEM. Computed as X - U (X minus total intermediate output)
#    sourced from the same upstream output files.
u52_raw   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",       sheet = "interm_output_2024")
u185_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "interm_output_2024")
uirio_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "interm_output_2024")


###-----------------------------------------------------------------
### Helper functions
### mat_to_df / vec_to_df : standardized export format (same as s01-03)
### leontief_*            : demand-side computation from A matrix
### ghosh_*               : supply-side computation from A matrix + X
### linkage_table         : HR sector-level summary (BL, FL, OM, SM)
### hem_all               : HEM loop — runs extraction for all sectors
###-----------------------------------------------------------------

mat_to_df <- function(mat) cbind(kode = rownames(mat), as.data.frame(mat))
vec_to_df <- function(vec, col) data.frame(kode = names(vec), setNames(list(vec), col))

# <- Leontief inverse: L = (I - A)^-1
leontief_inverse <- function(A) {
  n <- nrow(A)
  L <- solve(diag(n) - A)
  rownames(L) <- rownames(A)
  colnames(L) <- colnames(A)
  L
}

# <- Output multiplier per sector j: col-sum of L[,j]
leontief_multiplier <- function(L) colSums(L)

# <- Ghosh output coefficient matrix: B_ij = z_ij / x_i
ghosh_B <- function(A, X) {
  X_safe <- pmax(X, 1)
  B <- sweep(A, 2, X_safe, "*")    # scale cols by x_j
  B <- sweep(B, 1, X_safe, "/")    # scale rows by 1/x_i
  rownames(B) <- rownames(A)
  colnames(B) <- colnames(A)
  B
}

# <- Ghosh inverse: G = (I - B)^-1
ghosh_inverse <- function(B) {
  n <- nrow(B)
  G <- solve(diag(n) - B)
  rownames(G) <- rownames(B)
  colnames(G) <- colnames(B)
  G
}

# <- Supply multiplier per sector i: row-sum of G[i,]
ghosh_multiplier <- function(G) rowSums(G)

# <- Hirschman-Rasmussen normalized BL and FL
backward_linkage <- function(L) {
  n       <- nrow(L)
  avg_all <- sum(L) / n^2
  (colSums(L) / n) / avg_all
}

forward_linkage <- function(G) {
  n       <- nrow(G)
  avg_all <- sum(G) / n^2
  (rowSums(G) / n) / avg_all
}

# <- HR linkage summary table (BL, FL, OM, SM, classification)
linkage_table <- function(L, G, X, table_name) {
  BL <- backward_linkage(L)
  FL <- forward_linkage(G)
  OM <- leontief_multiplier(L)
  SM <- ghosh_multiplier(G)
  data.frame(
    table      = table_name,
    kode       = names(BL),
    BL         = as.numeric(BL),
    FL         = as.numeric(FL),
    OM         = as.numeric(OM),
    SM         = as.numeric(SM),
    X          = as.numeric(X[names(BL)]),
    key_sector = case_when(
      BL > 1 & FL > 1  ~ "Key sector",
      BL > 1 & FL <= 1 ~ "Backward-dependent",
      BL <= 1 & FL > 1 ~ "Forward-dependent",
      TRUE             ~ "Independent"
    )
  )
}

# <- HEM: full extraction loop over all sectors
#    Returns data.frame with BL_HEM, FL_HEM, TL_HEM, nTL per sector.
#    Y = final demand vector = X - U (intermediate output).
#    For each sector k:
#      BL_HEM: zero col k in A -> counterfactual output loss (backward)
#      FL_HEM: zero row k in A -> counterfactual output loss (forward)
#      TL_HEM: zero both row+col k -> total structural loss
hem_all <- function(A, X, Y) {
  n        <- nrow(A)
  codes    <- rownames(A)
  X_total  <- sum(X)
  
  BL_HEM <- numeric(n)
  FL_HEM <- numeric(n)
  TL_HEM <- numeric(n)
  
  for (k in seq_len(n)) {
    # Backward: remove col k (sector k stops buying inputs)
    A_bl         <- A;  A_bl[, k] <- 0
    L_bl         <- solve(diag(n) - A_bl)
    BL_HEM[k]    <- X_total - sum(L_bl %*% Y)
    
    # Forward: remove row k (sector k stops supplying outputs)
    A_fl         <- A;  A_fl[k, ] <- 0
    L_fl         <- solve(diag(n) - A_fl)
    FL_HEM[k]    <- X_total - sum(L_fl %*% Y)
    
    # Total: remove both row and col k
    A_tl         <- A;  A_tl[k, ] <- 0;  A_tl[, k] <- 0
    L_tl         <- solve(diag(n) - A_tl)
    TL_HEM[k]    <- X_total - sum(L_tl %*% Y)
  }
  
  # Normalized TL: TL_k / mean(TL) — values > 1 = above-average structural importance
  nTL <- TL_HEM / mean(TL_HEM)
  
  data.frame(
    kode   = codes,
    BL_HEM = BL_HEM,
    FL_HEM = FL_HEM,
    TL_HEM = TL_HEM,
    nTL    = nTL
  )
}


###-----------------------------------------------------------------
### Data prep: parse raw imports into A matrices, X and Y vectors
###-----------------------------------------------------------------

# <- IO 52
A_IO52  <- io52_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IO52) <- io52_raw$kode
X_IO52  <- setNames(x52_raw$totaloutput_2024,      x52_raw$kode)
U_IO52  <- setNames(u52_raw$interm_output_2024,    u52_raw$kode)
Y_IO52  <- X_IO52 - U_IO52                          # final demand vector

# <- IO 185
A_IO185 <- io185_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IO185) <- io185_raw$kode
X_IO185 <- setNames(x185_raw$totaloutput_2024,     x185_raw$kode)
U_IO185 <- setNames(u185_raw$interm_output_2024,   u185_raw$kode)
Y_IO185 <- X_IO185 - U_IO185

# <- IRIO 1768
A_IRIO  <- irio_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IRIO) <- irio_raw$kode
X_IRIO  <- setNames(xirio_raw$totaloutput_2024,    xirio_raw$kode)
U_IRIO  <- setNames(uirio_raw$interm_output_2024,  uirio_raw$kode)
Y_IRIO  <- X_IRIO - U_IRIO


###-----------------------------------------------------------------
### COMPUTE: IO 52 — Leontief, Ghosh, BL/FL, HEM
###-----------------------------------------------------------------

cat("Computing IO 52...\n")

L_IO52 <- leontief_inverse(A_IO52)
B_IO52 <- ghosh_B(A_IO52, X_IO52)
G_IO52 <- ghosh_inverse(B_IO52)

summary_IO52 <- linkage_table(L_IO52, G_IO52, X_IO52, "IO52_2024")

cat("  Running HEM (52 extractions)...\n")
hem_IO52     <- hem_all(A_IO52, X_IO52, Y_IO52)
summary_IO52 <- summary_IO52 %>% left_join(hem_IO52, by = "kode")

cat("IO 52 done. Key sectors:", sum(summary_IO52$key_sector == "Key sector"),
    "| HEM structurally important (nTL>1):", sum(summary_IO52$nTL > 1), "\n")


###-----------------------------------------------------------------
### COMPUTE: IO 185 — Leontief, Ghosh, BL/FL, HEM
###-----------------------------------------------------------------

cat("Computing IO 185...\n")

L_IO185 <- leontief_inverse(A_IO185)
B_IO185 <- ghosh_B(A_IO185, X_IO185)
G_IO185 <- ghosh_inverse(B_IO185)

summary_IO185 <- linkage_table(L_IO185, G_IO185, X_IO185, "IO185_2024")

cat("  Running HEM (185 extractions)...\n")
hem_IO185     <- hem_all(A_IO185, X_IO185, Y_IO185)
summary_IO185 <- summary_IO185 %>% left_join(hem_IO185, by = "kode")

cat("IO 185 done. Key sectors:", sum(summary_IO185$key_sector == "Key sector"),
    "| HEM structurally important (nTL>1):", sum(summary_IO185$nTL > 1), "\n")


###-----------------------------------------------------------------
### COMPUTE: IRIO 52 — Leontief, Ghosh, BL/FL, HEM
### Note: 1768x1768 inversion is memory-intensive (~11GB peak).
### HEM requires 1768 separate inversions — runtime can be 30-60min.
### If RAM is limited, swap leontief_inverse() with Matrix::solve()
### using sparse representation: as(A_IRIO, "sparseMatrix").
###-----------------------------------------------------------------

cat("Computing IRIO (1768x1768 — may take several minutes)...\n")

L_IRIO <- leontief_inverse(A_IRIO)
B_IRIO <- ghosh_B(A_IRIO, X_IRIO)
G_IRIO <- ghosh_inverse(B_IRIO)

summary_IRIO <- linkage_table(L_IRIO, G_IRIO, X_IRIO, "IRIO52_2024")

cat("  Running HEM (1768 extractions — this will take a while)...\n")
hem_IRIO     <- hem_all(A_IRIO, X_IRIO, Y_IRIO)
summary_IRIO <- summary_IRIO %>% left_join(hem_IRIO, by = "kode")

cat("IRIO done. Key sectors:", sum(summary_IRIO$key_sector == "Key sector"),
    "| HEM structurally important (nTL>1):", sum(summary_IRIO$nTL > 1), "\n")


###-----------------------------------------------------------------
### AGGREGATE IRIO LINKAGES: province-level and national averages
### Aggregation is simple mean across subsectors per group.
### nTL_mean: average structural importance across subsectors.
###-----------------------------------------------------------------

# Parse kode: format "provcode-sectorcode"
summary_IRIO <- summary_IRIO %>%
  mutate(
    kode_prov = as.integer(sub("^([0-9]+)-.*", "\\1", kode)),
    kodeIO    = sub("^[0-9]+-", "", kode)
  )

# Province-level: mean metrics across 52 subsectors per province
prov_linkage <- summary_IRIO %>%
  group_by(kode_prov) %>%
  summarise(
    BL_mean  = mean(BL,     na.rm = TRUE),
    FL_mean  = mean(FL,     na.rm = TRUE),
    OM_mean  = mean(OM,     na.rm = TRUE),
    SM_mean  = mean(SM,     na.rm = TRUE),
    TL_mean  = mean(TL_HEM, na.rm = TRUE),
    nTL_mean = mean(nTL,    na.rm = TRUE),
    X_total  = sum(X,       na.rm = TRUE),
    n_key    = sum(key_sector == "Key sector"),
    n_struct = sum(nTL > 1),
    .groups  = "drop"
  )

# National subsector: mean metrics per kodeIO across 34 provinces
nat_sector_linkage <- summary_IRIO %>%
  group_by(kodeIO) %>%
  summarise(
    BL_mean  = mean(BL,     na.rm = TRUE),
    FL_mean  = mean(FL,     na.rm = TRUE),
    OM_mean  = mean(OM,     na.rm = TRUE),
    SM_mean  = mean(SM,     na.rm = TRUE),
    TL_mean  = mean(TL_HEM, na.rm = TRUE),
    nTL_mean = mean(nTL,    na.rm = TRUE),
    X_total  = sum(X,       na.rm = TRUE),
    n_key    = sum(key_sector == "Key sector"),
    n_struct = sum(nTL > 1),
    .groups  = "drop"
  )


###-----------------------------------------------------------------
### OUTPUT SHEETS — INTERPRETATION GUIDE
###
### Three output files are exported, one per table.
### Each file shares the same sheet structure:
###
### [1] leontief
###     Square matrix (n x n) with leading "kode" column.
###     Cell L[i,j] = total output required from sector i per unit
###     of final demand in sector j (direct + all indirect rounds).
###     Diagonal L[j,j] > 1 always (own-sector requirement).
###     Use: demand shock simulation -> L %*% delta_Y gives
###     economy-wide output impact vector per sector.
###
### [2] ghosh
###     Square matrix (n x n) with leading "kode" column.
###     Cell G[i,j] = total output generated in sector j per unit
###     of primary input added to sector i. Captures downstream
###     propagation of supply-side changes.
###     Use: forward linkage measurement. For causal supply shock
###     simulation, prefer HEM (see below).
###
### [3] linkage
###     One row per sector. Columns:
###     - BL        : Backward Linkage (HR-normalized). BL > 1 =
###                   sector pulls above-average input demand.
###     - FL        : Forward Linkage (HR-normalized). FL > 1 =
###                   sector supplies above-average output to buyers.
###     - OM        : Output Multiplier = col-sum of L. Total output
###                   induced per unit of final demand in this sector.
###     - SM        : Supply Multiplier = row-sum of G. Total output
###                   induced per unit of primary input in this sector.
###     - X         : Total output 2024 (Rp).
###     - key_sector: Hirschman-Rasmussen classification:
###                   "Key sector"         = BL>1 & FL>1
###                   "Backward-dependent" = BL>1 & FL<=1
###                   "Forward-dependent"  = BL<=1 & FL>1
###                   "Independent"        = BL<=1 & FL<=1
###     - BL_HEM    : HEM backward loss (Rp). Output lost if sector
###                   k stops buying inputs (col zeroed). Captures
###                   pure backward structural pull.
###     - FL_HEM    : HEM forward loss (Rp). Output lost if sector
###                   k stops supplying outputs (row zeroed). Captures
###                   pure forward structural push.
###     - TL_HEM    : Total Linkage (Rp). Output lost if sector k is
###                   fully extracted (row+col zeroed). This is the
###                   definitive HEM measure — no double-counting.
###                   Larger TL_HEM = more structurally critical.
###     - nTL       : Normalized TL = TL_k / mean(TL). nTL > 1 =
###                   above-average structural importance. Use this
###                   for cross-sector ranking.
###
### IRIO file has two additional sheets:
###
### [4] linkage_prov
###     One row per province. Averages of BL/FL/OM/SM/TL/nTL across
###     all 52 subsectors in that province, plus X_total (total
###     provincial output), n_key (HR key sectors), n_struct (HEM
###     structurally important sectors, nTL>1).
###     Higher nTL_mean = province's economy is more structurally
###     integrated into interregional supply chains.
###
### [5] linkage_nat
###     One row per subsector kodeIO. Averages of BL/FL/OM/SM/TL/nTL
###     across all 34 provinces, plus X_total and n_struct.
###     Use: identify subsectors that are nationally structural
###     regardless of province — e.g., if n_struct = 34, the sector
###     is HEM-important in every single province.
###-----------------------------------------------------------------


###-----------------------------------------------------------------
### EXPORT: 3 separate files — IO52, IO185, IRIO
###-----------------------------------------------------------------

# IO 52
openxlsx::write.xlsx(
  list(
    leontief = mat_to_df(L_IO52),
    ghosh    = mat_to_df(G_IO52),
    linkage  = summary_IO52
  ),
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IO52_2024.xlsx"
)

# IO 185
openxlsx::write.xlsx(
  list(
    leontief = mat_to_df(L_IO185),
    ghosh    = mat_to_df(G_IO185),
    linkage  = summary_IO185
  ),
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IO185_2024.xlsx"
)

# IRIO 52
openxlsx::write.xlsx(
  list(
    leontief     = mat_to_df(L_IRIO),
    ghosh        = mat_to_df(G_IRIO),
    linkage      = summary_IRIO,
    linkage_prov = prov_linkage,
    linkage_nat  = nat_sector_linkage
  ),
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IRIO52_2024.xlsx"
)
