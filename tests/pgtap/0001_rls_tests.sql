-- ============================================================================
-- carp24 Fangbuch — 0001_rls_tests.sql
-- pgTAP-Suite: RLS-Policies, RPCs, Trigger, Grants
-- Anwendung: supabase_admin (Superuser), nach 0001_init.sql
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(18);

-- ============================================================================
-- Seeding: auth.users  (Trigger legt profiles automatisch an)
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

-- User D (Pro-User, aktiv)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'pro_d@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{"display_name":"Pro D"}'::jsonb
);

-- Water (Referenz)
INSERT INTO public.waters (id, name, lat, lng, type, public, owner_id)
VALUES (
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  'Testsee', 48.2, 16.3, 'See', true,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

-- ============================================================================
-- T1: handle_new_user legt Profil an (display_name aus Metadata)
-- ============================================================================
SELECT is(
  (SELECT display_name FROM public.profiles
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Angler A',
  'T1: handle_new_user creates profile with display_name from metadata'
);

-- ============================================================================
-- T2: handle_new_user Default display_name
-- ============================================================================
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES (
  'a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'user_e@test.local',
  crypt('test1234', gen_salt('bf')),
  now(), now(), now(),
  '{}'::jsonb
);

SELECT is(
  (SELECT display_name FROM public.profiles
   WHERE id = 'a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0'),
  'Angler',
  'T2: handle_new_user defaults display_name to Angler when no metadata'
);

-- ============================================================================
-- T3: anon SELECT catches → Deny (keine Policy für anon)
-- ============================================================================
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT is(
  (SELECT count(*) FROM public.catches),
  0::bigint,
  'T3: anon sees 0 rows on catches (no anon policy)'
);

RESET ROLE;

-- ============================================================================
-- T4: Owner INSERT catch (draft=true) → ok
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT lives_ok(
  $$INSERT INTO public.catches
      (user_id, water_id, catch_ts, species, weight_kg, bait, method, notes, draft, client_uuid)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
      now(), 'SPIEGEL', 12.5, 'Boilies', 'PVA', 'Testlauf Angler A', true,
      '11111111-1111-1111-1111-111111111111'
    )$$,
  'T4: owner can INSERT catch with draft=true'
);

RESET ROLE;

-- ============================================================================
-- T5: Owner SELECT eigene catch → sichtbar
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT is(
  (SELECT count(*) FROM public.catches
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'T5: owner can SELECT own catch'
);

RESET ROLE;

-- ============================================================================
-- T6: Fremder UPDATE fremde catch → Deny (0 rows)
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

WITH upd AS (
  UPDATE public.catches SET bait = 'hacked'
  WHERE id = (SELECT id FROM public.catches
              WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
              LIMIT 1)
  RETURNING id
)
SELECT is(
  (SELECT id FROM upd),
  NULL,
  'T6: foreign user cannot UPDATE catch (RLS Deny, 0 rows)'
);

RESET ROLE;

-- ============================================================================
-- T7: Owner UPDATE draft → false direkt → Deny (WITH CHECK)
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$UPDATE public.catches SET draft = false
    WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      AND draft = true$$,
  'new row violates row-level security policy for table "catches"',
  'T7: owner CANNOT set draft=false directly (WITH CHECK blocks it)'
);

RESET ROLE;

-- ============================================================================
-- T8: publish_catch Freemium-Count (0→1→49→50 ok, 51→EXCEPTION)
-- ============================================================================

-- T8a: 0 published → publish via RPC → ok
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT lives_ok(
  $$SELECT public.publish_catch(
    (SELECT id FROM public.catches
     WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND draft = true
     LIMIT 1)
  )$$,
  'T8a: publish_catch 1st catch succeeds (count=0 < 50)'
);

RESET ROLE;

-- 48 weitere published catches per supabase_admin (total = 49 published)
INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
SELECT
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now() - (g * interval '1 hour'),
  'AMUR', 5.0 + g, false, gen_random_uuid()
FROM generate_series(1, 48) AS g;

-- Neuer draft (50. catch)
INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now(), 'SCHUPPEN', 3.5, true,
  '33333333-3333-3333-3333-333333333333'
);

-- T8b: 49 published → 50. publish → ok (count=49 < 50)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT lives_ok(
  $$SELECT public.publish_catch(
    (SELECT id FROM public.catches
     WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND draft = true
     LIMIT 1)
  )$$,
  'T8b: publish_catch 50th catch succeeds (count=49 < 50)'
);

RESET ROLE;

-- 51. draft
INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now(), 'ANDERE', 1.0, true,
  '44444444-4444-4444-4444-444444444444'
);

-- T8c: 50 published → 51. publish → EXCEPTION (count=50 >= 50)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$SELECT public.publish_catch(
    (SELECT id FROM public.catches
     WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND draft = true
     LIMIT 1)
  )$$,
  'free tier limit of 50 catches reached — upgrade to PRO',
  'T8c: publish_catch 51st catch FAILS (free tier limit reached)'
);

RESET ROLE;

-- ============================================================================
-- T9: publish_catch fremde catch → EXCEPTION
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now(), 'SPIEGEL', 8.0, true,
  '55555555-5555-5555-5555-555555555555'
);

RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$SELECT public.publish_catch(
    (SELECT id FROM public.catches
     WHERE user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
       AND draft = true
     LIMIT 1)
  )$$,
  'not your catch',
  'T9: publish_catch on foreign catch → EXCEPTION'
);

RESET ROLE;

-- ============================================================================
-- T10: Pro-User → 50+ catches ok (Subscription active)
-- ============================================================================
INSERT INTO public.subscriptions (user_id, plan, status, active_until)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'PRO', 'ACTIVE', now() + interval '1 year'
);

-- 50 published catches per admin
INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
SELECT
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now() - (g * interval '1 hour'),
  'AMUR', 5.0 + g, false, gen_random_uuid()
FROM generate_series(1, 50) AS g;

-- 51. draft
INSERT INTO public.catches
  (user_id, water_id, catch_ts, species, weight_kg, draft, client_uuid)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0',
  now(), 'SPIEGEL', 20.0, true,
  '66666666-6666-6666-6666-666666666666'
);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'dddddddd-dddd-dddd-dddd-dddddddddddd', true);

SELECT lives_ok(
  $$SELECT public.publish_catch(
    (SELECT id FROM public.catches
     WHERE user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
       AND draft = true
     LIMIT 1)
  )$$,
  'T10: Pro user can publish 51st catch (subscription active)'
);

RESET ROLE;

-- ============================================================================
-- T11: create_post eigene published catch → ok
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT lives_ok(
  $$SELECT public.create_post(
    (SELECT id FROM public.catches
     WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND draft = false
     ORDER BY created_at LIMIT 1),
    'Mein erster Test!', NULL,
    12.5, 'SPIEGEL', 'Testsee'
  )$$,
  'T11: create_post with own published catch → ok'
);

RESET ROLE;

-- ============================================================================
-- T12: create_post fremde catch → EXCEPTION
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$SELECT public.create_post(
    (SELECT id FROM public.catches
     WHERE user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
       AND draft = false
     LIMIT 1),
    'Fremde Post', NULL, 1.0, 'AMUR', 'Falsches Gewaesser'
  )$$,
  'not your catch',
  'T12: create_post on foreign catch → EXCEPTION'
);

RESET ROLE;

-- ============================================================================
-- T13: create_post auf draft-catch → EXCEPTION
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$SELECT public.create_post(
    (SELECT id FROM public.catches
     WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND draft = true
     ORDER BY created_at DESC LIMIT 1),
    'Draft post', NULL, 7.0, 'AMUR', 'Testsee'
  )$$,
  'catch must be published first (draft=true)',
  'T13: create_post on draft catch → EXCEPTION'
);

RESET ROLE;

-- ============================================================================
-- T14: subscriptions INSERT als authenticated → Deny (keine User-Policy)
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SELECT throws_ok(
  $$INSERT INTO public.subscriptions (user_id, plan, status, active_until)
    VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'PRO', 'ACTIVE', now() + interval '1 year')$$,
  'new row violates row-level security policy for table "subscriptions"',
  'T14: authenticated user CANNOT INSERT subscriptions (no policy)'
);

RESET ROLE;

-- ============================================================================
-- T15: profiles UPDATE fremdes Profil → Deny
-- ============================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

WITH up AS (
  UPDATE public.profiles SET display_name = 'hacked'
  WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  RETURNING id
)
SELECT is(
  (SELECT id FROM up),
  NULL,
  'T15: cannot UPDATE foreign profile (RLS Deny, 0 rows)'
);

RESET ROLE;

-- ============================================================================
-- T16: carp24_app hat CREATE-Recht auf public
-- ============================================================================
SELECT ok(
  (SELECT has_schema_privilege('carp24_app', 'public', 'CREATE')),
  'T16: carp24_app has CREATE privilege on public schema'
);

-- ============================================================================
-- T17+T18: marketplace_messages — from/to Sichtbarkeit
-- ============================================================================
INSERT INTO public.marketplace_listings
  (id, user_id, title, price, status)
VALUES (
  'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Angelrute', 50.00, 'AVAILABLE'
);

INSERT INTO public.marketplace_messages
  (listing_id, from_user, to_user, message)
VALUES (
  'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Hallo, ist die Rute noch da?'
);

-- T17: User B (to_user) sieht Nachricht
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_messages
   WHERE listing_id = 'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0'),
  1::bigint,
  'T17: to_user can SELECT marketplace_messages'
);

RESET ROLE;

-- T18: User C (Dritter) sieht keine Nachricht
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

SELECT is(
  (SELECT count(*) FROM public.marketplace_messages
   WHERE listing_id = 'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0'),
  0::bigint,
  'T18: third user cannot see marketplace_messages (RLS Deny)'
);

RESET ROLE;

-- ============================================================================
-- Finish
-- ============================================================================
SELECT * FROM finish();
ROLLBACK;