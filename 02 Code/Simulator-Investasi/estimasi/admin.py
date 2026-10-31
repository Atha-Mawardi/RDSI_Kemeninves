from django.contrib import admin

from .models import KoefisienSektoral, SetParameter


@admin.register(SetParameter)
class SetParameterAdmin(admin.ModelAdmin):
    list_display = ("nama", "sumber", "b1", "b2", "crs", "n_obs", "bawaan")
    list_filter = ("sumber", "crs")


@admin.register(KoefisienSektoral)
class KoefisienSektoralAdmin(admin.ModelAdmin):
    list_display = ("nama", "primer", "sekunder", "tva", "bawaan")
