"""Analisis IO/IRIO: invers Leontief, keterkaitan, aliran antarwilayah, pengganda, dan dampak investasi skenario.

Notasi: N = R × S baris (wilayah utama, sektor di dalamnya). A = Z / x (kolom), L = (I − A)⁻¹,
v = NTB / output. Keterkaitan ke belakang (BL) dari jumlah kolom L, ke depan (FL) dari jumlah baris
invers Ghosh G = (I − B)⁻¹ dengan B = Z / x (baris); keduanya dinormalkan terhadap rata-rata.
"""

from functools import lru_cache

import numpy as np

from datapanel.papua import KELUARGA
from datapanel.referensi import KODE_SEKTOR, NAMA_PROVINSI, NAMA_SEKTOR, PULAU_PROVINSI

from .models import TabelIO


class Tabel:
    def __init__(self, t: TabelIO):
        d = t.larik()
        self.pk, self.jenis, self.tahun, self.metode = t.pk, t.jenis, t.tahun, t.metode
        self.Z, self.x, self.va = d["Z"], d["x"], d["va"]
        self.wil = [int(k) for k in d["wil"]]
        self.sek = [str(s) for s in d["sek"]]
        self.R, self.S = len(self.wil), len(self.sek)
        aman = np.where(self.x > 0, self.x, 1.0)
        self.A = self.Z / aman[None, :]
        self.B = self.Z / aman[:, None]
        n = len(self.x)
        self.L = np.linalg.inv(np.eye(n) - self.A)
        self.G = np.linalg.inv(np.eye(n) - self.B)
        self.v = np.where(self.x > 0, self.va / aman, 0.0)

    def blok(self, M):
        """(N, N) -> (R, S, R, S)."""
        return M.reshape(self.R, self.S, self.R, self.S)


@lru_cache(maxsize=24)
def _tabel(pk, dimuat):
    return Tabel(TabelIO.objects.get(pk=pk))


def tabel(t: TabelIO) -> Tabel:
    return _tabel(t.pk, t.dimuat.isoformat())


def nasional_dari_irio(tb: Tabel):
    """Agregasi IRIO ke tabel nasional S × S (jumlah semua wilayah)."""
    Z = tb.blok(tb.Z).sum(axis=(0, 2))
    x = tb.x.reshape(tb.R, tb.S).sum(axis=0)
    va = tb.va.reshape(tb.R, tb.S).sum(axis=0)
    return Z, x, va


def keterkaitan(Z, x, va):
    """BL, FL (dinormalkan), pengganda output dan NTB per sektor untuk tabel S × S."""
    aman = np.where(x > 0, x, 1.0)
    A, B = Z / aman[None, :], Z / aman[:, None]
    n = len(x)
    L, G = np.linalg.inv(np.eye(n) - A), np.linalg.inv(np.eye(n) - B)
    v = np.where(x > 0, va / aman, 0.0)
    kol, bar = L.sum(axis=0), G.sum(axis=1)
    return {"bl": (kol / kol.mean()).tolist(), "fl": (bar / bar.mean()).tolist(),
            "pengganda_output": kol.tolist(), "pengganda_ntb": (v @ L).tolist(),
            "A": A.tolist(), "L": L.tolist(), "output": (x / 1e6).tolist(), "ntb": (va / 1e6).tolist()}


def keterkaitan_wilayah(tb: Tabel, kode):
    """Keterkaitan sektor di satu provinsi memakai L antarwilayah penuh (dampak dihitung ke semua wilayah)."""
    r = tb.wil.index(kode)
    sl = slice(r * tb.S, (r + 1) * tb.S)
    kol = tb.L[:, sl].sum(axis=0)
    bar = tb.G[sl, :].sum(axis=1)
    kol_all, bar_all = tb.L.sum(axis=0), tb.G.sum(axis=1)
    lokal = tb.L[sl, sl].sum(axis=0)
    Zr = tb.Z[sl, sl]
    xr = tb.x[sl]
    aman = np.where(xr > 0, xr, 1.0)
    return {"bl": (kol / kol_all.mean()).tolist(), "fl": (bar / bar_all.mean()).tolist(),
            "pengganda_output": kol.tolist(), "pengganda_ntb": (tb.v @ tb.L[:, sl]).tolist(),
            "bocoran": (1 - lokal / np.where(kol > 0, kol, 1)).tolist(),
            "A": (Zr / aman[None, :]).tolist(), "L": tb.L[sl, sl].tolist(),
            "output": (xr / 1e6).tolist(), "ntb": (tb.va[sl] / 1e6).tolist()}


def aliran(tb: Tabel, sektor_asal=None, sektor_tujuan=None):
    """Matriks aliran antara antarwilayah R × R (juta Rp), opsional dibatasi sektor asal/tujuan."""
    b = tb.blok(tb.Z)
    if sektor_asal:
        b = b[:, [tb.sek.index(s) for s in sektor_asal], :, :]
    if sektor_tujuan:
        b = b[:, :, :, [tb.sek.index(s) for s in sektor_tujuan]]
    return b.sum(axis=(1, 3))


def indikator_wilayah(tb: Tabel, sektor=None):
    """Indikator per provinsi untuk peta pengganda; sektor = kode sektor atau None (rata-rata berbobot output)."""
    kol = tb.L.sum(axis=0)
    ntb = tb.v @ tb.L
    B4 = tb.blok(tb.L)
    lokal = np.einsum("rsrj->rj", B4).reshape(-1)  # bagian pengganda yang jatuh di wilayah sendiri
    bocor = 1 - lokal / np.where(kol > 0, kol, 1)
    G_bar = tb.G.sum(axis=1)
    bl, fl = kol / kol.mean(), G_bar / G_bar.mean()
    x = tb.x.reshape(tb.R, tb.S)
    F = aliran(tb)
    keluar, masuk = F.sum(axis=1) - np.diag(F), F.sum(axis=0) - np.diag(F)
    out = {}
    for nama, v in (("pengganda_output", kol), ("pengganda_ntb", ntb), ("bocoran", bocor * 100),
                    ("bl", bl), ("fl", fl)):
        m = v.reshape(tb.R, tb.S)
        if sektor:
            j = tb.sek.index(sektor)
            nilai = m[:, j]
        else:
            nilai = (m * x).sum(axis=1) / np.where(x.sum(axis=1) > 0, x.sum(axis=1), 1)
        out[nama] = {str(k): float(nilai[i]) for i, k in enumerate(tb.wil)}
    out["kemandirian"] = {k: 100 - v for k, v in out["bocoran"].items()}
    out["ekspor_antar"] = {str(k): float(keluar[i] / 1e6) for i, k in enumerate(tb.wil)}
    out["impor_antar"] = {str(k): float(masuk[i] / 1e6) for i, k in enumerate(tb.wil)}
    out["neraca_antar"] = {str(k): float((keluar[i] - masuk[i]) / 1e6) for i, k in enumerate(tb.wil)}
    xs = tb.x.reshape(tb.R, tb.S)
    out["output"] = {str(k): float((xs[i, tb.sek.index(sektor)] if sektor else xs[i].sum()) / 1e6)
                     for i, k in enumerate(tb.wil)}
    return out


# ------------------------------------------------------------------ dampak investasi skenario
def jembatan_pmtb():
    """Per provinsi: komposisi produk PMTB domestik c (R × S) dan pangsa domestik d (R)."""
    t = TabelIO.objects.filter(jenis=TabelIO.Jenis.PMTB).first()
    if not t:
        return None
    d = t.larik()
    lokal = np.clip(d["lokal"], 0, None)
    c = lokal / np.where(lokal.sum(axis=1, keepdims=True) > 0, lokal.sum(axis=1, keepdims=True), 1)
    tot = lokal.sum(axis=1) + d["impor_ap"] + d["impor_ln"]
    dom = (lokal.sum(axis=1) + d["impor_ap"]) / np.where(tot > 0, tot, 1)
    return {"wil": [int(k) for k in d["wil"]], "c": c, "d": dom}


def pangsa_dagang(tb: Tabel):
    """T[s, i, r]: bagian produk i yang dipakai wilayah r yang berasal dari wilayah s."""
    pakai = tb.blok(tb.Z).sum(axis=3)  # (s, i, r)
    tot = pakai.sum(axis=0, keepdims=True)
    T = pakai / np.where(tot > 0, tot, 1)
    kosong = tot[0] <= 0  # (i, r)
    for i, r in zip(*np.nonzero(kosong)):
        T[:, i, r] = 0
        T[r, i, r] = 1
    return T


def ke_34(nilai):
    """{kode 34/38: v} -> {kode 34: v} dengan menjumlah keluarga Papua."""
    out = {}
    induk = {a: k for k, kel in KELUARGA.items() for a in kel}
    for k, v in nilai.items():
        k34 = induk.get(int(k), int(k))
        out[k34] = out.get(k34, 0.0) + v
    return out


def dampak(tb: Tabel, investasi, jembatan):
    """investasi: {kode 34: miliar Rp} -> dampak output dan NTB menurut provinsi × sektor (miliar Rp).

    Investasi provinsi r menjadi permintaan produk menurut komposisi PMTB domestik r, disumber antarwilayah
    menurut pangsa dagang IRIO, lalu Δx = L Δf dan ΔNTB = v ⊙ Δx.
    """
    T = pangsa_dagang(tb)
    idx_j = {k: i for i, k in enumerate(jembatan["wil"])}
    F = np.zeros((len(tb.x), tb.R))  # kolom = wilayah asal investasi
    for r, k in enumerate(tb.wil):
        I = investasi.get(k, 0.0) * 1000  # miliar -> juta
        if not I or k not in idx_j:
            continue
        j = idx_j[k]
        q = I * jembatan["d"][j] * jembatan["c"][j]  # (S,) permintaan produk
        F[:, r] = (T[:, :, r] * q[None, :]).reshape(-1)
    dX = tb.L @ F                      # (N, R)
    dV = tb.v[:, None] * dX
    dX3, dV3 = dX.reshape(tb.R, tb.S, tb.R), dV.reshape(tb.R, tb.S, tb.R)
    M = dV3.sum(axis=1)                # (wilayah penerima, wilayah investasi)
    inv = np.array([investasi.get(k, 0.0) for k in tb.wil])
    va0 = tb.va.reshape(tb.R, tb.S).sum(axis=1)
    hasil = {
        "wil": tb.wil, "sek": tb.sek,
        "investasi": inv.tolist(),
        "permintaan_domestik": (F.sum(axis=0) / 1000).tolist(),
        "d_output": (dX3.sum(axis=2) / 1000).tolist(),   # (R penerima, S)
        "d_ntb": (dV3.sum(axis=2) / 1000).tolist(),
        "matriks_ntb": (M / 1000).tolist(),              # [penerima][asal]
        "ntb_diterima": (M.sum(axis=1) / 1000).tolist(),
        "ntb_dipicu": (M.sum(axis=0) / 1000).tolist(),
        "ntb_sendiri": (np.diag(M) / 1000).tolist(),
        "pct_ntb": (M.sum(axis=1) / np.where(va0 > 0, va0, 1) * 100).tolist(),
    }
    dipicu = M.sum(axis=0)
    hasil["limpahan_pct"] = [float((1 - M[r, r] / dipicu[r]) * 100) if dipicu[r] > 0 else None for r in range(tb.R)]
    tot_inv = inv.sum()
    hasil["ringkasan"] = {
        "investasi": float(tot_inv), "d_output": float(dX.sum() / 1000), "d_ntb": float(dV.sum() / 1000),
        "pengganda_ntb": float(dV.sum() / 1000 / tot_inv) if tot_inv else None,
        "pengganda_output": float(dX.sum() / 1000 / tot_inv) if tot_inv else None,
        "limpahan_pct": float((1 - np.trace(M) / M.sum()) * 100) if M.sum() else None,
        "bocoran_impor_pct": float((1 - F.sum() / 1000 / tot_inv) * 100) if tot_inv else None,
        "pct_ntb_nasional": float(dV.sum() / tb.va.sum() * 100),
    }
    return hasil


def investasi_skenario(sk, sumber="a2", tahun=None):
    """{kode 34: miliar Rp} dari tabel hitung skenario; sumber a2 | a1a2 | kebutuhan; tahun None = kumulatif."""
    h = sk.hasil.data.get("hitung")
    if not h:
        return None, []
    kol = h["kolom"]
    ix = {k: kol.index(k) for k in ("kode", "tahun", "A1_real", "A2_real", "I_kebutuhan")}
    tahun_ada = sorted({b[ix["tahun"]] for b in h["baris"]})
    per = {}
    for b in h["baris"]:
        if tahun and b[ix["tahun"]] != tahun:
            continue
        if sumber == "a2":
            v = b[ix["A2_real"]]
        elif sumber == "a1a2":
            v = b[ix["A1_real"]] + b[ix["A2_real"]]
        else:
            v = max(b[ix["I_kebutuhan"]] - b[ix["A1_real"]], 0.0)
        per[b[ix["kode"]]] = per.get(b[ix["kode"]], 0.0) + v
    return ke_34(per), tahun_ada


def label_sektor():
    return [{"kode": s, "nama": NAMA_SEKTOR[s]} for s in KODE_SEKTOR]


def label_wilayah(wil):
    return [{"kode": k, "nama": NAMA_PROVINSI[k], "pulau": PULAU_PROVINSI[k]} for k in wil]
