# BRIEFING — Task 1.13: Error-Tracking Client-Handler (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen.

## Ziel
Ein Client-seitiger Error-Handler, der Frontend-Fehler automatisch in die neue `error_logs`-Tabelle schreibt (Backend fertig, Migration 0014, live verifiziert). **Kein Sentry, kein externer Dienst — Eigenbau auf Supabase.**

## Backend-Kontrakt (VERBINDLICH — live)
- Tabelle `public.error_logs`: `id (uuid)`, `user_id (uuid, auto via Trigger)`, `created_at (timestamptz)`, `level (text: error|warning|info)`, `source (text: client)`, `url (text)`, `message (text, max 2000 via Trigger)`, `stack (text, max 4000 via Trigger)`, `context (jsonb)`
- **INSERT via REST:** `supabase.from("error_logs").insert({ level, source, url, message, stack, context })` — RLS erlaubt authenticated-INSERT, user_id setzt der Trigger
- **Nur eingeloggte User:** kein INSERT ohne Session (RLS). Wenn keine Session → Fehler still ignorieren (kein Server-Log ohne User).

## Deliverables (in web/)

### 1. `web/src/lib/error-tracker.ts` (NEU)
Client-Modul mit:
- `export function initErrorTracker(sb: SupabaseClient)`:
  - `window.addEventListener("error", handler)` — lädt `sb.auth.getSession()`; wenn Session: `sb.from("error_logs").insert({ level: "error", source: "client", url: window.location.pathname, message: String(event.message || "").slice(0, 2000), stack: String(event.error?.stack || event.error || "").slice(0, 4000), context: { ua: navigator.userAgent } })` — **kein await, fire-and-forget**, Fehler beim Loggen selbst still schlucken (kein Endlos-Loop!)
  - `window.addEventListener("unhandledrejection", handler)` — gleicher Weg, `message: String(event.reason?.message || event.reason || "Unhandled Promise Rejection")`
  - Return eine Funktion zum Aufräumen (optional)
- `export function logError(sb, message, opts?: { level?, stack?, context? })` — manuelles Loggen (für abgefangene Fehler in catch-Blöcken)
- **Kein doppeltes Loggen:** dedupe-Key aus message+url in einem einfachen Set (max ~20 Einträge), damit wiederkehrende Fehler nicht die Tabelle fluten
- **Kein Feedback an User** (still), keine console.error-Spam-Verdopplung

### 2. `web/src/layouts/Layout.astro` (PATCH — Handler initialisieren)
- Im Frontmatter: `import { supabase } from "../lib/supabase-client"` (falls nicht schon da) + `import { initErrorTracker } from "../lib/error-tracker"`
- **VORSICHT:** Layout.astro ist SSR — der Error-Tracker ist Client-only. Rufe `initErrorTracker` NICHT im Frontmatter auf (dort gibt es kein window). Stattdessen: im bestehenden gebündelten `<script>`-Block (oder einem neuen kleinen gebündelten Script, NICHT is:inline) `initErrorTracker(supabase)` aufrufen, nachdem das Script den supabase-Client importiert hat.
- Prüfe zuerst: Gibt es im Layout schon ein gebündeltes Script mit `import { supabase }`? Wenn ja, dort ergänzen. Wenn nein: kleines gebündeltes `<script>` am Ende ergänzen: `import { supabase } from "../lib/supabase-client"; import { initErrorTracker } from "../lib/error-tracker"; initErrorTracker(supabase);`
- **KEIN is:inline für diesen Code** (braucht imports).

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/layouts/Layout.astro, web/src/lib/supabase-client.ts
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede neue Datei MUSS vollständig geschrieben werden. Keine Diffs, keine Snippets.**
- **Fehler beim Loggen dürfen nie neue Fehler erzeugen** (try/catch oder .catch(() => {}) um jeden supabase-Call)
- **Kein User-Feedback, kein UI** — nur still loggen
- `import.meta.env` NIE in is:inline — dieser Code ist gebündelt (import), ok.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "error_logs" /mnt/projekte/carp24-fangbuch/web/src/lib/error-tracker.ts   # MUSS ≥1
grep -c "unhandledrejection" /mnt/projekte/carp24-fangbuch/web/src/lib/error-tracker.ts   # MUSS ≥1
grep -c 'window.addEventListener("error"' /mnt/projekte/carp24-fangbuch/web/src/lib/error-tracker.ts   # MUSS ≥1
grep -c "initErrorTracker" /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro   # MUSS ≥1
grep -c "error-tracker" /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro      # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/   # MUSS 0
```
Server-Start + E2E (Fehler provozieren → DB-Zeile) macht der Hauptagent NACH deinem Lauf.
