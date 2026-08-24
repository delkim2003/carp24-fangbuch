# PLAN STATISTIK-STUDIO v2 (Backend + Frontend)

**Stand:** 24.08.2026 | **Status:** v2 — wartet auf Experten-Audit Runde 2 (Runde 1 lief gegen v1)
**Ziel (Philipp-Vision):** Nutzer baut sich Statistiken selbst: Zeitraum (von–bis), frei kombinierbare Bedingungen, Wetterdaten als Kern. Das System erkennt automatisch, welche Zeiten bei welchem Wetter ideal sind („aussagekräftige Statistik").
**v2-Änderung (24.08.):** **Wassertemperatur als User-Eingabe-Feld** (extrem wichtig fürs Studio) — neues Feld im Fang erfassen, Anzeige im Fang-Detail, eigene Dimension im Statistik-Studio. Abgrenzung: Lufttemperatur (`temp_c`) kommt automatisch von Open-Meteo; **Wassertemperatur (`water_temp_c`) ist eine manuelle Angabe des Users** (optional, wird am Wasser gemessen).

---

## 1. IST-Zustand (verifiziert)

| Datei | Inhalt |
|---|---|
| `supabase/migrations/0009_stats_bedingungs_api.sql` | 3 RPCs: `stats_conditions(p_filters jsonb)`, `stats_drilldown(p_filters jsonb)`, `stats_beste_kombis(p_filters jsonb, p_limit int)`. Alle SECURITY DEFINER, `search_path=''`, `auth.uid()`-Check, statisches SQL (Injection-Fix 20.08.) |
| Filter (in allen 3 RPCs identisch dupliziert) | `mond`, `druck_bucket` (<1005 / 1005-1015 / >=1015), `wind_bucket` (<5 / 5-10 / 10-20 / 20+), `wetter` (ILIKE), `gewaesser` (ILIKE), `art` (species/species_custom), `koeder` (ILIKE), `monat` (1-12), `uhrzeit_bucket` (0-6/6-12/12-18/18-24), `jahr`, **`zeitraum` {von, bis} — existiert bereits** |
| `stats_conditions`-Output | `total` {fangzahl, avg_gewicht, max_gewicht, sum_gewicht} + `buckets` {mond, druck, wind, wetter, gewaesser, uhrzeit, monat, art, koeder} — **ohne Temperatur-Dimensionen** |
| `stats_beste_kombis` | Nur 6 feste 2er-Kombis: mond+druck, mond+wetter, mond+koeder, druck+wetter, druck+koeder, wetter+koeder. HAVING count >= 2. **Ohne Uhrzeit/Wind/Temperatur** |
| `supabase/migrations/0001_init.sql` | `catches`: `weather jsonb` (temp_c, pressure_hpa, wind_kmh, weather_text, moon_text), `catch_ts timestamptz`, `species`, `species_custom`, `water_name`, `bait`, `weight_kg`, `length_cm`, `draft`, `deleted_at`. Indizes: `(user_id, catch_ts DESC)`, `(user_id, draft, deleted_at)`. **Kein water_temp_c-Feld** |
| `web/src/pages/statistik.astro` | Nutzt die 3 RPCs. **Keine Zeitraum-UI, keine Temperatur-Dimensionen, keine Insights-Karten.** Chips für WIND/WETTER etc. teils eingeklappt |
| `web/src/pages/fang-erfassen.astro` | Formular mit Gewicht/Länge/Fischart/Datum/Uhrzeit/Köder/Methode/Gewässer/GPS/Foto/Notizen/C&R/Öffentlich/Trip. **Kein Wassertemperatur-Feld** |
| `web/src/pages/faenge/[id].astro` | Fang-Detail mit WETTER-SNAPSHOT (TEMPERATUR/LUFTDRUCK/WIND/MOND aus weather-jsonb). **Keine Wassertemperatur-Anzeige** |
| `tests/pgtap/0001_rls_tests.sql` | pgTAP-Basis vorhanden |

## 2. Lücken (aus Philipps Vision abgeleitet)

1. **Wassertemperatur als User-Eingabe** — NEU: Feld `water_temp_c` in Fang erfassen (optional), Speicherung auf catches, Anzeige im Fang-Detail.
2. **Wassertemperatur als Studio-Dimension** — Filter-Bucket + Aggregation + Insight „beste Wassertemperatur".
3. **Lufttemperatur als Dimension** (optional, automatisch via Open-Meteo `temp_c`).
4. **Wetter-Insights** („welche Zeiten bei welchem Wetter ideal") — neue Auswertung: Uhrzeit × Wetterlage × Temperatur → Top-Muster mit Fangzahl, Ø Gewicht UND Kontext (Abweichung vom Gesamt-Ø im gewählten Zeitraum).
5. **Zeitraum-UI** — Backend-Filter existiert, Frontend hat keine VON/BIS-Eingabe.
6. **Kombi-Erweiterung** — `stats_beste_kombis` soll auch Uhrzeit/Wind/Temperatur-Kombinationen finden.
7. **Code-Duplikation** — Filter-Logik 3× kopiert; jede Änderung (z.B. neuer Bucket) muss an 3+ Stellen.

## 3. Geplante Änderungen

### Backend (neue Migration `0032_stats_v2.sql`)

**B.0 Wassertemperatur-Feld**
`ALTER TABLE public.catches ADD COLUMN water_temp_c numeric;` (nullable, optional, keine CHECK-Beschränkung nötig — Client validiert 0-40). Kein Backfill: alte Fänge haben NULL → Bucket `Unbekannt`.

**B.1 Bucket-Helper (2 neue, IMMUTABLE, analog `_to_bucket_druck`)**
- `public._to_bucket_lufttemp(p_val numeric) → text`: `<5`, `5-10`, `10-15`, `15-20`, `>=20`, NULL → `Unbekannt`.
- `public._to_bucket_wassertemp(p_val numeric) → text` (Karpfen-relevante Gewässertemperaturen): `<10`, `10-15`, `15-20`, `20-25`, `>=25`, NULL → `Unbekannt`.

**B.2 Filter-Logik erweitern (in allen 3 RPCs + neue Insights-Funktion)**
- Neuer Filter `lufttemp_bucket`: `_to_bucket_lufttemp((weather->>'temp_c')::numeric)` = Wert.
- Neuer Filter `wasser_temp_bucket`: `_to_bucket_wassertemp(c.water_temp_c)` = Wert.
- `zeitraum` bleibt wie ist (von-Tag 00:00:00Z bis bis-Tag 23:59:59Z).

**B.3 `stats_conditions` um beide Temperatur-Dimensionen erweitern**
- `bucket_rows`: neue Spalten `lufttemp` und `wassertemp` via Helper.
- `lufttemp_agg`, `wassertemp_agg`: `jsonb_object_agg` wie die anderen Dimensionen.
- Output `buckets` + `lufttemp` + `wassertemp`.

**B.4 Neue Funktion `stats_insights(p_filters jsonb) → jsonb`**
Automatische Muster-Erkennung über die gefilterte Menge (statische Aggregation, KEIN ML):
- `beste_fangzeit`: Uhrzeit-Bucket mit höchstem Ø-Gewicht (min. 2 Fänge) + Kontext {fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct}.
- `beste_wetterlage`: Wetterlage (`weather_text`) mit höchstem Ø-Gewicht + Kontext.
- `beste_wassertemperatur`: Wassertemperatur-Bucket mit höchstem Ø-Gewicht + Kontext (Philipp: „extrem wichtig fürs Studio").
- `beste_lufttemperatur`: Lufttemperatur-Bucket mit höchstem Ø-Gewicht + Kontext (optional, nur wenn Daten vorhanden).
- Kontext: `avg_gesamt` = Ø Gewicht der gesamten gefilterten Menge; `differenz_pct` = (bucket_avg - avg_gesamt) / avg_gesamt * 100 (gerundet, nur wenn avg_gesamt > 0).
- Mindest-Fangzahl pro Insight: 2 (sonst `null` + `hinweis`-Text, z.B. „Zu wenige Fänge für belastbare Aussage").

**B.5 `stats_beste_kombis` erweitern**
Zusätzliche 2er-Kombis aufnehmen: uhrzeit+wetter, uhrzeit+wassertemp, wetter+wassertemp, wetter+lufttemp, wind+wetter, wind+wassertemp, wassertemp+lufttemp (fest verdrahtet, statisch, keine SQL-Injection). Optional 3er-Kombi uhrzeit+wetter+wassertemp. Reihenfolge weiter nach avg_gewicht DESC, HAVING >= 2.

**B.6 Indizes (Performance)**
Prüfen + ergänzen: `catches(user_id, catch_ts)` existiert. Für Wasser-Temp-Filter reicht der bestehende Index (Filter auf user_id + bucket-Cast pro Zeile; bei kleinen Datenmengen kein eigener Index nötig). Nur wenn Query-Plan es zeigt: Expression-Index auf `(user_id, water_temp_c)` — nicht voreilig.

### Frontend

**F.1 Fang erfassen (`web/src/pages/fang-erfassen.astro`)**
Neues optionales Feld **WASSERTEMPERATUR (°C)** — Platzhalter z.B. `18.5`, input type number (step 0.1, min 0, max 40), im Formular bei den Fangdaten (linke Spalte, unter LÄNGE oder als eigene Zeile vor FISCHART). Wird als `water_temp_c` gespeichert. Hinweis-Text: „Wassertemperatur am Gewässer (optional)".

**F.2 Fang-Detail (`web/src/pages/faenge/[id].astro`)**
Im WETTER-SNAPSHOT zusätzliche Zeile **WASSERTEMPERATUR** (`water_temp_c` + „ °C", sonst „—"). Eigener Block, deutlich getrennt von der automatischen Lufttemperatur.

**F.3 Statistik (`web/src/pages/statistik.astro`)**
- **Zeitraum-Leiste**: zwei Datumsfelder VON / BIS (Default: letzte 12 Monate) + Button ANWENDEN + ZURÜCKSETZEN setzt auch Zeitraum zurück. `buildFilters()` um `zeitraum: {von, bis}` erweitern.
- **Wassertemperatur-Dimension**: Filterzeile WASSERTEMP mit 5 Buckets (<10 / 10-15 / 15-20 / 20-25 / >=25, Chips mit Fangzahl).
- **Lufttemperatur-Dimension**: Filterzeile LUFTTEMP (5 Buckets) — optional, wenn Daten vorhanden.
- **Wetter-Insights-Karten**: 4 Karten (BESTE FANGZEIT / BESTE WETTERLAGE / BESTE WASSERTEMPERATUR / BESTE LUFTTEMPERATUR) mit Wert, Subzeile, Badge (Fänge, Ø) + Kontext (z.B. „+24% über Schnitt"). Daten aus `stats_insights`.
- Alle Dimensionen offen anzeigen (keine Einklapp-Funktion).

### Tests

**T.1 pgTAP (`tests/pgtap/0002_stats_v2_tests.sql`)**
- `_to_bucket_wassertemp` / `_to_bucket_lufttemp`: Grenzwerte (9.9 → <10, 10 → 10-15, 24.9 → 20-25, 25 → >=25, NULL → Unbekannt; analog lufttemp).
- `stats_conditions` mit `wasser_temp_bucket`-Filter: nur passende Fänge; `buckets->wassertemp` enthält alle Buckets mit korrekten Fangzahlen.
- `stats_insights`: mit Seed-Daten — beste_fangzeit/beste_wetterlage/beste_wassertemperatur korrekt + Kontext (differenz_pct Vorzeichen); Mindest-Fangzahl-Regel (1 Fang → null + Hinweis); NULL-Wassertemperatur-Fänge fließen in `Unbekannt`, nicht in Insights.
- `stats_beste_kombis` mit wassertemp/uhrzeit-Kombis: Ergebnis enthält neue Kombinationen; HAVING >= 2 respektiert.
- Zeitraum-Filter: Fänge außerhalb von/bis werden ausgeschlossen (Grenz-Tag inklusive).

**T.2 Frontend-Verifikation (Playwright/curl)**
- Fang erfassen: Wassertemperatur-Feld sichtbar, speichert `water_temp_c` (E2E: Feld befüllen → Fang anlegen → DB prüfen).
- Fang-Detail: Wassertemperatur-Zeile sichtbar (mit Wert und bei fehlendem Wert „—").
- statistik.astro lädt mit Default-Zeitraum ohne Fehler; Chip-Klick + ANWENDEN triggern RPCs; Insights-Karten zeigen Daten oder Hinweis.

## 4. Offene Design-Entscheidungen (für Audit)

- **D1: DRY-Refactor** — Filter-Logik in gemeinsame Helper-Funktion ziehen (z.B. `_stats_filtered(p_filters jsonb) RETURNS SETOF catches` SECURITY DEFINER) vs. pragmatische Duplizierung beibehalten. Empfehlung: DRY-Helper, sorgfältig mit search_path + Grants.
- **D2: Insight-Mindestmenge** — ab wie vielen Fängen ist ein Insight „belastbar"? Vorschlag: >= 2 (analog kombis). Alternativ >= 3.
- **D3: Kombi-Tiefe** — nur 2er-Kombis oder auch 3er (uhrzeit+wetter+wassertemp)? 3er erzeugt mehr Zeilen, aber dünnere Daten.
- **D4: Bucket-Grenzen Wassertemperatur** — <10 / 10-15 / 15-20 / 20-25 / >=25 sinnvoll? (Karpfen: Aktivität steigt ab ~15°, Laich ~18-22°.) Alternative: <12 / 12-16 / 16-20 / 20-24 / >=24.
- **D5: Wassertemperatur als Spalte vs. in weather-jsonb** — Empfehlung: eigene Spalte `water_temp_c` (wie weight_kg/length_cm, User-Eingabe; einfacher zu filtern/indizieren als jsonb-Cast). Widerspruch aus dem Audit willkommen.

## 5. Akzeptanzkriterien

- [ ] `catches.water_temp_c` existiert; Fang erfassen speichert und Fang-Detail zeigt den Wert (bzw. „—" bei fehlendem Wert).
- [ ] `stats_conditions` liefert `buckets.wassertemp` (5 Buckets) + `buckets.lufttemp`; beide Filter wirken UND-korrekt.
- [ ] `stats_insights` liefert Insights inkl. `beste_wassertemperatur` mit Kontext (differenz_pct) bzw. Hinweis bei zu wenigen Fängen.
- [ ] `stats_beste_kombis` findet auch Wasser-Temp-/Uhrzeit-Kombis.
- [ ] Zeitraum-Filter (von/bis) greift in allen 4 Funktionen identisch.
- [ ] Alle Funktionen weiterhin SECURITY DEFINER + `auth.uid()` + keine SQL-Injection (nur statisches SQL / `format('%L')`).
- [ ] `statistik.astro`: Zeitraum-Leiste + Wassertemperatur-Dimension + 4 Insight-Karten sichtbar; alle Dimensionen offen.
- [ ] pgTAP-Tests grün (T.1); Frontend-Verifikation bestanden (T.2).

## 6. Nicht-Ziele (v1)

- Kein ML/Modell — reine statistische Aggregation.
- Keine Änderung am automatischen Wetter-Snapshot (Open-Meteo bleibt unangetastet).
- Kein CSV-Export (existiert in profil.astro; bleibt).
- Keine Mobile-Variante in v1 (Desktop-first wie bisher).

## 7. Build-Reihenfolge (nach Audit-Freigabe)

1. Migration `0032_stats_v2.sql` (B.0 → B.1 → B.2 → B.3 → B.4 → B.5 → B.6) via Projektkonvention (supabase db push / docker exec psql).
2. pgTAP-Tests `0002_stats_v2_tests.sql` ausführen (rot → grün).
3. Frontend: Fang erfassen (F.1) → Fang-Detail (F.2) → statistik.astro (F.3).
4. E2E-Verifikation (T.2) + Live-Check auf :4321 (Dev-Server, nicht Production-SSR killen).
5. Commit + RESUME-Update.
