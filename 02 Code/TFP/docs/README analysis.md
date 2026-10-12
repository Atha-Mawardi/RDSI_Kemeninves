# TFP analysis (07182026)

Perhitungan dan report Total Factor Productivity provinsi Indonesia untuk BAB 7 laporan
`Laporan/Analisis I Kebijakan Makro Investasi.docx`.

Dibuat 2026-07-18. Menggantikan perhitungan awal di `../01_analisis TFP provinsi.R`, yang
angkanya terbukti mengandung tiga kesalahan (lihat `00 Docs/memory_tfp.md` §5).

---

## Baca ini dulu kalau Anda AI atau orang baru

**`STATUS.md`** memuat status keluaran, tujuh butir yang masih terbuka, angka kunci, dan cara
menjalankan ulang. Mulai dari sana kalau tujuannya melanjutkan pekerjaan.

Urutan membaca yang paling cepat memberi konteks substansi:

1. `00 Docs/memory_tfp.md` — posisi TFP dalam kebijakan Indonesia, temuan Masterplan, empat
   jebakan metodologis, dan daftar angka kunci. **Mulai dari sini.**
2. `00 Docs/spesifikasi-model-tfp.md` — desain perhitungan dan alasan tiap pilihan model.
3. `00 Docs/catatan-literatur.md` — 24 sitasi terverifikasi + klaim mana yang boleh/tidak boleh
   ditulis. Bagian §5 mendaftar hal-hal yang **jangan** dikutip.
4. `00 Docs/analisis-figur.md` — pembacaan atas grafik dan tabel dokumen Masterplan.
5. `04 Report/Report TFP.md` — reportnya sendiri.

---

## Struktur folder

```
00 Docs/     catatan metodologi, literatur, memori, analisis figur
01 Input/    txt/      hasil konversi 13 dokumen Masterplan TFP (272 halaman)
             figures/  gambar tertanam + render halaman penuh
             manifest_konversi.csv
02 Code/     skrip Python dan R, dijalankan berurutan sesuai nomor
03 Output/   tabel hasil (.xlsx), grafik (.png), log eksekusi
04 Report/   kerangka.md -> Report TFP.md -> Report TFP.docx
```

## Urutan eksekusi

| # | Skrip | Keluaran |
|---|---|---|
| 1 | `02 Code/convert_pdf_to_txt.py` | `01 Input/txt/*.txt`, `01 Input/figures/`, manifest |
| 2 | `02 Code/00_diagnostik modal.R` | bukti basis harga kolom `pmtb`, banding elastisitas nominal vs riil |
| 3 | `02 Code/01_estimasi tfp.R` | tabel elastisitas, kaskade seleksi model, TFP provinsi |
| 4 | `02 Code/02_dekomposisi nasional.R` | dekomposisi pertumbuhan nasional per periode |
| 5 | `02 Code/04_simulasi drs vs crs.R` | simulasi DRS-vs-CRS (rekonsiliasi, sapuan skala, kontrafaktual) |
| 6 | `02 Code/03_visualisasi.R` | delapan grafik `.png` |
| 7 | `02 Code/05_kontribusi pertumbuhan tahunan.R` | grafik kontribusi per tahun |
| 8 | `02 Code/06_panel provinsi-tahun.R` | `03 Output (…)/Panel TFP Provinsi-Tahun.xlsx`, 272 baris |
| 9 | `02 Code/07_predicted value tfp.R` | `Predicted Value TFP 2017-2025.xlsx`, dua basis, dua lokasi |
| 10 | `02 Code/md_to_docx.py` | `04 Report/Report TFP.docx` |

Skrip Python dijalankan dengan `PYTHONIOENCODING=utf-8` — stdout Windows default cp1252 dan
akan gagal pada karakter seperti panah atau em-dash. Skrip R dijalankan dari folder ini.

## Sembilan skrip yang pindah ke arsip, 20 Agustus 2026

Atas persetujuan Eqi: 05, 06, 07 (benchmark lintas negara dan Tabel 1 Koop dkk), 08 dan 09
(simulasi trajektori 2026-2029), 11 (perbandingan tiga basis), 12 (operasi berkas keluaran),
14 dan 15 (jalur otomatis ke dataset umum). Kodenya di
`99 Arsip/TFP calc/TFP analysis (07182026)/02 Code/`, alasannya di `99 Arsip/MANIFES.md`.

Keluarannya **tidak dihapus dan tidak diperbarui**, jadi angkanya masih dari sebelum 2025
masuk. Yang basi: `Simulasi Trajektori 2026-2029.xlsx`, `Strategi RTS dan TFP 2026-2029.png`,
`Perbandingan Tiga Basis.xlsx`, dan log 08, 09, 11, 14, 15.

Skrip 14 dan 15 menyentuh workbook `All Dataset`. Sejak 20 Agustus kolom TFP di sana ditempel
Eqi sendiri, jadi tidak ada lagi skrip yang menulis ke workbook itu. Tautan luar Excel di
`Sheet1` tetap hidup dan tetap menunjuk `Panel TFP Provinsi-Tahun.xlsx`, yang sengaja
dipertahankan 272 baris supaya rentang formulanya tidak bergeser.

## Tahun 2025 masuk estimasi, 20 Agustus 2026

Workbook sumber kini terisi tenaga kerja 2025, jadi panel estimasi naik dari 272 ke **306
observasi** (34 provinsi × 2017-2025). Elastisitasnya bergeser:

| | Sebelum (2017-2024) | Sesudah (2017-2025) |
|---|---|---|
| riil: b1 / b2 | 0,401899 / 0,147184 | **0,475304 / 0,135782** |
| riil: kontribusi modal · TK · sisa | 1,31 · 0,31 · 2,21 | **1,55 · 0,28 · 2,00** |
| adhb: b1 / b2 | 0,458421 / 0,015230 | **0,506210 / 0,041713** |
| adhb: kontribusi modal · TK · sisa | 2,84 · 0,03 · 3,87 | **3,13 · 0,09 · 3,52** |

**Tenaga kerja 2025 bukan pengukuran.** Sheet `Keterangan` workbook sumber baris 181 menyatakan
`*_TenagaKerja` 2025 disalin dari 2024 (LOCF) dan `*_RataUpah` 2025 = 2024 × (UMP₂₀₂₅/UMP₂₀₂₄).
Akibatnya `g_L` 2025 **persis nol** di ke-34 provinsi, dan seluruh pertumbuhan output 2025 jatuh
ke residual. Ke-34 observasi bertipe "modal naik, tenaga kerja diam" itulah yang menarik b1 naik.

Karena itu, garis pemisahnya:

| Yang memuat 2025 | Yang tetap berhenti di 2024 |
|---|---|
| estimasi elastisitas (skrip 01) | dekomposisi nasional (skrip 02, periode 2018-2024) |
| `Predicted Value TFP 2017-2025.xlsx` (skrip 16) | delapan gambar (skrip 03) dan gambar tahunan (skrip 10) |
| | `Panel TFP Provinsi-Tahun.xlsx` (skrip 13) |

Dua pembacaan yang ikut berubah dan sudah tertulis ulang di kodenya:

1. **Tangga atenuasi basis riil berbalik bentuk.** Dulu tiga spesifikasi pertama bertahan di
   sekitar 1; sekarang ia naik monoton sampai 1,259 di fixed effects, lalu jatuh ke 0,611 —
   sebangun dengan basis adhb. Assertion di skrip 03 kini bercabang atas bentuk tangganya,
   bukan atas basis harganya.
2. **Tanda komponen 2020 kini bercampur.** b1 yang lebih besar membuat kontribusi modal 2020
   melorot ke −2,17, sehingga sisanya berbalik positif (+0,23). Penanda `g_Y` tidak lagi
   berimpit dengan ujung kolom di tahun itu, dan caption skrip 10 menyebutkannya sendiri.

## Basis harga

Skrip 01, 02, 03, 04, dan 10 memakai sakelar `BASIS_MODAL` dengan tiga nilai. Skrip 00 dan 16
berdiri di luar sakelar — skrip 16 membaca kedua basis sekaligus. Perbandingan lengkap ketiganya
di `00 Docs/perbandingan-tiga-basis.md`, dengan catatan angkanya dari sebelum 2025 masuk.

| Nilai | Variabel terikat | Variabel modal | Folder keluaran |
|---|---|---|---|
| `riil` (bawaan) | `9_ADHK` harga konstan | `4_ADHK` harga konstan | `03 Output (modal riil)/` |
| `nominal` | `9_ADHK` harga konstan | `pmtb` harga berlaku | `03 Output/` — versi terbit, jangan ditimpa |
| `adhb` | `9_ADHB` harga berlaku | `4_ADHB` harga berlaku | `03 Output (ADHB)/` — diagnostik |

Kolom `pmtb` yang dipakai versi terbit ternyata harga berlaku, sementara variabel terikat
`9_ADHK` harga konstan. Buktinya di `02 Code/00_diagnostik modal.R`. Basis riil menggeser
kontribusi TFP dari 26 persen ke 58 persen pertumbuhan. Laporan `.docx` masih memakai angka
versi nominal dan belum direvisi.

**Residual basis `adhb` bukan TFP.** Ia memuat inflasi harga output, jadi seluruh gambar dan
tabel basis itu melabelinya "sisa nominal". Basis itu melanggar langkah S0 kaskade seleksi
dengan sengaja, dan verdict di log menyatakannya. Gunanya mengukur berapa besar deflator
menggerakkan angka versi terbit.

Ganti basis tanpa menyunting berkas:

```
BASIS_MODAL=nominal Rscript "02 Code/01_estimasi tfp.R"
BASIS_MODAL=adhb    Rscript "02 Code/01_estimasi tfp.R"
```

Tahun dasar harga konstan dataset adalah **2010**, terkonfirmasi dari metadata workbook, seri
terbitan BPS, dan kecocokan laju pertumbuhan agregat dengan PDB nasional (selisih ≤ 0,04 poin
persen, 2019-2024). Rinciannya di `00 Docs/perbandingan-tiga-basis.md` bagian 7.

Sebelum menyunting skrip mana pun, ambil salinan folder keluarannya. Skrip 12 yang dulu
mengurus ini sudah masuk arsip pada 20 Agustus 2026, jadi salinannya diambil biasa. Keadaan
sebelum 2025 masuk tersimpan di `99 Snapshot 0820 (sebelum 2025)/`, dua folder keluaran utuh.

Data sumber tetap di `../Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` (tidak
disalin agar tidak ada dua versi yang bisa menyimpang). Dokumen PDF sumber di `../Masterplan TFP/`.

## Sambungan ke dataset umum project

`All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` di tingkat project
mengambil angka TFP dari sub-project ini lewat **tautan luar Excel**, bukan lewat tempel
manual. Sejak 11 Agustus 2026 tautan itu menunjuk basis **modal riil**.

| Kolom Sheet1 | Sumber | Tautan |
|---|---|---|
| `FD:FH` — `log_ADHK_Tot`, `log_pmtb`, `log_lab_tot`, `logtfp_it`, `logtfp_it_crs` | `03 Output (modal riil)/Hasil Estimasi TFP.xlsx` sheet `data_tfp` | [1] |
| `FI:FN` — `g_Y`, `g_K`, `g_L`, `kontrib_modal`, `kontrib_tk`, `kontrib_tfp` | `03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx` sheet `panel` | [2] |

Formulanya `INDEX/MATCH` yang dipasangkan lewat `Year & Pre_Prov`, bukan lewat nomor baris.
Jalur ini **masih hidup dan tidak disentuh siapa pun**. Skrip 13 tetap menghasilkan panel
272 baris, jadi rentang `[2]panel!G$2:G$273` tetap sah. Excel menghitung ulang sendiri saat
workbook dibuka, sebab `fullCalcOnLoad` menyala.

```
Rscript "02 Code/06_panel provinsi-tahun.R"
```

**Sejak 20 Agustus 2026 tidak ada skrip yang menulis ke workbook itu.** Skrip 14 dan 15 sudah
masuk arsip. Kolom `CD:CL` di sheet `Analisis Luaran 2` — sembilan kolom bernilai statis, bukan
tertaut — ditempel Eqi sendiri dari sheet `tempel_CD_CL_adhb` pada
`All Dataset/Predicted Value TFP 2017-2025.xlsx`, yang urutan barisnya dikunci ke sheet tujuan.

Tiga hal yang perlu diingat sebelum menyentuh berkas itu lagi:

1. **Sel kosong di sana bertipe teks, bukan blank.** Warisan penjaga
   `IFERROR(IF(…="","",…),"")`. `readxl` dan `pandas` bisa menebak seluruh kolomnya sebagai
   character kalau tidak dipaksa numerik.
2. **Baris 2017 kosong di kolom laju.** Tahun basis tidak punya laju.
3. **`Sheet1` kini 171 kolom, bukan 170.** Kolom `FO = PDBDeflator` ditambahkan manual sesudah
   skrip 14 terakhir jalan.

---

## Ringkas: apa yang dihitung

Model Solow/Cobb-Douglas dalam log, panel 34 provinsi 2017–2025 (306 observasi; sampai
19 Agustus 2026 hanya 272, karena tenaga kerja 2025 belum ada):

```
log Y[i,t] = a + b1 log K[i,t] + b2 log L[i,t] + u[i] + e[i,t]
```

Y = PDRB harga konstan (ADHK), K = PMTB, L = jumlah 17 kolom tenaga kerja sektoral.
Elastisitas **diestimasi**, tidak diimpor dari literatur. TFP adalah residual Solow.

Model terpilih ditentukan lewat kaskade aturan deterministik S0–S6 yang ditulis sebelum
hasilnya dilihat (lihat `00 Docs/spesifikasi-model-tfp.md`).

## Tiga hal yang harus diingat sebelum mengutip angka mana pun

1. **Modal diproksi PMTB, yaitu arus investasi, bukan stok kapital.** Elastisitas modal karena
   itu bias ke bawah, dan residual TFP menyerap sebagian kontribusi modal yang tidak tertangkap.
   Ini juga alasan kaveat pada basis non-CRS: penolakan CRS sebagian bisa atenuasi proksi arus,
   sehingga sisa TFP basis utama cenderung dilebih-lebihkan.
2. **Dekomposisi hanya disajikan sebagai rata-rata periode, tidak pernah tahun-per-tahun.**
   Tabel 5 Masterplan memperlihatkan apa yang terjadi kalau aturan ini dilanggar: TFP tahunan
   berayun dari −36,65 ke +77,37 sebagai cerminan mekanis pergerakan investasi.
3. **Peringkat antar provinsi kuat; deret waktu TFP lemah.** ρ = 0,9964 berarti 99,6% varian
   bersifat antar-provinsi. Tidak ada CAGR TFP dalam report ini, dan itu disengaja.
4. **Basis utama non-CRS/DRS, CRS diagnostik (revisi 2026-07-21).** Elastisitas terestimasi tanpa
   restriksi (b1=0,400, b2=0,191) jadi basis; varian CRS jadi diagnostik + kontrafaktual (§3.4).
   Lihat `00 Docs/litrev-twfe-drs-tfp.md`.
