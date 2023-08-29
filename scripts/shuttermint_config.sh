#!/usr/bin/env sh

CFG=/data/chain/config/config.toml

sed -i "/^bootstrap-peers =/c\bootstrap-peers = \"${SEED_NODES}\"" $CFG
sed -i "/^moniker =/c\moniker = \"${SHUTTERMINT_MONIKER}\"" $CFG
sed -i "/^genesis-file =/c\genesis-file = \"/info/genesis.json\"" $CFG
sed -i "/^external-address =/c\external-address = \"${PUBLIC_IP}\"" $CFG
sed -i "/^addr-book-strict =/c\addr-book-strict = true" $CFG
sed -i "/^pex =/c\pex = true" $CFG
