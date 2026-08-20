# BRIEFING — Task 1.6b: Offline-Draft-Queue-UI (carp24)

## Ziel
Offline-Fähigkeit ins Fang-Formular bringen: **IndexedDB-Draft-Queue** — wenn offline, wird der Fang lokal gespeichert, beim nächsten Online-Sync an Supabase übertragen. Sync-Indikator + Draft-Anzeige. **KEIN Duplikat** (client_uuid idempotent — Backend aus 1.6).

## Backend-Kontrakt (VERBINDLICH — live, Migration 0006/0007)
- `sync_catch(p_client_uuid uuid, p_data jsonb) RETURNS uuid` — idempotenter Upsert (client_uuid UNIQUE + last-write-wins via client_updated_at). **Genau der Weg für Offline-Sync.**
- p_data: catch_ts, species (SPIEGEL|LEDER|SCHUPPEN|AMUR|ANDERE), weight_kg, length_cm?, bait?, method?, notes?, photos?, lat?, lng?, water_name?, water_id?, draft (bool), weather_auto (false), client_updated_at (ISO)
- `get_changes(p_since, p_limit, p_offset)` — Delta-Sync (nicht zwingend nötig für Queue, aber für Vollständigkeit)

## Deliverables (PFLICHT-Dateien — alle in web/)

### 1. web/src/lib/offline-queue.ts (NEU)
IndexedDB-Wrapper (vanilla IndexedDB, KEINE extra Dependency — oder localforage NUR wenn nötig):
- `queueDraft(draft: DraftEntry): Promise<void>` — speichert {client_uuid, p_data, created_at} in IndexedDB (Store 'drafts')
- `getDrafts(): Promise<DraftEntry[]>` — alle offenen Drafts
- `removeDraft(client_uuid: string): Promise<void>` — nach erfolgreichem Sync
- `syncDrafts(): Promise<{synced: number, failed: number}>` — alle Drafts durchgehen, sync_catch aufrufen, bei Erfolg entfernen
- Typen: `DraftEntry { client_uuid: string; p_data: Record<string, unknown>; created_at: string }`
- Error-Handling: IndexedDB-Fehler ehrlich zurückgeben

### 2. web/src/pages/fang-erfassen.astro (ERWEITERN — nicht neu schreiben, bestehendes Formular aus 1.5b erhalten!)
- **Online/Offline-Erkennung:** `navigator.onLine` + 'online'/'offline'-EventListener
- **Submit-Logik anpassen:**
  - ONLINE: wie bisher (saveCatch direkt)
  - OFFLINE: `queueDraft({client_uuid, p_data, created_at})` → Erfolgs-Meldung „Offline gespeichert — wird synchronisiert" + Draft in Liste
- **Sync-Indikator:** kleine Status-Anzeige im Header/Bereich: „🟢 Online" / „🟠 Offline — X Drafts warten"
- **Beim Online-Wechsel:** automatisch `syncDrafts()` triggern
- **Draft-Liste** (klein, unter dem Formular oder als Banner): offene Drafts anzeigen (Datum + Gewicht), manueller „JETZT SYNCEN"-Button

### 3. web/src/components/SyncIndicator.astro (NEU)
- Zeigt Online/Offline-Status + wartende Draft-Anzahl
- Nutzt offline-queue.ts (getDrafts) + online/offline-Events
- Wird in Layout/Header eingebunden

### 4. web/src/layouts/Layout.astro oder Header.astro (einbinden)
- SyncIndicator überall sichtbar (mobile + desktop)

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/*.html (Design-Referenz)
- VERBOTEN: /etc, andere Projekte, supabase/migrations/, infra/, /tmp, drush, Shell-Schleifen, git-Operationen, Server starten, curl
- KEINE Analyse-Ausflüge. Baue.

## WICHTIG
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- fang-erfassen.astro: bestehendes Formular aus 1.5b ERHALTEN (Feldnamen, saveCatch, searchWaters, Geo) — nur Offline-Logik ERGÄNZEN
- KEINE Beispieldaten. Kein Mock.
- IndexedDB via `indexedDB.open('carp24-offline', 1)` mit onupgradeneeded (Store 'drafts', keyPath 'client_uuid')
- Design: Carp24 Editorial (Warm Sand, Khaki, Olive, JetBrains Mono Labels)

## VERIFIKATION (NUR Statik)
```bash
grep -c "indexedDB" /mnt/projekte/carp24-fangbuch/web/src/lib/offline-queue.ts
grep -c "queueDraft" /mnt/projekte/carp24-fangbuch/web/src/pages/fang-erfassen.astro
grep -c "syncDrafts" /mnt/projekte/carp24-fangbuch/web/src/lib/offline-queue.ts
grep -c "navigator.onLine\|addEventListener('online'" /mnt/projekte/carp24-fangbuch/web/src/pages/fang-erfassen.astro
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts
# muss alle >=1 sein
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
