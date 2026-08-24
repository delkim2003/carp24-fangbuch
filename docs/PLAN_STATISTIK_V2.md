# PLAN STATISTIK-STUDIO v2 (Backend + Frontend)

**Stand:** 24.08.2026 | **Status:** v3 — Runde-1-Funde (24) eingearbeitet; wartet auf Experten-Audit Runde 2
**Ziel (Philipp-Vision):** Nutzer baut sich Statistiken selbst: Zeitraum (von–bis), frei kombinierbare Bedingungen, Wetterdaten als Kern (Lufttemperatur automatisch + Wassertemperatur als User-Eingabe). Das System erkennt automatisch, welche Zeiten bei welchem Wetter ideal sind.
**v3-Änderung:** Alle 24 Runde-1-Funde (3× AENDERN, 92–95%) eingearbeitet — inkl. Fixes im BESTEHENDEN Code (Zeitzone, NULL-Buckets, Monats-Sortierung, Cast-Exceptions, Bucket-Naming), da 0032 die 3 RPCs via CREATE OR REPLACE neu schreibt.

---

## 1. IST-Zustand (verifiziert)

| Datei | Inhalt |
|---|---|
| `supabase/migrations/0009_stats_bedingungs_api.sql` | 3 RPCs: `stats_conditions(p_filters jsonb)`, `stats_drilldown(p_filters jsonb)`, `stats_beste_kombis(p_filters jsonb, p_limit int)`. SECURITY DEFINER, `search_path=''`, `auth.uid()`-Check, statisches SQL. **Bekannte Bugs (R1):** Uhrzeit-Buckets in UTC statt Europe/Vienna; NULL-Wetter → Wind `20+`/Druck `1005-1015`; `to_char(catch_ts,'TMMon')` locale-abhängig + Sortierung kaputt; `monat::int`/`jahr::int`/`zeitraum::timestamptz`-Casts werfen Exceptions bei Müll (DoS); `_to_bucket_druck` definiert aber nie aufgerufen; Bucket-Naming inkonsistent (`>= 1015` vs `20+` vs `'1015+'`-Alias); Zeitraum `T23:59:59Z` schließt sub-second aus |
| `supabase/migrations/0010_harden_function_grants.sql` | REVOKE EXECUTE von PUBLIC/anon + GRANT an authenticated für 7 Funktionen. **Achtung:** `CREATE OR REPLACE` in 0032 resetet ACLs auf DEFAULT → Grants müssen in 0032 WIEDERHOLT werden |
| `0001_init.sql` | `catches`: `weather jsonb` (temp_c, pressure_hpa, wind_kmh, weather_text, moon_text), `catch_ts timestamptz`, `weight_kg`, `length_cm`, `water_name`, `bait`, `species`, `species_custom`, `draft`, `deleted_at`. Indizes: `(user_id, catch_ts DESC)`, Partial `(user_id, draft, deleted_at) WHERE draft=false AND deleted_at IS NULL`. **Kein `water_temp_c`** |
| `web/src/pages/statistik.astro` | 3 RPCs (SSR + Client). **Blockers (R1):** `buildFilters(): Record<string,string>` kann kein `zeitraum`-Objekt; `state` ohne zeitraum-Key; `set:html` für initial-conditions-data (XSS-Risiko); SSR lädt keine Insights; kein Debounce |
| `web/src/pages/fang-erfassen.astro` | Kein Wassertemperatur-Feld |
| `web/src/pages/faenge/[id].astro` | WETTER-SNAPSHOT ohne Wassertemperatur-Zeile |
| `tests/pgtap/0001_rls_tests.sql` | Basis vorhanden (Muster `has_function_privilege` existiert) |

## 2. Lücken (aus Philipps Vision + R1)

1. **Wassertemperatur als User-Eingabe** — Feld in Fang erfassen (`water_temp_c`), Anzeige im Fang-Detail, eigene Studio-Dimension.
2. **Lufttemperatur als Studio-Dimension** (automatisch via Open-Meteo `temp_c`).
3. **Wetter-Insights** (beste Fangzeit/Wetterlage/Wasser-Temp/Luft-Temp) mit Kontext (differenz_pct + Stichproben-Hinweis), ohne 'Unbekannt'-Bucket.
4. **Zeitraum-UI** (Backend-Filter existiert, Frontend fehlt).
5. **Kombi-Erweiterung** (Uhrzeit/Wind/Temperatur).
6. **Bestands-Bugs fixen** (Zeitzone, NULL, Monatsnamen, Cast-DoS, Bucket-Naming) — via CREATE OR REPLACE in 0032.
7. **Code-Duplikation** — Filter-Logik 4× dupliziert → DRY-Helper.

## 3. Geplante Änderungen

### Backend (Migration `0032_stats_v2.sql`)

**B.0 Wassertemperatur-Feld**
`ALTER TABLE public.catches ADD COLUMN water_temp_c numeric;` (nullable, optional, Client-Validierung 0–40). Kein Backfill — alte Fänge NULL → `Unbekannt`.

**B.1 Bucket-Helper (IMMUTABLE, konsistentes Naming OHNE Space)**
- `_to_bucket_lufttemp(numeric) → text`: `<5`, `5-10`, `10-15`, `15-20`, `>=20`; NULL → `Unbekannt`.
- `_to_bucket_wassertemp(numeric) → text`: `<10`, `10-15`, `15-20`, `20-25`, `>=25`; NULL → `Unbekannt`.
- Beide mit **Exception-Guard**: `EXCEPTION WHEN others THEN RETURN 'Fehlerhaft'` (nicht-numerische Strings crashen sonst — R1 B9).
- **Grants:** Beide Helper bekommen `REVOKE EXECUTE FROM PUBLIC, anon, authenticated` (nur Owner; Defense-in-Depth — R1 C-F2).
- **Bestandsfix:** `_to_bucket_druck` auf `>=1015` (ohne Space) korrigieren und in den RPCs WIRKLICH aufrufen (R1 A3/B6), `'1015+'`-Alias entfernen. Neu: `_to_bucket_wind` (NULL → `Unbekannt`) — ersetzt inline CASE (R1 B7).

**B.2 DRY-Helper `_stats_filtered(p_filters jsonb) RETURNS SETOF catches` (R1 A4/D1)**
- SECURITY DEFINER + `SET search_path=''` + eigener `auth.uid()`-Check + `WHERE c.user_id = v_uid AND deleted_at IS NULL AND draft = false`.
- Zentrale Filter-Logik (ALLE Dimensionen + zeitraum), wird von den 4 RPCs genutzt. **Security-Regeln:** KEIN EXECUTE für authenticated/anon/PUBLIC (nur interne Aufrufe); eigener auth.uid()-Check; search_path=''.
- Alle Filter mit **Input-Validierung**: `monat`/`jahr` nur bei numerischem Wert (`~ '^[0-9]+$'`), `zeitraum.von/bis` nur bei ISO-Datum (`~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`) — sonst Filter ignorieren statt Exception (R1 C-F3/F4, DoS-Fix).

**B.3 Zeitzonen- und NULL-Fixes (Bestand, R1 B1/B2) — gelten für ALLE Funktionen**
- Uhrzeit-Buckets: `EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna')` (R1 B1).
- Wind/Druck/Wetter: NULL-Check VOR CASE → `Unbekannt` statt `20+`/`1005-1015` (R1 B2).
- Monat: `EXTRACT(MONTH FROM c.catch_ts)` numerisch (1–12) statt `to_char('TMMon')`; Frontend mappt via monthNamesDE (R1 B3).
- Zeitraum: Obergrenze `bis-Tag + INTERVAL '1 day'` statt `T23:59:59Z` (sub-second-sicher); Semantik: Filter arbeitet auf Tagesgrenzen des USERS — Frontend sendet reine `YYYY-MM-DD`, Backend interpretiert als `AT TIME ZONE 'Europe/Vienna'` (R1 A5).

**B.4 `stats_conditions` um beide Temperatur-Dimensionen erweitern**
- `bucket_rows`: `lufttemp` (aus `_to_bucket_lufttemp((weather->>'temp_c')::numeric)` mit Guard) + `wassertemp` (aus `_to_bucket_wassertemp(c.water_temp_c)`).
- Output `buckets` + `lufttemp` + `wassertemp`. Filter `lufttemp_bucket`, `wasser_temp_bucket` UND-korrekt.

**B.5 Neue Funktion `stats_insights(p_filters jsonb) → jsonb`**
- `beste_fangzeit`, `beste_wetterlage`, `beste_wassertemperatur`, `beste_lufttemperatur` — jeweils Bucket mit höchstem Ø-Gewicht + Kontext {fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct, stichproben_hinweis}.
- **'Unbekannt'-Bucket von der Auswahl AUSSCHLIESSEN** (nur wenn ALLE Fänge unbekannt → hinweis „Keine Wetterdaten") (R1 B4).
- **Mindest-Fangzahl: >= 3** für Insights (Einzel-Dimensionen), Kombis bleiben >= 2 (R1 A7). **stichproben_hinweis** bei < 5 Fängen im besten Bucket („nur 2 Fänge — wenig Aussagekraft") (R1 B5).
- `avg_gesamt IS NULL` (0 Fänge) → alle Insights null + hinweis „Keine Fänge im gewählten Zeitraum" (R1 B8).
- **Grants:** `REVOKE EXECUTE FROM PUBLIC, anon` + `GRANT EXECUTE TO authenticated` (R1 A1/C-F1).

**B.6 `stats_beste_kombis` erweitern**
- Zusätzliche 2er-Kombis: uhrzeit+wetter, uhrzeit+wassertemp, wetter+wassertemp, wetter+lufttemp, wind+wetter, wind+wassertemp, wassertemp+lufttemp (statisch). 3er-Kombi uhrzeit+wetter+wassertemp: **zurückgestellt** (dünne Daten; später).
- Nutzt `_stats_filtered` + neue Bucket-Helper (kein NULL-Infekt, R1 B7).

**B.7 Grants-Sektion am ENDE von 0032 (R1 A1 — BLOKKER)**
Nach allen CREATE OR REPLACE: REVOKE/GRANT für die 3 geänderten RPCs WIEDERHOLEN (analog 0010) + stats_insights + Helper (REVOKE für Helper). Sonst sind alle Funktionen nach CREATE OR REPLACE für PUBLIC+anon aufrufbar.

**B.8 Indizes:** Bestehende reichen (< 10k/User); kein GIN/Expression-Index (R1 A8). Optional Composite `(user_id, draft, deleted_at, catch_ts DESC)` nur bei Scale-Bedarf.

### Frontend

**F.1 Fang erfassen (`fang-erfassen.astro`)** — Feld **WASSERTEMPERATUR (°C)** (optional, type number, step 0.1, min 0, max 40, Platzhalter `18.5`, Hinweis „Wassertemperatur am Gewässer"), speichert `water_temp_c`.

**F.2 Fang-Detail (`faenge/[id].astro`)** — WETTER-SNAPSHOT + Zeile **WASSERTEMPERATUR** (`water_temp_c` + °C, sonst „—").

**F.3 Statistik (`statistik.astro`)**
- **Zeitraum-Leiste** VON/BIS/ANWENDEN/ZURÜCKSETZEN. **Fix (R1 C-F5/F6):** `state` um `zeitraum_von`/`zeitraum_bis` erweitern; `buildFilters()` auf `Record<string, any>` und `zeitraum: {von, bis}` setzen (nur wenn beide gesetzt).
- **Datums-Handling (R1 C-F7):** Wert direkt aus `<input type="date">.value` (YYYY-MM-DD) ohne JS-Date-TZ-Konvertierung nehmen.
- **WASSERTEMP-Dimension** (5 Buckets) + **LUFTTEMP-Dimension** (5 Buckets), alle Zeilen offen.
- **4 Insight-Karten** inkl. Kontext-Badge (differenz_pct, stichproben_hinweis) aus `stats_insights`.
- **SSR:** 4. RPC `stats_insights` in initial load (R1 C-F9).
- **XSS-Fix (R1 C-F11):** `set:html` für initial-conditions-data → `set:text` bzw. `JSON.parse(textContent)`.
- **Debounce 200ms** auf Filterwechsel (R1 C-F8).
- Bucket-Labels im Frontend-Mapping an neue Naming-Konvention angleichen (kein Space: `>=1015` etc., R1 B6).

### Tests (`tests/pgtap/0002_stats_v2_tests.sql`)

**T.1 Backend**
- Bucket-Helper: Grenzwerte (Luft: 4.9→<5, 5→5-10, 19.9→15-20, 20→>=20; Wasser: 9.9→<10, 10→10-15, 24.9→20-25, 25→>=25), NULL→Unbekannt, **nicht-numerisch→Fehlerhaft** (R1 B9).
- `stats_conditions`: temp-Filter UND-korrekt; `buckets.lufttemp/wassertemp` korrekt; **weather=NULL → Wind/Druck/Temp = Unbekannt** (R1 B2).
- **Zeitzonen-Test:** Session UTC, Fang 06:00 Europe/Vienna → Bucket 6-12 (R1 B1).
- Monats-Bucket numerisch 1-12, chronologisch sortiert (R1 B3).
- `stats_insights`: Seed-Daten, Kontext-Vorzeichen, **'Unbekannt' ausgeschlossen**, Mindestgrenze (1 Fang → null+Hinweis, 2 Fänge → null+Hinweis, 3+ → Daten), **0 Fänge → alle null + Hinweis**, Gleichstand (R1 B4/B5/B8/B10).
- `stats_beste_kombis`: neue Kombis; HAVING >= 2; NULL-Infekt weg.
- Zeitraum: Grenz-Tag inklusive (sub-second), Jahreswechsel, `von > bis` → 0, `von = bis` → 1 Tag (R1 A5/B10).
- **Injection/DoS:** `monat='abc'`, `jahr='12.5'`, `zeitraum.von='not-a-date'`, `druck_bucket='HACKED'` → KEINE Exception, Filter ignoriert (R1 C-F3/F4/F13).
- **Grants:** `has_function_privilege('authenticated', 'stats_insights(jsonb)', 'EXECUTE')` true; PUBLIC/anon false; Helper ohne EXECUTE (R1 C-F12).
- **RLS-Bypass:** User B sieht bei allen 4 RPCs 0 Fänge von User A (R1 C-F14).

**T.2 Frontend (Playwright/curl)**
- Fang erfassen: Feld sichtbar, speichert `water_temp_c` (E2E).
- Fang-Detail: Zeile sichtbar (Wert bzw. „—").
- statistik.astro: Default-Zeitraum lädt, ANWENDEN/Chip triggern RPCs, Insights-Karten zeigen Daten oder Hinweis, keine leeren States beim ersten Render (SSR).

## 4. Entscheidungen (aus R1 beschlossen)

- **D1 DRY:** JA — `_stats_filtered` Helper mit 3 Security-Regeln (kein EXECUTE für Clients, eigener auth.uid(), search_path='') (R1 A4).
- **D2 Mindest-Fangzahl:** Insights >= 3, Kombis >= 2, stichproben_hinweis < 5 (R1 A7/B5).
- **D3 Kombi-Tiefe:** nur 2er in v1; 3er zurückgestellt (dünne Daten).
- **D4 Buckets Wasser:** 5 Buckets `<10 / 10-15 / 15-20 / 20-25 / >=25` — konsistent mit Stitch-Screen; leere Gruppen erscheinen nicht in jsonb_object_agg, verzerren also nicht. (R1 B11 empfahl 4; abgelehnt wegen Screen-Konsistenz + kein Verzerrungsrisiko.)
- **D5 Naming:** EIN Schema ohne Space: `<5`, `5-10`, `10-15`, `15-20`, `>=20` (Luft), `<10`…`>=25` (Wasser); Bestand (Druck `>=1015`, Wind `>=20`) mit fixen; `'1015+'`-Alias entfernen (R1 B6/A9).
- **Zeitzone:** `Europe/Vienna` für Uhrzeit-Buckets UND Zeitraum-Tagesgrenzen (AT-App) (R1 B1/A5).

## 5. Akzeptanzkriterien

- [ ] `catches.water_temp_c` existiert; Fang erfassen speichert, Fang-Detail zeigt (bzw. „—").
- [ ] `stats_conditions` liefert `buckets.lufttemp` + `buckets.wassertemp`; Filter UND-korrekt; Uhrzeit-Buckets in Europe/Vienna; NULL-Wetter = `Unbekannt`.
- [ ] `stats_insights` liefert 4 Insights mit Kontext (differenz_pct, stichproben_hinweis), 'Unbekannt' ausgeschlossen, Mindestgrenze 3.
- [ ] `stats_beste_kombis` findet Wasser-Temp-/Uhrzeit-Kombis; keine NULL-Infektion.
- [ ] Keine Cast-Exception bei bösartigen Filtern (monat/jahr/zeitraum) — Filter ignoriert statt 500.
- [ ] Grants nach CREATE OR REPLACE wiederhergestellt (PUBLIC/anon NEIN, authenticated JA für RPCs; Helper ohne EXECUTE).
- [ ] `statistik.astro`: Zeitraum-Leiste (buildFilters `Record<string,any>`), beide Temp-Dimensionen, 4 Insight-Karten, SSR lädt Insights, kein `set:html`-XSS, Debounce.
- [ ] pgTAP grün (T.1 inkl. Zeitzonen-/Injection-/Grants-/RLS-Tests); Frontend-Verifikation bestanden (T.2).

## 6. Nicht-Ziele (v1)

- Kein ML/Modell — reine statistische Aggregation.
- Kein CSV-Export-Umbau (bleibt in profil.astro).
- Keine Mobile-Variante (Desktop-first).
- Keine 3er-Kombis, kein GIN-Index (dokumentiert, später).

## 7. Build-Reihenfolge (nach Audit-Freigabe)

1. Migration `0032_stats_v2.sql` (B.0 → B.1 → B.2 → B.3 → B.4 → B.5 → B.6 → B.7 → B.8) — erst auf Dev-DB, dann prod (Projektkonvention).
2. pgTAP `0002_stats_v2_tests.sql` (rot → grün).
3. Frontend: Fang erfassen (F.1) → Fang-Detail (F.2) → statistik.astro (F.3).
4. E2E (T.2) + Live-Check :4321 (Dev-Server, Production-SSR :4321 nicht killen).
5. Commit + RESUME-Update.

## 8. Changelog

- **v1 (24.08.):** Erstfassung Backend+Frontend.
- **v2 (24.08.):** Wassertemperatur (User-Eingabe) + Lufttemperatur (auto) als getrennte Dimensionen.
- **v3 (24.08.):** 24 R1-Funde eingearbeitet (Blocker: Grants-Reset A1, Zeitzone B1, buildFilters C-F5/F6; kritisch: NULL-Buckets, Monatsnamen, Cast-DoS, 'Unbekannt'-Insights, Stichproben-Kontext, Naming; mittel/minor: Helper-Grants, SSR-Insights, XSS set:html, Debounce, Test-Lücken).
