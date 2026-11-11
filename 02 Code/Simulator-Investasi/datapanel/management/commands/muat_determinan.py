from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from datapanel.models import VersiData
from datapanel.pembersihan import tambah_determinan

BERKAS = "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar Float (keamanan).xlsx"


class Command(BaseCommand):
    help = "Isi indikator determinan TFP (sheet Analisis Luaran 2) ke versi data, tanpa mengubah variabel lain."

    def add_arguments(self, parser):
        parser.add_argument("--versi", type=int, help="pk versi data; default = versi aktif")
        parser.add_argument("--berkas", help=f"workbook tim; default = {BERKAS}")

    def handle(self, *args, **opts):
        versi = VersiData.objects.filter(pk=opts["versi"]).first() if opts["versi"] else VersiData.aktif()
        if not versi:
            raise CommandError("Versi data tidak ditemukan.")
        berkas = Path(opts["berkas"]) if opts["berkas"] else Path(settings.REPO_DIR) / BERKAS
        if not berkas.exists():
            raise CommandError(f"Berkas tidak ditemukan: {berkas}")
        kol = tambah_determinan(versi, berkas)
        self.stdout.write(f"{versi}: {len(kol)} indikator determinan TFP diisi.")
