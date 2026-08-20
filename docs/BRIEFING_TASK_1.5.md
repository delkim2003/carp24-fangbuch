# Build-Briefing: Task 1.5 — Fang-Backend Seed + Photon-Suche (carp24 Phase 1A)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/supabase/ (migrations/, seed/, functions/), /mnt/projekte/carp24-fangbuch/infra/docker-compose.yml (Kong-Route für Edge-Functions), /mnt/projekte/carp24-fangbuch/.env.example
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm, docker restart, Server-Starts, curl auf externe Systeme ausser photon.komoot.io
- KEINE Analyse-Ausflüge. Mache genau die 3 Deliverables unten.
- KEINE Secrets ausgeben oder committen.
- JEDE Datei KOMPLETT schreiben (keine Diffs, keine Snippets).

## Kontext (Schema-REALITÄT — NICHT das Briefing-Papier!)
- Tabellen existieren bereits aus Phase 0, heissen ENGLISCH:
  - `public.waters` (id uuid gen_random_uuid, name text, lat numeric, lng numeric, type text, public boolean DEFAULT false, owner_id uuid NULL → profiles) — RLS: select_owner_or_public, insert_owner, update_owner
  - `public.catches` (id, user_id NOT NULL → profiles, water_id → waters, catch_ts timestamptz, species species_enum NOT NULL, species_custom text, weight_kg numeric NOT NULL, length_cm, bait, method, notes, photos text[] NOT NULL, weather jsonb, weather_auto bool, draft bool NOT NULL, client_uuid uuid NOT NULL, created_at, updated_at, deleted_at)
  - `species_enum`: SPIEGEL | LEDER | SCHUPPEN | AMUR | ANDERE
  - `publish_catch(uuid)` RPC existiert ✅ (SECURITY DEFINER, Pro-Check, advisory lock)
- imgproxy: IMGPROXY_STRIP_METADATA + ENABLE_WEBP_DETECTION sind konfiguriert ✅ (EXIF-GPS-Strip)
- **FEHLT:** Seed-Daten (waters=0, catches=0) + Edge-Function fuer Photon-Suche (functions/ ist leer)

## 🎯 AUFGABE (3 Deliverables)

### 1. Seed-Gewässer einspielen
Lies `supabase/seed/seed_waters_reference.sql` (25 österreichische Gewässer mit echten Koordinaten). Erstelle daraus eine Migration `supabase/migrations/0002_seed_waters.sql`:
- Komplettes SQL, idempotent (INSERT ... ON CONFLICT DO NOTHING — aber waters hat keinen unique-Constraint auf name; verwende WHERE NOT EXISTS auf name)
- Koordinaten UNVERÄNDERT aus der Referenz übernehmen (nie erfinden!)
- KEINE user_id setzen (owner_id NULL = öffentlich)

### 2. Seed-Fänge (18) für Statistik-Studio
Erstelle `supabase/migrations/0003_seed_catches.sql`:
- VORAB-Hinweis im SQL: „User wird via API erstellt (Task 1.4-Test-User), dann per Script eingefügt" — schreibe ein SQL-Script das den NEUESTEN User aus auth.users nimmt:
  ```sql
  INSERT INTO public.catches (user_id, water_id, catch_ts, species, weight_kg, length_cm, bait, method, notes, photos, weather, weather_auto, draft, client_uuid)
  SELECT u.id, w.id, ts, sp::public.species_enum, gew, laen, koeder, methode, notiz, ARRAY[]::text[], NULL, false, false, gen_random_uuid()
  FROM (VALUES
    ('2025-10-12T18:30:00+02:00'::timestamptz, 'SPIEGEL', 18.4, 92, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
    ... 18 Zeilen ...
  ) AS v(ts, sp, gew, laen, koeder, methode, gewaesser)
  JOIN auth.users u ON u.id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
  JOIN public.waters w ON w.name = v.gewaesser;
  ```
- Beispieldaten (18, realistisch, DEUTSCHE KOMMA-freie Zahlen mit Punkt):
  1. 2025-03-12 16:45 SPIEGEL 13.5 84 Boilie Grundmontage Silbersee Villach
  2. 2025-04-05 18:00 SPIEGEL 15.3 88 Boilie Grundmontage Silbersee Villach
  3. 2025-06-07 21:00 SPIEGEL 19.4 97 Boilie Grundmontage Silbersee Villach
  4. 2025-07-19 05:45 SPIEGEL 18.7 94 Pop-Up Grundmontage Silbersee Villach
  5. 2025-08-04 23:00 SCHUPPEN 20.9 101 Boilie Grundmontage Silbersee Villach
  6. 2025-09-09 18:20 SPIEGEL 21.4 102 Boilie Grundmontage Silbersee Villach
  7. 2025-10-12 18:30 SPIEGEL 18.4 92 Boilie Grundmontage Silbersee Villach
  8. 2025-05-16 07:10 LEDER 16.8 90 Boilie Grundmontage Neusiedler See
  9. 2025-05-24 22:40 SPIEGEL 22.1 105 Boilie Grundmontage Neusiedler See
  10. 2025-06-15 04:55 SCHUPPEN 14.2 86 Pop-Up Grundmontage Neusiedler See
  11. 2025-08-22 19:30 SPIEGEL 17.9 96 Boilie Grundmontage Neusiedler See
  12. 2025-04-18 15:20 AMUR 12.8 80 Boilie Grundmontage Wörthersee
  13. 2025-06-28 06:45 SPIEGEL 23.5 108 Boilie Grundmontage Wörthersee
  14. 2025-07-30 20:15 SPIEGEL 16.4 91 Boilie Grundmontage Wörthersee
  15. 2025-09-01 05:30 SCHUPPEN 15.7 88 Boilie Grundmontage Faaker See
  16. 2025-03-28 17:45 SPIEGEL 11.9 78 Boilie Grundmontage Ossiacher See
  17. 2025-06-05 22:10 LEDER 13.6 82 Boilie Grundmontage Ossiacher See
  18. 2025-10-05 18:00 SPIEGEL 19.8 99 Boilie Grundmontage Traunsee

### 3. Edge-Function: Photon-Gewässer-Suche
Erstelle `supabase/functions/gewaesser-search/index.ts` (Deno/TypeScript):
- POST/GET mit JSON: `{ "q": "Silbersee", "limit": 5 }`
- Ruft Photon auf: `https://photon.komoot.io/api/?q=<query>&lang=de&limit=<limit>`
- Filtert NUR `osm_value IN ('water','lake','river')` bzw. properties.osm_value — wir suchen Gewässer
- Gibt zurück: `{ results: [{ name, lat, lng, type }] }` — Koordinaten aus geometry.coordinates [lng, lat]
- **Cache:** In-Memory Map mit 1h TTL (keyed auf query) — keine DB nötig
- **Rate-Limit-Fallback:** Bei 429 von Photon → letzte Cache-Antwort ODER leeres Array mit Hinweis `"rate_limited": true`
- Error-Handling: Photon down → `{ results: [], error: "geocoding_unavailable" }`
- CORS-Header (Access-Control-Allow-Origin: *)
- Verwendung von `serve` aus `https://deno.land/std@0.177.0/http/server.ts` (Supabase-Edge-Runtime-Standard)

## ✅ VERIFIKATION (nur statisch, KEINE Server-Starts)
- `ls supabase/functions/gewaesser-search/index.ts` existiert
- `grep -c "photon.komoot.io" supabase/functions/gewaesser-search/index.ts` ≥ 1
- `grep -c "osm_value" supabase/functions/gewaesser-search/index.ts` ≥ 1
- `grep -c "INSERT INTO public.waters" supabase/migrations/0002_seed_waters.sql` = 1
- `grep -c "INSERT INTO public.catches" supabase/migrations/0003_seed_catches.sql` = 1

## 📝 ABGABE
- Sage „FERTIG" + grep-Beweise + Liste der erstellten Dateien.
- KEIN git-Commit — das macht Hermes.
