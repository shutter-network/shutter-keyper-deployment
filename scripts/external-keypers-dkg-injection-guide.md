# External Keypers: How to use DKG injection script

This guide describes the process for how external keypers can use DKG injection script in the **shutter-api-1002** deployment.

## Purpose

To restore key material generated during previous deployment, necessary to fulfill pending decryption tasks.

---

**Initial Keypers**: Keypers who were active during **eon 11**. Timestamp range: Mar-24-2025 01:03:45 PM UTC (1742821425) - Dec-01-2025 11:25:35 AM UTC (1764588335).

---

## Prerequisites

- Fully synced keyper running the shutter-api-1002 deployment version
- The same signing keys used for initial keypers deployment
- Backup from the initial keypers

---

## Process Steps

### 1. Run Keypers with Same Signing Keys

In the **shutter-api-1002** deployment, run the keypers with the **same signing keys** that were used previously for the initial keypers deployment and wait for them to sync with the network.

Sync can be confirmed by this log line.
```
synced registry contract end-block=20044460 num-discarded-events=0 num-inserted-events=0 start-block=20044460
```
The **end-block** should be (or greater than) the current head of the chain in the explorer.

### 2. Ensure the backup is copied to the same instance

Copy the backup to the same instance where the keyper is running.

### 3. Run DKG Injection Script

After a keyperset transition is done, run the DKG injection script with the backup path:

```bash
curl -fsSL https://raw.githubusercontent.com/shutter-network/shutter-keyper-deployment/feat/dkg-result-injection/scripts/inject_dkg_result.sh | bash -s -- <path_to_backup>
```

Replace `<path_to_backup>` with the actual path to your backup.

Check if there is no error in running the script.

---

## Summary Checklist

| Step | Action |
|------|--------|
| 1 | Run keypers in shutter-api-1002 with same signing keys as initial keypers and wait for keypers to sync  |
| 2 | Ensure the backup is copied to the same instance |
| 3 | Run DKG injection script with backup path |
