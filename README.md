# 🎣 Carp24 — Dein digitales Fangbuch

> Premium Digital Logbook für Karpfenangler. Erfasse, analysiere und teile deine Fänge.

[![Status](https://img.shields.io/badge/status-live_(Wartungsmodus)-yellow)]()
[![Astro](https://img.shields.io/badge/Astro-5.x_(SSR)-FF5D01)]()
[![Supabase](https://img.shields.io/badge/Supabase-Self--Hosted-3FCF8E)]()
[![Tailwind](https://img.shields.io/badge/Tailwind-4.x-06B6D4)]()

**Live:** https://carp24.org · **Vollständige Doku:** [docs/](docs/)

## Features

- **Fangbuch** — Fänge erfassen mit Gewicht, Länge, Fischart, Köder, Methode, Gewässer, GPS, Foto (Upload mit WebP-Konvertierung)
- **Dashboard** — KPIs, Fänge pro Monat, Top-Fänge, Gewichtsverlauf (uPlot)
- **Statistik-Studio** — Filter nach Wetter, Mondphase, Luftdruck, Wassertemperatur, Uhrzeit. *Zahlenregel: absolute Zahlen immer ganzzahlig, nur Gewicht mit Dezimal-Komma.*
- **Jahres-Rückblick** — Saison-Zusammenfassung mit Top-Fängen und Statistiken
- **Trips** — Angelausflüge planen und Fänge zuordnen
- **Badges** — Gamification (10 Achievements: Erster Fang, 100kg, Nachtfischer, ...)
- **Community-Board** — Öffentliche Fänge teilen · **Forum** — Kategorien, Threads, Antworten · **Chat** — Realtime-Community-Chat
- **Marktplatz** — Angel-Ausrüstung kaufen/verkaufen
- **KI-Assistent** — Daten-Chat, „Beste Bedingungen", 3-Tage-Fangprognose mit Wetter + Mondphase ([docs/AI-ASSISTENT.md](docs/AI-ASSISTENT.md))
- **CSV-Import** — Bestände importieren (max 500/Lauf) · **PRO-Datenexport** (CSV + PDF)
- **Premium** — monatlich kündbar (Stripe-Integration für Pro-Features)
- **i18n** — Deutsch/Englisch · **Dark Mode** — System-Override
- **DSGVO** — Klaro Consent, Matomo Self-Hosted, Account-Löschung, CSV-Export

## Tech-Stack

| Layer | Technologie |
|-------|-------------|
| Frontend | Astro 5 (SSR, Node-Adapter) + Tailwind CSS 4 |
| Backend | Supabase (Self-Hosted, Docker) |
| Auth | Supabase Auth (E-Mail + OAuth Google/Facebook) |
| DB | PostgreSQL (Supabase, 28 App-Tabellen — siehe [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md)) |
| Realtime | Supabase Realtime (Chat) |
| Payments | Stripe (Checkout + Webhook) |
| KI | OpenRouter (Mistral-Modelle, Rotation + Retry) + Open-Meteo (Wetter) |
| Analytics | Matomo (Self-Hosted, DSGVO) |
| Consent | Klaro |
| Server | NGINX (TLS, Reverse-Proxy) → Docker-Container (Node.js SSR) |

## Projektstruktur

```
carp24-fangbuch/
├── web/                    # Astro Frontend + SSR
│   ├── src/
│   │   ├── pages/          # Routen + API-Endpoints (api/ai/, api/catches/, ...)
│   │   ├── components/     # Header, Footer, CatchCard, ...
│   │   ├── layouts/        # Layout.astro
│   │   ├── middleware.ts   # Auth, Wartungsmodus, CSRF, Security-Header, Cache
│   │   └── lib/            # supabase-client, i18n, catch-service, ...
│   ├── public/             # Statische Assets (llms.txt, sitemap.xml, Favicons, og-carp24.png)
│   └── .env                # Environment (NICHT committen!)
├── supabase/
│   └── migrations/         # SQL-Migrationen
├── design/
│   └── screens/            # Stitch-Design-Screens (HTML/PNG)
├── docs/                   # Vollständige Doku (ARCHITEKTUR, DEPLOYMENT, AI-ASSISTENT, SEO-GEO, BETRIEB, ...)
└── infra/                  # Docker-Compose, Backups, Supabase-Utils
```

## Setup

```bash
# 1. Dependencies
cd web && npm install

# 2. Environment
cp .env.example .env
# → Supabase-URL, Anon-Key, Service-Role-Key eintragen (nie committen!)

# 3. Supabase Migrations
cd ../supabase && supabase db reset

# 4. Dev-Server
cd ../web && npm run dev

# 5. Build
npm run build
```

## Deployment

- **DEV:** `carp24-dev` (Port 8094) · **LIVE:** `carp24-app` (Port 4321 hinter NGINX) — gleicher Hetzner-Host
- **Supabase:** Docker Compose (Kong, Auth, DB, Realtime, Storage)
- **Domain:** carp24.org
- Deploy-Routine mit Rollback-Tag + wartungsbewusstem Smoke: **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**
- **Aktueller Betriebsstatus:** Wartungsmodus AN (Details [docs/BETRIEB.md](docs/BETRIEB.md))

## Dokumentation

| Datei | Inhalt |
|-------|--------|
| [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) | SSR, Middleware, Supabase, Docker/NGINX, Datenmodell |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Dev→Live-Routine, Rollback, Smoke, Wartungsmodus |
| [docs/AI-ASSISTENT.md](docs/AI-ASSISTENT.md) | KI-Endpoints, Modelle, Wetter-Integration, Prompts, Limits |
| [docs/SEO-GEO.md](docs/SEO-GEO.md) | llms.txt, FAQPage, Sitemap, Kanonisierung, Meta |
| [docs/BETRIEB.md](docs/BETRIEB.md) | Wartungsmodus, Monitoring, DB-Checks, offene Punkte |
| [docs/secrets.md](docs/secrets.md) | Secrets-Management |

Historische Dokumente (Briefings, Pläne, Audits 08/2026) liegen ebenfalls unter `docs/`.

## Lizenz

Proprietary — © 2026 Philipp Schlemmer / einfach-online.dev
