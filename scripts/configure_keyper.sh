#!/usr/bin/env bash

set -eux

CFG=/config/keyper.toml

[[ -f /info/variables ]] && . /info/variables || (echo "No variables file, assets container missing?"; exit 1)

# Values set via environment - remove from config to reduce confusion
sed -i "/DatabaseURL/c\DatabaseURL = \"\"  # from env" $CFG
sed -i "/BeaconAPIURL/c\BeaconAPIURL = \"\"  # from env" $CFG
sed -i "/MaxTxPointerAge/c\MaxTxPointerAge = 0  # from env" $CFG
sed -i "/PrivateKey/c\PrivateKey = \"\"  # from env" $CFG
sed -i "/ContractsURL/c\ContractsURL = \"\"  # from env" $CFG
sed -i "/EthereumURL/c\EthereumURL = \"\"  # from env" $CFG
sed -i "/ListenAddresses/c\ListenAddresses = \"\"  # from env" $CFG
sed -i "/ShuttermintURL/c\ShuttermintURL = \"\"  # from env" $CFG
sed -i "/Enabled/c\Enabled = false  # from env" $CFG

# Values set from assets container
sed -i "/InstanceID/c\InstanceID = ${_ASSETS_INSTANCE_ID}" $CFG
sed -i "/MaxNumKeysPerMessage/c\MaxNumKeysPerMessage = ${_ASSETS_MAX_NUM_KEYS_PER_MESSAGE}" $CFG
sed -i "/EncryptedGasLimit/c\EncryptedGasLimit = ${_ASSETS_ENCRYPTED_GAS_LIMIT}" $CFG
sed -i "/GenesisSlotTimestamp/c\GenesisSlotTimestamp = ${_ASSETS_GENESIS_SLOT_TIMESTAMP}" $CFG
sed -i "/KeyperSetManager/c\KeyperSetManager = \"${_ASSETS_KEYPER_SET_MANAGER}\"" $CFG
sed -i "/KeyBroadcastContract/c\KeyBroadcastContract = \"${_ASSETS_KEY_BROADCAST_CONTRACT}\"" $CFG
sed -i "/EonKeyPublish/c\EonKeyPublish = \"${_ASSETS_EON_KEY_PUBLISH}\"" $CFG
sed -i "/Sequencer/c\Sequencer = \"${_ASSETS_SEQUENCER}\"" $CFG
sed -i "/ValidatorRegistry/c\ValidatorRegistry = \"${_ASSETS_VALIDATOR_REGISTRY}\"" $CFG
sed -i "/DiscoveryNamespace/c\DiscoveryNamespace = \"shutter-gnosis-${_ASSETS_INSTANCE_ID}\"" $CFG
sed -i "/ValidatorPublicKey/c\ValidatorPublicKey = \"$(cat /data/chain/config/priv_validator_pubkey.hex)\"" $CFG
sed -i "/DKGPhaseLength/c\DKGPhaseLength = ${_ASSETS_DKG_PHASE_LENGTH}" $CFG
sed -i "/DKGStartBlockDelta/c\DKGStartBlockDelta = ${_ASSETS_DKG_START_BLOCK_DELTA}" $CFG
