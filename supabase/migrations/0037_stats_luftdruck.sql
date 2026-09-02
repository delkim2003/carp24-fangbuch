-- stats_luftdruck_korrelation: Fänge gruppiert nach Luftdruck-Bereichen
CREATE OR REPLACE FUNCTION public.stats_luftdruck_korrelation(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(druck_bereich text, catch_count integer, avg_weight numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  druck AS (
    SELECT
      CASE
        WHEN (c.weather->>'pressure_hpa')::int < 1000 THEN '<1000'
        WHEN (c.weather->>'pressure_hpa')::int < 1010 THEN '1000-1009'
        WHEN (c.weather->>'pressure_hpa')::int < 1020 THEN '1010-1019'
        WHEN (c.weather->>'pressure_hpa')::int < 1030 THEN '1020-1029'
        ELSE '≥1030'
      END AS bereich,
      c.weight_kg
    FROM base c
    WHERE c.weather->>'pressure_hpa' IS NOT NULL
  )
  SELECT
    d.bereich,
    count(*)::int,
    round(avg(d.weight_kg), 2)
  FROM druck d
  GROUP BY d.bereich
  ORDER BY min((CASE
    WHEN d.bereich = '<1000' THEN 0
    WHEN d.bereich = '1000-1009' THEN 1
    WHEN d.bereich = '1010-1019' THEN 2
    WHEN d.bereich = '1020-1029' THEN 3
    ELSE 4
  END));
END;
$$;

GRANT EXECUTE ON FUNCTION public.stats_luftdruck_korrelation(jsonb) TO authenticated, service_role;
