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

# 3) pgTAP-Tests ausführen
docker exec supabase-db psql -U supabase_admin -d postgres \
  -f tests/pgtap/0001_rls_tests.sql

# 4) Verifikation
docker exec supabase-db psql -U supabase_admin -d postgres -c "\dt public.*"
docker exec supabase-db psql -U postgres -c "SHOW wal_level;"  # logical
```

**WICHTIG:**
- `supabase_admin` ist der einzige Superuser (`rolsuper=t`); `postgres` hat `rolsuper=f`.
- `ON_ERROR_STOP=1` → Abbruch bei erstem Fehler (kein halbes Schema).
- Migrationen sind **idempotent** zu schreiben (`IF NOT EXISTS`, `DO $$ ... $$` wo nötig).
- `supabase_realtime`-Publication existiert bereits → `ALTER PUBLICATION ... ADD TABLE`, NIE bare `CREATE PUBLICATION` (Audit-Fund E9/M1).

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
