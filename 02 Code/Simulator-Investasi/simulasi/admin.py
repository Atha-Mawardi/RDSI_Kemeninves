from django.contrib import admin

from .models import HasilSkenario, Skenario


@admin.register(Skenario)
class SkenarioAdmin(admin.ModelAdmin):
    list_display = ("nama", "status", "versi_data", "set_parameter", "sasaran", "tahun_target", "diubah")
    list_filter = ("status",)


@admin.register(HasilSkenario)
class HasilSkenarioAdmin(admin.ModelAdmin):
    list_display = ("skenario", "dihitung", "durasi_detik")
    exclude = ("data",)
