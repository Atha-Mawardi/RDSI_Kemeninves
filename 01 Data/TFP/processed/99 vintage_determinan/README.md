# Vintage determinan

Seri di folder ini terpisah dari TFP terkini di `01 Data/TFP/output/modal_riil/`.

Berkas di folder ini adalah hasil model determinan dari seri TFP **yang lain**.
Generator skripnya tidak ada di repo; hanya workbook dan tabel yang tersimpan.

| | Workbook determinan | Estimasi TFP terkini (`output/modal_riil`) |
|---|---|---|
| Observasi | 306 (34 provinsi × 2017–2025) | 272 (34 × 2017–2024) |
| Seri TFP | tidak cocok dengan `logtfp_it` maupun CRS | two-way FE, PMTB riil |
| Contoh | TFP Aceh 2017 ≠ kedua seri terkini | |

Jangan merge, jangan regresi ulang di atas seri ini, jangan kutip sebagai determinan residual PMTB yang sekarang. Lihat `02 Code/TFP/docs/VINTAGE.md`.
