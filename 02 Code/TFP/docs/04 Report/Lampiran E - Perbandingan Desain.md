# Lampiran E — Perbandingan desain perhitungan TFP

Perhitungan awal kajian ini disusun dalam Stata (`Analisis Data Provinsi BKPM (2).do`). Tabel
berikut membandingkan setiap komponen desainnya dengan yang dipakai pada laporan ini, beserta
alasan tiap perubahan. Dari tujuh belas komponen, lima dipertahankan, sepuluh diubah, dan dua
ditambahkan.

## Komponen yang dipertahankan

| # | Komponen | Isi | Catatan |
|---|---|---|---|
| 1 | Kerangka fungsi produksi | Cobb-Douglas log-linear, `log Y = a + b1 log K + b2 log L + u_i + e_it` | Uji RESET pada efek tetap satu arah tidak menolak linearitas (p=0,343), sehingga bentuk ini dipertahankan |
| 2 | Ukuran modal | PMTB | Stok kapital provinsi tidak dipublikasikan BPS, dan perpetual inventory tidak layak dengan seri delapan tahun |
| 3 | Ukuran tenaga kerja | Penjumlahan 17 kolom tenaga kerja sektoral | — |
| 4 | Ekstraksi TFP | Residual `a + u_i + e_it`, di-antilog untuk level | — |
| 5 | Bentuk growth (first-difference) | Regresi pada laju pertumbuhan | Dipakai sebagai salah satu sumber elastisitas; hasilnya b1=0,151 dengan jumlah elastisitas 0,416 |

## Komponen yang diubah

| # | Komponen | Perhitungan awal | Laporan ini | Pertanggungjawaban |
|---|---|---|---|---|
| 6 | Variabel output utama | PDRB harga berlaku (ADHB) | PDRB harga konstan (ADHK) | TFP adalah konsep riil; residual dari output nominal memuat perubahan harga. Uji Pesaran CD memberi z=12,90 pada efek tetap basis nominal versus z=3,24 pada efek tetap basis riil; pada random effects selisihnya 33,56 versus 0,99. Catatan pada do-file itu sendiri sudah menyarankan pengulangan dengan output riil |
| 7 | Estimator utama | Random effects | Efek tetap dua arah, provinsi dan tahun | Uji Mundlak menolak random effects pada p<0,001, dan uji Pesaran CD menuntut penambahan efek tahun. Uji Hausman klasik tidak dipakai sebagai dasar, karena asumsinya sudah ditolak; lihat baris 9 |
| 8 | Dasar pemilihan estimator | Pertimbangan intuitif, dinyatakan eksplisit dalam komentar do-file | Kaskade S0–S6 yang ditetapkan sebelum hasil dilihat | Pilihan intuitif tidak dapat dipertanggungjawabkan kepada pembaca, dan tidak dapat direplikasi |
| 9 | Uji efek tetap versus acak | Hausman klasik | Uji Mundlak dengan galat baku cluster-robust | Hausman klasik mensyaratkan efisiensi estimator random effects, yang menuntut homoskedastisitas dan ketiadaan autokorelasi. Keduanya ditolak pada p<0,001 (Modified Wald; Wooldridge AR(1)). Kedua hasil Hausman tercatat dan keduanya tidak admissible: pada basis nominal χ²=54,7 (p<0,001) dan pada basis riil χ²=5,20 (p=0,074). Rujukan: Mundlak (1978); StataCorp (2025) |
| 10 | Efek tahun | Tidak ada pada model utama | Ada | Uji Pesaran CD menolak independensi lintas provinsi (p=0,001 pada efek tetap satu arah) |
| 11 | Galat baku | Klaster provinsi | Driscoll-Kraay | Uji CD tetap menolak setelah efek tahun ditambahkan (p<0,001). Galat baku elastisitas modal melebar dari 0,0349 ke 0,0531, yaitu 52% |
| 12 | Pergerakan TFP antar waktu | Selisih level antar tahun | Koefisien dummy tahun beserta selang kepercayaan | Korelasi intraklas 0,988 menunjukkan hampir seluruh varian bersifat antar-provinsi. Simpangan baku residual dalam provinsi (0,0355) melebihi seluruh rentang pergerakan deret nasional delapan tahun (0,0250) |
| 13 | Skala hasil | Tidak diuji dan tidak direstriksi | Diuji dengan Wald; elastisitas terestimasi non-CRS jadi basis utama, CRS jadi diagnostik + kontrafaktual | Uji menolak `b1+b2=1` di semua spesifikasi. Basis utama memakai elastisitas terestimasi apa adanya (b1=0,400, b2=0,191) agar suku skala tidak bocor ke residual (Barro 1999); varian skala hasil konstan disajikan sebagai diagnostik dan kontrafaktual tersimulasi (Bagian 3.2–3.4). Kaveat: penolakan CRS sebagian bisa atenuasi proksi arus PMTB (Griliches & Mairesse 1998; Basu & Fernald 1997) |
| 14 | Variabel instrumen (2SLS/GMM) | Ada, dengan PMA dan PMDN sebagai instrumen | Tidak dijalankan | PMA dan PMDN secara definisi merupakan bagian dari PMTB pada komponen aset tetap non-tanah, sehingga *exclusion restriction* gagal. |
| 15 | Galat baku jackknife dan bootstrap | Ada | Tidak dilaporkan | Keduanya menangani jumlah klaster yang kecil. Masalah yang mengikat pada data ini adalah dependensi lintas provinsi, yang ditangani Driscoll-Kraay |

## Komponen yang ditambahkan

| # | Komponen | Isi | Alasan |
|---|---|---|---|
| 16 | Level analisis | Provinsi, ditambah agregasi nasional dan pulau | Kerangka Bab 7 laporan induk menetapkan nasional dan pulau sebagai satuan penyajian. Unit observasi tetap provinsi |
| 17 | Dekomposisi pertumbuhan | Enam skenario elastisitas, lima ditampilkan di badan laporan | Diperlukan untuk menjawab besaran dan proporsi kontribusi TFP terhadap pertumbuhan |

## Status tiap perubahan terhadap perhitungan awal

**Satu perubahan sudah diantisipasi.** Catatan pada bagian robustness do-file menyatakan TFP
lazimnya dihitung atas output riil dan menyarankan pengulangan dengan PDRB harga konstan
(perubahan nomor 6).

**Empat perubahan merupakan tindak lanjut atas diagnostik yang hasilnya sudah tersedia** dalam
perhitungan awal tetapi tidak dipakai pada pemilihan model: nomor 7, 9, 10, dan 11.

**Empat perubahan tidak memiliki jejak dalam perhitungan awal** dan merupakan keputusan baru:
nomor 8 (mengganti dasar pemilihan estimator), 12 (cara mengukur pergerakan TFP antar waktu),
13 (menguji skala hasil), dan 14 (menolak pendekatan variabel instrumen).

**Satu perubahan bersifat penyajian.** Nomor 15: do-file menjalankan galat baku jackknife dan
bootstrap, dan yang baru adalah keputusan tidak melaporkannya.

Perubahan nomor 14 perlu dicatat khusus. Do-file menjalankan pendekatan variabel instrumen secara
ekstensif, mencakup sepuluh jenis estimator (G2SLS, FE-IV, EC2SLS, EC2SLS tanpa Swamy-Arora,
between, first-difference, 2SLS pooled, GMM, LIML, dan FE-IV lewat LSDV) pada dua basis output,
kecuali FE-IV lewat LSDV yang hanya dijalankan pada output riil,
tanpa mempertanyakan validitas instrumennya. Keberatan
*exclusion restriction* dalam laporan ini mengikuti definisi PMTB: PMA dan PMDN masuk komponen aset tetap, dan bukan dari catatan do-file.

## Akibat terhadap angka

| | Perhitungan awal | Laporan ini |
|---|---:|---:|
| Elastisitas modal | 0,829 | 0,446 (skala hasil konstan) / 0,400 (tanpa restriksi) |
| Elastisitas tenaga kerja | 0,262 | 0,554 (skala hasil konstan) / 0,191 (tanpa restriksi) |
| Jumlah elastisitas | 1,091 | 1 dipaksakan / 0,591 |

Perbedaan terbesar berasal dari perpindahan basis nominal ke riil. Pada basis riil dengan estimator
dan galat baku yang sama seperti perhitungan awal, elastisitas modal turun ke 0,459 dan elastisitas
tenaga kerja naik ke 0,438.
