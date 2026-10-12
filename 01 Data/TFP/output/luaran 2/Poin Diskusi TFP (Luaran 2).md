# Poin Diskusi TFP — Luaran 2

Diperbarui 11 September 2026. Catatan kerja (outline, CRS/DRS, cluster
FE/RE/RE2W/FGLS, spasial):
`02 Code/TFP/Notes - Penempatan CRS-DRS dan Luaran 2 (Subbab 6.1).md`.

Skrip: `luaran2_build.py`, `spatial_sar_sdm_maps.py`, `spatial_recheck.py`.

Lapisan TFP = **vintage B** (2017–2024; DRS b1=0,402 / b2=0,147; CRS b1=0,451).
Determinan = DV Stata **vintage C**. Tidak dicampur dalam satu angka.

---

## Outline vs folder ini

RTS (CRS/DRS, Wald, elastisitas per pulau) **sudah di Luaran 1**. 6.1 hanya
mengidentifikasi apa yang menggerakkan residual yang sudah ada. Peta DRS di
folder ini adalah **lampiran skala**, bukan substansi 6.1.

| 6.1 | Isi folder yang relevan |
|---|---|
| 6.1.1 matriks 2×2 | naskah, bukan gambar di sini |
| 6.1.2 tanda + pecah pulau | `Tabel Hasil TFP Spasial.xlsx` sheet FE vs FE2W; indeks residual per pulau; kuadran **CRS** |
| 6.1.3 triangulasi | notes §4–5 |

Satu kalimat RTS yang boleh masuk 6.1: DV = residual PPT (tanpa CRS); CRS =
satu kolom robustness (institusi tetap +); peta “siapa tertinggal” = CRS.

---

## Angka yang masih berlaku (tidak diulang di notes)

**Tiga lapisan.** Dummy tahun FE2W 2022 +0,146*** → 2025 +0,231***. Between
R²=0,72; konektivitas 0,431 (tanpa kargo **0,348**). Within: institusi 0,049
(hanya DK). FE tanpa dummy tahun menghidupkan keempat pilar karena ko-gerak
tren nasional.

**SDM/upah.** Median corr(idx_hr, tahun)=0,97. COVID memukul upah, bukan stok
SDM. `neg_gini` bermuatan negatif di PC1 SDM.

**Kuadran CRS × tren CRS — Prioritas (10):** NTT, NTB, Maluku, Sulawesi Barat,
Lampung, Aceh, Kalimantan Barat, Jawa Tengah, Sulawesi Selatan, Sumatra Barat.

Indeks residual 2024 (2017=100): Sulawesi 125,0 · Jawa 118,4 · Sumatera 114,5 ·
Maluku-Papua 114,1 · Kalimantan 110,5 · Bali-Nusra 109,1.

**Spasial.** Jangan kutip island ρ≈0,25. Moran rata-rata TFP queen I=0,49
hilang setelah FE pulau. SAR between: ρ ns, OLS R²=0,70.

**Vintage.** Aceh 2017: 16,02 / 22,14 / 23,26 pada tiga seri. Sheet1 hari ini
TWFE b1=0,387/b2=0,193, bukan 0,402/0,147.

---

## Daftar file

**6.1 (peta/grafik):**
`Peta Level TFP Efisiensi (CRS) Provinsi.png` ·
`Peta Tren TFP (CRS) Provinsi.png` ·
`Peta Kuadran Kebijakan TFP.png` ·
`Peta Pilar Fokus Investasi.png` ·
`Peringkat TFP Provinsi (CRS).png` ·
`Indeks TFP Residual per Pulau.png` ·
`Perubahan Upah Nasional per Tahun.png` ·
`maps/map_sar_mean_logtfp.png`

**Lampiran RTS / jangan sebagai ranking 6.1:**
`Peta Level TFP Produksi (DRS) Provinsi.png` ·
`Peta Ketergantungan Skala (DRS-CRS).png` ·
`TFP vs Skala Ekonomi (DRS vs CRS).png`

**Diagnostik spasial (bukan spillover):**
`maps/map_sar_island_W.png` ·
`maps/map_sar_island_lag.png` ·
`maps/map_sar_fe2w_residual.png`

**Tabel:** `Tabel Hasil TFP Spasial.xlsx` — Kuadran Provinsi, Ringkasan Pulau,
Dekomposisi Provinsi, Bottom-Up Nasional, Mean-Play Pulau, Model FE vs FE2W,
Konektivitas Tanpa Kargo, **CRS robustness DV**, **Penempatan outline**,
Moran recheck, SAR between ns. CSV: `penempatan_berkas.csv`.

**Bukan keluaran skrip terbit (versi lama / Hijau, jangan dikutip sebagai 6.1):**
`Indeks TFP Nasional.png` · `Indeks TFP per Pulau.png` ·
`Peringkat TFP Provinsi.png` (DRS, 5 Sep) · `Dekomposisi per Pulau.png` ·
`Peta Indeks Hijau Provinsi.png` · `Peta Indeks Institusi Provinsi.png` ·
`Hijau vs Tren TFP Provinsi.png` · `Hijau dan Tren TFP per Pulau.png`.
