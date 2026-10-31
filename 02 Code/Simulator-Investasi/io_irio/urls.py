from django.urls import path

from . import views

app_name = "io"
urlpatterns = [
    path("", views.beranda, name="beranda"),
    path("muat-ulang/", views.muat_ulang, name="muat_ulang"),
    path("api/aliran/", views.api_aliran, name="api_aliran"),
    path("api/keterkaitan/", views.api_keterkaitan, name="api_keterkaitan"),
    path("api/tren/", views.api_tren, name="api_tren"),
    path("api/indikator/", views.api_indikator, name="api_indikator"),
    path("api/dampak/", views.api_dampak, name="api_dampak"),
]
