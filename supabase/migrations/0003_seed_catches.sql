-- 0003_seed_catches.sql
-- Seed: 18 Beispiel-Fänge für Statistik-Studio
-- WICHTIG: User wird via API erstellt (Task 1.4-Test-User), dann per Script eingefügt.
-- Dieses Script nimmt den NEUESTEN User aus auth.users automatisch.

INSERT INTO public.catches (user_id, water_id, catch_ts, species, weight_kg, length_cm, bait, method, notes, photos, weather, weather_auto, draft, client_uuid)
SELECT
  u.id,
  w.id,
  v.ts,
  v.sp::public.species_enum,
  v.gew,
  v.laen,
  v.koeder,
  v.methode,
  NULL::text AS notiz,
  ARRAY[]::text[],
  NULL,
  false,
  false,
  gen_random_uuid()
FROM (VALUES
  ('2025-03-12T16:45:00+01:00'::timestamptz, 'SPIEGEL',  13.5,  84, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-04-05T18:00:00+02:00'::timestamptz, 'SPIEGEL',  15.3,  88, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-06-07T21:00:00+02:00'::timestamptz, 'SPIEGEL',  19.4,  97, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-07-19T05:45:00+02:00'::timestamptz, 'SPIEGEL',  18.7,  94, 'Pop-Up', 'Grundmontage', 'Silbersee Villach'),
  ('2025-08-04T23:00:00+02:00'::timestamptz, 'SCHUPPEN', 20.9, 101, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-09-09T18:20:00+02:00'::timestamptz, 'SPIEGEL',  21.4, 102, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-10-12T18:30:00+02:00'::timestamptz, 'SPIEGEL',  18.4,  92, 'Boilie', 'Grundmontage', 'Silbersee Villach'),
  ('2025-05-16T07:10:00+02:00'::timestamptz, 'LEDER',    16.8,  90, 'Boilie', 'Grundmontage', 'Neusiedler See'),
  ('2025-05-24T22:40:00+02:00'::timestamptz, 'SPIEGEL',  22.1, 105, 'Boilie', 'Grundmontage', 'Neusiedler See'),
  ('2025-06-15T04:55:00+02:00'::timestamptz, 'SCHUPPEN', 14.2,  86, 'Pop-Up', 'Grundmontage', 'Neusiedler See'),
  ('2025-08-22T19:30:00+02:00'::timestamptz, 'SPIEGEL',  17.9,  96, 'Boilie', 'Grundmontage', 'Neusiedler See'),
  ('2025-04-18T15:20:00+02:00'::timestamptz, 'AMUR',     12.8,  80, 'Boilie', 'Grundmontage', 'Wörthersee'),
  ('2025-06-28T06:45:00+02:00'::timestamptz, 'SPIEGEL',  23.5, 108, 'Boilie', 'Grundmontage', 'Wörthersee'),
  ('2025-07-30T20:15:00+02:00'::timestamptz, 'SPIEGEL',  16.4,  91, 'Boilie', 'Grundmontage', 'Wörthersee'),
  ('2025-09-01T05:30:00+02:00'::timestamptz, 'SCHUPPEN', 15.7,  88, 'Boilie', 'Grundmontage', 'Faaker See'),
  ('2025-03-28T17:45:00+01:00'::timestamptz, 'SPIEGEL',  11.9,  78, 'Boilie', 'Grundmontage', 'Ossiacher See'),
  ('2025-06-05T22:10:00+02:00'::timestamptz, 'LEDER',    13.6,  82, 'Boilie', 'Grundmontage', 'Ossiacher See'),
  ('2025-10-05T18:00:00+02:00'::timestamptz, 'SPIEGEL',  19.8,  99, 'Boilie', 'Grundmontage', 'Traunsee')
) AS v(ts, sp, gew, laen, koeder, methode, gewaesser)
JOIN auth.users u ON u.id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
JOIN public.waters w ON w.name = v.gewaesser;
