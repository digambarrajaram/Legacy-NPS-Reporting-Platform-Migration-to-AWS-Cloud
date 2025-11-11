#!/usr/bin/env bash
set -euo pipefail

# 02_snapshot.sh
# Usage:
#   ./02_snapshot.sh onprem   # runs pg_basebackup (requires SSH access / local postgres tools)
#   ./02_snapshot.sh rds      # triggers aws rds create-db-snapshot (for RDS)
#
# Edit placeholders below before running.

MODE="${1:-onprem}"   # onprem | rds

# -----------------------
# Common placeholders
# -----------------------
SOURCE_PG_HOST="SOURCE_PG_HOST_OR_IP"
SOURCE_PG_PORT="5432"
SOURCE_PG_USER="postgres"
SOURCE_PG_DB="postgres"
BACKUP_DIR="/tmp/pg_migration_snapshot"
SNAPSHOT_TAG="$(date +%Y%m%d%H%M%S)"
AWS_REGION="${AWS_REGION:-ap-south-1}"
RDS_INSTANCE_IDENTIFIER="YOUR_RDS_SOURCE_INSTANCE"  # only for rds mode
# -----------------------

if [[ "$MODE" == "onprem" ]]; then
  echo "[+] Creating on-prem logical snapshot using pg_dump (safe logical dump)"
  mkdir -p "${BACKUP_DIR}"
  DUMP_FILE="${BACKUP_DIR}/pg_dump_${SNAPSHOT_TAG}.sql.gz"

  # Logical dump of schema and data. For large DBs, consider pg_dump -Fd (directory) and parallel jobs.
  echo "[+] Running pg_dump (this will stream, may take time)..."
  PGPASSWORD="${PGPASSWORD:-}" \
    pg_dump -h "${SOURCE_PG_HOST}" -p "${SOURCE_PG_PORT}" -U "${SOURCE_PG_USER}" -Fc -d "${SOURCE_PG_DB}" -f "${DUMP_FILE%.gz}"

  echo "[+] gzipping (if needed)"
  gzip -f "${DUMP_FILE%.gz}"

  echo "[✔] Dump created: ${DUMP_FILE}.gz"
  exit 0

elif [[ "$MODE" == "rds" ]]; then
  echo "[+] Creating snapshot for RDS instance: ${RDS_INSTANCE_IDENTIFIER}"
  SNAP_NAME="${RDS_INSTANCE_IDENTIFIER}-migration-${SNAPSHOT_TAG}"

  aws rds create-db-snapshot \
    --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" \
    --db-snapshot-identifier "${SNAP_NAME}" \
    --region "${AWS_REGION}"

  echo "[+] Snapshot requested: ${SNAP_NAME}"
  echo "[+] Wait until snapshot is 'available':"
  echo "    aws rds wait db-snapshot-available --db-instance-identifier ${RDS_INSTANCE_IDENTIFIER} --db-snapshot-identifier ${SNAP_NAME} --region ${AWS_REGION}"
  exit 0
else
  echo "Usage: $0 {onprem|rds}"
  exit 2
fi
