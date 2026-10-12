# Inventaris berkas — usulan perapian

Disusun 4 Agustus 2026, setelah basis analisis pindah dari PMTB harga berlaku ke `4_ADHK`
harga konstan.

**Selesai dijalankan 4 Agustus 2026.** Delapan butir di bagian 1 sudah pindah ke
`BKPM-local/99 Arsip/`, total 14 berkas, struktur asli utuh. Rinciannya di `99 Arsip/MANIFES.md`.

Aturan yang dipegang: tidak ada berkas yang dihapus. Yang tidak terpakai pindah ke
`99 Arsip/` dengan struktur folder aslinya utuh, dan pemindahannya dicatat di
`99 Arsip/MANIFES.md`.

---

## 1. Usulan pindah ke arsip

| Berkas | Lokasi | Ukuran | Alasan |
|---|---|---|---|
| `__pycache__/` | `02 Code/` | 12 KB | Artefak build Python, dibuat ulang otomatis saat skrip jalan |
| `Kontribusi Pertumbuhan Tahun.textClipping` | `03 Output/` | 340 B | Text clipping macOS, tercipta tidak sengaja saat drag-and-drop |
| `test_write.txt` | `BKPM-local/` | 0 B | Berkas uji tulis, isinya kosong |
| `Rplots.pdf` | `BKPM-local/` | 66 KB | Keluaran device grafis R bawaan, bukan gambar yang dipakai |
| `01_analisis TFP provinsi.R` | `TFP calc/` | — | Digantikan `02 Code/01_estimasi tfp.R`. README baris 6 menyebut angkanya memuat tiga kesalahan |
| `Laporan Analisis TFP Provinsi.md` | `TFP calc/` | — | Naskah hasil skrip lama itu |
| `run_log.txt` | `TFP calc/` | — | Log skrip lama itu |
| `Output/` (7 berkas) | `TFP calc/` | — | Keluaran skrip lama itu: 4 xlsx dan 3 png |

Delapan butir. Empat pertama berkas remeh, empat terakhir satu rangkaian utuh milik
perhitungan lama yang sudah digantikan.

---

## 2. Tetap tinggal

| Berkas | Alasan |
|---|---|
| `03 Output/` seluruhnya | Keluaran versi terbit, sudah lolos pemeriksa. Laporan `.docx` mengacu ke angka ini |
| `03 Output (modal riil)/` seluruhnya | Keluaran basis baru, 13 gambar dan 6 workbook |
| `02 Code/` seluruh `.R` dan `.py` | Semuanya masih dipanggil pipeline |
| `Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx` | Satu-satunya sumber data |
| `All Dataset/99 Arsip/… (sebelum basis riil).xlsx` | Cadangan dataset umum sebelum skrip 14 membedahnya. Jangan ditimpa |
| `Masterplan TFP/` | PDF sumber, dirujuk `00 Docs/analisis-figur.md` |
| `Analisis TFP - Yudistira/` | Tiga do-file Stata, rujukan perbandingan metode |
| `01 Input/figures` (13) dan `txt` | Hasil konversi PDF Masterplan, dipakai analisis figur |
| `05 Presentasi/figures` (9) | Gambar untuk slide |
| `04 Report/` seluruhnya | Naskah, kerangka, log perubahan |

---

## 3. Butuh keputusan Anda

### 3.1 Tabrakan prefiks dua skrip `05_` — SELESAI

Sudah diganti 4 Agustus: `05_kontribusi pertumbuhan tahunan.R` jadi
`05_kontribusi pertumbuhan tahunan.R`. README sudah menyesuaikan.

### 3.2 Folder mana yang jadi kanonik

Sekarang ada dua folder keluaran lengkap. `03 Output/` versi terbit, `03 Output (modal riil)/`
versi baru yang secara teori benar.

Selama laporan `.docx` belum direvisi, keduanya perlu tinggal. Begitu naskah pindah ke basis
riil, `03 Output/` jadi kandidat arsip — tapi itu keputusan setelah revisi naskah, bukan sekarang.

### 3.3 Skenario di Dekomposisi Pertumbuhan Nasional — SELESAI

Keputusan Eqi 4 Agustus: ambil yang paling valid saja. Gambar sekarang satu kolom, skenario F
(two-way FE apa adanya). Skenario A sampai E tetap hidup di sheet `dekomposisi` pada
`Dekomposisi Nasional.xlsx`.

### 3.4 Tren TFP +1,92%/thn belum masuk gambar mana pun

Angkanya hidup di `log_01_estimasi.txt` tapi tidak ada di sheet Excel mana pun, sementara
`lm()` atas koefisien efek tahun memberi +2,09%. Menuliskannya ke gambar berarti mengetik angka
yang tidak bisa dirakit dari berkas, dan itu melanggar aturan reproduktibilitas.

Kalau angka itu perlu tampil, skrip 01 harus menulis satu sheet baru lebih dulu.
