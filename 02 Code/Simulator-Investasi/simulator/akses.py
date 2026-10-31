"""Kata sandi bersama (HTTP Basic) untuk situs publik, aktif bila SIMULATOR_AKSES diisi "pengguna:sandi"."""

import base64
import hmac

from django.conf import settings
from django.http import HttpResponse


class SandiBersama:
    def __init__(self, get_response):
        self.get_response = get_response
        self.harapan = base64.b64encode(settings.AKSES.encode()).decode() if settings.AKSES else ""

    def __call__(self, request):
        if self.harapan:
            jenis, _, isi = request.META.get("HTTP_AUTHORIZATION", "").partition(" ")
            if jenis.lower() != "basic" or not hmac.compare_digest(isi.strip(), self.harapan):
                respons = HttpResponse("Masukkan nama pengguna dan kata sandi.", status=401)
                respons["WWW-Authenticate"] = 'Basic realm="Simulator Investasi", charset="UTF-8"'
                return respons
        return self.get_response(request)
