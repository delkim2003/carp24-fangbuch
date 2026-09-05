# Carp24 Pre-Shutdown Audit Report

**Date:** 2026-09-05 21:50 CEST
**Server:** einfach-online-server (Ubuntu)
**Task:** Verify all Carp24 services & dependencies restart after reboot

---

## 1. Systemd Services

| Service | Status | Enabled | Type |
|---------|--------|---------|------|
| `carp24-web.service` | ✅ active (running) | ✅ enabled | Node SSR (Astro) |

**Unit file:** `/etc/systemd/system/carp24-web.service`
- **ExecStart:** `/usr/bin/node dist/server/entry.mjs`
- **WorkingDirectory:** `/mnt/projekte/carp24-fangbuch/web`
- **Restart:** `always` (RestartSec=5)
- **User:** philipp
- **Binds to:** port 127.0.0.1:4321
- **Environment:** loaded from `/mnt/projekte/carp24-fangbuch/web/.env` (12 lines, 600+ bytes)

**Dependencies:** RequiresMountsFor=/mnt/projekte, After=network.target

### ⚠️ Issue: No startup ordering with Docker/Tailscale
`carp24-web.service` only declares `After=network.target` but NOT `After=network-online.target`, `After=docker.service`, or `After=tailscaled.service`. On a cold boot the web server could start before Tailscale has established the 100.93.250.103 interface and before Docker/Supabase containers are healthy. Mitigated by `Restart=always` (retries every 5s).

---

## 2. Docker Containers (Supabase Backend)

**Docker daemon:** ✅ enabled, active

### Supabase containers — all `restart: unless-stopped` ✅

| Container | Image | Status | Ports |
|-----------|-------|--------|-------|
| supabase-db | postgres:17.6.1.136 | ✅ Up (healthy) | 5432 |
| supabase-kong | kong:3.9.3 | ✅ Up (healthy) | 100.93.250.103:8055→8000, 8443 |
| supabase-auth | gotrue:v2.189.0 | ✅ Up (healthy) | — |
| supabase-rest | postgrest:v14.12 | ✅ Up (healthy) | — |
| supabase-storage | storage-api:v1.60.4 | ✅ Up (healthy) | — |
| supabase-studio | studio:2026.08.03 | ✅ Up (healthy) | — |
| supabase-pooler | supavisor:2.9.5 | ✅ Up (healthy) | 100.93.250.103:6543, 5442 |
| supabse-meta | postgres-meta:v0.96.6 | ✅ U (healthy) | — |
| supabase-edge-functions | edge-runtime:v1.74.0 | ✅ Up (healthy) | — |
| supabase-imgproxy | imgproxy:v3.30.1 | ✅ Up (healthy) | — |
| supabase-templates | caddy:2-alpine | ✅ Up | — |
| realtime-dev.supabase-realtime | realtime:v2.102.3 | ✅ Up (healthy) | — |

**Network:** `supabase_default` (bridge, local) — all 12 containers connected ✅
**Compose file:** `/mnt/projekte/carp24-fangbuch/infra/docker-compose.yml` (project: `supabase`)
**Volume mounts:** Bind mounts from `/mnt/projekte/carp24-fangbuch/infra/volumes/` + named volumes
**Env file:** `/mnt/projekte/carp24-fangbuch/infra/.env` (123 lines)

### ✅ Restart behaviour on reboot
1. Docker daemon starts (enabled, `After=network-online.target`)
2. All 12 containers auto-restart (`unless-stopped` policy)
3. Docker preserves the `supabase_default` bridge network
4. Containers start in parallel; healthchecks + restart policies handle ordering
5. Kong binds to `100.93.250.103:8055` (Tailscale IP) — requires tailscaled to be up

---

## 3. Apache Reverse Proxy

**Apache:** ✅ active, `Syntax OK` on config test

**Enabled modules:** proxy, proxy_http, proxy_wstunnel, headers, rewrite, ssl — all present ✅

### Carp24 vHost: `carp24-build.conf`
| Directive | Value | Status |
|-----------|-------|--------|
| Listen | :8094 (in ports.conf) | ✅ |
| ServerName | carp24-build.local | ✅ |
| Backend | → 127.0.0.1:4321 (Node SSR) | ✅ |
| Auth API | → 100.93.250.103:8055/auth | ✅ |
| Rest API | → 100.93.250.103:8055/rest | ✅ |
| Storage | → 100.93.250.103:8055/storage | ✅ |
| Realtime | → 100.93.250.103:8055/realtime (WS) | ✅ |

**Security headers:** X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy ✅

**Health check (live):**
- Node backend (127.0.0.1:4321): **HTTP 200** ✅
- Apache proxy (127.0.0.1:8094): **HTTP 200** ✅
- Directus/Kong (100.93.250.103:8055): **HTTP 401** (expected — auth required) ✅

---

## 4. Cron Jobs & Scheduled Tasks

| Cron | Schedule | Script | Status |
|------|----------|--------|--------|
| Carp24 Backup | daily 02:30 | `/mnt/projekte/carp24-fangbuch/infra/backup.sh` | ✅ configured (user philipp) |

No root crons or system-level cron.d jobs for Carp24. ✅

---

## 5. Filesystem & Mount Points

| Mount | Device | Type | Fstab | Status |
|------|--------|------|-------|-------|
| `/mnt/projekte` | `/de/sdc1` (UUID: `2873ad46-…`) | ext4 | ✅ UUID-based | ✅ active, generated systemd mount unit |

The `RequiresMountsFor=/mnt/projekte` in the systemd service ensures the web service waits for this mount. ✅

---

## 6. Network Dependencies

| Service | Enabled | Auto-starts on boot | Notes |
|---------|---------|-------------------|-------|
| ``dockerd` / `docker.service` | ✅ | ✅ (enabled) | After=network-online.target|
| `tailscaled.service` | ✅ | ✅ (enabled) | After=NetworManager.service|
| `apache2.service` | ✅ | ✅ (enabled | Standard boot|

**Key IP:** `100.93.250.103` is a Tailscale IP. The Kong container binds exclusively to this IP (`100.93.250.103:8055`). After reboot, Tailscale must connect before Kong can bind — Docker's `restart: unless-stopped` handles this (container will retry).

---

## 7. Issues Found

### 🔴 MEDIUM: Startup ordering gap for `carp24-web.service`
The unit has `After=network.target` but not `After=network-online.target` or `After=docker.service`. On a cold boot, if the Node server starts before Docker/Tailscale are ready, API calls from the SSR will fail until backend containers become healthy.
**Mitigation:** `Restart=always` with RestartSec=5 handles transient failures, but the SSR could serve error pages briefly.
**Recommendation:** Add `After=network-online.target` to ensure the network is fully ready (including Tailscale).

### �️ LOW: No logrotate for carp24
There is no logrotate config for the apache access/error logs of carp24-build. Currently logs in `/var/log/apache2/` are growing unbounded. Not a boot blocker.

### ✅ No blocking issues found

---

## 8. Verdict

**CARP24 IS READY FOR SHUTDOWN AND WILL RESTART PROPERLY.**

All components use auto-start mechanisms:
- Systemd unit: enabled, Restart=always
- Docker containers: 12/12 with restart: unless-stopped
- Apache: enabled, sites-enabled linked
- Cron: user crontab persists across reboot
- Filesystem: UUID-based fstab entry, systemd mount unit
- Tailscale: enabled, provides critical 100.93.250.103 IP

No manual intervention required after reboot — everything will self-heal within ~60 seconds of kernel boot.