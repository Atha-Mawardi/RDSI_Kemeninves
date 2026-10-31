"""Lembar Hitung: besaran dasar per provinsi dan nasional (dari Data) dan kumpulan hasil semua slot."""

from . import gaya as G
from .konteks import KEL, PROVINSI, SEKTOR

R0 = 6  # baris provinsi pertama
NUM = '">-1E+300"'  # kriteria COUNTIFS: hanya sel berangka
TH_AWAL, TH_AKHIR = 2000, 2040


class TataHitung:
    def __init__(self, n_prov):
        self.n = n_prov
        self.r1 = R0 + n_prov - 1
        self.c = {}
        self._n = 4

    def tambah(self, k):
        self.c[k] = self._n
        self._n += 1

    def sel(self, k, i):
        """Sel provinsi ke-i (0-based), alamat lintas lembar."""
        return f"Hitung!${G.kol(self.c[k])}${R0 + i}"

    def rentang(self, k):
        return f"Hitung!${G.kol(self.c[k])}${R0}:${G.kol(self.c[k])}${self.r1}"


def lembar_hitung(wb, ctx):
    ws = wb.create_sheet("Hitung")
    G.warna_tab(ws, G.ABU)
    G.pita(ws, "Hitung", "Besaran dasar dari lembar Data (tahun dasar, jendela historis) dan kumpulan hasil semua slot. "
                         "Semua sel berumus.")
    prov = PROVINSI(ctx.kode)
    T = TataHitung(len(prov))
    sektor = [s for s, _, _ in SEKTOR]
    kolom = ["Y0", "Yn0", "K0", "Kn0", "Dfl0", "I0", "n", "mY", "mK", "mL",
             "cYY", "cKK", "cLL", "cYK", "cYL", "cKL", "sh0", "sh1", "sh2", "pangsa", "sinv"] + \
            [f"G3_{g}" for g in KEL] + [f"kh_{g}" for g in KEL] + [f"S3_{s}" for s in sektor] + \
            [f"ks_{s}" for s in sektor] + ["thB", "belanja0", "Pp", "pA", "pC", "ptva"]
    for k in kolom:
        T.tambah(k)
    judul = {
        "Y0": "PDRB riil dasar", "Yn0": "PDRB nominal dasar", "K0": "PMTB riil dasar", "Kn0": "PMTB nominal dasar",
        "Dfl0": "Deflator PMTB", "I0": "PMA+PMDN dasar", "n": "Tahun laju lengkap", "mY": "Laju ln PDRB",
        "mK": "Laju ln PMTB", "mL": "Laju ln TK", "sh0": "Pangsa inv. TD-2", "sh1": "Pangsa inv. TD-1",
        "sh2": "Pangsa inv. TD", "pangsa": "Pangsa rata-rata", "sinv": "Pangsa investasi", "thB": "Tahun APBD",
        "belanja0": "Belanja APBD", "Pp": "Produktivitas total", "pA": "Produktivitas pertanian",
        "pC": "Produktivitas industri", "ptva": "Produktivitas jasa bernilai tambah",
    }
    G.header(ws, 5, 1, ["Kode", "Provinsi", "Pulau"] + [judul.get(k, k) for k in kolom], tinggi=42)

    def S(k, r):
        return f"${G.kol(T.c[k])}{r}"

    for i, (kd, nm, pl) in enumerate(prov):
        r = R0 + i
        for c, v in enumerate((kd, nm, pl), 1):
            ws.cell(row=r, column=c, value=v)
        a = f"$A{r}"
        dasar = lambda var: f"SUMIFS(D_{var},D_kode,{a},D_tahun,TD)"  # noqa: E731
        f = {
            "Y0": f"={dasar('PDRB_ADHK')}",
            "Yn0": f"=IF({dasar('PDRB_ADHB')}>0,{dasar('PDRB_ADHB')},{S('Y0', r)}*{S('Dfl0', r)})",
            "K0": f"={dasar('PMTB_ADHK')}",
            "Kn0": f"={dasar('PMTB_ADHB')}",
            "Dfl0": f"={S('Kn0', r)}/{S('K0', r)}",
            "I0": f"={dasar('INV')}",
            "n": f"=COUNTIFS(D_kode,{a},D_ok,1)",
            "mY": f"=AVERAGEIFS(D_dY,D_kode,{a},D_ok,1)",
            "mK": f"=AVERAGEIFS(D_dK,D_kode,{a},D_ok,1)",
            "mL": f"=AVERAGEIFS(D_dL,D_kode,{a},D_ok,1)",
        }
        for kk, (x, y) in {"cYY": ("mY", "mY"), "cKK": ("mK", "mK"), "cLL": ("mL", "mL"), "cYK": ("mY", "mK"),
                           "cYL": ("mY", "mL"), "cKL": ("mK", "mL")}.items():
            f[kk] = f"=(SUMIFS(D_{kk[1:]},D_kode,{a},D_ok,1)-{S('n', r)}*{S(x, r)}*{S(y, r)})/({S('n', r)}-1)"
        for j in range(3):
            th = f"(TD-{2 - j})"
            f[f"sh{j}"] = (f'=IF(COUNTIFS(D_kode,{a},D_tahun,{th},D_INV,{NUM})=0,"",'
                           f'IFERROR(SUMIFS(D_INV,D_kode,{a},D_tahun,{th})/SUMIFS(D_INV,D_tahun,{th}),""))')
        f["pangsa"] = f"=IFERROR(AVERAGE({S('sh0', r)}:{S('sh2', r)}),0)"
        f["sinv"] = f"={S('pangsa', r)}/SUM({T.rentang('pangsa').replace('Hitung!', '')})"
        tiga = f'D_kode,{a},D_tahun,">="&(TD-2),D_tahun,"<="&TD'
        for g in KEL:
            f[f"G3_{g}"] = f"=SUMIFS(D_G_{g},{tiga})"
        tot = "+".join(S(f"G3_{g}", r) for g in KEL)
        for g in KEL:
            f[f"kh_{g}"] = f"=IF(({tot})>0,{S(f'G3_{g}', r)}/({tot}),KHN_{g})"
        kel_sektor = {s: kk for s, _, kk in SEKTOR}
        for s in sektor:
            f[f"S3_{s}"] = f"=SUMIFS(D_S_{s},{tiga})"
        for s in sektor:
            sama = [x for x in sektor if kel_sektor[x] == kel_sektor[s]]
            tot_s = "+".join(S(f"S3_{x}", r) for x in sama)
            f[f"ks_{s}"] = f"=IF(({tot_s})>0,{S(f'S3_{s}', r)}/({tot_s}),KSN_{s})"
        f["thB"] = (f"=SUMPRODUCT(MAX((D_kode={a})*(D_tahun<=TD)*ISNUMBER(D_APBD_BELANJA)*D_tahun))")
        f["belanja0"] = f"=IF({S('thB', r)}=0,0,SUMIFS(D_APBD_BELANJA,D_kode,{a},D_tahun,{S('thB', r)}))"
        pr = lambda va, tk: (f"=IF(TAHUN_TK=0,1,SUMIFS({va},D_kode,{a},D_tahun,TAHUN_TK)/"  # noqa: E731
                             f"SUMIFS({tk},D_kode,{a},D_tahun,TAHUN_TK))")
        f["Pp"] = pr("D_VATOT", "D_TKT")
        f["pA"] = pr("D_VA_A", "D_TK_A")
        f["pC"] = pr("D_VA_C", "D_TK_C")
        f["ptva"] = pr("D_VATVA", "D_TKTVA")
        for k, v in f.items():
            G.tulis(ws, r, T.c[k], v, fill=G.F_RUMUS)
    for k in kolom:
        G.nama(wb, f"HP_{k}", "Hitung", T.rentang(k).replace("Hitung!", ""))
    for k in ("Y0", "Yn0", "K0", "Kn0", "I0", "belanja0"):
        for r in range(R0, T.r1 + 1):
            ws.cell(row=r, column=T.c[k]).number_format = G.FMT_T
    G.nama(wb, "HP_kode", "Hitung", f"$A${R0}:$A${T.r1}")

    # ---- tabel tahunan nasional
    ct = T._n + 2
    G.bagian(ws, 4, ct, ct + 11, "Agregat nasional per tahun")
    kol_th = ["Tahun", "PDRB riil", "PMTB riil", "PMTB nominal", "PMA+PMDN", "d ln PDRB", "d ln PMTB",
              "d ln PMTB nominal", "d ln PMA+PMDN", "Inflasi PMTB", "Di jendela", "Provinsi ber-TK"]
    G.header(ws, 5, ct, kol_th, tinggi=42)
    n_th = TH_AKHIR - TH_AWAL + 1
    for j in range(n_th):
        r = R0 + j
        c = lambda k: f"${G.kol(ct + k)}{r}"  # noqa: E731
        p = lambda k: f"${G.kol(ct + k)}{r - 1}"  # noqa: E731
        ws.cell(row=r, column=ct, value=TH_AWAL + j)
        for k, var in enumerate(["PDRB_ADHK", "PMTB_ADHK", "PMTB_ADHB", "INV"], 1):
            G.tulis(ws, r, ct + k, f"=SUMIFS(D_{var},D_tahun,{c(0)})", fill=G.F_RUMUS, fmt=G.FMT_T)
        for k in range(4):
            if j == 0:
                v = '=""'
            else:
                v = f'=IF(AND(N({c(1 + k)})>0,N({p(1 + k)})>0),LN({c(1 + k)}/{p(1 + k)}),"")'
            G.tulis(ws, r, ct + 5 + k, v, fill=G.F_RUMUS, fmt=G.FMT_4)
        G.tulis(ws, r, ct + 9, f'=IFERROR({c(7)}-{c(6)},"")', fill=G.F_RUMUS, fmt=G.FMT_4)
        G.tulis(ws, r, ct + 10, f"=IF(AND({c(0)}>=HA,{c(0)}<=HZ,OR(KECUALI_2020=0,{c(0)}<>2020)),1,0)", fill=G.F_RUMUS)
        G.tulis(ws, r, ct + 11, f"=COUNTIFS(D_tahun,{c(0)},D_TKT,{NUM})", fill=G.F_RUMUS)
    rng = lambda k: f"${G.kol(ct + k)}${R0}:${G.kol(ct + k)}${R0 + n_th - 1}"  # noqa: E731

    # ---- besaran nasional
    cs = 1
    rs = T.r1 + 3
    G.bagian(ws, rs, cs, cs + 5, "Besaran nasional")
    skalar = [
        ("N_PROV", "Jumlah provinsi", "=COUNT(HP_Y0)", "0"),
        ("YNAS0", "PDRB riil nasional dasar", "=SUM(HP_Y0)", G.FMT_T),
        ("INAS0", "PMA+PMDN nasional dasar", "=SUM(HP_I0)", G.FMT_T),
        ("GY_HIST", "Laju ln PDRB nasional historis", f"=AVERAGEIFS({rng(5)},{rng(10)},1)", G.FMT_4),
        ("GK_HIST", "Laju ln PMTB nasional historis", f"=AVERAGEIFS({rng(6)},{rng(10)},1)", G.FMT_4),
        ("GI_HIST", "Laju ln PMA+PMDN nasional historis", f"=AVERAGEIFS({rng(8)},{rng(10)},1)", G.FMT_4),
        ("INFL_HIST", "Inflasi deflator PMTB historis (ln)", f"=AVERAGEIFS({rng(9)},{rng(10)},1)", G.FMT_4),
        ("TAHUN_TK", "Tahun TK sektoral lengkap terakhir",
         f"=SUMPRODUCT(MAX(({rng(0)}<=TD)*({rng(11)}>=N_PROV)*{rng(0)}))", "0"),
    ]
    for i, (nm, lb, f, fmt) in enumerate(skalar):
        r = rs + 1 + i
        G.gabung(ws, r, cs, cs + 2, lb, font=G.T_BIASA)
        G.tulis(ws, r, cs + 3, f, fill=G.F_RUMUS, fmt=fmt)
        G.nama(wb, nm, "Hitung", f"${G.kol(cs + 3)}${r}")
    r = rs + 2 + len(skalar)
    G.tulis(ws, r, cs, "Komposisi investasi nasional (3 tahun)", font=G.T_TEBAL)
    for j, g in enumerate(KEL):
        rr = r + 1 + j
        G.tulis(ws, rr, cs, g)
        tot = "+".join(f"SUM(HP_G3_{x})" for x in KEL)
        G.tulis(ws, rr, cs + 3, f"=SUM(HP_G3_{g})/({tot})", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.nama(wb, f"KHN_{g}", "Hitung", f"${G.kol(cs + 3)}${rr}")
        G.tulis(ws, rr, cs + 4, f"=SUMPRODUCT(HP_kh_{g},HP_sinv)", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.nama(wb, f"KHS_{g}", "Hitung", f"${G.kol(cs + 4)}${rr}")
    G.tulis(ws, r, cs + 3, "Total", font=G.T_KECIL)
    G.tulis(ws, r, cs + 4, "Berbobot investasi", font=G.T_KECIL)
    r += len(KEL) + 2
    G.tulis(ws, r, cs, "Komposisi sektor nasional di dalam kelompok", font=G.T_TEBAL)
    kel_sektor = {s: kk for s, _, kk in SEKTOR}
    for j, s in enumerate(sektor):
        rr = r + 1 + j
        G.tulis(ws, rr, cs, s)
        sama = "+".join(f"SUM(HP_S3_{x})" for x in sektor if kel_sektor[x] == kel_sektor[s])
        G.tulis(ws, rr, cs + 3, f"=IFERROR(SUM(HP_S3_{s})/({sama}),0)", fill=G.F_RUMUS, fmt=G.FMT_4)
        G.nama(wb, f"KSN_{s}", "Hitung", f"${G.kol(cs + 3)}${rr}")
    r_bebas = r + len(sektor) + 3

    G.lebar(ws, [7, 22, 12] + [11] * len(kolom))
    ws.freeze_panes = "D6"
    return ws, T, r_bebas


DERET_KUMPUL = ["gd", "gs", "gt", "Yd", "Ys", "Yt", "inv_tren", "inv_a1", "inv_a2", "inv_a2r", "inv_keb", "tamb_keb",
                "apbd_nas", "tfp_d", "tfp_s", "Ys_lo", "Ys_hi", "kjA", "kjY", "Dt"]
PROV_KUMPUL = ["g_dasar", "g_skenario", "g_sasaran", "prob", "keb_kum", "a2_kum", "a2r_kum", "selisih", "bobot",
               "tfp_skenario", "k_modal", "k_tk", "k_tfp", "k_sektoral", "k_realokasi", "k_determinan", "k_kejutan",
               "bonus_keb", "rasio_keb_pdrb", "sd"]
JUDUL_PROV_KUMPUL = {
    "g_dasar": "Laju tanpa penambahan (%)", "g_skenario": "Laju dengan penambahan (%)", "g_sasaran": "Sasaran (%)",
    "prob": "Confidence", "keb_kum": "Kebutuhan tambahan (T)", "a2_kum": "Investasi tambahan (T)",
    "a2r_kum": "Investasi tambahan terealisasi (T)", "selisih": "Selisih (T)", "bobot": "Bobot investasi tambahan",
    "tfp_skenario": "Indeks TFP", "k_modal": "Kontribusi modal (pp)", "k_tk": "Kontribusi TK (pp)",
    "k_tfp": "Kontribusi tren TFP (pp)", "k_sektoral": "Kontribusi sektoral (pp)",
    "k_realokasi": "Kontribusi realokasi (pp)", "k_determinan": "Kontribusi determinan (pp)",
    "k_kejutan": "Kontribusi shock (pp)", "bonus_keb": "Bonus jalur sasaran (pp)",
    "rasio_keb_pdrb": "Kebutuhan per tahun / PDRB (%)", "sd": "SD ln PDRB",
}
UANG = {"keb_kum", "a2_kum", "a2r_kum", "selisih"}


def kumpulan(wb, ws, ctx, peta, r0):
    """Tabel kumpulan semua slot di bawah lembar Hitung. peta: daftar TataMesin per slot."""
    from .mesin import JUDUL_DERET, JUDUL_RINGKAS, MAKS_H, RINGKAS

    ns = len(ctx.slot)
    ref = lambda s, sel: f"'{ctx.slot[s].sheet}'!{sel}"  # noqa: E731
    out = {}

    # 1. ringkasan per slot
    r = r0
    G.bagian(ws, r, 1, 6 + len(RINGKAS), "Kumpulan: ringkasan per slot")
    kol = ["No", "Skenario", "Singkat", "Tampil", "Lembar"] + [JUDUL_RINGKAS[k] for k in RINGKAS]
    G.header(ws, r + 1, 1, kol, tinggi=54)
    for s in range(ns):
        rr = r + 2 + s
        T = peta[s]
        G.tulis(ws, rr, 1, s + 1)
        G.tulis(ws, rr, 2, f"=INDEX(SK_NAMA,{s + 1})")
        G.tulis(ws, rr, 3, f"=INDEX(SK_SINGKAT,{s + 1})")
        G.tulis(ws, rr, 4, f"=INDEX(SK_TAMPIL,{s + 1})")
        G.tulis(ws, rr, 5, ctx.slot[s].sheet, font=G.T_KECIL)
        for j, k in enumerate(RINGKAS):
            G.tulis(ws, rr, 6 + j, f"={ref(s, T.RG(k))}", fill=G.F_RUMUS,
                    fmt=G.FMT_PCT1 if k == "prob_nas" else G.FMT_P)
    rr1 = r + 1 + ns
    for nm, c in (("KS_no", 1), ("KS_nama", 2), ("KS_singkat", 3), ("KS_tampil", 4)):
        G.nama(wb, nm, "Hitung", f"${G.kol(c)}${r + 2}:${G.kol(c)}${rr1}")
    for j, k in enumerate(RINGKAS):
        G.nama(wb, f"KS_{k}", "Hitung", f"${G.kol(6 + j)}${r + 2}:${G.kol(6 + j)}${rr1}")
    out["ringkas"] = (r + 1, rr1)

    # 2. deret per slot
    r = rr1 + 3
    G.bagian(ws, r, 1, 4 + MAKS_H, "Kumpulan: deret tahunan per slot (baris = slot, kolom = tahun)")
    r += 1
    for k in DERET_KUMPUL:
        G.tulis(ws, r, 1, JUDUL_DERET.get(k, k), font=G.T_TEBAL)
        G.header(ws, r, 3, ["Tahun dasar"] + [f"=TD+{h}" for h in range(1, MAKS_H + 1)])
        for s in range(ns):
            rr = r + 1 + s
            T = peta[s]
            G.tulis(ws, rr, 1, s + 1, font=G.T_KECIL)
            G.tulis(ws, rr, 2, f"=INDEX(SK_SINGKAT,{s + 1})", font=G.T_KECIL)
            awal = {"Yd": "=YNAS0", "Ys": "=YNAS0", "Yt": "=YNAS0", "tfp_d": 100, "tfp_s": 100, "Ys_lo": "=YNAS0",
                    "Ys_hi": "=YNAS0"}.get(k, '=NA()')
            G.tulis(ws, rr, 3, awal, fill=G.F_RUMUS)
            for h in range(1, MAKS_H + 1):
                G.tulis(ws, rr, 3 + h, f"={ref(s, T.D(k, h))}", fill=G.F_RUMUS, fmt=G.FMT_P)
        G.nama(wb, f"KT_{k}", "Hitung", f"$C${r + 1}:${G.kol(3 + MAKS_H)}${r + ns}")
        r += ns + 2
    out["deret"] = r

    # 3. hasil provinsi (tabel datar, sumber pivot)
    r += 1
    G.bagian(ws, r, 1, 7 + len(PROV_KUMPUL), "Kumpulan: hasil per provinsi (tabel datar)")
    kol = ["No", "Skenario", "Singkat", "Kode", "Provinsi", "Pulau", "Tampil"] + \
          [JUDUL_PROV_KUMPUL[k] for k in PROV_KUMPUL]
    rh = r + 1
    G.header(ws, rh, 1, kol, tinggi=42)
    prov = PROVINSI(ctx.kode)
    for s in range(ns):
        T = peta[s]
        for i, (kd, nm, pl) in enumerate(prov):
            rr = rh + 1 + s * len(prov) + i
            G.tulis(ws, rr, 1, s + 1)
            G.tulis(ws, rr, 2, f"=INDEX(SK_NAMA,{s + 1})")
            G.tulis(ws, rr, 3, f"=INDEX(SK_SINGKAT,{s + 1})")
            G.tulis(ws, rr, 4, kd)
            G.tulis(ws, rr, 5, nm)
            G.tulis(ws, rr, 6, pl)
            G.tulis(ws, rr, 7, f"=INDEX(SK_TAMPIL,{s + 1})")
            for j, k in enumerate(PROV_KUMPUL):
                isi = ref(s, T.P_(k, R0 + i))
                isi = f"={isi}/1000" if k in UANG else f"={isi}"
                G.tulis(ws, rr, 8 + j, isi, fmt=G.FMT_PCT1 if k in ("prob", "bobot") else G.FMT_P)
    rp1 = rh + ns * len(prov)
    for nm, c in (("KP_no", 1), ("KP_nama", 2), ("KP_singkat", 3), ("KP_kode", 4), ("KP_prov", 5),
                  ("KP_pulau", 6), ("KP_tampil", 7)):
        G.nama(wb, nm, "Hitung", f"${G.kol(c)}${rh + 1}:${G.kol(c)}${rp1}")
    for j, k in enumerate(PROV_KUMPUL):
        G.nama(wb, f"KP_{k}", "Hitung", f"${G.kol(8 + j)}${rh + 1}:${G.kol(8 + j)}${rp1}")
    out["prov"] = (rh, rp1, 7 + len(PROV_KUMPUL))

    # 4. arah sektor (tabel datar, sumber pivot)
    r = rp1 + 3
    G.bagian(ws, r, 1, 8, "Kumpulan: arah sektor per slot (tabel datar)")
    rh2 = r + 1
    G.header(ws, rh2, 1, ["No", "Skenario", "Singkat", "Sektor", "Nama sektor", "Kelompok", "Kebutuhan (T)",
                          "Investasi tambahan (T)"], tinggi=30)
    for s in range(ns):
        T = peta[s]
        for j, (kode_s, nm_s, kel) in enumerate(SEKTOR):
            rr = rh2 + 1 + s * len(SEKTOR) + j
            rs = T.rb + 2 + j
            G.tulis(ws, rr, 1, s + 1)
            G.tulis(ws, rr, 2, f"=INDEX(SK_NAMA,{s + 1})")
            G.tulis(ws, rr, 3, f"=INDEX(SK_SINGKAT,{s + 1})")
            G.tulis(ws, rr, 4, kode_s)
            G.tulis(ws, rr, 5, nm_s)
            G.tulis(ws, rr, 6, kel)
            G.tulis(ws, rr, 7, f"={ref(s, f'$U${rs}')}", fmt=G.FMT_T1)
            G.tulis(ws, rr, 8, f"={ref(s, f'$V${rs}')}", fmt=G.FMT_T1)
    rs1 = rh2 + ns * len(SEKTOR)
    for nm, c in (("KK_no", 1), ("KK_sektor", 4), ("KK_keb", 7), ("KK_a2", 8)):
        G.nama(wb, nm, "Hitung", f"${G.kol(c)}${rh2 + 1}:${G.kol(c)}${rs1}")
    out["sektor"] = (rh2, rs1, 8)

    # 5. kelompok per slot
    r = rs1 + 3
    G.bagian(ws, r, 1, 6, "Kumpulan: kelompok sektor per slot")
    rh3 = r + 1
    G.header(ws, rh3, 1, ["No", "Singkat", "Kelompok", "Pangsa historis", "Pangsa investasi tambahan", "Bonus pp"],
             tinggi=30)
    for s in range(ns):
        T = peta[s]
        rk0 = T.rb + 3 + len(SEKTOR)
        for j, g in enumerate(KEL):
            rr = rh3 + 1 + s * len(KEL) + j
            G.tulis(ws, rr, 1, s + 1)
            G.tulis(ws, rr, 2, f"=INDEX(SK_SINGKAT,{s + 1})")
            G.tulis(ws, rr, 3, g)
            for c, L in enumerate(("T", "U", "V"), 4):
                G.tulis(ws, rr, c, f"={ref(s, f'${L}${rk0 + 1 + j}')}", fmt=G.FMT_4)
    rg1 = rh3 + ns * len(KEL)
    for nm, c in (("KG_no", 1), ("KG_kel", 3), ("KG_hist", 4), ("KG_a2", 5), ("KG_bonus", 6)):
        G.nama(wb, nm, "Hitung", f"${G.kol(c)}${rh3 + 1}:${G.kol(c)}${rg1}")
    out["kelompok"] = (rh3, rg1)
    return out
