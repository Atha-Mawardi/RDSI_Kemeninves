# Vintage freeze — TFP (2026-09-05)

Tiga seri beredar. Jangan dicampur.

| ID | Apa | Ciri | Jangan dipakai untuk |
|---|---|---|---|
| **A** | `Report TFP.md` (mtime 2026-09-05 02:58) | b1=0,400; b2=0,191; RTS=0,591; tren residual 0,81%/thn; pangsa modal 64%; sisa 0,98 poin | kutipan bersama keluaran folder `modal_riil` |
| **B** | `01 Data/TFP/output/modal_riil/` (mtime 2026-09-05 11:13; restore snapshot 0820) | 272 obs, 2017–2024; b1=0,402; b2=0,147; RTS=0,549; tren residual 1,92%/thn; pangsa modal 34,2%; sisa 2,21 poin | dicampur dengan angka badan laporan A |
| **C** | `01 Data/TFP/processed/99 vintage_determinan/` (mtime 02:52) | 306 obs sampai 2025; seri TFP beda | regresi determinan atas residual B |

`STATUS.md` 20 Agustus mencatat run 2017–2025 dengan tenaga kerja 2025 = LOCF 2024 (b1 riil 0,475). Itu **bukan** folder B setelah restore. Predicted value 2017–2025 ada di `01 Data/TFP/processed/`, terpisah.

Residual di B adalah **residual produksi berbasis arus PMTB**, bukan TFP Hicks-neutral. Amplop lintas spesifikasi: residual ~0,76–2,21 pp; modal ~0,94–2,74 pp.

Layar transmisi di `docs/06 Review/` adalah diagnostik, bukan hasil kausal. PMA/PMDN tidak pernah dibagi TFP.

## Hash SHA-256 (freeze, sebelum koreksi jarak 8-4-2-2)

| File | SHA-256 | mtime |
|---|---|---|
| `01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` | `1435fe4a8a227b3d3db3d1bab93fec029647c7a491b5c845e6e05f4297d934cb` | 2026-09-05 02:57 |
| `01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx` | `eae8a7ebab595b47010d4c499f5160d96970f70de0af9fef16e00e488d8db879` | 2026-09-05 11:13 |
| `01 Data/TFP/output/modal_riil/Dekomposisi Nasional.xlsx` | `88d610dd107ba2a6ff5039045313b8b51a69a8b68f23b5ea1707c138469fd5a5` | 2026-09-05 11:13 |
| `01 Data/TFP/output/modal_riil/parameter_terpilih.rds` | `0c80d7661f7cf57e276213728e8476dfcebe8b9d9ee1fad1c13eb8e9329b6985` | 2026-09-05 11:13 |
| `02 Code/TFP/docs/04 Report/Report TFP.md` | `2bc238513aef7b3f4775d36109f5bac407a9014543082bdadfda37b969b672a5` | 2026-09-05 02:58 |
| `99 vintage_determinan/Determinan TFP Results.xlsx` | `284debcb814a242c7b67806f46a9873e589d3df67d3c777b1829a6fc40515352` | 2026-09-05 02:52 |
| `99 vintage_determinan/Determinan TFP Tables - all models.csv` | `b9b76a926c96036f6c66378858b69963e3116de260125b1a61dab5ed030a364d` | 2026-09-05 02:52 |

Skrip 02/04/03/10 setelah tanggal ini mengubah **alokasi sasaran 8-4-2-2**, **label residual**, sheet `jarak_sasaran` / kontrafaktual, dan PNG yang memakai label itu. Elastisitas vintage B (`parameter_terpilih.rds`) tidak diestimasi ulang. Mengulang skrip 02 pada data yang sama menghasilkan gK arus 3,23%/thn (file freeze 11:13 menulis 3,26); selisih kecil di agregasi, bukan estimasi baru.
