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
# Usage: ./inject_dkg_result.sh <path-to-backup.tar|path-to-backup.tar.xz>
#
# Ensure the node is sufficiently synced before running. If the keyper
# service is running, it will be stopped during the operation and
# restarted afterwards. The database service will be started if not
# already running, and stopped again afterwards if it was not running.

set -euo pipefail

EON="11"
KEYPER_CONFIG_INDEX="11"
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
  echo "Usage: $(basename "$0") <path-to-backup.tar|path-to-backup.tar.xz>" >&2
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

if [[ -n "$(docker compose ps --status=running -q db 2>/dev/null || true)" ]]; then
  DB_WAS_RUNNING=1
fi

if [[ -n "$(docker compose ps --status=running -q keyper 2>/dev/null || true)" ]]; then
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

if (( CURRENT_BLOCK < MIN_TENDERMINT_CURRENT_BLOCK )); then
  echo "ERROR: shuttermint sync block number ($CURRENT_BLOCK) is below MIN_TENDERMINT_CURRENT_BLOCK ($MIN_TENDERMINT_CURRENT_BLOCK); aborting. Please wait until the node is sufficiently synced and try again." >&2
  exit 1
fi

log "Checking keyper_set row exists for keyper_config_index=${KEYPER_CONFIG_INDEX}"
KEYPER_SET_COUNT=$(docker compose exec -T db sh -lc \
  "psql -t -A -U postgres -d ${KEYPER_DB} -c \"SELECT COUNT(*) FROM keyper_set WHERE keyper_config_index = '${KEYPER_CONFIG_INDEX}'\"" \
  2>/dev/null | tr -d '[:space:]')
if [[ "$KEYPER_SET_COUNT" == "0" ]]; then
  echo "ERROR: keyper_set row for keyper_config_index=${KEYPER_CONFIG_INDEX} not found in live DB; node may not be sufficiently synced. Please wait and try again." >&2
  exit 1
fi

log "Checking tendermint_batch_config row exists for keyper_config_index=${KEYPER_CONFIG_INDEX}"
BATCH_CONFIG_COUNT=$(docker compose exec -T db sh -lc \
  "psql -t -A -U postgres -d ${KEYPER_DB} -c \"SELECT COUNT(*) FROM tendermint_batch_config WHERE keyper_config_index = '${KEYPER_CONFIG_INDEX}'\"" \
  2>/dev/null | tr -d '[:space:]')
if [[ "$BATCH_CONFIG_COUNT" == "0" ]]; then
  echo "ERROR: tendermint_batch_config row for keyper_config_index=${KEYPER_CONFIG_INDEX} not found in live DB; node may not be sufficiently synced. Please wait and try again." >&2
  exit 1
fi

log "Stopping keyper service"
docker compose stop keyper >/dev/null 2>&1 || true

log "Extracting keyper DB from backup"
TAR_WARNING_FLAGS=()
if tar --help 2>/dev/null | grep -q -- '--warning'; then
  TAR_WARNING_FLAGS+=(--warning=no-unknown-keyword)
fi

TAR_COMPRESS_FLAGS=()
if [[ "$BACKUP_TARBALL_PATH" == *.tar.xz ]]; then
  TAR_COMPRESS_FLAGS=(-J)
fi

TAR_LIST_OUTPUT=""
if ! TAR_LIST_OUTPUT=$(tar "${TAR_WARNING_FLAGS[@]}" "${TAR_COMPRESS_FLAGS[@]}" -tf "$BACKUP_TARBALL_PATH" 2>/dev/null); then
  if [[ "${#TAR_COMPRESS_FLAGS[@]}" -eq 0 ]]; then
    TAR_COMPRESS_FLAGS=(-J)
    TAR_LIST_OUTPUT=$(tar "${TAR_WARNING_FLAGS[@]}" "${TAR_COMPRESS_FLAGS[@]}" -tf "$BACKUP_TARBALL_PATH" 2>/dev/null) || true
  fi
fi

DUMP_TAR_MEMBER=""
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  normalized_entry="${entry#./}"
  if [[ "$normalized_entry" == "keyper.dump" || "$normalized_entry" == */keyper.dump ]]; then
    DUMP_TAR_MEMBER="$entry"
    break
  fi
done <<< "$TAR_LIST_OUTPUT"

if [[ -z "$DUMP_TAR_MEMBER" ]]; then
  echo "ERROR: could not find keyper.dump inside ${BACKUP_TARBALL_PATH}" >&2
  exit 1
fi

tar "${TAR_WARNING_FLAGS[@]}" "${TAR_COMPRESS_FLAGS[@]}" -xOf "$BACKUP_TARBALL_PATH" "$DUMP_TAR_MEMBER" >"$DUMP_FILE"

if [[ ! -s "$DUMP_FILE" ]]; then
  echo "ERROR: failed to extract ${DUMP_TAR_MEMBER} from ${BACKUP_TARBALL_PATH}" >&2
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
_pg_restore_rc=0
docker exec "$BACKUP_CONTAINER" bash -lc \
  "pg_restore -C -U '$BACKUP_USER' -d '$BACKUP_DB' /backup/dump.sql" >/dev/null 2>&1 \
  || _pg_restore_rc=$?
if [[ "$_pg_restore_rc" -ge 2 ]]; then
  echo "ERROR: pg_restore failed (exit code $_pg_restore_rc)" >&2
  exit 1
fi

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

  if [[ ! -s "$LIVE_CSV_FILE" ]]; then
    log "No existing row for ${TABLE} ${KEY_COLUMN}=${KEY_VALUE} in live DB, will insert"
  fi

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

  UPSERT_SET=""
  for col in "${SELECT_COLUMN_LIST[@]}"; do
    if [[ -z "$UPSERT_SET" ]]; then
      UPSERT_SET="${col} = EXCLUDED.${col}"
    else
      UPSERT_SET="${UPSERT_SET}, ${col} = EXCLUDED.${col}"
    fi
  done

  log "Restoring ${TABLE} row ${KEY_COLUMN}=${KEY_VALUE}"
  {
    echo "BEGIN;"
    echo "CREATE TEMP TABLE tmp_upsert AS SELECT ${SELECT_COLUMNS_WITH_KEY} FROM ${TABLE} WHERE 1=0;"
    echo "COPY tmp_upsert FROM STDIN WITH CSV;"
    cat "$BACKUP_CSV_FILE"
    echo '\.'
    echo "INSERT INTO ${TABLE} (${SELECT_COLUMNS_WITH_KEY}) SELECT ${SELECT_COLUMNS_WITH_KEY} FROM tmp_upsert ON CONFLICT (${KEY_COLUMN}) DO UPDATE SET ${UPSERT_SET};"
    echo "COMMIT;"
  } | docker compose exec -T db psql -U postgres -d "${KEYPER_DB}" >/dev/null 2>&1
done

log "Done"
