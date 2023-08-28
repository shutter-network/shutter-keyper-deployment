#!/usr/bin/env bash

set -x

sed -i "/ValidatorPublicKey/c\ValidatorPublicKey = \"$(cat /data/chain/config/priv_validator_pubkey.hex)\""
/config/keyper.toml
