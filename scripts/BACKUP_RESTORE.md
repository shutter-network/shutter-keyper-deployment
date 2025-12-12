# Backup and Restore Guide

## Backup Process

### Creating a Backup

1. **Ensure services are running** - The backup process requires the database to be accessible
2. **Run the backup script**:
   ```bash
   # Use default backup directory (data/backups/)
   ./scripts/backup.sh
   
   # Use custom backup directory
   ./scripts/backup.sh /path/to/backups
   
   # Show help
   ./scripts/backup.sh -h
   ```
3. **Backup location** - Backups are stored in the specified directory (default: `data/backups/`)
4. **Backup naming** - Files are named with timestamp: `gnosis-keyper-YYYY-MM-DDTHH-MM-SS.tar.xz`
5. **Sanity check** - After the backup completes, verify in keyper logs that it resyncs events

### What Gets Backed Up

- Database dump (`keyper.dump`) - Contains full schema and data from the `keyper` database
- Chain data (`data/chain/`) - Blockchain data and configuration
- Keyper configuration (`config/`) - Application configuration files
- Environment variables - Except Signing Key

### What's NOT Backed Up

- **Signing Key** - The `SIGNING_KEY` environment variable is intentionally excluded from backups for security reasons. You must manually preserve this value separately.

### Security Considerations

⚠️ **IMPORTANT**: Backup files contain sensitive information including:
- Database contents with potentially sensitive data
- Configuration files that may contain API keys, passwords, or other secrets
- Chain data that could be used to reconstruct transaction history

**Security Best Practices:**
- Store backups on a different machine or secure cloud storage
- Limit access to backup files to authorized personnel only
- Consider using backup encryption tools for additional security

## Restore Process

### Prerequisites

- **Empty keyper instance** - The restore *must* be performed on a fresh, empty deployment
- **No running services** - Ensure all Docker containers are stopped before restore
- **Backup file available** - The backup archive should be present in the specified backup directory
- **Signing key available** - You must have the original `SIGNING_KEY` value from your deployment

### Restore Steps

1. **Run restore script**:
   ```bash
   # Use default backup directory (data/backups/)
   ./scripts/restore.sh
   
   # Use custom backup directory
   ./scripts/restore.sh /path/to/backups
   
   # Show help
   ./scripts/restore.sh -h

   # Don't ask for confirmation
   ./scripts/restore.sh -y /path/to/backups
   ```
    - This will automatically find the latest backup in the specified directory
    - Prompts for confirmation before proceeding
    - Restores all data to appropriate locations

## 2. Set the Signing Key

- After restoring, update both configuration files with the same signing key used in your original deployment:

    - In `.env`, set:
      ```env
      SIGNING_KEY="YOUR_PRIVATE_KEY"
      ```

    - In `keyper-config/keyper.toml`, replace the `PrivateKey` field with the same value:
      ```toml
      PrivateKey = "YOUR_PRIVATE_KEY"
      ```

- **CRITICAL**: Without the correct signing key in **both** files, the restored deployment will not function properly and may not be able to process transactions.

3. **Start services**:
   If using loki log collection, please follow instructions given in README.md.

   For basic restart:
   ```bash
   docker compose up -d
   ```

4. **Environment file preservation**:
   The restore script automatically preserves any existing `.env` file by creating a timestamped backup (`.env.backup.YYYY-MM-DDTHH-MM-SS`) before overwriting it with restored configuration. This ensures no environment variables are lost during the restore process.

### Restore Locations

- **Database**: `data/db-dump/keyper.dump` - Automatically restored to PostgreSQL
- **Chain data**: `data/chain/` - Keyper chain data and configuration
- **Configuration**: `config/` - Application configuration files
- **Environment**: `.env` - Updated with restored metrics settings

### Important Notes

- **Database restoration** - The database is automatically restored on first startup via the initialization script
- **Service order** - Restore must be completed before starting any services
- **Data integrity** - The restore process overwrites existing data; ensure you have a clean instance
- **Configuration review** - Review restored configuration files before starting services
- **Backup directory** - Both scripts accept an optional backup directory parameter, defaulting to `data/backups/`
- **Incomplete recovery** - Backups do not contain the signing key; manual intervention is required to complete the restore
- **Security** - Restored data may contain sensitive information; ensure proper access controls are in place

### Troubleshooting

- **No backup found** - Ensure backup files exist in the specified backup directory
- **Permission errors** - Ensure proper file permissions on backup files and directories
- **Configuration issues** - Verify that restored configuration files are valid
- **Custom backup locations** - When using custom backup directories, ensure the path is accessible and writable
- **Missing signing key** - You should be able to have original signing key at the time of restore.
