#!/usr/bin/env bash

set -e

NETWORK=$(docker compose config chain --format "json" | docker run --rm -i ghcr.io/jqlang/jq:1.7.1 '.networks.default.name' )

docker run --rm -it --network "$NETWORK" ghcr.io/curl/curl-container/curl-multi:master http://chain:26657/$1
