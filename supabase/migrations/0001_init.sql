-- ============================================================================
-- carp24 Fangbuch — 0001_init.sql
-- Komplettes DDL, idempotent, ON_ERROR_STOP-fähig (Postgres 17)
-- Anwendung:  supabase_admin mit -v ON_ERROR_STOP=1
-- Wiederholung: via DB-Reset (Dev-only), kein DROP IF EXISTS
-- ============================================================================

-- 0) Header
SET search_path = '';

-- ============================================================================
-- 1) ENUMs (6)
-- ============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'species_enum' AND n.nspname = 'public') THEN
    CREATE TYPE public.species_enum AS ENUM ('SPIEGEL','LEDER','SCHUPPEN','AMUR','ANDERE');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'plan' AND n.nspname = 'public') THEN
    CREATE TYPE public.plan AS ENUM ('FREE','PRO');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'listing_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.listing_status AS ENUM ('AVAILABLE','SOLD','HIDDEN');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'report_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.report_status AS ENUM ('OPEN','IN_PROGRESS','RESOLVED','REJECTED');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'target_type' AND n.nspname = 'public') THEN
    CREATE TYPE public.target_type AS ENUM ('POST','FORUM_TOPIC','FORUM_POST','CHAT','LISTING');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'mod_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.mod_status AS ENUM ('VISIBLE','HIDDEN');
  END IF;
END $$;

-- ============================================================================
-- 2) Tabellen (15)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id             uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name   text        NOT NULL DEFAULT 'Angler',
  bio            text,
  avatar_url     text,
  home_water     text,
  privacy_spots  boolean     NOT NULL DEFAULT true,
  role           text        NOT NULL DEFAULT 'USER'
                   CHECK (role IN ('USER','MODERATOR','ADMIN')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.channels (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  type       text        CHECK (type IN ('DIRECT','GROUP')),
  name       text,
  created_by uuid        REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.channel_members (
  channel_id uuid        NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES public.profiles(id),
  joined_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (channel_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid        UNIQUE NOT NULL REFERENCES public.profiles(id),
  plan                 public.plan NOT NULL DEFAULT 'FREE',
  stripe_customer      text,
  status               text        CHECK (status IN ('ACTIVE','CANCELED','PAST_DUE')),
  cancel_at_period_end boolean,
  active_until         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.waters (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text,
   lat        numeric     CHECK (lat >= -90 AND lat <= 90),
   lng        numeric     CHECK (lng >= -180 AND lng <= 180),
  type       text,
  public     boolean     NOT NULL DEFAULT false,
  owner_id   uuid        REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.catches (
  id             uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid           NOT NULL REFERENCES public.profiles(id),
  water_id       uuid           REFERENCES public.waters(id),
  catch_ts       timestamptz    NOT NULL,
  species        public.species_enum NOT NULL,
  species_custom text,
  weight_kg      numeric        NOT NULL,
  length_cm      numeric,
  bait           text,
  method         text,
  notes          text,
  photos         text[]         NOT NULL DEFAULT '{}',
  weather        jsonb,
  weather_auto   boolean,
  draft          boolean        NOT NULL DEFAULT true,
  client_uuid    uuid           NOT NULL DEFAULT gen_random_uuid(),
  created_at     timestamptz    NOT NULL DEFAULT now(),
  updated_at     timestamptz    NOT NULL DEFAULT now(),
  deleted_at     timestamptz,

  CONSTRAINT catches_client_uuid_unique UNIQUE (client_uuid),
  CONSTRAINT catches_weight_check
    CHECK (weight_kg > 0 AND weight_kg < 100),
  CONSTRAINT catches_length_check
    CHECK (length_cm IS NULL OR (length_cm > 0 AND length_cm < 500)),
  CONSTRAINT catches_ts_check
    CHECK (catch_ts <= now()),
  CONSTRAINT catches_notes_check
    CHECK (notes IS NULL OR char_length(notes) <= 1000)
);

CREATE TABLE IF NOT EXISTS public.posts (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        REFERENCES public.profiles(id),
  catch_id          uuid        REFERENCES public.catches(id),
  text              text,
  image             text,
  public_weight     numeric,
  public_species    text,
  public_water_name text,
   status            public.mod_status NOT NULL DEFAULT 'VISIBLE',
  reported_at       timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);

CREATE TABLE IF NOT EXISTS public.forum_topics (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES public.profiles(id),
  title       text        NOT NULL,
  body        text,
  status      public.mod_status NOT NULL DEFAULT 'VISIBLE',
  reported_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS public.forum_posts (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id    uuid        NOT NULL REFERENCES public.forum_topics(id) ON DELETE CASCADE,
  user_id     uuid        REFERENCES public.profiles(id),
   body        text        NOT NULL,
   status      public.mod_status NOT NULL DEFAULT 'VISIBLE',
   reported_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id uuid        NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id    uuid        REFERENCES public.profiles(id),
  message    text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.marketplace_listings (
  id          uuid              PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid              REFERENCES public.profiles(id),
  title       text              NOT NULL,
  description text,
  category    text,
   price       numeric     CHECK (price >= 0),
  photos      text[]            NOT NULL DEFAULT '{}',
  status      public.listing_status NOT NULL DEFAULT 'AVAILABLE',
  created_at  timestamptz       NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS public.marketplace_messages (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid        NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  from_user  uuid        REFERENCES public.profiles(id),
  to_user    uuid        REFERENCES public.profiles(id),
  message    text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reports (
  id          uuid              PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type public.target_type NOT NULL,
  target_id   uuid              NOT NULL,
  reporter_id uuid              REFERENCES public.profiles(id),
  reason      text,
  status      public.report_status NOT NULL DEFAULT 'OPEN',
  assigned_to uuid              REFERENCES public.profiles(id),
  resolved_at timestamptz,
  created_at  timestamptz       NOT NULL DEFAULT now(),
  updated_at  timestamptz       NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        REFERENCES public.profiles(id),
  type       text,
  payload    jsonb,
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trips (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        REFERENCES public.profiles(id),
  water_id   uuid        REFERENCES public.waters(id),
  start      timestamptz NOT NULL,
  "end"      timestamptz NOT NULL,
  notes      text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trips_end_after_start CHECK ("end" > start)
);

-- ============================================================================
-- 4) Indexe
-- ============================================================================

-- catches (client_uuid UNIQUE ist implizit durch UNIQUE-Constraint)
CREATE INDEX IF NOT EXISTS idx_catches_user_ts
  ON public.catches (user_id, catch_ts DESC);

CREATE INDEX IF NOT EXISTS idx_catches_user_draft
  ON public.catches (user_id, draft, deleted_at)
  WHERE draft = false AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_catches_water_id
  ON public.catches (water_id);

-- posts
CREATE INDEX IF NOT EXISTS idx_posts_status_created
  ON public.posts (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_posts_catch_id
  ON public.posts (catch_id);

CREATE INDEX IF NOT EXISTS idx_posts_user_id
  ON public.posts (user_id);

-- marketplace_listings
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_status
  ON public.marketplace_listings (status, created_at DESC);

-- marketplace_messages
CREATE INDEX IF NOT EXISTS idx_marketplace_messages_listing_id
  ON public.marketplace_messages (listing_id);

CREATE INDEX IF NOT EXISTS idx_marketplace_messages_to_user
  ON public.marketplace_messages (to_user, created_at);

CREATE INDEX IF NOT EXISTS idx_marketplace_messages_from_user
  ON public.marketplace_messages (from_user, created_at);

-- forum
CREATE INDEX IF NOT EXISTS idx_forum_topics_created_at
  ON public.forum_topics (created_at);

CREATE INDEX IF NOT EXISTS idx_forum_posts_topic_id
  ON public.forum_posts (topic_id);

-- chat
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel_created
  ON public.chat_messages (channel_id, created_at);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_read
  ON public.notifications (user_id, read_at, created_at);

-- reports
CREATE INDEX IF NOT EXISTS idx_reports_status_created
  ON public.reports (status, created_at);

-- channel_members (neben Composite-PK)
CREATE INDEX IF NOT EXISTS idx_channel_members_user_id
  ON public.channel_members (user_id);

-- ============================================================================
-- 5) Trigger-Funktionen + Trigger
-- ============================================================================

-- 5a) handle_new_user  ── SECURITY DEFINER, SET search_path = '' ──
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  INSERT INTO public.profiles (id, display_name, privacy_spots)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', 'Angler'),
    true
  );
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 5b) set_updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$fn$;

DO $do$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','subscriptions','waters','catches','reports','trips'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS set_updated_at ON public.%I;'
      ' CREATE TRIGGER set_updated_at'
      '   BEFORE UPDATE ON public.%I'
      '   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();',
      t, t
    );
  END LOOP;
END
$do$;

-- 5c) soft_delete_cascade  ── Anonymisierung bei profiles.deleted_at ──
CREATE OR REPLACE FUNCTION public.soft_delete_cascade()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    NEW.display_name := 'gelöschter Nutzer';
    NEW.bio          := '';
    NEW.avatar_url   := NULL;
    NEW.home_water   := NULL;

    UPDATE public.catches SET notes = NULL, bait = NULL, method = NULL WHERE user_id = NEW.id;
    UPDATE public.posts SET text = NULL WHERE user_id = NEW.id;
    UPDATE public.forum_topics SET title = 'gelöschter Nutzer', body = NULL WHERE user_id = NEW.id;
    UPDATE public.forum_posts SET body = NULL WHERE user_id = NEW.id;
    UPDATE public.chat_messages SET message = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.marketplace_listings SET title = 'gelöschter Nutzer', description = NULL, price = NULL WHERE user_id = NEW.id;
    UPDATE public.marketplace_messages SET message = 'gelöschter Nutzer' WHERE from_user = NEW.id OR to_user = NEW.id;
    UPDATE public.reports SET reason = NULL WHERE reporter_id = NEW.id;
    UPDATE public.trips SET notes = 'gelöschter Nutzer' WHERE user_id = NEW.id;
    UPDATE public.notifications SET payload = NULL WHERE user_id = NEW.id;
    UPDATE public.waters SET name = 'gelöschter Nutzer', lat = NULL, lng = NULL WHERE owner_id = NEW.id AND public = false;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS soft_delete_profile ON public.profiles;
CREATE TRIGGER soft_delete_profile
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.soft_delete_cascade();

-- ============================================================================
-- 6) RLS aktivieren + Policies
-- ============================================================================

-- ────────── profiles ──────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_authenticated ON public.profiles;
CREATE POLICY profiles_select_authenticated ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS profiles_update_owner ON public.profiles;
CREATE POLICY profiles_update_owner ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ────────── catches ──────────
ALTER TABLE public.catches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS catches_select_owner ON public.catches;
CREATE POLICY catches_select_owner ON public.catches
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS catches_insert_owner ON public.catches;
CREATE POLICY catches_insert_owner ON public.catches
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND draft = true);

DROP POLICY IF EXISTS catches_update_owner_draft ON public.catches;
CREATE POLICY catches_update_owner_draft ON public.catches
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND (draft = true OR deleted_at IS NOT NULL));

DROP POLICY IF EXISTS catches_delete_owner ON public.catches;
CREATE POLICY catches_delete_owner ON public.catches
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ────────── posts ──────────
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS posts_select_public ON public.posts;
CREATE POLICY posts_select_public ON public.posts
  FOR SELECT
  USING (status = 'VISIBLE' AND deleted_at IS NULL);

DROP POLICY IF EXISTS posts_insert_owner ON public.posts;

DROP POLICY IF EXISTS posts_update_owner ON public.posts;
CREATE POLICY posts_update_owner ON public.posts
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND status = 'VISIBLE');

DROP POLICY IF EXISTS posts_delete_owner ON public.posts;
CREATE POLICY posts_delete_owner ON public.posts
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ────────── subscriptions  (KEINE User-Policy, nur service_role) ──────────
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subscriptions_service_only ON public.subscriptions;
CREATE POLICY subscriptions_service_only ON public.subscriptions
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- ────────── waters ──────────
ALTER TABLE public.waters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS waters_select_owner_or_public ON public.waters;
CREATE POLICY waters_select_owner_or_public ON public.waters
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid() OR public = true);

DROP POLICY IF EXISTS waters_insert_owner ON public.waters;
CREATE POLICY waters_insert_owner ON public.waters
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS waters_update_owner ON public.waters;
CREATE POLICY waters_update_owner ON public.waters
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- ────────── channels ──────────
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS channels_select_member ON public.channels;
CREATE POLICY channels_select_member ON public.channels
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.channel_members cm
    WHERE cm.channel_id = id AND cm.user_id = auth.uid()
  ));

DROP POLICY IF EXISTS channels_insert_creator ON public.channels;
CREATE POLICY channels_insert_creator ON public.channels
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

-- ────────── channel_members ──────────
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS channel_members_select_own ON public.channel_members;
CREATE POLICY channel_members_select_own ON public.channel_members
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS channel_members_insert_by_creator ON public.channel_members;
CREATE POLICY channel_members_insert_by_creator ON public.channel_members
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.channels c
    WHERE c.id = channel_id AND c.created_by = auth.uid()
  ));

-- ────────── marketplace_listings ──────────
ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marketplace_listings_select_available ON public.marketplace_listings;
CREATE POLICY marketplace_listings_select_available ON public.marketplace_listings
  FOR SELECT TO authenticated
  USING ((status = 'AVAILABLE' AND deleted_at IS NULL) OR user_id = auth.uid());

DROP POLICY IF EXISTS marketplace_listings_insert_owner ON public.marketplace_listings;
CREATE POLICY marketplace_listings_insert_owner ON public.marketplace_listings
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS marketplace_listings_update_owner ON public.marketplace_listings;
CREATE POLICY marketplace_listings_update_owner ON public.marketplace_listings
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ────────── marketplace_messages ──────────
ALTER TABLE public.marketplace_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marketplace_messages_select_from_to ON public.marketplace_messages;
CREATE POLICY marketplace_messages_select_from_to ON public.marketplace_messages
  FOR SELECT TO authenticated
  USING (from_user = auth.uid() OR to_user = auth.uid());

DROP POLICY IF EXISTS marketplace_messages_insert_sender ON public.marketplace_messages;
CREATE POLICY marketplace_messages_insert_sender ON public.marketplace_messages
  FOR INSERT TO authenticated
  WITH CHECK (from_user = auth.uid());

-- ────────── chat_messages ──────────
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_messages_select_member ON public.chat_messages;
CREATE POLICY chat_messages_select_member ON public.chat_messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.channel_members cm
    WHERE cm.channel_id = chat_messages.channel_id
      AND cm.user_id = auth.uid()
  ));

DROP POLICY IF EXISTS chat_messages_insert_member ON public.chat_messages;
CREATE POLICY chat_messages_insert_member ON public.chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.channel_members cm
      WHERE cm.channel_id = chat_messages.channel_id
        AND cm.user_id = auth.uid()
    )
  );

-- ────────── reports ──────────
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reports_insert_reporter ON public.reports;
CREATE POLICY reports_insert_reporter ON public.reports
  FOR INSERT TO authenticated
  WITH CHECK (
    reporter_id = auth.uid()
    AND status = 'OPEN'
    AND assigned_to IS NULL
    AND resolved_at IS NULL
  );

DROP POLICY IF EXISTS reports_select_mod_or_reporter ON public.reports;
CREATE POLICY reports_select_mod_or_reporter ON public.reports
  FOR SELECT TO authenticated
  USING (
    reporter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('MODERATOR','ADMIN')
    )
  );

DROP POLICY IF EXISTS reports_update_mod ON public.reports;
CREATE POLICY reports_update_mod ON public.reports
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('MODERATOR','ADMIN')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('MODERATOR','ADMIN')
  ));

-- ────────── notifications ──────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_owner ON public.notifications;
CREATE POLICY notifications_select_owner ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_owner ON public.notifications;
CREATE POLICY notifications_update_owner ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ────────── forum_topics ──────────
ALTER TABLE public.forum_topics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS forum_topics_select_visible ON public.forum_topics;
CREATE POLICY forum_topics_select_visible ON public.forum_topics
  FOR SELECT
  USING (status = 'VISIBLE' AND deleted_at IS NULL);

DROP POLICY IF EXISTS forum_topics_insert_auth ON public.forum_topics;
CREATE POLICY forum_topics_insert_auth ON public.forum_topics
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS forum_topics_update_owner ON public.forum_topics;
CREATE POLICY forum_topics_update_owner ON public.forum_topics
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ────────── forum_posts ──────────
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS forum_posts_select_visible ON public.forum_posts;
CREATE POLICY forum_posts_select_visible ON public.forum_posts
  FOR SELECT
  USING (status = 'VISIBLE' AND deleted_at IS NULL);

DROP POLICY IF EXISTS forum_posts_insert_auth ON public.forum_posts;
CREATE POLICY forum_posts_insert_auth ON public.forum_posts
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS forum_posts_update_owner ON public.forum_posts;
CREATE POLICY forum_posts_update_owner ON public.forum_posts
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ────────── trips ──────────
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trips_select_owner ON public.trips;
CREATE POLICY trips_select_owner ON public.trips
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS trips_insert_owner ON public.trips;
CREATE POLICY trips_insert_owner ON public.trips
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS trips_update_owner ON public.trips;
CREATE POLICY trips_update_owner ON public.trips
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS trips_delete_owner ON public.trips;
CREATE POLICY trips_delete_owner ON public.trips
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ============================================================================
-- 7) RPCs (SECURITY DEFINER, search_path = '')
-- ============================================================================

-- 7a) publish_catch(p_catch_id uuid) → void
CREATE OR REPLACE FUNCTION public.publish_catch(p_catch_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_user_id  uuid;
  v_catch    record;
  v_count    integer;
  v_is_pro   boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

  SELECT * INTO v_catch FROM public.catches WHERE id = p_catch_id;

  IF v_catch IS NULL THEN
    RAISE EXCEPTION 'catch not found';
  END IF;

  IF v_catch.user_id <> v_user_id THEN
    RAISE EXCEPTION 'not your catch';
  END IF;

  IF v_catch.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'catch is deleted';
  END IF;

  IF v_catch.draft = false THEN
    RAISE EXCEPTION 'catch already published';
  END IF;

  -- Entitlement: PRO nutzt kein Limit, Free ≤ 50
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = v_user_id
      AND plan = 'PRO'
      AND status = 'ACTIVE'
      AND active_until > now()
  ) INTO v_is_pro;

  IF NOT v_is_pro THEN
    SELECT count(*) INTO v_count
    FROM public.catches
    WHERE user_id = v_user_id
      AND draft = false
      AND deleted_at IS NULL;

    IF v_count >= 50 THEN
      RAISE EXCEPTION 'free tier limit of 50 catches reached — upgrade to PRO';
    END IF;
  END IF;

  UPDATE public.catches
  SET draft = false, updated_at = now()
  WHERE id = p_catch_id;
END;
$fn$;

-- 7b) create_post(…) → uuid
CREATE OR REPLACE FUNCTION public.create_post(
  p_catch_id          uuid,
  p_text              text,
  p_image             text,
  p_public_weight     numeric,
  p_public_species    text,
  p_public_water_name text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_user_id uuid;
  v_catch   record;
  v_post_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO v_catch FROM public.catches WHERE id = p_catch_id;

  IF v_catch IS NULL THEN
    RAISE EXCEPTION 'catch not found';
  END IF;

  IF v_catch.user_id <> v_user_id THEN
    RAISE EXCEPTION 'not your catch';
  END IF;

  IF v_catch.draft = true THEN
    RAISE EXCEPTION 'catch must be published first (draft=true)';
  END IF;

  IF v_catch.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'catch is deleted';
  END IF;

  INSERT INTO public.posts
    (user_id, catch_id, text, image, public_weight, public_species, public_water_name, status)
  VALUES
    (v_user_id, p_catch_id, p_text, p_image, p_public_weight, p_public_species,
     p_public_water_name, 'VISIBLE')
  RETURNING id INTO v_post_id;

  RETURN v_post_id;
END;
$fn$;

-- ============================================================================
-- 8) Realtime: ALTER PUBLICATION (NIE CREATE — pub existiert bereits)
-- ============================================================================

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.marketplace_messages;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.channels;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.channel_members;
EXCEPTION WHEN duplicate_object OR undefined_object THEN NULL;
END $$;

ALTER TABLE public.chat_messages       REPLICA IDENTITY FULL;
ALTER TABLE public.marketplace_messages REPLICA IDENTITY FULL;
ALTER TABLE public.notifications       REPLICA IDENTITY FULL;
ALTER TABLE public.posts               REPLICA IDENTITY FULL;
ALTER TABLE public.channels            REPLICA IDENTITY FULL;
ALTER TABLE public.channel_members     REPLICA IDENTITY FULL;

-- ============================================================================
-- 9) carp24_app-Grants + ALTER DEFAULT PRIVILEGES
-- ============================================================================

GRANT USAGE ON SCHEMA public TO carp24_app;
GRANT ALL ON ALL TABLES    IN SCHEMA public TO carp24_app;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO carp24_app;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  GRANT ALL ON TABLES    TO carp24_app;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  GRANT ALL ON SEQUENCES TO carp24_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL ON TABLES    TO carp24_app;

-- ============================================================================
-- 10) Footer
-- ============================================================================
-- carp24 Fangbuch — 0001_init.sql erfolgreich angewendet.
-- Nächste Schritte:
--   pgTAP:  docker exec supabase-db psql -U supabase_admin -d postgres \
--             < tests/pgtap/0001_rls_tests.sql
--   Check:  \dt public.* │ supabase_realtime │ carp24_app Grants