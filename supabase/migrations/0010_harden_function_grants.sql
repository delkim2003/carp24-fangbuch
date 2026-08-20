-- 0010_harden_function_grants.sql
-- SECURITY-HÄRTUNG (Experten-QA 20.08.):
-- Die 7 API-Funktionen hatten EXECUTE für PUBLIC+anon (Default bei CREATE FUNCTION).
-- auth.uid()-Check blockt anon zwar, aber Defense-in-Depth: EXECUTE NUR für authenticated.
-- anon bekommt keinen Zugriff auf Sync/Statistik-Funktionen.

REVOKE EXECUTE ON FUNCTION public.sync_catch(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_changes(timestamptz, integer, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stats_conditions(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stats_drilldown(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_catch(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_post(uuid, text, text, numeric, text, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.sync_catch(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_changes(timestamptz, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stats_conditions(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stats_drilldown(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stats_beste_kombis(jsonb, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_catch(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_post(uuid, text, text, numeric, text, text) TO authenticated;

COMMENT ON FUNCTION public.sync_catch(uuid, jsonb) IS 'EXECUTE nur authenticated (Härtung 0010)';
