# Migrations-Runbook carp24 (Task 0.3-Vorbereitung)

> **Problem (Runde-3-Audit H1):** `supabase/migrations/` ist leer, `config.toml` fehlt, und
> `/docker-entrypoint-initdb.d/` (compose) läuft NUR beim First-Init — PGDATA ist bereits befüllt.
> Ein dort abgelegtes `0001_init.sql` würde NICHT angewendet.

## Wie 0001_init.sql angewendet wird (Dev, self-hosted)

### Minimum (dokumentiertes Runbook — gewählt für Phase 0)

```bash
# 1) DDL-Datei in Container kopieren (oder per stdin)
docker exec -i supabase-db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
  < supabase/migrations/0001_init.sql

# 2) pgTAP als supabase_admin installieren (pgtap.control ist NICHT trusted → nur Superuser)
docker exec supabase-db psql -U supabase_admin -d postgres -c "CREATE EXTENSION IF NOT EXISTS pgtap;"

# 3) pgTAP-Tests ausführen (stdin-Redirect — psql -f liest Container-Pfad, der existiert NICHT!)
docker exec supabase-db psql -U supabase_admin -d postgres \
  < tests/pgtap/0001_rls_tests.sql

# 4) Verifikation
docker exec supabase-db psql -U supabase_admin -d postgres -c "\dt public.*"
docker exec supabase-db psql -U postgres -c "SHOW wal_level;"  # logical
```

**WICHTIG:**
- `supabase_admin` ist der einzige Superuser (`rolsuper=t`); `postgres` hat `rolsuper=f`.
- `ON_ERROR_STOP=1` → Abbruch bei erstem Fehler (kein halbes Schema).
- Migrationen sind **idempotent** zu schreiben (`IF NOT EXISTS`, `DO $$ ... $$` wo nötig).
- `supabase_realtime`-Publication existiert bereits → `ALTER PUBLICATION ... ADD TABLE`, NIE bare `CREATE PUBLICATION` (Audit-Fund E9/M1).

## 0001_init.sql — MUSS-Checkliste (Konvergenz-Audit Runde 4, deleg_397e337b)

| # | Vorgabe | Begründung |
|---|---------|-----------|
| 1 | `handle_new_user`-Trigger = **SECURITY DEFINER** + `SET search_path = ''` | Trigger auf `auth.users` feuert mit Invoker-Rechten (supabase_auth_admin). Per Default-ACL hat supabase_auth_admin **kein INSERT auf profiles** → Signup bricht sonst mit „permission denied". Alternativ GRANT INSERT TO supabase_auth_admin — SECURITY DEFINER ist sauberer |
| 2 | **carp24_app-Grants** explizit: `GRANT USAGE, CREATE ON SCHEMA public`, `GRANT ALL ON ALL TABLES/SEQUENCES`, **`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`** (und postgres) | carp24_app (Studio-SQL-Editor, NOBYPASSRLS) hat aktuell **keine** Rechte — ohne Grants ist die R3-H2-Härtung funktionslos und Devs fallen auf postgres zurück |
| 3 | **`ALTER PUBLICATION supabase_realtime ADD TABLE`** je Realtime-Tabelle + **`ALTER TABLE ... REPLICA IDENTITY FULL`** | Publication existiert (puballtables=f, 0 Tabellen). Kandidaten: `chat_messages`, `marketplace_messages`, `notifications`, `posts`, `channels`, `channel_members`. Jetzt entscheiden (vermeidet spätere Migration) |
| 4 | `ALTER ROLE authenticator SET TimeZone='Europe/Vienna'` bleibt (bereits live gesetzt, R3-Fix E4) | Tagesgrenze/Biss-Zeiten korrekt |

**pgTAP-Teststrategie (M1):**
- `auth.uid()` liest `request.jwt.claim.sub` → in Tests: `SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','<uuid>',true);`
- `profiles.id → auth.users(id)` FK → Tests müssen **auth.users seeden** (kanonisches Minimal-INSERT, Trigger legt Profile automatisch an)
- `anon` hat `statement_timeout=3s`, `authenticated` 8s → gilt für alle SET ROLE-Statements
- supabase_admin hat **kein** statement_timeout → Migration läuft nicht unter 8s-Limit (M3)

### Optional (später, wenn supabase CLI installiert)

```bash
# config.toml + supabase link/db push
supabase link --project-ref <local>   # erfordert Projekt-ID, für self-hosted komplex
supabase db push
```

## Rollen-Modell (H2 — Studio nicht als postgres)

- `POSTGRES_USER_READ_WRITE: postgres` (compose Z.46) = RLS-Bypass + createdb/createrole im Studio-SQL-Editor.
- **Fix (Task 0.3-Beginn):** dedizierte Rolle `carp24_app` (login, NOSUPERUSER, NOBYPASSRLS) anlegen,
  `POSTGRES_USER_READ_WRITE: carp24_app` setzen, `POSTGRES_USER_READ_ONLY: supabase_read_only_user`.
- Studio-SQL-Editor verliert damit Superuser — gewollt.

## Dateien

| Pfad | Zweck |
|------|-------|
| `supabase/migrations/0001_init.sql` | Komplettes DDL (Task 0.3) |
| `tests/pgtap/0001_rls_tests.sql` | RLS-Tests (Task 0.3 DoD) |
| `supabase/config.toml` | FEHLT noch — für CLI-Option optional |
