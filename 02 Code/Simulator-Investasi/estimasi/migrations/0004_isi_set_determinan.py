from django.db import migrations


def isi(apps, schema_editor):
    from estimasi.determinan import AWAL

    SetDeterminan = apps.get_model("estimasi", "SetDeterminan")
    if not SetDeterminan.objects.exists():
        SetDeterminan.objects.create(
            nama="Determinan TFP provinsi 2017-2024", indikator=AWAL, bawaan=True,
            catatan="Satu regresi per pilar, 34 provinsi, N = 272; koefisien per +1 SD indikator.")


class Migration(migrations.Migration):
    dependencies = [("estimasi", "0003_set_determinan")]
    operations = [migrations.RunPython(isi, migrations.RunPython.noop)]
