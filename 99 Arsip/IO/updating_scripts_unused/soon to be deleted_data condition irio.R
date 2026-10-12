###------------------------------------------------------###
### DIAGNOSTIC: Memahami struktur data sebelum eksekusi  ###
### Jalankan blok per blok, amati output masing-masing   ###
###------------------------------------------------------###

library(rio); library(openxlsx); library(dplyr); library(tidyverse)

pdrb          <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx", sheet = "main_dat")
irio_raw      <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/irio16.csv", header = TRUE)
concord52_185 <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/concordance_185_52_17.xlsx", sheet = "sec17-52")

###--- BLOK 1: Struktur irio_raw ---###
# Pertanyaan: berapa dimensi? di mana letak Z, U, V, X?
cat("=== irio_raw: dimensi ===\n")
cat("nrow:", nrow(irio_raw), "| ncol:", ncol(irio_raw), "\n\n")

cat("=== 5 baris pertama, 5 kolom pertama ===\n")
print(irio_raw[1:5, 1:5])

cat("\n=== 5 baris terakhir, 5 kolom pertama ===\n")
print(irio_raw[(nrow(irio_raw)-4):nrow(irio_raw), 1:5])

cat("\n=== Kolom-kolom terakhir (5 kolom terakhir, 5 baris pertama) ===\n")
print(irio_raw[1:5, (ncol(irio_raw)-4):ncol(irio_raw)])

cat("\n=== Nama kolom: 10 pertama dan 10 terakhir ===\n")
print(head(names(irio_raw), 10))
print(tail(names(irio_raw), 10))

cat("\n=== Contoh nilai kode di kolom pertama ===\n")
print(head(irio_raw$kode, 20))
print(tail(irio_raw$kode, 20))

###--- BLOK 2: Struktur kode IRIO ---###
# Pertanyaan: format kode? pola provinsi-sektor? 
# Apakah 1768 = 52 sektor x 34 provinsi?
cat("\n=== Cek 1768 = 52 x 34? ===\n")
cat("52 x 34 =", 52 * 34, "\n")

sec_codes <- irio_raw$kode[1:1768]

# Ekstrak komponen kode
kode_df <- data.frame(kode = sec_codes) %>%
  mutate(
    prov = sub("^([0-9]+)-.*", "\\1", kode),       # ambil prefix angka
    sec  = sub("^[0-9]+-(.*)$", "\\1", kode)        # ambil suffix sektor
  )

cat("\n=== Jumlah provinsi unik dalam 1768 kode ===\n")
cat(n_distinct(kode_df$prov), "\n")
print(sort(unique(kode_df$prov)))

cat("\n=== Jumlah sektor unik dalam 1768 kode ===\n")
cat(n_distinct(kode_df$sec), "\n")
print(sort(unique(kode_df$sec)))

cat("\n=== Distribusi sektor per provinsi (harusnya merata 52 per prov) ===\n")
print(kode_df %>% count(prov) %>% summary())

###--- BLOK 3: Struktur PDRB ---###
cat("\n=== pdrb: dimensi dan kolom ===\n")
cat("nrow:", nrow(pdrb), "| ncol:", ncol(pdrb), "\n")
print(names(pdrb))

cat("\n=== 5 baris pertama ===\n")
print(head(pdrb, 5))

cat("\n=== Cek kodeIO: unik, NA, konsisten dengan irio? ===\n")
cat("Nilai unik kodeIO:", n_distinct(pdrb$kodeIO), "\n")
cat("NA pada kodeIO:", sum(is.na(pdrb$kodeIO)), "\n")
print(sort(unique(pdrb$kodeIO)))

cat("\n=== Jumlah provinsi dalam PDRB ===\n")
cat("Provinsi unik:", n_distinct(pdrb$kode_prov), "\n")
print(sort(unique(pdrb$kode_prov)))

cat("\n=== Cek kelengkapan: setiap provinsi punya 52 sektor? ===\n")
pdrb_check <- pdrb %>% count(kode_prov) 
print(summary(pdrb_check$n))
cat("Provinsi dengan baris != 52:\n")
print(pdrb_check %>% filter(n != 52))

###--- BLOK 4: Struktur concordance ---###
cat("\n=== concord52_185: dimensi dan kolom ===\n")
print(dim(concord52_185))
print(names(concord52_185))
print(head(concord52_185, 10))

cat("\n=== Nilai unik sec52 dan sec17 ===\n")
cat("sec52 unik:", n_distinct(concord52_185$sec52), "\n")
cat("sec17 unik:", n_distinct(concord52_185$sec17), "\n")
print(sort(unique(concord52_185$sec17)))

cat("\n=== Distribusi: berapa subsektor per sec17? ===\n")
print(concord52_185 %>% count(sec17) %>% arrange(sec17))

###--- BLOK 5: Join diagnostics ---###
# Apakah kodeIO di PDRB konsisten dengan sec52 di concordance?
cat("\n=== Cek join PDRB <-> concordance ===\n")
pdrb_test <- left_join(pdrb, concord52_185, by = c("kodeIO" = "sec52"))
cat("NA pada sec17 setelah join:", sum(is.na(pdrb_test$sec17)), "\n")
cat("kodeIO tanpa pasangan di concordance:\n")
print(setdiff(unique(pdrb$kodeIO), unique(concord52_185$sec52)))

# Apakah sec (dari kode IRIO) konsisten dengan sec52 di concordance?
cat("\n=== Cek konsistensi sec dari kode IRIO vs sec52 di concordance ===\n")
sec_irio_unik <- sort(unique(kode_df$sec))
sec_concord_unik <- sort(unique(concord52_185$sec52))
cat("Ada di IRIO tapi tidak di concordance:\n")
print(setdiff(sec_irio_unik, sec_concord_unik))
cat("Ada di concordance tapi tidak di IRIO:\n")
print(setdiff(sec_concord_unik, sec_irio_unik))

###--- BLOK 6: Cek nilai IRIO (Z, X) ---###
cat("\n=== Identifikasi posisi total output X di irio_raw ===\n")
# Berdasarkan kode v3: totaloutput ada di kolom 1780
cat("Nama kolom 1778-1782:\n")
print(names(irio_raw)[1778:min(1782, ncol(irio_raw))])
cat("Nilai totaloutput (baris 1-5, kolom 1780):\n")
print(irio_raw[1:5, 1780])

cat("\n=== Range nilai Z matrix (bukan 0 saja) ===\n")
irio_z_sample <- irio_raw[1:1768, 2:1769] %>% as.matrix() %>% apply(., 2, as.numeric)
cat("Min non-zero:", min(irio_z_sample[irio_z_sample > 0], na.rm = TRUE), "\n")
cat("Max:", max(irio_z_sample, na.rm = TRUE), "\n")
cat("Proporsi zero:", mean(irio_z_sample == 0), "\n")
cat("Satuan: apakah perlu *1e6? Cek total vs PDRB nasional.\n")
cat("Sum Z matrix (raw):", sum(irio_z_sample), "\n")
cat("Sum X (raw):", sum(as.numeric(irio_raw[1:1768, 1780])), "\n")

###--- BLOK 7: Konsistensi pdrb$kode vs kode_df$kode (kode IRIO) ---###
cat("\n=== Cek apakah pdrb$kode selaras dengan kode IRIO ===\n")
cat("Contoh pdrb$kode:\n")
print(head(sort(unique(pdrb$kode)), 10))
cat("Contoh kode IRIO:\n")
print(head(sort(sec_codes), 10))
cat("Ada di PDRB tapi tidak di IRIO:\n")
print(length(setdiff(unique(pdrb$kode), sec_codes)))
cat("Ada di IRIO tapi tidak di PDRB:\n")
print(length(setdiff(sec_codes, unique(pdrb$kode))))








# Konfirmasi 1: satuan PDRB
cat("=== Cek satuan PDRB ===\n")
cat("Total PDRB nasional (target, semua prov+sek):", sum(pdrb$target, na.rm=TRUE), "\n")
cat("Total PDRB nasional (base):", sum(pdrb$base, na.rm=TRUE), "\n")
# Ekspektasi: jika miliar rupiah, total target ~2024 PDB Indonesia ~22.000 triliun
# => sum harus sekitar 22.000.000 (miliar) atau 22.000 (triliun)

# Konfirmasi 2: kolom X di irio_raw
cat("\n=== Cek kolom 3100 vs 6000 ===\n")
cat("Nama kolom 1779-1781:", names(irio_raw)[1779:1781], "\n")
cat("Nilai kolom 3100 (1780) baris 1-5:\n")
print(irio_raw[1:5, 1780])
cat("Nilai kolom 6000 (1781) baris 1-5:\n")
print(irio_raw[1:5, 1781])
cat("Apakah identik?\n")
print(all(irio_raw[1:1768, 1780] == irio_raw[1:1768, 1781]))

# Konfirmasi 3: zero proportion - seberapa banyak?
pdrb_joined <- left_join(pdrb, concord52_185, by = c("kodeIO" = "sec52"))
pdrb_17_temp <- pdrb_joined %>%
  group_by(kode_prov, sec17) %>%
  mutate(target_17 = sum(target, na.rm=TRUE)) %>%
  ungroup() %>%
  mutate(prop_target = ifelse(target_17 > 0, target / target_17, 0))

cat("\n=== Proporsi zero di prop_target ===\n")
cat("Jumlah baris prop_target == 0:", sum(pdrb_17_temp$prop_target == 0), "\n")  
cat("Jumlah baris prop_target > 0 tapi base == 0:", 
    sum(pdrb_17_temp$prop_target > 0 & pdrb_17_temp$base == 0), "\n")
cat("Jumlah baris prop_target > 0 tapi base == 0 (sebagai % total):", 
    round(mean(pdrb_17_temp$prop_target > 0 & pdrb_17_temp$base == 0)*100, 1), "%\n")

