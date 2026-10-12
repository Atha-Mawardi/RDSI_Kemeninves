###-----------------------------------------------------------------<
### 05. Demand & Supply Shock Simulation (Batch Mode)               
###                                                                 
### This script simulates the economy-wide output impact of         
### demand-side (Leontief) and supply-side (Ghosh) shocks           
### across three tables: IO 52, IO 185, and IRIO 52 (2024).         
###                                                                 
### ---- CONCEPTUAL OVERVIEW ----                                   
###                                                                 
### [1] DEMAND SHOCK (Leontief)                                     
###     A demand shock increases final demand Y in sector j         
###     by delta_Y. The total output impact across all sectors      
###     is computed as:                                             
###       delta_X = L %*% delta_Y                                   
###     where L = (I - A)^-1 is the Leontief inverse.              
###     delta_X[i] = output increase induced in sector i            
###     from the demand injection in sector j.                      
###     Interpretation: how much upstream production is             
###     triggered by a unit increase in final demand.               
###                                                                 
### [2] SUPPLY SHOCK (Ghosh)                                        
###     A supply shock increases primary input V in sector i        
###     by delta_V. The total output impact is:                     
###       delta_X = delta_V %*% G                                   
###     where G = (I - B)^-1 is the Ghosh inverse,                 
###     B = output coefficient matrix (B_ij = z_ij / x_i).         
###     delta_X[j] = output increase induced in sector j            
###     from the supply expansion in sector i.                      
###     Interpretation: how much downstream production is           
###     enabled by a unit increase in primary input supply.         
###     Note: Ghosh used here as accounting framework only          
###     (Oosterhaven 1988 critique applies to causal inference).    
###                                                                 
### ---- SHOCK MODES (IRIO only) ----                               
###                                                                 
###   "sector_province"  : shock at one specific province-sector    
###                        pair. Target format: "32-I-29".          
###   "sector_national"  : shock at one sector across all 34        
###                        provinces, distributed proportionally    
###                        by each province's output share.         
###   "province_all"     : shock across all 52 subsectors in one    
###                        province, distributed proportionally     
###                        by each subsector's output share.        
###                                                                 
###   For IO52 and IO185, mode is not needed — shock goes           
###   directly to the target sector.                                
###                                                                 
### ---- HOW THE SCRIPT WORKS ----                                  
###                                                                 
### Step 1: Load A matrices + X, Y, V vectors from scripts 01-03.  
### Step 2: Compute L and G for each table (no HEM).               
### Step 3: Define batch scenarios in the SCENARIOS section.      
### Step 4: run_batch() loops over scenarios, calls               
###         simulate_shock() for each, collects results.            
### Step 5: Export one xlsx: one sheet per scenario + batch_summary.
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
u52_raw   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",       sheet = "interm_output_2024")
v52_raw   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",       sheet = "interm_input_2024")

io185_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "a_io185_2024")
x185_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "totaloutput_2024")
u185_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "interm_output_2024")
v185_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",     sheet = "interm_input_2024")

irio_raw  <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "a_irio_2024")
xirio_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "totaloutput_2024")
uirio_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "interm_output_2024")
virio_raw <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx", sheet = "interm_input_2024")



###-----------------------------------------------------------------
### SCENARIOS
### Define all shock scenarios here. Each entry is a list with:
###   label       : sheet name in output xlsx (no spaces)
###   table       : "IO52", "IO185", or "IRIO"
###   type        : "demand" (Leontief) or "supply" (Ghosh)
###   shock_value : shock size in Rp
###   target      : sector code, province code, or province-sector code
###   mode        : (IRIO only)
###                 "direct"          -> one province-sector pair
###                 "sector_national" -> one sector across all provinces
###                 "province_all"    -> all sectors in one province
###
### IO52 / IO185: mode not needed (always direct).
### IRIO: mode required.
###
### Examples below — edit freely before each run.
###-----------------------------------------------------------------

scenarios <- list(
  
  # IO 52: demand shock Rp 1T on sector I-10
  list(label = "IO52_demand_I10",    table = "IO52",  type = "demand",
       target = "I-10",              shock_value = 1),
  
  # IO 185: demand shock Rp 1T on sector 2
  list(label = "IO185_demand_I10",   table = "IO185", type = "demand",
       target = "2",              shock_value = 1),
  
  # IRIO: demand shock Rp 1T on sector I-29 in province 32 (Jawa Barat)
  list(label = "IRIO_demand_32_I29", table = "IRIO",  type = "demand",
       mode  = "direct",             target = "32-I-29", shock_value = 1),
  
  # IRIO: demand shock Rp 1T on sector I-10 distributed nationally
  list(label = "IRIO_demand_I10_nat",table = "IRIO",  type = "demand",
       mode  = "sector_national",    target = "I-01", shock_value = 1),
  
  # IRIO: supply shock Rp 1T across all sectors in province 94 (Papua)
  list(label = "IRIO_supply_prov94", table = "IRIO",  type = "supply",
       mode  = "province_all",       target = "94",   shock_value = 1)
  
)


###-----------------------------------------------------------------
### Helper functions
### mat_to_df / vec_to_df  : standardized export format
### leontief_inverse        : L = (I - A)^-1
### ghosh_B / ghosh_inverse : B matrix and G = (I - B)^-1
### build_shock_vector      : constructs delta_Y or delta_V
###                           given mode, target, shock_value
### simulate_shock          : single scenario runner
### run_batch               : loops over scenario list, exports xlsx
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

# <- Ghosh output coefficient matrix: B_ij = z_ij / x_i
ghosh_B <- function(A, X) {
  X_safe <- pmax(X, 1)
  B      <- sweep(A, 2, X_safe, "*")   # scale cols by x_j
  B      <- sweep(B, 1, X_safe, "/")   # scale rows by 1/x_i
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

# <- Build shock vector given mode, target, shock_value, and reference vector X
#    Returns named numeric vector of length n (same dimension as table).
#    Modes:
#      "direct"           : one entry nonzero at target (IO52, IO185, IRIO sector_province)
#      "sector_national"  : distribute shock across all province entries of target sector
#                           proportional to X share within that sector across provinces
#      "province_all"     : distribute shock across all sector entries of target province
#                           proportional to X share within that province across sectors
build_shock_vector <- function(codes, X, mode, target, shock_value) {
  delta <- setNames(rep(0, length(codes)), codes)
  
  if (mode == "direct") {
    if (!target %in% codes) stop("Target '", target, "' not found in table codes.")
    delta[target] <- shock_value
    
  } else if (mode == "sector_national") {
    # target = kodeIO (e.g. "I-29"), match all "provcode-I-29" entries
    matches <- codes[grepl(paste0("-", target, "$"), codes)]
    if (length(matches) == 0) stop("No IRIO entries found for sector '", target, "'.")
    shares        <- X[matches] / sum(X[matches])
    delta[matches] <- shock_value * shares
    
  } else if (mode == "province_all") {
    # target = kode_prov (e.g. "32"), match all "32-*" entries
    matches <- codes[grepl(paste0("^", target, "-"), codes)]
    if (length(matches) == 0) stop("No IRIO entries found for province '", target, "'.")
    shares        <- X[matches] / sum(X[matches])
    delta[matches] <- shock_value * shares
    
  } else {
    stop("Unknown mode: '", mode, "'. Use 'direct', 'sector_national', or 'province_all'.")
  }
  
  delta
}

# <- Single scenario simulation
#    Returns a list: $impact (sector-level data.frame), $total_impact, $top10
simulate_shock <- function(L, G, X, Y, V, type, mode, target, shock_value, label) {
  
  codes <- rownames(L)
  
  if (type == "demand") {
    delta   <- build_shock_vector(codes, X, mode, target, shock_value)
    impact  <- as.numeric(L %*% delta)           # delta_X = L %*% delta_Y
    
  } else if (type == "supply") {
    delta   <- build_shock_vector(codes, X, mode, target, shock_value)
    impact  <- as.numeric(delta %*% G)           # delta_X = delta_V %*% G (row vector)
    
  } else {
    stop("type must be 'demand' or 'supply'.")
  }
  
  impact_df <- data.frame(
    scenario     = label,
    kode         = codes,
    delta_input  = as.numeric(delta),
    delta_output = impact,
    X_baseline   = as.numeric(X[codes])
  ) %>%
    mutate(pct_of_baseline = delta_output / X_baseline * 100) %>%
    arrange(desc(abs(delta_output)))
  
  list(
    label        = label,
    impact       = impact_df,
    total_impact = sum(impact),
    top_sector   = impact_df$kode[1]
  )
}

# <- Batch runner: loops over scenarios list, exports one xlsx
#    Each scenario sheet = impact_df. Plus one "batch_summary" sheet.
run_batch <- function(scenarios, tables, output_name) {
  
  sheets       <- list()
  summary_rows <- list()
  
  for (sc in scenarios) {
    
    # resolve table objects
    tbl <- tables[[sc$table]]
    L   <- tbl$L
    G   <- tbl$G
    X   <- tbl$X
    Y   <- tbl$Y
    V   <- tbl$V
    
    # default mode = "direct" for IO52 and IO185
    mode <- if (!is.null(sc$mode)) sc$mode else "direct"
    
    cat("Running:", sc$label, "...\n")
    
    result <- simulate_shock(
      L = L, G = G, X = X, Y = Y, V = V,
      type        = sc$type,
      mode        = mode,
      target      = sc$target,
      shock_value = sc$shock_value,
      label       = sc$label
    )
    
    sheets[[sc$label]] <- result$impact
    
    summary_rows[[sc$label]] <- data.frame(
      label        = sc$label,
      table        = sc$table,
      type         = sc$type,
      mode         = mode,
      target       = sc$target,
      shock_value  = sc$shock_value,
      total_impact = result$total_impact,
      multiplier   = result$total_impact / sc$shock_value,
      top_sector   = result$top_sector
    )
    
    cat("  Done. Total impact: Rp", formatC(result$total_impact, format = "f", big.mark = ","), "\n")
  }
  
  # batch_summary sheet goes first
  sheets <- c(list(batch_summary = bind_rows(summary_rows)), sheets)
  
  openxlsx::write.xlsx(sheets, output_name)
  cat("Export complete:", output_name, "\n")
}


###-----------------------------------------------------------------
### Data prep: parse raw imports into A matrices, X, Y, V vectors
###-----------------------------------------------------------------

# <- IO 52
A_IO52  <- io52_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IO52) <- io52_raw$kode
X_IO52  <- setNames(x52_raw$totaloutput_2024,   x52_raw$kode)
U_IO52  <- setNames(u52_raw$interm_output_2024, u52_raw$kode)
V_IO52  <- setNames(v52_raw$interm_input_2024,  v52_raw$kode)
Y_IO52  <- X_IO52 - U_IO52                        # final demand vector

# <- IO 185
A_IO185 <- io185_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IO185) <- io185_raw$kode
X_IO185 <- setNames(x185_raw$totaloutput_2024,   x185_raw$kode)
U_IO185 <- setNames(u185_raw$interm_output_2024, u185_raw$kode)
V_IO185 <- setNames(v185_raw$interm_input_2024,  v185_raw$kode)
Y_IO185 <- X_IO185 - U_IO185

# <- IRIO 1768
A_IRIO  <- irio_raw %>% column_to_rownames("kode") %>% as.matrix() %>% apply(., 2, as.numeric)
rownames(A_IRIO) <- irio_raw$kode
X_IRIO  <- setNames(xirio_raw$totaloutput_2024,   xirio_raw$kode)
U_IRIO  <- setNames(uirio_raw$interm_output_2024, uirio_raw$kode)
V_IRIO  <- setNames(virio_raw$interm_input_2024,  virio_raw$kode)
Y_IRIO  <- X_IRIO - U_IRIO


###-----------------------------------------------------------------
### Compute L and G for each table (no HEM)
### IRIO: 1768x1768 inversion — may take several minutes
###-----------------------------------------------------------------

cat("Computing L and G: IO 52...\n")
L_IO52  <- leontief_inverse(A_IO52)
G_IO52  <- ghosh_inverse(ghosh_B(A_IO52, X_IO52))

cat("Computing L and G: IO 185...\n")
L_IO185 <- leontief_inverse(A_IO185)
G_IO185 <- ghosh_inverse(ghosh_B(A_IO185, X_IO185))

cat("Computing L and G: IRIO (1768x1768 — may take several minutes)...\n")
L_IRIO  <- leontief_inverse(A_IRIO)
G_IRIO  <- ghosh_inverse(ghosh_B(A_IRIO, X_IRIO))

# <- bundle all tables into one named list for run_batch()
tables <- list(
  IO52  = list(L = L_IO52,  G = G_IO52,  X = X_IO52,  Y = Y_IO52,  V = V_IO52),
  IO185 = list(L = L_IO185, G = G_IO185, X = X_IO185, Y = Y_IO185, V = V_IO185),
  IRIO  = list(L = L_IRIO,  G = G_IRIO,  X = X_IRIO,  Y = Y_IRIO,  V = V_IRIO)
)



###-----------------------------------------------------------------
### OUTPUT
### Edit output_name to customize the output file name.
###-----------------------------------------------------------------

run_batch(
  scenarios   = scenarios,
  tables      = tables,
  output_name = "01 Data/IO-IRIO-NA/output/updating_2024/Simulation results/v1_shock_simulation.xlsx"
)
