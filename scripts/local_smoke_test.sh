#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="nps-reporting:dev"
PORT=8080

echo "[+] Building Docker image..."
docker build -f "${ROOT}/app/Dockerfile" -t "${IMAGE_NAME}" "${ROOT}"

echo "[+] Running container..."
docker run --rm -d --name nps-reporting -p ${PORT}:8080 -e APP_ENV=dev "${IMAGE_NAME}"

# Give the app a moment to boot
sleep 5

echo "[+] Checking /health..."
curl -sf "http://localhost:${PORT}/health" | (command -v jq >/dev/null && jq . || cat)

echo "[+] Checking /metrics (first 10 lines)..."
curl -sf "http://localhost:${PORT}/metrics" | head

echo "[+] Stopping container..."
docker stop nps-reporting >/dev/null

echo "[✔] Local smoke test passed."
