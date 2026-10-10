-- =============================================================================
-- 20261010140000_marktplatz_premium.sql
-- Zweck: Marktplatz als Premium-Feature absichern.
--   - get_user_tier() / is_user_premium() als zentrale STABLE Premium-Quelle
--   - SECURITY-FIX: subscriptions -> nur eigene Zeilen per SELECT sichtbar,
--     KEIN INSERT/UPDATE/DELETE fuer Nutzer (service_role umgeht RLS)
--   - VEREINHEITLICHUNG: sync_is_pro() ersetzt sync_profile_tier()
--   - Backfill: profiles.is_pro = aktives Premium-Abo
--   - RLS: Marktplatz ohne Premium nicht lesbar/schreibbar
-- Idempotent.
-- =============================================================================

-- 1) Zentrale Premium-Quellen ------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_tier()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE(
           (SELECT 'premium'
              FROM public.subscriptions s
             WHERE s.user_id = auth.uid()
               AND s.tier = 'premium'
               AND s.status = 'ACTIVE'
               AND (s.active_until IS NULL OR s.active_until > now())
             LIMIT 1),
           'free'
         );
$$;

CREATE OR REPLACE FUNCTION public.is_user_premium()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT public.get_user_tier() = 'premium';
$$;

-- 2) SECURITY-FIX: subscriptions-Policies ------------------------------------
--    Bestehende Policy, die ALLES erlaubt, ueber pg_policies finden und droppen.
DO $$
DECLARE
  v_policy text;
BEGIN
  FOR v_policy IN
    SELECT policyname
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename = 'subscriptions'
       AND cmd = 'ALL'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.subscriptions', v_policy);
  END LOOP;
END
$$;

-- Neu: nur eigene Zeilen lesbar; INSERT/UPDATE/DELETE nur via service_role.
DROP POLICY IF EXISTS subscriptions_select_own ON public.subscriptions;
CREATE POLICY subscriptions_select_own ON public.subscriptions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- SELECT freigeben (eigene Zeilen via Policy); INSERT/UPDATE/DELETE bleiben
-- revoziert - service_role umgeht RLS und ist weiterhin voll berechtigt.
GRANT SELECT ON public.subscriptions TO authenticated;

-- 3) VEREINHEITLICHUNG: is_pro-Sync per Trigger -------------------------------
CREATE OR REPLACE FUNCTION public.sync_is_pro()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := COALESCE(NEW.user_id, OLD.user_id);
  IF v_user_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  UPDATE public.profiles
     SET is_pro = EXISTS (
           SELECT 1
             FROM public.subscriptions s
            WHERE s.user_id = v_user_id
              AND s.tier = 'premium'
              AND s.status = 'ACTIVE'
              AND (s.active_until IS NULL OR s.active_until > now())
         )
   WHERE id = v_user_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_tier ON public.subscriptions;
DROP TRIGGER IF EXISTS trg_sync_is_pro ON public.subscriptions;
CREATE TRIGGER trg_sync_is_pro
  AFTER INSERT OR UPDATE OR DELETE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_is_pro();

DROP FUNCTION IF EXISTS public.sync_profile_tier();

-- 4) Backfill: profiles.is_pro = aktives Premium-Abo --------------------------
UPDATE public.profiles p
   SET is_pro = EXISTS (
         SELECT 1
           FROM public.subscriptions s
          WHERE s.user_id = p.id
            AND s.tier = 'premium'
            AND s.status = 'ACTIVE'
            AND (s.active_until IS NULL OR s.active_until > now())
       );

-- 5) Marktplatz = Premium-Feature (ohne Premium KEIN Zugriff) -----------------
DROP POLICY IF EXISTS marketplace_read ON public.marketplace_items;
DROP POLICY IF EXISTS marketplace_insert ON public.marketplace_items;
DROP POLICY IF EXISTS marketplace_update ON public.marketplace_items;
DROP POLICY IF EXISTS marketplace_delete ON public.marketplace_items;

CREATE POLICY marketplace_premium_select ON public.marketplace_items
  FOR SELECT TO authenticated
  USING (public.is_user_premium() AND ((status = 'active') OR user_id = auth.uid()));

CREATE POLICY marketplace_premium_insert ON public.marketplace_items
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.is_user_premium());

CREATE POLICY marketplace_premium_update ON public.marketplace_items
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND public.is_user_premium())
  WITH CHECK (user_id = auth.uid() AND public.is_user_premium());

CREATE POLICY marketplace_premium_delete ON public.marketplace_items
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() AND public.is_user_premium());

-- Alt-Tabelle marketplace_listings (hat deleted_at; ggf. durch 0041 gedroppt)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'marketplace_listings') THEN
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_select_available ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_insert_owner ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_update_owner ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_premium_select ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_premium_insert ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_premium_update ON public.marketplace_listings';
    EXECUTE 'DROP POLICY IF EXISTS marketplace_listings_premium_delete ON public.marketplace_listings';

    EXECUTE 'CREATE POLICY marketplace_listings_premium_select ON public.marketplace_listings
      FOR SELECT TO authenticated
      USING (public.is_user_premium() AND ((status = ''AVAILABLE'' AND deleted_at IS NULL) OR user_id = auth.uid()))';

    EXECUTE 'CREATE POLICY marketplace_listings_premium_insert ON public.marketplace_listings
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid() AND public.is_user_premium())';

    EXECUTE 'CREATE POLICY marketplace_listings_premium_update ON public.marketplace_listings
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid() AND public.is_user_premium())
      WITH CHECK (user_id = auth.uid() AND public.is_user_premium())';

    EXECUTE 'CREATE POLICY marketplace_listings_premium_delete ON public.marketplace_listings
      FOR DELETE TO authenticated
      USING (user_id = auth.uid() AND public.is_user_premium())';
  END IF;
END
$$;