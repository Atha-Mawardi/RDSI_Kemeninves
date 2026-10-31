"""Lembar mesin per slot: meniru jalur deterministik simulasi aplikasi dengan rumus Excel.

Tata letak satu lembar:
- baris 6..(5+P): provinsi; kolom D.. konstanta dan hasil per provinsi, lalu blok tahunan (10 kolom per besaran);
- baris 5+P+1: jumlah nasional untuk besaran aditif;
- dari baris R_BAWAH: asumsi slot (A:B), deret tahunan nasional (D:N), ringkasan (P:Q), sektor (S:W),
  indikator determinan (Y:AE).
"""

from . import gaya as G
from .konteks import KEL, MAKS_H, NAMA_PILAR, PROVINSI, SEKTOR
from .skenario import C_SLOT, sel_prov

R0 = 6
C_TAHUN = 5  # kolom h = 1 pada deret tahunan
Z80, Z90 = 0.841621, 1.281552
W_KONST = "{0,1,2,3,4,5,6,7,8,9,10,11}"

SKALAR_SK = ["nama", "singkat", "b1", "b2", "se_b1", "se_b2", "beta_primer", "beta_sekunder", "beta_tva",
             "sasaran", "mode_sasaran", "lambda", "mode_tfp", "tfp_nasional", "faktor_tfp", "mode_tk", "tk_nasional",
             "mode_pmtb", "g_pmtb_nasional", "g_investasi", "inflasi_pmtb", "pass_through", "rasio_realisasi",
             "apbd_persen", "pass_through_apbd", "mode_a2", "skala_a2", "alokasi_a2"] + \
            [f"komp_{k}" for k in KEL] + ["realokasi_pp", "tujuan_realokasi"] + \
            [f"s{i}_{x}" for i in (1, 2) for x in ("jenis", "tahun", "besar", "rho")] + \
            [f"{a}_{p}" for p in NAMA_PILAR for a in ("dp", "dj", "dr")] + ["skala_se", "volatilitas_tfp"]

BLOK = ["It", "Kt", "Dfl", "A1p", "A1r", "apbd", "R", "lnYt", "Breq", "lnAreq", "lnKreq", "Ireq", "tamb", "freq",
        "keb", "A2p", "A2r", "fs", "Bs", "Ks", "lnAs", "lnYs", "Kd", "lnAd", "lnYd"]
JUDUL_BLOK = {
    "It": "Tren PMA+PMDN", "Kt": "PMTB riil tren", "Dfl": "Deflator PMTB", "A1p": "Investasi dasar (rencana)",
    "A1r": "Investasi dasar (realisasi)", "apbd": "Belanja modal APBD tambahan", "R": "Efek realokasi (ln)",
    "lnYt": "ln PDRB sasaran / dasar", "Breq": "Bonus sektoral, jalur sasaran", "lnAreq": "ln TFP, jalur sasaran",
    "lnKreq": "ln PMTB perlu / dasar", "Ireq": "PMA+PMDN dibutuhkan", "tamb": "Tambahan di atas investasi dasar",
    "freq": "Porsi tambahan", "keb": "Kebutuhan tambahan", "A2p": "Investasi tambahan (rencana)",
    "A2r": "Investasi tambahan (realisasi)", "fs": "Porsi investasi tambahan", "Bs": "Bonus sektoral",
    "Ks": "PMTB riil dengan penambahan", "lnAs": "ln TFP dengan penambahan", "lnYs": "ln PDRB dengan penambahan",
    "Kd": "PMTB riil tanpa penambahan", "lnAd": "ln TFP tanpa penambahan", "lnYd": "ln PDRB tanpa penambahan",
}
ADITIF = {"It", "A1p", "A1r", "apbd", "Ireq", "tamb", "keb", "A2p", "A2r", "Ks", "Kd", "Kt"}

KONST = ["Y0", "Yn0", "K0", "Dfl0", "sinv", "mY", "mK", "mL", "n", "cLL", "sres2"] + [f"kh_{g}" for g in KEL] + \
        ["belanja0", "Pp", "pA", "ptuj", "lock", "gs", "tl", "gA", "gL", "gK", "dev"] + [f"ka_{g}" for g in KEL] + \
        ["Dsek", "histA", "histL", "bobot_raw", "bobot"]
HASIL = ["g_dasar", "g_skenario", "g_sasaran", "keb_kum", "keb_pos", "a2_kum", "a2r_kum", "selisih", "YdH", "YsH",
         "YtH", "tfp_dasar", "tfp_skenario", "k_modal", "k_tk", "k_tfp", "k_sektoral", "k_realokasi", "k_determinan",
         "k_kejutan", "bonus_keb", "rasio_keb_pdrb", "fsbar", "d1", "d2", "Vid", "Vc", "sd", "prob", "cK", "e1", "e2",
         "cv"]
JUDUL = {
    "Y0": "PDRB dasar", "Yn0": "PDRB nominal", "K0": "PMTB dasar", "Dfl0": "Deflator", "sinv": "Pangsa investasi",
    "mY": "Laju PDRB hist.", "mK": "Laju PMTB hist.", "mL": "Laju TK hist.", "n": "Tahun", "cLL": "Var laju TK",
    "sres2": "Var residual TFP", "belanja0": "Belanja APBD", "Pp": "Produktivitas", "pA": "Prod. pertanian",
    "ptuj": "Prod. tujuan", "lock": "Sasaran dikunci", "gs": "Sasaran dikunci", "tl": "TFP diisi", "gA": "Laju TFP",
    "gL": "Laju TK", "gK": "Laju PMTB tren", "dev": "Deviasi proporsional", "Dsek": "Bonus per porsi",
    "histA": "TFP historis", "histL": "TK historis", "bobot_raw": "Bobot mentah", "bobot": "Bobot inv. tambahan",
    "g_dasar": "Laju tanpa penambahan %", "g_skenario": "Laju dengan penambahan %", "g_sasaran": "Sasaran %",
    "keb_kum": "Kebutuhan tambahan", "keb_pos": "Kebutuhan positif", "a2_kum": "Inv. tambahan (rencana)",
    "a2r_kum": "Inv. tambahan (realisasi)", "selisih": "Selisih", "YdH": "PDRB T tanpa", "YsH": "PDRB T dengan",
    "YtH": "PDRB T sasaran", "tfp_dasar": "Indeks TFP tanpa", "tfp_skenario": "Indeks TFP dengan",
    "k_modal": "Kontr. modal", "k_tk": "Kontr. TK", "k_tfp": "Kontr. tren TFP", "k_sektoral": "Kontr. sektoral",
    "k_realokasi": "Kontr. realokasi", "k_determinan": "Kontr. determinan", "k_kejutan": "Kontr. shock",
    "bonus_keb": "Bonus jalur sasaran pp", "rasio_keb_pdrb": "Kebutuhan/PDRB %", "fsbar": "Porsi tambahan rata2",
    "d1": "Sensitivitas el. modal", "d2": "Sensitivitas el. TK", "Vid": "Var idiosinkratik",
    "Vc": "Var bersama", "sd": "SD ln PDRB T", "prob": "Confidence", "cK": "Sensitivitas kebutuhan",
    "e1": "Kebutuhan per el. modal", "e2": "Kebutuhan per el. TK", "cv": "Koreksi kecembungan",
}

DERET = ["h", "th", "m", "akar", "Ksas", "kum", "Krata", "target"] + [f"x{i}" for i in range(9)] + \
        ["sh", "gI", "cgI", "fT", "tA", "a1flag", "a1nas", "a2in", "kebnas", "a2nas"] + \
        ["d1", "d2", "kjA", "kjY", "kjL", "kjI"] + [f"w_{p}" for p in NAMA_PILAR] + ["Dt"] + \
        ["Yd", "Ys", "Yt", "gd", "gs", "gt", "inv_tren", "inv_a1", "inv_a1p", "inv_a2", "inv_a2r", "inv_keb",
         "tamb_keb", "apbd_nas", "tfp_d", "tfp_s", "Ys_lo", "Ys_hi"]
JUDUL_DERET = {
    "h": "h", "th": "Tahun", "m": "Dalam horizon", "akar": "Akar h/H", "Ksas": "Sasaran tahunan",
    "kum": "Kumulatif ln sasaran", "Krata": "Laju rata-rata sasaran", "target": "PDRB nasional sasaran",
    "sh": "Porsi realokasi", "gI": "Laju tren PMA+PMDN (ln)", "cgI": "Kumulatif", "fT": "Faktor TFP",
    "tA": "Kumulatif faktor TFP", "a1flag": "Investasi dasar diisi", "a1nas": "Investasi dasar nasional",
    "a2in": "Investasi tambahan diisi", "kebnas": "Kebutuhan tambahan nasional", "a2nas": "Investasi tambahan nasional",
    "d1": "Jalur shock 1", "d2": "Jalur shock 2", "kjA": "Shock TFP", "kjY": "Shock PDRB", "kjL": "Shock TK",
    "kjI": "Faktor realisasi", "Dt": "Efek determinan (ln)", "Yd": "PDRB tanpa penambahan",
    "Ys": "PDRB dengan penambahan", "Yt": "PDRB sasaran", "gd": "Laju tanpa penambahan %",
    "gs": "Laju dengan penambahan %", "gt": "Laju sasaran %", "inv_tren": "Tren PMA+PMDN (T)",
    "inv_a1": "Investasi dasar realisasi (T)", "inv_a1p": "Investasi dasar rencana (T)",
    "inv_a2": "Investasi tambahan rencana (T)", "inv_a2r": "Investasi tambahan realisasi (T)",
    "inv_keb": "PMA+PMDN dibutuhkan (T)", "tamb_keb": "Kebutuhan tambahan (T)", "apbd_nas": "APBD tambahan (T)",
    "tfp_d": "Indeks TFP tanpa", "tfp_s": "Indeks TFP dengan", "Ys_lo": "PDRB dengan, P10", "Ys_hi": "PDRB dengan, P90",
}
for _i in range(9):
    JUDUL_DERET[f"x{_i}"] = f"Geser sasaran, iterasi {_i}"
for _p, _n in NAMA_PILAR.items():
    JUDUL_DERET[f"w_{_p}"] = f"Bobot waktu {_n}"

RINGKAS = ["g_rata_dasar", "g_rata_skenario", "g_rata_sasaran", "a2_kum", "a2r_kum", "keb_kum", "keb_rencana",
           "selisih", "keb_T", "tren_T", "tfp_T_dasar", "tfp_T_skenario", "pdrb_tambahan_T", "k_modal", "k_tk",
           "k_tfp", "k_sektoral", "k_realokasi", "k_determinan", "k_kejutan", "sd_nas", "geser", "prob_nas", "p10", "p90",
           "n_yakin", "keb_p80", "apbd_kum"]
JUDUL_RINGKAS = {
    "g_rata_dasar": "Laju tanpa penambahan investasi (%)", "g_rata_skenario": "Laju dengan penambahan investasi (%)",
    "g_rata_sasaran": "Sasaran (%)", "a2_kum": "Investasi tambahan kumulatif (T)",
    "a2r_kum": "Investasi tambahan terealisasi (T)", "keb_kum": "Kebutuhan tambahan kumulatif (T)",
    "keb_rencana": "Kebutuhan tambahan, rencana (T)", "selisih": "Selisih kebutuhan - realisasi (T)",
    "keb_T": "PMA+PMDN dibutuhkan tahun target (T)", "tren_T": "Tren PMA+PMDN tahun target (T)",
    "tfp_T_dasar": "Indeks TFP tanpa penambahan", "tfp_T_skenario": "Indeks TFP dengan penambahan",
    "pdrb_tambahan_T": "Tambahan PDRB tahun target (T)", "k_modal": "Kontribusi modal (pp)",
    "k_tk": "Kontribusi tenaga kerja (pp)", "k_tfp": "Kontribusi tren TFP (pp)",
    "k_sektoral": "Kontribusi bonus sektoral (pp)", "k_realokasi": "Kontribusi realokasi (pp)",
    "k_determinan": "Kontribusi determinan (pp)", "k_kejutan": "Kontribusi shock (pp)",
    "sd_nas": "SD ln PDRB nasional", "geser": "Geser median ln PDRB nasional", "prob_nas": "Confidence", "p10": "Laju P10 (%)", "p90": "Laju P90 (%)",
    "n_yakin": "Provinsi dengan confidence ≥ 80%", "keb_p80": "Kebutuhan batas aman (T)",
    "apbd_kum": "APBD tambahan kumulatif (T)",
}


class TataMesin:
    def __init__(self, n_prov, n_det):
        self.P = n_prov
        self.r1 = R0 + n_prov - 1
        self.rnas = self.r1 + 1
        self.rb = self.r1 + 5  # baris judul bagian bawah
        self.c = {}
        c = 4
        for k in KONST + HASIL:
            self.c[k] = c
            c += 1
        self.blok = {}
        c += 1
        for k in BLOK:
            self.blok[k] = c
            c += MAKS_H
        self.c_akhir = c - 1
        self.sk = {k: self.rb + 1 + i for i, k in enumerate(SKALAR_SK + TURUNAN)}
        self.dr = {k: self.rb + 2 + i for i, k in enumerate(DERET)}
        self.rr = {k: self.rb + 1 + i for i, k in enumerate(RINGKAS)}
        self.r_sektor = self.rb + 1
        self.r_det = self.rb + 1
        self.n_det = n_det

    # alamat
    def P_(self, k, r):
        return f"${G.kol(self.c[k])}{r}"

    def PR(self, k):
        return f"${G.kol(self.c[k])}${R0}:${G.kol(self.c[k])}${self.r1}"

    def B(self, k, h, r):
        return f"{G.kol(self.blok[k] + h - 1)}{r}"

    def BR(self, k, r):
        """Baris blok (h = 1..MAKS_H) satu provinsi."""
        return f"${G.kol(self.blok[k])}{r}:${G.kol(self.blok[k] + MAKS_H - 1)}{r}"

    def BK(self, k, h):
        """Kolom blok tahun h untuk semua provinsi."""
        L = G.kol(self.blok[k] + h - 1)
        return f"{L}${R0}:{L}${self.r1}"

    def BH(self, k, r):
        """Nilai blok di tahun target untuk provinsi baris r."""
        return f"INDEX({self.BR(k, r)},H_)"

    def S(self, k):
        return f"$B${self.sk[k]}"

    def D(self, k, h):
        return f"{G.kol(C_TAHUN + h - 1)}${self.dr[k]}"

    def DR(self, k):
        return f"${G.kol(C_TAHUN)}${self.dr[k]}:${G.kol(C_TAHUN + MAKS_H - 1)}${self.dr[k]}"

    def DH(self, k):
        return f"INDEX({self.DR(k)},H_)"

    def RG(self, k):
        return f"$Q${self.rr[k]}"


TURUNAN = ["H", "infl", "gI0", "r", "rr", "pt", "pta", "manual", "komp_n", "komp_sum", "tAH"] + \
          [f"{a}_{p}" for p in NAMA_PILAR for a in ("L", "R", "E", "V")] + \
          [f"s{i}_{x}" for i in (1, 2) for x in ("h0", "ok")]


def lembar_mesin(wb, ctx, s, rk, H_):
    """Satu lembar mesin untuk slot s (0-based). rk: baris Skenario. H_: TataHitung."""
    sl = ctx.slot[s]
    ws = wb.create_sheet(sl.sheet)
    G.warna_tab(ws, G.NAVY)
    T = TataMesin(len(ctx.kode), len(ctx.det))
    L = G.kol(C_SLOT + s)
    sk = lambda k: f"Skenario!${L}${rk[k]}"  # noqa: E731
    G.tulis(ws, 1, 1, f"=\"Mesin: \"&{sk('nama')}", font=G.T_JUDUL)
    G.tulis(ws, 2, 1, "Rumus meniru jalur deterministik aplikasi. Jangan disunting; ubah asumsi di lembar Skenario "
                      "dan AsumsiProv.", font=G.T_SUBJUDUL)
    ws.sheet_view.showGridLines = False

    # ---------------- asumsi slot (A:B)
    G.bagian(ws, T.rb, 1, 2, "Asumsi slot")
    for k in SKALAR_SK:
        r = T.sk[k]
        G.tulis(ws, r, 1, k, font=G.T_KECIL)
        kunci = {"lambda": "lambda"}.get(k, k)
        G.tulis(ws, r, 2, f'=IF({sk(kunci)}="","",{sk(kunci)})', fill=G.F_RUMUS)
    S = T.S
    tur = {
        "H": "=H_",
        "infl": f'=IF({S("inflasi_pmtb")}="",INFL_HIST,LN(1+{S("inflasi_pmtb")}/100))',
        "gI0": f'=IF({S("g_investasi")}="",GI_HIST,LN(1+{S("g_investasi")}/100))',
        "r": f"=N({S('rasio_realisasi')})",
        "rr": f"=MAX({S('r')},0.000001)",
        "pt": f"=N({S('pass_through')})",
        "pta": f"=N({S('pass_through_apbd')})",
        "manual": f'=IF({S("mode_sasaran")}="manual",1,0)',
        "komp_n": f"=COUNT({','.join(S(f'komp_{g}') for g in KEL)})",
        "komp_sum": "=" + "+".join(f"MAX(N({S(f'komp_{g}')}),0)" for g in KEL),
        "tAH": f"={T.DH('tA')}",
    }
    for p in NAMA_PILAR:
        tur[f"L_{p}"] = f'=IF({S("dj_" + p)}="",INDEX(EJ_jeda,MATCH("{p}",EJ_pilar,0)),MAX(INT({S("dj_" + p)}),0))'
        tur[f"R_{p}"] = f'=IF({S("dr_" + p)}="",INDEX(EJ_penuh,MATCH("{p}",EJ_pilar,0)),MAX(INT({S("dr_" + p)}),1))'
    for i in (1, 2):
        tur[f"s{i}_h0"] = f"=MAX(N({S(f's{i}_tahun')})-(TD+1),0)"
        tur[f"s{i}_ok"] = (f'=IF(AND({S(f"s{i}_jenis")}<>"",N({S(f"s{i}_besar")})<>0,N({S(f"s{i}_tahun")})>0,'
                           f'N({S(f"s{i}_tahun")})<=TD+H_),1,0)')

    # indikator determinan (Y:AE)
    cd = 25
    G.bagian(ws, T.rb, cd, cd + 6, "Indikator determinan")
    G.header(ws, T.rb + 1, cd, ["Kode", "Pilar", "Koefisien", "SE", "Perubahan (SD)", "Efek", "Var"])
    rd0 = T.rb + 2
    for j, ind in enumerate(ctx.det):
        r = rd0 + j
        di = f"Skenario!${L}${rk['di_' + ind['kode']]}"
        G.tulis(ws, r, cd, f"=INDEX(ED_kode,{j + 1})", font=G.T_KECIL)
        G.tulis(ws, r, cd + 1, f"=INDEX(ED_pilar,{j + 1})", font=G.T_KECIL)
        G.tulis(ws, r, cd + 2, f"=INDEX(ED_koef,{j + 1})", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.tulis(ws, r, cd + 3, f"=INDEX(ED_se,{j + 1})", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.tulis(ws, r, cd + 4, f'=IF({di}="",N({S("dp_" + ind["pilar"])}),{di})', fill=G.F_RUMUS, fmt=G.FMT_P)
        c = lambda k: f"{G.kol(cd + k)}{r}"  # noqa: E731
        G.tulis(ws, r, cd + 5, f"={c(2)}*{c(4)}", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.tulis(ws, r, cd + 6, f"=({c(3)}*{c(4)})^2", fill=G.F_RUMUS, fmt="0.000000")
    rd1 = rd0 + len(ctx.det) - 1
    pil = f"${G.kol(cd + 1)}${rd0}:${G.kol(cd + 1)}${rd1}"
    for p in NAMA_PILAR:
        tur[f"E_{p}"] = f'=SUMIF({pil},"{p}",${G.kol(cd + 5)}${rd0}:${G.kol(cd + 5)}${rd1})'
        tur[f"V_{p}"] = f'=SUMIF({pil},"{p}",${G.kol(cd + 6)}${rd0}:${G.kol(cd + 6)}${rd1})'
    for k in TURUNAN:
        r = T.sk[k]
        G.tulis(ws, r, 1, k, font=G.T_KECIL)
        G.tulis(ws, r, 2, tur[k], fill=G.F_RUMUS)

    # ---------------- konstanta provinsi
    G.header(ws, 5, 1, ["Kode", "Provinsi", "Pulau"] + [JUDUL.get(k, k) for k in KONST + HASIL], tinggi=42)
    for k in BLOK:
        G.gabung(ws, 4, T.blok[k], T.blok[k] + MAKS_H - 1, JUDUL_BLOK[k], font=G.T_HEADER, fill=G.F_SUB,
                 align=G.TENGAH)
        for h in range(1, MAKS_H + 1):
            G.tulis(ws, 5, T.blok[k] + h - 1, f"=TD+{h}", font=G.T_HEADER, fill=G.F_HEADER, align=G.TENGAH)
    P_, B, D = T.P_, T.B, T.D
    beta = {g: S(f"beta_{g}") for g in KEL[:3]}
    for i, (kd, nm, pl) in enumerate(PROVINSI(ctx.kode)):
        r = R0 + i
        for c, v in enumerate((kd, nm, pl), 1):
            ws.cell(row=r, column=c, value=v)
        hp = lambda k: H_.sel(k, i)  # noqa: E731
        ap = lambda k: sel_prov(s, k, i)  # noqa: E731
        f = {
            "Y0": f"={hp('Y0')}", "Yn0": f"={hp('Yn0')}", "K0": f"={hp('K0')}", "Dfl0": f"={hp('Dfl0')}",
            "sinv": f"={hp('sinv')}", "mY": f"={hp('mY')}", "mK": f"={hp('mK')}", "mL": f"={hp('mL')}",
            "n": f"={hp('n')}", "cLL": f"={hp('cLL')}",
            "sres2": (f"=MAX({hp('cYY')}+{S('b1')}^2*{hp('cKK')}+{S('b2')}^2*{hp('cLL')}-2*{S('b1')}*{hp('cYK')}"
                      f"-2*{S('b2')}*{hp('cYL')}+2*{S('b1')}*{S('b2')}*{hp('cKL')},0)"),
            "belanja0": f"={hp('belanja0')}", "Pp": f"={hp('Pp')}", "pA": f"={hp('pA')}",
            "ptuj": f'=IF({S("tujuan_realokasi")}="tva",{hp("ptva")},{hp("pC")})',
            "lock": f'=IF({ap("sasaran")}="",0,1)',
            "gs": f"=N({ap('sasaran')})/100",
            "tl": f'=IF({ap("tfp")}="",0,1)',
            "gA": (f'=IF({P_("tl", r)}=1,LN(1+N({ap("tfp")})/100),IF({S("mode_tfp")}="nasional",'
                   f'LN(1+{S("tfp_nasional")}/100),{P_("mY", r)}-{S("b1")}*{P_("mK", r)}-{S("b2")}*{P_("mL", r)})'
                   f'*{S("faktor_tfp")})'),
            "gL": (f'=IF({ap("tk")}<>"",LN(1+{ap("tk")}/100),IF({S("mode_tk")}="nasional",'
                   f'LN(1+{S("tk_nasional")}/100),{P_("mL", r)}))'),
            "gK": (f'=IF({S("mode_pmtb")}="nasional",IF({S("g_pmtb_nasional")}="",GK_HIST,'
                   f'LN(1+{S("g_pmtb_nasional")}/100)),{P_("mK", r)})'),
            "dev": (f'=IF({S("mode_sasaran")}="proporsional",(EXP({P_("mY", r)})-EXP(GY_HIST))*N({S("lambda")}),'
                    f'0)'),
            "histA": f'=IF(AND({S("mode_tfp")}<>"nasional",{P_("tl", r)}=0),1,0)',
            "histL": f'=IF(AND({S("mode_tk")}<>"nasional",{ap("tk")}=""),1,0)',
        }
        for g in KEL:
            f[f"kh_{g}"] = f"={hp(f'kh_{g}')}"
            f[f"ka_{g}"] = (f"=IF({S('komp_n')}=0,{P_(f'kh_{g}', r)},"
                            f"MAX(N({S(f'komp_{g}')}),0)/{S('komp_sum')})")
        f["Dsek"] = "=" + "+".join(f"{beta[g]}*({P_(f'ka_{g}', r)}-{P_(f'kh_{g}', r)})" for g in KEL[:3])
        mask = T.DR("m")
        f["bobot_raw"] = (f'=IF({S("alokasi_a2")}="pdrb",{P_("Y0", r)},IF({S("alokasi_a2")}="investasi",'
                          f'{P_("sinv", r)},IF({S("alokasi_a2")}="manual",N({ap("bobot")}),'
                          f'MAX(SUMPRODUCT({T.BR("keb", r)},{mask}),0))))')
        f["bobot"] = (f"=IF(SUM({T.PR('bobot_raw')})<=0,{P_('Y0', r)}/SUM({T.PR('Y0')}),"
                      f"{P_('bobot_raw', r)}/SUM({T.PR('bobot_raw')}))")
        # hasil
        BH = lambda k: T.BH(k, r)  # noqa: E731
        f.update({
            "g_dasar": f"=(EXP({BH('lnYd')}/H_)-1)*100",
            "g_skenario": f"=(EXP({BH('lnYs')}/H_)-1)*100",
            "g_sasaran": f"=(EXP({BH('lnYt')}/H_)-1)*100",
            "keb_kum": f"=SUMPRODUCT({T.BR('keb', r)},{mask})",
            "keb_pos": f"=SUMPRODUCT(({T.BR('keb', r)}>0)*{T.BR('keb', r)},{mask})",
            "a2_kum": f"=SUMPRODUCT({T.BR('A2p', r)},{mask})",
            "a2r_kum": f"=SUMPRODUCT({T.BR('A2r', r)},{mask})",
            "selisih": f"={P_('keb_kum', r)}-{P_('a2r_kum', r)}",
            "YdH": f"={P_('Y0', r)}*EXP({BH('lnYd')})",
            "YsH": f"={P_('Y0', r)}*EXP({BH('lnYs')})",
            "YtH": f"={P_('Y0', r)}*EXP({BH('lnYt')})",
            "tfp_dasar": f"=100*EXP({BH('lnAd')})",
            "tfp_skenario": f"=100*EXP({BH('lnAs')})",
            "k_modal": f"={S('b1')}*LN({BH('Ks')}/{P_('K0', r)})/H_*100",
            "k_tk": f"={S('b2')}*{P_('gL', r)}*100",
            "k_tfp": f"={P_('gA', r)}*{S('tAH')}/H_*100",
            "k_sektoral": f"={BH('Bs')}/H_*100",
            "k_realokasi": f"={BH('R')}/H_*100",
            "k_determinan": f"={T.DH('Dt')}/H_*100",
            "k_kejutan": f"=({T.DH('kjA')}+{T.DH('kjY')}+{S('b2')}*{T.DH('kjL')})/H_*100",
            "bonus_keb": f"=({BH('Breq')}+{BH('R')}+{T.DH('Dt')})/H_*100",
            "rasio_keb_pdrb": f"={P_('keb_kum', r)}/H_/{P_('Yn0', r)}*100",
            "fsbar": f"=SUMPRODUCT({T.BR('fs', r)},{mask})/H_",
            "d1": (f"=LN({BH('Ks')}/{P_('K0', r)})-{P_('histA', r)}*{P_('mK', r)}*{S('faktor_tfp')}*{S('tAH')}"),
            "d2": (f"=({P_('gL', r)}*H_+{T.DH('kjL')})-{P_('histA', r)}*{P_('mL', r)}*{S('faktor_tfp')}"
                   f"*{S('tAH')}"),
            "Vid": (f"=({P_('histA', r)}*{S('tAH')}^2*{P_('sres2', r)}/{P_('n', r)}"
                    f"+{P_('histL', r)}*({S('b2')}*H_)^2*{P_('cLL', r)}/{P_('n', r)})*{S('skala_se')}^2"
                    f"+H_*{P_('sres2', r)}*{S('volatilitas_tfp')}^2"),
            "Vc": (f"=({P_('d1', r)}*{S('se_b1')})^2*{S('skala_se')}^2+({P_('d2', r)}*{S('se_b2')})^2"
                   f"*{S('skala_se')}^2+VDET_{s}"),
            "sd": f"=SQRT({P_('Vid', r)}+{P_('Vc', r)})",
            "prob": f"=IF({P_('sd', r)}>0,1-NORMSDIST(({BH('lnYt')}-{BH('lnYs')})/{P_('sd', r)}),"
                    f"IF({BH('lnYs')}>={BH('lnYt')}-1E-9,1,0))",
            "cK": (f"=SUMPRODUCT(EXP({T.BR('lnKreq', r)})*{T.BR('Dfl', r)},{mask},{T.DR('akar')})*{P_('K0', r)}"
                   f"/(MAX({S('pt')},0.000001)*{S('b1')})"),
            "e1": (f"=SUMPRODUCT(EXP({T.BR('lnKreq', r)})*{T.BR('Dfl', r)}*({P_('histA', r)}*{P_('mK', r)}"
                   f"*{S('faktor_tfp')}*{T.DR('tA')}-{T.BR('lnKreq', r)}),{mask})*{P_('K0', r)}"
                   f"/(MAX({S('pt')},0.000001)*{S('b1')})"),
            "e2": (f"=SUMPRODUCT(EXP({T.BR('lnKreq', r)})*{T.BR('Dfl', r)}*({P_('histA', r)}*{P_('mL', r)}"
                   f"*{S('faktor_tfp')}*{T.DR('tA')}-({P_('gL', r)}*{T.DR('h')}+{T.DR('kjL')})),{mask})*{P_('K0', r)}"
                   f"/(MAX({S('pt')},0.000001)*{S('b1')})"),
            "cv": (f"=0.5*SUMPRODUCT(EXP({T.BR('lnKreq', r)})*{T.BR('Dfl', r)},{mask},{T.DR('akar')},{T.DR('akar')})"
                   f"*{P_('K0', r)}/MAX({S('pt')},0.000001)*({P_('Vid', r)}+{P_('Vc', r)})/{S('b1')}^2"),
        })
        for k, v in f.items():
            G.tulis(ws, r, T.c[k], v, fill=G.F_RUMUS)

        # blok tahunan
        for h in range(1, MAKS_H + 1):
            b = lambda k, hh=h: B(k, hh, r)  # noqa: E731
            d = lambda k, hh=h: D(k, hh)  # noqa: E731
            p = lambda k: P_(k, r)  # noqa: E731
            lnA_umum = f"{p('gA')}*{d('tA')}+{b('R')}+{d('kjA')}+{d('Dt')}"
            tk_umum = f"{S('b2')}*({p('gL')}*{h}+{d('kjL')})+{d('kjY')}"
            v = {
                "It": f"={p('sinv')}*INAS0*EXP({d('cgI')})",
                "Kt": f"={p('K0')}*EXP({p('gK')}*{h})",
                "Dfl": f"={p('Dfl0')}*EXP({S('infl')}*{h})",
                "A1p": f"=IF({d('a1flag')}=1,{d('a1nas')}*{p('sinv')},{b('It')})",
                "A1r": f"=IF({d('a1flag')}=1,{b('A1p')}*{S('r')},{b('It')})*{d('kjI')}",
                "apbd": f"=N({S('apbd_persen')})/100*{p('belanja0')}*EXP({S('infl')}*{h})",
                "R": f"=LN(MAX(({p('Pp')}+{d('sh')}*({p('ptuj')}-{p('pA')}))/{p('Pp')},0.000001))",
                "lnYt": (f"=IF({S('manual')}=1,IF({p('lock')}=1,LN(1+{p('gs')})*{h},{d('kum')}),"
                         f"LN(1+IF({p('lock')}=1,{p('gs')},MAX({d('Krata')}+{p('dev')}+{d('x8')},-0.9)))*{h})"),
                "Breq": "=0" if h == 1 else f"={B('Breq', h - 1, r)}+{B('freq', h - 1, r)}*{p('Dsek')}",
                "lnAreq": f"={lnA_umum}+{b('Breq')}",
                "lnKreq": f"=({b('lnYt')}-{b('lnAreq')}-({tk_umum}))/{S('b1')}",
                "Ireq": (f"={b('It')}+({p('K0')}*EXP({b('lnKreq')})*{b('Dfl')}-{b('Kt')}*{b('Dfl')}"
                         f"-{S('pta')}*{b('apbd')})/MAX({S('pt')},0.000001)"),
                "tamb": f"=MAX({b('Ireq')}-{b('A1r')},0)",
                "freq": f"=IF({b('A1r')}+{b('tamb')}>0,{b('tamb')}/({b('A1r')}+{b('tamb')}),0)",
                "keb": f"={b('Ireq')}-{b('A1r')}",
                "A2p": f"={p('bobot')}*{d('a2nas')}",
                "A2r": f"={b('A2p')}*{S('r')}*{d('kjI')}",
                "fs": f"=IF({b('A1r')}+{b('A2r')}>0,{b('A2r')}/({b('A1r')}+{b('A2r')}),0)",
                "Bs": "=0" if h == 1 else f"={B('Bs', h - 1, r)}+{B('fs', h - 1, r)}*{p('Dsek')}",
                "Ks": (f"=MAX({b('Kt')}+({S('pt')}*({b('A1r')}+{b('A2r')}-{b('It')})+{S('pta')}*{b('apbd')})"
                       f"/{b('Dfl')},0.05*{b('Kt')})"),
                "lnAs": f"={lnA_umum}+{b('Bs')}",
                "lnYs": f"={b('lnAs')}+{S('b1')}*LN({b('Ks')}/{p('K0')})+{tk_umum}",
                "Kd": f"=MAX({b('Kt')}+{S('pt')}*({b('A1r')}-{b('It')})/{b('Dfl')},0.05*{b('Kt')})",
                "lnAd": f"={p('gA')}*{d('tA')}+{d('kjA')}",
                "lnYd": f"={b('lnAd')}+{S('b1')}*LN({b('Kd')}/{p('K0')})+{tk_umum}",
            }
            for k, x in v.items():
                ws.cell(row=r, column=T.blok[k] + h - 1, value=x)

    # baris nasional
    G.tulis(ws, T.rnas, 2, "Nasional", font=G.T_TEBAL)
    for k in ("Y0", "K0", "keb_kum", "keb_pos", "a2_kum", "a2r_kum", "selisih", "YdH", "YsH", "YtH", "bobot_raw",
              "bobot"):
        G.tulis(ws, T.rnas, T.c[k], f"=SUM({T.PR(k)})", font=G.T_TEBAL, fmt=G.FMT_T)
    for k in ADITIF:
        for h in range(1, MAKS_H + 1):
            G.tulis(ws, T.rnas, T.blok[k] + h - 1, f"=SUM({T.BK(k, h)})", font=G.T_TEBAL, fmt=G.FMT_T)
    for k in KONST + HASIL:
        for r in range(R0, T.r1 + 1):
            ws.cell(row=r, column=T.c[k]).number_format = G.FMT_T if k in ("Y0", "Yn0", "K0", "belanja0") else \
                (G.FMT_P if k.startswith(("g_", "k_")) else G.FMT_4)

    # ---------------- deret tahunan (D:N)
    G.bagian(ws, T.rb, 4, C_TAHUN + MAKS_H - 1, "Deret tahunan nasional")
    for h in range(1, MAKS_H + 1):
        G.tulis(ws, T.rb + 1, C_TAHUN + h - 1, f"=TD+{h}", font=G.T_HEADER, fill=G.F_HEADER, align=G.TENGAH)
    G.tulis(ws, T.rb + 1, 4, "Besaran", font=G.T_HEADER, fill=G.F_HEADER)
    Y0R = T.PR("Y0")
    LK, GS, DEV = T.PR("lock"), T.PR("gs"), T.PR("dev")
    for k in DERET:
        r = T.dr[k]
        G.tulis(ws, r, 4, JUDUL_DERET.get(k, k), font=G.T_KECIL)
        for h in range(1, MAKS_H + 1):
            d = lambda kk, hh=h: D(kk, hh)  # noqa: E731
            dp = lambda kk, hh=h: D(kk, hh - 1)  # noqa: E731
            jalur = lambda nm, hh=h: f"Skenario!${L}${rk[f'j_{nm}_{hh}']}"  # noqa: E731
            m = d("m")
            na = lambda isi: f"=IF({m}=1,{isi},NA())"  # noqa: E731
            if k == "h":
                v = h
            elif k == "th":
                v = f"=TD+{h}"
            elif k == "m":
                v = f"=IF({h}<=H_,1,0)"
            elif k == "akar":
                v = f"=SQRT(MIN({h}/H_,1))"
            elif k == "Ksas":
                v = f'=IF({jalur("sasaran")}="",N({S("sasaran")}),{jalur("sasaran")})/100'
            elif k == "kum":
                v = f"=LN(1+{d('Ksas')})" + ("" if h == 1 else f"+{dp('kum')}")
            elif k == "Krata":
                v = f"=EXP({d('kum')}/{h})-1"
            elif k == "target":
                v = f"=YNAS0*EXP({d('kum')})"
            elif k == "x0":
                v = 0
            elif k.startswith("x"):
                x = D(f"x{int(k[1:]) - 1}", h)
                a = f"({d('Krata')}+{DEV}+{x})"
                lj = f"({LK}*{GS}+(1-{LK})*({a}-0.9+ABS({a}+0.9))/2)"
                fx = f"SUMPRODUCT({Y0R},(1+{lj})^{h})-{d('target')}"
                fp = f"SUMPRODUCT({Y0R}*(1-{LK})*({a}>-0.9)*{h}*(1+{lj})^({h}-1))"
                v = f"={x}-IFERROR(({fx})/({fp}),0)"
            elif k == "sh":
                v = f"=N({S('realokasi_pp')})/100*{h}/H_"
            elif k == "gI":
                v = f'=IF({jalur("g_investasi")}="",{S("gI0")},LN(1+{jalur("g_investasi")}/100))'
            elif k == "cgI":
                v = f"={d('gI')}" + ("" if h == 1 else f"+{dp('cgI')}")
            elif k == "fT":
                v = f'=IF({jalur("faktor_tfp")}="",1,{jalur("faktor_tfp")})'
            elif k == "tA":
                v = f"={d('fT')}" + ("" if h == 1 else f"+{dp('tA')}")
            elif k == "a1flag":
                v = f'=IF(Skenario!${L}${rk[f"a1_{h}"]}="",0,1)'
            elif k == "a1nas":
                v = f"=N(Skenario!${L}${rk[f'a1_{h}']})*1000"
            elif k == "a2in":
                v = f"=N(Skenario!${L}${rk[f'a2_{h}']})*1000"
            elif k == "kebnas":
                v = f"={B('keb', h, T.rnas)}"
            elif k == "a2nas":
                v = (f'=IF({S("mode_a2")}="kebutuhan x skala",N({S("skala_a2")})*MAX({d("kebnas")},0)/{S("rr")},'
                     f'{d("a2in")})*{m}')
            elif k in ("d1", "d2"):
                i = k[1]
                ok, h0 = S(f"s{i}_ok"), S(f"s{i}_h0")
                rho = f"MIN(MAX(N({S(f's{i}_rho')}),0),1)"
                v = (f"=IF(AND({ok}=1,{h - 1}>={h0}),LN(1+MAX(N({S(f's{i}_besar')})/100*"
                     f"IF({h - 1}-{h0}=0,1,{rho}^({h - 1}-{h0})),-0.95)),0)")
            elif k in ("kjA", "kjY", "kjL", "kjI"):
                lb = {"kjA": "TFP (level)", "kjY": "PDRB langsung", "kjL": "Tenaga kerja",
                      "kjI": "Realisasi PMA+PMDN"}[k]
                isi = "+".join(f'({S(f"s{i}_jenis")}="{lb}")*{d(f"d{i}")}' for i in (1, 2))
                v = f"=EXP({isi})" if k == "kjI" else f"={isi}"
            elif k.startswith("w_"):
                p = k[2:]
                Lp, Rp = S(f"L_{p}"), S(f"R_{p}")
                sft = f"({h}-{Lp}-{W_KONST})"
                v = f"=SUMPRODUCT(({W_KONST}<{Rp})*(ABS({sft})-ABS({sft}-H_)+H_))/(2*H_*{Rp})"
            elif k == "Dt":
                v = "=" + "+".join(f"{S(f'E_{p}')}*{d(f'w_{p}')}" for p in NAMA_PILAR)
            elif k in ("Yd", "Ys", "Yt"):
                v = na(f"SUMPRODUCT({Y0R},EXP({T.BK({'Yd': 'lnYd', 'Ys': 'lnYs', 'Yt': 'lnYt'}[k], h)}))")
            elif k in ("gd", "gs", "gt"):
                y = {"gd": "Yd", "gs": "Ys", "gt": "Yt"}[k]
                prev = "YNAS0" if h == 1 else dp(y)
                v = na(f"({d(y)}/{prev}-1)*100")
            elif k.startswith(("inv_", "tamb_", "apbd_")):
                src = {"inv_tren": "It", "inv_a1": "A1r", "inv_a1p": "A1p", "inv_a2r": "A2r", "inv_keb": "Ireq",
                       "tamb_keb": "keb", "apbd_nas": "apbd"}
                v = na(f"{d('a2nas')}/1000") if k == "inv_a2" else na(f"{B(src[k], h, T.rnas)}/1000")
            elif k in ("tfp_d", "tfp_s"):
                src = "lnAd" if k == "tfp_d" else "lnAs"
                v = na(f"100*EXP(SUMPRODUCT({Y0R},{T.BK(src, h)})/YNAS0)")
            elif k in ("Ys_lo", "Ys_hi"):
                sg = "-" if k == "Ys_lo" else ""
                v = na(f"{d('Ys')}*EXP({sg}{Z90}*{T.RG('sd_nas')}*{d('akar')})")
            ws.cell(row=r, column=C_TAHUN + h - 1, value=v)

    # ---------------- ringkasan (P:Q)
    G.bagian(ws, T.rb, 16, 17, "Ringkasan nasional")
    w = f"{Y0R}/YNAS0"
    sdk = S("skala_se")
    Q = T.RG
    om = f"{T.PR('YsH')}/SUM({T.PR('YsH')})"
    rumus = {
        "g_rata_dasar": f"=(({T.DH('Yd')}/YNAS0)^(1/H_)-1)*100",
        "g_rata_skenario": f"=(({T.DH('Ys')}/YNAS0)^(1/H_)-1)*100",
        "g_rata_sasaran": f"=(({T.DH('Yt')}/YNAS0)^(1/H_)-1)*100",
        "a2_kum": f"=SUM({T.DR('a2nas')})/1000",
        "a2r_kum": f"={P_('a2r_kum', T.rnas)}/1000",
        "keb_kum": f"={P_('keb_kum', T.rnas)}/1000",
        "keb_rencana": f"={Q('keb_kum')}/{S('rr')}",
        "selisih": f"={Q('keb_kum')}-{Q('a2r_kum')}",
        "keb_T": f"={T.BH('Ireq', T.rnas)}/1000",
        "tren_T": f"={T.BH('It', T.rnas)}/1000",
        "tfp_T_dasar": f"={T.DH('tfp_d')}",
        "tfp_T_skenario": f"={T.DH('tfp_s')}",
        "pdrb_tambahan_T": f"=({T.DH('Ys')}-{T.DH('Yd')})/1000",
        "sd_nas": (f"=SQRT(SUMPRODUCT(({om})^2,{T.PR('Vid')})+(SUMPRODUCT({om},{T.PR('d1')})*{S('se_b1')}*{sdk})^2"
                   f"+(SUMPRODUCT({om},{T.PR('d2')})*{S('se_b2')}*{sdk})^2+VDET_{s})"),
        "geser": f"=0.5*(SUMPRODUCT({om},{T.PR('Vid')}+{T.PR('Vc')})-{Q('sd_nas')}^2)",
        "prob_nas": (f"=IF({Q('sd_nas')}>0,1-NORMSDIST((LN({T.DH('Yt')}/{T.DH('Ys')})-{Q('geser')})/{Q('sd_nas')}),"
                     f"IF({T.DH('Ys')}>={T.DH('Yt')},1,0))"),
        "p10": f"=(({T.DH('Ys')}*EXP({Q('geser')}-{Z90}*{Q('sd_nas')})/YNAS0)^(1/H_)-1)*100",
        "p90": f"=(({T.DH('Ys')}*EXP({Q('geser')}+{Z90}*{Q('sd_nas')})/YNAS0)^(1/H_)-1)*100",
        "n_yakin": f'=COUNTIF({T.PR("prob")},">=0.8")',
        "keb_p80": (f"={Q('keb_kum')}+SUM({T.PR('cv')})/1000+{Z80}*SQRT(SUMPRODUCT({T.PR('cK')}^2,{T.PR('Vid')})"
                    f"+(SUM({T.PR('e1')})*{S('se_b1')}*{sdk})^2+(SUM({T.PR('e2')})*{S('se_b2')}*{sdk})^2"
                    f"+SUM({T.PR('cK')})^2*VDET_{s})/1000"),
        "apbd_kum": f"=SUMPRODUCT({T.BR('apbd', T.rnas)},{T.DR('m')})/1000",
    }
    for k in ("modal", "tk", "tfp", "sektoral", "realokasi", "determinan", "kejutan"):
        rumus[f"k_{k}"] = f"=SUMPRODUCT({w},{T.PR('k_' + k)})"
    for k in RINGKAS:
        r = T.rr[k]
        G.tulis(ws, r, 16, JUDUL_RINGKAS[k], font=G.T_BIASA)
        fmt = G.FMT_PCT1 if k == "prob_nas" else ("0" if k == "n_yakin" else (G.FMT_T if "kum" in k or k in (
            "selisih", "keb_T", "tren_T", "keb_rencana", "pdrb_tambahan_T", "keb_p80") else G.FMT_P))
        G.tulis(ws, r, 17, rumus[k], fill=G.F_RUMUS, fmt=fmt)
    # varian determinan (bersama, nasional)
    vdet = "+".join(f"{S(f'V_{p}')}*{T.DH(f'w_{p}')}^2" for p in NAMA_PILAR)
    r = T.rr[RINGKAS[-1]] + 1
    G.tulis(ws, r, 16, "Varian efek determinan", font=G.T_KECIL)
    G.tulis(ws, r, 17, f"=({vdet})*{sdk}^2", fill=G.F_RUMUS, fmt="0.000000")
    G.nama(wb, f"VDET_{s}", sl.sheet, f"$Q${r}")

    # ---------------- sektor (S:W)
    cs = 19
    G.bagian(ws, T.rb, cs, cs + 3, "Arah sektor (T)")
    G.header(ws, T.rb + 1, cs, ["Sektor", "Kelompok", "Kebutuhan", "Inv. tambahan"])
    for j, (kode_s, _, kel) in enumerate(SEKTOR):
        r = T.rb + 2 + j
        G.tulis(ws, r, cs, kode_s)
        G.tulis(ws, r, cs + 1, kel, font=G.T_KECIL)
        ks = f"HP_ks_{kode_s}"
        G.tulis(ws, r, cs + 2, f"=SUMPRODUCT({T.PR('keb_pos')},{T.PR('ka_' + kel)},{ks})/1000", fill=G.F_RUMUS,
                fmt=G.FMT_T1)
        G.tulis(ws, r, cs + 3, f"=SUMPRODUCT({T.PR('a2r_kum')},{T.PR('ka_' + kel)},{ks})/1000", fill=G.F_RUMUS,
                fmt=G.FMT_T1)
    rk0 = T.rb + 3 + len(SEKTOR)
    G.header(ws, rk0, cs, ["Kelompok", "Pangsa historis", "Pangsa inv. tambahan", "Bonus pp"])
    for j, g in enumerate(KEL):
        r = rk0 + 1 + j
        bt = beta[g] if g in beta else "0"
        G.tulis(ws, r, cs, g)
        G.tulis(ws, r, cs + 1, f"=KHS_{g}", fill=G.F_RUMUS, fmt=G.FMT_PCT1)
        G.tulis(ws, r, cs + 2, f"=SUMPRODUCT({T.PR('ka_' + g)},{T.PR('bobot')})", fill=G.F_RUMUS, fmt=G.FMT_PCT1)
        G.tulis(ws, r, cs + 3, f"=SUMPRODUCT({w},{T.PR('ka_' + g)}-{T.PR('kh_' + g)},{T.PR('fsbar')})*{bt}*100",
                fill=G.F_RUMUS, fmt=G.FMT_4)

    G.lebar(ws, [7, 22, 12] + [11] * (len(KONST) + len(HASIL)))
    ws.column_dimensions["A"].width = 16
    ws.column_dimensions["B"].width = 14
    ws.column_dimensions["D"].width = 26
    ws.column_dimensions["P"].width = 34
    for k in BLOK:
        for h in range(MAKS_H):
            ws.column_dimensions[G.kol(T.blok[k] + h)].width = 10
    ws.freeze_panes = "D6"
    ws.sheet_state = "visible"
    return ws, T
