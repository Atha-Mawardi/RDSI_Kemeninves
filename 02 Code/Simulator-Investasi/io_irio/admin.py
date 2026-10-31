from django.contrib import admin

from .models import TabelIO


@admin.register(TabelIO)
class TabelIOAdmin(admin.ModelAdmin):
    list_display = ("jenis", "tahun", "metode", "sumber", "dimuat")
    list_filter = ("jenis", "metode")
