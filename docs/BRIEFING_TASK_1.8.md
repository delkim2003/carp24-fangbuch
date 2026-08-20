# BRIEFING — Task 1.8: Fangliste + Empty + Success + Gewässer (carp24)

## Ziel
Die Fangliste (`web/src/pages/faenge.astro`) auf **echte Supabase-Daten** umbauen (KEINE Beispieldaten!): Liste aus catches-Tabelle, Filter, Empty-State, Success-Bestätigung, Gewässer-Anzeige. Außerdem `web/src/pages/faenge/[id].astro` (Detail) auf echte Daten.

## Backend-Kontrakt (VERBINDLICH — live)
### catches-Tabelle (RLS: user sieht NUR eigene Fänge)
Felder: `id (uuid)`, `client_uuid`, `user_id`, `catch_ts (timestamptz)`, `species (enum: SPIEGEL|LEDER|SCHUPPEN|AMUR|ANDERE)`, `weight_kg (numeric)`, `length_cm (numeric?)`, `bait (text?)`, `method (text?)`, `notes (text?)`, `photos (text[]?)`, `lat (numeric?)`, `lng (numeric?)`, `water_name (text?)`, `water_id (uuid?)`, `draft (bool)`, `weather (jsonb?)`, `weather_auto (bool)`, `created_at`, `updated_at`, `deleted_at (timestamptz?)`

### Abfrage (via supabase-client)
```ts
supabase.from('catches').select('*').eq('deleted_at', null).order('catch_ts', { ascending: false })
```
- RLS zeigt automatisch nur eigene Fänge (auth.uid())
- `deleted_at IS NULL` filter (weiche Löschung)
- weather jsonb: `weather->>'temp_c'`, `weather->>'pressure_hpa'`, `weather->>'moon_text'`, `weather->>'weather_text'`

## Deliverables (PFLICHT-Dateien — in web/)

### 1. web/src/pages/faenge.astro (KOMPLETT ÜBERSCHREIBEN — kein Mock!)
- Auth-Guard im Frontmatter: keine Session → Login-CTA
- **Daten laden:** im Frontmatter (oder onMount) `supabase.from('catches').select('*').eq('deleted_at', null).order('catch_ts', { ascending: false })`
- **LISTE:** Jeder Fang als Karte (Design: design/screens/catch-list.html + fangliste-empty.html):
  - Gewicht prominent (Monospace, groß, z.B. "18,4 KG" — Komma-Dezimal serverseitig gerundet, Zahlformat: weight_kg mit Komma, 1 Dezimalstelle)
  - Fischart (species-Enum → DE-Anzeige: SPIEGEL→Spiegelkarpfen, LEDER→Lederkarpfen, SCHUPPEN→Schuppenkarpfen, AMUR→Amurkarpfen, ANDERE→Andere)
  - Gewässer (water_name) + Datum (catch_ts → "12. OKT 2025"-Format, DE)
  - Tags: bait + weather->>'weather_text' (falls vorhanden)
  - Foto: photos[0] (falls vorhanden) als Thumbnail
  - Link zu /faenge/[id]
- **FILTER:** Suchfeld (Client-Filter auf water_name/species) + Sortierung (neueste/älteste/schwerste)
- **EMPTY-STATE:** Wenn 0 Fänge → Empty-State-Komponente (Design: fangliste-empty.html): „NOCH KEINE FÄNGE" + Karpfen-Silhouette + „ERSTEN FANG EINTRAGEN"-Button
- **SUCCESS:** Wenn URL-Parameter `?saved=1` → Success-Banner „FANG GESPEICHERT" (Design: fang-success.html, als kompaktes Banner oben)
- Zähler: "N FÄNGE GESAMT" aus echter Anzahl (nicht hartcodiert "72"!)

### 2. web/src/components/CatchCard.astro (NEU)
- Einzelne Fang-Karte (wiederverwendbar)
- Props: catch (Catch-Row)
- Formatierung: gewicht DE-Komma, datum DE-Format, species DE-Mapping
- weather-Tags anzeigen falls vorhanden

### 3. web/src/pages/faenge/[id].astro (KOMPLETT ÜBERSCHREIBEN — kein Mock!)
- Auth-Guard
- Einzelnen Fang laden: `supabase.from('catches').select('*').eq('id', id).eq('deleted_at', null).single()`
- Anzeige (Design: design/screens/catch-detail.html):
  - Foto groß (falls vorhanden)
  - Gewicht prominent (Monospace)
  - Alle Felder: Art, Gewässer, Datum, Länge, Köder, Methode, Notizen, Catch&Release (draft=false = published)
  - Wetter-Snapshot-Karte: weather jsonb (temp_c, pressure_hpa, wind_kmh, weather_text, moon_text, moon_phase) — mit Mond + Luftdruck prominent
  - **WICHTIG: lat/lng/water_name NUR für den Besitzer anzeigen** (RLS macht das automatisch — kein öffentlicher Zugriff)
  - Fehlerzustand: Fang nicht gefunden → „Fang nicht gefunden" + Link zur Liste

### 4. Gewässer-Anzeige
- In Liste + Detail: water_name anzeigen (Freitext aus Fang — Privatgewässer!)
- Kein waters-Join nötig (water_name steht am Fang)

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/catch-list.html, design/screens/fangliste-empty.html, design/screens/fang-success.html, design/screens/catch-detail.html
- VERBOTEN: /etc, andere Projekte, supabase/migrations/, infra/, /tmp, drush, Shell-Schleifen, git-Operationen, Server starten, curl
- KEINE Analyse-Ausflüge. Baue.

## WICHTIG
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- **KEINE Beispieldaten hartcoden!** Die 3 Mock-Fänge (silbersee-spiegelkarpfen etc.) MÜSSEN weg. Daten kommen NUR aus Supabase.
- Auth-Guard auf beiden Seiten (Session nötig)
- Supabase-Client importieren: `import { supabase } from "../lib/supabase-client";`
- Astro: für Client-JS `script is:inline` verwenden
- Design: Carp24 Editorial (Referenz-HTMLs im Projekt!)
- Zahlformat: weight_kg → "18,4" (DE), catch_ts → "12. OKT 2025"

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "from('catches')" /mnt/projekte/carp24-fangbuch/web/src/pages/faenge.astro
grep -c "from('catches')" /mnt/projekte/carp24-fangbuch/web/src/pages/faenge/\[id\].astro
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts
grep -c "NOCH KEINE FÄNGE\|leer\|empty" /mnt/projekte/carp24-fangbuch/web/src/pages/faenge.astro
grep -c "silbersee-spiegelkarpfen" /mnt/projekte/carp24-fangbuch/web/src/pages/faenge.astro
# letzter muss 0 sein (kein Mock!)
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
