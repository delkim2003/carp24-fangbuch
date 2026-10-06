# Betrieb

## Wartungsmodus (aktuell AN)

- Schalter: `app_settings.maintenance = {"enabled": true, "message": ""}` (sofort wirksam über die Middleware).
- Wer sieht was: Admin/MODERATOR = normal · Besucher = 302 auf `/wartung` · `/api/*` = 503 JSON · Login/Impressum/Datenschutz/robots/sitemap bleiben erreichbar.
- Doku zum Ablauf: [DEPLOYMENT.md](DEPLOYMENT.md).

## Monitoring & Qualität

- **Matomo** (Self-Hosted, `matomo.einfach-online.dev`) — in CSP `script-src` eingetragen.
- **error_logs**-Tabelle im Backend für Fehler-Sichtung.
- **Smoke-Checks** nach jedem Deploy (siehe DEPLOYMENT.md) — Wartungsmodus-Logik einrechnen (302 ist im Wartungsmodus KORREKT, kein Fehler!).
- Turnstile (Cloudflare) für Formular-Schutz — CSP-Pfade: `challenges.cloudflare.com` in script/frame/connect-src.

## Wartungsroutinen

- **DB-Zugriff:** `docker exec supabase-db psql -U supabase_admin -d postgres` (Tabellenübersicht in ARCHITEKTUR.md).
- **Supabase-Utilities:** `infra/utils/` (Key-Rotation/JWT-Sync, Postgres-Upgrade auf 17).
- **Secrets:** siehe [secrets.md](secrets.md) — `.env` nie committen, Keys rotieren über die Utils, Pre-Commit-Scan unter `infra/utils/pre-commit-secret-scan.sh`.
- **Service Worker** (`/sw.js`) ist aktiv (PWA) — bei UI-/Logout-Änderungen Cache-Strategie mitdenken.
- **npm audit:** aktuell 0 Vulnerabilities (10/2026 gefixt, inkl. Astro-RCE via AVIF) — regelmäßig wiederholen.

## Daten-Regeln (verbindlich)

- **Zahlenformat:** Absolute Zahlen/Zähler IMMER ganzzahlig — **nur Gewicht** darf ein Dezimal-Komma tragen (Länge in cm ebenfalls ganzzahlig).
- Statistik-Anzeige: `ni()`/`nf()`-Helfer in `statistik.astro` setzen das um.

## Offene Punkte (Auszug, Stand 10/2026)

- Wartungsmodus bewusst AN — Freigabe vor Public-Launch abstimmen.
- Stripe-Anbindung (Abos) nicht produktiv, Turnstile/DKIM finalisieren.
- lazy loading für Bilder (~222 KB Optimierungspotenzial), Landing-Bilder (Signed URLs).
- `support@carp24.de` vs. `.org` — Adressen-Klärung ausstehend (SEO-GEO.md).
