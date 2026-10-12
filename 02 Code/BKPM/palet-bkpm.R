# Palet dan pembantu gambar — BKPM
#
# Disampel dari gambar yang sudah ada di `01 Data/BKPM/output/`, bukan dikarang. Sebelum
# berkas ini ada, warna ditulis inline di tiap skrip dan `pulau_colors`
# terdefinisi DUA KALI di berkas yang sama dengan nilai berbeda — lihat catatan
# "Dua palet pulau" di bawah.
#
# source() berkas ini di awal tiap skrip gambar. Jangan menyalin nilai hex-nya
# ke skrip lain: kalau paletnya berubah, ia harus berubah di satu tempat.
#
#   source("02 Code/BKPM/palet-bkpm.R")     # dari root project
#   source("palet-bkpm.R")             # dari dalam 02 Code/BKPM/

suppressPackageStartupMessages(library(ggplot2))

# --- palet -------------------------------------------------------------------

PAL <- list(
  navy_1  = "#081526",   # paling gelap
  navy_2  = "#0E2440",
  navy_3  = "#062E4C",
  abu     = "#797F8C",   # kategori netral / "provinsi lain"
  sian    = "#5DD0E6",   # aksen terang
  merah   = "#D9042B",   # aksen utama
  merah_m = "#C0392B",
  pink    = "#F2509C",
  teal    = "#46A694",
  teal_g  = "#30726A",
  krem    = "#F2E6CE",
  salmon  = "#F59072",
  kertas  = "#ffffff"
)

# Enam pulau. Ini palet yang MENANG — ia dipakai di `01_visualisasi pdrb` bagian
# awal dan di `TFP analysis/02 Code/03_visualisasi.R`, jadi muncul di dua skrip
# yang berbeda. Lihat catatan "Dua palet pulau".
PAL_PULAU <- c(
  "Sumatera"           = PAL$krem,
  "Jawa"               = PAL$pink,
  "Bali-Nusa Tenggara" = PAL$merah,
  "Kalimantan"         = PAL$navy_3,
  "Sulawesi"           = PAL$teal_g,
  "Maluku-Papua"       = PAL$teal
)

# Sebagian skrip menulis "Bali-Nusra", sebagian "Bali-Nusa Tenggara". Alias ini
# supaya keduanya dapat warna yang sama tanpa harus menyeragamkan labelnya dulu.
PAL_PULAU <- c(PAL_PULAU, "Bali-Nusra" = unname(PAL_PULAU[["Bali-Nusa Tenggara"]]))

PAL_MEGASEKTOR <- c(
  "Primer"     = PAL$abu,
  "Sekunder"   = PAL$navy_2,
  "Tersier"    = PAL$navy_1,
  "Kuarterner" = PAL$sian
)

PAL_KELOMPOK <- c(
  "Ekstraktif / enklave sumber daya" = PAL$merah,
  "DKI Jakarta (artefak pencatatan)" = PAL$navy_3,
  "Provinsi lain"                    = PAL$abu
)

# --- DUA PALET PULAU: yang mana yang berlaku --------------------------------
#
# `02 Code/01_visualisasi pdrb.laporan pendahuluan.R` mendefinisikan
# `pulau_colors` dua kali di berkas yang sama:
#
#   baris ~681  Sumatera #F2E6CE  Jawa #F2509C  Bali-Nusra #D9042B
#               Kalimantan #062E4C  Sulawesi #30726A  Maluku-Papua #46A694
#   baris ~765  Sumatera #2980B9  Jawa #C0392B  Bali-Nusra #2C3E50
#               Kalimantan #27AE60  Sulawesi #8E44AD  Maluku-Papua #D35400
#
# Definisi kedua menimpa yang pertama untuk gambar-gambar sesudahnya, sehingga
# enam pulau yang sama muncul dengan dua set warna di satu laporan. Komentar di
# atas definisi kedua bahkan berbunyi "sesuai palet section sebelumnya" —
# padahal nilainya bertentangan dengan yang itu.
#
# Yang kedua adalah palet Flat-UI bawaan (#2980B9, #27AE60, #8E44AD, #C0392B,
# #D35400, #2C3E50, #95A5A6, #F39C12) — warna contoh yang tersalin, bukan
# keputusan desain. Yang pertama yang berlaku, karena ia juga dipakai di skrip
# TFP yang terpisah.
#
# Gambar yang sudah terlanjur memakai palet Flat-UI BELUM dirender ulang.
# Lihat catatan utang di Memory/BKPM/keputusan-visualisasi.md.

PAL_FLATUI_JANGAN_DIPAKAI <- c("#2980B9", "#27AE60", "#8E44AD", "#C0392B",
                               "#D35400", "#2C3E50", "#95A5A6", "#F39C12")

# --- angka -------------------------------------------------------------------
#
# Nama `fmt_id` dan `lab_id` DIPERTAHANKAN dari skrip TFP yang sudah memakainya.
# Doktrin viz menuntut desimal koma, bukan nama pembantu tertentu — menambah
# `koma()` di sini hanya akan membuat dua pembantu yang mengerjakan hal sama,
# lalu bercabang.

fmt_id <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")

lab_id <- function(d = 1) function(x) formatC(x, format = "f", digits = d, decimal.mark = ",")

persen_id <- function(d = 1) function(x) {
  paste0(formatC(x, format = "f", digits = d, decimal.mark = ","), "%")
}

# --- ekspor ------------------------------------------------------------------
#
# dpi 300 mengikuti inventaris keluaran di CLAUDE.md. `bg` dikunci putih karena
# ggsave tanpa bg menghasilkan latar transparan, dan itu tampak sebagai kotak
# hitam saat gambarnya ditempel ke slide bertema gelap.

simpan <- function(plot, nama, lebar = 11, tinggi = 6.5, dpi = 300) {
  ggsave(nama, plot, width = lebar, height = tinggi, dpi = dpi, bg = PAL$kertas)
  cat(sprintf("  tersimpan: %s (%.0fx%.0f px)\n", nama, lebar * dpi, tinggi * dpi))
}

# --- font --------------------------------------------------------------------
#
# BKPM tidak pernah menyebut font di skrip mana pun; seluruh gambar memakai
# bawaan ggplot. Itu DIBIARKAN di sini, bukan disamakan dengan default global
# (Times New Roman / Arial), karena mengubahnya akan mengubah tampilan ~28
# gambar yang sudah jadi dan sebagian sudah masuk .pptx dan .docx.
#
# Kalau pemilik project memutuskan fontnya, tambahkan di sini lalu render ulang
# seluruhnya sekaligus — jangan setengah-setengah.
