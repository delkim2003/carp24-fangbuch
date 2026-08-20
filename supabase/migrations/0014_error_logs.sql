-- ============================================================================
-- 0014_error_logs.sql — Error-Tracking (Task 1.13)
-- Client-Fehler werden in public.error_logs gespeichert (via RLS-INSERT).
-- Sicherheits-Prinzip:
--   - INSERT: nur authenticated (mit eigener user_id, via Trigger)
--   - SELECT: nur EIGENE Fehler (RLS) — Admin-Konsole (3.7, Phase 3) via service_role
--   - KEIN UPDATE/DELETE für User (nur service_role)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: error_logs
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.error_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  level       text NOT NULL DEFAULT 'error',          -- error | warning | info
  source      text NOT NULL DEFAULT 'client',         -- client | server | edge
  url         text,                                    -- wo passiert
  message     text,                                    -- Fehlermeldung (gekürzt)
  stack       text,                                    -- Stack-Trace (gekürzt)
  context     jsonb DEFAULT '{}'::jsonb                -- extra Infos (keine Secrets!)
);

-- ----------------------------------------------------------------------------
-- Trigger: user_id automatisch aus auth.uid() setzen (wie catches, 0005)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_error_log_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  NEW.user_id := auth.uid();
  -- Nachricht/Stack begrenzen (Missbrauch-Schutz)
  IF NEW.message IS NOT NULL THEN
    NEW.message := left(NEW.message, 2000);
  END IF;
  IF NEW.stack IS NOT NULL THEN
    NEW.stack := left(NEW.stack, 4000);
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_set_error_log_user_id ON public.error_logs;
CREATE TRIGGER trg_set_error_log_user_id
  BEFORE INSERT ON public.error_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_error_log_user_id();

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

-- INSERT: authenticated darf Fehler anlegen (user_id wird per Trigger gesetzt)
CREATE POLICY "error_logs_insert_own" ON public.error_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- SELECT: nur eigene Fehler
CREATE POLICY "error_logs_select_own" ON public.error_logs
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Keine UPDATE/DELETE-Policies für authenticated (Default-Deny)
-- Admin (Phase 3, 3.7) liest via service_role.

-- ----------------------------------------------------------------------------
-- Grants: anon bekommt NICHTS (Fehler nur von eingeloggten Usern)
-- ----------------------------------------------------------------------------
REVOKE ALL ON public.error_logs FROM anon;
GRANT SELECT, INSERT ON public.error_logs TO authenticated;
GRANT ALL ON public.error_logs TO service_role;
