# Simulator Investasi dan TFP

Aplikasi Django untuk BKPM/Kemeninves: berapa PMA+PMDN yang dibutuhkan agar PDRB tumbuh sesuai sasaran (misalnya 8%), di provinsi dan sektor mana, dan seberapa yakin hasilnya. Dibangun di atas fungsi produksi dan koefisien sektoral dari analisis TFP di `02 Code/TFP`.

## Menjalankan

```bash
cd "02 Code/Simulator-Investasi"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py muat_data_awal      # 34 provinsi + pangsa 6 provinsi Papua + 28 indikator determinan TFP, parameter, 8 paket bawaan, 2 contoh, 3 rekomendasi
python manage.py muat_io             # opsional: tabel IRIO dan IO nasional dari 01 Data/IO-IRIO-NA
python manage.py runserver           # http://127.0.0.1:8000
```

`muat_data_awal --ulang` mengosongkan data lalu memuat ulang. `--dataset <berkas.xlsx>` memakai dataset lain. `muat_determinan [--versi <pk>] [--berkas <xlsx>]` mengisi ulang indikator determinan TFP sebuah versi (bawaan versi aktif) dari lembar "Analisis Luaran 2" `01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx`. `muat_pangsa_papua [--versi <pk>]` mengisi ulang pangsa enam provinsi Papua sebuah versi dari berkas BKPM/DJPK. Uji: `python manage.py test` (estimator dan statistik t, diagnostik kelengkapan, penyunting grid, pivot, keterkaitan IO, mesin, paket; uji replikasi vintage B dan mesin dilewati bila berkas data repo tidak ada).

Untuk server: set `SIMULATOR_SECRET_KEY`, `SIMULATOR_DEBUG=0`, `SIMULATOR_HOSTS`, lalu `python manage.py collectstatic` dan jalankan `simulator.wsgi` dengan gunicorn di belakang nginx. Peta dan grafik tidak memanggil internet (Leaflet, Chart.js, dan geojson disajikan lokal).

## Isi aplikasi

| Menu | Fungsi |
|---|---|
| Skenario aktif (bilah atas) | Satu skenario aktif global per sesi; Beranda, Hasil, Jelajah, IO-IRIO, dan Pivot mengikutinya |
| Beranda | KPI nasional, peta indikator 38 provinsi dengan ringkasan sebaran dan peringkat, seri PMA/PMDN dan laju PDRB/PMTB, skenario aktif |
| Skenario | Ruang skenario: kolom = skenario, baris = asumsi (seperti lembar Skenario Excel), sunting di sel lalu simpan dan jalankan. Paket bawaan tetap; mengubahnya menyimpan salinan kustom yang bisa dinamai, dilihat, dihapus, dan dijadikan aktif. Form lengkap untuk kejutan dan jalur per tahun |
| Kejutan dan jalur | Kejutan pada TFP, PDRB, tenaga kerja, atau realisasi PMA+PMDN di tahun tertentu yang meluruh dengan persistensi ρ (nasional, satu pulau, atau satu provinsi); jalur per tahun untuk sasaran pertumbuhan, pengali laju TFP, dan laju tren PMA+PMDN, sehingga lintasan tidak harus lurus |
| Determinan TFP | Enam pilar (pendidikan, equity, institusi, konektivitas, lingkungan, keamanan), 27 indikator: perubahan di atas tren historis (dalam simpangan baku, 1 = selisih khas antara satu provinsi dan rata-rata provinsi) per pilar atau per indikator, jeda sebelum efek dan lama menuju efek penuh, atau didanai dari porsi investasi tambahan dengan biaya menaikkan 1 simpangan baku; efek per pilar, efek per Rp 100 T, dan grafik efek per tahun di Hasil; koefisien dapat disunting di Estimasi |
| Hasil | Skenario aktif: kartu, laju tanpa dan dengan penambahan investasi serta sasaran dengan pita P10–P90, grafik dan daftar kejutan/jalur, investasi, TFP, sumber laju, peta, tabel provinsi dan sektor |
| Bandingkan | Beberapa skenario dalam satu tabel neraca dan empat grafik; peta historis berdampingan dengan peta tiap skenario dalam skala warna yang sama |
| Jelajah | Peta dan ringkasan sebaran, profil provinsi, perbandingan se-pulau, peringkat, agregat per pulau, tabel untuk indikator utama dan indikator determinan TFP (dikelompokkan per pilar); Papua 6 provinsi secara bawaan |
| IO-IRIO | Tabel IRIO 38 provinsi × 17 sektor dan IO nasional (RAS/cross-entropy): peta aliran antarprovinsi, keterkaitan ke belakang/depan dan jaringan sektor, matriks A/L, peta pengganda per provinsi, dampak investasi skenario aktif (ΔOutput, ΔNTB, limpahan) |
| Pivot | Pivot bebas atas lima sumber (panel, sektoral, hasil skenario, IO per sektor, aliran IO); sumber panel memuat 28 indikator determinan TFP (kelompok "Determinan TFP: pilar", rata-rata untuk indeks dan rasio, jumlah untuk km, ton, orang, dan unit): seret bidang ke baris/kolom/filter, banyak ukuran dan agregasi (jumlah, rata-rata, berbobot, median, min/maks, simpangan baku), ukuran turunan, tampil sebagai % induk/kolom/baris/selisih/indeks, urut dan top-N, subtotal, peta panas, grafik, tata letak tersimpan dan tautan, unduh CSV/XLSX bergaya neraca |
| Data | Unggah dataset atau pembaruan, laporan pembersihan, konfirmasi/aktifkan versi; penyunting grid (provinsi × tahun atau provinsi × variabel, termasuk indikator determinan TFP, tempel dari Excel, tambah tahun baru, ekstrapolasi) yang selalu menyimpan versi turunan beralasan; Kelengkapan: 17 pemeriksaan dengan rincian sel yang bisa langsung disunting, matriks kelompok × tahun dan provinsi × tahun |
| Estimasi | Meja kerja two-way FE: pilih versi data, tahun bebas (termasuk mengecualikan 2020), provinsi per pulau, efek tahun, CRS, PMTB atau stok PIM; keluaran langsung (koefisien, SE klaster, t, p, CI 95%, uji CRS, efek tahun, peta efek provinsi, residual) dan kumpulan set elastisitas tersimpan dalam satu halaman; koefisien sektoral β |

Tabel di seluruh aplikasi memakai format neraca: baris kelompok, subtotal, dan total bergaris ganda.

## Paket skenario investasi

Tangga kebijakan di `simulasi/templat.py`. Tiap paket mewarisi asumsi paket dasarnya lalu menambah satu kelompok kebijakan, sehingga selisih antarpaket terbaca sebagai efek kebijakan itu. Paket dibuat dengan versi data aktif, set parameter bawaan, dan koefisien sektoral bawaan, lalu bisa disunting seperti skenario biasa.

| Paket | Dasar | Isi | Laju tanpa penambahan investasi | Laju dengan penambahan investasi | Investasi tambahan kum. (T) | Tambahan dibutuhkan (T) |
|---|---|---|---|---|---|---|
| BAU (Business as Usual) | – | Investasi dasar = tren historis PMA+PMDN, tanpa investasi tambahan | 3,99 | 3,99 | 0 | 9.523 |
| Perlambatan (Risiko Perlambatan) | BAU | Realisasi 6,8%/thn (laju 2017–2021, terlemah dalam data BKPM); kejutan 2026 meniru 2020: realisasi −5,6% (persistensi 0,85) dan TFP −1% (0,7); laju TFP 75% dari tren; belanja APBD −0,03 simpangan baku | 2,36 | 2,17 | 0 | 14.370 |
| Percepatan (Percepatan Realisasi) | BAU | Investasi dasar = target nilai PMA+PMDN Renstra BKPM: Rp2.175,3 / 2.567,5 / 2.969,6 / 3.414,8 T (2026–2029); jalan mantap +0,05 simpangan baku, kargo kapal +0,02 | 4,18 | 4,32 | 0 | 8.890 |
| Hilirisasi | Percepatan | Investasi tambahan = laju Peta Jalan Hilirisasi Rp566,5 T/thn (USD 618 miliar ÷ 18 tahun × Rp16.500), 60% sekunder, 25% jasa bernilai tambah; kargo kapal +0,04 simpangan baku, kargo kereta +0,04 | 4,18 | 5,32 | 2.266 | 7.737 |
| Pemerataan (KTI dan Fiskal Daerah) | Hilirisasi | Investasi tambahan berbobot 2× untuk KTI (Renstra: porsi luar Jawa 52,4% → 53,2%); belanja modal APBD +3%; 2 poin TK pertanian ke industri; belanja APBD +0,02 simpangan baku, P1 −0,08 | 4,18 | 6,27 | 2.266 | 5.476 |
| Reformasi (Produktivitas) | Pemerataan | Lama sekolah +0,20 simpangan baku, harapan lama sekolah +0,10, rasio PAD +0,05, kargo kereta +0,08; laju TFP 110% dari tren; sasaran proporsional | 4,42 | 6,83 | 2.266 | 4.479 |
| Penuh 8% (Kebutuhan Penuh 8%) | Reformasi | Investasi tambahan diskalakan sampai laju nasional dengan penambahan = 8% | 4,42 | 8,00 | 4.473 | 4.479 |
| Bertahap (Sasaran Bertahap) | Penuh 8% | Jalur sasaran RPJMN 6,3 → 7,5 → 7,7 → 8,0% dengan investasi tambahan sebesar kebutuhannya | 4,42 | 7,37 | 2.656 | 2.653 |

Sumber angka rupiah:

- **Renstra Kementerian Investasi dan Hilirisasi/BKPM 2025–2029** (Permen Investasi dan Hilirisasi/Kepala BKPM No. 6 Tahun 2025): Tabel 4.1 target nilai PMA+PMDN (2025 Rp1.905,6 T; jumlah 2025–2029 Rp13.032,8 T, disebut sebagai kebutuhan untuk pertumbuhan 8%), target realisasi bidang hilirisasi (Rp586,6 T pada 2026 sampai Rp901,6 T pada 2029), target porsi realisasi luar Jawa; Bab I Peta Jalan Hilirisasi Investasi Strategis 2023–2040 (USD 618,0 miliar); Bab III target pertumbuhan RPJMN 2025–2029.
- **Kurs** Rp16.500/USD, asumsi dasar ekonomi makro APBN 2026.
- **Realisasi PMA+PMDN BKPM** pada data panel: Rp692,8 T (2017), 809,6 (2019), 826,3 (2020), 901,0 (2021), 1.931,1 (2025); laju 2017–2021 dan episode 2020 menjadi dasar Perlambatan.

Investasi tambahan Hilirisasi diperlakukan di atas target Renstra (yang sudah memuat target hilirisasi), sehingga memakai laju Peta Jalan, bukan target hilirisasi Renstra, agar tidak terhitung dua kali. Target Renstra hanya sekitar Rp363 T di atas tren historis 2026–2029, sedangkan kebutuhan tambahan untuk 8% menurut model jauh lebih besar.

Perubahan determinan TFP dalam simpangan baku di atas laju historis 2017–2024 (lama sekolah +0,11 simpangan baku/thn, P1 +0,04, rasio PAD +0,05, belanja APBD +0,03, jalan mantap dan kargo sekitar 0). Determinan hanya masuk ke laju dengan penambahan investasi, sehingga Perlambatan dan Percepatan berbeda dari laju tanpa penambahan walau tanpa investasi tambahan.

Tiga skenario kustom "Rekomendasi jalur" (`templat.REKOMENDASI`, dibuat `muat_data_awal` atau `templat.buat_rekomendasi()`) memakai asumsi Bertahap dengan sasaran dan fokus berbeda, berdasar skrining transmisi sektor 2025, aturan penyeimbangan portofolio telaah TFP–BKPM, dan triangulasi kuadran Bagian 6.1.6:

| Jalur | Sasaran 2026–2029 (%) | Fokus | Laju dengan penambahan | Investasi tambahan kum. (T) |
|---|---|---|---|---|
| Jalur Industri | 6,0 → 7,0 → 7,8 → 8,2 | 65% sekunder (industri pengolahan, listrik, konstruksi), 25% jasa bernilai tambah; jalan mantap +0,15 simpangan baku, kargo kereta +0,08, lama sekolah +0,15 | 7,25 | 2.420 |
| Jalur SDM | 5,8 → 6,8 → 7,6 → 8,4 | Bobot 2× KTI, 35% jasa bernilai tambah, 15% tersier lain; lama sekolah +0,35 simpangan baku, P1 −0,20, IPM +0,05 | 7,15 | 2.770 |
| Jalur Fiskal | 6,5 → 7,2 → 7,6 → 8,0 | Belanja modal APBD +5%; rasio PAD +0,15 simpangan baku, belanja APBD +0,04, jalan mantap +0,10 | 7,32 | 2.511 |

Dua skenario contoh (`templat.CONTOH`, `templat.buat_contoh()`): **Tren 8%** (investasi dasar = tren historis, investasi tambahan = selisih target Renstra terhadap tren, Rp363 T kumulatif; laju dengan penambahan 4,19%) dan **Masterplan** (TFP 2%/thn, sasaran proporsional, investasi tambahan = target realisasi hilirisasi Renstra dengan komposisi hilirisasi, realokasi TK 3 poin; laju dengan penambahan 5,89%, Rp2.943 T kumulatif).

Angka dari dataset awal (38 provinsi, vintage B, β M2). Nama singkat dipakai di seluruh aplikasi; kode P0–P7 hanya kunci internal. Investasi tambahan Penuh 8% dan Bertahap dicari dengan secant atas skala jalur kebutuhan tambahan: kebutuhan tambahan nasional saja kurang, sebab surplus investasi dasar di provinsi yang sudah melampaui sasaran mengurangi angka nasional padahal investasi tambahan dialokasikan ke provinsi yang kekurangan.

## Metode singkat

1. **Fungsi produksi:** ln Y = a<sub>i</sub> + d<sub>t</sub> + b1 ln K + b2 ln L. Y = PDRB ADHK, K = PMTB ADHK, L = tenaga kerja 17 sektor. Bawaan vintage B: b1 = 0,4019 (SE 0,0424), b2 = 0,1472 (SE 0,1073), N = 272, 2017–2024.
2. **Investasi ke PMTB:** PMTB nominal = tren + π·(investasi dasar + investasi tambahan − tren PMA+PMDN) + π<sub>g</sub>·APBD tambahan, dideflasi dengan inflasi PMTB historis.
3. **Dua laju:** laju tanpa penambahan investasi = jalur dengan investasi dasar saja; laju dengan penambahan investasi = investasi dasar + investasi tambahan (+ APBD tambahan, realokasi tenaga kerja, bonus komposisi sektor, determinan TFP).
4. **Kebutuhan:** dari jalur sasaran per provinsi (seragam, proporsional dengan bisection agar nasional = sasaran, atau manual) dihitung mundur PMTB lalu PMA+PMDN yang dibutuhkan. Selisih terhadap investasi dasar = kebutuhan tambahan.
5. **Sektor:** bonus laju TFP = Σ β<sub>g</sub> × Δ pangsa investasi kelompok g (t−1), β dari `13_Sectoral` M2.
6. **Keyakinan:** Monte Carlo atas b1, b2, rata-rata TFP, laju TK, β, dan kejutan TFP tahunan, menghasilkan peluang capai sasaran dan kebutuhan P50/P80/P90.
7. **Kejutan dan jalur:** kejutan berukuran s pada tahun t<sub>0</sub> dengan persistensi ρ menggeser level TFP, PDRB, tenaga kerja, atau realisasi sebesar s·ρ<sup>t−t<sub>0</sub></sup>, pada kedua laju dan kebutuhan; jalur per tahun menggantikan nilai tunggal sasaran pertumbuhan, pengali laju TFP, atau laju tren PMA+PMDN pada tahun yang diisi.
8. **Estimasi:** two-way FE dengan demean bergantian (tepat untuk panel tak seimbang), SE klaster provinsi HC1, uji t dan CI memakai distribusi t dengan G−1 derajat bebas, uji CRS untuk b1 + b2 = 1. Pilihan stok modal PIM: K<sub>t</sub> = (1−δ)K<sub>t−1</sub> + I<sub>t</sub>, K<sub>0</sub> = I<sub>0</sub>/(g + δ).
9. **Determinan TFP:** D<sub>h</sub> = Σ<sub>k</sub> β<sub>k</sub>·Δz<sub>k</sub>·(1/R)·Σ<sub>r=0..R−1</sub> a(h − L − r) ditambahkan ke ln A pada laju dengan penambahan investasi dan kebutuhan (tidak pada laju tanpa penambahan). β = perubahan log TFP per kenaikan 1 simpangan baku indikator (satu regresi per pilar, 34 provinsi 2017–2024, N = 272); L = jeda, R = masa menuju efek penuh (asumsi; bawaan pendidikan 3/3, equity 2/2, institusi 1/2, konektivitas 1/2, lingkungan 2/2, keamanan 1/1); a = capaian perubahan (porsi kumulatif investasi tambahan bila didanai, linier bila tidak). Bila didanai, Δz = porsi × total investasi tambahan ÷ biaya menaikkan 1 simpangan baku; dana sudah masuk modal pada tahun dibelanjakan, efek TFP menyusul. Monte Carlo menarik β ~ N(β, SE).
10. **IO:** L = (I − A)<sup>−1</sup>, pengganda output = jumlah kolom L, pengganda NTB = v·L, keterkaitan ke depan dari invers Ghosh; dampak investasi = L·(jembatan PMTB × investasi per provinsi).
11. **Papua enam provinsi:** versi data dan estimasi tetap 34 provinsi. Untuk simulasi (opsi skenario "rinci Papua", bawaan aktif), tiap variabel Papua Barat dan Papua dibagi ke anggota keluarganya: X<sub>anggota,t</sub> = X<sub>induk,t</sub> × pangsa<sub>anggota,t</sub>. Pangsa dari `01 Data/BKPM/processed/Dataset Provinsi(Database (62026)).csv` (PDRB dari jumlah nilai tambah sektoral 2023–2025, PMTB 2024–2025, PMA/PMDN per sektor 2023–2025, penduduk = PDRB ADHB / PDRB per kapita sebagai pangsa tenaga kerja) dan APBD/PAD DJPK 2023–2025. Sebelum tahun pertama pangsa tahun itu dipakai mundur. Total induk dan nasional tidak berubah. Unggahan yang memuat baris provinsi pemekaran memperbarui pangsa; unggahan tanpa baris itu mewarisi pangsa versi induk atau versi aktif.

## Batasan

- **K adalah arus PMTB, bukan stok.** b1 cenderung batas bawah dan kebutuhan cenderung batas atas. PDRB tahun T ditentukan oleh PMTB tahun T, sehingga angka kumulatif adalah jumlah kebutuhan tahunan, bukan stok.
- **β sektoral menunjukkan keterdahuluan waktu, bukan kausalitas.**
- **Revisi data:** estimasi ulang pada dataset terbaru memberi b1 ≈ 0,387 dan b2 ≈ 0,193, berbeda dari vintage B karena PDRB/PMTB direvisi. Keduanya tersedia di kumpulan set halaman Estimasi.
- **Realisasi BKPM berbeda cakupan dengan PMTB**; pass-through mengatur porsinya.
- **Tenaga kerja 2025 belum ada** di dataset; laju TK memakai rata-rata historis atau isian.
- **Papua enam provinsi adalah rincian, bukan estimasi terpisah.** Laju historis provinsi baru sama dengan induknya sampai 2023 (PDRB) atau 2024 (PMTB); perbedaan datang dari level dan dari laju yang teramati sesudahnya (misalnya Papua Barat +20,8% 2024 karena LNG Tangguh, Papua Tengah −22% 2025). Elastisitas memakai estimasi 34 provinsi.
- **Berkas BKPM 2024–2025:** kolom PDRB dan PMTB sisi pengeluaran (`9_ADHK`, `9_ADHB`, `4_ADHK`, `4_ADHB`) untuk lima provinsi baru tergeser satu baris (misalnya baris Papua Pegunungan berisi angka Papua Tengah). Aplikasi mendeteksi dan mengembalikannya dengan mencocokkan total PDRB ke jumlah nilai tambah sektoral (yang berlabel benar), lalu mencatatnya di laporan. ADHB sektoral Papua 2023 tidak sejalan dengan ADHK (deflator implisit sekitar 4 kali provinsi lain), sehingga penduduk turunan Papua 2023 tidak dipakai. Dataset agregasi 34 provinsi tidak terdampak.

## UML

Sumber PlantUML ada di `docs/uml/*.puml`, gambar di `docs/uml/png/` dan `docs/uml/svg/`:

| Berkas | Diagram |
|---|---|
| 01_use_case | Use case |
| 02_komponen | Komponen dan paket |
| 03_kelas_domain | Kelas: model domain |
| 04_kelas_layanan | Kelas: pembersihan, estimasi, mesin simulasi, Excel |
| 05_sekuens_unggah | Sekuens: unggah dan pembersihan data |
| 06_sekuens_simulasi | Sekuens: menjalankan skenario |
| 07_sekuens_excel | Sekuens: putaran Excel |
| 08_aktivitas_pembersihan | Aktivitas: pipeline pembersihan |
| 09_aktivitas_simulasi | Aktivitas: algoritma simulasi |
| 10_state_versi | State: versi data dan skenario |
| 11_deployment | Deployment |
| 12_erd | Relasi entitas |

Render ulang (perlu Java dan Graphviz): `cd docs/uml && java -jar plantuml.jar -tsvg -o svg [0-9]*.puml && java -jar plantuml.jar -tpng -o png [0-9]*.puml`.
