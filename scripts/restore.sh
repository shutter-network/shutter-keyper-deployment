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
    echo "Restores from the latest backup in the specified directory."
    echo ""
    echo "Arguments:"
    echo "  BACKUP_DIRECTORY    Directory containing backup files (default: $DEFAULT_BACKUPS_DIR)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use default backup directory"
    echo "  $0 /path/to/backups         # Use custom backup directory"
    echo "  $0 -h                       # Show this help message"
    exit 0
fi

# Parse command line arguments
BACKUPS_DIR="${1:-$DEFAULT_BACKUPS_DIR}"

WORKDIR=$(mktemp -d)

cleanup() {
  rv=$?
  set +e
  
  rm -rf "$WORKDIR" || true
  
  if [ $rv -ne 0 ]; then
    echo -e "${R}Unexpected error, exit code: $rv${DEF}"
  fi
  
  exit $rv
}

trap cleanup EXIT

echo -e "${G}Restoring from latest backup${DEF}"
echo -e "${B}Backup directory: ${Y}$BACKUPS_DIR${DEF}"

if [ ! -d "$BACKUPS_DIR" ]; then
    echo -e "${R}Error: Backups directory not found at $BACKUPS_DIR${DEF}"
    exit 1
fi

LATEST_BACKUP=$(find "$BACKUPS_DIR" -name "shutter-api-keyper-*.tar.xz" -type f | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo -e "${R}Error: No backup files found in $BACKUPS_DIR${DEF}"
    exit 1
fi

echo -e "${B}Found latest backup: ${Y}$(basename "$LATEST_BACKUP")${DEF}"

echo -e "${Y}WARNING: This will overwrite existing data!${DEF}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${R}Restore cancelled.${DEF}"
    exit 0
fi

echo -e "${B}[1/6] Stopping services...${DEF}"
cd "$SCRIPT_DIR"
docker compose down

echo -e "${B}[2/6] Extracting backup archive...${DEF}"
docker run --rm -v "$LATEST_BACKUP:/backup.tar.xz:ro" -v "$WORKDIR:/extract" alpine:3.20.1 ash -c "apk -q --no-progress --no-cache add xz && tar -xf /backup.tar.xz -C /extract"

echo -e "${B}[2.5/6] Validating backup contents...${DEF}"
MISSING_COMPONENTS=()

if [ ! -d "$WORKDIR/chain" ]; then
    MISSING_COMPONENTS+=("chain data")
fi

if [ ! -d "$WORKDIR/keyper-config" ]; then
    MISSING_COMPONENTS+=("keyper configuration")
fi

if [ ! -f "$WORKDIR/keyper.dump" ]; then
    MISSING_COMPONENTS+=("database dump")
fi

if [ ${#MISSING_COMPONENTS[@]} -gt 0 ]; then
    echo -e "${R}Error: Backup is incomplete. Missing components:${DEF}"
    for component in "${MISSING_COMPONENTS[@]}"; do
        echo -e "${R}  - $component${DEF}"
    done
    echo -e "${R}This backup appears to be corrupted or incomplete. Cannot proceed with restore.${DEF}"
    exit 1
fi

echo -e "${G}✓ Backup validation passed - all required components found${DEF}"

echo -e "${B}[3/6] Restoring chain data...${DEF}"
rm -rf "${SCRIPT_DIR}/../data/chain" || true
cp -a "$WORKDIR/chain" "${SCRIPT_DIR}/../data/chain"
echo -e "${G}✓ Chain data restored${DEF}"

echo -e "${B}[4/6] Restoring keyper configuration...${DEF}"
rm -rf "${SCRIPT_DIR}/../config" || true
cp -a "$WORKDIR/keyper-config" "${SCRIPT_DIR}/../config"
echo -e "${G}✓ Keyper configuration restored${DEF}"

echo -e "${B}[5/6] Restoring database dump...${DEF}"
mkdir -p "${SCRIPT_DIR}/../data/db-dump"
cp "$WORKDIR/keyper.dump" "${SCRIPT_DIR}/../data/db-dump/keyper.dump"
echo -e "${G}✓ Database dump restored${DEF}"

echo -e "${B}[6/6] Restoring environment configuration...${DEF}"
if [ -f "$WORKDIR/env-config/.env" ]; then
    if [ -f "${SCRIPT_DIR}/../.env" ]; then
        cp "${SCRIPT_DIR}/../.env" "${SCRIPT_DIR}/../.env.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cp "$WORKDIR/env-config/.env" "${SCRIPT_DIR}/../.env"
    echo -e "${G}✓ Environment configuration restored${DEF}"
    echo -e "${Y}⚠ You'll need to set your SIGNING_KEY manually${DEF}"
else
    echo -e "${Y}⚠ No env-config/.env found in backup${DEF}"
fi

echo -e "${B}Cleaning up...${DEF}"
rm -rf "$WORKDIR"

echo -e "${G}Restore completed successfully!${DEF}"
echo -e "${Y}Next steps:${DEF}"
echo -e "1. Review the restored configuration files"
echo -e "2. Start the services: ${B}docker compose up -d${DEF}"
echo -e "3. The database will be automatically restored on first startup"

trap - EXIT
