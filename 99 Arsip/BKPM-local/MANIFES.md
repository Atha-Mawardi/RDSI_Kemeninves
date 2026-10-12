# Manifes arsip

Dipindahkan 4 Agustus 2026, atas persetujuan Eqi.

**Tidak ada berkas yang dihapus.** Struktur folder aslinya dipertahankan di bawah `99 Arsip/`,
jadi mengembalikannya cukup menyalin balik ke posisi yang sama relatif terhadap `BKPM-local/`.

## Isi

| Berkas | Posisi asal | Alasan |
|---|---|---|
| `test_write.txt` | `BKPM-local/` | Berkas uji tulis, isinya kosong |
| `Rplots.pdf` | `BKPM-local/` | Keluaran device grafis R bawaan, bukan gambar yang dipakai |
| `TFP calc/01_analisis TFP provinsi.R` | `TFP calc/` | Digantikan `TFP analysis (07182026)/02 Code/01_estimasi tfp.R`. README baris 6 mencatat angkanya memuat tiga kesalahan |
| `TFP calc/Laporan Analisis TFP Provinsi.md` | `TFP calc/` | Naskah hasil skrip lama itu |
| `TFP calc/run_log.txt` | `TFP calc/` | Log skrip lama itu |
| `TFP calc/Output/` (7 berkas) | `TFP calc/` | Keluaran skrip lama itu |
| `TFP calc/TFP analysis (07182026)/02 Code/__pycache__/` | idem | Artefak build Python, dibuat ulang otomatis |
| `TFP calc/TFP analysis (07182026)/03 Output/Kontribusi Pertumbuhan Tahun.textClipping` | idem | Text clipping macOS, tercipta tidak sengaja |

Total 14 berkas.

## Isi — pemindahan kedua, 20 Agustus 2026

Sembilan skrip cabang samping, atas persetujuan Eqi. Posisi asal semuanya
`TFP calc/TFP analysis (07182026)/02 Code/`.

| Berkas | Alasan |
|---|---|
| `05_benchmark elastisitas lintas negara.R` | Tabel `tribble` hardcode; keluarannya sudah jadi dan tidak dipanggil skrip lain |
| `06_benchmark elastisitas sumber berdoi.R` | Versi ketat sumber ber-DOI dari skrip 05 |
| `07_tabel1 koop 2000.R` | Ekstraksi Tabel 1 Koop dkk. (2000), sekali pakai |
| `08_simulasi trajektori.R` | Simulasi 2026–2029 menuju sasaran 8 persen |
| `09_visualisasi trajektori.R` | Satu gambar dari sheet `strategi_stacked` skrip 08 |
| `11_perbandingan tiga basis.R` | Menjajarkan keluaran tiga folder basis, tanpa hitungan baru |
| `12_uji reproduksi basis lama.R` | Utilitas berkas keluaran bermode `salin`/`banding`/`arsip` |
| `14_perbarui tautan dataset umum.py` | Jalur otomatis ke workbook `All Dataset`; sejak 20 Agustus kolomnya ditempel manual |
| `15_uji dataset umum.R` | Uji atas skrip 14; uji 1 sudah gagal sejak `Sheet1` bertambah jadi 171 kolom |

Keluaran ketiga skrip benchmark tetap di `03 Output/`, dan keluaran skrip 08/11 tetap
di folder basisnya masing-masing. Yang pindah hanya kodenya.

Pipeline yang tersisa: 00 → 01 → 02 → 03 → 10 → 13 → 16, plus skrip 04 dan dua skrip
Python konversi.

Total 23 berkas.

## Sebelum memindahkan

Diperiksa lebih dulu: tidak ada skrip aktif yang membaca berkas-berkas ini. Satu-satunya
rujukan ke `TFP calc/Output` datang dari `01_analisis TFP provinsi.R` sendiri, yang ikut
diarsipkan. Rujukan lain di `01_estimasi tfp.R` baris 7 dan `README.md` baris 6 hanya komentar
sejarah, bukan pemanggilan berkas.

## Mengembalikan

```
cd "BKPM-local"
cp -R "99 Arsip/<berkas>" "<posisi asal>"
```
