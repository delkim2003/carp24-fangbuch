-- 0023_pro_gating.sql — Pro-Gating (D1)
-- Fügt is_pro-Flag zur profiles-Tabelle hinzu.
-- Lesezugriff für eigene RLS-Policy existiert bereits (profiles_select_authenticated).
-- Schreiben nur via service_role (RPC/Webhook), nicht durch User.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_pro boolean NOT NULL DEFAULT false;

-- Admin-Flag für Philipp (info@einfach-online.dev) über auth.users-E-Mail
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'email'
  ) THEN
    -- profiles hat eine email-Spalte → direkt
    UPDATE public.profiles SET role = 'ADMIN' WHERE email = 'info@einfach-online.dev';
  ELSE
    -- Kein email-Feld auf profiles → über auth.users joinen
    UPDATE public.profiles p SET role = 'ADMIN'
    FROM auth.users u
    WHERE p.id = u.id AND u.email = 'info@einfach-online.dev';
  END IF;
END $$;
