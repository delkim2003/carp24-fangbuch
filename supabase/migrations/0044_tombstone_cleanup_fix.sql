-- ============================================================================
-- carp24 Fangbuch — 0044_tombstone_cleanup_fix.sql
-- Fix für 0043: cleanup_old_tombstones() referenziert deleted_at auf Tabellen
-- die es nicht haben (forum_threads, forum_posts, chat_messages, marketplace_items)
-- ============================================================================

BEGIN;

-- Korrigierte Funktion: nur catches + posts haben deleted_at
CREATE OR REPLACE FUNCTION public.cleanup_old_tombstones()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Fänge: hard-delete nach 90 Tagen (hat deleted_at)
  DELETE FROM public.catches
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Posts: hard-delete nach 90 Tagen (hat deleted_at)
  DELETE FROM public.posts
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Profiles: hard-delete nach 90 Tagen (hat deleted_at)
  -- ACHTUNG: Nur wenn keine FK-Constraints mehr greifen
  -- DELETE FROM public.profiles
  -- WHERE deleted_at IS NOT NULL
  --   AND deleted_at < now() - interval '90 days';
END;
$function$;

-- Grants beibehalten
REVOKE EXECUTE ON FUNCTION public.cleanup_old_tombstones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_old_tombstones() TO service_role;

COMMENT ON FUNCTION public.cleanup_old_tombstones()
  IS 'Hard-delete von Tombstones älter als 90 Tagen. Nur catches + posts (haben deleted_at). Via pg_cron oder manuell aufrufen.';

COMMIT;
