# Isi lubang kerangka: backcast/proyeksi, pemekaran, angkutan, kriminal.
# Baca panel/kerangka.csv. Tulis panel/panel_terisi.csv + catatan_imputasi.csv

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from statistics import mean
from pengaturan import (
    OUT, TABEL, YEARS, PROV, NEW_PAPUA, RAIL_PROV, JAWA, META,
    num, exists, read_csv, write_csv, load_nested, load_code_value,
    load_nasional, note, NOTES, PANEL_FIELDS,
)


def get_row(rows, code, year):
    return next(x for x in rows if x["code_prov"] == code and x["year"] == year)


def interpolate_back_fwd(series, code, var, nat=None, nat_anchor_year=None):
    start = META[code][4]
    out = dict(series)
    obs = {y: v for y, v in out.items() if v is not None and start <= y <= 2025}
    if not obs:
        return out
    ys = sorted(obs)
    for y in range(ys[0], ys[-1] + 1):
        if y in obs or not exists(code, y):
            continue
        lo = max(t for t in ys if t < y)
        hi = min(t for t in ys if t > y)
        w = (y - lo) / (hi - lo)
        out[y] = obs[lo] * (1 - w) + obs[hi] * w
        note(code, y, var, "interpolasi_linear", f"antara {lo} dan {hi}")
    first_y, first_v = ys[0], obs[ys[0]]
    for y in range(start, first_y):
        if nat and nat_anchor_year and nat.get(nat_anchor_year) and y in nat:
            out[y] = first_v * (nat[y] / nat[nat_anchor_year])
            note(code, y, var, "backcast_rasio_nasional",
                 f"level {first_y} × (nas_{y}/nas_{nat_anchor_year})")
        else:
            out[y] = first_v
            note(code, y, var, "LOCF_mundur", f"disalin dari {first_y}")
    last_y, last_v = ys[-1], obs[ys[-1]]
    for y in range(last_y + 1, 2026):
        if not exists(code, y):
            continue
        if last_y >= 2 + start and (last_y - 1) in out and out[last_y - 1]:
            g = min(max(out[last_y] / out[last_y - 1], 0.85), 1.20)
            out[y] = out[y - 1] * g
            note(code, y, var, "proyeksi_yoy_terakhir",
                 f"pertumbuhan {last_y-1}-{last_y} dibatasi ±20%")
        elif nat and y in nat and last_y in nat and nat[last_y]:
            out[y] = last_v * (nat[y] / nat[last_y])
            note(code, y, var, "proyeksi_rasio_nasional",
                 f"level {last_y} × (nas_{y}/nas_{last_y})")
        else:
            out[y] = last_v
            note(code, y, var, "LOCF", f"disalin dari {last_y}")
    return out


def isi_indeks_resmi(rows):
    nas = load_nasional()
    ikg_jawa = load_nested(TABEL / "ikg_jawa.csv")
    ikg_2024 = load_code_value(TABEL / "ikg_2024.csv")
    idi = load_nested(TABEL / "idi.csv")
    iklh = load_nested(TABEL / "iklh.csv")
    ika = load_nested(TABEL / "ika.csv")
    iktl = load_nested(TABEL / "iktl.csv")
    for _, code, *_ in PROV:
        ikg_s = {y: ikg_jawa.get(code, {}).get(y) for y in YEARS}
        ikg_s[2024] = ikg_s[2024] or ikg_2024.get(code)
        filled = interpolate_back_fwd({y: v for y, v in ikg_s.items() if v}, code, "ikg", nas["ikg"], 2024)
        idi_s = interpolate_back_fwd(dict(idi.get(code, {})), code, "idi", nas["idi"],
                                     2022 if 2022 in idi.get(code, {}) else 2024)
        iklh_s = interpolate_back_fwd(dict(iklh.get(code, {})), code, "iklh", nas["iklh"],
                                      2024 if 2024 in iklh.get(code, {}) else 2023)
        ika_s = interpolate_back_fwd(dict(ika.get(code, {})), code, "indeks_biru_ika", nas["ika"],
                                     2024 if 2024 in ika.get(code, {}) else 2023)
        iktl_s = interpolate_back_fwd(dict(iktl.get(code, {})), code, "indeks_hijau_iktl")
        for r in rows:
            if r["code_prov"] != code or r.get("status_observasi") != "berdiri":
                continue
            y = r["year"]
            r["ikg"] = r.get("ikg") if r.get("ikg") is not None else filled.get(y)
            r["idi"] = r.get("idi") if r.get("idi") is not None else idi_s.get(y)
            r["iklh"] = r.get("iklh") if r.get("iklh") is not None else iklh_s.get(y)
            r["indeks_biru_ika"] = r.get("indeks_biru_ika") if r.get("indeks_biru_ika") is not None else ika_s.get(y)
            r["indeks_hijau_iktl"] = r.get("indeks_hijau_iktl") if r.get("indeks_hijau_iktl") is not None else iktl_s.get(y)


def isi_jalan(rows):
    for r in rows:
        if r["code_prov"] == 31 and r.get("panjang_jalan_km") in (None, 0):
            r["panjang_jalan_km"] = 1210.0
            note(31, r["year"], "panjang_jalan_km", "substitusi_BPS_jalan_DKI",
                 "kemantapan jalan nasional PU = 0/absen; diisi ~1.210 km")
        if r["code_prov"] == 31 and r.get("jalan_mantap_pct") in (0, 0.0):
            r["jalan_mantap_pct"] = None
    for _, code, *_ in PROV:
        s = {r["year"]: r.get("panjang_jalan_km") for r in rows if r["code_prov"] == code}
        m = {r["year"]: r.get("jalan_mantap_pct") for r in rows if r["code_prov"] == code}
        s2 = interpolate_back_fwd({y: v for y, v in s.items() if v}, code, "panjang_jalan_km")
        m2 = interpolate_back_fwd({y: v for y, v in m.items() if v}, code, "jalan_mantap_pct")
        for r in rows:
            if r["code_prov"] != code or r.get("status_observasi") != "berdiri":
                continue
            if r.get("panjang_jalan_km") is None:
                r["panjang_jalan_km"] = s2.get(r["year"])
            if r.get("jalan_mantap_pct") is None:
                r["jalan_mantap_pct"] = m2.get(r["year"])
    for y in YEARS:
        vals = [r["jalan_mantap_pct"] for r in rows
                if r["year"] == y and r["code_prov"] in JAWA
                and r.get("jalan_mantap_pct") not in (None, 0)]
        mu = mean(vals) if vals else 90.0
        for r in rows:
            if r["code_prov"] == 31 and r["year"] == y and r.get("jalan_mantap_pct") is None:
                r["jalan_mantap_pct"] = mu
                note(31, y, "jalan_mantap_pct", "rata_Jawa", "PU tidak mencatat kemantapan DKI")


def pecah_pmtb_pdrb_2023(rows):
    for r in rows:
        if r["code_prov"] == 97 and r["year"] >= 2023 and r.get("pma_miliar") is None:
            r["pma_miliar"] = 0.0
            r["pma_pmdn_miliar"] = r.get("pmdn_miliar") or 0
            note(97, r["year"], "pma_miliar", "nol_tidak_tercatat", "BKPM tidak mencatat PMA; diisi 0")
    for parent, kids in ((91, [92]), (94, [95, 96, 97])):
        for var in ("pdrb_miliar", "pmtb_miliar"):
            p24 = get_row(rows, parent, 2024).get(var)
            k24 = [get_row(rows, k, 2024).get(var) for k in kids]
            p23r = get_row(rows, parent, 2023)
            p23 = p23r.get(var)
            if not p24 or not p23 or any(v is None for v in k24):
                continue
            tot24 = p24 + sum(k24)
            for k, v24 in zip(kids, k24):
                rk = get_row(rows, k, 2023)
                if rk.get(var) is None:
                    rk[var] = p23 * v24 / tot24
                    note(k, 2023, var, "bagi_porsi_2024",
                         f"angka gabungan 2023 induk {parent} × porsi {var} 2024")
            baru = p23 * p24 / tot24
            note(parent, 2023, var, "rekonstruksi_pemekaran",
                 f"angka gabungan {p23:.1f} dipecah; sisa induk {baru:.1f}")
            p23r[var] = baru


def isi_upah_dan_salin_induk(rows):
    upah24 = {r["code_prov"]: r.get("upah_agregat") for r in rows if r["year"] == 2024}
    ump = {(r["code_prov"], r["year"]): r.get("ump") for r in rows}
    for r in rows:
        if r["year"] != 2025 or r.get("status_observasi") != "berdiri" or r.get("upah_agregat") is not None:
            continue
        u0, u1, u2 = ump.get((r["code_prov"], 2024)), ump.get((r["code_prov"], 2025)), upah24.get(r["code_prov"])
        if u0 and u1 and u2:
            r["upah_agregat"] = u2 * (u1 / u0)
            note(r["code_prov"], 2025, "upah_agregat", "proyeksi_rasio_UMP",
                 "upah_2024 × (UMP_2025/UMP_2024)")
        elif u2:
            r["upah_agregat"] = u2 * 1.05
            note(r["code_prov"], 2025, "upah_agregat", "proyeksi_5pct", "+5% dari 2024")
    for r in rows:
        if r["code_prov"] not in NEW_PAPUA or r.get("status_observasi") != "berdiri":
            continue
        par = get_row(rows, 91 if r["code_prov"] == 92 else 94, r["year"])
        if r.get("ump") is None and par.get("ump"):
            r["ump"] = par["ump"]
            note(r["code_prov"], r["year"], "ump", "salin_induk", f"salin {par['code_prov']}")
        if r.get("inc") is None and par.get("inc"):
            r["inc"] = par["inc"]
            note(r["code_prov"], r["year"], "inc", "salin_induk", "PDRB per kapita induk")
        if r.get("upah_agregat") is None and par.get("upah_agregat"):
            r["upah_agregat"] = par["upah_agregat"]
            note(r["code_prov"], r["year"], "upah_agregat", "salin_induk_Sakernas",
                 "Sakernas 38 provinsi belum ada")
        if r.get("idi") is None and par.get("idi"):
            r["idi"] = par["idi"]
            note(r["code_prov"], r["year"], "idi", "salin_induk", "IDI pemekaran belum terbit")


def isi_kriminal(rows):
    nas = load_nasional()["crime"]
    crime_2023 = load_code_value(TABEL / "crime_2023.csv")
    pdrb23 = {r["code_prov"]: r.get("pdrb_miliar") or 0 for r in rows
              if r["year"] == 2023 and r["code_prov"] not in NEW_PAPUA}
    residual = nas[2023] - sum(crime_2023.values())
    others = [c for c in pdrb23 if c not in crime_2023]
    pdrb_oth = sum(pdrb23[c] for c in others) or 1
    stock23 = dict(crime_2023)
    for c in others:
        stock23[c] = residual * (pdrb23[c] / pdrb_oth)
        note(c, 2023, "tindak_pidana", "alokasi_sisa_PDRB",
             "sisa nasional 2023 setelah 10 provinsi BPS, proporsional PDRB")
    group_stock = {91: stock23.get(91, 0), 94: stock23.get(94, 0)}
    groups = {91: [91, 92], 94: [94, 95, 96, 97]}
    for r in rows:
        if r.get("status_observasi") != "berdiri":
            continue
        y, code = r["year"], r["code_prov"]
        scale = nas.get(y, nas[2023]) / nas[2023]
        parent = 91 if code in (91, 92) else (94 if code in (94, 95, 96, 97) else None)
        if parent is not None and y >= 2023:
            members = [c for c in groups[parent] if exists(c, y)]
            pdrbs = {c: get_row(rows, c, y).get("pdrb_miliar") or get_row(rows, c, y).get("h_adhb") or 0
                     for c in members}
            tot = sum(pdrbs.values()) or 1
            r["tindak_pidana"] = group_stock[parent] * scale * (pdrbs[code] / tot)
            note(code, y, "tindak_pidana", "bagi_wilayah_pemekaran",
                 f"stok 2023 wilayah {parent} × skala nasional × porsi PDRB")
        else:
            sh = stock23.get(code)
            if sh is None:
                continue
            r["tindak_pidana"] = sh * scale
            if y != 2023:
                note(code, y, "tindak_pidana", "skala_nasional",
                     "porsi 2023 × (kasus_nas_t / kasus_nas_2023)")
        pop = (r["pdrb_miliar"] * 1e6 / r["inc"]) if r.get("pdrb_miliar") and r.get("inc") else None
        r["tindak_pidana_per_100rb"] = (100000.0 * r["tindak_pidana"] / pop) if pop and pop > 0 else None


def isi_angkutan(rows):
    nas = load_nasional()
    h_year = {}
    for r in rows:
        if r.get("status_observasi") == "berdiri" and r.get("h_adhb"):
            h_year[r["year"]] = h_year.get(r["year"], 0) + r["h_adhb"]
    for y in YEARS:
        tot_h = h_year.get(y) or 0
        tot_rail = sum((r.get("h_adhb") or 0) for r in rows
                       if r["year"] == y and r["code_prov"] in RAIL_PROV and r.get("status_observasi") == "berdiri") or 1
        for r in rows:
            if r["year"] != y or r.get("status_observasi") != "berdiri":
                continue
            sh = ((r.get("h_adhb") or 0) / tot_h) if tot_h else 0
            r["pax_udara"] = nas["pax_air"][y] * 1e6 * sh
            r["pax_laut"] = nas["pax_laut"][y] * 1e6 * sh
            r["pax_bus"] = nas["pax_bus"][y] * 1e6 * sh
            r["cargo_udara_juta_ton"] = nas["cargo_air"][y] * sh
            r["cargo_laut_juta_ton"] = nas["cargo_laut"][y] * sh
            if r["code_prov"] in RAIL_PROV:
                shr = ((r.get("h_adhb") or 0) / tot_rail) if tot_rail else 0
                r["pax_ka"] = nas["pax_ka"][y] * 1e6 * shr
                r["cargo_ka_juta_ton"] = nas["cargo_ka"][y] * shr
            else:
                r["pax_ka"] = 0.0
                r["cargo_ka_juta_ton"] = 0.0
            r["cargo_total_juta_ton"] = (
                r["cargo_udara_juta_ton"] + r["cargo_laut_juta_ton"] + r["cargo_ka_juta_ton"]
            )
            note(r["code_prov"], y, "pax_udara", "alokasi_H_ADHB",
                 "total nasional × porsi PDRB transportasi (H_ADHB)")


def isi_fiskal(rows):
    for _, code, *_ in PROV:
        for var in ("rasio_pad", "serapan_belanja"):
            s = {r["year"]: r.get(var) for r in rows if r["code_prov"] == code}
            s2 = interpolate_back_fwd({y: v for y, v in s.items() if v}, code, var)
            for r in rows:
                if r["code_prov"] == code and r.get("status_observasi") == "berdiri" and r.get(var) is None:
                    r[var] = s2.get(r["year"])


def coerce_num(rows):
    skip = {"prov_nama", "pulau", "status_observasi"}
    for r in rows:
        r["code_prov"] = int(r["code_prov"])
        r["year"] = int(r["year"])
        if r.get("code_prov_induk") not in (None, ""):
            r["code_prov_induk"] = int(float(r["code_prov_induk"]))
        if r.get("provinsi_berdiri") not in (None, ""):
            r["provinsi_berdiri"] = int(float(r["provinsi_berdiri"]))
        for k, v in list(r.items()):
            if k in skip or k in ("code_prov", "year", "code_prov_induk", "provinsi_berdiri", "status_observasi"):
                continue
            if v in ("", None):
                r[k] = None
            else:
                r[k] = num(v)


def main():
    rows = read_csv(OUT / "kerangka.csv")
    coerce_num(rows)
    isi_jalan(rows)
    pecah_pmtb_pdrb_2023(rows)
    isi_upah_dan_salin_induk(rows)
    isi_indeks_resmi(rows)
    isi_upah_dan_salin_induk(rows)
    isi_fiskal(rows)
    isi_kriminal(rows)
    isi_angkutan(rows)
    write_csv(OUT / "panel_terisi.csv", rows, PANEL_FIELDS + ["inc"])
    write_csv(OUT / "catatan_imputasi.csv", NOTES,
              ["code_prov", "year", "variabel", "metode", "keterangan"])
    n_isi = sum(1 for r in rows if r.get("status_observasi") == "berdiri")
    print(f"panel terisi {len(rows)} baris ({n_isi} berdiri), catatan {len(NOTES)}")


if __name__ == "__main__":
    main()
