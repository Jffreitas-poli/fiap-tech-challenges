FROM python:3.12-alpine AS builder

WORKDIR /app
COPY requirements.txt .
RUN apk add --no-cache --virtual .build-deps python3-dev build-base \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt \
    && apk del .build-deps


FROM python:3.12-alpine AS base

WORKDIR /app
COPY --from=builder /install /usr/local
COPY . .
EXPOSE 8005


FROM base AS staging

CMD ["python", "app.py"]


FROM base AS prod

CMD ["gunicorn", "--bind", "0.0.0.0:8005", "--workers", "2", "app:app"]
