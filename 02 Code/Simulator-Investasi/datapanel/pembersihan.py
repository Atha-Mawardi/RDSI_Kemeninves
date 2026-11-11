"""
Pipeline pembersihan panel provinsi-tahun.

Masukan: xlsx (semua sheet) atau csv, format lebar (satu baris = provinsi-tahun)
atau panjang (kolom provinsi, tahun, variabel, nilai). Keluaran: DataFrame lebar
ber-indeks (kode, tahun) dengan kolom kode kanonik, catatan per sel, dan daftar
temuan yang ditulis ke laporan dan ke workbook hasil.

Urutan langkah sengaja tetap supaya laporan dapat dibaca dari atas ke bawah:
baca -> petakan kolom -> kunci provinsi/tahun -> angka -> satuan -> lipat
pemekaran dan duplikat -> konsistensi -> imputasi -> lonjakan -> cakupan.
"""

import io
import re
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from . import variabel as V
from .papua import hitung_pangsa
from .papua import koreksi_geser as koreksi_geser_papua
from .referensi import KODE_PROVINSI, KODE_SEKTOR, NAMA_PROVINSI, cari_kode_provinsi, kode_pemekaran

KOLOM_TAHUN = {"year", "tahun", "thn"}
KOLOM_KODE = {"code_prov", "kode_prov", "kode", "kode_provinsi", "kd_prov", "prov_code", "kode prov"}
KOLOM_NAMA = {"pre_prov", "prov", "provinsi", "nama_provinsi", "prov_nama", "province", "nama provinsi"}
KOSONG = {"", "-", "--", "..", "...", "na", "n/a", "nan", "null", "none", "#n/a", "#div/0!",
          "#value!", "#ref!", "tidak ada", "x"}

OPSI_BAWAAN = {
    "imputasi": "interpolasi",  # tidak | interpolasi | locf | interpolasi_locf
    "lipat_pemekaran": True,
    "ambang_lonjakan": 50.0,  # persen perubahan tahunan yang ditandai
    "tahun_min": None,
    "tahun_max": None,
}


@dataclass
class Temuan:
    tingkat: str  # info | peringatan | error
    langkah: str
    pesan: str
    detail: list = field(default_factory=list)

    def ke_dict(self):
        return {"tingkat": self.tingkat, "langkah": self.langkah, "pesan": self.pesan,
                "detail": self.detail[:50]}


@dataclass
class HasilPembersihan:
    df: pd.DataFrame
    catatan: dict
    temuan: list
    pemetaan: dict
    kolom_tak_dikenal: list
    rincian: pd.DataFrame | None = None  # baris enam provinsi Papua sebelum dilipat

    def pangsa_pemekaran(self, sumber):
        if self.rincian is None or self.rincian.empty:
            return {}
        p = hitung_pangsa(self.rincian, sumber)
        return p if p["kunci"] else {}

    @property
    def ada_galat(self):
        return any(t.tingkat == "error" for t in self.temuan)

    def ringkasan(self):
        wajib_ada = [k for k in V.WAJIB if k in self.df.columns]
        tahun = sorted(set(self.df.index.get_level_values("tahun"))) if len(self.df) else []
        return {
            "n_baris": int(len(self.df)),
            "n_provinsi": int(self.df.index.get_level_values("kode").nunique()) if len(self.df) else 0,
            "tahun": [int(t) for t in tahun],
            "n_variabel": int(self.df.shape[1]),
            "n_imputasi": sum(1 for c in self.catatan.values() for v in c.values()
                              if v.startswith("imputasi")),
            "n_lonjakan": sum(1 for c in self.catatan.values() for v in c.values()
                              if v.startswith("lonjakan")),
            "wajib_hilang": [k for k in V.WAJIB if k not in wajib_ada],
            "lengkap_untuk_simulasi": len(wajib_ada) == len(V.WAJIB),
            "n_peringatan": sum(t.tingkat == "peringatan" for t in self.temuan),
            "n_galat": sum(t.tingkat == "error" for t in self.temuan),
        }


def ke_angka(seri):
    """Ubah kolom campuran teks/angka ke float. Kembalikan (seri, n_teks, n_gagal)."""
    if pd.api.types.is_numeric_dtype(seri) and not pd.api.types.is_bool_dtype(seri):
        return seri.astype(float), 0, 0
    hasil = np.full(len(seri), np.nan)
    n_teks = n_gagal = 0
    for i, v in enumerate(seri.tolist()):
        if v is None or (isinstance(v, float) and np.isnan(v)):
            continue
        if isinstance(v, (int, float, np.number)) and not isinstance(v, bool):
            hasil[i] = float(v)
            continue
        s = str(v).strip().replace("\u00a0", "").replace(" ", "")
        n_teks += 1
        if s.lower() in KOSONG:
            continue
        s = s.replace("Rp", "").replace("%", "")
        if "," in s and "." in s:
            # pemisah terakhir adalah desimal: 1.234,5 (Indonesia) atau 1,234.5
            s = s.replace(".", "").replace(",", ".") if s.rfind(",") > s.rfind(".") else s.replace(",", "")
        elif "," in s:
            s = s.replace(",", "") if re.fullmatch(r"-?\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
        elif re.fullmatch(r"-?\d{1,3}(\.\d{3}){2,}", s):
            s = s.replace(".", "")
        try:
            hasil[i] = float(s)
        except ValueError:
            n_gagal += 1
    return pd.Series(hasil, index=seri.index), n_teks, n_gagal


def _norm(nama):
    return re.sub(r"\s+", " ", str(nama)).strip().lower()


class PipelinePembersihan:
    def __init__(self, opsi=None):
        self.opsi = {**OPSI_BAWAAN, **(opsi or {})}
        self.temuan = []
        self.catatan = {}
        self.rincian = None

    def _catat(self, tingkat, langkah, pesan, detail=None):
        self.temuan.append(Temuan(tingkat, langkah, pesan, detail or []))

    def _tandai(self, kode, tahun, var, teks):
        self.catatan.setdefault((int(kode), int(tahun)), {})[var] = teks

    # ------------------------------------------------------------------ baca
    def _baca(self, berkas, nama_berkas):
        nama = (nama_berkas or getattr(berkas, "name", "")).lower()
        data = berkas.read() if hasattr(berkas, "read") else open(berkas, "rb").read()
        if nama.endswith((".xlsx", ".xlsm", ".xls")):
            mentah = pd.read_excel(io.BytesIO(data), sheet_name=None, header=None)
            if self.opsi.get("sheet") in mentah:
                mentah = {self.opsi["sheet"]: mentah[self.opsi["sheet"]]}
        elif nama.endswith((".csv", ".txt")):
            teks = None
            for enc in ("utf-8-sig", "latin-1"):
                try:
                    teks = data.decode(enc)
                    break
                except UnicodeDecodeError:
                    continue
            mentah = {"csv": pd.read_csv(io.StringIO(teks), sep=None, engine="python", header=None)}
        else:
            raise ValueError("Format berkas harus .xlsx atau .csv")
        self._catat("info", "Baca berkas", f"{len(mentah)} sheet terbaca dari {nama_berkas}.")
        return mentah

    def _cari_header(self, mentah):
        """Baris header = baris pertama (maks. 15) yang memuat kolom tahun dan provinsi."""
        for i in range(min(15, len(mentah))):
            sel = {_norm(v) for v in mentah.iloc[i].tolist() if pd.notna(v)}
            if sel & KOLOM_TAHUN and (sel & KOLOM_KODE or sel & KOLOM_NAMA):
                return i
        return None

    def _sheet_ke_tabel(self, nama_sheet, mentah):
        i = self._cari_header(mentah)
        if i is None:
            self._catat("info", "Baca berkas", f"Sheet '{nama_sheet}' dilewati: tidak ada kolom provinsi dan tahun.")
            return None
        df = mentah.iloc[i + 1:].copy()
        kolom, terlihat = [], {}
        for c in mentah.iloc[i].tolist():
            c = "" if pd.isna(c) else re.sub(r"\s+", " ", str(c)).strip()
            if c in terlihat:
                terlihat[c] += 1
                c = f"{c}.{terlihat[c]}"
            else:
                terlihat[c] = 0
            kolom.append(c)
        df.columns = kolom
        df = df.loc[:, [c for c in df.columns if c]].dropna(how="all")
        low = {c: _norm(c) for c in df.columns}
        if {"variabel", "nilai"} <= set(low.values()):
            df = self._dari_panjang(df, low)
        return df

    def _dari_panjang(self, df, low):
        inv = {v: k for k, v in low.items()}
        kunci = [k for k in df.columns if low[k] in KOLOM_TAHUN | KOLOM_KODE | KOLOM_NAMA]
        lebar = df.pivot_table(index=kunci, columns=inv["variabel"], values=inv["nilai"],
                               aggfunc="last").reset_index()
        lebar.columns.name = None
        self._catat("info", "Baca berkas", "Format panjang (variabel, nilai) diputar ke format lebar.")
        return lebar

    # --------------------------------------------------------- petakan kolom
    def _petakan(self, tabel):
        alias = V.peta_alias()
        prioritas = {v.kode: [a.lower() for a in (v.kode,) + v.alias] for v in V.DAFTAR}
        pemetaan, tak_dikenal = {}, []
        for c in tabel.columns:
            n = _norm(c)
            if n in KOLOM_TAHUN | KOLOM_KODE | KOLOM_NAMA | {"pulau", "island", "no", "no."}:
                continue
            kode = alias.get(n)
            if kode is None:
                tak_dikenal.append(c)
                continue
            lama = pemetaan.get(kode)
            if lama is None or prioritas[kode].index(n) < prioritas[kode].index(_norm(lama)):
                pemetaan[kode] = c
        return pemetaan, tak_dikenal

    # ------------------------------------------------------------ kunci baris
    def _kunci(self, tabel, nama_sheet):
        low = {c: _norm(c) for c in tabel.columns}
        c_tahun = next(c for c in tabel.columns if low[c] in KOLOM_TAHUN)
        c_kode = next((c for c in tabel.columns if low[c] in KOLOM_KODE), None)
        c_nama = next((c for c in tabel.columns if low[c] in KOLOM_NAMA), None)

        tahun, _, _ = ke_angka(tabel[c_tahun])
        kode = pd.Series(np.nan, index=tabel.index)
        lipat = pd.Series(False, index=tabel.index)
        tak_kenal = set()
        kode38 = pd.Series(np.nan, index=tabel.index)
        if c_kode is not None:
            k, _, _ = ke_angka(tabel[c_kode])
            sah = k.isin(KODE_PROVINSI)
            # kode 92-97 (38 provinsi) tidak dipercaya; serahkan ke nama
            kode[sah] = k[sah]
        if c_nama is not None:
            # nama provinsi pemekaran menang atas kolom kode (berkas BKPM mengisi kode induk)
            anak = tabel[c_nama].map(lambda nm: None if pd.isna(nm) else kode_pemekaran(nm))
            anak = pd.to_numeric(anak, errors="coerce")
            kode[anak.notna()] = np.nan
            kode38[anak.notna()] = anak[anak.notna()]
            for idx in kode.index[kode.isna()]:
                nm = tabel.at[idx, c_nama]
                if pd.isna(nm):
                    continue
                k, cat = cari_kode_provinsi(nm)
                if k is None:
                    tak_kenal.add(str(nm).strip())
                else:
                    kode[idx] = k
                    if cat:
                        lipat[idx] = True
        if tak_kenal:
            self._catat("peringatan", "Kunci provinsi",
                        f"Sheet '{nama_sheet}': {len(tak_kenal)} nama provinsi tidak dikenali dan dibuang.",
                        sorted(tak_kenal))
        if lipat.any():
            self._catat("info", "Kunci provinsi",
                        f"Sheet '{nama_sheet}': {int(lipat.sum())} baris provinsi pemekaran Papua dilipat ke induknya.")
        induk = kode.isin([91, 94]) & ~lipat
        kode38[induk] = kode[induk]
        out = pd.DataFrame({"kode": kode, "tahun": tahun, "_lipat": lipat, "_kode38": kode38})
        dibuang = out[["kode", "tahun"]].isna().any(axis=1)
        if dibuang.any():
            self._catat("info", "Kunci provinsi",
                        f"Sheet '{nama_sheet}': {int(dibuang.sum())} baris tanpa provinsi/tahun sah dibuang "
                        "(baris total, catatan kaki, atau kosong).")
        return out, dibuang

    # ------------------------------------------------------------- jalankan
    def jalankan(self, berkas, nama_berkas=None):
        mentah = self._baca(berkas, nama_berkas)
        bagian, pemetaan_total, tak_dikenal_total = [], {}, []
        for nama_sheet, m in mentah.items():
            tabel = self._sheet_ke_tabel(nama_sheet, m)
            if tabel is None or tabel.empty:
                continue
            pemetaan, tak_dikenal = self._petakan(tabel)
            baru = {k: c for k, c in pemetaan.items() if k not in pemetaan_total}
            if not baru:
                self._catat("info", "Petakan kolom", f"Sheet '{nama_sheet}' tidak menambah variabel baru.")
                continue
            kunci, dibuang = self._kunci(tabel, nama_sheet)
            blok = pd.DataFrame(index=tabel.index)
            n_teks = 0
            gagal = {}
            for kode, c in baru.items():
                seri, nt, ng = ke_angka(tabel[c])
                blok[kode] = seri
                n_teks += nt
                if ng:
                    gagal[c] = ng
            if n_teks:
                self._catat("info", "Konversi angka",
                            f"Sheet '{nama_sheet}': {n_teks} sel bertipe teks dikonversi (sel kosong-teks, "
                            "format 1.234,5, tanda '-').")
            if gagal:
                self._catat("peringatan", "Konversi angka",
                            f"Sheet '{nama_sheet}': sel teks yang tidak dapat dibaca sebagai angka dikosongkan.",
                            [f"{c}: {n} sel" for c, n in gagal.items()])
            blok = pd.concat([kunci, blok], axis=1)[~dibuang]
            bagian.append(blok)
            pemetaan_total.update({k: f"{nama_sheet}!{c}" for k, c in baru.items()})
            tak_dikenal_total += [f"{nama_sheet}!{c}" for c in tak_dikenal]
            self._catat("info", "Petakan kolom",
                        f"Sheet '{nama_sheet}': {len(baru)} variabel dipetakan, {len(tak_dikenal)} kolom tidak dikenal.")

        if not bagian:
            self._catat("error", "Petakan kolom",
                        "Tidak ada sheet yang memuat kolom provinsi, tahun, dan variabel yang dikenali.")
            return HasilPembersihan(pd.DataFrame(), {}, self.temuan, {}, tak_dikenal_total)

        df = self._satukan(bagian)
        df = self._satuan(df)
        self._konsistensi(df)
        df = self._batasi_tahun(df)
        df = self._imputasi(df)
        self._lonjakan(df)
        self._cakupan(df)
        df = df[[v.kode for v in V.DAFTAR if v.kode in df.columns]]
        return HasilPembersihan(df, self.catatan, self.temuan, pemetaan_total, tak_dikenal_total, self.rincian)

    def _rincian_papua(self, blok, nilai):
        """Simpan baris enam provinsi Papua (sebelum dilipat) dan kembalikan kolom yang tergeser."""
        sel = blok["_kode38"].notna()
        if not (blok["_lipat"].any() and sel.any()):
            return blok
        r = blok[sel].astype({"_kode38": int}).groupby(["_kode38", "tahun"])[nilai].last()
        r.index.names = ["kode", "tahun"]
        catatan = []
        r = koreksi_geser_papua(r, catatan)
        for c in catatan:
            self._catat("peringatan", "Pemekaran Papua", c)
        if catatan:
            kunci = pd.MultiIndex.from_arrays([blok.loc[sel, "_kode38"].astype(int), blok.loc[sel, "tahun"]])
            blok = blok.copy()
            blok.loc[sel, nilai] = r.reindex(kunci)[nilai].to_numpy()
        self.rincian = r if self.rincian is None else self.rincian.combine_first(r)
        return blok

    def _satukan(self, bagian):
        hasil = None
        for blok in bagian:
            blok = blok.astype({"kode": int, "tahun": int})
            nilai = [c for c in blok.columns if c not in ("kode", "tahun", "_lipat", "_kode38")]
            blok = self._rincian_papua(blok, nilai)
            grup = blok.groupby(["kode", "tahun"])
            ukuran = grup.size()
            lipat = grup["_lipat"].any()
            dup = ukuran[(ukuran > 1) & ~lipat]
            if len(dup):
                self._catat("peringatan", "Duplikat",
                            f"{len(dup)} pasangan provinsi-tahun muncul lebih dari sekali; baris terakhir dipakai.",
                            [f"{NAMA_PROVINSI[k]} {t}" for k, t in dup.index[:30]])
            dijumlah = grup[nilai].sum(min_count=1)
            rata = [c for c in nilai if c in V.PER_KODE and V.PER_KODE[c].agregasi != "jumlah"]
            if rata:
                dijumlah[rata] = grup[rata].mean()
            terakhir = grup[nilai].last()
            pakai_jumlah = np.repeat(lipat.reindex(terakhir.index).to_numpy()[:, None], len(nilai), axis=1)
            gabung = terakhir.mask(pakai_jumlah, dijumlah)
            hasil = gabung if hasil is None else hasil.combine_first(gabung)
        return hasil.sort_index()

    def _satuan(self, df):
        def skala(cols, faktor, pesan):
            cols = [c for c in cols if c in df.columns]
            if cols:
                df[cols] = df[cols] * faktor
                self._catat("peringatan", "Satuan", pesan, cols[:20])

        if "PAD" in df and df["PAD"].median() > 1e6:
            skala(["PAD"], 1e-9, "PAD tampak dalam rupiah penuh; dibagi 10^9 menjadi miliar Rp.")
        if {"PMA", "PMDN", "PMTB_ADHB"} <= set(df.columns):
            inv = (df["PMA"].fillna(0) + df["PMDN"].fillna(0)).groupby(level="tahun").sum()
            pmtb = df["PMTB_ADHB"].groupby(level="tahun").sum()
            rasio = (inv / pmtb.replace(0, np.nan)).median()
            if rasio > 20:
                skala(["PMA", "PMDN"] + [f"{p}_{s}" for p in ("PMA", "PMDN") for s in KODE_SEKTOR],
                      1e-3, f"Rasio investasi/PMTB {rasio:,.0f}: PMA/PMDN tampak dalam juta Rp; dibagi 1.000.")
        for kol in ("PDRB_ADHK", "PDRB_ADHB", "PMTB_ADHK", "PMTB_ADHB"):
            if kol in df:
                nas = df[kol].groupby(level="tahun").sum().median()
                if 0 < nas < 1e5:
                    skala([kol], 1e3, f"{kol} nasional {nas:,.0f}: tampak dalam triliun Rp; dikali 1.000.")
                elif nas > 1e9:
                    skala([kol], 1e-3, f"{kol} nasional {nas:,.0f}: tampak dalam juta Rp; dibagi 1.000.")
        tk = [f"TK_{s}" for s in KODE_SEKTOR if f"TK_{s}" in df]
        if len(tk) == len(KODE_SEKTOR):
            total = df[tk].sum(axis=1, min_count=1)
            if 0 < total.median() < 1e5:
                skala(tk, 1e3, "Tenaga kerja tampak dalam ribu jiwa; dikali 1.000.")
        negatif = [c for c in df.columns if c.startswith(("PMA_", "PMDN_")) and (df[c] < 0).any()]
        if negatif:
            self._catat("peringatan", "Satuan",
                        "Ada realisasi sektoral negatif (koreksi pencatatan). Nilai dipertahankan; "
                        "model sektoral memotongnya ke nol saat menghitung pangsa.", negatif[:20])
        return df

    def _konsistensi(self, df):
        def banding(total, bagian, ambang, nama):
            if total not in df or not all(b in df for b in bagian):
                return
            jumlah = df[bagian].sum(axis=1, min_count=len(bagian))
            selisih = (jumlah / df[total] - 1).abs()
            buruk = selisih[selisih > ambang].dropna()
            if len(buruk):
                self._catat("peringatan", "Konsistensi",
                            f"{len(buruk)} baris: jumlah {nama} sektoral berbeda > {ambang:.0%} dari totalnya.",
                            [f"{NAMA_PROVINSI[k]} {t}: {v:.1%}" for (k, t), v in buruk.head(20).items()])
            else:
                self._catat("info", "Konsistensi", f"Jumlah {nama} sektoral cocok dengan totalnya.")

        banding("PDRB_ADHK", [f"VA_{s}" for s in KODE_SEKTOR], 0.03, "nilai tambah")
        banding("PMA", [f"PMA_{s}" for s in KODE_SEKTOR], 0.05, "PMA")
        banding("PMDN", [f"PMDN_{s}" for s in KODE_SEKTOR], 0.05, "PMDN")

    def _batasi_tahun(self, df):
        tmin, tmax = self.opsi.get("tahun_min"), self.opsi.get("tahun_max")
        t = df.index.get_level_values("tahun")
        if tmin:
            df = df[t >= int(tmin)]
        if tmax:
            df = df[df.index.get_level_values("tahun") <= int(tmax)]
        return df

    def _imputasi(self, df):
        cara = self.opsi.get("imputasi", "tidak")
        if cara == "tidak" or df.empty:
            n_kosong = int(df.isna().sum().sum())
            self._catat("info", "Imputasi", f"Imputasi tidak dijalankan; {n_kosong} sel kosong dibiarkan.")
            return df
        provs = df.index.get_level_values("kode").unique()
        tahun = sorted(df.index.get_level_values("tahun").unique())
        penuh = pd.MultiIndex.from_product([provs, tahun], names=["kode", "tahun"])
        df = df.reindex(penuh)
        sebelum = df.isna()
        # Realisasi PMA/PMDN itu arus yang tersendat-sendat; sel kosong lebih
        # mungkin berarti tidak ada realisasi tercatat daripada data hilang.
        mulus = [c for c in df.columns if not c.startswith(("PMA", "PMDN"))]
        out = []
        for kode, g in df.groupby(level="kode"):
            g = g.droplevel("kode")
            if cara in ("interpolasi", "interpolasi_locf"):
                g[mulus] = g[mulus].interpolate(method="index", limit_area="inside")
            if cara in ("locf", "interpolasi_locf"):
                g[mulus] = g[mulus].ffill()
            g.index = pd.MultiIndex.from_product([[kode], g.index], names=["kode", "tahun"])
            out.append(g)
        df = pd.concat(out)
        terisi = sebelum & df.notna()
        metode = {"interpolasi": "interpolasi linear", "locf": "LOCF (nilai tahun sebelumnya)",
                  "interpolasi_locf": "interpolasi/LOCF"}[cara]
        per_var = terisi.sum()
        for (kode, th), row in terisi[terisi.any(axis=1)].iterrows():
            for var in row.index[row.values]:
                self._tandai(kode, th, var, f"imputasi: {metode}")
        if per_var.sum():
            self._catat("peringatan", "Imputasi",
                        f"{int(per_var.sum())} sel diisi dengan {metode}. Sel ini diwarnai oranye di Excel.",
                        [f"{k}: {int(v)} sel" for k, v in per_var[per_var > 0].items()][:30])
        else:
            self._catat("info", "Imputasi", "Tidak ada sel yang perlu diisi.")
        self._catat("info", "Imputasi", "Kolom PMA/PMDN tidak diimputasi: sel kosong dibaca sebagai "
                    "tidak ada realisasi tercatat.")
        # baris yang seluruhnya kosong setelah reindex tidak disimpan
        return df.dropna(how="all")

    def _lonjakan(self, df):
        ambang = float(self.opsi.get("ambang_lonjakan") or 50) / 100
        cek = [c for c in ("PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB") if c in df]
        tk = [f"TK_{s}" for s in KODE_SEKTOR if f"TK_{s}" in df]
        seri = {c: df[c] for c in cek}
        if len(tk) == len(KODE_SEKTOR):
            seri["TK_TOTAL"] = df[tk].sum(axis=1, min_count=len(tk))
        detail = []
        for nama, s in seri.items():
            g = s.groupby(level="kode").pct_change(fill_method=None)
            for (kode, th), v in g[g.abs() > ambang].dropna().items():
                self._tandai(kode, th, nama, f"lonjakan: {nama} {v:+.0%}")
                detail.append(f"{NAMA_PROVINSI[kode]} {th} {nama} {v:+.0%}")
        if detail:
            self._catat("peringatan", "Lonjakan",
                        f"{len(detail)} perubahan tahunan melebihi ±{ambang:.0%}. Nilai tidak diubah, "
                        "hanya ditandai kuning di Excel untuk dicek.", detail)
        else:
            self._catat("info", "Lonjakan", f"Tidak ada perubahan tahunan melebihi ±{ambang:.0%}.")

    def _cakupan(self, df):
        provs = set(df.index.get_level_values("kode"))
        hilang = [NAMA_PROVINSI[k] for k in KODE_PROVINSI if k not in provs]
        if hilang:
            self._catat("peringatan", "Cakupan", f"{len(hilang)} provinsi tidak ada di berkas.", hilang)
        wajib_hilang = [k for k in V.WAJIB if k not in df.columns]
        if wajib_hilang:
            self._catat("peringatan", "Cakupan",
                        f"{len(wajib_hilang)} variabel wajib simulasi tidak ada. Versi ini bisa dipakai "
                        "untuk jelajah data atau sebagai pembaruan parsial atas versi lain.",
                        wajib_hilang)
        else:
            self._catat("info", "Cakupan", "Seluruh variabel wajib simulasi tersedia.")


KODE_DETERMINAN = [v.kode for v in V.DAFTAR if v.grup.startswith("Determinan TFP")]
SHEET_DETERMINAN = "Analisis Luaran 2"


def tambah_determinan(versi, berkas):
    """Isi kolom indikator determinan TFP `versi` dari workbook tim; variabel lain tidak disentuh.

    Dibaca dari sheet Analisis Luaran 2 bila ada (Sheet1 memuat sebagian indikator tanpa 2025).
    Kembalikan daftar kode indikator yang terisi.
    """
    from pathlib import Path
    with open(berkas, "rb") as f:
        baru = PipelinePembersihan({"imputasi": "tidak", "sheet": SHEET_DETERMINAN}).jalankan(
            f, Path(berkas).name).df
    kol = [k for k in KODE_DETERMINAN if k in baru.columns]
    if not kol:
        return []
    df, catatan = versi.ke_dataframe(dengan_catatan=True)
    df = df.drop(columns=[k for k in KODE_DETERMINAN if k in df.columns]).join(baru[kol], how="left")
    versi.simpan_dataframe(df, catatan)
    versi.laporan = list(versi.laporan or []) + [Temuan(
        "info", "Determinan TFP", f"{len(kol)} indikator determinan TFP diisi dari {Path(berkas).name}.", kol).ke_dict()]
    versi.save(update_fields=["laporan"])
    return kol


def gabungkan_pembaruan(induk_df, induk_catatan, baru_df, baru_catatan):
    """Timpa sel induk dengan sel baru yang terisi; sel lain diwarisi dari induk."""
    gabung = baru_df.combine_first(induk_df)
    catatan = {k: dict(v) for k, v in induk_catatan.items()}
    baru_r = baru_df.reindex(index=gabung.index, columns=gabung.columns)
    induk_r = induk_df.reindex(index=gabung.index, columns=gabung.columns)
    beda = baru_r.notna() & (induk_r.isna() | ((induk_r - baru_r).abs() > 1e-9))
    for (kode, th), row in beda[beda.any(axis=1)].iterrows():
        for var in row.index[row.values]:
            catatan.setdefault((kode, th), {})[var] = "diperbarui dari unggahan"
    for k, v in baru_catatan.items():
        catatan.setdefault(k, {}).update(v)
    return gabung, catatan
