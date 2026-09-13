-- 0052_profiles_select_security.sql
-- HIGH: Profiles SELECT — sensible Spalten für authenticated einschränken
-- Problem: profiles_select_authenticated USING (true) erlaubt es jedem User,
-- is_pro und role aller anderen User zu lesen → Admin-Accounts sichtbar.
--
-- Fix: 1) Table-Level SELECT REVOKE (entfernt blanket Zugriff)
--      2) Column-Level SELECT GRANT nur für sichere Spalten
--      3) Service_role behält vollen Zugriff (Supabase Admin, Webhooks, Middleware)
--      4) is_pro/role wird via Service-Role Client gelesen (createServiceClient)

-- WICHTIG: Reihenfolge! Erst table-level REVOKE, dann column-level GRANT.
-- Sonst gewinnt das table-level GRANT über column-level.

-- 1) Table-Level SELECT entfernen
REVOKE SELECT ON public.profiles FROM authenticated;

-- 2) Column-Level SELECT nur für sichere Spalten
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

-- 3) Service_role behält vollen Zugriff (wird durch supabase_admin abgedeckt)
-- 4) is_pro/role wird via createServiceClient() in ssr-client.ts gelesen
