# Snapshot Keyper

This repository contains the docker compose configuration to run a snapshot keyper.

## Prerequisites

You will need a recent version of `docker` that bundles the `docker compose` command.

## Installation

### 1 
Clone or download this repository and open a shell inside it.

### 2
Edit the `example.env` file, fill in your information:

- your account key
- ...

Save the file as `.env`.

## Running

TODO

## Updating

TODO


## Developer Notes

The `docker-compose.yaml` intends to create the configuration files from scratch, with the help of some values set in
`.env`:

- `db` container has a db creation script mounted
- `assets` container contains the deployment files and shuttermint genesis file. It is a prerequisite for the `chain` and `keyper` containers, to mount the necessary assets.  **TODO**: needs to be finished when the
  image comes available
- `keyper-create-config` should run once, if there is no config file yet.
- `keyper-initdb` runs the `/rolling-shutter snapshotkeyper initdb` command
- `chain-init` sets up the shuttermint chain with the help of `genesis.json` from `assets` container
- `config-publickey` copies the `ValidatorPublicKey` from the `/chain` directory into the `keyper` configuration
- `chain` & `keyper` finally run the actual stack
