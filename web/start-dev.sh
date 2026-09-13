#!/bin/bash
# Dev-Server Start-Script — lädt .env und setzt externe Supabase-URL
cd /mnt/projekte/carp24-fangbuch/web

# .env laden (alle Variablen exportieren)
set -a
source .env
set +a

# Überschreibe PUBLIC_SUPABASE_URL für Host-Betrieb (Docker-Hostnamen nicht auflösbar)
export PUBLIC_SUPABASE_URL=http://100.93.250.103:8055

HOST=0.0.0.0 PORT=8094 node dist/server/entry.mjs
