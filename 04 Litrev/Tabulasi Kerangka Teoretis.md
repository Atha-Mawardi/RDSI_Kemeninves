# Tabulasi Kerangka Teoretis — Investasi terhadap Produktivitas TK dan TFP

Panel 34 provinsi × 2017–2024 (272 obs). Modal = arus PMTB. Estimator dibatasi statis:
POLS, two-way FE, 2SLS. Sumber: 74 paper baru di `~/.claude/literature/`, seluruhnya
terverifikasi Crossref 2026-08-02.

`Fit` dinilai terhadap N=34, T=8, modal arus. Tiga nilai: **jalan** / **kaveat** / **gugur**.

---

## 1. Tabel kerangka

| # | Kerangka | Klaim inti | Sumber kunci | Syarat data | Fit |
|---|---|---|---|---|---|
| **A. Modal** |
| A1 | PMTB arus sebagai K | elastisitas bias ke bawah, arah diketahui, besarnya tidak | Collard-Wexler & De Loecker 2016 (T2) | tidak butuh data tambahan | kaveat |
| A2 | Stok PIM | bobot asumsi stok awal membengkak pada deret pendek | Berlemann & Wesselhöft 2014 (T2) | butuh 30–40 tahun; ada 8 | **gugur** |
| A3 | Moving-average investasi | nol preseden di literatur | — | jendela 3–5 thn memakan T | **gugur** |
| A4 | Rasio PMTB/PDRB sebagai regresor | I/Y berasosiasi dengan pertumbuhan Y/L di non-OECD | Bond dkk. 2010; Mankiw dkk. 1992 | tidak butuh stok | kaveat |
| **B. Variabel terikat** |
| B1 | `log Y ~ log K + log L` tanpa restriksi | elastisitas apa adanya, skala tidak dipaksakan | Islam 1995 | 272 obs | **jalan** |
| B2 | `log(Y/L) ~ log(K/L)` | bentuk per-pekerja **mensyaratkan** CRS, bukan menyederhanakannya | Mankiw dkk. 1992; Islam 1995 | Wald menolak CRS di semua varian | kaveat — diagnostik saja |
| B3 | Akuntansi taraf K/Y | tulis dalam rasio modal-output | Hall & Jones 1999 | menuntut stok K | **gugur** |
| B4 | Dekomposisi capital deepening + TFP | identitas akuntansi, bukan regresi | Jorgenson & Griliches 1967; Bosworth & Collins 2008 | berdampingan, tidak menggantikan regresi | kaveat |
| **C. TFP** |
| C1 | Tahap dua: TFP ~ PMTB | **koefisien nol persis** — residual ortogonal terhadap regresornya | penalaran aljabar; Daraio dkk. 2018 | berlaku bila transformasi tahap 1 dan 2 identik | **gugur** |
| C2 | Tahap dua: TFP ~ PMA/PMDN | z irisan definisional x → bias variabel terabaikan tahap satu | Wang & Schmidt 2002; Daraio dkk. 2018 | pooled R² 0,69 | **gugur** |
| C3 | Residual Solow pangsa faktor lalu tahap dua | residual tidak ortogonal, tahap dua punya isi | Hall 1988 | butuh pangsa pendapatan faktor | **gugur** — ditutup §3 spesifikasi |
| C4 | Generated regressand | kovarians OLS tahap dua tidak sah; koreksi bootstrap dua tahap | Pagan 1984; Murphy & Topel 1985; Simar & Wilson 2007 | ongkos tanpa bayaran bila C1–C3 gugur | — |
| C5 | **Satu tahap augmented dengan pangsa asing** | komposisi bukan kombinasi linear input | Haskel dkk. 2007; Wang & Schmidt 2002 | 272 obs, PMA & PMDN sama-sama juta IDR | **jalan** |
| **D. PMA versus PMDN** |
| D1 | Limpahan horizontal | pangsa kehadiran asing menggerakkan produktivitas; tanda bisa negatif | Caves 1974; Aitken & Harrison 1999; Iršová & Havránek 2013 | meta 1.205 taksiran: rata-rata **nol** | kaveat — daya rendah |
| D2 | Limpahan vertikal | limpahan nyata lewat pemasok hulu, bukan sesama pesaing | Javorcik 2004; Havránek & Iršová 2011 | butuh PMA/PMDN sektoral × IRIO | **gugur** — pemilahan belum ada |
| D3 | Absorptive capacity — modal manusia | efek modal asing bersyarat pada stok modal manusia | Borensztein dkk. 1998; Su & Liu 2016 | HK bergerak lambat, variasi within tipis | kaveat |
| D4 | Absorptive capacity — jarak teknologi | limpahan terbesar saat jurang teknologi sedang | Girma 2005 | gap **wajib** dari PDRB/pekerja, bukan TFP | kaveat |
| D5 | Crowding in / out | modal asing menambah atau menggeser modal domestik | Agosín & Machado 2005; Farla dkk. 2016 | PMDN tidak pernah dikurangkan dari ruas kiri | kaveat |
| **E. Identifikasi** |
| E1 | Bartik lewat pangsa awal | identifikasi bersandar eksogenitas pangsa sektor awal | Goldsmith-Pinkham dkk. 2020 | pangsa sektor mencerminkan endowmen | **gugur** |
| E2 | Bartik lewat shift eksogen | guncangan sektoral harus kuasi-acak dan banyak | Borusyak dkk. 2022, 2025 | 23 sektor, paparan terkonsentrasi | **gugur** |
| E3 | Bartik dari data realisasi domestik | **mewarisi kegagalan exclusion restriction**, hanya diencerkan | — (penalaran) | shift dari PMA/PMDN nasional | **gugur** |
| E4 | Shift dari harga komoditas dunia | shift benar-benar di luar Indonesia | Allcott & Keniston 2018; Bazzi & Blattman 2014 | butuh deret harga dunia × pangsa SDA 2017 | kaveat |
| E5 | Instrumen keterkaitan IRIO | paparan guncangan provinsi lain, bukan investasi sendiri | belum dicarikan preseden | IRIO 34×52 sudah ada | terbuka |
| E6 | Non-IV + tren provinsi + batas Oster | klaim diturunkan ke asosiasi berbatas, batasnya dihitung | Besley & Burgess 2004; Oster 2019 | tren memakan 34 parameter | kaveat |
| **F. Batas klaim** |
| F1 | Panel statis cukup, dinamis gugur | bias Nickell berorde 1/T, tidak hilang seiring N | Nickell 1981; Judson & Owen 1999; Roodman 2009 | LDV butuh T≥20–30; instrumen GMM tumbuh ~T² | **jalan** |
| F2 | AR(1) ditangani di inferensi | autokorelasi merusak galat baku, bukan titik estimasi | Bertrand dkk. 2004; Driscoll & Kraay 1998 | — | **jalan** |
| F3 | Driscoll-Kraay pada T=8 | pembenarannya asimtotik saat T→∞ | Vogelsang 2012; Hoechle 2007 | T=8 → **p adalah batas atas keyakinan** | kaveat |
| F4 | Lag terdistribusi tanpa LDV | efek dibaca dari jumlah koefisien, bukan koefisien satuan | Beck & Katz 2011; De Boef & Keele 2008 | 2 lag → 204 obs; 3 lag → 170 obs | kaveat — uji kekokohan |
| F5 | Bahasa "asosiasi", bukan "dampak" | FE tidak identifikasi kausal bila keluaran lalu memengaruhi input kini | Imai & Kim 2019; Hernán 2018 | PDRB t−1 → PMTB t tidak bisa disangkal | **jalan** |
| F6 | Winsorizing dan subperiode COVID | diusulkan sebagai uji kekokohan | — | **nol preseden metodologis ditemukan** | **gugur** |

---

## 2. Spesifikasi terpilih

```
log Y[i,t] = a + b1·log PMTB[i,t] + b2·log L[i,t] + b3·s[i,t] + b4·(s[i,t] × HK[i,t]) + X'γ + u[i] + λ[t] + e[i,t]

s[i,t] = PMA[i,t] / (PMA[i,t] + PMDN[i,t])
```

Two-way FE, SE Driscoll-Kraay, dilengkapi t(33) dan bootstrap klaster liar.

| Suku | Peran | Rujukan penopang |
|---|---|---|
| `log PMTB` | skala modal, tanpa restriksi CRS | Islam 1995; kaveat bias: Collard-Wexler & De Loecker 2016 |
| `log L` | tenaga kerja, elastisitas diestimasi | Islam 1995 |
| `s` | komposisi asing-domestik, bukan skala | Haskel dkk. 2007; Caves 1974 |
| `s × HK` | absorptive capacity, HK dipusatkan | Borensztein dkk. 1998; Su & Liu 2016 |
| `u[i]` | taraf produktivitas provinsi, bukan gangguan | Islam 1995 |
| `λ[t]` | guncangan agregat bersama | Muinelo-Gallo & Roca-Sagalés 2011 (sudah tercatat) |
| Satu tahap, bukan dua | menghindari ortogonalitas dan generated regressand | Wang & Schmidt 2002; Pagan 1984 |

**Kontrol `X`**, urut kekuatan penopang: modal manusia, kualitas TK sebagai penyesuai `L`,
akses listrik dan panjang jalan, keterbukaan `(ekspor+impor)/PDRB`, pangsa TK sektoral.

**Bad control, jangan dipakai:** internet, pelabuhan, bandara. Ketiganya kemungkinan terbentuk
*oleh* PMTB dalam 2017–2024, jadi duduk di jalur antara regresor dan hasil (Cinelli dkk. 2024).

**Spesifikasi pendamping**, terpisah, bukan tambahan suku:
`log PMDN ~ log PMA + log PDRB + u[i] + λ[t]` untuk crowding in/out. PMDN tidak pernah
dikurangkan dari ruas kiri (Farla dkk. 2016).

---

## 3. Tiga putusan yang mengubah desain

**Regresi tahap dua atas TFP gugur secara aljabar.** Two-way within-transform menyapu `u[i]`
bersama konstanta, menyisakan `e[i,t]` yang ortogonal terhadap `log PMTB` lewat normal equations
tahap satu. Koefisiennya nol persis — identitas, bukan temuan. Karena itu pertanyaan
"investasi → TFP" dijawab lewat `b3` di persamaan augmented, bukan lewat regresi terpisah.

**Rasio `(PMA+PMDN)/PMTB` tidak masuk persamaan produktivitas.** Galur 4 mengusulkannya
berdampingan dengan `log PMTB`; galur 3 menolaknya dan alasannya menang: PMTB muncul sebagai
penyebut rasio *dan* sebagai regresor, sehingga galat ukur PMTB masuk dua kali dan biasnya
searah. Rasio itu tetap hidup di Subbab 6.3 sebagai diagnostik cakupan, tempatnya sekarang.

**Bartik gugur, dan bukan karena N=34.** Kalau shift nasional per sektor dihitung dari data
realisasi PMA-PMDN yang sama, instrumennya mewarisi kegagalan exclusion restriction yang sudah
dipakai menolak instrumen langsung — hanya diencerkan lewat pembobotan pangsa. Periksa itu
lebih dulu; soal N datang belakangan.

---

## 4. Kalimat pembelaan, siap tempel ke metodologi

> Panel ini terdiri atas 34 provinsi dengan delapan titik tahun, dan panjang deret sebesar itu
> menutup jalan bagi spesifikasi dinamis: bias estimator within pada model berlag variabel terikat
> berorde 1/T sehingga tidak hilang seiring bertambahnya jumlah provinsi (Nickell, 1981), dan masih
> berarti bahkan pada deret sepanjang 30 tahun (Judson dan Owen, 1999). Estimator momen umum yang
> lazim menggantikannya justru lebih rapuh di sini, karena jumlah instrumen tumbuh kuadratik
> terhadap panjang deret sementara jumlah unit hanya 34, dan kelebihan instrumen melemahkan uji
> Hansen yang seharusnya menjaga validitasnya (Roodman, 2009). Autokorelasi orde satu pada residual
> karena itu ditangani di sisi inferensi, bukan dengan mengubah spesifikasi, karena pada panel
> wilayah autokorelasi merusak galat baku dan bukan titik estimasinya (Bertrand dkk., 2004); galat
> baku Driscoll-Kraay menyerap autokorelasi dan dependensi lintas provinsi sekaligus (Driscoll dan
> Kraay, 1998; Hoechle, 2007). Pembenaran Driscoll-Kraay bersifat asimtotik pada dimensi waktu yang
> membesar, sehingga pada delapan titik tahun nilai p yang dilaporkan adalah batas atas keyakinan,
> bukan ukuran yang sudah terkalibrasi (Vogelsang, 2012). Model efek tetap dua arah juga tidak
> memenuhi syarat identifikasi kausal ketika keluaran tahun sebelumnya mempengaruhi investasi tahun
> berjalan (Imai dan Kim, 2019), sehingga seluruh elastisitas dilaporkan sebagai asosiasi bersyarat.

---

## 5. Uji kekokohan

1. Bootstrap klaster liar atas klaster provinsi (Cameron & Miller 2015; Roodman dkk. 2019).
2. Sebaran t berderajat kebebasan 33, bukan normal baku (Vogelsang 2012).
3. Lag terdistribusi PMTB 2–3 tahun tanpa LDV, dilaporkan sebagai jumlah koefisien (Beck & Katz 2011).
4. Jackknife leave-one-out provinsi — ukuran ekonomi provinsi timpang (MacKinnon dkk. 2023).
5. Tiga jenis galat baku berdampingan, selisihnya dilaporkan apa adanya (Hoechle 2007).

---

## 6. Lubang yang harus ikut terbit

1. **Tidak ada satu paper pun yang membela arus GFCF sebagai K dalam fungsi produksi.** Dicari
   lewat Crossref, OpenAlex, dan WebSearch di enam galur; nihil. Olomola & Osinubi (2018) memakai
   PMTB sebagai K tanpa membahas biasnya — kelalaian, bukan pembenaran. Kalau laporan perlu
   menyatakan syaratnya, itu penalaran sendiri dan wajib ditandai begitu.
2. **Angka bias faktor-dua tidak boleh dipinjam.** Collard-Wexler & De Loecker mengukur stok yang
   salah ukur pada data perusahaan, bukan arus menggantikan stok pada panel provinsi.
3. **Arah kausalitas dibantah di jurnal utama.** Blomström dkk. (1996): pertumbuhan mendahului
   pembentukan modal. Bond dkk. (2010) menemukan sebaliknya untuk non-OECD. Tegangan ini
   ditampilkan, bukan diselesaikan sepihak.
4. **Limpahan horizontal rata-rata nol** di meta 1.205 taksiran (Iršová & Havránek 2013).
   Dengan 272 obs dan ~40 parameter FE, daya untuk efek kecil rendah. Nyatakan di muka.
5. **Subperiode pra/pasca COVID tanpa penopang metodologis.** Subbab 6.3 sudah memakainya.
   Pilihannya: cari lebih lama, atau laporkan sebagai eksplorasi tanpa klaim inferensial.
6. **Seluruh 74 ringkasan berstatus `abstrak-saja` atau `metadata-saja`.** Belum ada kutipan
   berhalaman. Kalau naskah butuh kutipan langsung, PDF-nya dibuka lebih dulu.

---

## 7. Prasyarat yang sudah terjawab

| Pertanyaan galur 4 | Jawaban dari `spesifikasi-model-tfp.md` |
|---|---|
| Stok modal tahap satu dibangun dari PMTB lewat PIM? | **Tidak.** §1: K = PMTB langsung. PIM hanya skenario E, pembanding dekomposisi |
| Tenaga kerja disesuaikan kualitas pendidikan? | **Tidak.** L = jumlah 17 kolom `*_TenagaKerja`, headcount. Modal manusia bebas jadi kontrol |
| Isi `X_it`? | daftar di bagian 2 |
| Rasio tingkat provinsi? | **belum dihitung.** Plafon 78% itu angka pulau; agregasi bisa menyembunyikan provinsi tunggal |
