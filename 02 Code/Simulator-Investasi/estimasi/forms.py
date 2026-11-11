from django import forms

from .determinan import NAMA_PILAR, per_pilar
from .models import KoefisienSektoral, SetDeterminan, SetParameter


class FormSetParameter(forms.ModelForm):
    class Meta:
        model = SetParameter
        fields = ["nama", "b1", "se_b1", "b2", "se_b2", "crs", "tahun_awal", "tahun_akhir", "catatan", "bawaan"]
        widgets = {"catatan": forms.Textarea(attrs={"rows": 3})}

    def clean(self):
        d = super().clean()
        if d.get("b1") is not None and not 0.01 <= d["b1"] <= 1.5:
            self.add_error("b1", "b1 harus antara 0,01 dan 1,5.")
        return d


class FormKoefisienSektoral(forms.ModelForm):
    class Meta:
        model = KoefisienSektoral
        fields = ["nama", "primer", "se_primer", "sekunder", "se_sekunder", "tva", "se_tva", "catatan", "bawaan"]
        widgets = {"catatan": forms.Textarea(attrs={"rows": 3})}


class FormSetDeterminan(forms.ModelForm):
    """Nama set dan, per indikator, koefisien, standard error, SD, dan rata-rata."""

    KOLOM = [("koef", "Koefisien"), ("se", "Standard error"), ("sd", "Standard deviation indikator"), ("rata", "Rata-rata asli")]

    class Meta:
        model = SetDeterminan
        fields = ["nama", "catatan", "bawaan"]
        widgets = {"catatan": forms.Textarea(attrs={"rows": 2})}

    def __init__(self, *args, indikator=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.indikator = [dict(x) for x in (indikator or self.instance.indikator or [])]
        for ind in self.indikator:
            for k, _ in self.KOLOM:
                self.fields[f"{k}_{ind['kode']}"] = forms.FloatField(
                    initial=ind.get(k), required=k == "koef", min_value=0 if k in ("se", "sd") else None,
                    widget=forms.NumberInput(attrs={"step": "any", "class": "sel-kecil"}))

    def baris(self):
        for p, isi in per_pilar(self.indikator).items():
            if isi:
                yield NAMA_PILAR.get(p, p), [(ind, [self[f"{k}_{ind['kode']}"] for k, _ in self.KOLOM]) for ind in isi]

    def save(self, commit=True):
        obj = super().save(commit=False)
        d = self.cleaned_data
        obj.indikator = [{**ind, **{k: d.get(f"{k}_{ind['kode']}") or 0.0 for k, _ in self.KOLOM}}
                         for ind in self.indikator]
        if commit:
            obj.save()
        return obj
