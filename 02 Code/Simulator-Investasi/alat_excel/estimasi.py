"""Lembar Estimasi: estimasi ulang elastisitas dari lembar Data dan tabel koefisien yang bisa disunting."""

from . import gaya as G
from .konteks import NAMA_PILAR

R_EP = 20  # baris judul tabel set elastisitas
N_TAHUN_EST = 30
N_PROV_EST = 60


def lembar_estimasi(wb, ctx):
    ws = wb.create_sheet("Estimasi")
    G.warna_tab(ws, G.BIRU)
    G.pita(ws, "Estimasi dan koefisien",
           "Estimasi ulang elastisitas dari lembar Data dan tabel koefisien yang dipakai skenario. Sel kuning dapat diubah.")

    G.bagian(ws, 4, 1, 3, "Jendela estimasi")
    isian = [("EA", "Tahun awal", 2017), ("EZ", "Tahun akhir", max(ctx.umum["tahun_dasar"] - 1, 2018)),
             ("EST_2020", "Kecualikan 2020 (1 = ya)", 0)]
    for i, (nm, lb, v) in enumerate(isian):
        r = 5 + i
        G.tulis(ws, r, 1, lb, font=G.T_TEBAL)
        G.tulis(ws, r, 3, v, fill=G.F_ISIAN, align=G.TENGAH, border=G.KOTAK)
        G.nama(wb, nm, "Estimasi", f"$C${r}")
    G.tulis(ws, 9, 1, "ln PDRB pada ln PMTB dan ln tenaga kerja, fixed effect provinsi dan tahun; standard error klaster "
                      "provinsi.", font=G.T_KECIL)

    # ---- pembantu (kolom T ke kanan)
    ct = 20
    G.bagian(ws, 4, ct, ct + 8, "Pembantu estimasi")
    G.header(ws, 5, ct, ["Kode", "Obs", "Σ e·k", "Σ e·l", "", "Tahun", "Obs"])
    for i in range(N_PROV_EST):
        r = 6 + i
        if i < len(ctx.kode):
            ws.cell(row=r, column=ct, value=ctx.kode[i])
        a = f"${G.kol(ct)}{r}"
        G.tulis(ws, r, ct + 1, f'=IF({a}="","",COUNTIFS(D_kode,{a},D_eok,1))', fill=G.F_RUMUS)
        G.tulis(ws, r, ct + 2, f'=IF({a}="","",SUMIFS(D_eek,D_kode,{a}))', fill=G.F_RUMUS)
        G.tulis(ws, r, ct + 3, f'=IF({a}="","",SUMIFS(D_eel,D_kode,{a}))', fill=G.F_RUMUS)
    for i in range(N_TAHUN_EST):
        r = 6 + i
        G.tulis(ws, r, ct + 5, f"=IF(EA+{i}<=EZ,EA+{i},\"\")", fill=G.F_RUMUS)
        y = f"${G.kol(ct + 5)}{r}"
        G.tulis(ws, r, ct + 6, f'=IF({y}="","",COUNTIFS(D_tahun,{y},D_eok,1))', fill=G.F_RUMUS)
    rp = f"${G.kol(ct)}$6:${G.kol(ct)}${5 + N_PROV_EST}"
    obs = f"${G.kol(ct + 1)}$6:${G.kol(ct + 1)}${5 + N_PROV_EST}"
    sk = f"${G.kol(ct + 2)}$6:${G.kol(ct + 2)}${5 + N_PROV_EST}"
    sl = f"${G.kol(ct + 3)}$6:${G.kol(ct + 3)}${5 + N_PROV_EST}"
    oth = f"${G.kol(ct + 6)}$6:${G.kol(ct + 6)}${5 + N_TAHUN_EST}"
    del rp

    skalar = [
        ("EST_N", "Observasi", "=SUM(D_eok)"),
        ("EST_G", "Provinsi", f'=COUNTIF({obs},">0")'),
        ("EST_T", "Tahun", f'=COUNTIF({oth},">0")'),
        ("EST_k", "Regresor (termasuk dummy tahun)", "=2+EST_T-1"),
        ("EST_mY", "Rata-rata ln PDRB", "=AVERAGEIFS(D_lnY,D_eok,1)"),
        ("EST_mK", "Rata-rata ln PMTB", "=AVERAGEIFS(D_lnK,D_eok,1)"),
        ("EST_mL", "Rata-rata ln TK", "=AVERAGEIFS(D_lnL,D_eok,1)"),
        ("EST_Skk", "Σ k²", "=SUM(D_ekk)"), ("EST_Sll", "Σ l²", "=SUM(D_ell)"), ("EST_Skl", "Σ k·l", "=SUM(D_ekl)"),
        ("EST_Sky", "Σ k·y", "=SUM(D_eyk)"), ("EST_Sly", "Σ l·y", "=SUM(D_eyl)"), ("EST_Syy", "Σ y²", "=SUM(D_eyy)"),
        ("EST_det", "Determinan", "=EST_Skk*EST_Sll-EST_Skl^2"),
        ("EST_b1", "Elastisitas modal", "=(EST_Sll*EST_Sky-EST_Skl*EST_Sly)/EST_det"),
        ("EST_b2", "Elastisitas TK", "=(EST_Skk*EST_Sly-EST_Skl*EST_Sky)/EST_det"),
        ("EST_M11", "Meat kk", f"=SUMPRODUCT({sk},{sk})"),
        ("EST_M22", "Meat ll", f"=SUMPRODUCT({sl},{sl})"),
        ("EST_M12", "Meat kl", f"=SUMPRODUCT({sk},{sl})"),
        ("EST_c", "Koreksi n/(n-k)", "=EST_N/(EST_N-EST_k)"),
        ("EST_V11", "Var b1",
         "=EST_c*(EST_Sll^2*EST_M11-2*EST_Sll*EST_Skl*EST_M12+EST_Skl^2*EST_M22)/EST_det^2"),
        ("EST_V22", "Var b2",
         "=EST_c*(EST_Skl^2*EST_M11-2*EST_Skl*EST_Skk*EST_M12+EST_Skk^2*EST_M22)/EST_det^2"),
        ("EST_V12", "Kov b1 b2",
         "=EST_c*(-EST_Sll*EST_Skl*EST_M11+(EST_Sll*EST_Skk+EST_Skl^2)*EST_M12-EST_Skl*EST_Skk*EST_M22)/EST_det^2"),
        ("EST_se1", "SE b1", "=SQRT(EST_V11)"), ("EST_se2", "SE b2", "=SQRT(EST_V22)"),
        ("EST_df", "Derajat bebas klaster", "=EST_G-1"),
        ("EST_ee", "Σ e²", "=SUM(D_eee)"),
        ("EST_r2", "R² within", "=1-EST_ee/EST_Syy"),
        ("EST_tk", "t kritis 95%", "=TINV(0.05,EST_df)"),
    ]
    G.bagian(ws, 4, ct + 9, ct + 11, "Besaran antara")
    for i, (nm, lb, f) in enumerate(skalar):
        r = 5 + i
        G.tulis(ws, r, ct + 9, lb, font=G.T_KECIL)
        G.tulis(ws, r, ct + 11, f, fill=G.F_RUMUS, fmt="0.000000")
        G.nama(wb, nm, "Estimasi", f"${G.kol(ct + 11)}${r}")
    G.lebar(ws, [7, 7, 9, 9, 2, 7, 7, 2, 2, 26, 2, 12], mulai=ct)

    # ---- tabel hasil
    G.bagian(ws, 4, 5, 12, "Hasil estimasi")
    G.header(ws, 5, 5, ["", "Koefisien", "SE klaster", "t", "p", "CI 95% bawah", "CI 95% atas", ""])
    for i, (lb, b, se) in enumerate([("ln PMTB (modal)", "EST_b1", "EST_se1"),
                                     ("ln tenaga kerja", "EST_b2", "EST_se2"),
                                     ("Jumlah (uji skala hasil konstan, H0 = 1)", "EST_b1+EST_b2",
                                      "SQRT(EST_V11+EST_V22+2*EST_V12)")]):
        r = 6 + i
        t = f"({b}{'-1' if i == 2 else ''})/({se})"
        G.tulis(ws, r, 5, lb, font=G.T_TEBAL)
        for c, f in enumerate([f"={b}", f"={se}", f"={t}", f"=TDIST(ABS({t}),EST_df,2)",
                               f"={b}-EST_tk*{se}", f"={b}+EST_tk*{se}"], 6):
            G.tulis(ws, r, c, f, fill=G.F_RUMUS, fmt=G.FMT_4, border=G.GARIS)
        G.tulis(ws, r, 12, f'=IF(I{r}<0.01,"***",IF(I{r}<0.05,"**",IF(I{r}<0.1,"*","")))', font=G.T_TEBAL)
    for i, (lb, f, fmt) in enumerate([("Observasi", "=EST_N", "0"), ("Provinsi", "=EST_G", "0"),
                                      ("Tahun", "=EST_T", "0"), ("R² within", "=EST_r2", G.FMT_4)]):
        r = 10 + i
        G.tulis(ws, r, 5, lb, font=G.T_BIASA)
        G.tulis(ws, r, 6, f, fill=G.F_RUMUS, fmt=fmt)
    G.tulis(ws, 15, 5, "Demean dua arah satu langkah: tepat untuk panel seimbang. Bila ada provinsi-tahun yang "
                       "hilang, angka bisa sedikit berbeda dari aplikasi.", font=G.T_KECIL)
    G.tulis(ws, 16, 5, "Hasil ini otomatis tersedia sebagai set \"Estimasi Excel\" di tabel di bawah.", font=G.T_KECIL)

    # ---- set elastisitas
    r = R_EP
    G.bagian(ws, r - 1, 1, 12, "Set elastisitas")
    G.header(ws, r, 1, ["Nama set", "", "", "", "Elastisitas modal", "Elastisitas TK", "SE modal", "SE TK"])
    baris = [(s.nama, s.b1, s.b2, s.se_b1, s.se_b2) for s in ctx.set_param]
    baris += [("Estimasi Excel", "=EST_b1", "=EST_b2", "=EST_se1", "=EST_se2"), ("Manual", 0.4, 0.15, 0.04, 0.1)]
    for i, (nm, *v) in enumerate(baris):
        rr = r + 1 + i
        G.gabung(ws, rr, 1, 4, nm, fill=G.F_ISIAN if nm != "Estimasi Excel" else G.F_RUMUS)
        for j, x in enumerate(v):
            G.tulis(ws, rr, 5 + j, x, fill=G.F_RUMUS if nm == "Estimasi Excel" else G.F_ISIAN, fmt=G.FMT_4)
    r1 = r + len(baris)
    for nm, c in (("EP_nama", 1), ("EP_b1", 5), ("EP_b2", 6), ("EP_se1", 7), ("EP_se2", 8)):
        G.nama(wb, nm, "Estimasi", f"${G.kol(c)}${r + 1}:${G.kol(c)}${r1}")

    # ---- set koefisien sektoral
    r = r1 + 3
    G.bagian(ws, r - 1, 1, 12, "Set koefisien sektoral (laju TFP per pangsa investasi kelompok, basis tersier lainnya)")
    G.header(ws, r, 1, ["Nama set", "", "", "", "Primer", "Sekunder", "Tersier bernilai tambah", "Tersier lainnya",
                        "SE primer", "SE sekunder", "SE tersier bernilai tambah"], tinggi=30)
    baris = [(s.nama, s.primer, s.sekunder, s.tva, 0, s.se_primer, s.se_sekunder, s.se_tva) for s in ctx.set_sektoral]
    baris += [("Tanpa bonus sektoral", 0, 0, 0, 0, 0, 0, 0), ("Manual", 0.015, 0.05, 0.056, 0, 0.007, 0.018, 0.02)]
    for i, (nm, *v) in enumerate(baris):
        rr = r + 1 + i
        G.gabung(ws, rr, 1, 4, nm, fill=G.F_ISIAN)
        for j, x in enumerate(v):
            G.tulis(ws, rr, 5 + j, x, fill=G.F_ISIAN, fmt=G.FMT_4)
    r1 = r + len(baris)
    for nm, c in (("ES_nama", 1), ("ES_primer", 5), ("ES_sekunder", 6), ("ES_tva", 7), ("ES_tlain", 8),
                  ("ES_se_primer", 9), ("ES_se_sekunder", 10), ("ES_se_tva", 11)):
        G.nama(wb, nm, "Estimasi", f"${G.kol(c)}${r + 1}:${G.kol(c)}${r1}")

    # ---- koefisien determinan
    r = r1 + 3
    G.bagian(ws, r - 1, 1, 12, "Koefisien determinan TFP (perubahan log TFP per 1 SD indikator)")
    G.header(ws, r, 1, ["Kode", "Pilar", "Indikator", "", "Koefisien", "SE", "Satuan", "SD"])
    for i, ind in enumerate(ctx.det):
        rr = r + 1 + i
        G.tulis(ws, rr, 1, ind["kode"], font=G.T_KECIL)
        G.tulis(ws, rr, 2, ind["pilar"], font=G.T_KECIL)
        G.gabung(ws, rr, 3, 4, ind["label"])
        G.tulis(ws, rr, 5, ind.get("koef") or 0, fill=G.F_ISIAN, fmt=G.FMT_4)
        G.tulis(ws, rr, 6, ind.get("se") or 0, fill=G.F_ISIAN, fmt=G.FMT_4)
        G.tulis(ws, rr, 7, ind.get("satuan", ""), font=G.T_KECIL)
        G.tulis(ws, rr, 8, ind.get("sd"), fmt=G.FMT_4, font=G.T_KECIL)
    r1 = r + len(ctx.det)
    for nm, c in (("ED_kode", 1), ("ED_pilar", 2), ("ED_koef", 5), ("ED_se", 6)):
        G.nama(wb, nm, "Estimasi", f"${G.kol(c)}${r + 1}:${G.kol(c)}${r1}")

    # ---- jeda default per pilar
    r = r1 + 3
    G.bagian(ws, r - 1, 1, 12, "Jeda dan masa menuju efek penuh (default per pilar, tahun)")
    G.header(ws, r, 1, ["Pilar", "Nama", "", "", "Jeda", "Masa penuh"])
    for i, (p, nm) in enumerate(NAMA_PILAR.items()):
        rr = r + 1 + i
        L, R = ctx.jeda.get(p, (0, 1))
        G.tulis(ws, rr, 1, p, font=G.T_KECIL)
        G.gabung(ws, rr, 2, 4, nm)
        G.tulis(ws, rr, 5, L, fill=G.F_ISIAN)
        G.tulis(ws, rr, 6, R, fill=G.F_ISIAN)
    r1 = r + len(NAMA_PILAR)
    for nm, c in (("EJ_pilar", 1), ("EJ_jeda", 5), ("EJ_penuh", 6)):
        G.nama(wb, nm, "Estimasi", f"${G.kol(c)}${r + 1}:${G.kol(c)}${r1}")

    G.lebar(ws, [12, 12, 14, 14, 12, 12, 12, 12, 12, 12, 12, 6])
    ws.column_dimensions["A"].width = 26
    return ws
