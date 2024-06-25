#!/usr/bin/env ash

set -eux

[[ -f /assets/variables.env ]] && . /assets/variables.env || (echo "Missing variables file (/assets/variables), assets container missing?"; exit 1)

SOURCE=/config/generated.toml
CFG=/config/keyper.toml

mv "$SOURCE" "$CFG"

# Values set from assets container and compose env varibles
sed -i "/^InstanceID/c\InstanceID = ${_ASSETS_INSTANCE_ID}" $CFG
sed -i "/^DatabaseURL/c\DatabaseURL = \"${SHUTTER_DATABASEURL}\"" $CFG
sed -i "/^BeaconAPIURL/c\BeaconAPIURL = \"${SHUTTER_BEACONAPIURL}\"" $CFG
sed -i "/^MaxNumKeysPerMessage/c\MaxNumKeysPerMessage = ${_ASSETS_MAX_NUM_KEYS_PER_MESSAGE}" $CFG
sed -i "/^EncryptedGasLimit/c\EncryptedGasLimit = ${_ASSETS_ENCRYPTED_GAS_LIMIT}" $CFG
sed -i "/^MaxTxPointerAge/c\MaxTxPointerAge =  ${SHUTTER_GNOSIS_MAXTXPOINTERAGE}" $CFG
sed -i "/^GenesisSlotTimestamp/c\GenesisSlotTimestamp = ${_ASSETS_GENESIS_SLOT_TIMESTAMP}" $CFG
sed -i "/^SyncStartBlockNumber/c\SyncStartBlockNumber = ${_ASSETS_SYNC_START_BLOCK_NUMBER}" $CFG
sed -i "/^PrivateKey/c\PrivateKey = \"${SHUTTER_GNOSIS_NODE_PRIVATEKEY}\"" $CFG
sed -i "/^ContractsURL/c\ContractsURL = \"${SHUTTER_GNOSIS_NODE_CONTRACTSURL}\"" $CFG
sed -i "/^DeploymentDir/c\DeploymentDir = \"\"  # unused" $CFG
sed -i "/^EthereumURL/c\EthereumURL = \"${SHUTTER_GNOSIS_NODE_ETHEREUMURL}\"" $CFG
sed -i "/^KeyperSetManager/c\KeyperSetManager = \"${_ASSETS_KEYPER_SET_MANAGER}\"" $CFG
sed -i "/^KeyBroadcastContract/c\KeyBroadcastContract = \"${_ASSETS_KEY_BROADCAST_CONTRACT}\"" $CFG
sed -i "/^EonKeyPublish/c\EonKeyPublish = \"${_ASSETS_EON_KEY_PUBLISH}\"" $CFG
sed -i "/^Sequencer/c\Sequencer = \"${_ASSETS_SEQUENCER}\"" $CFG
sed -i "/^ValidatorRegistry/c\ValidatorRegistry = \"${_ASSETS_VALIDATOR_REGISTRY}\"" $CFG
sed -i "/^DiscoveryNamespace/c\DiscoveryNamespace = \"${_ASSETS_DISCOVERY_NAME_PREFIX}-${_ASSETS_INSTANCE_ID}\"" $CFG
sed -i "/^ShuttermintURL/c\ShuttermintURL = \"${SHUTTER_SHUTTERMINT_SHUTTERMINTURL}\"" $CFG
sed -i "/^ValidatorPublicKey/c\ValidatorPublicKey = \"$(cat /data/chain/config/priv_validator_pubkey.hex)\"" $CFG
sed -i "/^ListenAddresses/c\ListenAddresses = \"${SHUTTER_P2P_LISTENADDRESSES}\"" $CFG
sed -i "/^CustomBootstrapAddresses/c\CustomBootstrapAddresses = ${_ASSETS_CUSTOM_BOOTSTRAP_ADDRESSES}" $CFG
sed -i "/^DKGPhaseLength/c\DKGPhaseLength = ${_ASSETS_DKG_PHASE_LENGTH}" $CFG
sed -i "/^DKGStartBlockDelta/c\DKGStartBlockDelta = ${_ASSETS_DKG_START_BLOCK_DELTA}" $CFG
sed -i "/^Enabled/c\Enabled = ${SHUTTER_METRICS_ENABLED}" $CFG
