# Produktivitas Total Faktor: Pengukuran dan Kontribusinya terhadap Pertumbuhan

> **Vintage freeze (2026-09-05).** Badan teks di bawah ini adalah laporan versi lama
> (b1 = 0,400; b2 = 0,191; tren residual 0,81%/thn; pangsa modal ~64%). Keluaran kode
> terkini ada di `01 Data/TFP/output/modal_riil/` (b1 = 0,402; b2 = 0,147; tren 1,92%/thn;
> pangsa modal 34%). Jangan mencampur angka. Residual = produksi berbasis arus PMTB,
> bukan TFP Hicks-neutral. §1.5 memakai alokasi 8-4-2-2 resmi. Lihat `docs/VINTAGE.md`.

## 1. Definisi dan urgensi TFP

### 1.1 Apa itu TFP

Produktivitas total faktor mengukur bagian pertumbuhan output yang tidak dijelaskan oleh
pertambahan modal dan tenaga kerja. Definisi operasionalnya berasal dari fungsi produksi
Cobb-Douglas:

```
Y = A · K^b1 · L^b2
```

dengan Y output, K modal, L tenaga kerja, dan A tingkat produktivitas. Dalam bentuk logaritma,
A muncul sebagai residual, yaitu apa pun yang tersisa setelah kontribusi input dikurangkan. OECD
merumuskannya sebagai kemampuan "memproduksi lebih banyak dengan lebih sedikit" (Bureau & Antón
2022, dikutip dalam Masterplan Produktivitas Nasional).

Karena TFP adalah residual, ia menyerap kemajuan teknologi, kualitas kelembagaan, dan efisiensi
alokasi, bersama seluruh kesalahan pengukuran pada output dan input. Angka TFP karena itu
membatasi peran produktivitas dari atas. Ia tidak mengukurnya.

### 1.2 Skala hasil: CRS, DRS, dan IRS

Skala hasil (*returns to scale*) menjawab satu pertanyaan: bila seluruh input digandakan sekaligus,
berapa kali lipat output naik? Pada fungsi Cobb-Douglas jawabannya terbaca dari jumlah elastisitas
b1 + b2.

- **Skala hasil konstan (CRS), b1 + b2 = 1.** Menggandakan modal dan tenaga kerja tepat menggandakan
  output. Ini asumsi baku *growth accounting*: bobot input diturunkan dari pangsa pendapatan faktor
  dengan anggapan pasar kompetitif sempurna (Barro 1999).
- **Skala hasil menurun (DRS), b1 + b2 < 1.** Output naik kurang dari dua kali lipat. Menambah input
  secara proporsional memberi tambahan output yang menyusut.
- **Skala hasil meningkat (IRS), b1 + b2 > 1.** Output naik lebih dari dua kali lipat, biasanya karena
  aglomerasi: pemusatan kegiatan menurunkan biaya bersama dan memperbesar limpahan pengetahuan.
  Skala hasil yang konsisten dengan aglomerasi terukur berkisar 1,01–1,10, sedangkan elastisitas
  aglomerasinya sendiri berada di bawah 0,10 (Graham 2009; Kakamu dkk. 2012).

Perbedaan ini menentukan sejauh mana pertumbuhan bisa disandarkan pada akumulasi input semata. Di
bawah DRS, menumpuk modal dan tenaga kerja tanpa kenaikan produktivitas menghadapi langit-langit:
laju pertumbuhan melandai seiring input bertambah. Debat "keajaiban Asia Timur" adalah ilustrasi
paling terkenal. Young (1995) menunjukkan pertumbuhan pesat Singapura, Korea, dan tetangganya hampir
seluruhnya berasal dari kenaikan partisipasi kerja, pendidikan, dan rasio investasi, dengan
pertumbuhan TFP yang tidak istimewa. Krugman (1994) menarik implikasinya: pertumbuhan yang ditopang
*perspiration* ketimbang *inspiration* akhirnya melandai, sebuah pola yang ia paralelkan dengan
pertumbuhan Uni Soviet yang mengandalkan mobilisasi sumber daya. Gaya kerja mikro di balik pelandaian
itu adalah produk marjinal modal yang menurun—dibahas pada §1.3—yang bekerja bahkan ketika skala
hasil agregatnya konstan; skala hasil menurun hanya memperberatnya.

IRS menjanjikan pertumbuhan yang menguat sendiri melalui klaster dan kota, tetapi ia harus ditegakkan
dari data, bukan diasumsikan. Kajian ini menaksir b1 + b2 = 0,591, yaitu skala hasil menurun
terukur, dan tidak menemukan IRS; angka 1,540 yang sempat muncul pada satu spesifikasi mencerminkan
salah-spesifikasi ketimbang aglomerasi (§3.2). Mengapa DRS terukur ini sebagian bisa merupakan
artefak pengukuran alih-alih teknologi yang benar-benar berskala menurun, juga dijelaskan di §3.2.

### 1.3 Modal, tenaga kerja, dan TFP: kenapa investasi yang sama tak selalu berbuah sama

Ketiga sumber pertumbuhan bekerja lewat saluran yang berbeda. Menambah modal—membangun pabrik, jalan,
mesin—menggerakkan output *sepanjang* fungsi produksi, dengan bobot elastisitas b1. Karena b1 lebih
kecil dari satu, tiap unit modal tambahan memberi tambahan output yang makin kecil: inilah produk
marjinal modal yang menurun, dan ia berlaku bahkan bila skala hasil agregatnya konstan. Menambah
tenaga kerja bekerja serupa lewat b2. TFP berbeda jenis: ia menggeser *seluruh* fungsi produksi ke
atas, sehingga jumlah modal dan tenaga kerja yang sama menghasilkan output lebih banyak.

Perbedaan saluran itu menjelaskan mengapa rupiah investasi yang sama tidak berbuah pertumbuhan yang
sama. Dua daerah bisa menambah PMTB dengan laju identik namun tumbuh berbeda, bergantung pada ke mana
modal itu mengalir (sektor produktif atau rente sumber daya), apakah ia berpasangan dengan tenaga
kerja terampil dan teknologi yang memadai, dan seberapa penuh kapasitasnya terpakai. Alokasi,
komplementaritas, utilisasi, dan kemajuan teknologi tak-terwujud semuanya masuk ke TFP. Satu hal
justru tidak: kemajuan teknologi yang *terwujud* dalam mesin baru tercatat sebagai kontribusi modal,
bukan TFP, karena ia terbeli bersama barang modalnya (van der Eng 2010, §1.4).

Data kajian ini menampakkan pola itu, meski harus dibaca sebagai tafsir atas residual ketimbang
perbedaan teknologi antar daerah—elastisitas nasional yang sama dipakai untuk semua pulau (§3.3).
Jawa menyisakan 1,24 poin pertumbuhan di luar kontribusi input, Kalimantan menyisakan −0,11 poin.
Sisa negatif Kalimantan berarti input tumbuh lebih cepat daripada output, pola khas ekonomi yang
investasinya ekstraktif dan padat modal; galat pengukuran modal memperberatnya. Sisa itu karena itu
mencerminkan komposisi investasinya, dan membacanya semata sebagai inefisiensi teknis akan keliru.

Tenaga kerja memikul ambiguitas yang setara. Yang diukur adalah jumlah orang bekerja, bukan mutunya.
Bila keterampilan angkatan kerja meningkat, pendalaman modal manusia itu jatuh ke residual dan ikut
terhitung sebagai TFP (Batasan 2). Karena itu "menambah tenaga kerja" dengan mutu tetap dan
"menaikkan mutu tenaga kerja" muncul di dua tempat berbeda pada dekomposisi.

Pada tingkat agregat, mahalnya menumpuk modal terangkum dalam ICOR sekitar 6 yang dilaporkan Bab 5.3
laporan induk: perlu sekitar enam rupiah investasi untuk menaikkan output satu rupiah. Angka setinggi
itu menegaskan pesan §1.2, bahwa akumulasi modal saja, tanpa kenaikan TFP, adalah jalan pertumbuhan
yang mahal dan makin berat.

### 1.4 Mengapa TFP penting bagi Indonesia

Pertumbuhan Indonesia bersandar pada akumulasi faktor. van der Eng (2010) menghitung TFP hanya
menjelaskan 7–13% pertumbuhan PDB selama 1880–2008, sementara pertumbuhan stok modal menjelaskan
44–61% sepanjang periode itu dan 56–61% pada masa pertumbuhan cepat 1967–1998. Artikel tersebut
tidak konsisten dengan dirinya sendiri: badan teksnya menyebut 6–12% sedangkan kesimpulannya
7–13%; angka kesimpulan yang dikutip di sini. Untuk periode yang lebih dekat, van der Eng (2009)
memperoleh pertumbuhan TFP rata-rata
−0,2% per tahun selama 1971–2007. Rusiawan dkk. (2015) dengan growth accounting Divisia
memperoleh kontribusi TFP −0,62 poin dari pertumbuhan PDB 4,58% selama 1976–2011.

Rata-rata jangka panjang itu menutupi ayunan antar-dekade. van der Eng (2009) mencatat
pertumbuhan TFP mencapai +1,7% per tahun pada 2000–2007 dan menjelaskan 33% pertumbuhan PDB.
Musyawwiri dan Üngör (2019), memakai Penn World Table, menemukan kontribusi TFP "turned
persistently positive after 1999". Perbaikan itu tidak bertahan setelah 2010. Dekomposisi APO
yang dipakai Masterplan Produktivitas Nasional mencatat TFP −0,89% pada 2011–2015 dan −0,35% pada
2016–2022 (Tabel 1).

Dalam rentang lima dekade, seluruh komponen melemah bersamaan. Pertumbuhan output turun dari
8,28% pada 1971–1975 ke 3,59% pada 2016–2022, dan pertumbuhan TFP dari +1,96% ke −0,35%
(Masterplan Produktivitas Nasional, hal. 26).

van der Eng sendiri meragukan angka rendah itu berarti Indonesia tidak mengalami kemajuan
teknologi, karena sebagian kemajuan dapat ter-*embodied* dalam stok modal dan karenanya tercatat
sebagai kontribusi modal.

**Tabel 1. Dekomposisi sumber pertumbuhan Indonesia versi APO (%/tahun)**

| Periode | Output | Tenaga kerja | Modal | TFP |
|---|---:|---:|---:|---:|
| 2006–2010 | 5,45 | 1,74 (31,9%) | 3,21 (58,9%) | 0,50 (9,2%) |
| 2011–2015 | 5,29 | 2,67 (50,5%) | 3,51 (66,3%) | −0,89 (−16,8%) |
| 2016–2022 | 3,59 | 1,13 (31,6%) | 2,80 (78,1%) | −0,35 (−9,7%) |
| 1971–2022 | 5,44 | 2,03 (37,4%) | 3,31 (61,0%) | 0,09 (1,6%) |

Sumber: Masterplan Produktivitas Nasional 2025–2029, Tabel 1, berbasis data APO (2024). Angka
dalam kurung adalah pangsa terhadap pertumbuhan output. Pangsa modal dan tenaga kerja berjumlah
lebih dari 100% pada periode ketika TFP tumbuh negatif; pada 2011–2015 keduanya berjumlah 116,8%.
Ini pola yang lazim pada dekomposisi jenis ini.

Dalam perbandingan internasional, Masterplan mencatat kontribusi TFP terhadap pertumbuhan
Indonesia sebesar 10%, terhadap rata-rata enam negara pembanding 16%, dan terhadap lima negara maju
sekitar 24%.

### 1.5 Urgensi kebijakan

Bappenas menerjemahkan sasaran pertumbuhan 8% pada 2029 ke dalam komposisi yang disebut Gerakan
8-4-2-2. Teks naratif Masterplan hal. 48 dan Foreword hal. VII menuliskan **empat poin tenaga kerja,
dua poin modal, dan dua poin TFP**. Paparan peluncuran (7 Oktober 2025, hal. 9) dan Tabel 3
Masterplan (proyeksi 2029: modal 3,69; tenaga kerja 2,28; TFP 1,89) menulis sebaliknya. Kajian ini
mengikuti narasi resmi: **4 tenaga kerja + 2 modal + 2 TFP**. Kode lama membalik alokasi itu;
dikoreksi 5 September 2026.

Residual di bawah ini adalah residual produksi berbasis arus PMTB, bukan TFP yang diturunkan
Bappenas dari stok PIM dan pangsa pendapatan. Perbandingan indikatif.

**Tabel 2. Jarak realisasi 2018–2024 terhadap sasaran 8-4-2-2 (poin persen)**

| Komponen | Sasaran 2029 | Realisasi laporan (vintage A) | Realisasi kode terkini (vintage B, F) | Jarak (B) |
|---|---:|---:|---:|---:|
| Modal | 2,0 | 2,45 | 1,30 | 0,70 |
| Tenaga kerja | 4,0 | 0,40 | 0,31 | 3,69 |
| Residual PMTB | 2,0 | 0,98 | 2,22 | −0,22 |
| Output | 8,0 | 3,83 | 3,83 | 4,17 |

Di bawah alokasi resmi, jarak yang mengikat adalah tenaga kerja (3,69 poin). Residual PMTB vintage B
sudah di atas 2 poin, tetapi itu sisa regresi PMTB, bukan TFP growth accounting. Di bawah
parameterisasi pangsa modal 1/3 (skenario D), sisa vintage B menjadi 1,36 poin.

---

## 2. Perhitungan TFP

### 2.1 Literatur perhitungan TFP

Literatur menyediakan empat keluarga metode. Rinciannya ada di Lampiran A.

*Growth accounting* mendekomposisi pertumbuhan output memakai bobot pangsa pendapatan faktor,
tanpa estimasi ekonometrik. Rusiawan dkk. (2015) menerapkannya untuk Indonesia dengan bobot
Divisia yang dihitung dari data upah. Metode ini menuntut pasar faktor kompetitif sempurna,
utilisasi input penuh, dan skala hasil konstan (Inklaar dkk. 2007).

*Solow residual dengan pangsa impor* memakai bobot dari literatur negara lain. Olomola dan Osinubi
(2018) memakai 0,6 untuk tenaga kerja dan 0,4 untuk modal pada empat negara termasuk Indonesia,
mengikuti Chen (1997) serta Easterly dan Levine (2001) sebagaimana mereka kutip. Pangsa 0,6 itu
tidak sesuai dengan pengukuran pangsa pendapatan Indonesia: van der Eng (2010) melaporkan pangsa
tenaga kerja 38,2% pada 1980, 47,0% pada 1990, dan 51,3% pada 1995. Pangsa itu pernah jatuh ke 28%
pada 1998, tetapi van der Eng menyebutnya anomali akibat lonjakan inflasi dan mengeluarkannya dari
interpolasinya, sehingga rentang yang layak dibandingkan adalah 38–51%.
Olomola dan Osinubi juga memakai PMTB sebagai ukuran modal, sama seperti kajian ini, tanpa
membahas konsekuensinya.

*Regresi fungsi produksi* mengestimasi elastisitas dari data. Di Giacinto dan Nuzzo (2006)
memakainya pada panel wilayah-sektor Italia untuk menghindari asumsi pasar kompetitif sempurna dan
skala hasil konstan yang diperlukan bila elastisitas diturunkan dari pangsa pendapatan. Tang dan
MacLeod (2006) menerapkannya pada panel sepuluh provinsi Kanada.

Pada panel wilayah, TFP adalah residual Solow (Solow 1957), yaitu bagian pertumbuhan output yang
tidak terjelaskan oleh input terukur. Hulten (2001) menyebutnya "a measure of our ignorance":
residual menyerap teknologi, efisiensi, kelembagaan, aglomerasi, dan kualitas input yang tidak
tertangkap. Karena residual inilah wadah heterogenitas produktivitas, letak efek provinsi `u_i`
menentukan apakah perbedaan TFP antar-daerah terjaga atau tersapu. Bila `u_i` dimasukkan sebagai
regresor lewat transformasi *within*, level produktivitas antar-provinsi ikut disapu; bila
elastisitas diestimasi lalu TFP dipulihkan sebagai residual `log Y − b1·log K − b2·log L` yang
**masih memuat `u_i`**, perbedaan antar-provinsi tetap hidup di dalam ukuran TFP. Combes, Duranton,
dan Gobillon (2008) justru mengekstraksi efek tetap wilayah sebagai ukuran produktivitas lokal dan
menunjukkan gagal mengontrol heterogenitas komposisi dapat membiaskan estimasi secara substansial.
Efek tetap dua arah karena itu berperan ganda: efek tahun menyerap guncangan makro bersama, efek
provinsi meredam endogenitas input, sedangkan level produktivitas daerah dibiarkan mengendap di
residual (Griliches dan Mairesse 1998). Kajian ini menempuh jalur itu.

*DEA-Malmquist* tidak mengasumsikan bentuk fungsional. Kataoka (2020) menerapkannya pada provinsi
Indonesia 1990–2015 dan mendekomposisi indeks Malmquist menjadi perubahan efisiensi dan perubahan
teknologi; ia menemukan skala hasil dan perubahan teknologi yang bervariasi antar-daerah, sehingga
skala hasil menurun pada sebagian provinsi adalah pola yang lazim. Keluarannya indeks efisiensi relatif, yang tidak dapat dibaca sebagai persen kontribusi
terhadap pertumbuhan. Kataoka sendiri mencatat DEA bersifat deterministik dan mengabaikan galat
acak.

Stochastic frontier analysis disebut dalam literatur sebagai alternatif parametrik. Pendalamannya
dijadwalkan pada keluaran berikutnya.

### 2.2 Metode kajian

**Data.** Panel 34 provinsi, 2017–2024, 272 observasi terpakai. Tahun 2025 tidak masuk karena PMTB
dan tenaga kerja belum tersedia. Output diukur dengan PDRB harga konstan, modal dengan PMTB, dan
tenaga kerja dengan penjumlahan 17 kolom tenaga kerja sektoral. Cakupan 34 provinsi mengikuti
ketersediaan data; empat provinsi hasil pemekaran Papua dikeluarkan, sama seperti yang dilakukan
Masterplan Produktivitas Nasional.

**Mengapa elastisitas diestimasi.** Kerangka awal kajian ini menetapkan pangsa modal 1/3 dengan
stok kapital perpetual inventory. Pendekatan itu tidak dapat dijalankan dengan data yang tersedia.
Perpetual inventory menuntut stok awal `K₀ = I₀/(g+δ)` dan seri investasi panjang, sedangkan PMTB
provinsi hanya tersedia sejak 2017. Dengan depresiasi 5%, galat stok awal meluruh sebesar 0,95
pangkat t, sehingga sekitar 70% galat itu masih bertahan setelah tujuh tahun. Chen dan Plotnikova
(2018) membahas persis masalah nilai awal pada rentang waktu pendek. BPS juga tidak memublikasikan
stok modal provinsi, yang membuat Kataoka (2020) harus menyusun estimasinya sendiri.

Alasan kedua menyangkut asumsinya. Menurunkan elastisitas dari pangsa pendapatan hanya sah bila
pasar faktor kompetitif sempurna. Niebel dkk. (2017) merinci penyebab elastisitas menyimpang dari
pangsa pendapatan: kesalahan pengukuran, skala hasil tidak konstan, persaingan tidak sempurna, dan
spillover yang tidak terukur. Tang dan MacLeod (2006) menambahkan bahwa upah kerap ditentukan
tawar-menawar kolektif dan tidak mencerminkan produk marjinal.

Asumsi pangsa modal 1/3 tetap dipertahankan sebagai salah satu skenario dekomposisi, sehingga ia
diuji dan tidak dibuang. Kerangka Bab 7.3.2 juga menetapkan sensitivitas pada 0,4. Di bawah skala
hasil konstan, pangsa modal 0,4 memberi sisa 0,13 poin, yaitu di antara skenario D (0,333 → 0,40
poin) dan skenario A (0,446 → −0,05 poin). Skenario F pada Tabel 5 juga memakai elastisitas modal
0,400 tetapi memberi sisa 0,98 poin, karena spesifikasi itu tidak merestriksi skala hasil dan
elastisitas tenaga kerjanya 0,191 alih-alih 0,6.

**Kaskade seleksi model.** Aturan berikut ditetapkan sebelum hasil dilihat.

**Tabel 3. Kaskade seleksi model**

| Langkah | Aturan | Hasil |
|---|---|---|
| S0 | Variabel terikat harus output riil. TFP adalah konsep riil; residual dari regresi output nominal memuat perubahan harga. Restriksi ini ditetapkan *a priori*. | PDRB harga konstan |
| S1 | Breusch-Pagan LM menolak, berarti ada efek individu | p<0,001 |
| S2 | Bila Modified Wald atau Wooldridge AR(1) menolak, uji Hausman klasik tidak sah. Pakai uji Mundlak. | Keduanya menolak p<0,001; Mundlak p<0,001 → efek tetap |
| S3 | Bila Pesaran CD menolak, tambahkan efek tahun dan uji ulang | CD satu arah p=0,001 → efek tahun ditambahkan; CD dua arah tetap p<0,001 |
| S4 | Uji Wald `b1+b2=1` sebagai diagnostik pasca-estimasi | Ditolak di semua spesifikasi; dibahas pada 3.2 |
| S5 | RESET; bila tidak menolak, Cobb-Douglas dipertahankan | p=0,343 pada efek tetap satu arah |
| S6 | Galat baku klaster provinsi; pindah ke Driscoll-Kraay bila CD masih menolak | Driscoll-Kraay |

Model terpilih: PDRB harga konstan, efek tetap dua arah provinsi dan tahun, galat baku
Driscoll-Kraay.

Uji Hausman klasik tidak dipakai karena asumsinya sudah ditolak. Uji itu bersandar pada efisiensi
estimator random effects, yang menuntut homoskedastisitas dan tidak adanya autokorelasi. Keduanya
ditolak pada p<0,001. Dokumentasi StataCorp (2025) menyatakan uji Hausman "cannot be performed
after estimation using cluster–robust, bootstrap, or jackknife standard errors" dan menganjurkan
uji Mundlak (1978) sebagai gantinya.

**Posisi terhadap perhitungan sebelumnya.** Perhitungan awal kajian ini memakai random effects atas
PDRB harga berlaku dan memperoleh elastisitas modal 0,829 serta elastisitas tenaga kerja 0,262.
Dari tujuh belas komponen desain, lima dipertahankan tanpa perubahan, sepuluh diubah, dan dua
ditambahkan; rinciannya beserta pertanggungjawaban tiap perubahan ada di Lampiran E. Satu
perubahan, yaitu perpindahan ke output riil, sudah disarankan dalam catatan perhitungan awal itu
sendiri; empat lainnya merupakan tindak lanjut atas diagnostik yang hasilnya sudah tersedia di sana
tetapi tidak dipakai pada pemilihan model.

**Ekstraksi TFP ke provinsi dan tahun.** TFP provinsi diperoleh sebagai residual model,
`log Y − b1·log K − b2·log L`, dengan elastisitas utama tak-terestriksi b1=0,400 dan b2=0,191.
Residual ini masih memuat efek provinsi `u_i`, sehingga perbedaan level TFP antar-provinsi terjaga,
bukan tersapu efek tetap (Hulten 2001; Combes dkk. 2008). Pergerakan TFP antar waktu diperoleh dari
koefisien dummy tahun. Efek tahun pada spesifikasi dua arah menangkap perubahan produktivitas yang
umum bagi seluruh unit (Muinelo-Gallo dan Roca-Sagalés 2011; Niebel dkk. 2017).

---

## 3. Hasil perhitungan TFP

### 3.1 Hasil uji diagnostik

Seluruh statistik yang menjadi masukan kaskade tercantum pada Tabel 3. Tiga hal di luar tabel itu
perlu dicatat.

Diagnostik pada basis nominal berperilaku jauh lebih buruk daripada basis riil. Uji Pesaran CD
memberi z=12,90 pada efek tetap basis nominal dibandingkan z=3,24 pada efek tetap basis riil, dan
z=33,56 pada random effects basis nominal dibandingkan z=0,99 pada random effects basis riil.
Perbedaan itu mendukung restriksi S0 yang ditetapkan di muka.

Perpindahan ke galat baku Driscoll-Kraay (1998), yang tahan terhadap dependensi lintas provinsi dan
serial pada panel, mengubah inferensi secara berarti. Galat baku elastisitas modal melebar dari
0,0349 pada klaster provinsi ke 0,0531 pada Driscoll-Kraay, yaitu 52% lebih lebar. Inferensi
berbasis klaster pada data ini terlalu percaya diri.

Uji RESET dijalankan pada spesifikasi efek tetap satu arah dan memberi p=0,343. Uji ini tidak
berdaya mendeteksi kesalahan pengukuran variabel modal, sehingga hasilnya tidak menutup kemungkinan
tersebut, dan persoalannya dibahas pada 3.2.

### 3.2 Interpretasi model terbaik

**Tabel 4. Elastisitas model terpilih**

| Spesifikasi | Elastisitas modal | Elastisitas tenaga kerja | Jumlah |
|---|---:|---:|---:|
| Efek tetap dua arah, tanpa restriksi (basis utama) | 0,400 (0,053) | 0,191 (0,068) | 0,591 |
| Efek tetap dua arah, skala hasil konstan (diagnostik) | 0,446 (0,054) | 0,554 | 1 (dipaksakan) |

Galat baku Driscoll-Kraay dalam kurung. Elastisitas tenaga kerja pada baris kedua adalah
1 dikurangi elastisitas modal secara konstruksi.

**Skala hasil: elastisitas terestimasi dipakai sebagai basis, CRS sebagai diagnostik.** Uji Wald
menolak skala hasil konstan pada seluruh spesifikasi: 0,897 pada random effects (p=0,041), 0,803
pada efek tetap satu arah (p=0,003), dan 0,591 pada efek tetap dua arah (p<0,001). Basis utama
kajian ini adalah elastisitas terestimasi apa adanya (b1=0,400, b2=0,191). Alasannya bersifat
akuntansi: memaksakan skala hasil konstan pada elastisitas yang menjumlah 0,591 akan menaruh suku
skala `(1 − b1 − b2)·pertumbuhan input` ke dalam residual lalu menyebutnya TFP, sehingga residual
terkontaminasi pertumbuhan input (Barro 1999). Memakai elastisitas terestimasi menjaga residual
bebas dari kontaminasi itu. Varian skala hasil konstan tetap disajikan, tetapi sebagai diagnostik
yang menjelaskan pilihan model dan sebagai kontrafaktual tersimulasi pada Bagian 3.4.

**Kaveat penting: penolakan CRS sebagian bisa atenuasi, bukan DRS struktural.** Penolakan uji Wald
tidak otomatis berarti teknologi benar-benar berskala hasil menurun. Jumlah elastisitas menurun
monoton seiring makin banyak variasi yang dibuang transformasi: 1,011 pada pooled OLS, 0,897 pada
random effects, 0,803 pada efek tetap, dan 0,591 pada efek tetap dua arah (Gambar 1). Penurunan itu
digerakkan hampir seluruhnya oleh elastisitas modal, yang jatuh dari 0,854 ke 0,400, sedangkan
elastisitas tenaga kerja tidak monoton. Bukti paling bersihnya langkah dari efek tetap satu arah ke dua arah,
yang menurunkan jumlah elastisitas dari 0,803 ke 0,591 sambil hanya membuang variasi antar-tahun;
heterogenitas provinsi sudah diserap efek tetap pada langkah sebelumnya, sehingga penurunan itu
tidak dapat dijelaskan oleh variabel provinsi yang terabaikan.

Pola itu adalah tanda tangan kesalahan pengukuran. Griliches dan Mairesse (1998) mendokumentasikan
bahwa pada panel produksi, koefisien modal kerap rendah dan estimasi skala hasil rendah tak masuk
akal karena modal diukur dengan galat besar dan transformasi *within* "membuang sinyal", sehingga
skala hasil lebih mudah ditolak ke arah menurun semata karena elastisitas modal *under-estimate*.
Griliches dan Hausman (1986) menunjukkan galat pengukuran "gets magnified in the within dimension";
Chen dan Plotnikova (2018) menurunkan arah biasnya untuk proksi modal yang lemah korelasinya dengan
stok sebenarnya, yaitu bias ke bawah. Di sini modal diproksi arus PMTB, sebuah *flow* yang lebih
bergejolak dan lebih rawan galat ukur relatif terhadap jasa modal sejati, sehingga b1=0,400 sangat
mungkin batas bawah. Basu dan Fernald (1997) memberi paralel penting: estimasi produksi AS kerap
menghasilkan *apparent decreasing returns* yang mereka jelaskan lewat agregasi atas unit heterogen
dan persoalan pengukuran, dan bukan sebagai bukti skala hasil menurun yang struktural.
Konsekuensinya: skala hasil menurun 0,591 yang terukur sebagian bersifat statistik alih-alih
struktural, sehingga residual TFP pada basis utama cenderung dilebih-lebihkan dan koreksi yang benar
akan menurunkannya.

Estimasi pooled sebesar 1,011 tidak dipakai sebagai jangkar. Pooled OLS mengandung dua bias
berlawanan: atenuasi menariknya ke bawah, sedangkan heterogenitas provinsi yang terkorelasi dengan
modal menariknya ke atas. Yang dipakai adalah pola monotoniknya. Spesifikasi dengan PMTB tahun
sebelumnya, yang seharusnya mengurangi sebagian galat ukur bila cerita atenuasi benar, menaikkan
elastisitas modal hanya dari 0,400 ke 0,416 — kenaikan yang tidak cukup untuk menutup jarak menuju
skala hasil konstan, sehingga besaran koreksinya tetap tidak diketahui. Karena itu basis utama
dilaporkan dengan elastisitas terestimasi, dan varian skala hasil konstan menyertainya sebagai
diagnostik yang membatasi klaim (Bagian 3.3 dan 3.4).

![Gambar 1](../03%20Output/Tangga%20Atenuasi%20Elastisitas.png)

**Gambar 1. Jumlah elastisitas menurut spesifikasi**

**Jumlah elastisitas pada basis nominal.** Nilai 1,540 pada efek tetap basis nominal adalah gejala,
bukan temuan. Elastisitas ekonomi urbanisasi pada industri manufaktur berkisar 0,01–0,20 dengan
mayoritas di bawah 0,10 (Graham 2009), dan derajat skala ekonomi setara dengan elastisitas
aglomerasi (Kakamu dkk. 2012), sehingga skala hasil yang konsisten dengan literatur berada di
kisaran 1,01–1,10. Lee dan Park (2024) memperoleh 1,323 pada spesifikasi awal mereka, menyebutnya
"unreasonably large; this is a potential sign of CSD", dan memperoleh 1,084 setelah koreksi.
Spesifikasi yang menghasilkan 1,540 dalam kajian ini, yaitu efek tetap basis nominal, gagal uji
Pesaran CD dengan z=12,90, sehingga pembacaan yang sama berlaku.

**Capital-driven atau productivity-driven.** Pada basis utama tanpa restriksi (skenario F di
Tabel 5), modal menyumbang 64% pertumbuhan, tenaga kerja 10%, dan sisa TFP 26%. Pada empat skenario
berskala hasil konstan yang dipakai sebagai pembanding (A, B, D, E), modal menyumbang 53–71%,
tenaga kerja 30–36%, dan sisa di bawah 11%. Dominasi modal bertahan baik pada basis utama maupun
diagnostik CRS; yang berpindah antara keduanya hanya besaran sisa. Pola dominasi modal ini sejalan
arah dengan van der Eng (2010), Rusiawan dkk. (2015), dan dekomposisi APO pada Tabel 1, meskipun
ketiganya memakai ukuran modal dan bobot yang berbeda.

**Kepekaan terhadap PMTB tahun sebelumnya.** Spesifikasi dengan PMTB tahun sebelumnya memberi
elastisitas modal 0,416 dibandingkan 0,400 pada spesifikasi kontemporer. Karena PMTB sangat
persisten antar tahun, spesifikasi ter-lag tidak memutus simultanitas; kemiripan keduanya hanya
menunjukkan hasil tidak digerakkan oleh komponen kontemporer PMTB semata. Rincian panel robustness
ada di Lampiran C.

Pendekatan variabel instrumen dengan PMA dan PMDN sebagai instrumen bagi PMTB tidak dijalankan,
dan itu keputusan metodologis. PMA dan PMDN secara definisi merupakan bagian dari PMTB pada
komponen aset tetap non-tanah, sehingga keduanya memengaruhi output lewat saluran yang sama dengan
regresor yang hendak diinstrumen dan *exclusion restriction* gagal.

Bentuk translog tidak dipakai. Uji RESET pada efek tetap satu arah tidak menolak linearitas, dan pada translog skala hasil
menjadi fungsi yang dievaluasi di satu titik, sehingga tidak lagi berupa parameter tunggal yang
dapat diuji.

### 3.3 Analisis TFP

**Rekonsiliasi angka pertumbuhan.** Angka 5,03% dan 5,11% pada Bab 5.1 adalah pertumbuhan PDB
nasional tahun tunggal untuk 2024 dan 2025. Angka di sini, 3,83%, adalah rata-rata 2018–2024 atas
agregat 34 PDRB provinsi. Selisihnya berasal dari tiga hal: rentang waktunya memuat kontraksi 2020
sebesar −2,05%, perhitungannya memakai rata-rata selisih logaritma, dan agregatnya adalah
penjumlahan 34 PDRB provinsi sedangkan PDB nasional BPS memakai cakupan berbeda.

**Dekomposisi nasional.** Tabel 5 menyajikan dekomposisi
`g(Y) = b1·g(K) + b2·g(L) + sisa`. Residual dilabeli "sisa" karena ia memuat kemajuan teknologi
bersama seluruh kesalahan spesifikasi dan pengukuran. Basis utama adalah skenario F, yaitu
elastisitas terestimasi tanpa restriksi skala hasil; skenario A, B, D, dan E memaksakan skala hasil
konstan dan disajikan sebagai pembanding.

Perhitungan ini bukan growth accounting baku. Growth accounting mensyaratkan stok kapital dan
pangsa faktor dari data pendapatan, sedangkan di sini modal diproksi arus PMTB dan elastisitasnya
diestimasi.

**Tabel 5. Dekomposisi pertumbuhan PDRB riil nasional, 2018–2024 (poin persen)**

| Skenario | b1 | Modal | Tenaga kerja | Sisa | Pangsa sisa |
|---|---:|---:|---:|---:|---:|
| F. Tanpa restriksi skala hasil (basis utama) | 0,400 | 2,45 | 0,40 | 0,98 | 25,7% |
| A. Elastisitas level, skala hasil konstan | 0,446 | 2,73 | 1,15 | −0,05 | −1,4% |
| B. Elastisitas growth, skala hasil konstan | 0,364 | 2,23 | 1,32 | 0,28 | 7,3% |
| D. Pangsa modal 1/3 | 0,333 | 2,04 | 1,38 | 0,40 | 10,5% |
| E. Modal diukur stok perpetual inventory | 0,446 | 2,53 | 1,15 | 0,14 | 3,7% |

Pertumbuhan PDRB riil 3,83%, PMTB 6,12%, tenaga kerja 2,08% per tahun. Identitas dekomposisi
terpenuhi hingga 4,4×10⁻¹⁶. Pada basis utama, sisa 0,98 poin (25,7% pertumbuhan); pada varian
skala hasil konstan sisa turun ke rentang −0,05 sampai +0,40 poin. Selisih itu adalah suku skala
yang, di bawah CRS, dipindahkan dari residual ke kontribusi input, dan dibedah pada Bagian 3.4.
Skenario C, yang memakai bobot pangsa pendapatan terukur, dikeluarkan dari tabel dan dibahas pada
Batasan 11.

![Gambar 2](../03%20Output/Dekomposisi%20Pertumbuhan%20Nasional.png)

**Gambar 2. Dekomposisi pertumbuhan PDRB riil nasional menurut skenario**

Skenario B memakai elastisitas bentuk growth yang telah dinormalisasi ke skala hasil konstan.
Estimasi mentahnya adalah 0,151 untuk modal dan 0,265 untuk tenaga kerja, dengan jumlah 0,416;
normalisasinya membagi masing-masing dengan jumlah tersebut sehingga menghasilkan 0,364.

**Cabang skala hasil konstan sebagai kontrafaktual.** Cabang ini bukan basis utama, tetapi berguna
untuk membatasi klaim: bila skala hasil konstan dipaksakan, dekomposisi kolaps menjadi satu garis:

```
sisa = g(Y) − g(L) − b1·[g(K) − g(L)] = 1,75 − 4,05·b1
```

Garis ini berlaku untuk setiap nilai b1, tetapi kemiringannya bergantung pada ketiga laju
pertumbuhan yang terukur. Batas atas mutlak sisa adalah 1,75 poin atau 45,8% pertumbuhan, tercapai
hanya bila elastisitas modal nol. Sisa mencapai nol pada elastisitas modal 0,433.

Ambang di mana sisa melampaui 25% pertumbuhan bergantung pada laju pertumbuhan modal yang dipakai.
Dengan arus PMTB (6,12%) ambangnya 0,196; dengan stok perpetual inventory ambangnya berkisar 0,182
sampai 0,293 bergantung asumsi depresiasi dan pertumbuhan awal. Estimasi elastisitas modal yang
tersedia adalah 0,446 (skala hasil konstan), 0,400 (tanpa restriksi), dan 0,299 (panel berbobot
pangsa output). Ketiganya berada di atas seluruh rentang ambang, meskipun yang terendah hanya
sedikit di atasnya.

Estimasi bentuk growth mentah, 0,151, berada di bawah seluruh rentang ambang. Angka itu tidak dapat
diletakkan pada garis ini karena jumlah elastisitasnya 0,416, sedangkan garis ini diturunkan di
bawah skala hasil konstan. Setelah dinormalisasi menjadi 0,364, ia berada di atas ambang.

![Gambar 3](../03%20Output/Amplop%20Sisa%20vs%20Elastisitas%20Modal.png)

**Gambar 3. Sisa sebagai fungsi elastisitas modal di bawah skala hasil konstan**

Elastisitas 0,446 pada skenario A juga tunduk pada atenuasi yang dibahas di 3.2. Bila elastisitas
modal sebenarnya lebih tinggi, sisa yang benar lebih kecil daripada yang dilaporkan, sehingga
kesimpulan "sisa mendekati nol" pada cabang ini bersifat konservatif.

**Pergerakan TFP antar waktu.** Gambar 4 menyajikan indeks produktivitas agregat dari koefisien
dummy tahun model utama tak-terestriksi. Indeks bergerak dari 100 pada 2017 ke 101,4 pada 2018,
mendatar sekitar 101 sampai 2021, lalu menanjak ke 103,0 pada 2022, 104,9 pada 2023, dan 106,8 pada
2024. Tren linear +0,81% per tahun (p=0,002) sebagai kemiringan rata-rata koefisien efek tahun;
spesifikasi bertren dua arah dengan galat baku Driscoll-Kraay memberi +0,63% per tahun (p=0,017),
sama tanda dan sama-sama signifikan.

Kenaikan itu tidak merata sepanjang deret. Selang kepercayaan 95% memuat angka 100 sepanjang
2019–2023, dan hanya pada 2018 (batas bawah 100,2) serta 2024 (batas bawah 100,4) level indeks
menyingkir di atas tahun basis. Sebagian besar tanjakan terjadi pasca-2021, sehingga sebagian dari
indeks ini menyerap pemulihan utilisasi kapasitas pasca-pandemi alih-alih semata kemajuan teknologi.

Pada cabang skala hasil konstan sebagai kontrafaktual, deret yang sama justru menurun: dari 100
ke 97,5 pada 2021 lalu 98,6 pada 2024, dengan tren −0,27% per tahun (p=0,049). Selisih sekitar
1,1 poin persen antara kedua tren adalah suku `(1 − b1 − b2)` dikalikan pertumbuhan input
tertimbang, yaitu komponen yang masuk ke residual ketika skala hasil tidak direstriksi (dibedah
pada Bagian 3.4). Arah tanda yang berlawanan antara basis utama dan kontrafaktual menegaskan bahwa
tanda tren TFP nasional bergantung pada asumsi skala hasil, bukan hanya pada data.

![Gambar 4](../03%20Output/Indeks%20TFP%20Nasional.png)

**Gambar 4. Indeks TFP nasional, 2017 = 100**

**Kontribusi kumulatif tiap faktor.** Gambar 5 menaruh pergerakan TFP itu berdampingan dengan
kontribusi kumulatif modal dan tenaga kerja, ketiganya diindeks ke 100 pada 2017. Garis modal dan
tenaga kerja adalah kontribusi kumulatif input tertimbang elastisitas non-CRS, `100·exp(Σ b·g)`,
sedangkan garis TFP adalah indeks efek tahun yang sama dengan Gambar 4. Pada 2024 indeks modal
mencapai 118,7, TFP 106,8, dan tenaga kerja 102,8. Urutan itu sejalan dengan pangsa periode penuh
pada Tabel 5, tempat modal menyumbang 64%, sisa TFP 26%, dan tenaga kerja 10% pertumbuhan. Indeks
modal pula satu-satunya yang mencatat palung nyata pada 2020, mencerminkan kontraksi arus PMTB saat
pandemi.

![Gambar 5](../03%20Output/Kontribusi%20Kumulatif%20Faktor.png)

**Gambar 5. Kontribusi kumulatif modal, tenaga kerja, dan TFP, 2017 = 100**

Ketiga garis sebanding tetapi tidak dirancang untuk dijumlahkan ke output, sehingga grafik ini
berbeda dari dekomposisi bertumpuk pada Gambar 2. Garis modal dan tenaga kerja berasal dari agregat
nasional berbobot output, sedangkan garis TFP berasal dari panel yang membobot tiap provinsi sama,
sehingga keduanya mengukur objek yang berlainan (Batasan 10). Garis TFP diambil dari efek tahun
alih-alih sisa identitas per tahun, karena dekomposisi tahun-per-tahun kehilangan keabsahannya ketika
rasio investasi terhadap stok bergolak, terutama pada 2020–2021 (Batasan 6).

Pertumbuhan TFP tidak dilaporkan sebagai CAGR. TFP di sini residual regresi, dan korelasi
intraklas 0,9964 berarti 99,6% varian model bersifat antar-provinsi, sehingga deret nasional
bertumpu pada irisan variasi dalam-provinsi yang tipis. Uji Wooldridge menolak ketiadaan
autokorelasi orde satu pada p<0,001, sehingga titik ujung adalah titik paling tidak andal,
sedangkan CAGR hanya memakai titik ujung.

**Tabel 6. Pembanding eksternal pertumbuhan TFP Indonesia**

| Sumber | Periode | TFP (%/tahun) | Ukuran modal | Bobot |
|---|---|---:|---|---|
| Kajian ini, tanpa restriksi (basis utama) | 2017–2024 | +0,81 | arus PMTB | elastisitas terestimasi |
| Kajian ini, skala hasil konstan (kontrafaktual) | 2017–2024 | −0,26 | arus PMTB | elastisitas terestimasi |
| APO (Masterplan Tabel 1) | 2016–2022 | −0,35 | stok | pangsa pendapatan |
| van der Eng (2009) | 1971–2007 | −0,20 | stok perpetual inventory | pangsa pendapatan |
| Rusiawan dkk. (2015) | 1976–2011 | −0,62 | stok perpetual inventory | pangsa Divisia |

Kedua baris kajian ini adalah kemiringan rata-rata koefisien efek tahun; spesifikasi bertren dengan
galat baku Driscoll-Kraay memberi +0,63%/thn (p=0,017) untuk basis utama dan −0,27%/thn (p=0,049)
untuk kontrafaktual, sama tanda dengan masing-masing. Tabel ini pembanding dan bukan validasi.
Hanya APO yang periodenya beririsan dengan sampel kajian; van der Eng dan Rusiawan berakhir sebelum
sampel dimulai. Keempat sumber memakai ukuran modal dan bobot yang berbeda. Efek tahun dalam kajian
ini juga didefinisikan setelah efek provinsi disapu, sehingga ia mengecualikan perubahan
produktivitas yang berasal dari pergeseran komposisi antar provinsi, sedangkan growth accounting
nasional memasukkannya. Basis utama +0,81 tidak sejalan dengan satu pun pembanding; kontrafaktual
CRS −0,26 kebetulan mendekati mereka, tetapi kedekatan itu sebagian konsekuensi dari sama-sama
memaksakan skala hasil konstan, bukan konfirmasi independen.

**Perbedaan antar provinsi.** Gambar 6 menyajikan deviasi level TFP tiap provinsi dari rata-rata
34 provinsi, memakai elastisitas utama tak-terestriksi. Sebarannya membentang 2,1 poin logaritma.
DKI Jakarta tertinggi pada +1,24, diikuti Jawa Timur +1,03, Jawa Barat +1,00, Kalimantan Timur
+0,75, dan Jawa Tengah +0,72; Maluku Utara terendah pada −0,85, disusul Maluku −0,79 dan Nusa
Tenggara Timur −0,72.

Peringkat ini perlu dibaca dengan hati-hati karena elastisitas tenaga kerja yang rendah (0,191)
membuat residual level menyerap skala tenaga kerja: provinsi berpenduduk besar seperti keempat
provinsi Jawa naik ke puncak karena hanya sedikit kontribusi tenaga kerjanya yang dikurangkan.
Peringkat atas karena itu mencampur provinsi ekstraktif (Kalimantan Timur, Riau), enklave jasa
(DKI Jakarta), dan ekonomi besar terdiversifikasi (Jawa Timur, Jawa Barat, Jawa Tengah), bukan
semata efisiensi teknis. DKI Jakarta menjadi kasus khusus karena PDRB dicatat menurut lokasi
produksi sedangkan tenaga kerja Sakernas menurut tempat tinggal, sehingga output pekerja komuter
masuk ke Jakarta tetapi pekerjanya tercatat di provinsi penyangga.

![Gambar 6](../03%20Output/Peringkat%20TFP%20Provinsi.png)

**Gambar 6. Peringkat TFP provinsi, deviasi dari rata-rata nasional**

Tren TFP per provinsi diperoleh dari regresi delapan titik beserta galat bakunya. Selisih dua titik
ujung akan membuang enam titik di antaranya. Dua puluh tiga dari 34 provinsi memiliki tren yang
berbeda dari nol pada p<0,05. Angka itu adalah batas atas, karena galat baku dari regresi atas
residual yang terautokorelasi positif cenderung terlalu kecil. Daftar lengkap ada di Lampiran D.

**Perbedaan antar pulau.** Tabel 7 menyajikan dekomposisi yang sama pada agregat enam pulau,
memakai elastisitas panel utama tak-terestriksi. Perbedaan antar pulau karena itu berasal dari
komposisi pertumbuhan inputnya, bukan dari perbedaan teknologi produksi antar-wilayah.

**Tabel 7. Dekomposisi pertumbuhan per pulau, 2018–2024 (poin persen, skenario F tanpa restriksi)**

| Pulau | Output | Modal | Tenaga kerja | Sisa |
|---|---:|---:|---:|---:|
| Sulawesi | 5,72 | 3,40 | 0,54 | 1,78 |
| Jawa | 3,82 | 2,22 | 0,35 | 1,24 |
| Sumatera | 3,47 | 2,38 | 0,37 | 0,72 |
| Maluku-Papua | 4,69 | 3,33 | 0,87 | 0,50 |
| Bali-Nusra | 2,32 | 1,80 | 0,51 | 0,01 |
| Kalimantan | 3,56 | 3,27 | 0,40 | −0,11 |

Sisa per pulau tidak menjumlah ke sisa nasional. Agregasi fungsi Cobb-Douglas tidak bersifat
aditif, dan tiap pulau memiliki komposisi pertumbuhan input yang berbeda. Sisa negatif Kalimantan
menandakan pertumbuhan input melampaui pertumbuhan output, pola khas ekonomi berbasis investasi
ekstraktif.

![Gambar 7](../03%20Output/Dekomposisi%20per%20Pulau.png)

**Gambar 7. Dekomposisi pertumbuhan per pulau**

Gambar 8 menyajikan indeks TFP tiap pulau pada basis utama. Kalimantan mencapai 142,4 dan Jawa
130,5 pada 2024, disusul Sumatera 124,3, Sulawesi 117,4, dan Maluku-Papua 114,5 setelah sempat
jatuh ke sekitar 92 pada 2019–2020; Bali-Nusra praktis datar di 101,0. Seperti indeks nasional,
seluruh deret ini bergerak naik karena tidak merestriksi skala hasil, sehingga levelnya memuat suku
skala di samping produktivitas.

![Gambar 8](../03%20Output/Indeks%20TFP%20per%20Pulau.png)

**Gambar 8. Indeks TFP per pulau, 2017 = 100**

Tiap pulau hanya memuat 3 sampai 10 provinsi, sehingga presisi estimasi per pulau jauh di bawah
estimasi nasional. Bali-Nusra dengan tiga provinsi paling rapuh dan sebaiknya tidak dijadikan
dasar kesimpulan tersendiri.

Perbandingan dengan Tabel 6 Masterplan Produktivitas Nasional untuk 2013–2022 tidak menambah bukti.
Kedua perhitungan memakai periode, ukuran modal, dan metode yang berbeda, dan seri output tahunan
Tabel 6 Masterplan untuk 2020–2022 memuat nilai absolut identik bertanda selang-seling pada
sebagian baris provinsi, yang menandakan galat pengolahan.

### 3.4 Simulasi DRS versus CRS

Basis utama memakai skala hasil menurun (DRS), sedangkan diagnostik memaksakan skala hasil konstan
(CRS). Perbedaan keduanya bukan perbedaan data melainkan perbedaan asumsi, dan simulasi ini
mengukur konsekuensi akuntansinya. Ini komparatif-statik deterministik, bukan simulasi acak:
identitas dekomposisi `g(Y) = b1·g(K) + b2·g(L) + sisa` dievaluasi ulang untuk berbagai nilai skala
hasil sambil menahan pertumbuhan input teramati tetap, sehingga yang berpindah hanya pembagian
pertumbuhan terukur di antara modal, tenaga kerja, dan residual.

**Rekonsiliasi kontribusi.** Saat elastisitas dipaksa dari DRS (jumlah 0,591) ke CRS (jumlah 1),
pangsa modal atas pertumbuhan naik dari 64,0% ke 71,3% dan sisa turun dari +0,98 ke −0,05 poin,
yaitu selisih 1,03 poin. Suku skala murni `(1 − b1 − b2)·g_input` bernilai 1,97 poin. Selisih
rekonsiliasi (1,03) lebih kecil daripada suku skala murni (1,97) karena perpindahan ke CRS tidak
sekadar merentangkan jumlah elastisitas, tetapi juga menaikkan elastisitas tenaga kerja dari 0,191
ke 0,554, dan tambahan bobot tenaga kerja itu menyerap sebagian suku skala yang seharusnya jatuh
seluruhnya ke sisa.

![Gambar 9](../03%20Output/Simulasi%20DRS%20vs%20CRS.png)

**Gambar 9. Perpindahan kontribusi saat skala hasil disapu dari DRS ke CRS**

**Sapuan skala hasil.** Gambar 9 menyapu jumlah elastisitas dari 0,591 ke 1,00 dengan pangsa modal
atas jumlah itu ditahan tetap. Sisa turun monoton dari +0,98 poin di DRS ke −0,99 poin di CRS
penuh, melewati nol pada jumlah elastisitas sekitar 0,80 (elastisitas modal sekitar 0,54),
sedangkan kontribusi modal naik dari 2,45 ke 4,14 poin. Tanda residual karena itu ditentukan
asumsi skala hasil, bukan data.

**Kontrafaktual maju.** Bila sasaran output 8% dikejar dengan pertumbuhan input teramati (PMTB
6,12%, tenaga kerja 2,08%), TFP yang dibutuhkan adalah 4,12 poin di bawah CRS versus 5,16 poin di
bawah DRS, selisih 1,03 poin. Pada jalur 8-4-2-2 resmi, kontribusi modal sasaran adalah 2 poin
(gK = 6% pada alfa=1/3), bukan 4 poin (gK = 12%). Angka 12% di paragraf ini adalah vintage kode
lama; lihat sheet `kontrafaktual` terkini.
Asumsi skala hasil karena itu menggeser besar setoran TFP yang diperlukan untuk menembus 8% sekitar
satu poin persen. Antar pulau, selisih sisa CRS-DRS berkisar 0,92 poin (Jawa) sampai 2,03 poin
(Maluku-Papua).

**Batas kejujuran.** Simulasi ini menunjukkan konsekuensi tiap asumsi skala hasil, tetapi tidak
dapat memutuskan mana yang benar secara struktural. Data tidak memisahkan skala hasil menurun yang
sejati dari atenuasi akibat proksi arus PMTB (Bagian 3.2). Karena atenuasi menekan elastisitas
modal ke bawah dan pendalaman modal manusia yang tak terukur ikut jatuh ke residual, kontribusi TFP
yang sebenarnya besar kemungkinan berada di antara kontrafaktual CRS (mendekati nol) dan basis DRS
(0,98 poin), dan condong ke ujung bawah rentang itu.

---

## 4. Diskusi

MENYUSUL.

---

## Batasan

1. **Modal diukur dengan arus PMTB, dan efeknya berlawanan arah.** Elastisitas modal teratenuasi,
   yang menaikkan sisa. Sementara itu arus PMTB tumbuh 6,12% per tahun sedangkan stok perpetual
   inventory tumbuh 4,78–6,45% bergantung asumsi depresiasi dan pertumbuhan awal, dengan nilai
   tengah 5,69%. Pada dua dari empat kombinasi asumsi, laju stok justru melampaui laju arus,
   sehingga tanda saluran kedua ini sendiri tidak robust. Saluran pertama berlaku karena
   pertumbuhan modal melampaui pertumbuhan tenaga kerja, yaitu 6,12% berbanding 2,08%. Arah neto
   tidak dapat ditentukan tanpa stok kapital yang benar. Skenario E memakai nilai tengah dan
   menggeser sisa dari −0,05 ke +0,14 poin.

   Perpetual inventory ditolak pada 2.2 untuk mengukur **level** stok modal provinsi. Skenario E
   memakai **laju pertumbuhan** stok nasional, yang jauh lebih tahan terhadap galat stok awal
   karena galat itu meluruh proporsional pada pembilang dan penyebut.

2. **Tenaga kerja diukur tanpa koreksi kualitas.** Input berupa jumlah orang bekerja. Sepanjang
   kualitas angkatan kerja meningkat selama periode pengamatan, pendalaman modal manusia jatuh ke
   dalam residual dan terhitung sebagai TFP, sehingga sisa terukur terlalu besar. Besaran efek ini
   tidak dihitung dalam kajian ini karena memerlukan seri modal manusia yang tidak tersedia di
   dataset. Ini juga menjelaskan sebagian selisih terhadap van der Eng, yang memakai
   *education-augmented employment*.

3. **Pembobotan panel berbeda dari pembobotan agregat nasional.** Panel membobot tiap provinsi
   sama, sedangkan agregat nasional membobot pangsa output. Panel berbobot pangsa output memberi
   elastisitas modal 0,299 dan elastisitas tenaga kerja 0,036, dengan jumlah 0,335. Spesifikasi itu
   praktis runtuh dan dipakai sebagai peringatan. Ia tidak setara dengan estimasi utama, dan
   kesimpulan pada 3.3 tidak disandarkan padanya.

4. **Dependensi lintas provinsi tidak sepenuhnya teratasi.** Uji Pesaran CD tetap menolak setelah
   efek tahun ditambahkan (p<0,001). Galat baku Driscoll-Kraay melebarkan galat baku elastisitas
   modal dari 0,0349 ke 0,0531, yaitu 52%, tetapi tidak mengubah titik estimasi.

5. **Status kausal.** PMTB tahun sebelumnya memberi elastisitas 0,416 dibandingkan 0,400 pada
   spesifikasi kontemporer. Karena PMTB sangat persisten, spesifikasi ter-lag tidak memutus
   simultanitas. Seluruh elastisitas dibaca sebagai asosiasi.

6. **Dekomposisi hanya disajikan sebagai rata-rata periode penuh.** Kesetaraan pertumbuhan PMTB
   dengan pertumbuhan stok modal menuntut rasio investasi terhadap stok yang stabil, dan syarat itu
   gagal pada 2020–2021. Tabel 5 Masterplan Produktivitas Nasional memperlihatkan akibat melanggar
   aturan ini: baris Total Provinces berayun dari +77,37 pada 2017 ke −36,65 pada 2018, dan pada
   tingkat provinsi Papua Barat berayun dari +167,91 ke −107,63.

7. **Efek tahun menyerap seluruh guncangan agregat.** Siklus bisnis, pergerakan harga, dan pandemi
   ikut masuk. Pada indeks utama, deret mendatar di sekitar 101 pada 2019–2021 lalu menanjak
   pasca-2021, sehingga sebagian tanjakan lebih mungkin mencerminkan pemulihan utilisasi kapasitas
   daripada kemajuan teknologi; pada kontrafaktual skala hasil konstan, guncangan yang sama muncul
   sebagai palung −2,5 poin indeks pada 2021. Level indeksnya juga arbitrer karena hanya relatif
   terhadap tahun basis. Preseden literatur mendukung penafsiran efek tahun sebagai perubahan
   produktivitas bersama (Muinelo-Gallo dan Roca-Sagalés 2011), tetapi kami tidak menemukan preseden
   publikasi deret koefisien dummy tahun sebagai indeks TFP bernama; penyajian ini merupakan pilihan
   metodologis kajian.

8. **Level TFP provinsi memuat skala, endowmen sumber daya, dan komposisi sektoral.** Pada basis
   utama, elastisitas tenaga kerja yang rendah (0,191) membuat residual level menyerap skala tenaga
   kerja, sehingga provinsi berpenduduk besar (empat provinsi Jawa) naik ke puncak bersama provinsi
   ekstraktif (Kalimantan Timur, Riau) dan enklave jasa (DKI Jakarta). Peringkat atas karena itu
   mencerminkan skala dan rente sumber daya selain efisiensi teknis. DKI Jakarta menghadapi persoalan
   tambahan: PDRB dicatat menurut lokasi produksi sedangkan tenaga kerja dicatat menurut tempat
   tinggal, sehingga pekerja komuter menghasilkan output di DKI tetapi tercatat sebagai tenaga kerja
   Jawa Barat dan Banten.

9. **Ketiadaan pembanding untuk angka provinsi.** Kataoka (2020) adalah satu-satunya studi TFP
   provinsi Indonesia yang tersedia, dan keluarannya indeks Malmquist relatif yang tidak dapat
   dibaca sebagai persen kontribusi terhadap pertumbuhan. Angka provinsi dalam kajian ini karena itu
   tidak memiliki pembanding langsung di literatur akademik.

10. **Dua deret TFP dalam laporan ini memakai pembobotan agregasi berbeda.** Indeks efek tahun
    berasal dari panel yang membobot tiap provinsi sama, sedangkan dekomposisi berasal dari agregat
    yang membobot pangsa output. Keduanya tidak dapat dibaca sebagai dua ukuran atas objek yang
    sama.

11. **Pangsa pendapatan tenaga kerja terukur tidak dipakai sebagai bobot.** Dataset memuat
    pendapatan bulanan per pekerja untuk 17 sektor, mencakup upah, barang, kerja paruh waktu, dan
    pemasukan wirausaha. Perhitungannya menghasilkan pangsa pendapatan tenaga kerja 15,1% pada 2017
    dan 17,9% pada 2024, dengan median antar provinsi-tahun 18,3%. Angka itu berada jauh di bawah
    rentang 38–51% yang dilaporkan van der Eng (2010) untuk 1980–1995, dan sumber selisihnya belum
    dapat dipastikan dari dataset ini. Dipakai sebagai bobot, ia memberi elastisitas modal 0,841,
    kontribusi modal 5,15 poin, dan sisa −1,65 poin atau −43,2% pertumbuhan. Sisa sebesar itu tidak
    memiliki padanan pada satu pun pembanding di Tabel 6. Ketidaksesuaian antara pangsa pendapatan
    terukur dan elastisitas terestimasi konsisten dengan Niebel dkk. (2017) dan Tang dan MacLeod
    (2006), yang menyatakan keduanya menyimpang bila pasar faktor tidak kompetitif sempurna.

12. **Angka World Bank dan ADB tidak dikutip.** Beberapa sumber institusional memuat estimasi TFP
    Indonesia, tetapi tabelnya belum diverifikasi langsung dari dokumen aslinya.

Catatan pemilihan galat baku. Bab 6.2.3 memakai galat baku klaster provinsi pada panel provinsi
yang sama, meskipun variabel terikat dan spesifikasinya berbeda; bab itu meregresi indeks
pembangunan manusia, penyerapan tenaga kerja, produktivitas tenaga kerja, dan upah riil terhadap
investasi. Uji Pesaran CD dijalankan pada bab ini dan tidak pada 6.2, dan hasil uji itulah yang
mendasari perpindahan ke Driscoll-Kraay. Perlakuan terhadap DKI Jakarta dan provinsi ekstraktif
juga berbeda: Bab 6.2.3 mengeluarkannya dalam uji kepekaan, sedangkan bab ini menampilkannya dan
menandainya pada Gambar 6.

Catatan kontribusi tenaga kerja. Bab 7.2 menyatakan kontribusi tenaga kerja rendah relatif terhadap
kelimpahannya. Kajian ini memperoleh kontribusi tenaga kerja 10% pertumbuhan pada basis utama
tak-terestriksi dan 30–36% pada varian skala hasil konstan. Kedua pernyataan dapat berdampingan
karena acuannya berbeda: 7.2 mengacu pada pangsa penduduk usia kerja, sedangkan angka di sini
mengacu pada pertumbuhan output.

---

## Lampiran

- **Lampiran A** — Perbandingan empat keluarga metode perhitungan TFP
- **Lampiran B** — Kaskade seleksi model dengan seluruh statistik diagnostik
- **Lampiran C** — Panel robustness: elastisitas berbobot, PMTB tahun sebelumnya, bentuk growth
- **Lampiran D** — Tren TFP 34 provinsi dengan galat baku dan p-value
- **Lampiran E** — Perbandingan desain perhitungan terhadap perhitungan sebelumnya

## Daftar sumber

Sumber lengkap beserta status verifikasinya ada di `00 Docs/catatan-literatur.md`.

Bappenas (2025). *Paparan peluncuran Master Plan Produktivitas Nasional*, 7 Oktober 2025.

Bappenas & Asian Productivity Organization (2025). *Indonesia's National Productivity Master Plan
2025–2029*. Tokyo: APO.

Barro, R.J. (1999). Notes on Growth Accounting. *Journal of Economic Growth* 4(2), 119–137.

Basu, S. & Fernald, J.G. (1997). Returns to Scale in U.S. Production: Estimates and Implications.
*Journal of Political Economy* 105(2), 249–283.

Chen, X. & Plotnikova, T. (2018). The Measurement of Capital: Retrieving Initial Values from Panel
Data. *Review of Income and Wealth* 64(3), 542–562.

Combes, P.-P., Duranton, G. & Gobillon, L. (2008). Spatial Wage Disparities: Sorting Matters!
*Journal of Urban Economics* 63(2), 723–742.

Di Giacinto, V. & Nuzzo, G. (2006). Explaining labour productivity differentials across Italian
regions: the role of socio-economic structure and factor endowments. *Papers in Regional Science*
85(2), 299–320.

Driscoll, J.C. & Kraay, A.C. (1998). Consistent Covariance Matrix Estimation with Spatially
Dependent Panel Data. *The Review of Economics and Statistics* 80(4), 549–560.

Graham, D.J. (2009). Identifying urbanisation and localisation externalities in manufacturing and
service industries. *Papers in Regional Science* 88(1), 63–84.

Griliches, Z. & Hausman, J.A. (1986). Errors in variables in panel data. *Journal of Econometrics*
31(1), 93–118.

Griliches, Z. & Mairesse, J. (1998). Production Functions: The Search for Identification. Dalam
S. Strøm (ed.), *Econometrics and Economic Theory in the 20th Century: The Ragnar Frisch Centennial
Symposium*, 169–203. Cambridge University Press.

Hulten, C.R. (2001). Total Factor Productivity: A Short Biography. Dalam C.R. Hulten, E.R. Dean &
M.J. Harper (eds.), *New Developments in Productivity Analysis*, 1–54. University of Chicago Press.

Inklaar, R., Timmer, M.P., & van Ark, B. (2007). Mind the Gap! International Comparisons of
Productivity in Services and Goods Production. *German Economic Review* 8(2), 281–307.

Kakamu, K., Polasek, W., & Wago, H. (2012). Production technology and agglomeration for Japanese
prefectures during 1991–2000. *Papers in Regional Science* 91(1), 29–41.

Kataoka, M. (2020). Total factor productivity change in Indonesia's provincial economies for
1990–2015: Malmquist productivity index approach. *Letters in Spatial and Resource Sciences* 13(3),
233–243.

Krugman, P. (1994). The Myth of Asia's Miracle. *Foreign Affairs* 73(6), 62–78.

Lee, Y.H. & Park, J. (2024). Middle-income country trap and total factor productivity growth.
*Pacific Economic Review* 29(2), 214–229.

McCombie, J.S.L. & Roberts, M. (2007). Returns to Scale and Regional Growth: The Static-Dynamic
Verdoorn Law Paradox Revisited. *Journal of Regional Science* 47(2), 179–208.

Muinelo-Gallo, L. & Roca-Sagalés, O. (2011). Economic Growth and Inequality: The Role of Fiscal
Policies. *Australian Economic Papers* 50(2–3), 74–97.

Mundlak, Y. (1978). On the Pooling of Time Series and Cross Section Data. *Econometrica* 46(1),
69–85.

Musyawwiri, A. & Üngör, M. (2019). An Overview of the Proximate Determinants of Economic Growth in
Indonesia Since 1960. *Bulletin of Indonesian Economic Studies* 55(2), 213–237.

Niebel, T., O'Mahony, M., & Saam, M. (2017). The Contribution of Intangible Assets to Sectoral
Productivity Growth in the EU. *Review of Income and Wealth* 63(s1), S49–S67.

Olomola, P.A. & Osinubi, T.T. (2018). Determinants of Total Factor Productivity in Mexico,
Indonesia, Nigeria, and Turkey (1980–2014). *Emerging Economy Studies* 4(2).

Rusiawan, W., Tjiptoherijanto, P., Suganda, E., & Darmajanti, L. (2015). Assessment of green total
factor productivity impact on sustainable Indonesia productivity growth. *Procedia Environmental
Sciences* 28, 493–501.

Solow, R.M. (1957). Technical Change and the Aggregate Production Function. *The Review of Economics
and Statistics* 39(3), 312–320.

StataCorp (2025). Mundlak specification test (`estat mundlak`), New in Stata 19.

Tang, J. & MacLeod, C. (2006). Labour force ageing and productivity performance in Canada.
*Canadian Journal of Economics* 39(2), 582–603.

van der Eng, P. (2009). Total Factor Productivity and Economic Growth in Indonesia. ANU
Arndt-Corden Working Paper 2009/01.

van der Eng, P. (2010). The sources of long-term economic growth in Indonesia, 1880–2008.
*Explorations in Economic History* 47(3), 294–309.

Young, A. (1995). The Tyranny of Numbers: Confronting the Statistical Realities of the East Asian
Growth Experience. *The Quarterly Journal of Economics* 110(3), 641–680.

Chen (1997) serta Easterly dan Levine (2001) dikutip sebagaimana tercantum dalam Olomola dan
Osinubi (2018). Bureau dan Antón (2022) dikutip sebagaimana tercantum dalam Masterplan
Produktivitas Nasional.
