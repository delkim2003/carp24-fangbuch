-- 0032_stats_v2.sql
-- Statistik-Studio v2: Wassertemperatur, DRY-Helper, Insights, Kombis, Fixes
-- Reihenfolge: B.0 → B.1 → B.2 → B.4 → stats_drilldown → B.5 → B.6 → B.7
-- Alle Funktionen: SECURITY DEFINER, SET search_path = '', VOLATILE (auth.uid()).

-- ============================================================================
-- B.0 Wassertemperatur-Feld (MUSS VOR allen CREATE FUNCTION — RETURNS SETOF)
-- ============================================================================
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS water_temp_c numeric;

COMMENT ON COLUMN public.catches.water_temp_c
  IS 'Wassertemperatur in Grad Celsius, User-Eingabe, 0-40, NULL wenn unbekannt';

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'catches_water_temp_c_check'
      AND conrelid = 'public.catches'::regclass
  ) THEN
    ALTER TABLE public.catches
      ADD CONSTRAINT catches_water_temp_c_check
      CHECK (water_temp_c IS NULL OR (water_temp_c >= 0 AND water_temp_c <= 40));
  END IF;
END $do$;

-- ============================================================================
-- B.1 Bucket-Helper (IMMUTABLE, Exception-Guard, Naming OHNE Space)
-- ============================================================================

-- _to_bucket_lufttemp: <5 / 5-10 / 10-15 / 15-20 / >=20
CREATE OR REPLACE FUNCTION public._to_bucket_lufttemp(p_val numeric)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = ''
AS $fn$
BEGIN
  IF p_val IS NULL    THEN RETURN 'Unbekannt';
  ELSIF p_val < 5     THEN RETURN '<5';
  ELSIF p_val < 10    THEN RETURN '5-10';
  ELSIF p_val < 15    THEN RETURN '10-15';
  ELSIF p_val < 20    THEN RETURN '15-20';
  ELSE                      RETURN '>=20';
  END IF;
EXCEPTION WHEN OTHERS THEN RETURN 'Fehlerhaft';
END;
$fn$;

-- _to_bucket_wassertemp: <10 / 10-15 / 15-20 / 20-25 / >=25
CREATE OR REPLACE FUNCTION public._to_bucket_wassertemp(p_val numeric)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = ''
AS $fn$
BEGIN
  IF p_val IS NULL    THEN RETURN 'Unbekannt';
  ELSIF p_val < 10    THEN RETURN '<10';
  ELSIF p_val < 15    THEN RETURN '10-15';
  ELSIF p_val < 20    THEN RETURN '15-20';
  ELSIF p_val < 25    THEN RETURN '20-25';
  ELSE                      RETURN '>=25';
  END IF;
EXCEPTION WHEN OTHERS THEN RETURN 'Fehlerhaft';
END;
$fn$;

-- _to_bucket_wind: <5 / 5-10 / 10-20 / 20+ ; NULL → Unbekannt
CREATE OR REPLACE FUNCTION public._to_bucket_wind(p_val numeric)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = ''
AS $fn$
BEGIN
  IF p_val IS NULL    THEN RETURN 'Unbekannt';
  ELSIF p_val < 5     THEN RETURN '<5';
  ELSIF p_val < 10    THEN RETURN '5-10';
  ELSIF p_val < 20    THEN RETURN '10-20';
  ELSE                      RETURN '20+';
  END IF;
EXCEPTION WHEN OTHERS THEN RETURN 'Fehlerhaft';
END;
$fn$;

-- _to_bucket_druck: <1005 / 1005-1015 / >=1015 (OHNE Space, Fix)
CREATE OR REPLACE FUNCTION public._to_bucket_druck(p_val numeric)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = ''
AS $fn$
BEGIN
  IF p_val IS NULL     THEN RETURN 'Unbekannt';
  ELSIF p_val < 1005   THEN RETURN '<1005';
  ELSIF p_val >= 1015  THEN RETURN '>=1015';
  ELSE                       RETURN '1005-1015';
  END IF;
EXCEPTION WHEN OTHERS THEN RETURN 'Fehlerhaft';
END;
$fn$;

-- ============================================================================
-- B.2 DRY-Helper _stats_filtered(p_filters jsonb) → SETOF public.catches
-- SECURITY DEFINER, VOLATILE (auth.uid()), Input-Validierung (DoS-fest).
-- ============================================================================
CREATE OR REPLACE FUNCTION public._stats_filtered(p_filters jsonb)
RETURNS SETOF public.catches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
VOLATILE
AS $fn$
DECLARE
  v_uid              uuid;
  v_von              timestamptz;
  v_bis              timestamptz;
  v_monat            int;
  v_jahr             int;
  v_wetter           text;
  v_gewaesser        text;
  v_art              text;
  v_koeder           text;
  v_mond             text;
  v_druck_bucket     text;
  v_wind_bucket      text;
  v_uhrzeit_bucket   text;
  v_lufttemp_bucket  text;
  v_wassertemp_bucket text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- ── Input-Validierung: zeitraum.von ──
  IF p_filters->'zeitraum'->>'von' IS NOT NULL
     AND (p_filters->'zeitraum'->>'von') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    BEGIN
      IF TO_CHAR((p_filters->'zeitraum'->>'von')::date, 'YYYY-MM-DD')
         = p_filters->'zeitraum'->>'von' THEN
        v_von := ((p_filters->'zeitraum'->>'von') || 'T00:00:00')::timestamp
                 AT TIME ZONE 'Europe/Vienna';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_von := NULL;
    END;
  END IF;

  -- ── Input-Validierung: zeitraum.bis ──
  IF p_filters->'zeitraum'->>'bis' IS NOT NULL
     AND (p_filters->'zeitraum'->>'bis') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    BEGIN
      IF TO_CHAR((p_filters->'zeitraum'->>'bis')::date, 'YYYY-MM-DD')
         = p_filters->'zeitraum'->>'bis' THEN
        v_bis := ((p_filters->'zeitraum'->>'bis') || 'T00:00:00')::timestamp
                 AT TIME ZONE 'Europe/Vienna';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_bis := NULL;
    END;
  END IF;

  -- ── Input-Validierung: monat ──
  IF p_filters->>'monat' IS NOT NULL
     AND (p_filters->>'monat') ~ '^([1-9]|1[0-2])$' THEN
    v_monat := (p_filters->>'monat')::int;
  END IF;

  -- ── Input-Validierung: jahr ──
  IF p_filters->>'jahr' IS NOT NULL
     AND (p_filters->>'jahr') ~ '^[0-9]{4}$' THEN
    v_jahr := (p_filters->>'jahr')::int;
  END IF;

  -- ── Input-Validierung: String-Filter (Länge ≤ 256, kein Whitespace-only) ──
  IF p_filters->>'wetter' IS NOT NULL
     AND char_length(p_filters->>'wetter') <= 256
     AND btrim(p_filters->>'wetter') <> '' THEN
    v_wetter := p_filters->>'wetter';
  END IF;

  IF p_filters->>'gewaesser' IS NOT NULL
     AND char_length(p_filters->>'gewaesser') <= 256
     AND btrim(p_filters->>'gewaesser') <> '' THEN
    v_gewaesser := p_filters->>'gewaesser';
  END IF;

  IF p_filters->>'art' IS NOT NULL
     AND char_length(p_filters->>'art') <= 256
     AND btrim(p_filters->>'art') <> '' THEN
    v_art := p_filters->>'art';
  END IF;

  IF p_filters->>'koeder' IS NOT NULL
     AND char_length(p_filters->>'koeder') <= 256
     AND btrim(p_filters->>'koeder') <> '' THEN
    v_koeder := p_filters->>'koeder';
  END IF;

  -- ── Bucket-Filter (direkt durchgereicht, ELSE true im CASE) ──
  v_mond            := p_filters->>'mond';
  v_druck_bucket    := p_filters->>'druck_bucket';
  v_wind_bucket     := p_filters->>'wind_bucket';
  v_uhrzeit_bucket  := p_filters->>'uhrzeit_bucket';
  v_lufttemp_bucket := p_filters->>'lufttemp_bucket';
  v_wassertemp_bucket := p_filters->>'wasser_temp_bucket';

  RETURN QUERY
  SELECT c.*
  FROM public.catches c
  WHERE c.user_id = v_uid
    AND c.deleted_at IS NULL
    AND c.draft = false
    -- Mond
    AND (v_mond IS NULL OR c.weather->>'moon_text' = v_mond)
    -- Druck-Bucket
    AND (v_druck_bucket IS NULL
         OR CASE v_druck_bucket
              WHEN '<1005'     THEN (c.weather->>'pressure_hpa')::numeric < 1005
              WHEN '1005-1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1005
                                  AND (c.weather->>'pressure_hpa')::numeric < 1015
              WHEN '>=1015'    THEN (c.weather->>'pressure_hpa')::numeric >= 1015
              WHEN '>= 1015'   THEN (c.weather->>'pressure_hpa')::numeric >= 1015
              WHEN '1015+'     THEN (c.weather->>'pressure_hpa')::numeric >= 1015
              ELSE true
            END)
    -- Wind-Bucket
    AND (v_wind_bucket IS NULL
         OR CASE v_wind_bucket
              WHEN '<5'    THEN (c.weather->>'wind_kmh')::numeric < 5
              WHEN '5-10'  THEN (c.weather->>'wind_kmh')::numeric >= 5
                              AND (c.weather->>'wind_kmh')::numeric < 10
              WHEN '10-20' THEN (c.weather->>'wind_kmh')::numeric >= 10
                              AND (c.weather->>'wind_kmh')::numeric < 20
              WHEN '20+'   THEN (c.weather->>'wind_kmh')::numeric >= 20
              ELSE true
            END)
    -- Wetter (ILIKE Teilstring)
    AND (v_wetter IS NULL
         OR c.weather->>'weather_text' ILIKE ('%' || v_wetter || '%'))
    -- Gewässer (ILIKE Teilstring)
    AND (v_gewaesser IS NULL
         OR c.water_name ILIKE ('%' || v_gewaesser || '%'))
    -- Art: species_enum ODER species_custom
    AND (v_art IS NULL
         OR c.species::text = v_art
         OR c.species_custom ILIKE ('%' || v_art || '%'))
    -- Köder (ILIKE Teilstring)
    AND (v_koeder IS NULL
         OR c.bait ILIKE ('%' || v_koeder || '%'))
    -- Monat (numerisch, Vienna)
    AND (v_monat IS NULL
         OR EXTRACT(MONTH FROM c.catch_ts AT TIME ZONE 'Europe/Vienna')::int = v_monat)
    -- Jahr (numerisch, Vienna)
    AND (v_jahr IS NULL
         OR EXTRACT(YEAR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna')::int = v_jahr)
    -- Uhrzeit-Bucket (Vienna)
    AND (v_uhrzeit_bucket IS NULL
         OR CASE v_uhrzeit_bucket
              WHEN '0-6'   THEN EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') >= 0
                              AND EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') < 6
              WHEN '6-12'  THEN EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') >= 6
                              AND EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') < 12
              WHEN '12-18' THEN EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') >= 12
                              AND EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') < 18
              WHEN '18-24' THEN EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') >= 18
              ELSE true
            END)
    -- Lufttemperatur-Bucket (via Helper)
    AND (v_lufttemp_bucket IS NULL
         OR public._to_bucket_lufttemp((c.weather->>'temp_c')::numeric) = v_lufttemp_bucket)
    -- Wassertemperatur-Bucket (via Helper)
    AND (v_wassertemp_bucket IS NULL
         OR public._to_bucket_wassertemp(c.water_temp_c) = v_wassertemp_bucket)
    -- Zeitraum (Vienna-Tagesgrenzen, sub-second-sicher)
    AND (v_von IS NULL OR c.catch_ts >= v_von)
    AND (v_bis IS NULL OR c.catch_ts < (v_bis + INTERVAL '1 day'));
END;
$fn$;

-- ============================================================================
-- B.4 stats_conditions(p_filters jsonb) → jsonb
-- Erweitert: lufttemp + wassertemp Buckets, Helper statt inline-CASE,
-- EXTRACT(MONTH) numerisch, Uhrzeit Vienna, statement_timeout.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_conditions(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
VOLATILE
AS $fn$
DECLARE
  v_uid    uuid;
  v_result jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SET LOCAL statement_timeout = '5s';

  WITH base AS (
    SELECT * FROM public._stats_filtered(p_filters)
  ),
  total AS (
    SELECT
      count(*)::int                           AS fangzahl,
      round(avg(weight_kg), 1)               AS avg_gewicht,
      round(max(weight_kg), 1)               AS max_gewicht,
      round(COALESCE(sum(weight_kg), 0), 1)  AS sum_gewicht
    FROM base
  ),
  bucket_rows AS (
    SELECT
      COALESCE(weather->>'moon_text', 'Unbekannt')                AS mond,
      public._to_bucket_druck((weather->>'pressure_hpa')::numeric) AS druck,
      public._to_bucket_wind((weather->>'wind_kmh')::numeric)     AS wind,
      COALESCE(weather->>'weather_text', 'Unbekannt')             AS wetter,
      COALESCE(water_name, 'Unbekannt')                           AS gewaesser,
      CASE
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 6  THEN '0-6'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 12 THEN '6-12'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 18 THEN '12-18'
        ELSE '18-24'
      END                                                          AS uhrzeit,
      EXTRACT(MONTH FROM catch_ts AT TIME ZONE 'Europe/Vienna')::int AS monat_num,
      COALESCE(species_custom, species::text, 'Unbekannt')        AS art,
      COALESCE(bait, 'Unbekannt')                                  AS koeder,
      public._to_bucket_lufttemp((weather->>'temp_c')::numeric)   AS lufttemp,
      public._to_bucket_wassertemp(water_temp_c)                   AS wassertemp,
      weight_kg
    FROM base
  ),
  mond_agg AS (
    SELECT jsonb_object_agg(mond, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT mond, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY mond
    ) sub
  ),
  druck_agg AS (
    SELECT jsonb_object_agg(druck, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT druck, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY druck
    ) sub
  ),
  wind_agg AS (
    SELECT jsonb_object_agg(wind, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT wind, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY wind
    ) sub
  ),
  wetter_agg AS (
    SELECT jsonb_object_agg(wetter, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT wetter, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY wetter
    ) sub
  ),
  gewaesser_agg AS (
    SELECT jsonb_object_agg(gewaesser, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT gewaesser, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY gewaesser
    ) sub
  ),
  uhrzeit_agg AS (
    SELECT jsonb_object_agg(uhrzeit, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT uhrzeit, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY uhrzeit
    ) sub
  ),
  monat_agg AS (
    SELECT jsonb_object_agg(monat_num::text, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT monat_num, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY monat_num ORDER BY monat_num
    ) sub
  ),
  art_agg AS (
    SELECT jsonb_object_agg(art, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT art, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY art
    ) sub
  ),
  koeder_agg AS (
    SELECT jsonb_object_agg(koeder, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT koeder, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY koeder
    ) sub
  ),
  lufttemp_agg AS (
    SELECT jsonb_object_agg(lufttemp, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT lufttemp, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY lufttemp
    ) sub
  ),
  wassertemp_agg AS (
    SELECT jsonb_object_agg(wassertemp, jsonb_build_object(
      'fangzahl', fangzahl, 'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT wassertemp, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY wassertemp
    ) sub
  )
  SELECT jsonb_build_object(
    'total', jsonb_build_object(
      'fangzahl',    t.fangzahl,
      'avg_gewicht', t.avg_gewicht,
      'max_gewicht', t.max_gewicht,
      'sum_gewicht', t.sum_gewicht
    ),
    'buckets', jsonb_build_object(
      'mond',       COALESCE(m.d,  '{}'::jsonb),
      'druck',      COALESCE(d.d,  '{}'::jsonb),
      'wind',       COALESCE(w.d,  '{}'::jsonb),
      'wetter',     COALESCE(we.d, '{}'::jsonb),
      'gewaesser',  COALESCE(g.d,  '{}'::jsonb),
      'uhrzeit',    COALESCE(u.d,  '{}'::jsonb),
      'monat',      COALESCE(mo.d, '{}'::jsonb),
      'art',        COALESCE(a.d,  '{}'::jsonb),
      'koeder',     COALESCE(k.d,  '{}'::jsonb),
      'lufttemp',   COALESCE(lt.d, '{}'::jsonb),
      'wassertemp', COALESCE(wt.d, '{}'::jsonb)
    )
  ) INTO v_result
  FROM total t
  CROSS JOIN mond_agg m
  CROSS JOIN druck_agg d
  CROSS JOIN wind_agg w
  CROSS JOIN wetter_agg we
  CROSS JOIN gewaesser_agg g
  CROSS JOIN uhrzeit_agg u
  CROSS JOIN monat_agg mo
  CROSS JOIN art_agg a
  CROSS JOIN koeder_agg k
  CROSS JOIN lufttemp_agg lt
  CROSS JOIN wassertemp_agg wt;

  RETURN v_result;
END;
$fn$;

-- ============================================================================
-- stats_drilldown(p_filters jsonb) → TABLE
-- Nutzt _stats_filtered (DRY), water_temp_c im Output, statement_timeout.
-- HINWEIS: DROP + CREATE statt CREATE OR REPLACE — Rückgabetyp (OUT-Tabelle)
-- ändert sich durch water_temp_c und ist in PG nicht per OR REPLACE änderbar.
-- ============================================================================
DROP FUNCTION IF EXISTS public.stats_drilldown(jsonb);
CREATE FUNCTION public.stats_drilldown(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(
  id           uuid,
  catch_ts     timestamptz,
  water_name   text,
  species      text,
  weight_kg    numeric,
  length_cm    numeric,
  bait         text,
  weather      jsonb,
  water_temp_c numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
VOLATILE
AS $fn$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SET LOCAL statement_timeout = '5s';

  RETURN QUERY
  SELECT c.id, c.catch_ts, c.water_name,
         COALESCE(c.species_custom, c.species::text) AS species,
         c.weight_kg, c.length_cm, c.bait, c.weather, c.water_temp_c
  FROM public._stats_filtered(p_filters) c
  ORDER BY c.catch_ts DESC
  LIMIT 200;
END;
$fn$;

-- ============================================================================
-- B.5 stats_insights(p_filters jsonb) → jsonb
-- 5 Insights: beste_fangzeit, beste_wetterlage, beste_wassertemperatur,
--             beste_lufttemperatur, beste_koeder_kombi.
-- Kontext: fangzahl, avg_gewicht, avg_gesamt, differenz_kg, differenz_pct,
--          stichproben_hinweis.
-- 'Unbekannt' ausgeschlossen, Mindestgrenze >= 3, Tie-Breaking.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_insights(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
VOLATILE
AS $fn$
DECLARE
  v_uid                uuid;
  v_total_fangzahl     int;
  v_total_avg_gewicht  numeric;
  v_ins_fangzeit       jsonb;
  v_ins_wetterlage     jsonb;
  v_ins_wassertemp     jsonb;
  v_ins_lufttemp       jsonb;
  v_ins_koeder         jsonb;
  v_null_hint          jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SET LOCAL statement_timeout = '5s';

  -- ── Gesamt-Statistik ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters))
  SELECT count(*)::int, round(avg(weight_kg), 1)
  INTO v_total_fangzahl, v_total_avg_gewicht
  FROM base;

  -- ── 0 Fänge → alle null + Hinweis ──
  IF v_total_fangzahl = 0 THEN
    v_null_hint := jsonb_build_object(
      'wert', null,
      'fangzahl', 0,
      'avg_gewicht', null,
      'avg_gesamt', null,
      'differenz_kg', null,
      'differenz_pct', null,
      'stichproben_hinweis', null,
      'hinweis', 'Keine Faenge im gewaehlten Zeitraum'
    );
    RETURN jsonb_build_object(
      'beste_fangzeit',         v_null_hint,
      'beste_wetterlage',       v_null_hint,
      'beste_wassertemperatur', v_null_hint,
      'beste_lufttemperatur',   v_null_hint,
      'beste_koeder_kombi',     v_null_hint
    );
  END IF;

  -- ── 1. beste_fangzeit (Uhrzeit-Bucket, Vienna) ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  dim AS (
    SELECT
      CASE
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 6  THEN '0-6'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 12 THEN '6-12'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 18 THEN '12-18'
        ELSE '18-24'
      END AS bucket,
      weight_kg
    FROM base
  ),
  agg AS (
    SELECT bucket, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
    FROM dim
    GROUP BY bucket
    HAVING count(*) >= 3
  )
  SELECT CASE WHEN EXISTS (SELECT 1 FROM agg) THEN jsonb_build_object(
    'wert',               (array_agg(bucket ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'fangzahl',           (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gewicht',        (array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gesamt',         v_total_avg_gewicht,
    'differenz_kg',       round((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht, 1),
    'differenz_pct',      CASE WHEN v_total_avg_gewicht > 0
                          THEN round(((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht) / v_total_avg_gewicht * 100, 1)
                          ELSE null END,
    'stichproben_hinweis', CASE WHEN (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] < 10
                           THEN 'Weniger als 10 Faenge — Ergebnis mit Vorsicht geniessen' ELSE null END
  ) ELSE jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten (mindestens 3 Faenge benoetigt)') END
  INTO v_ins_fangzeit
  FROM agg;

  -- ── 2. beste_wetterlage ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  dim AS (
    SELECT COALESCE(weather->>'weather_text', 'Unbekannt') AS bucket, weight_kg
    FROM base
  ),
  agg AS (
    SELECT bucket, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
    FROM dim
    WHERE bucket <> 'Unbekannt'
    GROUP BY bucket
    HAVING count(*) >= 3
  )
  SELECT CASE WHEN EXISTS (SELECT 1 FROM agg) THEN jsonb_build_object(
    'wert',               (array_agg(bucket ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'fangzahl',           (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gewicht',        (array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gesamt',         v_total_avg_gewicht,
    'differenz_kg',       round((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht, 1),
    'differenz_pct',      CASE WHEN v_total_avg_gewicht > 0
                          THEN round(((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht) / v_total_avg_gewicht * 100, 1)
                          ELSE null END,
    'stichproben_hinweis', CASE WHEN (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] < 10
                           THEN 'Weniger als 10 Faenge — Ergebnis mit Vorsicht geniessen' ELSE null END
  ) ELSE jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten (mindestens 3 Faenge benoetigt)') END
  INTO v_ins_wetterlage
  FROM agg;

  -- ── 3. beste_wassertemperatur ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  dim AS (
    SELECT public._to_bucket_wassertemp(water_temp_c) AS bucket, weight_kg
    FROM base
  ),
  agg AS (
    SELECT bucket, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
    FROM dim
    WHERE bucket <> 'Unbekannt'
    GROUP BY bucket
    HAVING count(*) >= 3
  )
  SELECT CASE WHEN EXISTS (SELECT 1 FROM agg) THEN jsonb_build_object(
    'wert',               (array_agg(bucket ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'fangzahl',           (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gewicht',        (array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gesamt',         v_total_avg_gewicht,
    'differenz_kg',       round((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht, 1),
    'differenz_pct',      CASE WHEN v_total_avg_gewicht > 0
                          THEN round(((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht) / v_total_avg_gewicht * 100, 1)
                          ELSE null END,
    'stichproben_hinweis', CASE WHEN (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] < 10
                           THEN 'Weniger als 10 Faenge — Ergebnis mit Vorsicht geniessen' ELSE null END
  ) ELSE jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten (mindestens 3 Faenge benoetigt)') END
  INTO v_ins_wassertemp
  FROM agg;

  -- ── 4. beste_lufttemperatur ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  dim AS (
    SELECT public._to_bucket_lufttemp((weather->>'temp_c')::numeric) AS bucket, weight_kg
    FROM base
  ),
  agg AS (
    SELECT bucket, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
    FROM dim
    WHERE bucket <> 'Unbekannt'
    GROUP BY bucket
    HAVING count(*) >= 3
  )
  SELECT CASE WHEN EXISTS (SELECT 1 FROM agg) THEN jsonb_build_object(
    'wert',               (array_agg(bucket ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'fangzahl',           (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gewicht',        (array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gesamt',         v_total_avg_gewicht,
    'differenz_kg',       round((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht, 1),
    'differenz_pct',      CASE WHEN v_total_avg_gewicht > 0
                          THEN round(((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht) / v_total_avg_gewicht * 100, 1)
                          ELSE null END,
    'stichproben_hinweis', CASE WHEN (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] < 10
                           THEN 'Weniger als 10 Faenge — Ergebnis mit Vorsicht geniessen' ELSE null END
  ) ELSE jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten (mindestens 3 Faenge benoetigt)') END
  INTO v_ins_lufttemp
  FROM agg;

  -- ── 5. beste_koeder_kombi (bestes einzelnes Koeder) ──
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  dim AS (
    SELECT COALESCE(bait, 'Unbekannt') AS bucket, weight_kg
    FROM base
  ),
  agg AS (
    SELECT bucket, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
    FROM dim
    WHERE bucket <> 'Unbekannt'
    GROUP BY bucket
    HAVING count(*) >= 3
  )
  SELECT CASE WHEN EXISTS (SELECT 1 FROM agg) THEN jsonb_build_object(
    'wert',               (array_agg(bucket ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'fangzahl',           (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gewicht',        (array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1],
    'avg_gesamt',         v_total_avg_gewicht,
    'differenz_kg',       round((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht, 1),
    'differenz_pct',      CASE WHEN v_total_avg_gewicht > 0
                          THEN round(((array_agg(avg_gewicht ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] - v_total_avg_gewicht) / v_total_avg_gewicht * 100, 1)
                          ELSE null END,
    'stichproben_hinweis', CASE WHEN (array_agg(fangzahl ORDER BY avg_gewicht DESC, fangzahl DESC, bucket ASC))[1] < 10
                           THEN 'Weniger als 10 Faenge — Ergebnis mit Vorsicht geniessen' ELSE null END
  ) ELSE jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten (mindestens 3 Faenge benoetigt)') END
  INTO v_ins_koeder
  FROM agg;

  RETURN jsonb_build_object(
    'beste_fangzeit',         COALESCE(v_ins_fangzeit,   jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten')),
    'beste_wetterlage',       COALESCE(v_ins_wetterlage, jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten')),
    'beste_wassertemperatur', COALESCE(v_ins_wassertemp, jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten')),
    'beste_lufttemperatur',   COALESCE(v_ins_lufttemp,   jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten')),
    'beste_koeder_kombi',     COALESCE(v_ins_koeder,     jsonb_build_object('wert', null, 'hinweis', 'Nicht genuegend Daten'))
  );
END;
$fn$;

-- ============================================================================
-- B.6 stats_beste_kombis(p_filters jsonb, p_limit integer) → TABLE
-- Erweitert: +7 neue 2er-Kombis (uhrzeit+wetter, uhrzeit+wassertemp,
-- wetter+wassertemp, wetter+lufttemp, wind+wetter, wind+wassertemp,
-- wassertemp+lufttemp). Nutzt Helper, Vienna-Uhrzeit, statement_timeout.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_beste_kombis(
  p_filters jsonb   DEFAULT '{}'::jsonb,
  p_limit   integer DEFAULT 5
)
RETURNS TABLE(
  kombi       text,
  fangzahl    integer,
  avg_gewicht numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
VOLATILE
AS $fn$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SET LOCAL statement_timeout = '5s';

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public._stats_filtered(p_filters)
  ),
  with_dims AS (
    SELECT
      COALESCE(weather->>'moon_text', 'Unbekannt')                  AS mond_val,
      public._to_bucket_druck((weather->>'pressure_hpa')::numeric)  AS druck_val,
      public._to_bucket_wind((weather->>'wind_kmh')::numeric)       AS wind_val,
      COALESCE(weather->>'weather_text', 'Unbekannt')               AS wetter_val,
      COALESCE(bait, 'Unbekannt')                                    AS koeder_val,
      CASE
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 6  THEN '0-6'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 12 THEN '6-12'
        WHEN EXTRACT(HOUR FROM catch_ts AT TIME ZONE 'Europe/Vienna') < 18 THEN '12-18'
        ELSE '18-24'
      END                                                           AS uhrzeit_val,
      public._to_bucket_wassertemp(water_temp_c)                    AS wassertemp_val,
      public._to_bucket_lufttemp((weather->>'temp_c')::numeric)     AS lufttemp_val,
      weight_kg
    FROM base
  ),
  kombis AS (
    SELECT p.kombi, count(*)::int AS fangzahl, round(avg(p.weight_kg), 1) AS avg_gewicht
    FROM (
      -- Bestehende 6 Kombis
      SELECT 'mond=' || mond_val || ' + druck=' || druck_val AS kombi, weight_kg FROM with_dims
      UNION ALL
      SELECT 'mond=' || mond_val || ' + wetter=' || wetter_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'mond=' || mond_val || ' + koeder=' || koeder_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'druck=' || druck_val || ' + wetter=' || wetter_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'druck=' || druck_val || ' + koeder=' || koeder_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wetter=' || wetter_val || ' + koeder=' || koeder_val, weight_kg FROM with_dims
      -- Neue 7 Kombis (B.6)
      UNION ALL
      SELECT 'uhrzeit=' || uhrzeit_val || ' + wetter=' || wetter_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'uhrzeit=' || uhrzeit_val || ' + wassertemp=' || wassertemp_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wetter=' || wetter_val || ' + wassertemp=' || wassertemp_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wetter=' || wetter_val || ' + lufttemp=' || lufttemp_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wind=' || wind_val || ' + wetter=' || wetter_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wind=' || wind_val || ' + wassertemp=' || wassertemp_val, weight_kg FROM with_dims
      UNION ALL
      SELECT 'wassertemp=' || wassertemp_val || ' + lufttemp=' || lufttemp_val, weight_kg FROM with_dims
    ) p
    GROUP BY p.kombi
    HAVING count(*) >= 2
  )
  SELECT k.kombi, k.fangzahl, k.avg_gewicht
  FROM kombis k
  ORDER BY k.avg_gewicht DESC, k.fangzahl DESC, k.kombi ASC
  LIMIT p_limit;
END;
$fn$;

-- ============================================================================
-- B.7 Grants-Sektion (Defense-in-Depth — PG14+ behält ACLs bei CREATE OR REPLACE)
-- ============================================================================

-- RPCs: REVOKE PUBLIC/anon, GRANT authenticated
REVOKE EXECUTE ON FUNCTION public.stats_conditions(jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_conditions(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_drilldown(jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_drilldown(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_insights(jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_insights(jsonb) TO authenticated;

-- Interne Helper: KEIN EXECUTE für PUBLIC/anon/authenticated
REVOKE EXECUTE ON FUNCTION public._stats_filtered(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._to_bucket_lufttemp(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._to_bucket_wassertemp(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._to_bucket_wind(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._to_bucket_druck(numeric) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public._stats_filtered(jsonb)
  IS 'DRY-Helper: gefilterte Catches des authentifizierten Users. Kein externer EXECUTE.';
COMMENT ON FUNCTION public.stats_insights(jsonb)
  IS '5 Wetter-Insights mit Kontext. EXECUTE nur authenticated.';
COMMENT ON FUNCTION public.stats_conditions(jsonb)
  IS 'Aggregat-Statistik + Bucket-Verteilungen (inkl. Luft-/Wassertemperatur). EXECUTE nur authenticated.';
COMMENT ON FUNCTION public.stats_drilldown(jsonb)
  IS 'Gefilterte Fangliste (max 200). EXECUTE nur authenticated.';
COMMENT ON FUNCTION public.stats_beste_kombis(jsonb, integer)
  IS 'Beste 2er-Kombis nach avg_gewicht (13 Kombis). EXECUTE nur authenticated.';

-- ============================================================================
-- 0032_stats_v2.sql erfolgreich angewendet.
-- ============================================================================
