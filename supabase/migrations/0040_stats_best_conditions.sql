-- stats_best_conditions: Beste Kombination aus Mond + Wetter (2D, min. 3 Fänge)
CREATE OR REPLACE FUNCTION public.stats_best_conditions(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(best_mond text, best_wetter text, avg_weight numeric, catch_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SET LOCAL statement_timeout = '5s';
  RETURN QUERY
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters)),
  kombis AS (
    SELECT
      COALESCE(c.weather->>'moon_text', 'Unbekannt') AS mond,
      COALESCE(c.weather->>'weather_text', 'Unbekannt') AS wetter,
      c.weight_kg
    FROM base c
    WHERE c.weather->>'moon_text' IS NOT NULL OR c.weather->>'weather_text' IS NOT NULL
  ),
  agg AS (
    SELECT k.mond, k.wetter, count(*)::int AS cnt, round(avg(k.weight_kg), 2) AS avg_w
    FROM kombis k
    GROUP BY k.mond, k.wetter
    HAVING count(*) >= 3
  )
  SELECT a.mond, a.wetter, a.avg_w, a.cnt
  FROM agg a
  ORDER BY a.avg_w DESC, a.cnt DESC
  LIMIT 1;
END;
$$;
GRANT EXECUTE ON FUNCTION public.stats_best_conditions(jsonb) TO authenticated, service_role;

-- stats_wassertemp_korrelation: Fänge nach Wassertemperatur-Buckets
CREATE OR REPLACE FUNCTION public.stats_wassertemp_korrelation(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(temp_bereich text, catch_count integer, avg_weight numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SET LOCAL statement_timeout = '5s';
  RETURN QUERY
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters))
  SELECT
    public._to_bucket_wassertemp(c.water_temp_c)::text,
    count(*)::int,
    round(avg(c.weight_kg), 2)
  FROM base c
  WHERE c.water_temp_c IS NOT NULL
  GROUP BY public._to_bucket_wassertemp(c.water_temp_c)
  ORDER BY min(c.water_temp_c);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stats_wassertemp_korrelation(jsonb) TO authenticated, service_role;
