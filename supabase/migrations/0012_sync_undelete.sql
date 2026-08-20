-- 0012_sync_undelete.sql
-- EXPERTOEN-QA FIX (E2-Fund 2, 20.08.):
-- sync_catch überschrieb beim LWW-Update nie deleted_at → ein gelöschter Fang
-- (deleted_at gesetzt) konnte per Offline-Edit auf anderem Gerät nie reaktiviert werden.
-- LWW-Semantik: Der neueste client_updated_at gewinnt IMMER — auch gegen eine Löschung.
-- Wenn der Client einen Fang mit neuem timestamp editiert, wird deleted_at zurückgesetzt (Undelete).

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
        -- UNDELETE: neuester Client-Edit reaktiviert gelöschte Fänge
        deleted_at        = NULL,
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
    v_client_ts
  )
  RETURNING id INTO v_catch_id;

  RETURN v_catch_id;
END;
$function$;

COMMENT ON FUNCTION public.sync_catch(uuid, jsonb)
  IS 'Idempotenter Offline-Sync-Upsert: LWW via client_updated_at. Inkl. species_custom + Undelete (QA-Fix 0011/0012).';
