"""Skenario aktif: satu pilihan per sesi yang diikuti Hasil, Beranda, Jelajah, IO, dan Pivot."""

from .models import Skenario

KUNCI = "skenario_aktif"


def daftar_berhasil():
    return Skenario.objects.filter(hasil__isnull=False).order_by("kelompok", "templat", "nama")


def ambil(request):
    """Skenario aktif sesi ini; default BAU (atau skenario berhasil pertama) bila belum dipilih."""
    pk = request.session.get(KUNCI)
    qs = Skenario.objects.filter(hasil__isnull=False).select_related("hasil", "versi_data")
    sk = qs.filter(pk=pk).first() if pk else None
    if sk is None:
        sk = qs.filter(kelompok=Skenario.Kelompok.BAWAAN, templat="P0").first() or qs.order_by("-diubah").first()
    return sk


def tetapkan(request, sk):
    request.session[KUNCI] = sk.pk


def grup():
    """[(judul, [skenario...]), ...] untuk pemilih bertingkat."""
    semua = list(Skenario.objects.only("pk", "nama", "singkat", "kelompok", "templat", "status").order_by("templat", "nama"))
    return [("Default", [s for s in semua if s.kelompok == Skenario.Kelompok.BAWAAN]),
            ("Kustom", [s for s in semua if s.kelompok != Skenario.Kelompok.BAWAAN])]
