-- 0025_push_subscriptions.sql — Web-Push (E2)
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint text PRIMARY KEY,
  keys jsonb NOT NULL,               -- { p256dh, auth }
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "push_subscriptions_own" ON public.push_subscriptions FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.push_subscriptions TO authenticated;
-- FK zu profiles für PostgREST-Relation
ALTER TABLE public.push_subscriptions DROP CONSTRAINT IF EXISTS push_subscriptions_user_profiles_fk;
ALTER TABLE public.push_subscriptions ADD CONSTRAINT push_subscriptions_user_profiles_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;