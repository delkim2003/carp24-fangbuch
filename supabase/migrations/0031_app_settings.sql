-- Zentrale App-Einstellungen (Wartungsmodus etc.)
CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY app_settings_select_all ON public.app_settings
  FOR SELECT TO anon, authenticated USING (true);
-- Nur service_role darf schreiben (keine UPDATE/INSERT-Policy für anon/authenticated)
INSERT INTO public.app_settings (key, value) VALUES ('maintenance', '{"enabled": false, "message": ""}')
  ON CONFLICT (key) DO NOTHING;
