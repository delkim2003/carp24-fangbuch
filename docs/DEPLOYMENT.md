# Deployment (DEV → LIVE)

**Grundregel:** Jede Änderung wird zuerst in DEV bewiesen, dann LIVE deployen. LIVE-Niethner (Hetzner) nur über die Deploy-Routine anfassen.

## Server

| | DEV | LIVE |
|---|---|---|
| Host | 46.225.98.79 (Hetzner) | 46.225.98.79 (gleicher Host!) |
| URL | http://46.225.98.79:8094 | https://carp24.org |
| Container | `carp24-dev` | `carp24-app` (hinter NGINX :4321) |
| SSH | `ssh -p 2222 philipp@46.225.98.79` (Key `~/.ssh/hetzner_carp24`) | gleich |

## Deploy-Routine (bewährt)

1. **Rollback-Tag VOR dem Deploy** (harter Pflichtschritt!):
   `docker tag carp24-image rollback-YYYYMMDD_HHMM` (die Routinen setzen es in Phase 0/4 selbst)
2. **Build:** `npm run build` in `web/` — Build-Exit MUSS 0 sein.
3. **Docker-Rebuild:** Image neu bauen (`--no-cache` bei Basis-Image-Wechseln) + Container neu starten.
4. **Verify:** MD5-Vergleich lokales Artefakt vs. Container-Datei + Marker-Grep im Image.
5. **Smoke-Tests — wartungsbewusst:**
   - `/` → 302 auf `/wartung` = **korrekt** (Wartungsmodus AN!)
   - `/login` und `/login/` → **200** (Exempt-Pfade)
   - `/agb` → 302 (wartungskorrekt)
   - Bei Wartungsmodus AUS: alle → 200.
6. Container-Status: `docker ps` (`carp24-app Up …`).

Rollback: `docker stop carp24-app && docker run … rollback-TAG …` bzw. Image retaggen + neu starten. Vorhandene Tags: u. a. `rollback-20261006_1439`, `rollback-20261006_1730`.

## Wartungsmodus

- **Ein/Aus:** `app_settings.maintenance = {"enabled": true, "message": ""}` (in der DB, wirkt sofort über die Middleware).
- Exempts: Admin/MODERATOR, `/login`, `/wartung`, `/impressum`, `/datenschutz`, `/404`, `/offline`, `/admin/*`, `/api/auth/*`.
- `/api/*` (außer auth) → **503 JSON** im Wartungsmodus.
- robots.txt + sitemap.xml bleiben 200 (statische `public/`-Dateien laufen durch).

## NGINX-Änderungen (selten, aber kritisch)

- Config: `/etc/nginx/sites-enabled/carp24` — **Zwillingsdatei zu `sites-available/carp24` (kein Symlink!)**. Bei Änderungen BEIDE gleich halten.
- Ablauf: Backup nach `/etc/nginx/backups/` (NIE in `sites-enabled/`!) → ändern → `sudo nginx -t` → `sudo nginx -s reload`.
- Wenn `nginx -t` fehlschlägt: nicht reloaden, Backup zurückkopieren.

## Secrets

Siehe [secrets.md](secrets.md). Kurzfassung: `.env` wird nie committet (`.gitignore` gesperrt), Passwörter/Keys nur in Env/Dateien mit `0600`, Deploy- und Login-Skripte mit Secret-Fluss liegen bewusst AUSSERHALB des Repos.

## Bekannte Betriebsbesonderheiten

- Astro SSR + Docker: `import.meta.env` wird zur Build-Zeit ersetzt — für Laufzeit-Secrets IMMER `process.env` nutzen!
- Statistik-Zahlen: absolute Werte ganzzahlig, nur Gewicht mit Dezimal-Komma (Anzeigeformat).
- Service-Worker (`/sw.js`) aktiv — bei Logout-Änderungen SW-Cache beachten.
