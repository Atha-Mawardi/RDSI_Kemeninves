# Log Perubahan — Report TFP (0721)

Ringkasan revisi yang mengubah basis analisis dari **CRS (skala hasil konstan)** menjadi
**non-CRS / DRS (unrestricted two-way fixed effects)** sebagai hasil utama. Estimator tidak
berubah (tetap TWFE provinsi + tahun, Driscoll-Kraay SE); yang berubah adalah **restriksi
skala hasil** yang dipakai sebagai dasar semua angka turunan dan ekspor.

## Alasan (why)
Tim memilih hasil non-restriksi (DRS) sebagai utama. Uji Wald memang menolak CRS di semua
spesifikasi (jumlah elastisitas 0,591), sehingga melaporkan hasil unrestricted lebih jujur
daripada memaksakan CRS — pemaksaan CRS membocorkan suku skala `(1−b1−b2)·pertumbuhan input`
ke dalam residual dan menyebutnya TFP. Landasan literatur di `00 Docs/litrev-twfe-drs-tfp.md`.

## Keputusan yang dikunci bersama pengguna
1. **CRS → diagnostik + kontrafaktual saja.** Non-CRS/DRS jadi satu-satunya dasar analisis
   per-wilayah / per-tahun / per-pulau dan seluruh ekspor xlsx.
2. **Tabel jarak sasaran 8-4-2-2** dihitung ulang dengan elastisitas non-CRS (b1=0,400),
   bukan α=1/3.
3. **Tambahan baru:** modul simulasi DRS-vs-CRS (comparative-statics deterministik).
4. **Peringkat TFP provinsi** yang berbalik di bawah non-CRS **diterima apa adanya** dengan
   caveat mekanisme (b2 rendah), tidak diberi tandingan CRS.

## Perubahan angka utama (sebelum → sesudah)
| Besaran | CRS (lama, kini sekunder) | Non-CRS/DRS (baru, utama) |
|---|---|---|
| Elastisitas modal b1 / tenaga kerja b2 | 0,446 / 0,554 (jumlah 1, dipaksakan) | 0,400 / 0,191 (jumlah 0,591) |
| Residual TFP nasional | −0,05 poin | **+0,98 poin (25,7%)** |
| Tren TFP nasional | −0,27%/thn | **+0,81%/thn (p=0,002)** |
| Indeks TFP nasional 2024 (2017=100) | ~98,6 | **106,8** |
| Kontribusi modal | 71% | **64%** |
| Jarak sasaran — realisasi TFP / jarak | 0,40 (α=1/3) | **0,98 / 1,02** (non-CRS) |
| Peringkat provinsi teratas | DKI, Kaltim, Papua Barat (enclave/ekstraktif) | **DKI, Jatim, Jabar, Kaltim** (provinsi besar) |
| Provinsi bertren signifikan | 14/34 | **23/34** |
| Indeks pulau 2024 (contoh Kalimantan) | 105,4 | **142,4** |

## Perubahan per bagian (`Report TFP.md`)
- **§1.3 / Tabel 2** — jarak sasaran memakai realisasi non-CRS.
- **§2.1** — integrasi litrev: TWFE tidak mengupas keunikan regional karena TFP dipulihkan
  sebagai residual yang masih memuat u_i.
- **§2.2** — deskripsi ekstraksi elastisitas primer dari model unrestricted.
- **§3.2** — reframing skala hasil: non-CRS primer, CRS diagnostik. Ditambah **caveat
  atenuasi**: sebagian penolakan CRS bisa artefak proksi PMTB (flow, bukan stok PIM), bukan
  DRS struktural (Griliches-Mairesse 1998; Basu-Fernald 1997). Residual non-CRS dinyatakan
  sebagai batas atas; kontribusi TFP sejati ditaruh antara ~0 dan 0,98, condong rendah.
- **§3.3 / Tabel 5, 6, 7 / Gambar 4–7** — indeks tahunan, peringkat provinsi, dekomposisi
  pulau semua di basis non-CRS. Mekanisme peringkat provinsi (b2 rendah menyerap skala TK)
  dijelaskan jujur + Batasan 8. Envelope lama dilabel ulang "kontrafaktual".
- **§3.4 (BARU) / Gambar 8** — simulasi DRS-vs-CRS: rekonsiliasi kontribusi, sweep RTS
  0,591→1,0, kontrafaktual maju. Sumber: `03 Output/Simulasi DRS vs CRS.xlsx`.
- **Batasan 7–8** — ditambah/diperbarui (proksi flow, sensitivitas peringkat).
- **Daftar sumber** — +8 sitasi terverifikasi (Solow 1957, Hulten 2001, Barro 1999,
  Basu-Fernald 1997, Griliches-Mairesse 1998, Combes-Duranton-Gobillon 2008,
  Driscoll-Kraay 1998, Purwono dkk. 2020).

## Berkas yang berubah / dibuat
- Kode: `02 Code/01_estimasi tfp.R`, `02_dekomposisi nasional.R`, `03_visualisasi.R`
  (direvisi), **`04_simulasi drs vs crs.R` (baru)**.
- Output diregenerasi (`03 Output/`): `Hasil Estimasi TFP.xlsx`, `Dekomposisi Nasional.xlsx`,
  **`Simulasi DRS vs CRS.xlsx` + `.png` (baru)**, 7 PNG lama, `parameter_terpilih.rds`
  (kini memuat parameter primer `b1_un/b2_un` + sekunder `b1_crs`), log 01–04.
- Dokumen: `Report TFP.md`, `Report TFP_0721.docx` (baru, penamaan konsisten),
  `00 Docs/litrev-twfe-drs-tfp.md` (baru), `00 Docs/spesifikasi-model-tfp.md`,
  `00 Docs/memory_tfp.md`, `kerangka.md`, `Lampiran E - Perbandingan Desain.md`,
  `STATUS.md`, `README.md`.

## Catatan berkas Word
- `Report TFP_0721.docx` = versi non-CRS terbaru (penamaan konsisten `[descriptor]_[MMDD]`).
- `Report TFP.docx` = versi lama 19 Juli (CRS-primer), belum ketimpa karena masih terkunci
  Word. Untuk menimpanya: tutup Word lalu jalankan
  `PYTHONIOENCODING=utf-8 python "02 Code/md_to_docx.py"`.

## Status verifikasi — LULUS
- Agent kode & agent report saling-cek angka ke xlsx: **0 selisih**; identitas dekomposisi
  4,44e-16.
- QA independen (telusur angka-per-angka, dari nol): **LULUS**. Setiap angka headline —
  dua elastisitas primer + jumlah, semua skenario dekomposisi, residual +0,98/25,7%, kedua
  tren (+0,81 lm / +0,63 DK) dengan p-value, share modal 64%/71%, 34 deviasi provinsi, 6
  dekomposisi & indeks pulau, seluruh tabel jarak sasaran, semua angka simulasi (gap 1,03;
  suku skala 1,97; req-TFP 4,12/5,16 dan 1,50/2,81; gap pulau 0,92–2,03) — telusur ke sel
  xlsx/log pada presisi penuh. Cek struktural "CRS hanya diagnostik/kontrafaktual": **LULUS**.
  Caveat atenuasi di §3.2: **ADA**.
- **Perbaikan pasca-QA:** empat z-statistik Pesaran CD di §3.1 (nominal RE 33,56; riil RE
  0,99; nominal FE 12,90; riil FE 3,24) tadinya tidak terekam di log (script hanya cetak
  p-value). `01_estimasi tfp.R` ditambah cetakan `CD z-stat`; setelah rerun, keempat nilai
  **cocok persis** dengan yang tertulis di laporan — kini reproducible dari `log_01_estimasi.txt`.
  Pipeline 01→02→04→03 dijalankan ulang penuh (data deterministik, tidak berubah).

---

## Tambahan 2026-07-21 (sore) — kelengkapan keterbacaan (docx + PPT)

Atas permintaan pengguna, tiga penambahan; estimator, elastisitas, dan seluruh angka inti
**tidak berubah**.

1. **Gambar baru "Kontribusi Kumulatif Faktor" (Gambar 5, §3.3).** Tiga indeks sebanding
   2017=100: kontribusi kumulatif modal `100·exp(Σ b1·gK)` dan tenaga kerja `100·exp(Σ b2·gL)`
   dari agregat nasional, plus indeks TFP dari efek tahun. 2024: modal 118,7 · TFP 106,8 · TK
   102,8. **Bukan** dekomposisi bertumpuk (tiga garis tidak menjumlah ke output; garis output
   sengaja tak ditampilkan) dan garis TFP pakai efek tahun — jadi **tidak** melanggar aturan
   "jangan dekomposisi tahunan" (Batasan 6). Skrip: blok baru di `03_visualisasi.R` (kini 8 PNG).
   Figur 5–8 lama digeser ke 6–9.
2. **Subbab konseptual baru §1.2 (Skala hasil: CRS/DRS/IRS) dan §1.3 (modal/TK/TFP: kenapa
   investasi sama berbuah beda).** §1.2/1.3 lama → 1.4/1.5. Studi kasus: keajaiban Asia Timur
   (Young 1995; Krugman 1994) untuk DRS akumulasi; aglomerasi untuk IRS (definisional — kajian
   menaksir DRS 0,591, tidak menemukan IRS). Mekanisme "investasi sama berbuah beda" dijelaskan
   lewat produk marjinal modal menurun (b1<1), dipisahkan dari skala hasil; embodied tech
   diletakkan di kontribusi modal (bukan TFP); contoh Kalimantan (−0,11) vs Jawa (+1,24) dibaca
   sebagai tafsir residual, bukan beda teknologi.
3. **PPT (`Slides TFP_0721.tex`):** 3 frame baru (skala hasil; kenapa investasi berbuah beda;
   grafik kontribusi kumulatif). Perbaikan kosmetik: Pesaran CD two-way FE z=3,24 → **4,24**
   (3,24 adalah statistik one-way; report sudah benar). Kompilasi bersih, 21 halaman.

### Perbaikan sitasi (temuan audit)
- **Purwono dkk. (2020) dicabut** dari §2.1 dan Daftar sumber: metadatanya keliru (judul/DOI
  milik Kataoka; paper Purwono asli soal konvergensi inflasi). Kalimat §2.1 kini Kataoka saja,
  konsisten Batasan 9. Diperbaiki pula di `litrev-twfe-drs-tfp.md` #8 dan `catatan-literatur.md`.
- **Krugman (1994)** *Foreign Affairs* 73(6), 62–78 dan **Young (1995)** *QJE* 110(3), 641–680
  ditambahkan (terverifikasi independen). Halaman **Kataoka** dilengkapi (13(3), 233–243).
  Combes "hampir 100%" dilunakkan jadi "substansial" (besaran tak terverifikasi dari PDF).

### Verifikasi
Empat subagent read-only: audit angka (report+slides vs log — **konsisten penuh**), audit sitasi
(Krugman/Young terverifikasi; Purwono cacat → dicabut), audit konsistensi & konsep (empat koreksi
konseptual diterapkan), dan pemeriksa akhir atas teks baru. Grafik di-eyetest via Read; docx dibangun
ulang (`md_to_docx.py`, 9 gambar) dan snapshot `Report TFP_0721.docx` disinkronkan.

### Penyuntingan slide 2026-07-21 (malam) — atas permintaan pengguna
- **Judul deck** diganti dari "TFP Indonesia: Kenapa Kami Lepas Asumsi CRS" menjadi **"Analisis TFP"**
  (subtitle metodologis non-CRS/DRS tetap). Baris author "Kajian TFP --- BKPM" dihapus dari halaman judul.
- **Slide penutup "Yang perlu diingat BKPM"** diubah jadi **"Ringkasan analisis"**: fakta analitis
  dipertahankan (modal 64%, TFP ~0,8%/th, angka provinsi/pulau rapuh), resep kebijakan yang ditujukan
  ke BKPM ("kebijakan investasi tetap inti", "target 8% berat tanpa lompatan TFP") dibuang — sesuai
  arahan "fokus ke analisis saja".
- Deck dikompilasi ulang bersih (21 halaman); halaman judul & ringkasan sudah di-eyetest. Hanya
  `Slides TFP_0721.tex/.pdf` yang berubah; report .md/.docx tidak tersentuh.
