#!/bin/bash
# ============================================================
# CARP24 DEPLOYMENT SCRIPT
# Führt einen sicheren Dev→Live-Transfer durch.
#
# Nutzung: ./deploy.sh [--dry-run]
# ============================================================
set -euo pipefail

LIVE_HOST="46.225.98.79"
LIVE_PORT="4321"
SSH_PORT="2222"
SSH_KEY="$HOME/.ssh/hetzner_carp24"
SSH_USER="philipp"
REMOTE_DIR="/opt/carp24"
LOCAL_DIR="/mnt/projekte/carp24-fangbuch/web"
IMAGE_NAME="carp24-app:latest"
CONTAINER_NAME="carp24-app"

DRY_RUN="${1:-}"

log() { echo "[DEPLOY $(date +%H:%M:%S)] $*"; }
fail() { log "❌ FEHLER: $*"; exit 1; }

# ── Schritt 1: Lokaler Build ──────────────────────────────
log "1/7 Lokaler Build..."
cd "$LOCAL_DIR"
npm run build 2>&1 | tail -3
log "✅ Build OK"

# ── Schritt 2: Pre-Deploy Smoke Test (lokal) ─────────────
log "2/7 Pre-Deploy Smoke Test (lokal)..."
# Starte temporären Server auf zufälligem Port
TEST_PORT=19876
HOST=0.0.0.0 PORT=$TEST_PORT node dist/server/entry.mjs &
TEST_PID=$!
sleep 3

# Smoke Tests
ERRORS=0
for path in "/" "/login" "/premium" "/datenschutz"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$TEST_PORT$path" 2>/dev/null)
  if [ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 500 ]; then
    log "❌ $path → HTTP $STATUS"
    ERRORS=$((ERRORS + 1))
  else
    log "✅ $path → HTTP $STATUS"
  fi
done

kill $TEST_PID 2>/dev/null || true

if [ "$ERRORS" -gt 0 ]; then
  fail "Pre-Deploy Smoke Test fehlgeschlagen ($ERRORS Fehler). Deploy abgebrochen."
fi
log "✅ Pre-Deploy Smoke Test bestanden"

# ── Schritt 3: Sync zu Live ──────────────────────────────
if [ "$DRY_RUN" = "--dry-run" ]; then
  log "3/7 DRY-RUN: Sync übersprungen"
else
  log "3/7 Sync dist/ zu Live..."
  rsync -avz \
    -e "ssh -p $SSH_PORT -i $SSH_KEY" \
    "$LOCAL_DIR/dist/" \
    "$SSH_USER@$LIVE_HOST:$REMOTE_DIR/dist/" 2>&1 | tail -3
  
  log "3/7 Sync src/ zu Live..."
  rsync -avz \
    -e "ssh -p $SSH_PORT -i $SSH_KEY" \
    --exclude 'node_modules' --exclude 'dist' --exclude '.env' --exclude '.env.*' --exclude 'start-dev*.sh' \
    "$LOCAL_DIR/src/" \
    "$SSH_USER@$LIVE_HOST:$REMOTE_DIR/src/" 2>&1 | tail -3
  
  log "3/7 Sync config-Dateien..."
  scp -P $SSH_PORT -i $SSH_KEY \
    "$LOCAL_DIR/package.json" \
    "$LOCAL_DIR/package-lock.json" \
    "$LOCAL_DIR/Dockerfile" \
    "$LOCAL_DIR/astro.config.mjs" \
    "$LOCAL_DIR/tsconfig.json" \
    "$SSH_USER@$LIVE_HOST:$REMOTE_DIR/"
  
  log "✅ Sync OK"
fi

# ── Schritt 4: Docker Build auf Live ─────────────────────
if [ "$DRY_RUN" = "--dry-run" ]; then
  log "4/7 DRY-RUN: Docker Build übersprungen"
else
  log "4/7 Docker Build auf Live (no-cache)..."
  ssh -p $SSH_PORT -i $SSH_KEY "$SSH_USER@$LIVE_HOST" "
    cd $REMOTE_DIR && docker build --no-cache -t $IMAGE_NAME . 2>&1 | tail -3
  "
  log "✅ Docker Build OK"
fi

# ── Schritt 5: Container Restart ─────────────────────────
if [ "$DRY_RUN" = "--dry-run" ]; then
  log "5/7 DRY-RUN: Container Restart übersprungen"
else
  log "5/7 Container Restart..."
  ssh -p $SSH_PORT -i $SSH_KEY "$SSH_USER@$LIVE_HOST" "
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    docker run -d --name $CONTAINER_NAME \
      --network supabase_default \
      --env-file $REMOTE_DIR/.env \
      -p $LIVE_PORT:$LIVE_PORT \
      --restart unless-stopped \
      $IMAGE_NAME
    sleep 5
  "
  log "✅ Container gestartet"
fi

# ── Schritt 6: Post-Deploy Smoke Test (Live) ─────────────
if [ "$DRY_RUN" = "--dry-run" ]; then
  log "6/7 DRY-RUN: Live Smoke Test übersprungen"
else
  log "6/7 Post-Deploy Smoke Test (Live)..."
  ERRORS=0
  for path in "/" "/login" "/premium" "/datenschutz"; do
    STATUS=$(ssh -p $SSH_PORT -i $SSH_KEY "$SSH_USER@$LIVE_HOST" \
      "curl -s -o /dev/null -w '%{http_code}' http://localhost:$LIVE_PORT$path" 2>/dev/null)
    if [ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 500 ]; then
      log "❌ $path → HTTP $STATUS"
      ERRORS=$((ERRORS + 1))
    else
      log "✅ $path → HTTP $STATUS"
    fi
  done
  
  # Supabase-Verbindung testen
  AUTH_STATUS=$(ssh -p $SSH_PORT -i $SSH_KEY "$SSH_USER@$LIVE_HOST" \
    "curl -s -X POST http://localhost:$LIVE_PORT/api/auth/login \
      -H 'Content-Type: application/json' \
      -d '{\"email\":\"test@test.com\",\"password\":\"test\"}' \
      | grep -c 'Invalid login credentials'" 2>/dev/null)
  
  if [ "$AUTH_STATUS" -eq 1 ]; then
    log "✅ Supabase Auth erreichbar"
  else
    log "❌ Supabase Auth NICHT erreichbar"
    ERRORS=$((ERRORS + 1))
  fi
  
  if [ "$ERRORS" -gt 0 ]; then
    fail "Post-Deploy Smoke Test fehlgeschlagen ($ERRORS Fehler). ROLLBACK empfohlen!"
  fi
  log "✅ Post-Deploy Smoke Test bestanden"
fi

# ── Schritt 7: Git Tag ───────────────────────────────────
log "7/7 Git Tag..."
cd "$LOCAL_DIR/.."
TAG="v$(date +%Y%m%d-%H%M)"
git tag -f "$TAG"
log "✅ Tag: $TAG"

# ── Zusammenfassung ───────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  ✅ DEPLOYMENT ERFOLGREICH"
log "  Live: https://carp24.org"
log "  Tag:  $TAG"
log "═══════════════════════════════════════════"
