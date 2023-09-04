# STILL WIP - DO NOT USE YET

# Snapshot Keyper

This repository contains the docker compose configuration to run a snapshot keyper.

## Prerequisites


### System requirements

The computational requirements for running a Keyper node for the Shutter Network are pretty low.

However, it must be ensured that the Keyper remains online and available as much as possible since a supermajority of all Keypers is required for decryption key generation to work.

To ensure availability, the system running the Keyper must have a permanent internet connection (i.e., no residential DSL, cable, etc. connections.) and a static public IPv4 address.

We recommend the following minimum hardware specs:

- 1 CPU core
- 2 GB RAM
- 50GB disk

We also strongly advise using a monitoring system to ensure continued availability. Reliable uptime is highly requested.

### Software

- You will need a recent version of `docker` that bundles the `docker compose` command.  // TODO: which docker version @ ulo
- For cloning the repository you will need `git`.

The Keyper node is distributed as a docker-compose stack consisting of multiple services. This repository contains all necessary files.

Your node will, of course, also need access to a Gnosis Chain RPC. You can find a list of public RPC points [here at the GC docs](https://docs.gnosischain.com/tools/rpc/).

One component is opt-in monitoring, which requires opening a port for access to get the data, as well as a public IP address that needs to be shared with the Shutter team if you wish to participate in system-wide monitoring of the nodes. Personal monitoring is also possible, but we feel it would be great to have an overview of the whole system as well.

## Installation

### 1
Clone or download this repository and open a shell inside it.

### 2
Copy the `example.env` file to `.env` and fill in your information:

- your Ethereum account key: `SIGNING_KEY`
- a name of your choice for your keyper node: `KEYPER_NAME`
- your **public** IP address: `PUBLIC_IP`

## Running

You start your keyper node by running

```
docker compose up -d
```

## Backups

Once your keyper is up and running, you should backup the following files

- `.env`
- `./config`
- `./data/chain/config`

These files will allow you to re-build your keyper if your machine ever crashes.

## Updating

TODO


## Developer Notes

The `docker-compose.yaml` intends to create the configuration files from scratch, with the help of some values set in
`.env`:

- `db` container has a db creation script mounted
- `assets` container contains the deployment files and shuttermint genesis file. It is a prerequisite for the `chain` and `keyper` containers, to mount the necessary assets.
- `keyper-create-config` should run once, if there is no config file yet.
- `keyper-initdb` runs the `/rolling-shutter snapshotkeyper initdb` command
- `chain-init` sets up the shuttermint chain with the help of `genesis.json` from `assets` container
- `config-publickey` copies the `ValidatorPublicKey` from the `/chain` directory into the `keyper` configuration
- `config-chain` adjusts the shuttermint chain configuration according to environment variables and docker setup
- `chain` & `keyper` finally run the actual stack

### Debugging

The script `./dev/chain.sh` allows you to contact [the RPC API](https://docs.tendermint.com/v0.34/rpc/) of the shuttermint node, inside the docker network. Usage:

    ./dev/chain.sh ENDPOINT
    e.g.
    ./dev/chain.sh health
