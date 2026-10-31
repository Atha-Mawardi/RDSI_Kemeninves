"""Format angka gaya Indonesia: titik ribuan, koma desimal."""

import math

from django import template
from django.utils.html import format_html

register = template.Library()


def _id(nilai, digit):
    s = f"{nilai:,.{digit}f}"
    return s.replace(",", "\0").replace(".", ",").replace("\0", ".")


@register.filter
def angka(nilai, digit=1):
    try:
        v = float(nilai)
    except (TypeError, ValueError):
        return "–"
    if math.isnan(v):
        return "–"
    return _id(v, int(digit))


@register.filter
def ringkas(nilai):
    """Digit desimal menyesuaikan besaran: 1.234.567 | 12,3 | 0,123 | 0,0123."""
    try:
        v = float(nilai)
    except (TypeError, ValueError):
        return "–"
    if math.isnan(v):
        return "–"
    a = abs(v)
    digit = 0 if a >= 100 else 1 if a >= 10 else 2 if a >= 1 else 3 if a >= 0.01 or a == 0 else 4
    return _id(v, digit)


@register.filter
def triliun(nilai_miliar, digit=1):
    try:
        return angka(float(nilai_miliar) / 1000, digit)
    except (TypeError, ValueError):
        return "–"


@register.filter
def persen(nilai, digit=0):
    try:
        return angka(float(nilai) * 100, digit) + "%"
    except (TypeError, ValueError):
        return "–"


@register.filter
def ambil(kamus, kunci):
    if kamus is None:
        return None
    if isinstance(kamus, dict):
        return kamus.get(kunci, kamus.get(str(kunci)))
    return getattr(kamus, str(kunci), None)


@register.filter
def kelas_lengkap(nilai):
    """Kelas warna sel kelengkapan (persen terisi)."""
    if nilai is None:
        return "p0"
    return "p100" if nilai >= 99.95 else "p50" if nilai >= 50 else "p1" if nilai > 0 else "p0"


@register.simple_tag
def istilah(kunci, label=None):
    """Judul kolom: nama, keterangan satu baris di bawahnya (bila ada), definisi lengkap sebagai tooltip."""
    from simulasi.istilah import ISTILAH
    nama, ket, definisi = ISTILAH[kunci]
    if not ket:
        return format_html('<span class="istilah" title="{}">{}</span>', definisi, label or nama)
    return format_html('<span class="istilah" title="{}">{}<small>{}</small></span>', definisi, label or nama, ket)
