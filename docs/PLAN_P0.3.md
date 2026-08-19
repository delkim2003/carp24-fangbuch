# 🏗️ P0.3 — Schema 0001_init.sql (KOMPLETTES DDL) — PLAN ZUR ABNAHME

> **Status:** ✅ **ABGENOMMEN 19.08. (Philipp: „Phase 3 ready wenn das Sinn macht, alles andere ok")** — Realtime: alle 6 Tabellen (Phase-3-ready), species_enum + 50er-Grenze wie empfohlen → BUILD-FREIGABE
> **Basis:** BAUPLAN v2 Task 0.3 · MASTER_SPRINT Plan v7 (Datenmodell R1–R6) · MIGRATIONS_RUNBOOK (MUSS-Checkliste R4)
> **Voraussetzung:** P0.2 ABGENOMMEN (19.08., 4 Experten-Runden, PROCEED 95%)

## 1. Ziel

`supabase/migrations/0001_init.sql` — das **komplette DDL** für das carp24-Datenmodell (15 Tabellen, ENUMs, CHECKs, Trigger, RLS, RPCs, Indexe, Realtime-Publication) + `tests/pgtap/0001_rls_tests.sql` — **pgTAP grün**. Anwendung laut MIGRATIONS_RUNBOOK als `supabase_admin` (ON_ERROR_STOP=1, idempotent).

## 2. Ist-Zustand (live verifiziert, 19.08.)

| Fakt | Wert |
|------|------|
| DB | Postgres 17.6 (supabase-db, Port 5442) |
| Rollen | supabase_admin (Superuser), postgres (nicht Superuser), anon/authenticated (NOBYPASSRLS), service_role (BYPASSRLS), authenticator (TimeZone=Europe/Vienna), **carp24_app (NOBYPASSRLS, funktionslos — braucht Grants!)** |
| Schema | `public` leer (0 Relationen), USAGE für anon/authenticated/service_role/carp24_app |
| Default-ACLs | supabase_admin+postgres granten ALL an anon/authenticated/service_role → kein explizites GRANT nötig für diese 3 |
| pgTAP | 1.3.3 verfügbar, NICHT installiert (nur als supabase_admin installierbar — pgtap nicht trusted) |
| WAL | `wal_level=logical` ✓ |
| Publication | `supabase_realtime` existiert (puballtables=f, **0 Tabellen**) → ALTER PUBLICATION, NIE CREATE |
| auth.uid()/jwt() | vorhanden → RLS/RPC nutzbar |

## 3. DDL-Umfang (aus MASTER_SPRINT Z.94–141)

### ENUMs (6)
`species_enum` (SPIEGEL/LEDER/SCHUPPEN/AMUR/ANDERE) · `plan` (FREE/PRO) · `listing_status` (AVAILABLE/SOLD/HIDDEN) · `report_status` (OPEN/IN_PROGRESS/RESOLVED/REJECTED) · `target_type` (POST/FORUM_TOPIC/FORUM_POST/CHAT/LISTING) · `mod_status` (VISIBLE/HIDDEN)

### Tabellen (15) — Basis: `id uuid PK gen_random_uuid()`, `created_at/updated_at timestamptz default now()`
1. **profiles** — display_name, bio, avatar_url, home_water, privacy_spots, **role (USER/MODERATOR/ADMIN)**, deleted_at; FK id→auth.users
2. **channels** — type (DIRECT/GROUP), name, created_by, created_at (Chat, Phase 3)
3. **channel_members** — channel_id, user_id, joined_at (RLS: nur Mitglieder)
4. **subscriptions** — user_id **UNIQUE**, plan, stripe_customer, status (ACTIVE/CANCELED/PAST_DUE), cancel_at_period_end, active_until — **NICHT user-writable**
5. **waters** — name, lat/lng nullable, type, public, owner_id
6. **catches** — user_id, water_id, catch_ts, species_enum, species_custom, weight_kg, length_cm, bait, method, notes, photos text[], weather jsonb, weather_auto, draft bool, **client_uuid UNIQUE**, deleted_at; CHECKs (s.u.); **INSERT immer draft=true**
7. **posts** — user_id, catch_id, text, image, public_weight, public_species, public_water_name, status, reported_at, created_at, deleted_at (Snapshot — nie Koordinaten!)
8. **forum_topics** — user_id, title, body, status, reported_at, created_at
9. **forum_posts** — **topic_id FK**, user_id, body, status, reported_at, created_at (kein title!)
10. **chat_messages** — **channel_id FK→channels**, user_id, message, created_at
11. **marketplace_listings** — user_id, title, description, category, price, photos, status, created_at, deleted_at
12. **marketplace_messages** — listing_id, from_user, to_user, message, created_at (RLS from/to)
13. **reports** — target_type, target_id, reporter_id, reason, status, **assigned_to**, resolved_at, created_at
14. **notifications** — user_id, type, payload jsonb, read_at, created_at
15. **trips** — user_id, water_id, start, end (**CHECK end>start**), notes

### CHECKs
- catches: `weight_kg > 0 AND weight_kg < 100` · `length_cm IS NULL OR (length_cm > 0 AND length_cm < 500)` · `catch_ts <= now()` · `notes <= 1000 Zeichen`
- trips: `end > start`

### Indexe
- catches: `(user_id, catch_ts DESC)`, `(user_id, draft, deleted_at)` partial (draft=false AND deleted_at IS NULL), `(client_uuid)` UNIQUE, `(user_id)` FK
- posts: `(status, created_at DESC)`, `(catch_id)`, `(user_id)`
- marketplace: `(status, created_at DESC)`, `(listing_id)`, `(to_user, created_at)`
- forum: `(created_at)`, `(topic_id)`; chat: `(channel_id, created_at)`
- notifications `(user_id, read_at, created_at)`; reports `(status, created_at)`; subscriptions `(user_id)` UNIQUE

### Trigger
- **`handle_new_user`** → profiles-Auto-Anlage bei Signup — **SECURITY DEFINER + SET search_path=''** (MUSS-Checkliste #1, sonst permission denied auf profiles!)
- `set_updated_at` → updated_at-Auto-Update
- `soft_delete_cascade` → profiles.deleted_at → Feld-für-Feld-Anonymisierung (display_name→'gelöschter Nutzer', bio→'', avatar→NULL, user_id bleibt)

### RLS-Kern (R1–R4)
- **catches**: Owner ALLES; UPDATE-Policy `WITH CHECK (draft=true)` (User kann draft NICHT auf false setzen); publish nur via RPC
- **publish_catch(p_catch_id uuid)**: SECURITY DEFINER, search_path fixiert, `pg_advisory_xact_lock(hashtext(auth.uid()::text))`, Prüfung: catch gehört User + draft=true + **Pro-Entitlement: plan='PRO' AND active_until>now() ODER Count(draft=false AND deleted_at IS NULL) < 50**
- **posts**: öffentlich lesbar (kuratierte Spalten); INSERT via **create_post()** mit Eigentums-Check (catch_id = auth.uid())
- **subscriptions**: KEINE User-Write-Policy (nur service_role)
- **waters.public**: VIEW/RPC mit lat/lng gerundet (Projektion, kein CHECK)
- **marketplace_messages/chat_messages**: via channel_members / from/to
- **reports**: Moderator-Rolle (profiles.role='MODERATOR') + Reporter

### Realtime (MUSS-Checkliste #3)
`ALTER PUBLICATION supabase_realtime ADD TABLE` für: **chat_messages, marketplace_messages, notifications, posts, channels, channel_members** + `ALTER TABLE ... REPLICA IDENTITY FULL`

### carp24_app-Grants (MUSS-Checkliste #2)
`GRANT USAGE, CREATE ON SCHEMA public` · `GRANT ALL ON ALL TABLES/SEQUENCES` · **`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`** (+ postgres) — sonst ist die R3-H2-Härtung funktionslos

## 4. pgTAP-Tests (tests/pgtap/0001_rls_tests.sql)

- **Strategie:** `SET LOCAL ROLE anon/authenticated` + `SELECT set_config('request.jwt.claim.sub','<uuid>',true)` (auth.uid()-Pfad)
- **Seeding:** auth.users minimal INSERT (Trigger legt Profile automatisch an — testet Trigger gleich mit!)
- **Abdeckung:** Owner-CRUD · Fremd-User-Deny · draft=true-UPDATE-Deny (Kann User draft flippen? → NEIN) · publish_catch-Freemium-Count (49→50→51) · Pro-Entitlement · create_post-Eigentums-Check · subscriptions nicht user-writable · anon auf posts (kuratierte Spalten) · Moderator-Report-Zugriff
- **Zeitlimits:** anon 3s, authenticated 8s (gilt für SET ROLE-Statements)

## 5. Schritte (Reihenfolge)

1. `supabase/migrations/0001_init.sql` schreiben (idempotent, ON_ERROR_STOP-fähig)
2. `tests/pgtap/0001_rls_tests.sql` schreiben
3. Runbook-Schritt 1+2: DDL + pgTAP-Extension als supabase_admin anwenden
4. Runbook-Schritt 3: pgTAP-Tests via stdin
5. Verifikation: `\dt public.*`, Publikation-Tabellen, carp24_app-Rechte (`has_schema_privilege` CREATE=t)
6. Commit + Vault-Update

## 6. DoD / Verifikation (aus BAUPLAN + R4-Checkliste)

- [ ] 0001_init.sql idempotent (2× anwenden → kein Fehler)
- [ ] pgTAP grün (alle RLS-Policies getestet)
- [ ] `supabase_realtime` enthält die 6 Realtime-Tabellen (ALTER PUBLICATION, kein CREATE-Fehler)
- [ ] handle_new_user: Signup-Simulation → profiles-Zeile entsteht (per Trigger)
- [ ] carp24_app: `has_schema_privilege('carp24_app','public','CREATE')=t` + SELECT auf Tabellen möglich
- [ ] subscriptions: `INSERT` als authenticated → abgelehnt
- [ ] publish_catch: Freemium-Grenze 50 getestet (49 ok, 50 ok, 51 → Fehler ohne Pro)
- [ ] Kein Secret in git · `docker compose config -q` bleibt valid

## 7. Risiken + Rollback

| Risiko | Mitigation | Rollback |
|--------|-----------|----------|
| DDL-Fehler bricht Schema | ON_ERROR_STOP=1, Test-zuerst | DB-Reset: `docker compose down` + volumes löschen + up (Dev, keine Daten) |
| Idempotenz-Lücke | 2×-Anwendungs-Test im DoD | Fix + Re-Apply |
| RLS zu streng blockt Frontend | pgTAP deckt Policies ab | Policy-Patch in 002_... |

## 8. Offene Fragen an Philipp

1. **Realtime-Tabellen final?** Vorschlag: chat_messages, marketplace_messages, notifications, posts, channels, channel_members (Phase-3-Ready). OK — oder nur Phase-1-Tabellen (posts, notifications)?
2. **species_enum-Werte:** SPIEGEL/LEDER/SCHUPPEN/AMUR/ANDERE — passt das für euch, oder fehlt z.B. WILDKARPEN?
3. **50-Fänge-Grenze:** Count(draft=false AND deleted_at IS NULL) < 50 für Free — bestätigt?

## 9. Geschätzter Aufwand

~3–5 h (DDL ~600–800 Zeilen + pgTAP-Suite ~40–60 Tests), danach Task 0.4 (Secrets) / 0.5 (Backup final).
