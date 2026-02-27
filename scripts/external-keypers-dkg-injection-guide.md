# External Keypers: How to use DKG injection script

This guide describes the process for external keypers to use DKG injection script in the **shutter-api-1002** deployment, using the same signing keys as the initial keypers deployment.

---

## Prerequisites

- Access to the **shutter-api-1002** deployment environment
- The same signing keys used for initial keypers deployment
- Backup from the initial keypers
- The DKG injection script (`inject_dkg_result.sh`)

---

## Process Steps

### 1. Run Keypers with Same Signing Keys

In the **shutter-api-1002** deployment, run the keypers with the **same signing keys** that were used previously for the initial keypers deployment.

### 2. Wait for Keypers to Sync

Wait for the keypers to sync with the network before proceeding.

### 3. Keyper Set Transition

**Shutter team** will execute a new **keyper set transition**. After the keyper set transition is completed, a new eon key will be generated.

### 4. Obtain Backup from Initial Keypers

Ensure you have the **backup from the initial keypers** available. This backup is required for the DKG injection step.

### 5. Run DKG Injection Script

Run the DKG injection script with the backup path:

```bash
./inject_dkg_result.sh <path_to_backup>
```

Replace `<path_to_backup>` with the actual path to your backup.

### 6. Verify in Database

After the script runs successfully, verify the injection by checking the database:

- Query the **`keyper_set`** table for **`keyper_config_index = 11`** (eon 11)
- Confirm that your keyper is now included in the eon 11 keypers

```sql
select * from keyper_set where keyper_config_index = 11;
```

---

## Summary Checklist

| Step | Action |
|------|--------|
| 1 | Run keypers in shutter-api-1002 with same signing keys as initial keypers |
| 2 | Wait for keypers to sync |
| 3 | Perform new keyper set transition (AddKeyperSet) |
| 4 | Obtain backup from initial keypers |
| 5 | Run `./inject_dkg_result.sh <path_to_backup>` |
| 6 | Verify in DB: eon 11 `keyper_set` contains your keyper |
