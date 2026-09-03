-- ============================================================================
-- carp24 Fangbuch — 0043_tombstone_cleanup.sql
-- Soft-Delete Cleanup: Hard-delete von Tombstones älter als 90 Tage
-- ============================================================================

BEGIN;

-- 1) Cleanup-Funktion für catches
CREATE OR REPLACE FUNCTION public.cleanup_old_tombstones()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Fänge: hard-delete nach 90 Tagen
  DELETE FROM public.catches
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Forum-Posts: hard-delete nach 90 Tagen
  DELETE FROM public.forum_posts
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Forum-Threads: hard-delete nach 90 Tagen
  DELETE FROM public.forum_threads
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Chat-Messages: hard-delete nach 90 Tagen
  DELETE FROM public.chat_messages
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';

  -- Marketplace-Items: hard-delete nach 90 Tagen
  DELETE FROM public.marketplace_items
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '90 days';
END;
$function$;

-- 2) Grants: nur service_role darf aufrufen
REVOKE EXECUTE ON FUNCTION public.cleanup_old_tombstones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_old_tombstones() TO service_role;

-- 3) Kommentar
COMMENT ON FUNCTION public.cleanup_old_tombstones()
  IS 'Hard-delete von Tombstones älter als 90 Tagen. Via pg_cron oder manuell aufrufen.';

COMMIT;
