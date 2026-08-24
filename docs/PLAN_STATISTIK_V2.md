# PLAN STATISTIK-STUDIO v2 (Backend + Frontend)

**Stand:** 24.08.2026 | **Status:** v1 — wartet auf Experten-Audit Runde 1
**Ziel (Philipp-Vision):** Nutzer baut sich Statistiken selbst: Zeitraum (von–bis), frei kombinierbare Bedingungen, Wetterdaten als Kern. Das System erkennt automatisch, welche Zeiten bei welchem Wetter ideal sind („aussagekräftige Statistik").

---

## 1. IST-Zustand (verifiziert)

| Datei | Inhalt |
|---|---|
| `supabase/migrations/0009_stats_bedingungs_api.sql` | 3 RPCs: `stats_conditions(p_filters jsonb)`, `stats_drilldown(p_filters jsonb)`, `stats_beste_kombis(p_filters jsonb, p_limit int)`. Alle SECURITY DEFINER, `search_path=''`, `auth.uid()`-Check, statisches SQL (Injection-Fix 20.08.) |
| Filter (in allen 3 RPCs identisch dupliziert) | `mond`, `druck_bucket` (<1005 / 1005-1015 / >=1015), `wind_bucket` (<5 / 5-10 / 10-20 / 20+), `wetter` (ILIKE), `gewaesser` (ILIKE), `art` (species/species_custom), `koeder` (ILIKE), `monat` (1-12), `uhrzeit_bucket` (0-6/6-12/12-18/18-24), `jahr`, **`zeitraum` {von, bis} — existiert bereits** |
| `stats_conditions`-Output | `total` {fangzahl, avg_gewicht, max_gewicht, sum_gewicht} + `buckets` {mond, druck, wind, wetter, gewaesser, uhrzeit, monat, art, koeder} — **ohne Temperatur** |
| `stats_beste_kombis` | Nur 6 feste 2er-Kombis: mond+druck, mond+wetter, mond+koeder, druck+wetter, druck+koeder, wetter+koeder. HAVING count >= 2. **Ohne Uhrzeit/Wind/Temperatur** |
| `supabase/migrations/0001_init.sql` | `catches`: `weather jsonb` (temp_c, pressure_hpa, wind_kmh, weather_text, moon_text), `catch_ts timestamptz`, `species`, `species_custom`, `water_name`, `bait`, `draft`, `deleted_at`. Indizes: `(user_id, catch_ts DESC)`, `(user_id, draft, deleted_at)` |
| `web/src/pages/statistik.astro` | Nutzt die 3 RPCs. **Keine Zeitraum-UI, keine Temperatur-Dimension, keine Insights-Karten.** Chips für WIND/WETTER etc. teils eingeklappt |
| `tests/pgtap/0001_rls_tests.sql` | pgTAP-Basis vorhanden |

## 2. Lücken (aus Philipps Vision abgeleitet)

1. **Temperatur als 10. Dimension** — Daten existieren (`weather->>'temp_c'`), aber kein Bucket-Filter und keine Bucket-Aggregation.
2. **Wetter-Insights** („welche Zeiten bei welchem Wetter ideal") — neue Auswertung: Uhrzeit × Wetterlage × Temperatur → Top-Muster mit Fangzahl, Ø Gewicht UND Kontext (Abweichung vom Gesamt-Ø im gewählten Zeitraum).
3. **Zeitraum-UI** — Backend-Filter existiert, Frontend hat keine VON/BIS-Eingabe.
4. **Kombi-Erweiterung** — `stats_beste_kombis` soll auch Uhrzeit/Wind/Temperatur-Kombinationen finden.
5. **Code-Duplikation** — Filter-Logik 3× kopiert; jede Änderung (z.B. neuer Bucket) muss an 3+ Stellen.

## 3. Geplante Änderungen

### Backend (neue Migration `0032_stats_v2.sql`)

**B.1 Temperatur-Bucket-Helper**
`public._to_bucket_temp(p_val numeric) → text` (IMMUTABLE, analog `_to_bucket_druck`):
Buckets: `<5`, `5-10`, `10-15`, `15-20`, `>=20` (bzw. `>20`), NULL → `Unbekannt`.

**B.2 Filter-Logik erweitern (in allen 3 RPCs + neue Insights-Funktion)**
- Neuer Filter `temp_bucket` (exakter Bucket-Vergleich via `_to_bucket_temp((weather->>'temp_c')::numeric)`).
- Neuer Filter `zeitraum` bleibt wie ist (semantisch: von-Tag 00:00:00Z bis bis-Tag 23:59:59Z).

**B.3 `stats_conditions` um Temperatur-Bucket erweitern**
- `bucket_rows`: neue Spalte `temp` via `_to_bucket_temp`.
- `temp_agg`: `jsonb_object_agg` wie die anderen Dimensionen.
- Output `buckets` + `temp`.

**B.4 Neue Funktion `stats_insights(p_filters jsonb) → jsonb`**
Automatische Muster-Erkennung über die gefilterte Menge (statische Aggregation, KEIN ML):
- `beste_fangzeit`: Uhrzeit-Bucket mit höchstem Ø-Gewicht (min. 2 Fänge) + Kontext {fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct}.
- `beste_wetterlage`: Wetterlage (`weather_text`) mit höchstem Ø-Gewicht + Kontext.
- `beste_temperatur`: Temperatur-Bucket mit höchstem Ø-Gewicht + Kontext.
- Kontext: `avg_gesamt` = Ø Gewicht der gesamten gefilterten Menge; `differenz_pct` = (bucket_avg - avg_gesamt) / avg_gesamt * 100 (gerundet, nur wenn avg_gesamt > 0).
- Mindest-Fangzahl pro Insight: 2 (sonst `null` + `hinweis`-Text, z.B. „Zu wenige Fänge für belastbare Aussage").

**B.5 `stats_beste_kombis` erweitern**
Zusätzliche 2er-Kombis aufnehmen: uhrzeit+wetter, uhrzeit+temp, wetter+temp, wind+wetter, wind+temp (fest verdrahtet, statisch, keine SQL-Injection). Optional 3er-Kombi uhrzeit+wetter+temp. Reihenfolge weiter nach avg_gewicht DESC, HAVING >= 2.

**B.6 Indizes (Performance)**
Prüfen + ergänzen: `catches(user_id, catch_ts)` existiert; bei vielen Fängen ggf. GIN-Index auf `weather` (nur wenn Query-Plan das zeigt — nicht voreilig; jsonb-Operatoren auf `weather->>'temp_c'` sind nicht GIN-optimiert, da Expression-Index auf `(weather->>'temp_c')` optional).

### Frontend (`web/src/pages/statistik.astro`)

**F.1 Zeitraum-Leiste**: zwei Datumsfelder VON / BIS (Default: letzte 12 Monate) + Button ANWENDEN + ZURÜCKSETZEN setzt auch Zeitraum zurück. `buildFilters()` um `zeitraum: {von, bis}` erweitern.
**F.2 Temperatur-Dimension**: 10. Filterzeile TEMPERATUR mit 5 Buckets (Chips mit Fangzahl).
**F.3 Wetter-Insights-Karten**: 3 Karten (BESTE FANGZEIT / BESTE WETTERLAGE / BESTE TEMPERATUR) mit Wert, Subzeile, Badge (Fänge, Ø) + Kontext (z.B. „+24% über Schnitt"). Daten aus `stats_insights`.
**F.4 Alle 10 Dimensionen offen anzeigen** (keine Einklapp-Funktion).

### Tests

**T.1 pgTAP (`tests/pgtap/0002_stats_v2_tests.sql`)**
- `_to_bucket_temp`: Grenzwerte (4.9 → <5, 5 → 5-10, 14.9 → 10-15, 15 → 15-20, 19.9 → 15-20, 20 → >=20, NULL → Unbekannt).
- `stats_conditions` mit `temp_bucket`-Filter: nur passende Fänge; `buckets->temp` enthält alle Buckets mit korrekten Fangzahlen.
- `stats_insights`: mit Seed-Daten — beste_fangzeit/beste_wetterlage/beste_temperatur korrekt + Kontext (differenz_pct Vorzeichen); Mindest-Fangzahl-Regel (1 Fang → null + Hinweis).
- `stats_beste_kombis` mit temp/uhrzeit-Kombis: Ergebnis enthält neue Kombinationen; HAVING >= 2 respektiert.
- Zeitraum-Filter: Fänge außerhalb von/bis werden ausgeschlossen (Grenz-Tag inklusive).

**T.2 Frontend-Verifikation (Playwright/curl)**
- statistik.astro lädt mit Default-Zeitraum ohne Fehler; Chip-Klick + ANWENDEN triggern RPCs; Insights-Karten zeigen Daten oder Hinweis.

## 4. Offene Design-Entscheidungen (für Audit)

- **D1: DRY-Refactor** — Filter-Logik in gemeinsame Helper-Funktion ziehen (z.B. `_stats_filtered(p_filters jsonb) RETURNS SETOF catches` SECURITY DEFINER) vs. pragmatische Duplizierung beibehalten. Pro DRY: eine Stelle für neue Dimensionen. Contra: Helper-Funktion in SECURITY DEFINER-Kette = zusätzliche Angriffsfläche + Performance (RV_SETOF). **Empfehlung: DRY-Helper, aber sorgfältig mit search_path + Grants.**
- **D2: Insight-Mindestmenge** — ab wie vielen Fängen ist ein Insight „belastbar"? Vorschlag: >= 2 (analog kombis). Alternativ >= 3.
- **D3: Kombi-Tiefe** — nur 2er-Kombis oder auch 3er (uhrzeit+wetter+temp)? 3er erzeugt mehr Zeilen, aber dünnere Daten.
- **D4: Bucket-Grenzen Temperatur** — 5 Buckets (<5 / 5-10 / 10-15 / 15-20 / >=20) sinnvoll? Alternative: 4 oder 6 Buckets.

## 5. Akzeptanzkriterien

- [ ] `stats_conditions` liefert `buckets.temp` mit 5 Buckets; `temp_bucket`-Filter wirkt UND-korrekt.
- [ ] `stats_insights` liefert 3 Insights mit Kontext (differenz_pct) bzw. Hinweis bei zu wenigen Fängen.
- [ ] `stats_beste_kombis` findet auch Uhrzeit-/Wind-/Temperatur-Kombis.
- [ ] Zeitraum-Filter (von/bis) greift in allen 4 Funktionen identisch.
- [ ] Alle Funktionen weiterhin SECURITY DEFINER + `auth.uid()` + keine SQL-Injection (nur statisches SQL / `format('%L')`).
- [ ] `statistik.astro`: Zeitraum-Leiste + Temperatur-Dimension + 3 Insight-Karten sichtbar; alle 10 Dimensionen offen.
- [ ] pgTAP-Tests grün (T.1); Frontend-Verifikation bestanden (T.2).

## 6. Nicht-Ziele (v1)

- Kein ML/Modell — reine statistische Aggregation.
- Keine Änderung am Fang-Erfassungs-Formular (Wetterdaten werden bereits automatisch erfasst).
- Kein CSV-Export (existiert in profil.astro; bleibt).
- Keine Mobile-Variante in v1 (Desktop-first wie bisher).

## 7. Build-Reihenfolge (nach Audit-Freigabe)

1. Migration `0032_stats_v2.sql` (B.1 → B.2 → B.3 → B.4 → B.5 → B.6) via `supabase db push` (bzw. Projektkonvention).
2. pgTAP-Tests `0002_stats_v2_tests.sql` ausführen (rot → grün).
3. Frontend `statistik.astro` (F.1 → F.2 → F.3 → F.4).
4. E2E-Verifikation (T.2) + Live-Check auf :4321 (Dev-Server, nicht Production-SSR killen).
5. Commit + RESUME-Update.
