# BRIEFING — Task 1.5b: Fang-Formular auf echte API (carp24)

## Ziel
Das Fang-Formular (`web/src/pages/fang-erfassen.astro`) auf das echte Supabase-Backend anbinden: Auth (Login nötig für publish), sync_catch-RPC (Fang anlegen), publish_catch-RPC (50er-Grenze), Gewässer-Suche via Edge-Function, 3 Geo-Methoden. **KEINE Beispieldaten.**

## Backend-Kontrakt (VERBINDLICH — bereits live, Migrationen 0001-0012)

### 1. sync_catch — Fang anlegen/aktualisieren (offline-fähig)
```sql
sync_catch(p_client_uuid uuid, p_data jsonb) RETURNS uuid
```
p_data-Felder (jsonb):
- `catch_ts` (ISO-String), `species` (ENUM: SPIEGEL|LEDER|SCHUPPEN|AMUR|ANDERE — NICHT 'Karpfen'!)
- `weight_kg` (numeric), `length_cm` (numeric, optional)
- `bait` (text), `method` (text, optional), `notes` (text ≤1000)
- `photos` (text[] — Array von Storage-Pfaden, optional)
- `lat` (numeric), `lng` (numeric), `water_name` (text), `water_id` (uuid, optional)
- `draft` (bool, default false)
- `weather` (jsonb, wird vom wetter-hook gesetzt — NICHT vom Client!), `weather_auto` (bool, false)
- `client_updated_at` (ISO-String — LWW-Basis!)

Rückgabe: catch_id (uuid)

### 2. publish_catch — veröffentlichen (50er-Grenze + Pro-Gate)
```sql
publish_catch(p_catch_id uuid) RETURNS void
```
Muss nach sync_catch aufgerufen werden (nur wenn draft=false bzw. immer für neue Fänge). Wirft bei >50 Fängen ohne Pro.

### 3. gewaesser-search — Edge-Function (Photon)
- URL: `{SUPABASE_URL}/functions/v1/gewaesser-search?query={q}`
- Auth: Bearer (User-JWT oder anon-key)
- Response: `[{name, lat, lng}, ...]` — Autocomplete für Gewässer

### 4. Auth (GoTrue)
- Login: `supabase.auth.signInWithPassword({email, password})`
- Session: `supabase.auth.getSession()`
- **Das Formular OHNE Login darf NICHT speichern können** (sync_catch wirft 'not authenticated')

## Deliverables (PFLICHT-Dateien — alle im web/)

1. **`web/src/lib/supabase-client.ts`** — BEREITS FERTIG (1.3), unverändert lassen
2. **`web/src/pages/fang-erfassen.astro`** — KOMPLETT ÜBERSCHREIBEN:
   - Auth-Guard: `onMount` prüft Session; wenn nicht eingeloggt → Login-CTA statt Formular (Link zu /login)
   - Formular-Felder (aus bestehendem Mockup + BAUPLAN 1.5b):
     - Gewicht (KG, Komma-Dezimal, prominent), Länge (cm, optional)
     - Fischart als Chips: SPIEGEL / LEDER / SCHUPPEN / AMUR / ANDERE
     - Gewässer: **Autocomplete-Suche** via gewaesser-search (Debounce 300ms, Dropdown mit Treffern name+coords), **ODER Freitext** (water_name für Privatgewässer), **+ 3 Geo-Methoden:**
       - (a) **GPS auto:** Button „Standort verwenden" → navigator.geolocation → lat/lng füllen
       - (b) **Manuell:** lat/lng-Inputs (dezimal)
       - (c) **Karten-Pick:** (optional, wenn machbar — sonst nur a+b im ersten Schritt und Karten-Pick als TODO markieren)
     - Köder (bait, optional), Methode (optional), Notizen ≤1000 mit Zähler
     - Datum+Uhrzeit (catch_ts)
     - Foto-Upload (optional, HEIC-Hinweis — Storage-Upload via supabase.storage, bucket 'catch-photos')
   - Submit-Logik:
     1. client_uuid via `crypto.randomUUID()`
     2. `supabase.rpc('sync_catch', { p_client_uuid, p_data })` 
     3. `supabase.rpc('publish_catch', { p_catch_id })`
     4. Erfolg → Redirect zu /faenge (Success-State existiert als Design)
     5. Fehler → Inline-Fehler (ehrlich, nicht schlucken)
   - Design: Carp24 Editorial (Warm Sand #E8E0C8, Khaki-Karten #CCCA9B, Olive #6C7A57, Source Serif 4/3, JetBrains Mono Labels) — Referenz: `design/screens/catch-form.html` (projekt-intern!)

3. **`web/src/lib/catch-service.ts`** (NEU) — Service-Schicht:
   - `saveCatch(data): Promise<{id, error}>` — sync_catch + publish_catch
   - `searchWaters(query): Promise<Water[]>`
   - Typen: `Water {name, lat, lng}`, `CatchInput {...}`

4. **Login-Flow** (minimal, da ohne Login kein Test möglich):
   - `web/src/pages/login.astro` — KOMPLETT ÜBERSCHREIBEN: E-Mail+Passwort → signInWithPassword, Fehler-Anzeige, Redirect zu /fang-erfassen nach Login
   - Session-State im Layout (Header zeigt Login/Logout)

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/catch-form.html, web/src/lib/supabase-client.ts, web/astro.config.mjs
- VERBOTEN: /etc, andere Projekte, supabase/migrations/ lesen (Kontrakt steht oben), infra/, /tmp, drush, Shell-Schleifen, git-Operationen
- KEINE Analyse-Ausflüge. Baue.

## WICHTIGE REGELN
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- `@supabase/supabase-js` ist installiert (2.112.3) — nutze es
- KEINE Beispieldaten hardcoden. KEINE Mock-Daten als 'fertig' deklarieren.
- `.env` nicht anfassen (PUBLIC_SUPABASE_URL/ANON_KEY sind schon da)
- DOMPurify für notes/water_name-Rendering falls nötig (installiert)
- Mobile-First, Touch-Targets ≥44px

## VERIFIKATION (NUR Syntax/Statik — KEINE Server, kein curl!)
```bash
grep -c "sync_catch" /mnt/projekte/carp24-fangbuch/web/src/lib/catch-service.ts
grep -c "publish_catch" /mnt/projekte/carp24-fangbuch/web/src/lib/catch-service.ts
grep -c "signInWithPassword" /mnt/projekte/carp24-fangbuch/web/src/pages/login.astro
grep -c "gewaesser-search\|searchWaters" /mnt/projekte/carp24-fangbuch/web/src/lib/catch-service.ts
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts
# muss alle >=1 sein
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
