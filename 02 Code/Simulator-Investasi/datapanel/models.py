import pandas as pd
from django.conf import settings
from django.db import models, transaction


class Provinsi(models.Model):
    kode = models.PositiveSmallIntegerField(primary_key=True)
    nama = models.CharField(max_length=60)
    pulau = models.CharField(max_length=20)

    class Meta:
        ordering = ["kode"]
        verbose_name_plural = "provinsi"

    def __str__(self):
        return self.nama


class VersiData(models.Model):
    """Satu dataset panel provinsi-tahun hasil pembersihan.

    Versi tidak pernah disunting di tempat oleh unggahan: pembaruan selalu
    membuat versi turunan dengan `induk` menunjuk versi asalnya, sehingga
    skenario lama tetap bisa direproduksi.
    """

    class Status(models.TextChoices):
        DRAF = "draf", "Draf (menunggu konfirmasi)"
        SIAP = "siap", "Siap dipakai"
        AKTIF = "aktif", "Aktif"
        ARSIP = "arsip", "Arsip"
        GAGAL = "gagal", "Gagal validasi"

    class Sumber(models.TextChoices):
        AWAL = "awal", "Dataset awal tim"
        UNGGAH = "unggah", "Unggahan baru"
        PEMBARUAN = "pembaruan", "Pembaruan atas versi lain"
        EDIT = "edit", "Suntingan manual"

    nama = models.CharField(max_length=120)
    keterangan = models.TextField(blank=True)
    sumber = models.CharField(max_length=12, choices=Sumber.choices, default=Sumber.UNGGAH)
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.DRAF)
    induk = models.ForeignKey("self", null=True, blank=True, on_delete=models.SET_NULL,
                              related_name="turunan")
    berkas = models.FileField(upload_to="unggahan/%Y%m/", blank=True)
    nama_berkas = models.CharField(max_length=255, blank=True)
    opsi_pembersihan = models.JSONField(default=dict, blank=True)
    laporan = models.JSONField(default=list, blank=True)
    ringkasan = models.JSONField(default=dict, blank=True)
    tahun_awal = models.PositiveSmallIntegerField(null=True, blank=True)
    tahun_akhir = models.PositiveSmallIntegerField(null=True, blank=True)
    n_baris = models.PositiveIntegerField(default=0)
    # pangsa enam provinsi Papua di keluarga induknya; lihat datapanel/papua.py
    pangsa_pemekaran = models.JSONField(default=dict, blank=True)
    dibuat = models.DateTimeField(auto_now_add=True)
    dibuat_oleh = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL)

    class Meta:
        ordering = ["-dibuat"]
        verbose_name_plural = "versi data"

    def __str__(self):
        return f"{self.nama} (#{self.pk})"

    @classmethod
    def aktif(cls):
        return cls.objects.filter(status=cls.Status.AKTIF).first()

    @property
    def bisa_dipakai(self):
        return self.status in (self.Status.SIAP, self.Status.AKTIF)

    @property
    def lengkap_untuk_simulasi(self):
        return bool(self.ringkasan.get("lengkap_untuk_simulasi"))

    @transaction.atomic
    def aktifkan(self):
        VersiData.objects.filter(status=self.Status.AKTIF).exclude(pk=self.pk).update(
            status=self.Status.SIAP)
        self.status = self.Status.AKTIF
        self.save(update_fields=["status"])

    @property
    def bisa_rinci_papua(self):
        return bool((self.pangsa_pemekaran or {}).get("kunci"))

    def ke_dataframe_38(self):
        """Panel 38 provinsi: Papua Barat dan Papua dipecah menurut pangsa pemekaran."""
        from .papua import pecah
        return pecah(self.ke_dataframe(), self.pangsa_pemekaran)

    def ke_dataframe(self, dengan_catatan=False):
        """Panel lebar ber-indeks (kode, tahun) dengan kolom kode kanonik."""
        baris, catatan = [], {}
        for kode, tahun, nilai, cat in self.observasi.values_list(
                "provinsi_id", "tahun", "nilai", "catatan"):
            baris.append({"kode": kode, "tahun": tahun, **nilai})
            if cat:
                catatan[(kode, tahun)] = cat
        df = pd.DataFrame(baris)
        if df.empty:
            df = pd.DataFrame(columns=["kode", "tahun"])
        df = df.set_index(["kode", "tahun"]).sort_index().astype(float)
        return (df, catatan) if dengan_catatan else df

    @transaction.atomic
    def simpan_dataframe(self, df, catatan=None):
        """Ganti seluruh observasi versi ini dengan isi `df` (indeks kode, tahun)."""
        catatan = catatan or {}
        self.observasi.all().delete()
        objek = []
        for (kode, tahun), row in df.iterrows():
            nilai = {k: float(v) for k, v in row.items() if pd.notna(v)}
            objek.append(Observasi(versi=self, provinsi_id=int(kode), tahun=int(tahun),
                                   nilai=nilai, catatan=catatan.get((kode, tahun), {})))
        Observasi.objects.bulk_create(objek, batch_size=500)
        tahun = df.index.get_level_values("tahun") if len(df) else []
        self.tahun_awal = int(min(tahun)) if len(tahun) else None
        self.tahun_akhir = int(max(tahun)) if len(tahun) else None
        self.n_baris = len(objek)
        self.save(update_fields=["tahun_awal", "tahun_akhir", "n_baris"])


class Observasi(models.Model):
    versi = models.ForeignKey(VersiData, on_delete=models.CASCADE, related_name="observasi")
    provinsi = models.ForeignKey(Provinsi, on_delete=models.PROTECT)
    tahun = models.PositiveSmallIntegerField()
    # kode kanonik -> nilai; kunci yang tidak ada berarti kosong
    nilai = models.JSONField(default=dict)
    # kode kanonik -> catatan pembersihan (imputasi, lonjakan, diperbarui)
    catatan = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["provinsi_id", "tahun"]
        constraints = [
            models.UniqueConstraint(fields=["versi", "provinsi", "tahun"], name="obs_unik"),
        ]
        verbose_name_plural = "observasi"

    def __str__(self):
        return f"{self.provinsi_id}-{self.tahun} (versi {self.versi_id})"
