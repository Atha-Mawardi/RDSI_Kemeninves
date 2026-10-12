# SCRIPT OVERVIEW --------------------------------------
# Visualisasi hasil estimasi TFP & dekomposisi pertumbuhan nasional.
#
# Input  : <out_dir>/Hasil Estimasi TFP.xlsx
#          <out_dir>/Dekomposisi Nasional.xlsx
#          <out_dir>/parameter_terpilih.rds
# Output : 8 PNG di <out_dir>
#   1) Dekomposisi Pertumbuhan Nasional.png
#   2) Indeks TFP Nasional.png
#   3) Peringkat TFP Provinsi.png
#   4) Tangga Atenuasi Elastisitas.png
#   5) Amplop Sisa vs Elastisitas Modal.png
#   6) Dekomposisi per Pulau.png
#   7) Indeks TFP per Pulau.png
#   8) Kontribusi Kumulatif Faktor.png
#
# Skrip ini TIDAK menghitung ulang estimasi apa pun, hanya membaca hasil dan
# merakit label. SEMUA angka yang tercetak di gambar dirakit dengan sprintf/
# fmt_id dari data yang dibaca — tidak ada satu pun yang diketik tangan.
#
# Jalankan dari root project (folder .Rproj-nya sub-project TFP):
#   Rscript "02 Code/03_visualisasi.R"
# ------------------------------------------------------
#
# PERUBAHAN BASIS MODAL (Agustus 2026) --------------------------------
# Kolom `pmtb` yang dipakai versi terbit ternyata harga BERLAKU, sedangkan
# variabel terikat 9_ADHK harga konstan. Basis dipindah ke 4_ADHK (PMTB harga
# konstan). Angka berubah besar, dan beberapa kalimat di gambar versi lama
# menjadi keliru. Yang ditulis ulang di sini, beserta sebabnya:
#
#   G1  subtitle menyebut "b1 = 0,400; b2 = 0,191"  -> b2 riil 0,147. Dirakit
#       dari parameter, tidak lagi diketik.
#   G1  caption "sisanya (0,98 poin)"               -> 2,21 poin.
#   G1  caption "segmen negatif digambar turun di bawah nol" -> pada basis riil
#       TIDAK ADA komponen negatif di skenario mana pun. Kalimat dibuang, dan
#       assertion mengunci ketiadaannya.
#   G1  skenario C dulu dibuang karena "kontribusi modalnya 134 persen dari
#       pertumbuhan". Pada basis riil kontribusi modal C = 71,6 persen dan
#       stacknya sama tinggi dengan yang lain, jadi kedua alasan pembuangan
#       gugur. C DIKEMBALIKAN ke gambar.
#   G3  subtitle "level log TFP berkisar 13,5 di semua provinsi" -> pada basis
#       riil level log TFP 22,5-24,7. Angkanya dirakit dari data.
#   G4  judul "skala hasil menurun seiring makin banyak variasi dibuang" dan
#       caption "penurunan berurutan dari 1,011 ke 0,591" -> pada basis riil
#       tangganya TIDAK monoton: 1,011 -> 1,075 -> 1,189 -> 0,549. Judul dan
#       caption ditulis ulang jadi deskriptif, dan assertion mengunci
#       ketidak-monotonannya.
#   G5  amplop "sisa = 1,75 - 4,05 x b1", titik impas b1 = 0,433, dan kalimat
#       "seluruh estimasi berada di wilayah sisa kecil" -> amplop riil
#       "sisa = 1,75 - 1,18 x b1", impas di b1 = 1,478 (di luar jangkauan),
#       jadi sisa SELALU positif. Ceritanya berbalik dan ditulis ulang.
#   G6  subtitle "b1 = 0,400; b2 = 0,191)" (plus kurung nyasar) -> dirakit.
#   G8  subtitle "(b1 = 0,400; b2 = 0,191)" -> dirakit.
#
# Label seri "Sisa (TFP + galat)" sempat diganti "TFP". Koreksi 2026-09-05:
# residual produksi berbasis arus PMTB, bukan TFP Hicks-neutral. Nama berkas PNG
# tidak diubah. Kunci warna mega_colors tetap "TFP"; tampilan lewat labels=.
#
# Caption seluruh gambar DIPENDEKKAN ke maksimal dua baris + sumber, mengikuti
# gaya gambar 05. Sebelumnya 4-6 baris per gambar.
# ------------------------------------------------------

# 1) Persiapan ----
rm(list = ls())

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Sakelar basis harga modal — sama dengan skrip 01/02/04/08. Keluaran versi
# terbit di "03 Output" TIDAK BOLEH ditimpa; basis riil menulis ke foldernya
# sendiri.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"
dir_out <- switch(BASIS_MODAL,
                  riil    = "01 Data/TFP/output/modal_riil",
                  nominal = "01 Data/TFP/output/nominal",
                  adhb    = "01 Data/TFP/output/adhb")

# Kata sifat basis harga untuk judul dan sumbu, dan nama residual. Pada basis adhb
# residual memuat inflasi harga output, jadi ia BUKAN TFP dan tidak boleh dilabeli
# begitu. Pada basis riil pun residual = produksi berbasis PMTB, bukan TFP Hicks-
# neutral. Kunci warna di mega_colors tetap "TFP" supaya palet tidak pecah;
# penggantinya lewat argumen labels= di scale_fill_manual.
LBL_HARGA <- if (BASIS_ADHB) "harga berlaku" else "riil"
LBL_SISA  <- if (BASIS_ADHB) "Sisa nominal" else "Residual PMTB"

f_tfp <- file.path(dir_out, "Hasil Estimasi TFP.xlsx")
f_dek <- file.path(dir_out, "Dekomposisi Nasional.xlsx")
f_par <- file.path(dir_out, "parameter_terpilih.rds")
stopifnot(file.exists(f_tfp), file.exists(f_dek), file.exists(f_par))
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, dir_out))

# Palet project ada di tingkat BKPM-local, bukan di dalam sub-project TFP.
# Pathnya ditulis LITERAL (karena itu terulang dua kali): periksa-viz.py
# menelusuri source() dari string literalnya, jadi versi bervariabel membuat
# skrip ini terbaca "tanpa palet" sekaligus "ekspor tanpa dpi/bg" — dpi dan bg
# hidup di dalam simpan() di berkas palet.
if (!file.exists("02 Code/BKPM/palet-bkpm.R")) {
  stop("berkas palet tidak ketemu: 02 Code/BKPM/palet-bkpm.R\n",
       "jalankan skrip ini dari root project (.Rproj), bukan dari 02 Code/")
}
source("02 Code/BKPM/palet-bkpm.R")

## palet rumah ----
# Nilainya sama persis dengan blok palet inline versi lama, hanya diambil dari
# berkas palet supaya tidak ada hex kembar yang bisa bercabang.
mega_colors  <- c("Modal"        = unname(PAL$navy_2),   # #0E2440
                  "Tenaga kerja" = unname(PAL$abu),      # #797F8C
                  "TFP"          = unname(PAL$sian))     # #5DD0E6
aksen        <- unname(PAL$merah)     # #D9042B
netral_gelap <- unname(PAL$navy_3)    # #062E4C
netral_sedang<- unname(PAL$abu)
warna_leader <- "grey60"              # sengaja bukan warna segmennya

# PAL_PULAU dari berkas palet memakai ejaan "Bali-Nusa Tenggara"; data di sini
# memakai "Bali-Nusra". Alias untuk keduanya sudah ada di berkas palet.
pulau_colors <- PAL_PULAU[c("Sumatera", "Jawa", "Bali-Nusra",
                            "Kalimantan", "Sulawesi", "Maluku-Papua")]
# Sumatera krem terang tidak terbaca sebagai GARIS di atas latar putih; versi
# lebih gelap dipakai khusus untuk garis, isian ribbon tetap krem.
pulau_lines <- pulau_colors
pulau_lines[["Sumatera"]] <- "#A68B4B"

sumber_txt <- "Sumber: BPS & BKPM, diolah."

## tema rumah ----
# Ukuran huruf mengikuti revisi 05_kontribusi pertumbuhan tahunan.R: gambar-
# gambar ini ditempel ke lembar Excel selebar ~16 cm dan pada penyusutan itu
# teks berukuran lama (base 10, caption 8) tidak terbaca.
#
# Yang dinaikkan huruf RELATIF TERHADAP LEBAR KANVAS. Lebar kanvas dikunci
# 9 inci untuk SELURUH gambar; kalau lebar ikut naik bersama hurufnya, gambar
# yang ditempel 16 cm terlihat persis seperti sebelumnya. Hanya tinggi yang
# menyesuaikan isi.
LEBAR <- 9   # inci, seragam untuk kedelapan gambar

tema_rumah <- theme_classic(base_size = 13) +
  theme(
    plot.title            = element_text(face = "bold", size = 15),
    plot.subtitle         = element_text(size = 12, color = "grey30"),
    # margin t = 12: dengan caption.position "plot", jarak bawaan caption ke
    # label sumbu-x hanya ~6 pt, dan pada gambar berfacet keduanya saling
    # menempel. Dinaikkan untuk SELURUH gambar supaya jaraknya seragam.
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

LAB_SIZE  <- 3.6   # mm; x 2,845 = 10,2 pt — label data utama
LAB_KECIL <- 3.2   # mm; blok keterangan dan anotasi sekunder

# Panjang baris teks, dalam karakter. Angkanya diukur di eyetest putaran 1:
# pada lebar kanvas 9 inci, subtitle 12 pt mulai TERPOTONG di tepi kanan sekitar
# 110 karakter dan caption 10,5 pt sekitar 125. Enam dari sebelas gambar putaran
# pertama kehilangan ujung kalimatnya persis karena ini, dan itu tidak kelihatan
# sampai PNG-nya dibuka. Batas di bawah memberi margin, dan muat() mengubahnya
# jadi pemeriksaan terhitung supaya tidak perlu dicari dengan mata lagi.
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

# fmt_id(), lab_id(), persen_id(), dan simpan() datang dari berkas palet.
# Tidak didefinisikan ulang: dua pembantu yang mengerjakan hal sama bercabang.

# Geometri label-di-luar-batang, dipakai G1 dan G6. Satuan sumbu x = 1 kategori,
# angkanya disalin dari 05_kontribusi pertumbuhan tahunan.R yang sudah lolos
# tiga putaran eyetest pada huruf 3,6 mm dan lebar kanvas 9 inci.
BAR_HALF   <- 0.20   # setengah lebar batang
LEADER_IN  <- 0.21   # pangkal leader, tepat di luar tepi batang
LEADER_OUT <- 0.29   # ujung leader
LAB_X      <- 0.32   # awal teks, hjust = 0
PENANDA    <- 0.27   # setengah panjang garis penanda gY; HARUS lebih panjang
                     # dari BAR_HALF, kalau sama ia terbaca sebagai tepi batang
                     # berwarna merah alih-alih sebagai penanda
MIN_GAP    <- 0.42   # poin persen; jarak minimum antar label dalam satu kolom

# Label ditaruh di tengah segmennya, LALU disebar kalau berdempetan. ggrepel
# tidak dipakai walau boleh dipasang: penempatannya tidak bisa dibaca dari kode
# dan bisa bergeser antar render. Penyebaran di bawah deterministik.
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

# Stacking manual: segmen positif naik dari nol, segmen negatif turun dari nol.
# position_stack menumpuk nilai negatif ke atas dan itu menyembunyikan tandanya.
tumpuk <- function(df, grup) {
  df %>%
    arrange({{ grup }}, komponen) %>%
    group_by({{ grup }}) %>%
    mutate(
      pos_cum = cumsum(ifelse(nilai > 0, nilai, 0)),
      neg_cum = cumsum(ifelse(nilai < 0, nilai, 0)),
      ymax    = ifelse(nilai > 0, pos_cum, neg_cum - nilai),
      ymin    = ifelse(nilai > 0, pos_cum - nilai, neg_cum)
    ) %>%
    ungroup()
}

# 2) Parameter dan uji terhadap log ----
par_tfp <- readRDS(f_par)
b1 <- unname(par_tfp$b1_un)
b2 <- unname(par_tfp$b2_un)

# Angka acuan disalin dari log perhitungan, dan salinannya diuji di sini.
# Vintage B (folder modal_riil, 272 obs 2017-2024, snapshot 0820):
#   b1=0,4019 b2=0,1472; F: modal 1,30 · TK 0,31 · residual 2,22.
# Acuan 20 Agustus (N=306, tenaga kerja 2025 LOCF) TIDAK dipakai di folder ini.
# nominal : nilai versi terbit (vintage A).
# adhb    : run ADHB di folder adhb (bila ada).
acuan <- switch(BASIS_MODAL,
  riil    = list(b1 = 0.401899, b2 = 0.147184, gY = 3.83, kK = 1.30, kL = 0.31, tfp = 2.22),
  nominal = list(b1 = 0.399673, b2 = 0.191303, gY = 3.83, kK = 2.45, kL = 0.40, tfp = 0.98),
  adhb    = list(b1 = 0.506210, b2 = 0.041713, gY = 6.74, kK = 3.13, kL = 0.09, tfp = 3.52))

# Batas sumbu ditulis eksplisit per basis, bukan dihitung otomatis. Batas otomatis
# akan menggeser gambar versi terbit sepersekian poin dan memicu diff PNG yang
# tidak perlu; batas bercabang menjaga dua folder lama persis seperti sekarang.
G1_Y_LIM    <- if (BASIS_ADHB) c(0, 7.40)   else c(0, 4.30)
G1_Y_BREAKS <- if (BASIS_ADHB) seq(0, 7, 1) else seq(0, 4, 0.5)
G6_Y_LIM    <- if (BASIS_ADHB) c(0, 9.60)     else c(0, 6.35)
G6_Y_BREAKS <- if (BASIS_ADHB) seq(0, 9, 1)   else seq(0, 6, 1)
G4_Y_LIM    <- if (BASIS_ADHB) c(0, 1.68)       else c(0, 1.38)
G4_Y_BREAKS <- if (BASIS_ADHB) seq(0, 1.6, 0.2) else seq(0, 1.2, 0.2)
G5_Y_LIM    <- if (BASIS_ADHB) c(0, 4.95)       else c(0, 1.98)
G5_Y_BREAKS <- if (BASIS_ADHB) seq(0, 4.5, 0.5) else seq(0, 2, 0.25)
# Blok keterangan duduk DI BAWAH garis ambang (adhb: 1,68), bukan memotongnya.
# Di eyetest putaran 1 posisi 2,00 membuat garis putus-putus mencoret baris kedua.
G5_KET_Y    <- if (BASIS_ADHB) 1.50             else 0.55
# Indeks nasional adhb mencapai 133,7 pada 2024; batas 125 memotong garisnya.
G2_Y_LIM    <- if (BASIS_ADHB) c(97, 142)        else c(97, 125)
G2_Y_BREAKS <- if (BASIS_ADHB) seq(100, 140, 5)  else seq(96, 124, 4)
# Gambar 8 memakai lim8 yang dirakit dari data; hanya breaks-nya yang perlu
# melebar, karena indeks modal dan sisa pada basis adhb menembus 125.
G8_Y_BREAKS  <- if (BASIS_ADHB) seq(95, 145, 5)  else seq(95, 125, 5)
G8_LAB_VJUST <- if (BASIS_ADHB) -0.45            else 0.5
# Kalimantan pada basis adhb menembus 250; breaks lama berhenti di 160 sehingga
# separuh atas panel kehilangan label sumbu.
G7_Y_BREAKS  <- if (BASIS_ADHB) seq(80, 300, 40) else seq(80, 160, 20)
stopifnot(abs(b1 - acuan$b1) < 1e-5, abs(b2 - acuan$b2) < 1e-5)

# 3) GAMBAR 1: Dekomposisi pertumbuhan nasional ----
dek <- read.xlsx(f_dek, sheet = "dekomposisi")

# F (tanpa CRS) adalah basis UTAMA dan ditaruh paling kiri; A-E pembanding.
#
# HANYA skenario F yang ditampilkan, atas keputusan Eqi: ambil yang paling
# valid saja. F adalah basis UTAMA - elastisitas two-way FE apa adanya, tanpa
# CRS dipaksakan. A sampai E berstatus pembanding diagnostik dan tetap hidup di
# sheet `dekomposisi` pada Dekomposisi Nasional.xlsx bagi yang mau memeriksanya.
urut_skenario <- "F. Tanpa CRS"

dek1 <- dek %>%
  filter(skenario %in% urut_skenario) %>%
  mutate(skenario = factor(skenario, levels = urut_skenario))

# --- uji klaim yang dipakai di teks gambar 1 --------------------------------
# (a) identitas dekomposisi tertutup;
# (b) tidak ada komponen negatif, sehingga tidak perlu menggambar turun;
# (c) angkanya cocok dengan log dekomposisi.
f_row <- dek1
stopifnot(
  nrow(dek1) == 1,
  max(abs(dek1$kontrib_K + dek1$kontrib_L + dek1$sisa - dek1$gY)) < 1e-10,
  all(dek1$kontrib_K > 0), all(dek1$kontrib_L > 0), all(dek1$sisa > 0),
  abs(f_row$gY        - acuan$gY)  < 0.005,
  abs(f_row$kontrib_K - acuan$kK)  < 0.005,
  abs(f_row$kontrib_L - acuan$kL)  < 0.005,
  abs(f_row$sisa      - acuan$tfp) < 0.005
)

gY_nas <- f_row$gY

g1_long <- dek1 %>%
  transmute(skenario,
            `Modal`        = kontrib_K,
            `Tenaga kerja` = kontrib_L,
            `TFP`          = sisa) %>%
  pivot_longer(-skenario, names_to = "komponen", values_to = "nilai") %>%
  mutate(komponen = factor(komponen, levels = names(mega_colors))) %>%
  tumpuk(skenario) %>%
  mutate(x = as.integer(skenario))

g1_tot <- dek1 %>%
  transmute(skenario, gY) %>%
  mutate(x = as.integer(skenario))

g1_lab <- g1_long %>%
  mutate(y_seg = (ymin + ymax) / 2) %>%
  group_by(skenario) %>%
  mutate(y_lab = sebar(y_seg, MIN_GAP)) %>%
  ungroup()

p1 <- ggplot() +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_rect(data = g1_long,
            aes(xmin = x - BAR_HALF, xmax = x + BAR_HALF,
                ymin = ymin, ymax = ymax, fill = komponen)) +
  geom_segment(data = g1_tot,
               aes(x = x - PENANDA, xend = x + PENANDA, y = gY, yend = gY),
               color = aksen, linewidth = 0.6) +
  geom_point(data = g1_tot, aes(x = x, y = gY),
             color = aksen, size = 1.7, shape = 18) +
  geom_segment(data = g1_lab,
               aes(x = x + LEADER_IN, xend = x + LEADER_OUT,
                   y = y_seg, yend = y_lab),
               color = warna_leader, linewidth = 0.3) +
  geom_text(data = g1_lab,
            aes(x = x + LAB_X, y = y_lab, label = fmt_id(nilai, 2)),
            hjust = 0, size = LAB_SIZE, color = netral_gelap) +
  scale_fill_manual(values = mega_colors,
                    labels = c("Modal", "Tenaga kerja", LBL_SISA)) +
  scale_x_continuous(breaks = 1, labels = "",
                     limits = c(0.30, 1.90), expand = c(0, 0)) +
  scale_y_continuous(labels = lab_id(1), breaks = G1_Y_BREAKS,
                     limits = G1_Y_LIM, expand = c(0, 0)) +
  labs(
    title    = sprintf("Sumber pertumbuhan PDRB %s nasional, 2018-2024", LBL_HARGA),
    subtitle = muat(sprintf("Elastisitas two-way FE apa adanya: b1 = %s; b2 = %s.",
                            fmt_id(f_row$b1, 3), fmt_id(f_row$b2, 3)),
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "Poin persen",
    caption  = muat(sprintf(paste0("Garis merah: pertumbuhan aktual %s%%. ",
                                   "%s menyerap %s poin.\n",
                                   "Residual produksi berbasis arus PMTB, bukan TFP Hicks-neutral. %s"),
                            fmt_id(gY_nas, 2), LBL_SISA, fmt_id(f_row$sisa, 2), sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

simpan(p1, file.path(dir_out, "Dekomposisi Pertumbuhan Nasional.png"),
       lebar = LEBAR, tinggi = 6.2)

# 4) GAMBAR 2: Indeks TFP nasional ----
# Sejak 20 Agustus 2026 estimasi memuat 2025, jadi sheet efek_tahun punya 9 baris.
# Gambar tetap berhenti di 2024. Tenaga kerja 2025 disalin dari 2024 secara LOCF,
# sehingga efek tahun 2025 menyerap pertumbuhan yang seharusnya jatuh ke tenaga
# kerja. Menggambarnya berarti menerbitkan artefak imputasi sebagai kemajuan TFP.
efek <- read.xlsx(f_tfp, sheet = "efek_tahun") %>%
  filter(Year <= 2024) %>%
  mutate(lo_idx = 100 * exp(lo),
         hi_idx = 100 * exp(hi))

idx_akhir <- efek$indeks_100[efek$Year == max(efek$Year)]
naik_pct  <- idx_akhir - 100

# Klaim caption: indeks berakhir di atas 100 dan kenaikannya sebesar naik_pct.
# Diuji, bukan diasumsikan — kalau serinya berubah arah, teksnya harus berubah.
stopifnot(
  nrow(efek) == 8,
  identical(as.integer(efek$Year), 2017:2024),
  abs(efek$indeks_100[efek$Year == 2017] - 100) < 1e-9,
  idx_akhir > 100,
  all(efek$lo_idx <= efek$indeks_100 + 1e-9),
  all(efek$hi_idx >= efek$indeks_100 - 1e-9)
)

p2 <- ggplot(efek, aes(x = Year, y = indeks_100)) +
  geom_hline(yintercept = 100, linetype = "dashed",
             color = netral_sedang, linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo_idx, ymax = hi_idx),
              fill = mega_colors[["TFP"]], alpha = 0.35) +
  geom_line(color = aksen, linewidth = 0.8) +
  geom_point(color = aksen, size = 1.8) +
  geom_text(aes(y = hi_idx, label = fmt_id(indeks_100, 1)), vjust = -0.7,
            size = LAB_SIZE, color = netral_gelap) +
  scale_x_continuous(breaks = 2017:2024, expand = expansion(mult = c(0.04, 0.05))) +
  scale_y_continuous(labels = lab_id(0), breaks = G2_Y_BREAKS) +
  coord_cartesian(ylim = G2_Y_LIM) +
  labs(
    title    = sprintf("Indeks %s nasional, 2017 = 100", LBL_SISA),
    subtitle = "Efek tahun model two-way FE; pita = selang kepercayaan 95 persen.",
    x        = NULL,
    y        = "Indeks (2017 = 100)",
    caption  = muat(sprintf(paste0("Indeks 2024 mencapai %s, yaitu %s persen di atas 2017.\n",
                                   "%s: residual produksi berbasis PMTB. %s"),
                            fmt_id(idx_akhir, 1), fmt_id(naik_pct, 1), LBL_SISA, sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah

simpan(p2, file.path(dir_out, "Indeks TFP Nasional.png"),
       lebar = LEBAR, tinggi = 5.4)

# 5) GAMBAR 3: Peringkat TFP provinsi ----
prov_ekstraktif <- c("Kalimantan Timur", "Riau", "Papua Barat", "Kalimantan Utara",
                     "Kep.Riau", "Jambi", "Papua", "Kep.Bangka Belitung",
                     "Kalimantan Selatan", "Sumatera Selatan")

prov <- read.xlsx(f_tfp, sheet = "tfp_provinsi") %>%
  mutate(kelompok = case_when(
           Pre_Prov == "DKI Jakarta"     ~ "DKI Jakarta (artefak pencatatan)",
           Pre_Prov %in% prov_ekstraktif ~ "Ekstraktif / enklave sumber daya",
           TRUE                          ~ "Provinsi lain"),
         kelompok = factor(kelompok, levels = names(PAL_KELOMPOK)),
         Pre_Prov = ifelse(Pre_Prov == "DI yogyakarta", "DI Yogyakarta", Pre_Prov),
         Pre_Prov = gsub("^Kep\\.", "Kep. ", Pre_Prov)) %>%
  arrange(dev_nasional) %>%
  mutate(Pre_Prov = factor(Pre_Prov, levels = Pre_Prov))

# Rentang level log TFP dirakit dari data. Versi lama menulis "berkisar 13,5 di
# semua provinsi"; pada basis riil levelnya 22,5-24,7, jadi angka itu keliru.
lv_lo <- min(prov$logtfp_rata)
lv_hi <- max(prov$logtfp_rata)

# Klaim caption: provinsi ekstraktif cenderung berada di atas rata-rata.
# "Cenderung" diuji sebagai rata-rata kelompok, bukan sebagai klaim setiap unit.
rata_ekstraktif <- mean(prov$dev_nasional[prov$kelompok == "Ekstraktif / enklave sumber daya"])
rata_lain       <- mean(prov$dev_nasional[prov$kelompok == "Provinsi lain"])
stopifnot(
  nrow(prov) == 34,
  abs(mean(prov$dev_nasional)) < 1e-9,     # deviasi terhadap rata-rata, jumlahnya nol
  rata_ekstraktif > rata_lain,
  lv_hi - lv_lo > 0
)

# Batas sumbu dirakit dari data + ruang untuk label di ujung, bukan diketik.
pad_x <- 0.32
lim_x <- c(min(prov$dev_nasional) - pad_x, max(prov$dev_nasional) + pad_x)

p3 <- ggplot(prov, aes(x = dev_nasional, y = Pre_Prov)) +
  geom_vline(xintercept = 0, color = netral_sedang, linewidth = 0.45) +
  geom_segment(aes(x = 0, xend = dev_nasional, yend = Pre_Prov),
               color = "grey85", linewidth = 0.35) +
  geom_point(aes(color = kelompok), size = 2.6) +
  geom_text(aes(label = fmt_id(dev_nasional, 2),
                hjust = ifelse(dev_nasional >= 0, -0.28, 1.28)),
            size = LAB_SIZE, color = "grey45") +
  scale_color_manual(values = PAL_KELOMPOK, drop = FALSE) +
  scale_x_continuous(labels = lab_id(1), breaks = seq(-1, 1.2, 0.2),
                     limits = lim_x, expand = c(0, 0)) +
  labs(
    title    = sprintf("Peringkat %s antarprovinsi (level), rata-rata 2017-2024",
                       LBL_SISA),
    subtitle = muat(sprintf("Deviasi log residual terhadap rata-rata 34 provinsi; levelnya sendiri berdesak di %s-%s.",
                            fmt_id(lv_lo, 1), fmt_id(lv_hi, 1)),
                    MAKS_SUBTITLE),
    x        = sprintf("Deviasi log %s dari rata-rata nasional", LBL_SISA),
    y        = NULL,
    caption  = muat(paste0("Peringkat level, bukan produktivitas: memuat skala, endowmen, dan komposisi sektor.\n",
                           "Pembanding produktivitas: tren CRS dalam-provinsi. PDRB DKI menurut lokasi kerja. ",
                           sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
        axis.line.y        = element_blank(),
        axis.ticks.y       = element_blank())

simpan(p3, file.path(dir_out, "Peringkat TFP Provinsi.png"),
       lebar = LEBAR, tinggi = 10.5)

# 6) GAMBAR 4: Tangga atenuasi elastisitas ----
tangga <- read.xlsx(f_tfp, sheet = "tangga_atenuasi")

# --- klaim yang HARUS ditulis ulang untuk basis riil ------------------------
# Versi lama berjudul "skala hasil menurun seiring makin banyak variasi
# dibuang" dan captionnya menyebut "penurunan berurutan dari 1,011 ke 0,591".
# Pada modal riil tangganya TIDAK monoton:
#   Pooled 1,011 -> Random 1,075 -> Fixed 1,189 -> Two-way 0,549.
# Ia justru NAIK di dua langkah pertama, lalu jatuh sekali di langkah terakhir.
# Assertion di bawah mengunci pembacaan itu: kalau suatu saat tangganya benar-
# benar monoton, skrip berhenti dan judulnya memang harus ditulis ulang lagi.
# Pada basis adhb polanya lebih ekstrem dan tidak lagi "di sekitar 1":
#   Pooled 1,008 -> Random 1,080 -> Fixed 1,477 -> Two-way 0,474.
# Ia naik monoton di tiga langkah pertama - fixed effects justru menembus 1,4 -
# lalu jatuh sekali. Assertion-nya karena itu berbeda, bukan dilonggarkan.
#
# Vintage B (272 obs, folder ini): 1,011 -> 1,075 -> 1,189 -> 0,549.
# Run 20 Agustus (N=306, tidak di folder ini): 1,010 -> 1,103 -> 1,259 -> 0,611.
# Assertion mengunci bentuk: naik di tiga langkah pertama, lalu two-way jatuh.
rts <- tangga$rts
naik_monoton <- all(diff(rts[1:3]) > 0)
stopifnot(
  nrow(tangga) == 4,
  any(diff(rts) > 0),                       # ADA langkah yang naik -> tidak monoton turun
  rts[4] < 0.65,                            # two-way FE jatuh jauh di bawah 1
  which.min(rts) == 4,                      # dan ia yang terendah
  abs(rts[4] - (b1 + b2)) < 1e-6            # baris terakhir = elastisitas UTAMA
)
if (naik_monoton) {
  stopifnot(rts[3] > 1.15)                  # fixed effects di atas CRS (vintage B: 1,19)
} else {
  stopifnot(all(abs(rts[1:3] - 1) < 0.20))  # tiga spesifikasi pertama di sekitar 1
}

# Label sumbu dipendekkan: "variasi dibuang" versi lama butuh 3-4 baris per
# kategori, dan pada huruf 11,5 pt itu tidak muat. Informasinya pindah ke
# subtitle, yang memang tempatnya.
lab_spek <- c("Pooled OLS", "Random\neffects", "Fixed effects\n(provinsi)",
              "Two-way FE\n(provinsi + tahun)")
stopifnot(length(lab_spek) == nrow(tangga))

tangga <- tangga %>%
  mutate(spesifikasi = factor(spesifikasi, levels = tangga$spesifikasi),
         x = as.integer(spesifikasi))

tangga_long <- tangga %>%
  transmute(spesifikasi, x, `Modal` = b1, `Tenaga kerja` = b2) %>%
  pivot_longer(c(`Modal`, `Tenaga kerja`), names_to = "komponen", values_to = "nilai") %>%
  mutate(komponen = factor(komponen, levels = c("Modal", "Tenaga kerja")))

p4 <- ggplot() +
  geom_col(data = tangga_long,
           aes(x = x, y = nilai, fill = komponen),
           width = 0.55, position = position_stack(reverse = TRUE)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = aksen, linewidth = 0.5) +
  annotate("text", x = 4.42, y = 1.05, label = "CRS = 1,0",
           color = aksen, size = LAB_KECIL, hjust = 1, fontface = "bold") +
  geom_line(data = tangga, aes(x = x, y = rts), color = aksen, linewidth = 0.7) +
  geom_point(data = tangga, aes(x = x, y = rts), color = aksen, size = 2.4) +
  geom_label(data = tangga, aes(x = x, y = rts, label = fmt_id(rts, 3)),
             vjust = -0.55, size = LAB_SIZE, color = aksen, linewidth = 0,
             fill = "white", label.padding = unit(0.10, "lines")) +
  scale_fill_manual(values = mega_colors[c("Modal", "Tenaga kerja")],
                    labels = c("Modal (b1)", "Tenaga kerja (b2)")) +
  scale_x_continuous(breaks = 1:4, labels = lab_spek,
                     limits = c(0.5, 4.5), expand = c(0, 0)) +
  scale_y_continuous(labels = lab_id(1), breaks = G4_Y_BREAKS,
                     limits = G4_Y_LIM, expand = c(0, 0)) +
  labs(
    title    = "Jumlah elastisitas b1 + b2 di empat spesifikasi panel",
    subtitle = muat(paste0("Makin ke kanan makin banyak variasi dibuang, dari tanpa efek tetap ",
                           "sampai provinsi + tahun."),
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "b1 + b2",
    caption  = muat(if (naik_monoton) {
      sprintf(paste0("Jumlahnya justru naik sampai %s pada fixed effects, ",
                     "lalu jatuh ke %s setelah efek tahun masuk.\n",
                     "Penurunan satu langkah itu ciri atenuasi galat ukur, bukan bukti skala hasil menurun. %s"),
              fmt_id(rts[3], 3), fmt_id(rts[4], 3), sumber_txt)
    } else {
      sprintf(paste0("Jumlahnya bertahan di sekitar 1 pada tiga spesifikasi pertama, ",
                     "lalu jatuh ke %s hanya setelah efek tahun masuk.\n",
                     "Penurunan satu langkah itu ciri atenuasi galat ukur, bukan bukti skala hasil menurun. %s"),
              fmt_id(rts[4], 3), sumber_txt)
    }, MAKS_CAPTION)
  ) +
  tema_rumah +
  theme(axis.text.x = element_text(size = 11, lineheight = 1.05))

simpan(p4, file.path(dir_out, "Tangga Atenuasi Elastisitas.png"),
       lebar = LEBAR, tinggi = 6.0)

# 7) GAMBAR 5: Amplop sisa vs elastisitas modal ----
# Di bawah CRS (b2 = 1 - b1) dekomposisi kolaps jadi fungsi linear satu
# parameter:  sisa(b1) = gY - gL - b1*(gK - gL).
# Koefisiennya DIHITUNG dari seri, tidak diketik: pada modal nominal gK jauh
# lebih tinggi sehingga kemiringannya -4,05; pada modal riil -1,18, dan itulah
# yang membalik cerita gambar ini.
gK_nas <- dek %>% filter(skenario == "F. Tanpa CRS") %>% pull(gK)
gL_nas <- dek %>% filter(skenario == "F. Tanpa CRS") %>% pull(gL)

intersep  <- gY_nas - gL_nas
kemiringan <- -(gK_nas - gL_nas)
amplop <- function(x) intersep + kemiringan * x

b1_impas <- intersep / (-kemiringan)          # sisa = 0
amb      <- 0.25 * gY_nas                     # ambang 25 persen dari gY
b1_amb   <- (intersep - amb) / (-kemiringan)  # sisa = ambang

garis5 <- data.frame(b1 = seq(0, 1, by = 0.005)) %>% mutate(sisa = amplop(b1))

# Titik = nilai b1 tiap skenario, diambil dari sheet skenario (bukan diketik).
# E dikeluarkan: b1-nya sama dengan A tetapi gK-nya stok PIM, jadi ia tidak
# duduk di amplop yang digambar dari gK arus PMTB.
sken <- read.xlsx(f_dek, sheet = "skenario") %>%
  filter(skenario != "E. PIM (CRS)") %>%
  mutate(kode  = substr(skenario, 1, 1),
         label = sub("^[A-F]\\. ", "", skenario),
         sisa  = amplop(b1)) %>%
  arrange(b1)

# --- uji klaim gambar 5 -----------------------------------------------------
# (a) amplop yang dirakit cocok dengan sisa yang dihitung skrip 02 untuk
#     skenario CRS (A, B, C, D) — F non-CRS sengaja tidak diuji ke situ;
# (b) sisa TIDAK PERNAH nol di dalam rentang gambar; titik impas di luar [0,1];
# (c) berapa skenario yang berada di atas ambang 25 persen.
cek_crs <- dek %>%
  filter(skenario %in% c("A. Level (CRS)", "B. Growth (CRS)",
                         "C. Pangsa terukur", "D. Alfa baku 1/3"))
n_atas <- sum(sken$sisa > amb)
n_bawah <- sum(sken$sisa <= amb)
stopifnot(
  max(abs(amplop(cek_crs$b1) - cek_crs$sisa)) < 1e-9,
  b1_impas > 1,                       # sisa = 0 di luar jangkauan gambar
  all(garis5$sisa > 0),               # sisa selalu positif sepanjang b1 = 0..1
  n_atas == 4, n_bawah == 1,          # hanya C yang di bawah ambang
  sken$kode[which.min(sken$sisa)] == "C"
)

ket5 <- paste0(
  paste0(sken$kode, "  ", sken$label, ": b1 = ", fmt_id(sken$b1, 3),
         "; sisa = ", fmt_id(sken$sisa, 2)),
  collapse = "\n")

p5 <- ggplot() +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_hline(yintercept = amb, linetype = "dashed",
             color = aksen, linewidth = 0.45) +
  geom_line(data = garis5, aes(x = b1, y = sisa),
            color = netral_gelap, linewidth = 0.8) +
  geom_point(data = sken, aes(x = b1, y = sisa), color = aksen, size = 2.6) +
  geom_text(data = sken, aes(x = b1 + 0.018, y = sisa + 0.075, label = kode),
            hjust = 0, size = LAB_SIZE, fontface = "bold", color = aksen) +
  annotate("text", x = 0.985, y = amb + 0.08,
           label = sprintf("ambang 25 persen dari gY (sisa = %s)", fmt_id(amb, 2)),
           hjust = 1, vjust = 0, size = LAB_KECIL, color = aksen) +
  # Blok keterangan duduk di pita kosong di bawah garis. Karena amplop tidak
  # pernah turun di bawah 0,57 pada b1 <= 1, seluruh wilayah y < 0,55 kosong —
  # dan di eyetest putaran 1 blok ini masih ditaruh di y = 0,86, menempel pada
  # garisnya sambil menyisakan sepertiga panel kosong di bawahnya.
  # Pada basis adhb amplopnya jauh lebih curam (turun 4,66 ke 0,55), jadi pita
  # kosongnya pindah: blok keterangan naik ke y = 2,0 supaya tidak menabrak garis.
  annotate("text", x = 0.03, y = G5_KET_Y, label = ket5,
           hjust = 0, vjust = 1, size = LAB_KECIL, color = netral_gelap,
           lineheight = 1.25) +
  scale_x_continuous(labels = lab_id(1), breaks = seq(0, 1, 0.1),
                     limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(labels = lab_id(1), breaks = G5_Y_BREAKS,
                     limits = G5_Y_LIM, expand = c(0, 0)) +
  labs(
    title    = "Di bawah CRS, sisa tetap positif berapa pun elastisitas modalnya",
    subtitle = muat(sprintf("Kolaps jadi satu parameter: sisa = %s - %s x b1 (gY %s; gK %s; gL %s).",
                            fmt_id(intersep, 2), fmt_id(-kemiringan, 2),
                            fmt_id(gY_nas, 2), fmt_id(gK_nas, 2), fmt_id(gL_nas, 2)),
                    MAKS_SUBTITLE),
    x        = "Elastisitas modal b1",
    y        = "Sisa (poin persen)",
    caption  = muat(sprintf(paste0("Sisa baru nol pada b1 = %s, jauh di luar rentang masuk akal; ",
                                   "empat dari lima skenario di atas ambang.\n",
                                   "F diestimasi tanpa CRS, jadi posisinya di sini padanan CRS dari b1 yang sama. %s"),
                            fmt_id(b1_impas, 2), sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah

# Tinggi 6,0 -> 5,6: pada 6,0 pita kosong di bawah garis jadi terlalu lebar
# walau blok keterangan sudah dipindah ke sana.
simpan(p5, file.path(dir_out, "Amplop Sisa vs Elastisitas Modal.png"),
       lebar = LEBAR, tinggi = 5.6)

# 8) GAMBAR 6: Dekomposisi per pulau ----
dek_p <- read.xlsx(f_dek, sheet = "dekomposisi_pulau") %>%
  filter(skenario == "F. Tanpa CRS")

urut_pulau6 <- dek_p %>% arrange(desc(sisa)) %>% pull(Pulau)

# Klaim: identitas berlaku per pulau, dan pada basis riil TIDAK ADA pulau
# dengan TFP negatif (pada versi nominal Maluku-Papua negatif di skenario A).
stopifnot(
  nrow(dek_p) == 6,
  max(abs(dek_p$kontrib_K + dek_p$kontrib_L + dek_p$sisa - dek_p$gY)) < 1e-10,
  all(dek_p$sisa > 0),
  all(abs(dek_p$b1 - b1) < 1e-6), all(abs(dek_p$b2 - b2) < 1e-6)
)

g6_long <- dek_p %>%
  transmute(Pulau,
            `Modal`        = kontrib_K,
            `Tenaga kerja` = kontrib_L,
            `TFP`          = sisa) %>%
  pivot_longer(-Pulau, names_to = "komponen", values_to = "nilai") %>%
  mutate(Pulau    = factor(Pulau, levels = urut_pulau6),
         komponen = factor(komponen, levels = names(mega_colors))) %>%
  tumpuk(Pulau) %>%
  mutate(x = as.integer(Pulau))

g6_tot <- dek_p %>%
  transmute(Pulau, gY) %>%
  mutate(Pulau = factor(Pulau, levels = urut_pulau6),
         x     = as.integer(Pulau))

g6_lab <- g6_long %>%
  mutate(y_seg = (ymin + ymax) / 2) %>%
  group_by(Pulau) %>%
  mutate(y_lab = sebar(y_seg, MIN_GAP)) %>%
  ungroup()

p6 <- ggplot() +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_rect(data = g6_long,
            aes(xmin = x - BAR_HALF, xmax = x + BAR_HALF,
                ymin = ymin, ymax = ymax, fill = komponen)) +
  geom_segment(data = g6_tot,
               aes(x = x - PENANDA, xend = x + PENANDA, y = gY, yend = gY),
               color = aksen, linewidth = 0.6) +
  geom_point(data = g6_tot, aes(x = x, y = gY),
             color = aksen, size = 1.7, shape = 18) +
  geom_segment(data = g6_lab,
               aes(x = x + LEADER_IN, xend = x + LEADER_OUT,
                   y = y_seg, yend = y_lab),
               color = warna_leader, linewidth = 0.3) +
  geom_text(data = g6_lab,
            aes(x = x + LAB_X, y = y_lab, label = fmt_id(nilai, 2)),
            hjust = 0, size = LAB_SIZE, color = netral_gelap) +
  scale_fill_manual(values = mega_colors,
                    labels = c("Modal", "Tenaga kerja", LBL_SISA)) +
  scale_x_continuous(breaks = 1:6, labels = urut_pulau6,
                     limits = c(0.50, 6.68), expand = c(0, 0)) +
  scale_y_continuous(labels = lab_id(1), breaks = G6_Y_BREAKS,
                     limits = G6_Y_LIM, expand = c(0, 0)) +
  labs(
    title    = sprintf("Sumber pertumbuhan PDRB %s per pulau, 2018-2024", LBL_HARGA),
    subtitle = muat(sprintf("Elastisitas nasional skenario F (b1 = %s; b2 = %s). Garis merah: pertumbuhan aktual.",
                            fmt_id(b1, 3), fmt_id(b2, 3)),
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "Poin persen",
    caption  = muat(paste0("Pulau diurutkan menurut besar residual. Elastisitasnya nasional, jadi beda ",
                           "antarpulau datang dari laju inputnya.\n",
                           LBL_SISA, " di sini residual produksi berbasis PMTB. ", sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah +
  theme(axis.text.x = element_text(size = 11))

simpan(p6, file.path(dir_out, "Dekomposisi per Pulau.png"),
       lebar = LEBAR, tinggi = 6.0)

# 9) GAMBAR 7: Indeks TFP per pulau (small multiples) ----
# Dibatasi 2024 dengan alasan yang sama seperti gambar 2: efek tahun 2025 memuat
# pertumbuhan yang seharusnya jatuh ke tenaga kerja, sebab angkanya salinan 2024.
efek_p <- read.xlsx(f_tfp, sheet = "efek_tahun_pulau") %>%
  filter(Year <= 2024) %>%
  mutate(lo_idx = 100 * exp(lo),
         hi_idx = 100 * exp(hi))

urut_pulau7 <- names(pulau_colors)
lab_pulau7  <- efek_p %>%
  distinct(Pulau, n_prov) %>%
  mutate(lab = paste0(Pulau, " (", n_prov, " provinsi)"))

efek_p <- efek_p %>%
  left_join(lab_pulau7, by = c("Pulau", "n_prov")) %>%
  mutate(Pulau = factor(Pulau, levels = urut_pulau7),
         lab   = factor(lab, levels = lab_pulau7$lab[match(urut_pulau7, lab_pulau7$Pulau)]))

# Berapa pulau yang indeks 2024-nya di atas 100 — dipakai di caption, jadi diuji.
akhir7 <- efek_p %>% filter(Year == max(Year))
n_naik <- sum(akhir7$indeks_100 > 100)
stopifnot(
  nrow(efek_p) == 48,
  setequal(levels(efek_p$Pulau), unique(as.character(efek_p$Pulau))),
  sum(efek_p$n_prov[efek_p$Year == 2017]) == 34,
  n_naik == 6
)

lim7 <- c(min(efek_p$lo_idx) - 2, max(efek_p$hi_idx) + 2)

p7 <- ggplot(efek_p, aes(x = Year, y = indeks_100)) +
  geom_hline(yintercept = 100, linetype = "dashed",
             color = netral_sedang, linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo_idx, ymax = hi_idx, fill = Pulau), alpha = 0.28) +
  geom_line(aes(color = Pulau), linewidth = 0.8) +
  geom_point(aes(color = Pulau), size = 1.4) +
  facet_wrap(~ lab, nrow = 2) +
  scale_color_manual(values = pulau_lines, guide = "none") +
  scale_fill_manual(values = pulau_colors, guide = "none") +
  scale_x_continuous(breaks = seq(2017, 2024, 2),
                     expand = expansion(mult = c(0.06, 0.06))) +
  scale_y_continuous(labels = lab_id(0), breaks = G7_Y_BREAKS) +
  coord_cartesian(ylim = lim7) +
  labs(
    title    = sprintf("Indeks %s per pulau, 2017 = 100", LBL_SISA),
    subtitle = muat("Model two-way FE diestimasi terpisah per pulau; pita = selang kepercayaan 95 persen.",
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "Indeks (2017 = 100)",
    caption  = muat(paste0("Keenam pulau berakhir di atas 100 pada 2024. Pita melebar di pulau ",
                           "berprovinsi sedikit.\n", LBL_SISA, " di sini residual produksi berbasis PMTB. ",
                           sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah +
  theme(panel.spacing = unit(0.9, "lines"))

# Tinggi 6,6 -> 7,0: pada 6,6 baris pertama caption hampir menyentuh label
# sumbu-x baris facet bawah. Gambar ini satu-satunya yang berfacet, jadi ia
# butuh ruang vertikal lebih daripada tujuh gambar lain di skrip ini.
simpan(p7, file.path(dir_out, "Indeks TFP per Pulau.png"),
       lebar = LEBAR, tinggi = 7.0)

# 10) GAMBAR 8: Kontribusi kumulatif per faktor over time ----
# Tiga INDEKS yang sebanding (2017 = 100), BUKAN dekomposisi bertumpuk:
#   - Modal & tenaga kerja: kontribusi kumulatif input berbobot elastisitas
#     non-CRS, dari agregat nasional (berbobot output) -> 100*exp(cumsum(b*g)).
#   - TFP: indeks efek tahun (panel, tiap provinsi berbobot sama), objek yang
#     sah untuk dimensi waktu, BUKAN residual identitas per tahun. Memakai efek
#     tahun inilah yang membuat grafik ini lolos aturan "jangan dekomposisi
#     tahunan" (Batasan E6): tidak ada sisa tahunan yang dihitung.
# Basis pembobotan modal/TK berbeda dari basis TFP; ketiga garis TIDAK menjumlah
# ke output, dan garis output sengaja TIDAK ditampilkan supaya pembaca tidak
# tergoda mengurangkan output - modal - TK (dekomposisi terlarang).
# Dipotong 2024 supaya sejajar dengan `efek`, yang juga berhenti di situ. Tanpa
# potongan ini garis modal dan tenaga kerja berjalan satu tahun lebih panjang
# daripada garis sisa, dan ketiganya tidak lagi bisa dibaca berdampingan.
seri <- read.xlsx(f_dek, sheet = "seri_nasional") %>%
  filter(Year <= 2024) %>%
  arrange(Year) %>%
  mutate(g_K0  = ifelse(is.na(g_K), 0, g_K),   # 2017 tahun basis, pertumbuhan NA -> 0
         g_L0  = ifelse(is.na(g_L), 0, g_L),
         idx_K = 100 * exp(cumsum(b1 * g_K0 / 100)),
         idx_L = 100 * exp(cumsum(b2 * g_L0 / 100)))

LBL_KUM_SISA <- paste0(LBL_SISA, " (efek tahun)")
kum_col <- c(unname(mega_colors[["Modal"]]),
             unname(mega_colors[["Tenaga kerja"]]),
             unname(mega_colors[["TFP"]]))
names(kum_col) <- c("Modal", "Tenaga kerja", LBL_KUM_SISA)

kum_garis <- bind_rows(
  seri %>% transmute(Year, komponen = "Modal",        idx = idx_K),
  seri %>% transmute(Year, komponen = "Tenaga kerja", idx = idx_L),
  efek %>% transmute(Year, komponen = LBL_KUM_SISA,   idx = indeks_100)
) %>% mutate(komponen = factor(komponen, levels = names(kum_col)))

kum_lab <- kum_garis %>% filter(Year == max(Year))

# Klaim caption: pada 2024 garis TFP berakhir paling tinggi di antara ketiganya.
# Pada basis nominal urutannya terbalik (modal di atas), jadi ini WAJIB diuji.
akhir_tfp <- kum_lab$idx[kum_lab$komponen == LBL_KUM_SISA]
stopifnot(
  nrow(kum_garis) == 24,
  abs(seri$idx_K[seri$Year == 2017] - 100) < 1e-9,
  abs(seri$idx_L[seri$Year == 2017] - 100) < 1e-9,
  akhir_tfp == max(kum_lab$idx),
  all(kum_lab$idx > 100)
)

lim8 <- c(min(c(kum_garis$idx, efek$lo_idx)) - 2,
          max(c(kum_garis$idx, efek$hi_idx)) + 2)

p8 <- ggplot() +
  geom_hline(yintercept = 100, linetype = "dashed",
             color = netral_sedang, linewidth = 0.4) +
  geom_ribbon(data = efek, aes(x = Year, ymin = lo_idx, ymax = hi_idx),
              fill = mega_colors[["TFP"]], alpha = 0.20) +
  geom_line(data = kum_garis, aes(x = Year, y = idx, color = komponen),
            linewidth = 0.8) +
  geom_point(data = kum_garis, aes(x = Year, y = idx, color = komponen),
             size = 1.5) +
  # Pada basis adhb b2 = 0,015 membuat garis tenaga kerja berhenti di 100,2,
  # dan label yang duduk di tengah titik tercoret garis putus-putus y = 100.
  # Ketiga label karena itu naik sedikit di basis itu saja.
  geom_text(data = kum_lab,
            aes(x = Year, y = idx, color = komponen, label = fmt_id(idx, 1)),
            hjust = -0.22, vjust = G8_LAB_VJUST, size = LAB_SIZE, show.legend = FALSE) +
  scale_color_manual(values = kum_col) +
  scale_x_continuous(breaks = 2017:2024,
                     expand = expansion(mult = c(0.03, 0.12))) +
  scale_y_continuous(labels = lab_id(0), breaks = G8_Y_BREAKS) +
  coord_cartesian(ylim = lim8) +
  labs(
    title    = sprintf("Kontribusi kumulatif modal, tenaga kerja, dan %s, 2017 = 100",
                       LBL_SISA),
    subtitle = muat(sprintf(paste0("Modal dan tenaga kerja: input kumulatif berbobot elastisitas ",
                                   "non-CRS (b1 = %s; b2 = %s)."),
                            fmt_id(b1, 3), fmt_id(b2, 3)),
                    MAKS_SUBTITLE),
    x        = NULL,
    y        = "Indeks (2017 = 100)",
    caption  = muat(paste0("Garis ", LBL_SISA,
                           ": efek tahun. Ketiganya sebanding, bukan dekomposisi bertumpuk.\n",
                           "Basis pembobotan berbeda. Pita 95 persen untuk ", LBL_SISA, ". ",
                           sumber_txt),
                    MAKS_CAPTION)
  ) +
  tema_rumah

simpan(p8, file.path(dir_out, "Kontribusi Kumulatif Faktor.png"),
       lebar = LEBAR, tinggi = 5.8)

cat("Selesai: 8 PNG tersimpan di", dir_out, "\n")
