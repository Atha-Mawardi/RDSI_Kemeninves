from django.contrib import admin

from .models import Observasi, Provinsi, VersiData


@admin.register(Provinsi)
class ProvinsiAdmin(admin.ModelAdmin):
    list_display = ("kode", "nama", "pulau")


@admin.register(VersiData)
class VersiDataAdmin(admin.ModelAdmin):
    list_display = ("pk", "nama", "status", "sumber", "tahun_awal", "tahun_akhir", "n_baris", "dibuat")
    list_filter = ("status", "sumber")


@admin.register(Observasi)
class ObservasiAdmin(admin.ModelAdmin):
    list_display = ("versi", "provinsi", "tahun")
    list_filter = ("versi", "tahun")
