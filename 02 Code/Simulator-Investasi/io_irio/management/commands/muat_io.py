import time

from django.core.management.base import BaseCommand

from io_irio import muat


class Command(BaseCommand):
    help = "Muat tabel IRIO 2017-2025, IO nasional 2021-2025 (RAS dan CE), dan komposisi PMTB provinsi 2016."

    def add_arguments(self, parser):
        parser.add_argument("--jenis", choices=["irio", "nasional", "pmtb"], action="append",
                            help="Batasi jenis yang dimuat (boleh berulang).")
        parser.add_argument("--tahun", type=int, action="append")

    def handle(self, *args, **o):
        jenis = set(o["jenis"] or ["irio", "nasional", "pmtb"])
        tahun = set(o["tahun"] or [])
        mulai = time.time()
        if "pmtb" in jenis:
            t = muat.muat_pmtb()
            self.stdout.write(f"  {t}: PMTB {t.ringkasan['pmtb_T']:,.0f} T")
        for nama, sumber, fungsi in (("irio", muat.berkas_irio, muat.muat_irio),
                                     ("nasional", muat.berkas_nasional, muat.muat_nasional)):
            if nama not in jenis:
                continue
            for th, metode, berkas in sumber():
                if tahun and th not in tahun:
                    continue
                t = fungsi(th, metode, berkas)
                self.stdout.write(f"  {t}: output {t.ringkasan['output_T']:,.0f} T, NTB {t.ringkasan['va_T']:,.0f} T")
        self.stdout.write(self.style.SUCCESS(f"Selesai dalam {time.time() - mulai:.0f} detik."))
