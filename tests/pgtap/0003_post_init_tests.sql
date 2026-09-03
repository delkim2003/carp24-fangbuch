-- ============================================================================
-- carp24 Fangbuch — 0003_post_init_tests.sql
-- pgTAP-Suite: RLS-Policies für Post-Init-Tabellen
-- Anwendung: supabase_admin (Superuser), nach allen Init-Migrationen
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(29);

-- ============================================================================
-- Seeding: auth.users (User A, B, C wie in 0001_rls_tests.sql)
-- ============================================================================

-- User A (normaler User)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'user_a@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Angler A"}'::jsonb
);

-- User B (normaler User)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'user_b@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Angler B"}'::jsonb
);

-- User C (Moderator)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'mod_c@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Mod C"}'::jsonb
);
UPDATE public.profiles SET role = 'MODERATOR'
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- ============================================================================
-- Seed-Daten für Tests
-- ============================================================================

-- error_logs: User A hat einen Fehler geloggt
-- Trigger überschreibt user_id mit auth.uid(), daher als User A inserten
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

INSERT INTO public.error_logs (id, level, source, url, message, stack, context)
VALUES (
  'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1',
  'error', 'client', '/test', 'Test error', 'stack trace', '{}'::jsonb
);

RESET ROLE;

-- content_reports: User A hat einen Report erstellt
INSERT INTO public.content_reports (id, target_type, target_id, reporter_id, reason, status)
VALUES (
  'r1r1r1r1-r1r1-r1r1-r1r1-r1r1r1r1r1r1',
  'catch', 'some-catch-id',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Testreport fuer RLS', 'open'
);

-- badges: existieren bereits durch 0018_badges.sql Seed
-- user_badges: User A hat ein Badge
INSERT INTO public.user_badges (user_id, badge_id)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (SELECT id FROM public.badges WHERE code = 'erster_fang' LIMIT 1)
);

-- forum_threads: User A hat einen Thread erstellt
INSERT INTO public.forum_threads (id, user_id, title, body, category)
VALUES (
  'f1f1f1f1-f1f1-f1f1-f1f1-f1f1f1f1f1f1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Test Thread', 'Test body content', 'allgemein'
);

-- marketplace_items: User A hat ein Item erstellt (per admin)
INSERT INTO public.marketplace_items (id, user_id, title, description, price, category, status)
VALUES (
  'm1m1m1m1-m1m1-m1m1-m1m1-m1m1m1m1m1m1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Angelrute', 'Neuwertig', 50.00, 'angeln', 'active'
);

-- marketplace_contacts: User B hat User A kontaktiert
INSERT INTO public.marketplace_contacts (id, item_id, from_user, to_user, message)
VALUES (
  'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2',
  'm1m1m1m1-m1m1-m1m1-m1m1-m1m1m1m1m1m1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Ist die Rute noch da?'
);

-- push_subscriptions: User A hat eine Subscription
INSERT INTO public.push_subscriptions (user_id, endpoint, keys)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'https://fcm.googleapis.com/test-endpoint-a',
  '{"p256dh":"key-a","auth":"auth-a"}'::jsonb
);

-- app_settings: existiert bereits durch 0031_app_settings.sql Seed

-- ============================================================================
-- 1. error_logs (0014)
-- ============================================================================

-- T1: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'error_logs' AND relnamespace = 'public'::regnamespace),
  'T1: error_logs — RLS is enabled'
);

-- T2: anon kann NICHT lesen
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT is(
  (SELECT count(*) FROM public.error_logs),
  0::bigint,
  'T2: anon sees 0 rows on error_logs (REVOKE ALL on anon)'
);

RESET ROLE;

-- T3: User kann eigene Fehler lesen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.error_logs
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T3: authenticated user can SELECT own error_logs'
);

RESET ROLE;

-- T4: User kann Fehler schreiben (INSERT)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT lives_ok(
  $$INSERT INTO public.error_logs (level, source, url, message)
    VALUES ('warning', 'client', '/test2', 'Test warning')$$,
  'T4: authenticated user can INSERT error_logs (user_id set by trigger)'
);

RESET ROLE;

-- ============================================================================
-- 2. content_reports (0017)
-- ============================================================================

-- T5: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'content_reports' AND relnamespace = 'public'::regnamespace),
  'T5: content_reports — RLS is enabled'
);

-- T6: anon kann NICHT lesen
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT is(
  (SELECT count(*) FROM public.content_reports),
  0::bigint,
  'T6: anon sees 0 rows on content_reports (no grant for anon)'
);

RESET ROLE;

-- T7: User kann eigene Reports lesen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.content_reports
   WHERE reporter_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T7: reporter can SELECT own content_reports'
);

RESET ROLE;

-- T8: Moderator als authenticated sieht nur eigene Reports (keine Mod-Policy)
-- Admin (service_role) umgeht RLS und sieht alle — das wird hier NICHT getestet.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

SELECT is(
  (SELECT count(*) FROM public.content_reports),
  0::bigint,
  'T8: moderator (as authenticated) sees only own reports (none = 0, no mod policy)'
);

RESET ROLE;

-- ============================================================================
-- 3. badges (0018)
-- ============================================================================

-- T9: RLS aktiv (badges)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'badges' AND relnamespace = 'public'::regnamespace),
  'T9: badges — RLS is enabled'
);

-- T10: RLS aktiv (user_badges)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'user_badges' AND relnamespace = 'public'::regnamespace),
  'T10: user_badges — RLS is enabled'
);

-- T11: anon kann lesen (public badges)
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT ok(
  (SELECT count(*) > 0 FROM public.badges),
  'T11: anon can SELECT public badges (USING true)'
);

RESET ROLE;

-- T12: User kann eigene user_badges lesen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.user_badges
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T12: authenticated user can SELECT own user_badges'
);

RESET ROLE;

-- ============================================================================
-- 4. forum_threads (0021)
-- ============================================================================

-- T13: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'forum_threads' AND relnamespace = 'public'::regnamespace),
  'T13: forum_threads — RLS is enabled'
);

-- T14: anon kann NICHT lesen (kein Grant an anon)
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT is(
  (SELECT count(*) FROM public.forum_threads),
  0::bigint,
  'T14: anon sees 0 rows on forum_threads (no grant for anon)'
);

RESET ROLE;

-- T15: User kann eigene Threads erstellen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT lives_ok(
  $$INSERT INTO public.forum_threads (title, body, category)
    VALUES ('User B Thread', 'Body from user B', 'allgemein')$$,
  'T15: authenticated user can INSERT own forum_thread'
);

RESET ROLE;

-- ============================================================================
-- 5. marketplace_items (0026)
-- ============================================================================

-- T16: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'marketplace_items' AND relnamespace = 'public'::regnamespace),
  'T16: marketplace_items — RLS is enabled'
);

-- T17: anon kann NICHT lesen (kein Grant an anon)
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_items),
  0::bigint,
  'T17: anon sees 0 rows on marketplace_items (no grant for anon)'
);

RESET ROLE;

-- T18: User kann eigene Items erstellen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT lives_ok(
  $$INSERT INTO public.marketplace_items (title, description, price, category)
    VALUES ('User B Item', 'Beschreibung', 25.00, 'angeln')$$,
  'T18: authenticated user can INSERT own marketplace_item'
);

RESET ROLE;

-- ============================================================================
-- 6. marketplace_contacts (0029)
-- ============================================================================

-- T19: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'marketplace_contacts' AND relnamespace = 'public'::regnamespace),
  'T19: marketplace_contacts — RLS is enabled'
);

-- T20: User kann eigene Contacts lesen (als from_user)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_contacts
   WHERE from_user = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1::bigint,
  'T20: from_user can SELECT own marketplace_contacts'
);

RESET ROLE;

-- T21: User kann eigene Contacts lesen (als to_user)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_contacts
   WHERE to_user = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T21: to_user can SELECT marketplace_contacts addressed to them'
);

RESET ROLE;

-- T22: Dritter User sieht keine Contacts
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_contacts),
  0::bigint,
  'T22: third user cannot see marketplace_contacts (RLS Deny)'
);

RESET ROLE;

-- ============================================================================
-- 7. push_subscriptions (0025)
-- ============================================================================

-- T23: RLS aktiv
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE relname = 'push_subscriptions' AND relnamespace = 'public'::regnamespace),
  'T23: push_subscriptions — RLS is enabled'
);

-- T24: User kann eigene Subscriptions lesen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.push_subscriptions
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T24: user can SELECT own push_subscriptions'
);

RESET ROLE;

-- T25: User kann eigene Subscriptions erstellen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT lives_ok(
  $$INSERT INTO public.push_subscriptions (endpoint, keys)
    VALUES ('https://fcm.googleapis.com/test-endpoint-b',
            '{"p256dh":"key-b","auth":"auth-b"}'::jsonb)$$,
  'T25: user can INSERT own push_subscription'
);

RESET ROLE;

-- T26: User kann fremde Subscriptions NICHT lesen
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT is(
  (SELECT count(*) FROM public.push_subscriptions
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0::bigint,
  'T26: user cannot see foreign push_subscriptions (RLS Deny)'
);

RESET ROLE;

-- ============================================================================
-- 8. app_settings (0031)
-- ============================================================================

-- T27: RLS aktiv, anon+authenticated können lesen, aber KEIN INSERT für authenticated
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT ok(
  (SELECT count(*) > 0 FROM public.app_settings),
  'T27a: anon can SELECT app_settings (public read)'
);

RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT ok(
  (SELECT count(*) > 0 FROM public.app_settings),
  'T27b: authenticated can SELECT app_settings (public read)'
);

SELECT throws_ok(
  $$INSERT INTO public.app_settings (key, value)
    VALUES ('test_key', '{"test": true}'::jsonb)$$,
  'new row violates row-level security policy for table "app_settings"',
  'T27c: authenticated CANNOT INSERT app_settings (no insert policy)'
);

RESET ROLE;

-- ============================================================================
-- Finish
-- ============================================================================
SELECT * FROM finish();
ROLLBACK;