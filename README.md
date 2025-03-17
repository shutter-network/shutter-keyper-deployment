# Shutter API Keyper

This repository contains the docker compose configuration to run a shutter api keyper.

## Prerequisites

### Chain execution clients

Keypers are required to have access to a the Chain's execution client API, where the shutter registry and keyperset manager contracts are deployed.

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

> *) **NOTE**: The `example-mainnet.env` file is a template for Gnosis mainnet deployment. If you want to deploy a Keyper for the Chiado testnet instead, use the `example-chiado.env` file.

## Running

You start your Keyper node by running

```
docker compose up -d
```

### To run with pushing logs to loki

Firstly, it needs loki docker driver installed, which can be done by following command:
```
docker plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions
```

Now, after setting env variable accordingly, to start keyper with push logs enabled, run following command:
```
docker compose -f docker-compose.yml -f docker-compose.loki.yml up -d
```

## Backups

Once your Keyper is up and running, you should regularly back up the following:

- `.env`
- `./config`
- `./data`

These files will allow you to re-build your Keyper in case of data loss.

## Updating

```shell
cd shutter-keyper-deployment
git fetch
git checkout shutter-api/<new-version-tag>
docker compose up -d
```

If using loki push logs then instead on runing `docker compose up -d`, run the following
```
docker compose -f docker-compose.yml -f docker-compose.loki.yml up -d
```

## Version History
### `shutter-api-keyper/2025.02.01`
- initial public release

## Contract Deployments
```txt
  Deployer: 0x7D18359c2f49e4aEBc0df761B1152c31DE044e83
  ---------------------------------------------------
  RegistryContract: 0x7D18359c2f49e4aEBc0df761B1152c31DE044e83
  KeysetManagerContract: 0xFaB842d8Ff826E93D31f839AD47218d8c9511cC6
  KeyBroadcastContract: 0x474079EFa5D93bb48a1cA27Ebbf46d32E273A28b
```
