#!/usr/bin/env bash

set -euo pipefail

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
DEF='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Default backup directory
DEFAULT_BACKUPS_DIR="${SCRIPT_DIR}/../data/backups"

# Show usage if help is requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [BACKUP_DIRECTORY]"
    echo ""
    echo "Creates a backup archive of the shutter-keyper deployment."
    echo ""
    echo "Arguments:"
    echo "  BACKUP_DIRECTORY    Directory to store the backup (default: $DEFAULT_BACKUPS_DIR)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use default backup directory"
    echo "  $0 /path/to/backups         # Use custom backup directory"
    echo "  $0 -h                       # Show this help message"
    exit 0
fi

# Parse command line arguments
BACKUPS_DIR="${1:-$DEFAULT_BACKUPS_DIR}"

ARCHIVE_NAME="gnosis-keyper-$(date +%Y-%m-%dT%H-%M-%S).tar.xz"

source "${SCRIPT_DIR}/../.env"

mkdir -p "$BACKUPS_DIR"
WORKDIR=$(mktemp -d -p "${BACKUPS_DIR}")

cleanup_and_restart() {
  rv=$?
  set +e

  rm -rf "$WORKDIR"
  docker compose start

  if [ $rv -ne 0 ]; then
    echo -e "${R}Unexpected error, exit code: $rv${DEF}"
  fi

  exit $rv
}

trap cleanup_and_restart EXIT

echo -e "${G}Creating backup archive${DEF}"
echo -e "${B}Backup directory: ${Y}$BACKUPS_DIR${DEF}"

echo -e "${B}[1/6] Stopping all services except database...${DEF}"
docker compose stop keyper
docker compose stop chain

echo -e "${B}[2/6] Creating database dump...${DEF}"
docker compose exec db pg_dump -U postgres -d keyper -Fc --create --clean -f /var/lib/postgresql/data/keyper.dump

echo -e "${B}[3/6] Stopping database...${DEF}"
docker compose stop db

echo -e "${B}[4/6] Copying data...${DEF}"
cp -a "${SCRIPT_DIR}/../data/chain/" "${WORKDIR}/chain"
cp -a "${SCRIPT_DIR}/../data/db/keyper.dump" "${WORKDIR}/keyper.dump"
cp -a "${SCRIPT_DIR}/../config" "${WORKDIR}/keyper-config"

KEYPER_TOML="${WORKDIR}/keyper-config/keyper.toml"
if [ -f "$KEYPER_TOML" ]; then
    sed -i 's|\(PrivateKey\s*=\s*\).*|\1"PLACEHOLDER_REPLACE_WITH_YOUR_PRIVATE_KEY"|' "$KEYPER_TOML"
    echo -e "${G}✓ keyper.toml backed up (private key replaced with placeholder)${DEF}"
else
    echo -e "${Y}⚠ keyper.toml not found in config, skipping private key sanitization${DEF}"
fi

mkdir -p "${WORKDIR}/env-config"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    sed 's/^SIGNING_KEY=.*/SIGNING_KEY=PLACEHOLDER_REPLACE_WITH_YOUR_PRIVATE_KEY/' "${SCRIPT_DIR}/../.env" > "${WORKDIR}/env-config/.env"
    echo -e "${G}✓ Environment configuration backed up (private key replaced with placeholder)${DEF}"
else
    echo -e "${Y}⚠ .env file not found, skipping environment backup${DEF}"
fi

echo -e "${B}[5/6] Compressing archive...${DEF}"
docker run --rm -i -v "${WORKDIR}:/workdir" -v "$BACKUPS_DIR:/data" alpine:3.20.1 ash -c "apk -q --no-progress --no-cache add xz pv && tar -cf - -C /workdir . | pv -petabs \$(du -sb /workdir | cut -f 1) | xz -zq > /data/${ARCHIVE_NAME}"

echo -e "${B}[6/6] Cleaning up...${DEF}"
rm "${SCRIPT_DIR}/../data/db/keyper.dump" || true

echo -e "${G}Done, backup archive created at ${B}$BACKUPS_DIR/${ARCHIVE_NAME}${DEF}"

echo -e "\n\n${R}WARNING, IMPORTANT!${DEF}"
echo -e "${Y}If you import this backup, make sure to stop this deployment first!${DEF}"