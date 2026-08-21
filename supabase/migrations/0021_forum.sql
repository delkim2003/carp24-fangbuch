-- 0021_forum.sql — Forum (C2)
-- Alte Entwurfs-Tabellen (topic_id-basiert, unbenutzt) entfernen: nur wenn leer + altes Schema
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='forum_posts' AND column_name='topic_id')
     AND NOT EXISTS (SELECT 1 FROM public.forum_posts) THEN
    DROP TABLE IF EXISTS public.forum_posts, public.forum_topics;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.forum_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.forum_threads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.forum_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
-- Threads: alle eingeloggten lesen, Autor schreibt/editiert/löscht
CREATE POLICY "forum_threads_read" ON public.forum_threads FOR SELECT TO authenticated USING (true);
CREATE POLICY "forum_threads_insert" ON public.forum_threads FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "forum_threads_update_own" ON public.forum_threads FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "forum_threads_delete_own" ON public.forum_threads FOR DELETE TO authenticated USING (user_id = auth.uid());
-- Posts: analog
CREATE POLICY "forum_posts_read" ON public.forum_posts FOR SELECT TO authenticated USING (true);
CREATE POLICY "forum_posts_insert" ON public.forum_posts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "forum_posts_update_own" ON public.forum_posts FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "forum_posts_delete_own" ON public.forum_posts FOR DELETE TO authenticated USING (user_id = auth.uid());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.forum_threads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.forum_posts TO authenticated;
-- Index für Antworten-Count
CREATE INDEX IF NOT EXISTS forum_posts_thread_idx ON public.forum_posts(thread_id, created_at);

-- FK zu profiles für PostgREST-Relation (profiles(display_name) in UI-Queries)
ALTER TABLE public.forum_threads DROP CONSTRAINT IF EXISTS forum_threads_user_profiles_fk;
ALTER TABLE public.forum_threads ADD CONSTRAINT forum_threads_user_profiles_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.forum_posts DROP CONSTRAINT IF EXISTS forum_posts_user_profiles_fk;
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_user_profiles_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
