from django.db import models


class SetParameter(models.Model):
    """Elastisitas fungsi produksi log Y = a_i + d_t + b1 log K + b2 log L.

    K adalah arus PMTB harga konstan, bukan stok kapital; b1 karena itu batas
    bawah dan residual menyerap sebagian kontribusi modal (lihat VINTAGE.md).
    """

    class Sumber(models.TextChoices):
        VINTAGE = "vintage", "Vintage kajian TFP"
        ESTIMASI = "estimasi", "Estimasi ulang di aplikasi"
        MANUAL = "manual", "Isian manual"

    nama = models.CharField(max_length=120)
    sumber = models.CharField(max_length=10, choices=Sumber.choices, default=Sumber.MANUAL)
    b1 = models.FloatField("elastisitas modal (b1)")
    se_b1 = models.FloatField("SE b1", default=0)
    b2 = models.FloatField("elastisitas tenaga kerja (b2)")
    se_b2 = models.FloatField("SE b2", default=0)
    crs = models.BooleanField("dipaksa CRS", default=False)
    n_obs = models.PositiveIntegerField(null=True, blank=True)
    tahun_awal = models.PositiveSmallIntegerField(null=True, blank=True)
    tahun_akhir = models.PositiveSmallIntegerField(null=True, blank=True)
    versi_data = models.ForeignKey("datapanel.VersiData", null=True, blank=True,
                                   on_delete=models.SET_NULL, related_name="set_parameter")
    catatan = models.TextField(blank=True)
    # spesifikasi estimasi (tahun dikecualikan, provinsi, modal, efek tahun) dan keluaran lengkapnya
    spesifikasi = models.JSONField(default=dict, blank=True)
    hasil = models.JSONField(default=dict, blank=True)
    bawaan = models.BooleanField(default=False)
    dibuat = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-bawaan", "sumber", "nama"]
        verbose_name_plural = "set parameter"

    def __str__(self):
        return f"{self.nama} (b1={self.b1:.3f}, b2={self.b2:.3f})"

    @property
    def rts(self):
        return self.b1 + self.b2


class KoefisienSektoral(models.Model):
    """Koefisien model pertumbuhan residual pada pangsa investasi t-1 (13_Sectoral.do).

    Basis yang dihilangkan: tersier lainnya. Koefisien = perubahan d log TFP
    per tahun bila seluruh pangsa investasi digeser dari tersier lainnya ke
    kelompok yang disebut. Presedensi waktu lintas provinsi, bukan kausal.
    """

    nama = models.CharField(max_length=120)
    primer = models.FloatField(default=0)
    se_primer = models.FloatField(default=0)
    sekunder = models.FloatField(default=0)
    se_sekunder = models.FloatField(default=0)
    tva = models.FloatField("tersier bernilai tambah", default=0)
    se_tva = models.FloatField("SE tersier bernilai tambah", default=0)
    n_obs = models.PositiveIntegerField(null=True, blank=True)
    catatan = models.TextField(blank=True)
    bawaan = models.BooleanField(default=False)

    class Meta:
        ordering = ["-bawaan", "nama"]
        verbose_name_plural = "koefisien sektoral"

    def __str__(self):
        return self.nama

    def sebagai_dict(self):
        return {"primer": self.primer, "sekunder": self.sekunder, "tva": self.tva, "tlain": 0.0}

    def se_dict(self):
        return {"primer": self.se_primer, "sekunder": self.se_sekunder, "tva": self.se_tva, "tlain": 0.0}


class SetDeterminan(models.Model):
    """Koefisien determinan TFP per indikator (lihat `estimasi.determinan`).

    Efek dipakai sebagai pergeseran level log TFP di atas tren historis: koefisien x perubahan indikator (SD).
    """

    nama = models.CharField(max_length=120)
    # [{kode, pilar, label, satuan, transformasi, koef, se, sd, rata}]
    indikator = models.JSONField(default=list)
    catatan = models.TextField(blank=True)
    bawaan = models.BooleanField(default=False)
    dibuat = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-bawaan", "nama"]
        verbose_name_plural = "set determinan"

    def __str__(self):
        return self.nama

    @classmethod
    def utama(cls):
        return cls.objects.filter(bawaan=True).first() or cls.objects.first()
