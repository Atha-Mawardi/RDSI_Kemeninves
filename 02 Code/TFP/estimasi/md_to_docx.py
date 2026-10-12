"""
Konversi Report TFP.md -> .docx memakai python-docx.

Pandoc tidak tersedia di mesin ini, jadi konversi ditulis sendiri. Prinsipnya
menahan diri: dokumen memakai gaya bawaan template Word, tanpa mengubah jenis
huruf, ukuran, maupun spasi paragraf. Yang dipakai hanya bold dan italic, plus
abu-abu untuk baris kepala tabel.

Jalankan: PYTHONIOENCODING=utf-8 python "02 Code/TFP/estimasi/md_to_docx.py"
"""

import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "02 Code" / "TFP" / "docs" / "04 Report"
SUMBER = [REPORT / "Report TFP.md",
          REPORT / "Lampiran E - Perbandingan Desain.md"]
KELUARAN = REPORT / "Report TFP.docx"
LEBAR_GAMBAR = Inches(6.0)

# Satu-satunya warna yang dipakai, untuk baris kepala tabel.
ABU = "D9D9D9"


def arsir(cell, hexcolor=ABU):
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:fill"), hexcolor)
    cell._tc.get_or_add_tcPr().append(shd)


def tulis_inline(par, teks):
    """Render **bold**, *italic*, dan `code` sebagai run terpisah.

    Backtick dipetakan ke italic, bukan ke jenis huruf monospace, supaya
    dokumen tetap memakai satu jenis huruf bawaan.
    """
    for bagian in re.split(r"(\*\*.+?\*\*|\*[^*]+?\*|`[^`]+?`)", teks):
        if not bagian:
            continue
        if bagian.startswith("**") and bagian.endswith("**"):
            par.add_run(bagian[2:-2]).bold = True
        elif bagian.startswith("*") and bagian.endswith("*"):
            par.add_run(bagian[1:-1]).italic = True
        elif bagian.startswith("`") and bagian.endswith("`"):
            par.add_run(bagian[1:-1]).italic = True
        else:
            par.add_run(bagian)


def baris_tabel(baris):
    return [sel.strip() for sel in baris.strip().strip("|").split("|")]


def tulis_tabel(doc, blok):
    isi = [baris_tabel(b) for b in blok if not re.match(r"^\|[\s:|-]+\|$", b.strip())]
    if not isi:
        return
    n_kol = max(len(r) for r in isi)
    tabel = doc.add_table(rows=len(isi), cols=n_kol)
    tabel.style = "Table Grid"
    for i, baris in enumerate(isi):
        for j in range(n_kol):
            sel = tabel.cell(i, j)
            sel.text = ""
            par = sel.paragraphs[0]
            teks = baris[j] if j < len(baris) else ""
            tulis_inline(par, teks)
            if i == 0:
                arsir(sel)
                for run in par.runs:
                    run.bold = True


def konversi(doc, path_md, sisipkan_page_break=False):
    baris = path_md.read_text(encoding="utf-8").split("\n")
    if sisipkan_page_break:
        doc.add_page_break()

    i = 0
    while i < len(baris):
        b = baris[i]
        s = b.strip()

        if not s:
            i += 1
            continue

        # Pemisah horizontal diabaikan; struktur sudah dibawa heading.
        if re.match(r"^-{3,}$", s):
            i += 1
            continue

        # Gambar
        m = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)$", s)
        if m:
            rel = m.group(2).replace("%20", " ")
            img = (path_md.parent / rel).resolve()
            if img.exists():
                doc.add_picture(str(img), width=LEBAR_GAMBAR)
                doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
            else:
                print(f"  gambar tidak ditemukan: {img}", file=sys.stderr)
            i += 1
            continue

        # Heading
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            doc.add_heading(m.group(2).strip(), level=len(m.group(1)))
            i += 1
            continue

        # Tabel
        if s.startswith("|"):
            blok = []
            while i < len(baris) and baris[i].strip().startswith("|"):
                blok.append(baris[i])
                i += 1
            tulis_tabel(doc, blok)
            continue

        # Blok kode: dirender sebagai paragraf italic, satu baris per paragraf
        if s.startswith("```"):
            i += 1
            while i < len(baris) and not baris[i].strip().startswith("```"):
                if baris[i].strip():
                    par = doc.add_paragraph()
                    par.add_run(baris[i].strip()).italic = True
                i += 1
            i += 1
            continue

        # Daftar bernomor dan berpoin
        m = re.match(r"^(\d+)\.\s+(.*)$", s)
        if m:
            par = doc.add_paragraph(style="List Number")
            tulis_inline(par, m.group(2))
            i += 1
            continue
        m = re.match(r"^[-*]\s+(.*)$", s)
        if m:
            par = doc.add_paragraph(style="List Bullet")
            tulis_inline(par, m.group(1))
            i += 1
            continue

        # Paragraf: gabungkan baris sampai baris kosong atau elemen blok lain
        potongan = []
        while i < len(baris):
            t = baris[i].strip()
            if (not t or t.startswith(("|", "#", "```", "!["))
                    or re.match(r"^-{3,}$", t)
                    or re.match(r"^(\d+\.|[-*])\s", t)):
                break
            potongan.append(t)
            i += 1
        if potongan:
            par = doc.add_paragraph()
            tulis_inline(par, " ".join(potongan))


def main():
    doc = Document()
    for n, src in enumerate(SUMBER):
        if not src.exists():
            sys.exit(f"Berkas sumber tidak ada: {src}")
        print(f"memproses {src.name}")
        konversi(doc, src, sisipkan_page_break=(n > 0))

    doc.save(KELUARAN)
    n_tabel = len(doc.tables)
    n_gambar = sum(1 for s in doc.inline_shapes)
    print(f"\nTersimpan: {KELUARAN.name}")
    print(f"  paragraf {len(doc.paragraphs)} | tabel {n_tabel} | gambar {n_gambar}")


if __name__ == "__main__":
    main()
