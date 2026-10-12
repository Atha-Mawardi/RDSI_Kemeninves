# Litrev — elastisitas output modal dan tenaga kerja lintas negara

Dibuat 2026-08-04, direvisi hari yang sama. Menjawab satu pertanyaan: **b1 = 0,400 dan
b2 = 0,191 itu buruk atau baik dibanding negara lain?**

Keluaran terhitungnya di `03 Output/Benchmarking Elastisitas Lintas Negara_0804.xlsx`,
dirakit oleh `02 Code/05_benchmark elastisitas lintas negara.R`. Log jalannya di
`03 Output/log_05_benchmark.txt`.

**Aturan masuk:** hanya studi yang mengestimasi b1 **dan** b2 sekaligus, tanpa memaksakan
imbal hasil konstan. Versi pertama berkas ini memakai 66 negara Senhadji (2000) sebagai
lapisan dasar; seluruh lapisan itu dicabut karena CRS dipaksakan di sana, sehingga b2-nya
bukan hasil estimasi melainkan 1 − b1. Angka semacam itu tidak menjawab apa pun soal
posisi 0,191 maupun soal jumlah 0,591.

Harganya: cakupannya turun dari 67 negara jadi **9 negara, 12 estimasi**. Itu memang harga
yang benar untuk dibayar.

Tingkat verifikasi: **keberadaan sumber**, bukan pembacaan penuh teks asli tiap paper. Status
tiap angka tercatat di kolom `notes` berkas Excel.

---

## 1. Jawaban ringkas

1. **b1 = 0,400 tidak rendah, malah sedikit di atas tengah.** Di antara sembilan negara, ia
   peringkat 7 dari 9, dan mediannya 0,350. Sebarannya 0,071 sampai 0,520.
2. **b2 = 0,191 hampir yang terendah.** Peringkat 2 dari 9. Satu-satunya yang lebih rendah
   adalah Makedonia Utara, dan koefisien tenaga kerja di sana tidak bermakna secara statistik
   (p = 0,46), jadi bukan pembanding sungguhan.
3. **Jumlah 0,591 termasuk rendah tapi punya tetangga.** Peringkat 3 dari 9; median jumlahnya
   0,894.

**Pembacaan yang menyatukan ketiganya, dan ini temuan utamanya:** tiga estimasi dengan b2
paling rendah di seluruh tabel adalah **dua panel provinsi China dan panel provinsi
Indonesia** — 0,190, 0,191, dan 0,230. Ketiganya panel wilayah subnasional Asia dengan efek
tetap dua arah. Nilai b2 rendah bukan ciri ekonomi Indonesia; ia ciri desain estimasi ini.

---

## 2. Seluruh estimasi, diurutkan menurut b2

| b2 | b1 | Jumlah | Wilayah | Unit | Estimator | Modal | Data |
|---|---|---|---|---|---|---|---|
| −0,014 | 0,071 | 0,058 | Makedonia Utara | negara | ARDL bounds | arus | 2005-2024 |
| 0,190 | 0,433 | 0,623 | China | 28 provinsi | two-way FE | stok | 1982-2005 |
| **0,191** | **0,400** | **0,591** | **Indonesia (kajian ini)** | **34 provinsi** | **two-way FE** | **arus** | **2017-2025** |
| 0,230 | 0,170 | 0,400 | China | 31 provinsi | LSDV dua arah | arus | 2000-2009 |
| 0,325 | 0,490 | 0,815 | Indonesia | 26 provinsi | frontier translog | arus | 1993-2000 |
| 0,460 | 0,520 | 0,980 | Italia | 20 wilayah x 17 sektor | kointegrasi panel | stok | 1970-1994 |
| 0,490 | 0,350 | 0,840 | Rusia | 79 region | two-way FE | stok | 2002-2010 |
| 0,510 | 0,490 | 1,000 | Bangladesh | manufaktur | WLS | proksi lemah | s.d. 2013 |
| 0,580 | 0,490 | 1,070 | Yordania | enam sektor swasta | regresi deret | stok | 2000-2015 |
| 0,590 | 0,310 | 0,900 | Amerika Serikat | 48 negara bagian | pooled OLS | stok | 1970-1986 |
| 0,639 | 0,380 | 1,019 | Yordania | negara | ARDL | stok (ICOR) | 1992-2019 |
| 0,703 | 0,191 | 0,894 | India | 16 negara bagian, manufaktur | frontier translog | stok | 1993-2011 |

Baris Makedonia Utara dimuat sebagai kasus ekstrem, bukan pembanding setara: koefisien tenaga
kerjanya negatif dan tidak bermakna, sehingga jumlahnya tidak bisa dibaca sebagai imbal hasil.

Baris Amerika Serikat memuat **input ketiga**, modal publik, dengan elastisitas 0,15. Jumlah
ketiganya 1,05. Karena itu b1 dan b2-nya tidak sebanding langsung dengan model dua input.

---

## 3. Pola yang terbaca

**Tiga pengelompokan yang jelas.**

| Kelompok | Jumlah b1+b2 | Cirinya |
|---|---|---|
| Panel provinsi Asia, efek tetap dua arah | 0,40 - 0,62 | Indonesia dan China, b2 antara 0,19 dan 0,23 |
| Panel wilayah bukan-Asia, atau frontier | 0,82 - 0,98 | Rusia, Italia, Indonesia (frontier) |
| Deret satu negara | 0,90 - 1,07 | Yordania, Amerika Serikat, Bangladesh |

Semakin banyak variasi yang dibuang estimator, semakin rendah jumlahnya. Ini persis tangga
atenuasi yang sudah tercatat di `spesifikasi-model-tfp.md` §4 untuk data kita sendiri:
pooled 1,011 → RE 0,897 → FE 0,803 → two-way FE 0,591. **Pola yang sama muncul lintas studi,
bukan hanya di dalam satu data.** Itu penopang paling kuat untuk kaveat atenuasi.

**Proksi modal arus bukan penjelasnya sendirian.** Margono dkk. juga memproksi modal dengan
arus, di provinsi Indonesia pula, dan berjumlah 0,815 — tetapi pendugannya frontier translog,
bukan efek tetap dua arah. Jadi yang menekan jumlahnya bukan proksi arus, melainkan
kombinasi proksi arus dengan estimator yang membuang variasi antar unit dan antar waktu.

**Hao & Wei tidak membingkai hasilnya sebagai kegagalan.** Mereka menolak CRS dengan F = 31,67
dan menyebutnya "high decreasing returns to scale". Terbit di *The Developing Economies*.
Jadi melaporkan b2 = 0,19 dan jumlah 0,62 dari panel provinsi bukan hal yang tidak bisa
diterbitkan.

---

## 4. Angka tingkat kelompok, juga non-restricted

Miller & Upadhyay memakai bentuk per-pekerja dengan suku ln L, jadi CRS diuji, tidak
dipaksakan. Ini spesifikasi yang paling dekat dengan `spesifikasi-model-tfp.md` §5.

| Kelompok | b1 | b2 | Jumlah |
|---|---|---|---|
| 83 negara, semua | 0,476 | 0,426 | 0,901 |
| **Berpendapatan tinggi** | **0,168** | **0,321** | **0,489** |
| Berpendapatan menengah | 0,569 | 0,253 | 0,822 |
| Berpendapatan rendah | 0,460 | 1,335 | 1,795 |
| Asia | 0,366 | 0,647 | 1,012 |
| Eropa | 0,541 | 0,410 | 0,951 |
| Amerika Latin | 0,511 | 0,570 | 1,081 |
| Afrika | 0,445 | 1,259 | 1,704 |

Dua butir yang berguna:

1. Kelompok berpendapatan tinggi berjumlah **0,489**, lebih rendah daripada 0,591 kajian ini.
   Jumlah di bawah 0,6 pada panel yang menguji imbal hasil bukan hal yang belum pernah terbit.
2. Kelompok berpendapatan menengah, tempat Indonesia berada, memberi **b2 = 0,253** —
   elastisitas tenaga kerja terendah kedua di antara kelompok mana pun. Pola b2 rendah pada
   negara berpendapatan menengah punya preseden.

---

## 5. Sumber yang dicabut dan alasannya

| Sumber | Kenapa dicabut |
|---|---|
| Senhadji (2000), 66 negara | CRS dipaksakan; b2 = 1 − b1, bukan hasil estimasi |
| Honjo, 47 prefektur Jepang | CRS dipaksakan, dan sumbernya bahan presentasi |
| Gechert dkk. (2022), meta-analisis sigma | mengukur elastisitas substitusi, parameter yang berbeda |

Senhadji tetap berguna untuk **argumen lain**, bukan untuk tabel ini: rata-rata pangsa modal
terestimasinya lintas 66 negara adalah 0,55, dan ia menyebut sendiri angka itu "significantly
higher than the usual values (of 0.33 and 0.40) used in growth accounting exercises". Itu
penopang independen untuk keputusan mengestimasi elastisitas alih-alih memakai α baku 1/3 —
lihat `spesifikasi-model-tfp.md` §3. Estimasi Senhadji untuk Indonesia sendiri 0,47.

Gechert dkk. tetap relevan sebagai kaveat bentuk fungsional: dari 3.186 estimasi di 121 studi,
elastisitas substitusi yang paling didukung bukti adalah 0,3 sesudah koreksi bias publikasi,
yang menolak Cobb-Douglas. Itu galat spesifikasi yang tidak masuk galat baku mana pun di
tabel ini. Ia **bukan** pembanding angka b1 atau b2.

---

## 6. Yang tidak boleh disimpulkan

1. **Jangan menulis "elastisitas Indonesia lebih buruk dari negara X".** Elastisitas output
   bukan ukuran prestasi. Ia parameter teknologi terestimasi.
2. **Jangan menyebut b2 = 0,191 anomali Indonesia.** Dua panel provinsi China memberi 0,190
   dan 0,230 dengan desain sama.
3. **Jangan membandingkan baris India dan Bangladesh dengan baris lain tanpa menyebut
   cakupannya.** Keduanya manufaktur, bukan seluruh ekonomi. Modal di baris Bangladesh
   diproksi total kewajiban, yang sukar ditafsirkan sebagai modal.
4. **Jangan memakai baris Amerika Serikat sebagai pembanding dua input.** Ada input ketiga.
5. **Jangan menyebut jumlah 0,591 "terbukti imbal hasil menurun".** Kaveat atenuasi di
   `spesifikasi-model-tfp.md` §4 tetap berlaku, dan §3 litrev ini justru memperkuatnya.

---

## 7. Daftar sumber

| # | Sumber | Tier | Dipakai untuk | Status periksa |
|---|---|---|---|---|
| 1 | Hao, R. & Wei, Z. (2009), *Sources of Income Differences Across Chinese Provinces During the Reform Period*, The Developing Economies 47(1). DOI 10.1111/j.1746-1049.2009.00074.x | T1 | China, panel provinsi, b2 = 0,190 | Crossref, 2026-08-04 |
| 2 | Margono, H., Sharma, S.C., Sylwester, K. & Al-Qalawi, U. (2011), *Technical efficiency and productivity analysis in Indonesian provincial economies*, Applied Economics 43(6). DOI 10.1080/00036840802599834 | T1 | Indonesia, pembanding dalam negeri | Crossref, 2026-08-04 |
| 3 | Heshmati, A. & Su, B. (2013), *Development and Sources of Labor Productivity in Chinese Provinces*, China Economic Policy Review 2(2). DOI 10.1142/s1793969013500052 | T2 | China, data terbaru, modal arus | Crossref, 2026-08-04 |
| 4 | Al-Bess, M.N. & Malawi, A.I. (2025), *Food Security and Marginal Productivity of Labor in Jordan*, Dirasat: Human and Social Sciences. DOI 10.35516/hum.2025.8061 | T2 | Yordania, deret negara | Crossref, 2026-08-04 |
| 5 | Munnell, A.H. (1990), *How Does Public Infrastructure Affect Regional Economic Performance?*, New England Economic Review, FRB Boston | T2 | Amerika Serikat, panel negara bagian | terbitan lembaga, tanpa DOI |
| 6 | Miller, S.M. & Upadhyay, M.P., *Total Factor Productivity, Human Capital, and Outward Orientation*, kertas kerja UNLV | T4 | angka tingkat kelompok | kertas kerja; sepupu terbitannya DOI 10.1016/s0304-3878(00)00112-7 |
| 7 | Marrocu, E., Paci, R. & Pala, R. (2001), *Estimation of Total Factor Productivity for Regions and Sectors in Italy*. DOI 10.2139/ssrn.254390 | T4 | Italia, panel wilayah-sektor | SSRN tanpa versi terbit |
| 8 | *Efficiency of Indian Organized Manufacturing*, publishingindia.com | T4 | India, manufaktur | tanpa DOI |
| 9 | Fungsi produksi region Rusia dengan data panel, *Molodoy Uchenyy* (2013) ed. 58 | T4 | Rusia, 79 region | tanpa DOI, jurnal mahasiswa |
| 10 | *Cobb-Douglas Production Function in North Macedonia: An ARDL Analysis*, Ekonomski Institut (2026) | T4 | kasus ekstrem | tanpa DOI |
| 11 | Husain, S. & Islam, S.M. (2016), *A test for the Cobb-Douglas production function in manufacturing sector: The case of Bangladesh*, IJBER 5(5) | T4 | Bangladesh, manufaktur | tanpa DOI |

Sumber 1-5 dan Senhadji (2000) serta Gechert dkk. (2022) masuk perpustakaan global
`~/.claude/literature/papers/`. Sumber 6-11 tidak, karena tier.

**Empat baris tabel bersumber T4** — Italia, India, Rusia, Makedonia Utara, ditambah Bangladesh
dan baris kedua Yordania. Menurut `~/.claude/skills/tinjauan-literatur/references/standar-sumber.md`,
T4 tidak pernah masuk daftar pustaka naskah klien. Baris-baris itu dipertahankan di tabel kerja
sebagai jejak untuk menemukan padanan T1-nya, bukan sebagai penyangga klaim.

---

## 8. Yang masih terbuka

1. **Cakupan tipis: sembilan negara.** Yang paling perlu ditambah adalah panel provinsi negara
   ASEAN dan negara berpendapatan menengah lain — Vietnam, Thailand, Filipina, Turki, Brasil,
   Meksiko — dengan estimator yang setara. Pencarian hari ini belum menemukan yang melaporkan
   b1 dan b2 sekaligus tanpa restriksi.
2. **Enam dari dua belas estimasi bertier T4.** Sebelum ada satu pun angka di tabel ini masuk
   naskah klien, cari padanan terbitan jurnal terindeks untuk Italia, Rusia, dan India.
   Untuk Italia, mulai dari versi CRENoS-nya.
3. **Angka sumber T1 dan T2 baru diperiksa keberadaannya**, dan dibaca dari versi kertas kerja
   atau badan teks hasil pencarian, bukan dari PDF terbit. Cocokkan ke tabel aslinya sebelum
   dikutip.
4. **Miller & Upadhyay**: yang dipakai versi kertas kerja UNLV. Perlu dipastikan apakah tabel
   per kelompok pendapatan itu juga ada di versi Journal of Development Economics.
5. Studi frontier stokastik untuk wilayah Turki (Yiğiteli & Şanlı 2024, DOI
   10.1007/s40822-023-00255-7) memakai translog dan kemungkinan melaporkan elastisitas output;
   angkanya belum diambil.
