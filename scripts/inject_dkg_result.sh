#!/usr/bin/env bash

# This script overrides a selected DKG result in the keyper database
# with the corresponding data from a backup. The following tables are
# affected:
# - dkg_result (columns: success, error, pure_result)
# - keyper_set (columns: keypers, threshold)
# - tendermint_batch_config (columns: keypers, threshold)
#
# The existing tables are backed up in the same database (with suffix
# "_backup") before applying the changes in case they need to be
# restored.
#
# The rows to update are identified by EON and KEYPER_CONFIG_INDEX
# variables defined below.
#
# Usage: ./inject_dkg_result.sh <path-to-backup.tar.xz>
#
# Ensure the node is sufficiently synced before running. If the keyper
# service is running, it will be stopped during the operation and
# restarted afterwards. The database service will be started if not
# already running, and stopped again afterwards if it was not running.

set -euo pipefail

EON="1"
KEYPER_CONFIG_INDEX="1"
MIN_TENDERMINT_CURRENT_BLOCK="0"

BACKUP_CONTAINER="backup-db"
BACKUP_IMAGE="postgres"
BACKUP_DB="postgres"
BACKUP_USER="postgres"
BACKUP_PASSWORD="postgres"
KEYPER_DB="keyper"
BACKUP_TABLE_SUFFIX="_backup"

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t inject-dkg-result)"
DUMP_FILE="${TMP_DIR}/keyper.dump"
TABLES=(
  "dkg_result:eon:${EON}:success, error, pure_result"
  "tendermint_batch_config:keyper_config_index:${KEYPER_CONFIG_INDEX}:keypers, threshold"
  "keyper_set:keyper_config_index:${KEYPER_CONFIG_INDEX}:keypers, threshold"
)

log() {
  echo "==> $1"
}

usage() {
  echo "Usage: $(basename "$0") <path-to-backup.tar.xz>" >&2
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  usage
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: required command 'tar' not found in PATH" >&2
  exit 1
fi

BACKUP_TARBALL_PATH="$1"

if [[ ! -f "$BACKUP_TARBALL_PATH" ]]; then
  echo "ERROR: tarball not found: $BACKUP_TARBALL_PATH" >&2
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${BACKUP_CONTAINER}\$"; then
  echo "ERROR: container '${BACKUP_CONTAINER}' already exists. Aborting." >&2
  exit 1
fi

DB_WAS_RUNNING=0
KEYPER_WAS_RUNNING=0

if [[ -n "$(docker compose ps -q db 2>/dev/null || true)" ]]; then
  DB_WAS_RUNNING=1
fi

if [[ -n "$(docker compose ps -q keyper 2>/dev/null || true)" ]]; then
  KEYPER_WAS_RUNNING=1
fi

cleanup() {
  rv=$?
  if [[ "$rv" -ne 0 ]]; then
    echo "Aborting due to error (exit code $rv)" >&2
  fi

  log "Stopping backup container"
  docker stop "$BACKUP_CONTAINER" >/dev/null 2>&1 || true

  if [[ "$KEYPER_WAS_RUNNING" -eq 1 ]]; then
    log "Restarting keyper service (was running before)"
    docker compose start keyper >/dev/null 2>&1 || true
  else
    log "Leaving keyper service stopped (was not running before)"
  fi

  if [[ "$DB_WAS_RUNNING" -eq 0 ]]; then
    log "Stopping db service (was not running before)"
    docker compose stop db >/dev/null 2>&1 || true
  else
    log "Keeping db service running (was running before)"
  fi

  if [[ -d "$TMP_DIR" ]]; then
    log "Removing temporary directory ${TMP_DIR}"
    rm -rf "$TMP_DIR"
  fi

  exit "$rv"
}
trap cleanup EXIT

if [[ "$DB_WAS_RUNNING" -eq 0 ]]; then
  log "Starting db service (was not running)"
  docker compose start db >/dev/null
fi

log "Checking shuttermint sync block number >= ${MIN_TENDERMINT_CURRENT_BLOCK}"
CURRENT_BLOCK=$(docker compose exec -T db sh -lc \
  "psql -t -A -U postgres -d ${KEYPER_DB} -c \"SELECT current_block FROM tendermint_sync_meta ORDER BY current_block DESC LIMIT 1\"" \
  2>/dev/null | tr -d '[:space:]')

if [[ -z "$CURRENT_BLOCK" ]]; then
  echo "ERROR: failed to read shuttermint sync block number" >&2
  exit 1
fi

if ! [[ "$CURRENT_BLOCK" =~ ^[0-9]+$ ]]; then
  echo "ERROR: shuttermint sync block number is not an integer: $CURRENT_BLOCK" >&2
  exit 1
fi

if ! [[ "$MIN_TENDERMINT_CURRENT_BLOCK" =~ ^-?[0-9]+$ ]]; then
  echo "ERROR: MIN_TENDERMINT_CURRENT_BLOCK must be an integer (current: $MIN_TENDERMINT_CURRENT_BLOCK)" >&2
  exit 1
fi

if (( CURRENT_BLOCK < MIN_TENDERMINT_CURRENT_BLOCK )); then
  echo "ERROR: shuttermint sync block number ($CURRENT_BLOCK) is below MIN_TENDERMINT_CURRENT_BLOCK ($MIN_TENDERMINT_CURRENT_BLOCK); aborting. Please wait until the node is sufficiently synced and try again." >&2
  exit 1
fi

log "Stopping keyper service"
docker compose stop keyper >/dev/null 2>&1 || true

log "Extracting keyper DB from backup"
tar -xJOf "$BACKUP_TARBALL_PATH" ./keyper.dump >"$DUMP_FILE"

if [[ ! -s "$DUMP_FILE" ]]; then
  echo "ERROR: failed to extract ./keyper.dump from ${BACKUP_TARBALL_PATH}" >&2
  exit 1
fi

log "Starting backup container"
docker run -d --rm \
  --name "$BACKUP_CONTAINER" \
  -e POSTGRES_USER="$BACKUP_USER" \
  -e POSTGRES_PASSWORD="$BACKUP_PASSWORD" \
  -e POSTGRES_DB="$BACKUP_DB" \
  -v "$DUMP_FILE:/backup/dump.sql:ro" \
  "$BACKUP_IMAGE" >/dev/null

log "Waiting for backup DB to become ready"
for i in {1..30}; do
  if docker exec "$BACKUP_CONTAINER" pg_isready -U "$BACKUP_USER" -d "$BACKUP_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker exec "$BACKUP_CONTAINER" pg_isready -U "$BACKUP_USER" -d "$BACKUP_DB" >/dev/null 2>&1; then
  echo "ERROR: backup DB did not become ready after 30 seconds" >&2
  exit 1
fi

log "Restoring dump into backup DB"
docker exec "$BACKUP_CONTAINER" bash -lc \
  "pg_restore -v -C -U '$BACKUP_USER' -d '$BACKUP_DB' /backup/dump.sql" >/dev/null 2>&1

for entry in "${TABLES[@]}"; do
  IFS=: read -r TABLE KEY_COLUMN KEY_VALUE SELECT_COLUMNS <<<"$entry"
  BACKUP_CSV_FILE="${TMP_DIR}/${TABLE}_backup_${KEY_COLUMN}_${KEY_VALUE}.csv"
  LIVE_CSV_FILE="${TMP_DIR}/${TABLE}_live_${KEY_COLUMN}_${KEY_VALUE}.csv"
  SELECT_COLUMN_LIST=()

  for col in ${SELECT_COLUMNS//,/ }; do
    [[ -z "$col" ]] && continue
    if [[ "$col" == "$KEY_COLUMN" ]]; then
      echo "ERROR: column list for ${TABLE} must not include key column ${KEY_COLUMN}" >&2
      exit 1
    fi
    SELECT_COLUMN_LIST+=("$col")
  done

  if [[ "${#SELECT_COLUMN_LIST[@]}" -eq 0 ]]; then
    echo "ERROR: no non-key columns specified for update in ${TABLE}" >&2
    exit 1
  fi

  SELECT_COLUMN_LIST_WITH_KEY=("$KEY_COLUMN" "${SELECT_COLUMN_LIST[@]}")
  SELECT_COLUMNS_WITH_KEY=$(IFS=', '; echo "${SELECT_COLUMN_LIST_WITH_KEY[*]}")

  log "Extracting ${TABLE} row ${KEY_COLUMN}=${KEY_VALUE} from backup DB"
  docker exec "$BACKUP_CONTAINER" bash -lc \
    "psql -v ON_ERROR_STOP=1 -U '$BACKUP_USER' -d '$KEYPER_DB' -c \"COPY (SELECT ${SELECT_COLUMNS_WITH_KEY} FROM ${TABLE} WHERE ${KEY_COLUMN} = '${KEY_VALUE}' LIMIT 1) TO STDOUT WITH CSV\"" \
    >"$BACKUP_CSV_FILE" 2>/dev/null

  if [[ ! -s "$BACKUP_CSV_FILE" ]]; then
    echo "ERROR: no data extracted from backup DB (no row with ${KEY_COLUMN}=${KEY_VALUE} in ${TABLE})" >&2
    exit 1
  fi

  log "Extracting ${TABLE} row ${KEY_COLUMN}=${KEY_VALUE} from live DB"
  docker compose exec -T db sh -lc \
    "psql -v ON_ERROR_STOP=1 -U postgres -d ${KEYPER_DB} -c \"COPY (SELECT ${SELECT_COLUMNS_WITH_KEY} FROM ${TABLE} WHERE ${KEY_COLUMN} = '${KEY_VALUE}' LIMIT 1) TO STDOUT WITH CSV\"" \
    >"$LIVE_CSV_FILE" 2>/dev/null || true

  if [[ -s "$LIVE_CSV_FILE" && -s "$BACKUP_CSV_FILE" && "$(cat "$LIVE_CSV_FILE")" == "$(cat "$BACKUP_CSV_FILE")" ]]; then
    log "Live row for ${TABLE} already matches backup, nothing to do"
    continue
  fi

  BACKUP_TABLE_NAME="${TABLE}${BACKUP_TABLE_SUFFIX}"

  log "Backing up table ${TABLE} to ${BACKUP_TABLE_NAME} in live DB"
  {
    echo "CREATE TABLE IF NOT EXISTS ${BACKUP_TABLE_NAME} (LIKE ${TABLE} INCLUDING ALL);"
    echo "TRUNCATE ${BACKUP_TABLE_NAME};"
    echo "INSERT INTO ${BACKUP_TABLE_NAME} SELECT * FROM ${TABLE};"
  } | docker compose exec -T db psql -U postgres -d "${KEYPER_DB}" >/dev/null 2>&1

  UPDATE_SET=""
  for col in "${SELECT_COLUMN_LIST[@]}"; do
    if [[ -z "$UPDATE_SET" ]]; then
      UPDATE_SET="${col} = u.${col}"
    else
      UPDATE_SET="${UPDATE_SET}, ${col} = u.${col}"
    fi
  done

  log "Restoring ${TABLE} row ${KEY_COLUMN}=${KEY_VALUE}"
  {
    echo "BEGIN;"
    echo "CREATE TEMP TABLE tmp_update AS SELECT ${SELECT_COLUMNS_WITH_KEY} FROM ${TABLE} WHERE 1=0;"
    echo "COPY tmp_update FROM STDIN WITH CSV;"
    cat "$BACKUP_CSV_FILE"
    echo '\.'
    echo "UPDATE ${TABLE} AS t SET ${UPDATE_SET} FROM tmp_update u WHERE t.${KEY_COLUMN} = u.${KEY_COLUMN};"
    echo "COMMIT;"
  } | docker compose exec -T db psql -U postgres -d "${KEYPER_DB}" >/dev/null 2>&1
done

log "Done"
