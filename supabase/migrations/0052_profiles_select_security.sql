-- 0052_profiles_select_security.sql
-- HIGH: Profiles SELECT — sensible Spalten für authenticated einschränken
-- Problem: profiles_select_authenticated USING (true) erlaubt es jedem User,
-- is_pro und role aller anderen User zu lesen → Admin-Accounts sichtbar.
--
-- Fix: Column-Level REVOKE/GRANT (wie 0051 für UPDATE bereits gemacht)
--      Service_role behält vollen Zugriff (Supabase Admin, Webhooks, Middleware)
--      Bestehende Queries (board, chat, forum) lesen nur display_name/avatar_url → funktionieren weiter
--      is_pro/role wird via Service-Role Client in profil.astro/premium.astro gelesen

-- 1) SELECT auf sichere Spalten beschränken
REVOKE SELECT ON public.profiles FROM authenticated;

GRANT SELECT (
  id,
  display_name,
  avatar_url,
  bio,
  home_water,
  privacy_spots,
  created_at,
  deleted_at
) ON public.profiles TO authenticated;

-- 2) Service_role behält vollen Zugriff (wird durch supabase_admin abgedeckt)
-- 3) is_pro/role wird via createServiceClient() in ssr-client.ts gelesen
