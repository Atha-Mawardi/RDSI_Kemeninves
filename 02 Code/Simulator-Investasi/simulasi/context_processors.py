import re

from . import aktif


def skenario_aktif(request):
    if request.path.startswith(("/admin/", "/static/")):
        return {}
    return {"sk_aktif": aktif.ambil(request), "sk_grup": aktif.grup(),
            "di_hasil": bool(re.match(r"^/skenario/\d+/$", request.path))}
