-- ============================================================================
-- carp24 Fangbuch — 0002_stats_v2_tests.sql
-- pgTAP-Suite: Statistik v2 (Wassertemperatur, Lufttemperatur, Insights,
--              Zeitzone, Fuzz/DoS, Grants, RLS-Bypass)
-- Anwendung: supabase_admin (Superuser), NACH 0032_stats_v2.sql
-- Muster:    0001_rls_tests.sql (set_config request.jwt.claim.sub + SET ROLE)
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(58);

-- ============================================================================
-- Seeding: auth.users (Trigger legt profiles automatisch an)
-- ============================================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'user_a_stats@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Angler A"}'::jsonb
);

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'user_b_stats@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Angler B"}'::jsonb
);

-- ============================================================================
-- T.0 Test-Fixtures für User A (isoliert, water_temp_c gesetzt)
-- Trigger set_catch_user_id_trg (0005) erzwingt user_id = auth.uid()
-- → JWT vor den INSERTs setzen
-- ============================================================================

SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- 4 Fänge morgens (6-12 Vienna), Wasser 18°, Luft 16°, Klar, Boilies
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-01T04:00:00Z', 'SPIEGEL', 20.5, 85, 'Testsee', 'Boilies', '{"temp_c":16,"pressure_hpa":1012,"wind_kmh":8,"weather_text":"Klar"}', 18),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-02T04:30:00Z', 'SPIEGEL', 18.2, 82, 'Testsee', 'Boilies', '{"temp_c":17,"pressure_hpa":1010,"wind_kmh":5,"weather_text":"Klar"}', 19),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-03T05:00:00Z', 'SPIEGEL', 22.1, 88, 'Testsee', 'Boilies', '{"temp_c":15,"pressure_hpa":1008,"wind_kmh":10,"weather_text":"Bewoelkt"}', 17),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-04T05:30:00Z', 'SPIEGEL', 16.8, 78, 'Testsee', 'Boilies', '{"temp_c":16,"pressure_hpa":1011,"wind_kmh":6,"weather_text":"Klar"}', 18);

-- 4 Fänge nachts (0-6 Vienna), Wasser 12°, Luft 8°, Regen, Mais
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-05T22:00:00Z', 'SPIEGEL', 10.2, 68, 'Testsee', 'Mais', '{"temp_c":8,"pressure_hpa":1002,"wind_kmh":22,"weather_text":"Regen"}', 12),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-06T22:30:00Z', 'SPIEGEL', 9.8, 66, 'Testsee', 'Mais', '{"temp_c":7,"pressure_hpa":1000,"wind_kmh":25,"weather_text":"Regen"}', 11),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-07T23:00:00Z', 'SPIEGEL', 11.5, 70, 'Testsee', 'Mais', '{"temp_c":9,"pressure_hpa":1003,"wind_kmh":20,"weather_text":"Regen"}', 12),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-08T23:30:00Z', 'SPIEGEL', 8.9, 65, 'Testsee', 'Mais', '{"temp_c":8,"pressure_hpa":1001,"wind_kmh":24,"weather_text":"Regen"}', 11);

-- 3 Fänge ohne Wetterdaten (weather NULL) → 'Unbekannt' Buckets
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-10T10:00:00Z', 'SPIEGEL', 14.0, 74, 'Testsee', 'Boilies', NULL, NULL),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-11T11:00:00Z', 'SPIEGEL', 15.5, 76, 'Testsee', 'Boilies', NULL, NULL),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-12T12:00:00Z', 'SPIEGEL', 13.2, 72, 'Testsee', 'Boilies', NULL, NULL);

-- Zeitzonen-Test-Fang: 06:00 Vienna = 04:00 UTC (muss in 6-12 landen, nicht 0-6)
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-15T04:00:00Z', 'SPIEGEL', 17.0, 80, 'Testsee', 'Boilies', '{"temp_c":15,"pressure_hpa":1013,"wind_kmh":7,"weather_text":"Klar"}', 16);

-- Grenz-Tag-Fang: 2026-06-20 23:59:59.5 UTC (sub-second, muss inklusive sein)
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-20T23:59:59.5Z', 'SPIEGEL', 12.0, 70, 'Testsee', 'Boilies', '{"temp_c":14,"pressure_hpa":1014,"wind_kmh":4,"weather_text":"Klar"}', 15);

-- Vienna-Tagesgrenzen-Fang: 00:30 Vienna am 21.06. = 2026-06-20 22:30 UTC
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-06-20T22:30:00Z', 'SPIEGEL', 19.0, 84, 'Testsee', 'Boilies', '{"temp_c":15,"pressure_hpa":1015,"wind_kmh":3,"weather_text":"Klar"}', 17);

-- Jahreswechsel-Fänge
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-12-31T12:00:00Z', 'SPIEGEL', 8.0, 60, 'Testsee', 'Mais', '{"temp_c":4,"pressure_hpa":1020,"wind_kmh":15,"weather_text":"Bewoelkt"}', 5),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-01T12:00:00Z', 'SPIEGEL', 9.0, 62, 'Testsee', 'Mais', '{"temp_c":5,"pressure_hpa":1021,"wind_kmh":12,"weather_text":"Bewoelkt"}', 6);

-- User B: 1 eigener Fang (RLS-Bypass-Test)
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, length_cm, water_name, bait, weather, water_temp_c)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-06-15T12:00:00Z', 'SPIEGEL', 30.0, 95, 'Fremdsee', 'Mais', '{"temp_c":20,"pressure_hpa":1010,"wind_kmh":10,"weather_text":"Klar"}', 22);

-- Fixtures sind draft (Default true) — für die Statistik sichtbar machen
UPDATE public.catches SET draft = false, deleted_at = NULL
WHERE user_id IN ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
  AND draft = true;

-- ============================================================================
-- Helper-Tests
-- ============================================================================

-- _to_bucket_lufttemp: Grenzwerte
SELECT is(public._to_bucket_lufttemp(0::numeric),    '<5',   'lufttemp 0 -> <5');
SELECT is(public._to_bucket_lufttemp(4.9::numeric),  '<5',   'lufttemp 4.9 -> <5');
SELECT is(public._to_bucket_lufttemp(5::numeric),    '5-10', 'lufttemp 5 -> 5-10');
SELECT is(public._to_bucket_lufttemp(19.9::numeric), '15-20','lufttemp 19.9 -> 15-20');
SELECT is(public._to_bucket_lufttemp(20::numeric),   '>=20', 'lufttemp 20 -> >=20');
SELECT is(public._to_bucket_lufttemp(40::numeric),   '>=20', 'lufttemp 40 -> >=20');
SELECT is(public._to_bucket_lufttemp(NULL::numeric), 'Unbekannt', 'lufttemp NULL -> Unbekannt');

-- _to_bucket_wassertemp: Grenzwerte
SELECT is(public._to_bucket_wassertemp(0::numeric),    '<10',   'wassertemp 0 -> <10');
SELECT is(public._to_bucket_wassertemp(9.9::numeric),  '<10',   'wassertemp 9.9 -> <10');
SELECT is(public._to_bucket_wassertemp(10::numeric),   '10-15', 'wassertemp 10 -> 10-15');
SELECT is(public._to_bucket_wassertemp(24.9::numeric), '20-25', 'wassertemp 24.9 -> 20-25');
SELECT is(public._to_bucket_wassertemp(25::numeric),   '>=25',  'wassertemp 25 -> >=25');
SELECT is(public._to_bucket_wassertemp(40::numeric),   '>=25',  'wassertemp 40 -> >=25');
SELECT is(public._to_bucket_wassertemp(NULL::numeric), 'Unbekannt', 'wassertemp NULL -> Unbekannt');

-- ============================================================================
-- stats_conditions (als User A)
-- ============================================================================

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- wasser_temp_bucket-Filter: 15-20 → 4 Morgen-Fänge (18/19/17/18) + Zeitzonen-Fang (16) + Vienna-Tagesgrenze (17) + Grenz-Tag-Fang (15) = 7
SELECT ok(
  (SELECT (public.stats_conditions('{"wasser_temp_bucket":"15-20"}'::jsonb) #>> '{total,fangzahl}')::int = 7),
  'stats_conditions: wasser_temp_bucket 15-20 liefert 7 Fänge'
);

-- lufttemp_bucket-Filter: <10 → 4 Nacht-Fänge (8/7/9/8) + Jahreswechsel (4/5) = 6
SELECT ok(
  (SELECT (public.stats_conditions('{"lufttemp_bucket":"<5"}'::jsonb) #>> '{total,fangzahl}')::int = 1),
  'stats_conditions: lufttemp_bucket <5 liefert genau 1 Fang (nur 4°C Jahreswechsel)'
);

-- buckets.wassertemp enthält korrekte Fangzahlen (ohne Filter)
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,wassertemp,15-20,fangzahl}')::int >= 6),
  'stats_conditions: buckets.wassertemp 15-20 Fangzahl vorhanden'
);

-- NULL-weather → Wind/Druck/Temp = Unbekannt (nicht 20+/1005-1015)
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,wind,Unbekannt,fangzahl}')::int = 3),
  'stats_conditions: NULL-weather -> wind Unbekannt (3 Fänge)'
);
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,lufttemp,Unbekannt,fangzahl}')::int = 3),
  'stats_conditions: NULL-weather -> lufttemp Unbekannt (3 Fänge)'
);
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,wassertemp,Unbekannt,fangzahl}')::int = 3),
  'stats_conditions: NULL-weather -> wassertemp Unbekannt (3 Fänge)'
);

-- Zeitzonen-Test: Fang 06:00 Vienna (04:00 UTC) landet in 6-12, nicht 0-6
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,uhrzeit,6-12,fangzahl}')::int >= 5),
  'stats_conditions: Uhrzeit-Bucket 6-12 enthält den 06:00-Vienna-Fang (Zeitzonen-Fix)'
);

-- Monat numerisch: Juni-Fänge in monat '6'
SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{buckets,monat,6,fangzahl}')::int >= 12),
  'stats_conditions: Monat 6 (Juni) numerisch vorhanden'
);

-- ============================================================================
-- stats_insights (als User A)
-- ============================================================================

-- beste_fangzeit: Morgen-Bucket 6-12 (Ø ~19,4) vs Nacht 0-6 (Ø ~10,1) → 6-12 gewinnt
SELECT is(
  (SELECT public.stats_insights('{}'::jsonb) #>> '{beste_fangzeit,wert}'),
  '6-12',
  'insights: beste_fangzeit = 6-12 (Ø höher als 0-6)'
);

-- beste_wetterlage: Klar (Ø ~18,6) vs Regen (Ø ~10,1) → Klar
SELECT is(
  (SELECT public.stats_insights('{}'::jsonb) #>> '{beste_wetterlage,wert}'),
  'Klar',
  'insights: beste_wetterlage = Klar'
);

-- beste_wassertemperatur: 15-20 (Ø ~18,5) vs 10-15 (Ø ~10,1) → 15-20
SELECT is(
  (SELECT public.stats_insights('{}'::jsonb) #>> '{beste_wassertemperatur,wert}'),
  '15-20',
  'insights: beste_wassertemperatur = 15-20'
);

-- beste_lufttemperatur: 15-20 (Ø ~18) vs <5 (Ø ~8,5) → 15-20
SELECT is(
  (SELECT public.stats_insights('{}'::jsonb) #>> '{beste_lufttemperatur,wert}'),
  '15-20',
  'insights: beste_lufttemperatur = 15-20'
);

-- 'Unbekannt' NICHT als bestes Insight: wassertemp Unbekannt hat Ø ~14,2 (3 Fänge) < 15-20
SELECT ok(
  (SELECT (public.stats_insights('{}'::jsonb) #>> '{beste_wassertemperatur,wert}') <> 'Unbekannt'),
  'insights: Unbekannt wird nicht als beste Wassertemperatur gewählt'
);

-- Kontext: differenz_pct vorhanden (positive Zahl für beste_fangzeit)
SELECT ok(
  (SELECT (public.stats_insights('{}'::jsonb) #>> '{beste_fangzeit,differenz_pct}')::numeric > 0),
  'insights: differenz_pct für beste_fangzeit > 0 (Morgen über Schnitt)'
);

-- stichproben_hinweis bei < 10 Fängen im besten Bucket
SELECT ok(
  (SELECT (public.stats_insights('{}'::jsonb) #>> '{beste_fangzeit,stichproben_hinweis}') IS NOT NULL),
  'insights: stichproben_hinweis vorhanden (beste_fangzeit hat < 10 Fänge)'
);

-- Mindestgrenze: Filter, der nur 1-2 Fänge ergibt → null + hinweis
-- z.B. jahr 2025 (1 Fang) → beste_fangzeit.wert null
SELECT ok(
  (SELECT (public.stats_insights('{"jahr":"2025"}'::jsonb) #>> '{beste_fangzeit,wert}') IS NULL),
  'insights: 1 Fang (jahr 2025) -> beste_fangzeit null + hinweis'
);
SELECT ok(
  (SELECT (public.stats_insights('{"jahr":"2025"}'::jsonb) #>> '{beste_fangzeit,hinweis}') IS NOT NULL),
  'insights: 1 Fang -> hinweis vorhanden'
);

-- 0 Fänge: Filter auf nicht existierendes Gewässer → alle null
SELECT ok(
  (SELECT (public.stats_insights('{"gewaesser":"GibtEsNicht"}'::jsonb) #>> '{beste_fangzeit,wert}') IS NULL),
  'insights: 0 Fänge -> beste_fangzeit null'
);

-- ============================================================================
-- stats_beste_kombis (als User A)
-- ============================================================================

-- Neue Kombi wetter+wassertemp vorhanden (Klar + 15-20 → 6 Fänge)
SELECT ok(
  (SELECT count(*) > 0
   FROM public.stats_beste_kombis('{}'::jsonb, 25) k
   WHERE k.kombi LIKE '%Klar%' AND k.kombi LIKE '%15-20%'),
  'kombis: wetter+wassertemp Kombination vorhanden'
);

-- Kombi-Boundary: Nacht-Kombi (uhrzeit 0-6 + wassertemp 10-15, 4 Fänge) existiert bei hohem Limit
SELECT ok(
  (SELECT count(*) > 0
   FROM public.stats_beste_kombis('{}'::jsonb, 100) k
   WHERE k.kombi LIKE '%uhrzeit=0-6%' AND k.kombi LIKE '%wassertemp=10-15%'),
  'kombis: uhrzeit 0-6 + wassertemp 10-15 vorhanden (4 Nacht-Fänge)'
);

-- ============================================================================
-- zeitraum (als User A)
-- ============================================================================

-- Grenz-Tag: von=bis=2026-06-20 → sub-second-Fang 23:59:59.5 inklusive + Vienna-Fänge am 21.6. (22:30 UTC 20.6.) exklusive? 
-- 2026-06-20 in Vienna = 2026-06-19T22:00Z bis 2026-06-20T21:59:59Z → sub-second-Fang 23:59:59.5Z ist AUSSERHALB (22:00 Vienna 21.6.)
-- Stattdessen: von=bis=2026-06-21 → enthält 00:30 Vienna Fang (20.6. 22:30Z) + sub-second (21.6. 01:59:59.5 Vienna) = 2 Fänge
SELECT ok(
  (SELECT (public.stats_conditions('{"zeitraum":{"von":"2026-06-21","bis":"2026-06-21"}}'::jsonb) #>> '{total,fangzahl}')::int = 2),
  'zeitraum: von=bis=21.06. liefert 2 Fänge (00:30 Vienna + 23:59:59.5 inklusive)'
);

-- Jahreswechsel: von=2025-12-31 bis=2026-01-01 → beide Fänge
SELECT ok(
  (SELECT (public.stats_conditions('{"zeitraum":{"von":"2025-12-31","bis":"2026-01-01"}}'::jsonb) #>> '{total,fangzahl}')::int = 2),
  'zeitraum: Jahreswechsel liefert beide Fänge'
);

-- von > bis → 0
SELECT ok(
  (SELECT (public.stats_conditions('{"zeitraum":{"von":"2026-06-30","bis":"2026-06-01"}}'::jsonb) #>> '{total,fangzahl}')::int = 0),
  'zeitraum: von > bis -> 0 Fänge'
);

-- von = bis = 2026-06-15 → genau 1 Fang (Zeitzonen-Fang 04:00Z = 06:00 Vienna)
SELECT ok(
  (SELECT (public.stats_conditions('{"zeitraum":{"von":"2026-06-15","bis":"2026-06-15"}}'::jsonb) #>> '{total,fangzahl}')::int = 1),
  'zeitraum: von=bis=15.06. liefert genau 1 Fang (Vienna-Tagesgrenze)'
);

-- ============================================================================
-- Fuzz / DoS (keine Exception — Filter wird ignoriert)
-- ============================================================================

SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"monat":"abc"}'::jsonb) $$,
  'fuzz: monat abc -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"monat":"9999999999999999999"}'::jsonb) $$,
  'fuzz: monat Overflow -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"jahr":"99"}'::jsonb) $$,
  'fuzz: jahr 99 -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"jahr":"12.5"}'::jsonb) $$,
  'fuzz: jahr 12.5 -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"zeitraum":{"von":"2026-13-01","bis":"2026-06-01"}}'::jsonb) $$,
  'fuzz: zeitraum.von 2026-13-01 -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"zeitraum":{"von":"2026-02-30","bis":"2026-06-01"}}'::jsonb) $$,
  'fuzz: zeitraum.von 2026-02-30 -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"zeitraum":{"von":"0000-01-31","bis":"2026-06-01"}}'::jsonb) $$,
  'fuzz: zeitraum.von 0000-01-31 -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"zeitraum":{"von":"not-a-date","bis":"2026-06-01"}}'::jsonb) $$,
  'fuzz: zeitraum.von not-a-date -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions((('{"wetter":"' || repeat('A', 10000) || '"}'::text)::jsonb)) $$,
  'fuzz: wetter 10KB String -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"druck_bucket":"HACKED"}'::jsonb) $$,
  'fuzz: druck_bucket HACKED -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_conditions('{"wasser_temp_bucket":"<script>"}'::jsonb) $$,
  'fuzz: wasser_temp_bucket script -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_insights('{"monat":"abc"}'::jsonb) $$,
  'fuzz: insights monat abc -> keine Exception'
);
SELECT lives_ok(
  $$ SELECT public.stats_beste_kombis('{"zeitraum":{"von":"2026-13-01","bis":"2026-06-01"}}'::jsonb, 5) $$,
  'fuzz: kombis zeitraum ungültig -> keine Exception'
);

RESET ROLE;

-- ============================================================================
-- Grants
-- ============================================================================

SELECT ok(
  has_function_privilege('authenticated', 'public.stats_insights(jsonb)', 'EXECUTE'),
  'grants: authenticated darf stats_insights ausführen'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.stats_insights(jsonb)', 'EXECUTE'),
  'grants: anon darf stats_insights NICHT ausführen'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'public._stats_filtered(jsonb)', 'EXECUTE'),
  'grants: _stats_filtered ohne EXECUTE für authenticated'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'public._to_bucket_wassertemp(numeric)', 'EXECUTE'),
  'grants: _to_bucket_wassertemp ohne EXECUTE für authenticated'
);

-- ============================================================================
-- RLS-Bypass: User B sieht 0 Fänge von User A
-- ============================================================================

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT ok(
  (SELECT (public.stats_conditions('{}'::jsonb) #>> '{total,fangzahl}')::int = 1),
  'rls: User B sieht nur seinen eigenen Fang (1)'
);
SELECT ok(
  (SELECT (public.stats_insights('{}'::jsonb) #>> '{beste_wassertemperatur,wert}') IS DISTINCT FROM '15-20'),
  'rls: User B Insight zeigt NICHT User-A-Bucket (15-20) — keine Daten-Leakage'
);
SELECT ok(
  (SELECT count(*) = 0 FROM public.stats_drilldown('{}'::jsonb) WHERE water_name = 'Testsee'),
  'rls: User B sieht keine Fänge aus Testsee (User A)'
);

RESET ROLE;

-- ============================================================================
-- Cleanup
-- ============================================================================

-- Performance-Test (optional, kommentiert — 10k Fänge):
-- BEGIN; INSERT INTO public.catches (user_id, catch_ts, species, weight_kg, water_name, weather, water_temp_c)
-- SELECT 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - (i || ' hours')::interval, 'SPIEGEL', 10 + (i % 20), 'Perfsee', '{"temp_c":15}', 15
-- FROM generate_series(1, 10000) i; SELECT clock_timestamp() ... (TODO: als separates Skript)

SELECT finish();
ROLLBACK;
