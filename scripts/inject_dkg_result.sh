#!/usr/bin/env bash

# This script injects a DKG result into the keyper database. The following
# tables are affected:
# - dkg_result: eon, success, error, pure_result — copied from backup
# - keyper_set: keyper_config_index, activation_block_number, keypers, threshold — hardcoded
# - tendermint_batch_config: all columns — hardcoded except eon/success/error/pure_result
#
# The existing tables are backed up in the same database (with suffix "_backup")
# before applying changes.
#
# Usage: ./inject_dkg_result.sh <path-to-backup.tar|path-to-backup.tar.xz>
#
# Ensure the node is sufficiently synced before running. If the keyper service
# is running, it will be stopped during the operation and restarted afterwards.
# The database service will be started if not already running, and stopped again
# afterwards if it was not running before.

set -euo pipefail

MIN_TENDERMINT_CURRENT_BLOCK="349800"

EON="11"
KEYPER_CONFIG_INDEX="11"
KEYPERS="{0xe03472CCb8e011b7Dfb3343837D75Bf6C9c3324C,0x4B5E2356b666898e101627BdDc518956bcd90a03,0x23d33956940083e0E92Dd608D6E576AfbEcc83a9,0x48A0e1789C82084aE28c179bd5742454f8CD4ed6,0xfc7d75e4bb6D18591cDc1E766CE7cF231bc08fBc,0x00D82BAc88c5E60fDAfac7e534A13D0E7F3e145a,0xcc7cd01106951B4809e640873C15363609d2C58e,0x7Ca18A55b64c1509d34e964a9e323a6c71e905a2,0x0c8f3E3912F35a59ffddc9Ff1ABB8FafC89b29de,0xEbe0BE11161e8aea85733D4ff09De6470E6558Da,0x2AF3d10Ac40737bf38437e96C8EdE308f2C6A3bc,0x4521DC1B2748585E51f8631A0f4c964B6e8BC893}"
THRESHOLD="5"
ACTIVATION_BLOCK_NUMBER="44979852"
TENDERMINT_HEIGHT="723"
TENDERMINT_STARTED="true"

BACKUP_CONTAINER="backup-db"
BACKUP_IMAGE="postgres"
BACKUP_DB="postgres"
BACKUP_USER="postgres"
BACKUP_PASSWORD="postgres"
KEYPER_DB="keyper"

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t inject-dkg-result)"
DUMP_FILE="${TMP_DIR}/keyper.dump"

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
_consecutive=0
for i in {1..60}; do
  if docker exec "$BACKUP_CONTAINER" pg_isready -U "$BACKUP_USER" -d "$BACKUP_DB" >/dev/null 2>&1; then
    _consecutive=$(( _consecutive + 1 ))
    [ "$_consecutive" -ge 3 ] && break
  else
    _consecutive=0
  fi
  sleep 1
done
if [[ "$_consecutive" -lt 3 ]]; then
  echo "ERROR: backup DB did not become ready after 60 seconds" >&2
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

log "Checking dkg_result row exists in backup for eon=${EON}"
BACKUP_DKG_COUNT=$(docker exec "$BACKUP_CONTAINER" psql -t -A -U "$BACKUP_USER" -d "$KEYPER_DB" \
  -c "SELECT COUNT(*) FROM dkg_result WHERE eon = ${EON}" 2>/dev/null | tr -d '[:space:]')
if [[ "$BACKUP_DKG_COUNT" == "0" ]]; then
  echo "ERROR: no dkg_result row for eon=${EON} in backup DB" >&2
  exit 1
fi

log "Backing up tables"
{
  for TABLE in dkg_result keyper_set tendermint_batch_config; do
    echo "CREATE TABLE IF NOT EXISTS ${TABLE}_backup (LIKE ${TABLE} INCLUDING ALL);"
    echo "TRUNCATE ${TABLE}_backup;"
    echo "INSERT INTO ${TABLE}_backup SELECT * FROM ${TABLE};"
  done
} | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d "${KEYPER_DB}" >/dev/null

log "Injecting DKG result"
{
  echo "BEGIN;"
  echo "CREATE TEMP TABLE tmp_dkg_result (eon bigint, success boolean, error text, pure_result bytea);"
  echo "COPY tmp_dkg_result FROM STDIN WITH (FORMAT csv);"
  docker exec "$BACKUP_CONTAINER" psql -U "$BACKUP_USER" -d "$KEYPER_DB" \
    -c "COPY (SELECT eon, success, error, pure_result FROM dkg_result WHERE eon = ${EON} LIMIT 1) TO STDOUT WITH (FORMAT csv)"
  echo '\.'
  echo "INSERT INTO dkg_result (eon, success, error, pure_result)"
  echo "  SELECT eon, success, error, pure_result FROM tmp_dkg_result"
  echo "  ON CONFLICT (eon) DO UPDATE SET"
  echo "    success = EXCLUDED.success, error = EXCLUDED.error, pure_result = EXCLUDED.pure_result;"
  echo "INSERT INTO keyper_set (keyper_config_index, activation_block_number, keypers, threshold)"
  echo "  VALUES (${KEYPER_CONFIG_INDEX}, ${ACTIVATION_BLOCK_NUMBER}, '${KEYPERS}', ${THRESHOLD})"
  echo "  ON CONFLICT (keyper_config_index) DO UPDATE SET"
  echo "    activation_block_number = EXCLUDED.activation_block_number,"
  echo "    keypers = EXCLUDED.keypers,"
  echo "    threshold = EXCLUDED.threshold;"
  echo "INSERT INTO tendermint_batch_config (keyper_config_index, height, keypers, threshold, started, activation_block_number)"
  echo "  VALUES (${KEYPER_CONFIG_INDEX}, ${TENDERMINT_HEIGHT}, '${KEYPERS}', ${THRESHOLD}, ${TENDERMINT_STARTED}, ${ACTIVATION_BLOCK_NUMBER})"
  echo "  ON CONFLICT (keyper_config_index) DO UPDATE SET"
  echo "    height = EXCLUDED.height,"
  echo "    keypers = EXCLUDED.keypers,"
  echo "    threshold = EXCLUDED.threshold,"
  echo "    started = EXCLUDED.started,"
  echo "    activation_block_number = EXCLUDED.activation_block_number;"
  echo "COMMIT;"
} | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d "${KEYPER_DB}" >/dev/null

log "Done"
