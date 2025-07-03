#!/usr/bin/env bash

set -euo pipefail

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
DEF='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BACKUPS_DIR="${SCRIPT_DIR}/../data/backups"

WORKDIR=$(mktemp -d)

cleanup() {
  rv=$?
  set +e
  echo -e "${R}Unexpected error, exit code: $rv, cleaning up.${DEF}"
  rm -rf "$WORKDIR" || true
  exit $rv
}

trap cleanup EXIT

echo -e "${G}Restoring from latest backup${DEF}"

# Check if backups directory exists
if [ ! -d "$BACKUPS_DIR" ]; then
    echo -e "${R}Error: Backups directory not found at $BACKUPS_DIR${DEF}"
    exit 1
fi

# Find the latest backup file
LATEST_BACKUP=$(find "$BACKUPS_DIR" -name "shutter-api-keyper-*.tar.xz" -type f | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo -e "${R}Error: No backup files found in $BACKUPS_DIR${DEF}"
    exit 1
fi

echo -e "${B}Found latest backup: ${Y}$(basename "$LATEST_BACKUP")${DEF}"

# Confirm with user
echo -e "${Y}WARNING: This will overwrite existing data!${DEF}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${R}Restore cancelled.${DEF}"
    exit 0
fi

echo -e "${B}[1/6] Stopping services...${DEF}"
docker compose down || true

echo -e "${B}[2/6] Extracting backup archive...${DEF}"
docker run --rm -v "$LATEST_BACKUP:/backup.tar.xz:ro" -v "$WORKDIR:/extract" alpine:3.20.1 ash -c "apk -q --no-progress --no-cache add xz && tar -xf /backup.tar.xz -C /extract"

echo -e "${B}[3/6] Restoring chain data...${DEF}"
if [ -d "$WORKDIR/chain" ]; then
    mkdir -p "${SCRIPT_DIR}/../data/chain"
    rm -rf "${SCRIPT_DIR}/../data/chain"
    cp -a "$WORKDIR/chain" "${SCRIPT_DIR}/../data/chain"
    echo -e "${G}✓ Chain data restored${DEF}"
else
    echo -e "${Y}⚠ No chain data found in backup${DEF}"
    exit 1
fi

echo -e "${B}[4/6] Restoring keyper configuration...${DEF}"
if [ -d "$WORKDIR/keyper-config" ]; then
    mkdir -p "${SCRIPT_DIR}/../config"
    rm -rf "${SCRIPT_DIR}/../config"
    cp -a "$WORKDIR/keyper-config" "${SCRIPT_DIR}/../config"
    echo -e "${G}✓ Keyper configuration restored${DEF}"
else
    echo -e "${Y}⚠ No keyper-config found in backup${DEF}"
    exit 1
fi

echo -e "${B}[5/6] Restoring database dump...${DEF}"
if [ -f "$WORKDIR/keyper.dump" ]; then
    mkdir -p "${SCRIPT_DIR}/../data/db-data"
    cp "$WORKDIR/keyper.dump" "${SCRIPT_DIR}/../data/db-data/keyper.dump"
    echo -e "${G}✓ Database dump restored${DEF}"
else
    echo -e "${Y}⚠ No database dump found in backup${DEF}"
    exit 1
fi

echo -e "${B}[6/6] Restoring environment variables...${DEF}"
if [ -f "$WORKDIR/metrics-config/settings.env" ]; then
    # Read the restored settings and update .env file
    source "$WORKDIR/metrics-config/settings.env"
    
    # Update the .env file with restored values
    if [ -f "${SCRIPT_DIR}/../.env" ]; then
        # Backup current .env
        cp "${SCRIPT_DIR}/../.env" "${SCRIPT_DIR}/../.env.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update PUSHGATEWAY variables in .env
        sed -i.bak "s/^PUSHGATEWAY_URL=.*/PUSHGATEWAY_URL=${PUSHGATEWAY_URL:-}/" "${SCRIPT_DIR}/../.env"
        sed -i.bak "s/^PUSHGATEWAY_USERNAME=.*/PUSHGATEWAY_USERNAME=${PUSHGATEWAY_USERNAME:-}/" "${SCRIPT_DIR}/../.env"
        sed -i.bak "s/^PUSHGATEWAY_PASSWORD=.*/PUSHGATEWAY_PASSWORD=${PUSHGATEWAY_PASSWORD:-}/" "${SCRIPT_DIR}/../.env"
        
        # Clean up backup files
        rm -f "${SCRIPT_DIR}/../.env.bak"
        
        echo -e "${G}✓ Environment variables restored${DEF}"
    else
        echo -e "${Y}⚠ .env file not found, skipping environment restore${DEF}"
    fi
else
    echo -e "${Y}⚠ No metrics-config/settings.env found in backup${DEF}"
fi

echo -e "${B}Cleaning up...${DEF}"
rm -rf "$WORKDIR"

echo -e "${G}Restore completed successfully!${DEF}"
echo -e "${Y}Next steps:${DEF}"
echo -e "1. Review the restored configuration files"
echo -e "2. Start the services: ${B}docker compose up -d${DEF}"
echo -e "3. The database will be automatically restored on first startup"

trap - EXIT
