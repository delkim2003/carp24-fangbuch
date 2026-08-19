#!/bin/bash
# === carp24 Backup (P0.5 — verschlüsselt + offsite) ===
# Supabase self-hosted v1.26.08 / Postgres 17.6
# Täglicher Dump: pg_dump (supabase_admin) + Storage-Tar + Config-Tar → GPG AES256 → Offsite (Vault/GDrive)
# Rotation: 7 lokal + 7 offsite

set -euo pipefail

trap 'rm -f "$BACKUP_DIR"/postgres_*.dump "$BACKUP_DIR"/storage_*.tar.gz "$BACKUP_DIR"/config_*.tar.gz "$BACKUP_DIR"/roles_*.sql 2>/dev/null' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- .env laden (BACKUP_PASSPHRASE) ---
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "FEHLER: $ENV_FILE nicht gefunden." >&2
  exit 1
fi
set -a
source "$ENV_FILE"
set +a

if [ -z "${BACKUP_PASSPHRASE:-}" ]; then
  echo "FEHLER: BACKUP_PASSPHRASE nicht gesetzt in $ENV_FILE" >&2
  exit 1
fi

DATE=$(date +%Y%m%d_%H%M)
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
OFFSITE_DIR="/mnt/projekte/vault/02_SYSTEM/BACKUPS/carp24"
ROTATION_KEEP=7

mkdir -p "$BACKUP_DIR"
mkdir -p "$OFFSITE_DIR"

LOG="$BACKUP_DIR/backup.log"

log() {
  echo "[$DATE] $*" | tee -a "$LOG"
}

log "carp24-Backup Start"

# --- 1) Postgres pg_dump (supabase_admin, Custom format) ---
PG_DUMP_FILE="$BACKUP_DIR/postgres_$DATE.dump"
if docker exec supabase-db pg_dump -U supabase_admin -Fc -d postgres > "$PG_DUMP_FILE" 2>> "$LOG"; then
  log "pg_dump OK: $PG_DUMP_FILE ($(du -h "$PG_DUMP_FILE" | cut -f1))"
else
  log "FEHLER: pg_dump schlug fehl"
  exit 1
fi

# --- 1b) Rollen/Dump (pg_dumpall --globals-only) ---
ROLES_FILE="$BACKUP_DIR/roles_$DATE.sql"
if docker exec supabase-db pg_dumpall -U supabase_admin --globals-only > "$ROLES_FILE" 2>> "$LOG"; then
  log "Roles-Dump OK: $ROLES_FILE"
else
  log "FEHLER: Roles-Dump"
  exit 1
fi

# --- 2) Storage-Tar ---
STORAGE_TAR_FILE="$BACKUP_DIR/storage_$DATE.tar.gz"
STORAGE_PATH="$REPO_ROOT/infra/volumes/storage"
if [ -d "$STORAGE_PATH" ]; then
  if tar -czf "$STORAGE_TAR_FILE" -C "$REPO_ROOT/infra/volumes" storage 2>> "$LOG"; then
    log "Storage-Tar OK: $STORAGE_TAR_FILE ($(du -h "$STORAGE_TAR_FILE" | cut -f1))"
  else
    log "FEHLER: Storage-Tar schlug fehl"
    exit 1
  fi
else
  log "WARNUNG: Storage-Verzeichnis $STORAGE_PATH nicht gefunden — übersprungen"
fi

# --- 2b) Config-Tar (.env + docker-compose.yml + kong.yml) ---
CONFIG_TAR_FILE="$BACKUP_DIR/config_$DATE.tar.gz"
if [ -f "$SCRIPT_DIR/.env" ] || [ -f "$SCRIPT_DIR/docker-compose.yml" ] || [ -d "$SCRIPT_DIR/volumes/api" ]; then
  if tar -czf "$CONFIG_TAR_FILE" \
    -C "$SCRIPT_DIR" .env docker-compose.yml \
    -C "$SCRIPT_DIR/volumes/api" kong.yml 2>> "$LOG"; then
    log "Config-Tar OK: $CONFIG_TAR_FILE ($(du -h "$CONFIG_TAR_FILE" | cut -f1))"
  else
    log "FEHLER: Config-Tar schlug fehl"
    exit 1
  fi
else
  log "WARNUNG: Config-Dateien nicht gefunden — übersprungen"
fi

# --- 3) GPG-Verschlüsselung (AES256, symmetrisch) ---
PG_GPG_FILE="$BACKUP_DIR/postgres_$DATE.dump.gpg"
STORAGE_GPG_FILE="$BACKUP_DIR/storage_$DATE.tar.gz.gpg"
CONFIG_GPG_FILE="$BACKUP_DIR/config_$DATE.tar.gz.gpg"
ROLES_GPG_FILE="$BACKUP_DIR/roles_$DATE.sql.gpg"

gpg --batch --yes --symmetric --cipher-algo AES256 \
  --passphrase "$BACKUP_PASSPHRASE" \
  -o "$PG_GPG_FILE" "$PG_DUMP_FILE" 2>> "$LOG"
rm -f "$PG_DUMP_FILE"
log "GPG postgres OK: $PG_GPG_FILE ($(du -h "$PG_GPG_FILE" | cut -f1))"

if [ -f "$STORAGE_TAR_FILE" ]; then
  gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase "$BACKUP_PASSPHRASE" \
    -o "$STORAGE_GPG_FILE" "$STORAGE_TAR_FILE" 2>> "$LOG"
  rm -f "$STORAGE_TAR_FILE"
  log "GPG storage OK: $STORAGE_GPG_FILE ($(du -h "$STORAGE_GPG_FILE" | cut -f1))"
fi

if [ -f "$CONFIG_TAR_FILE" ]; then
  gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase "$BACKUP_PASSPHRASE" \
    -o "$CONFIG_GPG_FILE" "$CONFIG_TAR_FILE" 2>> "$LOG"
  rm -f "$CONFIG_TAR_FILE"
  log "GPG config OK: $CONFIG_GPG_FILE ($(du -h "$CONFIG_GPG_FILE" | cut -f1))"
fi

gpg --batch --yes --symmetric --cipher-algo AES256 \
  --passphrase "$BACKUP_PASSPHRASE" \
  -o "$ROLES_GPG_FILE" "$ROLES_FILE" 2>> "$LOG"
rm -f "$ROLES_FILE"
log "GPG roles OK: $ROLES_GPG_FILE ($(du -h "$ROLES_GPG_FILE" | cut -f1))"

# --- 4) Offsite-Kopie (Vault → Insync → Google Drive) ---
cp "$PG_GPG_FILE" "$OFFSITE_DIR/" 2>> "$LOG" && log "Offsite postgres OK → $OFFSITE_DIR/"
cp "$ROLES_GPG_FILE" "$OFFSITE_DIR/" 2>> "$LOG" && log "Offsite roles OK → $OFFSITE_DIR/"
if [ -f "$STORAGE_GPG_FILE" ]; then
  cp "$STORAGE_GPG_FILE" "$OFFSITE_DIR/" 2>> "$LOG" && log "Offsite storage OK → $OFFSITE_DIR/"
fi
if [ -f "$CONFIG_GPG_FILE" ]; then
  cp "$CONFIG_GPG_FILE" "$OFFSITE_DIR/" 2>> "$LOG" && log "Offsite config OK → $OFFSITE_DIR/"
fi

# --- 5) Rotation: 7 lokal (.gpg) ---
ls -t "$BACKUP_DIR"/postgres_*.dump.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$BACKUP_DIR"/storage_*.tar.gz.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$BACKUP_DIR"/config_*.tar.gz.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$BACKUP_DIR"/roles_*.sql.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
log "Rotation lokal: max $ROTATION_KEEP behalten"

# --- 5b) Rotation: 7 offsite (.gpg) ---
ls -t "$OFFSITE_DIR"/postgres_*.dump.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$OFFSITE_DIR"/storage_*.tar.gz.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$OFFSITE_DIR"/config_*.tar.gz.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
ls -t "$OFFSITE_DIR"/roles_*.sql.gpg 2>/dev/null | tail -n +$((ROTATION_KEEP + 1)) | xargs -r rm -f
log "Rotation offsite: max $ROTATION_KEEP behalten"

# --- 6) Abschluss ---
log "Backup fertig (verschlüsselt + offsite)"
echo "✅ carp24-Backup OK"
echo "   postgres: $PG_GPG_FILE ($(du -h "$PG_GPG_FILE" | cut -f1))"
echo "   roles:    $ROLES_GPG_FILE ($(du -h "$ROLES_GPG_FILE" | cut -f1))"
if [ -f "$STORAGE_GPG_FILE" ]; then
  echo "   storage:  $STORAGE_GPG_FILE ($(du -h "$STORAGE_GPG_FILE" | cut -f1))"
fi
if [ -f "$CONFIG_GPG_FILE" ]; then
  echo "   config:   $CONFIG_GPG_FILE ($(du -h "$CONFIG_GPG_FILE" | cut -f1))"
fi
