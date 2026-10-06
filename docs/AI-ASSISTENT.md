# KI-Assistent (Angel-App)

Zwei SSR-Endpoints unter `web/src/pages/api/ai/`, beide authentifiziert (Login nötig), **nur Pro-Mitglieder** (Admin/MODERATOR bypass + unbegrenzt). Nicht-Pro → 403 mit Hinweis auf `/premium`.

## `/api/ai/chat` — Daten-Chat

Beantwortet Fragen zu den **eigenen Fangdaten** („Wie war meine Bilanz?", „Wann soll ich angeln gehen?").

- **Kontext:** letzte 50 Fänge, vollständig gemappt (Datum, kg, Art, Gewässer, Köder, Methode, Notiz + Wetter-JSON: Wettertext, °C, hPa, Wind km/h, Mond) + **3-Tage-Wetter-Ausblick** für den Ort des letzten Fangs (Open-Meteo, `forecast_days=3`).
- **Prompt-Regeln:** ausschließlich Datenbasis, nichts erfinden („Wenn Daten fehlen: keine Daten vor."), keine Preise/Rabatte, Wetterfragen mit Wetterdaten + Ausblick beantworten, Antworten als kurze **SCHLAGWORT:-Zeilen** (max 7 × 90 Zeichen, KEIN Markdown).
- **Limits:** 50 Anfragen/Monat (Zähler `ai_usage`), Rate-Limit 5 s/User.
- **Modell-Rotation:** `mistralai/mistral-small-2603` → `mistralai/mistral-small-3.2-24b-instruct` → `mistralai/mistral-nemo`, 3 Versuche, 404 → nächstes Modell, 429 → Backoff, Abort nach 30 s → 504.

## `/api/ai/analyze` — Buttons „Beste Bedingungen" + „3-Tage-Fangprognose"

Zwei Modi (`mode: "best-conditions" | "forecast"`):

- **best-conditions:** Auswertung aller Fänge (bis 500): häufigste/beste Mondphase, Wetter, Luftdruck-, Temperatur-, Windbereich. Ohne Wetterdaten: ehrlicher Fallback-Text („N Fänge, keine mit Wetterdaten").
- **forecast:** Standort (Ortsuche via Open-Meteo Geocoding) + 3-Tage-Vorhersage (Temp min/max, Niederschlag, Wettercode, Wind, Mondphase pro Tag) + Abgleich mit den historischen Bestwerten.
- Antwort + **Confidence-Bubble** („Basierend auf X Fängen mit Wetterdaten (Y gesamt)").

## Wetter-Integration (Open-Meteo, DSGVO-frei)

| Zweck | API | Notiz |
|-------|-----|-------|
| Wetter-Snapshot beim Fang (≤24 h alt) | `api.open-meteo.com/v1/forecast` (`current`) | Feldnamen der Antwort: `windspeed_10m_max`, `weathercode` (alte Schreibweise!) |
| 3-Tage-Ausblick / Prognose | `/v1/forecast` (`daily`, `forecast_days=3`) | Auch Mondphase (`moon_phase`) |
| Ortsuche (Buttons) | `geocoding-api.open-meteo.com` | Kommt im Frontend (Autovervollständigung) |
| Historisches Wetter für alte Fänge | `/v1/archive` | vorgesehen als Backfill (ERA5 ab 1940) |

## Technische Regeln

- **`process.env` statt `import.meta.env`** für alle Laufzeit-Secrets (`OPENROUTER_API_KEY`) — `import.meta.env` wird zur Build-Zeit ersetzt (Docker = immer undefined!). Fallback: `app_settings.openrouter_key`.
- **Temperatur 0.2** bei allen LLM-Calls (Fakten-Antworten, keine Kreativität).
- **Zahlenformat:** absolute Zahlen ganzzahlig, nur Gewicht mit Dezimal-Komma.
- **Datenschutz:** Prompts enthalten nur eigene Fangdaten + Wetterwerte; DSGVO: transiente Verarbeitung, kein Logging der Inhalte.

## Frontend

`web/src/pages/assistent.astro` — Chat mit Vorschlags-Buttons, Nutzungszähler, Confidence-Bubble; Antwort-Bubbles mit `white-space: pre-wrap` + `line-height: 1.6` (Format-Regel des Prompts erzeugt Schlagwort-Zeilen).
