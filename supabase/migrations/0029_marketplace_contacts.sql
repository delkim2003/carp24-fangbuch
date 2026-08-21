-- 0029_marketplace_contacts.sql — Marktplatz Kontaktformular
CREATE TABLE IF NOT EXISTS public.marketplace_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.marketplace_items(id) ON DELETE CASCADE,
  from_user uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message text NOT NULL CHECK (char_length(message) BETWEEN 3 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.marketplace_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY marketplace_contacts_insert_own ON public.marketplace_contacts
  FOR INSERT TO authenticated WITH CHECK (from_user = auth.uid());
CREATE POLICY marketplace_contacts_select_participant ON public.marketplace_contacts
  FOR SELECT TO authenticated USING (from_user = auth.uid() OR to_user = auth.uid());
GRANT SELECT, INSERT ON public.marketplace_contacts TO authenticated;
CREATE INDEX IF NOT EXISTS marketplace_contacts_to_user_idx ON public.marketplace_contacts(to_user, created_at DESC);
