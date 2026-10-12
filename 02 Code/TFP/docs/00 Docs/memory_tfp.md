# memory_tfp.md — Memori Kajian TFP BKPM

Dokumen ini dibuat agar sesi berikutnya (manusia atau AI) bisa masuk ke topik TFP tanpa
mengulang pembacaan 272 halaman dokumen dan 24 sitasi. Tanggal: 2026-07-18.

Sumber: `01 Input/txt/` (13 dokumen Masterplan TFP), `00 Docs/catatan-literatur.md`,
`BKPM-local/TFP calc/run_log.txt`, dan verifikasi numerik langsung atas dataset provinsi.

---

## 1. Posisi TFP dalam kebijakan Indonesia

**Gerakan 8-4-2-2 (Bappenas).** Untuk menembus pertumbuhan 8% pada 2029 dibutuhkan komposisi
**4 poin tenaga kerja + 2 poin modal + 2 poin TFP** (narasi Masterplan hal. 48 / Foreword). Paparan
peluncuran dan Tabel 3 menulis sebaliknya; kajian mengikuti narasi (koreksi 2026-09-05). Residual
yang diukur di sini adalah residual produksi berbasis PMTB, bukan TFP Hicks-neutral.
Sumber: `Materi Paparan__04. REV_Paparan Bapak Deputi_Diskusi Panel.txt` hal. 9; audit `docs/06 Review/`.

**Masalahnya: realisasi TFP jauh dari 2 poin.** Dekomposisi APO di Masterplan (Tabel 1,
hal. 42; sumber APO data 2024) untuk Indonesia:

| Periode | Output | Tenaga kerja | Kapital | TFP |
|---|---|---|---|---|
| 2006–10 | 5,45 | 1,74 (31,9%) | 3,21 (58,9%) | 0,50 (9,2%) |
| 2011–15 | 5,29 | 2,67 (50,5%) | 3,51 (66,3%) | −0,89 (−16,8%) |
| **2016–22** | **3,59** | **1,13 (31,6%)** | **2,80 (78,1%)** | **−0,35 (−9,7%)** |
| 1971–2000 | 6,05 | 2,20 (36,3%) | 3,59 (59,3%) | 0,26 (4,4%) |
| 2001–22 | 4,60 | 1,81 (39,4%) | 2,94 (63,9%) | −0,15 (−3,3%) |
| 1971–2022 | 5,44 | 2,03 (37,4%) | 3,31 (61,0%) | 0,09 (1,6%) |

Jadi jarak ke target bukan sedikit: dari −0,35 menuju +2,0 poin persen.

**Tren jangka panjang memburuk.** Output turun 8,28% (1971–75) → 3,59% (2016–22); produktivitas
tenaga kerja 2,23% → 1,13%; capital deepening 4,08% → 2,80%; TFP 1,96% → −0,35%.
Korelasi pertumbuhan–TFP di Indonesia ditaksir 0,89. Masterplan hal. 42–43.

**APO menyebutnya pergeseran paradigma.** Sekjen APO (Dr. Indra) di peluncuran MPPN: "dari
pertumbuhan bertumpu pada akumulasi input ke pertumbuhan yang dipacu oleh TFP". APO juga
mencatat "variasi TFP antardaerah yang lebar: ada provinsi yang tumbuh dengan bauran tenaga
kerja, modal, dan TFP yang seimbang; ada pula yang **investasi bertambah tetapi produktivitas
tak bergerak**." Kalimat terakhir itu tepat menggambarkan temuan kajian BKPM ini.

---

## 2. Temuan Masterplan yang langsung berhadapan dengan kajian kita

**Masterplan sudah punya estimasi TFP provinsi, dan cakupannya sama: 34 provinsi.** Papua dan
Papua Barat hasil pemekaran dikeluarkan karena datanya belum cukup — persis alasan dataset kita
juga 34. Semua estimasi produktivitas Masterplan "primarily based on the Solow model".

**Tabel 5 Masterplan (hal. 51, "Source of Economic Growth: Selected Provinces") mengandung
patologi yang harus kita hindari.** Baris "Total Provinces" 2013–22: Output 3,40 (100%),
Tenaga kerja 0,78 (23%), Kapital 4,28 (126%), **TFP −1,66 (−49%)**. Tetapi angka tahunannya:

- Kapital: 14,14 → 3,22 → 24,56 → 17,98 → **−73,30** → 40,09 → 3,31 → 3,04 → 6,86 → 2,90
- TFP: −8,66 → 1,23 → −19,66 → −14,39 → **+77,37** → −36,65 → 0,66 → −4,97 → −5,66 → −5,83

Kapital dan TFP bergerak sebagai cermin sempurna satu sama lain. DKI 2017: kapital −36,04,
TFP +47,62; 2018 kapital +34,89, TFP −32,05. Ini **artefak mekanis dari memakai arus investasi
sebagai ukuran modal**, bukan ekonomi. Konsekuensi untuk kita: (a) jangan pernah menyajikan
dekomposisi tahun-per-tahun, hanya rata-rata periode; (b) kita punya contoh terbit yang
menunjukkan apa yang salah, sehingga caveat kita bukan sekadar kehati-hatian teoretis.

**Perbandingan Kalimantan Timur adalah peringatan.** Masterplan menilai Kaltim "highly balanced"
dengan kontribusi tenaga kerja/kapital/TFP = 36%/26%/38%. Perhitungan lama kita menyebut TFP
Kaltim turun −2,45%/tahun. Verifikasi data: pertumbuhan PMTB Kaltim 8–15%/tahun melawan PDRB
riil 2,6–6,2%. Karena PMTB masuk regresor dengan koefisien positif, lonjakan investasi
menurunkan TFP terukur secara mekanis. **Angka Kaltim kita adalah artefak, bukan temuan.**

---

## 3. Metode: apa yang dipakai dan mengapa

Keputusan user (18/07/2026): **regresi panel yang mengestimasi elastisitas**, bukan growth
accounting dengan α baku 1/3 + stok modal PIM seperti tertulis di kerangka BAB 7.3.2 laporan.
Konsekuensinya 7.3.2 perlu direvisi.

**Dasar literatur untuk pilihan ini kuat.** Di Giacinto & Nuzzo (2006) menyatakan estimasi
ekonometrik "avoiding the assumptions of perfectly competitive markets and constant returns to
scale that are needed to derive output elasticities from factor shares". Niebel dkk. (2017)
merinci penyebab elastisitas menyimpang dari income share: kesalahan pengukuran, non-CRS,
persaingan tidak sempurna, spillover. Tang & MacLeod (2006) menambahkan bahwa upah sering
ditentukan tawar-menawar kolektif, bukan produk marjinal.

**Bukti empiris yang paling meyakinkan justru dari data Indonesia sendiri, tetapi cakupannya
terbatas.** van der Eng (2010) melaporkan pangsa tenaga kerja Indonesia 38,2% (1980), 47,0%
(1990), 51,3% (1995), dengan minimum 28%. Olomola & Osinubi (2018) memaksakan 0,6 untuk Indonesia
— di luar seluruh rentang itu.

**Hati-hati: rentang 28–51% hanya sah untuk menolak pangsa pendapatan impor sebagai deskripsi
pangsa pendapatan Indonesia. Ia TIDAK boleh dipakai menilai elastisitas hasil regresi.** Seluruh
argumen kita bertumpu pada premis bahwa elastisitas output berbeda dari pangsa pendapatan; memakai
pangsa pendapatan untuk memvalidasi elastisitas akan membatalkan premis itu sendiri. Versi awal
catatan ini menyebut elastisitas 0,438 "tervalidasi" karena jatuh di dalam rentang van der Eng —
itu keliru dan sudah dicabut. Tambahan pula, estimasi CRS kita (b2 = 0,554) justru lebih dekat ke
0,6 milik Olomola daripada ke batas atas van der Eng, sehingga argumen itu juga akan berbalik.

Alasan menolak α=1/3 karena itu **tidak** boleh bersandar pada "menyiratkan 2/3 untuk tenaga
kerja". Alasan yang sah ada dua: asumsi pasar kompetitif sempurna yang gagal (§4 di bawah), dan
ketidaklayakan PIM provinsi dengan seri 8 tahun (lihat `spesifikasi-model-tfp.md` §3).

**Jangan menulis** "factor share negara lain tidak berlaku karena struktur ekonomi berbeda" —
tidak ada rujukannya. Pakai bingkai "asumsi yang gagal", atau bukti empiris di atas.

---

## 4. Empat jebakan metodologis yang sudah teridentifikasi

### 4.1 PMTB adalah arus, bukan stok — dan biasnya ke bawah

Chen & Plotnikova (2018) menurunkan arah biasnya: bila proksi dan stok modal sebenarnya hanya
berkorelasi lemah, "this estimator is biased **downwards**". Griliches & Hausman (1986)
menjelaskan mengapa fixed effects memperburuk, bukan meredam: measurement error "gets magnified
in the within dimension", menghasilkan koefisien "too low and insignificant".

Konsisten dengan yang kita amati: b1 FE (0,452) < b1 RE (0,459), dan elastisitas bentuk growth
(0,213) jauh di bawah bentuk level (0,459). **Implikasi yang harus ditulis: elastisitas modal
kita adalah batas bawah, sehingga residual TFP kita menyerap sebagian kontribusi modal — TFP
terukur cenderung terlalu besar, bukan terlalu kecil.**

### 4.2 RTS besar adalah gejala salah spesifikasi, bukan aglomerasi

Ini koreksi terpenting dari riset literatur. Elastisitas aglomerasi empiris berkisar 0,01–0,20
dengan "majority of values under 0.10" (Graham 2009). Derajat skala ekonomi = elastisitas
aglomerasi (Kakamu dkk. 2012). Maka RTS yang konsisten dengan literatur adalah **1,01–1,10**.

Lee & Park (2024) mendapat RTS 1,323 dan menyebutnya "**unreasonably large; this is a potential
sign of CSD [cross-sectional dependence]**"; setelah dikoreksi turun ke 1,084.

Kasus kita cocok persis: ADHB-FE memberi RTS **1,540** dan uji Pesaran CD pada ADHB menghasilkan
**z = 33,6**. Jadi RTS janggal itu punya pembacaan diagnostik berbasis literatur, bukan sekadar
"tidak masuk akal secara ekonomi". **Jangan pernah membingkai RTS >1,1 sebagai bukti aglomerasi.**

### 4.3 Hausman klasik tidak sah di sini

Uji Hausman mengasumsikan RE efisien di bawah H0, yang menuntut homoskedastisitas dan tanpa
autokorelasi. Keduanya kita tolak pada p<0,001 (Modified Wald; Wooldridge AR(1)). StataCorp
(2025) menyatakan uji ini "cannot be performed after estimation using cluster–robust, bootstrap,
or jackknife standard errors", dan menganjurkan uji Mundlak yang tetap valid.

Karena itu Hausman ADHK p=0,074 **tidak admissible**; yang berlaku adalah Mundlak (p<0,001) →
FE. Ketegangan Hausman-vs-Mundlak selesai dalam satu kalimat, bukan jadi dilema.
Rujukan primer: Mundlak (1978). Jangan mengutip Wooldridge (2010) dari ingatan — halamannya
belum diverifikasi.

### 4.4 Deret waktu TFP model ini lemah; peringkat antar provinsi kuat

ρ = 0,992: 99,2% varian bersifat antar-provinsi. Simpangan baku residual dalam-provinsi 0,035
lebih besar daripada seluruh rentang pergerakan deret TFP nasional delapan tahun (0,020 poin
log). Fluktuasi tahunan tidak dapat dibedakan dari galat dan **tidak boleh dinarasikan**.

Karena itu: tidak ada CAGR TFP. Penggantinya efek tahun dari two-way FE beserta selang
kepercayaan. Preseden literaturnya sedang, bukan kuat — Muinelo-Gallo & Roca-Sagalés (2011)
menyatakan "the period-specific intercepts pick up productivity changes that are common to all
countries", tetapi tidak ada preseden memublikasikannya sebagai "indeks TFP" bernama. Tulis
sebagai ekstensi kita sendiri, dengan dua peringatan: level efek tahun arbitrer (hanya
perubahannya bermakna), dan efek tahun menyerap seluruh guncangan agregat termasuk siklus
bisnis dan harga.

---

## 5. Kesalahan pada perhitungan lama yang sudah diverifikasi

Tercatat di `BKPM-local/TFP calc/Laporan Analisis TFP Provinsi.md`, harus dikoreksi.

**5.1 "Pertumbuhan TFP 2,24%/tahun" salah.** Itu intercept regresi bentuk growth, yang hanya
bermakna TFP bila koefisiennya menjumlah 1. Faktanya 0,213 + 0,273 = 0,486. Verifikasi numerik:
rata-rata pertumbuhan PMTB 6,58%, tenaga kerja 2,33%, PDRB riil 4,59%; input menjelaskan 2,04
poin; setelah dinormalisasi ke CRS kontribusi input menjadi 2,04/0,486 = 4,19 poin, sehingga
**TFP tersisa sekitar 0,4 poin persen per tahun**. Angka 2,24 hampir seluruhnya *scale gap*.

Angka 0,4 itu konsisten dengan pembanding eksternal: APO −0,35 (2016–22), van der Eng −0,2
(1971–2007), Rusiawan dkk. −0,62 (1976–2011). Konvergensi ini menguatkan.

**5.2 Sekitar 22% dispersi TFP antar provinsi adalah artefak ukuran.** Δcons = log λ × (1−b1−b2)
= log λ × 0,103. Rentang PDRB riil antar provinsi sekitar 30× (log 3,4), sehingga 0,35 dari 1,62
poin log murni skala — dan selalu berarah "makin besar makin produktif". Hilang bila CRS
dipaksakan.

**5.3 Cluster-robust SE tidak menangani cross-sectional dependence.** Report lama mengklaim
sudah. ADHK-FE gagal Pesaran CD (z=3,24, p=0,001). Perbaikannya year effects (CD turun ke
p=0,19) atau Driscoll-Kraay.

**5.4 Arah pergeseran level FE-vs-RE.** Benar untuk ADHK (FE ~1,5 poin log di atas RE), terbalik
untuk ADHB (FE ~5,6 poin log di bawah RE).

---

## 6. Angka kunci untuk dikutip cepat

| Besaran | Nilai | Sumber |
|---|---|---|
| Target kontribusi TFP 2029 | +2,0 poin persen | Bappenas, Gerakan 8-4-2-2 |
| TFP Indonesia 2016–22 (APO) | −0,35%/thn, −9,7% dari pertumbuhan | Masterplan Tabel 1 |
| TFP Indonesia 1971–2007 | −0,2%/thn | van der Eng (2009) |
| TFP Indonesia 1976–2011 | −0,62 poin dari PDB 4,58% | Rusiawan dkk. (2015) |
| TFP dari pertumbuhan 1880–2007 | hanya 7–13% | van der Eng (2010) |
| Kontribusi stok modal 1967–97 | 56–61% | van der Eng (2010) |
| Share tenaga kerja Indonesia | 28–51% | van der Eng (2010) |
| Elastisitas kita (ADHK-RE) | modal 0,459; tenaga kerja 0,438 | run_log.txt |
| RTS wajar menurut literatur regional | 1,01–1,10 | Graham (2009), Kakamu dkk. (2012) |
| Rentang pertumbuhan PMTB provinsi | 6,58%/thn rata-rata | verifikasi dataset |

---

## 6b. Temuan tambahan dari putaran kerja 18/07/2026

**Pangsa pendapatan tenaga kerja dapat dihitung dari dataset, dan hasilnya mengejutkan.** Kolom
`*_RataUpah` (17 sektor) memuat pendapatan bulanan per pekerja mencakup upah, barang, kerja paruh
waktu, dan pemasukan wirausaha. Pangsa terhitung: 15,1% (2017) → 17,9% (2024), median antar
provinsi-tahun 18,3%, bobot Divisia 0,159. Angka itu jauh di bawah rentang 28–51% van der Eng.
Dipakai sebagai bobot growth accounting, ia memberi elastisitas modal 0,841 dan kontribusi modal
134,5% pertumbuhan — hasil yang tidak dapat dipertahankan. **Jangan pakai sebagai bobot; pakai
untuk memfalsifikasi α=1/3.** Provinsi ekstraktif berpangsa terendah (Riau 0,089, DKI 0,090), NTB
tertinggi (0,357).

**Satuan `9_ADHB` dan `9_ADHK` adalah TRILIUN rupiah**, meskipun nama berkas menyebut miliar.
Diverifikasi: jumlah 34 provinsi 2023 = 20.532 triliun terhadap PDB Indonesia sekitar 20.900
triliun. Ini penting untuk perhitungan apa pun yang memakai satuan absolut.

**Masterplan bertentangan dengan dirinya sendiri soal Gerakan 8-4-2-2.** Teks naratif hal. 48 dan
Foreword hal. VII menulis "Labor (4%) + Capital (2%) + TFP (2%)". Paparan peluncuran hal. 9 dan
Tabel 3 Masterplan menyatakan sebaliknya, yaitu modal 4. **Koreksi 2026-09-05: kajian mengikuti
narasi (4 tenaga kerja + 2 modal).** Di bawah itu, jarak yang mengikat adalah tenaga kerja.

**Koreksi atas §4.4 di atas: ρ=0,988 adalah korelasi intraklas, bukan autokorelasi.** Klaim
autokorelasi harus bersandar pada uji Wooldridge AR(1) (p<0,001), bukan pada ρ.

**Revisi pelaporan skala hasil (2026-07-21): non-CRS primer, CRS diagnostik.** Basis utama laporan
kini elastisitas terestimasi non-CRS/DRS (b1=0,400, b2=0,191); CRS turun jadi diagnostik +
kontrafaktual tersimulasi (skrip `04_simulasi drs vs crs.R`, `Simulasi DRS vs CRS.xlsx/.png`). Dasar
di litrev `litrev-twfe-drs-tfp.md`: memaksakan CRS membocorkan suku skala `(1−b1−b2)·g_input` ke
residual; TFP dipulihkan sebagai residual yang masih memuat `u_i` sehingga heterogenitas antar-daerah
terjaga. **Kaveat wajib:** penolakan CRS sebagian bisa atenuasi proksi arus PMTB (Griliches &
Mairesse 1998; Basu & Fernald 1997), sehingga b1 batas bawah dan TFP basis utama dilebih-lebihkan;
TFP sebenarnya kemungkinan antara ~0 (kontrafaktual CRS) dan 0,98 poin (DRS), condong ke bawah.
Dominasi modal bertahan di kedua (64% non-CRS, 71% CRS); yang berpindah besaran TFP (26% vs −1%).

**Level pulau (basis utama non-CRS).** Dekomposisi sisa: Sulawesi +1,78, Jawa +1,24, Sumatera +0,72,
Maluku-Papua +0,50, Bali-Nusra +0,01, Kalimantan −0,11. Indeks TFP 2024: Kalimantan 142,4; Jawa
130,5; Sumatera 124,3; Sulawesi 117,4; Maluku-Papua 114,5; Bali-Nusra 101,0. (Varian CRS lama:
Sulawesi +0,37, Jawa +0,32, Sumatera −0,26, Bali-Nusra −1,17, Kalimantan −1,24, Maluku-Papua −1,53.)
Perbandingan dengan Tabel 6 Masterplan tidak menambah bukti karena seri Masterplan 2020–22 rusak.

**Peringkat provinsi (basis utama non-CRS) berubah dari versi CRS.** Puncak kini DKI +1,24, Jawa
Timur +1,03, Jawa Barat +1,00, Kaltim +0,75, Jawa Tengah +0,72 — didorong skala tenaga kerja karena
b2 rendah (0,191), sehingga provinsi berpenduduk besar naik. Klaim lama "6 dari 7 teratas ekstraktif/
enklave" hanya berlaku pada versi CRS, jangan dipakai untuk basis utama.

**Empat putaran review menemukan pola kesalahan yang berulang: klaim yang cakupannya lebih luas
daripada buktinya.** Contohnya "seluruh estimasi", "seluruh skenario CRS", "tidak bergantung
skenario", "dua perubahan sudah diantisipasi". Semuanya benar untuk sebagian kasus dan salah
untuk kasus yang tidak disebut. Pada penulisan berikutnya, setiap kuantor universal perlu dicek
terhadap daftar lengkap kasusnya.

## 6c. Putaran kerja 11/08/2026 — panel provinsi dan dataset umum

**Kontribusi TFP per provinsi jauh lebih menyebar daripada angka nasionalnya.** Nasional 57,8
persen; provinsinya membentang dari Papua Barat 6,4 persen sampai Sumatera Selatan 84,8 persen.
DKI dan Bali sama-sama 76 persen. Yang di ujung bawah — Papua Barat, Kalimantan Timur 12,4
persen, NTB 17,8 persen — punya kontribusi modal besar tapi PDRB tumbuh pelan. Angkanya di
`03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx`, sheet `rata_provinsi`. **Kaveat §7
berlaku penuh di sini:** tidak ada pembanding literatur untuk kontribusi TFP tingkat provinsi,
jadi jangan tulis "sejalan dengan literatur".

**Dekomposisi tahun-per-tahun tingkat provinsi ada, tapi bukan untuk laporan.** Sheet `panel`
memuatnya karena berguna sebagai alat kerja. Ayunannya besar dan mekanis: Aceh 2022 kontribusi
modalnya −0,30 sementara PDRB tumbuh 4,13, jadi sisanya melompat ke 4,31. Aturan penyajian di
skrip 02 tetap berlaku — laporan memakai rata-rata periode.

**`logtfp_it_crs` berbentuk per-pekerja.** Ia `log(Y/L) − b1_crs·log(K/L)`, sementara
`logtfp_it` tiga suku penuh. Levelnya tidak sebanding. Yang boleh dibandingkan peringkat dan
pergerakannya, bukan selisih levelnya.

**Dataset umum project menarik angka TFP lewat tautan luar Excel, bukan tempel manual.**
`All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` kolom `FD:FN` berisi
formula `INDEX/MATCH` yang dipasangkan lewat `Year & Pre_Prov`. Sejak 11 Agustus tautannya
menunjuk `03 Output (modal riil)`. Siapa pun yang ingin mengubah angka TFP di sana harus lewat
`02 Code/14_perbarui tautan dataset umum.py`, bukan mengetik ke selnya.

**Dua kolom log yang tidak terpengaruh basis harga.** `log_ADHK_Tot` dan `log_lab_tot` identik
sampai digit terakhir di basis nominal maupun riil. Sakelar `BASIS_MODAL` hanya menyentuh sisi
modal, jadi kalau ada yang mengusulkan "perbarui juga tenaga kerjanya", jawabannya tidak perlu.

**Nol yang berarti tidak ada data.** Baris 2025 di dataset umum dulu tercatat `log_lab_tot = 0`
dan `logtfp_it = 0`, bukan kosong, karena `INDEX` atas sel kosong mengembalikan nol. Sudah
diperbaiki dengan penjaga `IFERROR(IF(…="","",…),"")`. Pola yang sama patut dicurigai di kolom
hasil pencarian mana pun di workbook itu.

## 7. Yang belum dikerjakan / hati-hati

- Angka kontribusi TFP tingkat **provinsi** tidak punya pembanding di literatur akademik.
  Kataoka (2020) satu-satunya studi provinsi, tetapi keluarannya indeks Malmquist relatif.
  Kalau kita menghasilkan persen kontribusi per provinsi, itu **kontribusi baru** — jangan
  tulis "sejalan dengan literatur".
- Angka World Bank/ADB/UNESCAP belum diverifikasi dari dokumen aslinya; jangan dikutip dulu.
- DOI van der Eng (2010) belum dikonfirmasi balik. 12 sitasi berstatus V-meta perlu cek DOI
  sekali lagi sebelum daftar pustaka dikunci.
- Tabel 1 Rusiawan (2015) punya kejanggalan: kolom "Capital Growth" 5,48 identik untuk fase 1
  dan 2. Hati-hati bila mengutip angka per fase.
- SFA dan DEA sengaja ditunda ke keluaran berikutnya (sudah dinyatakan di kerangka 7.3 laporan).
