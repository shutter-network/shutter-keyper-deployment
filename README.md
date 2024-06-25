# Gnosis Keyper

This repository contains the docker compose configuration to run a gnosis Keyper.

## Prerequisites

### Gnosis beacon and execution clients

Keypers are required to have access to a Gnosis Chain [consensus client API](https://ethereum.github.io/beacon-APIs/).
If you need to host these, please refer to https://docs.gnosischain.com/node. Please note, that additional system requirements to run gnosis chain nodes
are not part of the section below and need to be considered explicitly.

### System requirements

The computational requirements for running a Keyper node for the Shutter Network are pretty low.

However, it must be ensured that the Keyper remains online and available as much as possible since a supermajority of all Keypers is required for decryption key generation to work.

To ensure availability, the system running the Keyper must have a permanent internet connection (i.e., no residential DSL, cable, etc. connections.) and a static public IPv4 address.

We recommend the following minimum hardware specs:

- 2 CPU core
- 4 GB RAM
- \>20GB disk

We also strongly advise using a monitoring system to ensure continued availability. Reliable uptime is highly requested.
Shutter Network / brainbot does operate a prometheus compatible monitoring system. See below for details.

### Software

- You will need a recent version of `docker` and the `docker compose` cli plugin. 
- For cloning the repository you will need `git`.

The Keyper node is distributed as a docker-compose stack consisting of multiple services. This repository contains all necessary files.

One component is opt-in monitoring, which by default requires opening a port for scrape access to the metrics endpoints, 
as well as a public IP address that needs to be shared with the Shutter team if you wish to participate in system-wide 
monitoring of the nodes.
If you would rather not open up the metrics endpoints support for push based metrics will be added in the near future. 

Personal monitoring is also possible, but we feel it would be great to have an overview of the whole system as well.


## Installation

1. Clone this repository and open a shell inside it:

   ```shell
   git clone --branch gnosis/main https://github.com/shutter-network/shutter-keyper-deployment.git
   cd shutter-keyper-deployment
   ```

2. Copy the `example.env` file to `.env` and fill in your information:
   - Your Ethereum account key (hex-encoded without `0x` prefix): `SIGNING_KEY`
     
     **IMPORTANT**: Please double-check that you are using the key associated with the address that you provided during the Keyper application process. Otherwise, your Keyper node will not be able to join the network.
   - A name of your choice for your keyper node: `KEYPER_NAME`
   - Your **public** IP address: `PUBLIC_IP`
   - A Gnosis consensus / beacon chain API endpoint: `GNOSIS_BEACON_RPC_HTTP_URL`
   - A Gnosis execution JSON RPC API endpoint (HTTP): `GNOSIS_EXECUTION_RPC_HTTP_URL`
   - A Gnosis execution JSON RPC API endpoint (WebSocket): `GNOSIS_EXECUTION_RPC_WS_URL`

     It is important that this is the address your node is reachable under from the internet since it is used for the P2P network between the nodes.

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

TBD

## Version History

### `v1.0.0` - `2023-09-21`

Initial public release
