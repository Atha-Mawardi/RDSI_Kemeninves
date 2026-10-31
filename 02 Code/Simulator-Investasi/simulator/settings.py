"""
Pengaturan Simulator Investasi dan TFP Provinsi.

Rahasia dan mode debug dibaca dari environment supaya berkas ini aman masuk git.
Nilai bawaan cocok untuk dipakai di laptop analis.
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
# Akar repositori RDSI_Kemeninves, dipakai perintah muat_data_awal.
REPO_DIR = BASE_DIR.parent.parent

SECRET_KEY = os.environ.get(
    "SIMULATOR_SECRET_KEY",
    "dev-only-ganti-di-server-6b1f0e0c7d6a4c2f9a3e",
)
DEBUG = os.environ.get("SIMULATOR_DEBUG", "1") == "1"
ALLOWED_HOSTS = os.environ.get("SIMULATOR_HOSTS", "localhost,127.0.0.1").split(",")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.humanize",
    "datapanel",
    "estimasi",
    "simulasi",
    "io_irio",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "simulator.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "datapanel.context_processors.versi_aktif",
                "simulasi.context_processors.skenario_aktif",
            ],
        },
    },
]

WSGI_APPLICATION = "simulator.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "id"
TIME_ZONE = "Asia/Jakarta"
USE_I18N = True
USE_TZ = True
USE_THOUSAND_SEPARATOR = False

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"

MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Batas unggah 25 MB: workbook dataset agregasi sekitar 1 MB.
DATA_UPLOAD_MAX_MEMORY_SIZE = 25 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 25 * 1024 * 1024
