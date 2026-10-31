"""
Mesin simulasi: investasi -> PMTB -> PDRB -> TFP, maju dan mundur.

Kerangka (semua dalam log, relatif terhadap tahun dasar 0, h = 1..H):

    ln Y_h - ln Y_0 = ln A_h - ln A_0 + b1 (ln K_h - ln K_0) + b2 g_L h
    ln A_h - ln A_0 = g_A h + B_h + R_h (+ kejutan, di Monte Carlo)

K = PMTB harga konstan (arus, sama dengan estimasi). B = bonus komposisi
investasi dari model 13_Sectoral (pangsa t-1, basis tersier lainnya). R = efek
level realokasi tenaga kerja antarsektor (produk rata-rata, batas atas).

Saluran investasi bersifat marjinal terhadap tren, bukan pangsa tetap, supaya
provinsi dengan realisasi PMA+PMDN > PMTB (Maluku Utara, Papua Barat) tidak
menghasilkan "PMTB lain" negatif:

    PMTB nominal_h = PMTB tren_h + pi (I1_h + I2_h - I tren_h) + pi_g APBD_h

I1 = realisasi rencana dasar (A1; bila tidak diisi = tren), I2 = tambahan (A2).
Mode mundur membalik persamaan yang sama untuk K yang dibutuhkan sasaran.

Jalur per tahun (`jalur`) mengganti nilai konstan untuk sasaran K, faktor TFP, dan laju
tren PMA+PMDN. Kejutan (`kejutan`) adalah deviasi level yang meluruh geometris:
d_h = besar x persistensi^(h - h0) untuk h >= h0, pada TFP, PDRB langsung, tenaga kerja,
atau realisasi investasi (A1 dan A2), untuk nasional, satu pulau, atau satu provinsi.
Kejutan berlaku pada jalur Bn, Xn, dan kebutuhan.

Determinan TFP (`determinan`) menggeser level ln A di jalur Xn dan kebutuhan (tidak di Bn):

    D_h = sum_k beta_k dz_k x (1/R) sum_{r=0}^{R-1} a(h - L - r)

dz = perbaikan indikator di atas tren historis (SD), L = jeda, R = masa menuju efek penuh,
a = capaian perbaikan (porsi kumulatif investasi tambahan bila didanai, linier bila tidak).
Bila biaya per +1 SD dan porsi investasi tambahan diisi, dz = porsi x total investasi
tambahan / biaya. Dana ini bagian dari investasi tambahan (sudah masuk modal), bukan uang baru.
"""

from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from datapanel.panel import pangsa_kelompok_investasi, pangsa_sektor_investasi, tambah_turunan
from datapanel.referensi import (KELOMPOK, KELOMPOK_SEKTOR, KODE_SEKTOR, NAMA_PROVINSI,
                                 NAMA_SEKTOR, PULAU_PROVINSI)
from estimasi.determinan import JEDA_AWAL, NAMA_PILAR

KEL = ["primer", "sekunder", "tva", "tlain"]
TUJUAN_REALOKASI = {"C": ["C"], "tva": ["H", "J", "K", "MN"]}
JENIS_KEJUTAN = {"tfp": "TFP (level)", "pdrb": "PDRB langsung", "tk": "Tenaga kerja", "investasi": "Realisasi PMA+PMDN"}
JALUR = {"sasaran": "Sasaran pertumbuhan (%/tahun)", "faktor_tfp": "Pengali laju TFP (1 = tren)",
         "g_investasi": "Laju tren PMA+PMDN (%/tahun)"}


class GalatSimulasi(Exception):
    pass


@dataclass
class Konfigurasi:
    tahun_dasar: int = 2025
    tahun_target: int = 2029
    hist_awal: int = 2018
    hist_akhir: int = 2024
    kecualikan_2020: bool = False
    b1: float = 0.401899
    b2: float = 0.147184
    se_b1: float = 0.042356
    se_b2: float = 0.107323
    beta: dict = field(default_factory=lambda: {k: 0.0 for k in KEL})
    se_beta: dict = field(default_factory=lambda: {k: 0.0 for k in KEL})
    sasaran: float = 8.0
    mode_sasaran: str = "seragam"  # seragam | proporsional | manual
    lambda_proporsional: float = 1.0
    mode_tfp: str = "historis"  # historis | nasional | manual
    tfp_nasional: float = 2.0
    faktor_tfp: float = 1.0
    mode_tk: str = "historis"
    tk_nasional: float = 2.0
    mode_pmtb: str = "historis"  # historis | nasional
    g_pmtb_nasional: float | None = None
    g_investasi: float | None = None
    inflasi_pmtb: float | None = None
    pass_through: float = 1.0
    rasio_realisasi: float = 1.0
    pass_through_apbd: float = 1.0
    apbd_persen: float = 0.0
    a1: dict = field(default_factory=dict)  # tahun -> triliun Rp nasional
    a2: dict = field(default_factory=dict)
    alokasi_a2: str = "kebutuhan"  # pdrb | investasi | kebutuhan | manual
    komposisi_a2: dict | None = None
    realokasi_pp: float = 0.0
    tujuan_realokasi: str = "C"
    override: dict = field(default_factory=dict)  # kode -> {sasaran, tfp, tk, bobot_a2, primer..}
    jalur: dict = field(default_factory=dict)  # kunci JALUR -> {tahun: nilai}
    kejutan: list = field(default_factory=list)  # [{jenis, tahun, besar %, persistensi, cakupan}]
    determinan: dict = field(default_factory=dict)  # pilar -> {dz, jeda, penuh, porsi, biaya, cakupan, indikator}
    koef_determinan: list = field(default_factory=list)  # [{kode, pilar, koef, se, ...}]
    n_simulasi: int = 500
    skala_se: float = 1.0
    volatilitas_tfp: float = 1.0
    seed: int = 2026


def _ln1p_persen(x):
    return np.log1p(np.asarray(x, dtype=float) / 100.0)


class MesinSimulasi:
    def __init__(self, panel, cfg: Konfigurasi):
        self.cfg = cfg
        self.peringatan = []
        self.df = tambah_turunan(panel)
        self._siapkan()

    # ================================================================ data
    def _siapkan(self):
        c, df = self.cfg, self.df
        if c.tahun_target <= c.tahun_dasar:
            raise GalatSimulasi("Tahun target harus setelah tahun dasar.")
        tahun_ada = set(df.index.get_level_values("tahun"))
        if c.tahun_dasar not in tahun_ada:
            raise GalatSimulasi(f"Tahun dasar {c.tahun_dasar} tidak ada di versi data.")
        dasar = df.xs(c.tahun_dasar, level="tahun")
        perlu = ["PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB", "PMAPMDN"]
        lengkap = dasar[perlu].notna().all(axis=1) & (dasar[["PDRB_ADHK", "PMTB_ADHK"]] > 0).all(axis=1)
        if not lengkap.all():
            hilang = [NAMA_PROVINSI.get(int(k), k) for k in lengkap.index[~lengkap]]
            self.peringatan.append(f"Provinsi tanpa data dasar lengkap {c.tahun_dasar} dikeluarkan: "
                                   + ", ".join(hilang))
        self.kode = [int(k) for k in lengkap.index[lengkap]]
        if not self.kode:
            raise GalatSimulasi("Tidak ada provinsi dengan data tahun dasar lengkap.")
        P = len(self.kode)
        self.H = c.tahun_target - c.tahun_dasar
        self.t = np.arange(1, self.H + 1, dtype=float)
        self.tahun = list(range(c.tahun_dasar + 1, c.tahun_target + 1))
        d = dasar.loc[self.kode]
        self.Y0 = d["PDRB_ADHK"].to_numpy(float)
        self.K0 = d["PMTB_ADHK"].to_numpy(float)
        self.Kn0 = d["PMTB_ADHB"].to_numpy(float)
        self.I0 = d["PMAPMDN"].to_numpy(float)
        self.Dfl0 = self.Kn0 / self.K0
        self.Yn0 = (d["PDRB_ADHB"] if "PDRB_ADHB" in d else d["PDRB_ADHK"] * self.Dfl0) \
            .fillna(d["PDRB_ADHK"] * self.Dfl0).to_numpy(float)

        # ---- momen historis per provinsi: laju log dY, dK, dL
        lv = pd.DataFrame({"lnY": np.log(df["PDRB_ADHK"]), "lnK": np.log(df["PMTB_ADHK"]),
                           "lnL": np.log(df["TK_TOTAL"]) if "TK_TOTAL" in df else np.nan})
        dl = lv.groupby(level="kode").diff()
        th = dl.index.get_level_values("tahun")
        jendela = (th >= c.hist_awal) & (th <= c.hist_akhir)
        if c.kecualikan_2020:
            jendela &= th != 2020
        dl = dl[jendela]
        self.mY, self.mK, self.mL = np.zeros(P), np.zeros(P), np.zeros(P)
        self.Sig = np.zeros((P, 3, 3))
        self.n_hist = np.zeros(P)
        for i, k in enumerate(self.kode):
            g = dl.xs(k, level="kode") if k in dl.index.get_level_values("kode") else pd.DataFrame()
            g3 = g.dropna()
            if len(g3) < 3:
                raise GalatSimulasi(f"{NAMA_PROVINSI[k]}: kurang dari 3 tahun laju lengkap di jendela historis.")
            self.mY[i], self.mK[i], self.mL[i] = g3.mean().to_numpy()
            self.Sig[i] = np.cov(g3.to_numpy().T)
            self.n_hist[i] = len(g3)
        nas = df[["PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB", "PMAPMDN"]].groupby(level="tahun").sum(min_count=1)
        nas_dl = np.log(nas).diff()
        nj = (nas_dl.index >= c.hist_awal) & (nas_dl.index <= c.hist_akhir)
        if c.kecualikan_2020:
            nj &= nas_dl.index != 2020
        self.gY_nas_hist = float(nas_dl.loc[nj, "PDRB_ADHK"].mean())
        self.gK_nas_hist = float(nas_dl.loc[nj, "PMTB_ADHK"].mean())
        self.infl_hist = float((nas_dl.loc[nj, "PMTB_ADHB"] - nas_dl.loc[nj, "PMTB_ADHK"]).mean())
        self.gI_hist = float(nas_dl.loc[nj, "PMAPMDN"].mean())

        # ---- laju dasar (log)
        o = {int(k): v for k, v in (c.override or {}).items()}

        def dari_override(kunci, cadangan):
            return np.array([_ln1p_persen(o[k][kunci]) if o.get(k, {}).get(kunci) not in (None, "")
                             else cadangan[i] for i, k in enumerate(self.kode)])

        dasar_tk = np.full(P, _ln1p_persen(c.tk_nasional)) if c.mode_tk == "nasional" else self.mL
        self.gL = dari_override("tk", dasar_tk)
        self.tk_tetap = np.array([o.get(k, {}).get("tk") not in (None, "") for k in self.kode])
        if any(o.get(k, {}).get("bobot_a2") not in (None, "") for k in self.kode) and c.alokasi_a2 != "manual":
            self.peringatan.append("Bobot investasi tambahan per provinsi diisi, tetapi alokasinya bukan 'manual'; bobot diabaikan.")
        self.gK_tren = (np.full(P, _ln1p_persen(c.g_pmtb_nasional) if c.g_pmtb_nasional is not None
                                else self.gK_nas_hist) if c.mode_pmtb == "nasional" else self.mK.copy())
        self.gI = _ln1p_persen(c.g_investasi) if c.g_investasi is not None else self.gI_hist
        self.infl = _ln1p_persen(c.inflasi_pmtb) if c.inflasi_pmtb is not None else self.infl_hist
        self.gA = self._laju_tfp(c.b1, c.b2)

        # ---- investasi: pangsa provinsi dan komposisi sektor (3 tahun terakhir)
        tiga = [t for t in range(c.tahun_dasar - 2, c.tahun_dasar + 1) if t in tahun_ada]
        inv = df["PMAPMDN"].unstack("tahun")[tiga].reindex(self.kode)
        pangsa = (inv / inv.sum()).mean(axis=1).fillna(0).to_numpy()
        self.s_inv = pangsa / pangsa.sum()
        self.I_nas0 = float(df.xs(c.tahun_dasar, level="tahun")["PMAPMDN"].sum())
        self.komp_hist = pangsa_kelompok_investasi(df, tiga).reindex(self.kode)[KEL].to_numpy()
        self.komp_sektor = pangsa_sektor_investasi(df, tiga).reindex(self.kode)[KODE_SEKTOR]
        nas_komp = (self.komp_hist * (self.s_inv[:, None])).sum(axis=0)
        self.komp_hist_nas = nas_komp / nas_komp.sum()
        if c.komposisi_a2:
            k = np.array([max(float(c.komposisi_a2.get(x, 0) or 0), 0) for x in KEL])
            if k.sum() <= 0:
                raise GalatSimulasi("Komposisi sektor investasi tambahan berjumlah nol.")
            self.komp_a2 = np.tile(k / k.sum(), (P, 1))
        else:
            self.komp_a2 = self.komp_hist.copy()
        for i, kd in enumerate(self.kode):
            ov = o.get(kd, {})
            if all(ov.get(x) not in (None, "") for x in KEL):
                k = np.array([max(float(ov[x]), 0) for x in KEL])
                if k.sum() > 0:
                    self.komp_a2[i] = k / k.sum()

        # ---- fiskal daerah (tahun terakhir yang tersedia <= tahun dasar)
        def terakhir(kol):
            if kol not in df:
                return np.zeros(P)
            s = df[kol].unstack("tahun")
            s = s[[t for t in s.columns if t <= c.tahun_dasar]].reindex(self.kode)
            return s.ffill(axis=1).iloc[:, -1].fillna(0).to_numpy(float)

        self.belanja0 = terakhir("APBD_BELANJA")
        self.pad0 = terakhir("PAD")

        # ---- produktivitas sektoral untuk realokasi tenaga kerja
        tk_kol = [f"TK_{s}" for s in KODE_SEKTOR]
        ada_tk = df[tk_kol].notna().all(axis=1)
        th_tk = [t for t in sorted(tahun_ada) if t <= c.tahun_dasar
                 and ada_tk.xs(t, level="tahun").reindex(self.kode).fillna(False).all()]
        self.tahun_tk = th_tk[-1] if th_tk else None
        if self.tahun_tk:
            x = df.xs(self.tahun_tk, level="tahun").loc[self.kode]
            va = lambda ss: x[[f"VA_{s}" for s in ss]].sum(axis=1).to_numpy(float)
            tk = lambda ss: x[[f"TK_{s}" for s in ss]].sum(axis=1).to_numpy(float)
            self.P_prov = va(KODE_SEKTOR) / tk(KODE_SEKTOR)
            self.p_A = va(["A"]) / tk(["A"])
            tuj = TUJUAN_REALOKASI.get(c.tujuan_realokasi, ["C"])
            self.p_tuj = va(tuj) / tk(tuj)
        else:
            self.P_prov = self.p_A = self.p_tuj = np.ones(P)
            if c.realokasi_pp:
                self.peringatan.append("Tenaga kerja sektoral tidak tersedia; realokasi diabaikan.")

        # ---- jalur deterministik bersama
        t = self.t
        self.K_tren = self.K0[:, None] * np.exp(self.gK_tren[:, None] * t)
        self.Dfl = self.Dfl0[:, None] * np.exp(self.infl * t)
        g_inv = self._deret("g_investasi")
        self.gI_h = np.where(np.isnan(g_inv), self.gI, np.log1p(g_inv / 100))
        self.I_tren = self.s_inv[:, None] * self.I_nas0 * np.exp(np.cumsum(self.gI_h))[None, :]
        f_tfp = self._deret("faktor_tfp")
        self.tA = np.cumsum(np.where(np.isnan(f_tfp), 1.0, f_tfp))
        self._kejutan()
        self.A1_plan, self.A1_real, self.a1_diisi = self._rencana_a1()
        self.apbd = (c.apbd_persen / 100.0) * self.belanja0[:, None] * np.exp(self.infl * t)
        s = (c.realokasi_pp / 100.0) * t / self.H
        self.R = np.log(np.maximum(
            (self.P_prov[:, None] + s[None, :] * (self.p_tuj - self.p_A)[:, None]) / self.P_prov[:, None], 1e-6))
        self.lnYstar, self.g_sasaran = self._jalur_sasaran()
        self._determinan()

    def _deret(self, kunci):
        """Nilai per tahun proyeksi dari `jalur`; NaN bila tahun itu tidak diisi."""
        isi = (self.cfg.jalur or {}).get(kunci) or {}
        return np.array([float(isi[str(th)]) if isi.get(str(th)) not in (None, "") else np.nan
                         for th in self.tahun])

    def _kejutan(self):
        """Matriks (P,H) log deviasi: kj_A (TFP), kj_Y (PDRB), kj_L (TK); kj_I faktor realisasi."""
        P, H = len(self.kode), self.H
        self.kj_A, self.kj_Y, self.kj_L = np.zeros((P, H)), np.zeros((P, H)), np.zeros((P, H))
        self.kj_I = np.ones((P, H))
        for kj in self.cfg.kejutan or []:
            try:
                jenis, th0 = kj.get("jenis"), int(kj.get("tahun"))
                besar, rho = float(kj.get("besar") or 0) / 100, float(kj.get("persistensi", 1) or 0)
            except (TypeError, ValueError):
                continue
            if jenis not in JENIS_KEJUTAN or not besar or th0 > self.tahun[-1]:
                continue
            masker = self._masker(kj.get("cakupan"))
            h0 = max(th0 - self.tahun[0], 0)
            jalur = np.zeros(H)
            jalur[h0:] = besar * np.clip(rho, 0, 1) ** np.arange(H - h0)
            d = np.log1p(np.maximum(jalur, -0.95))[None, :] * masker[:, None]
            if jenis == "tfp":
                self.kj_A += d
            elif jenis == "pdrb":
                self.kj_Y += d
            elif jenis == "tk":
                self.kj_L += d
            else:
                self.kj_I *= np.exp(d)

    def _masker(self, cakupan):
        cak = str(cakupan or "nasional")
        if cak.startswith("pulau:"):
            return np.array([PULAU_PROVINSI[k] == cak[6:] for k in self.kode])
        if cak.startswith("prov:"):
            return np.array([str(k) == cak[5:] for k in self.kode])
        return np.ones(len(self.kode), bool)

    def _determinan(self):
        """Efek determinan TFP per pilar -> self.dt_pilar dan self.Dt (P,H) log TFP."""
        c, H, P = self.cfg, self.H, len(self.kode)
        self.dt_pilar, self.Dt = [], np.zeros((P, H))
        isian = c.determinan or {}
        if not isian or not c.koef_determinan:
            return
        a2 = self._a2_nasional()
        a2_tot = a2.sum()
        a_dana = np.cumsum(a2) / a2_tot if a2_tot > 0 else None
        a_linier = np.arange(1, H + 1) / H

        def angka(v, cadangan=0.0):
            try:
                return float(v) if v not in (None, "") else cadangan
            except (TypeError, ValueError):
                return cadangan

        for pilar in dict.fromkeys(ind["pilar"] for ind in c.koef_determinan):
            d = isian.get(pilar) or {}
            ind = [x for x in c.koef_determinan if x["pilar"] == pilar]
            koef = np.array([angka(x.get("koef")) for x in ind])
            se = np.array([angka(x.get("se")) for x in ind])
            porsi, biaya = angka(d.get("porsi")), angka(d.get("biaya"))
            didanai = porsi > 0 and biaya > 0
            if didanai and a2_tot <= 0:
                self.peringatan.append(f"Determinan {pilar}: porsi investasi tambahan diisi tetapi investasi "
                                       "tambahan nol; dipakai perbaikan yang diisi langsung.")
                didanai = False
            dana = porsi / 100 * a2_tot if didanai else 0.0
            dz = dana / 1000 / biaya if didanai else angka(d.get("dz"))
            ubah = d.get("indikator") or {}
            dz_ind = np.array([angka(ubah.get(x["kode"]), dz) for x in ind])
            if not np.any(dz_ind * koef):
                continue
            L0, R0 = JEDA_AWAL.get(pilar, (0, 1))
            L, R = max(int(angka(d.get("jeda"), L0)), 0), max(int(angka(d.get("penuh"), R0)), 1)
            a = a_dana if didanai else a_linier
            capai = lambda s: 0.0 if s <= 0 else (a[s - 1] if s <= H else 1.0)
            w = np.array([np.mean([capai(h + 1 - L - r) for r in range(R)]) for h in range(H)])
            masker = self._masker(d.get("cakupan"))
            efek = float(koef @ dz_ind)
            self.Dt += efek * masker[:, None] * w[None, :]
            self.dt_pilar.append({"pilar": pilar, "dz": dz, "dz_ind": dz_ind, "koef": koef, "se": se,
                                  "w": w, "masker": masker, "dana": dana, "didanai": didanai,
                                  "efek": efek, "jeda": L, "penuh": R})

    def _dt_acak(self, rng, D, k):
        """Efek determinan dengan koefisien diundi N(koef, se x skala). (D,P,H)."""
        out = np.zeros((D, len(self.kode), self.H))
        for p in self.dt_pilar:
            e = rng.normal(p["koef"][None, :], p["se"][None, :] * k, (D, len(p["koef"]))) @ p["dz_ind"]
            out += e[:, None, None] * p["masker"][None, :, None] * p["w"][None, None, :]
        return out

    def _laju_tfp(self, b1, b2):
        c = self.cfg
        hist = (self.mY - b1 * self.mK - b2 * self.mL)
        if c.mode_tfp == "nasional":
            dasar = np.full(len(self.kode), float(_ln1p_persen(c.tfp_nasional)))
        else:
            dasar = hist
        o = {int(k): v for k, v in (c.override or {}).items()}
        tetap = np.array([o.get(k, {}).get("tfp") not in (None, "") for k in self.kode])
        isian = np.array([_ln1p_persen(o[k]["tfp"]) if t else 0.0 for k, t in zip(self.kode, tetap)])
        self.tfp_tetap = tetap
        # faktor penyesuaian hanya untuk nilai yang tidak diisi langsung per provinsi
        return np.where(tetap, isian, dasar * c.faktor_tfp)

    def _sd_residual(self, b1, b2):
        w = np.array([1.0, -b1, -b2])
        return np.sqrt(np.maximum(np.einsum("i,pij,j->p", w, self.Sig, w), 0))

    def _rencana_a1(self):
        """A1 diisi per tahun (triliun, nasional) -> dibagi menurut pangsa provinsi."""
        c = self.cfg
        plan = self.I_tren.copy()
        diisi = np.zeros(self.H, bool)
        for h, th in enumerate(self.tahun):
            v = c.a1.get(str(th), c.a1.get(th))
            if v not in (None, ""):
                plan[:, h] = float(v) * 1000 * self.s_inv
                diisi[h] = True
        real = np.where(diisi[None, :], plan * c.rasio_realisasi, self.I_tren) * self.kj_I
        return plan, real, diisi

    def _a2_nasional(self):
        c = self.cfg
        out = np.zeros(self.H)
        for h, th in enumerate(self.tahun):
            v = c.a2.get(str(th), c.a2.get(th))
            if v not in (None, ""):
                out[h] = float(v) * 1000
        return out

    def _jalur_sasaran(self):
        c = self.cfg
        t = self.t
        K_h = self._deret("sasaran")
        K_h = np.where(np.isnan(K_h), c.sasaran, K_h) / 100.0
        kum = np.cumsum(np.log1p(K_h))  # ln(Y nasional sasaran / Y0) per tahun
        K_rata = np.expm1(kum / t)  # laju rata-rata dari tahun dasar sampai h
        K = float(K_rata[-1])
        P = len(self.kode)
        o = {int(k): v for k, v in (c.override or {}).items()}
        tetap = np.array([o.get(k, {}).get("sasaran") not in (None, "") for k in self.kode])
        g_tetap = np.array([float(o[k]["sasaran"]) / 100 if t_ else 0.0 for k, t_ in zip(self.kode, tetap)])
        if c.mode_sasaran == "manual":
            lnY = np.where(tetap[:, None], np.log1p(g_tetap)[:, None] * t, kum[None, :])
            return lnY, np.expm1(lnY[:, -1] / self.H)
        if c.mode_sasaran == "seragam" and not tetap.any():
            return np.tile(kum, (P, 1)), np.full(P, K)
        # Provinsi yang diisi sendiri dikunci; sisanya digeser bersama agar PDRB nasional mengikuti jalur sasaran.
        dev = ((np.expm1(self.mY) - np.expm1(self.gY_nas_hist)) * c.lambda_proporsional
               if c.mode_sasaran == "proporsional" else np.zeros(P))
        lnY = np.zeros((P, self.H))
        Ynas0 = self.Y0.sum()
        for h, th in enumerate(t):
            laju = lambda geser: np.where(tetap, g_tetap, np.maximum(K_rata[h] + dev + geser, -0.9))
            target = Ynas0 * np.exp(kum[h])
            lo, hi = -0.5, 0.5
            for _ in range(80):
                mid = (lo + hi) / 2
                if (self.Y0 * (1 + laju(mid)) ** th).sum() > target:
                    hi = mid
                else:
                    lo = mid
            gg = laju((lo + hi) / 2)
            lnY[:, h] = np.log1p(gg) * th
        capai = ((self.Y0 * np.exp(lnY[:, -1])).sum() / Ynas0) ** (1 / self.H) - 1
        if abs(capai - K) > 1e-4:
            self.peringatan.append(
                f"Sasaran provinsi yang dikunci membuat sasaran nasional {K * 100:.1f}% tidak dapat dipenuhi "
                f"(tercapai {capai * 100:.2f}%).")
        return lnY, np.expm1(lnY[:, -1] / self.H)

    # ============================================================ inti
    def _bonus(self, beta, dshare_lag):
        """beta (D,4), dshare_lag (P,4) atau (D,P,4) -> (D,P)."""
        if dshare_lag.ndim == 2:
            return beta @ dshare_lag.T
        return np.einsum("dk,dpk->dp", beta, dshare_lag)

    def _maju(self, b1, b2, gA, gL, kejut, beta, A2_real, dt=None):
        """Proyeksi skenario (A1 + A2 + APBD + realokasi + determinan). Bentuk keluaran (D,P,H)."""
        c = self.cfg
        dt = self.Dt[None] if dt is None else dt
        dKn = c.pass_through * (self.A1_real + A2_real - self.I_tren) + c.pass_through_apbd * self.apbd
        K = np.maximum(self.K_tren + dKn / self.Dfl, 0.05 * self.K_tren)
        total = self.A1_real + A2_real
        share = (self.A1_real[..., None] * self.komp_hist[:, None, :]
                 + A2_real[..., None] * self.komp_a2[:, None, :]) / np.where(total > 0, total, 1)[..., None]
        dshare = share - self.komp_hist[:, None, :]
        lag = np.concatenate([np.zeros((len(self.kode), 1, 4)), dshare[:, :-1, :]], axis=1)
        bonus = np.einsum("dk,phk->dph", beta, lag)
        B = np.cumsum(bonus, axis=2)
        lnK = np.log(K / self.K0[:, None])
        lnA = gA[..., None] * self.tA + B + self.R[None] + kejut + self.kj_A[None] + dt
        lnY = lnA + b1[..., None] * lnK[None] + b2[..., None] * (gL[..., None] * self.t + self.kj_L[None]) \
            + self.kj_Y[None]
        return {"lnY": lnY, "lnA": lnA, "lnK": lnK, "K": K, "B": B, "share": share}

    def _dasar(self, b1, b2, gA, gL, kejut):
        """Jalur Bn: hanya A1 (tanpa A2, APBD tambahan, dan realokasi). A1 kosong = tren."""
        c = self.cfg
        dKn = c.pass_through * (self.A1_real - self.I_tren)
        K = np.maximum(self.K_tren + dKn / self.Dfl, 0.05 * self.K_tren)
        lnK = np.log(K / self.K0[:, None])
        lnA = gA[..., None] * self.tA + kejut + self.kj_A[None]
        lnY = lnA + b1[..., None] * lnK[None] + b2[..., None] * (gL[..., None] * self.t + self.kj_L[None]) \
            + self.kj_Y[None]
        return {"lnY": lnY, "lnA": lnA, "lnK": lnK, "K": K}

    def _mundur(self, b1, b2, gA, gL, kejut, beta, dt=None):
        """Investasi yang dibutuhkan untuk jalur sasaran. Bentuk (D,P,H)."""
        c = self.cfg
        dt = self.Dt[None] if dt is None else dt
        D, P, H = gA.shape[0], len(self.kode), self.H
        lnK = np.zeros((D, P, H))
        I_real = np.zeros((D, P, H))
        B = np.zeros((D, P, H))
        lnA = np.zeros((D, P, H))
        dshare_lag = np.zeros((D, P, 4))
        Bc = np.zeros((D, P))
        for h in range(H):
            Bc = Bc + self._bonus(beta, dshare_lag)
            B[..., h] = Bc
            lnA[..., h] = gA * self.tA[h] + Bc + self.R[None, :, h] + kejut[..., h] + self.kj_A[None, :, h] \
                + dt[..., h]
            lnK[..., h] = (self.lnYstar[None, :, h] - lnA[..., h] - b2 * (gL * self.t[h] + self.kj_L[None, :, h])
                           - self.kj_Y[None, :, h]) / b1
            Kn_req = self.K0 * np.exp(lnK[..., h]) * self.Dfl[:, h]
            Kn_tr = self.K_tren[:, h] * self.Dfl[:, h]
            I_real[..., h] = self.I_tren[:, h] + (Kn_req - Kn_tr - c.pass_through_apbd * self.apbd[:, h]) \
                / max(c.pass_through, 1e-6)
            tambah = np.maximum(I_real[..., h] - self.A1_real[:, h], 0)
            total = self.A1_real[:, h] + tambah
            share = (self.A1_real[:, h, None] * self.komp_hist + tambah[..., None] * self.komp_a2) \
                / np.where(total > 0, total, 1)[..., None]
            dshare_lag = share - self.komp_hist
        return {"lnK": lnK, "I_real": I_real, "B": B, "lnA": lnA}

    def _bobot_alokasi(self, keb_tambahan):
        c = self.cfg
        if c.alokasi_a2 == "pdrb":
            w = self.Y0.copy()
        elif c.alokasi_a2 == "investasi":
            w = self.s_inv.copy()
        elif c.alokasi_a2 == "manual":
            o = {int(k): v for k, v in (c.override or {}).items()}
            w = np.array([float(o.get(k, {}).get("bobot_a2") or 0) for k in self.kode])
        else:
            w = np.maximum(keb_tambahan, 0)
        if w.sum() <= 0:
            self.peringatan.append("Bobot alokasi investasi tambahan berjumlah nol; dipakai pangsa PDRB.")
            w = self.Y0.copy()
        return w / w.sum()

    # ======================================================= jalankan
    def jalankan(self, dengan_mc=True):
        c = self.cfg
        one = np.ones((1, 1))
        b1, b2 = one * c.b1, one * c.b2
        gA = self.gA[None]
        gL = self.gL[None]
        nol = np.zeros((1, len(self.kode), self.H))
        beta = np.array([[c.beta.get(k, 0.0) for k in KEL]])

        dasar = self._dasar(b1, b2, gA, gL, nol)
        keb = self._mundur(b1[:, 0][:, None], b2[:, 0][:, None], gA, gL, nol, beta)
        keb_tambahan = (keb["I_real"][0] - self.A1_real)  # (P,H) realisasi di atas A1
        self.bobot_a2 = self._bobot_alokasi(keb_tambahan.sum(axis=1))
        a2_nas = self._a2_nasional()
        self.A2_plan = self.bobot_a2[:, None] * a2_nas[None, :]
        A2_real = self.A2_plan * c.rasio_realisasi * self.kj_I
        sken = self._maju(b1, b2, gA, gL, nol, beta, A2_real)

        hasil = self._kemas(dasar, sken, keb, A2_real, a2_nas)
        if dengan_mc and c.n_simulasi > 0:
            hasil["ketidakpastian"] = self._monte_carlo(A2_real, hasil)
        hasil["meta"]["peringatan"] = self.peringatan
        return hasil

    def _sasaran_rata_nas(self):
        """Laju rata-rata jalur sasaran nasional (%/thn); sama dengan `sasaran` bila jalur konstan."""
        Yt = (self.Y0 * np.exp(self.lnYstar[:, -1])).sum()
        return ((Yt / self.Y0.sum()) ** (1 / self.H) - 1) * 100

    # ================================================== Monte Carlo
    def _monte_carlo(self, A2_real, hasil):
        c = self.cfg
        rng = np.random.default_rng(c.seed)
        D, P, H = int(c.n_simulasi), len(self.kode), self.H
        k = c.skala_se
        b1 = np.clip(rng.normal(c.b1, c.se_b1 * k, D), 0.05, 0.95)[:, None]
        b2 = np.clip(rng.normal(c.b2, c.se_b2 * k, D), 0.0, 1.0)[:, None]
        sd_res = self._sd_residual(c.b1, c.b2)
        if c.mode_tfp == "historis":
            gA = (self.mY[None] - b1 * self.mK[None] - b2 * self.mL[None]) * c.faktor_tfp
            gA = gA + rng.normal(0, 1, (D, P)) * (sd_res / np.sqrt(self.n_hist)) * k
            gA = np.where(self.tfp_tetap[None], self.gA[None], gA)
        else:
            gA = np.tile(self.gA, (D, 1))
        gL = np.tile(self.gL, (D, 1))
        if c.mode_tk == "historis":
            sdL = np.sqrt(self.Sig[:, 2, 2])
            gL = gL + np.where(self.tk_tetap[None], 0.0, rng.normal(0, 1, (D, P)) * (sdL / np.sqrt(self.n_hist)) * k)
        kejut = np.cumsum(rng.normal(0, 1, (D, P, H)) * (sd_res * c.volatilitas_tfp)[None, :, None], axis=2)
        beta = np.stack([rng.normal(c.beta.get(x, 0), c.se_beta.get(x, 0) * k, D) for x in KEL], axis=1)

        dt = self._dt_acak(rng, D, k)
        sken = self._maju(b1, b2, gA, gL, kejut, beta, A2_real, dt)
        keb = self._mundur(b1, b2, gA, gL, kejut, beta, dt)

        Ynas = (self.Y0[None, :, None] * np.exp(sken["lnY"])).sum(axis=1)  # (D,H)
        Ynas0 = self.Y0.sum()
        g_th = np.diff(np.concatenate([np.full((D, 1), Ynas0), Ynas], axis=1), axis=1) \
            / np.concatenate([np.full((D, 1), Ynas0), Ynas[:, :-1]], axis=1) * 100
        g_rata_nas = ((Ynas[:, -1] / Ynas0) ** (1 / H) - 1) * 100
        g_rata_prov = np.expm1(sken["lnY"][..., -1] / H) * 100  # (D,P)
        sasaran_prov = self.g_sasaran * 100
        prob_prov = (g_rata_prov >= sasaran_prov[None] - 1e-9).mean(axis=0)
        keb_kum = (keb["I_real"] - self.A1_real[None]).sum(axis=2)  # (D,P)
        keb_kum_nas = keb_kum.sum(axis=1) / 1000
        keb_T_nas = keb["I_real"][..., -1].sum(axis=1) / 1000

        q = lambda x, p: [float(v) for v in np.percentile(x, p, axis=0)]
        hist, tepi = np.histogram(g_rata_nas, bins=24)
        return {
            "n": D,
            "g_tahunan": {"p10": q(g_th, 10), "p50": q(g_th, 50), "p90": q(g_th, 90)},
            "g_rata": {"p10": float(np.percentile(g_rata_nas, 10)), "p50": float(np.percentile(g_rata_nas, 50)),
                       "p90": float(np.percentile(g_rata_nas, 90))},
            "prob_nasional": float((g_rata_nas >= self._sasaran_rata_nas() - 1e-9).mean()),
            "prob_provinsi": {int(kd): float(p) for kd, p in zip(self.kode, prob_prov)},
            "g_prov_p10": {int(kd): float(v) for kd, v in zip(self.kode, np.percentile(g_rata_prov, 10, axis=0))},
            "g_prov_p90": {int(kd): float(v) for kd, v in zip(self.kode, np.percentile(g_rata_prov, 90, axis=0))},
            "n_prov_yakin": int((prob_prov >= 0.8).sum()),
            "kebutuhan_tambahan_kum": {"p50": float(np.percentile(keb_kum_nas, 50)),
                                       "p80": float(np.percentile(keb_kum_nas, 80)),
                                       "p90": float(np.percentile(keb_kum_nas, 90))},
            "kebutuhan_T": {"p50": float(np.percentile(keb_T_nas, 50)),
                            "p80": float(np.percentile(keb_T_nas, 80)),
                            "p90": float(np.percentile(keb_T_nas, 90))},
            "keb_prov_p80": {int(kd): float(v) for kd, v in zip(self.kode, np.percentile(keb_kum, 80, axis=0))},
            "histogram": {"nilai": [int(v) for v in hist], "tepi": [float(v) for v in tepi]},
        }

    # ====================================================== kemas
    def _kemas(self, dasar, sken, keb, A2_real, a2_nas):
        c, H = self.cfg, self.H
        T = lambda x: [float(v) for v in np.asarray(x)]
        Y0 = self.Y0
        w = Y0 / Y0.sum()

        def nasional_Y(lnY):
            return np.concatenate([[Y0.sum()], (Y0[:, None] * np.exp(lnY)).sum(axis=0)])

        def laju(seri):
            return (seri[1:] / seri[:-1] - 1) * 100

        Yd, Ys = nasional_Y(dasar["lnY"][0]), nasional_Y(sken["lnY"][0])
        Yt = nasional_Y(self.lnYstar)
        tfp = lambda lnA: np.concatenate([[100.0], 100 * np.exp((w[:, None] * lnA).sum(axis=0))])
        K_keb = self.K0[:, None] * np.exp(keb["lnK"][0])
        I_keb = keb["I_real"][0]
        tambahan_keb = I_keb - self.A1_real
        r = max(c.rasio_realisasi, 1e-6)

        g_rata = lambda s: ((s[-1] / s[0]) ** (1 / H) - 1) * 100
        lnY_s = sken["lnY"][0]
        kontrib = {
            "modal": c.b1 * sken["lnK"][:, -1] / H * 100,
            "tk": c.b2 * self.gL * 100,
            "tfp_tren": self.gA * self.tA[-1] / H * 100,
            "sektoral": sken["B"][0][:, -1] / H * 100,
            "realokasi": self.R[:, -1] / H * 100,
            "determinan": self.Dt[:, -1] / H * 100,
            "kejutan": (self.kj_A[:, -1] + self.kj_Y[:, -1] + c.b2 * self.kj_L[:, -1]) / H * 100,
        }
        kontrib_nas = {k: float((w * v).sum()) for k, v in kontrib.items()}

        nas = {
            "tahun": [c.tahun_dasar] + self.tahun,
            "pdrb_dasar": T(Yd), "pdrb_skenario": T(Ys), "pdrb_sasaran": T(Yt),
            "g_dasar": T(laju(Yd)), "g_skenario": T(laju(Ys)), "g_sasaran": T(laju(Yt)),
            "pmtb_dasar": T(np.concatenate([[self.K0.sum()], dasar["K"].sum(axis=0)])),
            "pmtb_skenario": T(np.concatenate([[self.K0.sum()], sken["K"].sum(axis=0)])),
            "pmtb_kebutuhan": T(np.concatenate([[self.K0.sum()], K_keb.sum(axis=0)])),
            "inv_tren": T(self.I_tren.sum(axis=0) / 1000),
            "inv_a1": T(self.A1_real.sum(axis=0) / 1000),
            "inv_a1_rencana": T(self.A1_plan.sum(axis=0) / 1000),
            "inv_a2": T(a2_nas / 1000),
            "inv_a2_realisasi": T(A2_real.sum(axis=0) / 1000),
            "inv_kebutuhan": T(I_keb.sum(axis=0) / 1000),
            "tambahan_kebutuhan": T(tambahan_keb.sum(axis=0) / 1000),
            "tambahan_rencana": T(tambahan_keb.sum(axis=0) / 1000 / r),
            "apbd_tambahan": T(self.apbd.sum(axis=0) / 1000),
            "tfp_dasar": T(tfp(dasar["lnA"][0])), "tfp_skenario": T(tfp(sken["lnA"][0])),
            "tfp_kebutuhan": T(tfp(keb["lnA"][0])),
            "ringkasan": {
                "g_rata_dasar": g_rata(Yd), "g_rata_skenario": g_rata(Ys), "g_rata_sasaran": g_rata(Yt),
                "a2_kumulatif": float(a2_nas.sum() / 1000),
                "a2_realisasi_kumulatif": float(A2_real.sum() / 1000),
                "kebutuhan_tambahan_kumulatif": float(tambahan_keb.sum() / 1000),
                "kebutuhan_tambahan_rencana_kumulatif": float(tambahan_keb.sum() / 1000 / r),
                "kebutuhan_T": float(I_keb[:, -1].sum() / 1000),
                "inv_tren_T": float(self.I_tren[:, -1].sum() / 1000),
                "selisih_a2": float((tambahan_keb.sum() - A2_real.sum()) / 1000),
                "g_K_kebutuhan": float(np.expm1(np.log(K_keb.sum(axis=0)[-1] / self.K0.sum()) / H) * 100),
                "g_K_tren": float(np.expm1(np.log(self.K_tren.sum(axis=0)[-1] / self.K0.sum()) / H) * 100),
                "g_K_dasar": float(np.expm1(np.log(dasar["K"].sum(axis=0)[-1] / self.K0.sum()) / H) * 100),
                "tfp_T_dasar": float(tfp(dasar["lnA"][0])[-1]),
                "tfp_T_skenario": float(tfp(sken["lnA"][0])[-1]),
                "kontribusi": kontrib_nas,
                "pdrb_tambahan_T": float((Ys[-1] - Yd[-1]) / 1000),
            },
        }

        prov = []
        g_d = np.expm1(dasar["lnY"][0][:, -1] / H) * 100
        g_s = np.expm1(lnY_s[:, -1] / H) * 100
        for i, kd in enumerate(self.kode):
            Ys_i = np.concatenate([[Y0[i]], Y0[i] * np.exp(lnY_s[i])])
            Yd_i = np.concatenate([[Y0[i]], Y0[i] * np.exp(dasar["lnY"][0][i])])
            prov.append({
                "kode": kd, "nama": NAMA_PROVINSI[kd], "pulau": PULAU_PROVINSI[kd],
                "pdrb0": float(Y0[i]), "pmtb0": float(self.K0[i]), "pmtb0_nominal": float(self.Kn0[i]),
                "inv0": float(self.I0[i]),
                "bonus_kebutuhan_pp": float((keb["B"][0][i, -1] + self.R[i, -1] + self.Dt[i, -1]) / H * 100),
                "rasio_inv_pmtb": float(self.I0[i] / self.Kn0[i]),
                "pad": float(self.pad0[i]), "belanja_apbd": float(self.belanja0[i]),
                "g_tfp": float(np.expm1(self.gA[i]) * 100), "g_tk": float(np.expm1(self.gL[i]) * 100),
                "g_pmtb_tren": float(np.expm1(self.gK_tren[i]) * 100),
                "g_sasaran": float(self.g_sasaran[i] * 100),
                "g_dasar": float(g_d[i]), "g_skenario": float(g_s[i]),
                "g_K_kebutuhan": float(np.expm1(keb["lnK"][0][i, -1] / H) * 100),
                "tfp_T_dasar": float(100 * np.exp(dasar["lnA"][0][i, -1])),
                "tfp_T_skenario": float(100 * np.exp(sken["lnA"][0][i, -1])),
                "bobot_a2": float(self.bobot_a2[i]),
                "a2_kumulatif": float(self.A2_plan[i].sum()),
                "kebutuhan_tambahan_kumulatif": float(tambahan_keb[i].sum()),
                "kebutuhan_T": float(I_keb[i, -1]),
                "inv_tren_T": float(self.I_tren[i, -1]),
                "selisih": float(tambahan_keb[i].sum() - A2_real[i].sum()),
                "rasio_kebutuhan_pdrb": float(tambahan_keb[i].sum() / H / self.Yn0[i] * 100),
                "rasio_kebutuhan_belanja": float(tambahan_keb[i].sum() / H / self.belanja0[i])
                if self.belanja0[i] > 0 else None,
                "kontribusi": {k: float(v[i]) for k, v in kontrib.items()},
                "komposisi_hist": {k: float(v) for k, v in zip(KEL, self.komp_hist[i])},
                "komposisi_a2": {k: float(v) for k, v in zip(KEL, self.komp_a2[i])},
                "seri": {"g_skenario": T(laju(Ys_i)), "g_dasar": T(laju(Yd_i)),
                         "kebutuhan": T(I_keb[i] / 1000), "a2": T(self.A2_plan[i] / 1000),
                         "tren": T(self.I_tren[i] / 1000)},
            })

        # efek kejutan pada ln PDRB nasional (pp level) dan jalur sasaran per tahun
        efek_kj = self.kj_A + self.kj_Y + c.b2 * self.kj_L
        nas["kejutan_level"] = T(np.expm1((w[:, None] * efek_kj).sum(axis=0)) * 100)
        nas["realisasi_faktor"] = T((self.s_inv[:, None] * self.kj_I).sum(axis=0))
        nas["sasaran_tahunan"] = T(np.expm1(np.diff(np.concatenate([[0.0], np.log(Yt[1:] / Yt[0])]))) * 100)
        for p, i in zip(prov, range(len(self.kode))):
            p["seri"]["tfp"] = T(100 * np.exp(sken["lnA"][0][i]))
            p["seri"]["g_sasaran"] = T(np.expm1(np.diff(np.concatenate([[0.0], self.lnYstar[i]]))) * 100)

        nas["determinan"] = self._ringkas_determinan(w)
        for p, i in zip(prov, range(len(self.kode))):
            p["seri"]["determinan"] = T(np.expm1(self.Dt[i]) * 100)

        Kn_s = sken["K"] * self.Dfl
        kolom = ["kode", "provinsi", "pulau", "tahun", "I_tren", "A1_real", "A2_real", "I_kebutuhan",
                 "PMTB_nominal", "PMTB_riil", "PMTB_kebutuhan", "lnA_skenario", "bonus_sektor", "determinan_ln", "kejutan_ln",
                 "faktor_realisasi", "PDRB_dasar", "PDRB_skenario", "PDRB_sasaran", "g_dasar", "g_skenario",
                 "g_sasaran"]
        baris = []
        for i, kd in enumerate(self.kode):
            Yd_i = Y0[i] * np.exp(np.concatenate([[0.0], dasar["lnY"][0][i]]))
            Ys_i = Y0[i] * np.exp(np.concatenate([[0.0], lnY_s[i]]))
            Yt_i = Y0[i] * np.exp(np.concatenate([[0.0], self.lnYstar[i]]))
            for h, th in enumerate(self.tahun):
                baris.append([kd, NAMA_PROVINSI[kd], PULAU_PROVINSI[kd], th,
                              float(self.I_tren[i, h]), float(self.A1_real[i, h]), float(A2_real[i, h]),
                              float(I_keb[i, h]), float(Kn_s[i, h]), float(sken["K"][i, h]), float(K_keb[i, h]),
                              float(sken["lnA"][0][i, h]), float(sken["B"][0][i, h]),
                              float(self.Dt[i, h]), float(efek_kj[i, h]),
                              float(self.kj_I[i, h]), float(Yd_i[h + 1]), float(Ys_i[h + 1]), float(Yt_i[h + 1]),
                              float((Yd_i[h + 1] / Yd_i[h] - 1) * 100), float((Ys_i[h + 1] / Ys_i[h] - 1) * 100),
                              float((Yt_i[h + 1] / Yt_i[h] - 1) * 100)])
        hitung = {"kolom": kolom, "baris": baris}

        sektoral = self._sektoral(tambahan_keb, A2_real, sken)
        meta = {
            "tahun_dasar": c.tahun_dasar, "tahun_target": c.tahun_target, "H": H,
            "tahun_tk": self.tahun_tk,
            "parameter": {"b1": c.b1, "b2": c.b2, "se_b1": c.se_b1, "se_b2": c.se_b2, "beta": c.beta},
            "asumsi": {
                "g_investasi_tren": float(np.expm1(self.gI) * 100),
                "inflasi_pmtb": float(np.expm1(self.infl) * 100),
                "g_pdrb_hist_nas": float(np.expm1(self.gY_nas_hist) * 100),
                "g_pmtb_hist_nas": float(np.expm1(self.gK_nas_hist) * 100),
                "a1_diisi": [int(th) for th, d in zip(self.tahun, self.a1_diisi) if d],
                "g_investasi_tahunan": T(np.expm1(self.gI_h) * 100),
                "faktor_tfp_tahunan": T(np.diff(np.concatenate([[0.0], self.tA]))),
            },
            "jalur": c.jalur or {},
            "kejutan": list(c.kejutan or []),
        }
        return {"meta": meta, "nasional": nas, "provinsi": prov, "sektoral": sektoral, "hitung": hitung}

    def _ringkas_determinan(self, w):
        """Per pilar: perbaikan, efek (% TFP nasional), kontribusi laju, dana, dan efek per Rp 100 T."""
        H = self.H
        pilar, seri = [], {}
        for p in self.dt_pilar:
            bobot = float((w * p["masker"]).sum())
            ln_T = p["efek"] * p["w"][-1] * bobot
            pp = ln_T / H * 100
            dana_T = p["dana"] / 1000
            pilar.append({
                "pilar": p["pilar"], "nama": NAMA_PILAR.get(p["pilar"], p["pilar"]),
                "dz": float(p["dz"]), "didanai": p["didanai"], "jeda": p["jeda"], "penuh": p["penuh"],
                "efek_penuh": float(np.expm1(p["efek"] * bobot) * 100),
                "efek_T": float(np.expm1(ln_T) * 100),
                "pp_laju": float(pp), "dana_T": float(dana_T),
                "pp_per_100T": float(pp / dana_T * 100) if dana_T > 0 else None,
            })
            seri[p["pilar"]] = [float(v) for v in np.expm1(p["efek"] * p["w"] * bobot) * 100]
        total_T = float(np.expm1((w * self.Dt[:, -1]).sum()) * 100)
        return {"pilar": pilar, "seri": seri, "efek_T": total_T,
                "pp_laju": float((w * self.Dt[:, -1]).sum() / H * 100)}

    def _sektoral(self, tambahan_keb, A2_real, sken):
        c = self.cfg
        positif = np.maximum(tambahan_keb, 0).sum(axis=1)  # (P,)
        a2_kum = A2_real.sum(axis=1)
        kel_idx = {k: i for i, k in enumerate(KEL)}
        matriks, matriks_a2 = {}, {}
        tot_sektor = {s: 0.0 for s in KODE_SEKTOR}
        tot_sektor_a2 = {s: 0.0 for s in KODE_SEKTOR}
        for i, kd in enumerate(self.kode):
            baris, baris_a2 = {}, {}
            for s in KODE_SEKTOR:
                kel = kel_idx[KELOMPOK_SEKTOR[s]]
                bobot = self.komp_a2[i, kel] * float(self.komp_sektor.loc[kd, s])
                baris[s] = float(positif[i] * bobot)
                baris_a2[s] = float(a2_kum[i] * bobot)
                tot_sektor[s] += baris[s]
                tot_sektor_a2[s] += baris_a2[s]
            matriks[kd], matriks_a2[kd] = baris, baris_a2
        w = self.Y0 / self.Y0.sum()
        dshare_rata = (sken["share"] - self.komp_hist[:, None, :]).mean(axis=1)  # (P,4)
        kelompok = []
        for j, (k, nama) in enumerate(KELOMPOK):
            b = c.beta.get(k, 0.0)
            kelompok.append({
                "kode": k, "nama": nama, "beta": b, "se": c.se_beta.get(k, 0.0),
                "pangsa_hist_nas": float(self.komp_hist_nas[j]),
                "pangsa_a2_nas": float((self.komp_a2[:, j] * self.bobot_a2).sum()),
                "bonus_pp": float((w * dshare_rata[:, j]).sum() * b * 100),
            })
        sektor = [{"kode": s, "nama": NAMA_SEKTOR[s], "kelompok": KELOMPOK_SEKTOR[s],
                   "kebutuhan": tot_sektor[s], "a2": tot_sektor_a2[s]} for s in KODE_SEKTOR]
        return {"kelompok": kelompok, "sektor": sektor, "matriks": matriks, "matriks_a2": matriks_a2}
