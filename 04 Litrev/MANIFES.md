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
