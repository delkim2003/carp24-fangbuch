#!/bin/bash
# === carp24 Backup (BAUPLAN Task 0.5 — STUB/Basis) ===
# Ziel (final, Task 0.5): pg_dump + Storage offsite + verschlüsselt, täglich, Restore-Dry-Run.
# Stand 19.08.2026: Grundgerüst — Task 0.3 (DDL) läuft noch, daher leere DB zu sichern.
# Nach 0.3: pg_dump auf volles Schema erweitern, Offsite-Ziel + Verschlüsselung ergänzen.

set -eu
DATE=$(date +%Y%m%d_%H%M)
BACKUP_DIR="${BACKUP_DIR:-/mnt/projekte/carp24-fangbuch/infra/backups}"
mkdir -p "$BACKUP_DIR"
LOG="$BACKUP_DIR/backup.log"

echo "[$DATE] carp24-Backup Start" >> "$LOG"

# 1) Postgres (pg_dump — volle DB, Postgres 17)
if docker exec supabase-db pg_dump -U postgres -Fc -d postgres > "$BACKUP_DIR/postgres_$DATE.dump" 2>> "$LOG"; then
  echo "[$DATE] pg_dump OK: $BACKUP_DIR/postgres_$DATE.dump ($(du -h "$BACKUP_DIR/postgres_$DATE.dump" | cut -f1))" >> "$LOG"
else
  echo "[$DATE] FEHLER: pg_dump schlug fehl" >> "$LOG"
  exit 1
fi

# 2) Storage (Uploads)
if [ -d /mnt/projekte/carp24-fangbuch/infra/volumes/storage ]; then
  tar -czf "$BACKUP_DIR/storage_$DATE.tar.gz" -C /mnt/projekte/carp24-fangbuch/infra/volumes storage 2>> "$LOG" \
    && echo "[$DATE] Storage-Tar OK" >> "$LOG" \
    || echo "[$DATE] FEHLER: Storage-Tar" >> "$LOG"
fi

# 3) Rotation: 7 tägliche Backups behalten
ls -t "$BACKUP_DIR"/postgres_*.dump 2>/dev/null | tail -n +8 | xargs -r rm -f
ls -t "$BACKUP_DIR"/storage_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

echo "[$DATE] Backup fertig (Rotation: 7)" >> "$LOG"
echo "✅ carp24-Backup OK — postgres_$DATE.dump"
