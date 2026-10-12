"""Create a lean Pandoc reference DOCX using the report's styles only.

Using the full report directly as --reference-doc causes all legacy figures to
be copied into the standalone subsection.  This builder keeps the style/theme
parts and page geometry without copying body content or media.
"""

from __future__ import annotations

import shutil
import tempfile
import zipfile
from pathlib import Path

from docx import Document


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / "Laporan Akhir Kebijakan Makro Investasi v2.docx"
OUTPUT = HERE / "reference_report_styles.docx"


def main() -> None:
    src_doc = Document(SOURCE)
    blank = Document()
    src_sec = src_doc.sections[0]
    dst_sec = blank.sections[0]
    for attr in (
        "page_width",
        "page_height",
        "top_margin",
        "bottom_margin",
        "left_margin",
        "right_margin",
        "header_distance",
        "footer_distance",
    ):
        setattr(dst_sec, attr, getattr(src_sec, attr))

    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp) / "base.docx"
        blank.save(base)
        replacements = {
            "word/styles.xml",
            "word/stylesWithEffects.xml",
            "word/fontTable.xml",
            "word/theme/theme1.xml",
        }
        with zipfile.ZipFile(SOURCE) as source_zip, zipfile.ZipFile(base) as base_zip:
            source_names = set(source_zip.namelist())
            with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED) as out_zip:
                for item in base_zip.infolist():
                    data = base_zip.read(item.filename)
                    if item.filename in replacements and item.filename in source_names:
                        data = source_zip.read(item.filename)
                    out_zip.writestr(item, data)
    print(OUTPUT)


if __name__ == "__main__":
    main()
