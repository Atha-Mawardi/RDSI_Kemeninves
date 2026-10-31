"""Unggah aplikasi ke PythonAnywhere lalu muat ulang situs.

    python deploy/pythonanywhere.py           # kode, template, dan berkas statis
    python deploy/pythonanywhere.py --data    # ditambah snapshot deploy/db.sqlite3 dan deploy/media (menimpa data situs)

Kredensial dibaca dari ~/.pa_simulator (baris 1 nama pengguna, baris 2 API token). Jalankan dari folder aplikasi
setelah `python manage.py collectstatic`. Paket baru di requirements.txt dipasang dari konsol Bash PythonAnywhere:
`~/.virtualenvs/simulator/bin/pip install -r ~/simulator/requirements.txt`.
"""

import pathlib
import subprocess
import sys
import time

PENGGUNA, TOKEN = pathlib.Path.home().joinpath(".pa_simulator").read_text().split()[:2]
API = f"https://www.pythonanywhere.com/api/v0/user/{PENGGUNA}"
TUJUAN = f"{API}/files/path/home/{PENGGUNA}/simulator/"
DOMAIN = f"{PENGGUNA}.pythonanywhere.com"


def curl(*argumen):
    return subprocess.run(["curl", "-s", "-H", f"Authorization: Token {TOKEN}", *argumen],
                          capture_output=True, text=True).stdout


def daftar_berkas(dengan_data):
    kode = subprocess.run(["git", "ls-files", "."], capture_output=True, text=True).stdout.split("\n")
    pasangan = [(f, f) for f in kode if f and not f.startswith(("docs/", "deploy/", "alat_excel/"))]
    pasangan += [(str(p), str(p)) for p in pathlib.Path("staticfiles").rglob("*") if p.is_file() and p.suffix != ".gz"]
    if dengan_data:
        pasangan += [("deploy/db.sqlite3", "db.sqlite3")]
        pasangan += [(str(p), "media/" + str(p.relative_to("deploy/media")))
                     for p in pathlib.Path("deploy/media").rglob("*") if p.is_file()]
    return pasangan


def main():
    pasangan = daftar_berkas("--data" in sys.argv)
    for i, (lokal, jauh) in enumerate(pasangan, 1):
        while (kode := curl("-o", "/dev/null", "-w", "%{http_code}", "-F", f"content=@{lokal}", TUJUAN + jauh)) == "429":
            time.sleep(20)
        if kode not in ("200", "201"):
            print("gagal", jauh, kode)
        print(f"\r{i}/{len(pasangan)}", end="", flush=True)
        time.sleep(0.5)
    print()
    print(curl("-X", "POST", f"{API}/webapps/{DOMAIN}/reload/"))


if __name__ == "__main__":
    main()
