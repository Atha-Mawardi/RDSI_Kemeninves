# SCRIPT OVERVIEW --------------------------------------
# Visualisasi simulasi trajektori 2026-2029 menuju sasaran 8%.
#
# Input  : <dir_out>/Simulasi Trajektori 2026-2029.xlsx
#            sheet strategi_stacked
# Output : 1 PNG di <dir_out>
#   Strategi RTS dan TFP 2026-2029.png
#
# Skrip ini TIDAK menghitung ulang simulasi; ia membaca keluaran
# 08_simulasi trajektori.R dan merakit label. Semua angka yang tercetak di
# gambar dirakit dengan sprintf/fmt_id dari data — tidak ada yang diketik.
#
# Jalankan dari root sub-project TFP, SETELAH skrip 08:
#   Rscript "02 Code/09_visualisasi trajektori.R"
#
# PESAN YANG HARUS SAMPAI ----------------------------------------------------
# "Selama modal dan tenaga kerja ditahan di laju 2022-2024, seluruh jarak
#  menuju sasaran harus ditutup TFP — dan jaraknya melebar tiap tahun."
#   Tinggi segmen modal dan tenaga kerja sama di keempat panel; yang memanjang
#   hanya segmen TFP, sampai menyentuh garis sasaran.
#   Perbandingan DRS dan CRS memperlihatkan bahwa pembagian antar segmen ikut
#   berubah bersama asumsi skala hasil, sementara totalnya tetap sasaran.
# ------------------------------------------------------

rm(list = ls())

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Sakelar basis harga modal — sama dengan skrip 01/02/03/04/05/08.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"
dir_out <- switch(BASIS_MODAL,
                  riil    = "03 Output (modal riil)",
                  nominal = "03 Output",
                  adhb    = "03 Output (ADHB)")

# Basis adhb TIDAK menghasilkan gambar di sini, dan itu keputusan substansi,
# bukan keterbatasan teknis. Sasaran 8 persen Masterplan didefinisikan atas
# pertumbuhan PDB RIIL. Pada basis adhb laju basis 2022-2024 adalah 8,72 persen
# NOMINAL, jadi gambarnya akan memperlihatkan sasaran yang sudah terlampaui
# 0,72 poin - padahal yang dibandingkan dua besaran berbeda. Itu kesalahan
# kategori yang sejenis dengan yang diperbaiki pemindahan basis modal ini.
#
# Angkanya tetap ada dan bisa ditelusuri di Simulasi Trajektori 2026-2029.xlsx
# hasil skrip 08. Yang tidak dibuat hanyalah gambar yang akan salah dibaca.
if (BASIS_ADHB) {
  cat("Basis adhb: gambar trajektori sengaja TIDAK dibuat.\n")
  cat("Alasan: sasaran 8 persen Masterplan adalah pertumbuhan riil, sedangkan\n")
  cat("laju basis pada basis ini nominal. Membandingkannya tidak setara.\n")
  cat("Angka simulasinya tetap tersedia di Simulasi Trajektori 2026-2029.xlsx.\n")
  quit(save = "no", status = 0)
}

f_traj <- file.path(dir_out, "Simulasi Trajektori 2026-2029.xlsx")
stopifnot(file.exists(f_traj))
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, dir_out))

# Path palet ditulis LITERAL (karena itu terulang dua kali): periksa-viz.py
# menelusuri source() dari string literalnya, jadi versi bervariabel membuat
# skrip ini terbaca "tanpa palet" sekaligus "ekspor tanpa dpi/bg".
if (!file.exists("../../02 Code/00_palet-bkpm.R")) {
  stop("berkas palet tidak ketemu: ../../02 Code/00_palet-bkpm.R\n",
       "jalankan skrip ini dari root sub-project TFP, bukan dari 02 Code/")
}
source("../../02 Code/00_palet-bkpm.R")

## palet ----
# Sama persis dengan mega_colors di 03_visualisasi.R: pembaca membaca warna
# sebagai identitas komponen lintas gambar, bukan sebagai keputusan per-gambar.
warna_komponen <- c("Modal"        = unname(PAL$navy_2),
                    "Tenaga kerja" = unname(PAL$abu),
                    "TFP"          = unname(PAL$sian))
aksen        <- unname(PAL$merah)     # garis sasaran
netral_gelap <- unname(PAL$navy_3)    # teks label angka

sumber_txt <- "Sumber: BPS & BKPM, diolah."

## tema ----
# Ukuran huruf dan lebar kanvas mengikuti 03_visualisasi.R dan
# 05_kontribusi pertumbuhan tahunan.R: gambar ditempel ke lembar Excel ~16 cm,
# jadi huruf naik sementara lebar kanvas dikunci 9 inci.
LEBAR <- 9

tema_rumah <- theme_classic(base_size = 13) +
  theme(
    plot.title            = element_text(face = "bold", size = 15),
    plot.subtitle         = element_text(size = 12, color = "grey30"),
    # margin t = 12: sama dengan 03_visualisasi.R — jarak bawaan caption ke
    # label sumbu-x hanya ~6 pt dan keduanya terbaca menempel.
    plot.caption          = element_text(color = "grey50", size = 10.5, hjust = 0,
                                         margin = margin(t = 12)),
    plot.caption.position = "plot",
    plot.title.position   = "plot",
    panel.grid.major.y    = element_line(color = "grey90", linewidth = 0.4),
    strip.background      = element_blank(),
    strip.text            = element_text(face = "bold", size = 12),
    legend.position       = "bottom",
    legend.title          = element_blank(),
    legend.key.size       = unit(0.5, "cm"),
    legend.text           = element_text(size = 11.5),
    axis.title            = element_text(size = 12),
    axis.text             = element_text(size = 11.5),
    plot.margin           = margin(10, 14, 8, 10)
  )

# Panjang baris teks, dalam karakter. Diukur di eyetest putaran 1: pada lebar
# kanvas 9 inci, subtitle 12 pt mulai TERPOTONG di tepi kanan sekitar 110
# karakter dan caption 10,5 pt sekitar 125. muat() mengubahnya jadi pemeriksaan
# terhitung — putaran pertama kehilangan ujung kalimat di enam gambar sekaligus,
# dan itu baru terlihat setelah PNG-nya dibuka satu per satu.
MAKS_SUBTITLE <- 100
MAKS_CAPTION  <- 115

muat <- function(teks, maks) {
  baris   <- strsplit(teks, "\n", fixed = TRUE)[[1]]
  panjang <- nchar(baris)
  if (any(panjang > maks)) {
    stop("baris teks ", max(panjang), " karakter, batas ", maks, ": ",
         baris[which.max(panjang)])
  }
  teks
}

# fmt_id(), lab_id(), persen_id(), simpan() datang dari berkas palet.

# ==============================================================================
# Strategi RTS dan TFP: kebutuhan TFP per tahun sasaran, tiga skenario
# ==============================================================================

## konstanta tata letak ----
URUT_SKENARIO <- c("1. Tanpa intervensi", "2. RTS tetap DRS", "3. RTS penuh CRS",
                   "4. Modal dan TK tumbuh 8%")
# Kode skenario, bukan nama. Gambar ini dipakai di deck dan pemilik project
# menjelaskan artinya sendiri di sana, jadi gambarnya tidak menerangkan diri.
#   NI  = tanpa intervensi
#   TFP = TFP mengejar sasaran, skala hasil tetap DRS
#   CRS = TFP mengejar sasaran, skala hasil dipaksa 1,0
#   Gr  = modal dan tenaga kerja tumbuh 8 persen, TFP tetap di basis
LABEL_PENDEK  <- c("NI", "TFP", "CRS", "Gr")

# Skenario 4 satu-satunya yang lajunya berbeda; dipakai untuk memisahkannya saat
# menghitung laju basis yang dicetak di subtitle.
SKEN_INPUT8   <- "4. Modal dan TK tumbuh 8%"

BAR_HALF      <- 0.30   # setengah lebar batang, satuan sumbu x = 1 kategori
X_LIM         <- c(0.45, 4.55)   # garis sasaran membentang persis selebar ini
Y_LIM         <- c(0, 8.80)      # eksplisit, bukan otomatis; diuji di bawah
Y_BREAKS      <- seq(0, 8, 1)
JARAK_TOTAL   <- 0.22   # jarak label total di atas ujung batang
UKURAN_TOTAL  <- 3.4    # mm
UKURAN_TFP    <- 3.2    # mm

## 1) Baca data ----
strategi <- read.xlsx(f_traj, sheet = "strategi_stacked")

## 2) Uji data yang dibaca ----
# Isi sheet tidak dipercaya begitu saja: gambar ini menampilkan identitas
# dekomposisi, jadi kalau identitasnya tidak tertutup gambarnya bohong.
hitung_skenario <- table(factor(strategi$skenario, levels = URUT_SKENARIO))
tfp_drs <- strategi$kontrib_tfp[strategi$skenario == "2. RTS tetap DRS"]
tfp_crs <- strategi$kontrib_tfp[strategi$skenario == "3. RTS penuh CRS"]
# konstan lintas tahun di dalam tiap skenario -> rentangnya nol
rentang_modal <- strategi %>%
  group_by(skenario) %>%
  summarise(r = diff(range(kontrib_modal)), .groups = "drop")
rentang_tk <- strategi %>%
  group_by(skenario) %>%
  summarise(r = diff(range(kontrib_tk)), .groups = "drop")

stopifnot(
  nrow(strategi) == 16,                                    # (1)
  all(hitung_skenario == 4),
  max(abs(strategi$kontrib_modal + strategi$kontrib_tk +
            strategi$kontrib_tfp - strategi$total)) < 1e-9, # (2)
  max(rentang_modal$r) < 1e-9, max(rentang_tk$r) < 1e-9,    # (3)
  all(tfp_drs > tfp_crs),                                   # (4)
  max(strategi$total) <= Y_LIM[2]                           # (5)
)

## 3) Laju input yang dipakai tiap kelompok batang ----
# Nilainya tidak diketik: kontribusi = elastisitas x laju, jadi lajunya dibalik
# dari data. Tiga batang pertama memakai laju basis yang sama walau kontribusinya
# berbeda, karena yang berbeda hanya elastisitasnya. Batang keempat sengaja lain.
basis  <- strategi[strategi$skenario != SKEN_INPUT8, ]
input8 <- strategi[strategi$skenario == SKEN_INPUT8, ]

laju_modal <- unique(round(basis$kontrib_modal / basis$b1, 6))
laju_tk    <- unique(round(basis$kontrib_tk / basis$b2, 6))
laju_input8 <- unique(round(c(input8$kontrib_modal / input8$b1,
                              input8$kontrib_tk / input8$b2), 6))
stopifnot(length(laju_modal) == 1, length(laju_tk) == 1, length(laju_input8) == 1)

# Batang keempat menahan TFP di basis, jadi segmen TFP-nya wajib sama dengan
# batang pertama. Kalau tidak, ia sudah bukan skenario "hanya input yang naik".
stopifnot(all(abs(input8$kontrib_tfp -
                    strategi$kontrib_tfp[strategi$skenario == URUT_SKENARIO[1]]) < 1e-9))

## 4) Koordinat batang ----
segmen <- strategi %>%
  transmute(Year, skenario,
            `Modal`        = kontrib_modal,
            `Tenaga kerja` = kontrib_tk,
            `TFP`          = kontrib_tfp) %>%
  pivot_longer(c(`Modal`, `Tenaga kerja`, `TFP`),
               names_to = "komponen", values_to = "nilai") %>%
  mutate(skenario = factor(skenario, levels = URUT_SKENARIO),
         komponen = factor(komponen, levels = names(warna_komponen))) %>%
  arrange(Year, skenario, komponen) %>%
  group_by(Year, skenario) %>%
  mutate(ymax = cumsum(nilai),
         ymin = ymax - nilai) %>%
  ungroup() %>%
  mutate(x = as.integer(skenario))

lab_total <- strategi %>%
  mutate(skenario = factor(skenario, levels = URUT_SKENARIO),
         x = as.integer(skenario))

lab_tfp <- segmen %>%
  filter(komponen == "TFP") %>%
  mutate(y = (ymin + ymax) / 2)

sasaran <- strategi %>% distinct(Year, gY_target)

## 5) Gambar ----
p <- ggplot() +
  geom_rect(data = segmen,
            aes(xmin = x - BAR_HALF, xmax = x + BAR_HALF,
                ymin = ymin, ymax = ymax, fill = komponen)) +
  geom_segment(data = sasaran,
               aes(x = X_LIM[1], xend = X_LIM[2],
                   y = gY_target, yend = gY_target),
               color = aksen, linewidth = 0.6) +
  geom_text(data = lab_total,
            aes(x = x, y = total + JARAK_TOTAL, label = fmt_id(total, 2)),
            size = UKURAN_TOTAL, color = netral_gelap) +
  geom_text(data = lab_tfp,
            aes(x = x, y = y, label = fmt_id(nilai, 2)),
            size = UKURAN_TFP, color = netral_gelap) +
  facet_wrap(~ Year, nrow = 1) +
  scale_fill_manual(values = warna_komponen) +
  scale_x_continuous(breaks = 1:4, labels = LABEL_PENDEK,
                     limits = X_LIM, expand = c(0, 0)) +
  scale_y_continuous(labels = lab_id(1), breaks = Y_BREAKS,
                     limits = Y_LIM, expand = c(0, 0)) +
  labs(
    # Teks gambar sengaja minimal: keterangan skenario disampaikan pemilik
    # project di deck, bukan di kanvas.
    title    = "Sumber pertumbuhan per skenario, 2026-2029",
    subtitle = muat(sprintf("gPMTB %s%%; gTK %s%%; Gr: keduanya %s%%. Garis merah: sasaran.",
                            fmt_id(laju_modal, 2), fmt_id(laju_tk, 2),
                            fmt_id(laju_input8, 2)),
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "Poin persen",
    fill     = NULL,
    caption  = sumber_txt
  ) +
  tema_rumah

simpan(p, file.path(dir_out, "Strategi RTS dan TFP 2026-2029.png"),
       lebar = LEBAR, tinggi = 5.6)

cat("Selesai: 1 PNG tersimpan di", dir_out, "\n")
