from django.urls import path
from django.views.generic import RedirectView

from . import views

app_name = "datapanel"
urlpatterns = [
    path("", views.daftar_versi, name="daftar_versi"),
    path("unggah/", views.unggah, name="unggah"),
    path("templat.xlsx", views.unduh_templat, name="templat"),
    path("jelajah/", views.penjelajah, name="penjelajah"),
    path("penjelajah/", RedirectView.as_view(pattern_name="datapanel:penjelajah", query_string=True)),
    path("api/indikator/", views.api_indikator, name="api_indikator"),
    path("<int:pk>/", views.detail_versi, name="detail_versi"),
    path("<int:pk>/unduh.xlsx", views.unduh_versi, name="unduh_versi"),
    path("<int:pk>/kelengkapan/", views.kelengkapan, name="kelengkapan"),
    path("<int:pk>/grid/", views.sunting_grid, name="sunting_grid"),
    path("<int:pk>/grid.json", views.grid_json, name="grid_json"),
    path("<int:pk>/<str:aksi>/", views.aksi_versi, name="aksi_versi"),
    path("<int:pk>/sunting/<int:kode>/<int:tahun>/", views.sunting_observasi, name="sunting_observasi"),
]
