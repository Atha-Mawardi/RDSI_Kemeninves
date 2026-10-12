# ==============================================================================
# Dekomposisi pertumbuhan nasional berbasis elastisitas terestimasi
#
# BUKAN growth accounting baku. Growth accounting mensyaratkan stok kapital
# (perpetual inventory) dan pangsa faktor dari data pendapatan. Di sini modal
# diproksi arus PMTB dan elastisitasnya diestimasi dari panel provinsi. Penamaan
# ini dijaga konsisten di report supaya tidak mengundang perbandingan yang keliru.
#
# Tiga aturan penyajian yang mengikat, semuanya punya alasan empiris:
#   (1) Rata-rata periode, TIDAK PERNAH tahun-per-tahun. g(PMTB) ~ g(stok modal)
#       hanya masuk akal bila rasio investasi/stok stabil, dan itu terlanggar
#       telak pada 2020-21. Tabel 5 Masterplan memperlihatkan akibatnya: TFP
#       tahunan berayun -36,65 ke +77,37 sebagai cerminan pergerakan investasi.
#   (2) Residual dilabeli "Residual PMTB", bukan TFP Hicks-neutral.
#   (3) Disajikan sebagai rentang lintas skenario elastisitas, bukan titik tunggal.
# ==============================================================================

library(tidyverse)
library(openxlsx)

data_file <- "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"

# Sakelar basis harga modal - lihat penjelasan lengkap di 01_estimasi tfp.R.
# Nilainya wajib sama dengan yang dipakai skrip 01, karena skrip ini membaca
# parameter_terpilih.rds hasil skrip itu.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"

out_dir   <- switch(BASIS_MODAL,
                    riil    = "01 Data/TFP/output/modal_riil",
                    nominal = "01 Data/TFP/output/nominal",
                    adhb    = "01 Data/TFP/output/adhb")
par_file  <- file.path(out_dir, "parameter_terpilih.rds")
stopifnot(file.exists(par_file))
par <- readRDS(par_file)
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, out_dir))

# Kolom modal yang diagregasi harus mengikuti sakelar yang sama. Kalau tidak,
# elastisitas dari skrip 01 dipasangkan ke laju pertumbuhan basis harga lain.
kol_modal  <- switch(BASIS_MODAL, riil = "4_ADHK", nominal = "pmtb", adhb = "4_ADHB")
# Kolom output ikut basis. Pada "adhb" kedua sisi persamaan harga berlaku.
kol_output <- if (BASIS_ADHB) "9_ADHB" else "9_ADHK"

# ==============================================================================
# 1. Agregasi 34 provinsi menjadi seri nasional
# ==============================================================================
df <- read.xlsx(data_file, sheet = "Sheet1")
tk_cols <- grep("_TenagaKerja$", names(df), value = TRUE)

nas <- df %>%
  mutate(labours_total = rowSums(across(all_of(tk_cols))),
         K_modal = .data[[kol_modal]]) %>%
  filter(!is.na(K_modal), !is.na(labours_total), !is.na(.data[[kol_output]])) %>%
  group_by(Year) %>%
  summarise(Y = sum(.data[[kol_output]]), K = sum(K_modal), L = sum(labours_total),
            n_prov = n(), .groups = "drop") %>%
  arrange(Year)

cat("\n=============== 1. Seri nasional (agregasi provinsi) ===============\n")
print(as.data.frame(nas %>% mutate(across(c(Y, K, L), ~round(.x / 1e3, 1)))),
      row.names = FALSE)
stopifnot(all(nas$n_prov == 34))

nas <- nas %>%
  mutate(g_Y = 100 * (log(Y) - log(dplyr::lag(Y))),
         g_K = 100 * (log(K) - log(dplyr::lag(K))),
         g_L = 100 * (log(L) - log(dplyr::lag(L))))

cat("\nPertumbuhan nasional (log-difference, %/thn):\n")
print(as.data.frame(nas %>% select(Year, g_Y, g_K, g_L) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))),
      row.names = FALSE)

# ==============================================================================
# 1b. Stok modal PIM nasional - mengukur saluran kedua dari masalah arus-vs-stok
#
# Memakai g(PMTB) sebagai g(stok modal) merusak dua hal sekaligus, dan arahnya
# BERLAWANAN:
#   (a) elastisitas b1 teratenuasi  -> sisa terlalu BESAR
#   (b) g(PMTB) > g(stok modal)     -> kontribusi modal terlalu besar
#                                   -> sisa terlalu KECIL
# Saluran (b) tidak bisa diabaikan: selama periode ini PMTB tumbuh 6,12%/thn
# sementara output 3,83%/thn, sehingga rasio investasi/stok naik dan stok modal
# pasti tumbuh lebih lambat dari 6,12%.
#
# PIM di sini hanya nasional. Di level provinsi tidak layak: seri hanya 8 tahun,
# galat stok awal meluruh sebesar (1-delta)^t sehingga dengan delta=5% masih
# tersisa ~70% setelah tujuh tahun (Chen & Plotnikova 2018 membahas persis
# masalah nilai awal pada rentang waktu pendek). Bahkan di level nasional angka
# ini indikatif, bukan pengukuran - karena itu disajikan sebagai rentang delta.
# ==============================================================================
pim_gK <- function(I, delta, g_asumsi) {
  K <- numeric(length(I))
  K[1] <- I[1] / (g_asumsi + delta)            # stok awal keadaan tunak
  for (t in 2:length(I)) K[t] <- (1 - delta) * K[t - 1] + I[t]
  100 * mean(diff(log(K)))                     # rata-rata pertumbuhan, %/thn
}

g_I  <- mean(nas$g_K, na.rm = TRUE) / 100
grid_pim <- crossing(delta = c(0.05, 0.08), g_asumsi = c(0.04, g_I)) %>%
  mutate(g_K_pim = map2_dbl(delta, g_asumsi, ~ pim_gK(nas$K, .x, .y)),
         label = sprintf("delta=%.0f%%, g0=%.1f%%", 100 * delta, 100 * g_asumsi))

cat("\n-- Stok modal PIM nasional: pertumbuhan stok vs pertumbuhan arus --\n")
cat(sprintf("g(PMTB) arus = %.2f%%/thn\n", 100 * g_I))
print(as.data.frame(grid_pim %>% select(label, g_K_pim) %>%
                      mutate(g_K_pim = round(g_K_pim, 2))), row.names = FALSE)
g_K_pim_tengah <- median(grid_pim$g_K_pim)
cat(sprintf("Nilai tengah dipakai sebagai skenario PIM: %.2f%%/thn\n", g_K_pim_tengah))

# ==============================================================================
# 2. Skenario elastisitas
#
# Skenario BASIS/UTAMA adalah F: elastisitas two-way FE apa adanya. Residualnya
# secara sah memuat suku skala (1-b1-b2) x pertumbuhan input; itu diterima
# terbuka. Skenario CRS (A, B, E) dan alfa baku (D) dipertahankan sebagai
# PEMBANDING, bukan lagi basis. Alasan menyertakan CRS: estimasi tak-terestriksi
# teratenuasi - b1+b2 mengecil seiring variasi dibuang, tanda tangan measurement
# error pada modal (Griliches & Hausman 1986; Chen & Plotnikova 2018), sehingga
# CRS berguna sebagai batas atas kontribusi modal.
#
# CATATAN: pada basis modal riil (4_ADHK) tangganya TIDAK monoton - pooled 1,01,
# random 1,08, within 1,19, baru two-way 0,55. Angka b1+b2 karena itu tidak
# ditulis tangan di mana pun; semuanya diturunkan dari parameter hasil skrip 01.
# ==============================================================================
b1_un  <- unname(par$b1_un)             # BASIS/UTAMA: two-way FE tak-terestriksi
b2_un  <- unname(par$b2_un)
b1_lvl <- unname(par$b1_crs)                                   # CRS per-pekerja (pembanding)
b1_grw <- unname(par$b1_growth / (par$b1_growth + par$b2_growth))  # growth, dinormalisasi

b2_ukur <- unname(par$pangsa_divisia)   # pangsa pendapatan TK terukur, bobot Divisia

skenario <- tibble(
  skenario = c("A. Level (CRS)", "B. Growth (CRS)", "C. Pangsa terukur",
               "D. Alfa baku 1/3", "E. PIM (CRS)", "F. Tanpa CRS"),
  dasar = c("elastisitas terestimasi bentuk level, dipaksa CRS (pembanding)",
            "elastisitas terestimasi bentuk growth, dinormalisasi CRS (pembanding)",
            "growth accounting ala Rusiawan, bobot pangsa pendapatan terukur (pembanding)",
            "asumsi awal kerangka 7.3.2 laporan, tanpa estimasi (pembanding)",
            "elastisitas A, modal diukur stok PIM bukan arus PMTB (pembanding)",
            # Angka b1+b2 dirakit dari parameter, bukan ditulis tangan, supaya
            # labelnya ikut berubah saat basis harga modal diganti.
            sprintf("elastisitas two-way FE apa adanya, b1+b2=%s (BASIS/UTAMA)",
                    formatC(b1_un + b2_un, format = "f", digits = 2,
                            decimal.mark = ","))),
  b1 = c(b1_lvl, b1_grw, 1 - b2_ukur, 1/3, b1_lvl, b1_un),
  b2 = c(1 - b1_lvl, 1 - b1_grw, b2_ukur, 2/3, 1 - b1_lvl, b2_un)
)

cat("\n=============== 2. Skenario elastisitas ===============\n")
print(as.data.frame(skenario %>% mutate(across(where(is.numeric), ~round(.x, 4)))),
      row.names = FALSE)

# ==============================================================================
# 3. Dekomposisi per periode
# ==============================================================================
# Hanya periode penuh. Subperiode pra/pasca-COVID sengaja TIDAK didekomposisi:
# syarat g(PMTB) ~ g(stok modal) menuntut rasio investasi/stok stabil, dan pada
# jendela dua-tiga tahun syarat itu jelas gagal. Dimensi waktu ditangani oleh
# indeks efek tahun di 01_estimasi, yang memang dirancang untuk itu dan memakai
# skema pembobotan yang konsisten.
periode <- tribble(
  ~periode,            ~dari, ~sampai,
  "2018-2024 (penuh)",  2018,  2024
)

dekomposisi <- periode %>%
  rowwise() %>%
  mutate(sub = list(nas %>% filter(Year >= dari, Year <= sampai))) %>%
  mutate(gY = mean(sub$g_Y), gK = mean(sub$g_K), gL = mean(sub$g_L)) %>%
  ungroup() %>%
  select(periode, gY, gK, gL) %>%
  crossing(skenario) %>%
  # skenario PIM memakai pertumbuhan stok, bukan arus
  mutate(gK = if_else(grepl("^E\\.", skenario), g_K_pim_tengah, gK)) %>%
  mutate(
    kontrib_K = b1 * gK,
    kontrib_L = b2 * gL,
    sisa      = gY - kontrib_K - kontrib_L,          # residual, definisi
    pangsa_K  = 100 * kontrib_K / gY,
    pangsa_L  = 100 * kontrib_L / gY,
    pangsa_sisa = 100 * sisa / gY
  )

# Verifikasi identitas: kontribusi harus menjumlah persis ke gY
maks_selisih <- max(abs(dekomposisi$kontrib_K + dekomposisi$kontrib_L +
                          dekomposisi$sisa - dekomposisi$gY))
cat("\n=============== 3. Dekomposisi ===============\n")
cat("Cek identitas |K + L + sisa - gY| maks =", format(maks_selisih, scientific = TRUE), "\n")
stopifnot(maks_selisih < 1e-10)

for (p in unique(dekomposisi$periode)) {
  cat(sprintf("\n-- %s --\n", p))
  d <- dekomposisi %>% filter(periode == p)
  cat(sprintf(paste0("   pertumbuhan: PDRB ",
                     if (BASIS_ADHB) "harga berlaku" else "riil",
                     " %.2f%% | PMTB %.2f%% | tenaga kerja %.2f%%\n"),
              d$gY[1], d$gK[1], d$gL[1]))
  print(as.data.frame(d %>% select(skenario, b1, kontrib_K, kontrib_L, sisa,
                                   pangsa_K, pangsa_L, pangsa_sisa) %>%
                        mutate(across(where(is.numeric), ~round(.x, 2)))),
        row.names = FALSE)
}

# ==============================================================================
# 4. Rentang lintas skenario + jarak ke sasaran 8-4-2-2
# ==============================================================================
cat("\n=============== 4. Rentang dan jarak ke sasaran ===============\n")
rentang <- dekomposisi %>%
  group_by(periode) %>%
  summarise(gY = first(gY),
            sisa_min = min(sisa), sisa_maks = max(sisa),
            K_min = min(kontrib_K), K_maks = max(kontrib_K), .groups = "drop")
print(as.data.frame(rentang %>% mutate(across(where(is.numeric), ~round(.x, 2)))),
      row.names = FALSE)

# -- Analisis amplop: di bawah CRS dekomposisi kolaps jadi satu garis ----------
# sisa = gY - gL - b1*(gK - gL). Ini pernyataan yang tidak bergantung pada
# pilihan skenario mana pun, jadi jauh lebih kuat daripada "rentang tiga skenario".
d0 <- dekomposisi %>% filter(periode == "2018-2024 (penuh)") %>% slice(1)
cat("\n-- Amplop: sisa sebagai fungsi b1 (di bawah CRS) --\n")
cat(sprintf("sisa = %.2f - %.2f x b1   (gY=%.2f, gL=%.2f, gK-gL=%.2f)\n",
            d0$gY - d0$gL, d0$gK - d0$gL, d0$gY, d0$gL, d0$gK - d0$gL))
cat(sprintf("  batas atas mutlak (b1=0): %.2f poin = %.1f%% pertumbuhan\n",
            d0$gY - d0$gL, 100 * (d0$gY - d0$gL) / d0$gY))
b1_impas <- (d0$gY - d0$gL) / (d0$gK - d0$gL)
cat(sprintf("  sisa = 0 pada b1 = %.3f\n", b1_impas))
b1_25 <- (d0$gY - d0$gL - 0.25 * d0$gY) / (d0$gK - d0$gL)
cat(sprintf("  sisa melampaui 25%% pertumbuhan hanya bila b1 < %.3f\n", b1_25))

# Amplop bergantung pada g(K), dan g(K) yang benar tidak diketahui. Ambangnya
# karena itu dilaporkan sebagai rentang atas grid PIM, bukan satu angka.
ambang_grid <- grid_pim %>%
  mutate(ambang = (d0$gY - d0$gL - 0.25 * d0$gY) / (g_K_pim - d0$gL)) %>%
  arrange(ambang)
tab_ambang <- bind_rows(
  tibble(label = "arus PMTB", g_K_pim = d0$gK, ambang = b1_25),
  ambang_grid %>% select(label, g_K_pim, ambang)
) %>% mutate(across(where(is.numeric), ~round(.x, 3)))
cat("\n  Ambang 25% bergantung g(K) yang dipakai:\n")
print(as.data.frame(tab_ambang), row.names = FALSE)
cat(sprintf("  -> rentang ambang %.3f s.d. %.3f\n",
            min(c(b1_25, ambang_grid$ambang)), max(c(b1_25, ambang_grid$ambang))))

# Estimasi b1 yang tersedia, termasuk bentuk growth TANPA normalisasi. Angka
# mentah bentuk growth (0,151) berada di bawah sebagian ambang, tetapi tidak
# dapat diletakkan pada amplop karena b1+b2-nya 0,416 dan amplop mensyaratkan
# skala hasil konstan. Setelah dinormalisasi ia menjadi 0,364.
est_b1 <- tibble(
  sumber = c("two-way FE (utama)", "CRS per-pekerja", "panel berbobot",
             "bentuk growth mentah", "bentuk growth dinormalisasi CRS"),
  b1 = c(unname(par$b1_level), b1_lvl, unname(par$b1_bobot),
         unname(par$b1_growth), b1_grw),
  crs = c("tidak", "ya", "tidak", "tidak (jumlah 0,416)", "ya")
)
cat("\n  Estimasi b1 yang tersedia:\n")
print(as.data.frame(est_b1 %>% mutate(b1 = round(b1, 3))), row.names = FALSE)

# -- Jarak ke sasaran, memakai elastisitas BASIS non-CRS ----------------------
# Realisasi dihitung dengan skenario F (tak-terestriksi, b1~0,400), BUKAN alfa=1/3.
# Ini keputusan user: basis analisis adalah elastisitas terestimasi non-CRS.
# Ketiga komponen ditampilkan supaya tidak terbaca seolah TFP satu-satunya yang
# tertinggal.
cat("\n=============== 5. Jarak ke sasaran Gerakan 8-4-2-2 ===============\n")
cat("Sasaran resmi (narasi Masterplan hal. 48 / Foreword): 8% = 4 poin tenaga kerja + 2 poin modal + 2 poin TFP.\n")
cat("Kode lama membalik modal/tenaga kerja (4 modal + 2 TK); dikoreksi 2026-09-05.\n")
cat("Realisasi: skenario F (elastisitas terestimasi non-CRS). Residual di sini bukan TFP Hicks-neutral.\n")
dC <- dekomposisi %>% filter(periode == "2018-2024 (penuh)", grepl("^F\\.", skenario))
jarak <- tibble(
  komponen  = c("Modal", "Tenaga kerja", "Residual PMTB", "Output"),
  sasaran   = c(2, 4, 2, 8),
  realisasi = c(dC$kontrib_K, dC$kontrib_L, dC$sisa, dC$gY)
) %>% mutate(jarak = sasaran - realisasi)
print(as.data.frame(jarak %>% mutate(across(where(is.numeric), ~round(.x, 2)))),
      row.names = FALSE)
cat("\nCatatan: sasaran 2 poin TFP Bappenas memakai stok PIM dan pangsa pendapatan\n")
cat("(alfa=1/3). Realisasi di sini residual produksi berbasis arus PMTB dan elastisitas\n")
cat("non-CRS, jadi perbandingan indikatif. Jarak tenaga kerja yang besar adalah\n")
cat("konsekuensi alokasi resmi, bukan temuan residual.\n")

# Pembanding eksternal (semua level nasional, metode berbeda)
# Pembanding, BUKAN validasi. Objeknya berbeda pada ukuran modal, bobot, koreksi
# kualitas tenaga kerja, dan cakupan: efek tahun kami didefinisikan setelah efek
# provinsi disapu, sehingga mengecualikan realokasi antar wilayah yang justru
# termasuk dalam growth accounting nasional. Hanya APO yang periodenya beririsan.
cat("\n=============== 6. Pembanding eksternal (bukan validasi) ===============\n")
pemb <- tribble(
  ~sumber,                            ~periode,    ~tfp,  ~ukuran_modal,  ~bobot,
  "APO (Masterplan Tabel 1)",         "2016-2022", -0.35, "stok",         "pangsa pendapatan",
  "van der Eng (2009)",               "1971-2007", -0.20, "stok PIM",     "pangsa pendapatan",
  "Rusiawan dkk. (2015)",             "1976-2011", -0.62, "stok PIM",     "pangsa Divisia",
  "Kajian ini (efek tahun non-CRS)",  "2017-2024", 100 * unname(par$tren_unc), "arus PMTB", "elastisitas terestimasi (UTAMA)",
  "Kajian ini (efek tahun CRS)",      "2017-2024", 100 * unname(par$tren_crs_lm), "arus PMTB", "elastisitas terestimasi (pembanding)"
)
print(as.data.frame(pemb %>% mutate(tfp = round(tfp, 2))), row.names = FALSE)
cat("\nHanya APO yang periodenya beririsan dengan sampel kami; van der Eng dan\n")
cat("Rusiawan berakhir sebelum sampel dimulai. Kemiripan angka tidak boleh dibaca\n")
cat("sebagai validasi. Basis UTAMA non-CRS memberi ")
cat(sprintf("%+.2f%%/thn, yang lebih tinggi dari seluruh pembanding; varian CRS\n",
            100 * unname(par$tren_unc)))
cat(sprintf("(pembanding) %+.2f%%/thn kebetulan mendekati mereka karena sama-sama memaksakan skala 1.\n",
            100 * unname(par$tren_crs_lm)))

# ==============================================================================
# 7. Dekomposisi per pulau
#
# Unit observasi tetap provinsi; pulau hanya lapisan agregasi, sama kedudukannya
# dengan nasional. Elastisitas TIDAK diestimasi ulang per pulau - dipakai
# elastisitas panel nasional BASIS non-CRS (skenario F) yang sama, sehingga yang
# berbeda antar pulau murni komposisi pertumbuhan inputnya, bukan teknologinya.
# Skenario A (CRS) dipertahankan sebagai pembanding.
# ==============================================================================
cat("\n=============== 7. Dekomposisi per pulau ===============\n")

# Peta pulau. Sheet `prov_name` di xlsx hilang setelah reorganisasi;
# salinannya yang andal adalah CSV di folder processed yang sama.
peta_pulau <- read.csv("01 Data/BKPM/processed/Dataset Provinsi(prov_name).csv") %>%
  select(Code_Prov, Pulau) %>%
  filter(!is.na(Code_Prov), !is.na(Pulau)) %>%
  distinct()

pulau_seri <- df %>%
  mutate(labours_total = rowSums(across(all_of(tk_cols))),
         K_modal = .data[[kol_modal]]) %>%
  filter(!is.na(K_modal), !is.na(labours_total), !is.na(.data[[kol_output]])) %>%
  left_join(peta_pulau, by = "Code_Prov")
stopifnot(!any(is.na(pulau_seri$Pulau)))

pulau_agg <- pulau_seri %>%
  group_by(Pulau, Year) %>%
  summarise(Y = sum(.data[[kol_output]]), K = sum(K_modal), L = sum(labours_total),
            n_prov = n(), .groups = "drop") %>%
  arrange(Pulau, Year) %>%
  group_by(Pulau) %>%
  mutate(g_Y = 100 * (log(Y) - log(dplyr::lag(Y))),
         g_K = 100 * (log(K) - log(dplyr::lag(K))),
         g_L = 100 * (log(L) - log(dplyr::lag(L)))) %>%
  ungroup()

cat("Provinsi per pulau:",
    paste(sprintf("%s(%d)", sort(unique(peta_pulau$Pulau)),
                  as.integer(table(peta_pulau$Pulau))), collapse = " "),
    "| total", nrow(peta_pulau), "\n")

# Dua skenario saja untuk pulau: BASIS non-CRS (F) dan pembanding CRS level (A).
# Menampilkan enam skenario x enam pulau tidak terbaca.
sk_pulau <- skenario %>% filter(grepl("^F\\.|^A\\.", skenario))

dek_pulau <- pulau_agg %>%
  filter(Year >= 2018, Year <= 2024) %>%
  group_by(Pulau) %>%
  summarise(gY = mean(g_Y), gK = mean(g_K), gL = mean(g_L), .groups = "drop") %>%
  crossing(sk_pulau) %>%
  mutate(kontrib_K = b1 * gK, kontrib_L = b2 * gL,
         sisa = gY - kontrib_K - kontrib_L,
         pangsa_sisa = 100 * sisa / gY)

selisih_pulau <- max(abs(dek_pulau$kontrib_K + dek_pulau$kontrib_L +
                           dek_pulau$sisa - dek_pulau$gY))
cat("Cek identitas per pulau, maks =", format(selisih_pulau, scientific = TRUE), "\n")
stopifnot(selisih_pulau < 1e-10)

for (sk in unique(dek_pulau$skenario)) {
  cat(sprintf("\n-- %s --\n", sk))
  print(as.data.frame(dek_pulau %>% filter(skenario == sk) %>%
                        select(Pulau, gY, gK, gL, kontrib_K, kontrib_L, sisa, pangsa_sisa) %>%
                        arrange(desc(sisa)) %>%
                        mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)
}

cat("\nPembanding Masterplan Tabel 6 (TFP rata-rata 2013-22, metode & periode berbeda):\n")
cat("  Sumatra +0,27 | Jawa -1,54 | Nusa Tenggara -7,16 | Kalimantan -3,63\n")
cat("  Sulawesi +1,71 | Maluku +4,29 | Papua +0,16 | Total -1,66\n")
cat("  Catatan: seri output tahunan Tabel 6 untuk 2020-2022 rusak (nilai absolut\n")
cat("  identik bertanda selang-seling), jadi hanya rata-rata periodenya yang dipakai.\n")

# ==============================================================================
# 8. Ekspor
# ==============================================================================
write.xlsx(list(seri_nasional = nas, skenario = skenario,
                dekomposisi = dekomposisi, rentang = rentang,
                pembanding = pemb, jarak_sasaran = jarak,
                pim = grid_pim, seri_pulau = pulau_agg, dekomposisi_pulau = dek_pulau),
           file.path(out_dir, "Dekomposisi Nasional.xlsx"))

cat("\n=============== SELESAI ===============\n")
