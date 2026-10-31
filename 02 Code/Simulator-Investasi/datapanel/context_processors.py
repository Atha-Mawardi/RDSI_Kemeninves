from .models import VersiData
from .referensi import NAMA_PROVINSI

_NAMA = {str(k): v for k, v in NAMA_PROVINSI.items()}


def versi_aktif(request):
    return {"versi_aktif": VersiData.aktif(), "nama_provinsi": _NAMA}
