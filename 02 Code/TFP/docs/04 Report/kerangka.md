# Kerangka + Poin Temuan — Report TFP (revisi pasca-GATE)

Revisi 2026-07-18 setelah review logika ekonomi. Tujuh *blocker* sudah ditutup dan angkanya
dihitung ulang. Riwayat perubahan ada di bagian akhir.

**Revisi 2026-07-21 — basis dibalik ke non-CRS/DRS.** Framing "dua pembacaan setara" dicabut.
Basis utama sekarang **elastisitas terestimasi tanpa restriksi (non-CRS/DRS: b1=0,400, b2=0,191,
jumlah 0,591)**; CRS turun status jadi **diagnostik + kontrafaktual tersimulasi**. Konsekuensi angka
utama: sisa nasional +0,98 poin (25,7% pertumbuhan); indeks TFP nasional naik ke 106,8 (2024), tren
**+0,81%/thn (p=0,002)**; kontribusi modal 64% (non-CRS) vs 71% (CRS). Ditambah §3.4 simulasi
DRS-vs-CRS (komparatif-statik deterministik) dan Gambar 8. Litrev `litrev-twfe-drs-tfp.md`
diintegrasikan ke §2.1 dan §3.2 (8 sumber: Solow, Hulten, Barro, Basu-Fernald, Griliches-Mairesse,
Combes dkk., Driscoll-Kraay, Purwono dkk.). **Kaveat wajib:** penolakan CRS sebagian bisa atenuasi
proksi arus PMTB, sehingga sisa basis utama batas atas — TFP sebenarnya antara ~0 dan 0,98, condong
ke bawah. Peringkat provinsi non-CRS didominasi provinsi skala besar (DKI, tiga Jawa, Kaltim), bukan
lagi "6 dari 7 ekstraktif/enklave" (itu hanya versi CRS). Baris di bawah yang masih berlabel CRS
dibaca sebagai diagnostik.

---

## Struktur (penomoran mandiri 1–4)

1. **Definisi dan urgensi TFP** — maks 2 hal
2. **Perhitungan TFP** — maks 3 hal · Sub-1 literatur · Sub-2 metode
3. **Hasil perhitungan TFP** — Sub-1 diagnostik · Sub-2 interpretasi · Sub-3 analisis · Sub-4 simulasi DRS-vs-CRS
4. **Diskusi** — MENYUSUL

Lampiran: Tabel keluarga metode, kaskade lengkap, panel robustness, tren 34 provinsi.

---

## A. Bagian 1 — urgensi

Narasi yang dipakai: **"sempat membaik pada 2000-an, lalu berbalik menurun"** — bukan
"konvergensi lima sumber". Versi lama menghilangkan dua bukti yang berlawanan dan tidak
bisa dipertahankan.

| # | Temuan | Angka | Sumber |
|---|---|---|---|
| A1 | TFP menjelaskan porsi kecil pertumbuhan jangka sangat panjang | 7–13% pertumbuhan PDB 1880–2007; stok modal 44–61% | van der Eng (2010) |
| A2 | Rata-rata periode modern negatif | −0,2%/thn 1971–2007 | van der Eng (2009) |
| **A2b** | **Tetapi sempat positif kuat pada 2000-an** | **+1,7%/thn 2000–07, menjelaskan 33% pertumbuhan** | **van der Eng (2009)** |
| **A2c** | **Konfirmasi independen perbaikan itu** | kontribusi TFP "turned persistently positive after 1999" | **Musyawwiri & Üngör (2019), Penn World Table** |
| A3 | Growth accounting nasional | TFP −0,62 poin dari pertumbuhan 4,58%, 1976–2011 | Rusiawan dkk. (2015) |
| **A4** | **Lalu berbalik lagi** | APO: −0,89 (2011–15) → **−0,35 (2016–22)**; modal 2,80 poin (78,1%) | Masterplan Tabel 1 |
| A5 | Tren 50 tahun | Output 8,28% → 3,59%; TFP +1,96% → −0,35% | Masterplan hal. 42 |
| A6 | Posisi internasional | kontribusi TFP Indonesia 10%, 6 negara Asia 16%, 5 negara maju 24% | **Masterplan hal. 56, narasi — atribusikan harfiah, bukan sebagai fakta terverifikasi** |
| A7 | Sasaran kebijakan | 8% pada 2029 = 4 poin tenaga kerja + 2 poin modal + 2 poin TFP (narasi Masterplan; koreksi 2026-09-05) | Bappenas, Perpres 12/2025 |
| **A8** | **Jarak ke sasaran — tiga komponen, skenario C saja** | Modal 1,96 · Tenaga kerja 0,62 · TFP 1,60 · Output 4,17 poin | kajian ini |

**A8 direvisi total.** Rentang 1,60–2,05 dicabut: hanya skenario C yang memakai α=1/3 seperti
sasaran, jadi hanya itu yang perbandingannya setara. Ketiga komponen ditampilkan sekaligus supaya
tidak terbaca seolah TFP satu-satunya yang tertinggal — jarak modal (1,96) justru lebih besar.
Wajib satu kalimat: sasaran 2 poin diturunkan dengan stok modal PIM dan pangsa pendapatan,
sehingga perbandingannya indikatif.

Kualifikasi wajib: van der Eng meragukan angkanya berarti tidak ada kemajuan teknologi, karena
sebagiannya bisa ter-*embodied* dalam stok modal.

## B. Bagian 2 — metode

| # | Isi |
|---|---|
| B1 | Empat keluarga metode: growth accounting (Rusiawan); Solow residual pangsa impor (Olomola); regresi fungsi produksi (Di Giacinto & Nuzzo; Tang & MacLeod); DEA-Malmquist (Kataoka). SFA disebut, ditunda. → **Tabel ke lampiran**, narasikan tiga kalimat |
| **B2** | **Alasan #1 menolak 7.3.2 — ketidaklayakan data.** PIM menuntut `K₀=I₀/(g+δ)` + seri panjang; PMTB provinsi hanya 2017–2025. Dengan δ=5% galat awal meluruh 0,95ᵗ → masih ~70% setelah 7 tahun. BPS tidak memublikasikan stok modal provinsi; Kataoka (2020) harus mengarang estimasinya sendiri. **Ini alasan yang tidak bisa dibantah, taruh pertama.** |
| B3 | Alasan #2 — asumsi: menurunkan elastisitas dari pangsa pendapatan menuntut pasar kompetitif sempurna, utilisasi penuh, CRS (Inklaar dkk. 2007); penyimpangan karena salah ukur, non-CRS, persaingan tak sempurna, spillover (Niebel dkk. 2017) |
| **B4** | **α=1/3 dipertahankan sebagai skenario C** → perubahan metode jadi *perluasan*, bukan pembatalan. Pembaca 7.3.2 mendapati asumsinya masih diuji di dalam. |
| B5 | Kaskade **S0–S3, S5, S6** (S4 dikeluarkan, lihat catatan) |
| B6 | Hausman klasik tidak sah di bawah heteroskedastisitas/autokorelasi (StataCorp 2025); keduanya ditolak p<0,001 → Hausman ADHK p=0,074 tidak admissible |
| B7 | Data: 34 provinsi × 2017–2024, 272 observasi; 2025 keluar karena PMTB & tenaga kerja belum ada |

**Pangsa pendapatan van der Eng (28–51%) hanya dipakai untuk satu hal:** menolak 0,6 milik Olomola
sebagai deskripsi pangsa pendapatan Indonesia. Falsifikasi itu sah karena seluruhnya berlangsung
di dalam ruang pangsa pendapatan. **Jangan pakai untuk menilai elastisitas hasil regresi** — itu
membatalkan premis B3. Estimasi kami sendiri (b2=0,554) lebih dekat ke 0,6 daripada ke 0,51.

**S4 dikeluarkan dari kaskade.** Uji RTS jadi diagnostik pasca-estimasi di 3.2, bukan langkah
seleksi. Kaskade yang salah satu langkahnya di-*override* bukan lagi deterministik.

## C. Bagian 3.1–3.2 — diagnostik dan interpretasi

| # | Temuan | Angka |
|---|---|---|
| C1 | Model terpilih | ADHK, two-way FE (provinsi + tahun), SE Driscoll-Kraay |
| C2 | Elastisitas tak-terestriksi | b1 = 0,400 (SE 0,053); b2 = 0,191 (SE 0,068) |
| C3 | Elastisitas CRS (dasar dekomposisi) | b1 = 0,446 (SE 0,054); b2 = 0,554 |
| C4 | Uji RTS ditolak di semua spesifikasi | RE 0,897 (p=0,041); FE 0,803 (p=0,003); two-way 0,591 (p<0,001) |
| **C5** | **Penolakan itu hipotesis gabungan** | Di bawah errors-in-variables estimator *within* tidak konsisten, sehingga yang ditolak adalah konjungsi "CRS **dan** modal terukur tanpa galat". Menolaknya tidak mengizinkan kesimpulan DRS. |
| C6 | Tangga atenuasi sbg pola, bukan jangkar | b1: 0,854 → 0,459 → 0,452 → 0,400 seiring variasi dibuang. **Yang teratenuasi terutama modal**; b2 tidak monoton. Jangan pakai level pooled 1,011 sbg bukti — pooled punya dua bias berlawanan. |
| C7 | Dasar teoretis | measurement error diperbesar di dimensi *within* (Griliches & Hausman 1986); proksi modal lemah membiaskan elastisitas modal ke bawah (Chen & Plotnikova 2018) |
| **C8** | **Alasan utama memaksakan CRS bersifat akuntansi, bukan empiris** | tanpa CRS, suku `(1−b1−b2)×pertumbuhan input` masuk residual dan disebut TFP. Buktinya: tren +0,81%/thn tanpa CRS vs −0,27%/thn dengan CRS. |
| C9 | ADHB RTS 1,540 = gejala, bukan temuan | RTS ~1,3 "unreasonably large… a potential sign of CSD" (Lee & Park 2024); ADHB gagal CD z=33,6. Elastisitas aglomerasi empiris <0,10 → RTS wajar 1,01–1,10 (Graham 2009; Kakamu dkk. 2012) |
| C10 | Diagnostik | BP-LM p<0,001; Mundlak p<0,001; Wald-het p<0,001; AR(1) p<0,001; CD FE p=0,001, two-way **masih** p<0,001 → Driscoll-Kraay; RESET p=0,343 → Cobb-Douglas dipertahankan |
| C11 | Capital-driven | modal 53–71% pertumbuhan di seluruh skenario CRS |
| C12 | Robustness | PMTB lag-1 b1=0,416 (vs 0,400) → simultanitas kontemporer bukan penggerak utama |

## D. Bagian 3.3 — analisis TFP

| # | Temuan | Angka |
|---|---|---|
| D1 | Pertumbuhan nasional 2018–2024 | PDRB riil 3,83%/thn; PMTB 6,12%/thn; tenaga kerja 2,08%/thn |
| **D2** | **Dekomposisi, lima skenario** | modal 2,04–2,73 poin; tenaga kerja 0,40–1,38; **sisa −0,05 s.d. +0,98 poin** |
| **D2b** | **Skenario D (stok PIM)** | g(K) PIM 5,69%/thn vs arus 6,12% → **sisa +0,14 poin (3,7%)** |
| **D2c** | **Skenario E (tanpa CRS), ditampilkan lalu dibantah** | **sisa 0,98 poin = 25,7%**, tren +0,81%/thn. Dibantah dengan aljabar suku skala. |
| **D3** | **Amplop — pernyataan paling kuat, tidak bergantung skenario** | `sisa = 1,75 − 4,05·b1`. Batas atas mutlak **1,75 poin (45,8%)** hanya bila b1=0. Sisa nol pada b1=0,433. Melampaui 25% hanya bila **b1 < 0,196** — di bawah seluruh estimasi kami, termasuk berbobot 0,299. |
| **D5** | Indeks TFP nasional | 2017=100 → 97,5 (2021) → 98,6 (2024). Tren **−0,27%/thn (SE 0,0014, p=0,049)** dari spesifikasi bertren linear + SE Driscoll-Kraay |
| **D6** | Pemulihan pasca-COVID tidak signifikan | selang 2024 = **±3,3 poin indeks** (95,4–101,8) → tak dapat dibedakan dari 100 |
| **D7** | **Pembanding eksternal, BUKAN validasi** | kajian ini −0,27 (arus PMTB, elastisitas terestimasi); APO −0,35 (stok, pangsa); van der Eng −0,20 (PIM, pangsa); Rusiawan −0,62 (PIM, Divisia). **Hanya APO yang periodenya beririsan.** Kemiripan sebagian konsekuensi pemaksaan CRS. |
| D8 | Peringkat TFP provinsi (level) | DKI +0,82; Kaltim +0,78; Papua Barat +0,54 teratas. NTT terbawah. |
| D10 | Tren provinsi jarang signifikan | **14 dari 34** pada p<0,05 — dan itu **batas atas**, karena SE dari OLS 8 titik atas residual berautokorelasi positif terlalu kecil |
| D11 | Tidak ada CAGR TFP | ρ=**0,988**; sd residual dalam-provinsi **0,0355** > rentang deret nasional 8 tahun **0,0250**; AR(1) kuat → titik ujung paling tidak andal |

**D4 (dekomposisi subperiode) DIBUANG.** Tandanya berlawanan dengan D5 di kedua subperiode, dan
jendela 2–3 tahun melanggar syarat rasio investasi/stok stabil. Dimensi waktu ditangani D5 saja.

**D9 (validasi Kaltim vs Masterplan) DIBUANG.** Melanggar E8, dan memakai provinsi yang memory
kami sendiri tetapkan sebagai artefak.

## E. Batasan — wajib terbit utuh, disajikan sebagai daftar bernomor padat

| # | Batasan |
|---|---|
| **E1** | **Modal arus, bukan stok — dua saluran berlawanan.** (a) elastisitas teratenuasi → sisa **naik**; (b) g(PMTB)=6,12% > g(stok PIM)=5,69% → kontribusi modal terlalu besar → sisa **turun**. Syarat yang membuat (a) berlaku: g(K) > g(L), dan di sini 6,12 > 2,08. **Arah neto tidak dapat ditentukan**; skenario D mengukur saluran (b) dan menggesernya dari −0,05 ke +0,14. |
| E2 | Bias agregasi: panel berbobot pangsa output memberi b1=0,299 b2=0,036 (jumlah 0,335) — spesifikasi yang praktis runtuh. Pakai sebagai peringatan, bukan estimasi alternatif setara. |
| E3 | CD tidak sepenuhnya teratasi (two-way FE masih p<0,001); Driscoll-Kraay hanya mengoreksi inferensi, bukan titik estimasi |
| E4 | Bukan identifikasi kausal. PMTB lag-1 (0,416 vs 0,400) menunjukkan simultanitas kontemporer kecil, tetapi ini bukan identifikasi. Baca sebagai asosiasi. |
| E5 | IV/2SLS ditolak beralasan: PMA/PMDN bagian dari PMTB (exclusion restriction gagal); instrumen lemah (within-R² 0,13) |
| E6 | Dekomposisi hanya rata-rata periode penuh. Tabel 5 Masterplan menunjukkan akibat melanggar: TFP tahunan −36,65 → +77,37 mencerminkan pergerakan investasi |
| E7 | Efek tahun menyerap seluruh guncangan agregat (siklus, harga, pandemi), bukan hanya teknologi. Level indeksnya arbitrer. **Tidak ada preseden publikasi deret ini sebagai "indeks TFP" bernama — ini pilihan metodologis kami sendiri.** |
| E8 | Angka TFP provinsi kami kontribusi baru; tidak ada pembanding persen kontribusi di literatur. Jangan tulis "sejalan dengan literatur". |
| **E9** | **Level TFP provinsi mencerminkan endowmen dan komposisi sektoral, bukan efisiensi teknis.** Enam dari tujuh teratas provinsi ekstraktif/enklave. DKI menggelembung karena PDRB dicatat menurut lokasi produksi sedangkan tenaga kerja Sakernas menurut tempat tinggal — komuter Bodetabek menghasilkan output di DKI tapi tercatat sebagai tenaga kerja Jabar/Banten. |
| **E10** | **Tenaga kerja tanpa koreksi kualitas.** Input berupa headcount. Rata-rata lama sekolah naik sepanjang periode, sehingga seluruh pendalaman modal manusia jatuh ke residual dan terhitung sebagai TFP. Arahnya jelas: **TFP terukur terlalu besar**. Ini juga menjelaskan sebagian selisih terhadap van der Eng yang memakai *education-augmented employment*. |
| **E11** | **Dua deret TFP memakai pembobotan agregasi berbeda.** Indeks efek tahun dari panel yang membobot tiap provinsi sama; dekomposisi dari agregat yang membobot pangsa output. Tidak boleh dibaca sebagai dua ukuran atas benda yang sama. |

## F. Rekonsiliasi dengan bab sebelumnya (wajib, jangan didiamkan)

| # | Isu | Penanganan |
|---|---|---|
| F1 | BAB 5.1 menyebut pertumbuhan 5,03–5,11%; kami 3,83% | satu kalimat di awal 3.3: rata-rata log-difference, periode 2018–2024 termasuk kontraksi 2020 (−2,05%), dan agregat = jumlah 34 PDRB provinsi, bukan PDB BPS |
| F2 | BAB 6.2.3 memakai SE klaster; kami menyatakan klaster tidak memadai | catatan kaki di 2.2: uji Pesaran CD dijalankan di sini dan tidak di 6.2, sehingga pilihan SE berbeda |
| F3 | BAB 6.2.3 mengeluarkan DKI & provinsi ekstraktif sbg outlier; kami menjadikannya headline | rujuk perlakuan 6.2.3 di E9, atau jalankan peringkat tanpa mereka sebagai kepekaan |
| F4 | Kerangka 7.4.2 menetapkan pulau sbg satuan wajib; kami hanya nasional + provinsi | nyatakan penghapusannya dengan alasan, atau tambahkan agregasi pulau |
| F5 | 7.5 menjanjikan pembanding World Bank & PWT | PWT terisi lewat Musyawwiri & Üngör (A2c). World Bank **dinyatakan dikeluarkan** karena angkanya belum diverifikasi dari dokumen asli |

## G. Gambar dan tabel

| Gambar | File | Di |
|---|---|---|
| 1 | `Dekomposisi Pertumbuhan Nasional.png` (perlu render ulang: 5 skenario) | 3.3 |
| 2 | `Indeks TFP Nasional.png` | 3.3 |
| 3 | `Peringkat TFP Provinsi.png` (idealnya tandai provinsi ekstraktif) | 3.3 |
| 4 | `Tangga Atenuasi Elastisitas.png` — **tidak boleh ke lampiran**, satu-satunya bukti visual untuk C5/C6 | 3.2 |
| 5 | **amplop sisa vs b1** (baru, kecil) | 3.3 |

Flowchart TikZ **dihapus** — kaskade lebih efisien sebagai tabel enam baris.

| Tabel | Isi | Di |
|---|---|---|
| 1 | Kaskade seleksi ringkas (4 baris: langkah, uji, p, verdict) | 3.1 |
| 2 | Elastisitas model terpilih | 3.2 |
| 3 | Dekomposisi 5 skenario | 3.3 |
| 4 | Jarak ke sasaran 8-4-2-2, tiga komponen | 3.3 atau 1.3 |
| 5 | Pembanding eksternal + kolom ukuran modal & bobot | 3.3 |

Ke lampiran: keluarga metode, kaskade lengkap, panel robustness, tren 34 provinsi.

## H. Gaya — titik rawan yang harus dijaga saat menulis

1. Konstruksi **"A, bukan B" maksimal dua kali** di seluruh report. Sekarang ada lima calon;
   pertahankan C9 ("gejala, bukan temuan") dan E5 ("ditolak, bukan dilewati").
2. **Jangan cetak tebal kesimpulan kontrarian.** Tulis mekanismenya dulu, biarkan kesimpulan
   menyusul tanpa penekanan tipografi.
3. **Setiap batasan harus menyebut arah bias atau angka.** E3, E4, E7 belum — beri masing-masing satu.
4. Hapus sub-bagian "2.0 Pengantar"; lebur ke kalimat pembuka 2.1.
5. Label yang lebih besar dari isinya sudah dicabut: "konvergensi lima sumber", "validasi
   eksternal", "kesimpulan robust". Jangan dihidupkan lagi.

---

## Riwayat revisi pasca-GATE

| Blocker | Perubahan | Status |
|---|---|---|
| 1 | D4 (dekomposisi subperiode) dibuang | selesai, skrip diubah |
| 2 | D9 (validasi Kaltim) dibuang | selesai |
| 3 | E1 jadi dua saluran; PIM nasional dibangun (g(K)=5,69% vs arus 6,12%); skenario D ditambah | selesai, dihitung |
| 4 | Tren dihitung ulang lewat spesifikasi bertren linear + DK: **−0,27%/thn, p=0,049** | selesai |
| 5 | Bagian A: van der Eng 2000–07 dan Musyawwiri & Üngör masuk; "konvergensi" dicabut | selesai |
| 6 | Sirkularitas pangsa pendapatan ditutup; "validasi" dicabut dari memory_tfp.md | selesai |
| 7 | D6 diperbaiki ke ±3,3; ρ dan sd residual diregenerasi (0,988 / 0,0355 / 0,0250) | selesai |
| 8–16 | Keputusan penyajian: amplop, skenario E, tabel jarak 3 komponen, S4 keluar kaskade, E9–E11, F1–F5, lampiran | diputuskan, dieksekusi saat menulis |
