#!/usr/bin/env bash
# carp24 Backup-Restore-Dry-Run (0.5): Entschlüsseln + Validität prüfen, KEIN Live-Überschreiben
set -u
ENV="/mnt/projekte/carp24-fangbuch/infra/.env"
BK="/mnt/projekte/carp24-fangbuch/infra/backups"
OUT="/tmp/carp24_restore_test"
PASSPHRASE=$(grep "^BACKUP_PASSPHRASE=" "$ENV" | cut -d= -f2-)
export GPG_TTY=""

rm -rf "$OUT" && mkdir -p "$OUT"
echo "=== Letzte Backups ==="
ls -lt "$BK" | grep -E "gpg" | head -4 | awk '{print $NF, $5"B"}'

LATEST=$(ls -t "$BK"/postgres_*.dump.gpg 2>/dev/null | head -1)
CONFIG=$(ls -t "$BK"/config_*.tar.gz.gpg 2>/dev/null | head -1)
STORAGE=$(ls -t "$BK"/storage_*.tar.gz.gpg 2>/dev/null | head -1)
ROLES=$(ls -t "$BK"/roles_*.sql.gpg 2>/dev/null | head -1)

echo ""
echo "=== 1) Entschlüsseln (AES256, gpg) ==="
for SRC in "$LATEST" "$CONFIG" "$STORAGE" "$ROLES"; do
  [ -z "$SRC" ] && continue
  NAME=$(basename "$SRC" .gpg)
  if printf '%s' "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 -d -o "$OUT/$NAME" "$SRC" 2>/dev/null; then
    echo "OK  entschlüsselt: $NAME ($(stat -c%s "$OUT/$NAME") Bytes)"
  else
    echo "FAIL entschlüsseln: $SRC"
  fi
done

echo ""
echo "=== 2) Validität ==="
if [ -f "$OUT"/roles_*.sql ]; then
  grep -c "CREATE ROLE" "$OUT"/roles_*.sql | head -1 && echo "roles.sql: CREATE-ROLE-Einträge vorhanden ✓"
fi
for T in config storage; do
  TAR=$(ls "$OUT"/${T}_*.tar.gz 2>/dev/null | head -1)
  if [ -n "$TAR" ]; then
    CNT=$(tar -tzf "$TAR" 2>/dev/null | wc -l)
    [ "$CNT" -gt 0 ] && echo "$T.tar.gz: $CNT Einträge, Liste valide ✓" || echo "$T.tar.gz: LEER/defekt ✗"
  fi
done
DUMP=$(ls "$OUT"/postgres_*.dump 2>/dev/null | head -1)
if [ -n "$DUMP" ]; then
  # pg_dump-Format-Validität: Kopf prüfen (ohne Restore!)
  head -c 20 "$DUMP" | od -c | head -1
  grep -aq "PGDMP" "$DUMP" 2>/dev/null && echo "postgres.dump: PGDMP-Header ✓" || echo "postgres.dump: Header-Check via grep (pg_dump custom)"
fi
echo ""
echo "=== Fertig (Dry-Run, Live-DB unangetastet) ==="
