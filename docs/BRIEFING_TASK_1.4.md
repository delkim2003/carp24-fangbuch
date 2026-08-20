# Build-Briefing: Task 1.4 — Auth E-Mail + TOTP-API (carp24 Phase 1A)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/infra/docker-compose.yml, /mnt/projekte/carp24-fangbuch/infra/.env.example, /mnt/projekte/carp24-fangbuch/.env.example
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm, docker restart, Server-Starts, curl auf externe Systeme
- KEINE Analyse-Ausflüge. Mache genau die 2 Änderungen unten.
- KEINE Secrets ausgeben oder committen.

## Kontext
- Supabase-Stack läuft auf dem Server (11/11 healthy), GoTrue v2.189.0 im Docker-Compose unter `infra/docker-compose.yml`.
- E-Mail-Auth ist bereits konfiguriert: `GOTRUE_EXTERNAL_EMAIL_ENABLED`, `GOTRUE_MAILER_AUTOCONFIRM`, SMTP-Settings, `GOTRUE_RATE_LIMIT_EMAIL_SENT`, `GOTRUE_URI_ALLOW_LIST` — ALLE existieren schon. NICHT anfassen.
- **MFA/TOTP ist auskommentiert** (im docker-compose, Sektion „multi-factor authentication (MFA)" ~Zeile 241-244). Das muss aktiviert werden, damit die TOTP-API (enroll_factor/challenge_factor/verify_factor) nutzbar ist.

## 🎯 AUFGABE (nur 2 Änderungen)

### 1. Docker-Compose: MFA/TOTP aktivieren
In `infra/docker-compose.yml` die MFA-Sektion auskommentieren und auf Env-Variablen umbiegen:
- `GOTRUE_MFA_TOTP_ENROLL_ENABLED: ${MFA_TOTP_ENROLL_ENABLED:-true}`
- `GOTRUE_MFA_TOTP_VERIFY_ENABLED: ${MFA_TOTP_VERIFY_ENABLED:-true}`
- `GOTRUE_MFA_PHONE_ENROLL_ENABLED: ${MFA_PHONE_ENROLL_ENABLED:-false}`

WICHTIG: Die Datei wird KOMPLETT neu geschrieben (keine Diffs, keine Snippets) — alle anderen Sektionen (Kong, DB, Realtime, Storage, imgproxy, Edge-Functions) bleiben EXAKT wie sie sind. NUR die MFA-Kommentarzeilen werden durch aktive Zeilen ersetzt.

### 2. .env.example: MFA-Keys ergänzen
In `/mnt/projekte/carp24-fangbuch/.env.example` unter der Auth-Sektion ergänzen:
```
# MFA/TOTP (Task 1.4)
MFA_TOTP_ENROLL_ENABLED=true
MFA_TOTP_VERIFY_ENABLED=true
MFA_PHONE_ENROLL_ENABLED=false
```

NICHT `infra/.env` ändern (dort setzt Hermes die Werte selbst, keine Secrets von dir).

## ✅ VERIFIKATION (nur statisch, KEINE Server-Starts)
- `grep -n "GOTRUE_MFA_TOTP_ENROLL_ENABLED" infra/docker-compose.yml` → Zeile vorhanden, nicht auskommentiert
- `grep -n "MFA_TOTP_ENROLL_ENABLED" .env.example` → vorhanden
- docker-compose.yml YAML-syntaktisch valide: `python3 -c "import yaml,sys; yaml.safe_load(open('infra/docker-compose.yml')); print('YAML OK')"`

## 📝 ABGABE
- Sage am Ende: „FERTIG" + die grep-Beweise (Zeilenausgaben).
- KEIN git-Commit — das macht Hermes.
