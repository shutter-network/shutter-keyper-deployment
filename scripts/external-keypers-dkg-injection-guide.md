# How to use the key injection script to restore the time capsule key shares into an existing instance

This guide describes the process to inject the Ethereum Time Capsule Key shares generated under the initial deployment of the Shutter API Keyper set and backed up under the following deployment: https://github.com/shutter-network/shutter-keyper-deployment/releases/tag/shutter-api-keyper%2F2025.08.01

This is needed to generate the time capsule decryption keys when the decryption timestamp is reached.

Initial Keypers refer to the Keypers who were active during eon 11 of the afore-mentioned API Keyper deployment. Timestamp range: Mar-24-2025 01:03:45 PM UTC (1742821425) - Dec-01-2025 11:25:35 AM UTC (1764588335).

## Prerequisites

- Fully synced Keyper running the latest Shutter API 1002 deployment version. Release: https://github.com/shutter-network/shutter-keyper-deployment/releases/tag/shutter-api-keyper%2F2026.04.03.
- The same Ethereum signing key used during the time capsule key collection.
- Backup of the initial Keyper keys requested in November 2025.

## Process Steps

### 1. Deploy a Keyper instance with the correct Ethereum key

All Keypers have already been requested to start a new instance with the Ethereum signing key they used during the time capsule key generation; This step has already been performed and all Keypers are running this release with the Ethereum signing key used during the time capsule collection: https://github.com/shutter-network/shutter-keyper-deployment/releases/tag/shutter-api-keyper%2F2026.04.03

### 2. Check that your Keyper Gnosis chain is sufficiently synched to the top of the chain

The synching status can be confirmed if you see the below logs:

```
synced registry contract end-block=20044460 num-discarded-events=0 num-inserted-events=0 start-block=20044460
```

The **end-block** should greater than block 44980000 (Mar 4, 2026).

Note: Some Keypers have been running into rate-limiting issues and are not able to synch fully. This is currently not an issue as long as they are synched past the required activation block number which they already are.

### 3. Ensure the backup is copied to the same instance

Copy the November Time capsule backup to the same instance where the Keyper is running under a designated folder different from the standard backup folder, to keep backups separate.

### 4. Run the DKG injection script

Run the DKG injection script and provide the correct time capsule backup path:

```bash
./scripts/inject_dkg_result.sh <path_to_backup>
```

Replace `<path_to_backup>` with the actual path to your time capsule backup.

Check if there is no error in running the script. The output should look something like this:

```
==> Checking shuttermint sync block number >= 349800
==> Stopping keyper service
==> Extracting keyper DB from backup
==> Starting backup container
==> Waiting for backup DB to become ready
==> Restoring dump into backup DB
==> Checking backup DB state
==> Checking if backup tables already exist
==> Backing up tables
==> Injecting DKG result
==> Done
==> Stopping backup container
==> Restarting keyper service (was running before)
```
