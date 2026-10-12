# SCRIPT OVERVIEW --------------------------------------
# Mengalihkan tautan luar di dataset umum project dari basis modal nominal ke
# basis modal riil, lalu menambah enam kolom kontribusi pertumbuhan.
#
# Sasaran : ../../../All Dataset/Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx
# Sumber  : 03 Output (modal riil)/Hasil Estimasi TFP.xlsx      sheet data_tfp
#           03 Output (modal riil)/Panel TFP Provinsi-Tahun.xlsx sheet panel
#
# KENAPA BEDAH XML, BUKAN openpyxl ATAU openxlsx. Workbook sasaran memuat tautan
# luar, satu tabel bernama, metadata larik dinamis, dan 2.040 formula di sheet
# ICOR Estimation. Menulis ulang lewat pustaka mana pun membuang sebagian di
# antaranya tanpa memberi tahu. Yang disentuh di sini hanya anggota zip yang
# memang harus berubah; sisanya disalin apa adanya, bit demi bit.
#
# APA YANG BERUBAH DI SHEET1
#   FD-FH  tautannya dialihkan ke folder basis riil, cache disegarkan
#   FI-FN  kolom baru: g_Y, g_K, g_L, kontrib_modal, kontrib_tk, kontrib_tfp
#
# Sel sumber yang kosong ditinggal kosong, bukan diisi nol. Formula lama memakai
# INDEX telanjang, dan INDEX atas sel kosong mengembalikan nol; itu sebabnya baris
# 2025 sebelumnya tercatat log tenaga kerja nol padahal datanya belum terbit.
# Formula FD-FH ikut dibungkus penjaga yang sama dengan kolom baru, jadi 2025
# terbaca kosong baik oleh R maupun oleh Excel sesudah tautan disegarkan.
#
# Jalankan dari root sub-project TFP:
#   PYTHONIOENCODING=utf-8 python3 "02 Code/14_perbarui tautan dataset umum.py"

import os
import re
import shutil
import sys
import zipfile

import openpyxl

DIR_OUT = "03 Output (modal riil)"
DIR_DATASET = "../../../All Dataset"
NAMA_XLSX = "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar.xlsx"

f_sasaran = os.path.join(DIR_DATASET, NAMA_XLSX)
f_est = os.path.join(DIR_OUT, "Hasil Estimasi TFP.xlsx")
f_panel = os.path.join(DIR_OUT, "Panel TFP Provinsi-Tahun.xlsx")
for f in (f_sasaran, f_est, f_panel):
    assert os.path.exists(f), f"tidak ada: {f}"

# Jalur lama yang harus lenyap dari seluruh berkas rels, dan penggantinya.
LAMA_URL = "03%20Output/"
BARU_URL = "03%20Output%20(modal%20riil)/"

# Kolom sumber -> kolom tujuan di Sheet1. Huruf kolom sumber mengikuti urutan
# kolom sheet data_tfp dan sheet panel apa adanya; kalau skrip 01 atau 13 menukar
# urutan kolomnya, assertion judul di bawah yang menangkapnya.
PETA_LAMA = [("F", "FD", "log_ADHK_Tot"), ("G", "FE", "log_pmtb"),
             ("H", "FF", "log_lab_tot"), ("I", "FG", "logtfp_it"),
             ("J", "FH", "logtfp_it_crs")]
PETA_BARU = [("G", "FI", "g_Y"), ("H", "FJ", "g_K"), ("I", "FK", "g_L"),
             ("J", "FL", "kontrib_modal"), ("K", "FM", "kontrib_tk"),
             ("L", "FN", "kontrib_tfp")]


def baca_sheet(path, nama_sheet):
    """Baca satu sheet jadi (judul, daftar baris). read_only melewati gambar
    tertanam yang membuat openpyxl gagal membuka berkas keluaran skrip 01."""
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb[nama_sheet]
    ws.reset_dimensions()
    baris = list(ws.iter_rows(values_only=True))
    wb.close()
    return baris[0], baris[1:]


def huruf_ke_indeks(huruf):
    n = 0
    for c in huruf:
        n = n * 26 + (ord(c) - 64)
    return n - 1


def angka_xml(x):
    """Format angka seperti Excel menulisnya: cukup digit untuk pulang-pergi."""
    return repr(float(x))


def kunci(tahun, provinsi):
    """Kunci gabungan yang ditiru dari formula: $B & $C = Year & Pre_Prov."""
    return "%d|%s" % (int(tahun), provinsi)


# ==============================================================================
# 1. Baca kedua sumber
# ==============================================================================
judul_est, baris_est = baca_sheet(f_est, "data_tfp")
judul_pan, baris_pan = baca_sheet(f_panel, "panel")

# Judul dipastikan lebih dulu. Kalau urutan kolom sumber bergeser, seluruh
# pemetaan huruf kolom di atas jadi salah tanpa gejala apa pun di hasilnya.
for huruf, _, nama in PETA_LAMA:
    assert judul_est[huruf_ke_indeks(huruf)] == nama, (huruf, nama, judul_est)
for huruf, _, nama in PETA_BARU:
    assert judul_pan[huruf_ke_indeks(huruf)] == nama, (huruf, nama, judul_pan)
assert judul_est[1] == "Pre_Prov" and judul_est[3] == "Year"
assert judul_pan[1] == "Pre_Prov" and judul_pan[3] == "Year"
assert len(baris_est) == 306, len(baris_est)
assert len(baris_pan) == 272, len(baris_pan)

nilai_est = {}
for b in baris_est:
    nilai_est[kunci(b[3], b[1])] = b
nilai_pan = {}
for b in baris_pan:
    nilai_pan[kunci(b[3], b[1])] = b
assert len(nilai_est) == 306 and len(nilai_pan) == 272

print("Sumber terbaca: data_tfp %d baris, panel %d baris" % (len(baris_est), len(baris_pan)))

# ==============================================================================
# 2. Cadangan
# ==============================================================================
dir_arsip = os.path.join(DIR_DATASET, "99 Arsip")
os.makedirs(dir_arsip, exist_ok=True)
f_cadangan = os.path.join(
    dir_arsip, "Dataset Agregasi Provinsi Penyetaraan Satuan Miliar (sebelum basis riil).xlsx")
# Cadangan tidak pernah ditimpa. Skrip yang dijalankan dua kali akan menyalin
# berkas yang sudah dibedah, dan cadangan aslinya hilang tanpa jejak.
if os.path.exists(f_cadangan):
    print("Cadangan sudah ada, dibiarkan: %s" % f_cadangan)
else:
    shutil.copy2(f_sasaran, f_cadangan)
    assert os.path.getsize(f_cadangan) == os.path.getsize(f_sasaran)
    print("Cadangan: %s (%d byte)" % (f_cadangan, os.path.getsize(f_cadangan)))

# ==============================================================================
# 3. Muat seluruh isi zip
# ==============================================================================
with zipfile.ZipFile(f_sasaran) as z:
    urutan = z.namelist()
    isi = {n: z.read(n) for n in urutan}
anggota_awal = set(urutan)
print("Anggota zip: %d" % len(urutan))


def teks(nama):
    return isi[nama].decode("utf-8")


def simpan(nama, s):
    isi[nama] = s.encode("utf-8")


# ==============================================================================
# 4. Tautan 1: alihkan target, segarkan cache
# ==============================================================================
n_rels1 = "xl/externalLinks/_rels/externalLink1.xml.rels"
s = teks(n_rels1)
n_ganti = s.count(LAMA_URL)
assert n_ganti == 3, "target lama ditemukan %d kali, seharusnya 3" % n_ganti
simpan(n_rels1, s.replace(LAMA_URL, BARU_URL))
print("Tautan 1 dialihkan pada %d target." % n_ganti)

# Cache sheet data_tfp ditulis ulang penuh. Sel sumber yang kosong tidak ditulis,
# persis seperti Excel menulisnya; INDEX atas sel kosong memang mengembalikan nol.
n_link1 = "xl/externalLinks/externalLink1.xml"
s = teks(n_link1)
assert '<sheetName val="data_tfp"/>' in s

potongan = []
for i, b in enumerate(baris_est):
    r = i + 2
    sel = ['<cell r="B%d" t="str"><v>%s</v></cell>' % (r, b[1]),
           '<cell r="D%d"><v>%d</v></cell>' % (r, int(b[3]))]
    for huruf, _, _ in PETA_LAMA:
        v = b[huruf_ke_indeks(huruf)]
        if v is not None:
            sel.append('<cell r="%s%d"><v>%s</v></cell>' % (huruf, r, angka_xml(v)))
    potongan.append('<row r="%d">%s</row>' % (r, "".join(sel)))

blok_baru = '<sheetData sheetId="8">%s</sheetData>' % "".join(potongan)
s, n = re.subn(r'<sheetData sheetId="8">.*?</sheetData>', lambda m: blok_baru, s, flags=re.S)
assert n == 1, "blok cache data_tfp tidak ketemu"
simpan(n_link1, s)
print("Cache tautan 1 ditulis ulang: %d baris." % len(potongan))

# ==============================================================================
# 5. Tautan 2: berkas panel
# ==============================================================================
NS_LINK = ('xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
           'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
           'mc:Ignorable="x14" '
           'xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"')

potongan = []
for i, b in enumerate(baris_pan):
    r = i + 2
    sel = ['<cell r="B%d" t="str"><v>%s</v></cell>' % (r, b[1]),
           '<cell r="D%d"><v>%d</v></cell>' % (r, int(b[3]))]
    for huruf, _, _ in PETA_BARU:
        v = b[huruf_ke_indeks(huruf)]
        if v is not None:
            sel.append('<cell r="%s%d"><v>%s</v></cell>' % (huruf, r, angka_xml(v)))
    potongan.append('<row r="%d">%s</row>' % (r, "".join(sel)))

nama_sheet_pan = ["panel", "rata_provinsi", "catatan", "kaveat"]
link2 = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'
         '<externalLink %s>'
         '<externalBook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId1">'
         '<sheetNames>%s</sheetNames>'
         '<sheetDataSet><sheetData sheetId="0">%s</sheetData>'
         '<sheetData sheetId="1"/><sheetData sheetId="2"/><sheetData sheetId="3"/>'
         '</sheetDataSet></externalBook></externalLink>') % (
    NS_LINK,
    "".join('<sheetName val="%s"/>' % n for n in nama_sheet_pan),
    "".join(potongan))
simpan("xl/externalLinks/externalLink2.xml", link2)

jalur_panel = ("../BKPM-local/TFP%20calc/TFP%20analysis%20(07182026)/"
               "03%20Output%20(modal%20riil)/Panel%20TFP%20Provinsi-Tahun.xlsx")
simpan("xl/externalLinks/_rels/externalLink2.xml.rels",
       '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'
       '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
       '<Relationship Id="rId1" '
       'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLinkPath" '
       'Target="%s" TargetMode="External"/></Relationships>' % jalur_panel)
print("Tautan 2 dibuat: %d baris cache." % len(potongan))

# Daftarkan di [Content_Types].xml
n_ct = "[Content_Types].xml"
s = teks(n_ct)
tipe_link = ('<Override PartName="/xl/externalLinks/externalLink2.xml" '
             'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.externalLink+xml"/>')
assert "/xl/externalLinks/externalLink1.xml" in s
s = s.replace("</Types>", tipe_link + "</Types>")
# calcChain dibuang, jadi override-nya ikut dibuang. Excel menyusunnya ulang.
s = re.sub(r'<Override PartName="/xl/calcChain\.xml"[^/]*/>', "", s)
simpan(n_ct, s)

# Daftarkan di workbook.xml.rels
n_wbrels = "xl/_rels/workbook.xml.rels"
s = teks(n_wbrels)
ada = set(re.findall(r'Id="(rId\d+)"', s))
rid_link2 = next("rId%d" % i for i in range(1, 100) if "rId%d" % i not in ada)
rel_link2 = ('<Relationship Id="%s" '
             'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink" '
             'Target="externalLinks/externalLink2.xml"/>' % rid_link2)
s = s.replace("</Relationships>", rel_link2 + "</Relationships>")
s = re.sub(r'<Relationship Id="[^"]*"[^>]*Target="calcChain\.xml"/>', "", s)
simpan(n_wbrels, s)

# Daftarkan di workbook.xml. Urutan externalReference menentukan nomor [1] dan
# [2] di dalam formula, jadi tautan panel harus jadi yang kedua.
n_wb = "xl/workbook.xml"
s = teks(n_wb)
assert "<externalReferences><externalReference r:id=" in s
s = s.replace("</externalReferences>",
              '<externalReference r:id="%s"/></externalReferences>' % rid_link2)
# fullCalcOnLoad: cache yang ditulis skrip ini hanya bekal sementara. Excel wajib
# menghitung ulang saat berkas dibuka, supaya nilainya datang dari berkas sumber.
if "<calcPr" in s:
    s = re.sub(r'<calcPr([^/>]*)/>', r'<calcPr\1 fullCalcOnLoad="1"/>', s, count=1)
else:
    s = s.replace("</workbook>", '<calcPr fullCalcOnLoad="1"/></workbook>')
simpan(n_wb, s)
print("Tautan 2 terdaftar sebagai %s, nomor [2] di formula." % rid_link2)

# ==============================================================================
# 6. Sheet1 (secara fisik sheet2.xml)
# ==============================================================================
n_sheet = "xl/worksheets/sheet2.xml"
s = teks(n_sheet)

# Kunci per baris dibaca dari sheetnya sendiri: B = Year, C = Pre_Prov (indeks
# shared string). Menebaknya dari urutan baris akan salah begitu ada baris
# tersisip, dan itu jenis kesalahan yang tidak kelihatan di hasilnya.
sst = re.findall(r"<si>(.*?)</si>", teks("xl/sharedStrings.xml"), re.S)
sst = ["".join(re.findall(r"<t[^>]*>(.*?)</t>", x, re.S)) for x in sst]


POLA_SEL = re.compile(r'<c r="([A-Z]+\d+)"([^>]*?)(?:/>|>(.*?)</c>)', re.S)


def nilai_sel(blok, ref):
    """Nilai satu sel dari potongan XML barisnya. Sel kosong ditulis Excel dalam
    dua bentuk — menutup sendiri, atau berisi tanpa <v> — dan keduanya null."""
    for m in POLA_SEL.finditer(blok):
        if m.group(1) != ref:
            continue
        if m.group(3) is None:
            return None
        v = re.search(r"<v>(.*?)</v>", m.group(3), re.S)
        if not v:
            return None
        return sst[int(v.group(1))] if 't="s"' in m.group(2) else v.group(1)
    return None


def xesc(x):
    return x.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def formula(tautan, sheet, kol_sumber, r, baris_akhir):
    """Formula pencarian, bentuknya disalin dari yang sudah ada di FD-FH.

    Dua kali INDEX, bukan satu. Sel sumber yang kosong dikembalikan INDEX sebagai
    nol, dan nol itu terbaca sebagai angka yang sebenarnya. Itu yang dulu membuat
    2025 tercatat log tenaga kerja nol, padahal datanya memang belum terbit."""
    idx = ("INDEX([{t}]{s}!{k}$2:{k}${n},MATCH($B{r}&$C{r},"
           "[{t}]{s}!$D$2:$D${n}&[{t}]{s}!$B$2:$B${n},0))").format(
        t=tautan, s=sheet, k=kol_sumber, n=baris_akhir, r=r)
    return xesc('IFERROR(IF(%s="","",%s),"")' % (idx, idx))


def sel_formula(kol, r, f, v):
    if v is None:
        return '<c r="%s%d"><f t="array" ref="%s%d">%s</f></c>' % (kol, r, kol, r, f)
    return '<c r="%s%d"><f t="array" ref="%s%d">%s</f><v>%s</v></c>' % (
        kol, r, kol, r, f, angka_xml(v))


hitung = {"judul": 0, "lama": 0, "lama_kosong": 0, "baru": 0, "kosong": 0}
potongan_judul = "".join(
    '<c r="%s1" t="inlineStr"><is><t>%s</t></is></c>' % (kol, nama)
    for _, kol, nama in PETA_BARU)


def olah_baris(m):
    blok = m.group(0)
    r = int(re.search(r'r="(\d+)"', blok).group(1))
    if r == 1:
        hitung["judul"] += 1
        return blok.replace("</row>", potongan_judul + "</row>")

    tahun = nilai_sel(blok, "B%d" % r)
    prov = nilai_sel(blok, "C%d" % r)
    assert tahun is not None and prov is not None, r
    k = kunci(float(tahun), prov)

    # 6a. Kolom lama: formula dan nilai cache-nya sama-sama ditulis ulang.
    src = nilai_est.get(k)
    assert src is not None, "baris %d tanpa pasangan di data_tfp: %s" % (r, k)
    for huruf, kol, _ in PETA_LAMA:
        v = src[huruf_ke_indeks(huruf)]
        pola = r'<c r="%s%d"[^>]*>.*?</c>' % (kol, r)
        mm = re.search(pola, blok, re.S)
        assert mm, "sel %s%d tanpa formula" % (kol, r)
        baru = sel_formula(kol, r, formula(1, "data_tfp", huruf, r, 307), v)
        blok = blok[:mm.start()] + baru + blok[mm.end():]
        hitung["lama" if v is not None else "lama_kosong"] += 1

    # 6b. Sel kolom baru.
    src = nilai_pan.get(k)
    sel = []
    for huruf, kol, _ in PETA_BARU:
        v = None if src is None else src[huruf_ke_indeks(huruf)]
        sel.append(sel_formula(kol, r, formula(2, "panel", huruf, r, 273), v))
        hitung["baru" if v is not None else "kosong"] += 1
    return blok.replace("</row>", "".join(sel) + "</row>")


s, n = re.subn(r"<row [^>]*r=\"\d+\"[^>]*>.*?</row>", olah_baris, s, flags=re.S)
assert n == 307, n
assert hitung["judul"] == 1

s = s.replace('<dimension ref="A1:FH307"/>', '<dimension ref="A1:FN307"/>')
assert '<dimension ref="A1:FN307"/>' in s
simpan(n_sheet, s)
print("Sheet1 kolom lama : %d sel berisi, %d sel kosong." % (hitung["lama"], hitung["lama_kosong"]))
print("Sheet1 kolom baru : %d sel berisi, %d sel kosong." % (hitung["baru"], hitung["kosong"]))

# ==============================================================================
# 7. Buang calcChain, tulis zip
# ==============================================================================
del isi["xl/calcChain.xml"]
urutan = [n for n in urutan if n != "xl/calcChain.xml"] + ["xl/externalLinks/externalLink2.xml",
                                                          "xl/externalLinks/_rels/externalLink2.xml.rels"]

f_tmp = f_sasaran + ".sedang-ditulis.xlsx"
with zipfile.ZipFile(f_tmp, "w", zipfile.ZIP_DEFLATED) as z:
    for n in urutan:
        z.writestr(n, isi[n])

# Bukti terakhir sebelum berkas asal ditimpa: hasilnya harus bisa dibuka.
wb = openpyxl.load_workbook(f_tmp, read_only=True, data_only=True)
ws = wb["Sheet1"]
ws.reset_dimensions()
uji = list(ws.iter_rows(min_row=1, max_row=2, values_only=True))
wb.close()
assert len(uji[0]) == 170, len(uji[0])
assert uji[0][163] == "logtfp_it_crs" and uji[0][169] == "kontrib_tfp", uji[0][158:]
assert abs(uji[1][160] - 17.4898335794066) < 1e-12, uji[1][160]

os.replace(f_tmp, f_sasaran)

with zipfile.ZipFile(f_sasaran) as z:
    akhir = set(z.namelist())
assert anggota_awal - akhir == {"xl/calcChain.xml"}, anggota_awal - akhir
assert akhir - anggota_awal == {"xl/externalLinks/externalLink2.xml",
                                "xl/externalLinks/_rels/externalLink2.xml.rels"}

print("\n=============== SELESAI ===============")
print("Berkas: %s" % os.path.abspath(f_sasaran))
print("Anggota zip: %d -> %d" % (len(anggota_awal), len(akhir)))
