# syntax=docker/dockerfile:1

FROM public.ecr.aws/docker/library/python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System deps (tzdata, ca-certs). No build tools to keep image slim.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first for better layer caching
COPY app/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy app source
COPY app/src ./src

# Non-root user
RUN useradd -m appuser
USER appuser

# Default envs (override in Helm)
ENV APP_ENV=prod \
    APP_VERSION=0.1.0 \
    PORT=8080

EXPOSE 8080

# Gunicorn (uvicorn workers) is robust behind k8s
CMD ["gunicorn", "src.main:app", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "60"]
