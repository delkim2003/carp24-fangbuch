-- 0033_rollback_stats_v2.sql
-- Rollback für 0032_stats_v2.sql
-- Stellt 0009-Originale wieder her, entfernt neue Funktionen + water_temp_c.

-- ============================================================================
-- 1) Neue Funktionen entfernen (DROP IF EXISTS)
-- ============================================================================
DROP FUNCTION IF EXISTS public.stats_insights(jsonb);
DROP FUNCTION IF EXISTS public._stats_filtered(jsonb);
DROP FUNCTION IF EXISTS public._to_bucket_lufttemp(numeric);
DROP FUNCTION IF EXISTS public._to_bucket_wassertemp(numeric);
DROP FUNCTION IF EXISTS public._to_bucket_wind(numeric);

-- stats_drilldown hat neue Rückgabespalte (water_temp_c) → DROP + Neuanlage
DROP FUNCTION IF EXISTS public.stats_drilldown(jsonb);

-- ============================================================================
-- 2) Original _to_bucket_druck wiederherstellen (>= 1015 MIT Space)
-- ============================================================================
CREATE OR REPLACE FUNCTION public._to_bucket_druck(p_val numeric)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $fn$
BEGIN
  IF p_val IS NULL          THEN RETURN 'Unbekannt';
  ELSIF p_val < 1005        THEN RETURN '<1005';
  ELSIF p_val >= 1015       THEN RETURN '>= 1015';
  ELSE                           RETURN '1005-1015';
  END IF;
END;
$fn$;

-- ============================================================================
-- 3) Original stats_conditions wiederherstellen (aus 0009)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_conditions(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid uuid;
  v_result jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  WITH base AS (
    SELECT c.*
    FROM public.catches c
    WHERE c.user_id = v_uid
      AND c.deleted_at IS NULL
      AND c.draft = false
      AND (p_filters->>'mond' IS NULL
           OR c.weather->>'moon_text' = p_filters->>'mond')
      AND (p_filters->>'druck_bucket' IS NULL
           OR CASE p_filters->>'druck_bucket'
                WHEN '<1005'     THEN (c.weather->>'pressure_hpa')::numeric < 1005
                WHEN '1005-1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1005
                                    AND (c.weather->>'pressure_hpa')::numeric < 1015
                WHEN '1015+'     THEN (c.weather->>'pressure_hpa')::numeric >= 1015
                WHEN '>= 1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1015
                ELSE true
              END)
      AND (p_filters->>'wind_bucket' IS NULL
           OR CASE p_filters->>'wind_bucket'
                WHEN '<5'    THEN (c.weather->>'wind_kmh')::numeric < 5
                WHEN '5-10'  THEN (c.weather->>'wind_kmh')::numeric >= 5
                               AND (c.weather->>'wind_kmh')::numeric < 10
                WHEN '10-20' THEN (c.weather->>'wind_kmh')::numeric >= 10
                               AND (c.weather->>'wind_kmh')::numeric < 20
                WHEN '20+'   THEN (c.weather->>'wind_kmh')::numeric >= 20
                ELSE true
              END)
      AND (p_filters->>'wetter' IS NULL
           OR c.weather->>'weather_text' ILIKE ('%' || (p_filters->>'wetter') || '%'))
      AND (p_filters->>'gewaesser' IS NULL
           OR c.water_name ILIKE ('%' || (p_filters->>'gewaesser') || '%'))
      AND (p_filters->>'art' IS NULL
           OR c.species::text = p_filters->>'art'
           OR c.species_custom ILIKE ('%' || (p_filters->>'art') || '%'))
      AND (p_filters->>'koeder' IS NULL
           OR c.bait ILIKE ('%' || (p_filters->>'koeder') || '%'))
      AND (p_filters->>'monat' IS NULL
           OR EXTRACT(MONTH FROM c.catch_ts) = (p_filters->>'monat')::int)
      AND (p_filters->>'uhrzeit_bucket' IS NULL
           OR CASE p_filters->>'uhrzeit_bucket'
                WHEN '0-6'   THEN EXTRACT(HOUR FROM c.catch_ts) >= 0
                               AND EXTRACT(HOUR FROM c.catch_ts) < 6
                WHEN '6-12'  THEN EXTRACT(HOUR FROM c.catch_ts) >= 6
                               AND EXTRACT(HOUR FROM c.catch_ts) < 12
                WHEN '12-18' THEN EXTRACT(HOUR FROM c.catch_ts) >= 12
                               AND EXTRACT(HOUR FROM c.catch_ts) < 18
                WHEN '18-24' THEN EXTRACT(HOUR FROM c.catch_ts) >= 18
                ELSE true
              END)
      AND (p_filters->>'jahr' IS NULL
           OR EXTRACT(YEAR FROM c.catch_ts) = (p_filters->>'jahr')::int)
      AND (p_filters->'zeitraum' IS NULL
           OR (c.catch_ts >= ((p_filters->'zeitraum'->>'von') || 'T00:00:00Z')::timestamptz
               AND c.catch_ts < ((p_filters->'zeitraum'->>'bis') || 'T23:59:59Z')::timestamptz))
  ),
  total AS (
    SELECT
      count(*)::int                                AS fangzahl,
      round(avg(weight_kg), 1)                     AS avg_gewicht,
      round(max(weight_kg), 1)                     AS max_gewicht,
      round(COALESCE(sum(weight_kg), 0), 1)        AS sum_gewicht
    FROM base
  ),
  bucket_rows AS (
    SELECT
      COALESCE(weather->>'moon_text', 'Unbekannt')               AS mond,
      CASE
        WHEN (weather->>'pressure_hpa')::numeric < 1005  THEN '<1005'
        WHEN (weather->>'pressure_hpa')::numeric >= 1015 THEN '>= 1015'
        ELSE '1005-1015'
      END                                                          AS druck,
      CASE
        WHEN (weather->>'wind_kmh')::numeric < 5   THEN '<5'
        WHEN (weather->>'wind_kmh')::numeric < 10  THEN '5-10'
        WHEN (weather->>'wind_kmh')::numeric < 20  THEN '10-20'
        ELSE '20+'
      END                                                          AS wind,
      COALESCE(weather->>'weather_text', 'Unbekannt')             AS wetter,
      COALESCE(water_name, 'Unbekannt')                           AS gewaesser,
      CASE
        WHEN EXTRACT(HOUR FROM catch_ts) < 6  THEN '0-6'
        WHEN EXTRACT(HOUR FROM catch_ts) < 12 THEN '6-12'
        WHEN EXTRACT(HOUR FROM catch_ts) < 18 THEN '12-18'
        ELSE '18-24'
      END                                                          AS uhrzeit,
      to_char(catch_ts, 'TMMon')                                   AS monat,
      COALESCE(species_custom, species::text, 'Unbekannt')        AS art,
      COALESCE(bait, 'Unbekannt')                                  AS koeder,
      weight_kg
    FROM base
  ),
  mond_agg AS (
    SELECT jsonb_object_agg(mond, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT mond, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY mond
    ) sub
  ),
  druck_agg AS (
    SELECT jsonb_object_agg(druck, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT druck, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY druck
    ) sub
  ),
  wind_agg AS (
    SELECT jsonb_object_agg(wind, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT wind, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY wind
    ) sub
  ),
  wetter_agg AS (
    SELECT jsonb_object_agg(wetter, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT wetter, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY wetter
    ) sub
  ),
  gewaesser_agg AS (
    SELECT jsonb_object_agg(gewaesser, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT gewaesser, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY gewaesser
    ) sub
  ),
  uhrzeit_agg AS (
    SELECT jsonb_object_agg(uhrzeit, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT uhrzeit, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY uhrzeit
    ) sub
  ),
  monat_agg AS (
    SELECT jsonb_object_agg(monat, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT monat, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY monat
    ) sub
  ),
  art_agg AS (
    SELECT jsonb_object_agg(art, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT art, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY art
    ) sub
  ),
  koeder_agg AS (
    SELECT jsonb_object_agg(koeder, jsonb_build_object(
      'fangzahl',    fangzahl,
      'avg_gewicht', avg_gewicht
    )) AS d
    FROM (
      SELECT koeder, count(*)::int AS fangzahl, round(avg(weight_kg), 1) AS avg_gewicht
      FROM bucket_rows GROUP BY koeder
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
      'mond',      COALESCE(m.d, '{}'::jsonb),
      'druck',     COALESCE(d.d, '{}'::jsonb),
      'wind',      COALESCE(w.d, '{}'::jsonb),
      'wetter',    COALESCE(we.d, '{}'::jsonb),
      'gewaesser', COALESCE(g.d, '{}'::jsonb),
      'uhrzeit',   COALESCE(u.d, '{}'::jsonb),
      'monat',     COALESCE(mo.d, '{}'::jsonb),
      'art',       COALESCE(a.d, '{}'::jsonb),
      'koeder',    COALESCE(k.d, '{}'::jsonb)
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
  CROSS JOIN koeder_agg k;

  RETURN v_result;
END;
$fn$;

-- ============================================================================
-- 4) Original stats_drilldown wiederherstellen (aus 0009)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_drilldown(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(
  id         uuid,
  catch_ts   timestamptz,
  water_name text,
  species    text,
  weight_kg  numeric,
  length_cm  numeric,
  bait       text,
  weather    jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN QUERY
  SELECT c.id, c.catch_ts, c.water_name,
         COALESCE(c.species_custom, c.species::text) AS species,
         c.weight_kg, c.length_cm, c.bait, c.weather
  FROM public.catches c
  WHERE c.user_id = v_uid
    AND c.deleted_at IS NULL
    AND c.draft = false
    AND (p_filters->>'mond' IS NULL OR c.weather->>'moon_text' = p_filters->>'mond')
    AND (p_filters->>'druck_bucket' IS NULL
         OR CASE p_filters->>'druck_bucket'
              WHEN '<1005'     THEN (c.weather->>'pressure_hpa')::numeric < 1005
              WHEN '1005-1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1005
                                  AND (c.weather->>'pressure_hpa')::numeric < 1015
              WHEN '1015+'     THEN (c.weather->>'pressure_hpa')::numeric >= 1015
              WHEN '>= 1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1015
              ELSE true END)
              AND (p_filters->>'wind_bucket' IS NULL
         OR CASE p_filters->>'wind_bucket'
              WHEN '<5'    THEN (c.weather->>'wind_kmh')::numeric < 5
              WHEN '5-10'  THEN (c.weather->>'wind_kmh')::numeric >= 5
                             AND (c.weather->>'wind_kmh')::numeric < 10
              WHEN '10-20' THEN (c.weather->>'wind_kmh')::numeric >= 10
                             AND (c.weather->>'wind_kmh')::numeric < 20
              WHEN '20+'   THEN (c.weather->>'wind_kmh')::numeric >= 20
              ELSE true END)
    AND (p_filters->>'wetter' IS NULL
         OR c.weather->>'weather_text' ILIKE ('%' || (p_filters->>'wetter') || '%'))
    AND (p_filters->>'gewaesser' IS NULL
         OR c.water_name ILIKE ('%' || (p_filters->>'gewaesser') || '%'))
    AND (p_filters->>'art' IS NULL
         OR c.species::text = p_filters->>'art'
         OR c.species_custom ILIKE ('%' || (p_filters->>'art') || '%'))
    AND (p_filters->>'koeder' IS NULL
         OR c.bait ILIKE ('%' || (p_filters->>'koeder') || '%'))
    AND (p_filters->>'monat' IS NULL
         OR EXTRACT(MONTH FROM c.catch_ts) = (p_filters->>'monat')::int)
    AND (p_filters->>'uhrzeit_bucket' IS NULL
         OR CASE p_filters->>'uhrzeit_bucket'
              WHEN '0-6'   THEN EXTRACT(HOUR FROM c.catch_ts) >= 0
                             AND EXTRACT(HOUR FROM c.catch_ts) < 6
              WHEN '6-12'  THEN EXTRACT(HOUR FROM c.catch_ts) >= 6
                             AND EXTRACT(HOUR FROM c.catch_ts) < 12
              WHEN '12-18' THEN EXTRACT(HOUR FROM c.catch_ts) >= 12
                             AND EXTRACT(HOUR FROM c.catch_ts) < 18
              WHEN '18-24' THEN EXTRACT(HOUR FROM c.catch_ts) >= 18
              ELSE true END)
    AND (p_filters->>'jahr' IS NULL
         OR EXTRACT(YEAR FROM c.catch_ts) = (p_filters->>'jahr')::int)
    AND (p_filters->'zeitraum' IS NULL
         OR (c.catch_ts >= ((p_filters->'zeitraum'->>'von') || 'T00:00:00Z')::timestamptz
             AND c.catch_ts < ((p_filters->'zeitraum'->>'bis') || 'T23:59:59Z')::timestamptz))
  ORDER BY c.catch_ts DESC;
END;
$fn$;

-- ============================================================================
-- 5) Original stats_beste_kombis wiederherstellen (aus 0009)
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
AS $fn$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT c.*
    FROM public.catches c
    WHERE c.user_id = v_uid
      AND c.deleted_at IS NULL
      AND c.draft = false
      AND (p_filters->>'mond' IS NULL OR c.weather->>'moon_text' = p_filters->>'mond')
      AND (p_filters->>'druck_bucket' IS NULL
           OR CASE p_filters->>'druck_bucket'
                WHEN '<1005'     THEN (c.weather->>'pressure_hpa')::numeric < 1005
                WHEN '1005-1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1005
                                    AND (c.weather->>'pressure_hpa')::numeric < 1015
                WHEN '1015+'     THEN (c.weather->>'pressure_hpa')::numeric >= 1015
                WHEN '>= 1015' THEN (c.weather->>'pressure_hpa')::numeric >= 1015
                ELSE true END)
      AND (p_filters->>'wind_bucket' IS NULL
           OR CASE p_filters->>'wind_bucket'
                WHEN '<5'    THEN (c.weather->>'wind_kmh')::numeric < 5
                WHEN '5-10'  THEN (c.weather->>'wind_kmh')::numeric >= 5
                               AND (c.weather->>'wind_kmh')::numeric < 10
                WHEN '10-20' THEN (c.weather->>'wind_kmh')::numeric >= 10
                               AND (c.weather->>'wind_kmh')::numeric < 20
                WHEN '20+'   THEN (c.weather->>'wind_kmh')::numeric >= 20
                ELSE true END)
      AND (p_filters->>'wetter' IS NULL
           OR c.weather->>'weather_text' ILIKE ('%' || (p_filters->>'wetter') || '%'))
      AND (p_filters->>'gewaesser' IS NULL
           OR c.water_name ILIKE ('%' || (p_filters->>'gewaesser') || '%'))
      AND (p_filters->>'art' IS NULL
           OR c.species::text = p_filters->>'art'
           OR c.species_custom ILIKE ('%' || (p_filters->>'art') || '%'))
      AND (p_filters->>'koeder' IS NULL
           OR c.bait ILIKE ('%' || (p_filters->>'koeder') || '%'))
      AND (p_filters->>'monat' IS NULL
           OR EXTRACT(MONTH FROM c.catch_ts) = (p_filters->>'monat')::int)
      AND (p_filters->>'uhrzeit_bucket' IS NULL
           OR CASE p_filters->>'uhrzeit_bucket'
                WHEN '0-6'   THEN EXTRACT(HOUR FROM c.catch_ts) >= 0
                               AND EXTRACT(HOUR FROM c.catch_ts) < 6
                WHEN '6-12'  THEN EXTRACT(HOUR FROM c.catch_ts) >= 6
                               AND EXTRACT(HOUR FROM c.catch_ts) < 12
                WHEN '12-18' THEN EXTRACT(HOUR FROM c.catch_ts) >= 12
                               AND EXTRACT(HOUR FROM c.catch_ts) < 18
                WHEN '18-24' THEN EXTRACT(HOUR FROM c.catch_ts) >= 18
                ELSE true END)
      AND (p_filters->>'jahr' IS NULL
           OR EXTRACT(YEAR FROM c.catch_ts) = (p_filters->>'jahr')::int)
      AND (p_filters->'zeitraum' IS NULL
           OR (c.catch_ts >= ((p_filters->'zeitraum'->>'von') || 'T00:00:00Z')::timestamptz
               AND c.catch_ts < ((p_filters->'zeitraum'->>'bis') || 'T23:59:59Z')::timestamptz))
  ),
  with_dims AS (
    SELECT
      COALESCE(weather->>'moon_text', 'Unbekannt') AS mond_val,
      CASE
        WHEN (weather->>'pressure_hpa')::numeric < 1005  THEN '<1005'
        WHEN (weather->>'pressure_hpa')::numeric >= 1015 THEN '>= 1015'
        ELSE '1005-1015'
      END AS druck_val,
      COALESCE(weather->>'weather_text', 'Unbekannt') AS wetter_val,
      COALESCE(bait, 'Unbekannt') AS koeder_val,
      weight_kg
    FROM base
  ),
  kombis AS (
    SELECT p.kombi, count(*)::int AS fangzahl, round(avg(p.weight_kg), 1) AS avg_gewicht
    FROM (
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
    ) p
    GROUP BY p.kombi
    HAVING count(*) >= 2
  )
  SELECT k.kombi, k.fangzahl, k.avg_gewicht
  FROM kombis k
  ORDER BY k.avg_gewicht DESC
  LIMIT p_limit;
END;
$fn$;

-- ============================================================================
-- 6) water_temp_c Spalte entfernen
-- ============================================================================
ALTER TABLE public.catches DROP COLUMN IF EXISTS water_temp_c;

-- ============================================================================
-- 7) Grants aus 0010 wiederherstellen (Originale + stats_drilldown)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.stats_conditions(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stats_drilldown(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.stats_conditions(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stats_drilldown(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) TO authenticated;

COMMENT ON FUNCTION public.stats_conditions(jsonb)
  IS 'Aggregat-Statistik + Bucket-Verteilungen. EXECUTE nur authenticated (Härtung 0010).';
COMMENT ON FUNCTION public.stats_drilldown(jsonb)
  IS 'Gefilterte Fangliste. EXECUTE nur authenticated (Härtung 0010).';
COMMENT ON FUNCTION public.stats_beste_kombis(jsonb, integer)
  IS 'Beste 2er-Kombis nach avg_gewicht. EXECUTE nur authenticated (Härtung 0010).';

-- ============================================================================
-- 0033_rollback_stats_v2.sql erfolgreich angewendet.
-- Originale aus 0009 + Grants aus 0010 wiederhergestellt.
-- ============================================================================
