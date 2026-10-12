#*** Arsip: disalin dari Laptop CISDI data/climate-volatility-structural-change/Code/01_Calculate LPR (Sakernas).R (21 Agu 2026)
#*** Angkatan kerja, penduduk bekerja, pop 15-64, lf_rate, emp_rate per kabkota-tahun.
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
# B5_R5B  = 5B KEGIATAN DENGAN WAKTU TERBANYAK
# B5_R5A1 = 5A1 BEKERJA MINIMAL 1 JAM TANPA TERPUTUS
# B5_R7A  = 7A BEKERJA KUMULATIF
# B5_R7B  = 7B SEMENTARA TIDAK BEKERJA KUMULATIF
# B5_R6   = 6 SEMENTARA TIDAK BEKERJA
# B5_R15A = 15A MENCARI PEKERJAAN SEMINGGU YANG LALU
# B5_R16A = 16A MENCARI PEKERJAAN SEBULAN LALU
# B5_R20A = 20A ALASAN TIDAK MENCARI KERJA
# B5_R21A = 21A MAU MENERIMA JIKA ADA TAWARAN PEKERJAAN
# B4_K6   = UMUR

sak17 <- import("E:/dataset/BPS/SAKERNAS/Sakernas 2017/skrnas17.dta")

#*#-> Generate kode kabupaten 
sak17 <- sak17 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak17 <- sak17 %>%
  mutate(
    activity_work   = if_else(b5_r5a1 == 1 | b5_r7a == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(b5_r6   == 1 | b5_r7b == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(b5_r15a == 1 | b5_r16a == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(b5_r15b == 1 | b5_r16b == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(b5_r20a == 1 | b5_r20a == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(b5_r20a == 3 & (b5_r21a == 1 | b5_r22 == 1), 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = b4_k6
  )

sak17_agr <- sak17 %>%
  mutate(
    inLF_W = inLF * weight,
    inemp_W = inemp * weight,
    tahun = 2017L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(weight,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)


#*---|> Sakernas 2018
sak18 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2018/Sakernas 2018 Aug/SAK082018/DATA/sakernas_201808_15+_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak18 <- sak18 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak18 <- sak18 %>%
  mutate(
    activity_work   = if_else(B5_R5A1 == 1 | B5_R7A  == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(B5_R6   == 1 | B5_R7B  == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(B5_R15A == 1 | B5_R16A == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(B5_R16A == 1 | B5_R16B == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(B5_R20A == 1 | B5_R20A == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(B5_R20A == 3 & (B5_R21A == 1 | B5_R22 == 1), 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = B4_K8
  )

#*#-> Agreggating 
sak18_agr <- sak18 %>%
  mutate(
    inLF_W = inLF * FINAL_WEIG,
    inemp_W = inemp * FINAL_WEIG,
    tahun = 2018L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(FINAL_WEIG,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*---|> Sakernas 2019
sak19 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2019/sak_201908_15+.dta")

#*#-> Generate kode kabupaten 
sak19 <- sak19 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak19 <- sak19 %>%
  mutate(
    activity_work   = if_else(b5_r5a1 == 1 | b5_r7a  == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(b5_r6   == 1 | b5_r7b  == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(b5_r12a == 1 | b5_r13a == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(b5_r12b == 1 | b5_r13b == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(b5_r17a == 1 | b5_r17a == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(b5_r17a == 3 & (b5_r18a == 1 | b5_r19 == 1), 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = b4_k8
  )

#*#-> Agreggating 
sak19_agr <- sak19 %>%
  mutate(
    inLF_W = inLF * weightr_sp,
    inemp_W = inemp * weightr_sp,
    tahun = 2019L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(weightr_sp,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*---|> Sakernas 2020
sak20 <- import("E:/dataset/BPS/SAKERNAS/Sakernas2020/sak2020_8.dta")

#*#-> Generate kode kabupaten 
sak20 <- sak20 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak20 <- sak20 %>%
  mutate(
    activity_work   = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(r10a == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(r22a == 1 | r23b == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(r22b == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(r25a == 1 | r25a == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(r25a == 3 & r26 == 1, 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = k6
  )

#*#-> Agreggating 
sak20_agr <- sak20 %>%
  mutate(
    inLF_W = inLF * final_weig,
    inemp_W = inemp * final_weig,
    tahun = 2020L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(final_weig,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*---|> Sakernas 2021
sak21 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2021/sak21auglabeltrain.dta")

#*#-> Generate kode kabupaten 
sak21 <- sak21 %>% mutate(kode = paste0(kode_prov,sprintf("%02d",kode_kab)))

#*#-> Identifying population in the Labor Force
sak21 <- sak21 %>%
  mutate(
    activity_work   = if_else(r9a == 1 | r9b  == 1 | r9c == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(r10a == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(r29a == 1 | r30_bln == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(r29b == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(r32a == 1 | r32a == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(r32a == 3 & r33 == 1, 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = k6
  )

#*#-> Agreggating 
sak21_agr <- sak21 %>%
  mutate(
    inLF_W = inLF * final_weig,
    inemp_W = inemp * final_weig,
    tahun = 2021L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(final_weig,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*---|> Sakernas 2022
sak22 <- import("E:/dataset/BPS/SAKERNAS/Sakernas Agustus 2022/Survei Angkatan Kerja Nasional 2022 Agustus/Sakernas22_Agustus.dta")

#*#-> Generate kode kabupaten 
sak22 <- sak22 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak22 <- sak22 %>%
  mutate(
    activity_work   = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(R10 == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(R31A == 1 | R32A == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(R31B == 1 | R32B == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(R35A == 1 | R35A == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(R35A == 3 & R36A == 1, 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K6
  )

#*#-> Agreggating 
sak22_agr <- sak22 %>%
  mutate(
    inLF_W = inLF * WEIGHT,
    inemp_W = inemp * WEIGHT,
    tahun = 2022L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(WEIGHT,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*---|> Sakernas 2023 (PROBLEMATIK)
sak23 <- import("E:/dataset/BPS/SAKERNAS/SAKERNAS 2023/Sakernas Agustus 2023/SAKERNAS_08-2023/sak202308_15_diseminasi.dbf")

#*#-> Generate kode kabupaten 
sak23 <- sak23 %>% mutate(kode = paste0(KODE_PROV,sprintf("%02d",KODE_KAB)))

#*#-> Identifying population in the Labor Force
sak23 <- sak23 %>%
  mutate(
    activity_work   = if_else(R9A == 1 | R9B  == 1 | R9C == 1, 1L, 0L, missing = 0L),
    temp_notwork    = if_else(R10 == 1, 1L, 0L, missing = 0L),
    looking_forwork = if_else(R31A == 1 | R32A == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(R31B == 1 | R32B == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(R35A == 1 | R35A == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(R35A == 3 & R36A == 1, 1L, 0L, missing = 0L),
    inLF = if_else(
      activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
        business_prep == 1 | reason_accepted == 1 | discouraged == 1,
      1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K9
  )


#*#-> Agreggating 
sak23_agr <- sak23 %>%
  mutate(
    inLF_W  = inLF  * as.numeric(WEIGHTR),   # <-- kunci perbaikan
    inemp_W = inemp * as.numeric(WEIGHTR),
    tahun = 2023L
  ) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(as.numeric(WEIGHTR), na.rm = TRUE),  # <-- juga di sini
    .groups = "drop"
  ) %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop
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
    looking_forwork = if_else(R38A == 1 | R39A == 1, 1L, 0L, missing = 0L),
    business_prep   = if_else(R38B == 1 | R39B == 1, 1L, 0L, missing = 0L),
    reason_accepted = if_else(R42A == 1 | R42A == 2, 1L, 0L, missing = 0L),
    discouraged     = if_else(R42A == 3 & R43A == 1, 1L, 0L, missing = 0L)) %>%
  mutate(inLF = if_else(
    activity_work == 1 | temp_notwork == 1 | looking_forwork == 1 |
      business_prep == 1 | reason_accepted == 1 | discouraged == 1,1L, 0L),
    inemp = if_else(activity_work == 1 | temp_notwork == 1, 1L, 0L),
    age = K10
  )
    
#*#-> Agreggating 
sak24_agr <- sak24 %>%
  mutate(
    inLF_W  = inLF * WEIGHT,
    inemp_W = inemp * WEIGHT,
    tahun   = 2024L) %>%
  filter(age %in% 15:64) %>%
  group_by(tahun, kode) %>%
  summarise(
    inLF  = sum(inLF_W,  na.rm = TRUE),
    inemp = sum(inemp_W, na.rm = TRUE),
    pop   = sum(WEIGHT,  na.rm = TRUE),
    .groups = "drop") %>%
  mutate(
    emp_rate = inemp / inLF,
    lf_rate  = inLF / pop)

#*#-> Adjusting relasi BPS 38 provinsi -> 34 provinsi
relasibps <- import("Input/Relasi BPS 34-38.xlsx")
relasibps <- relasibps %>% mutate(kode = as.character(kode), 
                                  ADM2_PCODE = as.character(ADM2_PCODE))

sak24_agr <- left_join(sak24_agr,relasibps,by=c("kode"))
sak24_agr <- sak24_agr %>% dplyr::select(., -c(kode)) %>% rename(kode = ADM2_PCODE)


sak1724 <- rbind(sak17_agr,sak18_agr,sak19_agr,sak20_agr,sak21_agr,sak22_agr,sak23_agr,sak24_agr)
sak1724 <- sak1724 %>% rename(pop1564 = pop)

  
export(sak1724,"Input/bps data (cleaned)/LF and Emp.xlsx")
