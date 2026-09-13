#!/bin/bash
# Dev-Server Start-Script — lädt .env und setzt externe Supabase-URL
cd /mnt/projekte/carp24-fangbuch/web

# .env laden (alle Variablen exportieren)
set -a
source .env
set +a

# Überschreibe URLs für Host-Betrieb (Docker-Hostnamen nicht auflösbar)
export PUBLIC_SUPABASE_URL=http://100.93.250.103:8055
export SUPABASE_URL=http://100.93.250.103:8055
export HOST=0.0.0.0
export PORT=8094

exec node dist/server/entry.mjs
