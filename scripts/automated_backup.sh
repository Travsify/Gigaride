#!/usr/bin/env bash
# ==============================================================================
# GIGA RIDE ENTERPRISE DISASTER RECOVERY & CONTINUOUS SNAPSHOT ENGINE
# ==============================================================================
set -euo pipefail

BACKUP_DIR="/var/backups/giga"
SOURCE_FILE="/var/www/giga/data/data_store.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_ARCHIVE="${BACKUP_DIR}/giga_backup_${TIMESTAMP}.tar.gz"
CHECKSUM_FILE="${BACKUP_DIR}/giga_backup_${TIMESTAMP}.sha256"

mkdir -p "${BACKUP_DIR}"

if [ ! -f "${SOURCE_FILE}" ]; then
  if [ -f "/var/www/giga/data_store.json" ]; then
    SOURCE_FILE="/var/www/giga/data_store.json"
  else
    echo "[Backup Error] Datastore file not found."
    exit 1
  fi
fi

# 1. Create compressed archive
tar -czf "${BACKUP_ARCHIVE}" -C "$(dirname "${SOURCE_FILE}")" "$(basename "${SOURCE_FILE}")"

# 2. Generate SHA-256 integrity checksum
sha256sum "${BACKUP_ARCHIVE}" > "${CHECKSUM_FILE}"

# 3. Rotate archives older than 30 days
find "${BACKUP_DIR}" -name "giga_backup_*.tar.gz" -type f -mtime +30 -delete
find "${BACKUP_DIR}" -name "giga_backup_*.sha256" -type f -mtime +30 -delete

echo "✓ Backup created successfully: ${BACKUP_ARCHIVE}"
echo "✓ Checksum: $(cat "${CHECKSUM_FILE}")"
