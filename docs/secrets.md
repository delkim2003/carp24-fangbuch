# 🔐 Carp24 — Secrets-Management (P0.4)

> **Stand:** 19.08.2026 · **DoD:** kein Secret in git (grep), .env.example vollständig, Rotation-Plan, pre-commit-Scan aktiv

## 1. Secret-Inventar

Alle Secrets leben in `infra/.env` (600, nie in Git). `.env.example` (112 Zeilen, getrackt) enthält KEINE Werte.

| Secret | Zweck | Wo | Rotations-Intervall |
|---|---|---|---|
| `POSTGRES_PASSWORD` | Supabase-DB (supabase-db Container) | infra/.env | Jährlich / nach Kompromittierung |
| `JWT_SECRET` | GoTrue-JWT-Signierung | infra/.env | **Sofort nach Key-Leak** (invalidiert alle Sessions) |
| `ANON_KEY` / `SERVICE_ROLE_KEY` | Supabase-API (JWT mit anon/service_role claim) | infra/.env | Jährlich / nach Leak |
| `ANON_KEY_ASYMMETRIC` / `SERVICE_ROLE_KEY_ASYMMETRIC` | Asymmetrische API-Keys (optional) | infra/.env | Jährlich |
| `GOTRUE_JWT_SECRET` | GoTrue intern | infra/.env | Wie JWT_SECRET |
| `PG_META_CRYPTO_KEY` | Studio Meta-API Verschlüsselung | infra/.env | Jährlich |
| `DASHBOARD_PASSWORD` | Studio-Admin-Login (carp24ops) | infra/.env | Monatlich / nach Verdacht |
| `STRIPE_SECRET_KEY` (Phase 2) | Zahlungen | infra/.env | Jährlich + Webhook-Rotation |
| `MISTRAL_API_KEY` (Phase 2) | KI-Chatbot | infra/.env | Jährlich |
| `MAILERSEND_API_KEY` (Phase 1) | SMTP | infra/.env | Jährlich |
| `OPEN_METEO` (kostenlos) | Wetter | — | Kein Key |

## 2. Zugriffskontrolle

- `.env` → `chmod 600`, Owner `philipp`
- **Kein Secret in Git-History:** `.env.old` wurde am 19.08. endgültig gepurged (filter-branch + gc, kein Remote)
- **Kein Secret in Logs/Backups:** Backup-Skripte schließen `.env` mit ein (verschlüsselt, offsite) — Restore-Spielregeln im Runbook
- **Kein Secret in Docker-Envs:** docker-compose nutzt nur `${VAR}`-Referenzen; Werte kommen aus infra/.env (compose lädt automatisch)

## 3. Rotation-Plan

### Sofort (Key-Leak-Verdacht)
```bash
cd /mnt/projekte/carp24-fangbuch/infra
# Neue Keys generieren
bash utils/generate-keys.sh   # gibt neue JWT_SECRET/ANON/SERVICE_ROLE/POSTGRES_PASSWORD aus
# Werte in .env ersetzen (nur die betroffenen)
# Stack neu starten (auth/rest müssen neue Keys laden)
docker compose up -d --force-recreate supabase-auth supabase-rest supabase-kong
# Sessions invalidiert (JWT_SECRET-Wechsel) → alle User neu einloggen
```

### Geplant (jährlich / bei Release-Meilensteinen)
1. `JWT_SECRET` + `GOTRUE_JWT_SECRET` rotieren → Auth-Invalidierung einkalkulieren (Ankündigung)
2. `POSTGRES_PASSWORD` rotieren → alle Container + Pooler-Verbindungen neu
3. `DASHBOARD_PASSWORD` rotieren (Studio)
4. API-Keys (ANON/SERVICE_ROLE) neu generieren → Frontend-Env aktualisieren

### Ablauf je Secret
1. Neuen Wert generieren (openssl rand -base64 48)
2. In infra/.env ersetzen
3. Betroffene Container force-recreate
4. Login/Funktionstest (E2E-Smoke)
5. Alten Wert NIEMALS committen/loggen

## 4. pre-commit Secret-Scan

Installiert am 19.08. (`infra/utils/pre-commit-secret-scan.sh` → `.git/hooks/pre-commit`):
- Blockt Commits mit echten Secret-Patterns (JWT_SECRET=, SERVICE_ROLE_KEY=, POSTGRES_PASSWORD= mit Werten)
- Erlaubt `.env.example` (keine Werte) und `${VAR}`-Referenzen
- Bei False-Positive: Muster in Whitelist ergänzen (Utils-Dateien)

**Verifikation:**
```bash
# Grep-Check (DoD)
git ls-files | xargs grep -lE "JWT_SECRET=[A-Za-z0-9]|SERVICE_ROLE_KEY=[A-Za-z0-9]" | grep -v ".env.example" | wc -l
# → muss 0 sein (echte Werte, nicht ${VAR})
```

## 5. Erneuerung (ToDos)

- [ ] Phase 1: SMTP-Key (MailerSend) anlegen → in .env
- [ ] Phase 2: Stripe + Mistral Keys → in .env
- [ ] Erste geplante Rotation: spätestens 01.01.2027 (JWT/PG/Dashboard)
- [ ] Secret-Scan-Cron (wöchentlich, `grep`-Beweis) — mit Watchdog kombinieren
