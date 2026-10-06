# Architektur (Stand 10/2026)

## Überblick

```
Internet ──► NGINX 1.28 (Host, TLS, Reverse-Proxy, locations mit Cache-Control)
                │
                ▼ :4321
         carp24-app (Docker, Astro 5 SSR, Node-Adapter)
                │
                ▼ :8000 (Kong) / :54322
         Supabase self-hosted (Postgres, Auth, Realtime, Storage)
```

- **DEV:** `carp24-dev` (Port 8094, direkt am Astro-Dev/-Prod-Container, kein NGINX davor)
- **LIVE:** `carp24-app` (Port 4321 hinter NGINX, TLS via Let's Encrypt)
- Beide Container hängen im Netz `supabase_default` und teilen sich **eine** Supabase-Instanz.

## Astro SSR (web/)

- Node-Adapter, alles SSR (kein statisches dist-HTML außer `public/`).
- `src/middleware.ts` = zentrale Schaltstelle für JEDE Anfrage:
  1. **Static-Asset-Kurzschluss** (`/_astro/`, Bilder, Fonts …) — ohne DB/Auth, versorgt mit Security-Headern.
  2. **Auth:** `supabase.auth.getUser()` (validiert JWT + refreshed Tokens; `getSession()` nur für die Session-Token), Profile-Cache mit 30 s TTL (Rolle + is_pro).
  3. **Wartungsmodus:** siehe [DEPLOYMENT.md](DEPLOYMENT.md) — Exempts: Login/Register/Logout (`/api/auth/`), `/login`, `/wartung`, `/impressum`, `/datenschutz`, `/404`, `/offline`, `/admin/*`, MODERATOR/ADMIN.
  4. **CSRF:** Origin-Check für POST/PUT/DELETE/PATCH (erlaubt: `https://carp24.org`, DEV-Hosts) — ausgenommen `/api/auth/`, `/api/stripe/webhook`, `/supabase/`.
  5. **Security-Header = Single Source** (genau hier, nirgends sonst — NGINX setzt keine mehr):
     `Strict-Transport-Security` (max-age 1 J, includeSubDomains), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (geolocation=(self), Kamera/Mikro/… = leer), **CSP granular** (script-src: self + Turnstile + jsdelivr + Matomo; connect-src: self + api.open-meteo.com + openrouter.ai + wss:).
  6. **Cache:** Assets = 1 Jahr immutable · `/api/` = no-store · HTML = no-cache, must-revalidate.

## Supabase / Datenmodell (28 Tabellen, public-Schema)

`admin_audit_log, admin_notifications, ai_usage, app_settings, badges, catches, channel_members, channels, chat_messages, content_reports, error_logs, feature_flags, forum_posts, forum_threads, marketplace_contacts, marketplace_items, marketplace_listings, marketplace_messages, notifications, posts, profiles, push_subscriptions, reports, stripe_events, subscriptions, trips, user_badges, waters`

Kern-Entitäten:
- **catches** — Fang (catch_ts, weight_kg, species, water_name, lat/lng, bait, method, notes, `weather`-JSON = Wetter-Snapshot mit temp_c/weather_text/pressure_hpa/wind_speed_kmh/moon_text, weather_auto, deleted_at)
- **waters / trips** — Gewässer und Ausflüge
- **app_settings** — Key/Value (u. a. `maintenance` = Wartungsmodus, `openrouter_key` = KI-Key-Fallback)
- **ai_usage** — Monatszähler KI-Assistent (50/Monat Pro, siehe AI-ASSISTENT.md)
- **profiles** — Rolle (USER/MODERATOR/ADMIN), is_pro

Auth-Cookie: `sb-carp24-auth-token` — LIVE: `secure=true, sameSite=lax, host-only, path=/` · DEV: `secure=false`.

## NGINX

- Server-Blöcke unter `/etc/nginx/sites-enabled/carp24` (**Achtung: echte Duplikatdatei zu `sites-available/carp24`, KEIN Symlink — beide pflegen!**).
- Zuständig: TLS, Reverse-Proxy, **Cache-Control in `/_astro/`- u. a. Asset-Locations** (1 J immutable / 7 T / 30 T).
- Keine Security-Header mehr (bewusst, s. o. Single-Source). Backups der Config unter `/etc/nginx/backups/` — **nie Sicherungen in `sites-enabled/` ablegen** (wird als Site geladen → `nginx -t` bricht ab!).

## Self-Hosting-Notizen

- Supabase-Utilities in `infra/utils/` (Key-Generierung, JWT-Sync, Postgres-Upgrade) — arbeiten mit `.env` (nie committen!).
- DB-Zugriff: `docker exec supabase-db psql -U supabase_admin -d postgres`.
