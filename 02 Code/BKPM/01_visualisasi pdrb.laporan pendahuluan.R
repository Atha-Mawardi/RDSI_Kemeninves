
# SCRIPT OVERVIEW --------------------------------------
# viz kebutuhan laporan pendahuluan mencakup data PDRB dan PMTB/PMA-PMDN.
# visualisasi yang dilakukan adalah:
# 1) efektivitas investasi. 
# - horizontal bar chart two cats: CAGR econ and inv growth
# - presented on several categories: 
# * nat (sectors), isl (sectors), prov (total), prov (selected sectors)
# - scatterplot. x-axis = inv growth, y-axis = ec. growth for province x sector
# * colored by sectoral classification & island
# 2) kontribusi pertumbuhan ekonomi
# - weighted average of economic contribution
# * prov nas (map) [kontribusi + actual growth]
# * sec nas (horizontal bar chart) [kontribusi + actual growth]
# * prov isl (horizontal bar chart) [kontribusi + actual growth]
# * sec prov (horizontal bar chart) [kontribusi top 3 dan sisanya lain-lain,
# dibuat proporsi per bar chart, panjang bar mengikuti growth actual, tapi 
# isinya setiap bar adalah proporsi per sector. diberikan legend]  

# Problem: tidak ada data inv. sektoral jadi analisis poin 1 level agregat
#          sedang diproses datanya.


# 1) Persiapan script ----
rm(list = ls())

## load library ----
library(openxlsx)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(ggpattern)
library(patchwork)


## import dataset ----
pdrb_inv <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx",sheet = "Database")
metadata <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx",sheet = "Tabel Operasional ")
col_names <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx",sheet = "column_names")
longnames_klas <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx",sheet = "longnames")
prov_nama <- read.xlsx("01 Data/BKPM/processed/Dataset Provinsi.xlsx",sheet = "prov_name")

# 2) Data cleaning ----
##-> we use ADHB growth
pdrb_inv <- pdrb_inv %>% dplyr::select(., c(Code_Prov,Year,A_ADHB:RSTU_ADHB,PMA_1,PMDN_1,`4_ADHB`))
pdrb_inv <- pdrb_inv %>% mutate(across(c(A_ADHB:RSTU_ADHB), as.numeric),
                                across(c(PMA_1,PMDN_1,`4_ADHB`), ~ as.numeric(gsub(",", ".", .x))))
pdrb_inv <- pdrb_inv %>% mutate(PMA_1 = PMA_1/1e3,
                                PMDN_1 = PMDN_1/1e3)

##-> agreggating to 34 provinces, renaming variables, creating megasectors
pdrb_inv.34 <- pdrb_inv %>%
  group_by(Code_Prov, Year) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop")   

pdrb_inv.34_wide <- pdrb_inv.34 %>%
  pivot_longer(cols      = -c(Code_Prov, Year),
               names_to  = "kodename",
               values_to = "Nilai") %>%
  pivot_wider(names_from  = Year,
              values_from = Nilai)

pdrb_inv.34_wide <- pdrb_inv.34_wide %>% left_join(., col_names)

megasectors <- pdrb_inv.34_wide %>% dplyr::select(., c(Code_Prov,sect_klas_megasektor,`2017`:`2025`)) %>%
  group_by(Code_Prov,sect_klas_megasektor) %>% 
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  filter(!is.na(sect_klas_megasektor))
head(megasectors)


klas_alt <- pdrb_inv.34_wide %>% dplyr::select(., c(Code_Prov,sect_klas_alt,`2017`:`2025`)) %>%
  group_by(Code_Prov,sect_klas_alt) %>% 
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  filter(!is.na(sect_klas_alt))

megasectors <- megasectors %>%
  pivot_longer(cols      = `2017`:`2025`,
               names_to  = "Year",
               values_to = "Nilai") %>%
  pivot_wider(names_from  = sect_klas_megasektor,
              values_from = Nilai)

klas_alt <- klas_alt %>%
  pivot_longer(cols      = `2017`:`2025`,
               names_to  = "Year",
               values_to = "Nilai") %>%
  pivot_wider(names_from  = sect_klas_alt,
              values_from = Nilai) 

pdrb_inv.34 <- pdrb_inv.34_wide %>% dplyr::select(., -c(kodename,sect_klas_megasektor,sect_klas_alt)) %>%
  pivot_longer(cols      = `2017`:`2025`,
               names_to  = "Year",
               values_to = "Nilai") %>%
  pivot_wider(names_from  = sect_name,
              values_from = Nilai) 

pdrb_inv.cleaned <- list(pdrb_inv.34, megasectors, klas_alt) %>%
  reduce(left_join, by = c("Code_Prov", "Year"))

pdrb_inv.cleaned <- pdrb_inv.cleaned %>% 
  mutate(total_pdrb = rowSums(across(c(Primer,Sekunder,Tersier,Kuarterner)),na.rm = T),
         pma_pmdn = rowSums(across(c(PMA,PMDN)),na.rm = T))

pdrb_inv.cleaned <- pdrb_inv.cleaned %>%
  pivot_longer(cols      = -c(Code_Prov, Year),
               names_to  = "kodename",
               values_to = "Nilai") %>%
  pivot_wider(names_from  = Year,
              values_from = Nilai)

pdrb_inv.cleaned <- pdrb_inv.cleaned %>% left_join(.,longnames_klas) 
pdrb_inv.cleaned <- pdrb_inv.cleaned %>% left_join(.,prov_nama) 
##-> Fixing kodename
pdrb_inv.cleaned <- pdrb_inv.cleaned %>% mutate(
  kodename = case_when(kodename == "pma_pmdn" ~ "PMA + PMDN",
                       kodename == "total_pdrb" ~ "PDRB Total",
                       TRUE ~ kodename)
)


# 3) Data viz: GDP and PDB ----
cagr_start <- 2022

## Investasi dan PDB nasional (CAGR) ----
national <- pdrb_inv.cleaned %>% dplyr::select(.,-c(Code_Prov,Pulau,Prov_nama)) %>%
  group_by(klasifikasi,kodename) %>% 
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop")

national <- national %>% 
  mutate(cagr = (`2025`/.data[[as.character(cagr_start)]])^(1 / (2025-cagr_start))-1)

national %>% filter(klasifikasi %in% c("total", "investment")) %>%
  mutate(kodename = ifelse(kodename == "PDRB Total", "PDB", kodename)) %>%
  mutate(cagr_pct = cagr * 100,
         color_group = case_when(
           kodename %in% c("PMA", "PMDN", "PMA + PMDN") ~ "Investasi Swasta",
           kodename == "PMTB"                            ~ "PMTB",
           kodename == "PDB"                             ~ "PDB"
         )) %>%
  ggplot(aes(x = reorder(kodename, cagr_pct), y = cagr_pct, fill = color_group)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%", cagr_pct)),
            hjust = -0.2, size = 3.2, color = "black") +
  coord_flip() +
  scale_fill_manual(
    values = c(
      "Investasi Swasta" = "#2C3E50",
      "PMTB"              = "#7F8C8D",
      "PDB"              = "#C0392B"
    )
  ) +
  scale_y_continuous(
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title   = "CAGR PDB dan Investasi, 2022–2025",
    x       = NULL,
    y       = "CAGR (%)",
    caption = "Sumber: BPS & BKPM, diolah"
  ) +
  theme_classic(base_size = 11) +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    axis.line.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    axis.text.y        = element_text(face = "bold"),
    panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
    plot.caption       = element_text(color = "grey50", size = 10),
    legend.position    = "none"
  )

ggsave(filename = "01 Data/BKPM/output/CAGR PDB dan Investasi (Nasional).png",plot = last_plot(),dpi = 300,units = "in")

nat_pdrb <- national %>% filter(kodename == "PDRB Total") %>% pull(cagr) * 100
nat_inv  <- national %>% filter(kodename == "PMA + PMDN") %>% pull(cagr) * 100
nat_pmtb <- national %>% filter(kodename == "PMTB")        %>% pull(cagr) * 100

## Pulau total PMA+PMDN (CAGR) ----
pulau <- pdrb_inv.cleaned %>% dplyr::select(.,-c(Code_Prov,Prov_nama)) %>%
  group_by(Pulau,klasifikasi,kodename) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  mutate(cagr = (`2025`/.data[[as.character(cagr_start)]])^(1 / (2025-cagr_start))-1)

urutan_pulau <- pulau %>%
  filter(kodename == "PDRB Total") %>%
  arrange(desc(cagr)) %>%
  pull(Pulau)

pulau_plot <- pulau %>%
  filter(kodename %in% c("PDRB Total", "PMA + PMDN")) %>%
  mutate(
    cagr_pct = cagr * 100,
    kodename = ifelse(kodename == "PDRB Total", "PDRB", kodename),
    Pulau    = factor(Pulau, levels = urutan_pulau)
  )

clipped_pulau <- pulau_plot %>% filter(cagr_pct < -5)

pulau_plot %>%
  ggplot(aes(x = Pulau, y = cagr_pct, fill = Pulau)) +
  geom_hline(aes(yintercept = nat_pdrb, linetype = "CAGR PDB Nasional"),      color = "grey30", linewidth = 0.3) +
  geom_hline(aes(yintercept = nat_inv,  linetype = "CAGR PMA+PMDN Nasional"), color = "grey30", linewidth = 0.3) +
  geom_col_pattern(
    aes(pattern = kodename),
    position        = position_dodge(width = 0.6),
    width           = 0.6,
    pattern_angle   = 45,
    pattern_density = 0.06,
    pattern_spacing = 0.01,
    pattern_fill    = "white",
    pattern_colour  = "white",
    colour          = NA
  ) +
  geom_label(
    data          = clipped_pulau,
    aes(x = Pulau, y = -4.5, label = sprintf("%.1f%%", cagr_pct), group = kodename),
    position      = position_dodge(width = 0.6),
    size          = 2.5, vjust = 0, color = "grey20",
    fill          = "white", linewidth = 0.2,
    label.padding = unit(0.1, "lines"),
    inherit.aes   = FALSE
  ) +
  scale_fill_manual(
    name   = "Pulau",
    values = c(
      "Bali-Nusa Tenggara" = "#D9042B",
      "Jawa"               = "#F2509C",
      "Kalimantan"         = "#062E4C",
      "Maluku-Papua"       = "#46A694",
      "Sulawesi"           = "#30726A",
      "Sumatera"           = "#F2E6CE"
    )
  ) +
  scale_pattern_manual(
    name   = "Variabel",
    values = c("PDRB" = "none", "PMA + PMDN" = "stripe"),
    labels = c("PDRB", "PMA + PMDN")
  ) +
  scale_linetype_manual(
    name   = "Referensi",
    values = c("CAGR PDB Nasional" = "solid", "CAGR PMA+PMDN Nasional" = "dashed")
  ) +
  coord_cartesian(ylim = c(-5, NA)) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title   = "CAGR PDRB dan PMA + PMDN berdasarkan pulau besar, 2022–2025",
    x       = NULL, y = "CAGR (%)",
    caption = "Sumber: BPS & BKPM, diolah."
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title           = element_text(face = "bold", size = 11),
    axis.line.x          = element_blank(),
    axis.ticks.x         = element_blank(),
    axis.text.x          = element_text(size = 9, face = "bold"),
    panel.grid.major.y   = element_line(color = "grey90", linewidth = 0.4),
    plot.caption         = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position    = c(0.5, 0.8),  
    legend.box         = "horizontal",
    legend.justification = "center",
    legend.box.spacing = unit(0.1, "cm"),
    legend.background  = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title       = element_text(size = 8, face = "bold"),
    legend.key.size    = unit(0.4, "cm"),
    legend.text        = element_text(size = 7.5),
    legend.margin      = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/CAGR PDRB dan Investasi (Pulau).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 11, height = 5
)

## Pulau total PMTB (CAGR) ----
pulau_pmtb_plot <- pulau %>%
  filter(kodename %in% c("PDRB Total", "PMTB")) %>%
  mutate(
    cagr_pct = cagr * 100,
    kodename = ifelse(kodename == "PDRB Total", "PDRB", kodename),
    Pulau    = factor(Pulau, levels = urutan_pulau)
  )

clipped_pulau_pmtb <- pulau_pmtb_plot %>% filter(cagr_pct < -5)

pulau_pmtb_plot %>%
  ggplot(aes(x = Pulau, y = cagr_pct, fill = Pulau)) +
  geom_hline(aes(yintercept = nat_pdrb, linetype = "CAGR PDB Nasional"),   color = "grey30", linewidth = 0.3) +
  geom_hline(aes(yintercept = nat_pmtb, linetype = "CAGR PMTB Nasional"),  color = "grey30", linewidth = 0.3) +
  geom_col_pattern(
    aes(pattern = kodename),
    position        = position_dodge(width = 0.6),
    width           = 0.6,
    pattern_angle   = 45,
    pattern_density = 0.06,
    pattern_spacing = 0.01,
    pattern_fill    = "white",
    pattern_colour  = "white",
    colour          = NA
  ) +
  geom_label(
    data          = clipped_pulau_pmtb,
    aes(x = Pulau, y = -4.5, label = sprintf("%.1f%%", cagr_pct), group = kodename),
    position      = position_dodge(width = 0.6),
    size          = 2.5, vjust = 0, color = "grey20",
    fill          = "white", linewidth = 0.2,
    label.padding = unit(0.1, "lines"),
    inherit.aes   = FALSE
  ) +
  scale_fill_manual(
    name   = "Pulau",
    values = c(
      "Bali-Nusa Tenggara" = "#D9042B",
      "Jawa"               = "#F2509C",
      "Kalimantan"         = "#062E4C",
      "Maluku-Papua"       = "#46A694",
      "Sulawesi"           = "#30726A",
      "Sumatera"           = "#F2E6CE"
    )
  ) +
  scale_pattern_manual(
    name   = "Variabel",
    values = c("PDRB" = "none", "PMTB" = "stripe"),
    labels = c("PDRB", "PMTB")
  ) +
  scale_linetype_manual(
    name   = "Referensi",
    values = c("CAGR PDB Nasional" = "solid", "CAGR PMTB Nasional" = "dashed")
  ) +
  coord_cartesian(ylim = c(-1, NA)) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title   = "CAGR PDRB dan PMTB berdasarkan pulau besar, 2022–2025",
    x       = NULL, y = "CAGR (%)",
    caption = "Sumber: BPS & BKPM, diolah."
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title           = element_text(face = "bold", size = 11),
    axis.line.x          = element_blank(),
    axis.ticks.x         = element_blank(),
    axis.text.x          = element_text(size = 9, face = "bold"),
    panel.grid.major.y   = element_line(color = "grey90", linewidth = 0.4),
    plot.caption         = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position      = c(0.5, 0.88),
    legend.box           = "horizontal",
    legend.justification = "center",
    legend.box.spacing   = unit(0.1, "cm"),
    legend.background    = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title         = element_text(size = 8, face = "bold"),
    legend.key.size      = unit(0.4, "cm"),
    legend.text          = element_text(size = 7.5),
    legend.margin        = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/CAGR PDRB dan PMTB (Pulau).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 11, height = 5
)

## Provinsi total PMA+PMDN (CAGR) ----
provinsi <- pdrb_inv.cleaned %>% dplyr::select(.,-c(Code_Prov)) %>%
  group_by(Pulau,Prov_nama,klasifikasi,kodename) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)),.groups = "drop") %>%
  mutate(cagr = (`2025`/.data[[as.character(cagr_start)]])^(1 / (2025-cagr_start))-1)

urutan <- provinsi %>%
  filter(kodename == "PDRB Total") %>%
  arrange(desc(cagr)) %>%
  pull(Prov_nama)

provinsi_plot <- provinsi %>%
  filter(kodename %in% c("PDRB Total", "PMA + PMDN")) %>%
  mutate(
    cagr_pct  = cagr * 100,
    kodename  = ifelse(kodename == "PDRB Total", "PDRB", kodename),
    Prov_nama = factor(Prov_nama, levels = urutan)
  )

clipped_df <- provinsi_plot %>% filter(cagr_pct < -5)

provinsi_plot %>%
  ggplot(aes(x = Prov_nama, y = cagr_pct, fill = Pulau)) +
  geom_hline(aes(yintercept = nat_pdrb, linetype = "CAGR PDB Nasional"),     color = "grey30", linewidth = 0.3) +
  geom_hline(aes(yintercept = nat_inv,  linetype = "CAGR PMA+PMDN Nasional"), color = "grey30", linewidth = 0.3) +
  geom_col_pattern(
    aes(pattern = kodename),
    position        = position_dodge(width = 0.6),
    width           = 0.6,
    pattern_angle   = 45,
    pattern_density = 0.06,
    pattern_spacing = 0.01,
    pattern_fill    = "white",
    pattern_colour  = "white",
    colour          = NA
  ) +
  geom_label(
    data        = clipped_df,
    aes(x = Prov_nama, y = -4.5, label = sprintf("%.1f%%", cagr_pct), group = kodename),
    position    = position_dodge(width = 0.6),
    size        = 2,
    vjust       = 0,
    color       = "grey20",
    fill        = "white",
    linewidth   = 0.2,
    label.padding = unit(0.1, "lines"),
    inherit.aes = FALSE
  ) +
  scale_fill_manual(
    name   = "Pulau",
    values = c(
      "Bali-Nusa Tenggara" = "#D9042B",
      "Jawa"               = "#F2509C",
      "Kalimantan"         = "#062E4C",
      "Maluku-Papua"       = "#46A694",
      "Sulawesi"           = "#30726A",
      "Sumatera"           = "#F2E6CE"
    )
  ) +
  scale_pattern_manual(
    name   = "Variabel",
    values = c("PDRB" = "none", "PMA + PMDN" = "stripe"),
    labels = c("PDRB", "PMA + PMDN")
  ) +
  scale_linetype_manual(
    name   = "Referensi",
    values = c("CAGR PDB Nasional" = "solid", "CAGR PMA+PMDN Nasional" = "dashed")
  ) +
  coord_cartesian(ylim = c(-5, NA)) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title   = "CAGR PDRB dan PMA + PMDN berdasarkan provinsi, 2022–2025",
    x       = NULL,
    y       = "CAGR (%)",
    caption = "Sumber: BPS & BKPM, diolah."
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title         = element_text(face = "bold", size = 11),
    axis.line.x        = element_blank(),
    axis.ticks.x       = element_blank(),
    axis.text.x        = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7, face = "bold"),
    panel.grid.major.y = element_line(color = "grey90", linewidth = 0.4),
    plot.caption       = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position    = c(0.4, 0.8),  
    legend.box         = "horizontal",
    legend.justification = "center",
    legend.box.spacing = unit(0.1, "cm"),
    legend.background  = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title       = element_text(size = 8, face = "bold"),
    legend.key.size    = unit(0.4, "cm"),
    legend.text        = element_text(size = 7.5),
    legend.margin      = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/CAGR PDRB dan Investasi (Provinsi).png",
  plot     = last_plot(),dpi      = 300,units    = "in",width    = 11,height   = 6)

## Provinsi total PMTB (CAGR) ----
provinsi_pmtb_plot <- provinsi %>%
  filter(kodename %in% c("PDRB Total", "PMTB")) %>%
  mutate(
    cagr_pct  = cagr * 100,
    kodename  = ifelse(kodename == "PDRB Total", "PDRB", kodename),
    Prov_nama = factor(Prov_nama, levels = urutan)
  )

clipped_pmtb <- provinsi_pmtb_plot %>% filter(cagr_pct < -5)

provinsi_pmtb_plot %>%
  ggplot(aes(x = Prov_nama, y = cagr_pct, fill = Pulau)) +
  geom_hline(aes(yintercept = nat_pdrb, linetype = "CAGR PDB Nasional"),  color = "grey30", linewidth = 0.3) +
  geom_hline(aes(yintercept = nat_pmtb, linetype = "CAGR PMTB Nasional"), color = "grey30", linewidth = 0.3) +
  geom_col_pattern(
    aes(pattern = kodename),
    position        = position_dodge(width = 0.6),
    width           = 0.6,
    pattern_angle   = 45,
    pattern_density = 0.06,
    pattern_spacing = 0.01,
    pattern_fill    = "white",
    pattern_colour  = "white",
    colour          = NA
  ) +
  geom_label(
    data        = clipped_pmtb,
    aes(x = Prov_nama, y = -4.5, label = sprintf("%.1f%%", cagr_pct), group = kodename),
    position    = position_dodge(width = 0.6),
    size        = 2, vjust = 0, color = "grey20",
    fill        = "white", linewidth = 0.2,
    label.padding = unit(0.1, "lines"),
    inherit.aes = FALSE
  ) +
  scale_fill_manual(
    name   = "Pulau",
    values = c(
      "Bali-Nusa Tenggara" = "#D9042B",
      "Jawa"               = "#F2509C",
      "Kalimantan"         = "#062E4C",
      "Maluku-Papua"       = "#46A694",
      "Sulawesi"           = "#30726A",
      "Sumatera"           = "#F2E6CE"
    )
  ) +
  scale_pattern_manual(
    name   = "Variabel",
    values = c("PDRB" = "none", "PMTB" = "stripe"),
    labels = c("PDRB", "PMTB")
  ) +
  scale_linetype_manual(
    name   = "Referensi",
    values = c("CAGR PDB Nasional" = "solid", "CAGR PMTB Nasional" = "dashed")
  ) +
  coord_cartesian(ylim = c(-1, NA)) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title   = "CAGR PDRB dan PMTB berdasarkan provinsi, 2022–2025",
    x       = NULL, y = "CAGR (%)",
    caption = "Sumber: BPS & BKPM, diolah."
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title         = element_text(face = "bold", size = 11),
    axis.line.x        = element_blank(),
    axis.ticks.x       = element_blank(),
    axis.text.x        = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7, face = "bold"),
    panel.grid.major.y = element_line(color = "grey90", linewidth = 0.4),
    plot.caption       = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position    = c(0.5, 0.8),
    legend.box         = "horizontal",
    legend.justification = "center",
    legend.box.spacing = unit(0.1, "cm"),
    legend.background  = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title       = element_text(size = 8, face = "bold"),
    legend.key.size    = unit(0.4, "cm"),
    legend.text        = element_text(size = 7.5),
    legend.margin      = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/CAGR PDRB dan PMTB (Provinsi).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 10, height = 6
)


# 4) Data viz: Growth Contribution ----
## Sektoral -> Nasional (Klasifikasi:sektor) (CAGR) ----
# Agregat per sektor secara nasional (sum semua provinsi)
nat_sektor <- pdrb_inv.cleaned %>%
  filter(klasifikasi == "sektor") %>%
  select(-c(Code_Prov, Pulau, Prov_nama, klasifikasi)) %>%
  group_by(kodename) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop")

nat_sektor <- nat_sektor %>%
  left_join(col_names %>% select(sect_name, sect_klas_megasektor),
            by = c("kodename" = "sect_name"))

nat_sektor_total_base <- sum(nat_sektor[[as.character(cagr_start)]], na.rm = TRUE)

nat_sektor <- nat_sektor %>%
  mutate(
    cagr           = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    share_base     = .data[[as.character(cagr_start)]] / nat_sektor_total_base,
    kontribusi     = share_base * cagr * 100,          # kontribusi dalam pp
    cagr_pct       = cagr * 100,
    kontribusi_rel = kontribusi / nat_pdrb * 100       # % dari total growth nasional
  )

# Urutan: sektor dengan kontribusi relatif terbesar di kiri
urutan_sektor <- nat_sektor %>% arrange(desc(kontribusi_rel)) %>% pull(kodename)
nat_sektor <- nat_sektor %>% mutate(kodename = factor(kodename, levels = urutan_sektor))

# Scale factor: cap secondary axis di 40%, sehingga sektor kecil lebih terbaca
right_max    <- 40
scale_factor <- max(nat_sektor$cagr_pct, na.rm = TRUE) / right_max

mega_colors <- c(
  "Primer"     = "#797F8C",
  "Sekunder"   = "#0E2440",
  "Tersier"    = "#081526",
  "Kuarterner" = "#5DD0E6"
)

nat_sektor %>%
  ggplot(aes(x = kodename)) +
  geom_col(aes(y = cagr_pct, fill = sect_klas_megasektor), width = 0.7) +
  geom_hline(yintercept = nat_pdrb, linetype = "dashed", color = "grey40", linewidth = 0.4) +
  geom_line(aes(y = kontribusi_rel * scale_factor, group = 1),
            color = "#F59072", linewidth = 0.8) +
  geom_point(aes(y = kontribusi_rel * scale_factor),
             color = "#F59072", size = 2.5) +
  scale_fill_manual(name = "Megasektor", values = mega_colors, na.value = "grey70") +
  scale_y_continuous(
    name     = "CAGR Aktual (%)",
    labels   = function(x) paste0(x, "%"),
    expand   = expansion(mult = c(0, 0.12)),
    sec.axis = sec_axis(
      ~ . / scale_factor,
      name   = "Growth contribution (%)",
      breaks = seq(0, right_max, by = 10),
      labels = function(x) paste0(x, "%")
    )
  ) +
  coord_cartesian(ylim = c(NA, max(nat_sektor$cagr_pct, na.rm = TRUE) * 1.12)) +
  labs(
    title   = "CAGR Sektoral dan Kontribusi terhadap Pertumbuhan PDB Nasional, 2022–2025",
    x       = NULL,
    caption = paste0(
      "Sumber: BPS, diolah.\n",
      "Bar chart: CAGR aktual sektor (y-axis kiri) | Line chart: % kontribusi sektoral thd. pertumbuhan PDB Nasional (y-axis kanan).\n",
      "Kontribusi = bobot PDRB sektoral tahun dasar (2022) × CAGR sektor. Garis putus-putus = CAGR PDB Nasional."
    )
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title           = element_text(face = "bold", size = 11),
    axis.line.x          = element_blank(),
    axis.ticks.x         = element_blank(),
    axis.text.x          = element_text(angle = 45, hjust = 1, size = 7.5, face = "bold"),
    panel.grid.major.y   = element_line(color = "grey90", linewidth = 0.4),
    plot.caption         = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position      = "bottom",
    legend.box           = "horizontal",
    legend.box.spacing   = unit(0.1, "cm"),
    legend.background    = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title         = element_text(size = 8, face = "bold"),
    legend.key.size      = unit(0.4, "cm"),
    legend.text          = element_text(size = 7.5),
    legend.margin        = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Sektoral (Nasional).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 8, height = 6
)


## Prov -> Nasional (CAGR) ----
nat_prov <- pdrb_inv.cleaned %>%
  filter(kodename == "PDRB Total") %>%
  select(-c(klasifikasi)) %>%
  group_by(Code_Prov, Prov_nama, Pulau) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop")

nat_prov_total_base <- sum(nat_prov[[as.character(cagr_start)]], na.rm = TRUE)

nat_prov <- nat_prov %>%
  mutate(
    cagr           = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    share_base     = .data[[as.character(cagr_start)]] / nat_prov_total_base,
    kontribusi     = share_base * cagr * 100,
    cagr_pct       = cagr * 100,
    kontribusi_rel = kontribusi / nat_pdrb * 100
  )

urutan_prov <- nat_prov %>% arrange(desc(kontribusi_rel)) %>% pull(Prov_nama)
nat_prov <- nat_prov %>% mutate(Prov_nama = factor(Prov_nama, levels = urutan_prov))

right_max_prov <- 40
scale_factor_prov <- max(nat_prov$cagr_pct, na.rm = TRUE) / right_max_prov

pulau_colors <- c(
  "Bali-Nusa Tenggara" = "#D9042B",
  "Jawa"               = "#F2509C",
  "Kalimantan"         = "#062E4C",
  "Maluku-Papua"       = "#46A694",
  "Sulawesi"           = "#30726A",
  "Sumatera"           = "#F2E6CE"
)

nat_prov %>%
  ggplot(aes(x = Prov_nama)) +
  geom_col(aes(y = cagr_pct, fill = Pulau), width = 0.7) +
  geom_hline(yintercept = nat_pdrb, linetype = "dashed", color = "grey40", linewidth = 0.4) +
  geom_line(aes(y = kontribusi_rel * scale_factor_prov, group = 1),
            color = "#F59072", linewidth = 0.8) +
  geom_point(aes(y = kontribusi_rel * scale_factor_prov),
             color = "#F59072", size = 2) +
  scale_fill_manual(name = "Pulau", values = pulau_colors) +
  scale_y_continuous(
    name     = "CAGR Aktual (%)",
    labels   = function(x) paste0(x, "%"),
    expand   = expansion(mult = c(0, 0.04)),
    sec.axis = sec_axis(
      ~ . / scale_factor_prov,
      name   = "Kontribusi thd. Pertumbuhan Nasional (%)",
      breaks = seq(0, right_max_prov, by = 10),
      labels = function(x) paste0(x, "%")
    )
  ) +
  labs(
    title   = "CAGR Provinsi dan Kontribusi terhadap Pertumbuhan PDB Nasional, 2022–2025",
    x       = NULL,
    caption = paste0(
      "Sumber: BPS, diolah.\n",
      "Bar chart: CAGR aktual provinsi (y-axis kiri) | Line chart: % kontribusi provinsi thd. pertumbuhan PDB Nasional (y-axis kanan).\n",
      "Kontribusi = bobot PDRB provinsi tahun dasar (2022) × CAGR sektor. Garis putus-putus = CAGR PDB Nasional."
    )
  ) +
  theme_classic(base_size = 10) +
  theme(
    plot.title           = element_text(face = "bold", size = 11),
    axis.line.x          = element_blank(),
    axis.ticks.x         = element_blank(),
    axis.text.x          = element_text(angle = 45, hjust = 1, size = 7, face = "bold"),
    panel.grid.major.y   = element_line(color = "grey90", linewidth = 0.4),
    plot.caption         = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position      = "bottom",
    legend.box           = "horizontal",
    legend.box.spacing   = unit(0.1, "cm"),
    legend.background    = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title         = element_text(size = 8, face = "bold"),
    legend.key.size      = unit(0.4, "cm"),
    legend.text          = element_text(size = 7.5),
    legend.margin        = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Provinsi (Nasional).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 10, height = 6
)


## Prov -> Pulau  [Output terpisah per Pulau] (CAGR) ----
# Data: kontribusi tiap provinsi terhadap pertumbuhan pulaunya
prov_pulau <- pdrb_inv.cleaned %>%
  filter(kodename == "PDRB Total") %>%
  group_by(Pulau, Prov_nama) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  group_by(Pulau) %>%
  mutate(
    total_base = sum(.data[[as.character(cagr_start)]], na.rm = TRUE),
    cagr_prov  = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    share_base = .data[[as.character(cagr_start)]] / total_base,
    kontribusi = share_base * cagr_prov * 100
  ) %>%
  ungroup()

# CAGR per pulau untuk subtitle tiap chart
cagr_pulau <- pulau %>%
  filter(kodename == "PDRB Total") %>%
  select(Pulau, cagr) %>%
  mutate(label_cagr = sprintf("CAGR PDRB: %.1f%%", cagr * 100))

# Palet warna pulau (sesuai palet section sebelumnya)
pulau_colors <- c(
  "Bali-Nusra"   = "#2C3E50",
  "Jawa"         = "#C0392B",
  "Kalimantan"   = "#27AE60",
  "Maluku-Papua" = "#8E44AD",
  "Sulawesi"     = "#D35400",
  "Sumatera"     = "#2980B9"
)

# Urutan panel: kiri-atas ke kanan-bawah (geografis barat ke timur)
urutan_panel <- c("Sumatera", "Jawa", "Bali-Nusra", "Kalimantan", "Sulawesi", "Maluku-Papua")

# Fungsi satu chart per pulau
make_prov_pulau_plot <- function(nama_pulau) {
  df <- prov_pulau %>%
    filter(Pulau == nama_pulau) %>%
    arrange(kontribusi) %>%
    mutate(Prov_nama = factor(Prov_nama, levels = unique(Prov_nama)))

  sub_label <- cagr_pulau %>% filter(Pulau == nama_pulau) %>% pull(label_cagr)

  ggplot(df, aes(x = Prov_nama, y = kontribusi)) +
    geom_col(width = 0.7, fill = pulau_colors[[nama_pulau]]) +
    coord_flip() +
    scale_y_continuous(
      labels = function(x) paste0(x, "%"),
      expand = expansion(mult = c(0.05, 0.1))
    ) +
    labs(title = nama_pulau, subtitle = sub_label, x = NULL, y = "Kontribusi (pp)") +
    theme_classic(base_size = 9) +
    theme(
      plot.title         = element_text(face = "bold", size = 10, hjust = 0.5),
      plot.subtitle      = element_text(size = 8, hjust = 0.5, color = "grey40"),
      axis.text.y        = element_text(size = 7),
      axis.line.y        = element_blank(),
      axis.ticks.y       = element_blank(),
      panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3),
      legend.position    = "none"
    )
}

# Susun 6 chart, 2 baris × 3 kolom
plot_list_prov_pulau <- lapply(urutan_panel, make_prov_pulau_plot)

combined_prov_pulau <- wrap_plots(plot_list_prov_pulau, nrow = 2) +
  plot_annotation(
    caption = "Sumber: BPS, diolah. Kontribusi = bobot PDRB provinsi tahun dasar (2022) × CAGR provinsi (thd. total pulau).",
    theme   = theme(plot.caption = element_text(color = "grey50", size = 8, hjust = 0))
  )

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Provinsi (Pulau).png",
  plot     = combined_prov_pulau, dpi = 300, units = "in", width = 10, height = 8
)


## Sektoral -> Pulau (Klasifikasi:sektor) [Output terpisah per Pulau, lalu dimerge jadi satu sesuai urutan] (CAGR) ----
# Data: kontribusi sektoral per pulau
sektor_pulau <- pdrb_inv.cleaned %>%
  filter(klasifikasi == "sektor") %>%
  select(-c(Code_Prov, Prov_nama, klasifikasi)) %>%
  group_by(Pulau, kodename) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  left_join(col_names %>% select(sect_name, sect_klas_megasektor),
            by = c("kodename" = "sect_name")) %>%
  group_by(Pulau) %>%
  mutate(
    total_base = sum(.data[[as.character(cagr_start)]], na.rm = TRUE),
    cagr_sekt  = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    share_base = .data[[as.character(cagr_start)]] / total_base,
    kontribusi = share_base * cagr_sekt * 100
  ) %>%
  ungroup()
# (cagr_pulau & urutan_panel sudah didefinisikan di subsection Prov -> Pulau)

# Fungsi satu chart per pulau
make_sektor_pulau_plot <- function(nama_pulau) {
  df <- sektor_pulau %>%
    filter(Pulau == nama_pulau) %>%
    arrange(kontribusi) %>%
    mutate(kodename = factor(kodename, levels = unique(kodename)))

  sub_label <- cagr_pulau %>% filter(Pulau == nama_pulau) %>% pull(label_cagr)

  ggplot(df, aes(x = kodename, y = kontribusi, fill = sect_klas_megasektor)) +
    geom_col(width = 0.7) +
    geom_vline(xintercept = 0, color = "grey60", linewidth = 0.3) +
    coord_flip() +
    scale_fill_manual(name = "Megasektor", values = mega_colors, na.value = "grey70") +
    scale_y_continuous(
      labels = function(x) paste0(x, "%"),
      expand = expansion(mult = c(0.05, 0.1))
    ) +
    labs(title = nama_pulau, subtitle = sub_label, x = NULL, y = "Kontribusi (pp)") +
    theme_classic(base_size = 9) +
    theme(
      plot.title         = element_text(face = "bold", size = 10, hjust = 0.5),
      plot.subtitle      = element_text(size = 8, hjust = 0.5, color = "grey40"),
      axis.text.y        = element_text(size = 7),
      axis.line.y        = element_blank(),
      axis.ticks.y       = element_blank(),
      panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3),
      legend.position    = "none"
    )
}

# Buat 6 chart, susun 2 baris × 3 kolom, legend bersama di bawah
plot_list_sektor_pulau <- lapply(urutan_panel, make_sektor_pulau_plot)

combined_sektor_pulau <- wrap_plots(plot_list_sektor_pulau, nrow = 2) +
  plot_layout(guides = "collect") +
  plot_annotation(
    caption = "Sumber: BPS, diolah. Kontribusi = bobot PDRB sektoral (2022) × CAGR sektor.",
    theme   = theme(plot.caption = element_text(color = "grey50", size = 8, hjust = 0))
  ) &
  theme(
    legend.position    = "bottom",
    legend.box         = "horizontal",
    legend.background  = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
    legend.title       = element_text(size = 8, face = "bold"),
    legend.key.size    = unit(0.4, "cm"),
    legend.text        = element_text(size = 7.5),
    legend.margin      = margin(3, 5, 3, 5)
  )

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Sektoral (Pulau).png",
  plot     = combined_sektor_pulau, dpi = 300, units = "in", width = 10, height = 8
)


## Sektoral -> Prov (Klasifikasi:megasector) (CAGR) ----
# Stacked bar (1 bar per provinsi), segmen = kontribusi (pp), label = share of growth (%).
# Helper dipakai 2x (megasektor & sektor top-3). Memakai geom_rect + posisi label manual
# agar segmen negatif dan tandanya presisi (position_stack salah menempatkan nilai negatif).
# df wajib punya kolom: Prov_nama, grp (factor fill), kontribusi (pp), cagr_prov, share_growth
plot_kontribusi_stack <- function(df, prov_levels, fill_values, fill_name,
                                  judul, caption_txt, legend_pos) {
  d <- df %>%
    mutate(y = as.integer(factor(Prov_nama, levels = prov_levels))) %>%
    arrange(y, grp) %>%
    group_by(Prov_nama) %>%
    mutate(
      cum_pos = cumsum(pmax(kontribusi, 0)),
      cum_neg = cumsum(pmin(kontribusi, 0)),
      xmax    = ifelse(kontribusi >= 0, cum_pos, cum_neg - kontribusi),
      xmin    = ifelse(kontribusi >= 0, cum_pos - kontribusi, cum_neg),
      xmid    = (xmin + xmax) / 2
    ) %>%
    ungroup() %>%
    mutate(
      # warna label adaptif: terang di segmen gelap, gelap di segmen terang
      fill_hex = fill_values[as.character(grp)],
      lum      = (col2rgb(fill_hex)["red", ]   * 299 +
                  col2rgb(fill_hex)["green", ] * 587 +
                  col2rgb(fill_hex)["blue", ]  * 114) / 1000,
      lbl_col  = ifelse(lum > 150, "grey15", "white"),
      lbl_x    = pmax(xmid, -9.2),                                       # nilai ekstrem di-cut, label tetap tampak
      lbl_txt  = ifelse(abs(kontribusi) >= 0.1, sprintf("%.0f%%", share_growth), "")
    )

  # CAGR provinsi di ujung kanan (sejajar ujung segmen positif)
  cagr_lbl <- d %>%
    group_by(y) %>%
    summarise(x_pos = max(xmax, 0), cagr_prov = first(cagr_prov), .groups = "drop")

  ggplot(d) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = y - 0.4, ymax = y + 0.4, fill = grp)) +
    geom_vline(xintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_text(aes(x = lbl_x, y = y, label = lbl_txt, color = lbl_col), size = 2) +
    geom_text(data = cagr_lbl, aes(x = x_pos + 0.5, y = y, label = sprintf("%.1f%%", cagr_prov)),
              hjust = 0, size = 2.5, fontface = "bold", color = "grey20") +
    scale_fill_manual(name = fill_name, values = fill_values) +
    scale_color_identity() +
    scale_y_continuous(breaks = seq_along(prov_levels), labels = prov_levels,
                       expand = expansion(mult = c(0.01, 0.01))) +
    scale_x_continuous(labels = function(x) paste0(x, "%"),
                       expand = expansion(mult = c(0.02, 0.18))) +
    coord_cartesian(xlim = c(-10, NA)) +
    labs(title = judul, x = "Kontribusi terhadap pertumbuhan (pp)", y = NULL, caption = caption_txt) +
    theme_classic(base_size = 10) +
    theme(
      plot.title         = element_text(face = "bold", size = 11),
      axis.text.y        = element_text(size = 7, face = "bold"),
      axis.line.y        = element_blank(),
      axis.ticks.y       = element_blank(),
      panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
      plot.caption         = element_text(color = "grey50", size = 8, hjust = 0),
      legend.position      = legend_pos,
      legend.justification = "center",
      legend.background    = element_rect(fill = "white", color = "grey80", linewidth = 0.3),
      legend.title         = element_text(size = 8, face = "bold"),
      legend.key.size      = unit(0.4, "cm"),
      legend.text          = element_text(size = 7.5),
      legend.margin        = margin(3, 5, 3, 5)
    )
}

# --- Data: kontribusi megasektor per provinsi ---
# share of growth dibagi |CAGR| agar tanda label konsisten dengan posisi segmen (lihat Kaltim: CAGR negatif)
prov_mega <- pdrb_inv.cleaned %>%
  filter(kodename %in% c("Primer", "Sekunder", "Tersier", "Kuarterner")) %>%
  group_by(Prov_nama, kodename) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  group_by(Prov_nama) %>%
  mutate(
    cagr_mega    = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    kontribusi   = (.data[[as.character(cagr_start)]] / sum(.data[[as.character(cagr_start)]])) * cagr_mega * 100,
    cagr_prov    = sum(kontribusi),
    share_growth = kontribusi / pmax(abs(cagr_prov), 0.01) * 100
  ) %>%
  ungroup() %>%
  mutate(grp = factor(kodename, levels = c("Primer", "Sekunder", "Tersier", "Kuarterner")))

# Urutan provinsi: CAGR terbesar di atas
urutan_prov_mega <- prov_mega %>% distinct(Prov_nama, cagr_prov) %>% arrange(cagr_prov) %>% pull(Prov_nama)

plot_kontribusi_stack(
  df          = prov_mega,
  prov_levels = urutan_prov_mega,
  fill_values = mega_colors,
  fill_name   = "Megasektor",
  judul       = "Kontribusi Megasektor terhadap Pertumbuhan PDRB Provinsi, 2022–2025",
  caption_txt = paste0(
    "Sumber: BPS, diolah. Angka di tiap segmen = share of growth (% terhadap |CAGR| provinsi).\n",
    "Angka di ujung kanan = CAGR PDRB provinsi."
  ),
  legend_pos  = "bottom"
)

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Megasektor (Provinsi).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 8, height = 8
)


## Sektoral -> Prov (Top-3 sektor + Lainnya) (CAGR) ----
# Sama dengan chart megasektor, tapi isi = 3 sektor teratas per provinsi, sisanya "Lainnya".
prov_sektor <- pdrb_inv.cleaned %>%
  filter(klasifikasi == "sektor") %>%
  group_by(Prov_nama, kodename) %>%
  summarise(across(`2017`:`2025`, ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  group_by(Prov_nama) %>%
  mutate(
    cagr_sekt  = (`2025` / .data[[as.character(cagr_start)]])^(1 / (2025 - cagr_start)) - 1,
    kontribusi = (.data[[as.character(cagr_start)]] / sum(.data[[as.character(cagr_start)]])) * cagr_sekt * 100
  ) %>%
  ungroup()

# Top-3 kontribusi per provinsi; sisanya -> "Lainnya"
prov_sektor_grp <- prov_sektor %>%
  group_by(Prov_nama) %>%
  mutate(rk = rank(-kontribusi, ties.method = "first"),
         sektor_grp = ifelse(rk <= 3, kodename, "Lainnya")) %>%
  group_by(Prov_nama, sektor_grp) %>%
  summarise(kontribusi = sum(kontribusi), .groups = "drop") %>%
  group_by(Prov_nama) %>%
  mutate(cagr_prov    = sum(kontribusi),
         share_growth = kontribusi / pmax(abs(cagr_prov), 0.01) * 100) %>%
  ungroup()

# Warna sektor diturunkan dari basis hue palet pulau (hijau #27AE60, biru #2980B9, oranye #D35400);
# tiap famili megasektor diberi gradasi terang->gelap
fam_of   <- c(Primer = "green", Sekunder = "blue", Tersier = "orange", Kuarterner = "orange")
fam_ramp <- list(
  green  = c("#A7DCBB", "#14663A"),
  blue   = c("#A3C9E3", "#184D70"),
  orange = c("#F0A878", "#7E3200")
)

# Urut sektor: per famili (hijau->biru->oranye), lalu kontribusi terbesar; "Lainnya" terakhir
sekt_tot <- prov_sektor_grp %>%
  filter(sektor_grp != "Lainnya") %>%
  group_by(sektor_grp) %>% summarise(tot = sum(kontribusi), .groups = "drop") %>%
  left_join(col_names %>% distinct(sect_name, sect_klas_megasektor),
            by = c("sektor_grp" = "sect_name")) %>%
  mutate(fam = fam_of[sect_klas_megasektor]) %>%
  arrange(match(fam, c("green", "blue", "orange")), desc(tot))

sekt_levels <- c(sekt_tot$sektor_grp, "Lainnya")

sekt_colors <- unlist(lapply(c("green", "blue", "orange"), function(f) {
  s <- sekt_tot$sektor_grp[sekt_tot$fam == f]
  if (length(s) == 0) return(NULL)
  setNames(colorRampPalette(fam_ramp[[f]])(length(s)), s)
}))
sekt_colors["Lainnya"] <- "grey65"

prov_sektor_grp <- prov_sektor_grp %>%
  mutate(grp = factor(sektor_grp, levels = sekt_levels))

plot_kontribusi_stack(
  df          = prov_sektor_grp,
  prov_levels = urutan_prov_mega,
  fill_values = sekt_colors,
  fill_name   = "Sektor",
  judul       = "Komposisi Kontribusi Sektoral (Top-3) terhadap Pertumbuhan PDRB Provinsi, 2022–2025",
  caption_txt = paste0(
    "Sumber: BPS, diolah. Tiap bar memuat 3 sektor terbesar per provinsi; sisanya digabung 'Lainnya'.\n",
    "Angka di tiap segmen = share of growth (% terhadap |CAGR| provinsi). Angka di ujung kanan = CAGR PDRB provinsi."
  ),
  legend_pos  = c(0.84, 0.5)
)

ggsave(
  filename = "01 Data/BKPM/output/Kontribusi Sektoral Top3 (Provinsi).png",
  plot     = last_plot(), dpi = 300, units = "in", width = 8, height = 8
)


# 5) Data viz: Hubungan Investasi (scatter) ----
# CAGR per provinsi (dalam %), wide per variabel investasi & PDRB
prov_cagr <- provinsi %>%
  filter(kodename %in% c("PMA", "PMDN", "PMA + PMDN", "PMTB", "PDRB Total")) %>%
  mutate(cagr = cagr * 100) %>%
  select(Pulau, Prov_nama, kodename, cagr) %>%
  pivot_wider(names_from = kodename, values_from = cagr)

# National refs (%) tambahan untuk garis bantu
nat_pma  <- national %>% filter(kodename == "PMA")  %>% pull(cagr) * 100
nat_pmdn <- national %>% filter(kodename == "PMDN") %>% pull(cagr) * 100

# Helper: scatter CAGR x vs y, titik per pulau, fit kuadratik, R^2 di subtitle.
# vline/hline opsional (garis bantu CAGR nasional).
scatter_cagr <- function(df, xvar, yvar, xlab, ylab, vline = NA, hline = NA, drop_outliers = FALSE) {
  dd  <- df %>% transmute(Pulau, x = .data[[xvar]], y = .data[[yvar]]) %>% filter(!is.na(x), !is.na(y))
  if (drop_outliers) {                                   # buang outlier (aturan IQR 1.5x) pada x dan y
    in_bound <- function(v) { q <- quantile(v, c(.25, .75)); r <- 1.5 * diff(q); v >= q[1] - r & v <= q[2] + r }
    dd <- dd %>% filter(in_bound(x), in_bound(y))
  }
  r2  <- summary(lm(y ~ poly(x, 2), data = dd))$r.squared

  ggplot(dd, aes(x = x, y = y)) +
    (if (!is.na(vline)) geom_vline(xintercept = vline, linetype = "dashed", color = "grey55", linewidth = 0.3)) +
    (if (!is.na(hline)) geom_hline(yintercept = hline, linetype = "dashed", color = "grey55", linewidth = 0.3)) +
    geom_smooth(method = "lm", formula = y ~ poly(x, 2), se = TRUE,
                color = "grey25", fill = "grey85", linewidth = 0.6) +
    geom_point(aes(color = Pulau), size = 2, alpha = 0.9) +
    scale_color_manual(name = "Pulau", values = pulau_colors) +
    scale_x_continuous(labels = function(z) paste0(z, "%")) +
    scale_y_continuous(labels = function(z) paste0(z, "%")) +
    labs(subtitle = sprintf("R² = %.2f", r2), x = xlab, y = ylab) +
    theme_classic(base_size = 10) +
    theme(
      plot.subtitle    = element_text(color = "grey40", size = 9),
      panel.grid.major = element_line(color = "grey92", linewidth = 0.3)
    )
}

## Investasi vs PMTB ----
f1a <- scatter_cagr(prov_cagr, "PMA",        "PMTB", "CAGR PMA (%)",         "CAGR PMTB (%)")
f1b <- scatter_cagr(prov_cagr, "PMDN",       "PMTB", "CAGR PMDN (%)",        "CAGR PMTB (%)")
f1c <- scatter_cagr(prov_cagr, "PMA + PMDN", "PMTB", "CAGR PMA + PMDN (%)",  "CAGR PMTB (%)")

fig1 <- (f1a | f1b | f1c) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title   = "Hubungan CAGR Investasi Swasta dan PMTB per Provinsi, 2022–2025",
    caption = "Sumber: BPS & BKPM, diolah. Garis tebal = fit kuadratik (± selang kepercayaan).",
    theme   = theme(plot.title   = element_text(face = "bold", size = 12),
                    plot.caption = element_text(color = "grey50", size = 8, hjust = 0))
  ) &
  theme(legend.position = "right", legend.direction = "vertical",
        legend.title = element_text(size = 8, face = "bold"),
        legend.text = element_text(size = 7.5), legend.key.size = unit(0.4, "cm"))

ggsave("01 Data/BKPM/output/Scatter Investasi vs PMTB.png", fig1, dpi = 300, units = "in", width = 13, height = 5)

## Investasi vs PDRB (dengan garis bantu CAGR nasional) ----
f2a <- scatter_cagr(prov_cagr, "PMA",        "PDRB Total", "CAGR PMA (%)",        "CAGR PDRB (%)", vline = nat_pma,  hline = nat_pdrb)
f2b <- scatter_cagr(prov_cagr, "PMDN",       "PDRB Total", "CAGR PMDN (%)",       "CAGR PDRB (%)", vline = nat_pmdn, hline = nat_pdrb)
f2c <- scatter_cagr(prov_cagr, "PMA + PMDN", "PDRB Total", "CAGR PMA + PMDN (%)", "CAGR PDRB (%)", vline = nat_inv,  hline = nat_pdrb)
f2d <- scatter_cagr(prov_cagr, "PMTB",       "PDRB Total", "CAGR PMTB (%)",       "CAGR PDRB (%)", vline = nat_pmtb, hline = nat_pdrb)

fig2 <- (f2a | f2b) / (f2c | f2d) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title   = "Hubungan CAGR Investasi dan PDRB per Provinsi, 2022–2025",
    caption = "Sumber: BPS & BKPM, diolah. Garis putus-putus = CAGR nasional (investasi & PDB). Garis tebal = fit kuadratik.",
    theme   = theme(plot.title   = element_text(face = "bold", size = 12),
                    plot.caption = element_text(color = "grey50", size = 8, hjust = 0))
  ) &
  theme(legend.position = "right", legend.direction = "vertical",
        legend.title = element_text(size = 8, face = "bold"),
        legend.text = element_text(size = 7.5), legend.key.size = unit(0.4, "cm"))

ggsave("01 Data/BKPM/output/Scatter Investasi vs PDRB.png", fig2, dpi = 300, units = "in", width = 11, height = 9)

## Investasi vs PDRB (tanpa outlier) ----
f3a <- scatter_cagr(prov_cagr, "PMA",        "PDRB Total", "CAGR PMA (%)",        "CAGR PDRB (%)", vline = nat_pma,  hline = nat_pdrb, drop_outliers = TRUE)
f3b <- scatter_cagr(prov_cagr, "PMDN",       "PDRB Total", "CAGR PMDN (%)",       "CAGR PDRB (%)", vline = nat_pmdn, hline = nat_pdrb, drop_outliers = TRUE)
f3c <- scatter_cagr(prov_cagr, "PMA + PMDN", "PDRB Total", "CAGR PMA + PMDN (%)", "CAGR PDRB (%)", vline = nat_inv,  hline = nat_pdrb, drop_outliers = TRUE)
f3d <- scatter_cagr(prov_cagr, "PMTB",       "PDRB Total", "CAGR PMTB (%)",       "CAGR PDRB (%)", vline = nat_pmtb, hline = nat_pdrb, drop_outliers = TRUE)

fig3 <- (f3a | f3b) / (f3c | f3d) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title   = "Hubungan CAGR Investasi dan PDRB per Provinsi, 2022–2025 (tanpa outlier)",
    caption = "Sumber: BPS & BKPM, diolah. Outlier dibuang (aturan IQR 1,5x). Garis putus-putus = CAGR nasional. Garis tebal = fit kuadratik.",
    theme   = theme(plot.title   = element_text(face = "bold", size = 12),
                    plot.caption = element_text(color = "grey50", size = 8, hjust = 0))
  ) &
  theme(legend.position = "right", legend.direction = "vertical",
        legend.title = element_text(size = 8, face = "bold"),
        legend.text = element_text(size = 7.5), legend.key.size = unit(0.4, "cm"))

ggsave("01 Data/BKPM/output/Scatter Investasi vs PDRB (tanpa outlier).png", fig3, dpi = 300, units = "in", width = 11, height = 9)

