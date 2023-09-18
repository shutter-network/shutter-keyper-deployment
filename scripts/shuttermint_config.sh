#!/usr/bin/env sh

CFG=/data/chain/config/config.toml

sed -i "/^bootstrap-peers =/c\bootstrap-peers = \"${SEED_NODES}\"" $CFG
sed -i "/^moniker =/c\moniker = \"${SHUTTERMINT_MONIKER}\"" $CFG
sed -i "/^genesis-file =/c\genesis-file = \"/info/genesis.json\"" $CFG
sed -i "/^external-address =/c\external-address = \"${PUBLIC_IP}:26656\"" $CFG
sed -i "/^addr-book-strict =/c\addr-book-strict = true" $CFG
sed -i "/^pex =/c\pex = true" $CFG
if [ "$METRICS_ENABLED" = "true" ]; then
  sed -i "/^prometheus =/c\prometheus = true" $CFG
  sed -i "/^prometheus-listen-addr =/c\prometheus-listen-addr = \"0.0.0.0:26660\"" $CFG
fi
