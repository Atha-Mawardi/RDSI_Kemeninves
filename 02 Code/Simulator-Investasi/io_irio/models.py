import io

import numpy as np
from django.core.files.base import ContentFile
from django.db import models


class TabelIO(models.Model):
    """Satu tabel input-output tersimpan sebagai larik numpy (npz) di MEDIA_ROOT/io/."""

    class Jenis(models.TextChoices):
        IRIO = "irio", "IRIO 34 provinsi × 17 sektor"
        NASIONAL = "nasional", "IO nasional 17 sektor"
        PMTB = "pmtb", "Komposisi PMTB provinsi (IO provinsi 2016)"

    jenis = models.CharField(max_length=10, choices=Jenis.choices)
    tahun = models.PositiveSmallIntegerField()
    metode = models.CharField(max_length=16, blank=True, help_text="RAS atau CE (cross entropy)")
    berkas = models.FileField(upload_to="io/")
    sumber = models.CharField(max_length=400, blank=True)
    ringkasan = models.JSONField(default=dict, blank=True)
    dimuat = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["jenis", "-tahun", "metode"]
        constraints = [models.UniqueConstraint(fields=["jenis", "tahun", "metode"], name="io_unik")]
        verbose_name = "tabel IO"
        verbose_name_plural = "tabel IO"

    def __str__(self):
        return f"{self.get_jenis_display()} {self.tahun}{' ' + self.metode if self.metode else ''}"

    @property
    def label(self):
        return f"{self.tahun} {self.metode}".strip()

    def simpan_larik(self, **larik):
        buf = io.BytesIO()
        np.savez_compressed(buf, **larik)
        nama = f"{self.jenis}_{self.tahun}_{self.metode or 'x'}.npz"
        if self.berkas:
            self.berkas.delete(save=False)
        self.berkas.save(nama, ContentFile(buf.getvalue()), save=False)

    def larik(self):
        with self.berkas.open("rb") as f:
            d = np.load(io.BytesIO(f.read()), allow_pickle=False)
            return {k: d[k] for k in d.files}
