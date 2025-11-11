#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-http://localhost:8080}"
echo "[+] Checking health at ${HOST}/health"
curl -sf "${HOST}/health" || (echo "Health check failed" && exit 2)

echo "[+] Checking metrics endpoint"
curl -sf "${HOST}/metrics" | head -n 20 || (echo "Metrics check failed" && exit 3)

echo "[+] Acceptance checks passed"
exit 0
