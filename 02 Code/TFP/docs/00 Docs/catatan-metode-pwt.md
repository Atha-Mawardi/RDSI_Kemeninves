# Catatan metode — Penn World Table 8

Sumber: Feenstra, Inklaar & Timmer (2015), "The Next Generation of the Penn World Table",
*American Economic Review* 105(10): 3150-3182. PDF ada di `~/Downloads/`.

Dibaca 4 Agustus 2026, saat mencari jalan keluar dari masalah scale term.

---

## 1. Metode intinya

**Indeks kuantitas Törnqvist atas endowmen faktor** (persamaan 13-14, hal. 3166):

```
ln Q_T = Σ_l  ½ ( s_lj + s_lk ) × ln( v_lj / v_lk )
```

`s` adalah **pangsa pendapatan faktor yang teramati**, dirata-ratakan antara dua periode atau
dua negara. Tidak ada yang diregresikan.

TFP adalah pertumbuhan output dibagi indeks Törnqvist input (persamaan 25, hal. 3172):

```
RTFP_t/t-1 = ( RGDP_t / RGDP_t-1 ) / Q_T( v_t, v_t-1, w_t, w_t-1 )
```

Fungsi produksinya translog, bukan Cobb-Douglas, sehingga elastisitas substitusi boleh berbeda
antarnegara dan antarwaktu (hal. 3177). Indeks Törnqvist adalah bentuk empiris translog itu.

## 2. Lima keputusan pengukuran

| Komponen | Cara PWT | Halaman |
|---|---|---|
| Pangsa tenaga kerja | `LABSH`, pendapatan karyawan **dan** wiraswasta terhadap PDB | 3155, 3172 |
| Pangsa modal | **Diasumsikan `1 − LABSH`**, tidak diestimasi terpisah | 3173 |
| Wiraswasta | Koreksi Gollin (2002): mixed income dibelah ke tenaga kerja dan modal memakai proporsi yang sama dengan pendapatan non-mixed | 3172 |
| Modal | PIM per jenis aset — bangunan, alat angkut, mesin, komputer, peralatan komunikasi, software — dengan depresiasi geometrik spesifik aset | 3172 |
| Tenaga kerja | Headcount dikali indeks human capital dari rata-rata lama sekolah (Barro-Lee 2013) dan return to schooling ala Caselli (2005) | 3172 |

Kutipan yang menentukan, hal. 3173:

> "we assume that the income share of physical capital equals 1 minus the labor income share"

Karena pangsa modal didefinisikan sebagai sisa, kedua pangsa berjumlah satu **per konstruksi**.
Skala hasil konstan tidak diuji dan tidak diasumsikan diam-diam — ia lahir dari definisinya.

## 3. Pemetaan ke masalah project ini

| Masalah kajian BKPM | Jawaban PWT |
|---|---|
| `b1 + b2 = 0,549`, memunculkan scale term 1,33 poin dari residual 2,21 poin | Tidak mungkin muncul. Pangsa berjumlah satu per konstruksi |
| Modal diukur arus PMTB, bukan stok (Batasan E1) | PIM per jenis aset |
| `b2 = 0,147` terlalu rendah, tenaga kerja kurang dikreditkan | Pangsa dari data pendapatan, bukan regresi yang teratenuasi |
| Pangsa upah terukur 15-18% | Persis kasus yang Gollin (2002) tulis. Indonesia penuh wiraswasta dan pekerja informal, sehingga kompensasi karyawan saja kurang mencatat |
| Kualitas tenaga kerja jatuh ke residual (Batasan E10) | Human capital masuk sebagai input |

## 4. Yang perlu dicatat sebelum mengadopsi

PWT bekerja di tingkat negara dengan neraca nasional lengkap. Kajian ini bekerja di tingkat
provinsi. Tiga hal berbeda:

1. **Pangsa pendapatan per provinsi** harus dirakit dari upah dan tenaga kerja Sakernas, bukan
   dari neraca. Dataset sudah memuat `_RataUpah` dan `_TenagaKerja` untuk 17 sektor.
2. **Rata-rata lama sekolah per provinsi** belum ada di project.
3. **PMTB terpilah jenis aset per provinsi** hampir pasti tidak tersedia.

Konsekuensinya adopsi bisa bertingkat. Tingkat pertama — pangsa pendapatan plus CRS — sudah
bisa dikerjakan dengan data yang ada sekarang.

## 5. Rujukan turunan yang perlu dibaca kalau jadi diadopsi

- Gollin, D. (2002), "Getting Income Shares Right", *JPE* 110(2) — koreksi wiraswasta.
- Caselli, F. (2005), "Accounting for Cross-Country Income Differences", *Handbook of Economic
  Growth* — indeks human capital dan development accounting.
- Barro & Lee (2013) — data rata-rata lama sekolah.
- Inklaar & Timmer, online Appendix C PWT8 — rincian sumber dan metode `LABSH`.

Keempatnya belum diverifikasi lewat Crossref. Verifikasi dulu sebelum masuk daftar pustaka.
