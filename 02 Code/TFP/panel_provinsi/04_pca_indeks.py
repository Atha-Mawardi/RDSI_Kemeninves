# PCA konektivitas & institusi. Baca panel_terisi.csv, tulis panel akhir + loadings.

import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from statistics import mean
from pengaturan import OUT, read_csv, write_csv, num, PANEL_FIELDS


def pca_scores(rows, cols, invert=None):
    invert = set(invert or [])
    by_year = {}
    for r in rows:
        by_year.setdefault(r["year"], []).append(r)
    zmap = {}
    for y, grp in by_year.items():
        for c in cols:
            vals = [r[c] for r in grp if r.get(c) is not None]
            if len(vals) < 3:
                continue
            mu = mean(vals)
            sd = (sum((v - mu) ** 2 for v in vals) / (len(vals) - 1)) ** 0.5
            if sd == 0:
                sd = 1.0
            for r in grp:
                if r.get(c) is None:
                    continue
                z = (r[c] - mu) / sd
                zmap[(r["code_prov"], y, c)] = -z if c in invert else z
    X, keys = [], []
    for r in rows:
        vec = [zmap.get((r["code_prov"], r["year"], c)) for c in cols]
        if any(v is None for v in vec):
            continue
        X.append(vec)
        keys.append((r["code_prov"], r["year"]))
    if len(X) < 10:
        return {}, [0] * len(cols), 0.0
    n, k = len(X), len(cols)
    mus = [sum(row[j] for row in X) / n for j in range(k)]
    xc = [[row[j] - mus[j] for j in range(k)] for row in X]
    C = [[sum(xc[i][a] * xc[i][b] for i in range(n)) / (n - 1) for b in range(k)] for a in range(k)]
    import numpy as np
    evals, evecs = np.linalg.eigh(np.array(C))
    idx = int(np.argmax(evals))
    load = evecs[:, idx].tolist()
    varshare = float(evals[idx] / evals.sum()) if evals.sum() else 0.0
    if sum(load) < 0:
        load = [-x for x in load]
    raw = [sum(load[j] * vec[j] for j in range(k)) for vec in xc]
    lo, hi = min(raw), max(raw)
    span = hi - lo if hi != lo else 1.0
    scaled = {key: 100.0 * (s - lo) / span for key, s in zip(keys, raw)}
    return scaled, load, varshare


def coerce(rows):
    skip = {"prov_nama", "pulau", "status_observasi"}
    for r in rows:
        r["code_prov"] = int(r["code_prov"])
        r["year"] = int(r["year"])
        for k, v in list(r.items()):
            if k in skip or k in ("code_prov", "year", "status_observasi"):
                continue
            r[k] = None if v in ("", None) else (v if k in skip else num(v) if k not in (
                "code_prov_induk", "provinsi_berdiri") else int(float(v)) if v not in ("", None) else None)


def main():
    rows = read_csv(OUT / "panel_terisi.csv")
    coerce(rows)
    aktif = [r for r in rows if r.get("status_observasi") == "berdiri"]
    inst_cols = ["rasio_pad", "serapan_belanja", "idi", "tindak_pidana_per_100rb",
                 "ikg", "indeks_hijau_iktl", "indeks_biru_ika"]
    for r in aktif:
        r["pax_angkutan"] = (r.get("pax_udara") or 0) + (r.get("pax_laut") or 0) + (r.get("pax_bus") or 0)
        for c in ("panjang_jalan_km", "pax_angkutan", "pax_ka", "cargo_total_juta_ton"):
            if r.get(c) is not None:
                r[c + "_log"] = math.log(r[c] + 1.0)
    conn_cols = ["panjang_jalan_km_log", "jalan_mantap_pct", "pax_angkutan_log",
                 "pax_ka_log", "cargo_total_juta_ton_log"]
    sc_conn, load_conn, var_conn = pca_scores(aktif, conn_cols)
    sc_inst, load_inst, var_inst = pca_scores(aktif, inst_cols, invert={"tindak_pidana_per_100rb", "ikg"})
    for r in rows:
        key = (r["code_prov"], r["year"])
        r["indeks_konektivitas"] = sc_conn.get(key)
        r["indeks_institusi"] = sc_inst.get(key)

    write_csv(OUT / "panel_provinsi_tahun_2017_2025.csv", rows, PANEL_FIELDS)
    write_csv(OUT / "pca_loadings_konektivitas.csv",
              [{"variabel": c, "loading_pc1": load_conn[i]} for i, c in enumerate(conn_cols)],
              ["variabel", "loading_pc1"])
    write_csv(OUT / "pca_loadings_institusi.csv",
              [{"variabel": c, "loading_pc1": load_inst[i]} for i, c in enumerate(inst_cols)],
              ["variabel", "loading_pc1"])
    codebook = [
        ("code_prov", "Kode BPS provinsi (Code_Prov2022)", "kode", "BPS"),
        ("pma_miliar", "Realisasi PMA", "miliar Rp", "Dataset Provinsi / BKPM"),
        ("pmdn_miliar", "Realisasi PMDN", "miliar Rp", "Dataset Provinsi / BKPM"),
        ("pmtb_miliar", "PMTB ADHB", "miliar Rp", "BPS PDRB pengeluaran"),
        ("upah_agregat", "Upah sebulan tertimbang 17 sektor", "Rp", "Sakernas; 2025 diproyeksi UMP"),
        ("panjang_jalan_km", "Panjang jalan nasional", "km", "KemenPUPR"),
        ("jalan_mantap_pct", "Persentase jalan nasional mantap", "%", "KemenPUPR"),
        ("pax_udara", "Penumpang udara (alokasi)", "orang", "BPS nasional × H_ADHB"),
        ("pax_ka", "Penumpang KA (0 jika tidak ada jaringan)", "orang", "BPS nasional × H_ADHB"),
        ("pax_laut", "Penumpang laut (alokasi)", "orang", "BPS nasional × H_ADHB"),
        ("pax_bus", "Penumpang bus (alokasi)", "orang", "proksi nasional × H_ADHB"),
        ("cargo_*", "Barang angkutan (alokasi)", "juta ton", "nasional × H_ADHB"),
        ("indeks_konektivitas", "PC1 PCA, 0-100; pax udara+laut+bus digabung", "indeks", "hitung sendiri"),
        ("rasio_pad", "PAD / pendapatan daerah", "rasio", "DJPK SIKD"),
        ("serapan_belanja", "Realisasi/anggaran belanja", "%", "DJPK SIKD"),
        ("idi", "Indeks Demokrasi Indonesia", "0-100", "BPS; metode baru 2021"),
        ("tindak_pidana_per_100rb", "Kejahatan per 100 ribu penduduk", "rasio", "BPS"),
        ("ikg", "Indeks Ketimpangan Gender", "0-1", "BPS"),
        ("indeks_hijau_iktl", "Indeks Kualitas Tutupan Lahan", "0-100", "KLHK"),
        ("indeks_biru_ika", "Indeks Kualitas Air", "0-100", "KLHK"),
        ("indeks_institusi", "PC1 PCA institusi, 0-100; IKG & kriminal dibalik", "indeks", "hitung sendiri"),
    ]
    write_csv(OUT / "codebook.csv",
              [{"kolom": a, "definisi": b, "satuan": c, "sumber": d} for a, b, c, d in codebook],
              ["kolom", "definisi", "satuan", "sumber"])
    print(f"PCA konektivitas var PC1={var_conn:.3f}  institusi var PC1={var_inst:.3f}")
    print("tulis", OUT / "panel_provinsi_tahun_2017_2025.csv")


if __name__ == "__main__":
    main()
