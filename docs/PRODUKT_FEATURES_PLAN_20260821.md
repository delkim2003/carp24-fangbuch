# 🗺️ CARP24 — PLAN: ALLE PRODUKT-FEATURES VOR ALPHA (21.08.2026, v2)

> **Auftrag (Philipp, 21.08.):** Alle offenen Produkt-Features vor dem Alpha-Test einbauen. **v2 = nach Experten-Loop** (Audit-Report: `docs/AUDIT_PLAN_EXPERTEN_20260821.md`; 3 Subagenten timeouteten → Self-Audit, 2× P0 + 5× P1 eingearbeitet). Dann Build-Phase (OpenCode-Briefings pro Feature).
> Basis: Feature-Matrix v3 (Restlücke = 14 Produkt-Features; Dark Mode ✅, Phase-1-Kern ✅).

## Reihenfolge & Batches

| Batch | Features | Warum diese Reihenfolge |
|-------|----------|-------------------------|
| A | **CSV-Import → Badges → Jahres-Rückblick → Trips** | Schnelle Gewinne, kein externer Dienst; **v2: Badges NACH Import** (Daten-Importeur-Badge, P2-3) |
| B | Google/FB-Login (OAuth) | Akquise; braucht AVV (Google/FB) + Provider-Creds |
| C | **Community-Board → Forum → Chat** | v2: Forum vor Chat (statisch einfacher, P3-1); User-Content → content_reports (P0-2) |
| D | Pro-Gating, Abo/Stripe | Monetarisierung; Stripe = AVV/Steuer + Webhook-Idempotenz (P1-3/P1-5) |
| E | i18n, Push, KI-Assistent, Marktplatz | Plattform/Experimentell, größte Scope |

## PFLICHT-ÜBERGREIFEND (P0 — vor oder mit den Features)

| Task | Fund | Inhalt |
|------|------|--------|
| **X1 Export/Löschung erweitern** | P0-1 | Art-15/17-Export + Löschung um ALLE neuen Tabellen erweitern (trips, user_badges, forum_*, chat_*, marketplace_items, push_subscriptions, content_reports). DoD: E2E-Export enthält neue Daten |
| **X2 content_reports (DSA)** | P0-2 | Migration: `content_reports` (id, target_type, target_id, reporter_id, reason, status, created_at) + Meldelink auf allen User-Content-Elementen + Admin-Ansicht (status: open/resolved) |

## FEATURE-DETAILS

### A1 CSV-Import (Fänge übernehmen)
- **Scope:** /profil → "Fänge importieren" (CSV hochladen, Spalten-Mapping: Datum, Gewicht, Fischart, Gewässer, lat/lng optional; Validierung + Vorschau + Fehlerreport; max 500 Zeilen/Lauf)
- **Schema:** keine Änderung (publish_catch-RPC wiederverwenden, aber ohne Pro-Check für eigenen Import? → Import = eigene RPC `import_catches` mit Session-Check + batch insert)
- **DoD:** E2E: CSV mit 5 Fängen → importiert + Liste zeigt sie; Fehlerreport bei kaputten Zeilen
- **Aufwand:** 1 Tag

### A2 Jahres-Rückblick
- **Scope:** /rueckblick (saisonal, 1.1.–31.12.): Fänge gesamt, kg gesamt, Top-3 (Gewicht/Gewässer/Köder), Mond-Statistik, Foto-Collage der Top-Fänge; teilen als Bild (Canvas) oder Link
- **Schema:** keine (Aggregate aus catches)
- **DoD:** E2E: Jahreswerte korrekt (27 Fänge → Summen stimmen); Teilen-Button rendert
- **Aufwand:** 1 Tag

### A3 Badges (Gamification)
- **Scope:** Badge-Definitionen (10 Stück: Erster Fang, 10 Karpfen, 100 kg, Nachtfischer [Fang 22–5 Uhr], 5 Gewässer, Serie 7 Tage, Foto-Profi, Regenfischer [Wetter-Hook], 1 Jahr Mitglied, Daten-Importeur) + Profil-Badge-Grid + Toast bei neuem Badge
- **Schema:** Migration 0016 `badges` (id, code, name, description, icon, sort) + `user_badges` (user_id, badge_id, earned_at, PK user+badge); Badge-Check via RPC `check_badges(user_id)` nach jedem publish/import
- **DoD:** E2E: Test-User erfüllt Bedingung → Badge erscheint im Profil
- **Aufwand:** 1–1,5 Tage

### A4 Trips (Angelausflüge)
- **Scope:** /trips: Trip anlegen (Name, Gewässer, Datum, Notizen), Fänge einem Trip zuordnen (Fang-Formular: Trip-Dropdown), Trip-Detail mit Fängen + Statistik
- **Schema:** Migration 0017 `trips` (id, user_id, name, water_name, trip_date, notes, created_at) + `catches.trip_id` FK nullable; RLS own
- **DoD:** E2E: Trip anlegen → Fang zuordnen → Detail zeigt Fang
- **Aufwand:** 1,5 Tage

### B1 Google/FB-Login (OAuth)
- **Scope:** GoTrue-Provider konfigurieren (Google + Facebook) via docker-compose Env (GOTRUE_EXTERNAL_GOOGLE/FACEBOOK_ENABLED + Client-ID/Secret), Login-Seite Social-Buttons
- **Schema:** keine (GoTrue managed)
- **Risiko:** Provider-Creds (Philipp), AVV Google/FB (Vault 0.7 hatte sie geplant), Redirect-URLs
- **DoD:** E2E: Google-Button erscheint; echter OAuth-Flow nur mit echten Creds (Dev: Test-Creds)
- **Aufwand:** 0,5–1 Tag (ohne Wartezeit auf Creds)

### C1 Community-Board/Teilen
- **Scope:** Öffentliche Seite /community: Top-Fänge (gewichtete Liste, nur public=1), Fang "teilen" (public toggle + generierter Share-Link /c/{slug}); anonym lesbar, nur Owner setzt public
- **Schema:** Migration 0018: `catches.is_public bool default false` + `catches.share_slug text`; RLS: public lesbar nur is_public=true + deleted_at null
- **DoD:** E2E: Owner toggelt public → /community zeigt Fang; anonym sieht /c/slug; private Fänge unsichtbar
- **Aufwand:** 2 Tage

### C2 Forum
- **Scope:** /forum: Kategorien (Allgemein, Gewässer, Ausrüstung, Karpfen-Küche), Threads + Antworten (Markdown-light), eigene Posts editierbar/löschbar, Moderation (nur Admin löscht fremde)
- **Schema:** Migration 0019: `forum_categories`, `forum_threads`, `forum_posts` (user_id, FK, RLS own + read public)
- **Risiko:** DSGVO/DSA: Notice-and-Action, Abuse-Reporting (Vault 5.2 hatte Notice-and-Action geplant)
- **DoD:** E2E: Thread erstellen → Antworten → löschen
- **Aufwand:** 3–4 Tage

### C3 Chat
- **Scope:** Realtime-Chat pro Fang/Community (Supabase Realtime ist da): /chat/{channel}: Nachrichten senden/lesen, Historie, Realtime-Subscription, RLS channel-member
- **Schema:** Migration 0020: `chat_channels`, `chat_messages` (RLS: member-only read, own write)
- **Risiko:** Moderation (Flood/Abuse), Realtime-Kanal-Auth
- **DoD:** E2E: 2 Sessions → Nachricht erscheint in beiden
- **Aufwand:** 3 Tage

### D1 Pro-Gating
- **Scope:** Free vs. Pro (Feature-Locks): Free = Kern (Fänge, Statistik, Wetter); Pro = Foto-Speicher >5, CSV-Import, Jahres-Rückblick, Badges, Trips, Chat. Lock-Icons + Upgrade-CTA; `profiles.is_pro`
- **Schema:** Migration 0021: `profiles.is_pro bool default false` + publish_catch-Pro-Check erweitern
- **DoD:** E2E: Free-User sieht Lock bei Pro-Feature; Pro-User nicht
- **Aufwand:** 2 Tage

### D2 Abo/Stripe
- **Scope:** Stripe Checkout (monatlich/jährlich), Webhook → set is_pro; /preis mit Plänen; Abo-Verwaltung (Portal-Link)
- **Schema:** keine DB (Stripe managed); Env: STRIPE_SECRET/WEBHOOK
- **Risiko:** AVV Stripe, Steuer (USt), PCI (kein Card-Handling — Checkout macht's), Sandbox-Test
- **DoD:** E2E: Test-Checkout (Stripe test mode) → is_pro=true via Webhook
- **Aufwand:** 2–3 Tage

### E1 i18n
- **Scope:** de/en Grundgerüst: Astro i18n (Locale-Routing /en), UI-Strings auslagerung (Key-Store), Rechtstexte EN-Version
- **Schema:** keine
- **DoD:** /en ist erreichbar, Kernseiten übersetzt
- **Aufwand:** 2–3 Tage

### E2 Push-Notifications
- **Scope:** Web-Push (VAPID): SW-push-Event + Abo-Verwaltung (Profil), Trigger: Fang-Erinnerung (Tage ohne Fang), Community-Antwort
- **Schema:** Migration 0022: `push_subscriptions` (user_id, endpoint, keys, created_at)
- **Risiko:** VAPID-Keys, iOS-Support unvollständig
- **DoD:** E2E: Abo speichern; Push-Test (Dev-Tool)
- **Aufwand:** 2 Tage

### E3 KI-Assistent
- **Scope:** /assistent: Fang-Analyse (Statistik zusammenfassen), Köder-/Gewässer-Tipps aus eigenen Daten; API via OpenRouter (GLM/MiMo) server-seitig (Astro-API-Route, Key im Env, RLS-check), Antworten nicht persistent (DSGVO!)
- **Schema:** keine
- **Risiko:** AVV Mistral/OpenRouter (0.7 geplant), Datenschutz (keine Speicherung, Opt-in)
- **DoD:** E2E: Frage → Antwort mit Kontext (echte API, Sandbox-Key)
- **Aufwand:** 2 Tage

### E4 Marktplatz
- **Scope:** /marktplatz: Anzeigen (Titel, Preis, Kategorie, Foto, Ort), Kontakt über internes Formular (E-Mail), Suche/Filter, eigene Anzeigen verwalten
- **Schema:** Migration 0023: `marketplace_items` (user_id, title, price, category, description, photos, location, status) + RLS own write, public read
- **Risiko:** Betrug/Abuse, Preisangaben (USt), Foto-Upload wiederverwenden
- **DoD:** E2E: Anzeige erstellen → Liste zeigt sie → Kontakt-Formular sendet Mail
- **Aufwand:** 4–5 Tage

## ÜBERGREIFENDE RISIKEN
1. **DSGVO/DSA:** Community-Features (Forum/Chat/Marktplatz) = User-Content → Impressum/Notice-and-Action, Abuse-Reporting, Löschkonzept erweitern (Vault 5.2 DSA)
2. **AVVs:** Google/FB (B1), Stripe (D2), OpenRouter/Mistral (E3) — Vault 0.7 hatte AVV Google/FB + Mistral geplant; Stripe neu
3. **OAuth:** Redirect-URLs + Creds fehlen (Philipp) — Dev-Fallback: Buttons sichtbar, Flow erst mit Creds
4. **Migrationen:** 8 neue Migrationen (0016–0023) — Container-Migrationszähler beachten (aktuell 61, nachziehen-Prozedur bekannt)
5. **Test-Daten:** Badges/Trips/Rückblick brauchen Test-Fänge mit Zeiträumen (Seeder)

## BUILD-REIHENFOLGE (nach Audit, v2)
X1/X2 (P0) → A1 CSV → A3 Badges → A2 Rückblick → A4 Trips → B1 OAuth → C1 Board → C2 Forum → C3 Chat → D1 Gating → D2 Stripe → E1 i18n → E2 Push → E3 KI → E4 Marktplatz
(jedes Feature: Briefing → OpenCode → E2E → Commit; Batch-Checkpoints nach A, C, D)

## PLAN-v2-DELTA (Findings aus Experten-Loop eingearbeitet)

| Feature | Konkretisierung |
|---------|-----------------|
| A1 CSV | `import_catches`-RPC nutzt GLEICHE Validierungslogik wie publish_catch (lat/lng-CHECK, Pflichtfelder); danach `check_badges(user_id)` |
| A3 Badges | Badge-Check als eigenständige RPC `check_badges(user_id)` vom Client nach Speichern/Import aufgerufen — KEIN Trigger-Nesting (P2-1) |
| B1 OAuth | GoTrue-Env: `GOTRUE_SITE_URL`, `GOTRUE_EXTERNAL_REDIRECT_URL`, `GOTRUE_EXTERNAL_GOOGLE_ENABLED/CLIENT_ID/SECRET`, FB analog; Redirect in Provider-Konsole: `{SITE_URL}/auth/v1/callback` (P1-1) |
| C1 Board | **Privacy by Design:** bei is_public lat/lng auf 2 Dezimalstellen runden (~1 km) oder verbergen (P2-4) |
| C2 Forum | Meldelink → `content_reports` (X2); eigene Posts editierbar/löschbar, Admin löscht fremde via Report |
| C3 Chat | Realtime-Setup: `alter publication supabase_realtime add table chat_messages` + REPLICA IDENTITY FULL; Kanal-Auth via JWT (Authorization-Header); Flood-Schutz 1 msg/2s (client + RLS) (P1-2) |
| D1 Gating | Admin/Pro-Flag: Philipp (Admin) sieht ALLES ohne Locks — Alpha-Sichtbarkeit gesichert (P1-4) |
| D2 Stripe | Webhook: `STRIPE_WEBHOOK_SECRET` + Idempotenz-Tabelle `stripe_events` (event.id) + nur `checkout.session.completed` setzt is_pro; Test-Mode (P1-3) |
| E3 KI | No-Log-Regel (kein Prompt in Logs), Rate-Limit + Timeout server-seitig, UI-Hinweis "KI-generiert", Opt-in (P3-3) |
| E4 Marktplatz | Fotos im BESTEHENDEN Bucket `catch-photos` mit Pfad-Präfix `marketplace/` (privat, signed URLs) (P2-5) |

## ÜBERGREIFENDE RISIKEN (v2)
1. **DSGVO/DSA:** Community = User-Content → `content_reports` (X2) + Notice-and-Action + Abuse-Reporting; Löschkonzept/VVT im Vault erweitern
2. **AVVs:** Google/FB (B1) + Mistral/OpenRouter (E3) aus 0.7; **Stripe (D2) NEU in DSGVO_AVV** ergänzen, Abschluss VOR Aktivierung (P1-5)
3. **OAuth:** Redirect-URLs + Creds fehlen (Philipp) — Dev-Fallback: Buttons sichtbar, Flow erst mit Creds
4. **Migrationen:** 8+ neue (0016–0023 + content_reports + stripe_events) — Zähler 61, Nachzieh-Prozedur bekannt
5. **Test-Daten:** Badges/Trips/Rückblick brauchen Test-Fänge mit Zeiträumen (Seeder)
