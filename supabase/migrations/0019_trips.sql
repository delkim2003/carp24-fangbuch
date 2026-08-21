-- 0019_trips.sql — Angelausflüge (A4) — Schema-Update für bestehende trips-Tabelle

-- ============================================================================
-- 1) trips-Tabelle an neues Schema anpassen
-- ============================================================================
-- Bestehende Tabelle hat: water_id, start (timestamptz), end (timestamptz)
-- Ziel: name, start_date (date), end_date (date), notes

-- name-Spalte hinzufügen (falls nicht vorhanden)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'name'
  ) THEN
    ALTER TABLE public.trips ADD COLUMN name text NOT NULL DEFAULT 'Angelausflug';
    ALTER TABLE public.trips ADD CONSTRAINT trips_name_check CHECK (char_length(name) BETWEEN 1 AND 100);
  END IF;
END $$;

-- start_date/end_date als date-Spalten hinzufügen (falls nicht vorhanden)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'start_date'
  ) THEN
    ALTER TABLE public.trips ADD COLUMN start_date date;
    ALTER TABLE public.trips ADD COLUMN end_date date;
    -- Bestehende start/end-Daten migrieren
    UPDATE public.trips SET start_date = start::date, end_date = "end"::date WHERE start IS NOT NULL;
  END IF;
END $$;

-- notes-Constraint anpassen (falls nötig)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_schema = 'public' AND constraint_name = 'trips_notes_check'
  ) THEN
    ALTER TABLE public.trips ADD CONSTRAINT trips_notes_check CHECK (char_length(notes) <= 1000);
  END IF;
END $$;

-- Alte Constraints entfernen (falls vorhanden)
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_end_after_start;

-- Alte start/end-Spalten (timestamptz) nullable: neues UI nutzt start_date/end_date
ALTER TABLE public.trips ALTER COLUMN start DROP NOT NULL;
ALTER TABLE public.trips ALTER COLUMN "end" DROP NOT NULL;

-- user_id DEFAULT: RLS WITH CHECK (user_id = auth.uid()) sonst NULL-Fehler (42501)
ALTER TABLE public.trips ALTER COLUMN user_id SET DEFAULT auth.uid();

-- ============================================================================
-- 2) catches.trip_id (nullable FK)
-- ============================================================================
ALTER TABLE public.catches
  ADD COLUMN IF NOT EXISTS trip_id uuid REFERENCES public.trips(id) ON DELETE SET NULL;

-- ============================================================================
-- 3) publish_catch erweitern: neuer Parameter p_trip_id
-- ============================================================================
CREATE OR REPLACE FUNCTION public.publish_catch(
  p_catch_id uuid,
  p_trip_id  uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_user_id  uuid;
  v_catch    record;
  v_count    integer;
  v_is_pro   boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

  SELECT * INTO v_catch FROM public.catches WHERE id = p_catch_id;

  IF v_catch IS NULL THEN
    RAISE EXCEPTION 'catch not found';
  END IF;

  IF v_catch.user_id <> v_user_id THEN
    RAISE EXCEPTION 'not your catch';
  END IF;

  IF v_catch.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'catch is deleted';
  END IF;

  IF v_catch.draft = false THEN
    RAISE EXCEPTION 'catch already published';
  END IF;

  -- Entitlement: PRO nutzt kein Limit, Free ≤ 50
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = v_user_id
      AND plan = 'PRO'
      AND status = 'ACTIVE'
      AND active_until > now()
  ) INTO v_is_pro;

  IF NOT v_is_pro THEN
    SELECT count(*) INTO v_count
    FROM public.catches
    WHERE user_id = v_user_id
      AND draft = false
      AND deleted_at IS NULL;

    IF v_count >= 50 THEN
      RAISE EXCEPTION 'free tier limit of 50 catches reached — upgrade to PRO';
    END IF;
  END IF;

  UPDATE public.catches
  SET draft      = false,
      trip_id    = CASE
                     WHEN p_trip_id IS NOT NULL
                       AND EXISTS (
                         SELECT 1 FROM public.trips t
                         WHERE t.id = p_trip_id AND t.user_id = v_user_id
                       )
                     THEN p_trip_id
                     ELSE NULL
                   END,
      updated_at = now()
  WHERE id = p_catch_id;
END;
$fn$;

-- ============================================================================
-- 4) Grants für neue Signatur
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.publish_catch(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.publish_catch(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION public.publish_catch(uuid, uuid)
  IS 'Veröffentlicht Catch + optional trip_id zuordnen (nur eigene Trips). EXECUTE nur authenticated.';
