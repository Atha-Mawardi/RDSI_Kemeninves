# 07_agregasi tenaga kerja upah provinsi.R
#
# Total tenaga kerja dan rata-rata upah pekerja per PROVINSI per tahun 2017-2024,
# diagregasi dari tabel kabkota x 17 lapangan usaha KBLI.
#
# Masukan : 01 Data/BKPM/processed/[13062026] Emp_upah.xlsx  (keluaran 06_sakernas_sectoral emp-upah.R)
#           01 Data/BKPM/processed/kodekab.xlsx              (nama provinsi, kunci ID + 2 digit)
# Keluaran: 01 Data/BKPM/output/tenaga kerja dan upah provinsi_0821.xlsx  (3 sheet)
#
# KEPUTUSAN
#
# 1. Tenaga kerja dijumlah lurus lintas sektor dan kabkota. Satuannya orang.
#
# 2. Upah provinsi = rata-rata tertimbang, bobotnya jumlah pekerja sel itu:
#    sum(rata_upah * tenaga_kerja) / sum(tenaga_kerja).
#    Rata-rata dari rata-rata sektor salah, karena sektor besar dan sektor kecil
#    akan berbobot sama.
#
# 3. Basis upah: SELURUH pekerja, termasuk sel yang rata_upah-nya nol. Sel nol
#    berisi pekerja tanpa upah (berusaha sendiri, pekerja keluarga) dan juga sel
#    hasil pengisian nol saat expand grid di skrip 06; keduanya menarik rata-rata
#    ke bawah. Varian "hanya sel ber-upah > 0" pernah dihitung dan selisihnya di
#    bawah 0,2%, jadi kolomnya dibuang biar tabelnya bersih.
#    Catatan: ini upah rata-rata SELURUH pekerja, bukan upah buruh/karyawan saja.
#    Angka yang terakhir itu menuntut mikrodata Sakernas dan penyaringan status
#    pekerjaan.
#
# 4. Kode provinsi = dua digit pertama kode kabkota. Kode di berkas masukan sudah
#    diseragamkan ke 34 provinsi lewat Relasi BPS 34-38 di skrip 06.

library(tidyverse)
library(rio)
library(openxlsx)

emp <- import("01 Data/BKPM/processed/[13062026] Emp_upah.xlsx")
kodekab <- import("01 Data/BKPM/processed/kodekab.xlsx")

# kodekab.xlsx memuat dua penamaan (singkat dan "Provinsi ..."), plus provinsi
# pemekaran Papua yang berbagi kode lama. Basisnya 34 provinsi, jadi: ambil nama
# panjang, lalu satu nama terpendek per kode — ID91 jadi Papua Barat, ID94 jadi Papua.
prov_nama <- kodekab %>%
  filter(level == "provinsi", str_starts(nama_wilayah, "Provinsi ")) %>%
  group_by(ADM2_PCODE) %>%
  slice_min(nchar(nama_wilayah), n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(kode_prov = str_remove(ADM2_PCODE, "^ID"), provinsi = nama_wilayah)
stopifnot(!any(duplicated(prov_nama$kode_prov)))

emp <- emp %>%
  mutate(
    kode = sprintf("%04d", as.integer(kode)),
    kode_prov = str_sub(kode, 1, 2),
    tahun = as.integer(tahun)
  )

# rata-rata tertimbang jumlah pekerja
upah_tertimbang <- function(upah, bobot) {
  pakai <- !is.na(upah) & !is.na(bobot) & bobot > 0
  if (!any(pakai)) return(NA_real_)
  sum(upah[pakai] * bobot[pakai]) / sum(bobot[pakai])
}

prov_sektor <- emp %>%
  group_by(tahun, kode_prov, lapus) %>%
  summarise(
    upah         = upah_tertimbang(rata_upah, tenaga_kerja),
    tenaga_kerja = sum(tenaga_kerja, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  relocate(tenaga_kerja, .before = upah)

prov <- emp %>%
  group_by(tahun, kode_prov) %>%
  summarise(
    upah         = upah_tertimbang(rata_upah, tenaga_kerja),
    n_kabkota    = n_distinct(kode),
    tenaga_kerja = sum(tenaga_kerja, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  relocate(tenaga_kerja, .before = upah)

nasional <- emp %>%
  group_by(tahun) %>%
  summarise(
    upah         = upah_tertimbang(rata_upah, tenaga_kerja),
    n_kabkota    = n_distinct(kode),
    tenaga_kerja = sum(tenaga_kerja, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  relocate(tenaga_kerja, .before = upah)

prov        <- left_join(prov, prov_nama, by = "kode_prov") %>% relocate(provinsi, .after = kode_prov)
prov_sektor <- left_join(prov_sektor, prov_nama, by = "kode_prov") %>% relocate(provinsi, .after = kode_prov)

# --- pemeriksa: agregasi tidak boleh menambah atau menghilangkan orang
cek_total <- emp %>% group_by(tahun) %>% summarise(mentah = sum(tenaga_kerja, na.rm = TRUE), .groups = "drop") %>%
  left_join(prov %>% group_by(tahun) %>% summarise(agregat = sum(tenaga_kerja), .groups = "drop"), by = "tahun") %>%
  mutate(selisih = mentah - agregat)
stopifnot(all(abs(cek_total$selisih) < 1e-6))
stopifnot(!any(is.na(prov$provinsi)))
stopifnot(all(nasional$n_kabkota >= 513))
prov     <- prov     %>% select(-n_kabkota)
nasional <- nasional %>% select(-n_kabkota)

write.xlsx(
  list(provinsi_tahun = prov, provinsi_sektor_tahun = prov_sektor, nasional_tahun = nasional),
  "01 Data/BKPM/output/tenaga kerja dan upah provinsi_0821.xlsx",
  overwrite = TRUE
)

cat("\n== nasional per tahun\n"); print(as.data.frame(nasional), row.names = FALSE)
cat("\n== jumlah baris provinsi x tahun:", nrow(prov), "| provinsi unik:", n_distinct(prov$kode_prov), "\n")
cat("\n== 5 provinsi tenaga kerja terbesar, 2024\n")
print(as.data.frame(prov %>% filter(tahun == 2024) %>% arrange(desc(tenaga_kerja)) %>% head(5)), row.names = FALSE)
cat("\n== 5 provinsi upah tertinggi, 2024\n")
print(as.data.frame(prov %>% filter(tahun == 2024) %>% arrange(desc(upah)) %>% head(5)), row.names = FALSE)
