#*** Arsip: disalin dari Laptop CISDI data/fisindep_precip/xx_sectoral_employment.R (21 Agu 2026)
#*** Tenaga kerja dan rata-rata upah per 17 lapangan usaha KBLI. Keluarannya = 01 Data/BKPM/processed/[13062026] Emp_upah.xlsx.
#*** Butuh mikrodata Sakernas 2017-2024 di path E:/ (drive Windows) — belum ada di Mac.


#***************************************************************#
# script perhitungan Labor Force Participation Rate (%/numbers)
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

#*---|> Sakernas 2017
sak17 <- import("E:/dataset/BPS/SAKERNAS/Sakernas 2017/skrnas17.dta")

#*#-> Generate kode kabupaten 
sak17 <- sak17 %>% mutate(kode = paste0(kode_prov, sprintf("%02d", kode_kab)))

#*#-> Identifying population in employment and defining sector/wage
sak17 <- sak17 %>%
  mutate(
    activity_work   = if_else(b5_r5a1 == 1 | b5_r7a == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(b5_r6   == 1 | b5_r7b == 1, 1L, 0L, missing = 0L),
    inemp           = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age             = b4_k6,
    lapus           = b5_r23_17,
    wage            = rowSums(across(c(b5_r30b1,b5_r30b2,b5_r30c11,b5_r30c12,b5_r30c21,b5_r30c22)), na.rm = TRUE)
  )

#*#-> Aggregation: Total Employment and Average Sectoral Wage
sak17_agr <- sak17 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * weight,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * weight 
  ) %>%
  group_by(tahun = 2017L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(weight[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )
#*---|> Sakernas 2018
sak18 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2018/Sakernas 2018 Aug/SAK082018/DATA/sakernas_201808_15+_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak18 <- sak18 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak18 <- sak18 %>%
  mutate(
    activity_work   = if_else(B5_R5A1 == 1 | B5_R7A  == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(B5_R6   == 1 | B5_R7B  == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = B4_K8,
    lapus = B5_R23_SEK,
    wage = rowSums(across(c(B5_R31B1,B5_R31B2,B5_R31C1,B5_R31C2)), na.rm = TRUE)
  )

#*#-> Aggregation: Total Employment and Average Sectoral Wage
sak18_agr <- sak18 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * FINAL_WEIG,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * FINAL_WEIG 
  ) %>%
  group_by(tahun = 2018L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(FINAL_WEIG[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )

#*---|> Sakernas 2019
sak19 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2019/sak_201908_15+.dta")

#*#-> Generate kode kabupaten 
sak19 <- sak19 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak19 <- sak19 %>%
  mutate(
    activity_work   = if_else(b5_r5a1 == 1 | b5_r7a  == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(b5_r6   == 1 | b5_r7b  == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = b4_k8,
    lapus = b5_r20_kat,
    wage = rowSums(across(c(b5_r28b1,b5_r28b2,b5_r28c1,b5_r28c2)), na.rm = TRUE)
  )


#*#-> Agreggating 
sak19_agr <- sak19 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * weightr_sp,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * weightr_sp 
  ) %>%
  group_by(tahun = 2019L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(weightr_sp[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )
#*---|> Sakernas 2020
sak20 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2020/sak2020_8.dta")

#*#-> Generate kode kabupaten 
sak20 <- sak20 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak20 <- sak20 %>%
  mutate(
    activity_work   = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(r10a == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = k6,
    lapus = r13a_kateg,
    wage = rowSums(across(c(r14a1,r14a2)), na.rm = TRUE)
  )

#*#-> Agreggating 
sak20_agr <- sak20 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * final_weig,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * final_weig 
  ) %>%
  group_by(tahun = 2020L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(final_weig[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )

#*---|> Sakernas 2021
sak21 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2021/sak21auglabeltrain.dta")

#*#-> Generate kode kabupaten 
sak21 <- sak21 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak21 <- sak21 %>%
  mutate(
    activity_work   = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(r10a == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = k6,
    lapus = kbli2020_1,
    wage = rowSums(across(c(r14a_uang,r14a2_brg)), na.rm = TRUE)
  )

#*#-> Agreggating 
sak21_agr <- sak21 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * final_weig,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * final_weig 
  ) %>%
  group_by(tahun = 2021L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(final_weig[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )

#*---|> Sakernas 2022
sak22 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2022/Survei Angkatan Kerja Nasional 2022 Agustus/Sakernas22_Agustus.dta")

#*#-> Generate kode kabupaten 
sak22 <- sak22 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak22 <- sak22 %>%
  mutate(
    activity_work   = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(R10 == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K6,
    lapus = R14AKATEGO,
    wage = rowSums(across(c(R15A_UANG,R15A_BRG)), na.rm = TRUE)
  )

#*#-> Agreggating 
sak22_agr <- sak22 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * WEIGHT,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * WEIGHT 
  ) %>%
  group_by(tahun = 2022L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(WEIGHT[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )

#*---|> Sakernas 2023 (PROBLEMATIK)
sak23 <- import("E:/dataset/BPS/SAKERNAS/SAKERNAS 2023/Sakernas Agustus 2023/SAKERNAS_08-2023/sak202308_15_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak23 <- sak23 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak23 <- sak23 %>%
  mutate(
    activity_work   = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(R10 == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K9,
    lapus = R14AKATE_A,
    wage = rowSums(across(c(R15_UANG,R15_BRG)), na.rm = TRUE)
  )

#*#-> Agreggating 
sak23_agr <- sak23 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * as.numeric(WEIGHTR),
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * as.numeric(WEIGHTR) 
  ) %>%
  group_by(tahun = 2023L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(as.numeric(WEIGHTR)[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )



#*---|> Sakernas 2024
# R50D = WAKTU TERBANYAK SEMINGGU TERAKHIR
# R10A = BEKERJA PALING SEDIKIT SATU JAM DALAM SEMINGGU TERAKHIR
# R10B = MELAKUKAN KEGIATAN UNTUK MEMPEROLEH PENGHASILAN PENDAPATAN UANG DALAM SEMINGGU TERAKHIR
# R10C = MEMBANTU KEGIATAN USAHA ATAU PEKERJAAN KELUARGA ORANG LAIN DALAM SEMINGGU TERAKHIR
# R11  = SEDANG TIDAK BEKERJA TIDAK MENJALANKAN USAHA DALAM SEMINGGU TERAKHIR
# R38A = MENCARI PEKERJAAN SEMINGGU TERAKHIR
# R39A = MENCARI PEKERJAAN SEBULAN TERAKHIR
# R42A = ALASAN UTAMA TIDAK MENCARI PEKERJAAN DAN TIDAK MEMPERSIAPKAN USAHA SEMINGGU TERAKHIR
# R43A = MAU MENERIMA JIKA ADA PENAWARAN PEKERJAAN SEMINGGU TERAKHIR
# K10  = UMUR

sak24 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2024/[GABUNGAN] Sakernas Agustus 2024.dta")

#*#-> Generate kode kabupaten 
sak24 <- sak24 %>% mutate(kode = paste0(KODE_PROV,KODE_KAB))

#*#-> Identifying population in the Labor Force
sak24 <- sak24 %>%
  mutate(
    activity_work   = if_else(R10A == 1 | R10B == 1 | R10C == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(R11 == 1, 1L, 0L, missing = 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K10,
    lapus = R15A_KBLI2,
    wage = rowSums(across(c(R16_1,R16_2)), na.rm = TRUE)
  )

#*#-> Agreggating 
sak24_agr <- sak24 %>%
  filter(age %in% 15:64) %>%
  mutate(
    inemp_W = inemp * WEIGHT,
    # Menghitung total upah tertimbang untuk rata-rata berbobot
    total_wage_W = wage * WEIGHT
  ) %>%
  group_by(tahun = 2024L, kode, lapus) %>%
  summarise(
    tenaga_kerja = sum(inemp_W, na.rm = TRUE),
    # Rata-rata upah tertimbang (weighted average) berdasarkan sektor & kabupaten
    rata_upah    = sum(total_wage_W, na.rm = TRUE) / sum(WEIGHT[!is.na(wage)], na.rm = TRUE),
    .groups = "drop"
  )

#*#-> Adjusting relasi BPS 38 provinsi -> 34 provinsi
relasibps <- import("Input/Relasi BPS 34-38.xlsx")
relasibps <- relasibps %>% mutate(kode = as.character(kode), 
                                  ADM2_PCODE = as.character(ADM2_PCODE))

sak24_agr <- left_join(sak24_agr,relasibps,by=c("kode"))
sak24_agr <- sak24_agr %>% dplyr::select(., -c(kode)) %>% rename(kode = ADM2_PCODE)


sak1724 <- rbind(sak17_agr,sak18_agr,sak19_agr,sak20_agr,sak21_agr,sak22_agr,sak23_agr,sak24_agr)
sak1724 <- sak1724 %>% filter(lapus != 0, !is.na(lapus))

id <- sak1724 %>% group_by(tahun,kode) %>% summarise(.groups = "drop")
id_expanded <- expand.grid(
  tahun = unique(id$tahun),
  kode = unique(id$kode),
  lapus = 1:17
)

id_expanded <- merge(id, expand.grid(lapus = 1:17), all = TRUE)

sak1724 <- left_join(id_expanded,sak1724)
sak1724 <- sak1724 %>% mutate(tenaga_kerja = ifelse(is.na(tenaga_kerja),0,tenaga_kerja),
                              rata_upah = ifelse(is.na(rata_upah),0,rata_upah))

export(sak1724,"Input/final/[13062026] Emp_upah.xlsx")
