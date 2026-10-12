# RDSI Kemeninves

ditulis: tim PSE Atha Bintang Wahyu M. | PSE UGM

Kode ditulis tangan, dalam bahasa Indonesia. AI dipakai untuk penyesuaian gaya, perbaikan kesalahan, dan dokumentasi.

## Direktori

| Folder | Isi |
|---|---|
| `01 Data/` | Data kerja, gambar, csv, dan workbook hasil |
| `02 Code/` | Skrip R, do-file Stata, dan notebook |
| `03 Dokumen/` | Naskah, outline, dan pptx yang sedang dikerjakan |
| `04 Litrev/` | Catatan literatur dan bahan kajian |
| `99 Arsip/` | Berkas yang sudah diganti |

`01 Data/00 sumber/` adalah dump sumber (BPS, DJPK, APBD, dan sejenisnya). Folder itu tetap di komputer ini. Berkas yang lebih besar dari 10MB juga tetap di komputer ini.

## Alur kerja

1. BKPM. Realisasi PMA/PMDN terhadap PMTB: korelasi, rasio, dan gambar pergeseran. Skrip di `02 Code/BKPM/`. Hasil di `01 Data/BKPM/output/`.
2. TFP. Diagnostik modal, estimasi, dekomposisi, lalu notebook peringkat dan determinan. Skrip di `02 Code/TFP/`. Hasil di `01 Data/TFP/output/`.
3. IO–IRIO. EDA 2017–2025, updating tabel, lalu prakiraan investasi sampai 2029. Skrip di `02 Code/IO-IRIO-NA/`. Hasil di `01 Data/IO-IRIO-NA/output/`.

Satuan yang dipakai skrip: `PMA_1` dan `PMDN_1` dalam juta rupiah; PMTB `4_ADHB` / `4_ADHK` dan PDRB ADHB sektoral dalam miliar rupiah.

## Menjalankan

Buka `02 Code/BKPM/2026bkpm.Rproj`. Sesi RStudio mengembalikan direktori kerja ke akar repositori ini. Path `01 Data/…` dan `02 Code/…` dihitung dari akar.

Perintah `Rscript` dan `do` juga dijalankan dari akar, misalnya:

```
Rscript "02 Code/BKPM/03_pergeseran rasio bkpm-pmtb.R"
```

Catatan tiap folder ada di `README.md` folder itu.
