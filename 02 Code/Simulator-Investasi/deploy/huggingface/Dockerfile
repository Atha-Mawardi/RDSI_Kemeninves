FROM python:3.14-slim

RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client \
    && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 SIMULATOR_DEBUG=0 PORT=8000

# Kode dan snapshot data diambil dari repositori GitHub privat dengan deploy key baca-saja (secret DEPLOY_KEY),
# sehingga Space publik hanya memuat berkas ini. CACHE_BUST diubah agar Space mengambil versi terbaru.
ARG CACHE_BUST=1
RUN --mount=type=secret,id=DEPLOY_KEY,mode=0444,required=true \
    install -m 600 /run/secrets/DEPLOY_KEY /tmp/kunci && echo >> /tmp/kunci \
    && export GIT_SSH_COMMAND="ssh -i /tmp/kunci -o StrictHostKeyChecking=accept-new" \
    && git clone --depth 1 --filter=blob:none --sparse git@github.com:Atha-Mawardi/RDSI_Kemeninves.git /src \
    && git -C /src sparse-checkout set "02 Code/Simulator-Investasi" \
    && mv "/src/02 Code/Simulator-Investasi" /app && rm -rf /src /tmp/kunci

WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt \
    && cp deploy/db.sqlite3 db.sqlite3 && rm -rf media && cp -R deploy/media media \
    && python manage.py migrate --noinput && python manage.py collectstatic --noinput \
    && useradd -m -u 1000 app && chown -R app /app
USER app

EXPOSE 8000
CMD ["sh", "-c", "exec gunicorn simulator.wsgi --bind 0.0.0.0:${PORT} --workers 2 --threads 4 --timeout 300"]
