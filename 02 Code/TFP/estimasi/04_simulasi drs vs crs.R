# ==============================================================================
# Simulasi DRS vs CRS - komparatif-statik deterministik atas identitas dekomposisi
#
# BUKAN Monte-Carlo, tidak ada penarikan acak. Ini akuntansi pertumbuhan
# deterministik: identitas g(Y) = b1*g(K) + b2*g(L) + sisa dievaluasi ulang saat
# jumlah elastisitas (skala hasil) digeser dari 0,591 (DRS, basis UTAMA) ke 1,0
# (CRS). Tujuannya menunjukkan persis ke mana suku skala (1-b1-b2) berpindah:
# antara kontribusi modal, kontribusi tenaga kerja, dan sisa (residual PMTB).
#
# Input : 03 Output/parameter_terpilih.rds, 03 Output/Dekomposisi Nasional.xlsx
# Output: 03 Output/Simulasi DRS vs CRS.xlsx (3 sheet), Simulasi DRS vs CRS.png
#
# Tiga blok:
#   (1) Rekonsiliasi kontribusi - CRS vs DRS untuk pertumbuhan input teramati.
#   (2) Sweep skala hasil - jumlah elastisitas disapu kontinu 0,591 -> 1,0.
#   (3) Kontrafaktual maju - TFP yang disyaratkan untuk mencapai output sasaran.
# ==============================================================================

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Sakelar basis harga modal - lihat penjelasan lengkap di 01_estimasi tfp.R.
# Wajib sama dengan yang dipakai skrip 01 dan 02, karena skrip ini membaca
# keluaran keduanya.
BASIS_MODAL <- Sys.getenv("BASIS_MODAL", unset = "riil")
stopifnot(BASIS_MODAL %in% c("riil", "nominal", "adhb"))
BASIS_ADHB <- BASIS_MODAL == "adhb"

out_dir  <- switch(BASIS_MODAL,
                   riil    = "01 Data/TFP/output/modal_riil",
                   nominal = "01 Data/TFP/output/nominal",
                   adhb    = "01 Data/TFP/output/adhb")
par_file <- file.path(out_dir, "parameter_terpilih.rds")
dek_file <- file.path(out_dir, "Dekomposisi Nasional.xlsx")
stopifnot(file.exists(par_file), file.exists(dek_file))
par <- readRDS(par_file)
cat(sprintf("Basis harga modal: %s | keluaran: %s\n", BASIS_MODAL, out_dir))

# -- Elastisitas -------------------------------------------------------------
# DRS (basis UTAMA): two-way FE tak-terestriksi apa adanya.
b1_drs <- unname(par$b1_un); b2_drs <- unname(par$b2_un)
S_drs  <- b1_drs + b2_drs   # nominal 0,591 | riil 0,549 - jangan ditulis tangan

# Label skala hasil dirakit dari parameter, bukan diketik, supaya teks di log dan
# di grafik ikut berubah saat basis harga modal diganti.
fmt_S   <- function(x) formatC(x, format = "f", digits = 3, decimal.mark = ",")
lab_drs <- sprintf("DRS (%s)", fmt_S(S_drs))
# CRS (pembanding): bentuk per-pekerja, b2 = 1 - b1.
b1_crs <- unname(par$b1_crs); b2_crs <- 1 - b1_crs
# Pangsa modal atas jumlah elastisitas, dipertahankan tetap sepanjang sweep.
share_K <- b1_drs / S_drs                          # ~0,677

# -- Pertumbuhan input teramati 2018-2024 (dari seri yang sudah diagregasi) ---
nas <- read.xlsx(dek_file, sheet = "seri_nasional")
g   <- nas %>% filter(Year >= 2018, Year <= 2024) %>%
  summarise(gY = mean(g_Y), gK = mean(g_K), gL = mean(g_L))
gY <- g$gY; gK <- g$gK; gL <- g$gL

pul <- read.xlsx(dek_file, sheet = "seri_pulau")
g_pul <- pul %>% filter(Year >= 2018, Year <= 2024) %>%
  group_by(Pulau) %>%
  summarise(gY = mean(g_Y), gK = mean(g_K), gL = mean(g_L), .groups = "drop")

cat("=============== Simulasi DRS vs CRS ===============\n")
cat(sprintf("DRS: b1=%.4f b2=%.4f (jumlah %.4f) | CRS: b1=%.4f b2=%.4f | pangsa modal %.4f\n",
            b1_drs, b2_drs, S_drs, b1_crs, b2_crs, share_K))
cat(sprintf("Input teramati 2018-2024: gY=%.2f gK=%.2f gL=%.2f\n", gY, gK, gL))

# ==============================================================================
# BLOK 1. Rekonsiliasi kontribusi - CRS vs DRS
#
# Fungsi dekomposisi sederhana: kontribusi = elastisitas x pertumbuhan input,
# sisa = residual. Diterapkan ke nasional dan tiap pulau dengan pertumbuhan input
# masing-masing tetapi elastisitas nasional yang sama.
# ==============================================================================
dekom <- function(gY, gK, gL, b1, b2) {
  kK <- b1 * gK; kL <- b2 * gL
  tibble(kK = kK, kL = kL, sisa = gY - kK - kL)
}

reko_baris <- function(nama, gY, gK, gL) {
  d_crs <- dekom(gY, gK, gL, b1_crs, b2_crs)
  d_drs <- dekom(gY, gK, gL, b1_drs, b2_drs)
  # Suku skala murni: bagian pertumbuhan input berbobot yang "hilang" karena
  # jumlah elastisitas < 1. Inilah yang berpindah ke sisa saat CRS dilepas.
  g_input_w  <- share_K * gK + (1 - share_K) * gL
  suku_skala <- (1 - S_drs) * g_input_w
  tibble(
    wilayah = nama, gY = gY, gK = gK, gL = gL,
    kK_crs = d_crs$kK, kL_crs = d_crs$kL, sisa_crs = d_crs$sisa,
    kK_drs = d_drs$kK, kL_drs = d_drs$kL, sisa_drs = d_drs$sisa,
    pangsaK_crs = 100 * d_crs$kK / gY, pangsaK_drs = 100 * d_drs$kK / gY,
    suku_skala = suku_skala,
    sisa_gap = d_drs$sisa - d_crs$sisa   # kenaikan sisa saat pindah CRS -> DRS
  )
}

rekonsiliasi <- bind_rows(
  reko_baris("Nasional", gY, gK, gL),
  purrr::pmap_dfr(list(g_pul$Pulau, g_pul$gY, g_pul$gK, g_pul$gL), reko_baris)
)

cat("\n-- Blok 1: rekonsiliasi kontribusi (poin persen) --\n")
print(as.data.frame(rekonsiliasi %>%
                      select(wilayah, gY, kK_crs, sisa_crs, kK_drs, sisa_drs,
                             pangsaK_crs, pangsaK_drs, suku_skala, sisa_gap) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)
cat(sprintf("\nNasional: pangsa modal %.1f%% (CRS) -> %.1f%% (DRS); sisa %.2f -> %.2f (selisih %.2f poin).\n",
            rekonsiliasi$pangsaK_crs[1], rekonsiliasi$pangsaK_drs[1],
            rekonsiliasi$sisa_crs[1], rekonsiliasi$sisa_drs[1], rekonsiliasi$sisa_gap[1]))

# ==============================================================================
# BLOK 2. Sweep skala hasil
#
# Jumlah elastisitas S disapu dari 0,591 (DRS) ke 1,0 (CRS), pangsa modal atas
# jumlah itu ditahan tetap = share_K. Pada tiap S: b1 = share_K*S, b2 = (1-share_K)*S.
# Ditelusuri bagaimana kontribusi modal, tenaga kerja, dan sisa merespons.
# ==============================================================================
sweep <- tibble(S = sort(unique(c(seq(S_drs, 1.0, by = 0.005), 1.0)))) %>%
  mutate(b1 = share_K * S, b2 = (1 - share_K) * S,
         kontrib_K = b1 * gK, kontrib_L = b2 * gL,
         sisa = gY - kontrib_K - kontrib_L,
         pangsaK = 100 * kontrib_K / gY,
         pangsa_sisa = 100 * sisa / gY)

cat("\n-- Blok 2: sweep skala hasil, titik ujung (amplop) --\n")
print(as.data.frame(sweep %>% slice(c(1, n())) %>%
                      mutate(label = c(lab_drs, "CRS (1,00)")) %>%
                      select(label, S, b1, b2, kontrib_K, kontrib_L, sisa, pangsaK) %>%
                      mutate(across(where(is.numeric), ~round(.x, 3)))), row.names = FALSE)

# ==============================================================================
# BLOK 3. Kontrafaktual maju
#
# Diberi skenario pertumbuhan modal/tenaga kerja (termasuk laju yang konsisten
# dengan kerangka 8-4-2-2 resmi: 2 poin modal, 4 poin tenaga kerja) dan dihitung:
#   - proyeksi output bila residual = 0 (pertumbuhan murni dari akumulasi input)
#   - residual yang DISYARATKAN untuk mencapai output sasaran 8%
# di bawah elastisitas CRS vs DRS. Karena elastisitas DRS menjumlah lebih kecil,
# akumulasi input menjelaskan lebih sedikit, sehingga TFP yang disyaratkan lebih besar.
# ==============================================================================
gY_sasaran <- 8.0

# Alokasi resmi 8-4-2-2: 4 poin tenaga kerja + 2 poin modal + 2 poin TFP.
# Di bawah alfa=1/3, 2 poin modal butuh gK = 6%; 4 poin TK butuh gL = 6%.
# (Kode lama memakai 4 poin modal -> gK=12%; dikoreksi 2026-09-05.)
gK_8422 <- 2 / (1/3)   # = 6%
gL_8422 <- 4 / (2/3)   # = 6%

skenario_gK <- tibble(
  skenario = c("Input teramati",
               "Modal 8-4-2-2 (2 poin, alfa=1/3)",
               "Tenaga kerja 8-4-2-2 (4 poin, 1-alfa=2/3)"),
  gK = c(gK, gK_8422, gK),
  gL = c(gL, gL, gL_8422)
)

kontrafaktual <- skenario_gK %>%
  mutate(
    proj_gY_crs = b1_crs * gK + b2_crs * gL,     # output bila TFP = 0
    proj_gY_drs = b1_drs * gK + b2_drs * gL,
    req_tfp_crs = gY_sasaran - proj_gY_crs,      # TFP disyaratkan untuk output 8%
    req_tfp_drs = gY_sasaran - proj_gY_drs,
    selisih_req = req_tfp_drs - req_tfp_crs
  )

cat("\n-- Blok 3: kontrafaktual maju (output sasaran = 8%) --\n")
print(as.data.frame(kontrafaktual %>%
                      mutate(across(where(is.numeric), ~round(.x, 2)))), row.names = FALSE)

# ==============================================================================
# Ekspor xlsx + gambar
# ==============================================================================
write.xlsx(list(rekonsiliasi = rekonsiliasi,
                sweep = sweep,
                kontrafaktual = kontrafaktual),
           file.path(out_dir, "Simulasi DRS vs CRS.xlsx"))

# -- Gambar: sweep skala hasil (minimalis) -----------------------------------
mega_colors <- c("Modal"              = "#0E2440",
                 "Tenaga kerja"       = "#797F8C",
                 "TFP"                = "#5DD0E6")
aksen <- "#D9042B"
lab_id <- function(d = 1) function(x) formatC(x, format = "f", digits = d, decimal.mark = ",")
fmt_id <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")

sweep_long <- sweep %>%
  transmute(S,
            `Modal`              = kontrib_K,
            `Tenaga kerja`       = kontrib_L,
            TFP = sisa) %>%
  pivot_longer(-S, names_to = "komponen", values_to = "nilai") %>%
  mutate(komponen = factor(komponen, levels = names(mega_colors)))

p <- ggplot(sweep_long, aes(x = S, y = nilai, color = komponen)) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_vline(xintercept = S_drs, linetype = "dashed", color = aksen, linewidth = 0.45) +
  geom_vline(xintercept = 1.0, linetype = "dashed", color = "grey55", linewidth = 0.45) +
  geom_line(linewidth = 0.9) +
  annotate("text", x = S_drs, y = 3.9, label = sprintf("DRS (basis, %s)", fmt_S(S_drs)),
           color = aksen, size = 2.7, hjust = -0.05) +
  annotate("text", x = 1.0, y = 3.9, label = "CRS (1,00)",
           color = "grey40", size = 2.7, hjust = 1.05) +
  scale_color_manual(values = mega_colors,
                     labels = c("Modal", "Tenaga kerja", "Residual PMTB")) +
  scale_x_continuous(labels = lab_id(2), breaks = seq(0.6, 1.0, 0.1)) +
  scale_y_continuous(labels = lab_id(1), breaks = seq(-1, 4, 1)) +
  labs(
    title    = "Perpindahan kontribusi saat skala hasil disapu dari DRS ke CRS",
    subtitle = paste0("Identitas dekomposisi dievaluasi ulang untuk jumlah elastisitas b1+b2 dari ",
                      fmt_S(S_drs), " (DRS) ke 1,0 (CRS),\n",
                      "pangsa modal atas jumlah itu ditahan tetap. Input teramati 2018-2024: gY=",
                      fmt_id(gY, 2), "; gK=", fmt_id(gK, 2), "; gL=", fmt_id(gL, 2), " (poin persen)."),
    x        = "Skala hasil (jumlah elastisitas b1 + b2)",
    y        = "Kontribusi terhadap pertumbuhan (poin persen)",
    caption  = paste0(
      "Komparatif-statik deterministik, bukan simulasi acak. Saat skala dipaksa naik ke 1,0, suku skala berpindah dari sisa\n",
      "ke kontribusi modal dan tenaga kerja: sisa turun sementara kontribusi faktor naik. Sumber: BPS & BKPM, diolah.")
  ) +
  # Ukuran huruf disamakan dengan dua belas gambar lain di folder yang sama.
  # Gambar-gambar ini ditempel ke Excel pada lebar sekitar 16 cm; huruf lama
  # (base_size 10, caption 8 pt) tidak terbaca di ukuran itu. Lebar kanvas
  # dikunci 9 inci bersama gambar lain supaya ukuran huruf efektifnya seragam.
  theme_classic(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(size = 12, color = "grey30"),
        plot.caption = element_text(color = "grey50", size = 10.5, hjust = 0,
                                    margin = margin(t = 12)),
        plot.caption.position = "plot", plot.title.position = "plot",
        axis.title = element_text(size = 12),
        axis.text = element_text(size = 11.5),
        legend.text = element_text(size = 11.5),
        panel.grid.major.y = element_line(color = "grey90", linewidth = 0.4),
        legend.position = "bottom", legend.title = element_blank())

ggsave(file.path(out_dir, "Simulasi DRS vs CRS.png"), p,
       width = 9, height = 6, units = "in", dpi = 300, bg = "white")

cat("\n=============== SELESAI ===============\n")
cat("Keluaran:", normalizePath(out_dir), "\n")
