-- ============================================================================
-- 0013_my_sessions.sql — Sessions-Verwaltung (Task 1.4a, Option A)
-- Ermöglicht dem User: eigene Sessions sehen + einzelne abmelden.
-- Sicherheits-Prinzip: SECURITY DEFINER + auth.uid()-Check + nur EIGENE Sessions.
-- KEIN dynamisches SQL, KEINE Injection-Möglichkeit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Funktion: list_my_sessions() → eigene Sessions mit Geräte-Info
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_my_sessions()
RETURNS TABLE(
  session_id  uuid,
  created_at  timestamptz,
  last_used   timestamptz,
  aal_level   text,
  user_agent  text,
  ip          inet,
  is_aal2     boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    s.id::uuid,
    s.created_at,
    COALESCE(s.updated_at, s.created_at),
    s.aal::text,
    s.user_agent,
    s.ip,
    (s.aal = 'aal2')
  FROM auth.sessions s
  WHERE s.user_id = v_uid
  ORDER BY s.created_at DESC;
END;
$fn$;

-- ----------------------------------------------------------------------------
-- Funktion: revoke_my_session(p_session_id) → eigene Session beenden
-- Löscht NUR die Session des aufrufenden Users. Fremde Sessions → Fehler.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revoke_my_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid uuid;
  v_count int;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  DELETE FROM auth.sessions s
  WHERE s.id = p_session_id
    AND s.user_id = v_uid;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'session not found or not owned by user';
  END IF;
END;
$fn$;

-- ----------------------------------------------------------------------------
-- Grants: NUR authenticated + service_role (wie bei den Stats-Funktionen, 0010)
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.list_my_sessions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_my_sessions() FROM anon;
GRANT EXECUTE ON FUNCTION public.list_my_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_sessions() TO service_role;

REVOKE ALL ON FUNCTION public.revoke_my_session(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_my_session(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.revoke_my_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_my_session(uuid) TO service_role;
