#!/usr/bin/env bash

set -euo pipefail

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
DEF='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ARCHIVE_NAME="shutter-gnosis.dnp.dappnode.eth_export-$(date +%Y-%m-%dT%H-%M-%S).tar.xz"

source "${SCRIPT_DIR}/../.env"

WORKDIR=$(mktemp -d)

cleanup() {
  rv=$?
  set +e
  echo -e "${R}Unexpected error, exit code: $rv, cleaning up.${DEF}"
#  rm -rf "$WORKDIR"
  docker compose unpause || true
  exit $rv
}

trap cleanup EXIT

echo -e "${G}Creating export package for DAppNode${DEF}"

mkdir -p "${SCRIPT_DIR}/../data/backups"

echo -e "${B}[1/5] Pausing services...${DEF}"
docker compose pause || true

echo -e "${Y}[2/5] Copying data...${DEF}"
cp -a "${SCRIPT_DIR}/../data/chain/config" "${WORKDIR}/chain-config"
cp -a "${SCRIPT_DIR}/../data/db" "${WORKDIR}/db-data"
cp -a "${SCRIPT_DIR}/../config" "${WORKDIR}/keyper-config"

mkdir -p "${WORKDIR}/metrics-config"
cat > "${WORKDIR}/metrics-config/settings.env" <<EOF
PUSHGATEWAY_URL=${PUSHGATEWAY_URL:-}
PUSHGATEWAY_USERNAME=${PUSHGATEWAY_USERNAME:-}
PUSHGATEWAY_PASSWORD=${PUSHGATEWAY_PASSWORD:-}
EOF

echo -e "${B}[3/5] Resuming services...${DEF}"
docker compose unpause || true

echo -e "${Y}[4/5] Compressing archive...${DEF}"
docker run --rm -it -v "${WORKDIR}:/workdir" -v "${SCRIPT_DIR}/../data:/data" alpine:3.20.1 ash -c "apk -q --no-progress --no-cache add xz pv && tar -cf - -C /workdir . | pv -petabs \$(du -sb /workdir | cut -f 1) | xz -zq > /data/backups/${ARCHIVE_NAME}"

echo -e "${B}[5/5] Cleaning up...${DEF}"
rm -rf "$WORKDIR"

echo -e "${G}Done, export package created at ${B}data/backups/${ARCHIVE_NAME}${DEF}"

echo -e "\n\n${R}WARNING, IMPORTANT!${DEF}"
echo -e "${Y}If you import this export into a DAppNode, make sure to stop this deployment first!${DEF}"

trap - EXIT
