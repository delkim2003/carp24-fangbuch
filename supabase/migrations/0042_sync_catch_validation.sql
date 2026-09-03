-- ============================================================================
-- 0042_sync_catch_validation.sql
-- SPRINT 1 — S1.06: Server-seitige Input-Validierung für sync_catch.
-- Die catches-Tabelle hat CHECK constraints, aber sync_catch (SECURITY DEFINER)
-- umgeht RLS und schreibt direkt. Ohne Validierung kann beliebig langen Text
-- einschleusen. Diese Migration fügt Validierung VOR dem Schreiben ein.
--
-- Limits:
--   notes:          max 1000 Zeichen  (CHECK existiert in catches Tabelle)
--   bait:           max  200 Zeichen
--   method:         max  200 Zeichen
--   water_name:     max  500 Zeichen
--   species_custom: max  100 Zeichen
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

  -- ── Input-Längenvalidierung (unabhängig von CHECK in catches) ──────────
  IF p_data ->> 'notes' IS NOT NULL
     AND char_length(p_data ->> 'notes') > 1000 THEN
    RAISE EXCEPTION 'notes too long (max 1000 chars, got %)', char_length(p_data ->> 'notes');
  END IF;

  IF p_data ->> 'bait' IS NOT NULL
     AND char_length(p_data ->> 'bait') > 200 THEN
    RAISE EXCEPTION 'bait too long (max 200 chars, got %)', char_length(p_data ->> 'bait');
  END IF;

  IF p_data ->> 'method' IS NOT NULL
     AND char_length(p_data ->> 'method') > 200 THEN
    RAISE EXCEPTION 'method too long (max 200 chars, got %)', char_length(p_data ->> 'method');
  END IF;

  IF p_data ->> 'water_name' IS NOT NULL
     AND char_length(p_data ->> 'water_name') > 500 THEN
    RAISE EXCEPTION 'water_name too long (max 500 chars, got %)', char_length(p_data ->> 'water_name');
  END IF;

  IF p_data ->> 'species_custom' IS NOT NULL
     AND char_length(p_data ->> 'species_custom') > 100 THEN
    RAISE EXCEPTION 'species_custom too long (max 100 chars, got %)', char_length(p_data ->> 'species_custom');
  END IF;

  -- ── Normaler Sync-Flow ─────────────────────────────────────────────────
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
  IS 'Idempotenter Offline-Sync-Upsert: LWW via client_updated_at. Inkl. Input-Validierung (0042). Max-Längen: notes<=1000, bait<=200, method<=200, water_name<=500, species_custom<=100.';