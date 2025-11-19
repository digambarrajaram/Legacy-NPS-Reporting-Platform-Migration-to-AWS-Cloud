# syntax=docker/dockerfile:1

FROM public.ecr.aws/docker/library/python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_ENV=prod \
    APP_VERSION=0.1.0 \
    PORT=8080 \
    PROMETHEUS_MULTIPROC_DIR=/tmp/prom_multiproc

# System deps (tzdata, ca-certs). No build tools to keep image slim.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first for better layer caching
# COPY paths are relative to the build context (do NOT start with /)
COPY requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy app source
COPY src ./src

# Create non-root user and prepare directories (create user first so chown succeeds)
RUN useradd -m appuser \
    && mkdir -p ${PROMETHEUS_MULTIPROC_DIR} \
    && chown -R appuser:appuser ${PROMETHEUS_MULTIPROC_DIR} /app

# Switch to non-root user for security
USER appuser

EXPOSE 8080

# Gunicorn (uvicorn workers) is robust behind k8s
CMD ["gunicorn", "src.main:app", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "60"]
