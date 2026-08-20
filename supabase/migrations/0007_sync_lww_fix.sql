-- 0007_sync_lww_fix.sql
-- BUGFIX (E2E-Test 20.08.): sync_catch-LWW verglich updated_at (Trigger = now() = Sync-Zeit)
-- mit client_ts → Offline-Edits aus der Vergangenheit verloren IMMER beim Batch-Sync.
-- Fix: separate Spalte client_updated_at als LWW-Vergleichsbasis.

ALTER TABLE public.catches
  ADD COLUMN IF NOT EXISTS client_updated_at timestamptz;

COMMENT ON COLUMN public.catches.client_updated_at IS 'LWW-Basis für Offline-Sync (Client-Zeitstempel) — NICHT now()!';

-- sync_catch: LWW gegen client_updated_at, setzt sie explizit
CREATE OR REPLACE FUNCTION public.sync_catch(
  p_client_uuid     uuid,
  p_data            jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id         uuid;
  v_existing        record;
  v_client_ts       timestamptz;
  v_catch_id        uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  v_client_ts := (p_data ->> 'client_updated_at')::timestamptz;

  SELECT id, client_updated_at, deleted_at
  INTO v_existing
  FROM public.catches
  WHERE client_uuid = p_client_uuid
    AND user_id = v_user_id;

  IF v_existing.id IS NOT NULL THEN
    -- LWW: eingehender Edit gewinnt nur wenn er NEUER ist als der letzte Client-Edit
    IF v_client_ts IS NOT NULL
       AND (v_existing.client_updated_at IS NULL OR v_existing.client_updated_at < v_client_ts) THEN
      UPDATE public.catches SET
        catch_ts          = COALESCE((p_data ->> 'catch_ts')::timestamptz, catch_ts),
        species           = COALESCE((p_data ->> 'species')::public.species_enum, species),
        weight_kg         = COALESCE((p_data ->> 'weight_kg')::numeric, weight_kg),
        length_cm         = COALESCE((p_data ->> 'length_cm')::numeric, length_cm),
        bait              = COALESCE(p_data ->> 'bait', bait),
        method            = COALESCE(p_data ->> 'method', method),
        notes             = COALESCE(p_data ->> 'notes', notes),
        photos            = COALESCE(
                              CASE WHEN p_data ? 'photos'
                                   THEN ARRAY(SELECT jsonb_array_elements_text(p_data -> 'photos'))
                                   ELSE NULL END,
                              photos
                            ),
        lat               = COALESCE((p_data ->> 'lat')::numeric, lat),
        lng               = COALESCE((p_data ->> 'lng')::numeric, lng),
        water_name        = COALESCE(p_data ->> 'water_name', water_name),
        water_id          = COALESCE((p_data ->> 'water_id')::uuid, water_id),
        draft             = COALESCE((p_data ->> 'draft')::boolean, draft),
        weather           = COALESCE(p_data -> 'weather', weather),
        weather_auto      = COALESCE((p_data ->> 'weather_auto')::boolean, weather_auto),
        client_updated_at = v_client_ts
      WHERE id = v_existing.id;
    END IF;
    v_catch_id := v_existing.id;
    RETURN v_catch_id;
  END IF;

  INSERT INTO public.catches (
    client_uuid,
    user_id,
    catch_ts,
    species,
    weight_kg,
    length_cm,
    bait,
    method,
    notes,
    photos,
    lat,
    lng,
    water_name,
    water_id,
    draft,
    weather,
    weather_auto,
    client_updated_at
  ) VALUES (
    p_client_uuid,
    v_user_id,
    COALESCE((p_data ->> 'catch_ts')::timestamptz, now()),
    (p_data ->> 'species')::public.species_enum,
    (p_data ->> 'weight_kg')::numeric,
    (p_data ->> 'length_cm')::numeric,
    p_data ->> 'bait',
    p_data ->> 'method',
    p_data ->> 'notes',
    CASE WHEN p_data ? 'photos'
         THEN ARRAY(SELECT jsonb_array_elements_text(p_data -> 'photos'))
         ELSE '{}' END,
    (p_data ->> 'lat')::numeric,
    (p_data ->> 'lng')::numeric,
    p_data ->> 'water_name',
    (p_data ->> 'water_id')::uuid,
    COALESCE((p_data ->> 'draft')::boolean, true),
    p_data -> 'weather',
    (p_data ->> 'weather_auto')::boolean,
    v_client_ts
  )
  RETURNING id INTO v_catch_id;

  RETURN v_catch_id;
END;
$function$;

COMMENT ON FUNCTION public.sync_catch(uuid, jsonb)
  IS 'Idempotenter Offline-Sync-Upsert: LWW via client_updated_at (Client-Zeit). Gibt catch_id zurück.';

-- get_changes: Delta-Basis client_updated_at (nicht updated_at/now())
CREATE OR REPLACE FUNCTION public.get_changes(
  p_since   timestamptz,
  p_limit   integer DEFAULT 500,
  p_offset  integer DEFAULT 0
)
RETURNS TABLE (
  id           uuid,
  client_uuid  uuid,
  deleted      boolean,
  data         jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.client_uuid,
    (c.deleted_at IS NOT NULL) AS deleted,
    jsonb_build_object(
      'id',            c.id,
      'client_uuid',   c.client_uuid,
      'water_id',      c.water_id,
      'water_name',    c.water_name,
      'lat',           c.lat,
      'lng',           c.lng,
      'catch_ts',      c.catch_ts,
      'species',       c.species,
      'weight_kg',     c.weight_kg,
      'length_cm',     c.length_cm,
      'bait',          c.bait,
      'method',        c.method,
      'notes',         c.notes,
      'photos',        c.photos,
      'weather',       c.weather,
      'weather_auto',  c.weather_auto,
      'draft',         c.draft,
      'client_updated_at', c.client_updated_at,
      'created_at',    c.created_at,
      'updated_at',    c.updated_at,
      'deleted_at',    c.deleted_at
    ) AS data
  FROM public.catches c
  WHERE c.user_id = v_user_id
    AND (
      (c.client_updated_at IS NOT NULL AND c.client_updated_at > p_since)
      OR (c.updated_at > p_since)
      OR (c.deleted_at > p_since)
    )
  ORDER BY COALESCE(c.client_updated_at, c.updated_at) ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

COMMENT ON FUNCTION public.get_changes(timestamptz, integer, integer)
  IS 'Delta-Sync: Änderungen + Tombstones seit p_since (Basis client_updated_at/updated_at/deleted_at). Pagination.';
