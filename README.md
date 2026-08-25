# 🎣 Carp24 — Dein digitales Fangbuch

> Premium Digital Logbook für Karpfenangler. Erfasse, analysiere und teile deine Fänge.

[![Alpha](https://img.shields.io/badge/status-alpha-orange)]()
[![Astro](https://img.shields.io/badge/Astro-5.x-FF5D01)]()
[![Supabase](https://img.shields.io/badge/Supabase-Self--Hosted-3FCF8E)]()
[![Tailwind](https://img.shields.io/badge/Tailwind-4.x-06B6D4)]()

## Features

- **Fangbuch** — Fänge erfassen mit Gewicht, Länge, Fischart, Köder, Methode, Gewässer, GPS, Foto
- **Dashboard** — KPIs, Fänge pro Monat, Top-Fänge, Gewichtsverlauf
- **Statistik-Studio** — Filter nach Wetter, Mondphase, Luftdruck, Wassertemperatur, Uhrzeit
- **Jahres-Rückblick** — Saison-Zusammenfassung mit Top-Fängen und Statistiken
- **Trips** — Angelausflüge planen und Fänge zuordnen
- **Badges** — Gamification (10 Achievements: Erster Fang, 100kg, Nachtfischer, ...)
- **Community-Board** — Öffentliche Fänge teilen
- **Forum** — Kategorien, Threads, Antworten
- **Chat** — Realtime-Community-Chat
- **Marktplatz** — Angel-Ausrüstung kaufen/verkaufen
- **KI-Assistent** — Fang-Analyse und Köder-Tipps (OpenRouter)
- **CSV-Import** — Bestände Fänge importieren (max 500/Lauf)
- **Premium** — Stripe-Integration für Pro-Features
- **i18n** — Deutsch/Englisch
- **Dark Mode** — System-Override
- **DSGVO** — Klaro Consent, Matomo Self-Hosted, Account-Löschung, CSV-Export

## Tech-Stack

| Layer | Technologie |
|-------|-------------|
| Frontend | Astro 5 (SSR) + Tailwind CSS 4 |
| Backend | Supabase (Self-Hosted, Docker) |
| Auth | Supabase Auth (E-Mail + OAuth Google/Facebook) |
| DB | PostgreSQL 15 (Supabase) |
| Realtime | Supabase Realtime (Chat) |
| Payments | Stripe (Checkout + Webhook) |
| KI | OpenRouter (GLM/MiMo) |
| Analytics | Matomo (Self-Hosted, DSGVO) |
| Consent | Klaro |
| Server | Apache + Node.js (SSR) |

## Projektstruktur

```
carp24-fangbuch/
├── web/                    # Astro Frontend + SSR
│   ├── src/
│   │   ├── pages/          # Routen (30 Seiten)
│   │   ├── components/     # Header, Footer, CatchCard, ...
│   │   ├── layouts/        # Layout.astro
│   │   └── lib/            # supabase-client, i18n, catch-service, ...
│   ├── public/             # Statische Assets
│   └── .env                # Environment (NICHT committen)
├── supabase/
│   └── migrations/         #35 SQL-Migrationen
├── design/
│   └── screens/            # Stitch-Design-Screens (HTML/PNG)
├── docs/                   # Feature-Plan, RESUME, Audit-Reports
└── infra/                  # Docker, Backups, Scripts
```

## Setup

```bash
#1. Dependencies
cd web && npm install

#2. Environment
cp .env.example .env
# → Supabase-URL, Anon-Key, Service-Role-Key eintragen

#3. Supabase Migrations
cd ../supabase && supabase db reset

#4. Dev-Server
cd ../web && npm run dev
# → http://localhost:4321

#5. Build
npm run build
# → dist/ für Production
```

## Deployment

- **Server:** Tailscale-Netzwerk (100.93.250.103)
- **Web:** Apache Reverse Proxy → Node.js SSR (Port8094)
- **Supabase:** Docker Compose (Kong :8055, Auth, DB, Realtime, Storage)
- **Domain:** carp24.org

## Lizenz

Proprietary — ©2026 Philipp Schlemmer / einfach-online.dev
