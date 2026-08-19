# 🔧 P0.2-FIX-BATCH 19.08.2026 — aus 3-Experten-Audit (deleg_b935d62e)

**Verdicts Runde 1:** DevOps PAUSE (85%) · Security PAUSE (92%) · Architekt PROCEED (88%)
**Nach Fix-Batch:** Stack 11/11 healthy, alle kritischen Funde behoben. → Runde 2 (Re-Audit) gestartet.

## Fixes (ein Fix = ein Commit, main)

| Fix | Fund | Commit | Verifikation (live) |
|-----|------|--------|---------------------|
| E1 | IMGPROXY_STRIP_METADATA + ENABLE_WEBP_DETECTION fehlten | `b00bdba` | `docker exec supabase-imgproxy env` → beide `true` |
| E2 | infra/.env.old mit echten Secrets in Git | `5bfff7c` | `git rev-list --objects --all` → kein Blob; History-Rewrite (lokal, kein Remote) |
| E3 | 0 Memory-Limits auf 11/11 Containern | `3c9d2ea` | `docker inspect supabase-db` → 4294967296 (4g) |
| E4 | PGTZ=Europe/Vienna fehlte | `b578e0a` | Rest-Container `PGTZ=Europe/Vienna`; `pg_roles.authenticator.rolconfig` → `TimeZone=Europe/Vienna` |
| E5 | GOTRUE_RATE_LIMIT_EMAIL_SENT fehlte | `b578e0a` | Container-Env → `GOTRUE_RATE_LIMIT_EMAIL_SENT=5` |
| E6 | .env Permissions 664 | `5bfff7c` | `stat` → 600 |
| E7 | PG 5442/Kong auf 0.0.0.0 | `bc33d8c` | `ss -tln` → nur 100.93.250.103; localhost 8055 → nicht erreichbar, Tailscale → 401 |
| E8 | FUNCTIONS_VERIFY_JWT=false | `bc33d8c` | Container-Env → `VERIFY_JWT=true` (nach `unset` der Shell-Var!) |
| E9 | supabase_realtime-Publication existiert bereits | (Briefing) | **0001_init.sql muss `ALTER PUBLICATION … ADD TABLE` / `IF NOT EXISTS` nutzen, kein bare `CREATE`** |
| E10 | Monitoring-Ordner leer | `f487d58` | `carp24-watchdog.sh` läuft, Cron `1e71c5089bdc` alle 30 Min (still bei OK) |
| E11 | log_min_messages=fatal | `bc33d8c` | Compose → warning (RLS/DDL-Fehler sichtbar) |
| F5/M5 | .env.example unvollständig (19 → 77 Vars) | `df76223` | Generiert aus .env, alle Werte CHANGE_ME-Platzhalter |

## Als NICHT-Bug eingestuft (Experten-False Positives, verifiziert)
- „Einzel-Image-Tags = R6-Bruch": Images sind exakt die des Releases v1.26.08 — korrekt gepinnt
- „Supavisor statt PgBouncer = R6-Bruch": aktuelle Supabase-Releases liefern supavisor als Pooler mit — bewusste Release-Entscheidung

## Pitfall (neu, wiederverwendbar)
- **Shell-Env überschreibt .env in docker compose**: `FUNCTIONS_VERIFY_JWT=false` stand als Shell-Variable in der Session → compose löst das (Priorität: Shell > .env-Datei), der Wert im .env wurde ignoriert. Fix: `unset FUNCTIONS_VERIFY_JWT` + `--force-recreate`. Bei jedem „Compose zeigt anderen Wert als .env": `env | grep <VAR>` prüfen.

## Offen (bewusst)
- Swap voll (8GB, mysqld/insync/GNOME) → **Reboot So 23.08.** löst; MemAvailable 16.7GB = kein akutes Risiko
- .env-Permissions in allen Host-Profilen prüfen (Phase 1)
- SMTP konfigurieren (Task 1.9, bekannte Phase-1-Abhängigkeit)
- Task 0.6 voll (offsite-Backup etc.) folgt im BAUPLAN

## Nächster Schritt
- Re-Audit Runde 2: Fix-Verifikations-Experte + DevOps + Security (neue Perspektiven, „NUR NEUE Funde")

---

# 🔧 RUNDE 2 — 19.08.2026 ~09:05 (deleg_40c0f02a)

**Verdicts Runde 2:** Fix-Verifikation **PROCEED 92%** (alle 11 R1-Fixes OK, 0 Regressionen) · DevOps **PROCEED 88%** (2 HOCH latent) · Security **PAUSE 85%** (2 aktive Fehlkonfigurationen)

## Runde-2-Fixes (Commit `e658702` + folgende)

| # | Fund | Fix | Verifikation |
|---|------|-----|--------------|
| R2-F1 | HOCH: db/data + storage nicht in .gitignore (Datenleck-Vektor) | `infra/volumes/**/data/` + `infra/volumes/storage/` in .gitignore | `git check-ignore` → beide ignoriert ✅ |
| R2-F2 | HOCH: keine Log-Rotation (Docker-Logs unbegrenzt) | logging json-file max-size 20m max-file 3 auf alle 11 Services | `docker inspect supabase-db` → `{json-file map[max-file:3 max-size:20m]}` ✅ |
| R2-F3 | MITTEL: infra/backup.sh fehlt (Task 0.5) | backup.sh-Stub (pg_dump + Storage-Tar + Rotation 7) | Testlauf → postgres_20260819_0903.dump 311KB ✅ |
| R2-F4 | MITTEL: doppelte ENABLE_PHONE_* Keys in .env/.env.example | dedup (letzter Wert gewann still) | grep → je 1× ✅ |
| R2-F5 | MITTEL: Edge-Healthcheck nur TCP | bewusst belassen (Dev, kein /health-Endpoint verfügbar) | dokumentiert |
| R2-F6 | NIEDRIG: Compose-Header referenziert reset.sh/dev/ (existieren nicht) | bewusst belassen (Doc-Drift) | dokumentiert |
| R2-F7 | NIEDRIG: Logflare/Vector deaktiviert, undokumentiert | bewusst (Dev, Watchdog-Cron deckt ab) | dokumentiert |
| SEC-F1 | MITTEL: offene Registrierung (DISABLE_SIGNUP=false, SMTP leer) | `DISABLE_SIGNUP=true` in .env + auth force-recreate | Container-Env `GOTRUE_DISABLE_SIGNUP=true` ✅ |
| SEC-F2 | MITTEL: Studio-Username "admin" | `DASHBOARD_USERNAME=carp24ops` + kong force-recreate | falsche Creds → 401 ✅ |
| SEC-F3 | MITTEL latent: Docker-Socket in docker-compose.logs.yml (Vector) | dokumentiert — logs.yml NICHT starten ohne Need | dokumentiert |
| SEC-F5 | HINWEIS: JWT_KEYS tot (asymmetrische Migration halbfertig) | dokumentiert — läuft sauber symmetrisch HS256 | dokumentiert |
| SEC-F6 | HINWEIS: 5-Jahres-API-Keys, keine Rotation | dokumentiert — Rotation vor Phase 4 (CX22) | dokumentiert |
| SEC-F7 | HINWEIS: Host-Container diun mit RW-Docker-Socket | an Host-Admin gemeldet (außerhalb carp24) | dokumentiert |

## Zusätzliche Fixes
- Watchdog-Cron-Pfad: Skript nach `~/.hermes/profiles/agentur-berater/scripts/` + **Symlink** auf Repo-Version (Repo-Edits propagieren) — erster Tick 09:00 schlug fehl (Pfad), manueller Run läuft
- Watchdog-Swap-Warnung: nur noch bei RAM>85% UND Swap voll (kein 30-Min-Spam bis Reboot So 23.08.)

## Pitfall Runde 2 (wiederverwendbar)
- **docker compose: Shell-Env überschreibt .env erneut** (DISABLE_SIGNUP): `env | grep DISABLE_SIGNUP` → Shell hatte `false` → compose löste `false` auf. Vor jedem .env-Wert-Wechsel: `unset <VAR>` + force-recreate. (2. Vorkommen — Muster bestätigt.)

## Offen (bewusst, dokumentiert)
- Swap voll → Reboot So 23.08.
- SMTP → Task 1.9
- backup.sh final (offsite, verschlüsselt) → Task 0.5
- Key-Rotation → vor Phase 4
- logs.yml (Vector/Logflare) → nur bei Bedarf

## Nächster Schritt
- Runde 3 (Re-Audit auf R2-Fixes) — bei grün: P0.2 abgenommen → P0.3-Plan
