#!/bin/bash
# === carp24 Watchdog (Task 0.6) — RAM/Disk/Supabase-Health/Backup → Cron-Output für Telegram ===
# MASTER: /mnt/projekte/carp24-fangbuch/infra/monitoring/carp24-watchdog.sh
# SYNCHRON: wird nach jedem Update nach ~/.hermes/profiles/agentur-berater/scripts/ kopiert
# Wird vom Hermes-Cron aufgerufen; stdout = Telegram-Delivery.
# Ausgabe NUR bei Problemen (Watchdog-Pattern: still = alles gut).
#
# 27.09.2026 (Backup-Audit-Nachtrag):
#   - Backup-Check zeigt auf VAULT BACKUPS/carp24-live/ (LIVE-Backups, Audit Nr. 4)
#     statt Alt-Pfad infra/backups/ (DEV — seit 26.09. 02:30 bewusst NICHT gesichert,
#     Philipp: "Carp24 Dev braucht nicht gesichert werden nur carp24 live auf Hetzner").
#     Alt-Check = Ursache für 14 Dauer-Failed-Runs 27.09. (Fehlalarm auf totem Pfad).
#   - Dauer-Befunde (Backup stale/fehlt) max. 1×/12h melden: kein 30-Min-Spam
#     (gleiche Philosophie wie Swap-Warnung 24.08.). Unterdrückte Runs = still = exit 0,
#     sonst zählt Hermes "failed runs in a row" hoch und eskaliert erneut.
#   - Neuer/veränderter Befund meldet sofort (Key-Vergleich im Statefile).

set -u
DATE=$(date '+%d.%m.%Y %H:%M')
FAILS=0
OUT=""

# 1) Supabase-Container-Health
for c in supabase-db supabase-kong supabase-auth supabase-rest realtime-dev.supabase-realtime \
         supabase-storage supabase-imgproxy supabase-meta supabase-edge-functions \
         supabase-pooler supabase-studio; do
  S=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$c" 2>/dev/null)
  if [ "$S" != "healthy" ] && [ "$S" != "running" ]; then
    OUT="${OUT}❌ ${c}: ${S}\n"
    FAILS=$((FAILS+1))
  fi
done

# 2) RAM / Swap
MEM_TOTAL=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
SWAP_TOTAL=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/{print $2}' /proc/meminfo)
MEM_PCT=$(( (MEM_TOTAL - MEM_AVAIL) * 100 / MEM_TOTAL ))
if [ "$MEM_PCT" -gt 90 ]; then
  OUT="${OUT}❌ RAM ${MEM_PCT}% belegt (OOM-Gefahr)\n"
  FAILS=$((FAILS+1))
fi
# Swap-Warnung NUR bei akuter OOM-Gefahr (RAM > 85% UND Swap fast voll) —
# bekannt voll bis Reboot So 23.08. (MemAvailable reicht), sonst Spam alle 30 Min
if [ "$MEM_PCT" -gt 85 ] && [ "$SWAP_TOTAL" -gt 0 ] && [ "$SWAP_FREE" -lt $((SWAP_TOTAL / 10)) ]; then
  OUT="${OUT}❌ OOM-Gefahr: RAM ${MEM_PCT}% UND Swap fast voll (frei ${SWAP_FREE}kB)\n"
  FAILS=$((FAILS+1))
fi

# 3) Disk
DISK_PCT=$(df /mnt/projekte --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
if [ "${DISK_PCT:-0}" -gt 85 ]; then
  OUT="${OUT}❌ Disk /mnt/projekte ${DISK_PCT}% voll\n"
  FAILS=$((FAILS+1))
fi

# 4) Backup-Age (VAULT carp24-live: neuestes carp24-live_postgres_*.dump.gpg muss < 26h alt sein)
LIVE_DIR="/mnt/projekte/vault/02_SYSTEM/BACKUPS/carp24-live"
STATE="/home/philipp/.hermes/profiles/agentur-berater/cache/carp24-watchdog-backup-alarm"
mkdir -p "$(dirname "$STATE")"
BACKUP_MSG=""
LATEST_BACKUP=$(ls -t "$LIVE_DIR"/carp24-live_postgres_*.dump.gpg 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
  BACKUP_AGE_H=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 3600 ))
  if [ "$BACKUP_AGE_H" -gt 26 ]; then
    BACKUP_MSG="Backup zu alt: ${BACKUP_AGE_H}h (letztes: $(basename "$LATEST_BACKUP"))"
  fi
else
  BACKUP_MSG="KEIN carp24-live-Backup im Vault (${LIVE_DIR}) — LIVE-Daten ungesichert!"
fi

if [ -n "$BACKUP_MSG" ]; then
  NOW=$(date +%s)
  LAST_EPOCH=0
  LAST_KEY=""
  if [ -s "$STATE" ]; then read -r LAST_EPOCH LAST_KEY < "$STATE" || true; fi
  if [ "$BACKUP_MSG" != "${LAST_KEY:-}" ] || [ $((NOW - ${LAST_EPOCH:-0})) -gt 43200 ]; then
    OUT="${OUT}❌ ${BACKUP_MSG}\n"
    FAILS=$((FAILS+1))
    echo "$NOW $BACKUP_MSG" > "$STATE"
  fi
  # sonst: identischer Dauerbefund <12h alt → unterdrückt (still = exit 0, s. Header)
fi

if [ "$FAILS" -gt 0 ]; then
  echo "🐟 CARP24 WATCHDOG | $DATE"
  echo "══════════════════════════"
  printf "$OUT"
  echo "══════════════════════════"
  echo "❌ $FAILS Problem(e) — RAM ${MEM_PCT}% | Swap frei ${SWAP_FREE}kB | Disk ${DISK_PCT}%"
  exit 1
fi
# still = nichts melden (watchdog pattern)
exit 0