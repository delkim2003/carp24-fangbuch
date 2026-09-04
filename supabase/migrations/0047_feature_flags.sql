-- 0047_feature_flags.sql — Feature-Flags für Admin-Panel
CREATE TABLE IF NOT EXISTS public.feature_flags (
  key text PRIMARY KEY,
  value boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY feature_flags_select_all ON public.feature_flags
  FOR SELECT TO anon, authenticated USING (true);
-- Nur service_role darf schreiben (keine UPDATE/INSERT-Policy für anon/authenticated)

INSERT INTO public.feature_flags (key, value) VALUES ('registration_enabled', true) ON CONFLICT (key) DO NOTHING;
INSERT INTO public.feature_flags (key, value) VALUES ('chat_enabled', true) ON CONFLICT (key) DO NOTHING;
INSERT INTO public.feature_flags (key, value) VALUES ('marketplace_enabled', true) ON CONFLICT (key) DO NOTHING;