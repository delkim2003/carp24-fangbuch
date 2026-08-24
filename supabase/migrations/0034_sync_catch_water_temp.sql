-- ============================================================================
-- 0034_sync_catch_water_temp.sql
-- FIX (24.08., E2E-Befund): sync_catch kennt water_temp_c nicht —
-- das Feld wurde im Fang-Erfassen-Formular gesetzt, aber nie in der DB
-- gespeichert (UPDATE + INSERT ohne water_temp_c).
-- Erweitert sync_catch um water_temp_c (User-Eingabe, 0-40, nullable).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_catch(
  p_client_uuid     uuid,
  p_data            jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
        species_custom    = COALESCE(p_data ->> 'species_custom', species_custom),
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
        water_temp_c      = COALESCE((p_data ->> 'water_temp_c')::numeric, water_temp_c),
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
    species_custom,
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
    water_temp_c,
    client_updated_at
  ) VALUES (
    p_client_uuid,
    v_user_id,
    COALESCE((p_data ->> 'catch_ts')::timestamptz, now()),
    (p_data ->> 'species')::public.species_enum,
    p_data ->> 'species_custom',
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
    (p_data ->> 'water_temp_c')::numeric,
    v_client_ts
  )
  RETURNING id INTO v_catch_id;

  RETURN v_catch_id;
END;
$function$;

-- Grants wie gehabt (CREATE OR REPLACE behält ACLs in PG14+; Defense-in-Depth)
REVOKE EXECUTE ON FUNCTION public.sync_catch(uuid, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.sync_catch(uuid, jsonb) TO authenticated;

COMMENT ON FUNCTION public.sync_catch(uuid, jsonb)
  IS 'Idempotenter Offline-Sync-Upsert: LWW via client_updated_at. Inkl. species_custom (0011) und water_temp_c (0034).';
