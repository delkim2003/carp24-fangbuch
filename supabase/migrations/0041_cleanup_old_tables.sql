-- 0041_cleanup_old_tables.sql
-- Alte doppelte Tabellen aus 0001_init aufräumen
-- Mapping:
--   forum_topics       → forum_threads
--   forum_posts (old)  → forum_posts (new, thread_id statt topic_id)
--   chat_messages (old)→ chat_messages (new, body statt message, ohne channel_id)
--   marketplace_listings → marketplace_items
--   marketplace_messages → marketplace_contacts

-- ============================================================================
-- 1) forum_topics → forum_threads
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'forum_topics' AND table_schema = 'public') THEN
    SELECT count(*) INTO v_count FROM public.forum_topics;
    IF v_count > 0 THEN
      INSERT INTO public.forum_threads (id, user_id, title, body, created_at, updated_at)
      SELECT id, user_id, title, COALESCE(body, ''), created_at, created_at
      FROM public.forum_topics
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Migrated % rows from forum_topics to forum_threads', v_count;
    ELSE
      RAISE NOTICE 'forum_topics is empty, skipping migration';
    END IF;
  ELSE
    RAISE NOTICE 'forum_topics does not exist, skipping';
  END IF;
END $$;

-- ============================================================================
-- 2) forum_posts (old: topic_id) → forum_posts (new: thread_id)
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_posts' AND column_name = 'topic_id' AND table_schema = 'public') THEN
    SELECT count(*) INTO v_count FROM public.forum_posts;
    IF v_count > 0 THEN
      ALTER TABLE public.forum_posts RENAME TO forum_posts_old;
      CREATE TABLE public.forum_posts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        thread_id uuid NOT NULL REFERENCES public.forum_threads(id) ON DELETE CASCADE,
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
        created_at timestamptz NOT NULL DEFAULT now()
      );
      INSERT INTO public.forum_posts (id, thread_id, user_id, body, created_at)
      SELECT id, topic_id, user_id, COALESCE(body, ''), created_at
      FROM public.forum_posts_old
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Migrated % rows from old forum_posts to new forum_posts', v_count;
      DROP TABLE IF EXISTS public.forum_posts_old;
    ELSE
      DROP TABLE IF EXISTS public.forum_posts;
      RAISE NOTICE 'old forum_posts was empty, dropped';
    END IF;
  ELSE
    RAISE NOTICE 'old forum_posts (with topic_id) does not exist, skipping';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.forum_threads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- FK zu profiles für PostgREST-Relation
ALTER TABLE public.forum_posts DROP CONSTRAINT IF EXISTS forum_posts_user_profiles_fk;
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_user_profiles_fk
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- ============================================================================
-- 3) chat_messages (old: channel_id, message) → chat_messages (new: body)
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_messages' AND column_name = 'channel_id' AND table_schema = 'public') THEN
    SELECT count(*) INTO v_count FROM public.chat_messages;
    IF v_count > 0 THEN
      ALTER TABLE public.chat_messages RENAME TO chat_messages_old;
      CREATE TABLE public.chat_messages (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
        created_at timestamptz NOT NULL DEFAULT now()
      );
      INSERT INTO public.chat_messages (id, user_id, body, created_at)
      SELECT id, user_id, COALESCE(message, ''), created_at
      FROM public.chat_messages_old
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Migrated % rows from old chat_messages to new chat_messages', v_count;
      DROP TABLE IF EXISTS public.chat_messages_old;
    ELSE
      DROP TABLE IF EXISTS public.chat_messages;
      RAISE NOTICE 'old chat_messages was empty, dropped';
    END IF;
  ELSE
    RAISE NOTICE 'old chat_messages (with channel_id) does not exist, skipping';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- FK zu profiles für PostgREST-Relation
ALTER TABLE public.chat_messages DROP CONSTRAINT IF EXISTS chat_messages_user_profiles_fk;
ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_user_profiles_fk
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- ============================================================================
-- 4) marketplace_listings → marketplace_items
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'marketplace_listings' AND table_schema = 'public') THEN
    SELECT count(*) INTO v_count FROM public.marketplace_listings;
    IF v_count > 0 THEN
      INSERT INTO public.marketplace_items (id, user_id, title, description, price, category, photos, status, created_at)
      SELECT
        id, user_id,
        COALESCE(title, ''),
        COALESCE(description, ''),
        COALESCE(price, 0),
        COALESCE(category, 'andere'),
        COALESCE(photos, '{}'),
        CASE
          WHEN status = 'AVAILABLE' THEN 'active'
          WHEN status = 'SOLD' THEN 'sold'
          ELSE 'active'
        END,
        created_at
      FROM public.marketplace_listings
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Migrated % rows from marketplace_listings to marketplace_items', v_count;
    ELSE
      RAISE NOTICE 'marketplace_listings is empty, skipping migration';
    END IF;
  ELSE
    RAISE NOTICE 'marketplace_listings does not exist, skipping';
  END IF;
END $$;

-- ============================================================================
-- 5) marketplace_messages → marketplace_contacts
-- ============================================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'marketplace_messages' AND table_schema = 'public') THEN
    SELECT count(*) INTO v_count FROM public.marketplace_messages;
    IF v_count > 0 THEN
      INSERT INTO public.marketplace_contacts (id, item_id, from_user, to_user, message, created_at)
      SELECT
        id, listing_id, from_user, to_user,
        COALESCE(message, ''),
        created_at
      FROM public.marketplace_messages
      WHERE from_user IS NOT NULL AND to_user IS NOT NULL
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Migrated % rows from marketplace_messages to marketplace_contacts', v_count;
    ELSE
      RAISE NOTICE 'marketplace_messages is empty, skipping migration';
    END IF;
  ELSE
    RAISE NOTICE 'marketplace_messages does not exist, skipping';
  END IF;
END $$;

-- ============================================================================
-- 6) Alte Indizes droppen
-- ============================================================================
DROP INDEX IF EXISTS public.idx_forum_topics_created_at;
DROP INDEX IF EXISTS public.idx_forum_posts_topic_id;
DROP INDEX IF EXISTS public.idx_chat_messages_channel_created;
DROP INDEX IF EXISTS public.idx_marketplace_listings_status;
DROP INDEX IF EXISTS public.idx_marketplace_messages_listing_id;
DROP INDEX IF EXISTS public.idx_marketplace_messages_to_user;
DROP INDEX IF EXISTS public.idx_marketplace_messages_from_user;

-- ============================================================================
-- 7) Alte Tabellen droppen (CASCADE wegen FK-Abhängigkeiten)
-- ============================================================================
DROP TABLE IF EXISTS public.marketplace_messages CASCADE;
DROP TABLE IF EXISTS public.marketplace_listings CASCADE;
DROP TABLE IF EXISTS public.forum_topics CASCADE;

-- ============================================================================
-- 8) RLS + Policies für neue Tabellen sicherstellen
-- ============================================================================
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'forum_posts_read' AND tablename = 'forum_posts') THEN
    CREATE POLICY "forum_posts_read" ON public.forum_posts FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'forum_posts_insert' AND tablename = 'forum_posts') THEN
    CREATE POLICY "forum_posts_insert" ON public.forum_posts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'forum_posts_update_own' AND tablename = 'forum_posts') THEN
    CREATE POLICY "forum_posts_update_own" ON public.forum_posts FOR UPDATE TO authenticated USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'forum_posts_delete_own' AND tablename = 'forum_posts') THEN
    CREATE POLICY "forum_posts_delete_own" ON public.forum_posts FOR DELETE TO authenticated USING (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_messages_read' AND tablename = 'chat_messages') THEN
    CREATE POLICY "chat_messages_read" ON public.chat_messages FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_messages_insert_own' AND tablename = 'chat_messages') THEN
    CREATE POLICY "chat_messages_insert_own" ON public.chat_messages FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_messages_delete_own' AND tablename = 'chat_messages') THEN
    CREATE POLICY "chat_messages_delete_own" ON public.chat_messages FOR DELETE TO authenticated USING (user_id = auth.uid());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.forum_posts TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.chat_messages TO authenticated;

-- Index für forum_posts
CREATE INDEX IF NOT EXISTS forum_posts_thread_idx ON public.forum_posts(thread_id, created_at);

-- ============================================================================
-- 9) soft_delete_cascade aktualisieren
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
    UPDATE public.reports SET reason = NULL WHERE reporter_id = NEW.id;
    UPDATE public.trips SET notes = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.notifications SET payload = NULL WHERE user_id = NEW.id;
    UPDATE public.waters SET name = 'gelöschter Nutzer', lat = NULL, lng = NULL WHERE owner_id = NEW.id AND public = false;
  END IF;
  RETURN NEW;
END;
$fn$;

-- ============================================================================
-- 10) Alte ENUMs droppen
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_status') THEN
    DROP TYPE public.listing_status;
    RAISE NOTICE 'Dropped enum listing_status';
  END IF;
END $$;

-- ============================================================================
-- 11) Realtime
-- ============================================================================
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
