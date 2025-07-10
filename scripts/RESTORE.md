# Backup and Restore Guide

## Backup Process

### Creating a Backup

1. **Ensure services are running** - The backup process requires the database to be accessible
2. **Run the backup script**:
   ```bash
   ./scripts/backup.sh
   ```
3. **Backup location** - Backups are stored in `data/backups/` directory
4. **Backup naming** - Files are named with timestamp: `shutter-api-keyper-YYYY-MM-DDTHH-MM-SS.tar.xz`

### What Gets Backed Up

- Database dump (`keyper.dump`) - Contains full schema and data from the `keyper` database
- Chain data (`data/chain/`) - Blockchain data and configuration
- Keyper configuration (`config/`) - Application configuration files
- Environment variables - Except Signing Key

## Restore Process

### Prerequisites

- **Empty keyper instance** - The restore *must* be performed on a fresh, empty deployment
- **No running services** - Ensure all Docker containers are stopped before restore
- **Backup file available** - The backup archive should be present in `data/backups/` directory

### Restore Steps

1. **Setup environment**:
   ```bash
   cp example-api.env .env
   # Edit .env with your configuration values
   ```

2. **Run restore script**:
   ```bash
   ./scripts/restore.sh
   ```
   - This will automatically find the latest backup in `data/backups/`
   - Prompts for confirmation before proceeding
   - Restores all data to appropriate locations

3. **Set the Signing Key**:
   - After restoring, update the `.env` file by setting the `SIGNING_KEY` environment variable to the same value used in your original deployment.

4. **Start services**:
   ```bash
   docker compose up -d
   ```

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

### Troubleshooting

- **No backup found** - Ensure backup files exist in `data/backups/` directory
- **Permission errors** - Ensure proper file permissions on backup files
- **Configuration issues** - Verify that restored configuration files are valid
