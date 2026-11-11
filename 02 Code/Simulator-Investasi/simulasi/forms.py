from django import forms

from datapanel.models import VersiData
from datapanel.referensi import KELOMPOK, KODE_PROVINSI, KODE_PROVINSI_38, NAMA_PROVINSI, PULAU
from estimasi.determinan import JEDA_AWAL, PILAR, per_pilar, satu_sd
from estimasi.models import KoefisienSektoral, SetDeterminan, SetParameter

from .excel_skenario import KOLOM_ASUMSI
from .mesin import JALUR, JENIS_KEJUTAN
from .models import Skenario

CAKUPAN = [("nasional", "Nasional")] + [(f"pulau:{p}", f"Pulau {p}") for p in PULAU] + \
    [(f"prov:{k}", NAMA_PROVINSI[k]) for k in KODE_PROVINSI_38]
MAKS_KEJUTAN = 8
# isian determinan per pilar: (kunci, label, batas bawah, batas atas)
KOLOM_DETERMINAN = [("dz", "Perubahan (× standard deviation)", -3, 3), ("jeda", "Jeda sebelum efek (tahun)", 0, 10),
                    ("penuh", "Lama menuju efek penuh (tahun)", 1, 10), ("porsi", "Porsi investasi tambahan (%)", 0, 100),
                    ("biaya", "Biaya naik 1 standard deviation (triliun Rp)", 0, None)]

BAGIAN = [
    ("Basis", "Data, parameter, dan horizon",
     ["nama", "singkat", "deskripsi", "versi_data", "set_parameter", "koef_sektoral", "tahun_dasar", "tahun_target",
      "hist_awal", "hist_akhir", "kecualikan_2020", "pecah_papua"]),
    ("Sasaran", "Sasaran pertumbuhan nasional dan pembagiannya ke provinsi",
     ["sasaran", "mode_sasaran", "lambda_proporsional"]),
    ("Faktor", "Asumsi TFP, tenaga kerja, dan tren PMTB",
     ["mode_tfp", "tfp_nasional", "faktor_tfp", "mode_tk", "tk_nasional", "mode_pmtb", "g_pmtb_nasional"]),
    ("Investasi", "Investasi dasar dan investasi tambahan, triliun Rp nominal per tahun", []),
    ("Konversi", "Dari realisasi ke PMTB, dan fiskal daerah",
     ["g_investasi", "inflasi_pmtb", "pass_through", "rasio_realisasi", "apbd_persen", "pass_through_apbd"]),
    ("Sektoral", "Arah sektor investasi tambahan dan realokasi tenaga kerja",
     ["alokasi_a2", "realokasi_pp", "tujuan_realokasi"]),
    ("Jalur & shock", "Nilai per tahun yang berubah dan shock yang meluruh", []),
    ("Determinan", "Perubahan determinan TFP di atas tren historis dan jeda efeknya", ["set_determinan"]),
    ("Confidence", "Monte Carlo", ["n_simulasi", "skala_se", "volatilitas_tfp", "seed"]),
]


class FormSkenario(forms.ModelForm):
    class Meta:
        model = Skenario
        fields = [f for _, _, fs in BAGIAN for f in fs]
        widgets = {"deskripsi": forms.Textarea(attrs={"rows": 2})}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["versi_data"].queryset = VersiData.objects.filter(
            status__in=[VersiData.Status.SIAP, VersiData.Status.AKTIF])
        if not self.instance.pk:
            self.fields["versi_data"].initial = VersiData.aktif()
            self.fields["set_parameter"].initial = SetParameter.objects.filter(bawaan=True).first()
            self.fields["koef_sektoral"].initial = KoefisienSektoral.objects.filter(bawaan=True).first()
        for f in self.fields.values():
            if isinstance(f.widget, forms.NumberInput):
                f.widget.attrs.setdefault("step", "any")
        inst = self.instance
        dasar = int(self.data.get(self.add_prefix("tahun_dasar")) or inst.tahun_dasar or 2025)
        target = int(self.data.get(self.add_prefix("tahun_target")) or inst.tahun_target or 2029)
        self.tahun = list(range(dasar + 1, max(target, dasar + 1) + 1))[:15]
        for th in self.tahun:
            for kunci, label in (("a1", "Investasi dasar"), ("a2", "Investasi tambahan")):
                awal = (getattr(inst, kunci) or {}).get(str(th))
                self.fields[f"{kunci}_{th}"] = forms.FloatField(
                    label=f"{label} {th}", required=False, initial=awal, min_value=0,
                    widget=forms.NumberInput(attrs={"step": "any", "placeholder": "tren" if kunci == "a1" else "0"}))
        komp = inst.komposisi_a2 or {}
        for k, nama in KELOMPOK:
            self.fields[f"komp_{k}"] = forms.FloatField(
                label=nama, required=False, min_value=0, initial=komp.get(k),
                widget=forms.NumberInput(attrs={"step": "any", "placeholder": "historis"}))
        jalur = inst.jalur or {}
        for kunci, label in JALUR.items():
            for th in self.tahun:
                self.fields[f"jl_{kunci}_{th}"] = forms.FloatField(
                    label=f"{label} {th}", required=False, initial=(jalur.get(kunci) or {}).get(str(th)),
                    widget=forms.NumberInput(attrs={"step": "any", "placeholder": "konstan", "class": "sel-kecil"}))
        kj = list(inst.kejutan or [])
        self.n_kejutan = min(max(len(kj) + 2, 3), MAKS_KEJUTAN)
        for i in range(self.n_kejutan):
            a = kj[i] if i < len(kj) else {}
            self.fields[f"kj{i}_nama"] = forms.CharField(required=False, initial=a.get("nama"), max_length=60,
                                                         widget=forms.TextInput(attrs={"placeholder": "nama shock"}))
            self.fields[f"kj{i}_jenis"] = forms.ChoiceField(required=False, initial=a.get("jenis"),
                                                            choices=[("", "–")] + list(JENIS_KEJUTAN.items()))
            self.fields[f"kj{i}_tahun"] = forms.IntegerField(required=False, initial=a.get("tahun"),
                                                             min_value=1990, max_value=2100)
            self.fields[f"kj{i}_besar"] = forms.FloatField(required=False, initial=a.get("besar"), min_value=-90,
                                                           max_value=200, widget=forms.NumberInput(attrs={"step": "any"}))
            self.fields[f"kj{i}_persistensi"] = forms.FloatField(
                required=False, initial=a.get("persistensi", 1.0), min_value=0, max_value=1,
                widget=forms.NumberInput(attrs={"step": "0.05"}))
            self.fields[f"kj{i}_cakupan"] = forms.ChoiceField(required=False, initial=a.get("cakupan", "nasional"),
                                                              choices=CAKUPAN)
        self._siapkan_determinan(inst)

    def _siapkan_determinan(self, inst):
        self.fields["set_determinan"].empty_label = "Set default"
        dt = inst.determinan or {}
        for p, _ in PILAR:
            d = dt.get(p) or {}
            for k, label, lo, hi in KOLOM_DETERMINAN:
                ph = {"jeda": JEDA_AWAL[p][0], "penuh": JEDA_AWAL[p][1]}.get(k, "0" if k == "dz" else "–")
                self.fields[f"dt_{p}_{k}"] = forms.FloatField(
                    label=label, required=False, initial=d.get(k), min_value=lo, max_value=hi,
                    widget=forms.NumberInput(attrs={"step": "any", "placeholder": ph, "class": "sel-kecil"}))
            self.fields[f"dt_{p}_cakupan"] = forms.ChoiceField(
                required=False, initial=d.get("cakupan", "nasional"), choices=CAKUPAN,
                widget=forms.Select(attrs={"style": "min-width:150px"}))
        sd = inst.set_determinan or SetDeterminan.utama()
        self.indikator_determinan = list(sd.indikator) if sd else []
        for ind in self.indikator_determinan:
            awal = ((dt.get(ind["pilar"]) or {}).get("indikator") or {}).get(ind["kode"])
            self.fields[f"di_{ind['kode']}"] = forms.FloatField(
                required=False, initial=awal, min_value=-3, max_value=3,
                widget=forms.NumberInput(attrs={"step": "any", "placeholder": "pilar", "class": "sel-kecil"}))

    def bagian(self):
        for kode, judul, fs in BAGIAN:
            if kode in ("Investasi", "Jalur & shock"):
                yield kode, judul, None
            elif kode == "Determinan":
                yield kode, judul, [self["set_determinan"]]
            elif kode == "Sektoral":
                yield kode, judul, [self[f] for f in fs] + [self[f"komp_{k}"] for k, _ in KELOMPOK]
            else:
                yield kode, judul, [self[f] for f in fs]

    def baris_investasi(self):
        return [(th, self[f"a1_{th}"], self[f"a2_{th}"]) for th in self.tahun]

    def baris_jalur(self):
        return [(kunci, label, [self[f"jl_{kunci}_{th}"] for th in self.tahun]) for kunci, label in JALUR.items()]

    def baris_determinan(self):
        kol = [k for k, *_ in KOLOM_DETERMINAN] + ["cakupan"]
        return [(p, nama, [self[f"dt_{p}_{k}"] for k in kol]) for p, nama in PILAR]

    def kolom_determinan(self):
        return [label for _, label, *_ in KOLOM_DETERMINAN] + ["Cakupan"]

    def indikator_kolom(self):
        """Kelompok indikator per pilar, dibagi dua kolom dengan jumlah baris seimbang."""
        nama = dict(PILAR)
        grup = [(nama.get(p, p), [(ind, satu_sd(ind)[0], self[f"di_{ind['kode']}"]) for ind in isi])
                for p, isi in per_pilar(self.indikator_determinan).items() if isi]
        total, jalan, kiri = sum(len(g) + 1 for _, g in grup), 0, []
        for g in grup:
            if jalan and jalan + (len(g[1]) + 1) / 2 > total / 2:
                break
            kiri.append(g)
            jalan += len(g[1]) + 1
        return [kiri, grup[len(kiri):]]

    def baris_kejutan(self):
        kol = ("nama", "jenis", "tahun", "besar", "persistensi", "cakupan")
        return [[self[f"kj{i}_{k}"] for k in kol] for i in range(self.n_kejutan)]

    def clean(self):
        d = super().clean()
        if d.get("tahun_dasar") and d.get("tahun_target") and d["tahun_target"] <= d["tahun_dasar"]:
            self.add_error("tahun_target", "Tahun target harus setelah tahun dasar.")
        if d.get("tahun_target") and d.get("tahun_dasar") and d["tahun_target"] - d["tahun_dasar"] > 15:
            self.add_error("tahun_target", "Horizon maksimal 15 tahun.")
        if d.get("hist_awal") and d.get("hist_akhir") and d["hist_akhir"] - d["hist_awal"] < 2:
            self.add_error("hist_akhir", "Jendela historis minimal 3 tahun laju.")
        if d.get("set_parameter") and d["set_parameter"].b1 <= 0:
            self.add_error("set_parameter", "b1 harus positif untuk mode kebutuhan.")
        if d.get("pass_through") is not None and d["pass_through"] <= 0:
            self.add_error("pass_through", "Pass-through harus positif.")
        if d.get("rasio_realisasi") is not None and d["rasio_realisasi"] <= 0:
            self.add_error("rasio_realisasi", "Rasio realisasi harus positif.")
        komp = [d.get(f"komp_{k}") for k, _ in KELOMPOK]
        if any(v is not None for v in komp) and not all(v is not None for v in komp):
            self.add_error("komp_primer", "Isi keempat komposisi atau kosongkan semuanya.")
        for i in range(getattr(self, "n_kejutan", 0)):
            isi = [d.get(f"kj{i}_{k}") for k in ("jenis", "tahun", "besar")]
            if any(isi) and not all(isi):
                self.add_error(f"kj{i}_jenis", "Shock perlu jenis, tahun, dan besar.")
        for th in self.tahun:
            v = d.get(f"jl_faktor_tfp_{th}")
            if v is not None and v < 0:
                self.add_error(f"jl_faktor_tfp_{th}", "Faktor TFP tidak boleh negatif.")
        return d

    def save(self, commit=True):
        sk = super().save(commit=False)
        d = self.cleaned_data
        sk.a1 = {str(th): d[f"a1_{th}"] for th in self.tahun if d.get(f"a1_{th}") is not None}
        sk.a2 = {str(th): d[f"a2_{th}"] for th in self.tahun if d.get(f"a2_{th}") is not None}
        komp = {k: d.get(f"komp_{k}") for k, _ in KELOMPOK}
        sk.komposisi_a2 = komp if all(v is not None for v in komp.values()) and sum(komp.values()) > 0 else None
        sk.jalur = {k: isi for k in JALUR
                    if (isi := {str(th): d[f"jl_{k}_{th}"] for th in self.tahun if d.get(f"jl_{k}_{th}") is not None})}
        sk.kejutan = [{"nama": d.get(f"kj{i}_nama") or "", "jenis": d[f"kj{i}_jenis"], "tahun": d[f"kj{i}_tahun"],
                       "besar": d[f"kj{i}_besar"], "persistensi": 1.0 if d.get(f"kj{i}_persistensi") is None
                       else d[f"kj{i}_persistensi"], "cakupan": d.get(f"kj{i}_cakupan") or "nasional"}
                      for i in range(self.n_kejutan)
                      if d.get(f"kj{i}_jenis") and d.get(f"kj{i}_tahun") and d.get(f"kj{i}_besar")]
        sk.determinan = self._determinan_dari(d)
        if sk.pk and hasattr(sk, "hasil"):
            sk.status = Skenario.Status.USANG
        if commit:
            sk.save()
        return sk

    def _determinan_dari(self, d):
        out = {}
        for p, _ in PILAR:
            isi = {k: d[f"dt_{p}_{k}"] for k, *_ in KOLOM_DETERMINAN if d.get(f"dt_{p}_{k}") is not None}
            ind = {x["kode"]: d[f"di_{x['kode']}"] for x in self.indikator_determinan
                   if x["pilar"] == p and d.get(f"di_{x['kode']}") is not None}
            if ind:
                isi["indikator"] = ind
            if isi:
                if (d.get(f"dt_{p}_cakupan") or "nasional") != "nasional":
                    isi["cakupan"] = d[f"dt_{p}_cakupan"]
                out[p] = isi
        return out


class FormAsumsiProvinsi(forms.Form):
    """Grid provinsi (34, atau 38 bila Papua dirinci) x kolom asumsi."""

    def __init__(self, *args, override=None, kode=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.kode = kode or KODE_PROVINSI
        override = {int(k): v for k, v in (override or {}).items()}
        for kode in self.kode:
            for k, ket, lo, hi in KOLOM_ASUMSI:
                self.fields[f"{kode}_{k}"] = forms.FloatField(
                    required=False, min_value=lo, max_value=hi, initial=override.get(kode, {}).get(k),
                    widget=forms.NumberInput(attrs={"step": "any", "class": "sel-kecil"}))

    def baris(self):
        for kode in self.kode:
            yield kode, NAMA_PROVINSI[kode], [self[f"{kode}_{k}"] for k, *_ in KOLOM_ASUMSI]

    def ke_override(self):
        out = {}
        for kode in self.kode:
            isi = {k: self.cleaned_data[f"{kode}_{k}"] for k, *_ in KOLOM_ASUMSI
                   if self.cleaned_data.get(f"{kode}_{k}") is not None}
            if isi:
                out[str(kode)] = isi
        return out
