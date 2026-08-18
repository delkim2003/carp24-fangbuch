# 🐟 Carp24 — Digitales Fangbuch

> **Domain:** carp24.org · **Stack:** Supabase self-hosted + Astro PWA + Mistral (EU)
> **Status:** Phase 0 (Task 0.1 — Repo-Setup) · **Hetzner CX22: erst Phase 4** (Dev = Hauptserver)

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
├── supabase/          # Schema, Migrationen, Edge Functions, config.toml
├── web/               # Astro-PWA (Mobile-First)
├── infra/             # docker-compose (Supabase pinned), nginx, backup.sh, monitoring
├── tests/             # pgTAP, Playwright-E2E, k6
├── docs/              # secrets.md (Referenz), runbooks, ADR
├── .env.example       # Secrets PLATZHALTER (nie echte Werte!)
└── .gitignore
```

## Branching

- `main` — stabil, nur Releases
- `sprint-N` — aktiver Sprint (BAUPLAN: EIN Task nach dem anderen)

## Betriebsregeln (BAUPLAN v2)

1. Git-Commit VOR jedem Fix · Ein Fix = ein Commit · QA nach jedem Fix
2. OpenCode: KEINE Hermes-Skills, KEIN /tmp, nur OpenRouter-Auth
3. **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
4. Produkt-KI = Mistral direkt (nicht OpenRouter!)
5. Gate nach jeder Phase: Go/No-Go mit DoD
