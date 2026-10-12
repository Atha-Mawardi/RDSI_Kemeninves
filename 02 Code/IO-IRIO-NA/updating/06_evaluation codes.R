###---------------------------------------------------------<
### 00. Extract Evaluation Values for PPT Documentation    
###                                                        
### Reads the evaluation sheets from all output xlsx files 
### (scripts 01, 02, 03) and prints a clean summary of    
### convergence metrics, consistency values, and key       
### multiplier statistics — formatted for copy-paste into  
### the LaTeX methodology presentation.                    
###                                                        
### Run this AFTER scripts 01-03 and 04 have completed.   
### Outputs: printed console report + eval_summary.txt    
###---------------------------------------------------------<

library(openxlsx)
library(dplyr)

output_file <- "eval_summary.txt"
sink(output_file)  # <- redirect all cat() output to file as well

cat("=======================================================\n")
cat("  EVALUATION SUMMARY FOR PPT DOCUMENTATION\n")
cat("  Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=======================================================\n\n")


###---------------------------------------------------------
### SCRIPT 01: IO 52 RAS Convergence
### Sheet: "eval" — row_consistency, column_consistency
###---------------------------------------------------------

cat("-----------------------------------------------------------\n")
cat("MODULE 1: IO 52 Updating (2020 -> 2024)\n")
cat("-----------------------------------------------------------\n")

tryCatch({
  eval_io52 <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",
    sheet = "eval"
  )
  cat("RAS internal consistency (should be near machine zero):\n")
  cat(sprintf("  Row consistency    (max |A*X - U|)  : %.4e\n",
              eval_io52$row_consistency[1]))
  cat(sprintf("  Column consistency (max |colS(AX)-V|): %.4e\n",
              eval_io52$column_consistency[1]))
  
  # <- also read X and Z to report sum totals for context
  x_io52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",
                                sheet = "totaloutput_2024")
  z_io52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",
                                sheet = "z_io52_2024")
  z_mat  <- z_io52 %>% select(-kode) %>% as.matrix() %>% apply(., 2, as.numeric)
  
  cat(sprintf("  Total output X (Rp)                 : %.6e\n",
              sum(x_io52$totaloutput_2024, na.rm = TRUE)))
  cat(sprintf("  Total intermediate flow Z (Rp)      : %.6e\n",
              sum(z_mat, na.rm = TRUE)))
}, error = function(e) {
  cat("  [ERROR] Could not read IO 52 eval sheet:", conditionMessage(e), "\n")
})

cat("\n")


###---------------------------------------------------------
### SCRIPT 02: IO 185 Disaggregation Consistency
### Sheet: "eval_summary" — max_diff, rel_diff, sum totals
###         "eval_diag"   — per-subsector diagonal deviations
###---------------------------------------------------------

cat("-----------------------------------------------------------\n")
cat("MODULE 2: IO 185 Disaggregation (52 -> 185 products)\n")
cat("-----------------------------------------------------------\n")

tryCatch({
  eval_io185_summary <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",
    sheet = "eval_summary"
  )
  eval_io185_diag <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(185x185).xlsx",
    sheet = "eval_diag"
  )
  
  cat("Disaggregation consistency (re-aggregate Z185 -> Z51, compare to Z51):\n")
  
  # Print all metrics from summary
  for (i in seq_len(nrow(eval_io185_summary))) {
    cat(sprintf("  %-40s: %s\n",
                eval_io185_summary$metric[i],
                eval_io185_summary$value[i]))
  }
  
  cat("\nTop 5 subsectors with largest diagonal discrepancy:\n")
  top5 <- head(eval_io185_diag %>% arrange(desc(abs_diff)), 5)
  for (i in seq_len(nrow(top5))) {
    cat(sprintf("  %-8s | Z51: %12.2f | Z51_check: %12.2f | abs_diff: %.4e\n",
                top5$sec51[i], top5$Z51_2024[i], top5$Z51_check[i], top5$abs_diff[i]))
  }
}, error = function(e) {
  cat("  [ERROR] Could not read IO 185 eval sheets:", conditionMessage(e), "\n")
})

cat("\n")


###---------------------------------------------------------
### SCRIPT 03: IRIO RAS Convergence
### Sheet: "eval" — row_consistency, col_consistency, total_X
###---------------------------------------------------------

cat("-----------------------------------------------------------\n")
cat("MODULE 3: IRIO 52 Updating (2016 -> 2024)\n")
cat("-----------------------------------------------------------\n")

tryCatch({
  eval_irio <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/v4_irio_2024(1768x1768).xlsx",
    sheet = "eval"
  )
  cat("RAS internal consistency (1768x1768 matrix):\n")
  cat(sprintf("  Row consistency    (max |A*X - U|)  : %.4e\n",
              eval_irio$row_consistency[1]))
  cat(sprintf("  Column consistency (max |colS(AX)-V|): %.4e\n",
              eval_irio$col_consistency[1]))
  cat(sprintf("  Total output X (Rp)                 : %.6e\n",
              eval_irio$total_X[1]))
}, error = function(e) {
  cat("  [ERROR] Could not read IRIO eval sheet:", conditionMessage(e), "\n")
})

cat("\n")


###---------------------------------------------------------
### Additional: RAS seed sector count from scripts 01 & 03
### (read A matrices, count zero-column sectors that were seeded)
###---------------------------------------------------------

cat("-----------------------------------------------------------\n")
cat("SEED SECTOR DIAGNOSTICS\n")
cat("-----------------------------------------------------------\n")

tryCatch({
  a_io52_base <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx", sheet = "a_io52_2020"
  )
  a_mat_base <- a_io52_base %>% select(-kode) %>% as.matrix() %>% apply(., 2, as.numeric)
  zero_cols  <- sum(colSums(abs(a_mat_base)) == 0)
  cat(sprintf("IO 52: zero-column sectors in 2020 A matrix (needed seed): %d\n", zero_cols))
}, error = function(e) {
  cat("  [SKIP] IO 52 seed count:", conditionMessage(e), "\n")
})

cat("\n")


###---------------------------------------------------------
### Multiplier summary statistics (from script 04 output)
### Sheet: "linkage" in each multiplier output file
###---------------------------------------------------------

cat("-----------------------------------------------------------\n")
cat("MODULE 4: MULTIPLIER & LINKAGE SUMMARY STATISTICS\n")
cat("-----------------------------------------------------------\n")

summarize_linkage <- function(path, sheet = "linkage", label) {
  tryCatch({
    df <- openxlsx::read.xlsx(path, sheet = sheet)
    cat(sprintf("\n%s:\n", label))
    cat(sprintf("  Sectors total                     : %d\n", nrow(df)))
    cat(sprintf("  Key sectors (BL>1 & FL>1)         : %d\n",
                sum(df$key_sector == "Key sector", na.rm = TRUE)))
    cat(sprintf("  Backward-dependent (BL>1, FL<=1)  : %d\n",
                sum(df$key_sector == "Backward-dependent", na.rm = TRUE)))
    cat(sprintf("  Forward-dependent  (BL<=1, FL>1)  : %d\n",
                sum(df$key_sector == "Forward-dependent", na.rm = TRUE)))
    cat(sprintf("  Independent        (BL<=1, FL<=1)  : %d\n",
                sum(df$key_sector == "Independent", na.rm = TRUE)))
    cat(sprintf("  HEM structurally important (nTL>1): %d\n",
                sum(df$nTL > 1, na.rm = TRUE)))
    cat(sprintf("  OM range                          : [%.3f, %.3f]\n",
                min(df$OM, na.rm = TRUE), max(df$OM, na.rm = TRUE)))
    cat(sprintf("  BL range                          : [%.3f, %.3f]\n",
                min(df$BL, na.rm = TRUE), max(df$BL, na.rm = TRUE)))
    cat(sprintf("  FL range                          : [%.3f, %.3f]\n",
                min(df$FL, na.rm = TRUE), max(df$FL, na.rm = TRUE)))
    cat(sprintf("  nTL range                         : [%.3f, %.3f]\n",
                min(df$nTL, na.rm = TRUE), max(df$nTL, na.rm = TRUE)))
    
    # Top 3 sectors by OM and nTL
    top_om  <- df %>% arrange(desc(OM))  %>% head(3)
    top_ntl <- df %>% arrange(desc(nTL)) %>% head(3)
    cat("  Top 3 by Output Multiplier (OM)   :",
        paste(top_om$kode,  sprintf("%.3f", top_om$OM),  sep = "=", collapse = ", "), "\n")
    cat("  Top 3 by Structural Importance (nTL):",
        paste(top_ntl$kode, sprintf("%.3f", top_ntl$nTL), sep = "=", collapse = ", "), "\n")
    
  }, error = function(e) {
    cat(sprintf("  [ERROR] %s: %s\n", label, conditionMessage(e)))
  })
}

summarize_linkage(
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IO52_2024.xlsx",
  label = "IO 52 (52 subsectors)"
)
summarize_linkage(
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IO185_2024.xlsx",
  label = "IO 185 (185 products)"
)
summarize_linkage(
  "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IRIO52_2024.xlsx",
  label = "IRIO 52 (1768 province-sectors)"
)

# <- IRIO: also report province-level stats
tryCatch({
  prov <- openxlsx::read.xlsx(
    "01 Data/IO-IRIO-NA/output/updating_2024/Multiplier results/v1_multiplier_linkage_IRIO52_2024.xlsx",
    sheet = "linkage_prov"
  )
  cat(sprintf("\n  IRIO Province-level (mean across subsectors):\n"))
  top3_prov <- prov %>% arrange(desc(nTL_mean)) %>% head(3)
  cat("  Top 3 provinces by mean nTL     :",
      paste(top3_prov$kode_prov, sprintf("%.3f", top3_prov$nTL_mean), sep = "=", collapse = ", "), "\n")
  cat(sprintf("  nTL_mean range across provinces : [%.3f, %.3f]\n",
              min(prov$nTL_mean, na.rm = TRUE), max(prov$nTL_mean, na.rm = TRUE)))
}, error = function(e) {
  cat("  [SKIP] IRIO province linkage:", conditionMessage(e), "\n")
})

cat("\n")
cat("=======================================================\n")
cat("  END OF SUMMARY — paste values into LaTeX PPT\n")
cat("=======================================================\n")

sink()  # <- close file redirect

# Also print to console
cat(readLines(output_file), sep = "\n")
cat("\n\n[Output also saved to:", output_file, "]\n")