from django.urls import path

from . import views

app_name = "estimasi"
urlpatterns = [
    path("", views.daftar, name="daftar"),
    path("hitung/", views.api_hitung, name="api_hitung"),
    path("simpan/", views.simpan, name="simpan"),
    path("<int:pk>/hapus/", views.hapus, name="hapus"),
    path("<int:pk>/default/", views.jadikan_default, name="default"),
    path("baru/", views.sunting_parameter, name="tambah"),
    path("<int:pk>/", views.detail, name="detail"),
    path("<int:pk>/edit/", views.sunting_parameter, name="edit"),
    path("sektoral/baru/", views.sunting_sektoral, name="tambah_sektoral"),
    path("sektoral/<int:pk>/", views.sunting_sektoral, name="sunting_sektoral"),
    path("determinan/baru/", views.sunting_determinan, name="tambah_determinan"),
    path("determinan/<int:pk>/", views.sunting_determinan, name="sunting_determinan"),
    path("determinan/<int:pk>/hapus/", views.hapus_determinan, name="hapus_determinan"),
    path("determinan/<int:pk>/default/", views.default_determinan, name="default_determinan"),
]
