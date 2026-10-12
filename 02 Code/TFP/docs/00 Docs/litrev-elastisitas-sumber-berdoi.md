# Litrev — elastisitas output lintas negara, sumber ber-DOI saja

Dibuat 2026-08-04. Menjawab: **b1 = 0,400 dan b2 = 0,191 itu buruk atau baik dibanding negara
lain?** — dengan pembanding yang boleh masuk daftar pustaka naskah klien.

Keluaran terhitung: `03 Output/Benchmarking Elastisitas Sumber Berdoi_0804.xlsx`, dirakit oleh
`02 Code/06_benchmark elastisitas sumber berdoi.R`, log di `03 Output/log_06_benchmark_berdoi.txt`.

Berkas ini menggantikan `litrev-elastisitas-lintas-negara.md` sebagai rujukan naskah. Berkas
lama tetap disimpan sebagai jejak pencarian; enam barisnya bersumber tanpa DOI atau tanpa
telaah sejawat dan **tidak boleh dikutip**.

---

## 1. Dua aturan masuk, keduanya wajib

| Aturan | Kenapa | Yang gugur |
|---|---|---|
| b1 dan b2 dua-duanya terestimasi, CRS tidak dipaksakan | kalau CRS dipaksakan, b2 = 1 − b1, bukan hasil estimasi | Senhadji (2000) dan seluruh 66 negaranya |
| ber-DOI dan terbit di jurnal bertelaah sejawat | naskah klien tidak boleh menyandarkan angka pada sumber yang tidak pernah diperiksa siapa pun | SSRN tanpa versi terbit, jurnal mahasiswa, terbitan lembaga tanpa telaah |

Yang tersisa: **sebelas estimasi pasangan lengkap** — satu di antaranya kajian ini sendiri, jadi
sepuluh pembanding — plus **tiga estimasi b1 saja** dan **dua rujukan ASEAN**.

---

## 2. Pasangan lengkap, urut menurut b2

| b2 | b1 | Jumlah | Wilayah | Unit | Data | Estimator | Sumber |
|---|---|---|---|---|---|---|---|
| 0,190 | 0,433 | 0,623 | China | 28 provinsi | 1982-2005 | two-way FE | Hao & Wei 2009 |
| **0,191** | **0,400** | **0,591** | **Indonesia (kajian ini)** | **34 provinsi** | **2017-2025** | **two-way FE** | — |
| 0,230 | 0,170 | 0,400 | China | 31 provinsi | 2000-2009 | LSDV dua arah | Heshmati & Su 2013 |
| 0,313 | 0,452 | 0,765 | Eropa Tengah dan Timur | 10 negara | 1995-2014 | panel ECM | Hagemejer & Mućk 2019 |
| 0,325 | 0,490 | 0,815 | Indonesia | 26 provinsi | 1993-2000 | frontier translog | Margono dkk. 2011 |
| 0,592 | 0,374 | 0,966 | Negara industri Barat | 21 negara | 1990 | frontier Bayesian | Koop dkk. 2000 |
| 0,600 | 0,500 | 1,100 | OECD | negara OECD | 1993-2004 | frontier translog | Ghosh & Mastromarco 2013 |
| 0,639 | 0,380 | 1,019 | Yordania | negara | 1992-2019 | ARDL | Al-Bess & Malawi 2025 |
| 0,660 | 0,287 | 0,947 | Asia Timur | 5 negara | 1990 | frontier Bayesian | Koop dkk. 2000 |
| 0,671 | 0,220 | 0,891 | Afrika | 8 negara | 1990 | frontier Bayesian | Koop dkk. 2000 |
| 0,815 | 0,346 | 1,161 | Amerika Latin | 10 negara | 1990 | frontier Bayesian | Koop dkk. 2000 |

Sebaran sepuluh pembanding: b2 dari 0,190 sampai 0,815, median 0,596. Jumlah b1+b2 dari 0,400
sampai 1,161, median 0,919.

**Pasangan metodologis yang paling bersih di tabel ini:** Margono dkk. dan Ghosh & Mastromarco
memakai penduga yang sama persis — frontier translog dengan elastisitas dihitung di titik
rata-rata input. Yang pertama pada provinsi Indonesia memberi jumlah 0,815; yang kedua pada
negara OECD memberi 1,10 dan menolak imbal hasil konstan ke arah **meningkat**. Selisih 0,29
poin itu selisih ekonomi, bukan selisih estimator.

---

## 3. Jawabannya

1. **b1 = 0,400 di atas tengah.** Sebaran b1 pembanding 0,170 sampai 0,500, median 0,360.
   Tidak ada yang perlu dijelaskan dari besarannya sendiri.
2. **b2 = 0,191 terendah kedua**, hanya di atas Hao & Wei (0,190) — selisih satu angka di
   desimal ketiga. Median b2 pembanding 0,596, jadi angka kita kurang dari sepertiganya. Dua
   dari sepuluh pembanding punya b2 di bawah 0,25, dan **keduanya panel provinsi China**.
3. **Jumlah 0,591 termasuk rendah tapi bukan terendah.** Heshmati & Su 0,400 lebih rendah.
   Lima dari sepuluh pembanding juga berjumlah di bawah 0,9.
4. **Yang paling perlu dijelaskan justru b1 > b2.** Hanya tiga dari sepuluh pembanding punya
   elastisitas modal lebih besar daripada tenaga kerja: kajian ini, Hao & Wei, dan Eropa Tengah
   dan Timur. Lihat §3b.

**Yang menyatukan ketiganya.** b2 di bawah 0,25 muncul persis di studi yang memakai **panel
wilayah subnasional dengan efek tetap dua arah** — Hao & Wei dan Heshmati & Su. Tidak muncul
di deret satu negara (Yordania, b2 = 0,639), tidak di panel lintas negara (Eropa Tengah dan
Timur, b2 = 0,313), tidak di panel negara OECD (Ghosh & Mastromarco, b2 = 0,600), dan tidak di
panel provinsi Indonesia yang diduga dengan frontier translog (Margono dkk., b2 = 0,325).

b2 = 0,191 bukan ciri ekonomi Indonesia. Ia ciri kombinasi panel wilayah dengan efek tetap dua
arah. Itu temuan yang bisa dipertahankan dengan sepuluh pembanding ber-DOI.

---

## 3b. Temuan baru: b1 > b2 adalah pola minoritas

Koop, Osiewalski & Steel (2000), *Journal of Business & Economic Statistics* 18(3), DOI
10.1080/07350015.2000.10524871, mengestimasi frontier stokastik Bayesian dengan **frontier
berbeda tiap region** dan **elastisitas yang berubah menurut waktu**, pada 44 negara Penn World
Table 1965-1990. Imbal hasil konstan tidak dipaksakan; satu-satunya batasan yang dipasang
adalah elastisitas tak negatif.

| Region | RTS 1965 | RTS 1990 | b1 1965 | b1 1990 | b2 1965 | b2 1990 |
|---|---|---|---|---|---|---|
| Barat (21 negara) | 1,096 | 0,967 | 0,273 | 0,374 | 0,823 | 0,592 |
| Asia Timur (5 negara) | 0,922 | 0,949 | 0,338 | 0,287 | 0,582 | 0,660 |
| Afrika (8 negara) | 0,966 | 0,893 | 0,135 | 0,220 | 0,830 | 0,671 |
| Amerika Latin (10 negara) | 1,063 | 1,161 | 0,476 | 0,346 | 0,587 | 0,815 |

**Delapan pasangan, delapan kali b1 < b2.** Penulisnya menyatakannya langsung: *"Capital
elasticities tend to be lower than labor elasticities for all regions and all periods."*

Di seluruh tabel §2, hanya tiga dari sepuluh pembanding yang punya b1 > b2 seperti kajian ini:
Hao & Wei (China, 0,433 vs 0,190), Hagemejer & Mućk (Eropa Tengah dan Timur, 0,452 vs 0,313),
dan Heshmati & Su justru sebaliknya (0,170 vs 0,230).

**Konsekuensinya untuk naskah.** Yang perlu dijelaskan bukan sekadar "kenapa b2 rendah",
melainkan **"kenapa modal lebih besar daripada tenaga kerja"** — karena itu pola minoritas di
literatur. Penjelasan yang tersedia dan konsisten dengan `spesifikasi-model-tfp.md` §4: efek
tetap dua arah membuang variasi tenaga kerja antar provinsi dan antar tahun lebih habis daripada
variasi modal, sehingga atenuasinya menghantam b2 lebih keras. Perhatikan tangga atenuasi data
kita sendiri: b1 turun 0,854 → 0,400 (turun 53 persen), sementara b2 naik-turun 0,158 → 0,438 →
0,351 → 0,191. Kedua koefisien bergerak, tetapi urutannya berbalik hanya di ujung two-way FE.

**Dua butir metodologis lain dari paper ini.**

1. **Elastisitas seragam adalah restriksi yang ditolak keras.** Faktor Bayes untuk hipotesis
   bahwa elastisitas suatu region sama dengan Barat berorde 10⁻⁹⁹ (Asia Timur) dan 10⁻⁹³
   (Afrika). Model yang memaksa satu pasang elastisitas untuk semua unit dan semua tahun —
   termasuk model kajian ini — sedang memasang restriksi yang di data lintas negara ditolak
   habis-habisan. Ini keberatan yang jujur untuk dicantumkan di bagian batas.
2. **Dekomposisi tiga arah, bukan dua arah.** Perubahan output dipecah jadi perubahan input,
   perubahan efisiensi, dan perubahan teknologi. Dekomposisi dua arah menggabung efisiensi dan
   teknologi ke satu residual, sehingga penurunan efisiensi bisa menyamar sebagai kemunduran
   teknologi.

**Batas yang harus ikut disebut.** Indonesia **tidak** ada di sampel Koop dkk. Region "Asia
Timur" mereka cuma Hong Kong, Jepang, Korea, Filipina, dan Thailand — jadi ia pembanding taraf
pembangunan, bukan pembanding kawasan. Penulisnya sendiri memperingatkan frontier Asia Timur
dan Afrika ditentukan terlalu sedikit negara. Datanya berhenti 1990, berbasis PWT 5.6.

---

## 4. Tangga atenuasi muncul lintas studi, bukan hanya di data kita

`spesifikasi-model-tfp.md` §4 mencatat tangga atenuasi di data kita sendiri: pooled 1,011 →
random effects 0,897 → fixed effects 0,803 → two-way FE 0,591. Semakin banyak variasi dibuang,
semakin rendah jumlahnya.

Tabel di atas menunjukkan pola yang sama **antar studi**, dengan pengurutan yang sama:

| Kelompok desain | Jumlah b1+b2 | Studinya |
|---|---|---|
| Panel wilayah, efek tetap dua arah | 0,40 - 0,62 | Hao & Wei, Heshmati & Su, kajian ini |
| Panel lintas negara / frontier | 0,77 - 1,16 | Hagemejer & Mućk, Margono dkk., Ghosh & Mastromarco, Koop dkk. |
| Deret satu negara | 1,02 | Al-Bess & Malawi |

Yamarik (2011) menjalankan uji galat ukur Griliches-Hausman langsung pada stok modal negara
bagian Amerika Serikat dan **tidak** menemukan bukti kuat: penduga beda pertama 0,35 dan beda
panjang 0,46 mengapit penduga efek tetap 0,40-0,44. Ini penting sebagai pembanding terbalik —
di data yang stok modalnya diukur baik, tangga atenuasinya tidak muncul. Modal kita diproksi
arus PMTB.

---

## 4b. ASEAN: dicari, tidak ada padanannya

Pencarian 2026-08-04 tidak menemukan **satu pun** studi ber-DOI yang mengestimasi fungsi
produksi panel provinsi negara ASEAN selain Indonesia dengan kedua elastisitas bebas. Yang ada
berhenti di taraf negara atau sektor manufaktur.

| Cakupan | Temuan imbal hasil | Data | Sumber |
|---|---|---|---|
| Delapan ekonomi Asia Timur, termasuk Indonesia, Malaysia, Filipina, Thailand | meningkat di 5 dari 7 ekonomi; tertinggi Filipina 1,33; terendah Malaysia 0,991 | 9 sektor manufaktur, 1973-1998 | Liao dkk. 2009, The Manchester School |
| Lima pendiri ASEAN | tidak dilaporkan sebagai jumlah elastisitas | negara, 1981-2003 | Lee & Cheng 2011, Pacific Economic Review |

**Liao dkk. berguna.** Frontier translog dengan elastisitas dihitung di titik rata-rata,
mencakup Indonesia, dan hasilnya imbal hasil **meningkat** di sebagian besar ekonomi kawasan —
kebalikan arah dari panel provinsi. Tenaga kerja menyumbang paling besar di semua ekonomi
kecuali China, yang mereka baca sebagai cerminan sifat padat karya manufaktur kawasan. Batasnya:
cakupannya manufaktur, dan b1 serta b2 per ekonomi belum terbaca dari hasil pencarian — baru
jumlahnya.

**Lee & Cheng tidak bisa dipakai apa adanya.** Koefisien orde pertama translognya ln L = 0,424
dan ln K = 0,110 pada OLS, dan koefisien modalnya tidak bermakna. Tetapi **koefisien orde
pertama translog bukan elastisitas output** kecuali datanya dipusatkan di rata-rata, dan
papernya tidak menyatakan itu. Angka tersebut tidak boleh dikutip sebagai b1 dan b2.

**Kesimpulan untuk ASEAN.** Kekosongan ini sendiri temuan. Pembanding ASEAN yang setara
desainnya belum ada di literatur berbahasa Inggris yang terindeks, sehingga kajian ini tidak
punya tetangga kawasan untuk dibandingkan. Yang tersedia — taraf nasional dan sektoral —
konsisten menunjukkan imbal hasil di sekitar atau di atas satu, dan itu justru memperkuat
bacaan bahwa jumlah 0,591 lahir dari desain panel provinsi, bukan dari ekonomi kawasan.

---

## 5. Baris b1 saja

Tiga studi menguji imbal hasil tetapi tidak melaporkan b2 sebagai koefisien terpisah.

| b1 | Wilayah | Unit | Data | Temuan imbal hasil | Sumber |
|---|---|---|---|---|---|
| 0,40 | Italia | 20 wilayah | 1970-2003 | CRS **ditolak** ke arah menurun | Costantini & Destefanis 2009 |
| 0,44 | Amerika Serikat | 48 negara bagian | 1990-2007 | uji Wald tidak menolak b1 = 1/3 | Yamarik 2011 |
| 0,6175 | Spanyol | 17 wilayah | 1986-2010 | hasil kokoh terhadap asumsi CRS | Aray 2017 |

Costantini & Destefanis penting: **b1 mereka 0,40, persis angka kita, pada panel 20 wilayah
Italia dengan penduga yang menangani dependensi lintas unit, dan mereka juga menolak imbal
hasil konstan ke arah menurun.** Kedekatan angka ini kebetulan, tetapi arah kesimpulannya
bukan.

Kaveat wajib: angka Costantini & Destefanis di sini **kutipan sekunder** dari Eberhardt & Teal
(2011), belum dari teks aslinya. Sebelum dikutip di naskah, buka Economic Modelling 26(2).

---

## 6. Yang tidak boleh disimpulkan

1. **Jangan menulis "elastisitas Indonesia lebih buruk dari negara X".** Elastisitas output
   bukan ukuran prestasi; ia parameter teknologi terestimasi.
2. **Jangan menyebut b2 = 0,191 anomali Indonesia.** Hao & Wei mendapat 0,190 di panel provinsi
   China dan menerbitkannya sebagai temuan, bukan kegagalan.
3. **Jangan membandingkan baris Yordania dengan panel wilayah sebagai perbandingan ekonomi.**
   Itu perbandingan estimator: deret satu negara tidak membuang variasi antar unit.
4. **Jangan memakai baris b1 saja sebagai pasangan.** Ketiganya tidak melaporkan b2 terpisah.
5. **Jangan menyebut jumlah 0,591 "terbukti imbal hasil menurun".** Kaveat atenuasi di
   `spesifikasi-model-tfp.md` §4 tetap berlaku, dan §4 berkas ini memperkuatnya.

---

## 7. Daftar sumber

Dua belas sumber, seluruhnya ber-DOI. Sepuluh terbit di jurnal yang terindeks; dua belum
dipastikan dan ditandai. Hanya satu — Koop dkk. — yang PDF terbitnya sudah dibaca langsung.

| # | Sumber | Jurnal | DOI | Indeks |
|---|---|---|---|---|
| 1 | Hao, R. & Wei, Z. (2009), *Sources of Income Differences Across Chinese Provinces During the Reform Period: A Development Accounting Exercise* | The Developing Economies 47(1) | 10.1111/j.1746-1049.2009.00074.x | terindeks |
| 2 | Margono, H., Sharma, S.C., Sylwester, K. & Al-Qalawi, U. (2011), *Technical efficiency and productivity analysis in Indonesian provincial economies* | Applied Economics 43(6) | 10.1080/00036840802599834 | terindeks |
| 3 | Hagemejer, J. & Mućk, J. (2019), *Export-led growth and its determinants: Evidence from Central and Eastern European countries* | The World Economy 42(7) | 10.1111/twec.12790 | terindeks |
| 4 | Costantini, M. & Destefanis, S. (2009), *Cointegration analysis for cross-sectionally dependent panels: The case of regional production functions* | Economic Modelling 26(2) | 10.1016/j.econmod.2008.07.014 | terindeks |
| 5 | Aray, H. (2017), *More on decentralization and economic growth* | Papers in Regional Science 97(4) | 10.1111/pirs.12305 | terindeks |
| 6 | Yamarik, S. (2011), *State-level capital and investment: Updates and implications* | Contemporary Economic Policy 31(1) | 10.1111/j.1465-7287.2011.00282.x | terindeks |
| 6b | Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), *Modeling the Sources of Output Growth in a Panel of Countries* | Journal of Business & Economic Statistics 18(3) | 10.1080/07350015.2000.10524871 | terindeks |
| 7 | Ghosh, S. & Mastromarco, C. (2013), *Cross-border Economic Activities, Human Capital and Efficiency: A Stochastic Frontier Analysis for OECD Countries* | The World Economy 36(6) | 10.1111/twec.12010 | terindeks |
| 8 | Liao, H., Liu, X., Holmes, M. & Weyman-Jones, T. (2009), *The impact of foreign R&D on total factor productivity in the East Asian manufacturing industry* | The Manchester School 77(2) | 10.1111/j.1467-9957.2008.02096.x | terindeks |
| 9 | Lee, Y.H. & Cheng, M.Y. (2011), *Catching-up and technological progress of the ASEAN economies* | Pacific Economic Review 16(2) | 10.1111/j.1468-0106.2011.00545.x | terindeks |
| 10 | Heshmati, A. & Su, B. (2013), *Development and Sources of Labor Productivity in Chinese Provinces* | China Economic Policy Review 2(2) | 10.1142/s1793969013500052 | **belum dipastikan** |
| 11 | Al-Bess, M.N. & Malawi, A.I. (2025), *Food Security and Marginal Productivity of Labor in Jordan* | Dirasat: Human and Social Sciences | 10.35516/hum.2025.8061 | **belum dipastikan** |

Sumber pendukung yang dipakai untuk mengutip baris Italia: Eberhardt, M. & Teal, F. (2011),
*Econometrics for Grumblers*, Journal of Economic Surveys 25(1), DOI
10.1111/j.1467-6419.2010.00624.x, terindeks.

Seluruh DOI diperiksa lewat Crossref pada 2026-08-04.

### Yang dibuang dari berkas lama

| Sumber | Sebab |
|---|---|
| Senhadji (2000), 66 negara, IMF Staff Papers | CRS dipaksakan |
| Marrocu, Paci & Pala (2001), Italia | SSRN tanpa versi terbit |
| Miller & Upadhyay, kelompok pendapatan dan wilayah | kertas kerja UNLV, tanpa DOI |
| Munnell (1990), negara bagian Amerika Serikat | terbitan lembaga tanpa DOI; digantikan Yamarik (2011) |
| Studi manufaktur India, studi region Rusia, Makedonia Utara, Bangladesh | tanpa DOI, tanpa telaah sejawat |

Senhadji tetap berguna untuk argumen yang berbeda dan sudah tercatat di
`spesifikasi-model-tfp.md` §3: rata-rata pangsa modal terestimasinya lintas 66 negara 0,55,
dan ia menyebut sendiri angka itu jauh di atas nilai baku 0,33 dan 0,40 yang lazim dikalibrasi.
Itu penopang untuk keputusan mengestimasi elastisitas, bukan pembanding b2.

---

## 8. Yang masih terbuka

1. **Keterindeksan sumber 10 dan 11 belum diperiksa.** Kalau salah satunya ternyata tidak
   terindeks, baris China 2000-2009 dan baris Yordania gugur, dan pembanding tinggal tiga.
   Periksa lewat Scopus Sources atau `is_indexed_in_scopus` di OpenAlex.
2. **Angka baris Italia masih kutipan sekunder.** Buka Economic Modelling 26(2) sebelum dikutip.
3. **Angka sebagian besar sumber dibaca dari badan teks hasil pencarian atau versi kertas
   kerja**, bukan dari PDF terbit. Cocokkan ke tabel aslinya sebelum masuk naskah.
4. **Pembanding ASEAN sudah dicari dan tidak ada padanannya** — lihat §4b. Yang tersisa untuk
   dikejar: elastisitas per ekonomi di Liao dkk. (2009) Tabel 2, yang memuat Indonesia,
   Malaysia, Filipina, dan Thailand tetapi baru terbaca jumlahnya. Membuka PDF-nya akan
   menambah empat baris kawasan sekaligus.
5. **Baris Yamarik belum lengkap.** Model tanpa restriksinya menghasilkan koefisien tenaga
   kerja yang tidak stabil (0,71 pada beda pertama, 1,29 dan tidak bermakna pada beda panjang).
   Kalau Tabel 2 aslinya memuat pasangan b1-b2 efek tetap tanpa restriksi, baris itu bisa
   naik ke sheet `pasangan_lengkap`.
