#!/usr/bin/env bash

set -e

echo "Checking for backup dump file..."
if [ -f "/var/lib/postgresql/dump/keyper.dump" ]; then
    echo "Backup dump found, restoring database with full schema and data..."
    # Create the database first
    createdb -U postgres keyper 2>/dev/null || echo "Database already exists"
    # Restore the database with full schema and data
    pg_restore -U postgres -d keyper --create --clean -v /var/lib/postgresql/dump/keyper.dump
    echo "Database restore completed."
else
    echo "No backup dump file found, creating fresh database..."
    createdb -U postgres keyper
fi
