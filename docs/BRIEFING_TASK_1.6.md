# Build-Briefing: Task 1.6 — Offline-Sync-Backend (carp24 Phase 1A)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/supabase/migrations/ (0001-0005 als Schema-Referenz)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm, docker, Server-Starts, curl
- KEINE Analyse-Ausflüge. Mache genau die 3 Deliverables unten.
- JEDE Datei KOMPLETT schreiben (keine Diffs, keine Snippets).

## Kontext (Schema-REALITÄT)
- `public.catches` existiert: id uuid PK, user_id NOT NULL (Trigger setzt auth.uid()), water_id FK nullable, catch_ts, species species_enum NOT NULL, weight_kg numeric NOT NULL, bait, method, notes, photos text[] NOT NULL, weather jsonb, weather_auto bool, draft bool NOT NULL, **client_uuid uuid NOT NULL UNIQUE** (Index `catches_client_uuid_unique`), lat numeric, lng numeric, water_name text, created_at, updated_at (Trigger set_updated_at), deleted_at timestamptz NULL
- RLS: catches_insert_owner (draft=true), catches_update_owner_draft (draft=true OR deleted_at IS NOT NULL), catches_select_owner, catches_delete_owner
- Trigger: set_catch_user_id (BEFORE INSERT, erzwingt auth.uid()), set_updated_at
- **FEHLT:** Soft-Delete (Tombstone), Sync-RPCs — das ist Task 1.6

## 🎯 AUFGABE (3 Deliverables — ALLE in EINER Migration 0006)

Erstelle `supabase/migrations/0006_offline_sync.sql` mit:

### 1. Soft-Delete-Trigger (Tombstone)
```sql
CREATE OR REPLACE FUNCTION public.soft_delete_catch()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  -- Physisches DELETE wird zu Tombstone (deleted_at setzen)
  UPDATE public.catches SET deleted_at = now(), draft = false
  WHERE id = OLD.id AND deleted_at IS NULL;
  RETURN NULL; -- Original-DELETE unterdrücken
END; $function$;

CREATE TRIGGER soft_delete_catch_trg
  BEFORE DELETE ON public.catches
  FOR EACH ROW EXECUTE FUNCTION public.soft_delete_catch();
```
WICHTIG: deleted_at ist der Tombstone. Gelöschte Fänge bleiben in der DB (für Sync auf andere Geräte), werden aber überall sonst ausgefiltert (SELECT-Policy bleibt, aber Anwendungs-Logik filtert deleted_at IS NULL).

### 2. sync_catch RPC (idempotenter Upsert, last-write-wins)
- Signatur: `sync_catch(p_client_uuid uuid, p_data jsonb)` RETURNS uuid
- Auth: `auth.uid() IS NOT NULL` sonst RAISE 'not authenticated'
- Konflikt-Strategie **last-write-wins**: Wenn ein Fang mit gleicher client_uuid existiert UND der bestehende `updated_at` ÄLTER ist als die eingehende Änderung → UPDATE; wenn neuer → nichts tun (Client-Daten verwerfen), bestehende id zurückgeben
- p_data enthält: catch_ts, species, weight_kg, length_cm, bait, method, notes, photos, lat, lng, water_name, water_id, draft, weather, weather_auto, client_updated_at (ISO-Timestamp vom Client)
- Verhalten:
  - INSERT wenn client_uuid nicht existiert (draft=true beim ersten Sync — publish_catch macht später false)
  - UPDATE wenn existiert UND client_updated_at > bestehendes updated_at
  - Sonst: bestehende id zurückgeben (kein Duplikat, keine Überschreibung)
- Return: die catch_id (uuid)
- SECURITY DEFINER, SET search_path TO '' — die UPDATE/INSERT-Operationen brauchen keine RLS-Probleme (Dienst-Funktion)
- WICHTIG: Beim INSERT user_id IMMER auf auth.uid() setzen (nie aus p_data!)

### 3. get_changes RPC (Delta-Sync)
- Signatur: `get_changes(p_since timestamptz)` RETURNS TABLE(id uuid, client_uuid uuid, deleted boolean, data jsonb)
- Auth: `auth.uid() IS NOT NULL`
- Liefert ALLE Fänge des Users mit `updated_at > p_since` ODER `deleted_at > p_since` (Tombstones!)
- Felder als jsonb (data): id, client_uuid, water_id, water_name, lat, lng, catch_ts, species, weight_kg, length_cm, bait, method, notes, photos, weather, weather_auto, draft, created_at, updated_at, deleted_at
- deleted = (deleted_at IS NOT NULL) — Client löscht lokal, wenn deleted=true
- ORDER BY updated_at ASC (Chronologie)
- LIMIT 500 pro Aufruf (Pagination-Parameter p_limit DEFAULT 500, p_offset DEFAULT 0)

## ✅ VERIFIKATION (nur statisch, KEINE Server-Starts)
- `grep -c "soft_delete_catch_trg" supabase/migrations/0006_offline_sync.sql` = 1
- `grep -c "sync_catch" supabase/migrations/0006_offline_sync.sql` ≥ 2
- `grep -c "get_changes" supabase/migrations/0006_offline_sync.sql` ≥ 2
- `grep -c "last-write-wins\|last_write_wins\|client_updated_at" supabase/migrations/0006_offline_sync.sql` ≥ 1
- `grep -c "deleted_at IS NOT NULL" supabase/migrations/0006_offline_sync.sql` ≥ 1

## 📝 ABGABE
- Sage „FERTIG" + grep-Beweise + Struktur-Übersicht (welche Funktionen/Trigger in welcher Reihenfolge).
- KEIN git-Commit — das macht Hermes.
- KEINE psql-Ausführung — das macht Hermes (Migration wird separat angewendet + live getestet).
