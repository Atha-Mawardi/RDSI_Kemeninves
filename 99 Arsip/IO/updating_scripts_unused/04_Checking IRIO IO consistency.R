
###------------------------------------------------------###
### 04. Evaluate and Adjusting for IO-IRIO consistency   ###
### Both data are derived from different base year;      ###
### IO -> 2020 value; IRIO -> 2016 value. Potential      ### 
### inconsistency might be observed                      ###
### after both updated into 2024 value. Thus, this script###
### tries to evaluate the consistency in results, namely:###
### the intermediate input/output and total output       ###
###------------------------------------------------------###

#-> Import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> Import hasil update
io_res   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",         sheet = "totaloutput_2024")
irio_res <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_irio_2024(1768x1768).xlsx",   sheet = "totaloutput_2024")
io_u     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",         sheet = "interm_output_2024")
io_v     <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v2_io_2024(52x52).xlsx",         sheet = "interm_input_2024")
irio_u   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_irio_2024(1768x1768).xlsx",   sheet = "interm_output_2024")
irio_v   <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_irio_2024(1768x1768).xlsx",   sheet = "interm_input_2024")

#-> Ekstrak kode sektor dari kode IRIO (format: "{kode_prov}-{kode_sektor}", misal "11-I-01")
irio_res <- irio_res %>% mutate(sec52 = sub("^[0-9]+-", "", kode))
irio_u   <- irio_u   %>% mutate(sec52 = sub("^[0-9]+-", "", kode))
irio_v   <- irio_v   %>% mutate(sec52 = sub("^[0-9]+-", "", kode))

#-> Agregasi IRIO ke level nasional per sektor
irio_nat_x <- irio_res %>% group_by(sec52) %>% summarise(x_irio = sum(totaloutput_2024),   .groups = "drop")
irio_nat_u <- irio_u   %>% group_by(sec52) %>% summarise(u_irio = sum(interm_output_2024), .groups = "drop")
irio_nat_v <- irio_v   %>% group_by(sec52) %>% summarise(v_irio = sum(interm_input_2024),  .groups = "drop")

#-> Rename IO columns untuk join
io_nat_x <- io_res %>% rename(sec52 = kode, x_io = totaloutput_2024)
io_nat_u <- io_u   %>% rename(sec52 = kode, u_io = interm_output_2024)
io_nat_v <- io_v   %>% rename(sec52 = kode, v_io = interm_input_2024)

#-> Gabungkan & hitung gap
compare <- io_nat_x %>%
  left_join(irio_nat_x, by = "sec52") %>%
  left_join(io_nat_u,   by = "sec52") %>%
  left_join(irio_nat_u, by = "sec52") %>%
  left_join(io_nat_v,   by = "sec52") %>%
  left_join(irio_nat_v, by = "sec52") %>%
  mutate(
    gap_x     = x_irio - x_io,
    gap_x_pct = gap_x / x_io * 100,
    gap_u     = u_irio - u_io,
    gap_u_pct = gap_u / u_io * 100,
    gap_v     = v_irio - v_io,
    gap_v_pct = gap_v / v_io * 100
  )

#-> Print ringkasan
cat("=== Summary: max absolute relative gap ===\n")
cat("Total output (X) :", round(max(abs(compare$gap_x_pct), na.rm = TRUE), 4), "%\n")
cat("Interm output (U):", round(max(abs(compare$gap_u_pct), na.rm = TRUE), 4), "%\n")
cat("Interm input  (V):", round(max(abs(compare$gap_v_pct), na.rm = TRUE), 4), "%\n")

#-> Export
openxlsx::write.xlsx(
  list(comparison = compare),
  "01 Data/IO-IRIO-NA/output/updating_2024/v3_consistency_IO_vs_IRIO.xlsx"
)
