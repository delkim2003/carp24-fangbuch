# BRIEFING P0.3 — 0001_init.sql + pgTAP (Build-Auftrag an Coder)

> **Gegenstand:** carp24-Fangbuch, Supabase self-hosted (v1.26.08), Postgres 17.6
> **Status:** Plan ABGENOMMEN 19.08. — Build-Freigabe erteilt
> **Pflicht-Lektüre vor Build:** `docs/PLAN_P0.3.md` (abgenommen), `docs/MIGRATIONS_RUNBOOK.md` (MUSS-Checkliste), MASTER_SPRINT.md Z.94–141 (Datenmodell-Spec)

## 🎯 Lieferobjekte (NUR diese 2 Dateien!)

1. `supabase/migrations/0001_init.sql` — komplettes DDL, idempotent, ON_ERROR_STOP-fähig
2. `tests/pgtap/0001_rls_tests.sql` — pgTAP-Suite, alle RLS-Policies getestet

**Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**

## 📐 0001_init.sql — Struktur (Reihenfolge zwingend)

```sql
-- 0) Header: idempotent, search_path
-- 1) ENUMs (6): species_enum, plan, listing_status, report_status, target_type, mod_status
-- 2) Tabellen (15): profiles, channels, channel_members, subscriptions, waters, catches,
--    posts, forum_topics, forum_posts, chat_messages, marketplace_listings,
--    marketplace_messages, reports, notifications, trips
-- 3) CHECKs (auf catches + trips)
-- 4) Indexe (Liste unten)
-- 5) Trigger-Funktionen + Trigger: handle_new_user (SECURITY DEFINER!), set_updated_at,
--    soft_delete_cascade (Anonymisierung)
-- 6) RLS aktivieren + Policies (catches Owner, UPDATE draft=true-Deny, posts öffentlich
--    kuratiert, subscriptions service_role-only, marketplace/chat from-to, reports
--    Moderator+Reporter)
-- 7) RPCs: publish_catch() + create_post() (SECURITY DEFINER, search_path fixiert,
--    advisory-lock)
-- 8) Realtime: ALTER PUBLICATION supabase_realtime ADD TABLE (6 Tabellen) + REPLICA IDENTITY FULL
-- 9) carp24_app-Grants + ALTER DEFAULT PRIVILEGES
-- 10) Footer: Kommentar mit Anwendungshinweis
```

## 🗄️ Tabellen-Spec (aus MASTER_SPRINT, exakt)

**Basis alle Tabellen:** `id uuid primary key default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz default now()` (nur wo sinnvoll; chat/posts/notifications haben created_at, teils kein updated_at)

| Tabelle | Felder (zusätzlich zu Basis) |
|---------|------------------------------|
| `profiles` | display_name, bio, avatar_url, home_water, privacy_spots bool default true, role text default 'USER' CHECK (role IN ('USER','MODERATOR','ADMIN')), deleted_at timestamptz; **id FK → auth.users(id)** |
| `channels` | type text CHECK (type IN ('DIRECT','GROUP')), name, created_by uuid; created_at |
| `channel_members` | channel_id uuid FK→channels ON DELETE CASCADE, user_id uuid FK→profiles, joined_at; PK (channel_id, user_id) |
| `subscriptions` | user_id uuid **UNIQUE** FK→profiles, plan text default 'FREE' CHECK (plan IN ('FREE','PRO')), stripe_customer, status text CHECK (status IN ('ACTIVE','CANCELED','PAST_DUE')), cancel_at_period_end bool, active_until timestamptz |
| `waters` | name, lat numeric, lng numeric, type, public bool default false, owner_id uuid FK→profiles |
| `catches` | user_id uuid FK→profiles NOT NULL, water_id uuid FK→waters, catch_ts timestamptz NOT NULL, species species_enum NOT NULL, species_custom text, weight_kg numeric NOT NULL, length_cm numeric, bait text, method text, notes text, photos text[] default '{}', weather jsonb, weather_auto bool, draft bool default true NOT NULL, client_uuid uuid **UNIQUE** NOT NULL, deleted_at timestamptz |
| `posts` | user_id uuid FK→profiles, catch_id uuid FK→catches, text text, image text, public_weight numeric, public_species text, public_water_name text, status text default 'VISIBLE' CHECK (status IN ('VISIBLE','HIDDEN')), reported_at timestamptz, deleted_at timestamptz |
| `forum_topics` | user_id uuid FK→profiles, title text NOT NULL, body text, status text default 'VISIBLE' CHECK (status IN ('VISIBLE','HIDDEN')), reported_at timestamptz, deleted_at timestamptz |
| `forum_posts` | topic_id uuid FK→forum_topics ON DELETE CASCADE NOT NULL, user_id uuid FK→profiles, body text NOT NULL, status text default 'VISIBLE', reported_at, deleted_at |
| `chat_messages` | channel_id uuid FK→channels ON DELETE CASCADE NOT NULL, user_id uuid FK→profiles, message text NOT NULL |
| `marketplace_listings` | user_id uuid FK→profiles, title text NOT NULL, description text, category text, price numeric, photos text[] default '{}', status listing_status default 'AVAILABLE', deleted_at |
| `marketplace_messages` | listing_id uuid FK→marketplace_listings ON DELETE CASCADE, from_user uuid FK→profiles, to_user uuid FK→profiles, message text NOT NULL |
| `reports` | target_type target_type NOT NULL, target_id uuid NOT NULL, reporter_id uuid FK→profiles, reason text, status report_status default 'OPEN', assigned_to uuid FK→profiles, resolved_at timestamptz |
| `notifications` | user_id uuid FK→profiles, type text, payload jsonb, read_at timestamptz |
| `trips` | user_id uuid FK→profiles, water_id uuid FK→waters, start timestamptz NOT NULL, end timestamptz NOT NULL, notes |

**CHECKs:**
- catches: `weight_kg > 0 AND weight_kg < 100` · `length_cm IS NULL OR (length_cm > 0 AND length_cm < 500)` · `catch_ts <= now()` · `char_length(notes) <= 1000` (wenn notes nicht null) · `catch_ts IS NOT NULL`
- trips: `end > start`

**Indexe (exakt):**
- `catches(user_id, catch_ts DESC)` · `catches(user_id, draft, deleted_at)` WHERE draft = false AND deleted_at IS NULL · `catches(client_uuid)` UNIQUE (implizit durch UNIQUE-Constraint) · `catches(water_id)`
- `posts(status, created_at DESC)` · `posts(catch_id)` · `posts(user_id)`
- `marketplace_listings(status, created_at DESC)` · `marketplace_messages(listing_id)` · `marketplace_messages(to_user, created_at)`
- `forum_topics(created_at)` · `forum_posts(topic_id)` · `chat_messages(channel_id, created_at)`
- `notifications(user_id, read_at, created_at)` · `reports(status, created_at)`
- `channel_members(user_id)` (neben Composite-PK)

**Trigger:**
1. `handle_new_user()` — **SECURITY DEFINER, SET search_path = ''** — bei INSERT auf auth.users → profiles-Zeile anlegen (id = NEW.id, display_name = COALESCE(NEW.raw_user_meta_data->>'display_name','Angler'), privacy_spots=true)
2. `set_updated_at()` — BEFORE UPDATE auf alle Tabellen mit updated_at
3. `soft_delete_cascade()` — bei profiles.deleted_at setzen: display_name→'gelöschter Nutzer', bio→'', avatar_url→NULL (Feld-für-Feld, user_id bleibt)

## 🔒 RLS (exakt, aus R1–R4)

```sql
-- profiles: eigener Zugriff + öffentlich sichtbar (für Community)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- SELECT: jeder eingeloggte (authenticated) + anon? NEIN: nur authenticated, eigene + öffentliche
-- UPDATE: nur owner (auth.uid() = id)

-- catches: Owner ALLES
-- UPDATE-Policy mit USING (user_id = auth.uid()) AND WITH CHECK (user_id = auth.uid() AND draft = true)
--   → User kann draft NICHT auf false setzen (publish nur via RPC!)

-- posts: SELECT für alle (auch anon, nur nicht-deleted + VISIBLE), INSERT via RPC create_post
-- subscriptions: KEINE Policy für authenticated (nur service_role; RLS aktiv, keine Policy = deny)
-- waters: SELECT owner oder public=true; UPDATE owner
-- marketplace_listings: SELECT alle (AVAILABLE), INSERT owner, UPDATE owner
-- marketplace_messages: SELECT/INSERT wo from_user = auth.uid() OR to_user = auth.uid()
-- chat_messages: SELECT/INSERT via channel_members (auth.uid() IN member)
-- channel_members: SELECT nur eigene Mitgliedschaften, INSERT bei DIRECT: initiator
-- reports: INSERT reporter, SELECT Moderator (profiles.role='MODERATOR') oder reporter
-- notifications: SELECT/UPDATE nur owner (read_at)
-- forum_topics/forum_posts: SELECT alle VISIBLE, INSERT authenticated
-- trips: owner ALLES
```

## 🔧 RPCs (SECURITY DEFINER, search_path fixiert)

```sql
-- publish_catch(p_catch_id uuid) returns void
--   pg_advisory_xact_lock(hashtext(auth.uid()::text))
--   Prüfung: catch existiert + user_id = auth.uid() + draft = true + deleted_at IS NULL
--   Entitlement: EXISTIERT subscriptions(plan='PRO' AND active_until > now())
--     ODER (SELECT count(*) FROM catches WHERE user_id=auth.uid() AND draft=false AND deleted_at IS NULL) < 50
--   UPDATE catches SET draft=false, updated_at=now() WHERE id=p_catch_id
--   Fehler: RAISE EXCEPTION '...' bei Fremd-Catch / draft=false / über Limit

-- create_post(p_catch_id uuid, p_text text, p_image text, p_public_weight numeric,
--             p_public_species text, p_public_water_name text) returns uuid
--   Prüfung: catch gehört auth.uid() (Eigentums-Check) + catch ist published (draft=false)
--   INSERT posts mit Snapshot-Feldern, status='VISIBLE'
--   KEINE Koordinaten/weather/notes im Post!
```

## 🛰️ Realtime (MUSS-Checkliste #3 — 6 Tabellen, Phase-3-ready)

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.marketplace_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.channels;
ALTER PUBLICATION supabase_realtime ADD TABLE public.channel_members;
-- je Tabelle: ALTER TABLE ... REPLICA IDENTITY FULL
```

## 👤 carp24_app-Grants (MUSS-Checkliste #2)

```sql
GRANT USAGE, CREATE ON SCHEMA public TO carp24_app;
GRANT ALL ON ALL TABLES IN SCHEMA public TO carp24_app;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO carp24_app;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO carp24_app;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO carp24_app;
-- zusätzlich postgres als Grantor:
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO carp24_app;
```

## 🧪 pgTAP-Suite (tests/pgtap/0001_rls_tests.sql)

- `BEGIN; SELECT plan(N);` — N = Anzahl Tests
- **Setup:** users seeden via `INSERT INTO auth.users (id, email, ...)` (minimale Felder: id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) — Trigger legt profiles an
- **auth.uid()-Simulation:** `SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '<user-uuid>', true);`
- **Testfälle (mindestens):**
  1. anon: catches SELECT → 0 Zeilen (keine Policy)
  2. owner: INSERT catch (draft=true) → ok; SELECT → sichtbar
  3. fremder User: UPDATE fremde catch → 0 Zeilen (Deny)
  4. owner: UPDATE draft=true→false direkt → **FEHLER** (WITH CHECK)
  5. publish_catch: 49 Fänge (draft=false) + 1 draft → publish ok (50); 51. → EXCEPTION
  6. publish_catch fremde catch → EXCEPTION
  7. Pro-User (subscription ACTIV > now): 51+ Fänge ok
  8. create_post: eigene published catch → ok; fremde → EXCEPTION; draft-catch → EXCEPTION
  9. subscriptions: INSERT als authenticated → 0 Zeilen / Fehler (keine Policy)
  10. marketplace_messages: from/to sichtbar, Dritter nicht
  11. chat_messages: Nicht-Mitglied → Deny, Mitglied → ok
  12. reports: Nicht-Moderator kein UPDATE auf status
  13. profiles: UPDATE fremdes Profil → Deny
  14. anon: posts SELECT → nur VISIBLE + nicht-deleted
- Jeder Test: `SELECT ok(...)`, `SELECT lives_ok(...)`, `SELECT throws_ok(...)`, `SELECT results_eq(...)` etc.
- `ROLLBACK;` am Ende (pgTAP läuft in Transaktion)

## ✅ DoD (Build-Abnahme)

- [ ] 0001_init.sql idempotent (2× anwenden → 0 Fehler)
- [ ] pgTAP grün (alle Tests ok, 0 failed)
- [ ] supabase_realtime enthält 6 Tabellen
- [ ] carp24_app: has_schema_privilege CREATE=t
- [ ] handle_new_user: INSERT auth.users → profiles-Zeile
- [ ] subscriptions INSERT als authenticated → denied
- [ ] publish_catch 49→50 ok, 51→Exception

## ⚠️ Fallstricke

- **NIE** `CREATE PUBLICATION` — existiert bereits (E9/R4-Fund)
- **NIE** Trigger auf auth.users ohne SECURITY DEFINER (R4-H3-Fund)
- Idempotenz: `DO $$ ... $$` Blöcke oder `IF NOT EXISTS` für ENUMs/Tabellen wo sinnvoll — ABER: Tabellen mit IF NOT EXISTS + anschließendem ALTER können bei 2. Lauf fehlschlagen → bevorzugt `DROP ... IF EXISTS` NICHT verwenden, stattdessen sauber prüfen oder Gesamt-Migration dokumentieren als "einmalig, Dev-only" — im Header als Kommentar festhalten, dass Wiederholung via DB-Reset erfolgt
- pgTAP: `CREATE EXTENSION IF NOT EXISTS pgtap;` im Test-Header (idempotent)
- SQL nur für Postgres 17 (kein MySQL-Syntax)
