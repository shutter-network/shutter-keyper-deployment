# STILL WIP - DO NOT USE YET

# Snapshot Keyper

This repository contains the docker compose configuration to run a snapshot keyper.

## Prerequisites

You will need a recent version of `docker` that bundles the `docker compose` command.

## Installation

### 1
Clone or download this repository and open a shell inside it.

### 2
Edit the `example.env` file, fill in your information:

- your account key: `SIGNING_KEY`
- a name for your keyper node: `KEYPER_NAME`
- your **public** IP address: `PUBLIC_IP`

Save the file as `.env`.

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
