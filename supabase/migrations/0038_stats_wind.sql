CREATE OR REPLACE FUNCTION public.stats_wind_korrelation(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(wind_bereich text, catch_count integer, avg_weight numeric)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SET LOCAL statement_timeout = '5s';
  RETURN QUERY
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  wind AS (
    SELECT
      CASE
        WHEN (c.weather->>'wind_speed_kmh')::int < 5 THEN 'Windstill'
        WHEN (c.weather->>'wind_speed_kmh')::int < 15 THEN 'Leicht'
        WHEN (c.weather->>'wind_speed_kmh')::int < 30 THEN 'Mäßig'
        WHEN (c.weather->>'wind_speed_kmh')::int < 50 THEN 'Stark'
        ELSE 'Sturm'
      END AS bereich,
      c.weight_kg
    FROM base c
    WHERE c.weather->>'wind_speed_kmh' IS NOT NULL
  )
  SELECT w.bereich, count(*)::int, round(avg(w.weight_kg), 2)
  FROM wind w GROUP BY w.bereich
  ORDER BY min(CASE
    WHEN w.bereich = 'Windstill' THEN 0
    WHEN w.bereich = 'Leicht' THEN 1
    WHEN w.bereich = 'Mäßig' THEN 2
    WHEN w.bereich = 'Stark' THEN 3
    ELSE 4
  END);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stats_wind_korrelation(jsonb) TO authenticated, service_role;
