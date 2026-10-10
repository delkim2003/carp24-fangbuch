# Nachrichtenzentrale (Volles Postfach) — Sequenzplan

> **Für Hermes:** Code NUR via OpenCode (Briefings ≤2KB, AUSFÜHREN-MODUS). Phasen-Doku nach JEDER Phase (Projekt-Root + Vault 02_SYSTEM). QA NUR Minerva. GO-Gates wie markiert. Stand: 2026-10-08 17:32.

**Goal:** Branchenübliches Nachrichten-Postfach für den Marktplatz (Inbox + Chat-Threads + Antwortmöglichkeit + Unread-Badge + E-Mail-Hinweis), Muster Kleinanzeigen/Vinted. PLUS P0: Foto-Vorschau-Bug schließen (offener Punkt aus dem Moderations-Block).

**Architecture:** Bestehende Tabelle `marketplace_messages` (0001_init, derzeit 0 Zeilen) wird reaktiviert statt neu erfunden: FK auf aktuelle `marketplace_items`, `read_at` dazu. **Thread = (listing_id, Nutzerpaar) — KEINE eigene threads-Tabelle (YAGNI).** Server-Endpoints mit Session-Auth (Muster `contact.ts`/`submitted.ts`), UI als eigene Seite `/nachrichten` (Inbox + Thread-Ansicht), Mail-Hinweis pro neuer Nachricht via `lib/mail.ts`. Supabase-Realtime ist für die Tabelle bereits publiziert.

**Tech Stack:** Astro SSR · Supabase (RLS) · Zoho SMTP · Stitch (Design, `assets/9ae0bc7fe13b44e49da8fbee7c9a32be`) · OpenCode MiMo (BE) / v4-flash `--variant max` (FE) · Minerva (QA).

## Verifizierte Fakten (08.10., DEV-DB + Code)
- `marketplace_messages`: id, listing_id (FK → **`marketplace_listings` = ALT!**), from_user, to_user, message, created_at. RLS `insert_sender` (from_user=uid) + `select_from_to` (from/to=uid). In `supabase_realtime` publiziert. Anonymizer-Trigger 0011 („gelöschter Nutzer") greift.
- `marketplace_contacts`: item_id, from_user, to_user, message (CHECK 3–2000), created_at — **0 Zeilen**. `web/src/pages/api/marketplace/contact.ts` schreibt hier rein (Session-Auth, Item muss active sein, kein Self-Chat) — **OHNE Mail**.
- `marketplace_listings` = Alt-Tabelle existiert noch; aktuell ist `marketplace_items`.
- Global-Chat (`channels`/`chat_messages`) = separates Feature — **NICHT anfassen**.
- Formular-Vorschau (marktplatz.astro): `URL.createObjectURL` pro Datei = korrekt; Upload-Ref `'foto:'+uid+'/marketplace/…'` korrekt; **Anzeige-Wege (`_photoUrl` SSR + admin `photo_urls`) sind noch nie mit echten Fotos getestet** (E2E hatte fotos={}) → P0.

---

## P0 — Foto-Vorschau: Repro + Fix (schließt den offenen Block) 🚦 läuft
- **P0.1 (Minerva): Repro mit echtem Foto** (lokal, DEV-first, Test-Rows mit Cleanup): 1×1-PNG generieren → als Test-User per User-JWT in `catch-photos` hochladen (`<uid>/marketplace/test.webp` — RLS-Pfad!) → Item mit `photos: ['foto:<uid>/marketplace/test.webp']` anlegen → (a) GET `/api/admin/content?type=marketplace` mit Admin-Session → `photo_urls[0]` = ? → die URL per curl abrufen (HTTP-Status!), (b) `node dist/server/entry.mjs` rendert `/marktplatz` → `_photoUrl` im HTML?, (c) Vergleichsfall defekter Ref („Vorschau nicht verfügbar"/null). Beweis-Report je Schritt.
- **P0.2 (OpenCode, Modell nach Fundstelle):** Fix des bestätigten Bugs + Re-Verifikation durch Minerva. Wenn P0.1 GRÜN: Formular-Kacheln (objUrl) per Browser-Check gegenprüfen und Philipp um Screenshot bitten.
- GO-Gate: Re-Audit grün → Block W231–Moderation ist dann komplett → **P6 des Moderations-Plans (Closure) nachholen**.

## P1 — Design über STITCH (Delta-Regel!) + Abnahme durch Philipp 🚦 PFLICHT-GATE
- 2 Delta-Screens, **MOBILE** (deviceType MOBILE, designSystem `assets/9ae0bc7fe13b44e49da8fbee7c9a32be`, Prompt = NUR Struktur/Inhalt, **ALLE UI-TEXTE AUF DEUTSCH**):
  1. **„Nachrichten – Inbox"**: Thread-Liste (Kontaktname, Anzeigen-Zeile mit Foto-Thumb/Titel, letzte Nachricht, Zeit, Unread-Punkt), Empty-State „Noch keine Nachrichten.", Nav-Kontext mit NACHRICHTEN + Badge.
  2. **„Nachrichten – Chat"**: Anzeigen-Kontextkarte oben (Thumb, Titel, Preis, Link), Bubble-Verlauf (eigene rechts/fremd links, Zeitstempel), Quick-Reply-Chips („Ist noch verfügbar?", „Wann kann ich abholen?"), Input + SENDEn-Button.
- **Delta-Regel + Zwei-Listen-Presentation:** „WIRD GEBAUT (neu) / BLEIBT UNVERÄNDERT" — kein Redesign (Philipp 08.10.: „es darf nicht zu viel vom jetzigen Design abweichen").
- Sequenziell generieren (kein Parallel-Stau), HTML+PNG sofort sichern (`=s0`), Vision-Selbstcheck (8-Punkte) VOR der Abnahme.
- **GO-Gate: Philipps Design-Abnahme VOR Frontend-Build** (P2 Backend läuft parallel design-unabhängig weiter).

## P2 — Backend (OpenCode MiMo) — design-unabhängig, 2 Briefings ≤2KB
- **P2.1 Migration `supabase/migrations/0060_marketplace_messaging.sql`:**
  1. `ALTER TABLE marketplace_messages DROP CONSTRAINT marketplace_messages_listing_id_fkey; ADD CONSTRAINT … FOREIGN KEY (listing_id) REFERENCES marketplace_items(id) ON DELETE CASCADE;`
  2. `ADD COLUMN read_at timestamptz;` + `ADD CONSTRAINT marketplace_messages_message_check CHECK (char_length(message) >= 3 AND char_length(message) <= 2000);` + Index `(to_user, read_at)` + `(listing_id, from_user, to_user)`.
  3. Altbestand (idempotent): `INSERT INTO marketplace_messages (listing_id, from_user, to_user, message, created_at) SELECT item_id, from_user, to_user, message, created_at FROM marketplace_contacts c WHERE NOT EXISTS (SELECT 1 FROM marketplace_messages m WHERE m.listing_id = c.item_id AND m.from_user = c.from_user AND m.created_at = c.created_at);`
  4. Anwenden auf **BEIDE** DBs (DEV lokal + LIVE per ssh `cat | docker exec -i`), Beweis mit SOLL-Zahlen (`count(*)` vor/nach, FK-Definition zitieren).
- **P2.2 Endpoint NEU `web/src/pages/api/marketplace/messages.ts`** (Session-Auth wie contact.ts, JSON):
  - `GET ?mode=inbox` → Threads aggregiert pro (listing_id, counterpart): counterpart display_name, listing title, letzte Nachricht + created_at, unread_count, + `unread_total` (für Badge).
  - `GET ?listing_id=X&with_user=Y` → alle Nachrichten des Paares (created_at ASC) + Item-Infos (title, price, photos[0]).
  - `POST {listing_id, to_user, message}` → Validierung wie contact.ts (3–2000, Item existiert, kein Self, to_user = Item-Owner ODER ich bin Owner) + INSERT (from_user=me) + **Mail an Empfänger** (mail.ts, Betreff „Neue Nachricht auf carp24", Auszug + Link `/nachrichten`) — Mailfehler nur console.error.
  - `POST ?mode=read {listing_id, with_user}` → `UPDATE … SET read_at = now() WHERE to_user = me AND from_user = with_user AND listing_id = X AND read_at IS NULL`.
- **P2.3 `contact.ts` UMSTELLEN:** Insert künftig in `marketplace_messages` (identisches Mapping) + Mail — gleicher Endpoint/Vertrag für bestehende Clients, `marketplace_contacts` wird nur noch migriert (keine neuen Zeilen).

## P3 — Frontend (OpenCode v4-flash `--variant max`) — 3 Briefings ≤2KB
- **P3.1 NEU `web/src/pages/nachrichten.astro` (Inbox):** mobil-first, bestehende Layout-/Klassen-Sprache (Delta!), Thread-Liste laut abgenommenem Screen, Empty-State, Klick → Thread-Ansicht (`?listing_id=…&with_user=…`).
- **P3.2 Thread-Ansicht (selbe Seite):** Kontextkarte (Thumb/Titel/Preis/Link), Bubbles (eigene rechts, fremd links, Zeit), Quick-Reply-Chips, Input + Senden (POST messages), Auto-Scroll, Read-POST beim Öffnen + bei neuen fremden Nachrichten, Realtime-Subscribe (`marketplace_messages`, INSERT where to_user=me) + Polling-Fallback 10 s.
- **P3.3 Integration (Delta):** Nav-Eintrag „NACHRICHTEN" + Unread-Badge (bestehende Header-/Nav-Komponente, gleicher Stil), Marktplatz-KONTAKT-Flow verweist künftig auf den Thread (Nachricht ist die 1. Thread-Nachricht), Profilbereich Link „Meine Nachrichten" → `/nachrichten`.

## P4 — QA (Minerva) — Test-Matrix, „✅ VERIFIZIERT"/„❌" + Beweis
- **RLS-Proofs (SQL, DEV):** User C sieht Thread A↔B NICHT (SELECT = 0 Zeilen); INSERT als Nicht-Sender gesperrt; `read_at`-Update nur für eigene empfangene Nachrichten (fremde Zeilen = 0 betroffen).
- **E2E LIVE (Script-Muster `c24_e2e_moderation_20261008.sh`):** A→B Nachricht (200) + **IMAP-Beweis**, B→A Antwort + IMAP-Beweis, Inbox-Aggregation + unread_count 1→0 nach read-POST, Badge-JSON `unread_total`, contact.ts-Migration-Pfad grün. Cleanup DSGVO.
- **Migration-Proof:** FK → `marketplace_items` (Definition zitiert), Altbestand-SOLL-Zahl, CHECK + Indizes vorhanden.
- **FE-Checks:** TS-Type-Annotationen in `<script is:inline>` = 0 (OpenCode-Pitfall), Umlaut-Drift = 0, Mobile-Vision-QA (390px) der gebauten `/nachrichten`.

## P5 — Deploy LIVE + Abnahme 🚦
Backup `dist.backup.20261008_msgcenter` + Image `rollback-20261008_msgcenter` → Migration LIVE (SOLL-Beweis) → rsync src+dist → `docker build --no-cache` → Container RECREATE → Code-Im-Container-Verify (Marker greppen) → Smoke (200er, /nachrichten 200/302) → **Philipp mobile Abnahme** (Nachricht senden, antworten, Badge, Mails, Inbox).

## P6 — Session-Closure + Phasen-Doku final + Vault-Commit (inkl. Nachhol-Closure Moderations-Block).

---

**Experten-Zuordnung:** P0.1/P4 = Minerva · P1 = Hermes + Stitch · P2 = OpenCode MiMo · P3 = OpenCode v4-flash max · P5 = Hermes (Skill `carp24-deployment`).

**Risiken:** FK-Fix MUSS vor der Datenmigration laufen · contact.ts-Umstellung hält den API-Vertrag (gleiche Route/Parameter) · Realtime ist optional (Polling-Fallback) · DSGVO: Nachrichten werden beim Profil-Löschung anonymisiert (Trigger 0011) ✓ · `marketplace_listings` bleibt unangetastet (Altlast, außer FK-Löschung auf `marketplace_messages`).

**Dateien (wahrscheinlich):** `supabase/migrations/0060_marketplace_messaging.sql` (NEU) · `web/src/pages/api/marketplace/messages.ts` (NEU) · `web/src/pages/api/marketplace/contact.ts` · `web/src/pages/nachrichten.astro` (NEU) · Nav-/Header-Komponente · `web/src/pages/marktplatz.astro` (Kontakt-Flow) · ggf. `web/src/pages/profil.astro`.
