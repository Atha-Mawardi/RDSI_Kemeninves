# Spesifikasi Model TFP — desain perhitungan dan alasan tiap pilihan

Versi 2026-07-18. Menggantikan spesifikasi di `../01_analisis TFP provinsi.R`.
Skrip: `02 Code/01_estimasi tfp.R`, `02 Code/02_dekomposisi nasional.R`.

---

## 1. Model dasar

```
log Y[i,t] = a + b1 · log K[i,t] + b2 · log L[i,t] + u[i] + λ[t] + e[i,t]
TFP[i,t]   = exp(a + u[i] + e[i,t])
```

| Simbol | Variabel | Kolom dataset |
|---|---|---|
| Y | PDRB harga konstan | `9_ADHK` |
| K | PMTB | `pmtb` |
| L | tenaga kerja total | jumlah 17 kolom `*_TenagaKerja` |
| u[i] | efek provinsi | — |
| λ[t] | efek tahun | dummy `factor(Year)` |

Panel 34 provinsi × 2017–2024. 306 baris tersedia, **272 terpakai** — PMTB dan tenaga kerja
belum ada untuk 2025. Bentuk growth kehilangan tahun pertama tiap provinsi, tersisa 238.

**Elastisitas diestimasi, tidak diimpor.** Kerangka BAB 7.3.2 laporan semula menetapkan α baku
1/3 dengan stok kapital PIM. Itu diubah atas keputusan user. Dasar perubahannya di §3.

---

## 2. Kaskade seleksi model (S0–S6)

Aturan ditetapkan sebelum hasil dilihat. Kolom tabel diagnostik adalah input aturan; verdict
adalah pembacaan, bukan pertimbangan.

| Langkah | Aturan | Hasil |
|---|---|---|
| **S0** | Variabel terikat harus output riil. TFP konsep riil; residual dari regresi output nominal memuat perubahan harga. Restriksi *a priori*, bukan hasil pencarian data. | ADHK. ADHB hanya kontras diagnostik. |
| **S1** | Breusch-Pagan LM menolak → ada efek individu | p<0,001 → efek individu |
| **S2** | Bila Modified Wald **atau** Wooldridge AR(1) menolak, Hausman klasik tidak sah. Pakai uji Mundlak. | Wald-het p<0,001; AR(1) p<0,001 → Hausman gugur. Mundlak p<0,001 → **FE** |
| **S3** | Bila Pesaran CD menolak → tambah efek tahun, uji ulang | CD satu-arah p=0,001 → tambah efek tahun. CD two-way **masih** p<0,001 → lanjut ke S6 |
| **S4** | Uji Wald `b1+b2=1` | Ditolak di semua spesifikasi (lihat §4) |
| **S5** | RESET | ADHK-FE p=0,343; ADHK-RE p=0,083 → Cobb-Douglas dipertahankan |
| **S6** | SE cluster provinsi; pindah ke Driscoll-Kraay bila CD masih menolak | CD masih menolak → **Driscoll-Kraay** |

**Model terpilih: ADHK, two-way fixed effects (provinsi + tahun), SE Driscoll-Kraay.**

### Kenapa Hausman klasik dibuang

Uji Hausman bersandar pada `Var(b_FE − b_RE) = Var(b_FE) − Var(b_RE)`, yang hanya berlaku bila
RE efisien di bawah H0. Efisiensi itu menuntut homoskedastisitas dan tanpa autokorelasi — dua
asumsi yang ditolak pada p<0,001. StataCorp (2025) menyatakan uji ini "cannot be performed after
estimation using cluster–robust, bootstrap, or jackknife standard errors". Karena itu Hausman
ADHK p=0,074 **tidak admissible**, dan tidak ada dilema FE-vs-RE untuk diperdebatkan.
Rujukan formulasi pengganti: Mundlak (1978).

---

## 3. Kenapa mengestimasi elastisitas, bukan memakai α baku 1/3

Tiga alasan, urut dari yang paling kuat.

**(a) Bukti empiris dari data Indonesia sendiri.** van der Eng (2010) melaporkan pangsa tenaga
kerja Indonesia 38,2% (1980), 47,0% (1990), 51,3% (1995), dengan minimum 28%. Rentang 28–51%
itu tidak konsisten dengan α=1/3 untuk modal (yang menyiratkan 2/3 untuk tenaga kerja), maupun
dengan 0,6 yang dipakai Olomola & Osinubi (2018) untuk Indonesia.

**(b) Asumsi yang disyaratkan tidak terpenuhi.** Menurunkan elastisitas dari pangsa pendapatan
menuntut pasar faktor kompetitif sempurna, utilisasi input penuh, dan CRS (Inklaar dkk. 2007).
Niebel dkk. (2017) merinci penyebab elastisitas menyimpang dari pangsa pendapatan: kesalahan
pengukuran, non-CRS, persaingan tidak sempurna, spillover tak terukur. Tang & MacLeod (2006)
menambahkan bahwa upah kerap ditentukan tawar-menawar kolektif, bukan produk marjinal.

**(c) Preseden metodologis di konteks regional.** Di Giacinto & Nuzzo (2006) mengestimasi
parameter fungsi produksi pada panel wilayah-sektor Italia justru untuk "avoiding the assumptions
of perfectly competitive markets and constant returns to scale that are needed to derive output
elasticities from factor shares".

**Yang tidak boleh ditulis:** "pangsa faktor negara lain tidak berlaku karena struktur ekonominya
berbeda". Tidak ada rujukan yang membingkai masalahnya begitu. Pakai bingkai "asumsi yang gagal"
atau bukti empiris (a).

---

## 4. Returns to scale: elastisitas terestimasi non-CRS sebagai basis, CRS sebagai diagnostik

**Perubahan kebijakan pelaporan (2026-07-21).** Basis utama laporan kini adalah elastisitas
terestimasi tanpa restriksi (non-CRS/DRS: b1=0,400, b2=0,191, jumlah 0,591). Varian skala hasil
konstan (CRS) turun status menjadi diagnostik yang menjelaskan pilihan model dan menjadi
kontrafaktual tersimulasi (skrip `04_simulasi drs vs crs.R`). Alasannya (litrev
`00 Docs/litrev-twfe-drs-tfp.md`): memaksakan CRS menaruh suku skala `(1−b1−b2)·g_input` ke residual
sehingga TFP terkontaminasi pertumbuhan input (Barro 1999); dan TFP dipulihkan sebagai residual yang
masih memuat `u_i`, sehingga heterogenitas TFP antar-provinsi terjaga (Hulten 2001; Combes dkk.
2008). **Kaveat wajib:** sebagian penolakan CRS bisa merupakan atenuasi karena modal diproksi arus
PMTB (Griliches & Mairesse 1998; Basu & Fernald 1997), bukan skala hasil menurun struktural,
sehingga b1=0,400 kemungkinan batas bawah dan residual TFP basis utama cenderung dilebih-lebihkan.

Uji Wald `H0: b1+b2 = 1` ditolak di semua spesifikasi:

| Spesifikasi | b1+b2 | p |
|---|---|---|
| ADHK-RE | 0,897 | 0,041 |
| ADHK-FE | 0,803 | 0,003 |
| ADHK two-way FE | 0,591 | <0,001 |
| ADHB-FE | 1,540 | <0,001 |

**Tetapi angka-angka ini tidak boleh dibaca sebagai temuan DRS.** Perhatikan tangga atenuasi:

| Spesifikasi | Variasi yang dibuang | b1 | b2 | b1+b2 |
|---|---|---|---|---|
| Pooled OLS | tidak ada | 0,854 | 0,158 | **1,011** |
| Random effects | sebagian antar-provinsi | 0,459 | 0,438 | 0,897 |
| Fixed effects | seluruh antar-provinsi | 0,452 | 0,351 | 0,803 |
| Two-way FE | antar-provinsi + antar-tahun | 0,400 | 0,191 | 0,591 |

Penurunan monoton seiring makin banyak variasi dibuang adalah tanda tangan *measurement error*,
bukan bukti skala. Griliches & Hausman (1986) menunjukkan error pengukuran pada regresor "gets
magnified in the within dimension", menghasilkan koefisien "too low and insignificant". Chen &
Plotnikova (2018) menurunkan arah biasnya untuk kasus proksi modal yang lemah korelasinya dengan
stok sebenarnya: **bias ke bawah**. Estimasi pooled, yang membuang paling sedikit variasi,
justru yang paling dekat ke CRS (1,011).

Karena itu dekomposisi **basisnya** memakai elastisitas terestimasi non-CRS (skenario F), dan
varian CRS disajikan sebagai pembanding/kontrafaktual. Selisih keduanya besar dan dinyatakan
terbuka: tren efek tahun +0,81%/thn tanpa CRS versus **−0,26%/thn** dengan CRS; sisa nasional
+0,98 poin (non-CRS) versus −0,05 poin (CRS). Pada basis utama, sisa 0,98 poin harus dibaca dengan
kaveat atenuasi di atas, sehingga TFP yang sebenarnya kemungkinan berada di antara nol (kontrafaktual
CRS) dan 0,98, condong ke ujung bawah.

### Catatan tentang ADHB-FE = 1,540

Jangan dibingkai sebagai *increasing returns* akibat aglomerasi. Elastisitas aglomerasi empiris
berkisar 0,01–0,20 dengan mayoritas di bawah 0,10 (Graham 2009), dan derajat skala ekonomi setara
dengan elastisitas aglomerasi (Kakamu dkk. 2012), sehingga RTS yang konsisten dengan literatur
adalah 1,01–1,10. Lee & Park (2024) mendapat RTS 1,323 dan menyebutnya "unreasonably large; this
is a potential sign of CSD"; setelah dikoreksi turun ke 1,084. Kasus kita cocok: ADHB gagal
Pesaran CD dengan z=33,6. RTS 1,540 adalah **gejala salah spesifikasi**, bukan temuan ekonomi.

---

## 5. Model CRS bentuk per-pekerja

```
log(Y/L) = a + b1 · log(K/L) + u[i] + λ[t] + e[i,t]
```

Memaksakan `b2 = 1 − b1` lewat konstruksi variabel, bukan restriksi numerik. Hasil:
**b1 = 0,4455 (SE Driscoll-Kraay 0,0544), b2 = 0,5545.**

Pangsa tenaga kerja implisit 0,554 berada sedikit di atas rentang van der Eng (28–51%), tetapi
jauh lebih dekat kepadanya daripada 2/3 yang tersirat dari α=1/3.

TFP diekstrak sebagai `log(Y/L) − b1·log(K/L) = a + u[i] + e[i,t]`.

---

## 6. Deret waktu TFP: efek tahun, bukan CAGR

**CAGR TFP tidak dilaporkan, dan itu disengaja.** ρ = 0,9964: 99,6% varian model bersifat
antar-provinsi, sehingga deret nasional bertumpu pada irisan variasi dalam-provinsi yang tipis.
Residualnya terautokorelasi kuat (Wooldridge p<0,001), sehingga titik ujung adalah titik paling
tidak andal — dan CAGR hanya memakai titik ujung. (Catatan: dengan basis non-CRS, rentang deret
nasional 8 tahun 0,0662 kini lebih besar dari sd residual dalam-provinsi 0,0327, sehingga argumen
"sd melebihi rentang" pada versi CRS lama tidak lagi dipakai.)

Penggantinya: koefisien dummy tahun dari two-way FE beserta selang kepercayaannya. **Basis utama**
memakai model tak-terestriksi (non-CRS): indeks naik dari 100 (2017) ke 106,8 (2024), tren
**+0,81%/tahun (p=0,002)**; spesifikasi bertren + Driscoll-Kraay memberi +0,63%/thn (p=0,017).

Tabel di bawah adalah **kontrafaktual CRS** (efek tahun model per-pekerja skala hasil konstan),
yang justru menurun:

| Tahun | Koefisien | SE | Indeks (2017=100) |
|---|---|---|---|
| 2017 | 0 (basis) | — | 100,00 |
| 2018 | −0,0025 | 0,0030 | 99,75 |
| 2019 | −0,0106 | 0,0074 | 98,95 |
| 2020 | −0,0191 | 0,0061 | 98,11 |
| 2021 | −0,0250 | 0,0091 | 97,53 |
| 2022 | −0,0226 | 0,0127 | 97,76 |
| 2023 | −0,0184 | 0,0148 | 98,17 |
| 2024 | −0,0144 | 0,0166 | 98,57 |

Tren linear kontrafaktual CRS **−0,27%/tahun (SE 0,0014, p=0,049)**. Arah tanda yang berlawanan
antara basis utama dan kontrafaktual menegaskan tanda tren TFP bergantung pada asumsi skala hasil.

Dua peringatan yang wajib ikut ditulis:
1. Level efek tahun arbitrer, hanya relatif terhadap tahun basis. Hanya perubahannya bermakna.
2. Efek tahun menyerap **seluruh** guncangan agregat — siklus bisnis, harga, term-of-trade —
   bukan hanya kemajuan teknologi. Palung 2021 kemungkinan besar utilisasi kapasitas akibat
   COVID, bukan regres teknologi.

Preseden literaturnya sedang, bukan kuat. Muinelo-Gallo & Roca-Sagalés (2011) menyatakan
"the period-specific intercepts pick up productivity changes that are common to all countries",
tetapi tidak ada preseden memublikasikan deret ini sebagai "indeks TFP" bernama. Ini **ekstensi
kami sendiri** dan harus ditulis begitu.

Untuk tren per provinsi, dipakai regresi 8 titik dengan SE, bukan selisih dua ujung. Hasilnya:
**23 dari 34 provinsi** punya tren TFP yang berbeda dari nol pada p<0,05 di basis non-CRS (batas
atas, karena SE dari residual terautokorelasi positif terlalu kecil).

---

## 7. Dekomposisi nasional

Agregasi 34 provinsi (jumlah PDRB riil, PMTB, tenaga kerja), lalu
`g(Y) = b1·g(K) + b2·g(L) + sisa`. Identitas terverifikasi hingga 8,9×10⁻¹⁶.

**Bukan growth accounting**, dan penamaan ini dijaga. Growth accounting mensyaratkan stok kapital
PIM dan pangsa faktor dari data pendapatan. Sebut "dekomposisi pertumbuhan berbasis elastisitas
terestimasi". Residual dilabeli **"Sisa (TFP + galat)"**, bukan "TFP".

Basis utama F (non-CRS) plus empat skenario CRS sebagai pembanding:

| Skenario | b1 | b2 | Dasar |
|---|---|---|---|
| **F. Tanpa restriksi (basis utama)** | **0,400** | **0,191** | elastisitas two-way FE apa adanya |
| A. Level (CRS) | 0,446 | 0,554 | elastisitas terestimasi bentuk level |
| B. Growth (CRS) | 0,364 | 0,636 | elastisitas bentuk growth, dinormalisasi |
| D. α baku (CRS) | 0,333 | 0,667 | asumsi awal kerangka 7.3.2, tanpa estimasi |
| E. PIM (CRS) | 0,446 | 0,554 | elastisitas A, modal stok PIM |

Hasil 2018–2024: pertumbuhan PDRB riil 3,83%/thn. Basis utama F: kontribusi modal 2,45 poin (64%),
tenaga kerja 0,40 poin (10%), **sisa 0,98 poin (25,7%)**. Varian CRS: kontribusi modal 2,04–2,73
poin (53–71%), sisa −0,05 s.d. +0,40 poin.

Kesimpulan "pertumbuhan didominasi akumulasi input" **bertahan di basis utama maupun varian CRS**
(dominasi modal 64% versus 53–71%). Yang berpindah antar keduanya adalah besaran sisa TFP: 25,7%
di basis utama versus di bawah 11% pada varian CRS. Angka basis utama harus dibaca dengan kaveat
atenuasi (§4).

**Hanya rata-rata periode, tidak pernah tahun-per-tahun.** `g(PMTB) ≈ g(stok modal)` menuntut
rasio investasi/stok stabil, dan itu terlanggar telak pada 2020–21. Tabel 5 Masterplan
memperlihatkan akibat melanggar aturan ini: TFP tahunan berayun dari −36,65 ke +77,37 sebagai
cerminan mekanis pergerakan investasi.

---

## 8. Batasan yang harus ikut terbit

1. **Modal adalah arus, bukan stok.** Elastisitas modal bias ke bawah (Chen & Plotnikova 2018),
   dan FE memperbesarnya (Griliches & Hausman 1986). Konsekuensi logisnya: residual TFP menyerap
   sebagian kontribusi modal yang tidak tertangkap, sehingga **TFP terukur cenderung terlalu
   besar, bukan terlalu kecil**. Ini penalaran kami, bukan kutipan.
2. **Bias agregasi nyata.** Panel berbobot pangsa output memberi b1=0,299 dan b2=0,036, jauh dari
   estimasi tanpa bobot (0,400/0,191). Panel membobot tiap provinsi sama, agregat nasional
   membobot pangsa output. Ini alasan tambahan menyajikan dekomposisi sebagai rentang.
3. **Cross-sectional dependence tidak sepenuhnya teratasi.** Efek tahun tidak cukup (CD masih
   p<0,001); Driscoll-Kraay dipakai sebagai kompensasi pada inferensi, bukan pada titik estimasi.
4. **Endogenitas tidak diidentifikasi.** PMTB lag-1 memberi b1=0,416 (vs 0,400 kontemporer),
   jadi simultanitas kontemporer bukan penggerak utama — tetapi ini bukan identifikasi kausal.
   Baca seluruh elastisitas sebagai asosiasi.
5. **Tidak ada pembanding provinsi di literatur.** Kataoka (2020) satu-satunya studi TFP provinsi
   Indonesia, dan keluarannya indeks Malmquist relatif, bukan persen kontribusi. Angka provinsi
   kami adalah kontribusi baru — jangan tulis "sejalan dengan literatur".

## 9. Yang sengaja tidak dikerjakan

**IV/2SLS dengan PMA/PMDN sebagai instrumen PMTB — ditolak, bukan dilewati.** Dua alasan.
(a) *Exclusion restriction* gagal secara definisi: PMA dan PMDN masuk komponen PMTB.
menetapkan PMA/PMDN adalah bagian dari PMTB pada komponen aset tetap non-tanah, sehingga
instrumen memengaruhi output lewat saluran yang sama dengan regresor yang diinstrumen.
(b) Instrumen lemah: `02_analisis korelasi pmtb pma-pmdn.R` menemukan within-R² hanya 0,13 pada
two-way FE. 2SLS dengan instrumen lemah bias ke arah OLS dengan galat baku jauh lebih besar.

**Translog — ditolak.** RESET tidak menolak linearitas (p=0,343 dan 0,083). Dengan T=8 dan dua
input, translog menambah tiga parameter yang sangat kolinear. Di translog, returns to scale
menjadi fungsi yang dievaluasi di satu titik, bukan parameter — memperlemah diskusi CRS.

**SFA dan DEA — ditunda** ke keluaran berikutnya, sesuai kerangka 7.3 laporan.
