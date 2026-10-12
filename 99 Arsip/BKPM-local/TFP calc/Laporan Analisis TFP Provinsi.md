# Laporan Analisis TFP Provinsi

> **DOKUMEN INI SUDAH DIGANTIKAN.** Perhitungan penggantinya ada di
> `TFP analysis (07182026)/04 Report/Report TFP.md`, beserta seluruh skrip, data, dan grafiknya.
>
> Tiga angka dalam dokumen ini terbukti keliru dan sudah dicabut di tempatnya masing-masing:
> klaim pertumbuhan TFP 2,24%/tahun, kolom perubahan TFP per tahun tingkat provinsi, dan klaim
> bahwa galat baku cluster-robust menangani dependensi lintas provinsi. Rinciannya di
> `TFP analysis (07182026)/00 Docs/memory_tfp.md` bagian 5.
>
> Dokumen ini dipertahankan sebagai rekam jejak, bukan sebagai rujukan angka.

Perhitungan Total Factor Productivity 34 provinsi, 2017–2025, hasil porting do-file Stata
Yudistira (`Analisis Data Provinsi BKPM (2).do`) ke R dengan dataset terbaru
`Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx`.

Script: `01_analisis TFP provinsi.R` · Log lengkap: `run_log.txt` · Output: `Output/`

---

## 1. Ringkasan eksekutif

1. **Basis harga menentukan hasil.** Pada output nominal (ADHB) jumlah elastisitas modal +
   tenaga kerja mencapai 1,09 (RE) hingga 1,54 (FE) — *increasing returns* sebesar itu tidak
   masuk akal secara ekonomi dan merupakan tanda TFP nominal menyerap inflasi/deflator. Pada
   output riil (ADHK) jumlahnya 0,90 (RE) dan 0,80 (FE), mendekati *constant returns*.
   **Angka ADHK yang layak dijadikan pegangan.**
2. **Elastisitas modal ≈ elastisitas tenaga kerja pada basis riil**: 0,459 vs 0,438 (RE, ADHK),
   keduanya signifikan pada 1%. Kenaikan PMTB 10% berasosiasi dengan PDRB riil +4,6%.
3. **Uji Hausman memberi verdict berbeda per basis.** ADHB menolak RE dengan telak
   (χ²=54,7; p<0,001) → wajib FE. ADHK hanya menolak marginal (χ²=5,20; p=0,074) → RE masih
   bisa dipertahankan, dan koefisien RE vs FE-nya memang nyaris identik (0,459 vs 0,452).
4. **TFP antar-provinsi timpang ~5×.** Rentang log TFP riil 14,10 (NTT) hingga 15,72 (DKI
   Jakarta) = selisih 1,62 log poin. DKI, Kalimantan Timur, dan Riau di puncak; NTT, Bengkulu,
   dan Maluku Utara di dasar.
5. **Peringkat nominal ≠ peringkat riil.** Papua Barat, Kalimantan Utara, dan Jambi tampak
   sangat produktif pada basis ADHB tetapi hanya menengah pada ADHK — selisihnya adalah efek
   harga komoditas, bukan produktivitas.
6. **TFP nasional praktis stagnan 2017–2024** (rata-rata bergerak 14,849 → 14,847, dengan
   palung 2021 di 14,829). Pertumbuhan datang dari akumulasi input, bukan efisiensi.
   Sulawesi Tengah satu-satunya pengecualian mencolok (+3,6%/tahun, era hilirisasi nikel);
   Kalimantan Timur (−2,4%) dan NTB (−2,1%) turun paling dalam.
7. **TFP di sini berkorelasi kuat dengan ukuran ekonomi provinsi** — jadi ia belum bisa dibaca
   sebagai efisiensi murni. Lihat caveat di bagian 6.

---

## 2. Data dan spesifikasi

Model Solow yang dipertahankan sepanjang analisis:

```
log Y[i,t] = a + b1·log K[i,t] + b2·log L[i,t] + u[i] + e[i,t]
TFP[i,t]   = exp(a + u[i] + e[i,t])
```

| Komponen | Variabel |
|---|---|
| Output nominal (Y) | `9_ADHB` — PDRB harga berlaku |
| Output riil (Y) | `9_ADHK` — PDRB harga konstan |
| Modal (K) | `pmtb` — Pembentukan Modal Tetap Bruto |
| Tenaga kerja (L) | jumlah 17 kolom `*_TenagaKerja` (primer + sekunder + tersier) |

- **306 observasi** (34 provinsi × 9 tahun), **272 terpakai** — `pmtb` dan tenaga kerja belum
  tersedia untuk 2025, sehingga estimasi efektif 2017–2024. Sampel ADHB dan ADHK identik,
  jadi keduanya langsung sebanding.
- **Bentuk growth** (238 obs) kehilangan tahun pertama tiap provinsi karena *first-difference*.
- **PMA/PMDN** memakai kolom agregat siap pakai `PMA_1`/`PMDN_1`, bukan penjumlahan manual 17
  kolom sektoral yang sangat *sparse* (`O_PMA` kosong di 303 dari 306 baris).
- **Skala unit** mengikuti persis do-file asli (×1e9 untuk ADHB, ×1e6 untuk ADHK/pmtb).
  Konsekuensinya: **level absolut TFP tidak punya makna satuan**, tetapi perbandingan dan
  peringkat antar-provinsi sepenuhnya valid — pengali skala hanya menggeser konstanta dan
  tidak menyentuh elastisitas.
- **Cakupan porting**: seksi 1–8 do-file (FE/RE, robustness, growth-form, diagnostik).
  Seksi IV/GMM (do-file baris 406–500) di luar scope.

---

## 3. Elastisitas: empat model utama

Standard error cluster-robust per provinsi (padanan `vce(robust)` Stata).

| | **ADHB-RE** | **ADHB-FE** | **ADHK-RE** | **ADHK-FE** |
|---|---|---|---|---|
| log PMTB (b1) | 0,829*** (0,099) | 0,732*** (0,116) | 0,459*** (0,038) | 0,452*** (0,038) |
| log Tenaga Kerja (b2) | 0,262* (0,114) | 0,808*** (0,199) | 0,438*** (0,078) | 0,351*** (0,097) |
| Konstanta | 1,619 (0,919) | — | 14,840*** (0,605) | — |
| **b1 + b2** | **1,091** | **1,540** | **0,897** | **0,803** |
| N | 272 | 272 | 272 | 272 |
| R² *within* | 0,859 | 0,878 | 0,887 | 0,888 |
| ρ (share varian antar-provinsi) | — | 0,989 | — | 0,992 |

`*** p<0,01 · * p<0,05`

**Bacaan pokok.** Kolom ADHB-FE adalah lampu merah: elastisitas tenaga kerja 0,808 dengan
*returns to scale* 1,54 secara ekonomi tidak masuk akal untuk fungsi produksi agregat.
Begitu output di-deflasi (kolom ADHK), keduanya turun ke wilayah wajar dan hampir seimbang
antara modal dan tenaga kerja. Ini konsisten dengan catatan do-file sendiri (baris 199–201)
bahwa ADHB mencampur TFP sejati dengan perubahan harga.

Inferensi ADHK terbukti kokoh: SE jackknife (leave-one-province-out) dan bootstrap 500 replikasi
justru **lebih ketat** dari SE cluster-robust (b1: 0,046 dan 0,036 vs 0,038), jadi signifikansi
bukan artefak jumlah klaster yang cuma 34.

### Varian RE lain (basis ADHB)

| Varian                      | b1 (PMTB) | b2 (Tenaga Kerja) |
| --------------------------- | --------- | ----------------- |
| RE-GLS (Swamy-Arora, utama) | 0,829     | 0,262             |
| Two-way RE (dummy tahun)    | 0,568     | 0,366             |
| Mundlak CRE                 | 0,733     | 0,806             |
| Pooled OLS                  | 0,907     | 0,097             |
| Between estimator           | 0,913     | 0,090             |

Sebaran b2 yang liar (0,09 → 0,81) menunjukkan elastisitas tenaga kerja pada basis nominal
sangat bergantung pada cara varian antar-provinsi diperlakukan. Pada basis ADHK sebaran ini
jauh lebih tenang (RE 0,438; two-way RE 0,437; FE 0,351) — alasan tambahan memakai ADHK.

Regresi terpisah per provinsi (mean-group Pesaran-Smith) memberi rata-rata b1 = 1,00 dengan
simpangan baku 0,469 (rentang 0,15–2,17) dan b2 rata-rata 0,22 dengan simpangan 1,52
(rentang −4,37 sampai atas). Dengan hanya 8 tahun dan 5 derajat bebas per provinsi, angka
per provinsi ini **terlalu bising untuk dikutip**; ia hanya menandakan heterogenitas nyata
antar provinsi.

---

## 4. Pemilihan model

| Uji                      | ADHB              | ADHK                 | Bacaan                                                 |
| ------------------------ | ----------------- | -------------------- | ------------------------------------------------------ |
| Hausman FE vs RE         | χ²=54,7; p<0,001  | χ²=5,20; **p=0,074** | ADHB: RE ditolak → pakai FE. ADHK: RE bertahan di 5%.  |
| Breusch-Pagan LM         | χ²=702,4; p<0,001 | χ²=725,5; p<0,001    | Ada efek provinsi → pooled OLS tidak memadai.          |
| Mundlak (Hausman robust) | χ²=24,0; p<0,001  | χ²=52,5; p<0,001     | Versi cluster-robust justru menolak RE di kedua basis. |

**Catatan penting soal ketidaksepakatan ini.** Hausman klasik dan Mundlak memberi jawaban
berbeda untuk ADHK (p=0,074 vs p<0,001). Hausman klasik mensyaratkan homoskedastisitas dan
tanpa autokorelasi — dua asumsi yang justru ditolak oleh diagnostik di bagian 6 — sedangkan
uji Mundlak tetap valid di bawah *clustering*. **Secara teknis FE lebih dapat dipertahankan.**

Untungnya pilihan ini nyaris tidak berkonsekuensi untuk elastisitas ADHK (0,459 vs 0,452),
tetapi **sangat berkonsekuensi untuk level TFP**: konstanta FE mengabsorbsi seluruh perbedaan
antar-provinsi ke dalam *fixed effect*. Arah pergeserannya berbeda menurut basis harga: pada ADHK
level FE sekitar 1,5 poin log **di atas** RE, sedangkan pada ADHB sekitar 5,6 poin log **di bawah**
RE. Karena itu tabel di bawah menampilkan keduanya, dan **peringkat**-lah (bukan level) yang
sebaiknya dikutip — korelasi peringkat RE vs FE praktis sempurna.

---

## 5. Hasil TFP per provinsi

### 5.1 Level (log TFP, rata-rata periode)

Diurutkan dari TFP riil tertinggi. **Kolom `Δ%/thn` DICABUT**: ia selisih dua titik ujung atas
residual yang terautokorelasi kuat, sehingga ditentukan oleh pilihan tahun awal dan akhir. Angka
Kaltim -2,45%/thn khususnya artefak, karena pertumbuhan PMTB provinsi itu 8-15%/tahun melawan PDRB
riil 2,6-6,2%, dan PMTB masuk regresor dengan koefisien positif. Penggantinya: tren dari regresi
delapan titik beserta galat bakunya, di report baru.

|   # | Provinsi             | ADHK-RE | ADHK-FE | ADHB-RE |    Δ%/thn |
| --: | -------------------- | ------: | ------: | ------: | --------: |
|   1 | DKI Jakarta          |  15,715 |  17,251 |   1,721 |     +1,32 |
|   2 | Kalimantan Timur     |  15,581 |  17,016 |   1,917 |     −2,45 |
|   3 | Riau                 |  15,226 |  16,710 |   1,691 |     −0,54 |
|   4 | Papua Barat          |  15,224 |  16,527 |   2,235 |     −0,52 |
|   5 | Jawa Timur           |  15,181 |  16,837 |   1,538 |     +0,46 |
|   6 | Jawa Barat           |  15,148 |  16,810 |   1,587 |     +0,17 |
|   7 | Kalimantan Utara     |  15,091 |  16,369 |   2,016 |     +0,17 |
|   8 | Kep. Riau            |  15,085 |  16,467 |   1,591 |     −0,24 |
|   9 | Jambi                |  15,066 |  16,488 |   1,990 |     −0,11 |
|  10 | Sumatra Utara        |  14,971 |  16,526 |   1,547 |     −0,17 |
|  11 | Banten               |  14,969 |  16,504 |   1,508 |     −0,51 |
|  12 | Jawa Tengah          |  14,934 |  16,573 |   1,390 |     −0,05 |
|  13 | Kalimantan Selatan   |  14,909 |  16,345 |   1,870 |     −0,06 |
|  14 | Papua                |  14,886 |  16,322 |   1,641 |     −0,97 |
|  15 | Sumatera Selatan     |  14,882 |  16,388 |   1,513 |     +1,31 |
|  16 | Sulawesi Selatan     |  14,849 |  16,354 |   1,441 |     −0,13 |
|  17 | Sumatra Barat        |  14,838 |  16,296 |   1,642 |     −0,48 |
|  18 | Sulawesi Tengah      |  14,807 |  16,220 |   1,517 | **+3,64** |
|  19 | Kep. Bangka Belitung |  14,807 |  16,146 |   1,870 |     −0,25 |
|  20 | Sulawesi Utara       |  14,759 |  16,142 |   1,618 |     −0,18 |
|  21 | Bali                 |  14,758 |  16,211 |   1,641 |     −0,00 |
|  22 | Lampung              |  14,752 |  16,257 |   1,501 |     −0,50 |
|  23 | Aceh                 |  14,717 |  16,166 |   1,491 |     +0,16 |
|  24 | Sulawesi Tenggara    |  14,717 |  16,112 |   1,511 |     +0,51 |
|  25 | Kalimantan Barat     |  14,654 |  16,110 |   1,561 |     −0,52 |
|  26 | DI Yogyakarta        |  14,652 |  16,087 |   1,526 |     +0,36 |
|  27 | Kalimantan Tengah    |  14,651 |  16,051 |   1,480 |     +0,36 |
|  28 | Gorontalo            |  14,534 |  15,849 |   1,764 |     +0,51 |
|  29 | Sulawesi Barat       |  14,531 |  15,861 |   1,744 |     −0,32 |
|  30 | Nusa Tenggara Barat  |  14,429 |  15,884 |   1,367 |     −2,13 |
|  31 | Maluku               |  14,401 |  15,741 |   1,620 |     −0,28 |
|  32 | Maluku Utara         |  14,391 |  15,707 |   1,435 |     +0,98 |
|  33 | Bengkulu             |  14,353 |  15,722 |   1,429 |     −0,10 |
|  34 | Nusa Tenggara Timur  |  14,096 |  15,552 |   1,123 |     −0,34 |

File: `Output/Ringkasan TFP per Provinsi.xlsx` (level) ·
`Output/ADHK TFP per Province-Year.xlsx` (per provinsi-tahun) ·
`Output/RE Constants per Province-Year.xlsx` · `Output/FE Constants and Coefficients per Province.xlsx`

### 5.2 Grafik

**`Output/Ranking TFP Provinsi (ADHK vs ADHB).png`** — deviasi log TFP tiap provinsi dari
rata-rata nasional, ADHB dan ADHK berdampingan. Ditampilkan sebagai deviasi (bukan level)
karena level ADHB (~1,6) dan ADHK (~14,8) berbeda jauh akibat pengali skala. Grafik ini
langsung memperlihatkan temuan #5: Papua Barat melonjak di panel nominal (+0,60) tapi hanya
+0,39 di panel riil, sementara Jawa Timur/Jawa Tengah justru *negatif* di panel nominal namun
positif di panel riil.

**`Output/Tren TFP Provinsi.png`** — TFP per provinsi-tahun 2017–2024. Garis rata-rata
nasional hampir horizontal; hampir seluruh dispersi bersifat antar-provinsi, bukan antar-waktu
(sejalan dengan ρ = 0,992). Empat penggerak terbesar disorot.

**`Output/TFP vs Skala Ekonomi.png`** — TFP versus rata-rata log PDRB riil. Kemiringan jelas
positif; ini dasar caveat di bagian 6.

### 5.3 Pertumbuhan TFP (bentuk first-difference)

Konstanta pada regresi growth = rata-rata pertumbuhan TFP nasional per tahun (%).

| | Growth riil (Grwth2) RE | Growth riil FE | Growth nominal (Grwth1) RE |
|---|---|---|---|
| Konstanta (~~pertumbuhan TFP~~ DICABUT) | ~~2,24%/thn~~ | — | ~~5,65%/thn~~ |
| Pertumbuhan PMTB | 0,213*** | 0,138 (p=0,093) | 0,419*** |
| Pertumbuhan tenaga kerja | 0,273*** | 0,273*** | −0,481 (t.s.) |
| N | 238 | 238 | 238 |

**Koreksi.** Intercept ini tidak boleh dibaca sebagai pertumbuhan TFP. Pembacaan itu hanya sah
bila koefisien growth menjumlah 1; faktanya 0,213+0,273 = 0,486, sehingga intercept menyerap suku
skala `(1-0,486) x pertumbuhan input`. Setelah dikoreksi, pertumbuhan TFP jatuh ke sekitar
0,4 poin persen per tahun, dan estimasi penggantinya adalah -0,27%/tahun. Perhatikan bahwa elastisitas dalam bentuk growth (0,21) jauh di bawah bentuk
level (0,46): hubungan PMTB–output jauh lebih lemah pada variasi jangka pendek year-on-year
daripada pada perbedaan struktural antar-provinsi.

---

## 6. Diagnostik dan caveat

| Uji | Hasil | Implikasi |
|---|---|---|
| Wooldridge AR(1), level | ADHB F=108,4; ADHK F=61,0 (p<0,001) | Autokorelasi kuat pada model level. SE cluster-robust menangani autokorelasi serial, **tetapi tidak menangani dependensi lintas provinsi**; klaim sebaliknya di versi awal dokumen ini keliru. |
| Wooldridge AR(1), growth | Grwth1 p=0,968; Grwth2 p=0,037 | Bentuk growth bersih dari autokorelasi — konsisten dengan first-difference yang berhasil. |
| Modified Wald (heteroskedastisitas antar-provinsi) | Semua p<0,001 | Varian error berbeda antar provinsi → cluster-robust wajib, bukan opsional. |
| Pesaran CD (dependensi lintas-provinsi) | ADHB RE z=33,6; ADHK RE z=0,99 (p=0,322) | ADHB terguncang faktor bersama (harga/inflasi nasional). **ADHK lolos** — bukti tambahan model riil lebih bersih. |
| RESET (bentuk fungsional) | Semua p>0,08 | Cobb-Douglas log-linear memadai; tidak ada indikasi nonlinearitas terabaikan. |

### Yang perlu dijaga saat mengutip angka ini

1. **TFP di sini adalah residual Solow, bukan produktivitas murni.** Ia menyerap apa saja yang
   tidak dijelaskan modal dan tenaga kerja: kualitas infrastruktur, kelembagaan, komposisi
   sektor, endowment sumber daya alam, sekaligus **galat pengukuran data**. Kaltim dan Riau di
   peringkat atas kemungkinan besar mencerminkan rente sumber daya alam, bukan efisiensi.
2. **TFP berkorelasi positif dengan ukuran ekonomi** (grafik 5.2c). Karena TFP dihitung sebagai
   residual dan elastisitas dipaksa seragam untuk semua provinsi, provinsi yang menyimpang dari
   fungsi produksi rata-rata akan tampil dengan TFP tinggi/rendah — sebagian mekanis, bukan
   substantif. Regresi per provinsi menunjukkan b1 sungguh bervariasi (0,15–2,17), jadi asumsi
   slope seragam memang mengikat.
3. **Level absolut TFP tidak punya satuan** karena pengali skala warisan do-file. Kutip
   peringkat dan selisih, jangan kutip `exp(cons)` sebagai nilai rupiah.
4. **Modal diukur dengan PMTB (aliran), bukan stok kapital.** Ini penyimpangan dari fungsi
   produksi Solow baku yang memakai stok modal. Perpetual inventory belum tersedia di dataset
   ini; sepanjang rasio investasi/stok relatif stabil antar-provinsi, bias yang timbul terserap
   ke dalam efek provinsi.
5. **2025 kosong** untuk PMTB dan tenaga kerja, jadi seluruh kesimpulan berhenti di 2024.
6. **Endogenitas belum ditangani.** PMTB dan output saling menentukan; seksi IV do-file (PMA/PMDN
   sebagai instrumen untuk PMTB) belum diporting. Elastisitas 0,459 sebaiknya dibaca sebagai
   asosiasi, bukan efek kausal.

---

## 7. Catatan teknis porting

Empat titik yang tidak punya padanan 1:1 antara Stata dan R, ditandai eksplisit di script:

- **`xtreg, mle`** → didekati dengan `nlme::lme` random-intercept ML. Hasilnya sangat dekat
  dengan RE-GLS (b1 = 0,828 vs 0,829), jadi tidak mengubah kesimpulan apa pun.
- **`xttest3`** (modified Wald groupwise heteroskedasticity) → tidak ada di `plm`,
  diimplementasi manual mengikuti formula Greene.
- **R² within/between/overall** → dihitung manual sebagai kuadrat korelasi mengikuti definisi
  `xtreg` Stata, karena definisi R² bawaan `plm` berbeda dan tidak sebanding dengan matriks
  `FIT` di do-file.
- **Seksi IV/GMM** (do-file baris 406–500) tidak diporting — di luar scope.

**Verifikasi.** Identitas Solow `cons_it_k = log Y − b1·log K − b2·log L` (do-file baris 67)
diuji ulang terhadap file output: simpangan maksimum 1,4×10⁻⁵ pada 272 baris — konsisten
dengan pembulatan koefisien, bukan kesalahan perhitungan.

Dua bug yang diperbaiki dari run sebelumnya yang terputus, keduanya gagal secara diam-diam
sebelum akhirnya menghentikan script:

1. `summary(model_FE)$ercomp` bernilai `NULL` (model *within* tidak punya komponen varian).
   `NULL[1]` mengembalikan `NULL` tanpa memicu error, sehingga lolos `tryCatch` dan mengubah
   hasil menjadi *list* → `round()` gagal dan script berhenti di blok terakhir.
2. Komponen varian `plm` bernama `id`/`idios`, bukan `individual`/`idiosyncratic` seperti yang
   tercetak pada `summary()`. Nama yang salah menghasilkan `NA` tanpa peringatan apa pun.
