# Kajian Literatur: TFP dari Two-Way Fixed Effects & Pelaporan Skala Hasil Non-CRS (DRS)

*Untuk §2.1 (identifikasi TFP pada panel provinsi dengan FE) dan §3.2 (skala hasil / pilihan CRS vs. DRS).*
*Desain: Cobb-Douglas, panel 34 provinsi × 2017–2024, two-way FE (provinsi + tahun), SE Driscoll-Kraay. K = PMTB (proksi flow), L = tenaga kerja, Y = PDRB riil. Wald menolak CRS; b1+b2 = 0,591 (DRS). TFP = residual termasuk efek provinsi u_i.*

---

## 1. Rekomendasi Eksekutif

Mengestimasi TFP dengan mengontrol ruang dan waktu secara serentak (two-way fixed effects, TWFE) **defensibel secara metodologis**, dengan satu syarat desain yang justru sudah dipenuhi di sini: efek provinsi `u_i` **tidak dimasukkan sebagai regresor**, melainkan dibiarkan mengendap di **residual** dari mana TFP dipulihkan. Karena itu heterogenitas TFP antar-provinsi tetap terjaga (preserved), bukan tersapu (absorbed) — yang diserap FE tahun hanyalah guncangan makro/siklus bersama, dan yang diserap FE provinsi (bila dimasukkan ke regresor) hanyalah bias endogenitas input, bukan level produktivitas. Pelaporan hasil **non-CRS (DRS)** sebagai angka utama juga defensibel: memaksakan CRS pada elastisitas yang ditaksir bebas akan menaruh suku skala `(1 − b1 − b2)·g_input` secara keliru ke dalam residual, sehingga TFP terkontaminasi pertumbuhan input; dan penolakan uji CRS sendiri sebagian dapat merupakan artefak **attenuation bias** karena modal diproksi oleh *flow* (PMTB), bukan stok PIM. Rekomendasi: laporkan DRS sebagai baseline utama, sertakan varian CRS sebagai *robustness*, dan beri catatan eksplisit bahwa b1 yang rendah kemungkinan under-estimate karena kesalahan ukur modal.

---

## 2. Analisis

### 2.1 Apakah sah mengestimasi TFP sambil mengontrol ruang + waktu (province + year FE)?

**Kerangka dasar.** TFP adalah residual Solow — bagian pertumbuhan output yang tak terjelaskan oleh pertumbuhan input terukur (Solow, 1957). Hulten (2001) menegaskan residual ini bersifat *by construction* sebagai "measure of our ignorance": ia menyerap segala hal yang memengaruhi output di luar akumulasi K dan L — teknologi, efisiensi, kelembagaan, aglomerasi, kualitas input yang tak terukur. Justru karena residual inilah wadah heterogenitas produktivitas, **letak `u_i`** (di regresor atau di residual) menentukan apakah TFP regional terjaga atau hilang.

**Nuansa kunci — apakah FE "mengupas" keunikan regional yang seharusnya jadi TFP?** Kekhawatiran yang wajar: FE provinsi menyerap semua yang konstan-dalam-provinsi, sehingga tampak seolah "membuang" persis komponen keunikan daerah yang ingin ditangkap TFP. Kekhawatiran ini berlaku **hanya jika** `u_i` dijadikan variabel penjelas (di-*partial out* dari K dan L melalui within-transformation). Dalam desain ini tidak demikian: elastisitas `b1, b2` ditaksir, lalu

```
ln TFP_it = ln Y_it − b1·ln K_it − b2·ln L_it
```

dihitung sebagai **residual yang MASIH memuat `u_i`** (plus komponen waktu-varian). Artinya perbedaan level produktivitas antar-provinsi tetap hidup di dalam ukuran TFP — yang terjadi bukan penyerapan, melainkan **dekomposisi**: FE tahun (`λ_t`) menyerap guncangan makro bersama (siklus, term-of-trade, kebijakan nasional) agar tidak salah-atribusi ke input; sedangkan variasi antar-provinsi yang stabil tetap menjadi bagian TFP. Ini konsisten dengan praktik empiris produktivitas regional yang memperlakukan efek daerah sebagai **estimand** (yang ingin diukur), bukan *nuisance* yang dibuang (Combes, Duranton & Gobillon, 2008): mereka justru mengekstraksi efek tetap wilayah sebagai ukuran produktivitas lokal dan menunjukkan bahwa gagal mengontrol heterogenitas (komposisi) membiaskan estimasi hingga ~100%.

**Peran ganda FE dalam identifikasi elastisitas.** Griliches & Mairesse (1998) mendokumentasikan bahwa memasukkan FE ke dalam regresi produksi berguna untuk meredam simultanitas/endogenitas input (produktivitas tak-teramati berkorelasi dengan pilihan input), tetapi sekaligus berbiaya: within-transformation "membuang sinyal" dan menekan koefisien modal (lihat 2.2). Pemisahan peran menjadi penting: gunakan FE untuk **membersihkan estimasi elastisitas**, bukan untuk mendefinisikan TFP. Selama TFP dipulihkan sebagai residual pasca-estimasi (bukan sebagai selisih setelah mem-*partial-out* `u_i`), TWFE dan pelestarian heterogenitas TFP tidak bertentangan.

**Pandangan tandingan.** Sebagian literatur growth-accounting regional lebih memilih **tidak** memasang FE provinsi sama sekali dan membiarkan keunikan daerah "apa adanya" di data level, karena setiap kali `u_i` masuk regresor ada risiko meng-over-absorb variasi cross-section yang tipis (T pendek, K nyaris konstan dalam provinsi). Pendekatan level ini transparan tetapi rentan bias endogenitas dan salah-atribusi guncangan bersama ke input. Untuk Indonesia, studi TFP provinsi umumnya menempuh jalur non-parametrik (DEA-Malmquist) yang memisahkan technical change dari efficiency change tanpa memaksakan bentuk fungsional dan menemukan skala hasil bervariasi antar-provinsi (Kataoka 2020 — lihat Daftar Sumber), memberi konteks bahwa DRS pada sebagian daerah adalah temuan yang lazim, bukan anomali. **Posisi yang diambil:** TWFE dengan TFP-sebagai-residual-termasuk-`u_i` adalah kompromi yang tepat — menikmati koreksi endogenitas/guncangan bersama tanpa mengorbankan heterogenitas TFP.

### 2.2 Apakah melaporkan hasil non-CRS (DRS) defensibel vs. memaksakan CRS?

**(a) Skala hasil dalam growth accounting dan suku `(1 − b1 − b2)·g_input`.** Dalam dekomposisi Cobb-Douglas,

```
g_Y = b1·g_K + b2·g_L + g_TFP
```

hanya berlaku "bersih" bila skala hasil sesuai elastisitas yang dipakai. Jika elastisitas sejati menjumlah ke `μ = b1 + b2 ≠ 1` tetapi analis **memaksakan** CRS (mengganti b1,b2 dengan bobot yang berjumlah 1, mis. dari factor shares), maka residual yang terukur akan menyerap suku skala sisa:

```
g_TFP(terukur) = g_TFP(sejati) + (1 − μ)·g_input
```

Dengan μ = 0,591 (DRS), suku `(1 − 0,591) = 0,409` dikalikan pertumbuhan input akan **membocorkan pertumbuhan input ke dalam TFP** — persis kesalahan yang ingin dihindari growth accounting. Barro (1999) menegaskan bahwa formula growth accounting standar menyandarkan bobot input pada asumsi CRS dan persaingan sempurna; bila asumsi itu gagal (skala non-konstan, markup, spillover), residual menjadi campuran technical change + efek skala, sehingga interpretasi "TFP = kemajuan teknologi" tidak lagi lurus. Memakai elastisitas hasil-estimasi (DRS) menjaga residual bebas dari kontaminasi suku skala — argumen kuat untuk melaporkan DRS sebagai baseline.

**(b) Argumen attenuation: CRS yang ditolak bisa artefak mismeasurement.** Penolakan Wald atas CRS **tidak otomatis** berarti teknologi benar-benar DRS. Griliches & Mairesse (1998) menunjukkan bahwa dalam praktik panel, koefisien modal kerap "rendah dan sering tak signifikan, serta estimasi returns-to-scale rendah tak masuk akal", terutama karena **modal diukur dengan galat besar** dan variasinya dalam-unit tipis; within/FE-transformation memperparah dengan membuang sinyal, menghasilkan **attenuation bias** yang menarik b1 ke bawah. Konsekuensi mekanis: `μ = b1 + b2` ikut turun, sehingga uji CRS lebih mudah ditolak **ke arah DRS** semata karena b1 under-estimate. Dalam desain ini masalah diperkuat karena K diproksi oleh **PMTB, sebuah flow (investasi tahunan)**, bukan stok modal hasil Perpetual Inventory Method — flow lebih *volatile*, lebih rawan galat ukur relatif terhadap jasa modal sejati, dan tidak mencerminkan akumulasi kapital yang seharusnya masuk fungsi produksi. Karena itu b1 ≈ (bagian dari) 0,591 sangat mungkin merupakan **batas bawah**, dan DRS yang terukur sebagian bersifat **statistik, bukan struktural**. Basu & Fernald (1997) memberi paralel penting: estimasi produksi AS kerap menghasilkan *apparent decreasing returns* yang bertolak-belakang dengan bukti laba ekonomi kecil, dan mereka menjelaskannya lewat agregasi atas unit heterogen serta persoalan pengukuran — bukan bukti DRS teknologi sejati. Implikasi untuk laporan: sajikan DRS sebagai temuan utama **tetapi** beri caveat tegas bahwa sebagian penolakan CRS dapat berasal dari attenuation akibat proksi flow.

**(c) Kapan literatur menyarankan memaksakan vs. membebaskan restriksi RTS.**
- **Bebaskan (estimasi RTS, laporkan DRS)** bila: (i) tujuan utamanya *mengukur* skala hasil itu sendiri, (ii) asumsi persaingan sempurna/factor-share meragukan, atau (iii) analis ingin residual bebas kontaminasi suku skala. Basu & Fernald (1997) dan Barro (1999) sama-sama menempatkan RTS sebagai objek yang harus **diuji**, bukan diasumsikan, ketika data memungkinkan.
- **Paksakan CRS** bila: (i) elastisitas hasil-estimasi tak dapat dipercaya karena galat ukur/kolinearitas/T pendek — sehingga bobot dari **factor shares** (dual approach, Barro 1999; Hulten 2001) lebih andal daripada koefisien regresi yang bias; (ii) kerangka teori menuntut CRS agar residual dapat diinterpretasi sebagai kemajuan teknologi Hicks-netral (Solow, 1957); atau (iii) diperlukan komparabilitas dengan growth-accounting resmi (mis. BPS/APO) yang lazim mengasumsikan CRS.
- **Praktik yang disarankan di sini:** laporkan **DRS sebagai primer** (konsisten dengan uji Wald dan menjaga residual bersih), tampilkan **CRS sebagai robustness**, dan dokumentasikan bahwa selisih keduanya sebagian mencerminkan attenuation proksi PMTB. Ini memberi pembaca kebijakan dua angka dengan interpretasi yang jujur, bukan satu angka yang menyembunyikan asumsi.

---

## Daftar Sumber

1. **Solow, R. M. (1957).** "Technical Change and the Aggregate Production Function." *The Review of Economics and Statistics*, 39(3), 312–320. DOI: 10.2307/1926047. https://www.jstor.org/stable/1926047 — *Definisi residual TFP; kerangka Cobb-Douglas dengan CRS & Hicks-netral.*

2. **Hulten, C. R. (2001).** "Total Factor Productivity: A Short Biography." Dalam C. R. Hulten, E. R. Dean & M. J. Harper (Eds.), *New Developments in Productivity Analysis* (Studies in Income and Wealth, Vol. 63, hlm. 1–54). University of Chicago Press. NBER Working Paper No. 7471. DOI: 10.3386/w7471. https://www.nber.org/papers/w7471 — *Residual sebagai "measure of ignorance"; syarat interpretasi; dual/factor-share approach.*

3. **Barro, R. J. (1999).** "Notes on Growth Accounting." *Journal of Economic Growth*, 4(2), 119–137. DOI: 10.1023/A:1009828704275. https://link.springer.com/article/10.1023/A:1009828704275 — *Bobot input bergantung asumsi CRS + persaingan sempurna; spillover/increasing returns; dual approach lewat factor prices.*

4. **Basu, S., & Fernald, J. G. (1997).** "Returns to Scale in U.S. Production: Estimates and Implications." *Journal of Political Economy*, 105(2), 249–283. DOI: 10.1086/262073. https://www.journals.uchicago.edu/doi/10.1086/262073 — *"Apparent decreasing returns" sebagai artefak agregasi/pengukuran, bukan DRS struktural.*

5. **Griliches, Z., & Mairesse, J. (1998).** "Production Functions: The Search for Identification." Dalam S. Strøm (Ed.), *Econometrics and Economic Theory in the 20th Century: The Ragnar Frisch Centennial Symposium* (hlm. 169–203). Cambridge University Press. Versi kerja: NBER Working Paper No. 5067. DOI: 10.3386/w5067. https://www.nber.org/papers/w5067 — *Koefisien modal rendah & RTS rendah karena galat ukur modal + within-transformation membuang sinyal (attenuation bias).*

6. **Combes, P.-P., Duranton, G., & Gobillon, L. (2008).** "Spatial Wage Disparities: Sorting Matters!" *Journal of Urban Economics*, 63(2), 723–742. DOI: 10.1016/j.jue.2007.04.004. https://www.sciencedirect.com/science/article/abs/pii/S0094119007000630 — *Efek tetap wilayah sebagai estimand produktivitas lokal; gagal mengontrol heterogenitas membiaskan estimasi hingga ~100%.*

7. **Driscoll, J. C., & Kraay, A. C. (1998).** "Consistent Covariance Matrix Estimation with Spatially Dependent Panel Data." *The Review of Economics and Statistics*, 80(4), 549–560. DOI: 10.1162/003465398557825. https://direct.mit.edu/rest/article/80/4/549/57104 — *Justifikasi SE Driscoll-Kraay: robust terhadap dependensi cross-sectional/spasial & serial pada panel.*

8. **Kataoka, M. (2020).** "Total factor productivity change in Indonesia's provincial economies for 1990–2015: Malmquist productivity index approach." *Letters in Spatial and Resource Sciences*, 13(3), 233–243. DOI: 10.1007/s12076-020-00256-z. https://link.springer.com/article/10.1007/s12076-020-00256-z — *Konteks TFP provinsi Indonesia; skala hasil & technical change bervariasi antar-daerah (DRS lazim di sebagian provinsi).* **Koreksi 2026-07-21:** entri ini sebelumnya keliru ditulis sebagai "Purwono dkk. (2020)" dengan judul/DOI yang sebenarnya milik Kataoka; paper Purwono, Yasin & Mubin (2020) yang asli membahas konvergensi inflasi, bukan TFP.

---
*Catatan verifikasi: kedelapan sumber di atas telah dicek eksistensi & metadatanya (judul, jurnal, volume/halaman, DOI/URL) via penelusuran akademik pada Juli 2026. Nomor DOI Solow (2307/1926047) adalah pengenal JSTOR standar untuk artikel tersebut.*
