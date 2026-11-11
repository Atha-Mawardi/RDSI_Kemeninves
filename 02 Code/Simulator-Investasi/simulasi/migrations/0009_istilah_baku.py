import re

from django.db import migrations

ISTILAH = [
    (r"\bsimpangan baku\b", "standard deviation"),
    (r"\bgalat baku\b", "standard error"),
    (r"\befek tetap\b", "fixed effect"),
    (r"\balfa baku\b", "standard alpha"),
    (r"\bpengganda\b", "multiplier"),
    (r"\bbocoran\b", "spillover"),
    (r"\bbawaan\b", "default"),
]

TEKS = [
    ("simulasi", "Skenario", ["nama", "singkat", "deskripsi"]),
    ("estimasi", "SetParameter", ["nama", "catatan"]),
    ("estimasi", "KoefisienSektoral", ["nama", "catatan"]),
    ("estimasi", "SetDeterminan", ["nama", "catatan"]),
]


def _ganti(teks):
    for pola, baru in ISTILAH:
        teks = re.sub(pola, lambda m, b=baru: b[0].upper() + b[1:] if m.group()[0].isupper() else b, teks,
                      flags=re.IGNORECASE)
    return teks


def perbarui(apps, schema_editor):
    for app, model, kolom in TEKS:
        for obj in apps.get_model(app, model).objects.all():
            ubah = {k: _ganti(getattr(obj, k)) for k in kolom if getattr(obj, k)}
            ubah = {k: v for k, v in ubah.items() if v != getattr(obj, k)}
            if ubah:
                type(obj).objects.filter(pk=obj.pk).update(**ubah)


class Migration(migrations.Migration):

    dependencies = [
        ("simulasi", "0008_label_ramah"),
        ("estimasi", "0004_isi_set_determinan"),
    ]

    operations = [migrations.RunPython(perbarui, migrations.RunPython.noop)]
