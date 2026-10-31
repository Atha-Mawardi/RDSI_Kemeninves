from django.conf import settings
from django.db import models


class Skenario(models.Model):
    """Satu set asumsi yang bisa dijalankan ulang terhadap versi data dan parameter tertentu."""

    class ModeSasaran(models.TextChoices):
        SERAGAM = "seragam", "Seragam: tiap provinsi tumbuh sebesar sasaran"
        PROPORSIONAL = "proporsional", "Proporsional: pertahankan selisih laju historis, nasional = sasaran"
        MANUAL = "manual", "Manual per provinsi (lembar asumsi provinsi)"

    class ModeLaju(models.TextChoices):
        HISTORIS = "historis", "Historis per provinsi"
        NASIONAL = "nasional", "Satu nilai untuk semua provinsi"
        MANUAL = "manual", "Manual per provinsi"

    class ModePmtb(models.TextChoices):
        HISTORIS = "historis", "Tren historis per provinsi"
        NASIONAL = "nasional", "Satu laju nasional"

    class Alokasi(models.TextChoices):
        KEBUTUHAN = "kebutuhan", "Menurut kebutuhan untuk sasaran (jarak terbesar dapat lebih banyak)"
        PDRB = "pdrb", "Menurut pangsa PDRB"
        INVESTASI = "investasi", "Menurut pangsa realisasi PMA+PMDN 3 tahun terakhir"
        MANUAL = "manual", "Bobot manual per provinsi"

    class Tujuan(models.TextChoices):
        C = "C", "Industri pengolahan (C)"
        TVA = "tva", "Jasa bernilai tambah (H, J, K, MN)"

    class Status(models.TextChoices):
        BARU = "baru", "Belum dijalankan"
        SELESAI = "selesai", "Hasil terkini"
        USANG = "usang", "Asumsi berubah, perlu dijalankan ulang"
        GAGAL = "gagal", "Gagal dijalankan"

    class Kelompok(models.TextChoices):
        BAWAAN = "bawaan", "Estimasi tim RDSI"
        KUSTOM = "kustom", "Kustom (disimpan pengguna)"

    nama = models.CharField(max_length=120)
    singkat = models.CharField("nama singkat", max_length=24, blank=True,
                               help_text="Label pendek untuk grafik dan tabel; kosong = nama.")
    kelompok = models.CharField(max_length=8, choices=Kelompok.choices, default=Kelompok.KUSTOM)
    templat = models.CharField("kode paket asal", max_length=4, blank=True)
    deskripsi = models.TextField(blank=True)
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.BARU)
    versi_data = models.ForeignKey("datapanel.VersiData", on_delete=models.PROTECT, related_name="skenario")
    set_parameter = models.ForeignKey("estimasi.SetParameter", on_delete=models.PROTECT,
                                      related_name="skenario", verbose_name="set elastisitas")
    koef_sektoral = models.ForeignKey("estimasi.KoefisienSektoral", null=True, blank=True,
                                      on_delete=models.SET_NULL, related_name="skenario",
                                      verbose_name="koefisien komposisi sektor",
                                      help_text="Kosongkan untuk mematikan saluran komposisi sektor.")
    set_determinan = models.ForeignKey("estimasi.SetDeterminan", null=True, blank=True,
                                       on_delete=models.SET_NULL, related_name="skenario",
                                       verbose_name="koefisien determinan TFP",
                                       help_text="Kosong = set determinan bawaan.")

    tahun_dasar = models.PositiveSmallIntegerField(default=2025)
    tahun_target = models.PositiveSmallIntegerField(default=2029)
    hist_awal = models.PositiveSmallIntegerField("awal jendela historis", default=2018)
    hist_akhir = models.PositiveSmallIntegerField("akhir jendela historis", default=2024)
    kecualikan_2020 = models.BooleanField("keluarkan 2020 (COVID) dari rata-rata historis", default=False)
    pecah_papua = models.BooleanField(
        "rinci Papua menjadi enam provinsi (38 provinsi)", default=True,
        help_text="Papua Barat dan Papua dipecah menurut pangsa data 2023-2025; sebelum 2023 pangsa "
                  "tahun pertama dipakai mundur. Estimasi elastisitas tetap 34 provinsi.")

    sasaran = models.FloatField("sasaran pertumbuhan nasional (%/tahun)", default=8.0)
    mode_sasaran = models.CharField(max_length=14, choices=ModeSasaran.choices, default=ModeSasaran.SERAGAM)
    lambda_proporsional = models.FloatField("porsi selisih historis yang dipertahankan", default=1.0)

    mode_tfp = models.CharField("asumsi laju TFP", max_length=10, choices=ModeLaju.choices,
                                default=ModeLaju.HISTORIS)
    tfp_nasional = models.FloatField("laju TFP bila satu nilai (%/tahun)", default=2.0)
    faktor_tfp = models.FloatField("pengali laju TFP (1 = tren)", default=1.0,
                                   help_text="Mengalikan laju TFP historis: 1 = sesuai tren, 0,5 = separuhnya, 1,1 = 10% lebih cepat.")
    mode_tk = models.CharField("asumsi laju tenaga kerja", max_length=10, choices=ModeLaju.choices,
                               default=ModeLaju.HISTORIS)
    tk_nasional = models.FloatField("laju tenaga kerja bila satu nilai (%/tahun)", default=2.0)
    mode_pmtb = models.CharField("tren PMTB dasar", max_length=10, choices=ModePmtb.choices,
                                 default=ModePmtb.HISTORIS)
    g_pmtb_nasional = models.FloatField("laju PMTB nasional (%/tahun)", null=True, blank=True,
                                        help_text="Kosong = rata-rata historis nasional.")
    g_investasi = models.FloatField("laju tren PMA+PMDN nominal (%/tahun)", null=True, blank=True,
                                    help_text="Kosong = rata-rata historis nasional.")
    inflasi_pmtb = models.FloatField("inflasi deflator PMTB (%/tahun)", null=True, blank=True,
                                     help_text="Kosong = rata-rata historis.")

    pass_through = models.FloatField("pass-through realisasi ke PMTB", default=1.0,
                                     help_text="Bagian rupiah realisasi PMA+PMDN yang menjadi PMTB.")
    rasio_realisasi = models.FloatField("rasio realisasi terhadap rencana", default=1.0)
    apbd_persen = models.FloatField("belanja modal APBD tambahan (% belanja APBD)", default=0.0)
    pass_through_apbd = models.FloatField("pass-through belanja APBD ke PMTB", default=1.0)

    a1 = models.JSONField("investasi dasar: rencana realisasi dasar (triliun Rp/tahun)", default=dict, blank=True)
    a2 = models.JSONField("investasi tambahan (triliun Rp/tahun)", default=dict, blank=True)
    alokasi_a2 = models.CharField("alokasi investasi tambahan", max_length=10, choices=Alokasi.choices,
                                  default=Alokasi.KEBUTUHAN)
    komposisi_a2 = models.JSONField("komposisi sektor investasi tambahan", null=True, blank=True)

    realokasi_pp = models.FloatField("realokasi tenaga kerja dari pertanian (poin persen)", default=0.0)
    tujuan_realokasi = models.CharField(max_length=4, choices=Tujuan.choices, default=Tujuan.C)

    n_simulasi = models.PositiveIntegerField("jumlah simulasi Monte Carlo", default=500)
    skala_se = models.FloatField("pengali SE parameter", default=1.0)
    volatilitas_tfp = models.FloatField("pengali volatilitas TFP tahunan", default=1.0)
    seed = models.PositiveIntegerField(default=2026)

    override_provinsi = models.JSONField(default=dict, blank=True)
    # {"sasaran" | "faktor_tfp" | "g_investasi": {tahun: nilai}}; tahun kosong = nilai konstan skenario
    jalur = models.JSONField("jalur per tahun", default=dict, blank=True)
    # [{"nama", "jenis": tfp|pdrb|tk|investasi, "tahun", "besar" (%), "persistensi" (0-1), "cakupan"}]
    kejutan = models.JSONField(default=list, blank=True)
    # {pilar: {"dz" (SD), "jeda", "penuh" (thn), "porsi" (% investasi tambahan), "biaya" (T Rp per +1 SD),
    #          "cakupan", "indikator": {kode: dz}}}; perbaikan di atas tren historis
    determinan = models.JSONField("determinan TFP", default=dict, blank=True)
    # Paket bawaan: {nama field: nilai} yang diubah pengguna; diwariskan ke paket turunannya saat dibangun ulang
    penyesuaian = models.JSONField(default=dict, blank=True)

    dibuat = models.DateTimeField(auto_now_add=True)
    diubah = models.DateTimeField(auto_now=True)
    dibuat_oleh = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL)

    class Meta:
        ordering = ["-diubah"]
        verbose_name_plural = "skenario"

    def __str__(self):
        return self.nama

    @property
    def label(self):
        return self.singkat or self.nama

    @property
    def bawaan(self):
        return self.kelompok == self.Kelompok.BAWAAN

    @property
    def tahun_proyeksi(self):
        return list(range(self.tahun_dasar + 1, self.tahun_target + 1))

    @property
    def rinci_papua(self):
        return self.pecah_papua and self.versi_data.bisa_rinci_papua

    @property
    def kode_provinsi(self):
        from datapanel.referensi import KODE_PROVINSI, KODE_PROVINSI_38
        return KODE_PROVINSI_38 if self.rinci_papua else KODE_PROVINSI


class HasilSkenario(models.Model):
    skenario = models.OneToOneField(Skenario, on_delete=models.CASCADE, related_name="hasil")
    dihitung = models.DateTimeField(auto_now=True)
    durasi_detik = models.FloatField(default=0)
    data = models.JSONField(default=dict)

    def __str__(self):
        return f"Hasil {self.skenario}"
