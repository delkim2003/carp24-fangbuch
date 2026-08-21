-- 0022_chat.sql — Community-Chat (C3)
-- Alte Entwurfs-Tabelle entfernen: nur wenn leer + altes Schema
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chat_messages' AND column_name='channel_id')
     AND NOT EXISTS (SELECT 1 FROM public.chat_messages) THEN
    DROP TABLE IF EXISTS public.chat_messages;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
-- Read: alle eingeloggten (Realtime braucht SELECT-Policy für Subscription)
CREATE POLICY "chat_messages_read" ON public.chat_messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "chat_messages_insert_own" ON public.chat_messages FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "chat_messages_delete_own" ON public.chat_messages FOR DELETE TO authenticated USING (user_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.chat_messages TO authenticated;

-- FK zu profiles für PostgREST-Relation (profiles(display_name))
ALTER TABLE public.chat_messages DROP CONSTRAINT IF EXISTS chat_messages_user_profiles_fk;
ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_user_profiles_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Realtime-Setup (Flood-Schutz client-seitig; RLS blockt Fremd-Insert)
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
