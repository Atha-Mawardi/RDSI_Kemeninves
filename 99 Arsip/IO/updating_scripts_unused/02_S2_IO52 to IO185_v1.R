
###------------------------------------------------------###
### 02. Rescaling updated IO (52x52) into (185x185)      ###
### The second-stage part of achieving IO (185x185);     ###
### Full explanation can be accessed through             ###
###  "Technical notes.Rmd"                               ###
###------------------------------------------------------###

#-> import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> import data
A_io24.52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx",sheet = "a_irio_2024")
U_io24.52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx",sheet = "interm_output_2024",colNames = F)
V_io24.52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx",sheet = "interm_input_2024",colNames = F)
X_io24.52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/output/updating_2024/v1_io_2024(52x52).xlsx",sheet = "totaloutput_2024",colNames = F)
io185_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/io20.csv",header = T)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx",sheet = "Full_Concordance")
concord17_52 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx",sheet = "sec17-52")

head(io185_raw[, 185:187], 5)

io185_raw[, (ncol(io185_raw) - 2):ncol(io185_raw)][(nrow(io185_raw) - 2):nrow(io185_raw),]
io185_raw[, 1:2][(nrow(io185_raw) - 2):nrow(io185_raw),]
#-> 1. reversing 52x52 back into 51x51
# Since the concordance between the 52 and 185 classifications does not match 
# entirely (with no matching products for subsector I-46), we reversed our prior 
# calculation to align the new I-46 subsector with the 185-product list

# 1.1. reconstructing Z matrix
A <- as.matrix(A_io24.52)
X <- as.numeric(X_io24.52[[1]])
Z <- sweep(A, 2, X, "*")

# Tambahkan kolom Total Output & input
Z_ext <- cbind(Z, Total_Output = X)
Z_ext <- rbind(Z_ext,c(X, sum(X)))
Z_ext <- as.data.frame(Z_ext)

# 1.2. ro
Z_ext
