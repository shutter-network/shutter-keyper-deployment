# Shutter API Keyper

This repository contains the docker compose configuration to run a shutter api keyper.

---

## Table of Contents

- [Prerequisites](#prerequisites)
    - [Chain execution clients](#chain-execution-clients)
    - [System requirements](#system-requirements)
    - [Software](#software)
- [Installation](#installation)
- [Setting Up Logging](#setting-up-logging)
- [Running the Keyper Node](#running-the-keyper-node)
- [Backups](#backups)
- [Updating](#updating)
- [Version History](#version-history)
- [Contract Deployments](#contract-deployments)

---


## Prerequisites

### Chain execution clients

Keypers are required to have access an execution client's JSON RPC API, of the chain, where the shutter registry and keyperset manager contracts are deployed.

### System requirements

The computational requirements for running a Keyper node for the Shutter Network are pretty low.

However, it must be ensured that the Keyper remains online and available at all times since a supermajority of all Keypers is required for decryption key generation to work.

To ensure availability, the system running the Keyper must have a permanent internet connection (i.e., no residential DSL, cable, etc. connections.) and a static public IPv4 address.

We recommend the following minimum hardware specs:

- 2 CPU core
- 4 GB RAM
- \>20GB disk

We also strongly advise using a monitoring system to ensure continued availability. Reliable uptime is highly requested.
Shutter Network does operate a prometheus compatible monitoring system. See below for details.

### Software

- You will need a recent version of `docker` and the `docker compose` cli plugin.
- For cloning the repository you will need `git`.

The Keyper node is distributed as a docker-compose stack consisting of multiple services. This repository contains all necessary files.

One component is opt-in monitoring, which by default requires opening a port for scrape access to the metrics endpoints,
as well as a public IP address that needs to be shared with the Shutter team if you wish to participate in system-wide
monitoring of the nodes.

If you would rather not open up the metrics endpoints we also provide support for push based monitoring.

See the `Metrics` section in the .env file for more information.

Personal monitoring is also possible, but we feel it would be great to have an overview of the whole system as well.


## Installation

1. Clone this repository and open a shell inside it:

```shell
git clone https://github.com/shutter-network/shutter-keyper-deployment.git
cd shutter-keyper-deployment
git checkout shutter-api
```

2. Copy the `example-api.env`(*) file to `.env` and fill in your information:
  - **Required values**
    - Your Ethereum account key (hex-encoded *without* `0x` prefix): `SIGNING_KEY`

      **IMPORTANT**: Please double-check that you are using the key associated with the address that you provided during the Keyper application process. Otherwise, your Keyper node will not be able to join the network.
    - A name of your choice for your keyper node: `KEYPER_NAME`

      (Please use only letters, numbers, and underscores. No spaces or special characters.)
    - Your **public** IP address: `PUBLIC_IP`

      It is important that this is the address your node is reachable under from the internet since it is used for the P2P network between the nodes.
    - A Chain execution JSON RPC API endpoint (WebSocket): `CHAIN_EXECUTION_RPC_WS_URL`
  - Metrics (optional):
    - To enable metrics, set `METRICS_ENABLED` to `true` (the default)
    - Define the interface the metrics ports (`:9200` and `:27660`) should be exposed on with `METRICS_INTERFACE` (defaults to `0.0.0.0`, i.e. the public interface)
    - If you rather not publicly expose the metrics and would like to push metrics instead, uncomment the `COMPOSE_PROFILES=pushmetrics` line and set `METRICS_INTERFACE` to `127.0.0.1`.
      - Define the target(s) for the pushgateway with `PUSHGATEWAY_URL` (multiple targets can be separated by commas).

        The default value points to a pushgateway operated by the Shutter Network team. To gain access please ask for credentials in the Shutter Network Discourse forum.
  - Logging collection (optional):
    - To push logs to loki/vmlogs server:
      - Define the url for the server to push logs to, with `LOKI_URL`. The default value points to the logging server operated by the Shutter Network Team. To gain access please ask for credentials in the Shutter Network Discourse forum.
      - Use the `docker-compose.loki.yml` file, which overrides logging, as shown under the running and update sections.

> **NOTE**: The `example-api.env` file is a template for the Shutter API Keyper deployment on Gnosis Mainnet.

## Setting Up Logging

To enable log pushing to a Loki/VmLogs server, follow these steps:

1. Update `.env` to include Loki logs configuration using the credentials provided by the Shutter team:

    ```sh
    LOKI_URL=https://<user_id>:<password>@logs.metrics.shutter.network/insert/loki/api/v1/push
    ```

   If your password contains special characters, you must URL encode it before using it in the URL. For example:

    ```sh
    printf %s 'my@password#1' | jq -sRr @uri
    ```

2. Install the Loki Docker driver (if not installed):

    ```sh
    docker plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions
    ```

   > **Note:** For **ARM64 hosts**, add `-arm64` to the image tag.

For more details, refer to the [Docker driver client | Grafana Loki documentation](https://grafana.com/docs/loki/latest/send-data/docker-driver/).

> **IMPORTANT:** If logging is enabled, make sure to use the correct `docker compose` commands as noted below.

## Running the Keyper Node

### **Without Pushing Logs**
To start the Keyper node run:
```sh
docker compose up -d
```

### **With Log Pushing Enabled**
> **IMPORTANT:** Logging requires additional configuration steps. Follow the [Logging Setup](#setting-up-logging) section before running the following command:
```sh
docker compose -f docker-compose.yml -f docker-compose.loki.yml up -d
```

## Backups

### New Backup and Restore Guide

We have introduced a new backup and restore process with dedicated scripts to make it easier and safer to preserve your Keyper’s data.

**All keypers should follow the new process** described in the [Backup and Restore Guide](https://github.com/shutter-network/shutter-keyper-deployment/blob/shutter-api/scripts/BACKUP_RESTORE.md)
) to ensure backups are complete and restores work correctly.

### Previous Manual Backup

(Deprecated – use only for reference.)

If you are still using the manual process, regularly back up the following:

- `.env`
- `./config`
- `./data`

These files will allow you to re-build your Keyper in case of data loss.

## **Updating**

### **Without Pushing Logs**

```shell
cd shutter-keyper-deployment
git fetch
git checkout shutter-api-keyper/<new-version-tag>
docker compose up -d
```

### **Updating with Log Pushing Enabled**
> **IMPORTANT:** If logging is enabled, ensure you follow the [Logging Setup](#setting-up-logging) section first. Then, use the correct command:
```sh
cd shutter-keyper-deployment
git fetch
git checkout shutter-api-keyper/<new-version-tag>
docker compose -f docker-compose.yml -f docker-compose.loki.yml up -d
```

## Version History

### `shutter-api-keyper/2026.03.01` – `2026-03-10`
Important: This release introduces a new API Keyper set deployment with new assets and Keyper image 1.4.0. Do not update an existing API Keyper from earlier releases to this one. To run this release, operators should start from a fresh setup.

- Upgrade assets version to v1.0.2
- Add shutter-api-gnosis-1002 deployment

### `shutter-api-keyper/2025.12.01` – `2025-12-18`
- Upgrade to [Keyper v1.4.0](https://github.com/shutter-network/rolling-shutter/releases/tag/v1.4.0)
- Add support for event-based decryption conditions via ShutterEventTriggerRegistry (not enabled in this release)
- Fix compatibility for previous eons
- Fix event-based decryption trigger DB migration
- Fix decryption_key endpoint
- Fix keyper hanging issue
- Update handler and middleware to allow no sig on keys message and no check on decryption trigger

### `shutter-api-keyper/2025.11.01` – `2025-11-03`
- Upgrade to [Keyper v1.3.13](https://github.com/shutter-network/rolling-shutter/releases/tag/v1.3.13)
- Fix Shuttermint block processing
- Add DKG message sent/received metrics for improved observability of DKG communication

### `shutter-api-keyper/2025.08.01`
- Upgrade to [rolling-shutter v1.3.12](https://github.com/shutter-network/rolling-shutter/releases/tag/v1.3.12)
- Add logic to allow for DB migrations
- Fix issue with context cancellation
- Improve keyper metrics to include DKG results, ETH address and EL/CL clients
- Introduced a new backup and restore process with dedicated scripts.
  The previous manual backup method is now deprecated — operators should follow
  the new [Backup and Restore Guide](https://github.com/shutter-network/shutter-keyper-deployment/blob/shutter-api/scripts/BACKUP_RESTORE.md).

### `shutter-api-keyper/2025.07.01`
- Upgrade to [rolling-shutter v1.3.10](https://github.com/shutter-network/rolling-shutter/releases/tag/v1.3.10)
- Add middleware to enable/disable read only endpoints
- Add config to enable HTTP endpoints 

### `shutter-api-keyper/2025.05.03`
- Upgrade assets version to v0.0.1
- Add additional bootnode to CustomBootstrapAddresses
- Include SYNC_MONITOR_CHECK_INTERVAL as a configurable variable
- Update keyper configuration script to support the new variable

### `shutter-api-keyper/2025.05.02`
- Library upgrades: libp2p-kad-dht, libp2p-pubsub
- Remove sync monitor temporary fix

### `shutter-api-keyper/2025.05.01`
- Synch monitor temporary fix: Explicit panic on context cancellation.

### `shutter-api-keyper/2025.04.03`
- Sync monitor fix not to halt the system on reorgs

### `shutter-api-keyper/2025.04.02`
- Go version upgrade
- libp2p, go-ethereum, blst library upgrades
- Pectra upgrade compatibility
- sync monitor update for not checking dkg status

### `shutter-api-keyper/2025.04.01`
- Added sync monitor for api keyper

### `shutter-api-keyper/2025.03.01`
- Enabled log collection from keypers for better monitoring and issue detection.
- Fixed docker port mapping to ensure proper connectivity when behind an external firewall.

### `shutter-api-keyper/2025.02.01`
- initial public release

## Contract Deployments
```txt
  Deployer: 0x7D18359c2f49e4aEBc0df761B1152c31DE044e83
  ---------------------------------------------------
  RegistryContract: 0x694e5de9345d39C148DA90e6939A3fd2142267D9
  KeysetManagerContract: 0xFaB842d8Ff826E93D31f839AD47218d8c9511cC6
  KeyBroadcastContract: 0x474079EFa5D93bb48a1cA27Ebbf46d32E273A28b
```