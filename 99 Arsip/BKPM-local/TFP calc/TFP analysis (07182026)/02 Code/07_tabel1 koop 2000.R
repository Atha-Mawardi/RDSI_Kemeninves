# =============================================================================
# 07_tabel1 koop 2000.R
#
# Ekstraksi Tabel 1 Koop, Osiewalski & Steel (2000), Journal of Business &
# Economic Statistics 18(3), 284-299, DOI 10.1080/07350015.2000.10524871.
#
# Judul tabel aslinya: "Posterior and Prior for Returns to Scale and Factor
# Elasticities". Isinya median posterior untuk empat region pada dua tahun
# ujung, plus prior sebagai pembanding.
#
# TIGA HAL YANG MUDAH SALAH BACA:
#   1. Angka dalam kurung di paper adalah RENTANG ANTARKUARTIL (IQR), BUKAN
#      galat baku. Catatan kaki tabelnya menyatakan itu. Menyebutnya SE akan
#      membuat selang keyakinan yang dilaporkan salah.
#   2. Nilai tengahnya MEDIAN posterior, bukan rata-rata. Untuk posterior yang
#      menceng, keduanya berbeda.
#   3. RTS diestimasi sebagai parameter tersendiri, bukan dihitung dari b1 + b2.
#      Karena median jumlah tidak sama dengan jumlah median, RTS di tabel bisa
#      berbeda tipis dari b1 + b2. Sheet `periksa` menghitung selisihnya.
#
# Sumber angka: PDF terbit (JSTOR), dibaca langsung. Bukan kutipan sekunder.
#
# Dibuat 2026-08-04. Litrev: 00 Docs/litrev-elastisitas-sumber-berdoi.md §3b
# Ringkasan paper: ~/.claude/literature/papers/koop-2000-sources-output-growth-panel-countries.md
# =============================================================================

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
})

if (!dir.exists("03 Output")) stop("Jalankan skrip ini dari folder 'TFP analysis (07182026)'.")

# -----------------------------------------------------------------------------
# 1. Salinan Tabel 1, apa adanya
# -----------------------------------------------------------------------------
# Urutan kolom di paper: RTS 1965 | RTS 1990 | b1 1965 | b1 1990 | b2 1965 | b2 1990
# Tiap sel dua baris: median di atas, IQR dalam kurung di bawahnya.

TABEL1 <- tribble(
  ~baris,                 ~jenis,     ~n_negara,
  ~rts65, ~rts65_iqr, ~rts90, ~rts90_iqr,
  ~b1_65, ~b1_65_iqr, ~b1_90, ~b1_90_iqr,
  ~b2_65, ~b2_65_iqr, ~b2_90, ~b2_90_iqr,

  "West",                 "posterior", 21L,
  1.096, 0.051, 0.967, 0.054,
  0.273, 0.038, 0.374, 0.053,
  0.823, 0.079, 0.592, 0.097,

  "East Asia",            "posterior",  5L,
  0.922, 0.039, 0.949, 0.043,
  0.338, 0.056, 0.287, 0.052,
  0.582, 0.052, 0.660, 0.060,

  "Africa",               "posterior",  8L,
  0.966, 0.045, 0.893, 0.043,
  0.135, 0.058, 0.220, 0.066,
  0.830, 0.057, 0.671, 0.083,

  "Latin America",        "posterior", 10L,
  1.063, 0.061, 1.161, 0.065,
  0.476, 0.055, 0.346, 0.060,
  0.587, 0.102, 0.815, 0.114,

  "Prior West",           "prior",     NA_integer_,
  1.000, 0.135, 1.000, 0.135,
  0.500, 0.270, 0.500, 0.270,
  0.500, 0.270, 0.500, 0.270,

  "Prior other regions",  "prior",     NA_integer_,
  1.000, 0.234, 1.000, 0.234,
  0.500, 0.405, 0.500, 0.405,
  0.500, 0.405, 0.500, 0.405
)

# Nama region berbahasa Indonesia dan isi kelompoknya (Lampiran A paper)
ANGGOTA <- tribble(
  ~baris, ~region_id, ~anggota,
  "West", "Negara industri Barat",
  "Kanada, Amerika Serikat, Israel, Turki, Austria, Belgia, Denmark, Finlandia, Prancis, Jerman, Yunani, Irlandia, Italia, Belanda, Norwegia, Portugal, Spanyol, Swedia, Inggris, Australia, Selandia Baru",
  "East Asia", "Asia Timur",
  "Hong Kong, Jepang, Korea, Filipina, Thailand",
  "Africa", "Afrika",
  "Cote d'Ivoire, Kenya, Madagaskar, Malawi, Maroko, Nigeria, Zambia, Zimbabwe",
  "Latin America", "Amerika Latin",
  "Republik Dominika, Honduras, Jamaika, Meksiko, Panama, Argentina, Bolivia, Cile, Ekuador, Venezuela",
  "Prior West", "Prior, region acuan", "-",
  "Prior other regions", "Prior, region selain acuan", "-"
)

# -----------------------------------------------------------------------------
# 2. Bentuk lebar, meniru tata letak paper
# -----------------------------------------------------------------------------
tabel1_asli <- TABEL1 %>%
  left_join(ANGGOTA, by = "baris") %>%
  transmute(
    baris, region_id, jenis, n_negara,
    `RTS 1965`  = sprintf("%.3f (%.3f)", rts65, rts65_iqr),
    `RTS 1990`  = sprintf("%.3f (%.3f)", rts90, rts90_iqr),
    `b1 1965`   = sprintf("%.3f (%.3f)", b1_65, b1_65_iqr),
    `b1 1990`   = sprintf("%.3f (%.3f)", b1_90, b1_90_iqr),
    `b2 1965`   = sprintf("%.3f (%.3f)", b2_65, b2_65_iqr),
    `b2 1990`   = sprintf("%.3f (%.3f)", b2_90, b2_90_iqr),
    anggota
  )

# -----------------------------------------------------------------------------
# 3. Bentuk panjang, satu baris satu angka
# -----------------------------------------------------------------------------
tabel1_tidy <- TABEL1 %>%
  left_join(ANGGOTA, by = "baris") %>%
  pivot_longer(
    cols = matches("^(rts|b1|b2)"),
    names_to = "kunci", values_to = "nilai"
  ) %>%
  mutate(
    ukuran = ifelse(grepl("_iqr$", kunci), "iqr", "median"),
    kunci  = sub("_iqr$", "", kunci),
    besaran = case_when(
      grepl("^rts", kunci) ~ "RTS (imbal hasil)",
      grepl("^b1",  kunci) ~ "b1 (elastisitas modal)",
      grepl("^b2",  kunci) ~ "b2 (elastisitas tenaga kerja)"
    ),
    tahun = ifelse(grepl("65$", kunci), 1965L, 1990L)
  ) %>%
  select(baris, region_id, jenis, n_negara, besaran, tahun, ukuran, nilai) %>%
  pivot_wider(names_from = ukuran, values_from = nilai) %>%
  arrange(jenis, baris, besaran, tahun) %>%
  mutate(
    batas_bawah_kuartil = NA_real_,
    batas_atas_kuartil  = NA_real_
  ) %>%
  select(-batas_bawah_kuartil, -batas_atas_kuartil)

# -----------------------------------------------------------------------------
# 4. Pemeriksa: apakah b1 + b2 mendekati RTS yang dilaporkan
# -----------------------------------------------------------------------------
# RTS diestimasi sebagai parameter tersendiri dan yang dilaporkan mediannya.
# Median jumlah tidak sama dengan jumlah median, jadi selisih kecil itu wajar.
# Selisih besar akan berarti kolomnya salah dibaca.
periksa <- TABEL1 %>%
  select(baris, jenis, rts65, rts90, b1_65, b1_90, b2_65, b2_90) %>%
  transmute(
    baris, jenis,
    rts_1965_dilaporkan = rts65,
    rts_1965_b1_plus_b2 = b1_65 + b2_65,
    selisih_1965        = round(rts65 - (b1_65 + b2_65), 4),
    rts_1990_dilaporkan = rts90,
    rts_1990_b1_plus_b2 = b1_90 + b2_90,
    selisih_1990        = round(rts90 - (b1_90 + b2_90), 4)
  )

maks_selisih <- max(abs(c(periksa$selisih_1965, periksa$selisih_1990)))
if (maks_selisih > 0.005) {
  stop(sprintf("Selisih RTS vs b1+b2 mencapai %.4f. Kolom kemungkinan salah dibaca.",
               maks_selisih))
}

# -----------------------------------------------------------------------------
# 5. Turunan yang berguna: arah pergerakan 1965 ke 1990
# -----------------------------------------------------------------------------
pergerakan <- TABEL1 %>%
  filter(jenis == "posterior") %>%
  left_join(ANGGOTA, by = "baris") %>%
  transmute(
    region_id, n_negara,
    d_rts = round(rts90 - rts65, 3),
    d_b1  = round(b1_90 - b1_65, 3),
    d_b2  = round(b2_90 - b2_65, 3),
    imbal_hasil_1965 = ifelse(rts65 > 1, "meningkat", "menurun"),
    imbal_hasil_1990 = ifelse(rts90 > 1, "meningkat", "menurun"),
    modal_vs_tk_1965 = ifelse(b1_65 > b2_65, "b1 > b2", "b1 < b2"),
    modal_vs_tk_1990 = ifelse(b1_90 > b2_90, "b1 > b2", "b1 < b2")
  )

# -----------------------------------------------------------------------------
# 6. Catatan sumber dan kaveat
# -----------------------------------------------------------------------------
CATATAN <- tribble(
  ~hal, ~isinya,
  "Sumber", "Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), Modeling the Sources of Output Growth in a Panel of Countries, Journal of Business & Economic Statistics 18(3), 284-299",
  "DOI", "10.1080/07350015.2000.10524871",
  "Tabel", "Tabel 1: Posterior and Prior for Returns to Scale and Factor Elasticities",
  "Status baca", "PDF terbit dibaca langsung (JSTOR), bukan kutipan sekunder",
  "Diperiksa", "DOI, judul, penulis, tahun, venue lewat Crossref 2026-08-04",
  "Angka dalam kurung", "RENTANG ANTARKUARTIL (IQR), bukan galat baku. Catatan kaki tabel aslinya menyatakan itu",
  "Nilai tengah", "MEDIAN posterior, bukan rata-rata",
  "RTS", "diestimasi sebagai parameter tersendiri, bukan dihitung dari b1 + b2; selisihnya ada di sheet periksa",
  "Data", "44 negara, tahunan 1965-1990, Penn World Table versi 5.6",
  "Peubah", "Y = PDB riil dolar konstan indeks berantai; L = jumlah pekerja; K = stok modal nonresidensial",
  "Metode", "frontier produksi stokastik Bayesian, Gibbs sampler, frontier berbeda tiap region, elastisitas berubah menurut waktu",
  "Restriksi", "imbal hasil konstan TIDAK dipaksakan; prior dipusatkan di 1,0 tetapi tidak mengikat; satu-satunya batasan regularitas adalah elastisitas tak negatif, dan fraksi penolakannya di bawah 6 persen",
  "Uji frontier seragam", "faktor Bayes untuk hipotesis elastisitas suatu region sama dengan Barat berorde 10^-99 (Asia Timur) dan 10^-93 (Afrika); frontier dunia tunggal ditolak keras",
  "Kaveat 1", "INDONESIA TIDAK ADA DI SAMPEL. Region Asia Timur hanya Hong Kong, Jepang, Korea, Filipina, Thailand, jadi ia pembanding taraf pembangunan, bukan pembanding kawasan",
  "Kaveat 2", "penulisnya sendiri memperingatkan frontier Asia Timur dan Afrika ditentukan terlalu sedikit negara sehingga kurang terdefinisi baik",
  "Kaveat 3", "data berhenti 1990 dan berbasis PWT 5.6, yang sudah beberapa revisi tertinggal",
  "Kaveat 4", "ada bukti lemah korelasi serial pada galat simetris; penulisnya memilih mengabaikannya karena sulit dimodelkan",
  "Temuan kunci", "b1 < b2 di seluruh delapan pasangan region-periode; penulisnya menyatakan 'Capital elasticities tend to be lower than labor elasticities for all regions and all periods' (Bagian 4.2, nomor halaman belum dicatat)"
)

# -----------------------------------------------------------------------------
# 7. Tulis Excel
# -----------------------------------------------------------------------------
cat("Baris posterior:", sum(TABEL1$jenis == "posterior"),
    "| baris prior:", sum(TABEL1$jenis == "prior"), "\n")
cat("Baris tidy:", nrow(tabel1_tidy), "\n")
cat(sprintf("Selisih terbesar RTS vs b1+b2: %.4f (ambang 0,005)\n", maks_selisih))
cat("\nPergerakan 1965 -> 1990:\n")
print(as.data.frame(pergerakan))

berkas <- file.path("03 Output", "Koop dkk 2000 - Tabel 1 Posterior_0804.xlsx")
write.xlsx(
  list(tabel1_tidy = tabel1_tidy,
       tabel1_asli = tabel1_asli,
       pergerakan  = pergerakan,
       periksa     = periksa,
       catatan     = CATATAN),
  file = berkas, overwrite = TRUE, colWidths = "auto"
)

# openxlsx 4.2.8 menulis relasi ke drawings yang berkasnya tidak ada; pembaca ketat gagal.
bersihkan_relasi <- function(path) {
  tmp <- file.path(tempdir(), "xlsxfix7"); unlink(tmp, recursive = TRUE); dir.create(tmp)
  utils::unzip(path, exdir = tmp)
  for (f in list.files(file.path(tmp, "xl", "worksheets", "_rels"), full.names = TRUE)) {
    x <- readLines(f, warn = FALSE)
    x <- gsub("<Relationship [^>]*(drawings/drawing|drawings/vmlDrawing)[^>]*/>", "", x)
    writeLines(x, f)
  }
  wd <- setwd(tmp); on.exit(setwd(wd), add = TRUE)
  utils::zip(path, files = list.files(".", recursive = TRUE, all.files = TRUE), flags = "-rq")
}
bersihkan_relasi(normalizePath(berkas))

cat(sprintf("\nDitulis: %s\n", berkas))
