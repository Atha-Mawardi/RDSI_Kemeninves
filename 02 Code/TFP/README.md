# TFP

ditulis: tim PSE Atha Bintang Wahyu M. | PSE UGM

Dua rantai. Jalankan dari root. Residual = produksi berbasis PMTB, bukan TFP Hicks-neutral.
Vintage: `docs/VINTAGE.md`.

## Estimasi (`estimasi/`)

--> `00` diagnostik modal
--> `01` estimasi
--> `02` dekomposisi nasional
--> `03` visualisasi
--> `04` simulasi DRS vs CRS
--> `05` kontribusi pertumbuhan tahunan
--> `06` panel provinsi-tahun
--> `07` predicted value

Masukan: `01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx`.
Palet: `02 Code/BKPM/palet-bkpm.R`.

## Notebook

--> `01` produksi agregat
--> `02` peringkat
--> `03` determinan dan tiga provinsi
--> `04`–`07` EDA
--> `08`–`09` eval
--> `10` determinan spasial
--> `11` tampilan gambar yang sudah ada
--> `12` tabel revisi

Mesin SAR/SDM ada di dalam `06_eda_spasial2.ipynb`.

## Panel (`panel_provinsi/`)

--> `01` unduh → `02` kerangka → `03` imputasi → `04` pca → `05` audit R → `06` sheet 1 → `07` luaran 2 → `08` sel agregasi
--> `pengaturan.py` dan `tulis_bantuan.py` dipakai bersama, bukan langkah
