"""
Isi ulang pangsa pemekaran Papua sebuah versi data dari berkas kajian.

    python manage.py muat_pangsa_papua              # versi aktif
    python manage.py muat_pangsa_papua --versi 3
"""

from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from datapanel.models import VersiData
from datapanel.papua import pangsa_dari_berkas_tim, ringkasan


class Command(BaseCommand):
    help = "Hitung pangsa enam provinsi Papua dari berkas BKPM/DJPK dan simpan ke versi data."

    def add_arguments(self, parser):
        parser.add_argument("--versi", type=int, default=None, help="pk versi data (bawaan: versi aktif).")

    def handle(self, *args, **opts):
        versi = VersiData.objects.filter(pk=opts["versi"]).first() if opts["versi"] else VersiData.aktif()
        if not versi:
            raise CommandError("Versi data tidak ditemukan.")
        pangsa = pangsa_dari_berkas_tim(Path(settings.REPO_DIR))
        if not pangsa:
            raise CommandError("Berkas rincian Papua tidak ditemukan.")
        versi.pangsa_pemekaran = pangsa
        versi.save(update_fields=["pangsa_pemekaran"])
        for c in pangsa["catatan"]:
            self.stdout.write(self.style.WARNING(c))
        r = ringkasan(pangsa)
        self.stdout.write(f"{versi}: pangsa {len(pangsa['kunci'])} variabel.")
        for b in r["baris"]:
            nilai = ", ".join(f"{k} {v:.1%}" for k, (v, _t) in zip(r["kolom"], b["nilai"]) if v is not None)
            self.stdout.write(f"  {b['nama']}: {nilai}")
