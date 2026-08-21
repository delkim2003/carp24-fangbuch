-- 0026_marketplace.sql — Marktplatz (E4)
CREATE TABLE IF NOT EXISTS public.marketplace_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  category text NOT NULL DEFAULT 'andere',
  photos text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','sold')),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.marketplace_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "marketplace_read" ON public.marketplace_items FOR SELECT TO authenticated USING (status = 'active' OR user_id = auth.uid());
CREATE POLICY "marketplace_insert" ON public.marketplace_items FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "marketplace_update" ON public.marketplace_items FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "marketplace_delete" ON public.marketplace_items FOR DELETE TO authenticated USING (user_id = auth.uid());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketplace_items TO authenticated;
ALTER TABLE public.marketplace_items DROP CONSTRAINT IF EXISTS marketplace_items_user_profiles_fk;
ALTER TABLE public.marketplace_items ADD CONSTRAINT marketplace_items_user_profiles_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS marketplace_items_status_idx ON public.marketplace_items(status, created_at DESC);
