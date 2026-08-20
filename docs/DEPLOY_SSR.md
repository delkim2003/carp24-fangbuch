# Carp24 Web-Deploy (SSR seit Task 1.8)

## WICHTIG: Seit Task 1.8 ist das Frontend SSR (Astro Node-Adapter), NICHT mehr statisch!

- **Build:** `cd web && npm run build` → `dist/server/entry.mjs`
- **Laufzeit-Service:** Systemd `carp24-web` (Node-Server auf 127.0.0.1:4321)
- **Reverse-Proxy:** Apache-VHost `carp24-build.conf` (Port 8094) → ProxyPass auf 4321
- **Env:** `web/.env` (PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY) — via EnvironmentFile im Service

## Befehle
```bash
# Rebuild + Restart
cd /mnt/projekte/carp24-fangbuch/web
npm run build
sudo systemctl restart carp24-web
sudo systemctl status carp24-web --no-pager | head -5

# Test
curl -s -o /dev/null -w "%{http_code}\n" http://100.93.250.103:8094/
```

## WICHTIGE ASTRO-LEHRE (Env in is:inline-Scripts)
`import.meta.env` wird in `is:inline`-Scripts NICHT ersetzt (kein Bundler-Durchlauf).
Lösung: Env im Layout-Frontmatter lesen → `data-supabase-url`/`data-supabase-anon-key` am `<body>` → Scripts lesen per `document.body.dataset.supabaseUrl`.
NIE `%PUBLIC_SUPABASE_URL%`-Platzhalter hartcodieren (bleibt wörtlich im HTML).
