#!/bin/bash
# === carp24 Restore (P0.5) ===
# Nutzung: ./restore.sh <backup-file.dump.gpg> [--dry-run|--live]
# Standard-Modus: --dry-run (Temp-DB, Verifikation, Aufräumen)
# --live: WIRKLICHE Wiederherstellung in postgres-DB (mit Bestätigung)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# --- Argumente prüfen ---
if [ $# -lt 1 ]; then
  echo "Nutzung: $0 <backup-file.dump.gpg> [--dry-run|--live]"
  echo ""
  echo "  --dry-run   (Standard) Restore in Temp-DB, Verifikation, Aufräumen"
  echo "  --live      Wirkliche Wiederherstellung in postgres-DB (DESTRUKTIV!)"
  exit 1
fi

BACKUP_FILE="$1"
MODE="${2:---dry-run}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "FEHLER: Backup-Datei nicht gefunden: $BACKUP_FILE" >&2
  exit 1
fi

# --- Temp-Datei aufräumen bei Exit ---
TMPFILE="/tmp/restore_$$.dump"
cleanup() {
  rm -f "$TMPFILE" 2>/dev/null || true
}
trap cleanup EXIT

# --- Entschlüsseln ---
echo "Entschlüssele $BACKUP_FILE ..."
if ! gpg --batch --yes --decrypt --passphrase "$BACKUP_PASSPHRASE" \
  -o "$TMPFILE" "$BACKUP_FILE" 2>/dev/null; then
  echo "FEHLER: Entschlüsselung fehlgeschlagen (falsche Passphrase?)" >&2
  exit 1
fi
echo "Entschlüsselt → $TMPFILE ($(du -h "$TMPFILE" | cut -f1))"

# --- DRY-RUN Modus (Standard) ---
if [ "$MODE" = "--dry-run" ]; then
  echo ""
  echo "=== DRY-RUN: Restore in Temp-DB restore_test ==="

  # Temp-DB anlegen (falls noch vorhanden → löschen)
  docker exec supabase-db dropdb -U supabase_admin --if-exists restore_test 2>/dev/null || true
  if ! docker exec supabase-db createdb -U supabase_admin restore_test 2>&1; then
    echo "FEHLER: Konnte restore_test nicht anlegen" >&2
    exit 1
  fi
  echo "Temp-DB restore_test angelegt."

  # pg_restore in Temp-DB
  echo "Starte pg_restore ..."
  if ! docker exec -i supabase-db pg_restore \
    -U supabase_admin -d restore_test \
    --no-owner --no-privileges < "$TMPFILE" 2>&1; then
    echo "WARNUNG: pg_restore meldete Warnungen (Exit ≠ 0), prüfe Tabellen-Count ..."
  fi

  # Verifikation: Tabellen-Count > 0
  TABLE_COUNT=$(docker exec supabase-db psql -U supabase_admin -d restore_test -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" 2>&1)

  if [ "$TABLE_COUNT" -gt 0 ] 2>/dev/null; then
    echo "✅ DRY-RUN BESTANDEN: $TABLE_COUNT Tabellen in public-Schema gefunden."
  else
    echo "❌ DRY-RUN FEHLGESCHLAGEN: Keine Tabellen in public-Schema (count=$TABLE_COUNT)." >&2
    docker exec supabase-db dropdb -U supabase_admin --if-exists restore_test 2>/dev/null || true
    exit 1
  fi

  # Temp-DB löschen
  docker exec supabase-db dropdb -U supabase_admin --if-exists restore_test 2>/dev/null || true
  echo "Temp-DB restore_test gelöscht."
  echo ""
  echo "✅ Restore Dry-Run BESTANDEN ($TABLE_COUNT Tabellen)"
  exit 0
fi

# --- LIVE Modus (--live) ---
if [ "$MODE" = "--live" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  ⚠️  LIVE-RESTORE: Überschreibt die postgres-DB ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  read -rp "Wirklich fortfahren? Tippe RESTORE zur Bestätigung: " CONFIRM
  if [ "$CONFIRM" != "RESTORE" ]; then
    echo "Abgebrochen."
    exit 0
  fi

  echo ""
  echo "⚠️  WARNUNG: Sicherstellen, dass die aktuelle .env (JWT_SECRET, ANON_KEY,"
  echo "   SERVICE_ROLE_KEY, POSTGRES_PASSWORD etc.) zur wiederhergestellten DB passt!"
  echo "   Falls die .env seit dem Backup geändert wurde: App kann brechen."
  echo "   → .env-Backup einspielen ODER Secrets manuell prüfen."
  echo ""

  echo "Starte pg_restore --clean --if-exists in postgres-DB ..."
  if ! docker exec -i supabase-db pg_restore \
    -U supabase_admin -d postgres \
    --clean --if-exists --no-owner --no-privileges < "$TMPFILE" 2>&1; then
    echo "WARNUNG: pg_restore meldete Warnungen."
  fi

  # Verifikation
  TABLE_COUNT=$(docker exec supabase-db psql -U supabase_admin -d postgres -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" 2>&1)
  echo "Tabellen in public-Schema nach Restore: $TABLE_COUNT"
  echo "✅ LIVE-RESTORE ABGESCHLOSSEN"
  exit 0
fi

echo "FEHLER: Unbekannter Modus '$MODE'. Nutze --dry-run oder --live." >&2
exit 1
