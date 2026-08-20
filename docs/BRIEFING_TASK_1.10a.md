# Build-Briefing: Task 1.10a — Bedingungs-Aggregations-API (carp24 Phase 1A)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/supabase/migrations/ (0001-0008 als Schema-Referenz)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm, docker, Server-Starts, curl
- KEINE Analyse-Ausflüge. Mache genau das 1 Deliverable unten.
- JEDE Datei KOMPLETT schreiben (keine Diffs, keine Snippets).

## Kontext (Schema-REALITÄT)
- `public.catches`: id, user_id, water_id, water_name, lat, lng, catch_ts timestamptz, species species_enum (SPIEGEL/LEDER/SCHUPPEN/AMUR/ANDERE), species_custom, weight_kg numeric, length_cm, bait, method, notes, photos, **weather jsonb** (Struktur: temp_c, pressure_hpa, wind_kmh, weather_code, weather_text, moon_phase, moon_text, measured_at), weather_auto, draft, client_uuid, deleted_at, created_at, updated_at
- **Philipp-Anforderung (20.08.): „muss in allen Kombinationen gehen"** — KEIN starres Pivot!
- Statistik-Studio-Frontend (1.10b) baut auf DIESER API auf — Kontrakte müssen stimmen
- Seed-Daten: 18 Fänge mit weather (Mondphasen: neumond/zunehmend/vollmond/abnehmend; Luftdruck: <1005/1005-1015/1015+)

## 🎯 AUFGABE: Eine Migration `supabase/migrations/0009_stats_bedingungs_api.sql`

### Funktion 1: `stats_conditions(p_filters jsonb DEFAULT '{}'::jsonb)` — Statistik-Buckets
- Auth: `auth.uid() IS NOT NULL` sonst RAISE 'not authenticated'
- **p_filters = beliebige Kombination von Bedingungen (UND-Logik):**
  ```json
  {
    "mond": "neumond",
    "druck_bucket": "1005-1015",
    "wind_bucket": "5-10",
    "wetter": "Regen",
    "wassertemp_bucket": "15-20",
    "gewaesser": "Silbersee Villach",
    "art": "SPIEGEL",
    "koeder": "Boilie",
    "monat": 6,
    "uhrzeit_bucket": "18-24",
    "jahr": 2025
  }
  ```
- **Filter-Logik (alle optional, UND):**
  - mond: exakt auf weather->>'moon_text'
  - druck_bucket: aus weather->>'pressure_hpa' → '<1005' | '1005-1015' | '1015+'  (1005 = in 1005-1015; 1015 = in 1015+)
  - wind_bucket: aus weather->>'wind_kmh' → '<5' | '5-10' | '10-20' | '20+'
  - wetter: weather->>'weather_text' ILIKE %wert%
  - wassertemp_bucket: NICHT möglich (Wassertemperatur wird manuell eingegeben — Feld fehlt! → ignoriere unbekannte Filter KEINE Exception)
  - gewaesser: water_name ILIKE %wert% (auch privat!)
  - art: species = wert ODER species_custom ILIKE
  - koeder: bait ILIKE %wert%
  - monat: EXTRACT(MONTH FROM catch_ts) = wert
  - uhrzeit_bucket: EXTRACT(HOUR FROM catch_ts) → '0-6' | '6-12' | '12-18' | '18-24'
  - jahr: EXTRACT(YEAR FROM catch_ts) = wert
  - zeitraum: { "von": "2025-01-01", "bis": "2025-12-31" } (Datum-ISO)
- **Grundmenge:** user_id = auth.uid() AND deleted_at IS NULL AND draft = false
- **Output (ein JSON-Objekt):**
  ```json
  {
    "total": { "fangzahl": 3, "avg_gewicht": 18.2, "max_gewicht": 21.4, "sum_gewicht": 54.6 },
    "buckets": {
      "mond": { "neumond": {"fangzahl":2,"avg_gewicht":15.1}, "vollmond": {...} },
      "druck": { "1005-1015": {...}, "1015+": {...} },
      "wind": {...}, "wetter": {...}, "gewaesser": {...},
      "uhrzeit": {...}, "monat": {...}, "art": {...}, "koeder": {...}
    }
  }
  ```
  → Jede Dimension hat ihre eigene Bucket-Verteilung ÜBER die gefilterte Grundmenge. Nur Buckets mit fangzahl>0 ausgeben.
- Runden: avg_gewicht auf 1 Dezimalstelle, sum auf 1, max auf 1

### Funktion 2: `stats_drilldown(p_filters jsonb DEFAULT '{}'::jsonb)` — konkrete Fangliste
- Gleiche Filter-Logik wie stats_conditions (GLEICHE Funktion nutzen für Konsistenz!)
- Output: `RETURNS TABLE(id uuid, catch_ts timestamptz, water_name text, species text, weight_kg numeric, length_cm numeric, bait text, weather jsonb)` — die Fänge die ALLE Filter erfüllen
- ORDER BY catch_ts DESC

### Funktion 3: `stats_beste_kombis(p_filters jsonb DEFAULT '{}'::jsonb, p_limit integer DEFAULT 5)` — Korrelations-Sicht
- Gleiche Basis + Filter
- Findet die besten 2-Filter-Kombinationen (mond+druck, mond+wetter, mond+koeder, druck+wetter, druck+koeder, wetter+koeder) nach avg_gewicht
- Output: `RETURNS TABLE(kombi text, fangzahl integer, avg_gewicht numeric)` — kombi = "mond=neumond + druck=1005-1015"
- Nur Kombis mit fangzahl >= 2 (statistisch minimal sinnvoll)
- ORDER BY avg_gewicht DESC LIMIT p_limit

## ✅ VERIFIKATION (nur statisch, KEINE Server-Starts)
- `grep -c "stats_conditions" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 2
- `grep -c "stats_drilldown" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 2
- `grep -c "stats_beste_kombis" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 2
- `grep -c "moon_text" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 1
- `grep -c "pressure_hpa" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 1
- `grep -c "deleted_at IS NULL" supabase/migrations/0009_stats_bedingungs_api.sql` ≥ 1

## 📝 ABGABE
- Sage „FERTIG" + grep-Beweise + Funktions-Signaturen.
- KEIN git-Commit, KEINE psql-Ausführung — das macht Hermes (Migration separat anwenden + live testen).
