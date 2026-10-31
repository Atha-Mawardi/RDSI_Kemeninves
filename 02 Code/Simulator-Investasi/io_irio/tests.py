import numpy as np
from django.test import SimpleTestCase

from . import analisis


class KeterkaitanTest(SimpleTestCase):
    """Tabel dua sektor dengan invers Leontief yang bisa dihitung tangan."""

    def test_leontief_dan_keterkaitan(self):
        Z = np.array([[20.0, 30.0], [40.0, 10.0]])
        x = np.array([100.0, 100.0])
        va = x - Z.sum(axis=0)
        k = analisis.keterkaitan(Z, x, va)
        A = Z / x[None, :]
        L = np.linalg.inv(np.eye(2) - A)
        np.testing.assert_allclose(k["L"], L)
        np.testing.assert_allclose(k["pengganda_output"], L.sum(axis=0))
        self.assertAlmostEqual(np.mean(k["bl"]), 1.0)
        self.assertAlmostEqual(np.mean(k["fl"]), 1.0)
        # NTB yang tercipta per unit permintaan akhir = 1 bila semua input antara domestik
        np.testing.assert_allclose(k["pengganda_ntb"], [1.0, 1.0])
