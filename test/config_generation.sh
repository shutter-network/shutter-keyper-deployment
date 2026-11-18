#!/usr/bin/env bash

# Generates keyper.toml the way `docker compose up` does, with the images pinned
# in docker-compose.yml and no network, once with METRICS_ENABLED=true and once
# with false, and checks each result with test/check_keyper_config.py.
#
# It works on a copy in a temporary directory, under its own compose project
# name, so it never touches ./config, ./data or a running deployment.
#
# Usage: test/config_generation.sh

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"

compose() {
  local dir="$1"; shift
  docker compose --project-directory "${dir}" -p "keyper-config-test-$(basename "${dir}")" \
    -f "${dir}/docker-compose.yml" -f "${REPO}/test/compose.offline.yml" "$@"
}

cleanup() {
  for dir in "${WORK}"/*/; do
    compose "${dir%/}" down --volumes >/dev/null 2>&1 || true
  done
  # The containers write as root, so their files are removed from a container too.
  docker run --rm --network none -v "${WORK}:/work" busybox find /work -mindepth 1 -delete
  rmdir "${WORK}"
}
trap cleanup EXIT

for metrics in true false; do
  dir="${WORK}/metrics-${metrics}"
  mkdir "${dir}"
  cp -r "${REPO}/docker-compose.yml" "${REPO}/_container_scripts" "${dir}/"
  sed "s/^METRICS_ENABLED=.*/METRICS_ENABLED=${metrics}/" "${REPO}/example-api.env" >"${dir}/.env"

  echo "==> METRICS_ENABLED=${metrics}"
  compose "${dir}" up --detach --wait assets
  compose "${dir}" run --rm --no-deps keyper-create-config
  compose "${dir}" run --rm --no-deps chain-init
  compose "${dir}" run --rm --no-deps keyper-configure
  compose "${dir}" exec -T assets cat /assets/variables.env >"${dir}/assets.env"
  compose "${dir}" down --volumes

  python3 "${REPO}/test/check_keyper_config.py" "${dir}/config/keyper.toml" \
    --metrics-enabled "${metrics}" --assets-env "${dir}/assets.env"
done
