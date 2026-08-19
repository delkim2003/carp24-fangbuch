# 🐟 Carp24 — Digitales Fangbuch

> **Domain:** carp24.org · **Stack:** Supabase self-hosted + Astro PWA + Mistral (EU)
> **Status:** Phase 0 (Task 0.2 abgenommen nach 3-Experten-Audit-Loop 19.08.) · **Hetzner CX22: erst Phase 4** (Dev = Hauptserver)

## Projekt

Persönliches digitales Fangbuch für Karpfenangler mit:
- Fang erfassen <20s (Geo → Wetter automatisch, HEIC→WebP, offline-fähig)
- Statistiken + Wetter-Korrelation (ab 30 Tagen Datenbasis)
- KI-Chatbot (Mistral, SQL-Zahlenpfad, nur aggregierte Zahlen)
- Optional teilen (posts-Snapshot, nie Koordinaten) + Community Board + Marktplatz
- Privacy-first, self-hosted EU, keine Werbung

**Vollständige Spezifikation:** Vault `03_PROJEKTE/carp24-fangbuch/` (MASTER_SPRINT.md Plan v7 + BAUPLAN.md v2)

## Struktur

```
├── supabase/          # Schema + Migrationen (MIGRATIONS_RUNBOOK.md!), Edge Functions
├── web/               # Astro-PWA (Mobile-First)
├── infra/             # docker-compose (Supabase v1.26.08 pinned), .env, backup.sh, monitoring/
├── tests/             # pgTAP (tests/pgtap/), Playwright-E2E, k6
├── docs/              # FIX_BATCH, MIGRATIONS_RUNBOOK, ADR
├── .env.example       # Secrets PLATZHALTER (nie echte Werte!) — sync mit infra/.env.example
└── .gitignore         # .env, volumes/**/data, storage, backups
```

**⚠️ Edge Functions leben real in `infra/volumes/functions/`** (edge-runtime mountet `./volumes/functions`), NICHT `supabase/functions/` — das ist nur Doku-Pfad.

## Bring-up (Phase 0, Hauptserver)

```bash
cd infra/
# 1. Secrets generieren (KEINE manuellen Werte!)
bash utils/generate-keys.sh --update-env   # erzeugt .env + .env.old (NICHT committen!)
# 2. .env prüfen: Ports 8055/8443/5442/6543 auf 100.93.250.103 (Tailscale), DISABLE_SIGNUP=true
chmod 600 .env
# 3. Start
docker compose up -d --wait   # 11 Container healthy
# 4. Verifikation
docker exec supabase-db pg_isready -U postgres          # accepting
curl -s -o /dev/null -w '%{http_code}' http://100.93.250.103:8055/auth/v1/health  # 401 = Auth ok
```

**WICHTIG:** `.env`-Werte werden von Shell-Env-Variablen überschrieben! Vor Änderungen: `unset <VAR>` + `--force-recreate`.

## Migrationen (Task 0.3+)

→ `docs/MIGRATIONS_RUNBOOK.md` — 0001_init.sql als `supabase_admin` anwenden (ON_ERROR_STOP=1), pgTAP als `supabase_admin` installieren (pgtap nicht trusted), `supabase_realtime` existiert bereits (ALTER PUBLICATION).

## Branching

- `main` — stabil, nur Releases
- `sprint-N` — aktiver Sprint (BAUPLAN: EIN Task nach dem anderen)

## Betriebsregeln (BAUPLAN v2)

1. Git-Commit VOR jedem Fix · Ein Fix = ein Commit · QA nach jedem Fix
2. OpenCode: KEINE Hermes-Skills, KEIN /tmp, nur OpenRouter-Auth
3. **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
4. Produkt-KI = Mistral direkt (nicht OpenRouter!)
5. Gate nach jeder Phase: Go/No-Go mit DoD
