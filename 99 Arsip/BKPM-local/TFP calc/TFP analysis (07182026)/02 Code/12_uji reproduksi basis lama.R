# ==============================================================================
# Operasi berkas keluaran project TFP: banding, salin, arsip
#
# Semua operasi berkas project dikerjakan lewat skrip ini, bukan lewat perintah
# shell sekali pakai (cp -R, mv). Alasannya: perintah shell tidak meninggalkan
# jejak — tidak bisa dibaca ulang, tidak bisa diaudit, dan tidak bisa dijalankan
# lagi persis sama beberapa bulan kemudian. Skrip ini tersimpan di repo bersama
# kode analisisnya, jadi apa yang pernah dilakukan pada folder keluaran selalu
# bisa ditelusuri.
#
# Mode dipilih lewat variabel lingkungan MODE. Bawaannya "banding".
#
# ---- MODE=banding (bawaan) ---------------------------------------------------
# Menguji bahwa keluaran basis lama tidak berubah setelah kode disunting.
# Dipakai setiap kali skrip 01/02/03/04/08/09/10 disunting. Ia membandingkan
# folder keluaran terhadap SALINAN folder itu yang diambil sebelum penyuntingan.
#
# Checksum berkas tidak dipakai sebagai vonis: .xlsx menyimpan stempel waktu di
# dalamnya dan .png menyimpan metadata, jadi dua berkas dengan isi identik tetap
# berbeda byte. Yang dibandingkan karena itu ISINYA:
#   .txt   -> baris demi baris
#   .xlsx  -> sel demi sel, per sheet
#   .png   -> chunk gambar
#   .rds   -> isi objeknya
#
#   DIR_BARU="03 Output (modal riil)" \
#   DIR_LAMA="<salinan>/riil_baseline" \
#     Rscript "02 Code/12_uji reproduksi basis lama.R"
#
# Exit 0 = seluruh isi sama. Exit 1 = ada yang berubah, dan berkasnya disebut.
#
# ---- MODE=salin --------------------------------------------------------------
# Membuat salinan cadangan satu folder keluaran SEBELUM kode disunting, supaya
# mode banding punya pembanding.
#
#   MODE=salin DIR_SUMBER="03 Output (modal riil)" DIR_TUJUAN="<salinan>" \
#     Rscript "02 Code/12_uji reproduksi basis lama.R"
#
# Exit 0 = jumlah berkas di tujuan sama dengan di sumber. Exit 1 = tidak sama.
#
# ---- MODE=arsip --------------------------------------------------------------
# Memindahkan berkas keluaran yang sudah tidak diproduksi lagi ke folder arsip.
# Daftar berkas dipisah "|" (pipe), bukan koma, karena nama berkas project ini
# memuat spasi dan tanda kurung.
#
#   MODE=arsip DIR_SUMBER="03 Output (ADHB)" DIR_ARSIP="03 Output (ADHB)/arsip" \
#   BERKAS="TFP Nasional (ADHB).png|Ringkasan TFP (ADHB).xlsx" \
#   KONFIRMASI=ya \
#     Rscript "02 Code/12_uji reproduksi basis lama.R"
#
# Tanpa KONFIRMASI=ya ia hanya mencetak inventaris dan berhenti (exit 0).
# ==============================================================================

suppressPackageStartupMessages({
  library(openxlsx)
})

mode <- Sys.getenv("MODE", unset = "banding")

# ---- pembanding per jenis berkas (dipakai mode banding) ----------------------
# Fungsi-fungsi ini berdiri sendiri karena dipanggil berulang di dalam loop.
banding_txt <- function(a, b) {
  ra <- readLines(a, warn = FALSE)
  rb <- readLines(b, warn = FALSE)
  if (identical(ra, rb)) return(NA_character_)
  n <- min(length(ra), length(rb))
  beda <- which(ra[seq_len(n)] != rb[seq_len(n)])
  if (length(beda) == 0) return(sprintf("jumlah baris beda: %d vs %d", length(ra), length(rb)))
  sprintf("%d baris beda, pertama di baris %d", length(beda), beda[1])
}

banding_xlsx <- function(a, b) {
  sa <- getSheetNames(a); sb <- getSheetNames(b)
  if (!identical(sa, sb)) return(sprintf("daftar sheet beda: %s vs %s",
                                         paste(sa, collapse = ","),
                                         paste(sb, collapse = ",")))
  for (s in sa) {
    da <- read.xlsx(a, sheet = s)
    db <- read.xlsx(b, sheet = s)
    if (!isTRUE(all.equal(da, db, tolerance = 1e-12))) {
      return(sprintf("sheet '%s' berbeda isinya", s))
    }
  }
  NA_character_
}

# PNG dibandingkan lewat chunk gambarnya, bukan lewat checksum seluruh berkas.
# Berkas PNG memuat chunk penanda waktu (tIME) dan teks (tEXt) yang berubah tiap
# render meski gambarnya sama persis. Yang menentukan rupa gambar hanya IHDR
# (dimensi dan kedalaman warna), PLTE (palet), tRNS (transparansi), dan IDAT
# (piksel terkompresi). Keempat itulah yang dibandingkan.
#
# Struktur chunk PNG: 8 byte tanda tangan, lalu berulang
#   panjang (4 byte big-endian) | jenis (4 byte ASCII) | data | CRC (4 byte).
chunk_gambar <- function(path) {
  raw_all <- readBin(path, "raw", n = file.info(path)$size)
  if (length(raw_all) < 8) return(NULL)
  pos <- 9L                                  # lewati tanda tangan 8 byte
  penting <- c("IHDR", "PLTE", "tRNS", "IDAT")
  kumpul <- raw()
  while (pos + 7L <= length(raw_all)) {
    panjang <- sum(as.integer(raw_all[pos:(pos + 3L)]) * c(256^3, 256^2, 256, 1))
    jenis   <- rawToChar(raw_all[(pos + 4L):(pos + 7L)])
    awal    <- pos + 8L
    akhir   <- awal + panjang - 1L
    if (akhir > length(raw_all)) break
    if (jenis %in% penting) {
      kumpul <- c(kumpul, raw_all[(pos + 4L):(pos + 7L)])
      if (panjang > 0) kumpul <- c(kumpul, raw_all[awal:akhir])
    }
    if (jenis == "IEND") break
    pos <- akhir + 5L                        # lewati CRC 4 byte
  }
  kumpul
}

banding_png <- function(a, b) {
  ca <- chunk_gambar(a)
  cb <- chunk_gambar(b)
  if (is.null(ca) || is.null(cb)) return("berkas PNG tidak terbaca")
  if (identical(ca, cb)) return(NA_character_)
  sprintf("chunk gambar berbeda (%d vs %d byte)", length(ca), length(cb))
}

# ==============================================================================
# Pemilihan mode
# ==============================================================================
if (mode == "banding") {

  dir_baru <- Sys.getenv("DIR_BARU", unset = "")
  dir_lama <- Sys.getenv("DIR_LAMA", unset = "")
  if (dir_baru == "" || dir_lama == "") {
    stop("Set DIR_BARU dan DIR_LAMA lewat variabel lingkungan.")
  }
  stopifnot(dir.exists(dir_baru), dir.exists(dir_lama))

  cat(sprintf("Baru : %s\nLama : %s\n\n", dir_baru, dir_lama))

  # Artefak konflik sinkronisasi OneDrive tidak pernah ditulis skrip mana pun,
  # jadi ia bukan bagian dari keluaran yang diuji.
  adalah_artefak <- function(x) grepl("MacBook Air", x, fixed = TRUE)

  berkas <- sort(setdiff(
    intersect(list.files(dir_baru), list.files(dir_lama)),
    c(".DS_Store")))
  berkas <- berkas[!adalah_artefak(berkas)]

  hasil <- data.frame(berkas = berkas, catatan = NA_character_,
                      stringsAsFactors = FALSE)

  for (i in seq_along(berkas)) {
    f  <- berkas[i]
    fa <- file.path(dir_baru, f)
    fb <- file.path(dir_lama, f)
    ext <- tolower(tools::file_ext(f))
    hasil$catatan[i] <- switch(ext,
      txt  = banding_txt(fa, fb),
      xlsx = banding_xlsx(fa, fb),
      png  = banding_png(fa, fb),
      rds  = if (isTRUE(all.equal(readRDS(fa), readRDS(fb), tolerance = 1e-12))) {
               NA_character_
             } else "isi .rds berbeda",
      sprintf("jenis berkas tidak diuji (.%s)", ext))
  }

  beda <- hasil[!is.na(hasil$catatan), , drop = FALSE]
  sama <- hasil[is.na(hasil$catatan), , drop = FALSE]

  cat(sprintf("Berkas diuji : %d\n", nrow(hasil)))
  cat(sprintf("Isi sama     : %d\n", nrow(sama)))
  cat(sprintf("Isi berbeda  : %d\n\n", nrow(beda)))

  if (nrow(beda) > 0) {
    cat("BERKAS YANG ISINYA BERUBAH:\n")
    for (i in seq_len(nrow(beda))) {
      cat(sprintf("  %-55s %s\n", beda$berkas[i], beda$catatan[i]))
    }
    cat("\nGAGAL: keluaran basis lama tidak direproduksi.\n")
    quit(save = "no", status = 1)
  }

  cat("LOLOS: seluruh isi keluaran basis lama direproduksi persis.\n")

} else if (mode == "salin") {

  dir_sumber <- Sys.getenv("DIR_SUMBER", unset = "")
  dir_tujuan <- Sys.getenv("DIR_TUJUAN", unset = "")
  if (dir_sumber == "" || dir_tujuan == "") {
    stop("Set DIR_SUMBER dan DIR_TUJUAN lewat variabel lingkungan.")
  }
  stopifnot(dir.exists(dir_sumber))

  cat(sprintf("Sumber : %s\nTujuan : %s\n\n", dir_sumber, dir_tujuan))

  # Isi lama dihapus dulu supaya salinan tidak bercampur sisa salinan sebelumnya.
  # Sisa itu berbahaya: mode banding akan menguji berkas yang tidak pernah
  # diproduksi lagi dan mengira keluarannya utuh.
  if (dir.exists(dir_tujuan)) {
    cat("PERINGATAN: folder tujuan sudah ada, isinya ditimpa.\n\n")
    unlink(dir_tujuan, recursive = TRUE)
  }
  dir.create(dir_tujuan, recursive = TRUE, showWarnings = FALSE)

  berkas <- setdiff(list.files(dir_sumber), c(".DS_Store"))
  tersalin <- file.copy(file.path(dir_sumber, berkas),
                        file.path(dir_tujuan, berkas),
                        overwrite = TRUE)

  cat(sprintf("Berkas di sumber : %d\n", length(berkas)))
  cat(sprintf("Berkas tersalin  : %d\n", sum(tersalin)))

  # Verifikasi ulang lewat isi folder tujuan, bukan lewat nilai balik file.copy
  # saja, supaya kegagalan tulis diam-diam tetap ketahuan.
  ada_di_tujuan <- setdiff(list.files(dir_tujuan), c(".DS_Store"))
  cat(sprintf("Berkas di tujuan : %d\n\n", length(ada_di_tujuan)))

  if (length(ada_di_tujuan) != length(berkas)) {
    kurang <- setdiff(berkas, ada_di_tujuan)
    cat("BERKAS YANG TIDAK SAMPAI DI TUJUAN:\n")
    for (f in kurang) cat(sprintf("  %s\n", f))
    cat("\nGAGAL: salinan tidak lengkap.\n")
    quit(save = "no", status = 1)
  }

  cat("SELESAI: seluruh berkas tersalin.\n")

} else if (mode == "arsip") {

  dir_sumber <- Sys.getenv("DIR_SUMBER", unset = "")
  dir_arsip  <- Sys.getenv("DIR_ARSIP", unset = "")
  daftar     <- Sys.getenv("BERKAS", unset = "")
  konfirmasi <- Sys.getenv("KONFIRMASI", unset = "")
  if (dir_sumber == "" || dir_arsip == "" || daftar == "") {
    stop("Set DIR_SUMBER, DIR_ARSIP, dan BERKAS lewat variabel lingkungan.")
  }
  stopifnot(dir.exists(dir_sumber))

  # Pemisah pipe, bukan koma: nama berkas project ini memuat spasi dan tanda
  # kurung, dan beberapa memuat koma di dalam namanya.
  berkas <- trimws(strsplit(daftar, "|", fixed = TRUE)[[1]])
  berkas <- berkas[berkas != ""]

  cat(sprintf("Sumber : %s\nArsip  : %s\n\n", dir_sumber, dir_arsip))

  # Inventaris selalu dicetak lebih dulu, apa pun nilai KONFIRMASI, supaya
  # pembaca melihat persis berkas apa yang akan disentuh sebelum apa pun terjadi.
  cat("INVENTARIS:\n")
  ada <- logical(length(berkas))
  for (i in seq_along(berkas)) {
    jalur <- file.path(dir_sumber, berkas[i])
    ada[i] <- file.exists(jalur)
    if (ada[i]) {
      ukuran <- file.info(jalur)$size
      cat(sprintf("  %-55s %9.1f KB  ada\n", berkas[i], ukuran / 1024))
    } else {
      cat(sprintf("  %-55s %12s  TIDAK DITEMUKAN\n", berkas[i], "-"))
    }
  }
  cat("\n")

  # Pemindahan sebagian lebih buruk daripada tidak memindahkan sama sekali:
  # folder keluaran jadi setengah jalan dan sulit dipulihkan tanpa jejak.
  if (any(!ada)) {
    cat(sprintf("GAGAL: %d berkas tidak ditemukan, tidak ada yang dipindahkan.\n",
                sum(!ada)))
    quit(save = "no", status = 1)
  }

  if (konfirmasi != "ya") {
    cat("PRATINJAU: belum ada yang dipindahkan.\n")
    cat("Jalankan ulang dengan KONFIRMASI=ya kalau daftar di atas sudah benar.\n")
    quit(save = "no", status = 0)
  }

  dir.create(dir_arsip, recursive = TRUE, showWarnings = FALSE)

  cat("PEMINDAHAN:\n")
  gagal <- 0
  for (i in seq_along(berkas)) {
    asal   <- file.path(dir_sumber, berkas[i])
    tujuan <- file.path(dir_arsip, berkas[i])
    cara   <- "rename"

    pindah <- file.rename(asal, tujuan)

    # file.rename gagal kalau sumber dan arsip berada di volume berbeda
    # (misalnya arsip ditaruh di disk eksternal). Salin-lalu-hapus adalah
    # jalan keluarnya, dan caranya disebut di keluaran supaya tidak tersamar.
    if (!pindah) {
      cara <- "salin+hapus"
      if (file.copy(asal, tujuan, overwrite = TRUE)) {
        pindah <- file.remove(asal)
      }
    }

    hilang_dari_sumber <- !file.exists(asal)
    muncul_di_arsip    <- file.exists(tujuan)

    if (pindah && hilang_dari_sumber && muncul_di_arsip) {
      cat(sprintf("  %-55s pindah (%s)\n", berkas[i], cara))
    } else {
      gagal <- gagal + 1
      cat(sprintf("  %-55s GAGAL (di sumber: %s, di arsip: %s)\n",
                  berkas[i],
                  ifelse(hilang_dari_sumber, "hilang", "masih ada"),
                  ifelse(muncul_di_arsip, "ada", "tidak ada")))
    }
  }
  cat("\n")

  if (gagal > 0) {
    cat(sprintf("GAGAL: %d dari %d berkas tidak berpindah bersih.\n",
                gagal, length(berkas)))
    quit(save = "no", status = 1)
  }

  cat(sprintf("SELESAI: %d berkas pindah ke arsip.\n", length(berkas)))

} else {
  stop(sprintf("MODE tidak dikenal: '%s'. Pilihannya: banding, salin, arsip.", mode))
}
