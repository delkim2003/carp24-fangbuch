-- 0051_fix_profiles_rls_security.sql
-- P0-1: Verhindert, dass Free-User is_pro/role selbst setzen können.
--
-- MUSS ALS supabase_admin AUSGEFÜHRT WERDEN (Table Owner).
-- In Supabase CLI: läuft automatisch als supabase_admin.
--
-- Problem: profiles_update_owner USING (id = auth.uid()) prüft nur Ownership,
-- aber nicht WELCHE Spalten geändert werden. Supabase gibt authenticated
-- standardmäßig UPDATE auf alle Spalten → User kann is_pro=true, role='ADMIN' setzen.
--
-- Fix: Column-Level REVOKE/GRANT. Entfernt UPDATE auf sensitive Spalten
-- für authenticated. Service_role (Supabase Admin) behält volle Rechte.

-- 1) Entferne blanket UPDATE für authenticated
REVOKE UPDATE ON public.profiles FROM authenticated;

-- 2) Erlaube UPDATE nur auf sichere Spalten
GRANT UPDATE (
  display_name,
  bio,
  avatar_url,
  home_water,
  privacy_spots,
  deleted_at
) ON public.profiles TO authenticated;

-- 3) Index für schnelle Tier-Abfragen (Middleware + API)
CREATE INDEX IF NOT EXISTS idx_profiles_is_pro
  ON public.profiles (id, is_pro)
  WHERE is_pro = true;
