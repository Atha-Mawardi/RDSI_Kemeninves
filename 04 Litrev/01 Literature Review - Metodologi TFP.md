# Literature Review: Metodologi Perhitungan TFP (untuk Rencana TFP Provinsi Indonesia)

Tanggal diskusi: 2026-07-09
Sumber: 3 paper di `00 Assets` (dikonversi ke .txt via `convert_pdf_to_txt.py`)

- `kataoka2020.pdf` / `.txt`
- `olomola2018.pdf` / `.txt`
- `rusiawan2015.pdf` / `.txt`

Tujuan: mengekstrak **bagian perhitungan TFP inti saja** dari ketiga paper (mengabaikan ekstensi seperti Green TFP), sebagai referensi sebelum mendesain perhitungan TFP provinsi/sektoral Indonesia sendiri.

---

## Tabel Perbandingan

| | **Kataoka (2020)** | **Olomola & Osinubi (2018)** | **Rusiawan (2015)** |
|---|---|---|---|
| **Definisi TFP** | Efisiensi relatif antar provinsi (frontier) | Sisa/residual output setelah dikurangi kontribusi input | Sisa/residual output (growth accounting klasik) |
| **Metode inti** | DEA – Malmquist Productivity Index | Solow Residual (persamaan langsung) | Growth Accounting Method (Divisia index) |
| **Fungsi produksi** | Tidak diasumsikan (non-parametrik) | Cobb-Douglas, CRS | Cobb-Douglas, CRS |
| **Cara estimasi** | Linear programming (DEA), tanpa regresi | Aljabar langsung dari identitas (bukan regresi) | Aljabar langsung — dekomposisi pertumbuhan tahunan |
| **Bobot faktor (labor/kapital)** | Tidak perlu (DEA tidak butuh share) | **Ditetapkan tetap**: 0,6 (tenaga kerja) / 0,4 (modal) — dari literatur lain, bukan dihitung dari data | **Dihitung dari data**: labor income share (upah/PDB) tiap tahun; capital share = 1 − labor share |
| **Level data** | Provinsi (26 provinsi, 1990–2015) | Nasional (4 negara: Meksiko, Indonesia, Nigeria, Turki, 1980–2014) | Nasional (Indonesia saja, ~1976–2013) |
| **Kapital diukur pakai apa** | Stok modal provinsi (estimasi dari paper penulis sebelumnya, Kataoka 2013/2018) | Gross Fixed Capital Formation (arus investasi, bukan stok modal PIM) | Stok modal dengan depresiasi 5%/tahun (asumsi dari Mankiw-Romer-Weil) |
| **Software** | Tidak disebutkan | EViews 9 | Tidak disebutkan (manual) |
| **Ekstensi yang disebut tapi tidak jadi fokus** | SFA / dekomposisi Kalirajan (disarankan untuk riset lanjutan, tidak dipakai) | — | Green TFP (memasukkan emisi CO2 sebagai "input" tambahan) |

---

## Detail Per Paper

### 1. Kataoka (2020) — DEA-Malmquist, level provinsi

- **Definisi**: Malmquist Productivity Index (MI), didekomposisi jadi Efficiency Change (EC) × Technological Change (TC).
- **Tidak** memakai fungsi produksi parametrik — membangun frontier non-parametrik dari provinsi ber-praktik-terbaik (DEA output-oriented), dihitung dengan CRS & VRS.
- Input: GRDP (output), tenaga kerja, stok modal provinsi (dari estimasi penulis sebelumnya), human capital (proksi rata-rata lama pendidikan tenaga kerja).
- Data: 26 provinsi (dikonsolidasi ke batas 1990 agar panel seimbang meski ada pemekaran wilayah), 1990–2015, sumber BPS.
- Rumus inti (cumulative MI dari base year t0):
  `MI = EC × TC`, dengan EC lebih lanjut = PECH × SECH (pure efficiency × scale efficiency) di bawah VRS.
- Menolak bootstrap DEA (Simar & Wilson) karena tujuan studi adalah mengidentifikasi provinsi paling efisien.
- Cocok untuk: **membandingkan efisiensi relatif antar provinsi**, bukan mengukur %kontribusi TFP terhadap pertumbuhan.

### 2. Olomola & Osinubi (2018) — Solow Residual, level nasional (4 negara)

- **Definisi**: TFP = output residual setelah kontribusi modal & tenaga kerja dikurangi.
- Persamaan: `ln TFP_it = ln Y_it − (1−α) ln K_it − α ln L_it`, dengan α (labor share) = 0,6 dan (1−α) (capital share) = 0,4 — **fixed a priori**, mengikuti Chen (1997), Easterly & Levine (2001), dll (bukan dihitung dari data Indonesia).
- Kapital diukur dari **Gross Fixed Capital Formation** (arus investasi), bukan stok modal hasil PIM.
- Data: 4 negara MINT (Meksiko, Indonesia, Nigeria, Turki), 1980–2014, sumber World Bank WDI + ICRG.
- Tahap lanjutan (di luar cakupan TFP inti): TFP hasil hitungan lalu diregresi terhadap determinan (FDI, human capital, inflasi, korupsi, stabilitas pemerintah) pakai Panel ARDL/PMG di EViews 9.
- Catatan: metode TFP-nya paling sederhana di antara ketiga paper — bobot faktor pinjaman dari literatur lain, bukan estimasi lokal.

### 3. Rusiawan (2015) — Growth Accounting Method, level nasional (Indonesia)

- **Definisi**: TFP = Solow residual, `TFPG = EG − CGA − LGA` (pertumbuhan ekonomi dikurangi kontribusi modal & tenaga kerja terboboti).
- Bobot faktor **dihitung dari data riil tiap tahun**: Labour Income Share (LIS) = Upah/PDB, dirata-ratakan antar tahun (t, t−1) jadi LISA; Capital Income Share (CIS) = 1 − LIS, juga dirata-ratakan (CISA).
- Stok modal dihitung dengan depresiasi tetap 5%/tahun (asumsi dari Mankiw-Romer-Weil), PIM tidak dirinci detail dalam bagian yang terekstrak.
- Data: nasional, ~1976–2013, sumber BPS (PDB, stok modal, tenaga kerja, upah), World Bank (emisi CO2 untuk ekstensi Green TFP).
- Rumus disusun rapi sebagai deret langkah (Eq. 1–16): dari LIS/CIS → growth rate tiap komponen (EG, CG, LG) → weighted growth (CGA, LGA) → TFPG = EG − CGA − LGA.
- Menyediakan juga rumus sektoral (Eq. 5b, pakai Gross Value Added per sektor) meski hasil di paper hanya level nasional — jadi kerangkanya bisa diperluas ke sektoral.
- Ekstensi Green TFP: tambahkan CO2Gt/CO2GAt sebagai komponen ketiga yang dikurangkan dari EG (di luar cakupan analisis ini).

---

## Rekomendasi untuk Rencana TFP Provinsi Indonesia

**Kerangka dasar yang disarankan: Growth Accounting ala Rusiawan** — karena tujuannya adalah membangun *data series* TFP untuk analisis kebijakan makro (dekomposisi %pertumbuhan PDRB menjadi kontribusi modal, tenaga kerja, dan TFP), bukan sekadar ranking efisiensi antar provinsi.

Dua titik lemah Rusiawan yang perlu diperbaiki saat diadaptasi ke level provinsi:

1. **Stok modal provinsi tidak dipublikasikan BPS.** Rusiawan hanya bekerja di level nasional dengan asumsi depresiasi tunggal 5%/tahun. Untuk level provinsi, metodologi estimasi stok modal PIM ala **Kataoka (2013/2018)** lebih relevan untuk dipinjam khusus di bagian estimasi kapital.
2. **Labor income share mungkin tidak tersedia di level provinsi.** Bobot upah/PDB yang dipakai Rusiawan bergantung pada data upah nasional; di level provinsi mungkin perlu proksi dari data Sakernas atau asumsi tetap sebagai fallback.

**Trade-off metode:**
- Growth accounting (Rusiawan) → sederhana, hasil mudah diinterpretasikan ("TFP menyumbang X% pertumbuhan"), tapi sangat sensitif terhadap kualitas estimasi stok modal (residual jadi "tempat sampah" error pengukuran).
- DEA-Malmquist (Kataoka) → lebih tahan terhadap masalah estimasi stok modal presisi, tapi hasilnya indeks efisiensi relatif antar provinsi, bukan %kontribusi terhadap pertumbuhan — kurang pas untuk narasi kebijakan makro.
- Olomola → tidak disarankan sebagai basis utama karena bobot faktor (0,6/0,4) tidak mencerminkan struktur ekonomi Indonesia secara spesifik.

**Rencana lanjutan (belum dieksekusi):** merancang alur perhitungan TFP provinsi/sektoral lengkap — kebutuhan data (PDRB, tenaga kerja, investasi/PMTB per provinsi, upah), metode estimasi stok modal (PIM + asumsi depresiasi), dan formula dekomposisi pertumbuhan per provinsi/sektor.
