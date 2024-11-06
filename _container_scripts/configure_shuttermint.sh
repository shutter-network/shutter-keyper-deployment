#!/usr/bin/env ash

set -eux

[[ -f /assets/variables.env ]] && . /assets/variables.env || (echo "Missing variables file (/assets/variables), assets container missing?"; exit 1)

CFG=/data/chain/config/config.toml

rm /data/chain/config/genesis.json
ln -s /assets/genesis.json /data/chain/config/genesis.json

sed -i "/^seeds =/c\seeds = \"${_ASSETS_SHUTTERMINT_SEED_NODES}\"" $CFG
sed -i "/^moniker =/c\moniker = \"${SHUTTERMINT_MONIKER}\"" $CFG
sed -i "/^genesis_file =/c\genesis_file = \"/assets/genesis.json\"" $CFG
sed -i "/^external_address =/c\external_address = \"${PUBLIC_IP}:26656\"" $CFG
sed -i "/^addr_book_strict =/c\addr_book_strict = true" $CFG
sed -i "/^pex =/c\pex = true" $CFG
if [ "$METRICS_ENABLED" = "true" ]; then
  sed -i "/^prometheus =/c\prometheus = true" $CFG
  sed -i "/^prometheus_listen_addr =/c\prometheus_listen_addr = \"0.0.0.0:26660\"" $CFG
fi
