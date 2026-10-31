"""
Isi basis data dari berkas kajian di repositori ini.

    python manage.py muat_data_awal

Sumber yang dibaca (relatif terhadap akar repositori):
  01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
  01 Data/TFP/processed/... Miliar Float (keamanan).xlsx       (indikator determinan TFP)
  01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx         (SE vintage B)
  01 Data/TFP/output/modal_riil/Dekomposisi Nasional.xlsx       (skenario A-F)
  01 Data/TFP/output/sectoral/13_Sectoral.xlsx                  (model M1-M4)
  01 Data/BKPM/processed/Dataset Provinsi(Database (62026)).csv  (rincian 6 provinsi Papua)
  01 Data/TFP/processed/panel_provinsi_tahun_2017_2025.csv       (PAD/APBD 6 provinsi Papua)
Bila berkas keluaran tidak ada, angka vintage yang dicatat di VINTAGE.md dipakai.
"""

from pathlib import Path

import pandas as pd
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from datapanel.models import Provinsi, VersiData
from datapanel.papua import pangsa_dari_berkas_tim
from datapanel.management.commands.muat_determinan import BERKAS as BERKAS_DETERMINAN
from datapanel.pembersihan import PipelinePembersihan, tambah_determinan
from datapanel.referensi import PROVINSI
from estimasi import twfe
from estimasi.models import KoefisienSektoral, SetParameter
from simulasi import templat
from simulasi.models import Skenario

DATASET = "01 Data/TFP/processed/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"
HASIL_ESTIMASI = "01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx"
DEKOMPOSISI = "01 Data/TFP/output/modal_riil/Dekomposisi Nasional.xlsx"
SEKTORAL = "01 Data/TFP/output/sectoral/13_Sectoral.xlsx"

KET_SKENARIO = {
    "A": ("A. Level dipaksa CRS (pembanding)", True),
    "B": ("B. Growth dinormalisasi CRS (pembanding)", True),
    "C": ("C. Pangsa pendapatan terukur (pembanding)", False),
    "D": ("D. Alfa baku 1/3 (pembanding)", True),
}
KET_SEKTORAL = {
    "M1": "M1: pooled, efek tahun, kendali dlogK dlogL",
    "M2": "M2: M1 + logTFP t-1 (UTAMA)",
    "M3": "M3: FE provinsi (konservatif)",
    "M4": "M4: tanpa kendali dlogK dlogL",
}


class Command(BaseCommand):
    help = "Muat provinsi, dataset awal, set parameter vintage, koefisien sektoral, paket bawaan (BAU sampai Bertahap), dan skenario contoh."

    def add_arguments(self, parser):
        parser.add_argument("--dataset", default=None, help="Path workbook dataset (bawaan: dataset agregasi tim).")
        parser.add_argument("--ulang", action="store_true", help="Hapus isi lama sebelum memuat.")

    def handle(self, *args, **opts):
        repo = Path(settings.REPO_DIR)
        if opts["ulang"]:
            Skenario.objects.all().delete()
            SetParameter.objects.all().delete()
            KoefisienSektoral.objects.all().delete()
            VersiData.objects.all().delete()

        for kode, nama, pulau in PROVINSI:
            Provinsi.objects.update_or_create(kode=kode, defaults={"nama": nama, "pulau": pulau})
        self.stdout.write(f"{len(PROVINSI)} provinsi.")

        versi = self._dataset(Path(opts["dataset"]) if opts["dataset"] else repo / DATASET)
        if (repo / BERKAS_DETERMINAN).exists():
            kol = tambah_determinan(versi, repo / BERKAS_DETERMINAN)
            self.stdout.write(f"Indikator determinan TFP: {len(kol)}.")
        if not versi.bisa_rinci_papua:
            pangsa = pangsa_dari_berkas_tim(repo)
            if pangsa:
                versi.pangsa_pemekaran = pangsa
                versi.save(update_fields=["pangsa_pemekaran"])
                self.stdout.write(f"Pangsa pemekaran Papua: {len(pangsa['kunci'])} variabel.")
            else:
                self.stdout.write(self.style.WARNING("Berkas rincian Papua tidak ditemukan; simulasi 34 provinsi."))
        utama = self._parameter(repo, versi)
        m2 = self._sektoral(repo)
        self._skenario(versi, utama, m2)
        self.stdout.write(self.style.SUCCESS("Selesai. Jalankan: python manage.py runserver"))

    def _dataset(self, path):
        if not path.exists():
            raise CommandError(f"Dataset tidak ditemukan: {path}")
        ada = VersiData.objects.filter(sumber=VersiData.Sumber.AWAL).first()
        if ada:
            self.stdout.write(f"Dataset awal sudah ada: {ada}")
            return ada
        opsi = {"imputasi": "tidak"}
        hasil = PipelinePembersihan(opsi).jalankan(str(path), path.name)
        if hasil.ada_galat:
            raise CommandError("Dataset gagal dibersihkan: " + "; ".join(t.pesan for t in hasil.temuan))
        versi = VersiData.objects.create(
            nama="Dataset agregasi provinsi (tim, Sep 2026)", sumber=VersiData.Sumber.AWAL,
            status=VersiData.Status.SIAP, nama_berkas=path.name, opsi_pembersihan=opsi,
            laporan=[t.ke_dict() for t in hasil.temuan], ringkasan=hasil.ringkasan())
        versi.simpan_dataframe(hasil.df, hasil.catatan)
        versi.aktifkan()
        self.stdout.write(f"Dataset awal: {versi.n_baris} baris, {versi.tahun_awal}-{versi.tahun_akhir}.")
        return versi

    def _parameter(self, repo, versi):
        b1, se1, b2, se2, n = 0.401899, 0.042356, 0.147184, 0.107323, 272
        if (repo / HASIL_ESTIMASI).exists():
            km = pd.read_excel(repo / HASIL_ESTIMASI, sheet_name="kandidat_model").set_index("spesifikasi")
            r = km.loc["ADHK_FE2W"]
            b1, se1, b2, se2, n = r.b1, r.se_b1, r.b2, r.se_b2, int(r.N)
        utama, _ = SetParameter.objects.update_or_create(
            nama="F. Two-way FE tanpa CRS, vintage B (UTAMA)",
            defaults=dict(sumber=SetParameter.Sumber.VINTAGE, b1=b1, se_b1=se1, b2=b2, se_b2=se2,
                          n_obs=n, tahun_awal=2017, tahun_akhir=2024, bawaan=True,
                          catatan="01 Data/TFP/output/modal_riil/Hasil Estimasi TFP.xlsx, ADHK_FE2W. "
                                  "Basis seri yang dikutip laporan (VINTAGE.md seri B)."))
        if (repo / DEKOMPOSISI).exists():
            sk = pd.read_excel(repo / DEKOMPOSISI, sheet_name="skenario")
            for _, r in sk.iterrows():
                huruf = str(r.skenario)[0]
                if huruf in KET_SKENARIO:
                    nama, crs = KET_SKENARIO[huruf]
                    SetParameter.objects.update_or_create(
                        nama=nama, defaults=dict(sumber=SetParameter.Sumber.VINTAGE, b1=r.b1, b2=r.b2, crs=crs,
                                                 catatan=f"Dekomposisi Nasional.xlsx: {r.dasar}. SE tidak tersedia; "
                                                         "Monte Carlo hanya memvariasikan TFP dan tenaga kerja."))
        SetParameter.objects.update_or_create(
            nama="F. 2017-2025, TK 2025 = LOCF (STATUS 20 Agustus)",
            defaults=dict(sumber=SetParameter.Sumber.VINTAGE, b1=0.475304, b2=0.135782, n_obs=306,
                          tahun_awal=2017, tahun_akhir=2025,
                          catatan="STATUS.md 20 Agustus 2026. Tenaga kerja 2025 disalin dari 2024, sehingga g_L 2025 "
                                  "nol di semua provinsi dan b1 tertarik naik. SE tidak dicatat."))
        est = twfe.estimasi(versi.ke_dataframe(), 2017, 2024)
        SetParameter.objects.update_or_create(
            nama="Estimasi ulang dataset awal, 2017-2024",
            defaults=dict(sumber=SetParameter.Sumber.ESTIMASI, versi_data=versi, tahun_awal=2017, tahun_akhir=2024,
                          b1=est["b1"], se_b1=est["se_b1"], b2=est["b2"], se_b2=est["se_b2"], n_obs=est["n_obs"],
                          catatan="Two-way FE pada isi workbook saat ini. Berbeda dari vintage B karena 4_ADHK dan "
                                  "9_ADHK direvisi setelah freeze."))
        self.stdout.write(f"Set parameter: {SetParameter.objects.count()} (estimasi ulang b1={est['b1']:.4f}, "
                          f"b2={est['b2']:.4f}).")
        return utama

    def _sektoral(self, repo):
        nilai = {
            "M1": (0.011734, 0.006809, 0.043365, 0.016057, 0.026463, 0.014052),
            "M2": (0.014856, 0.007341, 0.049468, 0.018076, 0.056430, 0.019838),
            "M3": (0.001226, 0.016148, 0.021858, 0.013075, 0.006265, 0.015209),
            "M4": (0.010669, 0.007444, 0.033827, 0.011881, 0.054856, 0.019691),
        }
        if (repo / SEKTORAL).exists():
            m = pd.read_excel(repo / SEKTORAL, sheet_name="Model")
            for mod in list(nilai):
                sub = m[m.model == mod].set_index("term")
                try:
                    nilai[mod] = tuple(float(sub.loc[t, c]) for t in ("inv_primer_l1", "inv_sekunder_l1", "inv_tva_l1")
                                       for c in ("b", "se"))
                except KeyError:
                    pass
        hasil = {}
        for mod, v in nilai.items():
            obj, _ = KoefisienSektoral.objects.update_or_create(
                nama=KET_SEKTORAL[mod],
                defaults=dict(primer=v[0], se_primer=v[1], sekunder=v[2], se_sekunder=v[3], tva=v[4], se_tva=v[5],
                              n_obs=238, bawaan=(mod == "M2"),
                              catatan="13_Sectoral.do, d log TFP pada pangsa investasi PMA+PMDN t-1; basis tersier "
                                      "lainnya; SE klaster provinsi. Presedensi waktu, bukan kausal."))
            hasil[mod] = obj
        self.stdout.write(f"Koefisien sektoral: {len(hasil)}.")
        return hasil["M2"]

    def _skenario(self, versi, utama, m2):
        if Skenario.objects.exists():
            return
        sks, galat = templat.buat_semua(versi, utama, m2)
        for g in galat:
            self.stdout.write(self.style.WARNING(g))
        self.stdout.write(f"{len(sks)} paket skenario bawaan dibuat dan dijalankan.")
        for g in templat.buat_contoh(versi, utama, m2) + templat.buat_rekomendasi():
            self.stdout.write(self.style.WARNING(g))
        self.stdout.write(f"{len(templat.CONTOH) + len(templat.REKOMENDASI)} skenario contoh dibuat.")
