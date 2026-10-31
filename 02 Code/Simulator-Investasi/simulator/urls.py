from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from datapanel import pivot as pv
from datapanel.views import beranda

urlpatterns = [
    path("", beranda, name="beranda"),
    path("data/", include("datapanel.urls")),
    path("estimasi/", include("estimasi.urls")),
    path("io/", include("io_irio.urls")),
    path("pivot/", pv.pivot, name="pivot"),
    path("pivot/data/", pv.data, name="pivot_data"),
    path("pivot/xlsx/", pv.xlsx, name="pivot_xlsx"),
    path("skenario/", include("simulasi.urls")),
    path("admin/", admin.site.urls),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
