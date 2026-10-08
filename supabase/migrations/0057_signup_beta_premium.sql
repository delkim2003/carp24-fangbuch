-- =============================================================================
-- 0057_signup_beta_premium.sql
-- Zweck: Beta ohne Zahlung (W233) -- jeder Signup erhaelt automatisch
--        tier='premium' (source='trial', status='ACTIVE', active_until=NULL).
-- Abschalten bei Stripe-Go: Trigger 7 (trg_signup_beta_premium) droppen,
--        siehe ROLLBACK-Block am Ende dieser Datei.
-- Bestehende source='admin'-Zeilen werden NIEMALS angefasst.
-- Alles idempotent: IF NOT EXISTS / CREATE OR REPLACE / ON CONFLICT DO NOTHING.
-- =============================================================================

-- 1) Spalten tier/source ergaenzen (DEV) --------------------------------------
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'free';

ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'stripe';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'subscriptions_tier_check'
       AND conrelid = 'public.subscriptions'::regclass
  ) THEN
    ALTER TABLE public.subscriptions
      ADD CONSTRAINT subscriptions_tier_check CHECK (tier IN ('free', 'premium'));
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'subscriptions_source_check'
       AND conrelid = 'public.subscriptions'::regclass
  ) THEN
    ALTER TABLE public.subscriptions
      ADD CONSTRAINT subscriptions_source_check CHECK (source IN ('stripe', 'admin', 'trial'));
  END IF;
END
$$;

-- 2) is_pro auf profiles synchron halten --------------------------------------
CREATE OR REPLACE FUNCTION public.sync_profile_tier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles
     SET is_pro = EXISTS (
           SELECT 1
             FROM public.subscriptions s
            WHERE s.user_id = COALESCE(NEW.user_id, OLD.user_id)
              AND s.tier = 'premium'
              AND s.status = 'ACTIVE'
              AND (s.active_until IS NULL OR s.active_until > now())
         )
   WHERE id = COALESCE(NEW.user_id, OLD.user_id);
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 3) Tier des aktuellen Users ermitteln ---------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_tier()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  user_tier TEXT;
BEGIN
  SELECT COALESCE(
           (SELECT 'premium'
              FROM public.subscriptions s
             WHERE s.user_id = auth.uid()
               AND s.tier = 'premium'
               AND s.status = 'ACTIVE'
               AND (s.active_until IS NULL OR s.active_until > now())
             LIMIT 1),
           'free'
         )
    INTO user_tier;
  RETURN user_tier;
END;
$$;

-- 4) Premium-Check des aktuellen Users ----------------------------------------
CREATE OR REPLACE FUNCTION public.is_user_premium()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN public.get_user_tier() = 'premium';
END;
$$;

-- 5) Trigger: subscriptions -> profiles.is_pro --------------------------------
DROP TRIGGER IF EXISTS trg_sync_profile_tier ON public.subscriptions;

CREATE TRIGGER trg_sync_profile_tier
  AFTER INSERT OR DELETE OR UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_tier();

-- 6) Signup erhaelt automatisch premium (Beta ohne Zahlung, W233) -------------
CREATE OR REPLACE FUNCTION public.grant_signup_beta_premium()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id, tier, source, status, active_until)
  VALUES (NEW.id, 'premium', 'trial', 'ACTIVE', NULL)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 7) Trigger: profiles INSERT -> subscription 'premium'/'trial' ----------------
DROP TRIGGER IF EXISTS trg_signup_beta_premium ON public.profiles;

CREATE TRIGGER trg_signup_beta_premium
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.grant_signup_beta_premium();

-- 8) Backfill fuer bestehende Profile (idempotent) ----------------------------
INSERT INTO public.subscriptions (user_id, tier, source, status, active_until)
SELECT p.id, 'premium', 'trial', 'ACTIVE', NULL
  FROM public.profiles p
 WHERE p.deleted_at IS NULL
   AND NOT EXISTS (
         SELECT 1
           FROM public.subscriptions s
          WHERE s.user_id = p.id
       )
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- ROLLBACK:
-- DROP TRIGGER IF EXISTS trg_signup_beta_premium ON public.profiles;
-- DROP FUNCTION IF EXISTS public.grant_signup_beta_premium();
-- DELETE FROM public.subscriptions WHERE source = 'trial';
-- =============================================================================