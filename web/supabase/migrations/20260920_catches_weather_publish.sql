-- Migration: catches weather + publish columns
-- Date: 2026-09-20
-- Applied: LOCAL Docker + HETZNER Docker
-- Description: Adds weather data columns and publishing columns to catches table

-- Weather columns (from Open-Meteo API)
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS weather_code int;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS temperature_2m numeric;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS relative_humidity_2m numeric;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS wind_speed_10m numeric;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS pressure_msl numeric;

-- Publishing columns
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT false;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS published_at timestamptz;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS session_catches int;
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS session_duration_seconds int;

-- publish_catch RPC: single function with DEFAULT NULL (fixes ambiguity)
DROP FUNCTION IF EXISTS public.publish_catch(uuid, uuid);
DROP FUNCTION IF EXISTS public.publish_catch(uuid);

CREATE OR REPLACE FUNCTION public.publish_catch(p_catch_id uuid, p_trip_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_catch RECORD;
  v_catches_in_session int;
  v_session_seconds int;
  v_weather jsonb;
BEGIN
  SELECT * INTO v_catch FROM public.catches WHERE id = p_catch_id AND user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Fang nicht gefunden'); END IF;
  IF v_catch.is_published THEN RETURN jsonb_build_object('success', false, 'error', 'Bereits veröffentlicht'); END IF;

  SELECT COUNT(*), COALESCE(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))::int, 0)
  INTO v_catches_in_session, v_session_seconds
  FROM public.catches WHERE user_id = auth.uid()
    AND created_at >= v_catch.created_at - interval '24 hours'
    AND created_at <= v_catch.created_at + interval '24 hours';

  v_weather := jsonb_build_object(
    'temp_c', v_catch.temperature_2m,
    'weather_text', CASE v_catch.weather_code
      WHEN 0 THEN 'Klar' WHEN 1 THEN 'Überwiegend klar' WHEN 2 THEN 'Teils bewölkt' WHEN 3 THEN 'Bewölkt'
      WHEN 45 THEN 'Nebel' WHEN 48 THEN 'Reifnebel' WHEN 51 THEN 'Leichter Nieselregen' WHEN 53 THEN 'Mäßiger Nieselregen'
      WHEN 55 THEN 'Starker Nieselregen' WHEN 61 THEN 'Leichter Regen' WHEN 63 THEN 'Mäßiger Regen' WHEN 65 THEN 'Starker Regen'
      WHEN 71 THEN 'Leichter Schneefall' WHEN 73 THEN 'Mäßiger Schneefall' WHEN 75 THEN 'Starker Schneefall'
      WHEN 80 THEN 'Leichte Regenschauer' WHEN 81 THEN 'Mäßige Regenschauer' WHEN 82 THEN 'Starke Regenschauer'
      WHEN 95 THEN 'Gewitter' WHEN 96 THEN 'Gewitter mit Hagel' WHEN 99 THEN 'Starkes Gewitter mit Hagel'
      ELSE 'Unbekannt (' || v_catch.weather_code || ')' END,
    'pressure_hpa', v_catch.pressure_msl,
    'wind_speed_kmh', v_catch.wind_speed_10m,
    'humidity_pct', v_catch.relative_humidity_2m
  );

  UPDATE public.catches SET
    is_published = true,
    published_at = now(),
    session_catches = v_catches_in_session,
    session_duration_seconds = v_session_seconds,
    weather = v_weather,
    trip_id = COALESCE(p_trip_id, trip_id)
  WHERE id = p_catch_id;

  RETURN jsonb_build_object('success', true, 'catch_id', p_catch_id, 'session_catches', v_catches_in_session, 'session_seconds', v_session_seconds);
END;
$$;

REVOKE ALL ON FUNCTION public.publish_catch(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.publish_catch(uuid, uuid) TO authenticated;
-- Migration: add catch_release column
-- Date: 2026-09-20
-- Applied: LOCAL Docker + HETZNER Docker

ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS catch_release boolean DEFAULT false;
