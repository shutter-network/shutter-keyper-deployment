#!/usr/bin/env ash

set -euo pipefail

SOURCE=/config/generated.toml
CFG=/config/keyper.toml

# Save eth address, peer identity, p2p key and encryption key from existing config
if [[ -f "$CFG" ]]; then
  _ETH_ADDRESS=$(grep -e "^# Ethereum address:" $CFG || true)
  _PEER_ID=$(grep -e "^# Peer identity:" $CFG || true)
  _P2P_KEY=$(grep -e "^P2PKey =" $CFG || true)
  _ECIES_PRIVATE_KEY=$(grep -e "^ECIESPrivateKey =" $CFG || true)
fi

mv "$SOURCE" "$CFG"

# Reapply saved values
if [[ -n "${_ETH_ADDRESS:-}" ]]; then
  sed -i "/^# Ethereum address/c\\${_ETH_ADDRESS}" $CFG
fi
if [[ -n "${_PEER_ID:-}" ]]; then
  sed -i "/^# Peer identity/c\\${_PEER_ID}" $CFG
fi
if [[ -n "${_P2P_KEY:-}" ]]; then
  sed -i "/^P2PKey = /c\\${_P2P_KEY}" $CFG
fi
if [[ -n "${_ECIES_PRIVATE_KEY:-}" ]]; then
  sed -i "/^ECIESPrivateKey = /c\\${_ECIES_PRIVATE_KEY}" $CFG
fi

# Values set from network and compose env variables
sed -i "/^InstanceID/c\InstanceID = ${INSTANCE_ID}" $CFG
if [ "$SHUTTER_HTTP_ENABLED" = "true" ] || [ "$SHUTTER_HTTP_ENABLED" = "false" ]; then
  sed -i "/^HTTPEnabled =/c\HTTPEnabled = $SHUTTER_HTTP_ENABLED" $CFG
fi
sed -i "/^DatabaseURL/c\DatabaseURL = \"${SHUTTER_DATABASEURL}\"" $CFG
sed -i "/^MaxNumKeysPerMessage/c\MaxNumKeysPerMessage = ${MAX_NUM_KEYS_PER_MESSAGE}" $CFG
sed -i "/^SyncStartBlockNumber/c\SyncStartBlockNumber = ${SYNC_START_BLOCK_NUMBER}" $CFG
sed -i "/^PrivateKey/c\PrivateKey = \"${SHUTTER_CHAIN_NODE_PRIVATEKEY}\"" $CFG
sed -i "/^DeploymentDir/c\DeploymentDir = \"\"  # unused" $CFG
sed -i "/^EthereumURL/c\EthereumURL = \"${SHUTTER_CHAIN_NODE_ETHEREUMURL}\"" $CFG
sed -i "/^KeyperSetManager/c\KeyperSetManager = \"${KEYPER_SET_MANAGER}\"" $CFG
sed -i "/^KeyBroadcastContract/c\KeyBroadcastContract = \"${KEY_BROADCAST_CONTRACT}\"" $CFG
sed -i "/^ShutterRegistry/c\ShutterRegistry = \"${SHUTTER_REGISTRY}\"" $CFG
sed -i "/^ECIESKeyRegistry/c\ECIESKeyRegistry = \"${ECIES_KEY_REGISTRY}\"" $CFG
if [[ "${SHUTTER_EVENT_TRIGGER_REGISTRY:-}" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  sed -i "/^ShutterEventTriggerRegistry/c\ShutterEventTriggerRegistry = \"${SHUTTER_EVENT_TRIGGER_REGISTRY}\"" $CFG
fi
sed -i "/^DiscoveryNamespace/c\DiscoveryNamespace = \"${DISCOVERY_NAME_PREFIX}-${INSTANCE_ID}\"" $CFG
sed -i "/^ListenAddresses/c\ListenAddresses = \"${SHUTTER_P2P_LISTENADDRESSES}\"" $CFG
sed -i "/^AdvertiseAddresses/c\AdvertiseAddresses = \"${SHUTTER_P2P_ADVERTISEADDRESSES}\"" $CFG
sed -i "/^CustomBootstrapAddresses/c\CustomBootstrapAddresses = ${CUSTOM_BOOTSTRAP_ADDRESSES}" $CFG
sed -i "/^SyncMonitorCheckInterval/c\SyncMonitorCheckInterval = ${SYNC_MONITOR_CHECK_INTERVAL}" $CFG
sed -i "/^Enabled/c\Enabled = ${SHUTTER_METRICS_ENABLED}" $CFG
sed -i "/^Port/c\Port = ${SHUTTER_METRICS_PORT}" $CFG
