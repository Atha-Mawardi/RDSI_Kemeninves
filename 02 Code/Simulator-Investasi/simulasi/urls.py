from django.urls import path

from . import views

app_name = "simulasi"
urlpatterns = [
    path("", views.daftar, name="daftar"),
    path("baru/", views.edit, name="baru"),
    path("bandingkan/", views.bandingkan, name="bandingkan"),
    path("aktif/", views.pilih_aktif, name="aktif"),
    path("hasil/", views.hasil_aktif, name="hasil_aktif"),
    path("paket/semua/", views.templat_semua, name="templat_semua"),
    path("paket/<str:kode>/", views.templat_buat, name="templat_buat"),
    path("paket/<str:kode>/kembalikan/", views.templat_kembalikan, name="templat_kembalikan"),
    path("<int:pk>/", views.detail, name="detail"),
    path("<int:pk>/edit/", views.edit, name="edit"),
    path("<int:pk>/jalankan/", views.jalankan, name="jalankan"),
    path("<int:pk>/salin/", views.duplikat, name="duplikat"),
    path("<int:pk>/hapus/", views.hapus, name="hapus"),
    path("<int:pk>/kustom/", views.simpan_kustom, name="simpan_kustom"),
    path("<int:pk>/nama/", views.ganti_nama, name="ganti_nama"),
    path("<int:pk>/hitung.csv", views.unduh_hitung, name="unduh_hitung"),
    path("<int:pk>/hasil.xlsx", views.unduh_hasil, name="unduh_hasil"),
    path("<int:pk>/asumsi/", views.asumsi_provinsi, name="asumsi_provinsi"),
    path("<int:pk>/asumsi.xlsx", views.unduh_asumsi, name="unduh_asumsi"),
    path("<int:pk>/asumsi/unggah/", views.unggah_asumsi, name="unggah_asumsi"),
]
