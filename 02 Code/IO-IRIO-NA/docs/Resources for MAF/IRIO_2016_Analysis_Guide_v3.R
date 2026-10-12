# =============================================================================
# INTER-REGIONAL INPUT-OUTPUT (IRIO) ANALYSIS
# Indonesia IRIO 2016 - 52 Sectors x 34 Provinces
# =============================================================================
# Source: Tabel Inter Regional Input-Output Indonesia
#         Transaksi Domestik Atas Dasar Harga Produsen
#         Menurut 34 Provinsi dan 52 Industri, 2016 (Juta Rupiah)
# =============================================================================


# -----------------------------------------------------------------------------
# STEP 0: INSTALL AND LOAD REQUIRED PACKAGES
# -----------------------------------------------------------------------------
# Run this block only once if packages are not yet installed.

install.packages(c("readxl", "openxlsx", "Matrix", "dplyr", "tidyr"))

library(readxl)       # Reading .xlsx files
library(openxlsx)     # Writing results to .xlsx files
library(Matrix)       # Efficient matrix operations
library(dplyr)        # Data manipulation
library(tidyr)        # Data reshaping


# -----------------------------------------------------------------------------
# STEP 1: SET WORKING DIRECTORY AND FILE PATH
# -----------------------------------------------------------------------------
# Set your working directory to the folder containing the IRIO Excel file.
# Set working directory
setwd("C:/Users/Muhammad Aulia/CPI/SP-Program - 1. Projects (Contracts, Slide Decks, Studies, Reports)/85078 ViriyaENB_CoalTransition/Implementation Phase/04 Working File/02 Economic Assessment/irio2016")

# Define file path
file_path <- "C:/Users/Muhammad Aulia/CPI/SP-Program - 1. Projects (Contracts, Slide Decks, Studies, Reports)/85078 ViriyaENB_CoalTransition/Implementation Phase/04 Working File/02 Economic Assessment/irio2016/IRIO 52 Industri -Harga Produsen - 2016.xlsx"

# Sheet name in the Excel file
sheet_name <- "IRIO-PDD (52x52)"


# -----------------------------------------------------------------------------
# STEP 2: DEFINE DIMENSIONS
# -----------------------------------------------------------------------------
# The IRIO table has 34 provinces and 52 sectors.
# Total rows/columns in the Z (intermediate flow) block = 34 x 52 = 1,768

n_provinces <- 34
n_sectors   <- 52
n           <- n_provinces * n_sectors   # 1,768 — total number of region-sector pairs

# Province codes and names (in order as they appear in the table)
province_names <- c(
  "11. Aceh", "12. Sumatera Utara", "13. Sumatera Barat", "14. Riau",
  "15. Jambi", "16. Sumatera Selatan", "17. Bengkulu", "18. Lampung",
  "19. Kep. Bangka Belitung", "21. Kep. Riau", "31. DKI Jakarta",
  "32. Jawa Barat", "33. Jawa Tengah", "34. DI Yogyakarta", "35. Jawa Timur",
  "36. Banten", "51. Bali", "52. Nusa Tenggara Barat", "53. Nusa Tenggara Timur",
  "61. Kalimantan Barat", "62. Kalimantan Tengah", "63. Kalimantan Selatan",
  "64. Kalimantan Timur", "65. Kalimantan Utara", "71. Sulawesi Utara",
  "72. Sulawesi Tengah", "73. Sulawesi Selatan", "74. Sulawesi Tenggara",
  "75. Gorontalo", "76. Sulawesi Barat", "81. Maluku", "82. Maluku Utara",
  "91. Papua Barat", "94. Papua"
)

# Sector codes and names (in order as they appear in the table)
sector_codes <- paste0("I-", sprintf("%02d", 1:52))

sector_names <- c(
  "Pertanian Tanaman Pangan",
  "Pertanian Tanaman Hortikultura Semusim, Hortikultura Tahunan, dan Lainnya",
  "Perkebunan Semusim dan Tahunan",
  "Peternakan",
  "Jasa Pertanian dan Perburuan",
  "Kehutanan dan Penebangan Kayu",
  "Perikanan",
  "Pertambangan Minyak, Gas dan Panas Bumi",
  "Pertambangan Batubara dan Lignit",
  "Pertambangan Bijih Logam",
  "Pertambangan dan Penggalian Lainnya",
  "Industri Batubara dan Pengilangan Migas",
  "Industri Makanan dan Minuman",
  "Industri Pengolahan Tembakau",
  "Industri Tekstil dan Pakaian Jadi",
  "Industri Kulit, Barang dari Kulit dan Alas Kaki",
  "Industri Kayu, Barang dari Kayu dan Gabus dan Barang Anyaman",
  "Industri Kertas dan Barang dari Kertas, Percetakan dan Reproduksi Media Rekaman",
  "Industri Kimia, Farmasi dan Obat Tradisional",
  "Industri Karet, Barang dari Karet dan Plastik",
  "Industri Barang Galian bukan Logam",
  "Industri Logam Dasar",
  "Industri Barang dari Logam, Komputer, Barang Elektronik, Optik dan Peralatan Listrik",
  "Industri Mesin dan Perlengkapan YTDL",
  "Industri Alat Angkutan",
  "Industri Furnitur",
  "Industri Pengolahan Lainnya, Jasa Reparasi dan Pemasangan Mesin dan Peralatan",
  "Ketenagalistrikan",
  "Pengadaan Gas dan Produksi Es",
  "Pengadaan Air, Pengelolaan Sampah, Limbah, dan Daur Ulang",
  "Konstruksi",
  "Perdagangan Mobil, Sepeda Motor dan Reparasinya",
  "Perdagangan Besar dan Eceran, Bukan Mobil dan Sepeda Motor",
  "Angkutan Rel",
  "Angkutan Darat",
  "Angkutan Laut",
  "Angkutan Sungai Danau dan Penyeberangan",
  "Angkutan Udara",
  "Pergudangan dan Jasa Penunjang Angkutan, Pos dan Kurir",
  "Penyediaan Akomodasi",
  "Penyediaan Makan Minum",
  "Jasa Informasi dan Komunikasi",
  "Jasa Perantara Keuangan Selain Bank Sentral",
  "Asuransi dan Dana Pensiun",
  "Jasa Keuangan Lainnya",
  "Jasa Penunjang Keuangan",
  "Real Estate",
  "Jasa Perusahaan",
  "Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib",
  "Jasa Pendidikan",
  "Jasa Kesehatan dan Kegiatan Sosial",
  "Jasa Lainnya"
)

# Build region-sector labels used as row/column names throughout the analysis
# Format: "ProvinceCode_SectorCode", e.g. "11.Aceh_I-01"

rs_labels <- as.vector(sapply(province_names,
                              function(p) paste0(p, "_", sector_codes)))

# rs_labels has length 1,768 (34 provinces × 52 sectors), ordered province-first


# -----------------------------------------------------------------------------
# STEP 3: LOAD THE IRIO EXCEL FILE
# -----------------------------------------------------------------------------
# The raw Excel file has:
#   - Rows 1–5  (0-indexed: 0–4): Header rows (title, province, sector names, codes)
#   - Row 6     (0-indexed: 5):   Sector code row
#   - Rows 7 to 1774 (Excel): Data rows — 34×52 = 1,768 region-sector observations
#   - Rows 1775–1783:          Value-added and totals (not part of Z block)
#
# Columns (Excel):
#   - Cols A–D  (indices 1–4):  Metadata (province, sector description, code)
#   - Cols E to BZL (indices 5 to 1772): Z block — 1,768 intermediate flow columns
#   - Cols BZM onwards:        Final demand, exports, total output
#   - Last column (index 1954 / code "6000"): Total Output (x)
#
# In R (readxl), rows and columns are 1-indexed.
# We read the full sheet without a header to preserve the raw layout.

cat("Loading IRIO Excel file...\n")

raw <- read_excel(
  path      = file_path,
  sheet     = sheet_name,
  col_names = FALSE,   # Do not interpret any row as header
  col_types = "text"   # Read everything as text first to avoid type coercion
)

cat("File loaded. Dimensions:", nrow(raw), "rows x", ncol(raw), "cols\n")
# Expected: 1783 rows x 1953 columns


# -----------------------------------------------------------------------------
# STEP 4: EXTRACT THE Z MATRIX (Intermediate Flow Matrix)
# -----------------------------------------------------------------------------
# Layout (1-indexed in R):
#   Data rows  : rows 7 to 1774  (1,768 rows = 34 provinces x 52 sectors)
#   Z columns  : cols 5 to 1772  (1,768 columns = 34 provinces x 52 sectors)
#   Total Output: col 1953 - adjusted from v1 = 1954 

row_start <- 7       # First data row (row 6 in Excel = row 7 in R, 1-indexed)
row_end   <- 1774    # Last data row  (row 1773 in Excel = row 1774 in R)
col_start <- 5       # First Z column (col E in Excel = col 5 in R)
col_end   <- 1772    # Last Z column  (col BZL in Excel)
col_x     <- 1953    # Total Output column ("6000")

cat("Extracting Z matrix (intermediate flows)...\n")

Z_raw <- raw[row_start:row_end, col_start:col_end]
Z     <- matrix(as.numeric(as.matrix(Z_raw)),
                nrow = n, ncol = n)

# Replace any NA with 0 (structural zeros in sparse IRIO tables)
Z[is.na(Z)] <- 0

rownames(Z) <- rs_labels
colnames(Z) <- rs_labels

cat("Z matrix extracted. Dimensions:", nrow(Z), "x", ncol(Z), "\n")
# Expected: 1768 x 1768


# -----------------------------------------------------------------------------
# STEP 5: EXTRACT TOTAL OUTPUT VECTOR (x)
# -----------------------------------------------------------------------------
# Total Output (x_i) is in the last column of the raw table ("Total Output / 6000")
# and corresponds to the same 1,768 data rows.

cat("Extracting Total Output vector (x)...\n")

x <- as.numeric(as.matrix(raw[row_start:row_end, col_x]))
x[is.na(x)] <- 0
names(x) <- rs_labels

cat("Total Output vector extracted. Length:", length(x), "\n")
# Quick sanity check: print first 5 values
cat("First 5 Total Output values (Juta Rupiah):\n")
print(head(x, 5))


# -----------------------------------------------------------------------------
# STEP 6: COMPUTE THE A MATRIX (Technical Coefficients / Direct Input Matrix)
# -----------------------------------------------------------------------------
# The A matrix is derived from Z by dividing each column j by its total output x_j:
#
#   a_ij = z_ij / x_j
#
# where z_ij = intermediate input purchased by sector j from sector i,
# and   x_j  = total output of sector j.
#
# Each column of A represents the input structure of one region-sector unit.
# A is an (n x n) matrix, here 1768 x 1768.
#
# Note: If x_j = 0 (no output), set a_ij = 0 to avoid division by zero.

cat("Computing A matrix (technical coefficients)...\n")

# Construct a diagonal matrix of 1/x_j for safe inversion
x_inv <- ifelse(x > 0, 1 / x, 0)

# A = Z %*% diag(1/x)  — column-wise division of Z by x
A <- Z %*% diag(x_inv)

rownames(A) <- rs_labels
colnames(A) <- rs_labels

cat("A matrix computed. Dimensions:", nrow(A), "x", ncol(A), "\n")

# Verify: column sums should all be < 1 (share of intermediate inputs in total output)
col_sum_A <- colSums(A)
cat("A matrix column sums — Min:", round(min(col_sum_A), 4),
    " Max:", round(max(col_sum_A), 4),
    " Mean:", round(mean(col_sum_A), 4), "\n")
# All values should be in [0, 1) for a valid IO table


# -----------------------------------------------------------------------------
# STEP 7: COMPUTE THE LEONTIEF INVERSE MATRIX (L)
# -----------------------------------------------------------------------------
# The Leontief inverse (also called the total requirements matrix) is:
#
#   L = (I - A)^{-1}
#
# where I is the identity matrix.
#
# L_ij gives the total output required from sector i (in region r) per unit
# of final demand for sector j (in region s), capturing all direct and
# indirect production linkages across all regions.
#
# Because this is a 1768 x 1768 matrix, direct inversion via solve() is
# feasible but memory-intensive (~24 GB for dense double). We use solve()
# which applies LU decomposition — ensure your machine has sufficient RAM
# (at least 32 GB recommended for the full IRIO). If memory is limited,
# see the sparse matrix alternative commented below.

cat("Computing Leontief inverse L = (I - A)^(-1)...\n")
cat("This may take several minutes for a 1768x1768 matrix.\n")

I_mat <- diag(n)   # Identity matrix, 1768 x 1768

# ----- Standard dense inversion (requires ~24 GB RAM) -----
#L <- solve(I_mat - A) *not used for now

# ----- Sparse alternative (lower memory, slower for dense A) -----
library(Matrix)
A_sparse   <- Matrix(A, sparse = TRUE)
I_sparse   <- Diagonal(n)
ImA_sparse <- I_sparse - A_sparse
L          <- as.matrix(solve(ImA_sparse))

rownames(L) <- rs_labels
colnames(L) <- rs_labels

cat("Leontief inverse computed. Dimensions:", nrow(L), "x", ncol(L), "\n")

# Verify: diagonal elements should be >= 1 (a sector always requires at least
# 1 unit of its own output to produce 1 unit for final demand)
cat("L diagonal — Min:", round(min(diag(L)), 4),
    " Max:", round(max(diag(L)), 4), "\n")


# -----------------------------------------------------------------------------
# STEP 8: COMPUTE BACKWARD LINKAGES (Output Multipliers)
# -----------------------------------------------------------------------------
# Backward linkages measure how much total production across ALL sectors and
# regions is stimulated when final demand for sector j (in region r) increases
# by one unit.
#
# SIMPLE BACKWARD LINKAGE (column sum of L):
#   BL_j = sum_i L_ij   for each column j
#
# This is equivalent to the standard output multiplier. A higher BL indicates
# that sector j relies more heavily on inputs from other sectors.
#
# NORMALIZED BACKWARD LINKAGE (Rasmussen, 1956):
#   BL_norm_j = (1/n) * BL_j / ((1/n^2) * sum_i sum_j L_ij)
#             = n * BL_j / sum(L)
#
# A normalized BL > 1 means the sector has above-average backward linkage.

cat("Computing Backward Linkages...\n")

# Simple backward linkage (output multiplier per region-sector)
BL_simple <- colSums(L)
names(BL_simple) <- rs_labels

# Normalized backward linkage (Rasmussen)
L_grand_mean <- mean(L)   # mean of all 1768^2 elements
BL_norm      <- BL_simple / (n * L_grand_mean)
names(BL_norm) <- rs_labels

cat("Backward Linkages computed.\n")
cat("BL Simple — Min:", round(min(BL_simple), 4),
    " Max:", round(max(BL_simple), 4),
    " Mean:", round(mean(BL_simple), 4), "\n")
cat("BL Normalized — Sectors with BL > 1 (above average):",
    sum(BL_norm > 1), "\n")


# -----------------------------------------------------------------------------
# STEP 9: COMPUTE FORWARD LINKAGES (Income / Supply Multipliers)
# -----------------------------------------------------------------------------
# Forward linkages measure how much total production across ALL sectors and
# regions is stimulated when the PRIMARY INPUT (value added) in sector i
# increases by one unit — i.e., how much sector i supplies to downstream users.
#
# METHOD 1 — Ghosh Supply-Side Model (row sum of Leontief inverse):
#   Using the Ghosh inverse G = (I - B)^(-1), where B_ij = z_ij / x_i
#   FL_i = sum_j G_ij
#
# METHOD 2 — Row sum of Leontief inverse (Cella (1984) / Clements (1990) approach):
#   FL_i = sum_j L_ij   (row sum)
#   This approximation is widely used in IRIO studies.

cat("Computing Forward Linkages...\n")

# --- Method 2: Row sum of Leontief inverse (simpler approximation) ---
FL_leontief <- rowSums(L)
names(FL_leontief) <- rs_labels

# Normalized forward linkage (Rasmussen, Cella/Clements, row-sum based)
FL_leontief_norm <- FL_leontief / (n * L_grand_mean)
names(FL_leontief_norm) <- rs_labels

cat("Forward Linkages computed.\n")
cat("FL (Cella/Clements) — Min:", round(min(FL_leontief), 4),
    " Max:", round(max(FL_leontief), 4),
    " Mean:", round(mean(FL_leontief), 4), "\n")
cat("FL Normalized — Sectors with FL > 1 (above average):",
    sum(FL_leontief_norm > 1), "\n")

#NOT USED FOR NOW
# --- Method 1: Ghosh inverse ---
# Output coefficient matrix B: b_ij = z_ij / x_i (row-wise division)
#x_row_inv <- ifelse(x > 0, 1 / x, 0)
#B         <- diag(x_row_inv) %*% Z   # B = diag(1/x) %*% Z

#cat("Computing Ghosh inverse G = (I - B)^(-1)...\n")
#G <- solve(I_mat - B)

#rownames(G) <- rs_labels
#colnames(G) <- rs_labels

#FL_ghosh      <- rowSums(G)
#FL_ghosh_norm <- FL_ghosh / (n * mean(G))
#names(FL_ghosh)      <- rs_labels
#names(FL_ghosh_norm) <- rs_labels

#cat("Forward Linkages computed.\n")
#cat("FL Ghosh — Min:", round(min(FL_ghosh), 4),
 #   " Max:", round(max(FL_ghosh), 4),
  #  " Mean:", round(mean(FL_ghosh), 4), "\n")
#cat("FL Normalized (Ghosh) — Sectors with FL > 1 (above average):",
 #   sum(FL_ghosh_norm > 1), "\n")


# -----------------------------------------------------------------------------
# STEP 10: SECTOR CLASSIFICATION (Key Sectors)
# -----------------------------------------------------------------------------
# Using normalized Backward and Forward linkages, sectors are classified into
# four quadrants (Hirschman-Rasmussen classification):
#
#   Key / Base sectors      : BL > 1 AND FL > 1  → strong links both ways
#   Forward-oriented        : BL < 1 AND FL > 1  → mainly supply-side drivers
#   Backward-oriented       : BL > 1 AND FL < 1  → mainly demand-side drivers
#   Independent / Weak      : BL < 1 AND FL < 1  → weak linkages in both directions

cat("Classifying sectors by linkage type...\n")

classification <- case_when(
  BL_norm > 1 & FL_leontief_norm > 1 ~ "Key Sector (BL>1, FL>1)",
  BL_norm < 1 & FL_leontief_norm > 1 ~ "Forward-Oriented (BL<1, FL>1)",
  BL_norm > 1 & FL_leontief_norm < 1 ~ "Backward-Oriented (BL>1, FL<1)",
  TRUE                                ~ "Independent (BL<1, FL<1)"
)

linkage_summary <- data.frame(
  Region_Sector    = rs_labels,
  Province         = rep(province_names, each = n_sectors),
  Sector_Code      = rep(sector_codes, times = n_provinces),
  Sector_Name      = rep(sector_names, times = n_provinces),
  BL_Simple        = round(BL_simple, 6),
  BL_Normalized    = round(BL_norm, 6),
  FL_Leontief      = round(FL_leontief, 6),
  FL_Leontief_Norm = round(FL_leontief_norm, 6),
  Classification   = classification,
  stringsAsFactors = FALSE
)

cat("Classification distribution:\n")
print(table(linkage_summary$Classification))



# -----------------------------------------------------------------------------
# STEP 11: OUTPUT MULTIPLIER ANALYSIS — COAL MINING (I-09) DEMAND SHOCKS
#          Six annual scenarios, 2025–2030
# -----------------------------------------------------------------------------
# Context:
#   Each shock represents an exogenous DECLINE in final demand for sector I-09
#   (Pertambangan Batubara dan Lignit) across ALL 34 provinces, reflecting
#   projected coal demand reductions from 2025 to 2030.
#
# Methodology:
#   The total output response is computed as:
#       delta_x = L %*% delta_f
#   where:
#     delta_f = shock vector of length n (1,768), with non-zero entries only
#               at the 34 rows corresponding to sector I-09 in each province.
#     L       = Leontief inverse matrix (1,768 x 1,768)
#     delta_x = vector of output changes for ALL region-sector pairs (direct
#               + all indirect / upstream propagation effects)
#
# Shock distribution — proportionate to provincial output share in I-09:
#   Each province p receives a share of the total annual shock proportional
#   to its share of national total output in sector I-09:
#
#     share_p = x_{p, I-09} / sum_p( x_{p, I-09} )
#     delta_f_{p, I-09} = total_shock * share_p
#
#   Provinces with zero I-09 output receive a zero shock.
#   This reflects the economic reality that regions producing more coal
#   bear a proportionately larger demand contraction.
#
# Direct vs. Indirect impact decomposition:
#   Direct impact  : the shock value applied to each I-09 row (delta_f).
#                    Zero for all non-I-09 rows.
#   Indirect impact: delta_x minus the direct component — all output changes
#                    propagated to other sectors and regions through
#                    backward supply-chain linkages.
#
# Shock values (Juta Rupiah, negative = demand reduction):
#   shock_value25 = -401,041,894.4   (Year 2025)
#   shock_value26 = -415,333,651.9   (Year 2026)
#   shock_value27 = -427,055,889.5   (Year 2027)
#   shock_value28 = -433,792,604.3   (Year 2028)
#   shock_value29 = -437,794,810.1   (Year 2029)
#   shock_value30 = -438,877,719.6   (Year 2030)

cat("Running coal sector (I-09) shock analysis for 2025-2030...\n")

# ---- Define shock values per year ----
shock_value25 <- -401041894.4   # Year 2025
shock_value26 <- -415333651.9   # Year 2026
shock_value27 <- -427055889.5   # Year 2027
shock_value28 <- -433792604.3   # Year 2028
shock_value29 <- -437794810.1   # Year 2029
shock_value30 <- -438877719.6   # Year 2030

# Collect into a named list for loop processing
shock_scenarios <- list(
  "2025" = shock_value25,
  "2026" = shock_value26,
  "2027" = shock_value27,
  "2028" = shock_value28,
  "2029" = shock_value29,
  "2030" = shock_value30
)

years <- names(shock_scenarios)

# ---- Identify I-09 indices in rs_labels ----
# There should be exactly 34 matches (one per province)
target_sector_shock <- "I-09"
idx_I09 <- which(grepl(paste0("_", target_sector_shock, "$"), rs_labels))

cat("Number of I-09 entries found (should be 34):", length(idx_I09), "\n")
cat("I-09 region-sector labels:\n")
print(rs_labels[idx_I09])

# ---- Compute provincial output shares for sector I-09 ----
# x[idx_I09] gives the total output of I-09 for each of the 34 provinces,
# in the same order as province_names.
x_I09        <- x[idx_I09]
x_I09_total  <- sum(x_I09)

# Share of each province in national I-09 output (sums to 1).
# The condition must be element-wise (over x_I09, not x_I09_total) so that
# the result is always a length-34 vector matching province_names.
# Provinces with zero I-09 output receive a zero share and therefore a zero
# shock in delta_f — they are still affected by the shock indirectly through
# the Leontief inverse, as other provinces' demand contractions propagate
# through inter-regional supply-chain linkages.
province_share_I09 <- as.numeric(ifelse(x_I09 > 0, x_I09 / x_I09_total, 0))


cat("Provincial I-09 output shares (top 10 by share):\n")
print(round(sort(province_share_I09, decreasing = TRUE)[1:10], 6))
cat("Provinces with zero I-09 output (indirect effect only):\n")
print(province_names[x_I09 == 0])
cat("Sum of shares (should equal 1):", round(sum(province_share_I09), 8), "\n")


# ---- Run shocks and store results ----
# For each year, build the shock vector, compute delta_x, then decompose into
# direct and indirect components.

shock_results_list <- list()   # Will hold one data frame per year

for (yr in years) {
  
  total_shock <- shock_scenarios[[yr]]
  
  # Each province receives its output-share-proportionate slice of the total shock
  shock_by_province <- as.numeric(total_shock * province_share_I09)
  # Build shock vector (length 1768): non-zero only at I-09 positions
  
  delta_f <- rep(0, n)
  delta_f[idx_I09] <- shock_by_province   # positional: idx_I09[k] <- share[k]
  # Compute total output response (direct + indirect)
  delta_x <- as.numeric(L %*% delta_f)
  names(delta_x) <- rs_labels
  
  # ---- Direct impact ----
  # The direct impact is the first-round output loss in sector I-09 itself.
  # Defined as the shock value applied to each I-09 row (i.e., delta_f).
  
  # For all non-I-09 rows, direct impact = 0.
  direct_impact <- rep(0, n)
  direct_impact[idx_I09] <- delta_f[idx_I09]
  
  # ---- Indirect impact ----
  # All output changes beyond the direct first-round effect, i.e., the
  # propagation through upstream and downstream supply-chain linkages.
  indirect_impact <- delta_x - direct_impact
  
  # ---- Assemble results data frame ----
  shock_results_list[[yr]] <- data.frame(
    Year                      = as.integer(yr),
    Region_Sector             = rs_labels,
    Province                  = rep(province_names, each = n_sectors),
    Sector_Code               = rep(sector_codes, times = n_provinces),
    Sector_Name               = rep(sector_names, times = n_provinces),
    I09_Output_Share          = rep(round(province_share_I09, 8), each = n_sectors),
    Shock_Applied_Juta_Rp     = round(delta_f, 4),
    Direct_Impact_Juta_Rp     = round(direct_impact, 4),
    Indirect_Impact_Juta_Rp   = round(indirect_impact, 4),
    Total_Impact_Juta_Rp      = round(delta_x, 4),
    stringsAsFactors = FALSE
  )
  
  cat(sprintf(
    "Year %s | Shock: %+.1f Juta Rp | Total output response: %+.2f Juta Rp | Multiplier: %.4f\n",
    yr,
    total_shock,
    sum(delta_x),
    sum(delta_x) / total_shock
  ))
}

# Combine all years into one long-format data frame
all_shock_results <- bind_rows(shock_results_list)

cat("Shock analysis complete. Total rows in combined results:",
    nrow(all_shock_results), "\n")
# Expected: 6 years x 1768 region-sectors = 10,608 rows


# -----------------------------------------------------------------------------
# STEP 12: AGGREGATE LINKAGES AND SHOCK IMPACTS
# -----------------------------------------------------------------------------

cat("Aggregating linkages by sector (national average)...\n")

# ---- 12a: Backward / forward linkage aggregation ----

sector_agg <- linkage_summary %>%
  group_by(Sector_Code, Sector_Name) %>%
  summarise(
    BL_Simple_Mean        = round(mean(BL_Simple), 6),
    BL_Normalized_Mean    = round(mean(BL_Normalized), 6),
    FL_Leontief_Mean      = round(mean(FL_Leontief), 6),
    FL_Leontief_Norm_Mean = round(mean(FL_Leontief_Norm), 6),
    Key_Sector_Count      = sum(Classification == "Key Sector (BL>1, FL>1)"),
    .groups = "drop"
  ) %>%
  arrange(desc(BL_Normalized_Mean))

province_agg <- linkage_summary %>%
  group_by(Province) %>%
  summarise(
    BL_Simple_Mean        = round(mean(BL_Simple), 6),
    BL_Normalized_Mean    = round(mean(BL_Normalized), 6),
    FL_Leontief_Mean      = round(mean(FL_Leontief), 6),
    FL_Leontief_Norm_Mean = round(mean(FL_Leontief_Norm), 6),
    Key_Sector_Count      = sum(Classification == "Key Sector (BL>1, FL>1)"),
    .groups = "drop"
  ) %>%
  arrange(desc(BL_Normalized_Mean))

cat("Linkage aggregations complete.\n")

# ---- 12b: Aggregate shock impacts for the Consolidated Summary sheet ----

# Summary by PROVINCE x YEAR — total direct, indirect, and combined impacts
summary_by_province <- all_shock_results %>%
  group_by(Year, Province) %>%
  summarise(
    Direct_Impact_Juta_Rp   = round(sum(Direct_Impact_Juta_Rp), 4),
    Indirect_Impact_Juta_Rp = round(sum(Indirect_Impact_Juta_Rp), 4),
    Total_Impact_Juta_Rp    = round(sum(Total_Impact_Juta_Rp), 4),
    .groups = "drop"
  )

# Summary by SECTOR x YEAR — aggregated across all provinces
summary_by_sector <- all_shock_results %>%
  group_by(Year, Sector_Code, Sector_Name) %>%
  summarise(
    Direct_Impact_Juta_Rp   = round(sum(Direct_Impact_Juta_Rp), 4),
    Indirect_Impact_Juta_Rp = round(sum(Indirect_Impact_Juta_Rp), 4),
    Total_Impact_Juta_Rp    = round(sum(Total_Impact_Juta_Rp), 4),
    .groups = "drop"
  )

# National totals by YEAR — single row per year
summary_national <- all_shock_results %>%
  group_by(Year) %>%
  summarise(
    Total_Shock_Applied_Juta_Rp = round(sum(Shock_Applied_Juta_Rp), 4),
    Direct_Impact_Juta_Rp       = round(sum(Direct_Impact_Juta_Rp), 4),
    Indirect_Impact_Juta_Rp     = round(sum(Indirect_Impact_Juta_Rp), 4),
    Total_Impact_Juta_Rp        = round(sum(Total_Impact_Juta_Rp), 4),
    Output_Multiplier           = round(sum(Total_Impact_Juta_Rp) /
                                          sum(Shock_Applied_Juta_Rp), 6),
    .groups = "drop"
  )


# Wide-format pivot: Province rows x Year columns (Total Impact)
summary_province_wide <- summary_by_province %>%
  select(Province, Year, Total_Impact_Juta_Rp) %>%
  pivot_wider(names_from = Year,
              names_prefix = "Total_Impact_",
              values_from = Total_Impact_Juta_Rp) %>%
  mutate(Cumulative_2025_2030 = rowSums(across(starts_with("Total_Impact_")),
                                        na.rm = TRUE)) %>%
  arrange(Cumulative_2025_2030)

# Wide-format pivot: Sector rows x Year columns (Total Impact)
summary_sector_wide <- summary_by_sector %>%
  select(Sector_Code, Sector_Name, Year, Total_Impact_Juta_Rp) %>%
  pivot_wider(names_from = Year,
              names_prefix = "Total_Impact_",
              values_from = Total_Impact_Juta_Rp) %>%
  mutate(Cumulative_2025_2030 = rowSums(across(starts_with("Total_Impact_")),
                                        na.rm = TRUE)) %>%
  arrange(Cumulative_2025_2030)

cat("Shock impact aggregations complete.\n")


# -----------------------------------------------------------------------------
# STEP 13: EXPORT ALL RESULTS TO EXCEL
# -----------------------------------------------------------------------------
# Workbook layout:
#   Sheet 1 : Linkage_Summary          (unchanged — full 1768-row BL/FL table)
#   Sheet 2 : Sector_Aggregation       (unchanged — BL/FL by 52 sectors)
#   Sheet 3 : Province_Aggregation     (unchanged — BL/FL by 34 provinces)
#   Sheet 4 : Shock_Detail_All_Years   (long-format: all years x region-sectors)
#   Sheet 5 : Shock_By_Province_Year   (direct, indirect, total by province x year)
#   Sheet 6 : Shock_By_Sector_Year     (direct, indirect, total by sector x year)
#   Sheet 7 : Consolidated_Summary     (national totals + wide pivots + data dict)

output_path <- "C:/Users/Muhammad Aulia/CPI/SP-Program - 1. Projects (Contracts, Slide Decks, Studies, Reports)/85078 ViriyaENB_CoalTransition/Implementation Phase/04 Working File/02 Economic Assessment/irio2016/IRIO_2016_Analysis_Results.xlsx"

cat("Exporting results to Excel...\n")
cat("Output file:", output_path, "\n")

wb <- createWorkbook()

# ---- Shared styles ----
header_style <- createStyle(
  fontSize = 11, fontName = "Arial", fontColour = "white",
  fgFill = "#2E5496", halign = "center", valign = "center",
  textDecoration = "bold", wrapText = TRUE, border = "Bottom"
)
alt_style <- createStyle(fgFill = "#EEF2F8", fontName = "Arial", fontSize = 10)
title_style <- createStyle(
  fontSize = 12, fontName = "Arial", textDecoration = "bold",
  fontColour = "#1F3864"
)
neg_style <- createStyle(
  fontColour = "#C00000", fontName = "Arial", fontSize = 10,
  numFmt = "#,##0.0000"
)
num_style <- createStyle(fontName = "Arial", fontSize = 10, numFmt = "#,##0.0000")
num_style2 <- createStyle(fontName = "Arial", fontSize = 10, numFmt = "#,##0.00")

# Helper to apply alternate row shading
apply_alt_shading <- function(wb, sheet, nrows, ncols) {
  for (r in seq(2, nrows + 1, by = 2)) {
    addStyle(wb, sheet, alt_style, rows = r, cols = 1:ncols, gridExpand = TRUE)
  }
}


# ===========================================================================
# SHEET 1: Linkage Summary
# ===========================================================================
addWorksheet(wb, "Linkage_Summary")
writeData(wb, "Linkage_Summary", linkage_summary)
addStyle(wb, "Linkage_Summary", header_style,
         rows = 1, cols = 1:ncol(linkage_summary), gridExpand = TRUE)
apply_alt_shading(wb, "Linkage_Summary", nrow(linkage_summary), ncol(linkage_summary))
setColWidths(wb, "Linkage_Summary",
             cols = 1:ncol(linkage_summary),
             widths = 20)
freezePane(wb, "Linkage_Summary", firstRow = TRUE)


# ===========================================================================
# SHEET 2: Sector Aggregation
# ===========================================================================
addWorksheet(wb, "Sector_Aggregation")
writeData(wb, "Sector_Aggregation", sector_agg)
addStyle(wb, "Sector_Aggregation", header_style,
         rows = 1, cols = 1:ncol(sector_agg), gridExpand = TRUE)
apply_alt_shading(wb, "Sector_Aggregation", nrow(sector_agg), ncol(sector_agg))
setColWidths(wb, "Sector_Aggregation",
             cols = 1:ncol(sector_agg),
             widths = c(12, 55, 18, 20, 16, 20, 18))
freezePane(wb, "Sector_Aggregation", firstRow = TRUE)


# ===========================================================================
# SHEET 3: Province Aggregation
# ===========================================================================
addWorksheet(wb, "Province_Aggregation")
writeData(wb, "Province_Aggregation", province_agg)
addStyle(wb, "Province_Aggregation", header_style,
         rows = 1, cols = 1:ncol(province_agg), gridExpand = TRUE)
apply_alt_shading(wb, "Province_Aggregation", nrow(province_agg), ncol(province_agg))
setColWidths(wb, "Province_Aggregation",
             cols = 1:ncol(province_agg),
             widths = c(28, 18, 20, 16, 20, 18))
freezePane(wb, "Province_Aggregation", firstRow = TRUE)


#===========================================================================
# SHEET 4: Shock Detail — All Years (long format, 10,608 rows)
# ===========================================================================
addWorksheet(wb, "Shock_Detail_All_Years")

desc_S4 <- paste0(
  "Sector I-09 (Pertambangan Batubara dan Lignit) demand shock, 2025-2030. ",
  "Shock allocated to each province proportionate to its share of national I-09 output (x). ",
  "Direct impact = shock applied to I-09 rows; Indirect = propagated upstream/downstream effects. ",
  "All monetary values in Juta Rupiah."
)
writeData(wb, "Shock_Detail_All_Years",
          data.frame(Description = desc_S4),
          startRow = 1, startCol = 1, colNames = FALSE)
writeData(wb, "Shock_Detail_All_Years", all_shock_results, startRow = 3, startCol = 1)
addStyle(wb, "Shock_Detail_All_Years", header_style,
         rows = 3, cols = 1:ncol(all_shock_results), gridExpand = TRUE)
apply_alt_shading(wb, "Shock_Detail_All_Years", nrow(all_shock_results),
                  ncol(all_shock_results))
setColWidths(wb, "Shock_Detail_All_Years",
             cols = 1:ncol(all_shock_results),
             widths = c(8, 30, 25, 12, 55, 18, 22, 22, 22, 22))
freezePane(wb, "Shock_Detail_All_Years", firstRow = FALSE, firstActiveRow = 4,
           firstActiveCol = 3)

# ===========================================================================
# SHEET 5: Shock by Province x Year
# ===========================================================================
addWorksheet(wb, "Shock_By_Province_Year")

desc_S5 <- paste0(
  "Aggregated direct, indirect, and total output impacts of I-09 demand shock by province and year. ",
  "All values in Juta Rupiah."
)
writeData(wb, "Shock_By_Province_Year",
          data.frame(Description = desc_S5),
          startRow = 1, startCol = 1, colNames = FALSE)

# Long-format table
writeData(wb, "Shock_By_Province_Year", summary_by_province, startRow = 3, startCol = 1)
addStyle(wb, "Shock_By_Province_Year", header_style,
         rows = 3, cols = 1:ncol(summary_by_province), gridExpand = TRUE)
apply_alt_shading(wb, "Shock_By_Province_Year", nrow(summary_by_province),
                  ncol(summary_by_province))
setColWidths(wb, "Shock_By_Province_Year",
             cols = 1:ncol(summary_by_province),
             widths = c(8, 28, 22, 22, 22))

# Wide-format pivot below the long table (with spacer rows)
pivot_row_start <- nrow(summary_by_province) + 6
writeData(wb, "Shock_By_Province_Year",
          data.frame(Label = "WIDE PIVOT — Total Output Impact (Juta Rp) by Province and Year"),
          startRow = pivot_row_start, startCol = 1, colNames = FALSE)
addStyle(wb, "Shock_By_Province_Year", title_style,
         rows = pivot_row_start, cols = 1)
writeData(wb, "Shock_By_Province_Year", summary_province_wide,
          startRow = pivot_row_start + 2, startCol = 1)
addStyle(wb, "Shock_By_Province_Year", header_style,
         rows = pivot_row_start + 2,
         cols = 1:ncol(summary_province_wide), gridExpand = TRUE)
setColWidths(wb, "Shock_By_Province_Year",
             cols = 1:ncol(summary_province_wide),
             widths = c(28, rep(20, ncol(summary_province_wide) - 1)))

freezePane(wb, "Shock_By_Province_Year", firstRow = FALSE, firstActiveRow = 4)


# ===========================================================================
# SHEET 6: Shock by Sector x Year
# ===========================================================================
addWorksheet(wb, "Shock_By_Sector_Year")

desc_S6 <- paste0(
  "Aggregated direct, indirect, and total output impacts of I-09 demand shock by sector and year, ",
  "summed across all 34 provinces. All values in Juta Rupiah."
)
writeData(wb, "Shock_By_Sector_Year",
          data.frame(Description = desc_S6),
          startRow = 1, startCol = 1, colNames = FALSE)

writeData(wb, "Shock_By_Sector_Year", summary_by_sector, startRow = 3, startCol = 1)
addStyle(wb, "Shock_By_Sector_Year", header_style,
         rows = 3, cols = 1:ncol(summary_by_sector), gridExpand = TRUE)
apply_alt_shading(wb, "Shock_By_Sector_Year", nrow(summary_by_sector),
                  ncol(summary_by_sector))
setColWidths(wb, "Shock_By_Sector_Year",
             cols = 1:ncol(summary_by_sector),
             widths = c(8, 12, 55, 22, 22, 22))

# Wide pivot below
pivot_row_S6 <- nrow(summary_by_sector) + 6
writeData(wb, "Shock_By_Sector_Year",
          data.frame(Label = "WIDE PIVOT — Total Output Impact (Juta Rp) by Sector and Year"),
          startRow = pivot_row_S6, startCol = 1, colNames = FALSE)
addStyle(wb, "Shock_By_Sector_Year", title_style,
         rows = pivot_row_S6, cols = 1)
writeData(wb, "Shock_By_Sector_Year", summary_sector_wide,
          startRow = pivot_row_S6 + 2, startCol = 1)
addStyle(wb, "Shock_By_Sector_Year", header_style,
         rows = pivot_row_S6 + 2,
         cols = 1:ncol(summary_sector_wide), gridExpand = TRUE)
setColWidths(wb, "Shock_By_Sector_Year",
             cols = 1:ncol(summary_sector_wide),
             widths = c(12, 55, rep(20, ncol(summary_sector_wide) - 2)))

freezePane(wb, "Shock_By_Sector_Year", firstRow = FALSE, firstActiveRow = 4)


# ===========================================================================
# SHEET 7: Consolidated Summary
# ===========================================================================
# This sheet presents all key results in a single readable layout with four
# sections:
#   Section A — National totals by year (shock, direct, indirect, total, multiplier)
#   Section B — Province-level wide pivot (Total Impact by year)
#   Section C — Sector-level wide pivot (Total Impact by year)
#   Section D — Data dictionary

addWorksheet(wb, "Consolidated_Summary")
# ----- Section A: National Totals -----
writeData(wb, "Consolidated_Summary",
          data.frame(Label = "SECTION A: National Output Impact Summary — Sector I-09 Coal Mining Demand Shock, 2025-2030"),
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "Consolidated_Summary", title_style, rows = 1, cols = 1)

writeData(wb, "Consolidated_Summary",
          data.frame(Note = paste0(
            "Shock applied to I-09 (Pertambangan Batubara dan Lignit), allocated to each province ",
            "proportionate to its share of national I-09 total output (x). ",
            "Output Multiplier = Total Impact / Total Shock Applied. All values in Juta Rupiah."
          )),
          startRow = 2, startCol = 1, colNames = FALSE)

writeData(wb, "Consolidated_Summary", summary_national, startRow = 4, startCol = 1)
addStyle(wb, "Consolidated_Summary", header_style,
         rows = 4, cols = 1:ncol(summary_national), gridExpand = TRUE)
apply_alt_shading(wb, "Consolidated_Summary", nrow(summary_national),
                  ncol(summary_national))
setColWidths(wb, "Consolidated_Summary",
             cols = 1:ncol(summary_national),
             widths = c(8, 28, 24, 26, 24, 18))

# ----- Section B: Province Wide Pivot -----
sec_b_row <- nrow(summary_national) + 7
writeData(wb, "Consolidated_Summary",
          data.frame(Label = "SECTION B: Total Output Impact by Province (Juta Rp) — Columns = Years 2025-2030 + Cumulative"),
          startRow = sec_b_row, startCol = 1, colNames = FALSE)
addStyle(wb, "Consolidated_Summary", title_style, rows = sec_b_row, cols = 1)

writeData(wb, "Consolidated_Summary", summary_province_wide,
          startRow = sec_b_row + 2, startCol = 1)
addStyle(wb, "Consolidated_Summary", header_style,
         rows = sec_b_row + 2,
         cols = 1:ncol(summary_province_wide), gridExpand = TRUE)
apply_alt_shading(wb, "Consolidated_Summary", nrow(summary_province_wide),
                  ncol(summary_province_wide))
setColWidths(wb, "Consolidated_Summary",
             cols = 1:ncol(summary_province_wide),
             widths = c(28, rep(20, ncol(summary_province_wide) - 1)))

# ----- Section C: Sector Wide Pivot -----
sec_c_row <- sec_b_row + nrow(summary_province_wide) + 5
writeData(wb, "Consolidated_Summary",
          data.frame(Label = "SECTION C: Total Output Impact by Sector (Juta Rp) — Columns = Years 2025-2030 + Cumulative"),
          startRow = sec_c_row, startCol = 1, colNames = FALSE)
addStyle(wb, "Consolidated_Summary", title_style, rows = sec_c_row, cols = 1)

writeData(wb, "Consolidated_Summary", summary_sector_wide,
          startRow = sec_c_row + 2, startCol = 1)
addStyle(wb, "Consolidated_Summary", header_style,
         rows = sec_c_row + 2,
         cols = 1:ncol(summary_sector_wide), gridExpand = TRUE)
apply_alt_shading(wb, "Consolidated_Summary", nrow(summary_sector_wide),
                  ncol(summary_sector_wide))
setColWidths(wb, "Consolidated_Summary",
             cols = 1:ncol(summary_sector_wide),
             widths = c(12, 55, rep(20, ncol(summary_sector_wide) - 2)))

# ----- Section D: Data Dictionary -----
sec_d_row <- sec_c_row + nrow(summary_sector_wide) + 5
writeData(wb, "Consolidated_Summary",
          data.frame(Label = "SECTION D: Data Dictionary"),
          startRow = sec_d_row, startCol = 1, colNames = FALSE)
addStyle(wb, "Consolidated_Summary", title_style, rows = sec_d_row, cols = 1)

meta <- data.frame(
  Column       = c(
    "Year", "Region_Sector", "Province", "Sector_Code", "Sector_Name",
    "I09_Output_Share",
    "Shock_Applied_Juta_Rp", "Direct_Impact_Juta_Rp",
    "Indirect_Impact_Juta_Rp", "Total_Impact_Juta_Rp",
    "Output_Multiplier", "Cumulative_2025_2030",
    "BL_Simple", "BL_Normalized", "FL_Leontief", "FL_Leontief_Norm",
    "Classification"
  ),
  Description  = c(
    "Reference year of the shock scenario (2025 to 2030)",
    "Unique identifier combining Province and Sector Code",
    "Province name as listed in BPS IRIO 2016",
    "Sector code (I-01 to I-52)",
    "Full sector description in Bahasa Indonesia",
    "Province's share of national total output in sector I-09; used to allocate the annual shock proportionately",
    "Exogenous demand shock allocated to sector I-09 in each province (Juta Rp; negative = demand reduction)",
    "First-round output impact: equal to the shock value for I-09 rows; zero for all other sectors",
    "Propagated output impact across all other sectors and provinces via supply-chain linkages (Leontief)",
    "Total output change = Direct + Indirect; computed as L %*% delta_f",
    "Ratio of total output impact to total shock applied nationally",
    "Sum of Total_Impact_Juta_Rp across years 2025-2030",
    "Simple backward linkage = column sum of Leontief inverse L (output multiplier)",
    "Normalized backward linkage (Rasmussen): BL_Simple / (n * grand mean of L)",
    "Simple forward linkage = row sum of L (Cella/Clements approach)",
    "Normalized forward linkage (Rasmussen/Cella-Clements): FL_Leontief / (n * grand mean of L)",
    "Rasmussen sector classification using BL_Normalized and FL_Leontief_Norm: Key Sector / Forward-Oriented / Backward-Oriented / Independent"
  ),
  Unit_or_Notes = c(
    "integer", "text", "text", "text", "text",
    "dimensionless proportion [0, 1]; sums to 1 across 34 provinces",
    "Juta Rupiah (negative = contraction)",
    "Juta Rupiah (negative = output loss)",
    "Juta Rupiah (negative = output loss propagated)",
    "Juta Rupiah (negative = net output loss)",
    "dimensionless",
    "Juta Rupiah",
    "Juta Rp per Juta Rp final demand",
    "dimensionless; > 1 = above average",
    "Juta Rp per Juta Rp primary input",
    "dimensionless; > 1 = above average",
    "4-category classification"
  ),
  stringsAsFactors = FALSE
)

writeData(wb, "Consolidated_Summary", meta, startRow = sec_d_row + 2, startCol = 1)
addStyle(wb, "Consolidated_Summary", header_style,
         rows = sec_d_row + 2, cols = 1:3, gridExpand = TRUE)
setColWidths(wb, "Consolidated_Summary", cols = 1:3, widths = c(28, 75, 40))

freezePane(wb, "Consolidated_Summary", firstRow = FALSE, firstActiveRow = 5)


# ---- Save workbook ----
saveWorkbook(wb, output_path, overwrite = TRUE)


cat("=============================================================\n")
cat("IRIO Analysis complete. Results saved to:\n")
cat(output_path, "\n")
cat("Sheets exported:\n")
cat("  1. Linkage_Summary        — Full 1768 region-sector BL/FL linkage table\n")
cat("  2. Sector_Aggregation     — National BL/FL averages by 52 sectors\n")
cat("  3. Province_Aggregation   — BL/FL averages by 34 provinces\n")
cat("  4. Shock_Detail_All_Years — Long-format detail: all years x region-sectors (10,608 rows)\n")
cat("  5. Shock_By_Province_Year — Direct/indirect/total impact by province x year\n")
cat("  6. Shock_By_Sector_Year   — Direct/indirect/total impact by sector x year\n")
cat("  7. Consolidated_Summary   — National totals + wide pivots + data dictionary\n")
cat("=============================================================\n")


# =============================================================================
# END OF SCRIPT
# =============================================================================

