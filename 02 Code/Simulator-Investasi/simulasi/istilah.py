"""Glosarium istilah hasil skenario: nama, keterangan satu baris (boleh kosong), dan definisi lengkap (tooltip)."""

ISTILAH = {
    "bn": ("Laju tanpa penambahan investasi", "",
           "Laju PDRB riil rata-rata per tahun bila hanya ada investasi dasar (tren historis atau rencana), "
           "tanpa investasi tambahan."),
    "xn": ("Laju dengan penambahan investasi", "",
           "Laju PDRB riil rata-rata per tahun dengan investasi dasar ditambah investasi tambahan, belanja modal "
           "APBD tambahan, realokasi tenaga kerja, dan bonus komposisi sektor."),
    "sasaran": ("Sasaran", "target laju", "Target laju PDRB riil rata-rata per tahun."),
    "selisih_pp": ("Selisih (pp)", "laju dengan penambahan − sasaran",
                   "Laju dengan penambahan investasi dikurangi sasaran, dalam poin persen. Negatif = belum mencapai "
                   "sasaran."),
    "a1": ("Investasi Dasar", "PMA+PMDN tanpa tambahan",
           "Realisasi PMA+PMDN dasar: tren historis atau rencana yang diisi di skenario."),
    "a2": ("Investasi Tambahan", "di atas investasi dasar",
           "Investasi PMA+PMDN tambahan di atas investasi dasar yang diuji dalam skenario."),
    "a2_kum": ("Total Investasi Tambahan", "di atas investasi dasar",
               "Jumlah investasi tambahan selama horizon skenario, triliun Rp nominal."),
    "a2_alok": ("Investasi Tambahan", "bagian provinsi",
                "Investasi tambahan yang dialokasikan ke provinsi ini, jumlah selama horizon."),
    "keb": ("Kebutuhan tambahan", "di atas investasi dasar",
            "PMA+PMDN di atas investasi dasar yang dibutuhkan agar PDRB mengikuti jalur sasaran, jumlah selama "
            "horizon (perkiraan tengah), triliun Rp nominal."),
    "keb_kum": ("Kebutuhan kumulatif", "di atas investasi dasar",
                "PMA+PMDN di atas investasi dasar yang dibutuhkan provinsi agar mencapai sasarannya, jumlah selama "
                "horizon."),
    "keb_inv": ("Kebutuhan investasi", "total PMA+PMDN dibutuhkan",
                "Realisasi PMA+PMDN total yang dibutuhkan pada tahun itu agar PDRB berada di jalur sasaran."),
    "p80": ("Kebutuhan batas aman", "termasuk cadangan risiko",
            "Kebutuhan tambahan bila ingin lebih aman terhadap ketidakpastian: investasi sebesar ini cukup untuk "
            "mencapai sasaran pada 8 dari 10 kemungkinan hasil simulasi (persentil 80)."),
    "selisih_t": ("Selisih", "kebutuhan − investasi tambahan",
                  "Kebutuhan tambahan dikurangi total investasi tambahan. Positif = investasi tambahan masih "
                  "kurang; negatif = investasi tambahan melebihi kebutuhan."),
    "tfp_akhir": ("Indeks TFP akhir", "produktivitas, dasar = 100",
                  "Indeks produktivitas total faktor (TFP) pada tahun target, dengan tahun dasar = 100."),
    "dt_pp": ("Dari determinan TFP", "pp/thn",
              "Bagian laju dengan penambahan investasi yang berasal dari perubahan determinan TFP yang sudah terasa "
              "sampai tahun target (setelah jeda)."),
    "peluang": ("Peluang", "laju ≥ sasaran",
                "Bagian simulasi Monte Carlo yang laju PDRB-nya mencapai atau melampaui sasaran."),
    "p10_p90": ("P10–P90", "rentang laju dengan penambahan",
                "Rentang laju dengan penambahan investasi yang memuat 80% hasil simulasi Monte Carlo."),
    "g_tfp": ("g TFP", "laju produktivitas", "Laju TFP per tahun yang diasumsikan untuk provinsi."),
    "g_tk": ("g TK", "laju tenaga kerja", "Laju tenaga kerja per tahun yang diasumsikan untuk provinsi."),
    "g_pmtb_keb": ("g PMTB dibutuhkan", "laju modal agar capai sasaran",
                   "Laju PMTB riil per tahun yang dibutuhkan agar PDRB mencapai sasaran."),
    "pct_pdrb": ("% PDRB/thn", "kebutuhan per tahun ÷ PDRB",
                 "Kebutuhan tambahan per tahun dibagi PDRB nominal tahun dasar."),
    "x_apbd": ("× belanja APBD", "kebutuhan per tahun ÷ APBD",
               "Kebutuhan tambahan per tahun dibagi belanja APBD provinsi; 1 = sebesar seluruh belanja APBD."),
    "tren_inv": ("Tren inv.", "PMA+PMDN bila tren berlanjut", "Realisasi PMA+PMDN bila tren historis berlanjut."),
    "apbd_tambah": ("APBD tambahan", "belanja modal daerah ekstra",
                    "Belanja modal APBD tambahan yang diasumsikan skenario."),
    "tfp_bn": ("TFP tanpa penambahan", "indeks, dasar = 100", "Indeks TFP tanpa penambahan investasi."),
    "tfp_xn": ("TFP dengan penambahan", "indeks, dasar = 100",
               "Indeks TFP dengan penambahan investasi, termasuk bonus komposisi sektor."),
}
