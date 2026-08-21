-- DSA-Meldepflicht (Audit P0-2): Content-Reports für gemeldete Inhalte
CREATE TABLE IF NOT EXISTS public.content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type text NOT NULL CHECK (target_type IN ('catch','forum_post','forum_thread','chat_message','marketplace_item')),
  target_id text NOT NULL,
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 3 AND 500),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (target_type, target_id, reporter_id)
);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

-- Reporter kann eigenen Report lesen; JEDER angemeldete User kann melden (INSERT)
CREATE POLICY "reports_insert" ON public.content_reports FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
CREATE POLICY "reports_select_own" ON public.content_reports FOR SELECT TO authenticated USING (reporter_id = auth.uid());
-- Admin (service_role) sieht alle — RLS umgeht service_role automatisch

GRANT SELECT, INSERT ON public.content_reports TO authenticated;
