# Unduh sumber resmi untuk panel provinsi-tahun.
# Keluaran: 01 Data/TFP/processed/panel_raw/. Tidak menulis 01 Data/00 sumber/.

from pathlib import Path
import json
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
from xml.etree import ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pengaturan import RAW
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
CTX = ssl.create_default_context()

DJPK_KODE = [
    ("01", 11, "Aceh"), ("02", 12, "Sumatera Utara"), ("03", 13, "Sumatera Barat"),
    ("04", 14, "Riau"), ("05", 15, "Jambi"), ("06", 16, "Sumatera Selatan"),
    ("07", 17, "Bengkulu"), ("08", 18, "Lampung"), ("09", 31, "DKI Jakarta"),
    ("10", 32, "Jawa Barat"), ("11", 33, "Jawa Tengah"), ("12", 34, "DI Yogyakarta"),
    ("13", 35, "Jawa Timur"), ("14", 61, "Kalimantan Barat"), ("15", 62, "Kalimantan Tengah"),
    ("16", 63, "Kalimantan Selatan"), ("17", 64, "Kalimantan Timur"), ("18", 71, "Sulawesi Utara"),
    ("19", 72, "Sulawesi Tengah"), ("20", 73, "Sulawesi Selatan"), ("21", 74, "Sulawesi Tenggara"),
    ("22", 51, "Bali"), ("23", 52, "Nusa Tenggara Barat"), ("24", 53, "Nusa Tenggara Timur"),
    ("25", 81, "Maluku"), ("26", 94, "Papua"), ("27", 82, "Maluku Utara"),
    ("28", 36, "Banten"), ("29", 19, "Kep. Bangka Belitung"), ("30", 75, "Gorontalo"),
    ("31", 21, "Kep. Riau"), ("32", 91, "Papua Barat"), ("33", 76, "Sulawesi Barat"),
    ("34", 65, "Kalimantan Utara"), ("35", 95, "Papua Selatan"), ("36", 96, "Papua Tengah"),
    ("37", 97, "Papua Pegunungan"), ("38", 92, "Papua Barat Daya"),
]


def http(url, dest=None, data=None, timeout=60):
    headers = {"User-Agent": UA, "Accept": "*/*"}
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        body = urllib.parse.urlencode(data).encode()
        req = urllib.request.Request(url, data=body, headers=headers)
    else:
        req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=CTX, timeout=timeout) as r:
        raw = r.read()
    if dest:
        Path(dest).parent.mkdir(parents=True, exist_ok=True)
        Path(dest).write_bytes(raw)
    return raw


def parse_djpk_xml(raw):
    ns = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}
    root = ET.fromstring(raw)
    out = {}
    for row in root.findall(".//ss:Row", ns):
        cells = []
        for cell in row.findall("ss:Cell", ns):
            d = cell.find("ss:Data", ns)
            cells.append("" if d is None or d.text is None else d.text.strip())
        if len(cells) < 4 or cells[0] in ("", "Akun"):
            continue
        akun = re.sub(r"\s+", " ", cells[0]).strip()
        try:
            ang = float(cells[1]) if cells[1] else None
            real = float(cells[2]) if cells[2] else None
            pct = float(str(cells[3]).replace(",", ".")) if cells[3] not in ("", "0") else None
        except ValueError:
            continue
        out[akun] = {"anggaran": ang, "realisasi": real, "pct": pct}
    return out


def pick(d, *names):
    for n in names:
        if n in d:
            return d[n]
        for k, v in d.items():
            if k.strip() == n or n.lower() in k.lower():
                return v
    return {"anggaran": None, "realisasi": None, "pct": None}


def unduh_djpk_satu(tahun, kode_djpk, code_prov, nama):
    dest = RAW / "djpk" / f"apbd_{tahun}_{kode_djpk}.xml"
    url = ("https://djpk.kemenkeu.go.id/portal/csv_apbd"
           f"?type=apbd&periode=12&tahun={tahun}&provinsi={kode_djpk}&pemda=--")
    try:
        raw = http(url, dest=dest)
        parsed = parse_djpk_xml(raw)
        pad = pick(parsed, "PAD")
        pend = pick(parsed, "Pendapatan Daerah")
        bel = pick(parsed, "Belanja Daerah")
        return {
            "tahun": tahun, "kode_djpk": kode_djpk, "code_prov": code_prov, "prov": nama,
            "pad_anggaran": pad["anggaran"], "pad_realisasi": pad["realisasi"],
            "pendapatan_anggaran": pend["anggaran"], "pendapatan_realisasi": pend["realisasi"],
            "belanja_anggaran": bel["anggaran"], "belanja_realisasi": bel["realisasi"],
            "serapan_belanja_pct": bel["pct"],
            "status": "ok" if pad["realisasi"] is not None else "kosong",
        }
    except Exception as e:
        return {
            "tahun": tahun, "kode_djpk": kode_djpk, "code_prov": code_prov, "prov": nama,
            "status": f"gagal:{type(e).__name__}",
        }


def unduh_djpk():
    jobs = []
    for tahun in range(2017, 2026):
        for kode, cps, nama in DJPK_KODE:
            if tahun < 2023 and cps in (92, 95, 96, 97):
                continue
            jobs.append((tahun, kode, cps, nama))
    rows = []
    print(f"DJPK: {len(jobs)} unduhan")
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(unduh_djpk_satu, *j) for j in jobs]
        for i, fut in enumerate(as_completed(futs), 1):
            rows.append(fut.result())
            if i % 40 == 0:
                print(f"  {i}/{len(jobs)}")
    out = RAW / "djpk" / "apbd_panel.csv"
    keys = ["tahun", "kode_djpk", "code_prov", "prov",
            "pad_anggaran", "pad_realisasi", "pendapatan_anggaran", "pendapatan_realisasi",
            "belanja_anggaran", "belanja_realisasi", "serapan_belanja_pct", "status"]
    with out.open("w", encoding="utf-8") as f:
        f.write(",".join(keys) + "\n")
        for r in sorted(rows, key=lambda x: (x["tahun"], x["kode_djpk"])):
            f.write(",".join("" if r.get(k) is None else str(r.get(k, "")) for k in keys) + "\n")
    n_ok = sum(1 for r in rows if r.get("status") == "ok")
    print(f"DJPK selesai: {n_ok}/{len(rows)} ok -> {out}")


def unduh_wpdatatable(table_id, dest_json, label):
    html_url = {
        69: "https://lumbungdata.bantenprov.go.id/data-nilai-indeks-demokrasi-indonesia-idi/",
        64: "https://lumbungdata.bantenprov.go.id/data-indeks-ketimpangan-gender-ikg/",
    }[table_id]
    html = http(html_url).decode("utf-8", "ignore")
    m = re.search(rf'wdtNonceFrontendEdit_{table_id}"[^>]*value="([a-f0-9]+)"', html)
    nonce = m.group(1) if m else ""
    ajax = (f"https://lumbungdata.bantenprov.go.id/wp-admin/admin-ajax.php"
            f"?action=get_wdtable&table_id={table_id}")
    payload = {
        "draw": 1, "start": 0, "length": 200,
        "wdtNonce": nonce, "wdtNonceFrontendEdit": nonce,
    }
    raw = http(ajax, data=payload)
    dest_json.write_bytes(raw)
    print(f"{label}: {len(raw)} byte, nonce={nonce} -> {dest_json}")


def main():
    (RAW / "djpk").mkdir(parents=True, exist_ok=True)
    (RAW / "idi").mkdir(parents=True, exist_ok=True)
    (RAW / "ikg").mkdir(parents=True, exist_ok=True)
    try:
        unduh_wpdatatable(69, RAW / "idi" / "idi_wpdatatable.json", "IDI")
    except Exception as e:
        print("IDI gagal:", e)
    try:
        unduh_wpdatatable(64, RAW / "ikg" / "ikg_wpdatatable.json", "IKG")
    except Exception as e:
        print("IKG gagal:", e)
    unduh_djpk()


if __name__ == "__main__":
    main()
