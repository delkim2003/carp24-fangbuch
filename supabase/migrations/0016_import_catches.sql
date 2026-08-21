-- 0016_import_catches.sql
-- CSV-Import: RPC import_catches(p_catches jsonb, p_user_id uuid)
-- Validiert wie publish_catch, sammelt Fehler, max 500 Zeilen.

CREATE OR REPLACE FUNCTION public.import_catches(
  p_catches jsonb,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_user_id    uuid;
  v_imported   int := 0;
  v_failed     jsonb := '[]'::jsonb;
  v_row        jsonb;
  v_species    text;
  v_weight     numeric;
  v_lat        numeric;
  v_lng        numeric;
  v_catch_ts   timestamptz;
  v_water_name text;
  v_notes      text;
  v_bait       text;
  v_row_num    int;
  v_total      int;
  v_orig_total int;
  v_reason     text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF v_user_id <> p_user_id THEN
    RAISE EXCEPTION 'user_id mismatch';
  END IF;

  IF p_catches IS NULL OR jsonb_array_length(p_catches) = 0 THEN
    RETURN jsonb_build_object('imported', 0, 'failed', '[]'::jsonb);
  END IF;

  v_orig_total := jsonb_array_length(p_catches);
  v_total := LEAST(v_orig_total, 500);

  FOR i IN 0..v_total - 1 LOOP
    v_row := p_catches -> i;
    v_row_num := i + 1;
    v_reason := '';

    BEGIN v_species := v_row ->> 'species'; EXCEPTION WHEN OTHERS THEN v_species := NULL; END;
    BEGIN v_weight  := (v_row ->> 'weight_kg')::numeric; EXCEPTION WHEN OTHERS THEN v_weight := NULL; END;
    BEGIN v_catch_ts := (v_row ->> 'catch_ts')::timestamptz; EXCEPTION WHEN OTHERS THEN v_catch_ts := NULL; END;
    v_water_name := v_row ->> 'water_name';
    v_notes      := v_row ->> 'notes';
    v_bait       := v_row ->> 'koeder';
    BEGIN v_lat := NULLIF(v_row ->> 'lat', '')::numeric; EXCEPTION WHEN OTHERS THEN v_lat := NULL; END;
    BEGIN v_lng := NULLIF(v_row ->> 'lng', '')::numeric; EXCEPTION WHEN OTHERS THEN v_lng := NULL; END;

    IF v_species IS NULL OR v_species NOT IN ('SPIEGEL','LEDER','SCHUPPEN','AMUR','ANDERE') THEN
      v_reason := v_reason || 'Ungültige Fischart: ' || COALESCE(v_species, 'leer') || '. ';
    END IF;

    IF v_weight IS NULL OR v_weight <= 0 OR v_weight >= 100 THEN
      v_reason := v_reason || 'Ungültiges Gewicht: ' || COALESCE(v_weight::text, 'leer') || '. ';
    END IF;

    IF (v_lat IS NULL AND v_lng IS NOT NULL) OR (v_lat IS NOT NULL AND v_lng IS NULL) THEN
      v_reason := v_reason || 'Lat/Lng müssen beide gesetzt oder beide leer sein. ';
    END IF;

    IF v_catch_ts IS NULL THEN
      v_reason := v_reason || 'Ungültiges Datum. ';
    ELSIF v_catch_ts > now() THEN
      v_reason := v_reason || 'Datum in der Zukunft. ';
    END IF;

    IF v_notes IS NOT NULL AND char_length(v_notes) > 1000 THEN
      v_reason := v_reason || 'Notizen zu lang (max 1000). ';
    END IF;

    IF v_reason <> '' THEN
      v_failed := v_failed || jsonb_build_object('row', v_row_num, 'reason', rtrim(v_reason));
    ELSE
      BEGIN
        INSERT INTO public.catches
          (user_id, catch_ts, species, weight_kg, water_name, lat, lng, notes, bait, photos, draft)
        VALUES
          (p_user_id, v_catch_ts, v_species::public.species_enum, v_weight,
           NULLIF(v_water_name, ''), v_lat, v_lng, NULLIF(v_notes, ''), NULLIF(v_bait, ''),
           '{}'::text[], false);
        v_imported := v_imported + 1;
      EXCEPTION WHEN OTHERS THEN
        v_failed := v_failed || jsonb_build_object('row', v_row_num, 'reason', 'DB-Fehler: ' || SQLERRM);
      END;
    END IF;
  END LOOP;

  IF v_orig_total > 500 THEN
    v_failed := v_failed || jsonb_build_object('row', 0, 'reason', 'max 500 Zeilen — nur erste 500 verarbeitet');
  END IF;

  RETURN jsonb_build_object('imported', v_imported, 'failed', v_failed);
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.import_catches(jsonb, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.import_catches(jsonb, uuid) TO authenticated;

COMMENT ON FUNCTION public.import_catches(jsonb, uuid)
  IS 'CSV-Import: validiert Zeilen wie publish_catch, sammelt Fehler, max 500. EXECUTE nur authenticated.';
