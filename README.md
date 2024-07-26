# Gnosis Keyper

This repository contains the docker compose configuration to run a gnosis Keyper.

## Prerequisites

### Gnosis beacon and execution clients

Keypers are required to have access to a Gnosis Chain [consensus client API](https://ethereum.github.io/beacon-APIs/).
If you need to host these, please refer to https://docs.gnosischain.com/node. Please note, that additional system requirements to run gnosis chain nodes
are not part of the section below and need to be considered explicitly.

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
git checkout gnosis/v1.2.1
```

2. Copy the `example.env` file to `.env` and fill in your information:
   - **Required values**
     - Your Ethereum account key (hex-encoded *without* `0x` prefix): `SIGNING_KEY`

       **IMPORTANT**: Please double-check that you are using the key associated with the address that you provided during the Keyper application process. Otherwise, your Keyper node will not be able to join the network.
     - A name of your choice for your keyper node: `KEYPER_NAME`

       (Please use only letters, numbers, and underscores. No spaces or special characters.)
     - Your **public** IP address: `PUBLIC_IP`

       It is important that this is the address your node is reachable under from the internet since it is used for the P2P network between the nodes.
     - A Gnosis consensus / beacon chain API endpoint: `GNOSIS_BEACON_RPC_HTTP_URL`
     - A Gnosis execution JSON RPC API endpoint (HTTP): `GNOSIS_EXECUTION_RPC_HTTP_URL`
     - A Gnosis execution JSON RPC API endpoint (WebSocket): `GNOSIS_EXECUTION_RPC_WS_URL`
     - A Gnosis execution JSON RPC API endpoint (WebSocket): `GNOSIS_EXECUTION_RPC_WS_URL`
   - Metrics (optional):
     - To enable metrics, set `METRICS_ENABLED` to `true` (the default)
     - Define the interface the metrics ports (`:9100` and `:26660`) should be exposed on with `METRICS_INTERFACE` (defaults to `0.0.0.0`, i.e. the public interface)
     - If you rather not publicly expose the metrics and would like to push metrics instead, uncomment the `COMPOSE_PROFILES=pushmetrics` line and set `METRICS_INTERFACE` to `127.0.0.1`.
       - Define the target(s) for the pushgateway with `PUSHGATEWAY_URL` (multiple targets can be separated by commas).
         
         The default value points to a pushgateway operated by the Shutter Network team. To gain access please ask for credentials in the Shutter Network Discourse forum.     

## Running

You start your Keyper node by running

```
docker compose up -d
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
git checkout gnosis/<new-version-tag>
docker compose up -d
```

## Version History

### `gnosis/v1.2.1` - `2024-07-26`
- Improved handling of reorgs
- Improvements to libp2p connection handling
- Additional metrics to gain better insight into network health  

### `gnosis/v1.2.0` - `2024-07-16`
- Add minimal reorg resistance / replace data from reorged block
- Optimization on decryption key message validation
- Decrypt at least one transaction if possible (even if it's > encrypted gas limit)

### `gnosis/v1.1.0` - `2024-07-03`
- Use new sequencer contract `0xc5C4b277277A1A8401E0F039dfC49151bA64DC2E`
- Enable authentication for push metrics
  - Please note the slight change in the `.env` file (see `example.env`). 

    The properties `PUSHGATEWAY_USER` and `PUSHGATEWAY_PASSWORD` have been added.

### `gnosis/v1.0.1` - `2024-06-26`
Fix small typo in `.env` example file

### `gnosis/v1.0.0` - `2024-06-26`
Initial public release

### Contract Deployments
```txt
  Deployer: 0x8A7589135584CECFA5Bd73De02864075232407DD
-----------------------------------------------------------------------
  Sequencer: 0xc5C4b277277A1A8401E0F039dfC49151bA64DC2E
  ValidatorRegistry: 0xefCC23E71f6bA9B22C4D28F7588141d44496A6D6
  keyperSetManager: 0x7C2337f9bFce19d8970661DA50dE8DD7d3D34abb
  keyBroadcastContract: 0x626dB87f9a9aC47070016A50e802dd5974341301
```
