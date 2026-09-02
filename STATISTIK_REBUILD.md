# Statistik-Studio Rebuild — Plan

> Stitch-Screen: `e4451b211c5b49b0a84c968b8b85e9bd` (FINAL)
> Design-System: Carp24 Editorial (`assets/9ae0bc7fe13b44e49da8fbee7c9a32be`)
> Stitch-Projekt: `18051329713568778931`

## Phase 1: Supabase RPCs (Backend)

Neue RPCs die fehlen:

### 1.1 `stats_gewichtsverlauf(p_user_id UUID)`
- Gibt Monat + Ø Gewicht + Max Gewicht zurück (letzte 12 Monate)
- Quelle: catches WHERE user_id = p_user_id AND catch_ts >= now() - interval '12 months'
- Output: `TABLE(month TEXT, avg_weight NUMERIC, max_weight NUMERIC, catch_count INT)`

### 1.2 `stats_trips(p_user_id UUID)`
- Gibt Trip-Statistiken zurück
- Quelle: trips + catches (JOIN über trip_id)
- Output: `TABLE(trip_count INT, avg_weight_per_trip NUMERIC, best_water TEXT, trip_details JSONB)`
- trip_details: Array von {name, water, catch_count, avg_weight}

### 1.3 `stats_badges(p_user_id UUID)`
- Gibt Badge-Status zurück
- Quelle: badges (alle) + user_badges (erreichte)
- Output: `TABLE(total_badges INT, earned_badges INT, badge_list JSONB)`
- badge_list: Array von {name, description, icon, earned BOOLEAN, earned_at}

### 1.4 `stats_wetter_korrelation(p_user_id UUID)`
- Gibt Fänge nach Wettertyp zurück
- Quelle: catches.weather->>'weather_text'
- Output: `TABLE(weather_type TEXT, catch_count INT, avg_weight NUMERIC)`

### 1.5 `stats_filter(p_user_id UUID, p_filters JSONB)`
- Universeller Filter: akzeptiert JSON mit allen Filter-Parametern
- Gibt gefilterte KPIs + Chart-Daten zurück
- p_filters: {zeitraum_von, zeitraum_bis, gewaesser[], koeder[], mondphase[], wettertyp[], luftdruck_range, temperatur_range, gewicht_range, methode[], wassertemp_range, art[]}
- Output: `TABLE(total_catches INT, heaviest NUMERIC, avg_weight NUMERIC, active_waters INT, chart_data JSONB)`

## Phase 2: Frontend (Astro)

### 2.1 uPlot installieren
- `npm install uplot` (45KB, 0 deps)
- CSS-Variablen für Dark Mode vorbereiten

### 2.2 statistik.astro komplett neu bauen
- 75/25 Layout (Content/Sidebar)
- Filter-Sidebar mit 9 Filtergruppen (Experten-Logik)
- KPIs (4 Cards)
- Charts (Gewässer, Mondphasen, Fischverteilung, Monate)
- Köder-Kombinationen
- Gewichtsverlauf (uPlot Line Chart)
- Trip-Statistiken
- KI-Analyse (stats_insights RPC)
- Badge-Fortschritt
- Wetter-Korrelation
- Fangdetails-Tabelle

### 2.3 Filter-Logik
- Client-seitig: Filter-State → Supabase RPC-Aufruf → Charts aktualisieren
- Immer sichtbar: Zeitraum, Gewässer, Köder
- Einklappbar: Mondphase, Wetter, Gewicht, Methode, Wassertemp, Fischart

## Phase 3: QA
- Minerva verifiziert: Alle RPCs liefern Daten
- Vision-QA: Screen vs. Stitch vergleichen
- Mobile-Check: Accordion-Filter, responsive Charts

## Reihenfolge
1. RPCs bauen (sequenziell, MiMo)
2. Frontend bauen (GLM 5.2 oder V4 Flash)
3. QA (Minerva)
