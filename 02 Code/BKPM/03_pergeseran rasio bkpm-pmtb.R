# 03_pergeseran rasio bkpm-pmtb.R
#
# Subbab 6.3 poin 2 — SATU gambar: pergeseran rasio (PMA+PMDN)/PMTB dari 2017
# ke 2025 per wilayah (nasional + 6 pulau).
#
# Sumber angka: `01 Data/BKPM/output/Subbab 6.3 - Korelasi PMTB-PMA-PMDN/
# Rasio BKPM terhadap PMTB.csv`, keluaran `02_analisis korelasi pmtb pma-pmdn.R`.
# Skrip ini TIDAK menghitung ulang apa pun dan tidak menyentuh skrip 01/02.
#
# KEPUTUSAN DESAIN
#
# 1. Bentuknya batang horizontal terurut, bukan garis. Gambar garis untuk seri
#    ini sudah ada (`Rasio BKPM terhadap PMTB.png`). Yang ditanya di sini
#    besaran pergeserannya, dan besaran dibaca paling akurat sebagai panjang
#    dari baseline nol — bukan sebagai jarak vertikal antara dua ujung garis
#    yang titik awalnya berbeda-beda.
#
# 2. Tanpa errorbar, walau resep `bar-errorbar` memuatnya. Rasio ini agregat
#    akuntansi (jumlah realisasi / jumlah PMTB), bukan estimasi dari sampel;
#    tidak ada sebaran penarikan sampel yang bisa jadi selang kepercayaan.
#    Menggambar errorbar di sini berarti mengarang ketidakpastian.
#
# 3. Warna TIDAK memetakan identitas pulau. Nama pulaunya sudah tertulis di
#    sumbu, jadi warna per pulau cuma pengulangan. Yang dipetakan warna justru
#    hal yang tidak ada di sumbu: mana baris agregat (nasional, merah) dan mana
#    baris pulau (navy). Ini juga menghindari bentrok dengan gambar tetangga di
#    folder yang sama, yang masih memakai palet Flat-UI — lihat catatan "Dua
#    palet pulau" di `palet-bkpm.R`.
#
# 4. Level 2017 dan 2025 di dalam kurung dibulatkan ke BILANGAN BULAT, bukan
#    satu desimal. Alasannya spesifik: CSV menyimpan rasio yang sudah
#    dibulatkan 2 desimal, dan nasional 2025 tersimpan 26,85. Dibulatkan lagi
#    ke 1 desimal ia jadi "26,9", padahal gambar garis di folder yang sama dan
#    narasi .docx menulis "26,8%" — angka itu dihitung dari nilai yang belum
#    dibulatkan (~26,845). Membulatkan dua kali menggeser digit terakhir.
#    Selisihnya sendiri kebal terhadap ini (11,09 maupun 11,085 sama-sama
#    "+11,1"), jadi angka utama gambar ini aman; yang dijaga hanya angka
#    konteks di dalam kurung.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

# Path relatif dari root project (.Rproj), mengikuti konvensi CLAUDE.md dan
# skrip 01/02. Ditulis sebagai string apa adanya, bukan dirakit lewat
# file.path(): path yang dihitung tidak bisa diikuti pembaca yang memindai
# "palet mana yang dipakai skrip ini", dan tidak bisa diikuti periksa-viz.py.
source("02 Code/BKPM/palet-bkpm.R")

out_dir <- "01 Data/BKPM/output/Subbab 6.3 - Korelasi PMTB-PMA-PMDN"


# 1) Data ----------------------------------------------------------------------

rasio <- read.csv(file.path(out_dir, "Rasio BKPM terhadap PMTB.csv"),
                  check.names = FALSE, stringsAsFactors = FALSE)

# Uji berkas data terhadap angka yang log analisis 02 sendiri nyatakan
# (CLAUDE.md: "Rasio naik 15,8%->26,8%"; subtitle gambar garis: 15,8% -> 26,8%).
# Kalau CSV-nya dirender ulang dengan angka lain, skrip ini berhenti di sini,
# bukan menghasilkan gambar yang salah dengan caption yang meyakinkan.
stopifnot(
  nrow(rasio) == 7,
  all(c("Wilayah", "2017", "2025") %in% names(rasio)),
  setequal(rasio$Wilayah, c("Nasional", "Sumatera", "Jawa", "Bali-Nusra",
                            "Kalimantan", "Sulawesi", "Maluku-Papua")),
  abs(rasio$`2017`[rasio$Wilayah == "Nasional"] - 15.76) < 0.005,
  abs(rasio$`2025`[rasio$Wilayah == "Nasional"] - 26.85) < 0.005
)

geser <- rasio %>%
  transmute(Wilayah,
            awal  = `2017`,
            akhir = `2025`,
            delta = akhir - awal,
            agregat = ifelse(Wilayah == "Nasional", "Nasional", "Pulau"))

delta_nasional <- geser$delta[geser$Wilayah == "Nasional"]

# urutan baris eksplisit: pergeseran terbesar di atas. factor(levels = ) ditulis
# eksplisit, bukan reorder(), supaya urutannya terbaca dari kode.
urutan <- geser %>% arrange(delta) %>% pull(Wilayah)
geser <- geser %>%
  mutate(Wilayah = factor(Wilayah, levels = urutan),
         agregat = factor(agregat, levels = c("Nasional", "Pulau")),
         label = paste0("+", fmt_id(delta, 1), "   (",
                        fmt_id(awal, 0), " → ", fmt_id(akhir, 0), ")"))


# 2) Uji klaim judul, subtitle, dan caption ------------------------------------
#
# Ditulis SEBELUM render. Menghitung selisihnya dengan benar tidak menjamin
# kalimat tentang selisih itu benar.

teratas  <- geser %>% slice_max(delta, n = 1)
terbawah <- geser %>% slice_min(delta, n = 1)
n_di_atas_nasional <- sum(geser$delta > delta_nasional)
n_di_bawah_nasional <- sum(geser$delta < delta_nasional)

stopifnot(
  # "Seluruh wilayah naik"
  all(geser$delta > 0),
  # "dari +8,0 (Jawa) sampai +40,1 poin persentase (Maluku-Papua)"
  as.character(teratas$Wilayah) == "Maluku-Papua",
  fmt_id(teratas$delta, 1) == "40,1",
  as.character(terbawah$Wilayah) == "Jawa",
  fmt_id(terbawah$delta, 1) == "8,0",
  # "Batang merah = nasional (+11,1)"
  fmt_id(delta_nasional, 1) == "11,1",
  sum(geser$agregat == "Nasional") == 1,
  # "Empat pulau bergerak lebih jauh dari nasional, dua lebih pendek."
  n_di_atas_nasional == 4,
  n_di_bawah_nasional == 2,
  # tepat 6 pulau + 1 baris agregat, jadi "empat" dan "dua" habis membagi pulau
  n_di_atas_nasional + n_di_bawah_nasional == 6,
  sum(geser$agregat == "Pulau") == 6,
  # angka dalam kurung untuk baris ekstrem, seperti tercetak di gambar
  fmt_id(teratas$awal, 0) == "38", fmt_id(teratas$akhir, 0) == "78"
)

cat("klaim caption lolos. urutan (kecil->besar):", paste(urutan, collapse = " < "), "\n")
cat(sprintf("  nasional %+.2f pp; di atas nasional %d pulau, di bawah %d\n",
            delta_nasional, n_di_atas_nasional, n_di_bawah_nasional))


# 3) Gambar --------------------------------------------------------------------

warna_baris <- c(Nasional = PAL$merah, Pulau = PAL$navy_3)

# Tanpa garis acuan vertikal di nilai nasional. Putaran render pertama memakainya
# (`geom_vline(xintercept = delta_nasional, linetype = "22")`) dan garis itu
# memotong tepat di tengah label dua baris terpendek — "+8,0 | (16 → 24)" di Jawa
# dan "(12 → 21)" di Sumatera — karena batang keduanya berakhir sebelum 11,09
# sementara labelnya melewatinya. Menggesernya tidak menolong: label baris pendek
# selalu menyeberangi garis yang letaknya di kanan ujung batangnya.
#
# Garisnya juga tidak menambah informasi. Baris sudah terurut dan baris nasional
# sudah merah, jadi "di atas/di bawah nasional" terbaca dari posisi dan warna.
chart_geser <- ggplot(geser, aes(x = delta, y = Wilayah, fill = agregat)) +
  geom_col(width = 0.58) +
  geom_text(aes(label = label), hjust = 0, nudge_x = 1.1,
            size = 3.0, color = "grey25") +
  scale_fill_manual(values = warna_baris, guide = "none") +
  scale_x_continuous(limits = c(0, 50), breaks = seq(0, 40, 10),
                     labels = lab_id(0), expand = c(0, 0)) +
  labs(
    title = "Perubahan rasio (PMA+PMDN) / PMTB, 2017–2025",
    subtitle = paste0(
      "Poin persentase. Batang merah = nasional. ",
      "Angka dalam kurung = rasio 2017 dan rasio 2025, dibulatkan."),
    x = "Perubahan rasio 2017–2025 (poin persentase)", y = NULL,
    caption = "Sumber: BPS & BKPM, diolah. Rasio = (PMA + PMDN) / PMTB."
  ) +
  theme_classic(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(color = "grey40", size = 9),
        plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
        axis.text.y = element_text(size = 9.5),
        axis.line.y = element_blank(),
        axis.ticks.y = element_blank(),
        panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3))

simpan(chart_geser, file.path(out_dir, "Pergeseran Rasio BKPM terhadap PMTB.png"),
       lebar = 9, tinggi = 4.6)
