#!/usr/bin/env ash

# This script reads loads env variables from the assets container and exposes
# them in the shell environment then execs the given command

set -eu

set -a
[[ -f /assets/variables.env ]] && . /assets/variables.env || (echo "Missing variables file (/assets/variables), assets container missing?"; exit 1)
set +a

# FIXME: Temporary until next assets release
if [[ -z "${_ASSETS_VERSION:-}" ]]; then
  export _ASSETS_VERSION="$(cat /assets/version)"
fi

exec "$@"
