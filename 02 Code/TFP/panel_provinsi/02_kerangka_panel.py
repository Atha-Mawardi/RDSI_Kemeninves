# Gabung sumber resmi jadi kerangka panel 38 provinsi × 2017–2025.
# Belum mengisi lubang. Keluaran: 01 Data/TFP/processed/panel/kerangka.csv

import csv
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pengaturan import (
    RAW, OUT, TABEL, YEARS, PROV, META, BKPM_PROC, TFP_PROC,
    num, exists, read_csv, write_csv, load_nested, load_code_value,
    lookup, code_of, PANEL_FIELDS,
)


def load_database():
    out = {}
    for r in read_csv(BKPM_PROC / "Dataset Provinsi(Database).csv"):
        if not r.get("Year"):
            continue
        y = int(float(r["Year"]))
        code = int(float(r["Code_Prov2022"] or r["Code_Prov"]))
        pma, pmdn = num(r.get("PMA_1")), num(r.get("PMDN_1"))
        out[(code, y)] = {
            "pma_juta": pma, "pmdn_juta": pmdn,
            "pmtb_miliar": num(r.get("4_ADHB")),
            "h_adhb": num(r.get("H_ADHB")),
            "pdrb_miliar": num(r.get("9_ADHB")),
            "inc": num(r.get("Inc_Prov")),
            "ump": num(r.get("UMP_Prov")),
        }
    return out


def load_agregasi():
    rows = read_csv(TFP_PROC / "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar(Sheet1).csv")
    upah_cols = [c for c in rows[0] if c.endswith("_RataUpah")]
    tk_cols = [c for c in rows[0] if c.endswith("_TenagaKerja")]
    out = {}
    for r in rows:
        y, code = int(r["Year"]), int(r["Code_Prov"])
        wsum = tw = 0.0
        for uc, tc in zip(upah_cols, tk_cols):
            w, t = num(r.get(uc)), num(r.get(tc))
            if w is not None and t is not None and t > 0:
                wsum += w * t
                tw += t
        out[(code, y)] = {
            "upah_agregat": (wsum / tw) if tw > 0 else None,
            "ump": num(r.get("UMP_Prov")),
            "pma_miliar": num(r.get("PMA_1")),
            "pmdn_miliar": num(r.get("PMDN_1")),
        }
    return out


def load_djpk():
    out = {}
    for r in read_csv(RAW / "djpk" / "apbd_panel.csv"):
        code, y = int(r["code_prov"]), int(r["tahun"])
        pad, pend = num(r["pad_realisasi"]), num(r["pendapatan_realisasi"])
        bel_a, bel_r = num(r["belanja_anggaran"]), num(r["belanja_realisasi"])
        serapan = num(r["serapan_belanja_pct"])
        if serapan is None and bel_a and bel_r is not None:
            serapan = 100.0 * bel_r / bel_a
        out[(code, y)] = {
            "pad_miliar": pad / 1e9 if pad else None,
            "pendapatan_miliar": pend / 1e9 if pend else None,
            "belanja_miliar": bel_r / 1e9 if bel_r else None,
            "rasio_pad": (pad / pend) if pad is not None and pend else None,
            "serapan_belanja": serapan,
        }
    return out


def load_jalan():
    out = {}
    folder = RAW / "jalan_pu"
    for y in range(2017, 2025):
        p = folder / f"kemantapan_jalan_{y}.csv"
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8-sig", errors="ignore")
        delim = ";" if text.splitlines()[0].count(";") >= 3 else ","
        with p.open(newline="", encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f, delimiter=delim))
        for r in rows:
            keys = {k.lower().strip(): k for k in r}
            kd = r.get(keys.get("kd_prov", "Kd_Prov"), "")
            nama = r.get(keys.get("provinsi", "Provinsi"), "")
            if "indonesia" in str(nama).lower() or str(kd).lower() == "xxx":
                continue
            code = code_of(nama, kd)
            if code is None:
                continue
            pj = num(r.get(keys.get("total_panjang", "Total_Panjang")))
            mantap = None
            for k in r:
                if "mantap" in k.lower() and "%" in k:
                    mantap = num(r[k])
                    break
            out[(code, y)] = {
                "panjang_jalan_km": None if pj == 0 else pj,
                "jalan_mantap_pct": mantap,
            }
    return out


def main():
    db = load_database()
    agr = load_agregasi()
    djpk = load_djpk()
    jalan = load_jalan()
    iklh = load_nested(TABEL / "iklh.csv")
    ika = load_nested(TABEL / "ika.csv")
    iktl = load_nested(TABEL / "iktl.csv")
    idi = load_nested(TABEL / "idi.csv")
    ikg_jawa = load_nested(TABEL / "ikg_jawa.csv")
    ikg_2024 = load_code_value(TABEL / "ikg_2024.csv")
    crime_2023 = load_code_value(TABEL / "crime_2023.csv")

    rows = []
    for induk, code, nama, pulau, start in PROV:
        for y in YEARS:
            rec = {
                "code_prov": code, "code_prov_induk": induk, "prov_nama": nama,
                "pulau": pulau, "year": y, "provinsi_berdiri": start,
            }
            if not exists(code, y):
                rec["status_observasi"] = "belum_berdiri"
                rows.append(rec)
                continue
            rec["status_observasi"] = "berdiri"
            d, a, j, rd = db.get((code, y), {}), agr.get((code, y), {}), djpk.get((code, y), {}), jalan.get((code, y), {})
            pma, pmdn = d.get("pma_juta"), d.get("pmdn_juta")
            if pma is None and a.get("pma_miliar") is not None:
                pma = a["pma_miliar"] * 1000
            if pmdn is None and a.get("pmdn_miliar") is not None:
                pmdn = a["pmdn_miliar"] * 1000
            rec["pma_miliar"] = None if pma is None else pma / 1000.0
            rec["pmdn_miliar"] = None if pmdn is None else pmdn / 1000.0
            rec["pmtb_miliar"] = d.get("pmtb_miliar")
            rec["pma_pmdn_miliar"] = None if rec["pma_miliar"] is None and rec["pmdn_miliar"] is None else (
                (rec["pma_miliar"] or 0) + (rec["pmdn_miliar"] or 0)
            )
            rec["upah_agregat"] = a.get("upah_agregat")
            rec["ump"] = d.get("ump") or a.get("ump")
            rec["h_adhb"] = d.get("h_adhb")
            rec["pdrb_miliar"] = d.get("pdrb_miliar")
            rec["inc"] = d.get("inc")
            rec["pad_miliar"] = j.get("pad_miliar")
            rec["pendapatan_apbd_miliar"] = j.get("pendapatan_miliar")
            rec["belanja_apbd_miliar"] = j.get("belanja_miliar")
            rec["rasio_pad"] = j.get("rasio_pad")
            rec["serapan_belanja"] = j.get("serapan_belanja")
            rec["panjang_jalan_km"] = rd.get("panjang_jalan_km")
            rec["jalan_mantap_pct"] = rd.get("jalan_mantap_pct")
            rec["idi"] = lookup(idi, code, y)
            rec["ikg"] = lookup(ikg_jawa, code, y) or (ikg_2024.get(code) if y == 2024 else None)
            rec["iklh"] = lookup(iklh, code, y)
            rec["indeks_hijau_iktl"] = lookup(iktl, code, y)
            rec["indeks_biru_ika"] = lookup(ika, code, y)
            rec["tindak_pidana"] = crime_2023.get(code) if y == 2023 else None
            rows.append(rec)

    fields = PANEL_FIELDS + ["inc"]
    write_csv(OUT / "kerangka.csv", rows, fields)
    n_isi = sum(1 for r in rows if r.get("status_observasi") == "berdiri")
    print(f"kerangka {len(rows)} baris ({n_isi} berdiri) -> {OUT / 'kerangka.csv'}")


if __name__ == "__main__":
    main()
