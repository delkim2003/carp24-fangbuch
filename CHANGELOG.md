# Changelog

Alle signifikanten Änderungen an Carp24 dokumentiert.
Format: [Keep a Changelog](https://keepachangelog.com/de/1.0/)

## [0.1.0-alpha] — 2026-08-25

### Hinzugefügt
- **Fangbuch** — Fänge erfassen (Gewicht, Länge, Fischart, Köder, Methode, Gewässer, GPS, Foto, Wassertemperatur)
- **Dashboard** — KPIs (Gesamte Fänge, Schwerster Fang, Fänge dieses Jahr, Aktive Gewässer), Fänge pro Monat, Top-Fänge, Gewichtsverlauf
- **Statistik-Studio** — Filter nach Bedingungen, Mondphase, Luftdruck, Wind, Monat, Uhrzeit, Wassertemperatur
- **Jahres-Rückblick** — Saison-Zusammenfassung
- **Trips** — Angelausflüge anlegen und Fänge zuordnen
- **Badges** —10 Achievements (Erster Fang, Zehn Fänge,100 Kilo, Nachtfischer, Vielwasser, Woche voll, Foto-Profi, Regenfischer, Jahresmitglied, Import-Pionier)
- **Community-Board** — Öffentliche Fänge mit is_public Toggle
- **Forum** — Kategorien, Threads, Antworten (Markdown-light)
- **Chat** — Realtime-Community-Chat (Supabase Realtime)
- **Marktplatz** — Anzeigen erstellen, Kontakt-Formular
- **KI-Assistent** — Fang-Analyse via OpenRouter (GLM/MiMo)
- **CSV-Import** — Fänge importieren (max500/Lauf, Validierung, Fehlerreport)
- **Premium/Stripe** — Checkout, Webhook, Pro-Gating
- **OAuth** — Google + Facebook Login
- **i18n** — Deutsch/Englisch (alle Seiten)
- **Dark Mode** — System-Override mit Theme-Toggle
- **DSGVO** — Klaro Consent Banner, Matomo Self-Hosted, Account-Löschung, CSV-Export, Art-15/17-konform
- **Admin-Panel** — Nutzer-Verwaltung, Reports, Audit-Log, Revenue, Content, Stats
- **Push-Notifications** — Web-Push mit VAPID (Service Worker)
- **Profil** — MFA/TOTP, CSV-Import/Export, Badge-Grid, Push-Einstellungen
- **Impressum/Datenschutz** — Rechtlich erforderliche Seiten
- **Über Carp24** — Vision, Features,3-Schritte-CTA
- **Wartungsseite** —503 Maintenance Page
- **Gast-Navigation** — Über + Premium + Anmelden für nicht-eingeloggte User
- **Responsive** — Mobile-optimierte UI

### Infrastruktur
- Supabase Self-Hosted (Docker Compose): Kong, Auth, DB, Realtime, Storage, Studio
-35 SQL-Migrationen (catches, profiles, trips, badges, forum, chat, marketplace, content_reports, stripe_events, push_subscriptions, admin_audit_log, ...)
- DB-Indizes für Performance (catches, forum_posts, chat_messages, trips)
- Automatische Backups (PostgreSQL, Config, Storage, Roles) — verschlüsselt (GPG)
- Apache Reverse Proxy → Node.js SSR
- Tailscale-Netzwerk

### Sicherheit
- CSRF-Schutz auf allen API-Endpunkten
- Rate-Limiting auf Auth-Endpunkten
- RLS (Row Level Security) auf allen Tabellen
- Supabase Auth mit Cookie-Storage (SSR-kompatibel)
- Kong CORS konfiguriert
- Passwort-Mindestlänge8 Zeichen
- Admin/Moderator Rollen-System

### Performance
- N+1 Query-Eliminierung in Admin-API (users:402→4 Queries, reports:500→8 Queries)
- Lazy-Loading für Bilder
- DB-Indizes auf häufig abgefragten Spalten

### Behoben (während Alpha-Test)
- CORS-Error: Supabase-Proxy `/supabase/*` für Browser-Zugriff
- Cookie-Mismatch: storageKey SSR/Client Synchronisation
- SSR-Session: Alle15 Seiten auf `createSSRClient` Helper migriert
- i18n-Lücken in404, assistent, statistik, ueber, profil
- Registrierung-Placeholder: "mind.6 Zeichen" → "mind.8 Zeichen"
- admin/me.ts: Gibt401 statt200 bei fehlender Session
- RLS-Block: is_public Update mit authenticated Client
