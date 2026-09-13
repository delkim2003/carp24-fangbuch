#!/bin/bash
cd /mnt/projekte/carp24-fangbuch/web
set -a
source .env
set +a
export PUBLIC_SUPABASE_URL=http://100.93.250.103:8055
export SUPABASE_URL=http://100.93.250.103:8055
exec HOST=0.0.0.0 PORT=8094 node dist/server/entry.mjs
