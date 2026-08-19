#!/bin/bash
# === carp24 Watchdog (Task 0.6) — RAM/Disk/Supabase-Health → Cron-Output für Telegram ===
# Wird vom Hermes-Cron aufgerufen; stdout = Telegram-Delivery.
# Ausgabe NUR bei Problemen (Watchdog-Pattern: still = alles gut).

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
if [ "$SWAP_TOTAL" -gt 0 ] && [ "$SWAP_FREE" -lt $((SWAP_TOTAL / 10)) ]; then
  OUT="${OUT}⚠️ Swap fast voll (frei ${SWAP_FREE}kB / ${SWAP_TOTAL}kB)\n"
  FAILS=$((FAILS+1))
fi

# 3) Disk
DISK_PCT=$(df /mnt/projekte --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
if [ "${DISK_PCT:-0}" -gt 85 ]; then
  OUT="${OUT}❌ Disk /mnt/projekte ${DISK_PCT}% voll\n"
  FAILS=$((FAILS+1))
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
