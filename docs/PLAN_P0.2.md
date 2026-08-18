# 🏗️ P0.2 — Supabase-Compose Dev (Hauptserver) — PLAN ZUR ABNAHME

> **Status:** ⏳ Plan — wartet auf Philipp-Abnahme VOR Build
> **Basis:** BAUPLAN v2 Task 0.2 · MASTER_SPRINT Plan v7 (R6-Infra-Spec)

## 1. Ziel

Supabase self-hosted als Dev-Umgebung auf dem Hauptserver starten — mit ALLEN Kern-Komponenten auf EINEM gepinnten Release-Tag (R6: interdependente API-Verträge, kein Einzel-Tag-Pinning).

## 2. Ist-Zustand (gemessen, 18.08. 22:40)

| Ressource | Wert | Bewertung |
|-----------|------|-----------|
| RAM | 30 GB total, 18 GB verfügbar | ✅ ausreichend (R6: PgBouncer 4GB, KEINE 2×4GB-Overprovisionierung) |
| CPU | 6 Kerne | ✅ ok für Dev |
| Disk /mnt/projekte | 7,6 TB frei | ✅ |
| **Port 8000** | 🔴 **BELEGT (Honcho-API)** | Supabase-API will 8000 → **mappen** |
| **Port 8080** | 🔴 **BELEGT (Drupal)** | Supabase-Studio will 8080 → **mappen** |
| **Port 5432** | 🔴 **BELEGT** | Supabase-Postgres will 5432 → **mappen** |
| Port 54321/54322/54323 | frei | Supabase-Standard dev-Ports frei |

**Konsequenz:** Port-Mapping in docker-compose → Kong/API auf **8055**, Studio auf **8090**, Postgres auf **5442**, Rest (3000 Realtime, 54321 etc.) bleibt frei.

## 3. Komponenten + Version

**Release-Tag:** Ein komplettes `supabase/supabase`-Compose auschecken, **EIN Tag z.B. `v2.182.0`** (konkreten Tag beim Download verifizieren: `git tag | tail`). Inhalt:

| Komponente | Rolle | Port (extern) |
|-----------|-------|---------------|
| **Kong 2.8.x** | API-Gateway (/rest, /auth, /storage, /realtime, /functions) | **8055** |
| **Postgres (supabase/postgres Custom-Image)** | pg_net, pgjwt, vault, Rollen authenticator/anon/service_role/supabase_storage_admin | **5442** |
| GoTrue | Auth (E-Mail first) | intern |
| PostgREST | REST-API | intern |
| Realtime | Channels + WAL | 3000 |
| Storage + imgproxy | Dateien, HEIC→WebP, EXIF-Strip | intern |
| Edge (Deno) | Functions | intern |
| Studio | Admin-UI | **8090** |
| analytics/Logflare, Vector, pg-meta | Logging/Vector-Suche/Metadaten | intern |
| **PgBouncer** | Connection-Pooling (Transaction, plan_cache_mode=auto) | intern |

**imgproxy:** Eigenständiger Service mit `IMGPROXY_STRIP_METADATA=true` + `ENABLE_WEBP_DETECTION=true` + vips/libheif (HEIC-Support) — R6-Vorgabe.

## 4. WAL-Guardrails (R6, in DB-Config)

- `max_slot_wal_keep_size` begrenzen (Realtime-Lag-Schutz)
- `CREATE PUBLICATION supabase_realtime` + `REPLICA IDENTITY FULL` — kommt in Task 0.3 (0001_init.sql), NICHT hier

## 5. Schritte (Reihenfolge)

1. Repo: `infra/docker-compose.yml` + `infra/.env` (aus .env.example) anlegen — KEINE echten Secrets committen
2. Supabase-Compose auf gepinntem Tag herunterladen/verifizieren (`git tag` + Digest-Check)
3. Port-Mapping einbauen (8055/8090/5442) + Resource-Limits (PgBouncer 4GB cap)
4. `docker compose up -d` → Healthcheck aller Container (`pg_isready`, Kong /health)
5. Swap prüfen/einrichten (OOM-Schutz)
6. OOM-Test (k6-Smoke klein) + Benchmark-Notiz (CX32-Fallback-Entscheidung VORBEREITET, CX22 erst Phase 4)
7. Commit + Vault-Update

## 6. DoD / Verifikation (aus BAUPLAN)

- [ ] `docker compose up` läuft (alle Container up, 0 restart-loop)
- [ ] `pg_isready` → accepting connections
- [ ] Kong-API auf 8055 → /health 200
- [ ] Studio auf 8090 erreichbar
- [ ] OOM-Test dokumentiert (kein OOM-Kill bei k6-Smoke)
- [ ] Kein Secret in git (`grep -r "CHANGE_ME"` → 0 in committed files)
- [ ] Port-Konflikte 0 (8000/8080/5432 bleiben Honcho/Drupal unberührt!)

## 7. Risiken + Rollback

| Risiko | Mitigation | Rollback |
|--------|-----------|----------|
| Supabase-Tag inkompatibel mit anderem Container | Ein-Tag-Pinning (R6) | `docker compose down` — vollständig entfernbar |
| OOM (12 GB benutzt + Supabase) | Swap + PgBouncer 4GB cap | Container stoppen |
| Port-Chaos | Mapping getestet vor up | down |
| Kein DNS/nginx jetzt | Nur intern (localhost) — kein öffentlicher Zugriff in Phase 0 | — |

## 8. Offene Fragen an Philipp

1. **Release-Tag:** `v2.182.0` als Startpunkt ok? (Sollte beim Download als letzter stabiler Tag verifiziert werden)
2. **Studio-Zugriff:** Nur lokal (localhost:8090) — reicht dir das für Phase 0, oder brauchst du Tailscale-Zugriff von außen?
3. **Supavisor:** BAUPLAN sagt „PgBouncer+Supavisor" — R6 sagt PgBouncer-first (Supavisor erst wenn Chat live). **Empfehlung: nur PgBouncer jetzt** (R6-konform, spart RAM). OK?

## 9. Geschätzter Aufwand

~1,5–3 h (Download + Compose + Healthchecks), danach Task 0.3 (DDL) separat planen.
