import unittest
from dataclasses import replace

import numpy as np
from django.conf import settings
from django.test import SimpleTestCase, TestCase
from django.urls import reverse

from datapanel.models import Provinsi, VersiData
from datapanel.pembersihan import PipelinePembersihan
from datapanel.referensi import PROVINSI, PULAU_PROVINSI
from estimasi.determinan import AWAL
from estimasi.models import SetParameter

from . import templat
from .mesin import KEL, Konfigurasi, MesinSimulasi
from .models import Skenario

DATASET = settings.REPO_DIR / "01 Data" / "TFP" / "processed" / \
    "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"


@unittest.skipUnless(DATASET.exists(), "Dataset agregasi provinsi tidak tersedia")
class MesinTest(SimpleTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        with open(DATASET, "rb") as f:
            cls.panel = PipelinePembersihan({"imputasi": "tidak"}).jalankan(f, DATASET.name).df
        cls.dasar = Konfigurasi(n_simulasi=0, apbd_persen=0, realokasi_pp=0)

    def _mesin(self, **ubah):
        return MesinSimulasi(self.panel, replace(self.dasar, **ubah))

    @staticmethod
    def _g_nasional(m, lnY):
        return ((m.Y0 * np.exp(lnY[:, -1])).sum() / m.Y0.sum()) ** (1 / m.H) - 1

    def test_tanpa_a2_skenario_sama_dengan_dasar(self):
        h = self._mesin(a2={}).jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(h["pdrb_skenario"], h["pdrb_dasar"], rtol=1e-12)
        self.assertAlmostEqual(h["ringkasan"]["g_rata_skenario"], h["ringkasan"]["g_rata_dasar"], places=10)

    def test_a2_menaikkan_pertumbuhan(self):
        h = self._mesin(a2={"2026": 500, "2027": 500, "2028": 500, "2029": 500}).jalankan(dengan_mc=False)
        r = h["nasional"]["ringkasan"]
        self.assertGreater(r["g_rata_skenario"], r["g_rata_dasar"])

    def test_a1_di_bawah_tren_menurunkan_bn(self):
        tren = self._mesin().jalankan(dengan_mc=False)["nasional"]
        rendah = self._mesin(a1={str(t): v * 0.5 for t, v in zip(tren["tahun"][1:], tren["inv_tren"])})
        r = rendah.jalankan(dengan_mc=False)["nasional"]["ringkasan"]
        self.assertLess(r["g_rata_dasar"], tren["ringkasan"]["g_rata_dasar"])

    def test_kejutan_tfp_meluruh(self):
        dasar = self._mesin().jalankan(dengan_mc=False)["nasional"]
        kj = [{"jenis": "tfp", "tahun": 2026, "besar": -2.0, "persistensi": 0.5, "cakupan": "nasional"}]
        h = self._mesin(kejutan=kj).jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(h["kejutan_level"], [-2.0, -1.0, -0.5, -0.25], rtol=1e-6)
        self.assertLess(h["g_dasar"][0], dasar["g_dasar"][0] - 1.5)
        self.assertGreater(h["g_dasar"][1], dasar["g_dasar"][1])  # pulih saat kejutan meluruh
        self.assertGreater(h["ringkasan"]["kebutuhan_tambahan_kumulatif"],
                           dasar["ringkasan"]["kebutuhan_tambahan_kumulatif"])

    def test_determinan_kosong_tidak_mengubah_hasil(self):
        a2 = {"2026": 500, "2027": 500, "2028": 500, "2029": 500}
        acuan = self._mesin(a2=a2).jalankan(dengan_mc=False)["nasional"]
        h = self._mesin(a2=a2, koef_determinan=AWAL, determinan={"pendidikan": {"jeda": 1}}) \
            .jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(h["pdrb_skenario"], acuan["pdrb_skenario"], rtol=1e-12)
        self.assertEqual(h["determinan"]["pilar"], [])

    def test_determinan_berjeda_dan_tidak_di_bn(self):
        acuan = self._mesin().jalankan(dengan_mc=False)["nasional"]
        segera = self._mesin(koef_determinan=AWAL, determinan={"konektivitas": {"dz": 0.1, "jeda": 0, "penuh": 1}})
        tunda = self._mesin(koef_determinan=AWAL, determinan={"konektivitas": {"dz": 0.1, "jeda": 2, "penuh": 1}})
        efek = sum(x["koef"] for x in AWAL if x["pilar"] == "konektivitas") * 0.1
        np.testing.assert_allclose(segera.Dt[0], efek * np.arange(1, 5) / 4)
        np.testing.assert_allclose(tunda.Dt[0], efek * np.array([0, 0, 1, 2]) / 4)
        h = tunda.jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(h["pdrb_dasar"], acuan["pdrb_dasar"], rtol=1e-12)
        self.assertGreater(h["ringkasan"]["g_rata_skenario"], acuan["ringkasan"]["g_rata_skenario"])
        self.assertLess(h["ringkasan"]["kebutuhan_tambahan_kumulatif"],
                        acuan["ringkasan"]["kebutuhan_tambahan_kumulatif"])

    def test_determinan_dari_dana(self):
        a2 = {"2026": 100, "2027": 300, "2028": 300, "2029": 300}
        m = self._mesin(a2=a2, koef_determinan=AWAL,
                        determinan={"institusi": {"porsi": 10, "biaya": 200, "jeda": 0, "penuh": 1}})
        p = m.dt_pilar[0]
        self.assertAlmostEqual(p["dz"], 0.1 * 1000 / 200)
        np.testing.assert_allclose(p["w"], [0.1, 0.4, 0.7, 1.0])
        r = m.jalankan(dengan_mc=False)["nasional"]["determinan"]["pilar"][0]
        self.assertAlmostEqual(r["dana_T"], 100)
        self.assertIsNotNone(r["pp_per_100T"])

    def test_kejutan_investasi_dan_cakupan_pulau(self):
        kj = [{"jenis": "investasi", "tahun": 2027, "besar": -20.0, "persistensi": 1.0, "cakupan": "pulau:Jawa"}]
        m = self._mesin(kejutan=kj)
        jawa = np.array([PULAU_PROVINSI[k] == "Jawa" for k in m.kode])
        np.testing.assert_allclose(m.kj_I[jawa][:, 0], 1.0)
        np.testing.assert_allclose(m.kj_I[jawa][:, 1:], 0.8)
        np.testing.assert_allclose(m.kj_I[~jawa], 1.0)

    def test_jalur_sasaran_bertahap(self):
        jalur = {"sasaran": {"2026": 6.0, "2027": 7.0, "2028": 8.0, "2029": 9.0}}
        h = self._mesin(jalur=jalur).jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(h["sasaran_tahunan"], [6.0, 7.0, 8.0, 9.0], atol=1e-6)
        majemuk = (np.prod([1.06, 1.07, 1.08, 1.09]) ** 0.25 - 1) * 100
        self.assertAlmostEqual(h["ringkasan"]["g_rata_sasaran"], majemuk, places=6)

    def test_jalur_faktor_tfp_dan_laju_investasi(self):
        dasar = self._mesin().jalankan(dengan_mc=False)["nasional"]
        h = self._mesin(jalur={"faktor_tfp": {"2026": 0.0}, "g_investasi": {"2026": 0.0}}).jalankan(dengan_mc=False)
        n = h["nasional"]
        self.assertAlmostEqual(n["inv_tren"][0], sum(h["nasional"]["inv_tren"][:1]), places=6)
        self.assertLess(n["inv_tren"][0], dasar["inv_tren"][0])
        self.assertLess(n["g_dasar"][0], dasar["g_dasar"][0])

    def test_tanpa_kejutan_dan_jalur_identik(self):
        a = self._mesin().jalankan(dengan_mc=False)["nasional"]
        b = self._mesin(jalur={}, kejutan=[]).jalankan(dengan_mc=False)["nasional"]
        np.testing.assert_allclose(a["pdrb_skenario"], b["pdrb_skenario"], rtol=1e-12)

    def test_sasaran_seragam_dan_proporsional_capai_k(self):
        for mode in ("seragam", "proporsional"):
            m = self._mesin(mode_sasaran=mode, sasaran=8)
            self.assertAlmostEqual(self._g_nasional(m, m.lnYstar), 0.08, places=8, msg=mode)

    def test_sasaran_provinsi_dikunci_nasional_tetap_k(self):
        m = self._mesin(mode_sasaran="proporsional", sasaran=8, override={"32": {"sasaran": 9.0}})
        i = list(m.kode).index(32)
        self.assertAlmostEqual(m.g_sasaran[i], 0.09, places=8)
        self.assertAlmostEqual(self._g_nasional(m, m.lnYstar), 0.08, places=8)

    def test_kebutuhan_lalu_maju_kembali_ke_sasaran(self):
        """Investasi hasil hitung mundur, bila dimasukkan ke hitung maju, memberi jalur sasaran."""
        m = self._mesin(beta={k: 0.0 for k in KEL}, mode_sasaran="proporsional")
        P, H = len(m.kode), m.H
        b1, b2 = np.full((1, 1), m.cfg.b1), np.full((1, 1), m.cfg.b2)
        nol, beta = np.zeros((1, P, H)), np.zeros((1, 4))
        keb = m._mundur(b1, b2, m.gA[None], m.gL[None], nol, beta)
        A2 = keb["I_real"][0] - m.A1_real
        maju = m._maju(b1, b2, m.gA[None], m.gL[None], nol, beta, A2)
        np.testing.assert_allclose(maju["lnY"][0], m.lnYstar, atol=1e-10)

    def test_monte_carlo_konsisten(self):
        h1 = self._mesin(n_simulasi=200, seed=7).jalankan()["ketidakpastian"]
        h2 = self._mesin(n_simulasi=200, seed=7).jalankan()["ketidakpastian"]
        self.assertEqual(h1["prob_nasional"], h2["prob_nasional"])
        self.assertTrue(0 <= h1["prob_nasional"] <= 1)
        g = h1["g_rata"]
        self.assertLessEqual(g["p10"], g["p50"])
        self.assertLessEqual(g["p50"], g["p90"])
        k = h1["kebutuhan_tambahan_kum"]
        self.assertLessEqual(k["p50"], k["p80"])

    def test_rinci_papua_38_provinsi_total_tetap(self):
        from datapanel.papua import pangsa_dari_berkas_tim, pecah
        pangsa = pangsa_dari_berkas_tim(settings.REPO_DIR)
        if not pangsa:
            self.skipTest("Berkas rincian Papua tidak tersedia")
        m34 = self._mesin()
        m38 = MesinSimulasi(pecah(self.panel, pangsa), self.dasar)
        self.assertEqual(len(m38.kode), 38)
        self.assertAlmostEqual(m38.Y0.sum(), m34.Y0.sum(), places=3)
        self.assertAlmostEqual(m38.K0.sum(), m34.K0.sum(), places=3)
        self.assertAlmostEqual(self._g_nasional(m38, m38.lnYstar), self.dasar.sasaran / 100, places=4)


@unittest.skipUnless(DATASET.exists(), "Dataset agregasi provinsi tidak tersedia")
class TemplatTest(TestCase):
    def test_isian_mewarisi_paket_dasar(self):
        isi = templat.isian("P4")
        self.assertEqual(isi["a1"], templat.TARGET_RENSTRA)
        self.assertNotIn("a1_laju", isi)
        self.assertEqual(isi["komposisi_a2"]["sekunder"], 60)
        self.assertEqual(isi["alokasi_a2"], "manual")
        self.assertIsNone(templat.isian("P6")["bobot_pulau"])

    def test_tangga_paket(self):
        with open(DATASET, "rb") as f:
            df = PipelinePembersihan({"imputasi": "tidak"}).jalankan(f, DATASET.name).df
        for kode, nama, pulau in PROVINSI:
            Provinsi.objects.create(kode=kode, nama=nama, pulau=pulau)
        versi = VersiData.objects.create(nama="uji", status=VersiData.Status.SIAP)
        versi.simpan_dataframe(df, {})
        p = SetParameter.objects.create(nama="uji", b1=0.401899, se_b1=0.042356, b2=0.147184, se_b2=0.107323)
        sks, galat = templat.buat_semua(versi, p, None)
        self.assertEqual(galat, [])
        r = {sk.templat: sk.hasil.data["nasional"]["ringkasan"] for sk in sks}
        self.assertTrue(all(sk.bawaan and sk.singkat for sk in sks))
        self.assertAlmostEqual(r["P0"]["g_rata_skenario"], r["P0"]["g_rata_dasar"], places=8)
        self.assertLess(r["P1"]["g_rata_dasar"], r["P0"]["g_rata_dasar"])
        self.assertGreater(r["P2"]["g_rata_dasar"], r["P0"]["g_rata_dasar"])
        for a, b in (("P2", "P3"), ("P3", "P4"), ("P4", "P5")):
            self.assertGreater(r[b]["g_rata_skenario"], r[a]["g_rata_skenario"], msg=f"{a} -> {b}")
        self.assertAlmostEqual(r["P6"]["g_rata_skenario"], 8.0, delta=0.05)
        self.assertEqual(sum(sks[3].a2.values()), 4 * templat.A2_HILIRISASI["2026"])
        self.assertEqual(templat.buat_contoh(versi, p, None), [])
        tren = Skenario.objects.get(nama=templat.CONTOH[0]["nama"])
        n = tren.hasil.data["nasional"]
        for th, v in zip(n["tahun"][1:], n["inv_tren"]):
            self.assertAlmostEqual(tren.a2[str(th)], max(templat.TARGET_RENSTRA[str(th)] - v, 0), delta=0.06)
        jalur = [1 + v / 100 for v in templat.SASARAN_BERTAHAP.values()]
        sasaran_p7 = (np.prod(jalur) ** (1 / len(jalur)) - 1) * 100
        self.assertAlmostEqual(r["P7"]["g_rata_sasaran"], sasaran_p7, delta=0.01)
        self.assertAlmostEqual(r["P7"]["g_rata_skenario"], sasaran_p7, delta=0.1)
        # membangun ulang memperbarui paket yang sama, tidak menambah baris
        sks2, _ = templat.buat_semua(versi, p, None)
        self.assertEqual(sorted(s.pk for s in sks), sorted(s.pk for s in sks2))

        # A2 Hilirisasi diubah di kisi: disimpan sebagai penyesuaian, diwariskan, dan bertahan saat dibangun ulang
        paket = lambda k: Skenario.objects.get(kelompok=Skenario.Kelompok.BAWAAN, templat=k)  # noqa: E731
        p3, p6 = paket("P3"), paket("P6")
        self.client.post(reverse("simulasi:daftar"), {f"s{p3.pk}-a2_2026": "500", "simpan": "1"})
        a2_baru = {**templat.A2_HILIRISASI, "2026": 500.0}
        self.assertEqual(paket("P3").penyesuaian, {"a2": a2_baru})
        self.assertEqual(paket("P3").kelompok, Skenario.Kelompok.BAWAAN)
        for k in ("P3", "P4", "P5"):
            self.assertEqual(paket(k).a2, a2_baru, msg=k)
        self.assertEqual(paket("P6").a2, p6.a2)
        templat.buat_semua(versi, p, None)
        self.assertEqual(paket("P4").a2, a2_baru)
        self.assertEqual(templat.sesuaikan("P3", {"a2": a2_baru}, {"a2": templat.A2_HILIRISASI}), {})
        self.client.post(reverse("simulasi:templat_kembalikan", args=["P3"]))
        self.assertEqual(paket("P5").a2, templat.A2_HILIRISASI)

        # determinan TFP di kisi: tersimpan per pilar (dan per indikator), diwariskan ke paket turunan
        self.client.post(reverse("simulasi:daftar"), {f"s{p3.pk}-dt_konektivitas_dz": "0.1",
                                                      f"s{p3.pk}-di_ln_kargo_kapal": "0.2", "jalankan": "1"})
        dt = templat.isian("P3")["determinan"]
        dt["konektivitas"] = {"dz": 0.1, "indikator": {**dt["konektivitas"]["indikator"], "ln_kargo_kapal": 0.2}}
        self.assertEqual(paket("P3").penyesuaian, {"determinan": dt})
        p5 = paket("P5").determinan
        self.assertEqual(p5["konektivitas"]["dz"], 0.1)
        self.assertEqual(p5["konektivitas"]["indikator"]["ln_kargo_kapal"], 0.2)
        self.assertEqual(p5, templat.isian("P5", {"P3": {"determinan": dt}})["determinan"])
        self.assertEqual(paket("P2").determinan, templat.isian("P2")["determinan"])
        r3 = paket("P3").hasil.data["nasional"]
        self.assertGreater(r3["ringkasan"]["kontribusi"]["determinan"], 0)
        self.assertEqual([p["pilar"] for p in r3["determinan"]["pilar"]], ["konektivitas"])
