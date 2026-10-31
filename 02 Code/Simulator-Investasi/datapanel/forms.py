from django import forms

from . import variabel as V
from .models import VersiData


class FormUnggah(forms.Form):
    MODE = [
        ("baru", "Versi baru utuh (berkas memuat seluruh data)"),
        ("pembaruan", "Perbarui versi yang ada (sel kosong diwarisi dari versi induk)"),
    ]
    IMPUTASI = [
        ("tidak", "Jangan isi sel kosong"),
        ("interpolasi", "Interpolasi linear di antara tahun yang terisi"),
        ("locf", "Salin nilai tahun sebelumnya (LOCF)"),
        ("interpolasi_locf", "Interpolasi, lalu LOCF untuk tahun terakhir"),
    ]
    berkas = forms.FileField(help_text="xlsx (semua sheet dibaca) atau csv. Format lebar atau panjang.")
    nama = forms.CharField(max_length=120, help_text="Contoh: Pembaruan PDRB 2025 rilis Februari 2026")
    keterangan = forms.CharField(widget=forms.Textarea(attrs={"rows": 2}), required=False)
    mode = forms.ChoiceField(choices=MODE, initial="baru", widget=forms.RadioSelect)
    induk = forms.ModelChoiceField(queryset=VersiData.objects.none(), required=False,
                                   label="Versi induk (untuk mode pembaruan)")
    imputasi = forms.ChoiceField(choices=IMPUTASI, initial="interpolasi")
    ambang_lonjakan = forms.FloatField(initial=50, min_value=5, max_value=500,
                                       label="Tandai perubahan tahunan di atas (%)")
    tahun_min = forms.IntegerField(required=False, min_value=1990, max_value=2100)
    tahun_max = forms.IntegerField(required=False, min_value=1990, max_value=2100)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        qs = VersiData.objects.filter(status__in=[VersiData.Status.SIAP, VersiData.Status.AKTIF])
        self.fields["induk"].queryset = qs
        self.fields["induk"].initial = VersiData.aktif()

    def clean(self):
        data = super().clean()
        if data.get("mode") == "pembaruan" and not data.get("induk"):
            self.add_error("induk", "Pilih versi induk untuk mode pembaruan.")
        nama = (data.get("berkas").name if data.get("berkas") else "").lower()
        if nama and not nama.endswith((".xlsx", ".xlsm", ".csv", ".txt")):
            self.add_error("berkas", "Hanya .xlsx atau .csv.")
        return data


class FormObservasi(forms.Form):
    """Sunting satu baris provinsi-tahun. Field dibuat dari kamus variabel."""

    def __init__(self, *args, nilai=None, **kwargs):
        super().__init__(*args, **kwargs)
        nilai = nilai or {}
        for v in V.DAFTAR:
            self.fields[v.kode] = forms.FloatField(
                label=v.label, required=False, initial=nilai.get(v.kode),
                help_text=v.satuan, widget=forms.NumberInput(attrs={"step": "any"}))
        self.fields["alasan"] = forms.CharField(max_length=200, label="Alasan penyuntingan")

    def kelompok(self):
        out = {}
        for v in V.DAFTAR:
            out.setdefault(v.grup, []).append(self[v.kode])
        return out.items()
