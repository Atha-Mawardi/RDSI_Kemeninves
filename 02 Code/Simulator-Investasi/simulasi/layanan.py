"""Penghubung model Django dengan mesin simulasi."""

import time

from datapanel.papua import tahun_teramati

from .mesin import GalatSimulasi, Konfigurasi, MesinSimulasi
from .models import HasilSkenario, Skenario


def konfigurasi_dari(sk: Skenario) -> Konfigurasi:
    p = sk.set_parameter
    ks = sk.koef_sektoral
    return Konfigurasi(
        tahun_dasar=sk.tahun_dasar, tahun_target=sk.tahun_target,
        hist_awal=sk.hist_awal, hist_akhir=sk.hist_akhir, kecualikan_2020=sk.kecualikan_2020,
        b1=p.b1, b2=p.b2, se_b1=p.se_b1, se_b2=p.se_b2,
        beta=ks.sebagai_dict() if ks else {k: 0.0 for k in ("primer", "sekunder", "tva", "tlain")},
        se_beta=ks.se_dict() if ks else {k: 0.0 for k in ("primer", "sekunder", "tva", "tlain")},
        sasaran=sk.sasaran, mode_sasaran=sk.mode_sasaran, lambda_proporsional=sk.lambda_proporsional,
        mode_tfp=sk.mode_tfp, tfp_nasional=sk.tfp_nasional, faktor_tfp=sk.faktor_tfp,
        mode_tk=sk.mode_tk, tk_nasional=sk.tk_nasional,
        mode_pmtb=sk.mode_pmtb, g_pmtb_nasional=sk.g_pmtb_nasional,
        g_investasi=sk.g_investasi, inflasi_pmtb=sk.inflasi_pmtb,
        pass_through=sk.pass_through, rasio_realisasi=sk.rasio_realisasi,
        pass_through_apbd=sk.pass_through_apbd, apbd_persen=sk.apbd_persen,
        a1=sk.a1 or {}, a2=sk.a2 or {}, alokasi_a2=sk.alokasi_a2, komposisi_a2=sk.komposisi_a2,
        realokasi_pp=sk.realokasi_pp, tujuan_realokasi=sk.tujuan_realokasi,
        override=sk.override_provinsi or {}, jalur=sk.jalur or {}, kejutan=sk.kejutan or [],
        determinan=sk.determinan or {}, koef_determinan=_koef_determinan(sk),
        n_simulasi=min(sk.n_simulasi, 5000), skala_se=sk.skala_se,
        volatilitas_tfp=sk.volatilitas_tfp, seed=sk.seed,
    )


def _koef_determinan(sk: Skenario):
    if not sk.determinan:
        return []
    from estimasi.models import SetDeterminan

    sd = sk.set_determinan or SetDeterminan.utama()
    return list(sd.indikator) if sd else []


def jalankan(sk: Skenario):
    """Hitung dan simpan hasil. Kembalikan (hasil | None, pesan galat | None)."""
    mulai = time.perf_counter()
    versi = sk.versi_data
    try:
        panel = versi.ke_dataframe_38() if sk.rinci_papua else versi.ke_dataframe()
        mesin = MesinSimulasi(panel, konfigurasi_dari(sk))
        data = mesin.jalankan()
        data["meta"]["rinci_papua"] = sk.rinci_papua
        if sk.pecah_papua and not versi.bisa_rinci_papua:
            data["meta"].setdefault("peringatan", []).append(
                "Versi data ini belum punya pangsa pemekaran Papua; simulasi memakai 34 provinsi.")
        if sk.rinci_papua:
            data["meta"]["pangsa_papua"] = {
                "tahun_pdrb": tahun_teramati(versi.pangsa_pemekaran, "PDRB_ADHK"),
                "tahun_pmtb": tahun_teramati(versi.pangsa_pemekaran, "PMTB_ADHK"),
                "catatan": versi.pangsa_pemekaran.get("catatan", []),
            }
    except GalatSimulasi as e:
        sk.status = Skenario.Status.GAGAL
        sk.save(update_fields=["status"])
        return None, str(e)
    hasil, _ = HasilSkenario.objects.update_or_create(
        skenario=sk, defaults={"data": data, "durasi_detik": time.perf_counter() - mulai})
    Skenario.objects.filter(pk=sk.pk).update(status=Skenario.Status.SELESAI)
    sk.status = Skenario.Status.SELESAI
    return hasil, None
