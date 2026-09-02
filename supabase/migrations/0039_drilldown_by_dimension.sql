-- stats_drilldown_by_water: Fänge gruppiert nach Gewässer
CREATE OR REPLACE FUNCTION public.stats_drilldown_by_water(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(water_name text, catch_count integer, avg_weight numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SET LOCAL statement_timeout = '5s';
  RETURN QUERY
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters))
  SELECT COALESCE(c.water_name, 'Unbekannt')::text, count(*)::int, round(avg(c.weight_kg), 2)
  FROM base c GROUP BY COALESCE(c.water_name, 'Unbekannt') ORDER BY count(*) DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.stats_drilldown_by_water(jsonb) TO authenticated, service_role;

-- stats_drilldown_by_mond: Fänge gruppiert nach Mondphase
CREATE OR REPLACE FUNCTION public.stats_drilldown_by_mond(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(mond_phase text, catch_count integer, avg_weight numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SET LOCAL statement_timeout = '5s';
  RETURN QUERY
  WITH base AS (SELECT * FROM public._stats_filtered(p_filters))
  SELECT COALESCE(c.weather->>'moon_text', 'Unbekannt')::text, count(*)::int, round(avg(c.weight_kg), 2)
  FROM base c GROUP BY COALESCE(c.weather->>'moon_text', 'Unbekannt') ORDER BY count(*) DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.stats_drilldown_by_mond(jsonb) TO authenticated, service_role;
