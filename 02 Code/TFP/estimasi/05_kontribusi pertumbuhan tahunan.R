# SCRIPT OVERVIEW --------------------------------------
# Stacked column kontribusi pertumbuhan PDRB riil nasional per tahun, 2018-2024.
# Tiga komponen: modal (b1 x gK), tenaga kerja (b2 x gL), dan residual PMTB.
#
# Input  : 03 Output/Dekomposisi Nasional.xlsx  (sheet seri_nasional)
#          03 Output/parameter_terpilih.rds     (b1_un, b2_un)
# Output : 03 Output/Kontribusi Pertumbuhan Tahunan (Nasional).png
#
# CATATAN: skrip ini TIDAK mengestimasi apa pun. Elastisitas dibaca dari
# parameter_terpilih.rds (skenario F, tanpa CRS) dan pertumbuhan dibaca dari
# seri nasional; yang dihitung di sini hanya perkalian dan pengurangan identitas.
#
# Komponen ketiga dilabeli "Residual PMTB" (koreksi 2026-09-05). Di
# log_02_dekomposisi.txt dan di 03_visualisasi.R kolom yang sama bernama `sisa`.
# Isinya residual Solow berbasis arus PMTB, bukan TFP Hicks-neutral.
#
# Path relatif dari ROOT project (.Rproj), mengikuti konvensi CLAUDE.md.
# Jalankan: Rscript "02 Code/05_kontribusi pertumbuhan tahunan.R" dari root.

# 1) Persiapan ----
rm(list = ls())

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Sakelar basis harga modal — sama dengan skrip 01/02/03/04/08. Keluaran versi
# terbit di "03 Output" TIDAK BOLEH ditimpa; basis riil menulis ke foldernya
# sendiri.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"
dir_out <- switch(BASIS_MODAL,
                  riil    = "01 Data/TFP/output/modal_riil",
                  nominal = "01 Data/TFP/output/nominal",
                  adhb    = "01 Data/TFP/output/adhb")

# Lihat 03_visualisasi.R: pada basis adhb residual memuat inflasi harga output,
# jadi ia bukan TFP dan labelnya ikut berubah.
LBL_HARGA <- if (BASIS_ADHB) "harga berlaku" else "riil"
LBL_SISA  <- if (BASIS_ADHB) "Sisa nominal" else "Residual PMTB"

f_dek   <- file.path(dir_out, "Dekomposisi Nasional.xlsx")
f_par   <- file.path(dir_out, "parameter_terpilih.rds")
stopifnot(file.exists(f_dek), file.exists(f_par))
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, dir_out))

# Palet project ada di tingkat BKPM-local, bukan di dalam sub-project TFP ini.
# Di-source, bukan disalin hex-nya: kalau paletnya berubah ia harus berubah di
# satu tempat. Lihat Memory/BKPM/keputusan-visualisasi.md.
#
# Pathnya ditulis sebagai literal (dan karena itu terulang dua kali), bukan
# dirakit file.path() lalu disimpan di variabel: periksa-viz.py menelusuri
# source() dari string literalnya, sehingga versi bervariabel membuat skrip ini
# terbaca "tanpa palet" dan "ekspor tanpa dpi/bg" — dpi dan bg hidup di dalam
# simpan() di berkas palet.
if (!file.exists("02 Code/BKPM/palet-bkpm.R")) {
  stop("berkas palet tidak ketemu: 02 Code/BKPM/palet-bkpm.R\n",
       "jalankan skrip ini dari root project (folder .Rproj), bukan dari 02 Code/")
}
source("02 Code/BKPM/palet-bkpm.R")

## palet rumah ----
# Nilainya sama persis dengan blok palet di 03_visualisasi.R, hanya diambil dari
# berkas palet supaya tidak ada hex kembar yang bisa bercabang.
mega_colors  <- c("Modal"        = unname(PAL$navy_2),   # #0E2440
                  "Tenaga kerja" = unname(PAL$abu),      # #797F8C
                  "TFP"          = unname(PAL$sian))     # #5DD0E6
aksen        <- unname(PAL$merah)     # #D9042B
netral_gelap <- unname(PAL$navy_3)    # #062E4C

# Garis penghubung label sengaja BUKAN warna segmennya: garis sewarna data
# terbaca sebagai bagian dari data.
warna_leader <- "grey60"

sumber_txt <- "Sumber: BPS & BKPM, diolah."

## tema rumah ----
# Ukuran huruf DINAIKKAN dari tema di 03_visualisasi.R (base_size 10, judul 11,
# caption 8). Sebabnya bukan selera: gambar ini ditempel ke Excel selebar ~16 cm,
# dan pada penyusutan itu teks berukuran asli tidak terbaca.
#
# Yang dinaikkan adalah huruf RELATIF TERHADAP LEBAR KANVAS, dan lebar kanvas
# sengaja tidak ikut naik. Menskalakan keduanya bersama-sama menghasilkan gambar
# yang identik setelah ditempel — tidak ada yang berubah bagi pembacanya.
#
# Kanvas 9 inci = 22,9 cm; ditempel 16 cm faktornya 0,70. Jadi teks terkecil
# (caption 10,5 pt) mendarat di ~7,4 pt dan label data (3,6 mm = 10,2 pt) di
# ~7,2 pt — batas bawah yang masih terbaca.
tema_rumah <- theme_classic(base_size = 13) +
  theme(
    plot.title          = element_text(face = "bold", size = 15),
    plot.subtitle       = element_text(size = 12, color = "grey30"),
    # margin t = 12: disamakan dengan 03_visualisasi.R dan 09, supaya jarak
    # caption ke label sumbu-x seragam di seluruh gambar sub-project ini.
    plot.caption        = element_text(color = "grey50", size = 10.5, hjust = 0,
                                       margin = margin(t = 12)),
    plot.caption.position = "plot",
    plot.title.position = "plot",
    panel.grid.major.y  = element_line(color = "grey90", linewidth = 0.4),
    strip.background    = element_blank(),
    strip.text          = element_text(face = "bold", size = 12),
    legend.position     = "bottom",
    legend.title        = element_blank(),
    legend.key.size     = unit(0.5, "cm"),
    legend.text         = element_text(size = 11.5),
    axis.title          = element_text(size = 12),
    axis.text           = element_text(size = 11.5),
    plot.margin         = margin(10, 14, 8, 10)
  )

LAB_SIZE <- 3.6   # mm; x 2,845 = 10,2 pt. Dari 2,6 mm (7,4 pt).

# fmt_id() dan lab_id() datang dari berkas palet. Tidak didefinisikan ulang di
# sini: dua pembantu yang mengerjakan hal sama akan bercabang.

# 2) Data ----
par_tfp <- readRDS(f_par)
b1 <- unname(par_tfp$b1_un)
b2 <- unname(par_tfp$b2_un)

# Batas atas 2024 dipasang 20 Agustus 2026. Seri nasional kini sampai 2025, tapi
# tenaga kerja 2025 disalin dari 2024 secara LOCF sehingga g_L 2025 = 0,00. Batang
# 2025 akan menaruh seluruh pertumbuhan output di segmen TFP — artefak imputasi,
# bukan temuan. Dekomposisi skrip 02 juga tetap berhenti di 2024.
seri <- read.xlsx(f_dek, sheet = "seri_nasional") %>%
  filter(Year >= 2018, Year <= 2024, !is.na(g_Y)) %>%   # 2017 = tahun basis, g_Y NA
  arrange(Year) %>%
  mutate(
    kontrib_modal = b1 * g_K,
    kontrib_tk    = b2 * g_L,
    tfp           = g_Y - kontrib_modal - kontrib_tk
  )

# 3) Uji terhadap log perhitungan ----
# Angka di sini dihitung ulang dari seri, bukan disalin. Yang diuji: hasil
# hitungannya cocok dengan agregat yang dinyatakan log_02_dekomposisi.txt untuk
# skenario F — kolom yang di log bernama `sisa` adalah kolom `tfp` di sini.
#
# Acuan per basis harga modal. Basis nominal (versi terbit) memberi kontribusi
# modal 2,45 poin dan sisa 0,98; basis riil membalikkannya jadi 1,55 dan 2,00,
# karena kolom pmtb versi lama harga BERLAKU sementara outputnya harga konstan.
# Keduanya dipertahankan supaya sakelar tetap bisa dipakai untuk menghasilkan
# ulang gambar versi terbit.
# Basis adhb memindahkan terikat ke 9_ADHB juga, jadi gY-nya laju nominal 6,74.
#
# Vintage B (272 obs, 2017-2024): elastisitas dari parameter_terpilih.rds
# di folder modal_riil. Deret tahunan 2018-2024.
acuan <- switch(BASIS_MODAL,
  riil    = list(b1 = 0.401899, b2 = 0.147184, gY = 3.83, kK = 1.30, kL = 0.31, tfp = 2.22),
  nominal = list(b1 = 0.399673, b2 = 0.191303, gY = 3.83, kK = 2.45, kL = 0.40, tfp = 0.98),
  adhb    = list(b1 = 0.506210, b2 = 0.041713, gY = 6.74, kK = 3.13, kL = 0.09, tfp = 3.52))

# Batas sumbu ditulis eksplisit per basis. Rentang adhb: 2020 -1,73 sampai 2022 12,17.
Y_LIM    <- if (BASIS_ADHB) c(-2.20, 13.20) else c(-2.50, 5.75)
Y_BREAKS <- if (BASIS_ADHB) seq(-2, 13, 2)  else seq(-2, 5, 1)

stopifnot(
  nrow(seri) == 7,
  identical(as.integer(seri$Year), 2018:2024),
  abs(b1 - acuan$b1) < 1e-5,
  abs(b2 - acuan$b2) < 1e-5,
  max(abs(seri$kontrib_modal + seri$kontrib_tk + seri$tfp - seri$g_Y)) < 1e-12,
  abs(mean(seri$g_Y)           - acuan$gY)  < 0.005,
  abs(mean(seri$kontrib_modal) - acuan$kK)  < 0.005,
  abs(mean(seri$kontrib_tk)    - acuan$kL)  < 0.005,
  abs(mean(seri$tfp)           - acuan$tfp) < 0.005
)

# 2020 satu-satunya tahun bertanda negatif, dan ketiga komponennya ikut negatif.
stopifnot(
  any(c(seri$kontrib_modal, seri$kontrib_tk, seri$tfp) < 0),
  seri$g_Y[seri$Year == 2020] < 0
)

# Tanda komponen dan letak penanda g_Y.
#
# Sampai 11 Agustus 2026 tanda tidak pernah bercampur: 2018-2019 dan 2021-2024
# ketiganya positif, 2020 ketiganya negatif. Ujung kolom karena itu selalu jatuh
# TEPAT di g_Y, dan captionnya tidak perlu menjelaskan apa-apa.
#
# Sejak 2025 masuk, b1 naik 0,402 -> 0,475 dan kontribusi modal 2020 melorot ke
# -2,17. Sisa 2020 berbalik jadi POSITIF (+0,23), jadi tanda 2020 kini bercampur
# dan penanda g_Y tidak lagi berimpit dengan ujung kolom di tahun itu. Caption
# menyesuaikan sendiri lewat `tanda_campur` di bawah.
tanda <- seri %>%
  rowwise() %>%
  mutate(n_tanda = n_distinct(sign(c(kontrib_modal, kontrib_tk, tfp)))) %>%
  ungroup()
thn_campur   <- tanda$Year[tanda$n_tanda > 1]
tanda_campur <- length(thn_campur) > 0

# Pencampurannya hanya boleh terjadi di tahun kontraksi. Kalau suatu saat ada
# tahun tumbuh yang tandanya bercampur, skrip berhenti: itu pertanda elastisitas
# bergerak jauh, dan gambarnya perlu dibaca ulang sebelum terbit.
stopifnot(all(seri$g_Y[seri$Year %in% thn_campur] < 0))

# 3b) Cetak angkanya ke log ----
# Skrip ini sebelumnya hanya menggambar dan tidak pernah mencetak angkanya, jadi
# satu-satunya cara membaca seri tahunan adalah membuka PNG-nya. Angka yang
# digambar wajib bisa dibaca sebagai teks juga.
cat("\n=============== Kontribusi pertumbuhan tahunan (poin persen) ===============\n")
print(as.data.frame(seri %>%
                      select(Year, g_Y, g_K, g_L,
                             kontrib_modal, kontrib_tk, tfp) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

cat(sprintf("\nRata-rata %d-%d: gPDRB %.2f%% | gPMTB %.2f%% | gTK %.2f%% | residual %.2f poin\n",
            min(seri$Year), max(seri$Year),
            mean(seri$g_Y), mean(seri$g_K), mean(seri$g_L), mean(seri$tfp)))

# 4) Bentuk panjang + stacking manual ----
# Segmen positif naik dari nol, segmen negatif turun dari nol. Pola ini disalin
# dari 03_visualisasi.R (baris 104-107); position_stack menumpuk nilai negatif
# ke atas dan itu menyembunyikan tandanya.
komponen_lv <- names(mega_colors)   # Modal (bawah) -> Tenaga kerja -> TFP (atas)

g_long <- seri %>%
  transmute(Year,
            `Modal`        = kontrib_modal,
            `Tenaga kerja` = kontrib_tk,
            `TFP`          = tfp) %>%
  pivot_longer(-Year, names_to = "komponen", values_to = "nilai") %>%
  mutate(komponen = factor(komponen, levels = komponen_lv)) %>%
  arrange(Year, komponen) %>%
  group_by(Year) %>%
  mutate(
    pos_cum = cumsum(ifelse(nilai > 0, nilai, 0)),
    neg_cum = cumsum(ifelse(nilai < 0, nilai, 0)),
    ymax    = ifelse(nilai > 0, pos_cum, neg_cum - nilai),
    ymin    = ifelse(nilai > 0, pos_cum - nilai, neg_cum)
  ) %>%
  ungroup()

g_tot <- seri %>% transmute(Year, g_Y)

# 5) Label 21 segmen: di luar batang, disambung leader line ----
# Ketiga segmen diberi angka, bukan hanya TFP. Segmen tenaga kerja setipis 0,38
# poin (dan -0,15 pada 2020) tidak mungkin memuat teks di dalamnya, jadi SELURUH
# label ditaruh di luar supaya perlakuannya seragam — label yang sebagian di
# dalam dan sebagian di luar terbaca sebagai dua jenis angka yang berbeda.
#
# Geometri, satuan sumbu x = 1 tahun. Label duduk di kanan batang PEMILIKNYA,
# jadi jarak ke batang sendiri harus jelas lebih kecil daripada jarak ke batang
# berikutnya. Versi pertama memakai LAB_X 0,44 dan label berakhir di ~0,60,
# nyaris di tengah-tengah antara dua batang — angkanya jadi bisa terbaca milik
# kolom sebelah kanan.
#
# Angka di bawah dipersempit lagi saat huruf label dinaikkan ke 3,6 mm. Label
# empat karakter kini selebar ~0,27 satuan sumbu x (dari ~0,16), jadi dengan
# BAR_HALF 0,26 jarak label ke batang sendiri dan ke batang berikutnya jadi
# sama besar — dan aturannya jarak ke pemiliknya harus jelas lebih kecil.
BAR_HALF   <- 0.20   # setengah lebar batang; 0,34 -> 0,26 -> 0,20
LEADER_IN  <- 0.21   # pangkal leader, tepat di luar tepi batang
LEADER_OUT <- 0.29   # ujung leader
LAB_X      <- 0.32   # awal teks, hjust = 0
PENANDA    <- 0.27   # setengah panjang garis penanda g_Y. Harus LEBIH PANJANG
                     # dari BAR_HALF: karena tanda komponen tidak pernah
                     # bercampur, penanda selalu jatuh tepat di ujung kolom, dan
                     # kalau panjangnya sama persis ia terbaca sebagai tepi
                     # batang berwarna merah, bukan sebagai penanda. Dicoba 0,26
                     # di putaran 2 dan hasilnya begitu.

# Label ditaruh di tengah segmennya, LALU disebar kalau berdempetan. Yang butuh
# penyebaran hanya 2020: pusat segmen tenaga kerja dan TFP di sana berjarak 0,24
# poin, di bawah ambang keterbacaan. Enam tahun lainnya lewat tanpa digeser.
#
# ggrepel tidak dipakai walau boleh: penempatannya diacak ulang tiap render dan
# tidak bisa diperiksa dari kode. Penyebaran deterministik di bawah menghasilkan
# gambar yang sama tiap kali, dan jaraknya bisa dibaca sebagai angka.
# Naik dari 0,34 ke 0,42 saat huruf label dinaikkan ke 3,6 mm: tinggi huruf
# bertambah ~38%, dan ambang yang tidak ikut naik akan membuat label 2020
# bertumpuk lagi.
MIN_GAP <- 0.42   # poin persen

sebar <- function(y, min_gap) {
  o  <- order(y)
  ys <- y[o]
  for (i in seq_along(ys)[-1]) {
    if (ys[i] - ys[i - 1] < min_gap) ys[i] <- ys[i - 1] + min_gap
  }
  ys   <- ys - (mean(ys) - mean(y))   # pusat kelompok dikembalikan ke asalnya
  y[o] <- ys
  y
}

lab <- g_long %>%
  mutate(y_seg = (ymin + ymax) / 2) %>%
  group_by(Year) %>%
  mutate(y_lab = sebar(y_seg, MIN_GAP)) %>%
  ungroup()

# 6) Gambar ----
p <- ggplot() +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_rect(data = g_long,
            aes(xmin = Year - BAR_HALF, xmax = Year + BAR_HALF,
                ymin = ymin, ymax = ymax, fill = komponen)) +
  geom_segment(data = g_tot,
               aes(x = Year - PENANDA, xend = Year + PENANDA, y = g_Y, yend = g_Y),
               color = aksen, linewidth = 0.6) +
  geom_point(data = g_tot, aes(x = Year, y = g_Y),
             color = aksen, size = 1.7, shape = 18) +
  geom_segment(data = lab,
               aes(x = Year + LEADER_IN, xend = Year + LEADER_OUT,
                   y = y_seg, yend = y_lab),
               color = warna_leader, linewidth = 0.3) +
  geom_text(data = lab,
            aes(x = Year + LAB_X, y = y_lab, label = fmt_id(nilai, 2)),
            hjust = 0, size = LAB_SIZE, color = netral_gelap) +
  scale_fill_manual(values = mega_colors,
                    labels = c("Modal", "Tenaga kerja", LBL_SISA)) +
  # Batas kanan memberi ruang untuk label 2024 yang berdiri di luar batangnya.
  scale_x_continuous(breaks = 2018:2024, limits = c(2017.50, 2024.68),
                     expand = c(0, 0)) +
  # Batas bawah menampung penanda 2020 (-2,05) dan label TFP yang digeser turun
  # di bawahnya; batas atas penanda 2018 (5,29). Dilonggarkan dari
  # c(-2,35; 5,60) saat huruf dinaikkan. Basis adhb berayun jauh lebih lebar
  # (2020 -1,73 sampai 2022 12,17), jadi batasnya bercabang, bukan otomatis.
  scale_y_continuous(labels = lab_id(1), breaks = Y_BREAKS, limits = Y_LIM,
                     expand = c(0, 0)) +
  labs(
    title   = sprintf("Sumber pertumbuhan PDRB %s nasional, 2018-2024", LBL_HARGA),
    x       = NULL,
    y       = "Poin persen",
    caption = paste0("Garis merah: pertumbuhan aktual. ", LBL_SISA,
                     " di sini residual produksi berbasis PMTB.\n",
                     if (tanda_campur) {
                       sprintf(paste0("Di %s tanda komponennya bercampur, jadi ujung kolom ",
                                      "tidak berimpit dengan garis merah.\n"),
                               paste(thn_campur, collapse = " dan "))
                     } else "",
                     sumber_txt)
  ) +
  tema_rumah

# Lebar DIPERTAHANKAN 9 inci. Kalau lebarnya ikut naik bersama hurufnya, gambar
# yang ditempel 16 cm akan terlihat persis seperti sebelumnya. Tinggi naik dari
# 5,6 ke 6,5 karena huruf yang lebih besar menuntut ruang vertikal untuk 21
# label plus judul, legend, dan caption.
simpan(p, file.path(dir_out, "Kontribusi Pertumbuhan Tahunan (Nasional).png"),
       lebar = 9, tinggi = 6.5)
