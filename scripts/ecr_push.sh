#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit these or pass as env vars) ---
AWS_REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID="${ACCOUNT_ID:-123456789012}"
REPO_NAME="${REPO_NAME:-reporting}"
ECR="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%s)}"
# -----------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_LOCAL="${REPO_NAME}:latest"
IMAGE_REMOTE="${ECR}/${REPO_NAME}:${TAG}"

echo "[+] Authenticating to ECR (${AWS_REGION})..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR}"

echo "[+] Ensure ECR repo exists..."
aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "${REPO_NAME}" --region "${AWS_REGION}"

echo "[+] Building Docker image..."
docker build -f "${ROOT}/app/Dockerfile" -t "${IMAGE_LOCAL}" "${ROOT}"

echo "[+] Tagging ${IMAGE_LOCAL} -> ${IMAGE_REMOTE}"
docker tag "${IMAGE_LOCAL}" "${IMAGE_REMOTE}"

echo "[+] Pushing to ECR..."
docker push "${IMAGE_REMOTE}"

echo "[✔] Done. Image: ${IMAGE_REMOTE}"
