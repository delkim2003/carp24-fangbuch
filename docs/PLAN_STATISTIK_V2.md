# PLAN STATISTIK-STUDIO v2 (Backend + Frontend)

**Stand:** 24.08.2026 | **Status:** v5 FINAL — R1 (24) + R2 (Ops+FE) + R3 (35: SQL-Detail, Produkt/DSGVO, Fuzzing) eingearbeitet. Build-Freigabe nach Philipp-OK.
**Ziel (Philipp-Vision):** Nutzer baut sich Statistiken selbst: Zeitraum (von–bis), frei kombinierbare Bedingungen, Wetterdaten als Kern (Lufttemperatur automatisch + Wassertemperatur als User-Eingabe). Das System erkennt automatisch, welche Zeiten bei welchem Wetter ideal sind.

---

## 1. IST-Zustand (Kurzform — Details in v4-Changelog)

`0009_stats_bedingungs_api.sql` (3 RPCs, SECURITY DEFINER, search_path='', auth.uid(), statisches SQL) mit Bestands-Bugs: UTC-Uhrzeit-Buckets, NULL-Wetter→falsche Buckets, `to_char('TMMon')`-Monatsnamen, Cast-Exceptions (monat/jahr/zeitraum), `_to_bucket_druck` ungenutzt, inkonsistentes Naming, Zeitraum sub-second-Lücke. `0010` Grants für 7 Funktionen. `catches` ohne `water_temp_c`. `statistik.astro` ohne Zeitraum-UI/Insights/set:html-XSS/Promise.all. `fang-erfassen.astro` ohne Wasser-Temp-Feld; `CatchInput`/`buildInputData()` ohne Feld. `faenge/[id].astro` 4er-Grid ohne Wasser-Temp. `i18n.ts` ohne neue Keys. `infra/backup.sh` existiert (täglich 02:30).

## 2. Lücken

1. Wassertemperatur als User-Eingabe (Erfassen → `water_temp_c` → Detail → Studio-Dimension).
2. Lufttemperatur als Studio-Dimension (auto via Open-Meteo `temp_c`).
3. Wetter-Insights (Fangzeit/Wetterlage/Wasser-Temp/Luft-Temp + **Köder-Kombi**) mit Kontext + Stichproben-Hinweis, ohne 'Unbekannt'.
4. Zeitraum-UI (Backend existiert, Frontend fehlt).
5. Kombi-Erweiterung (Uhrzeit/Wind/Temperatur).
6. Bestands-Bugs fixen (Zeitzone, NULL, Monatsnamen, Cast-DoS, Naming) via CREATE OR REPLACE in 0032.
7. Code-Duplikation → DRY-Helper `_stats_filtered`.
8. **DSGVO (R3):** Hinweis Open-Meteo im Formular, Wasser-Temp in Datenschutzerklärung, CSV-Export um `water_temp_c` erweitern.

## 3. Geplante Änderungen

### Backend (Migration `0032_stats_v2.sql` — Reihenfolge EINHALTEN, R3 A9)

**B.0 (1. Schritt!) Wassertemperatur-Feld**
`ALTER TABLE public.catches ADD COLUMN water_temp_c numeric;` + `COMMENT ON COLUMN ... IS 'Wassertemperatur in Grad Celsius, User-Eingabe, 0-40, NULL wenn unbekannt';` + **CHECK** `(water_temp_c IS NULL OR (water_temp_c >= 0 AND water_temp_c <= 40))` (R3 A6). MUSS VOR allen CREATE FUNCTION stehen (RETURNS SETOF catches-Spaltenliste; R3 A1/A9).

**B.1 (2.) Bucket-Helper (IMMUTABLE, Naming OHNE Space, Exception-Guard, Grants-REVOKE für Clients)**
`_to_bucket_lufttemp` (`<5 / 5-10 / 10-15 / 15-20 / >=20`), `_to_bucket_wassertemp` (`<10 / 10-15 / 15-20 / 20-25 / >=25`), `_to_bucket_wind` (NEU, NULL→`Unbekannt`), `_to_bucket_druck` fixen (`>=1015`, Space entfernen). Alle: NULL→`Unbekannt`, `EXCEPTION WHEN others THEN RETURN 'Fehlerhaft'`. **WICHTIG (R3 A2):** In `bucket_rows` NUR via Helper aggregieren (nie inline-CASE ohne ELSE — jsonb_object_agg crasht bei NULL-Key).

**B.2 (3.) DRY-Helper `_stats_filtered(p_filters jsonb) RETURNS SETOF catches`**
- SECURITY DEFINER + `SET search_path=''` + **explizit VOLATILE** (auth.uid() ist volatil — NICHT STABLE/IMMUTABLE; R3 A1) + eigener auth.uid()-Check + `WHERE user_id=v_uid AND deleted_at IS NULL AND draft=false` (deckt Partial-Index).
- **Input-Validierung (R3 C-F1/F2/F4 — DoS-fest):**
  - `zeitraum.von/bis`: Format-Regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}$` **UND** Datumsgehalt via `TO_DATE(x,'YYYY-MM-DD') IS NOT NULL` + Monat 1–12 + Tag 1–31 (fängt `2026-13-01`, `2026-02-30`, `0000-01-31`).
  - `monat`: `^([1-9]|1[0-2])$` (kein Overflow, kein Monat 99). `jahr`: `^[0-9]{4}$`.
  - String-Filter (`wetter`, `gewaesser`, `art`, `koeder`): **Längen-Limit 256** + nur-Whitespace-Guard (R3 A7/C-F4).
  - Unbekannte Bucket-Werte → `ELSE true`-Guard (Filter ignoriert, kein Crash; R3 C-F3).
- Filter: alle Dimensionen + zeitraum (Semantik unten).

**B.3 (4.) Zeitzonen-/NULL-/Monats-/Zeitraum-Fixes (ALLEN Funktionen + Helper; R3 A3/A4)**
- Uhrzeit-Buckets ÜBERALL: `EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna')` (Filter UND Aggregation UND Helper — sonst stille Inkonsistenz).
- NULL-Check VOR CASE für wind/druck/wetter → `Unbekannt`.
- Monat: `EXTRACT(MONTH ...)` numerisch.
- **Zeitraum (R3 A4 — Vienna-Tagesgrenzen, NICHT UTC):**
  `c.catch_ts >= ((von)||'T00:00:00')::timestamp AT TIME ZONE 'Europe/Vienna'`
  `AND c.catch_ts < ((((bis)||'T00:00:00')::timestamp AT TIME ZONE 'Europe/Vienna') + INTERVAL '1 day')`
  (nur wenn beide validiert; sub-second-sicher).
- `statement_timeout`-Guard: `SET LOCAL statement_timeout = '5s'` in den RPCs (R3 C-F17).

**B.4 (5.) `stats_conditions` erweitern** — `bucket_rows`: `lufttemp` via `_to_bucket_lufttemp((weather->>'temp_c')::numeric)`, `wassertemp` via `_to_bucket_wassertemp(water_temp_c)`; Filter `lufttemp_bucket`/`wasser_temp_bucket` UND-korrekt; Output `buckets` + beide.

**B.5 (6.) `stats_insights(p_filters jsonb) → jsonb`**
- 4 Dimension-Insights (beste_fangzeit/wetterlage/wassertemperatur/lufttemperatur) + **5. Insight „beste_koeder_kombi"** (Top-Köder-Kombi aus `beste_kombis`, R3 B1) — alle mit Kontext {fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct, stichproben_hinweis}.
- 'Unbekannt' ausgeschlossen; Mindestgrenze **>= 3**; **stichproben_hinweis bei < 10 Fängen** (R3 B7); `avg_gesamt IS NULL` → alle null + „Keine Fänge im gewählten Zeitraum".
- **Tie-Breaking (R3 C-F6):** bei gleichem avg_gewicht gewinnt höhere Fangzahl, dann lexikographisch.
- Grants: REVOKE PUBLIC/anon + GRANT authenticated.

**B.6 (7.) `stats_beste_kombis` erweitern** — neue 2er-Kombis (uhrzeit+wetter, uhrzeit+wassertemp, wetter+wassertemp, wetter+lufttemp, wind+wetter, wind+wassertemp, wassertemp+lufttemp, wetter+koeder bereits vorhanden — bleibt); 3er zurückgestellt; nutzt Helper (kein NULL-Infekt).

**B.7 (8.) Grants-Sektion (R3 A5 — Begründung korrigieren: PG14+ behält ACLs bei CREATE OR REPLACE, Wiederholung ist Defense-in-Depth + nötig für NEUE Funktionen):**
REVOKE/GRANT für stats_conditions/stats_drilldown/stats_beste_kombis (wiederholen) + stats_insights (neu) + REVOKE für `_stats_filtered` + alle Bucket-Helper (kein EXECUTE für PUBLIC/anon/authenticated).

**B.8 Indizes:** bestehende reichen; kein GIN/Expression.

### Frontend

**F.1 Fang erfassen (`fang-erfassen.astro` + `catch-service.ts`)**
- Feld WASSERTEMPERATUR (°C) links nach LÄNGE vor FISCHART (number, step 0.1, min 0, max 40, Platzhalter 18.5, Hinweis „Wassertemperatur am Gewässer"). `CatchInput` + `buildInputData()` erweitern (leer → nicht senden). `data-testid="water-temp-input"`.
- **DSGVO-Hinweis (R3 B4):** unter Koordinaten-Feldern dezent: „Koordinaten werden für automatische Wetterdaten-Erfassung (Open-Meteo) verwendet."

**F.2 Fang-Detail (`faenge/[id].astro`)** — WASSERTEMPERATUR als eigene Zeile unter dem 4er-Grid (border-t; `water_temp_c` + „ °C" bzw. „—"). `data-testid="water-temp-display"`.

**F.3 Statistik (`statistik.astro`)**
- Zeitraum-Leiste in Bedingungen-Box vor `#conditions-rows`; Contract `zeitraum: {von, bis}` (beide gesetzt-Guard); `state` + `buildFilters(): Record<string, any>`; Datum direkt aus `<input type="date">.value`.
- **Insights:** `#insights-cards` (2×2 Grid unter Kombis) + `renderInsights()` + SSR-Load + `refreshAll()` 4. RPC; **5 Karten** (inkl. Beste Köder-Kombi); differenz-Badge grün/rot; stichproben_hinweis als dezenter Text; null → Hinweis.
- Fehlerbehandlung: `Promise.allSettled()` + `#conditions-error`; von>bis-Warnung; Loading-State („LÄDT…"); Debounce 200ms; `set:html`→`set:text`; **data-testid konsistent (R3 C-F18/F19):** `zeitraum-von/-bis/-anwenden/-reset`, `insight-card-0..4`, `conditions-error`, Chips bekommen `data-testid`.
- WASSERTEMP- + LUFTTEMP-Dimensionen; Bucket-Labels an Naming angeglichen.

**F.4 i18n (`i18n.ts`)** — neue Keys (de/en): `statistik.wassertemperatur/lufttemperatur/zeitraum_von/bis/anwenden/zuruecksetzen/insight_beste_fangzeit/wetterlage/wassertemp/lufttemp/koeder_kombi/keine_faenge/keine_wetterdaten/stichproben_hinweis/differenz_pct_besser/schlechter/von_nach_bis_warnung/disclaimer`, `fang_erfassen.wassertemperatur_label/hinweis/wetterdaten_hinweis`. **Datenschutzerklärung:** `datenschutz.daten_fangbuch` um „Wassertemperatur" + „Wetterdaten (automatisch via Open-Meteo)" ergänzen (R3 B5).

**F.5 CSV-Export (profil.astro, R3 B6 — DSGVO Art. 20):** `escapeCsvField`-Zeile um `water_temp_c` erweitern (aus Nicht-Zielen genommen).

### Tests (`tests/pgtap/0002_stats_v2_tests.sql`)

**T.0 Fixtures:** INSERTs mit `water_temp_c` IN der Test-Datei (isoliert, nicht im Seed).

**T.1 Backend**
- Helper: Grenzwerte (Luft 0/4.9/5/19.9/20/40; Wasser 0/9.9/10/24.9/25/40; Wind exakt 20; Druck exakt 1005/1015 — R3 C-F8), NULL→Unbekannt, nicht-numerisch→Fehlerhaft.
- `stats_conditions`: temp-Filter; weather=NULL→Unbekannt; Zeitzonen-Test (UTC-Session, 06:00 Vienna → 6-12); Monat numerisch+sortiert.
- `stats_insights`: Kontext-Vorzeichen; 'Unbekannt' ausgeschlossen; Mindestgrenze (1/2→null, **exakt 3→Daten**, R3 C-F7); 0 Fänge→null+Hinweis; **Gleichstand-Tie-Breaking (höhere Fangzahl)**; **exakt 2 Fänge bei Kombis**.
- `stats_beste_kombis`: neue Kombis; HAVING>=2; kein NULL-Infekt.
- Zeitraum: Grenz-Tag (sub-second), Jahreswechsel, von>bis→0, von=bis→1 Tag, **Vienna-Tagesgrenze (00:30 Vienna am 24. → inklusive; R3 A4)**.
- **Fuzz/DoS (R3 C-F1/F2/F4):** `zeitraum.von='2026-13-01'`, `'2026-02-30'`, `'0000-01-31'`, `monat='9999999999999999999'`, `jahr='99'`, `wetter`=10KB-String, `druck_bucket='HACKED'`, `wasser_temp_bucket='<script>'` → KEINE Exception, Filter ignoriert.
- **Grants:** `has_function_privilege` für stats_insights (authenticated true, PUBLIC/anon false), Helper ohne EXECUTE.
- **RLS-Bypass:** User B sieht 0 Fänge von User A (alle 4 RPCs).
- **Drilldown-Limit (R3 C-F10/F15):** `stats_drilldown` bekommt LIMIT (z.B. 200) + Schema-Test.
- **Performance (R3 C-F9):** Test mit großem Datensatz (pgTAP oder Skript) — stats_conditions < 500ms p95, drilldown < 300ms bei 10k Fängen.

**T.2 Frontend (Playwright, data-testid)**
- Fang erfassen: Feld sichtbar + speichert; DSGVO-Hinweis sichtbar.
- Fang-Detail: Zeile sichtbar (Wert/„—").
- statistik.astro: Zeitraum wirkt, 5 Insight-Karten (Daten oder Hinweis), SSR initial, von>bis-Warnung, Loading, kein set:html (grep), E2E über data-testid.

## 4. Entscheidungen

- D1 DRY: JA (Helper, explizit VOLATILE).
- D2 Mindest-Fangzahl: Insights >= 3, Kombis >= 2, **stichproben_hinweis < 10**.
- D3 Kombis: nur 2er in v1.
- D4 Wasser-Buckets: 5 (`<10/10-15/15-20/20-25/>=25`).
- D5 Naming: OHNE Space; Bestand fixen.
- D6 **Paywall — ENTSCHIEDEN (24.08., Philipp: „Mischung Free/Pro, Sweet Spot zum Kaufen"):** FREE = Erfassen (inkl. automatischer Wetterdaten-Erfassung — Datengrundlage muss frei sein), Fangbuch, Basis-Statistik (Zeitraum, Bedingungen, Drilldown, Beste Kombinationen), 50-Fänge-Limit. **PRO = die 5 Wetter-Insights-Karten** (beste_fangzeit/wetterlage/wassertemp/lufttemp/koeder_kombi) — Free-User sehen sie als **verblasste Vorschau mit Premium-Lock + Upgrade-CTA** zur Premium-Seite. Gating im Frontend (profiles.is_pro; kein Daten-Leak, da nur eigene Fänge). Premium-Seite: „ERWEITERTE STATISTIK" → **„INSIGHTS & TRENDS"** (Beschreibung: Wetter-Muster-Erkennung). 50-Fänge-Limit greift in Basis-Statistik bewusst NICHT (Upgrade-Magnet).
- D7 Zeitzone: Europe/Vienna (Uhrzeit + Tagesgrenzen).
- Zeitzonen-/NULL-/Monats-/Zeitraum-Fixes gelten für ALLE Funktionen + Helper (R3 A3).

## 5. Akzeptanzkriterien (Gate)

- [ ] `water_temp_c` existiert (mit CHECK 0–40 + COMMENT); Erfassen speichert, Detail zeigt, CSV-Export enthält das Feld.
- [ ] `stats_conditions` liefert beide Temp-Buckets; Uhrzeit Europe/Vienna; NULL→Unbekannt; keine Cast-Exception bei Fuzz-Fällen (F1/F2/F4).
- [ ] `stats_insights` liefert 5 Insights (inkl. Köder-Kombi) mit Kontext + stichproben_hinweis; 'Unbekannt' ausgeschlossen; Mindestgrenze 3; Tie-Breaking definiert.
- [ ] `stats_beste_kombis` neue Kombis; kein NULL-Infekt; Drilldown-Limit 200.
- [ ] Grants via `has_function_privilege` verifiziert (PUBLIC/anon NEIN, authenticated JA für RPCs; Helper ohne EXECUTE).
- [ ] **Fuzz-Gate (R3 C-SBA):** parametrisierter Fuzz-Lauf über p_filters (Fälle aus F1/F2/F4) endet ohne Exception; **grep: kein `set:html` im statistik.astro-Source**.
- [ ] **Performance-Gate:** stats_conditions < 500ms p95, drilldown < 300ms bei 10k Fängen.
- [ ] **RLS-Bypass-Gate:** User B sieht 0 Fänge von User A.
- [ ] DSGVO: Formular-Hinweis Open-Meteo + Datenschutzerklärung (Wasser-Temp + Open-Meteo) aktualisiert.
- [ ] statistik.astro: Zeitraum, 5 Insight-Karten (SSR+Client), von>bis-Warnung, Loading, Debounce, data-testid, keine Garantie-Sprache (Subline + Disclaimer).
- [ ] pgTAP grün (T.1: konkrete Assertion-Zahl dokumentieren); Frontend-E2E bestanden (T.2).

## 6. Nicht-Ziele (v1)

Kein ML/Modell · keine Mobile-Variante · keine 3er-Kombis · kein GIN-Index · **kein CSV-Export-Umbau ist GESTRICHEN (jetzt in F.5, DSGVO)**.

## 7. Build-Reihenfolge

**7.0 Backup + Rollback (BLOKKER):**
- a) `docker exec supabase-db pg_dump -U supabase_admin --schema-only -Fp --function=stats_conditions --function=stats_drilldown --function=stats_beste_kombis postgres > /tmp/stats_rpcs_backup.sql`
- b) Rollback-Skript `0033_rollback_stats_v2.sql` (0009-Originale + Grants).
- c) `infra/backup.sh` (frisches Backup vor Migration).
- d) `docker exec supabase-db psql -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -f supabase/migrations/0032_stats_v2.sql` (Dev zuerst, dann prod).
- e) pgTAP `0002_stats_v2_tests.sql` (rot → grün).
- f) Fehler → Rollback-Skript oder pg_dump-Restore.

**7.1 Frontend:** Fang erfassen (F.1) → Fang-Detail (F.2) → statistik.astro (F.3) → i18n (F.4) → CSV-Export (F.5).
**7.2 E2E (T.2) + Fuzz-Gate + Performance-Gate + Live-Check :4321.**
**7.3 Commit + RESUME-Update.**

## 8. Changelog

v1 Erstfassung · v2 Wassertemperatur+Lufttemperatur · v3 24 R1-Funde · v4 R2 (Ops+FE) · **v5 FINAL: R3 (35 Funde) — SQL-Reihenfolge/VOLATILE/jsonb_object_agg-Schutz/Vienna-Tagesgrenzen, DoS-feste Validierung (TO_DATE, Overflow, Längen), 5. Insight Köder-Kombi, DSGVO (Open-Meteo-Hinweis, Datenschutz-Text, CSV-Export), Paywall D6 offen, Fuzz-/Performance-/set:html-Gate, Tie-Breaking, Drilldown-Limit 200, statement_timeout.**
