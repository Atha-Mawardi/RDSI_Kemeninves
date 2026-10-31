import io
import json

import numpy as np
import openpyxl
import pandas as pd
from django.test import TestCase

from . import diagnosa, excel_data
from .models import Provinsi, VersiData
from .pembersihan import PipelinePembersihan, gabungkan_pembaruan, ke_angka
from .referensi import KODE_PROVINSI, PROVINSI, cari_kode_provinsi


def _xlsx(baris, kepala, judul=None):
    wb = openpyxl.Workbook()
    ws = wb.active
    if judul:
        ws.append([judul])
        ws.append([])
    ws.append(kepala)
    for b in baris:
        ws.append(b)
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    buf.name = "uji.xlsx"
    return buf


class KeAngkaTest(TestCase):
    def test_format_campuran(self):
        s, n_teks, n_gagal = ke_angka(pd.Series(["1.234,5", "1,234.5", " ", "-", 12, None, "2.500.000", "abc"]))
        self.assertEqual(s.iloc[0], 1234.5)
        self.assertEqual(s.iloc[1], 1234.5)
        self.assertTrue(np.isnan(s.iloc[2]) and np.isnan(s.iloc[3]) and np.isnan(s.iloc[5]))
        self.assertEqual(s.iloc[4], 12.0)
        self.assertEqual(s.iloc[6], 2_500_000.0)
        self.assertEqual(n_gagal, 1)


class ReferensiTest(TestCase):
    def test_nama_dan_alias(self):
        self.assertEqual(cari_kode_provinsi("Sumatra Utara")[0], 12)
        self.assertEqual(cari_kode_provinsi("DKI Jakarta")[0], 31)
        self.assertEqual(cari_kode_provinsi("Papua Tengah")[0], 94)
        self.assertEqual(len(KODE_PROVINSI), 34)


class PipelineTest(TestCase):
    def _jalankan(self, berkas, **opsi):
        return PipelinePembersihan({"imputasi": "tidak", **opsi}).jalankan(berkas, berkas.name)

    def test_header_tergeser_teks_kosong_dan_pemekaran_papua(self):
        kepala = ["Provinsi", "Tahun", "9_ADHK", "PMA_1"]
        baris = [
            ["Aceh", 2023, "150.000,5", " "],
            ["Aceh", 2024, 155000, "-"],
            ["Papua", 2024, 100, 1],
            ["Papua Tengah", 2024, 20, 2],
            ["Papua Pegunungan", 2024, 5, 3],
        ]
        h = self._jalankan(_xlsx(baris, kepala, judul="Tabel uji"))
        self.assertFalse(h.ada_galat)
        self.assertAlmostEqual(h.df.loc[(11, 2023), "PDRB_ADHK"], 150000.5)
        self.assertTrue(np.isnan(h.df.loc[(11, 2023), "PMA"]))
        self.assertAlmostEqual(h.df.loc[(94, 2024), "PDRB_ADHK"], 125)
        self.assertAlmostEqual(h.df.loc[(94, 2024), "PMA"], 6)

    def test_pad_rupiah_dikonversi_ke_miliar(self):
        kepala = ["kode", "tahun", "PAD_Prov2"]
        baris = [[k, 2024, 2_500_000_000_000 + k] for k in KODE_PROVINSI]
        h = self._jalankan(_xlsx(baris, kepala))
        self.assertAlmostEqual(h.df.loc[(11, 2024), "PAD"], 2500.000000011, places=6)

    def test_imputasi_interpolasi_dicatat(self):
        kepala = ["kode", "tahun", "PDRB_ADHK"]
        baris = [[11, 2020, 100000], [11, 2021, None], [11, 2022, 120000]]
        h = self._jalankan(_xlsx(baris, kepala), imputasi="interpolasi")
        self.assertAlmostEqual(h.df.loc[(11, 2021), "PDRB_ADHK"], 110000)
        self.assertIn("imputasi", h.catatan[(11, 2021)]["PDRB_ADHK"])

    def test_gabungkan_pembaruan(self):
        idx = pd.MultiIndex.from_tuples([(11, 2023), (11, 2024)], names=["kode", "tahun"])
        induk = pd.DataFrame({"PDRB_ADHK": [100.0, 110.0], "PMA": [1.0, 2.0]}, index=idx)
        idx2 = pd.MultiIndex.from_tuples([(11, 2024), (11, 2025)], names=["kode", "tahun"])
        baru = pd.DataFrame({"PDRB_ADHK": [111.0, 120.0]}, index=idx2)
        df, cat = gabungkan_pembaruan(induk, {}, baru, {})
        self.assertEqual(df.loc[(11, 2024), "PDRB_ADHK"], 111.0)
        self.assertEqual(df.loc[(11, 2024), "PMA"], 2.0)
        self.assertEqual(df.loc[(11, 2025), "PDRB_ADHK"], 120.0)
        self.assertEqual(df.loc[(11, 2023), "PDRB_ADHK"], 100.0)
        self.assertIn("diperbarui", cat[(11, 2024)]["PDRB_ADHK"])

    def test_putaran_excel_dataset(self):
        idx = pd.MultiIndex.from_product([KODE_PROVINSI, [2023, 2024]], names=["kode", "tahun"])
        rng = np.random.default_rng(1)
        df = pd.DataFrame({"PDRB_ADHK": rng.uniform(1e4, 1e6, len(idx)),
                           "PMA": rng.uniform(1, 1e4, len(idx))}, index=idx)
        isi = excel_data.tulis_dataset(df, {(11, 2024): {"PMA": "imputasi: uji"}}, [], judul="uji")
        berkas = io.BytesIO(isi)
        berkas.name = "putaran.xlsx"
        h = self._jalankan(berkas)
        pd.testing.assert_frame_equal(h.df[["PDRB_ADHK", "PMA"]], df, check_exact=False, rtol=1e-12)


class PapuaTest(TestCase):
    """Pangsa pemekaran, koreksi pergeseran baris, dan pemecahan 34 -> 38 provinsi."""

    KEL = (91, 92, 94, 95, 96, 97)

    def _rincian(self, geser=False):
        from .referensi import KODE_SEKTOR
        va = {91: 50.0, 92: 25.0, 94: 52.0, 95: 19.0, 96: 105.0, 97: 14.0}
        baris = []
        for kd in self.KEL:
            r = {"kode": kd, "tahun": 2024, "PDRB_ADHK": va[kd], "PMTB_ADHK": va[kd] / 4, "PMA": float(kd == 96)}
            r.update({f"VA_{s}": va[kd] / len(KODE_SEKTOR) for s in KODE_SEKTOR})
            baris.append(r)
        df = pd.DataFrame(baris).set_index(["kode", "tahun"])
        if geser:
            # pola berkas BKPM: total tiap baris baru milik baris baru sebelumnya (berputar)
            baru = [92, 94, 95, 96, 97]
            nilai = df.loc[[(k, 2024) for k in baru], ["PDRB_ADHK", "PMTB_ADHK"]].to_numpy()
            df.loc[[(k, 2024) for k in baru], ["PDRB_ADHK", "PMTB_ADHK"]] = np.roll(nilai, 1, axis=0)
        return df

    def test_koreksi_geser_melintasi_keluarga(self):
        from .papua import hitung_pangsa
        p = hitung_pangsa(self._rincian(geser=True))
        self.assertEqual(len(p["catatan"]), 1)
        benar = hitung_pangsa(self._rincian())
        self.assertEqual(p["kunci"]["PMTB_ADHK"], benar["kunci"]["PMTB_ADHK"])
        self.assertAlmostEqual(p["kunci"]["PMTB_ADHK"]["96"]["2024"], 105 / (52 + 19 + 105 + 14), places=5)

    def test_pecah_menjaga_total_dan_backcast(self):
        from .papua import hitung_pangsa, pecah
        p = hitung_pangsa(self._rincian())
        idx = pd.MultiIndex.from_product([[11, 91, 94], [2022, 2023, 2024, 2025]], names=["kode", "tahun"])
        df = pd.DataFrame({"PDRB_ADHK": np.arange(12, dtype=float) + 100, "PMA": 10.0}, index=idx)
        d38 = pecah(df, p)
        self.assertEqual(sorted(d38.index.get_level_values("kode").unique()), [11, 91, 92, 94, 95, 96, 97])
        pd.testing.assert_frame_equal(d38.groupby(level="tahun").sum(), df.groupby(level="tahun").sum())
        tengah = d38.xs(96, level="kode")["PDRB_ADHK"] / df.xs(94, level="kode")["PDRB_ADHK"]
        self.assertTrue(np.allclose(tengah, 105 / 190))  # pangsa 2024 dipakai mundur dan maju
        self.assertTrue(np.allclose(d38.xs(96, level="kode")["PMA"], 10.0))  # PMA keluarga Papua hanya di Tengah

    def test_pipeline_lipat_nama_meski_kode_induk(self):
        kepala = ["Code_Prov", "Prov", "Year", "9_ADHK", "PMA_1"]
        baris = [[91, "Papua Barat", 2024, 50000, 5], [91, "Papua Barat Daya", 2024, 25000, 1],
                 [94, "Papua", 2024, 52000, 1], [94, "Papua Tengah", 2024, 105000, 20]]
        hasil = PipelinePembersihan({"imputasi": "tidak"}).jalankan(_xlsx(baris, kepala), "uji.xlsx")
        self.assertEqual(hasil.df.loc[(91, 2024), "PDRB_ADHK"], 75000)
        self.assertEqual(hasil.df.loc[(94, 2024), "PDRB_ADHK"], 157000)
        p = hasil.pangsa_pemekaran("uji")
        self.assertAlmostEqual(p["kunci"]["PMA"]["96"]["2024"], 20 / 21, places=5)

    def test_indikator_determinan_rata_dilipat_dan_disalin(self):
        from .papua import hitung_pangsa, pecah
        kepala = ["Code_Prov", "Prov", "Year", "9_ADHK", "Educ_Prov", "Road_Prov_National"]
        baris = [[94, "Papua", 2024, 52000, 9.0, 100], [94, "Papua Tengah", 2024, 105000, 7.0, 300]]
        hasil = PipelinePembersihan({"imputasi": "tidak"}).jalankan(_xlsx(baris, kepala), "uji.xlsx")
        self.assertEqual(hasil.df.loc[(94, 2024), "LAMA_SEKOLAH"], 8.0)
        self.assertEqual(hasil.df.loc[(94, 2024), "JALAN_NASIONAL"], 400)
        idx = pd.MultiIndex.from_product([[94], [2024]], names=["kode", "tahun"])
        df = pd.DataFrame({"PDRB_ADHK": [190.0], "LAMA_SEKOLAH": [8.0], "JALAN_NASIONAL": [400.0]}, index=idx)
        d38 = pecah(df, hitung_pangsa(self._rincian()))
        self.assertTrue(np.allclose(d38["LAMA_SEKOLAH"], 8.0))
        self.assertAlmostEqual(d38["JALAN_NASIONAL"].sum(), 400.0)


class KelengkapanGridPivotTest(TestCase):
    """Diagnostik kelengkapan, penyunting grid (versi turunan), dan sumber data pivot."""

    @classmethod
    def setUpTestData(cls):
        for kode, nama, pulau in PROVINSI:
            Provinsi.objects.create(kode=kode, nama=nama, pulau=pulau)
        idx = pd.MultiIndex.from_product([KODE_PROVINSI, range(2020, 2025)], names=["kode", "tahun"])
        rng = np.random.default_rng(2)
        df = pd.DataFrame({"PDRB_ADHK": rng.uniform(1e4, 1e6, len(idx)), "PMTB_ADHK": rng.uniform(1e3, 1e5, len(idx)),
                           "PMA": rng.uniform(1, 1e4, len(idx)), "PMDN": rng.uniform(1, 1e4, len(idx)),
                           "LAMA_SEKOLAH": rng.uniform(6, 12, len(idx))}, index=idx)
        df.loc[(11, 2022), "PMA"] = -5.0
        cls.versi = VersiData.objects.create(nama="uji", status=VersiData.Status.SIAP)
        cls.versi.simpan_dataframe(df)

    def test_periksa_menandai_nilai_negatif(self):
        cek = {c["label"]: c for c in diagnosa.periksa(self.versi)}
        neg = cek["Nilai negatif di PDRB, PMTB, PMA, PMDN"]
        self.assertEqual(neg["status"], "periksa")
        self.assertEqual((neg["rincian"][0]["kode"], neg["rincian"][0]["tahun"]), (11, 2022))
        self.assertEqual(cek["Provinsi tanpa baris sama sekali"]["status"], "ok")
        m = diagnosa.matriks(self.versi)
        self.assertEqual(m["tahun"], [2020, 2021, 2022, 2023, 2024])

    def test_grid_membuat_versi_turunan(self):
        url = f"/data/{self.versi.pk}/grid/"
        ubah = {"perubahan": [{"kode": 11, "tahun": 2025, "var": "PDRB_ADHK", "nilai": 123.5},
                              {"kode": 11, "tahun": 2022, "var": "PMA", "nilai": 7}]}
        r = self.client.post(url, json.dumps(ubah), content_type="application/json", HTTP_HOST="localhost")
        self.assertEqual(r.status_code, 400)                     # alasan wajib
        r = self.client.post(url, json.dumps({**ubah, "alasan": "uji"}), content_type="application/json",
                             HTTP_HOST="localhost")
        self.assertEqual(r.status_code, 200, r.content)
        baru = VersiData.objects.get(pk=r.json()["pk"])
        self.assertEqual((baru.induk_id, baru.sumber, baru.tahun_akhir), (self.versi.pk, VersiData.Sumber.EDIT, 2025))
        df, cat = baru.ke_dataframe(dengan_catatan=True)
        self.assertEqual(df.loc[(11, 2025), "PDRB_ADHK"], 123.5)
        self.assertEqual(df.loc[(11, 2022), "PMA"], 7)
        self.assertIn("uji", cat[(11, 2022)]["PMA"])
        self.versi.refresh_from_db()
        self.assertEqual(self.versi.tahun_akhir, 2024)
        self.assertEqual(self.versi.ke_dataframe().loc[(11, 2022), "PMA"], -5.0)

    def test_pivot_data_dan_xlsx(self):
        r = self.client.get(f"/pivot/data/?sumber=panel&versi={self.versi.pk}", HTTP_HOST="localhost")
        self.assertEqual(r.status_code, 200)
        p = r.json()
        self.assertEqual([d["kunci"] for d in p["dimensi"]], ["pulau", "provinsi", "tahun"])
        self.assertEqual(len(p["data"]), 34 * 5)
        ukuran = {u["kunci"]: u for u in p["ukuran"]}
        self.assertEqual(ukuran["LAMA_SEKOLAH"]["agregat"], "rata")
        self.assertEqual(ukuran["LAMA_SEKOLAH"]["grup"], "Determinan TFP: Pendidikan")
        self.assertEqual(self.client.get("/pivot/data/?sumber=x", HTTP_HOST="localhost").status_code, 400)
        isi = {"judul": "uji", "header": [["Provinsi", "2024"]], "digit": 1, "berkas": "uji",
               "baris": [{"label": "Sumatera", "jenis": "grup", "tingkat": 0, "nilai": [10.0]},
                         {"label": "Aceh", "jenis": "", "tingkat": 1, "nilai": [10.0]},
                         {"label": "Total", "jenis": "total", "tingkat": 0, "nilai": [10.0]}]}
        r = self.client.post("/pivot/xlsx/", json.dumps(isi), content_type="application/json", HTTP_HOST="localhost")
        self.assertEqual(r.status_code, 200)
        wb = openpyxl.load_workbook(io.BytesIO(r.content))
        self.assertIn("Aceh", [c.value.strip() if isinstance(c.value, str) else c.value
                               for row in wb.active.iter_rows() for c in row])
