# Audit PCA dengan prcomp (opsional). Jalankan dari root proyek.
# Input: panel_provinsi_tahun_2017_2025.csv

library(dplyr)

root <- "01 Data/TFP/processed/panel"
panel <- read.csv(file.path(root, "panel_provinsi_tahun_2017_2025.csv"),
                  stringsAsFactors = FALSE)

d <- panel %>% filter(status_observasi == "berdiri")

z_within <- function(x, year) {
  ave(x, year, FUN = function(v) {
    s <- sd(v, na.rm = TRUE)
    if (is.na(s) || s == 0) return(rep(0, length(v)))
    (v - mean(v, na.rm = TRUE)) / s
  })
}

d <- d %>%
  mutate(
    pax_angkutan = pax_udara + pax_laut + pax_bus,
    panjang_jalan_km_log = log(panjang_jalan_km + 1),
    pax_angkutan_log = log(pax_angkutan + 1),
    pax_ka_log = log(pax_ka + 1),
    cargo_total_juta_ton_log = log(cargo_total_juta_ton + 1)
  )

conn_vars <- c("panjang_jalan_km_log", "jalan_mantap_pct",
               "pax_angkutan_log", "pax_ka_log", "cargo_total_juta_ton_log")
inst_vars <- c("rasio_pad", "serapan_belanja", "idi",
               "tindak_pidana_per_100rb", "ikg",
               "indeks_hijau_iktl", "indeks_biru_ika")

for (v in conn_vars) d[[paste0(v, "_z")]] <- z_within(d[[v]], d$year)
for (v in inst_vars) d[[paste0(v, "_z")]] <- z_within(d[[v]], d$year)
d$tindak_pidana_per_100rb_z <- -d$tindak_pidana_per_100rb_z
d$ikg_z <- -d$ikg_z

pc_conn <- prcomp(d[, paste0(conn_vars, "_z")], center = TRUE, scale. = FALSE)
pc_inst <- prcomp(d[, paste0(inst_vars, "_z")], center = TRUE, scale. = FALSE)
if (sum(pc_conn$rotation[, 1]) < 0) pc_conn$rotation[, 1] <- -pc_conn$rotation[, 1]
if (sum(pc_inst$rotation[, 1]) < 0) pc_inst$rotation[, 1] <- -pc_inst$rotation[, 1]
sc_conn <- as.numeric(scale(d[, paste0(conn_vars, "_z")], center = TRUE, scale = FALSE) %*% pc_conn$rotation[, 1])
sc_inst <- as.numeric(scale(d[, paste0(inst_vars, "_z")], center = TRUE, scale = FALSE) %*% pc_inst$rotation[, 1])
to01 <- function(x) 100 * (x - min(x)) / (max(x) - min(x))

d$indeks_konektivitas_r <- to01(sc_conn)
d$indeks_institusi_r <- to01(sc_inst)

cat("korelasi Python vs prcomp (konektivitas):",
    round(cor(d$indeks_konektivitas, d$indeks_konektivitas_r), 4), "\n")
cat("korelasi Python vs prcomp (institusi):",
    round(cor(d$indeks_institusi, d$indeks_institusi_r), 4), "\n")
cat("PC1 konektivitas var:", round(summary(pc_conn)$importance[2, 1], 3), "\n")
cat("PC1 institusi var:", round(summary(pc_inst)$importance[2, 1], 3), "\n")

write.csv(
  data.frame(variabel = conn_vars, loading_pc1 = pc_conn$rotation[, 1]),
  file.path(root, "pca_loadings_konektivitas_prcomp.csv"),
  row.names = FALSE
)
write.csv(
  data.frame(variabel = inst_vars, loading_pc1 = pc_inst$rotation[, 1]),
  file.path(root, "pca_loadings_institusi_prcomp.csv"),
  row.names = FALSE
)
