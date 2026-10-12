#*** Arsip: disalin dari Laptop CISDI data/climate-volatility-structural-change/Code/01_Recalc Labor Dataset (Sakernas).R (21 Agu 2026)
#*** Upah, pekerja, jam kerja per agri/nonagri x usia x pendidikan. Catatan: baris names(sak_age) memanggil df_wide yang tidak pernah dibuat.
#*** Butuh mikrodata Sakernas 2017-2024 di path E:/ (drive Windows) — belum ada di Mac.


#***************************************************************#
# script perhitungan ulang variabel ketenagakerjaan yang relevan
#***************************************************************#

#***************************************************************#
# |> Glossarium data
# kode     = kode kabupaten/kota (pre-pemekaran exc: 2024)
# weight   = pembobot (integer)
# work     = penduduk bekerja
# work_add = penduduk bekerja tambahan
# lapus    = utama agri/non-agri
# jamkerja = rata-rata jam seluruh pekerjaan kerja per hari ( 5 hari & 260 hari kerja)
# upah     = total upah (uang/barang/lembur/tunjangan/dst) 
# usia     = kelompok usia (6 kategori)
# educ     = tingkat pendidikan (3 kategori)
#***************************************************************#

#*---|> clean env
rm(list=ls())

#*---|> load packages
library(plm)
library(broom)
library(dplyr)
library(purrr)
library(ggplot2)
library(stringr)
library(rio)
library(dplyr)
library(tidyverse)

#*---|> Sakernas 2017
sak17 <- import("E:/dataset/BPS/SAKERNAS/Sakernas 2017/skrnas17.dta")

#*#-> Generate kode kabupaten 
sak17 <- sak17 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak17 <- sak17 %>% 
  mutate(
    activity_work     = if_else(b5_r5a1 == 1 | b5_r7a == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(b5_r6   == 1 | b5_r7b == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(b5_r38a == 1|b5_r38b == 1, 1L, 0L),
    lapus_int         = b5_r23_17,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = b5_r43b/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(b5_r30b1,b5_r30b2)),na.rm = T), 
    usia_int          = b4_k6,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = b5_r1a,
    educ              = case_when(educ_int %in% c(1:4)   ~ 1,
                                  educ_int %in% c(5:11)  ~ 2,
                                  educ_int %in% c(12:16) ~ 3,),
    weight            = weight,
    tahun             = 2017L)

sak17_cln <- sak17 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2018
sak18 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2018/Sakernas 2018 Aug/SAK082018/DATA/sakernas_201808_15+_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak18 <- sak18 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak18 <- sak18 %>% 
  mutate(
    activity_work     = if_else(B5_R5A1 == 1 | B5_R7A  == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(B5_R6   == 1 | B5_R7B  == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(B5_R40A == 1|B5_R40B == 1, 1L, 0L),
    lapus_int         = B5_R23_SEK,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = B5_R47B/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(B5_R31B1,B5_R31B2)),na.rm = T), 
    usia_int          = B4_K8,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = B5_R1A,
    educ              = case_when(educ_int %in% c(1:4)   ~ 1,
                                  educ_int %in% c(5:11)  ~ 2,
                                  educ_int %in% c(12:16) ~ 3,),
    weight            = FINAL_WEIG,
    tahun             = 2018L)


sak18_cln <- sak18 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2019
sak19 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2019/sak_201908_15+.dta")

#*#-> Generate kode kabupaten 
sak19 <- sak19 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak19 <- sak19 %>% 
  mutate(
    activity_work     = if_else(b5_r5a1 == 1 | b5_r7a  == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(b5_r6   == 1 | b5_r7b  == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(b5_r37a == 1|b5_r37b == 1, 1L, 0L),
    lapus_int         = b5_r20_kat,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = b5_r44b/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(b5_r28b1,b5_r28b2)),na.rm = T), 
    usia_int          = b4_k8,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = b5_r1a,
    educ              = case_when(educ_int %in% c(1:4)   ~ 1,
                                  educ_int %in% c(5:11)  ~ 2,
                                  educ_int %in% c(12:16) ~ 3,),
    weight            = weightr_sp,
    tahun             = 2019L)

sak19_cln <- sak19 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))

#*---|> Sakernas 2020
sak20 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2020/sak2020_8.dta")

#*#-> Generate kode kabupaten 
sak20 <- sak20 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak20 <- sak20 %>% 
  mutate(
    activity_work     = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(r10a == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(r20a == 1, 1L, 0L),
    lapus_int         = r13a_kateg,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = r20b/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(r14a1,r14a2)),na.rm = T), 
    usia_int          = k6,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = r6a,
    educ              = case_when(educ_int %in% c(1:2)   ~ 1,
                                  educ_int %in% c(3:5)  ~ 2,
                                  educ_int %in% c(6:8) ~ 3,),
    weight            = final_weig,
    tahun             = 2020L)

sak20_cln <- sak20 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2021
sak21 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2021/sak21auglabeltrain.dta")

#*#-> Generate kode kabupaten 
sak21 <- sak21 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak21 <- sak21 %>% 
  mutate(
    activity_work     = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(r10a == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(r27a == 1, 1L, 0L),
    lapus_int         = kbli2020_1,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = r27b_jml/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(r14a_uang,r14a2_brg)),na.rm = T), 
    usia_int          = k6,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = r6a,
    educ              = case_when(educ_int %in% c(1:2)  ~ 1,
                                  educ_int %in% c(3:6)  ~ 2,
                                  educ_int %in% c(7:12) ~ 3,),
    weight            = final_weig,
    tahun             = 2021L)

sak21_cln <- sak21 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2022
sak22 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2022/Survei Angkatan Kerja Nasional 2022 Agustus/Sakernas22_Agustus.dta")

#*#-> Generate kode kabupaten 
sak22 <- sak22 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak22 <- sak22 %>% 
  mutate(
    activity_work     = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(R10 == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(R28A == 1, 1L, 0L),
    lapus_int         = R41AKATEGO,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = R28B_JML/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(R15A_UANG,R15A_BRG)),na.rm = T), 
    usia_int          = K6,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = R6A,
    educ              = case_when(educ_int %in% c(1:2)  ~ 1,
                                  educ_int %in% c(3:6)  ~ 2,
                                  educ_int %in% c(7:12) ~ 3,),
    weight            = WEIGHT,
    tahun             = 2022L)

sak22_cln <- sak22 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2023
sak23 <- import("E:/dataset/BPS/SAKERNAS/SAKERNAS 2023/Sakernas Agustus 2023/SAKERNAS_08-2023/sak202308_15_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak23 <- sak23 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak23 <- sak23 %>% 
  mutate(
    activity_work     = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(R10 == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(R28A == 1, 1L, 0L),
    lapus_int         = R14AKATEGO,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = R28B_JML/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(R15_UANG,R15_BRG)),na.rm = T), 
    usia_int          = K9,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = R6A,
    educ              = case_when(educ_int %in% c(1:2)  ~ 1,
                                  educ_int %in% c(3:6)  ~ 2,
                                  educ_int %in% c(7:12) ~ 3,),
    weight            = as.numeric(WEIGHTR),
    tahun             = 2023L)

sak23_cln <- sak23 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))


#*---|> Sakernas 2024
sak24 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2024/[GABUNGAN] Sakernas Agustus 2024.dta")

#*#-> Generate kode kabupaten 
sak24 <- sak24 %>% mutate(kode = paste0(KODE_PROV,KODE_KAB))

#*#-> Identifying population in the Labor Force
sak24 <- sak24 %>% 
  mutate(
    activity_work     = if_else(R10A == 1 | R10B == 1 | R10C == 1, 1L, 0L, missing = 0L),
    temp_notwork      = if_else(R11 == 1, 1L, 0L, missing = 0L),
    work              = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    work_add          = if_else(R29 == 1, 1L, 0L),
    lapus_int         = R15A_KBLI2,
    lapus             = case_when(lapus_int == 1 ~ "agri",TRUE ~ "nonagri"),
    jamkerja          = R35B/5*260,
    jamkerja          = ifelse(jamkerja == 0,NA,jamkerja),
    upah              = rowSums(across(c(R16_1,R16_2)),na.rm = T), 
    usia_int          = K10,
    usia              = case_when(usia_int %in% c(15:25) ~ "15_25",
                                  usia_int %in% c(26:35) ~ "26_35",
                                  usia_int %in% c(36:45) ~ "36_45",
                                  usia_int %in% c(46:55) ~ "46_55",
                                  usia_int %in% c(56:65) ~ "56_65",
                                  usia_int >= 66         ~ "66_up"),
    educ_int          = R6A,
    educ              = case_when(educ_int %in% c(1:2)  ~ 1,
                                  educ_int %in% c(3:6)  ~ 2,
                                  educ_int %in% c(7:12) ~ 3,),
    weight            = WEIGHT,
    tahun             = 2024L)

sak24_cln <- sak24 %>% filter(work == 1) %>% filter(!is.na(usia)) %>%
  dplyr::select(., c(tahun,kode,weight,work,work_add,lapus,jamkerja,upah,usia,educ))

#*#-> Adjusting relasi BPS 38 provinsi -> 34 provinsi
relasibps <- import("Input/Relasi BPS 34-38.xlsx")
relasibps <- relasibps %>% mutate(kode = as.character(kode), 
                                  ADM2_PCODE = as.character(ADM2_PCODE))

sak24_cln <- left_join(sak24_cln,relasibps,by=c("kode"))
sak24_cln <- sak24_cln %>% dplyr::select(., -c(kode)) %>% rename(kode = ADM2_PCODE)


sak1724 <- rbind(sak17_cln,sak18_cln,sak19_cln,sak20_cln,sak21_cln,sak22_cln,sak23_cln,sak24_cln)

#*---|> Aggregating by age (recalculating from SAKERNAS_2017-2023_by age.dta)
sak_age <- sak1724 %>%
  group_by(tahun, kode, lapus, usia) %>%
  summarise(
    upah_w = weighted.mean(upah, weight, na.rm = TRUE),
    work_w = sum(work * weight, na.rm = TRUE),   # or weighted.mean — adjust as needed
    .groups = "drop"
  ) %>%
  # Step 2: Create combined lapus_usia key
  mutate(key = paste(lapus, usia, sep = "_")) %>%
  select(-lapus, -usia) %>%
  # Step 3: Pivot to wide
  pivot_wider(
    names_from  = key,
    values_from = c(upah_w, work_w),
    names_glue  = "{.value %>% sub('_w$', '', .)}_{key}"
  ) %>%
  # Step 4: Rename kode -> kode_kabkota
  rename(kode_kabkota = kode)

# Clean up column names: remove accidental double underscores
names(sak_age) <- gsub("__", "_", names(df_wide))

export(sak_age,"Input/bps data (cleaned)/SAKERNAS_2017-2024_by age [RECALC].csv")

#*---|> Aggregating by education
sak_educ <- sak1724 %>% 
  dplyr::select(., c(tahun, weight, kode, lapus, educ)) %>%
  mutate(educ_label = case_when(
    educ == 1 ~ "low_educ",
    educ == 2 ~ "mid_educ",
    educ == 3 ~ "high_educ"
  )) %>%
  group_by(tahun, kode, lapus, educ_label) %>%
  summarise(
    work = sum(weight, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(key = paste(lapus, educ_label, sep = "_")) %>%
  select(-lapus, -educ_label) %>%
  pivot_wider(
    names_from  = key,
    values_from = work,
    names_prefix = "work_"
  ) %>%
  rename(kode_kabkota = kode)

#*---|> Aggregating by average upah
#*sak_educ <- sak1724 %>% 
sak_lapus <- sak1724 %>% 
  dplyr::select(., c(tahun, weight, kode, lapus, upah, work_add, jamkerja, work)) %>%
  group_by(tahun, kode, lapus) %>%
  summarise(
    upah         = weighted.mean(upah, weight, na.rm = TRUE),
    work_add     = sum(work_add * weight, na.rm = TRUE),
    jamkerja_tot = sum(jamkerja * weight, na.rm = TRUE),
    jamkerja_avg = weighted.mean(jamkerja, weight, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from  = lapus,
    values_from = c(upah, work_add, jamkerja_tot, jamkerja_avg),
    names_glue  = "{lapus}_{.value}"   # <-- fix here
  ) %>%
  rename(kode_kabkota = kode)


sak_add <- left_join(sak_educ, sak_lapus, by=c("kode_kabkota","tahun")) %>% 
  mutate(across(everything(), ~replace_na(.x, 0)))

export(sak_add,"Input/bps data (cleaned)/SAKERNAS_2017-2024_educ additional workhrs wage.csv")

