# Status Kajian TFP — untuk ditinjau

Tanggal: 2026-07-18, diperbarui 2026-08-20. Dokumen ini untuk Anda anotasi sambil membaca.
Tulis catatan langsung di bawah butir yang bersangkutan; saya akan menindaklanjuti dari sini.

---

## PEMBARUAN 20 AGUSTUS 2026 — 2025 masuk estimasi, ADHB berdampingan dengan ADHK

Tiga pekerjaan, semuanya sudah jalan dan lolos uji.

**1. Panel estimasi naik dari 272 ke 306 observasi.** Workbook sumber kini terisi tenaga kerja
2025, jadi 2025 tidak lagi gugur sendiri di `plm`. Elastisitasnya bergeser besar:

| | Sebelum (2017-2024) | Sesudah (2017-2025) |
|---|---|---|
| riil: b1 | 0,401899 | **0,475304** |
| riil: b2 | 0,147184 | **0,135782** |
| riil: modal · TK · sisa (poin) | 1,31 · 0,31 · 2,21 | **1,55 · 0,28 · 2,00** |
| riil: pangsa sisa | 57,8% | **52,1%** |
| adhb: b1 | 0,458421 | **0,506210** |
| adhb: b2 | 0,015230 | **0,041713** |
| adhb: modal · TK · sisa (poin) | 2,84 · 0,03 · 3,87 | **3,13 · 0,09 · 3,52** |

**Yang harus Anda tahu sebelum mengutip angka 2025.** Sheet `Keterangan` workbook sumber baris
181 menyatakan sendiri: `*_TenagaKerja` 2025 **disalin dari 2024** (LOCF), dan `*_RataUpah` 2025
= 2024 × (UMP₂₀₂₅/UMP₂₀₂₄), sebab Sakernas 2025 belum terbit. Terverifikasi di angka: `g_L` 2025
**persis nol** di ke-34 provinsi.

Akibatnya dua lapis. Di baris 2025, seluruh pertumbuhan output jatuh ke residual. Di seluruh
panel, ke-34 observasi bertipe "modal naik, tenaga kerja diam" menarik b1 naik 18 persen dan b2
turun. Keputusan Anda 20 Agustus: tetap masukkan 2025, dengan kaveat ini ikut terbit.

Karena itu ada garis pemisah yang dipasang di kodenya:

| Yang memuat 2025 | Yang tetap berhenti di 2024 |
|---|---|
| estimasi elastisitas (skrip 01) | dekomposisi nasional (skrip 02) |
| `Predicted Value TFP 2017-2025.xlsx` (skrip 16) | delapan gambar (skrip 03), gambar tahunan (skrip 10) |
| | `Panel TFP Provinsi-Tahun.xlsx` (skrip 13) |

**2. Berkas predicted value, dua basis, dua lokasi.** `02 Code/07_predicted value tfp.R`
menulis `Predicted Value TFP 2017-2025.xlsx` ke `03 Output (ADHB)/` dan ke `All Dataset/`.
Kedua salinan terbukti identik sel demi sel. Enam sheet: `ADHK`, `ADHB` (306 baris masing-masing),
`tempel_CD_CL_adhb`, `basis`, `catatan`, `kaveat`.

Sheet `tempel_CD_CL_adhb` berisi persis sembilan kolom `CD:CL` dalam urutan yang sama, tanpa
kolom kunci, 306 baris. Urutan barisnya **dibaca dari `Analisis Luaran 2` itu sendiri**, lalu
dibandingkan elemen demi elemen — bukan dianggap sama. Jadi tinggal disalin sebagai satu blok.

**3. Sembilan skrip cabang samping pindah ke `99 Arsip/`.** Skrip 05, 06, 07, 08, 09, 11, 12,
14, dan 15. Daftar beserta alasannya di `99 Arsip/MANIFES.md`. Pipeline tersisa: 00, 01, 02, 03,
04, 10, 13, 16.

Keluaran kesembilan skrip itu tidak dihapus dan **tidak diperbarui**, jadi masih memuat angka
lama: `Simulasi Trajektori 2026-2029.xlsx`, `Strategi RTS dan TFP 2026-2029.png`,
`Perbandingan Tiga Basis.xlsx`, serta log 08, 09, 11, 14, dan 15.

**Dua pembacaan yang ikut berbalik, dan sudah ditulis ulang di kodenya.** Pertama, tangga
atenuasi basis riil tidak lagi "bertahan di sekitar 1": ia naik monoton sampai 1,259 di fixed
effects lalu jatuh ke 0,611, sebangun dengan basis adhb. Kedua, tanda komponen 2020 kini
bercampur — kontribusi modal −2,17 sementara sisanya +0,23 — sehingga penanda pertumbuhan aktual
tidak lagi berimpit dengan ujung kolom di tahun itu.

**Keadaan sebelumnya tersimpan** di `99 Snapshot 0820 (sebelum 2025)/`, dua folder keluaran utuh.

**Yang tersisa di tangan Eqi:** tempel sembilan kolom dari `tempel_CD_CL_adhb` ke `CD:CL`.

---

## PEMBARUAN 11 AGUSTUS 2026 — panel provinsi dan sambungan ke dataset umum

Dua pekerjaan, keduanya sudah jalan dan lolos uji. Tidak ada yang menunggu keputusan.

**1. Panel provinsi × tahun.** `02 Code/06_panel provinsi-tahun.R` menghasilkan
`03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx` — 272 baris, 34 provinsi × 8 tahun
(2017–2024), empat sheet: `panel`, `rata_provinsi`, `catatan`, `kaveat`.

Isinya log TFP dua versi plus kontribusi tiga faktor per provinsi per tahun. Elastisitas
non-CRS `b1 = 0,401899`, `b2 = 0,147184`, dibaca dari `parameter_terpilih.rds`.

Lima assertion dipasang. Yang paling menentukan: level direkonstruksi `sum(exp(log))` lalu
dijumlahkan lintas provinsi mendarat persis di `log_02_dekomposisi.txt` skenario F.

Sebaran share TFP antarprovinsi jauh lebih lebar dari angka nasional 57,8 persen:

| Ujung atas | | Ujung bawah | |
|---|---|---|---|
| Sumatera Selatan | 84,8% | Papua Barat | 6,4% |
| DKI Jakarta | 76,2% | Kalimantan Timur | 12,4% |
| Bali | 76,2% | Nusa Tenggara Barat | 17,8% |

Tiga yang di bawah punya kontribusi modal besar tapi PDRB tumbuh pelan.

**Batas pemakaian.** Kolom tahunannya berayun keras karena PMTB itu arus. Aceh 2022
kontribusi modalnya −0,30 padahal PDRB tumbuh 4,13, jadi TFP-nya melompat ke 4,31. Aturan
penyajian di skrip 02 melarang bentuk tahun-per-tahun masuk laporan. Berkas ini alat kerja.

**2. Dataset umum project sudah tersambung ke basis riil.**
`All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` ternyata sudah
mengambil angka TFP lewat tautan luar Excel sejak awal, hanya saja tautannya menunjuk folder
basis nominal. Yang dikerjakan mengalihkan tautan, bukan menimpa angka.

| | Sebelum | Sesudah |
|---|---|---|
| Target tautan | `03 Output` | `03 Output (modal riil)` |
| Kolom Sheet1 | 164 | 170 |
| Kontribusi TFP | 26% | 58% |

Enam kolom baru `FI:FN` — `g_Y`, `g_K`, `g_L`, `kontrib_modal`, `kontrib_tk`, `kontrib_tfp` —
datang dari panel lewat tautan kedua. Alurnya di `README.md` bagian "Sambungan ke dataset
umum project".

**Dua temuan yang mengubah bentuk pekerjaannya.** Pertama, `log_lab_tot` dan `log_ADHK_Tot`
identik sampai digit terakhir di kedua basis, jadi keduanya tidak perlu diganti; yang usang
hanya modal dan TFP. Kedua, baris 2025 sebelumnya tercatat log tenaga kerja **nol**, bukan
kosong, karena `INDEX` atas sel kosong mengembalikan nol. Nol palsu itu sudah dibuang.

Cadangan sebelum bedah: `All Dataset/99 Arsip/… (sebelum basis riil).xlsx`.

**Yang tersisa di tangan Eqi:** buka workbook itu di Excel sekali, pastikan tidak muncul
dialog perbaikan berkas, lalu izinkan Update Links.

---

## PEMBARUAN 4 AGUSTUS 2026 — basis pindah ke modal harga konstan

Kolom `pmtb` yang dipakai seluruh analisis terbit ternyata **harga berlaku**, sementara variabel
terikat `9_ADHK` harga konstan. Model lama karena itu meregresikan output riil pada modal
nominal. Bukti lengkap dan reproducible ada di `02 Code/00_diagnostik modal.R`.

Basis sudah pindah ke `4_ADHK`. Angkanya bergeser besar:

| | Nominal (terbit) | Riil (baru) |
|---|---|---|
| b1 | 0,3997 | 0,4019 |
| b2 | 0,1913 | 0,1472 |
| b1+b2 | 0,591 | 0,549 |
| Kontribusi modal | 2,45 poin (64%) | 1,31 poin (34%) |
| Kontribusi TFP | 0,98 poin (26%) | 2,21 poin (58%) |
| Tren TFP | +0,63%/thn | +1,92%/thn |

Elastisitas nyaris tidak bergerak karena deflator antarprovinsi hampir seragam dan diserap
dummy tahun. Yang jatuh adalah gK agregat, 6,12% ke 3,26%.

**Keluaran baru** di `03 Output (modal riil)/`: 13 gambar, 5 workbook, 6 log. Folder terbit
`03 Output/` sengaja tidak disentuh.

**Sakelar `BASIS_MODAL`** di skrip 00/01/02/03/04/08/09/10 memilih basis sekaligus folder
keluarannya, jadi kedua versi tetap direproduksi dari satu skrip. Lihat `README.md`.

**Modul baru:** `02 Code/08_simulasi trajektori.R` menghitung kebutuhan investasi dan TFP untuk
sasaran 2026-2029 (5,40 / 6,15 / 7,00 / 8,00 persen), basis pertumbuhan 2022-2024.

---

## KEPUTUSAN YANG MENUNGGU — penyajian TFP

Ini yang menghentikan pekerjaan pada 4 Agustus, dan perlu Eqi putuskan sebelum naskah direvisi.

**Masalahnya.** Eqi ingin tiga komponen saja: TFP, modal, tenaga kerja. Di bawah DRS itu
mustahil. Karena `1 − b1 − b2 = 0,451`, ada scale term sebesar **1,33 poin** yang otomatis
mendarat di residual. Residual nasional 2,21 poin, jadi 60 persennya bukan produktivitas.

Per pulau bahkan lebih parah — di Kalimantan dan Maluku-Papua scale term **melebihi** seluruh
residual (135% dan 126%), artinya TFP bersih di sana negatif.

Pemeriksaan silang yang gagal: pembanding Masterplan/APO memberi TFP negatif untuk Jawa,
Kalimantan, dan Nusa Tenggara, sementara versi DRS kita memberi positif untuk ketiganya.

**Jalan keluarnya memaksakan CRS.** Kalau b1+b2 = 1, scale term hilang per konstruksi.
Empat cara, semuanya sudah dihitung skrip 02:

| Basis | b1 | b2 | Modal | TK | TFP | Proporsi |
|---|---|---|---|---|---|---|
| Lama (nominal, DRS) | 0,400 | 0,191 | 2,45 | 0,40 | 0,98 | 64 / 10 / 26 |
| A. CRS terestimasi | 0,452 | 0,549 | 1,47 | 1,14 | 1,22 | 38 / 30 / 32 |
| D. Alfa 1/3 (Bappenas) | 0,333 | 0,667 | 1,09 | 1,39 | 1,35 | 28 / 36 / 35 |
| DRS diskalakan ke 1 | 0,732 | 0,268 | 2,39 | 0,56 | 0,88 | 62 / 15 / 23 |

**Metode PWT sebagai jalan kelima**, ditemukan 4 Agustus dan dicatat di
`00 Docs/catatan-metode-pwt.md`. PWT tidak pernah punya residual menggantung: pangsa modal
didefinisikan `1 − LABSH`, jadi berjumlah satu per konstruksi. Empat tingkat adopsi:

| Tingkat | Kebutuhan data | Status |
|---|---|---|
| Pangsa pendapatan + CRS | upah dan tenaga kerja per provinsi | sudah ada |
| Tambah human capital | rata-rata lama sekolah per provinsi | belum ada |
| Tambah stok PIM per jenis aset | PMTB terpilah jenis aset per provinsi | hampir pasti tidak ada |
| Pakai LABSH terbitan PWT | tidak ada | tinggal unduh, tapi nasional saja |

Rekomendasi: tingkat pertama, dengan koreksi Gollin (2002) atas pangsa upah. Pangsa terukur
15-18% di dataset ini terlalu rendah untuk negara sepenuh wiraswasta seperti Indonesia.

**Belum dikerjakan:** diagnostik yang membandingkan pangsa upah terukur, `b2` terestimasi, dan
rentang van der Eng 28-51 persen.

---

## Yang sudah selesai

| Keluaran | Lokasi | Status |
|---|---|---|
| Laporan | `04 Report/Report TFP.md` | Disetujui pemeriksa akhir setelah 3 putaran |
| Laporan versi Word | `04 Report/Report TFP.docx` | basis non-CRS/DRS, 8 gambar |
| Lampiran perbandingan desain | `04 Report/Lampiran E - Perbandingan Desain.md` | Sudah masuk ke .docx |
| Grafik | `03 Output/*.png` | 8 gambar (termasuk Simulasi DRS vs CRS), semua sudah dieyetest |
| Tabel hasil | `03 Output/*.xlsx` | 3 workbook (termasuk Simulasi DRS vs CRS) |
| Log perhitungan | `03 Output/log_0*.txt` | 4 log, semua exit 0 |
| Catatan literatur | `00 Docs/catatan-literatur.md` | 24 sitasi, 20 terverifikasi penuh |
| Memori topik | `00 Docs/memory_tfp.md` | Untuk sesi berikutnya |
| Spesifikasi model | `00 Docs/spesifikasi-model-tfp.md` | Desain + alasan tiap pilihan |
| Analisis figur Masterplan | `00 Docs/analisis-figur.md` | 21 figur/tabel relevan |
| Panel provinsi × tahun | `03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx` | 272 baris, 4 sheet, 5 assertion lolos |
| Sambungan dataset umum | `All Dataset/…Miliar.xlsx` | tautan luar sudah basis riil, 11 uji lolos |

Urutan membaca yang paling cepat memberi konteks ada di `README.md`.

---

## Yang masih terbuka

### 1. Bab 4 Diskusi kosong

Ditandai MENYUSUL sesuai instruksi Anda. Bahan yang sudah teridentifikasi untuk mengisinya:

- Bab 5.3 laporan induk melaporkan ICOR sekitar 6 dan kebutuhan investasi kumulatif Rp47.587
  triliun untuk mencapai 8%. Temuan kajian ini menjelaskan mikronya: pada basis utama non-CRS
  modal sudah menyumbang 2,45 dari 3,83 poin pertumbuhan (64%), sehingga menaikkan volume
  investasi saja tidak menutup jarak 4,17 poin.
- Jarak per komponen pada basis non-CRS (tenaga kerja 1,60; modal 1,55; TFP 1,02) menunjukkan
  tiga mesin pertumbuhan tertinggal bersamaan, dengan tenaga kerja justru paling jauh.

**Catatan Anda:**

### 2. Level pulau: pilihan penyajian

Sudah dihitung dan masuk laporan (Tabel 7, Gambar 6 dan 7). Yang perlu Anda putuskan: apakah
kedalaman ini memadai untuk mengisi subbab 7.4.2, atau perlu diperluas.

Presisi per pulau rendah karena tiap pulau hanya 3–10 provinsi. Bali-Nusra dengan tiga provinsi
paling rapuh, dan saya sudah menulis peringatannya. Kalau BKPM ingin kesimpulan per pulau yang
lebih kuat, itu butuh pendekatan berbeda, bukan sekadar memperbanyak grafik.

**Catatan Anda:**

### 3. Skala hasil: non-CRS primer, CRS diagnostik (revisi 2026-07-21)

Framing "dua pembacaan setara" dicabut. Basis utama sekarang elastisitas terestimasi tanpa
restriksi (non-CRS/DRS): sisa TFP +0,98 poin (25,7%), tren +0,81%/thn. Varian skala hasil konstan
(CRS) turun status jadi diagnostik dan kontrafaktual tersimulasi (§3.4, Gambar 8). Dasar di litrev
`00 Docs/litrev-twfe-drs-tfp.md`.

Yang bertahan di kedua: dominasi modal (64% non-CRS versus 71% CRS). Yang berpindah: besaran TFP
(26% versus −1%).

**Kaveat wajib dan sudah tertulis di laporan:** penolakan CRS sebagian bisa atenuasi karena modal
diproksi arus PMTB (Griliches & Mairesse 1998; Basu & Fernald 1997), sehingga b1=0,400 batas bawah
dan sisa basis utama cenderung dilebih-lebihkan. TFP sebenarnya kemungkinan antara ~0 (kontrafaktual
CRS, dekat pembanding eksternal APO −0,35 / van der Eng −0,20 / Rusiawan −0,62) dan 0,98 poin, condong
ke ujung bawah. Kontrafaktual CRS mendekati pembanding eksternal sebagian karena sama-sama memaksakan
skala 1, bukan konfirmasi independen.

**Catatan Anda:**

### 4. Konflik 8-4-2-2 di dokumen Masterplan — **diselesaikan 2026-09-05**

Teks naratif Masterplan hal. 48 dan Foreword hal. VII menulis pembagian **tenaga kerja 4, modal 2**.
Paparan peluncuran hal. 9 dan Tabel 3 Masterplan menulis sebaliknya, **modal 4**.

Kajian kini mengikuti narasi resmi (4 tenaga kerja + 2 modal + 2 TFP), sesuai audit
`docs/06 Review/`. Konsekuensi: jarak yang mengikat adalah tenaga kerja, bukan modal. Sheet
`jarak_sasaran` dan kontrafaktual skrip 04 memakai alokasi ini. Badan `Report TFP.md` selain §1.5
tetap vintage lama — lihat `docs/VINTAGE.md`.

**Catatan Anda:**

### 5. Pangsa pendapatan tenaga kerja 15–18%

Dihitung dari kolom `*_RataUpah` × `*_TenagaKerja` × 12 dibagi PDRB harga berlaku. Hasilnya jauh
di bawah rentang 38–51% yang dilaporkan van der Eng untuk Indonesia, dan sumber selisihnya belum
dapat dipastikan dari dataset ini.

Dipakai sebagai bobot, angka itu memberi kontribusi modal 134,5% pertumbuhan — hasil yang tidak
dapat dikutip. Karena itu dilaporkan sebagai batasan, bukan skenario utama.

Karena `RataUpah` variabel bentukan Anda, Anda lebih tahu apakah ada komponen pendapatan yang
belum tercakup. Kalau ternyata pangsanya seharusnya lebih tinggi, skenario growth accounting
berbasis pangsa terukur bisa dihidupkan kembali.

**Catatan Anda:**

### 6. Empat sitasi belum diverifikasi

Miller (1990), Abou Hamia (2020), Crafts & Woltjer (2021), Prados de la Escosura & Rosés (2021).
**Keempatnya tidak dikutip di laporan** — hanya ada di catatan kerja. Jadi daftar pustaka yang
terbit sudah bersih. Verifikasi tetap perlu kalau keempatnya akan dipakai di keluaran berikutnya.

**Catatan Anda:**

### 7. Versi bab buku van der Eng (2013)

Ada versi terbit peer-reviewed dari working paper ANU 2009/01: van der Eng (2013) dalam Rao &
van Ark (eds.), *World Economic Performance*, Edward Elgar, Bab 8. Mengutip bab buku lebih kuat
daripada working paper, tetapi isinya belum diverifikasi sehingga belum ditukar.

**Catatan Anda:**

---

## Angka kunci untuk dicek saat membaca

**Tabel di bawah adalah angka versi terbit (basis nominal, panel 2017-2024) dan tidak
diperbarui 20 Agustus.** Ia dipertahankan sebab `Report TFP.docx` masih memuat angka ini.
Untuk angka mutakhir, lihat pembaruan 20 Agustus di puncak berkas.

Basis utama = elastisitas terestimasi tanpa restriksi (non-CRS/DRS); CRS = diagnostik/kontrafaktual.

| Besaran | Nilai |
|---|---|
| Pertumbuhan PDRB riil 2018–2024 | 3,83%/thn |
| Elastisitas modal (basis utama non-CRS) | 0,400 (b2=0,191, jumlah 0,591) |
| Elastisitas modal (diagnostik CRS) | 0,446 (b2=0,554) |
| Kontribusi modal | 64% (non-CRS, utama) / 71% (CRS) |
| Sisa TFP | +0,98 poin, 25,7% (non-CRS, utama) / −0,05 poin (CRS) |
| Tren indeks TFP | +0,81%/thn, p=0,002 (non-CRS, utama) / −0,27%/thn (CRS) |
| Indeks TFP nasional 2024 | 106,8 (non-CRS, utama) / 98,6 (CRS) |
| Jarak ke sasaran (skenario F, alokasi resmi 4 TK + 2 modal) | lihat sheet `jarak_sasaran` terkini; vintage tabel ini (1,55 · 1,60 · 1,02) memakai alokasi terbalik |
| Provinsi TFP tertinggi (non-CRS) | DKI +1,24 · Jawa Timur +1,03 · Jawa Barat +1,00 · Kaltim +0,75 |
| Pulau indeks TFP 2024 (non-CRS) | Kalimantan 142,4 · Jawa 130,5 · Sumatera 124,3 · Bali-Nusra 101,0 |
| Simulasi DRS↔CRS | pangsa modal 71,3%→64,0% · selisih sisa 1,03 poin · suku skala 1,97 poin |

Semua angka dapat ditelusuri ke `03 Output/log_01_estimasi.txt`, `log_02_dekomposisi.txt`, dan
`log_04_simulasi.txt`.

---

## Bila laporan perlu diperbarui

Urutan menjalankan ulang, dari `TFP analysis (07182026)/`. Ganti `riil` dengan `adhb` dan
folder tujuannya dengan `03 Output (ADHB)` untuk basis harga berlaku.

```
D="03 Output (modal riil)"
BASIS_MODAL=riil Rscript "02 Code/01_estimasi tfp.R"                    > "$D/log_01_estimasi.txt"    2>&1
BASIS_MODAL=riil Rscript "02 Code/02_dekomposisi nasional.R"            > "$D/log_02_dekomposisi.txt" 2>&1
BASIS_MODAL=riil Rscript "02 Code/04_simulasi drs vs crs.R"             > "$D/log_04_simulasi.txt"    2>&1
BASIS_MODAL=riil Rscript "02 Code/03_visualisasi.R"                     > "$D/log_03_visualisasi.txt" 2>&1
BASIS_MODAL=riil Rscript "02 Code/05_kontribusi pertumbuhan tahunan.R"  > "$D/log_10_kontribusi.txt"  2>&1
BASIS_MODAL=riil Rscript "02 Code/06_panel provinsi-tahun.R"            > "$D/log_13_panel.txt"       2>&1
```

Setelah kedua basis selesai, sekali saja:

```
Rscript "02 Code/07_predicted value tfp.R"   > "03 Output (ADHB)/log_16_predicted.txt" 2>&1
PYTHONIOENCODING=utf-8 python3 "02 Code/md_to_docx.py"
```

Skrip 02, 03, 04, 10, dan 13 membaca `parameter_terpilih.rds` yang ditulis skrip 01, jadi
urutannya mengikat. Skrip 16 membaca keluaran kedua basis, jadi ia paling akhir.

**Blok `acuan` di skrip 03, 10, dan 13 akan menghentikan skrip kalau elastisitasnya bergeser.**
Itu memang gunanya. Kalau pergeserannya disengaja, salin angka baru dari `log_01_estimasi.txt`
dan baris `F. Tanpa CRS` di `log_02_dekomposisi.txt` ke ketiga blok itu, lalu jalankan lagi.

Bila mengubah teks laporan saja, cukup `md_to_docx.py`.

---

## Catatan lain dari Anda
