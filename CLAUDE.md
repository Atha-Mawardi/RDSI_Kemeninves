## Current Scope
**Active:** Data cleaning, exploratory analysis, visualization
**Inactive (planned):** econometric modeling beyond TFP/IO that already exists

## Layout
```
01 Data/          raw + processed + figures (bukan kode)
  00 sumber/      dump sumber BPS/DJPK/APBD/… (jangan diubah skrip analisis)
  BKPM/           processed/ + output/
  TFP/            raw/ processed/ output/{modal_riil,adhb,nominal,exploratory}
  IO-IRIO-NA/     processed/ + output/{gambar EDA, plots, updating_2024}
02 Code/          hanya skrip, per area
  BKPM/  TFP/  IO-IRIO-NA/
04 Litrev/
99 Arsip/         skrip/hasil yang sudah diganti
```

Jalankan skrip **dari root** (`2026bkpm.Rproj`). Path relatif ke `01 Data/…` dan `02 Code/…`.

## Data yang dipakai analisis
| Area | File kerja | Keterangan |
|------|------------|------------|
| BKPM | `01 Data/BKPM/processed/Dataset Provinsi.xlsx` | PDRB ADHB, PMA, PMDN, PMTB |
| TFP | `01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` | panel estimasi TFP |
| IO updating | `01 Data/IO-IRIO-NA/processed/updating_masukan/` | IO 2016/2020, IRIO 2016, concordance, PDRB 52 |

Key variables: `*_ADHB`, `PMA_1`, `PMDN_1`, `4_ADHB` (PMTB). Unit: nasional / pulau / provinsi. Tahun: 2017–2025 (CAGR 2022–2025).

## Code
Lihat README di tiap folder area. Ringkas:

| Folder | Isi |
|--------|-----|
| `02 Code/BKPM/` | viz laporan pendahuluan, korelasi PMTB–PMA/PMDN, agregasi upah |
| `02 Code/TFP/estimasi/` | diagnostik modal → estimasi → dekomposisi → viz → predicted value |
| `02 Code/TFP/panel_provinsi/` | bangun panel + isi workbook agregasi |
| `02 Code/IO-IRIO-NA/` | EDA 2017–2025 (`01`–`03`), updating (`updating/`), tampilan plot 2025 (`tampilan/`) |

**Execution:** prefix numerik di dalam foldernya. Jangan memodifikasi `01 Data/00 sumber/`.

## Conventions
- Bahasa: R (tidyverse) + Python untuk panel/IO notebook
- Path dari root via `.Rproj`
- Palet: `02 Code/BKPM/palet-bkpm.R`
- Hasil angka/gambar: `01 Data/<area>/output/`

## Catatan TFP output
Folder `01 Data/TFP/output/modal_riil` dan `adhb` diisi ulang dari snapshot 0820 (sebelum 2025 masuk estimasi). `Predicted Value TFP 2017-2025.xlsx` yang memuat 2025 tetap di `01 Data/TFP/processed/`. Versi terbit `nominal` kosong sampai skrip 01 dijalankan dengan `BASIS_MODAL=nominal`.

Vintage: jangan campur angka `Report TFP.md` (b1=0,400 / residual 0,81%) dengan folder `modal_riil` (b1=0,402 / 1,92%). Residual = produksi berbasis PMTB, bukan TFP Hicks-neutral. 8-4-2-2 resmi: **4 tenaga kerja + 2 modal + 2 TFP**. Workbook determinan lama di `01 Data/TFP/processed/99 vintage_determinan/` (seri TFP beda, 306 obs). Detail: `02 Code/TFP/docs/VINTAGE.md`.

## Pending (isi, bukan folder)
Subbab 6.3 poin 1–2 selesai. Metode: `02 Code/BKPM/02_analisis korelasi pmtb pma-pmdn.R`.
Nasional log semua-tahun: spline_df3, within-R²=0,301 (linear 0,132). Rasio BKPM/PMTB 15,8%→26,8% tanpa kenaikan keeratan.
`PMA_1` & `PMDN_1` keduanya juta IDR → `/1e3` = miliar, seunit dengan PMTB.

Subbab 6.1: CRS/DRS tetap di Luaran 1. Gambar: `02 Code/TFP/02_viz_peringkat.ipynb`.
