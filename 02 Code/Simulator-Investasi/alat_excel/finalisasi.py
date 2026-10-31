"""Finalisasi lewat Microsoft Excel (macOS): hitung ulang penuh, segarkan PivotTable, simpan.

Workbook tetap sah tanpa langkah ini (Excel menghitung ulang saat dibuka), tetapi nilai tersimpan
membuat pratinjau, Google Sheets, dan pembaca tanpa mesin hitung menampilkan angka.
"""

import shutil
import subprocess
import sys

SKRIP = r'''
on run argv
    set f to item 1 of argv
    with timeout of 900 seconds
    tell application "Microsoft Excel"
        set display alerts to false
        set calculation to calculation automatic
        open (POSIX file f)
        set wb to active workbook
        calculate full
        set n to 0
        repeat with i from 1 to (count of worksheets of wb)
            set ws to worksheet i of wb
            set k to 0
            try
                set k to count of pivot tables of ws
            end try
            repeat with j from 1 to k
                refresh table (pivot table j of ws)
                set n to n + 1
            end repeat
        end repeat
        calculate full
        activate object worksheet "Beranda" of wb
        save wb
        close wb saving no
        return "pivot disegarkan: " & n
    end tell
    end timeout
end run
'''


def finalisasi(berkas):
    if sys.platform != "darwin" or not shutil.which("osascript"):
        return "Finalisasi Excel dilewati (bukan macOS); Excel akan menghitung ulang saat berkas dibuka."
    hasil = subprocess.run(["osascript", "-e", SKRIP, str(berkas)], capture_output=True, text=True, timeout=900)
    if hasil.returncode != 0:
        return f"Finalisasi Excel gagal: {hasil.stderr.strip()}. Berkas tetap bisa dibuka (dihitung saat dibuka)."
    return "Finalisasi Excel: " + hasil.stdout.strip()
