# SCRIPT OVERVIEW --------------------------------------
# Simulasi trajektori pertumbuhan 2026-2029 menuju sasaran 8%.
#
# Identitas yang dipakai, sama dengan dekomposisi di skrip 02:
#   gY = b1*gK + b2*gL + TFP
#
# Tiga skenario:
#   1. Tanpa intervensi  - gK, gL, TFP bertahan di laju basis; hitung gap ke target
#   2. RTS tetap DRS     - kebutuhan gK dan TFP untuk mencapai target
#   3. RTS penuh CRS     - sama, dengan b1+b2 dinaikkan ke 1,0 secara proporsional
#
# Karena satu persamaan memuat dua hal tak tentu (gK dan TFP), hasilnya berbentuk
# FRONTIER, bukan titik tunggal. Dua jangkar dilaporkan di tiap ujungnya.
#
# Basis laju pertumbuhan: rata-rata 2022-2024 (pasca-COVID), keputusan Eqi.
# Elastisitas tetap dari panel penuh 2017-2024 - hanya lajunya yang dipersempit.
#
# Input  : 03 Output (modal riil)/parameter_terpilih.rds
#          03 Output (modal riil)/Dekomposisi Nasional.xlsx  (sheet seri_nasional)
#          ../Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx  (level PMTB/PDRB)
# Output : 03 Output (modal riil)/Simulasi Trajektori 2026-2029.xlsx
#
# Jalankan dari root project, SETELAH skrip 01 dan 02:
#   Rscript "02 Code/08_simulasi trajektori.R" > "03 Output (modal riil)/log_08_trajektori.txt" 2>&1
# ------------------------------------------------------

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(purrr)
})

BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"
out_dir <- switch(BASIS_MODAL,
                  riil    = "03 Output (modal riil)",
                  nominal = "03 Output",
                  adhb    = "03 Output (ADHB)")

# Rasio K/Y bagian 4 satu-satunya tempat di skrip ini yang sensitif satuan, jadi
# modal dan output wajib sebasis. `4_ADHB`/`9_ADHB` triliun, `4_ADHK`/`9_ADHK` juta.
kol_modal  <- switch(BASIS_MODAL, riil = "4_ADHK", nominal = "4_ADHK", adhb = "4_ADHB")
kol_output <- if (BASIS_ADHB) "9_ADHB" else "9_ADHK"

data_file <- "../Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
par_file  <- file.path(out_dir, "parameter_terpilih.rds")
dek_file  <- file.path(out_dir, "Dekomposisi Nasional.xlsx")
stopifnot(file.exists(par_file), file.exists(dek_file))

fmt_id <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")

cat("=============== Simulasi trajektori 2026-2029 ===============\n")
cat(sprintf("Basis harga modal: %s\n", BASIS_MODAL))

# ==============================================================================
# 1. Parameter dan basis
# ==============================================================================
par <- readRDS(par_file)
b1_drs <- unname(par$b1_un)
b2_drs <- unname(par$b2_un)
S_drs  <- b1_drs + b2_drs

# Penskalaan RTS proporsional: bauran modal-tenaga kerja ditahan tetap, hanya
# jumlahnya yang dinaikkan ke 1,0. Keputusan Eqi. Alternatifnya memakai b1_crs
# hasil regresi per-pekerja, yang mencampur perubahan skala dengan perubahan
# bobot antarfaktor - karena itu tidak dipakai di sini.
share_K <- b1_drs / S_drs
S_crs   <- 1.0
b1_crs  <- share_K * S_crs
b2_crs  <- (1 - share_K) * S_crs

cat(sprintf("\nElastisitas DRS : b1=%.4f b2=%.4f (jumlah %.4f)\n", b1_drs, b2_drs, S_drs))
cat(sprintf("Elastisitas CRS : b1=%.4f b2=%.4f (jumlah %.4f), pangsa modal ditahan %.4f\n",
            b1_crs, b2_crs, S_crs, share_K))

# -- Laju basis: rata-rata 2022-2024 ------------------------------------------
TAHUN_BASIS_DARI <- 2022
TAHUN_BASIS_SAMPAI <- 2024

seri <- read.xlsx(dek_file, sheet = "seri_nasional")
basis <- seri %>%
  filter(Year >= TAHUN_BASIS_DARI, Year <= TAHUN_BASIS_SAMPAI) %>%
  summarise(gY = mean(g_Y), gK = mean(g_K), gL = mean(g_L))
gY0 <- basis$gY; gK0 <- basis$gK; gL0 <- basis$gL

# Kontribusi TFP basis BERBEDA di tiap set elastisitas, karena residual menyerap
# apa pun yang tidak dialokasikan ke input. Ini titik yang paling sering salah
# dibaca: sisa yang lebih kecil di CRS bukan berarti TFP-nya lebih baik.
tfp0_drs <- gY0 - b1_drs * gK0 - b2_drs * gL0
tfp0_crs <- gY0 - b1_crs * gK0 - b2_crs * gL0

cat(sprintf("\nLaju basis %d-%d: gY=%.2f gK=%.2f gL=%.2f (%%/thn)\n",
            TAHUN_BASIS_DARI, TAHUN_BASIS_SAMPAI, gY0, gK0, gL0))
cat(sprintf("Kontribusi TFP basis: DRS %.2f poin | CRS %.2f poin\n", tfp0_drs, tfp0_crs))

# ==============================================================================
# 2. Target trajektori
# ==============================================================================
target <- tibble(
  Year   = 2026:2029,
  gY_target = c(5.40, 6.15, 7.00, 8.00)
)
cat("\nTrajektori sasaran:\n")
print(as.data.frame(target), row.names = FALSE)

# ==============================================================================
# SKENARIO 1. Tanpa intervensi
# ==============================================================================
# gK, gL, dan TFP bertahan di laju basis, jadi gY proyeksi = gY basis tiap tahun.
# Gap = jarak yang harus ditutup, apa pun caranya.
cat("\n=============== Skenario 1: tanpa intervensi ===============\n")
sken1 <- target %>%
  mutate(gY_proyeksi = gY0,
         gap = gY_target - gY_proyeksi,
         kontrib_modal = b1_drs * gK0,
         kontrib_tk    = b2_drs * gL0,
         kontrib_tfp   = tfp0_drs)
print(as.data.frame(sken1 %>% mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)
cat(sprintf("\nTanpa intervensi, sasaran 2029 meleset %.2f poin persen.\n",
            sken1$gap[sken1$Year == 2029]))

# ==============================================================================
# SKENARIO 2 & 3. Kebutuhan gK dan TFP
# ==============================================================================
# Dua jangkar untuk tiap tahun dan tiap set elastisitas:
#   (a) TFP ditahan di basis -> berapa gK yang dibutuhkan
#   (b) gK ditahan di basis  -> berapa kontribusi TFP yang dibutuhkan
jangkar <- function(nama, b1, b2, tfp0) {
  target %>%
    mutate(
      skenario = nama, b1 = b1, b2 = b2, rts = b1 + b2,
      tfp_basis = tfp0,
      # (a) tutup seluruh gap lewat modal
      gK_perlu  = gK0 + (gY_target - gY0) / b1,
      # (b) tutup seluruh gap lewat TFP
      tfp_perlu = tfp0 + (gY_target - gY0),
      # jarak yang harus dikejar, relatif terhadap basis masing-masing
      lonjakan_gK  = gK_perlu - gK0,
      lonjakan_tfp = tfp_perlu - tfp0
    ) %>%
    select(skenario, Year, gY_target, b1, b2, rts, tfp_basis,
           gK_perlu, lonjakan_gK, tfp_perlu, lonjakan_tfp)
}

sken23 <- bind_rows(
  jangkar("2. RTS tetap DRS", b1_drs, b2_drs, tfp0_drs),
  jangkar("3. RTS penuh CRS", b1_crs, b2_crs, tfp0_crs)
)

cat("\n=============== Skenario 2 & 3: jangkar kebutuhan ===============\n")
print(as.data.frame(sken23 %>% mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

# ---- ASSERTION POKOK --------------------------------------------------------
# Lonjakan TFP yang disyaratkan WAJIB identik di kedua skenario, karena kalau
# gK dan gL ditahan di basis, seluruh tambahan pertumbuhan harus datang dari TFP.
# Asumsi skala hasil hanya mengubah cara melabeli gY basis, bukan jaraknya ke
# target. Kalau assertion ini gagal, ada kesalahan aljabar di atas.
cek_lonjakan <- sken23 %>%
  group_by(Year) %>%
  summarise(rentang = max(lonjakan_tfp) - min(lonjakan_tfp), .groups = "drop")
stopifnot(all(cek_lonjakan$rentang < 1e-10))
stopifnot(all(abs(sken23$lonjakan_tfp - (sken23$gY_target - gY0)) < 1e-10))
cat("\nLolos: lonjakan TFP yang disyaratkan identik di DRS dan CRS, yaitu (target - gY basis).\n")
cat("Yang berbeda antar skenario hanya kebutuhan investasinya.\n")

# ==============================================================================
# STRATEGI RTS DAN TFP. Tabel batang bertumpuk empat skenario
# ==============================================================================
# Satu tabel panjang, 4 skenario x 4 tahun, sebagai bahan gambar batang bertumpuk.
# Dirakit dari empat potongan terpisah supaya tiap skenario terbaca sendiri-sendiri.
#
# Skenario 4 menjawab pertanyaan sebaliknya dari skenario 2 dan 3: kalau justru
# TFP dan skala hasil yang ditahan di basis, dan seluruh dorongan ditaruh di
# input, seberapa jauh pertumbuhan sampai. Lajunya dipatok 8 persen per tahun
# untuk modal dan tenaga kerja sekaligus, atas permintaan pemilik project.
LAJU_INPUT_TINGGI <- 8.0
potongan_tanpa_intervensi <- target %>%
  mutate(
    skenario = "1. Tanpa intervensi",
    b1 = b1_drs, b2 = b2_drs,
    kontrib_modal = b1_drs * gK0,
    kontrib_tk    = b2_drs * gL0,
    kontrib_tfp   = tfp0_drs,
    # gY_target tetap dibawa untuk menggambar garis sasaran, tapi totalnya bertahan
    # di gY basis: tanpa intervensi tidak ada komponen yang bergerak.
    total = gY0
  )

# Skenario 2 dan 3 memakai jangkar (b): gK dan gL ditahan di basis, seluruh tambahan
# pertumbuhan ditumpuk ke TFP, sehingga totalnya persis menyentuh sasaran.
potongan_drs <- sken23 %>%
  filter(skenario == "2. RTS tetap DRS") %>%
  transmute(
    Year, gY_target, skenario,
    b1 = b1_drs, b2 = b2_drs,
    kontrib_modal = b1_drs * gK0,
    kontrib_tk    = b2_drs * gL0,
    kontrib_tfp   = tfp_perlu,
    total = gY_target
  )

potongan_crs <- sken23 %>%
  filter(skenario == "3. RTS penuh CRS") %>%
  transmute(
    Year, gY_target, skenario,
    b1 = b1_crs, b2 = b2_crs,
    kontrib_modal = b1_crs * gK0,
    kontrib_tk    = b2_crs * gL0,
    kontrib_tfp   = tfp_perlu,
    total = gY_target
  )

# Skenario 4: elastisitas dan TFP persis seperti basis, hanya laju inputnya yang
# dinaikkan. Totalnya karena itu tidak dipatok sasaran - ia hasil hitungan, dan
# justru itu yang ingin dibaca: cukup atau tidak.
potongan_input8 <- target %>%
  mutate(
    skenario = "4. Modal dan TK tumbuh 8%",
    b1 = b1_drs, b2 = b2_drs,
    kontrib_modal = b1_drs * LAJU_INPUT_TINGGI,
    kontrib_tk    = b2_drs * LAJU_INPUT_TINGGI,
    kontrib_tfp   = tfp0_drs,
    total = b1_drs * LAJU_INPUT_TINGGI + b2_drs * LAJU_INPUT_TINGGI + tfp0_drs
  )

strategi_stacked <- bind_rows(potongan_tanpa_intervensi, potongan_drs,
                              potongan_crs, potongan_input8) %>%
  mutate(
    pangsa_modal = 100 * kontrib_modal / total,
    pangsa_tk    = 100 * kontrib_tk / total,
    pangsa_tfp   = 100 * kontrib_tfp / total
  ) %>%
  select(Year, gY_target, skenario, b1, b2,
         kontrib_modal, kontrib_tk, kontrib_tfp, total,
         pangsa_modal, pangsa_tk, pangsa_tfp) %>%
  arrange(skenario, Year)

baris_sken1   <- strategi_stacked %>% filter(skenario == "1. Tanpa intervensi")
baris_sasaran <- strategi_stacked %>%
  filter(skenario %in% c("2. RTS tetap DRS", "3. RTS penuh CRS"))
baris_input8  <- strategi_stacked %>% filter(skenario == "4. Modal dan TK tumbuh 8%")

# ---- ASSERTION TABEL BATANG BERTUMPUK ---------------------------------------
# (1) Bentuk tabel: 4 skenario x 4 tahun, tidak boleh ada baris yang menggandakan diri.
stopifnot(nrow(strategi_stacked) == 16)

# (2) Identitas dekomposisi tertutup: batang bertumpuk tidak boleh menyisakan celah.
stopifnot(all(abs(strategi_stacked$kontrib_modal + strategi_stacked$kontrib_tk +
                    strategi_stacked$kontrib_tfp - strategi_stacked$total) < 1e-10))

# (3) gK dan gL ditahan di laju basis, jadi dua komponen input tidak bergerak antar tahun.
cek_konstan <- strategi_stacked %>%
  group_by(skenario) %>%
  summarise(rentang_modal = max(kontrib_modal) - min(kontrib_modal),
            rentang_tk    = max(kontrib_tk) - min(kontrib_tk), .groups = "drop")
stopifnot(all(cek_konstan$rentang_modal < 1e-12), all(cek_konstan$rentang_tk < 1e-12))

# (4) Skenario 1 mandek di laju basis, bukan mengikuti sasaran.
stopifnot(all(abs(baris_sken1$total - gY0) < 1e-10))

# (5) Skenario 2 dan 3 persis menyentuh sasaran tahunannya.
stopifnot(all(abs(baris_sasaran$total - baris_sasaran$gY_target) < 1e-10))

# (6) Pangsa komponen habis di 100 persen, supaya proporsi batang bisa dipercaya.
stopifnot(all(abs(strategi_stacked$pangsa_modal + strategi_stacked$pangsa_tk +
                    strategi_stacked$pangsa_tfp - 100) < 1e-9))

# (7) Skenario 4 memakai laju input yang dipatok, dan TFP-nya persis TFP basis.
stopifnot(
  all(abs(baris_input8$kontrib_modal / baris_input8$b1 - LAJU_INPUT_TINGGI) < 1e-10),
  all(abs(baris_input8$kontrib_tk / baris_input8$b2 - LAJU_INPUT_TINGGI) < 1e-10),
  all(abs(baris_input8$kontrib_tfp - tfp0_drs) < 1e-10)
)

cat("\n=============== Strategi RTS dan TFP: empat skenario ===============\n")
print(as.data.frame(strategi_stacked %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

cat(sprintf(
  "\nPangsa komponen pada basis %d-%d: modal %.1f%%, tenaga kerja %.1f%%, TFP %.1f%%.\n",
  TAHUN_BASIS_DARI, TAHUN_BASIS_SAMPAI,
  baris_sken1$pangsa_modal[1], baris_sken1$pangsa_tk[1], baris_sken1$pangsa_tfp[1]))

cat(sprintf(
  "Modal dan TK tumbuh %.0f%%/thn dengan TFP dan RTS di basis: gY %.2f%%, kurang %.2f poin dari 8%%.\n",
  LAJU_INPUT_TINGGI, baris_input8$total[1], 8.00 - baris_input8$total[1]))

# ==============================================================================
# 3. Frontier: kombinasi gK dan TFP yang mencapai target
# ==============================================================================
# Untuk tiap gK, berapa kontribusi TFP yang masih harus disediakan.
#   TFP_perlu(gK) = gY_target - b1*gK - b2*gL0
grid_gK <- seq(0, 16, by = 0.25)
frontier <- expand_grid(
  gK = grid_gK,
  target %>% filter(Year == 2029)          # frontier digambar untuk sasaran 8%
) %>%
  mutate(
    `2. RTS tetap DRS` = gY_target - b1_drs * gK - b2_drs * gL0,
    `3. RTS penuh CRS` = gY_target - b1_crs * gK - b2_crs * gL0
  ) %>%
  pivot_longer(starts_with(c("2.", "3.")), names_to = "skenario", values_to = "tfp_perlu")

cat("\n=============== Frontier sasaran 8% (petikan) ===============\n")
print(as.data.frame(
  frontier %>% filter(gK %in% c(0, 4.5, 8, 12, 16)) %>%
    select(skenario, gK, tfp_perlu) %>%
    pivot_wider(names_from = skenario, values_from = tfp_perlu) %>%
    mutate(across(-gK, ~round(.x, 2)))), row.names = FALSE)

# Titik historis, untuk ditandai di grafik.
historis <- tibble(
  skenario = c("2. RTS tetap DRS", "3. RTS penuh CRS"),
  gK = gK0, tfp = c(tfp0_drs, tfp0_crs),
  label = "basis 2022-2024"
)

# ==============================================================================
# 4. Rasio investasi terhadap PDRB pada jalur target
# ==============================================================================
# Uji kewajaran. Kalau kebutuhan gK menuntut rasio investasi menembus puncak
# historis Indonesia (sekitar 33% sebelum krisis 1998), jalurnya tidak kredibel.
tk_cols <- grep("_TenagaKerja$", names(read.xlsx(data_file, sheet = "Sheet1", rows = 1)),
                value = TRUE)
lvl <- read.xlsx(data_file, sheet = "Sheet1") %>%
  filter(Year == 2024) %>%
  summarise(K = sum(.data[[kol_modal]]), Y = sum(.data[[kol_output]]))
rasio_2024 <- lvl$K / lvl$Y
cat(sprintf("\nRasio PMTB %s terhadap PDRB %s, 2024: %.1f%%\n",
            if (BASIS_ADHB) "harga berlaku" else "riil",
            if (BASIS_ADHB) "harga berlaku" else "riil", 100 * rasio_2024))

# 2025 tidak punya data, jadi diasumsikan mengikuti laju basis. Ini asumsi
# jembatan, bukan proyeksi - dicatat terbuka.
jalur_rasio <- function(nama, gK_jalur) {
  tahun <- 2025:2029
  gY_jalur <- c(gY0, target$gY_target)          # 2025 basis, 2026-2029 target
  gK_vec   <- c(gK0, rep(gK_jalur, 4))
  K <- lvl$K; Y <- lvl$Y; out <- numeric(length(tahun))
  for (i in seq_along(tahun)) {
    K <- K * exp(gK_vec[i] / 100)
    Y <- Y * exp(gY_jalur[i] / 100)
    out[i] <- K / Y
  }
  tibble(skenario = nama, Year = tahun, rasio_investasi = 100 * out)
}
gK_perlu_drs <- sken23$gK_perlu[sken23$skenario == "2. RTS tetap DRS" & sken23$Year == 2029]
gK_perlu_crs <- sken23$gK_perlu[sken23$skenario == "3. RTS penuh CRS" & sken23$Year == 2029]

rasio_jalur <- bind_rows(
  jalur_rasio("1. Tanpa intervensi", gK0),
  jalur_rasio("2. RTS tetap DRS",    gK_perlu_drs),
  jalur_rasio("3. RTS penuh CRS",    gK_perlu_crs)
)
cat("\nRasio investasi terhadap PDRB di sepanjang jalur (%):\n")
print(as.data.frame(
  rasio_jalur %>% pivot_wider(names_from = skenario, values_from = rasio_investasi) %>%
    mutate(across(-Year, ~round(.x, 1)))), row.names = FALSE)

PUNCAK_HISTORIS <- 33.0
rasio_2029 <- rasio_jalur %>% filter(Year == 2029)
cat(sprintf("\nPuncak historis Indonesia sekitar %.0f%% (sebelum krisis 1998).\n", PUNCAK_HISTORIS))
for (i in seq_len(nrow(rasio_2029))) {
  cat(sprintf("  %s: %.1f%% pada 2029 -> %s\n",
              rasio_2029$skenario[i], rasio_2029$rasio_investasi[i],
              ifelse(rasio_2029$rasio_investasi[i] > PUNCAK_HISTORIS,
                     "MELAMPAUI puncak historis", "masih di bawah puncak historis")))
}

# ==============================================================================
# 5. Ringkasan
# ==============================================================================
ringkas <- tibble(
  butir = c(
    "Pertumbuhan basis 2022-2024",
    "Sasaran 2029",
    "Gap yang harus ditutup",
    "Kebutuhan gK bila TFP tetap di basis - DRS",
    "Kebutuhan gK bila TFP tetap di basis - CRS",
    "Kebutuhan kontribusi TFP bila gK tetap - DRS",
    "Kebutuhan kontribusi TFP bila gK tetap - CRS",
    "Lonjakan TFP yang disyaratkan (kedua skenario)"
  ),
  nilai = c(gY0, 8.00, 8.00 - gY0, gK_perlu_drs, gK_perlu_crs,
            tfp0_drs + (8.00 - gY0), tfp0_crs + (8.00 - gY0), 8.00 - gY0),
  satuan = c(rep("%/thn", 2), "poin persen", rep("%/thn", 2), rep("poin persen", 3))
)
cat("\n=============== Ringkasan ===============\n")
print(as.data.frame(ringkas %>% mutate(nilai = round(nilai, 2))), row.names = FALSE)

CATATAN <- tibble(butir = c(
  "Basis laju pertumbuhan memakai rata-rata 2022-2024 atas keputusan pemilik project.",
  "Jendela tiga tahun melanggar Batasan D4 di kerangka.md; pencabutannya belum diputuskan.",
  "Elastisitas tetap dari panel penuh 2017-2024, hanya laju pertumbuhan yang dipersempit.",
  sprintf("Modal diukur arus PMTB %s (%s), bukan stok. Simulasi tidak menggulirkan stok PIM.",
          if (BASIS_ADHB) "harga berlaku" else "riil", kol_modal),
  "Skenario 3 menaikkan b1+b2 ke 1,0 secara proporsional dengan pangsa modal ditahan tetap.",
  "Lonjakan TFP yang disyaratkan sama di kedua skenario; hanya kebutuhan investasi yang beda.",
  "Kenaikan skala hasil bukan instrumen kebijakan langsung. Sebagian RTS rendah adalah",
  "  artefak atenuasi galat ukur, sehingga rentang DRS-CRS lebih tepat dibaca sebagai pita",
  "  ketidakpastian pengukuran atas kebutuhan investasi - lihat Batasan C5 di kerangka.md.",
  "Tahun 2025 tidak punya data; jalur rasio investasi mengasumsikan 2025 mengikuti laju basis.",
  "TFP di sini residual Solow, memuat galat ukur, suku skala, dan pendalaman modal manusia."
))

# ==============================================================================
# 6. Tulis keluaran
# ==============================================================================
write.xlsx(
  list(ringkasan       = ringkas,
       asumsi          = tibble(
         parameter = c("b1_drs", "b2_drs", "rts_drs", "share_K", "b1_crs", "b2_crs", "rts_crs",
                       "gY_basis", "gK_basis", "gL_basis", "tfp_basis_drs", "tfp_basis_crs",
                       "jendela_basis", "rasio_investasi_2024"),
         nilai = c(b1_drs, b2_drs, S_drs, share_K, b1_crs, b2_crs, S_crs,
                   gY0, gK0, gL0, tfp0_drs, tfp0_crs,
                   NA, 100 * rasio_2024),
         keterangan = c(rep("", 12),
                        sprintf("%d-%d", TAHUN_BASIS_DARI, TAHUN_BASIS_SAMPAI), "persen")),
       skenario1_tanpa_intervensi = sken1,
       skenario23_jangkar = sken23,
       strategi_stacked = strategi_stacked,
       frontier_2029   = frontier,
       titik_historis  = historis,
       rasio_investasi = rasio_jalur,
       catatan         = CATATAN),
  file = file.path(out_dir, "Simulasi Trajektori 2026-2029.xlsx"),
  overwrite = TRUE, colWidths = "auto"
)

cat(sprintf("\n=============== SELESAI ===============\nKeluaran: %s\n",
            file.path(out_dir, "Simulasi Trajektori 2026-2029.xlsx")))
