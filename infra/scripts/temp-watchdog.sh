#!/usr/bin/env bash
# temp-watchdog — ENDGÜLTIGER Schutz gegen E2E-Chromium-Leichen + Überhitzung (carp24/Server-Betrieb)
# Läuft via systemd-Timer alle 10 Min (temp-watchdog.timer).
# Sicherheitsregeln:
#  - Killt IMMER nur Playwright-Chromium-Leichen (Pfad enthält ms-playwright), älter als 5 Min
#    → trifft NIE Philipps manuellen GUI-Chrome (/opt/google/chrome, hat DISPLAY)
#  - Bei Temp > 80°C zusätzlich ALLE Chrome/Chromium-Prozesse OHNE DISPLAY/WAYLAND (Headless-Leichen)
# Log: /var/log/temp-watchdog.log
set -u
LOG=/var/log/temp-watchdog.log

ts() { date '+%F %T'; }

temp() {
  local v
  if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    v=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
  elif command -v sensors >/dev/null 2>&1; then
    v=$(sensors -j 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);ts=[v.get('temp1_input',0) for c in d.values() if isinstance(c,dict) for k,v in c.items() if k.startswith('temp') and isinstance(v,dict)];print(f'{max(ts):.1f}' if ts else '0')")
  else v="0"; fi
  # Dezimal-Komma (de_DE-Locale) → Punkt, damit awk/Log konsistent rechnen
  printf '%s' "$v" | tr ',' '.'
}

T=$(temp)
KILLED=0
EXTRA=0

# 1) IMMER: Playwright-Leichen > 300s killen
while read -r pid etimes; do
  [ -n "${pid:-}" ] || continue
  if [ "${etimes:-0}" -gt 300 ]; then
    kill -9 "$pid" 2>/dev/null && KILLED=$((KILLED + 1))
  fi
done < <(ps -eo pid,etimes,args | grep -E 'ms-playwright' | grep -v grep | awk '{print $1, $2}')

# 2) Bei > 80°C: Headless-Leichen (kein DISPLAY/WAYLAND/XDG_SESSION_TYPE)
if awk "BEGIN{exit !($T > 80)}"; then
  while read -r pid; do
    [ -n "${pid:-}" ] || continue
    if ! tr '\0' '\n' < /proc/"$pid"/environ 2>/dev/null | grep -qE '^(DISPLAY|WAYLAND_DISPLAY|XDG_SESSION_TYPE)=.+'; then
      kill -9 "$pid" 2>/dev/null && EXTRA=$((EXTRA + 1))
    fi
  done < <(ps -eo pid,args | grep -iE 'chrome|chromium' | grep -v grep | awk '{print $1}')
fi

echo "$(ts) temp=${T}C playwright_killed=${KILLED} extra_killed=${EXTRA}" >> "$LOG"
if [ "$KILLED" -gt 0 ] || [ "$EXTRA" -gt 0 ]; then
  echo "$(ts) AKTION: ${KILLED} Playwright- + ${EXTRA} Headless-Leichen gekillt" >> "$LOG"
fi
