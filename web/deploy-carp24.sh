#!/bin/bash
# ============================================================
# Carp24 DEV→LIVE Deploy Script
# Stand: 20.09.2026
# Usage: ./deploy-carp24.sh [--skip-db] [--skip-build] [--dry-run]
# ============================================================
set -euo pipefail

# ── Config ──────────────────────────────────────────────────
LOCAL_SRC="/mnt/projekte/carp24-fangbuch/web"
HETZNER_HOST="philipp@46.225.98.79"
HETZNER_SSH="-p 2222"
HETZNER_SRC="/opt/carp24/src"
HETZNER_DIST="/opt/carp24/dist"        # ⚠️ NICHT /opt/carp24/src/dist!
HETZNER_DOCKER_DIR="/opt/carp24"
CONTAINER_NAME="carp24-app"
IMAGE_NAME="carp24-app:latest"
DOCKER_NETWORK="supabase_default"
DOMAIN="https://carp24.org"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKIP_DB=false
SKIP_BUILD=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --skip-db) SKIP_DB=true ;;
    --skip-build) SKIP_BUILD=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

log() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

run() {
  if $DRY_RUN; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

ssh_cmd() {
  ssh $HETZNER_SSH $HETZNER_HOST "$@"
}

# ============================================================
# PHASE 1: Pre-Flight Checks
# ============================================================
log "═══ PHASE 1: Pre-Flight Checks ═══"

# 1.1 Check local source exists
[ -d "$LOCAL_SRC/src" ] || err "Local source not found: $LOCAL_SRC/src"

# 1.2 Check SSH connectivity
ssh_cmd "echo 'SSH OK'" || err "Cannot connect to Hetzner"

# 1.3 Check Docker is running
ssh_cmd "docker ps --format '{{.Names}}' | grep -q '$CONTAINER_NAME'" || err "Container $CONTAINER_NAME not running on Hetzner"

# 1.4 Check for uncommitted local changes
cd "$LOCAL_SRC"
if [ -n "$(git status --porcelain)" ]; then
  warn "Uncommitted changes in local repo:"
  git status --short
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

log "Pre-flight OK ✓"

# ============================================================
# PHASE 2: Build Local
# ============================================================
if ! $SKIP_BUILD; then
  log "═══ PHASE 2: Build Local ═══"
  cd "$LOCAL_SRC"
  run npx astro build
  log "Build complete ✓"
else
  log "═══ PHASE 2: Build SKIPPED ═══"
fi

# ============================================================
# PHASE 3: Sync Source to Hetzner
# ============================================================
log "═══ PHASE 3: Sync Source ═══"

# 3.1 Sync source files (for reference, not used by Docker directly)
log "Syncing source → $HETZNER_HOST:$HETZNER_SRC/"
run rsync -avz --delete \
  -e "ssh $HETZNER_SSH" \
  --exclude='node_modules' \
  --exclude='.env' \
  --exclude='dist/' \
  "$LOCAL_SRC/src/" "$HETZNER_HOST:$HETZNER_SRC/src/"

# 3.2 Sync package files
run rsync -avz \
  -e "ssh $HETZNER_SSH" \
  "$LOCAL_SRC/package.json" \
  "$LOCAL_SRC/package-lock.json" \
  "$HETZNER_HOST:$HETZNER_SRC/"

log "Source synced ✓"

# ============================================================
# PHASE 4: Sync dist/ to CORRECT path
# ============================================================
log "═══ PHASE 4: Sync dist/ ═══"

# ⚠️ KRITISCH: Dockerfile ist in /opt/carp24/ und kopiert dist/ von dort!
# dist/ MUSS nach /opt/carp24/dist/ NICHT /opt/carp24/src/dist/!

log "Syncing dist → $HETZNER_HOST:$HETZNER_DIST/"
log "(⚠️  NOT $HETZNER_SRC/dist — Dockerfile expects $HETZNER_DIST)"

# Use sudo cp on Hetzner because rsync might have permission issues
run rsync -avz --delete \
  -e "ssh $HETZNER_SSH" \
  "$LOCAL_SRC/dist/" "$HETZNER_HOST:$HETZNER_DIST/" 2>/dev/null || {
    warn "rsync permission denied, using sudo cp fallback"
    # First sync to temp location, then move
    run rsync -avz --delete \
      -e "ssh $HETZNER_SSH" \
      "$LOCAL_SRC/dist/" "$HETZNER_HOST:$HETZNER_SRC/dist/"
    ssh_cmd "sudo rm -rf $HETZNER_DIST && sudo cp -r $HETZNER_SRC/dist $HETZNER_DIST && sudo chown -R philipp:philipp $HETZNER_DIST"
  }

log "dist/ synced ✓"

# ============================================================
# PHASE 5: DB Migrations (if any)
# ============================================================
if ! $SKIP_DB; then
  log "═══ PHASE 5: DB Migrations ═══"
  
  # Check if there are pending migrations
  MIGRATION_DIR="$LOCAL_SRC/supabase/migrations"
  if [ -d "$MIGRATION_DIR" ] && [ "$(ls -A $MIGRATION_DIR 2>/dev/null)" ]; then
    warn "DB migrations found in $MIGRATION_DIR:"
    ls -la "$MIGRATION_DIR"
    echo ""
    read -p "Apply migrations to Hetzner supabase-db? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for f in "$MIGRATION_DIR"/*.sql; do
        log "Applying: $(basename $f)"
        cat "$f" | ssh_cmd "docker exec -i supabase-db psql -U supabase_admin -d postgres"
      done
      log "Migrations applied ✓"
    else
      warn "Migrations SKIPPED — may cause runtime errors!"
    fi
  else
    log "No pending DB migrations ✓"
  fi
else
  log "═══ PHASE 5: DB Migrations SKIPPED ═══"
fi

# ============================================================
# PHASE 6: Docker Build (--no-cache)
# ============================================================
log "═══ PHASE 6: Docker Build ═══"

log "Building $IMAGE_NAME (--no-cache)..."
run ssh_cmd "cd $HETZNER_DOCKER_DIR && docker build --no-cache -t $IMAGE_NAME ."
log "Docker build complete ✓"

# ============================================================
# PHASE 7: Docker Restart
# ============================================================
log "═══ PHASE 7: Docker Restart ═══"

run ssh_cmd "docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME && docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  --env-file $HETZNER_DOCKER_DIR/.env \
  --network $DOCKER_NETWORK \
  -p 4321:4321 \
  $IMAGE_NAME"

sleep 2
log "Container restarted ✓"

# ============================================================
# PHASE 8: Verify Container
# ============================================================
log "═══ PHASE 8: Verify Container ═══"

# 8.1 Check container is running
ssh_cmd "docker ps --format '{{.Names}} {{.Status}}' | grep $CONTAINER_NAME" || err "Container not running!"

# 8.2 Check for key code in container
log "Verifying container code..."
CREATE_IMAGE_BITMAP=$(ssh_cmd "docker exec $CONTAINER_NAME grep -rl 'createImageBitmap' /app/dist/ 2>/dev/null | wc -l")
IS_BINARY=$(ssh_cmd "docker exec $CONTAINER_NAME grep -rl 'isBinary' /app/dist/server/ 2>/dev/null | wc -l")

if [ "$CREATE_IMAGE_BITMAP" -eq 0 ]; then
  err "createImageBitmap NOT in container — old dist/! Rebuild failed."
fi
if [ "$IS_BINARY" -eq 0 ]; then
  err "isBinary (proxy fix) NOT in container — old dist/! Rebuild failed."
fi

log "Container code verified ✓ (createImageBitmap: $CREATE_IMAGE_BITMAP, isBinary: $IS_BINARY)"

# ============================================================
# PHASE 9: Smoke Test
# ============================================================
log "═══ PHASE 9: Smoke Test ═══"

PAGES=("/" "/login" "/faenge" "/fang-erfassen" "/premium" "/agb")
ALL_OK=true

for page in "${PAGES[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN$page" 2>/dev/null)
  if [ "$STATUS" -eq 200 ]; then
    log "  $page → $STATUS ✓"
  else
    err "  $page → $STATUS ✗"
    ALL_OK=false
  fi
done

# 9.2 Check Docker logs for errors
ERRORS=$(ssh_cmd "docker logs $CONTAINER_NAME 2>&1 | grep -i 'error\|ECONNREFUSED\|fetch failed' | tail -5")
if [ -n "$ERRORS" ]; then
  warn "Container errors found:"
  echo "$ERRORS"
fi

if $ALL_OK; then
  log "═══ DEPLOY COMPLETE ✓ ═══"
else
  err "═══ DEPLOY HAD ERRORS ═══"
fi

# ============================================================
# Summary
# ============================================================
echo ""
log "Container: $CONTAINER_NAME @ $DOMAIN"
log "Docker Network: $DOCKER_NETWORK"
log "dist/ Path: $HETZNER_DIST"
log "Source: $HETZNER_SRC"
echo ""
log "Commands:"
echo "  Logs:    ssh -p 2222 $HETZNER_HOST 'docker logs -f $CONTAINER_NAME'"
echo "  Shell:   ssh -p 2222 $HETZNER_HOST 'docker exec -it $CONTAINER_NAME sh'"
echo "  DB:      ssh -p 2222 $HETZNER_HOST 'docker exec supabase-db psql -U supabase_admin -d postgres'"
echo "  Restart: ssh -p 2222 $HETZNER_HOST 'docker restart $CONTAINER_NAME'"
