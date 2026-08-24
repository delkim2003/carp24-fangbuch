# PLAN STATISTIK-STUDIO v2 (Backend + Frontend)

**Stand:** 24.08.2026 | **Status:** v4 FINAL — Runde-1 (24 Funde) + Runde-2 (Operations + 16 Frontend-Details) eingearbeitet. Build-Freigabe nach Philipp-OK.
**Ziel (Philipp-Vision):** Nutzer baut sich Statistiken selbst: Zeitraum (von–bis), frei kombinierbare Bedingungen, Wetterdaten als Kern (Lufttemperatur automatisch + Wassertemperatur als User-Eingabe). Das System erkennt automatisch, welche Zeiten bei welchem Wetter ideal sind.
**Audit-Stand:** R1 = 3× AENDERN (92–95%) → v3. R2 = Fix-Verifikation **OK**, Operations AENDERN (Ergänzungen), Frontend AENDERN (Details) → v4 FINAL.

---

## 1. IST-Zustand (verifiziert)

| Datei | Inhalt |
|---|---|
| `supabase/migrations/0009_stats_bedingungs_api.sql` | 3 RPCs: `stats_conditions(p_filters jsonb)`, `stats_drilldown(p_filters jsonb)`, `stats_beste_kombis(p_filters jsonb, p_limit int)`. SECURITY DEFINER, `search_path=''`, `auth.uid()`-Check, statisches SQL. **Bugs (R1):** Uhrzeit-Buckets in UTC statt Europe/Vienna; NULL-Wetter → Wind `20+`/Druck `1005-1015`; `to_char(catch_ts,'TMMon')` locale-abhängig + Sortierung kaputt; `monat::int`/`jahr::int`/`zeitraum::timestamptz`-Casts werfen Exceptions (DoS); `_to_bucket_druck` nie aufgerufen; Bucket-Naming inkonsistent; Zeitraum `T23:59:59Z` sub-second-Lücke |
| `0010_harden_function_grants.sql` | REVOKE/GRANT für 7 Funktionen. **Achtung:** `CREATE OR REPLACE` resetet ACLs → Grants in 0032 WIEDERHOLEN |
| `0001_init.sql` | `catches`: `weather jsonb`, `catch_ts timestamptz`, `weight_kg`, `length_cm`, `water_name`, `bait`, `species`, `species_custom`, `draft`, `deleted_at`. Indizes `(user_id, catch_ts DESC)` + Partial `(user_id, draft, deleted_at) WHERE draft=false AND deleted_at IS NULL`. **Kein `water_temp_c`** |
| `statistik.astro` | 3 RPCs (SSR + Client). Blockers (R1/R2): `buildFilters(): Record<string,string>`, `state` ohne zeitraum, kein `#insights-cards`-Container, keine `renderInsights()`, kein SSR-`stats_insights`, kein Debounce, `set:html`-XSS, `Promise.all` statt allSettled |
| `fang-erfassen.astro` | Kein Wasser-Temp-Feld; `buildInputData()` ohne `water_temp_c`; `catch-service.ts` `CatchInput` ohne Feld |
| `faenge/[id].astro` | WETTER-SNAPSHOT 4er-Grid (TEMPERATUR/LUFTDRUCK/WIND/MOND) ohne Wasser-Temp-Zeile |
| `i18n.ts` | Keine Keys für Zeitraum/Insights/Wassertemperatur |
| `infra/backup.sh` | pg_dump täglich 02:30, GPG + offsite — existiert, wird aber im Plan nicht erwähnt |

## 2. Lücken

1. **Wassertemperatur als User-Eingabe** (Fang erfassen → `water_temp_c` → Fang-Detail → Studio-Dimension).
2. **Lufttemperatur als Studio-Dimension** (automatisch via Open-Meteo `temp_c`).
3. **Wetter-Insights** (beste Fangzeit/Wetterlage/Wasser-Temp/Luft-Temp) mit Kontext + Stichproben-Hinweis, ohne 'Unbekannt'.
4. **Zeitraum-UI** (Backend-Filter existiert, Frontend fehlt).
5. **Kombi-Erweiterung** (Uhrzeit/Wind/Temperatur).
6. **Bestands-Bugs fixen** (Zeitzone, NULL, Monatsnamen, Cast-DoS, Naming) via CREATE OR REPLACE in 0032.
7. **Code-Duplikation** → DRY-Helper `_stats_filtered`.

## 3. Geplante Änderungen

### Backend (Migration `0032_stats_v2.sql`)

**B.0 Wassertemperatur-Feld**
`ALTER TABLE public.catches ADD COLUMN water_temp_c numeric;` (nullable; Client-Validierung 0–40). ALTER ist reine Metadata-Operation (Postgres 17, kein Rewrite/Lock-Risiko — R2 B-Fund2). `import_catches` (0016) nutzt explizite Spaltenliste → bleibt kompatibel (NULL). Kein Backfill.

**B.1 Bucket-Helper (IMMUTABLE, Naming OHNE Space, Exception-Guard)**
- `_to_bucket_lufttemp(numeric) → text`: `<5`, `5-10`, `10-15`, `15-20`, `>=20`; NULL → `Unbekannt`; `EXCEPTION WHEN others THEN RETURN 'Fehlerhaft'`.
- `_to_bucket_wassertemp(numeric) → text`: `<10`, `10-15`, `15-20`, `20-25`, `>=25`; NULL → `Unbekannt`; Exception-Guard.
- **Grants:** `REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated` (nur Owner; R1 C-F2).
- Bestandsfix: `_to_bucket_druck` → `>=1015` (ohne Space), `_to_bucket_wind` NEU (NULL → `Unbekannt`), beide WIRKLICH in den RPCs nutzen; `'1015+'`-Alias entfernen (R1 A3/B6/B7).

**B.2 DRY-Helper `_stats_filtered(p_filters jsonb) RETURNS SETOF catches`**
- SECURITY DEFINER + `SET search_path=''` + eigener `auth.uid()`-Check + `WHERE c.user_id = v_uid AND deleted_at IS NULL AND draft = false` (deckt exakt den bestehenden Partial-Index — R2 B-Fund10).
- Zentrale Filter-Logik (ALLE Dimensionen + zeitraum). **Security:** KEIN EXECUTE für Clients; eigener auth.uid(); search_path='' (R1 A4).
- **Input-Validierung:** `monat`/`jahr` nur bei `~ '^[0-9]+$'`, `zeitraum.von/bis` nur bei `~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'` — sonst Filter ignorieren statt Exception (R1 C-F3/F4, DoS-Fix).

**B.3 Zeitzonen-/NULL-/Monats-Fixes (gelten für ALLE Funktionen)**
- Uhrzeit-Buckets: `EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna')` (R1 B1; Zeitzone auf Stack verifiziert OK — R2 B-Fund6).
- Wind/Druck/Wetter: NULL-Check VOR CASE → `Unbekannt` (R1 B2).
- Monat: `EXTRACT(MONTH ...)` numerisch 1–12, Frontend mappt via monthNamesDE (R1 B3).
- Zeitraum: Obergrenze `bis-Tag + INTERVAL '1 day'` (sub-second-sicher); Tagesgrenzen in Europe/Vienna (R1 A5).

**B.4 `stats_conditions` erweitern** — `bucket_rows` + `lufttemp` + `wassertemp`; Filter `lufttemp_bucket`, `wasser_temp_bucket` UND-korrekt; Output `buckets` + beide.

**B.5 `stats_insights(p_filters jsonb) → jsonb`**
- 4 Insights (beste_fangzeit/wetterlage/wassertemperatur/lufttemperatur) mit Kontext {fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct, stichproben_hinweis}.
- 'Unbekannt' ausgeschlossen (nur wenn ALLE unbekannt → „Keine Wetterdaten"); Mindestgrenze >= 3; stichproben_hinweis < 5 Fänge; `avg_gesamt IS NULL` (0 Fänge) → alle null + „Keine Fänge im gewählten Zeitraum".
- **Grants:** REVOKE PUBLIC/anon + GRANT authenticated (R1 A1/C-F1).

**B.6 `stats_beste_kombis` erweitern** — neue 2er-Kombis (uhrzeit+wetter, uhrzeit+wassertemp, wetter+wassertemp, wetter+lufttemp, wind+wetter, wind+wassertemp, wassertemp+lufttemp); 3er zurückgestellt; nutzt `_stats_filtered` + Helper.

**B.7 Grants-Sektion am ENDE von 0032** — REVOKE/GRANT für die 3 geänderten RPCs WIEDERHOLEN + stats_insights + Helper-REVOKE (R1 A1 — BLOKKER).

**B.8 Indizes:** Bestehende reichen; kein GIN/Expression (R1 A8).

### Frontend

**F.1 Fang erfassen (`fang-erfassen.astro` + `catch-service.ts`)**
- Feld **WASSERTEMPERATUR (°C)** in der **linken Spalte nach LÄNGE, vor FISCHART** (R2 C-Fund6): type number, step 0.1, min 0, max 40, Platzhalter `18.5`, Hinweis „Wassertemperatur am Gewässer".
- **`CatchInput` um `water_temp_c?: number` erweitern** (catch-service.ts; R2 C-Fund4).
- **`buildInputData()` um `water_temp_c` ergänzen** (leer → nicht senden/NULL; R2 C-Fund5).
- `data-testid="water-temp-input"`.

**F.2 Fang-Detail (`faenge/[id].astro`)** — WASSERTEMPERATUR als **eigene `<div>`-Zeile unter dem 4er-Grid** (border-t-separiert; 5. Spalte würde Grid brechen — R2 C-Fund7): `water_temp_c` + „ °C", sonst „—". `data-testid="water-temp-display"`.

**F.3 Statistik (`statistik.astro`)**
- **Zeitraum-Leiste** als eigener `<div>` **innerhalb der Bedingungen-Box, VOR `#conditions-rows`** (R2 C-Fund2): VON/BIS/ANWENDEN/ZURÜCKSETZEN.
- **Contract (R2 C-Fund1/3):** `p_filters.zeitraum = { von: "YYYY-MM-DD", bis: "YYYY-MM-DD" }` — nur anhängen, wenn BEIDE gesetzt; `state` um `zeitraum_von`/`zeitraum_bis`; `buildFilters(): Record<string, any>`.
- Datums-Werte direkt aus `<input type="date">.value` (keine JS-TZ-Konvertierung; R1 C-F7).
- **Insight-Karten (R2 C-Fund8 — größter Gap):** HTML-Container `#insights-cards` (rechte Spalte unter Kombinationen), Client-Funktion `renderInsights()`, **SSR-Load `stats_insights`** in initial load, `refreshAll()` um 4. RPC erweitern. **UX (Fund9):** 2×2 Grid, Karte = Titel + Wert + differenz-Badge (grün positiv/rot negativ) + stichproben_hinweis als dezenter `text-on-surface-variant`-Text; bei null + hinweis anzeigen.
- **Fehlerbehandlung (Fund12):** `Promise.allSettled()` für die 4 RPCs; Fehler je Block separat anzeigen; `conditions-error`-Container.
- **von > bis (Fund13):** Frontend-Warnung „Startdatum liegt nach Enddatum — keine Ergebnisse." statt leerer Empty-States.
- **Loading-State (Fund14):** Submit-Button deaktivieren + „LÄDT…" während refreshAll.
- **Debounce 200ms** auf Filterwechsel (R1 C-F8/Fund16).
- **XSS-Fix:** `set:html` → `set:text` für initial-conditions-data (R1 C-F11/Fund15).
- **data-testid (Fund11):** `zeitraum-von/-bis/-anwenden/-reset`, `insight-card-0..3`, `conditions-error`.
- WASSERTEMP- + LUFTTEMP-Dimensionen (5 Buckets je), alle Zeilen offen; Bucket-Labels an neues Naming angeglichen.

**F.4 i18n (R2 C-Fund10) — neue Keys in `i18n.ts` (de/en):**
`statistik.wassertemperatur`, `statistik.lufttemperatur`, `statistik.zeitraum_von/bis`, `statistik.anwenden`, `statistik.zuruecksetzen`, `statistik.insight_beste_fangzeit/wetterlage/wassertemp/lufttemp`, `statistik.keine_faenge`, `statistik.keine_wetterdaten`, `statistik.stichproben_hinweis` (Template „Nur {n} Fänge — wenig Aussagekraft"), `statistik.differenz_pct_besser/schlechter`, `statistik.von_nach_bis_warnung`, `fang_erfassen.wassertemperatur_label/hinweis`.

### Tests

**T.0 Test-Fixtures (R2 B-Fund4):** Test-spezifische INSERTs IN `0002_stats_v2_tests.sql` selbst (BEGIN; SET ROLE; INSERT ... VALUES mit `water_temp_c`) — isoliert vom Seed, landet nicht in Produktion.

**T.1 Backend (`tests/pgtap/0002_stats_v2_tests.sql`)**
- Bucket-Helper: Grenzwerte (Luft 4.9→<5, 5→5-10, 19.9→15-20, 20→>=20; Wasser 9.9→<10, 10→10-15, 24.9→20-25, 25→>=25), NULL→Unbekannt, **nicht-numerisch→Fehlerhaft**.
- `stats_conditions`: temp-Filter UND-korrekt; `buckets.lufttemp/wassertemp`; **weather=NULL → Unbekannt**.
- **Zeitzonen-Test:** Session UTC, Fang 06:00 Europe/Vienna → Bucket 6-12.
- Monats-Bucket numerisch + chronologisch.
- `stats_insights`: Seed, Kontext-Vorzeichen, 'Unbekannt' ausgeschlossen, Mindestgrenze (1/2 Fänge → null+Hinweis, 3+ → Daten), 0 Fänge → null+Hinweis, Gleichstand.
- `stats_beste_kombis`: neue Kombis, HAVING >= 2, kein NULL-Infekt.
- Zeitraum: Grenz-Tag inkl. sub-second, Jahreswechsel, von>bis → 0, von=bis → 1 Tag.
- **Injection/DoS:** monat='abc', jahr='12.5', zeitraum.von='not-a-date', druck_bucket='HACKED' → KEINE Exception.
- **Grants:** `has_function_privilege('authenticated','stats_insights(jsonb)','EXECUTE')` true; PUBLIC/anon false; Helper ohne EXECUTE (R1 C-F12; R2 B-Fund9).
- **RLS-Bypass:** User B sieht bei allen 4 RPCs 0 Fänge von User A.

**T.2 Frontend (Playwright/curl, data-testid-gestützt)**
- Fang erfassen: Feld sichtbar + speichert `water_temp_c` (E2E).
- Fang-Detail: Zeile sichtbar (Wert bzw. „—").
- statistik.astro: Zeitraum-Leiste wirkt (von/bis → RPC-Filter), 4 Insight-Karten mit Daten oder Hinweis, SSR initial gefüllt, von>bis-Warnung, Loading-State, kein XSS (set:text).

## 4. Entscheidungen

- **D1 DRY:** JA — `_stats_filtered` (3 Security-Regeln).
- **D2 Mindest-Fangzahl:** Insights >= 3, Kombis >= 2, stichproben_hinweis < 5.
- **D3 Kombi-Tiefe:** nur 2er in v1.
- **D4 Buckets Wasser:** 5 (`<10 / 10-15 / 15-20 / 20-25 / >=25`) — konsistent mit Stitch-Screen; leere Gruppen verzerren nicht.
- **D5 Naming:** OHNE Space (`<5`…`>=20` / `<10`…`>=25`); Bestand fixen; `'1015+'` entfernen.
- **Zeitzone:** `Europe/Vienna` für Uhrzeit-Buckets + Tagesgrenzen.
- **R2-Beschlüsse:** Backup+Rollback VOR Migration (7.0); Test-Fixtures isoliert in pgTAP (T.0); Grants-Verifikation in Abnahme; `data-testid` für E2E; `Promise.allSettled`.

## 5. Akzeptanzkriterien

- [ ] `catches.water_temp_c` existiert; Fang erfassen speichert (CatchInput + buildInputData), Fang-Detail zeigt (bzw. „—").
- [ ] `stats_conditions` liefert `buckets.lufttemp` + `buckets.wassertemp`; Uhrzeit-Buckets Europe/Vienna; NULL-Wetter = Unbekannt; keine Cast-Exception bei bösartigen Filtern.
- [ ] `stats_insights` liefert 4 Insights mit Kontext + stichproben_hinweis, 'Unbekannt' ausgeschlossen, Mindestgrenze 3.
- [ ] `stats_beste_kombis` findet neue Kombis; kein NULL-Infekt.
- [ ] **Grants nach CREATE OR REPLACE via `has_function_privilege` verifiziert** (PUBLIC/anon NEIN, authenticated JA; Helper ohne EXECUTE).
- [ ] statistik.astro: Zeitraum-Leiste (Contract {von,bis}, beide-gesetzt-Guard), beide Temp-Dimensionen, 4 Insight-Karten (Container + renderInsights + SSR + refresh), von>bis-Warnung, Loading, Debounce, kein set:html-XSS, data-testid.
- [ ] pgTAP grün (T.0/T.1); Frontend-E2E bestanden (T.2).

## 6. Nicht-Ziele (v1)

Kein ML/Modell · kein CSV-Export-Umbau · keine Mobile-Variante · keine 3er-Kombis · kein GIN-Index.

## 7. Build-Reihenfolge (nach Audit-Freigabe)

**7.0 Backup + Rollback-Vorbereitung (R2 B-Fund3/5 — BLOKKER)**
- a) Backup der 3 RPC-Originale: `docker exec supabase-db pg_dump -U supabase_admin --schema-only -Fp --function=stats_conditions --function=stats_drilldown --function=stats_beste_kombis postgres > /tmp/stats_rpcs_backup.sql`
- b) Rollback-Skript `0033_rollback_stats_v2.sql` vorbereiten (CREATE OR REPLACE der 0009-Originale + Grants aus 0010).
- c) Manuelles Backup: `infra/backup.sh` oder `docker exec supabase-db pg_dump -U supabase_admin -Fc -d postgres > /tmp/pre_0032_backup.dump`.
- d) Migration 0032: `docker exec supabase-db psql -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -f supabase/migrations/0032_stats_v2.sql` (zuerst Dev-DB, dann prod).
- e) Nach Erfolg: pgTAP `0002_stats_v2_tests.sql` (rot → grün).
- f) Bei Fehler: Rollback-Skript ODER pg_dump-Restore.

**7.1 Frontend:** Fang erfassen (F.1) → Fang-Detail (F.2) → statistik.astro (F.3) → i18n (F.4).
**7.2 E2E (T.2) + Live-Check :4321 (Dev-Server, Production-SSR :4321 nicht killen).**
**7.3 Commit + RESUME-Update.**

## 8. Changelog

- **v1:** Erstfassung. **v2:** Wassertemperatur + Lufttemperatur als getrennte Dimensionen. **v3:** 24 R1-Funde (Grants-Reset, Zeitzone, NULL-Buckets, Cast-DoS, Naming, DRY-Helper, Test-Lücken). **v4 FINAL:** R2 eingearbeitet — Operations (Backup/Rollback 7.0, ON_ERROR_STOP, T.0-Fixtures, Grants-Abnahme) + Frontend-Details (Contract zeitraum, #insights-cards/renderInsights/SSR/refresh, CatchInput/buildInputData, Fang-Detail-Layout, i18n-Keys, data-testid, allSettled, von>bis-Warnung, Loading).
