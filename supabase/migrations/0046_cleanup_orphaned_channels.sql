-- 0046_cleanup_orphaned_channels.sql
-- Orphaned Tabellen 'channels' und 'channel_members' aus 0001_init aufräumen.
-- Die Chat-Architektur wurde in 0022/0041 auf eine globale chat_messages-Tabelle
-- (ohne channel_id) umgestellt. Beide Tabellen mit ihren RLS-Policies,
-- Indizes und Realtime-Subscriptions existieren ungenutzt weiter.

-- ============================================================================
-- 1) Sicherheitsprüfung: Enthalten die Tabellen Daten?
-- ============================================================================
DO $$
DECLARE
  v_channel_count  integer;
  v_member_count   integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'channels'
  ) THEN
    RAISE NOTICE 'channels does not exist, nothing to clean up';
    RETURN;
  END IF;

  SELECT count(*) INTO v_channel_count FROM public.channels;
  SELECT count(*) INTO v_member_count  FROM public.channel_members;

  IF v_channel_count > 0 OR v_member_count > 0 THEN
    RAISE NOTICE 'WARNING: channels=%, channel_members=% – data will be dropped',
      v_channel_count, v_member_count;
  ELSE
    RAISE NOTICE 'channels and channel_members are empty, safe to drop';
  END IF;
END $$;

-- ============================================================================
-- 2) Realtime-Subscriptions entfernen
-- ============================================================================
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.channel_members;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.channels;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ============================================================================
-- 3) channel_members zuerst droppen (hat FK zu channels)
--    Policies + Index werden automatisch mit CASCADE entfernt,
--    aber explizit droppen ist sauberer.
-- ============================================================================
DROP POLICY IF EXISTS channel_members_select_own      ON public.channel_members;
DROP POLICY IF EXISTS channel_members_insert_by_creator ON public.channel_members;

DROP INDEX IF EXISTS public.idx_channel_members_user_id;

DROP TABLE IF EXISTS public.channel_members CASCADE;

-- ============================================================================
-- 4) channels droppen
-- ============================================================================
DROP POLICY IF EXISTS channels_select_member ON public.channels;
DROP POLICY IF EXISTS channels_insert_creator ON public.channels;

DROP TABLE IF EXISTS public.channels CASCADE;