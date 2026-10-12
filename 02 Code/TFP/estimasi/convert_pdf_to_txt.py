"""
Konversi deterministik dokumen Masterplan TFP -> .txt + ekstraksi figure.

Diadaptasi dari 'TFP Research/00 Assets/convert_pdf_to_txt.py' (pola yang sama:
PyMuPDF, penanda ===== PAGE n =====), digeneralisasi untuk:
  - walk rekursif seluruh folder sumber, bukan daftar file hardcoded
  - ikut mengonversi .docx lewat python-docx
  - ekstraksi gambar tertanam ke 01 Data/TFP/raw/masterplan_extract/figures/<stem>/
  - menulis manifest supaya hasilnya bisa ditelusuri

Ekstraksi murni mekanis. Tidak ada peringkasan atau terjemahan di sini - itu
dikerjakan terpisah setelah .txt-nya dibaca.

Jalankan:  PYTHONIOENCODING=utf-8 python "02 Code/TFP/estimasi/convert_pdf_to_txt.py"
(stdout Windows default cp1252 dan akan crash di karakter seperti -> atau em-dash)
"""

import csv
import sys
from pathlib import Path

import fitz  # PyMuPDF

ROOT = Path(__file__).resolve().parents[3]          # project root
SRC_DIR = ROOT / "01 Data" / "TFP" / "raw" / "Masterplan TFP"
TXT_DIR = ROOT / "01 Data" / "TFP" / "raw" / "masterplan_extract" / "txt"
FIG_DIR = ROOT / "01 Data" / "TFP" / "raw" / "masterplan_extract" / "figures"
MANIFEST = ROOT / "01 Data" / "TFP" / "raw" / "masterplan_extract" / "manifest_konversi.csv"

# Gambar di bawah ambang ini hampir selalu logo, ikon, atau garis hias.
MIN_IMG_W = 200
MIN_IMG_H = 200

# File sampah macOS yang ikut tersinkron lewat OneDrive.
SKIP_NAMES = {".DS_Store", "Thumbs.db"}


def safe_stem(path: Path) -> str:
    """Nama file datar yang tetap bisa dilacak ke sumbernya."""
    rel = path.relative_to(SRC_DIR)
    stem = "__".join(rel.parts).rsplit(".", 1)[0]
    keep = "-_ ()."
    stem = "".join(c if (c.isalnum() or c in keep) else "_" for c in stem)
    return stem[:120].strip()


def convert_pdf(pdf_path: Path) -> dict:
    stem = safe_stem(pdf_path)
    doc = fitz.open(pdf_path)

    pages = []
    for page_num, page in enumerate(doc, start=1):
        pages.append(f"\n\n===== PAGE {page_num} =====\n\n{page.get_text()}")

    full_text = "".join(pages)
    (TXT_DIR / f"{stem}.txt").write_text(full_text, encoding="utf-8")

    # Ekstraksi gambar: dedupe lewat xref supaya logo berulang tidak ditulis
    # puluhan kali, lalu buang yang terlalu kecil untuk jadi grafik.
    out_dir = FIG_DIR / stem
    seen_xrefs = set()
    n_img = 0
    for page_num, page in enumerate(doc, start=1):
        for img in page.get_images(full=True):
            xref = img[0]
            if xref in seen_xrefs:
                continue
            seen_xrefs.add(xref)
            try:
                pix = fitz.Pixmap(doc, xref)
            except Exception:
                continue
            if pix.width < MIN_IMG_W or pix.height < MIN_IMG_H:
                pix = None
                continue
            if pix.colorspace and pix.colorspace.n > 3:  # CMYK -> RGB
                pix = fitz.Pixmap(fitz.csRGB, pix)
            out_dir.mkdir(parents=True, exist_ok=True)
            pix.save(out_dir / f"p{page_num:03d}_x{xref}_{pix.width}x{pix.height}.png")
            n_img += 1
            pix = None

    n_pages = doc.page_count
    doc.close()
    return {"file": str(pdf_path.relative_to(SRC_DIR)), "jenis": "pdf",
            "halaman": n_pages, "karakter": len(full_text), "gambar": n_img,
            "txt": f"{stem}.txt"}


def render_figure_pages(pdf_path: Path, keywords=("FIGURE", "TABLE")) -> int:
    """Render halaman penuh yang memuat figure/tabel ke PNG.

    Perlu terpisah dari extract gambar tertanam: chart di dokumen ini digambar
    sebagai vektor, sehingga page.get_images() hanya menangkap layer raster di
    bawahnya (mis. outline peta kosong tanpa data). Render halaman menangkap
    grafik apa adanya seperti yang terlihat pembaca.
    """
    stem = safe_stem(pdf_path)
    out_dir = FIG_DIR / f"{stem}__halaman"
    doc = fitz.open(pdf_path)
    zoom = fitz.Matrix(2, 2)  # 2x ~ 144 dpi, cukup untuk membaca label sumbu

    n = 0
    for page_num, page in enumerate(doc, start=1):
        text_upper = page.get_text().upper()
        if not any(k in text_upper for k in keywords):
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        page.get_pixmap(matrix=zoom).save(out_dir / f"hal{page_num:03d}.png")
        n += 1

    doc.close()
    return n


def convert_docx(docx_path: Path) -> dict:
    from docx import Document

    stem = safe_stem(docx_path)
    d = Document(str(docx_path))

    parts = [p.text for p in d.paragraphs]
    for t_i, table in enumerate(d.tables, start=1):
        parts.append(f"\n===== TABEL {t_i} =====")
        for row in table.rows:
            parts.append(" | ".join(c.text.strip() for c in row.cells))

    full_text = "\n".join(parts)
    (TXT_DIR / f"{stem}.txt").write_text(full_text, encoding="utf-8")
    return {"file": str(docx_path.relative_to(SRC_DIR)), "jenis": "docx",
            "halaman": "", "karakter": len(full_text), "gambar": 0,
            "txt": f"{stem}.txt"}


def main() -> None:
    if not SRC_DIR.is_dir():
        sys.exit(f"Folder sumber tidak ditemukan: {SRC_DIR}")

    TXT_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)

    rows = []
    for path in sorted(SRC_DIR.rglob("*")):
        if not path.is_file() or path.name in SKIP_NAMES:
            continue
        ext = path.suffix.lower()
        if ext == ".pdf":
            rows.append(convert_pdf(path))
            rows[-1]["halaman_render"] = render_figure_pages(path)
        elif ext == ".docx":
            rows.append(convert_docx(path))
        else:
            continue
        r = rows[-1]
        print(f"{r['file']}: {r['halaman']} hal, {r['karakter']} char, "
              f"{r['gambar']} gambar, {r.get('halaman_render', 0)} hal-render "
              f"-> {r['txt']}")

    with MANIFEST.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["file", "jenis", "halaman",
                                           "karakter", "gambar",
                                           "halaman_render", "txt"],
                           restval=0)
        w.writeheader()
        w.writerows(rows)

    tot_pages = sum(r["halaman"] for r in rows if isinstance(r["halaman"], int))
    tot_imgs = sum(r["gambar"] for r in rows)
    print(f"\nSelesai: {len(rows)} dokumen, {tot_pages} halaman, "
          f"{tot_imgs} gambar. Manifest -> {MANIFEST.name}")


if __name__ == "__main__":
    main()
