-- 0045_cleanup_orphaned_reports.sql
-- Orphaned 'reports' Tabelle (0001_init) aufräumen.
-- Aktiver Nachfolger: 'content_reports' (0017).
-- Frontend nutzt bereits ausschliesslich content_reports.

-- ============================================================================
-- 1) Daten migrieren: reports → content_reports
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'reports' AND table_schema = 'public'
  ) THEN
    RAISE NOTICE 'reports table does not exist, skipping migration';
    RETURN;
  END IF;

  SELECT count(*) INTO v_count FROM public.reports;

  IF v_count = 0 THEN
    RAISE NOTICE 'reports is empty, skipping migration';
  ELSE
    INSERT INTO public.content_reports (id, target_type, target_id, reporter_id, reason, status, created_at)
    SELECT
      r.id,
      CASE r.target_type::text
        WHEN 'POST'          THEN 'forum_post'
        WHEN 'FORUM_TOPIC'   THEN 'forum_thread'
        WHEN 'FORUM_POST'    THEN 'forum_post'
        WHEN 'CHAT'          THEN 'chat_message'
        WHEN 'LISTING'       THEN 'marketplace_item'
        ELSE 'forum_post'
      END,
      r.target_id::text,
      r.reporter_id,
      COALESCE(r.reason, 'kein Grund angegeben'),
      CASE r.status::text
        WHEN 'OPEN'         THEN 'open'
        WHEN 'IN_PROGRESS'  THEN 'open'
        WHEN 'RESOLVED'     THEN 'resolved'
        WHEN 'REJECTED'     THEN 'dismissed'
        ELSE 'open'
      END,
      r.created_at
    FROM public.reports r
    WHERE r.reporter_id IS NOT NULL
    ON CONFLICT (target_type, target_id, reporter_id) DO NOTHING;

    RAISE NOTICE 'Migrated % rows from reports to content_reports', v_count;
  END IF;
END $$;

-- ============================================================================
-- 2) soft_delete_cascade: reports-Referenz entfernen
-- ============================================================================
CREATE OR REPLACE FUNCTION public.soft_delete_cascade()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    NEW.display_name := 'gelöschter Nutzer';
    NEW.bio          := '';
    NEW.avatar_url   := NULL;
    NEW.home_water   := NULL;

    UPDATE public.catches SET notes = NULL, bait = NULL, method = NULL,
           lat = NULL, lng = NULL, water_name = NULL WHERE user_id = NEW.id;
    UPDATE public.posts SET text = NULL WHERE user_id = NEW.id;
    UPDATE public.forum_threads SET title = 'gelöschter Nutzer', body = '' WHERE user_id = NEW.id;
    UPDATE public.forum_posts SET body = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.chat_messages SET body = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.marketplace_items SET title = 'gelöschter Nutzer', description = '', price = 0 WHERE user_id = NEW.id;
    UPDATE public.marketplace_contacts SET message = 'gelöschter Nutzer' WHERE from_user = NEW.id OR to_user = NEW.id;
    UPDATE public.trips SET notes = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.notifications SET payload = NULL WHERE user_id = NEW.id;
    UPDATE public.waters SET name = 'gelöschter Nutzer', lat = NULL, lng = NULL WHERE owner_id = NEW.id AND public = false;
  END IF;
  RETURN NEW;
END;
$fn$;

-- ============================================================================
-- 3) set_updated_at Trigger von reports entfernen
-- ============================================================================
DROP TRIGGER IF EXISTS set_updated_at ON public.reports;

-- ============================================================================
-- 4) Alte RLS Policies droppen
-- ============================================================================
DROP POLICY IF EXISTS reports_insert_reporter ON public.reports;
DROP POLICY IF EXISTS reports_select_mod_or_reporter ON public.reports;
DROP POLICY IF EXISTS reports_update_mod ON public.reports;

-- ============================================================================
-- 5) Alten Index droppen
-- ============================================================================
DROP INDEX IF EXISTS public.idx_reports_status_created;

-- ============================================================================
-- 6) Tabelle droppen (CASCADE wegen Trigger/FK)
-- ============================================================================
DROP TABLE IF EXISTS public.reports CASCADE;

-- ============================================================================
-- 7) Alte ENUMs droppen
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status') THEN
    DROP TYPE public.report_status;
    RAISE NOTICE 'Dropped enum report_status';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'target_type') THEN
    DROP TYPE public.target_type;
    RAISE NOTICE 'Dropped enum target_type';
  END IF;
END $$;
