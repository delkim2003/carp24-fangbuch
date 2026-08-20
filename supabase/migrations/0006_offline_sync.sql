-- ============================================================================
-- carp24 Fangbuch — 0006_offline_sync.sql
-- Offline-Sync-Backend: Soft-Delete (Tombstone), sync_catch RPC, get_changes RPC
-- Phase 1A — Task 1.6
-- ============================================================================

SET search_path = '';

-- ============================================================================
-- 1) Soft-Delete-Trigger (Tombstone)
--    Physisches DELETE wird zu UPDATE (deleted_at setzen, draft=false).
--    Gelöschte Fänge bleiben in der DB für Sync auf andere Geräte.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.soft_delete_catch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.catches
  SET deleted_at = now(), draft = false
  WHERE id = OLD.id AND deleted_at IS NULL;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS soft_delete_catch_trg ON public.catches;
CREATE TRIGGER soft_delete_catch_trg
  BEFORE DELETE ON public.catches
  FOR EACH ROW
  EXECUTE FUNCTION public.soft_delete_catch();

COMMENT ON TRIGGER soft_delete_catch_trg ON public.catches
  IS 'Verhindert physisches DELETE — setzt deleted_at (Tombstone) für Offline-Sync';

-- ============================================================================
-- 2) sync_catch(p_client_uuid uuid, p_data jsonb) → uuid
--    Idempotenter Upsert mit last-write-wins via client_updated_at.
--    SECURITY DEFINER umgeht RLS (Dienst-Funktion).
-- ============================================================================

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

  SELECT id, updated_at, deleted_at
  INTO v_existing
  FROM public.catches
  WHERE client_uuid = p_client_uuid
    AND user_id = v_user_id;

  IF v_existing.id IS NOT NULL THEN
    IF v_client_ts IS NOT NULL AND v_existing.updated_at < v_client_ts THEN
      UPDATE public.catches SET
        catch_ts      = COALESCE((p_data ->> 'catch_ts')::timestamptz, catch_ts),
        species       = COALESCE((p_data ->> 'species')::public.species_enum, species),
        weight_kg     = COALESCE((p_data ->> 'weight_kg')::numeric, weight_kg),
        length_cm     = COALESCE((p_data ->> 'length_cm')::numeric, length_cm),
        bait          = COALESCE(p_data ->> 'bait', bait),
        method        = COALESCE(p_data ->> 'method', method),
        notes         = COALESCE(p_data ->> 'notes', notes),
        photos        = COALESCE(
                          CASE WHEN p_data ? 'photos'
                               THEN ARRAY(SELECT jsonb_array_elements_text(p_data -> 'photos'))
                               ELSE NULL END,
                          photos
                        ),
        lat           = COALESCE((p_data ->> 'lat')::numeric, lat),
        lng           = COALESCE((p_data ->> 'lng')::numeric, lng),
        water_name    = COALESCE(p_data ->> 'water_name', water_name),
        water_id      = COALESCE((p_data ->> 'water_id')::uuid, water_id),
        draft         = COALESCE((p_data ->> 'draft')::boolean, draft),
        weather       = COALESCE(p_data -> 'weather', weather),
        weather_auto  = COALESCE((p_data ->> 'weather_auto')::boolean, weather_auto)
      WHERE id = v_existing.id;

      v_catch_id := v_existing.id;
    ELSE
      v_catch_id := v_existing.id;
    END IF;

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
    weather_auto
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
    (p_data ->> 'weather_auto')::boolean
  )
  RETURNING id INTO v_catch_id;

  RETURN v_catch_id;
END;
$function$;

COMMENT ON FUNCTION public.sync_catch(uuid, jsonb)
  IS 'Idempotenter Offline-Sync-Upsert: last-write-wins via client_updated_at. Gibt catch_id zurück.';

-- ============================================================================
-- 3) get_changes(p_since timestamptz) → TABLE(...)
--    Delta-Sync: Liefert alle Änderungen + Tombstones seit p_since.
--    Pagination via p_limit/p_offset (Default 500/0).
-- ============================================================================

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
      'created_at',    c.created_at,
      'updated_at',    c.updated_at,
      'deleted_at',    c.deleted_at
    ) AS data
  FROM public.catches c
  WHERE c.user_id = v_user_id
    AND (c.updated_at > p_since OR c.deleted_at > p_since)
  ORDER BY c.updated_at ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

COMMENT ON FUNCTION public.get_changes(timestamptz, integer, integer)
  IS 'Delta-Sync: Liefert Fang-Änderungen + Tombstones seit p_since. Pagination via p_limit/p_offset.';
