# Perbandingan tiga basis harga

Dibuat 2026-08-05. Angkanya dari `02 Code/11_perbandingan tiga basis.R`, yang membaca
keluaran skrip 01 dan 02 di ketiga folder tanpa menghitung apa pun yang baru. Log lengkap
di `03 Output (ADHB)/log_11_perbandingan.txt`, tabelnya di
`03 Output (ADHB)/Perbandingan Tiga Basis.xlsx`.

---

## 1. Ketiga basis

| Basis | Terikat | Modal | Folder | Status |
|---|---|---|---|---|
| Nominal | `9_ADHK` riil | `pmtb` harga berlaku | `03 Output/` | versi terbit, basis harganya campur |
| Riil | `9_ADHK` riil | `4_ADHK` riil | `03 Output (modal riil)/` | satu-satunya yang kedua sisinya harga konstan |
| ADHB | `9_ADHB` nominal | `4_ADHB` nominal | `03 Output (ADHB)/` | konsisten harga berlaku, diagnostik |

Basis nominal mewarisi cacat skrip Stata asal di `Analisis TFP - Yudistira/`: ketiga berkas
`.do` memakai `pmtb` harga berlaku di semua model, termasuk yang terikatnya `ADHK_9`. Kolom
`ADHK_4` tidak pernah muncul satu kali pun di sana.

**Residual basis ADHB bukan TFP.** Ia memuat inflasi harga output. Seluruh gambar dan tabel
basis itu melabelinya "sisa nominal", dan langkah S0 kaskade seleksi menyatakan pelanggarannya
terang-terangan di log.

---

## 2. Angka pokok

| Besaran | Nominal | Riil | ADHB |
|---|---|---|---|
| b1 | 0,3997 | 0,4019 | 0,4584 |
| b2 | 0,1913 | 0,1472 | 0,0152 |
| b1 + b2 | 0,591 | 0,549 | 0,474 |
| gY (%/thn) | 3,83 | 3,83 | 6,74 |
| gK (%/thn) | 6,12 | 3,26 | 6,19 |
| Kontribusi modal (poin) | 2,45 | 1,31 | 2,84 |
| Kontribusi tenaga kerja (poin) | 0,40 | 0,31 | 0,03 |
| Sisa (poin) | 0,98 | 2,21 | 3,87 |
| Pangsa sisa (persen) | 25,7 | 57,8 | 57,4 |

---

## 3. Apa yang dijawab perbandingan ini

**Elastisitas modal hampir tidak bergerak; yang bergerak laju modalnya.** b1 berjalan 0,400 →
0,402 → 0,458 di ketiga basis, rentang 0,06. Sementara gK melompat dari 3,26 (riil) ke 6,12
(nominal) dan 6,19 (ADHB). Selisih 2,86 poin itulah yang memindahkan kontribusi modal dari
1,31 ke 2,45 poin, dan karenanya membalik pangsa sisa dari 57,8 ke 25,7 persen.

**Deflator output dan deflator modal bergerak nyaris seiring.** Selisih nominal terhadap riil:
output 2,91 persen per tahun, modal 2,93 persen per tahun. Praktis sama. Inilah sebabnya basis
ADHB dan basis riil memberi pangsa sisa yang hampir sama (57,4 lawan 57,8) meski levelnya jauh
berbeda: keduanya konsisten basis harga, jadi deflator sebagian besar saling meniadakan.

**Angka versi terbit adalah anomali, bukan salah satu ujung rentang.** Dua basis yang konsisten
basis harganya sepakat di sekitar 57 persen. Versi terbit yang mencampur basis berdiri sendiri
di 25,7 persen. Selisih itu bukan ketidakpastian metodologis; ia akibat satu kolom yang salah
basis harga.

**Elastisitas tenaga kerja runtuh di basis ADHB.** b2 = 0,0152 dengan SE Driscoll-Kraay 0,0601,
jadi tidak berbeda dari nol. Kontribusi tenaga kerja tinggal 0,03 poin dari 6,74. Pembacaan yang
masuk akal: pada basis nominal, dummy tahun sudah menyerap sebagian besar pergerakan bersama
harga, dan sisa variasi tenaga kerja dalam-provinsi terlalu tipis untuk diidentifikasi.

**Tangga atenuasi berbalik bentuk.** Pada basis riil ia naik dua langkah lalu jatuh
(1,011 → 1,075 → 1,189 → 0,549). Pada basis ADHB kenaikannya jauh lebih tajam dan fixed effects
menembus 1,477 sebelum jatuh ke 0,474. Assertion di `03_visualisasi.R` dicabangkan mengikuti
kedua pola itu, bukan dilonggarkan.

---

## 4. Sisa per pulau

| Pulau | Nominal | Riil | ADHB |
|---|---|---|---|
| Sulawesi | 1,78 | 3,24 | 4,97 |
| Maluku-Papua | 0,50 | 1,85 | 4,32 |
| Sumatera | 0,72 | 1,89 | 4,19 |
| Jawa | 1,24 | 2,42 | 3,79 |
| Bali-Nusra | 0,01 | 1,23 | 3,12 |
| Kalimantan | −0,11 | 1,35 | 2,92 |

Peringkatnya nyaris bertahan lintas basis; yang berubah levelnya. Kalimantan satu-satunya yang
negatif, dan hanya pada versi terbit.

---

## 5. Yang tidak dibuat untuk basis ADHB

Tiga gambar simulasi trajektori 2026-2029 sengaja tidak digambar. Sasaran 8 persen Masterplan
didefinisikan atas pertumbuhan PDB **riil**, sedangkan laju basis 2022-2024 pada basis ADHB
adalah 8,72 persen **nominal**. Ketiga gambar akan memperlihatkan sasaran yang sudah terlampaui
0,72 poin, padahal yang dibandingkan dua besaran berbeda — kesalahan kategori yang sejenis
dengan yang diperbaiki pemindahan basis modal ini.

Angka simulasinya tetap ada dan bisa ditelusuri di
`03 Output (ADHB)/Simulasi Trajektori 2026-2029.xlsx`. `02 Code/09_visualisasi trajektori.R`
berhenti terkendali pada basis itu dan mencetak alasannya.

---

## 6. Cara menjalankan ulang

```
BASIS_MODAL=adhb Rscript "02 Code/01_estimasi tfp.R"          > "03 Output (ADHB)/log_01_estimasi.txt"    2>&1
BASIS_MODAL=adhb Rscript "02 Code/02_dekomposisi nasional.R"  > "03 Output (ADHB)/log_02_dekomposisi.txt" 2>&1
BASIS_MODAL=adhb Rscript "02 Code/04_simulasi drs vs crs.R"   > "03 Output (ADHB)/log_04_simulasi.txt"    2>&1
BASIS_MODAL=adhb Rscript "02 Code/08_simulasi trajektori.R"   > "03 Output (ADHB)/log_08_trajektori.txt"  2>&1
BASIS_MODAL=adhb Rscript "02 Code/03_visualisasi.R"           > "03 Output (ADHB)/log_03_visualisasi.txt" 2>&1
BASIS_MODAL=adhb Rscript "02 Code/05_kontribusi pertumbuhan tahunan.R" > "03 Output (ADHB)/log_10_kontribusi.txt" 2>&1
BASIS_MODAL=adhb Rscript "02 Code/09_visualisasi trajektori.R" > "03 Output (ADHB)/log_09_trajektori.txt" 2>&1
Rscript "02 Code/11_perbandingan tiga basis.R"                > "03 Output (ADHB)/log_11_perbandingan.txt" 2>&1
```

Blok `acuan` di skrip 03 dan 10 memuat angka yang disalin dari log skrip 01 dan 02, lalu diuji
`stopifnot`. Kalau angkanya bergeser, kedua skrip itu berhenti — dan memang harus berhenti.

Setelah menyunting skrip mana pun, jalankan uji reproduksi terhadap salinan folder lama:

```
DIR_BARU="03 Output (modal riil)" DIR_LAMA="<salinan>" Rscript "02 Code/12_uji reproduksi basis lama.R"
```

---

## 7. Catatan verifikasi data, 5 Agustus 2026

Tahun dasar harga konstan dataset adalah **2010**, terkonfirmasi tiga jalur:

1. Sheet `Keterangan` workbook sumber menulis `Grwth2_Prov` = "Pertumbuhan Ekonomi (%) dalam
   PDRB ADHK* (2010 = 100)"; seluruh kolom `*_ADHK` sektoral berlabel "(2010)".
2. BPS masih menerbitkan seri tahun dasar 2010 untuk periode ini; rebasing terakhir 2000 → 2010
   diumumkan akhir 2014.
3. Laju pertumbuhan PDRB agregat dataset berimpit dengan PDB nasional BPS: selisih ≤ 0,04 poin
   persen di 2019-2024 (4,976 vs 5,02; −2,030 vs −2,07; 3,708 vs 3,70; 5,345 vs 5,31;
   5,060 vs 5,05; 5,039 vs 5,03).

Level PDRB total dataset 1,0-1,1 persen di atas PDB nasional, konsisten sepanjang tahun.
PMTB `4_ADHK` 0,4-2,7 persen di bawah PMTB nasional BPS.

Dua hal lain yang muncul saat verifikasi dan belum ditindaklanjuti:

- Dataset memuat **tahun 2025 lengkap** untuk 34 provinsi. Seluruh analisis berhenti di 2024.
  Belum jelas apakah 2025 realisasi atau proyeksi.
- Satuan di dalam blok `*_ADHB` **tidak seragam**: `9_ADHB` dan `4_ADHB` triliun, tapi
  `7_ADHB`/`8_ADHB` (ekspor/impor) miliar. Anggapan satuan di skrip 01 sendiri terverifikasi
  benar untuk keempat kolom yang dipakai.
