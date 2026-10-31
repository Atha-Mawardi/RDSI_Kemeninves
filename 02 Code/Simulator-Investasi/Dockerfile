FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 SIMULATOR_DEBUG=0 PORT=8000
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
# Snapshot data (deploy/) menjadi basis data dan berkas IO situs; perubahan pengguna hilang saat kontainer dimulai ulang.
RUN cp deploy/db.sqlite3 db.sqlite3 && rm -rf media && cp -R deploy/media media \
    && python manage.py migrate --noinput && python manage.py collectstatic --noinput \
    && useradd -m -u 1000 app && chown -R app /app
USER app

EXPOSE 8000
CMD ["sh", "-c", "exec gunicorn simulator.wsgi --bind 0.0.0.0:${PORT} --workers 1 --threads 4 --timeout 300"]
