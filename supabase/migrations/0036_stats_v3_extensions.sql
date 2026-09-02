-- 0036_stats_v3_extensions.sql
-- Statistik-Studio v3: Gewichtsverlauf, Trips, Badges, Wetter-Korrelation
-- Alle Funktionen: SECURITY DEFINER, SET search_path = '', VOLATILE (auth.uid()).
-- REVOKE PUBLIC/anon, GRANT authenticated.

-- ============================================================================
-- 1. stats_gewichtsverlauf(p_filters jsonb) → TABLE
-- Gruppiert nach Monat (YYYY-MM, Vienna TZ), letzte 12 Monate.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_gewichtsverlauf(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(month text, avg_weight numeric, max_weight numeric, catch_count int)
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
  monthly AS (
    SELECT
      to_char(c.catch_ts AT TIME ZONE 'Europe/Vienna', 'YYYY-MM') AS monat,
      c.weight_kg
    FROM base c
    WHERE c.catch_ts >= (now() - INTERVAL '12 months')
  )
  SELECT
    m.monat                                         AS month,
    round(avg(m.weight_kg), 2)                     AS avg_weight,
    round(max(m.weight_kg), 2)                     AS max_weight,
    count(*)::int                                   AS catch_count
  FROM monthly m
  GROUP BY m.monat
  ORDER BY m.monat;
END;
$fn$;

-- ============================================================================
-- 2. stats_trips(p_user_id UUID) → TABLE
-- Trips + Catch-Stats des Users, letzte 12 Monate.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_trips(p_user_id uuid)
RETURNS TABLE(
  trip_count         int,
  avg_weight_per_trip numeric,
  best_water         text,
  trip_details       jsonb
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

  IF v_uid <> p_user_id THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SET LOCAL statement_timeout = '5s';

  RETURN QUERY
  WITH user_trips AS (
    SELECT
      t.id,
      t.name,
      t.water_name,
      t.start_date
    FROM public.trips t
    WHERE t.user_id = p_user_id
      AND t.start_date >= (now() - INTERVAL '12 months')::date
  ),
  trip_catches AS (
    SELECT
      ut.id           AS trip_id,
      ut.name         AS trip_name,
      ut.water_name   AS trip_water,
      ut.start_date,
      c.weight_kg
    FROM user_trips ut
    LEFT JOIN public.catches c
      ON c.trip_id = ut.id
      AND c.user_id = p_user_id
      AND c.deleted_at IS NULL
      AND c.draft = false
  ),
  trip_agg AS (
    SELECT
      tc.trip_id,
      tc.trip_name,
      tc.trip_water,
      tc.start_date,
      count(tc.weight_kg)::int             AS catch_count,
      round(avg(tc.weight_kg), 2)         AS avg_weight
    FROM trip_catches tc
    GROUP BY tc.trip_id, tc.trip_name, tc.trip_water, tc.start_date
  ),
  summary AS (
    SELECT
      count(*)::int                        AS v_trip_count,
      round(avg(ta.avg_weight), 2)        AS v_avg_weight_per_trip
    FROM trip_agg ta
    WHERE ta.catch_count > 0
  ),
  best AS (
    SELECT ta.trip_water
    FROM trip_agg ta
    WHERE ta.catch_count > 0
    ORDER BY ta.avg_weight DESC, ta.catch_count DESC
    LIMIT 1
  ),
  details AS (
    SELECT jsonb_agg(
      jsonb_build_object(
        'name',        ta.trip_name,
        'water_name',  ta.trip_water,
        'catch_count', ta.catch_count,
        'avg_weight',  ta.avg_weight,
        'start_date',  ta.start_date
      )
      ORDER BY ta.start_date DESC
    ) AS arr
    FROM trip_agg ta
  )
  SELECT
    s.v_trip_count,
    s.v_avg_weight_per_trip,
    b.trip_water,
    COALESCE(d.arr, '[]'::jsonb)
  FROM summary s
  CROSS JOIN best b
  CROSS JOIN details d;
END;
$fn$;

-- ============================================================================
-- 3. stats_badges(p_user_id UUID) → TABLE
-- Alle Badges + earned-Status des Users.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_badges(p_user_id uuid)
RETURNS TABLE(
  total_badges  int,
  earned_badges int,
  badge_list    jsonb
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

  IF v_uid <> p_user_id THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SET LOCAL statement_timeout = '5s';

  RETURN QUERY
  WITH all_badges AS (
    SELECT
      b.id,
      b.name,
      b.description,
      b.icon,
      ub.earned_at
    FROM public.badges b
    LEFT JOIN public.user_badges ub
      ON ub.badge_id = b.id AND ub.user_id = p_user_id
    ORDER BY b.sort
  ),
  agg AS (
    SELECT
      count(*)::int                                          AS v_total,
      count(ab.earned_at)::int                               AS v_earned,
      jsonb_agg(
        jsonb_build_object(
          'id',          ab.id,
          'name',        ab.name,
          'description', ab.description,
          'icon',        ab.icon,
          'earned',      (ab.earned_at IS NOT NULL),
          'earned_at',   ab.earned_at
        )
        ORDER BY ab.name
      )                                                      AS v_list
    FROM all_badges ab
  )
  SELECT a.v_total, a.v_earned, a.v_list
  FROM agg a;
END;
$fn$;

-- ============================================================================
-- 4. stats_wetter_korrelation(p_filters jsonb) → TABLE
-- Gruppiert nach weather->>'weather_text', sortiert nach catch_count DESC.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.stats_wetter_korrelation(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(
  weather_type text,
  catch_count  int,
  avg_weight   numeric
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
  )
  SELECT
    COALESCE(c.weather->>'weather_text', 'Unbekannt') AS weather_type,
    count(*)::int                                      AS catch_count,
    round(avg(c.weight_kg), 2)                        AS avg_weight
  FROM base c
  GROUP BY COALESCE(c.weather->>'weather_text', 'Unbekannt')
  ORDER BY count(*) DESC;
END;
$fn$;

-- ============================================================================
-- Grants-Sektion (Defense-in-Depth)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.stats_gewichtsverlauf(jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_gewichtsverlauf(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_trips(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_trips(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_badges(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_badges(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.stats_wetter_korrelation(jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.stats_wetter_korrelation(jsonb) TO authenticated;

-- ============================================================================
-- Kommentare
-- ============================================================================
COMMENT ON FUNCTION public.stats_gewichtsverlauf(jsonb)
  IS 'Gewichtsverlauf nach Monat (YYYY-MM, Vienna TZ, letzte 12 Monate). Nutzt _stats_filtered als DRY-Basis. EXECUTE nur authenticated.';

COMMENT ON FUNCTION public.stats_trips(uuid)
  IS 'Trip-Statistiken: Anzahl, avg Gewicht pro Trip, bestes Gewaesser, Detail-Array. Letzte 12 Monate. EXECUTE nur authenticated.';

COMMENT ON FUNCTION public.stats_badges(uuid)
  IS 'Alle Badges mit earned-Status des Users. EXECUTE nur authenticated.';

COMMENT ON FUNCTION public.stats_wetter_korrelation(jsonb)
  IS 'Wetter-Korrelation: Fangzahl und avg Gewicht pro Wettertyp. Nutzt _stats_filtered als DRY-Basis. EXECUTE nur authenticated.';

-- ============================================================================
-- 0036_stats_v3_extensions.sql erfolgreich angewendet.
-- ============================================================================
