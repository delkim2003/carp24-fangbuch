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
