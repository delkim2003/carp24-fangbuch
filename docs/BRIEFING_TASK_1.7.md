# Build-Briefing: Task 1.7 — Wetter-Hook (Open-Meteo) (carp24 Phase 1A)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/supabase/functions/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/supabase/functions/gewaesser-search/index.ts (als Stil-Vorlage, Deno.serve-Pattern)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm, docker, Server-Starts
- KEINE Analyse-Ausflüge. Mache genau die 1 Datei unten.
- JEDE Datei KOMPLETT schreiben (keine Diffs, keine Snippets).

## Kontext
- Geodaten liegen am FANG (catches.lat, catches.lng — Primärquelle, seit 20.08.-Korrektur)
- Wetter-Snapshot wird in catches.weather (jsonb) gespeichert
- Open-Meteo Free-API (D-6: non-commercial ok): `https://api.open-meteo.com/v1/forecast`
- Verifiziert (Silbersee 46.609/13.905): `past_days=1` + `hourly=temperature_2m,surface_pressure,wind_speed_10m,weather_code` + `daily=moon_phase` + `timezone=Europe/Vienna` liefert 192 Stunden, inkl. Luftdruck + Mondphase (0-1)
- **Regel: NUR Fänge ≤24h** — bei älteren Fängen KEIN Wetter-Auto, ehrlicher Hinweis (Retro-Wetter wäre bezahlt)

## 🎯 AUFGABE: Edge-Function `wetter-hook`

Erstelle `supabase/functions/wetter-hook/index.ts` (Deno, Deno.serve — WIE gewaesser-search, KEIN serve-Import!):

### Endpoint: POST
Body: `{ "lat": 46.609, "lng": 13.905, "catch_ts": "2026-08-19T18:30:00+02:00" }`

### Logik:
1. **CORS** wie gewaesser-search (OPTIONS → 204)
2. **Validierung:** lat/lng numerisch im Bereich (lat -90..90, lng -180..180), catch_ts vorhanden
3. **≤24h-Check:** `now - catch_ts > 24h` → `{ "weather": null, "reason": "older_than_24h", "message": "Wetter-Auto nur für Fänge der letzten 24h (kostenlose Open-Meteo-API)" }` mit HTTP 200
4. **Open-Meteo-Call:**
   ```
   https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&past_days=1&hourly=temperature_2m,surface_pressure,wind_speed_10m,weather_code&daily=moon_phase&timezone=Europe%2FVienna
   ```
   - Cache: In-Memory Map keyed `lat:lng:stunde` (1h TTL) — gleiche Stunde = gleicher Cache
   - Bei 429: stale Cache ODER `{ "weather": null, "reason": "rate_limited" }`
   - Bei Netzwerk-Fehler: `{ "weather": null, "reason": "unavailable" }`
5. **Wetter-Snapshot extrahieren** für die catch_ts-Stunde (finde den hourly-Index wo time == catch_ts-Stunde; wenn nicht exakt, nimm den nächstliegenden):
   ```json
   {
     "temp_c": 21.1,
     "pressure_hpa": 965.6,
     "wind_kmh": 3.4,
     "weather_code": 1,
     "weather_text": "überwiegend klar",
     "moon_phase": 0.228,
     "moon_text": "zunehmend",
     "measured_at": "2026-08-19T18:00:00"
   }
   ```
6. **Weather-Code → Text Mapping** (WMO):
   - 0: "sonnig", 1: "überwiegend klar", 2: "teils bewölkt", 3: "bedeckt"
   - 45,48: "neblig"
   - 51-57: "Nieselregen", 61-67: "Regen", 71-77: "Schnee", 80-82: "Regenschauer", 85-86: "Schneeschauer"
   - 95-99: "Gewitter"
7. **Mondphase → Text Mapping** (0-1):
   - <0.0625 oder ≥0.9375: "neumond"
   - 0.0625–0.3125: "zunehmend"
   - 0.3125–0.5625: "vollmond" (0.5 = Vollmond-Kern)
   - 0.5625–0.8125: "abnehmend"
   - 0.8125–0.9375: "letztes Viertel" → "abnehmend"
   - WICHTIG: Das sind die EXAKTEN Strings, die das Statistik-Studio als Filter verwendet (neumond/zunehmend/vollmond/abnehmend — wie Mockup 19.08.)
8. **Return:** `{ "weather": { ...snapshot }, "cached": bool }` HTTP 200

### Zusätzlich: GET /forecast (Forecast-Widget-Daten-Endpoint)
- GET mit `?lat=..&lng=..` → nächste 24h Forecast (heute+morgen) mit temp, wind, pressure, weather_code, moon_phase pro Stunde
- `{ "forecast": [ { "time": "...", "temp_c": .., "wind_kmh": .., "pressure_hpa": .., "weather_code": .., "moon_phase": .. } ] }`

## ✅ VERIFIKATION (nur statisch, KEINE Server-Starts)
- `grep -c "api.open-meteo.com" supabase/functions/wetter-hook/index.ts` ≥ 1
- `grep -c "surface_pressure" supabase/functions/wetter-hook/index.ts` ≥ 1
- `grep -c "moon_phase" supabase/functions/wetter-hook/index.ts` ≥ 2
- `grep -c "older_than_24h" supabase/functions/wetter-hook/index.ts` ≥ 1
- `grep -c "Deno.serve" supabase/functions/wetter-hook/index.ts` = 1

## 📝 ABGABE
- Sage „FERTIG" + grep-Beweise + WMO-Mapping-Tabelle (Anzahl Codes).
- KEIN git-Commit, KEINE psql-Ausführung, KEIN Deploy — das macht Hermes.
