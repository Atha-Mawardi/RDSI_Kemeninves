# =============================================================================
# 06_benchmark elastisitas sumber berdoi.R
#
# Tabel pembanding elastisitas output modal (b1) dan tenaga kerja (b2), versi
# ketat: HANYA sumber ber-DOI yang terbit di jurnal bertelaah sejawat.
#
# Beda dengan 05_benchmark elastisitas lintas negara.R:
#   05 memuat enam baris dari sumber tanpa DOI (jurnal mahasiswa, SSRN tanpa
#      versi terbit, terbitan tanpa telaah sejawat). Berkas itu tetap ada
#      sebagai jejak pencarian.
#   06 membuang seluruh baris itu. Yang tersisa lebih sedikit dan bisa dikutip.
#
# DUA ATURAN MASUK, keduanya wajib:
#   1. Studi mengestimasi b1 DAN b2 tanpa memaksakan imbal hasil konstan, ATAU
#      mengestimasi b1 dan menguji imbal hasil secara eksplisit.
#   2. Sumber punya DOI dan terbit di jurnal bertelaah sejawat. Kertas kerja,
#      SSRN tanpa versi terbit, dan terbitan tanpa telaah sejawat tidak masuk.
#
# Sheet:
#   pasangan_lengkap  b1 dan b2 dua-duanya terestimasi bebas
#   b1_saja           b1 terestimasi, b2 tidak dilaporkan terpisah
#   catatan_sumber    status keterindeksan tiap jurnal
#
# Dibuat 2026-08-04. Litrev: 00 Docs/litrev-elastisitas-sumber-berdoi.md
# =============================================================================

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
})

if (!dir.exists("03 Output")) stop("Jalankan skrip ini dari folder 'TFP analysis (07182026)'.")

# -----------------------------------------------------------------------------
# 1. Pasangan lengkap: b1 dan b2 dua-duanya hasil estimasi
# -----------------------------------------------------------------------------
PASANGAN <- tribble(
  ~wilayah, ~b1, ~b2, ~unit, ~tahun_data, ~estimator, ~modal, ~doi, ~jurnal, ~source, ~notes,

  "Indonesia", 0.400, 0.191, "34 provinsi", "2017-2025",
  "two-way fixed effects", "arus PMTB", "(perhitungan sendiri)", "(kajian ini)",
  "Kajian ini (2026), 02 Code/01_estimasi tfp.R, log 03 Output/log_01_estimasi.txt",
  paste0("272 observasi; SE Driscoll-Kraay; jumlah b1+b2 = 0,591; CRS ditolak p<0,001; ",
         "objek yang sedang dinilai, bukan pembanding"),

  "China", 0.170, 0.230, "31 provinsi", "2000-2009",
  "LSDV efek provinsi + tahun", "arus investasi aset tetap",
  "10.1142/s1793969013500052", "China Economic Policy Review 2(2)",
  "Heshmati, A. & Su, B. (2013), Development and Sources of Labor Productivity in Chinese Provinces",
  paste0("310 observasi; jumlah b1+b2 = 0,40, penulis menyebutnya 'decreasing returns to scale'; ",
         "spesifikasinya memuat empat regresor tambahan di luar modal dan tenaga kerja; ",
         "angka: teks asli (versi IZA DP 6263, bagian 6.1); ",
         "KETERINDEKSAN SCOPUS BELUM DIPASTIKAN, jurnal terbitan World Scientific"),

  "China", 0.433, 0.190, "28 provinsi", "1982-2005",
  "two-way fixed effects", "stok",
  "10.1111/j.1746-1049.2009.00074.x", "The Developing Economies 47(1)",
  "Hao, R. & Wei, Z. (2009), Sources of Income Differences Across Chinese Provinces During the Reform Period",
  paste0("bentuk per-pekerja dengan suku ln L; jumlah b1+b2 = 0,623; uji F terhadap CRS = 31,67, ditolak kuat; ",
         "penulis menyebut 'high decreasing returns to scale'; tanpa modal manusia b1 = 0,430 dan b2 = 0,200; ",
         "varian CRS pada data sama memberi b1 = 0,481-0,503; angka: teks asli (versi CERDI E 2007.23); ",
         "jurnal terindeks Scopus"),

  "Indonesia", 0.4895, 0.3251, "26 provinsi", "1993-2000",
  "stochastic frontier translog", "arus pembentukan modal",
  "10.1080/00036840802599834", "Applied Economics 43(6)",
  "Margono, H., Sharma, S.C., Sylwester, K. & Al-Qalawi, U. (2011), Technical efficiency and productivity analysis in Indonesian provincial economies",
  paste0("elastisitas rata-rata seluruh provinsi, dihitung di titik rata-rata input; jumlah b1+b2 = 0,815; ",
         "jumlah per provinsi 0,677 (Jawa Timur) - 0,945 (Kalimantan Tengah); ",
         "b1 per provinsi 0,289 (NTT) - 0,769 (Jakarta); b2 per provinsi 0,076 (Jakarta) - 0,589 (Bengkulu); ",
         "angka: teks asli (versi kertas kerja SIU); jurnal terindeks Scopus"),

  "Eropa Tengah dan Timur", 0.452, 0.313, "10 negara", "1995-2014",
  "panel ECM koefisien heterogen", "stok",
  "10.1111/twec.12790", "The World Economy 42(7)",
  "Hagemejer, J. & Muck, J. (2019), Export-led growth and its determinants: Evidence from Central and Eastern European countries",
  paste0("elastisitas jangka panjang nilai tambah; jumlah b1+b2 = 0,765; ",
         "penulis menyatakan CRS 'strongly rejected in favour of decreasing return to scale'; ",
         "varian dengan tren waktu menaikkan b1 ke 0,712 dan b2 ke 0,411; ",
         "angka: teks asli (Tabel 5); jurnal terindeks Scopus"),

  "Asia Timur", 0.287, 0.660, "5 negara", "1990 (panel 1965-1990)",
  "frontier stokastik Bayesian, frontier per region", "stok nonresidensial (PWT 5.6)",
  "10.1080/07350015.2000.10524871", "Journal of Business & Economic Statistics 18(3)",
  "Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), Modeling the Sources of Output Growth in a Panel of Countries",
  paste0("median posterior untuk tahun 1990; nilai 1965: b1 = 0,338 dan b2 = 0,582; ",
         "RTS 0,922 (1965) dan 0,949 (1990), jadi imbal hasil MENURUN di kedua ujung periode; ",
         "Asia Timur = Hong Kong, Jepang, Korea, Filipina, Thailand; INDONESIA TIDAK MASUK SAMPEL; ",
         "elastisitas dibiarkan berubah menurut waktu dan berbeda antar region, CRS tidak dipaksakan; ",
         "prior dipusatkan di 1,0 tetapi tidak mengikat; angka dalam kurung di papernya IQR, bukan SE; ",
         "angka: teks asli (Tabel 1); jurnal terindeks Scopus"),

  "Amerika Latin", 0.346, 0.815, "10 negara", "1990 (panel 1965-1990)",
  "frontier stokastik Bayesian, frontier per region", "stok nonresidensial (PWT 5.6)",
  "10.1080/07350015.2000.10524871", "Journal of Business & Economic Statistics 18(3)",
  "Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), Modeling the Sources of Output Growth in a Panel of Countries",
  paste0("median posterior 1990; nilai 1965: b1 = 0,476 dan b2 = 0,587; ",
         "RTS 1,063 (1965) dan 1,161 (1990), satu-satunya region dengan imbal hasil MENINGKAT; ",
         "angka: teks asli (Tabel 1); jurnal terindeks Scopus"),

  "Negara industri Barat", 0.374, 0.592, "21 negara", "1990 (panel 1965-1990)",
  "frontier stokastik Bayesian, frontier per region", "stok nonresidensial (PWT 5.6)",
  "10.1080/07350015.2000.10524871", "Journal of Business & Economic Statistics 18(3)",
  "Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), Modeling the Sources of Output Growth in a Panel of Countries",
  paste0("median posterior 1990; nilai 1965: b1 = 0,273 dan b2 = 0,823; ",
         "RTS 1,096 (1965) turun ke 0,967 (1990), jadi berbalik dari meningkat ke menurun; ",
         "elastisitas modal NAIK dan elastisitas tenaga kerja TURUN sepanjang periode; ",
         "angka: teks asli (Tabel 1); jurnal terindeks Scopus"),

  "Afrika", 0.220, 0.671, "8 negara", "1990 (panel 1965-1990)",
  "frontier stokastik Bayesian, frontier per region", "stok nonresidensial (PWT 5.6)",
  "10.1080/07350015.2000.10524871", "Journal of Business & Economic Statistics 18(3)",
  "Koop, G., Osiewalski, J. & Steel, M.F.J. (2000), Modeling the Sources of Output Growth in a Panel of Countries",
  paste0("median posterior 1990; nilai 1965: b1 = 0,135 dan b2 = 0,830; ",
         "RTS 0,966 (1965) dan 0,893 (1990), imbal hasil menurun; ",
         "penulis mencatat frontier Afrika ditentukan oleh sedikit negara dan kurang terdefinisi baik; ",
         "angka: teks asli (Tabel 1); jurnal terindeks Scopus"),

  "OECD", 0.50, 0.60, "negara OECD", "1993-2004",
  "stochastic frontier translog", "stok",
  "10.1111/twec.12010", "The World Economy 36(6)",
  "Ghosh, S. & Mastromarco, C. (2013), Cross-border Economic Activities, Human Capital and Efficiency: A Stochastic Frontier Analysis for OECD Countries",
  paste0("elastisitas dihitung di titik rata-rata input seluruh panel; SE 0,05 dan 0,04, keduanya p<0,01; ",
         "jumlah b1+b2 = 1,09 dan CRS DITOLAK ke arah imbal hasil MENINGKAT (SE 0,04); ",
         "uji rasio kemungkinan menolak Cobb-Douglas demi translog; ",
         "penduga sama dengan Margono dkk. (frontier translog, elastisitas di titik rata-rata), jadi ",
         "pasangan pembanding metodologis yang paling bersih; angka: teks asli (Tabel 3); jurnal terindeks Scopus"),

  "Yordania", 0.3804, 0.6385, "negara", "1992-2019",
  "ARDL jangka panjang", "stok (pendekatan ICOR)",
  "10.35516/hum.2025.8061", "Dirasat: Human and Social Sciences",
  "Al-Bess, M.N. & Malawi, A.I. (2025), Food Security and Marginal Productivity of Labor in Jordan",
  paste0("ARDL(4,5,5), kedua koefisien bermakna p<0,01; jumlah b1+b2 = 1,019, praktis CRS; ",
         "stok modal diestimasi lewat ICOR karena datanya tidak tersedia; angka: teks asli (Tabel 10); ",
         "KETERINDEKSAN SCOPUS BELUM DIPASTIKAN")
)

# -----------------------------------------------------------------------------
# 2. b1 saja: imbal hasil diuji, tetapi b2 tidak dilaporkan terpisah
# -----------------------------------------------------------------------------
B1_SAJA <- tribble(
  ~wilayah, ~b1, ~unit, ~tahun_data, ~estimator, ~doi, ~jurnal, ~source, ~notes,

  "Italia", 0.40, "20 wilayah", "1970-2003", "CUP-FM (kointegrasi, dependensi lintas unit)",
  "10.1016/j.econmod.2008.07.014", "Economic Modelling 26(2)",
  "Costantini, M. & Destefanis, S. (2009), Cointegration analysis for cross-sectionally dependent panels: The case of regional production functions",
  paste0("data ekonomi agregat; koefisien modal 0,40 dan CRS DITOLAK ke arah imbal hasil menurun; ",
         "per sektor elastisitas modal 0,24 (konstruksi) - 0,31 (jasa); ",
         "penduga group-mean FMOLS memberi koefisien tenaga kerja jauh lebih tinggi sehingga menyiratkan imbal hasil meningkat di semua model; ",
         "angka: kutipan sekunder dari Eberhardt & Teal (2011), DOI 10.1111/j.1467-6419.2010.00624.x, belum dari teks aslinya; ",
         "jurnal terindeks Scopus"),

  "Spanyol", 0.6175, "17 wilayah", "1986-2010", "efek tetap, SE Driscoll-Kraay",
  "10.1111/pirs.12305", "Papers in Regional Science 97(4)",
  "Aray, H. (2017), More on decentralization and economic growth",
  paste0("pangsa modal terestimasi dari regresi pertumbuhan per pekerja efisien; ",
         "subperiode: 0,4604 (1986-1993), 0,4616 (1994-2001), 0,5486 (2002-2010); ",
         "penulis menyatakan hasilnya kokoh 'regardless of the assumption of constant returns to scale'; ",
         "angka: teks asli (Tabel 5); jurnal terindeks Scopus"),

  "Amerika Serikat", 0.44, "48 negara bagian", "1990-2007", "fixed effects + boneka tahun",
  "10.1111/j.1465-7287.2011.00282.x", "Contemporary Economic Policy 31(1)",
  "Yamarik, S. (2011), State-level capital and investment: Updates and implications",
  paste0("angka 0,44 dari model CRS DIRESTRIKSI; POLS 0,53, beda pertama 0,35, beda panjang 0,46; ",
         "uji Wald tidak menolak b1 = 1/3 pada FE; pada model TANPA restriksi koefisien tenaga kerja ",
         "naik dari 0,71 (beda pertama) ke 1,29 dan tidak bermakna (beda panjang), sehingga pasangan ",
         "b1-b2 tanpa restriksi tidak stabil dan tidak dilaporkan sebagai satu pasangan; ",
         "menjalankan uji galat ukur Griliches-Hausman dan tidak menemukan bukti kuat; ",
         "angka: teks asli; jurnal terindeks Scopus")
)

# -----------------------------------------------------------------------------
# 2b. Pembanding ASEAN: yang ada cuma taraf nasional atau sektoral
# -----------------------------------------------------------------------------
# Pencarian 2026-08-04 tidak menemukan satu pun studi ber-DOI yang mengestimasi
# fungsi produksi PANEL PROVINSI negara ASEAN selain Indonesia dengan kedua
# elastisitas bebas. Yang ada berhenti di taraf negara atau sektor manufaktur.
# Keduanya di bawah ini melaporkan imbal hasil, bukan pasangan b1-b2, sehingga
# tidak bisa masuk sheet pasangan_lengkap.
ASEAN <- tribble(
  ~cakupan, ~temuan_imbal_hasil, ~unit, ~tahun_data, ~doi, ~jurnal, ~source, ~notes,

  "Delapan ekonomi Asia Timur termasuk Indonesia, Malaysia, Filipina, Thailand",
  "imbal hasil meningkat di 5 dari 7 ekonomi; tertinggi Filipina 1,33; terendah Malaysia 0,991 (praktis konstan)",
  "9 sektor manufaktur per ekonomi", "1973-1998",
  "10.1111/j.1467-9957.2008.02096.x", "The Manchester School 77(2)",
  "Liao, H., Liu, X., Holmes, M. & Weyman-Jones, T. (2009), The impact of foreign R&D on total factor productivity in the East Asian manufacturing industry",
  paste0("frontier translog, elastisitas dihitung di titik rata-rata; tenaga kerja menyumbang paling besar ",
         "di semua ekonomi kecuali China, mencerminkan sifat padat karya manufaktur kawasan; ",
         "CAKUPANNYA MANUFAKTUR, bukan seluruh ekonomi, dan b1 serta b2 per ekonomi tidak terbaca dari ",
         "hasil pencarian, hanya jumlahnya; angka: teks asli (Tabel 2); jurnal terindeks Scopus"),

  "Lima pendiri ASEAN: Indonesia, Malaysia, Filipina, Singapura, Thailand",
  "tidak dilaporkan sebagai jumlah elastisitas",
  "negara", "1981-2003",
  "10.1111/j.1468-0106.2011.00545.x", "Pacific Economic Review 16(2)",
  "Lee, Y.H. & Cheng, M.Y. (2011), Catching-up and technological progress of the ASEAN economies",
  paste0("frontier translog Battese-Coelli; koefisien orde pertama ln L = 0,424 dan ln K = 0,110 (OLS), ",
         "0,408 dan 0,213 (MLE), koefisien modal TIDAK BERMAKNA di kedua model; ",
         "KOEFISIEN ORDE PERTAMA TRANSLOG BUKAN ELASTISITAS OUTPUT kecuali datanya dipusatkan di rata-rata, ",
         "dan papernya tidak menyatakan itu; karena itu angka di atas tidak boleh dibaca sebagai b1 dan b2; ",
         "angka: teks asli (Tabel 4); jurnal terindeks Scopus")
)

# -----------------------------------------------------------------------------
# 3. Catatan status sumber
# -----------------------------------------------------------------------------
CATATAN_SUMBER <- tribble(
  ~jurnal, ~doi, ~status_indeks, ~keterangan,
  "The Developing Economies", "10.1111/j.1746-1049.2009.00074.x", "terindeks", "Wiley, terindeks Scopus",
  "Applied Economics", "10.1080/00036840802599834", "terindeks", "Taylor & Francis, terindeks Scopus",
  "The World Economy", "10.1111/twec.12790", "terindeks", "Wiley, terindeks Scopus",
  "The World Economy", "10.1111/twec.12010", "terindeks", "Wiley, terindeks Scopus",
  "The Manchester School", "10.1111/j.1467-9957.2008.02096.x", "terindeks", "Wiley, terindeks Scopus",
  "Journal of Business & Economic Statistics", "10.1080/07350015.2000.10524871", "terindeks", "Taylor & Francis, terindeks Scopus, jurnal ekonometrika papan atas",
  "Pacific Economic Review", "10.1111/j.1468-0106.2011.00545.x", "terindeks", "Wiley, terindeks Scopus",
  "Economic Modelling", "10.1016/j.econmod.2008.07.014", "terindeks", "Elsevier, terindeks Scopus",
  "Papers in Regional Science", "10.1111/pirs.12305", "terindeks", "Wiley, terindeks Scopus",
  "Contemporary Economic Policy", "10.1111/j.1465-7287.2011.00282.x", "terindeks", "Wiley, terindeks Scopus",
  "China Economic Policy Review", "10.1142/s1793969013500052", "belum dipastikan", "World Scientific; ber-DOI Crossref, keterindeksan belum diperiksa",
  "Dirasat: Human and Social Sciences", "10.35516/hum.2025.8061", "belum dipastikan", "Universitas Yordania; ber-DOI Crossref, keterindeksan belum diperiksa",
  "(dibuang) Molodoy Uchenyy, SSRN, publishingindia, Ekonomski Institut", "-", "tanpa DOI atau tanpa telaah sejawat",
  "enam baris di berkas 05 yang tidak lolos aturan berkas ini; lihat 03 Output/Benchmarking Elastisitas Lintas Negara_0804.xlsx"
)

# -----------------------------------------------------------------------------
# 4. Rakit dan diagnostik
# -----------------------------------------------------------------------------
pasangan <- PASANGAN %>%
  mutate(jumlah_b1_b2 = round(b1 + b2, 3)) %>%
  arrange(b2) %>%
  select(wilayah, b1, b2, source, notes, jumlah_b1_b2, unit, tahun_data, estimator, modal, doi, jurnal)

b1_saja <- B1_SAJA %>%
  arrange(b1) %>%
  select(wilayah, b1, source, notes, unit, tahun_data, estimator, doi, jurnal)

stopifnot(all(nzchar(pasangan$source)), all(nzchar(pasangan$notes)))
stopifnot(all(nzchar(pasangan$doi)))

idn <- pasangan %>% filter(wilayah == "Indonesia", tahun_data == "2017-2025")
cat(sprintf("Pasangan lengkap: %d estimasi, %d di antaranya pembanding\n",
            nrow(pasangan), nrow(pasangan) - 1))
cat(sprintf("Baris b1 saja: %d | baris ASEAN: %d\n", nrow(b1_saja), nrow(ASEAN)))
cat(sprintf("Indonesia: b1 = %.3f, b2 = %.3f, jumlah = %.3f\n\n", idn$b1, idn$b2, idn$jumlah_b1_b2))

cat("Urut menurut b2:\n")
print(as.data.frame(pasangan %>% select(wilayah, b1, b2, jumlah_b1_b2, unit, tahun_data)))

pemb <- pasangan %>% filter(!(wilayah == "Indonesia" & tahun_data == "2017-2025"))
cat(sprintf("\nb2 pembanding: min %.3f | median %.3f | maks %.3f\n",
            min(pemb$b2), median(pemb$b2), max(pemb$b2)))
cat(sprintf("Jumlah b1+b2 pembanding: min %.3f | median %.3f | maks %.3f\n",
            min(pemb$jumlah_b1_b2), median(pemb$jumlah_b1_b2), max(pemb$jumlah_b1_b2)))
cat(sprintf("Pembanding dengan b2 di bawah 0,25: %d dari %d (%s)\n",
            sum(pemb$b2 < 0.25), nrow(pemb),
            paste(sprintf("%s %s", pemb$wilayah[pemb$b2 < 0.25], pemb$tahun_data[pemb$b2 < 0.25]),
                  collapse = "; ")))
cat(sprintf("Pembanding yang menolak CRS ke arah menurun: %d dari %d\n",
            sum(pemb$jumlah_b1_b2 < 0.9), nrow(pemb)))
cat(sprintf("Pembanding dengan b1 > b2 (modal lebih besar dari tenaga kerja): %d dari %d (%s)\n",
            sum(pemb$b1 > pemb$b2), nrow(pemb),
            paste(pemb$wilayah[pemb$b1 > pemb$b2], collapse = "; ")))

# -----------------------------------------------------------------------------
# 5. Tulis Excel
# -----------------------------------------------------------------------------
berkas <- file.path("03 Output", "Benchmarking Elastisitas Sumber Berdoi_0804.xlsx")
write.xlsx(
  list(pasangan_lengkap = pasangan, b1_saja = b1_saja, asean = ASEAN,
       catatan_sumber = CATATAN_SUMBER),
  file = berkas, overwrite = TRUE, colWidths = "auto"
)

# openxlsx 4.2.8 menulis relasi ke drawings yang berkasnya tidak ada; pembaca ketat gagal.
bersihkan_relasi <- function(path) {
  tmp <- file.path(tempdir(), "xlsxfix6"); unlink(tmp, recursive = TRUE); dir.create(tmp)
  utils::unzip(path, exdir = tmp)
  for (f in list.files(file.path(tmp, "xl", "worksheets", "_rels"), full.names = TRUE)) {
    x <- readLines(f, warn = FALSE)
    x <- gsub("<Relationship [^>]*(drawings/drawing|drawings/vmlDrawing)[^>]*/>", "", x)
    writeLines(x, f)
  }
  wd <- setwd(tmp); on.exit(setwd(wd), add = TRUE)
  utils::zip(path, files = list.files(".", recursive = TRUE, all.files = TRUE), flags = "-rq")
}
bersihkan_relasi(normalizePath(berkas))

cat(sprintf("\nDitulis: %s\n", berkas))
