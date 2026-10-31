import unittest

import numpy as np
import pandas as pd
from django.conf import settings
from django.test import SimpleTestCase

from datapanel.referensi import KODE_SEKTOR

from . import statistik, twfe

HASIL_TFP = settings.REPO_DIR / "01 Data" / "TFP" / "output" / "modal_riil" / "Hasil Estimasi TFP.xlsx"


class TwfeSintetisTest(SimpleTestCase):
    def test_memulihkan_koefisien_sebenarnya(self):
        rng = np.random.default_rng(0)
        kode, tahun = np.arange(34), np.arange(2015, 2025)
        idx = pd.MultiIndex.from_product([kode, tahun], names=["kode", "tahun"])
        a = np.repeat(rng.normal(0, 1, 34), len(tahun))
        d = np.tile(rng.normal(0, 0.1, len(tahun)), 34)
        lnK = rng.normal(10, 1, len(idx))
        lnL = rng.normal(12, 1, len(idx))
        lnY = a + d + 0.4 * lnK + 0.2 * lnL + rng.normal(0, 0.01, len(idx))
        df = pd.DataFrame({"PDRB_ADHK": np.exp(lnY), "PMTB_ADHK": np.exp(lnK)}, index=idx)
        for s in KODE_SEKTOR:
            df[f"TK_{s}"] = np.exp(lnL) if s == "A" else 0.0
        h = twfe.estimasi(df)
        self.assertAlmostEqual(h["b1"], 0.4, places=2)
        self.assertAlmostEqual(h["b2"], 0.2, places=2)


def _panel_sintetis(seed=0, b1=0.4, b2=0.2):
    rng = np.random.default_rng(seed)
    kode, tahun = np.arange(11, 45), np.arange(2015, 2025)
    idx = pd.MultiIndex.from_product([kode, tahun], names=["kode", "tahun"])
    a = np.repeat(rng.normal(0, 1, len(kode)), len(tahun))
    d = np.tile(np.linspace(0, 0.3, len(tahun)), len(kode))
    lnK = rng.normal(10, 1, len(idx))
    lnL = rng.normal(12, 1, len(idx))
    lnY = a + d + b1 * lnK + b2 * lnL + rng.normal(0, 0.01, len(idx))
    df = pd.DataFrame({"PDRB_ADHK": np.exp(lnY), "PMTB_ADHK": np.exp(lnK)}, index=idx)
    for s in KODE_SEKTOR:
        df[f"TK_{s}"] = np.exp(lnL) if s == "A" else 0.0
    return df


class StatistikTest(SimpleTestCase):
    def test_distribusi_t(self):
        self.assertAlmostEqual(statistik.p_dua_sisi(2.0, 30), 0.05463, places=4)
        self.assertAlmostEqual(statistik.t_kritis(33), 2.0345, places=3)
        self.assertAlmostEqual(statistik.p_dua_sisi(1.959964, 10 ** 6), 0.05, places=3)
        self.assertEqual(statistik.bintang(0.004), "***")
        self.assertEqual(statistik.bintang(0.2), "")


class EstimasiLengkapTest(SimpleTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.df = _panel_sintetis()

    def test_keluaran_lengkap(self):
        h = twfe.estimasi_lengkap(self.df, 2015, 2024)
        self.assertAlmostEqual(h["b1"], 0.4, places=2)
        self.assertAlmostEqual(h["b2"], 0.2, places=2)
        self.assertEqual((h["n_obs"], h["n_provinsi"], h["n_tahun"], h["df_klaster"]), (340, 34, 10, 33))
        b1 = h["koefisien"][0]
        self.assertLess(b1["lo"], 0.4)
        self.assertGreater(b1["hi"], 0.4)
        self.assertEqual(b1["bintang"], "***")
        self.assertLess(h["uji_crs"]["p"], 0.001)              # b1 + b2 = 0,6 jelas bukan 1
        self.assertEqual(h["efek_tahun"][0]["d"], 0.0)
        self.assertAlmostEqual(h["efek_tahun"][-1]["d"], 0.3, places=2)
        self.assertEqual(len(h["residual"]), 340)

    def test_kecuali_tahun_provinsi_dan_crs(self):
        h = twfe.estimasi_lengkap(self.df, 2015, 2024, kecuali_tahun=[2020], provinsi=list(range(11, 31)))
        self.assertEqual((h["n_obs"], h["n_provinsi"], h["n_tahun"]), (180, 20, 9))
        self.assertNotIn(2020, [e["tahun"] for e in h["efek_tahun"]])
        c = twfe.estimasi_lengkap(self.df, 2015, 2024, crs=True)
        self.assertAlmostEqual(c["b1"] + c["b2"], 1.0, places=10)
        self.assertIsNone(c["uji_crs"])

    def test_pembungkus_sama_dengan_lengkap(self):
        a, b = twfe.estimasi(self.df, 2016, 2023), twfe.estimasi_lengkap(self.df, 2016, 2023)
        self.assertAlmostEqual(a["b1"], b["b1"], places=12)
        self.assertAlmostEqual(a["se_b2"], b["se_b2"], places=12)

    def test_stok_pim(self):
        I = self.df["PMTB_ADHK"].iloc[:10]
        K = twfe.stok_pim(I, 0.05)
        np.testing.assert_allclose(K.iloc[1:].to_numpy(), 0.95 * K.iloc[:-1].to_numpy() + I.iloc[1:].to_numpy())


@unittest.skipUnless(HASIL_TFP.exists(), "Hasil Estimasi TFP.xlsx tidak tersedia")
class TwfeVintageBTest(SimpleTestCase):
    """Data log yang dibekukan (sheet data_tfp) harus memberi b1 = 0,401899 dan b2 = 0,147184."""

    def test_reproduksi_vintage_b(self):
        d = pd.read_excel(HASIL_TFP, sheet_name="data_tfp")
        d = d[(d.Year >= 2017) & (d.Year <= 2024)]
        idx = pd.MultiIndex.from_arrays([d.Code_Prov, d.Year], names=["kode", "tahun"])
        df = pd.DataFrame({"PDRB_ADHK": np.exp(d.log_ADHK_Tot.to_numpy() - 20),
                           "PMTB_ADHK": np.exp(d.log_pmtb.to_numpy())}, index=idx)
        for s in KODE_SEKTOR:
            df[f"TK_{s}"] = np.exp(d.log_lab_tot.to_numpy()) if s == "A" else 0.0
        h = twfe.estimasi(df, 2017, 2024)
        self.assertEqual(h["n_obs"], 272)
        self.assertAlmostEqual(h["b1"], 0.401899, places=5)
        self.assertAlmostEqual(h["b2"], 0.147184, places=5)
        self.assertAlmostEqual(h["se_b1"], 0.042356, places=4)
        self.assertAlmostEqual(h["se_b2"], 0.107323, places=4)
