#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT="${SCRIPT_DIR}/.."

DB_SERVICE="db"
DB_NAME="keyper"
DB_USER="postgres"
TABLE_NAME="tendermint_outgoing_messages"
MESSAGE_LABEL="outgoing batch config message"
DEFAULT_WHERE_CLAUSE="description = 'new batch config (activation-block-number=45304962, config-index=14)'"

DB_STARTED_BY_SCRIPT=0

log() {
  echo "==> $1"
}

usage() {
  cat <<EOF
Usage: $(basename "$0")

Deletes exactly one row from ${TABLE_NAME}.

Examples:
  $(basename "$0")
EOF
}

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: this script does not accept arguments" >&2
      usage >&2
      exit 1
      ;;
  esac
fi

cleanup() {
  rv=$?
  set +e

  if [[ "$DB_STARTED_BY_SCRIPT" -eq 1 ]]; then
    log "Stopping ${DB_SERVICE} service to restore the original state"
    docker compose stop "${DB_SERVICE}" >/dev/null 2>&1 || true
  fi

  exit "$rv"
}

trap cleanup EXIT

cd "${REPO_ROOT}"

if docker compose ps --status running --services "${DB_SERVICE}" | grep -qx "${DB_SERVICE}"; then
  log "${DB_SERVICE} service is already running"
else
  log "Starting ${DB_SERVICE} service"
  if docker compose ps -a --services "${DB_SERVICE}" | grep -qx "${DB_SERVICE}"; then
    docker compose start "${DB_SERVICE}" >/dev/null
  else
    docker compose up -d "${DB_SERVICE}" >/dev/null
  fi
  DB_STARTED_BY_SCRIPT=1
fi

log "Waiting for ${DB_SERVICE} to become ready"
for _ in {1..60}; do
  if docker compose exec -T "${DB_SERVICE}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker compose exec -T "${DB_SERVICE}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
  echo "ERROR: ${DB_SERVICE} did not become ready within 60 seconds" >&2
  exit 1
fi

log "Checking whether the ${MESSAGE_LABEL} exists"
MATCH_COUNT=$(docker compose exec -T "${DB_SERVICE}" \
  psql -t -A -U "${DB_USER}" -d "${DB_NAME}" \
  -c "SELECT COUNT(*) FROM ${TABLE_NAME} WHERE ${DEFAULT_WHERE_CLAUSE};" | tr -d '[:space:]')

if ! [[ "${MATCH_COUNT}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: failed to determine whether the ${MESSAGE_LABEL} exists" >&2
  exit 1
fi

if [[ "${MATCH_COUNT}" -eq 0 ]]; then
  log "The ${MESSAGE_LABEL} is already absent; nothing to delete"
  exit 0
fi

if [[ "${MATCH_COUNT}" -ne 1 ]]; then
  echo "ERROR: expected exactly 1 matching ${MESSAGE_LABEL}, found ${MATCH_COUNT}" >&2
  exit 1
fi


log "Deleting the ${MESSAGE_LABEL}"
DELETE_COUNT=$(docker compose exec -T "${DB_SERVICE}" \
  psql -t -A -U "${DB_USER}" -d "${DB_NAME}" \
  -c "WITH deleted AS (DELETE FROM ${TABLE_NAME} WHERE ${DEFAULT_WHERE_CLAUSE} RETURNING 1) SELECT COUNT(*) FROM deleted;" | tr -d '[:space:]')

if [[ "${DELETE_COUNT}" != "1" ]]; then
  echo "ERROR: delete operation removed ${DELETE_COUNT} rows instead of 1 ${MESSAGE_LABEL}" >&2
  exit 1
fi

log "SUCCESS: deleted the ${MESSAGE_LABEL}"
