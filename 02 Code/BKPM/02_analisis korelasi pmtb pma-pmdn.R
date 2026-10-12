
# SCRIPT OVERVIEW --------------------------------------
# Subbab 6.3 poin 2: kuantifikasi korelasi PMTB (BPS, GFCF) vs realisasi PMA/PMDN (BKPM).
# Pendekatan (revisi v4): SELEKSI MODEL per subgroup berbasis AIC/BIC dengan kandidat luas.
#   - Semua model pakai observasi tingkat provinsi (34 provinsi x tahun 2017-2025).
#   - 7 kandidat bentuk fungsional per subgroup x bentuk variabel (log & growth):
#     linear, kuadratik, kubik, spline df3, spline df4, piecewise (breakpoint dicari + dipenalti),
#     plus resiprokal (khusus log) / asimetris-kink-di-nol (khusus growth).
#   - Perbedaan bentuk terpilih antar-subgroup = insight utama (growth cenderung linear,
#     log cenderung non-linear; pre vs post-covid beda bentuk).
#   - R2 yang dilaporkan = WITHIN-R2 = 1 - RSS_model/RSS_FE-only. Ini TIDAK memuat kontribusi
#     dummy FE (kalau pakai summary(lm)$r.squared, angkanya ~0,99 karena didongkrak dummy).
#   - AIC/BIC hanya dibandingkan DI DALAM satu bentuk variabel (response beda -> tak sebanding).
#   - Rasio (PMA+PMDN)/PMTB dari waktu ke waktu (brief minta eksplisit) -> reproduksi 15,8->26,8%.
# Catatan unit: PMA_1 & PMDN_1 keduanya JUTA IDR (handover keliru menulis PMA=USD). Setelah /1e3
#   keduanya jadi miliar IDR, sama unit dg PMTB (4_ADHB) -> penjumlahan & rasio valid.


# 1) Persiapan script ----
rm(list = ls())

library(openxlsx)
library(dplyr)
library(tidyverse)
library(splines)
library(plm)
library(sandwich)
library(lmtest)
library(modelsummary)
library(flextable)
library(officer)

pdrb_inv <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx", sheet = "Database")
col_names <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx", sheet = "column_names")
longnames_klas <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx", sheet = "longnames")
prov_nama <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx", sheet = "prov_name")

# 2) Data cleaning ---- (direplikasi dari 01_visualisasi pdrb.laporan pendahuluan.R)
pdrb_inv <- pdrb_inv %>% dplyr::select(., c(Code_Prov,Year,A_ADHB:RSTU_ADHB,PMA_1,PMDN_1,`4_ADHB`))
pdrb_inv <- pdrb_inv %>% mutate(across(c(A_ADHB:RSTU_ADHB), as.numeric),
                                across(c(PMA_1,PMDN_1,`4_ADHB`), ~ as.numeric(gsub(",", ".", .x))))
pdrb_inv <- pdrb_inv %>% mutate(PMA_1 = PMA_1/1e3, PMDN_1 = PMDN_1/1e3)  # juta -> miliar IDR

pdrb_inv.34 <- pdrb_inv %>% group_by(Code_Prov, Year) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop")

pdrb_inv.34_wide <- pdrb_inv.34 %>%
  pivot_longer(cols = -c(Code_Prov, Year), names_to = "kodename", values_to = "Nilai") %>%
  pivot_wider(names_from = Year, values_from = Nilai) %>% left_join(., col_names)

megasectors <- pdrb_inv.34_wide %>% dplyr::select(., c(Code_Prov,sect_klas_megasektor,`2017`:`2025`)) %>%
  group_by(Code_Prov,sect_klas_megasektor) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  filter(!is.na(sect_klas_megasektor)) %>%
  pivot_longer(cols = `2017`:`2025`, names_to = "Year", values_to = "Nilai") %>%
  pivot_wider(names_from = sect_klas_megasektor, values_from = Nilai)

klas_alt <- pdrb_inv.34_wide %>% dplyr::select(., c(Code_Prov,sect_klas_alt,`2017`:`2025`)) %>%
  group_by(Code_Prov,sect_klas_alt) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  filter(!is.na(sect_klas_alt)) %>%
  pivot_longer(cols = `2017`:`2025`, names_to = "Year", values_to = "Nilai") %>%
  pivot_wider(names_from = sect_klas_alt, values_from = Nilai)

pdrb_inv.34 <- pdrb_inv.34_wide %>% dplyr::select(., -c(kodename,sect_klas_megasektor,sect_klas_alt)) %>%
  pivot_longer(cols = `2017`:`2025`, names_to = "Year", values_to = "Nilai") %>%
  pivot_wider(names_from = sect_name, values_from = Nilai)

pdrb_inv.cleaned <- list(pdrb_inv.34, megasectors, klas_alt) %>%
  reduce(left_join, by = c("Code_Prov", "Year")) %>%
  mutate(total_pdrb = rowSums(across(c(Primer,Sekunder,Tersier,Kuarterner)),na.rm = T),
         pma_pmdn = rowSums(across(c(PMA,PMDN)),na.rm = T)) %>%
  pivot_longer(cols = -c(Code_Prov, Year), names_to = "kodename", values_to = "Nilai") %>%
  pivot_wider(names_from = Year, values_from = Nilai) %>%
  left_join(., longnames_klas) %>% left_join(., prov_nama) %>%
  mutate(kodename = case_when(kodename == "pma_pmdn" ~ "PMA + PMDN",
                              kodename == "total_pdrb" ~ "PDRB Total", TRUE ~ kodename))


# 3) Panel tingkat provinsi ----
province_panel <- pdrb_inv.cleaned %>%
  filter(kodename %in% c("PMTB", "PMA + PMDN")) %>%
  dplyr::select(Code_Prov, Prov_nama, Pulau, kodename, `2017`:`2025`) %>%
  pivot_longer(cols = `2017`:`2025`, names_to = "Year", values_to = "Nilai") %>%
  mutate(Year = as.integer(Year)) %>%
  pivot_wider(names_from = kodename, values_from = Nilai) %>%
  rename(x = `PMA + PMDN`, y = PMTB)

stopifnot("Bali-Nusra" %in% unique(province_panel$Pulau),
          !("Bali-Nusa Tenggara" %in% unique(province_panel$Pulau)),
          n_distinct(province_panel$Prov_nama) == 34)

province_panel <- province_panel %>%
  arrange(Prov_nama, Year) %>% group_by(Prov_nama) %>%
  # dplyr::lag eksplisit: library(plm) memask lag() dan bikin growth jadi 0
  mutate(gx = x/dplyr::lag(x) - 1, gy = y/dplyr::lag(y) - 1, lx = log(x), ly = log(y)) %>%
  ungroup() %>%
  mutate(post = ifelse(Year >= 2022, 1L, 0L),
         covid_period = case_when(Year %in% 2017:2019 ~ "pre-covid",
                                  Year %in% 2022:2025 ~ "post-covid", TRUE ~ NA_character_))

pulau_colors <- c("Bali-Nusra"="#2C3E50","Jawa"="#C0392B","Kalimantan"="#27AE60",
                  "Maluku-Papua"="#8E44AD","Sulawesi"="#D35400","Sumatera"="#2980B9")
urutan_pulau <- c("Sumatera","Jawa","Bali-Nusra","Kalimantan","Sulawesi","Maluku-Papua")
out_dir <- "01 Data/BKPM/output/Subbab 6.3 - Korelasi PMTB-PMA-PMDN"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)


# 4) Rasio (PMA+PMDN)/PMTB dari waktu ke waktu ----
share_nasional <- province_panel %>% group_by(Year) %>%
  summarise(inv = sum(x), pmtb = sum(y), .groups = "drop") %>%
  mutate(Wilayah = "Nasional", share_pct = 100*inv/pmtb)
share_pulau_year <- province_panel %>% group_by(Pulau, Year) %>%
  summarise(inv = sum(x), pmtb = sum(y), .groups = "drop") %>%
  mutate(share_pct = 100*inv/pmtb) %>% rename(Wilayah = Pulau)
share_all <- bind_rows(share_nasional %>% dplyr::select(Wilayah, Year, share_pct),
                       share_pulau_year %>% dplyr::select(Wilayah, Year, share_pct))
share_pulau_avg <- province_panel %>% group_by(Pulau, Year) %>%
  summarise(inv = sum(x), pmtb = sum(y), .groups = "drop") %>%
  group_by(Pulau) %>% summarise(share_pct = round(100*sum(inv)/sum(pmtb), 2), .groups = "drop") %>%
  arrange(desc(share_pct))
write.csv(share_all %>% mutate(share_pct = round(share_pct, 2)) %>%
            pivot_wider(names_from = Year, values_from = share_pct),
          file.path(out_dir, "Rasio BKPM terhadap PMTB.csv"), row.names = FALSE)


# 5) Engine seleksi model ----
MIN_N  <- 12   # minimal observasi per sel
MIN_DF <- 5    # minimal residual df
rss <- function(m) sum(resid(m)^2)

# fit satu spesifikasi; within_R2 = 1 - RSS_model/RSS_FE-only (kontribusi dummy FE dikeluarkan)
fit_one <- function(yv, rhs, fe, d, extra_par = 0) {
  m <- tryCatch(lm(as.formula(paste0(yv, " ~ ", rhs, fe)), data = d), error = function(e) NULL)
  if (is.null(m) || !is.finite(AIC(m)) || m$df.residual < MIN_DF) return(NULL)
  b <- tryCatch(lm(as.formula(paste0(yv, " ~ 1", fe)), data = d), error = function(e) NULL)
  if (is.null(b) || rss(b) <= 0) return(NULL)
  n <- nobs(m)
  list(model = m, AIC = AIC(m) + 2*extra_par, BIC = BIC(m) + log(n)*extra_par,
       within_R2 = 1 - rss(m)/rss(b), n = n, knot = NA_real_)
}

# piecewise: cari breakpoint di kuantil 25-75%, penalti +1 parameter
fit_pw <- function(yv, xv, fe, d) {
  xs <- d[[xv]]; best <- NULL
  for (cc in unique(quantile(xs, seq(.25, .75, by = .05), na.rm = TRUE))) {
    d$.k <- pmax(0, xs - cc)
    r <- fit_one(yv, paste0(xv, " + .k"), fe, d, extra_par = 1)
    if (!is.null(r) && (is.null(best) || r$AIC < best$AIC)) { r$knot <- cc; best <- r }
  }
  best
}

fit_family <- function(fam, yv, xv, fe, d) {
  switch(fam,
    linear     = fit_one(yv, xv, fe, d),
    kuadratik  = fit_one(yv, paste0(xv, " + I(", xv, "^2)"), fe, d),
    kubik      = fit_one(yv, paste0("poly(", xv, ",3)"), fe, d),
    spline_df3 = fit_one(yv, paste0("ns(", xv, ",3)"), fe, d),
    spline_df4 = fit_one(yv, paste0("ns(", xv, ",4)"), fe, d),
    piecewise  = fit_pw(yv, xv, fe, d),
    resiprokal = fit_one(yv, paste0(xv, " + I(1/", xv, ")"), fe, d),
    asimetris  = fit_one(yv, paste0(xv, " + pmax(", xv, ",0)"), fe, d),
    NULL)
}

spec_of <- function(form_type) {
  if (form_type == "log") list(yv="ly", xv="lx", fe=" + factor(Code_Prov) + factor(Year)",
                               fams=c("linear","kuadratik","kubik","spline_df3","spline_df4","piecewise","resiprokal"))
  else                    list(yv="gy", xv="gx", fe=" + factor(Year)",
                               fams=c("linear","kuadratik","kubik","spline_df3","spline_df4","piecewise","asimetris"))
}

prep_data <- function(d, s) d[is.finite(d[[s$yv]]) & is.finite(d[[s$xv]]), , drop = FALSE]

run_candidates <- function(d, form_type) {
  s <- spec_of(form_type); dd <- prep_data(d, s)
  if (nrow(dd) < MIN_N) return(NULL)
  fits <- lapply(s$fams, function(f) fit_family(f, s$yv, s$xv, s$fe, dd))
  names(fits) <- s$fams
  fits <- fits[!sapply(fits, is.null)]
  if (!length(fits)) return(NULL)
  list(fits = fits, data = dd, spec = s)
}

tidy_candidates <- function(rc, label, form_type) {
  if (is.null(rc)) return(NULL)
  data.frame(subgroup = label, bentuk = form_type, model = names(rc$fits),
             n = sapply(rc$fits, `[[`, "n"),
             AIC = round(sapply(rc$fits, `[[`, "AIC"), 1),
             BIC = round(sapply(rc$fits, `[[`, "BIC"), 1),
             within_R2 = round(sapply(rc$fits, `[[`, "within_R2"), 3),
             stringsAsFactors = FALSE)
}


# 6) Jalankan seleksi di 21 subgroup x 2 bentuk ----
subgroups <- list("Nasional - Semua" = province_panel,
                  "Nasional - Pre"   = province_panel %>% filter(covid_period == "pre-covid"),
                  "Nasional - Post"  = province_panel %>% filter(covid_period == "post-covid"))
for (pl in urutan_pulau) {
  subgroups[[paste0(pl, " - Semua")]] <- province_panel %>% filter(Pulau == pl)
  subgroups[[paste0(pl, " - Pre")]]   <- province_panel %>% filter(Pulau == pl, covid_period == "pre-covid")
  subgroups[[paste0(pl, " - Post")]]  <- province_panel %>% filter(Pulau == pl, covid_period == "post-covid")
}

cand_all <- list(); sel_rows <- list(); fit_store <- list()
for (nm in names(subgroups)) for (ft in c("log", "growth")) {
  rc <- run_candidates(subgroups[[nm]], ft)
  key <- paste(nm, ft)
  if (is.null(rc)) {
    sel_rows[[key]] <- data.frame(subgroup = nm, bentuk = ft, n = NA_integer_,
      model_AIC = "tak cukup data", model_BIC = "tak cukup data",
      within_R2 = NA_real_, AIC = NA_real_, BIC = NA_real_, d_AIC_vs_linear = NA_real_,
      stringsAsFactors = FALSE)
    next
  }
  tb <- tidy_candidates(rc, nm, ft)
  cand_all[[key]] <- tb
  iA <- which.min(tb$AIC); iB <- which.min(tb$BIC)
  aic_lin <- if ("linear" %in% tb$model) tb$AIC[tb$model == "linear"] else NA_real_
  sel_rows[[key]] <- data.frame(subgroup = nm, bentuk = ft, n = tb$n[1],
    model_AIC = tb$model[iA], model_BIC = tb$model[iB],
    within_R2 = tb$within_R2[iA], AIC = tb$AIC[iA], BIC = tb$BIC[iB],
    d_AIC_vs_linear = round(tb$AIC[iA] - aic_lin, 1), stringsAsFactors = FALSE)
  fit_store[[key]] <- list(rc = rc, best = tb$model[iA])
}
sel <- bind_rows(sel_rows)
cand_tbl <- bind_rows(cand_all)

cat("\n=== SELEKSI MODEL PER SUBGROUP ===\n"); print(as.data.frame(sel))
cat("\n=== POLA MENANG (AIC) ===\n"); print(table(sel$bentuk, sel$model_AIC))
cat("\n=== POLA MENANG (BIC) ===\n"); print(table(sel$bentuk, sel$model_BIC))


# 7) Robustness: leave-one-province-out pada model terpilih (khusus subgroup pulau) ----
loo_rows <- list()
for (key in names(fit_store)) {
  parts <- strsplit(key, " ")[[1]]; ft <- parts[length(parts)]
  nm <- sub(paste0(" ", ft, "$"), "", key)
  if (grepl("^Nasional", nm)) next
  rc <- fit_store[[key]]$rc; fam <- fit_store[[key]]$best; s <- rc$spec
  provs <- unique(rc$data$Code_Prov)
  vals <- sapply(provs, function(cp) {
    r <- fit_family(fam, s$yv, s$xv, s$fe, rc$data[rc$data$Code_Prov != cp, , drop = FALSE])
    if (is.null(r)) NA_real_ else r$within_R2
  })
  if (all(is.na(vals))) next
  loo_rows[[key]] <- data.frame(subgroup = nm, bentuk = ft, model = fam,
    within_R2 = round(sel$within_R2[sel$subgroup == nm & sel$bentuk == ft][1], 3),
    loo_min = round(min(vals, na.rm = TRUE), 3), loo_max = round(max(vals, na.rm = TRUE), 3),
    n_prov = length(provs), stringsAsFactors = FALSE)
}
loo <- bind_rows(loo_rows) %>%
  mutate(rentang = loo_max - loo_min,
         stabilitas = ifelse(rentang > 0.30, "tidak stabil", "cukup stabil"))
cat("\n=== LOO (leave-one-province-out) ===\n"); print(as.data.frame(loo))

sel <- sel %>% left_join(loo %>% dplyr::select(subgroup, bentuk, loo_min, loo_max, stabilitas),
                         by = c("subgroup", "bentuk")) %>%
  mutate(stabilitas = ifelse(grepl("^Nasional", subgroup), "nasional (34 prov)", stabilitas))

write.csv(sel, file.path(out_dir, "Model Selection per Subgroup.csv"), row.names = FALSE)
write.csv(cand_tbl, file.path(out_dir, "Model Selection - Semua Kandidat.csv"), row.names = FALSE)


# 8) R2 ladder (artefak ukuran & tren) + baris model terbaik ----
pdat <- pdata.frame(province_panel, index = c("Code_Prov", "Year"))
m_pool <- lm(ly ~ lx, data = province_panel)
m_prov <- plm(ly ~ lx, data = pdat, model = "within", effect = "individual")
m_two  <- plm(ly ~ lx, data = pdat, model = "within", effect = "twoways")
m_betw <- plm(ly ~ lx, data = pdat, model = "between")
R2_between <- round(as.numeric(summary(m_betw)$r.squared["rsq"]), 3)

best_nas_log <- sel %>% filter(subgroup == "Nasional - Semua", bentuk == "log")
ladder <- tibble(
  spesifikasi = c("Pooled OLS", "+ Province FE", "+ Province & Year FE",
                  paste0("+ FE, model terbaik (", best_nas_log$model_AIC, ")")),
  R2 = round(c(summary(m_pool)$r.squared, as.numeric(summary(m_prov)$r.squared["rsq"]),
               as.numeric(summary(m_two)$r.squared["rsq"]), best_nas_log$within_R2), 3))
cat("\n=== R2 ladder ===\n"); print(as.data.frame(ladder)); cat("Between R2:", R2_between, "\n")

gm <- data.frame(raw = c("nobs","r.squared"), clean = c("N","R2 (within)"), fmt = c(0,3))
v_pool <- sandwich::vcovCL(m_pool, cluster = province_panel$Code_Prov)
tabel_ladder <- modelsummary(
  list("Pooled OLS" = m_pool, "Province FE" = m_prov, "Province + Year FE" = m_two),
  vcov = list(v_pool, vcovHC(m_prov, type="HC1", cluster="group"), vcovHC(m_two, type="HC1", cluster="group")),
  stars = TRUE, gof_map = gm, coef_rename = c("lx" = "log PMA+PMDN"), output = "flextable",
  title = "Tabel 1. Elastisitas linear log-log per struktur FE (nasional)") %>%
  fontsize(size = 8, part = "all") %>% autofit()


# 9) Charts ----
model_colors <- c("linear"="#95A5A6","kuadratik"="#2980B9","kubik"="#8E44AD",
                  "spline_df3"="#27AE60","spline_df4"="#16A085","piecewise"="#D35400",
                  "resiprokal"="#C0392B","asimetris"="#F39C12","tak cukup data"="grey90")

## 9a. Heatmap model terpilih ----
urutan_sub <- c("Nasional - Semua","Nasional - Pre","Nasional - Post",
                unlist(lapply(urutan_pulau, function(p) paste0(p, c(" - Semua"," - Pre"," - Post")))))
hm <- sel %>% mutate(subgroup = factor(subgroup, levels = rev(urutan_sub)),
                     bentuk = factor(bentuk, levels = c("log","growth")),
                     lbl = ifelse(is.na(n), "-", sprintf("%s\nR²=%.2f", model_AIC, within_R2)))
chart_hm <- ggplot(hm, aes(x = bentuk, y = subgroup, fill = model_AIC)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = lbl), size = 2.5, color = "white", fontface = "bold", lineheight = 0.9) +
  scale_fill_manual(name = "Model terbaik (AIC)", values = model_colors) +
  labs(title = "Bentuk hubungan terbaik berbeda antar-subgroup dan antar-bentuk variabel",
       subtitle = "Growth cenderung linear; log cenderung non-linear. R² = within-R² (net efek provinsi & tahun).",
       x = NULL, y = NULL,
       caption = "Sumber: BPS & BKPM, diolah. Seleksi AIC dari 7 kandidat. '-' = tak cukup data.") +
  theme_classic(base_size = 10) +
  theme(plot.title = element_text(face="bold", size=11),
        plot.subtitle = element_text(color="grey40", size=9),
        axis.text.y = element_text(size = 8), axis.text.x = element_text(face="bold"),
        axis.line = element_blank(), axis.ticks = element_blank(),
        plot.caption = element_text(color="grey50", size=8, hjust=0),
        legend.position = "right", legend.title = element_text(size=8, face="bold"),
        legend.text = element_text(size=7.5), legend.key.size = unit(0.4,"cm"))
ggsave(file.path(out_dir, "Model Terpilih per Subgroup.png"), chart_hm,
       dpi = 300, units = "in", width = 9, height = 7)

## 9b. Kurva bentuk terpilih (partial effect), log, nasional + pulau ----
partial_curve <- function(key, npts = 120) {
  st <- fit_store[[key]]; if (is.null(st)) return(NULL)
  rc <- st$rc; s <- rc$spec; d <- rc$data; fam <- st$best
  r <- rc$fits[[fam]]; if (is.null(r)) return(NULL)
  gx <- seq(min(d[[s$xv]]), max(d[[s$xv]]), length.out = npts)
  nd <- d[rep(1, npts), , drop = FALSE]
  nd[[s$xv]] <- gx
  if (!is.na(r$knot)) nd$.k <- pmax(0, gx - r$knot)
  p <- tryCatch(as.numeric(predict(r$model, newdata = nd)), error = function(e) rep(NA_real_, npts))
  data.frame(x = gx, fit = p - mean(p, na.rm = TRUE), model = fam)
}
curve_panels <- lapply(c("Nasional", urutan_pulau), function(nm) {
  key <- paste0(nm, " - Semua log"); cv <- partial_curve(key)
  st <- fit_store[[key]]
  if (is.null(cv) || all(is.na(cv$fit))) return(ggplot() + labs(title=nm) + theme_classic(base_size=9))
  r2 <- sel$within_R2[sel$subgroup == paste0(nm," - Semua") & sel$bentuk == "log"][1]
  col <- if (nm == "Nasional") "grey25" else pulau_colors[[nm]]
  ggplot(cv, aes(x, fit)) +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.3) +
    geom_line(color = col, linewidth = 0.9) +
    geom_rug(data = st$rc$data, aes(x = lx, y = NULL), sides = "b", alpha = 0.25, length = unit(0.03,"npc")) +
    labs(title = nm, subtitle = sprintf("%s | within-R² = %.2f", cv$model[1], r2),
         x = "log PMA+PMDN", y = "efek parsial pd log PMTB") +
    theme_classic(base_size = 9) +
    theme(plot.title = element_text(face="bold", size=10, hjust=0.5),
          plot.subtitle = element_text(color="grey40", size=8, hjust=0.5),
          panel.grid.major = element_line(color="grey92", linewidth=0.3))
})
chart_curve <- patchwork::wrap_plots(curve_panels, ncol = 4) +
  patchwork::plot_annotation(
    title = "Bentuk hubungan terpilih (bentuk log, semua tahun)",
    caption = paste("Sumber: BPS & BKPM, diolah. Kurva = efek parsial model terpilih AIC, sudah dipusatkan;",
                    "efek provinsi & tahun dikeluarkan. Rug = sebaran data."),
    theme = theme(plot.title = element_text(face="bold", size=12),
                  plot.caption = element_text(color="grey50", size=8, hjust=0)))
ggsave(file.path(out_dir, "Bentuk Hubungan Terpilih (log).png"), chart_curve,
       dpi = 300, units = "in", width = 13, height = 7)

## 9c. Ladder ----
chart_ladder <- ladder %>% mutate(spesifikasi = factor(spesifikasi, levels = spesifikasi)) %>%
  ggplot(aes(x = spesifikasi, y = R2)) +
  geom_col(width = 0.6, fill = c("#95A5A6","#95A5A6","#95A5A6","#2C3E50")) +
  geom_text(aes(label = sprintf("%.2f", R2)), vjust = -0.4, size = 3.2, color = "grey20") +
  scale_y_continuous(limits = c(0, 0.8), expand = expansion(mult = c(0, 0.1))) +
  labs(title = "Korelasi log menyusut saat ukuran & tren dikeluarkan, lalu naik lagi saat bentuk dilonggarkan",
       subtitle = sprintf("R2 antar-provinsi (sumbu ukuran) = %.2f. Batang terakhir = model terbaik AIC.", R2_between),
       x = NULL, y = "R² (within, net FE)",
       caption = "Sumber: BPS & BKPM, diolah. n = 306 provinsi-tahun.") +
  theme_classic(base_size = 10) +
  theme(plot.title = element_text(face="bold", size=10.5),
        plot.subtitle = element_text(color="grey40", size=9),
        axis.text.x = element_text(face="bold", size=8),
        panel.grid.major.y = element_line(color="grey90", linewidth=0.3),
        plot.caption = element_text(color="grey50", size=8, hjust=0))
ggsave(file.path(out_dir, "Atenuasi R2 (ladder).png"), chart_ladder,
       dpi = 300, units = "in", width = 8, height = 5)

## 9d. Rasio over time ----
chart_share <- share_all %>%
  mutate(Wilayah = factor(Wilayah, levels = c("Nasional", urutan_pulau))) %>%
  ggplot(aes(x = Year, y = share_pct, group = Wilayah)) +
  geom_line(data = ~ filter(.x, Wilayah != "Nasional"), aes(color = Wilayah), linewidth = 0.7) +
  geom_line(data = ~ filter(.x, Wilayah == "Nasional"), color = "grey15", linewidth = 1.2) +
  geom_text(data = ~ filter(.x, Wilayah == "Nasional", Year == 2025), aes(label = "Nasional"),
            hjust = -0.1, size = 3, color = "grey15", fontface = "bold") +
  scale_color_manual(name = "Pulau", values = pulau_colors) +
  scale_x_continuous(breaks = 2017:2025, expand = expansion(mult = c(0.02, 0.14))) +
  scale_y_continuous(labels = function(z) paste0(z, "%")) +
  labs(title = "Rasio (PMA+PMDN) / PMTB, 2017–2025",
       subtitle = "Garis tebal = nasional. Nasional dan enam pulau.",
       x = NULL, y = "Realisasi BKPM / PMTB (%)",
       caption = "Sumber: BPS & BKPM, diolah.") +
  theme_classic(base_size = 10) +
  theme(plot.title = element_text(face="bold", size=11),
        plot.subtitle = element_text(color="grey40", size=9),
        panel.grid.major.y = element_line(color="grey90", linewidth=0.3),
        plot.caption = element_text(color="grey50", size=8, hjust=0),
        legend.position = c(0.18, 0.7),
        legend.background = element_rect(fill="white", color="grey80", linewidth=0.3),
        legend.title = element_text(size=8, face="bold"), legend.text = element_text(size=7.5),
        legend.key.size = unit(0.4,"cm"))
ggsave(file.path(out_dir, "Rasio BKPM terhadap PMTB.png"), chart_share,
       dpi = 300, units = "in", width = 8, height = 5)

## 9e. Scatter (growth & log, dengan/tanpa outlier) ----
scatter_unit <- function(df, judul, mode = "growth", drop_outliers = FALSE) {
  if (mode == "growth") { dd <- df %>% transmute(xv = gx*100, yv = gy*100)
    xlab <- "Growth PMA+PMDN (%)"; ylab <- "Growth PMTB (%)"; pct <- TRUE
  } else { dd <- df %>% transmute(xv = lx, yv = ly)
    xlab <- "log PMA+PMDN"; ylab <- "log PMTB"; pct <- FALSE }
  dd <- dd %>% filter(is.finite(xv), is.finite(yv))
  if (drop_outliers) {
    inb <- function(v) { q <- quantile(v, c(.25,.75)); r <- 1.5*diff(q); v >= q[1]-r & v <= q[2]+r }
    dd <- dd %>% filter(inb(xv), inb(yv))
  }
  if (nrow(dd) < 3) return(ggplot() + labs(title = judul) + theme_classic(base_size = 9))
  r2 <- summary(lm(yv ~ xv, data = dd))$r.squared
  col <- if (judul == "Nasional") "grey30" else pulau_colors[[judul]]
  g <- ggplot(dd, aes(x = xv, y = yv)) +
    geom_smooth(method = "lm", se = TRUE, color = "grey25", fill = "grey85", linewidth = 0.6) +
    geom_point(color = col, size = 1.6, alpha = 0.7) +
    labs(title = judul, subtitle = sprintf("R² = %.2f, n = %d", r2, nrow(dd)), x = xlab, y = ylab) +
    theme_classic(base_size = 9) +
    theme(plot.title = element_text(face="bold", size=10, hjust=0.5),
          plot.subtitle = element_text(color="grey40", size=8, hjust=0.5),
          panel.grid.major = element_line(color="grey92", linewidth=0.3))
  if (pct) g <- g + scale_x_continuous(labels=function(z) paste0(z,"%")) +
                    scale_y_continuous(labels=function(z) paste0(z,"%"))
  g
}
panel_data <- c(list("Nasional" = province_panel),
                setNames(lapply(urutan_pulau, function(p) province_panel %>% filter(Pulau == p)), urutan_pulau))
build_scatter <- function(mode, drop_outliers, judul, caption, file) {
  pl <- lapply(c("Nasional", urutan_pulau), function(nm) scatter_unit(panel_data[[nm]], nm, mode, drop_outliers))
  fig <- patchwork::wrap_plots(pl, ncol = 4) +
    patchwork::plot_annotation(title = judul, caption = caption,
      theme = theme(plot.title = element_text(face="bold", size=12),
                    plot.caption = element_text(color="grey50", size=8, hjust=0)))
  ggsave(file.path(out_dir, file), fig, dpi = 300, units = "in", width = 13, height = 7)
}
cap_src <- "Sumber: BPS & BKPM, diolah. Tiap titik = 1 provinsi-tahun. Garis = fit OLS linear (± selang kepercayaan)."
cap_out <- paste(cap_src, "Outlier dibuang (aturan IQR 1,5x pada kedua sumbu).")
cap_log <- paste(cap_src, "Fit linear ini hanya rujukan; bentuk terpilih ada di 'Bentuk Hubungan Terpilih'.")
build_scatter("growth", FALSE, "Growth PMA+PMDN vs Growth PMTB per provinsi (2017-2025)", cap_src,
              "Scatter Growth PMTB vs PMA-PMDN (Nasional-Pulau).png")
build_scatter("growth", TRUE, "Growth PMA+PMDN vs Growth PMTB per provinsi, tanpa outlier", cap_out,
              "Scatter Growth PMTB vs PMA-PMDN (tanpa outlier).png")
build_scatter("log", FALSE, "log PMA+PMDN vs log PMTB per provinsi (2017-2025)", cap_log,
              "Scatter Log-Log PMTB vs PMA-PMDN (Nasional-Pulau).png")
build_scatter("log", TRUE, "log PMA+PMDN vs log PMTB per provinsi, tanpa outlier",
              paste(cap_log, "Outlier dibuang (IQR 1,5x)."),
              "Scatter Log-Log PMTB vs PMA-PMDN (tanpa outlier).png")


# 10) Docx ----
idn <- function(s) gsub("(\\d)\\.(\\d)", "\\1,\\2", s)
g <- function(sg, bt, col) sel[[col]][sel$subgroup == sg & sel$bentuk == bt][1]
r2_lin_nas <- ladder$R2[3]; r2_best_nas <- best_nas_log$within_R2; mod_best_nas <- best_nas_log$model_AIC
share_25 <- floor(share_nasional$share_pct[share_nasional$Year==2025]*10+0.5)/10
share_17 <- floor(share_nasional$share_pct[share_nasional$Year==2017]*10+0.5)/10
n_lin_growth <- sum(sel$model_BIC[sel$bentuk=="growth"] == "linear", na.rm=TRUE)
n_fit_growth <- sum(sel$model_BIC[sel$bentuk=="growth"] != "tak cukup data", na.rm=TRUE)
n_nonlin_log <- sum(!sel$model_BIC[sel$bentuk=="log"] %in% c("linear","tak cukup data"), na.rm=TRUE)
n_fit_log    <- sum(sel$model_BIC[sel$bentuk=="log"] != "tak cukup data", na.rm=TRUE)

sel_ft <- flextable(sel %>% mutate(across(where(is.numeric), ~round(.x,3)))) %>%
  theme_booktabs() %>% fontsize(size = 7, part="all") %>% autofit() %>% set_table_properties(layout="autofit")
cand_ft <- flextable(cand_tbl %>% filter(grepl("^Nasional", subgroup))) %>%
  theme_booktabs() %>% fontsize(size = 7, part="all") %>% autofit() %>% set_table_properties(layout="autofit")
share_ft <- flextable(share_all %>% mutate(share_pct = round(share_pct,1)) %>%
                        pivot_wider(names_from=Year, values_from=share_pct)) %>%
  theme_booktabs() %>% fontsize(size=7.5, part="all") %>% bold(i = ~ Wilayah == "Nasional") %>%
  autofit() %>% set_table_properties(layout="autofit")

doc <- read_docx() %>%
  body_add_par("Ringkasan: Korelasi PMTB dan Realisasi PMA/PMDN", style = "heading 1") %>%
  body_add_par("Subbab 6.3 Poin 2 - Analisis I Kebijakan Makro Investasi", style = "centered") %>%
  body_add_par("") %>%
  body_add_par("Inti temuan", style = "heading 2") %>%
  body_add_par(idn(sprintf(paste0(
    "Bentuk hubungan PMTB dengan realisasi PMA/PMDN tidak sama di semua wilayah dan periode, dan itu ",
    "sendiri temuannya. Dari tujuh kandidat bentuk fungsional yang diuji di tiap subgroup, model ",
    "terbaik untuk nasional (bentuk log, semua tahun) adalah %s dengan within-R2 %.2f. Kalau bentuknya ",
    "dipaksa linear, angkanya cuma %.2f. Jadi memaksakan linearitas memangkas lebih dari separuh ",
    "hubungan yang sebenarnya ada."), mod_best_nas, r2_best_nas, r2_lin_nas))) %>%
  body_add_par(idn(sprintf(paste0(
    "Pola bentuknya sistematis. Pada bentuk pertumbuhan tahunan, %d dari %d subgroup memilih model ",
    "linear (kriteria BIC), dan daya jelasnya rendah di mana-mana. Pada bentuk log, %d dari %d subgroup ",
    "justru memilih bentuk non-linear. Artinya hubungan level punya kelengkungan yang nyata, sementara ",
    "hubungan antar-perubahan tahunan tidak."), n_lin_growth, n_fit_growth, n_nonlin_log, n_fit_log))) %>%
  body_add_par(paste0(
    "Kelengkungan itu punya arah yang masuk akal: elastisitas menguat seiring naiknya skala realisasi. ",
    "Ini sejalan dengan poin 1. Pada nilai realisasi kecil, angka BKPM banyak diisi komponen yang tidak ",
    "masuk PMTB (tanah dan modal kerja pra-operasional) serta noise pelaporan. Pada nilai besar, ",
    "pembentukan aset tetap riil yang mendominasi, sehingga kaitannya dengan PMTB menguat.")) %>%
  body_add_par(paste0(
    "Hubungan ini tetap korelasi, bukan sebab-akibat. Arah yang lebih masuk akal justru terbalik: ",
    "perusahaan melapor LKPM setelah aset tetapnya terbangun, bukan sebelum.")) %>%
  body_add_img(src = file.path(out_dir, "Model Terpilih per Subgroup.png"), width = 6.0, height = 4.7) %>%
  body_add_par("Bentuk hubungan per wilayah", style = "heading 2") %>%
  body_add_par(idn(sprintf(paste0(
    "Sumatera adalah kasus paling lemah. Model terbaiknya %s dengan within-R2 %.2f untuk semua tahun, ",
    "dan pola itu bertahan di periode pra-pandemi. Pembentukan modal tetap di Sumatera bergerak lepas ",
    "dari realisasi BKPM, menandakan porsi besar akumulasi aset di sana berasal dari pelaku di luar ",
    "semesta pelapor LKPM: rumah tangga, usaha non-pelapor, dan sektor yang dikecualikan seperti ",
    "perkebunan dan keuangan. Catatan: pada periode pasca-pandemi Sumatera justru memilih bentuk %s ",
    "dengan within-R2 %.2f, jadi dekoplingnya bukan sifat permanen."),
    g("Sumatera - Semua","log","model_AIC"), g("Sumatera - Semua","log","within_R2"),
    g("Sumatera - Post","log","model_AIC"), g("Sumatera - Post","log","within_R2")))) %>%
  body_add_par(idn(sprintf(paste0(
    "Kalimantan, Sulawesi, dan Maluku-Papua menunjukkan within-R2 tinggi (%.2f, %.2f, %.2f) begitu ",
    "bentuk non-linear diizinkan. Angka-angka ini perlu dibaca hati-hati. Uji leave-one-province-out ",
    "menunjukkan hasilnya bergantung pada satu-dua provinsi saja, sehingga tidak dipakai sebagai ",
    "kesimpulan utama. Yang kokoh adalah hasil nasional dengan 34 provinsi."),
    g("Kalimantan - Semua","log","within_R2"), g("Sulawesi - Semua","log","within_R2"),
    g("Maluku-Papua - Semua","log","within_R2")))) %>%
  body_add_img(src = file.path(out_dir, "Bentuk Hubungan Terpilih (log).png"), width = 6.5, height = 3.5) %>%
  body_add_par("Cakupan naik, keterwakilan tidak", style = "heading 2") %>%
  body_add_par(idn(sprintf(paste0(
    "Rasio realisasi BKPM terhadap PMTB naik dari %.1f%% (2017) ke %.1f%% (2025), sejalan dengan ",
    "benchmark resmi 16,46%% (Q1-2021) ke 27,88%% (Q3-2025). Cakupan pelaporan melebar. Tapi keeratan ",
    "hubungan tidak ikut membaik: pada bentuk log, nasional pasca-pandemi justru memilih model linear ",
    "dengan within-R2 %.2f, lebih rendah dari periode pra-pandemi (%.2f). Menambah volume laporan tidak ",
    "otomatis membuat PMA/PMDN jadi cermin PMTB yang lebih baik, karena tambahan itu tetap memuat ",
    "komponen yang tidak masuk PMTB dan tetap dari populasi dengan kepatuhan lapor sepertiga."),
    share_17, share_25, g("Nasional - Post","log","within_R2"), g("Nasional - Pre","log","within_R2")))) %>%
  body_add_img(src = file.path(out_dir, "Rasio BKPM terhadap PMTB.png"), width = 6.3, height = 3.9) %>%
  body_add_par("Implikasi kebijakan", style = "heading 2") %>%
  body_add_par(paste0(
    "Realisasi PMA/PMDN sahih untuk memantau funnel investasi korporasi pelapor: proyek yang masuk ",
    "OSS/LKPM. Ia bukan proxy andal untuk pembentukan modal tetap sebuah wilayah, dan paling jelas ",
    "gagal di Sumatera. Untuk memantau investasi riil daerah, pakai PMTB regional BPS langsung. Rasio ",
    "realisasi terhadap PMTB yang naik menandakan pelaporan makin lengkap, bukan realisasi makin ",
    "mewakili PMTB; dua hal ini jangan dipertukarkan dalam narasi capaian. Karena kaitannya menguat ",
    "pada skala besar, angka realisasi lebih bisa dipercaya untuk proyek besar dibanding untuk ",
    "menyimpulkan dinamika investasi daerah secara keseluruhan.")) %>%
  body_add_break() %>%
  body_add_par("Lampiran Tabel", style = "heading 1") %>%
  body_add_par("Model terbaik per subgroup (2.B/2.C)", style = "heading 2") %>%
  body_add_par(paste0(
    "Seleksi dari 7 kandidat: linear, kuadratik, kubik, spline df3, spline df4, piecewise (breakpoint ",
    "dicari dan dipenalti), plus resiprokal (bentuk log) atau asimetris (bentuk growth). within_R2 = ",
    "1 - RSS_model/RSS_FE-only, sehingga kontribusi dummy provinsi dan tahun tidak ikut terhitung."),
    style = "Balloon Text") %>%
  body_add_flextable(sel_ft) %>%
  body_add_par("") %>%
  body_add_par("Semua kandidat, subgroup nasional", style = "heading 2") %>%
  body_add_flextable(cand_ft) %>%
  body_add_par("") %>%
  body_add_par("Rasio (PMA+PMDN)/PMTB per wilayah, %", style = "heading 2") %>%
  body_add_flextable(share_ft) %>%
  body_add_par("") %>%
  body_add_par("Elastisitas linear per struktur FE", style = "heading 2") %>%
  body_add_flextable(tabel_ladder) %>%
  body_add_par("") %>%
  body_add_par("Metode dan keterbatasan ada di skrip ini.", style = "Balloon Text")

print(doc, target = file.path(out_dir, "Ringkasan Korelasi PMTB-PMA-PMDN.docx"))


# 11) Bersihkan output lama & ringkasan konsol ----
for (f in c("Goodness-of-Fit Growth.csv","Goodness-of-Fit Log.csv","Goodness-of-Fit Ladder.csv")) {
  fp <- file.path(out_dir, f); if (file.exists(fp)) file.remove(fp)
}
cat("\n=== SELESAI ===\n")
cat("Nasional log: model terbaik =", mod_best_nas, "| within-R2 =", r2_best_nas,
    "| linear =", r2_lin_nas, "\n")
cat("Output di:", out_dir, "\n")
