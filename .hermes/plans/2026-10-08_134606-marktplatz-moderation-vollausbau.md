# Marktplatz-Moderation komplett: Admin-Sicht + Benachrichtigungen — Sequenzplan

> **For Hermes:** Umsetzung EXAKT sequenziell (P1→P6), GO-Gate nach jeder Phase. Code NUR via OpenCode (Briefings ≤2KB, kopierfertig unten). Nach JEDER Phase: Phasen-Doku (Projekt-Root + `vault/02_SYSTEM/`) VOR der nächsten Phase — sonst „Pfusch".

**Goal:** Der DSGVO-Prüfflow wird rund: User bekommt nach dem Absenden eine sichtbare „wird geprüft"-Meldung + Mail; Admin sieht Inhalt + Fotos im Admin Panel + Pending-Hinweis in der Übersicht; Freigabe/Ablehnung versendet Entscheidungs-Mail (mit Begründung).

**Architecture:** Bestehender Flow bleibt unverändert (Client-RLS-Insert `status='pending'`, Admin-Entscheidung via `api/admin/content.ts` POST `action=approve|reject` → `moderation_log` + Status-Update). Ergänzt wird: (1) Notify-Endpoint für die „eingegangen"-Mail, (2) Decision-Mails im Approve/Reject-Handler, (3) Admin-Fetch um `description, photos, category` + signierte Bild-URLs, (4) drei UI-Ergänzungen (Detailkarte, Foto-Vorschau, Pending-Badge) + Success-Feedback.

**Tech Stack:** Astro SSR, Supabase (RLS), `src/lib/mail.ts` (Zoho SMTP, Absender `info@einfach-online.dev`), OpenCode BE `openrouter/xiaomi/mimo-v2.6-pro`, FE `openrouter/~deepseek/deepseek-v4-flash-latest --variant max`, Design-Spec GLM 5.2.

---

## Bewiesener Ist-Stand (file:line, NICHTS geraten)

- `marktplatz.astro:846-853` — Client-Insert `{…, status:'pending'}`; `:855-866` nach Erfolg: Consent-Insert + **`location.reload()` OHNE jede Meldung** → Bug „keine Meldung".
- `marktplatz.astro:705` — Foto-Pfad `uid + '/marketplace/' + …` (heute gefixt, `b85231d`).
- Foto-Refs = `foto:<pfad>` (`onDone('foto:' + filePath)`), Anzeige via `createSignedUrl(ref.slice(5), 3600)` + URL-Rewrite `process.env.PUBLIC_SUPABASE_URL || 'http://supabase-kong:8000'` → `/supabase` (Pattern `marktplatz.astro:79-80`).
- `api/admin/content.ts:412` — JSON-Listen-Branch `type === "marketplace"`: select **nur** `id, user_id, title, price, status, created_at` → `description`, `photos`, `category` fehlen → Bugs „Beitrag nicht sichtbar" + „Bild-Vorschau kaputt" (Fotos werden nie geladen!).
- `api/admin/content.ts:202-237` = CSV-Export-Branch (unverändert lassen; Nebenbefund: `filename="chat.csv"` Copy-Paste-Bug — optional-fix).
- `api/admin/content.ts:636-683` — POST approve|reject: Validierung 636, `moderation_log`-Insert 663 (inkl. `note`), Status-Update 679-683 (`active`/`rejected`) — **keine Mail** → Bugs „keine Entscheidungs-Mail".
- `moderation_log` (DB): `id, item_id, admin_id, decision, checklist jsonb, note text?, created_at` — `note` ist die Begründung ✓.
- `admin/content.astro:197-243` — `renderMarketplace()`: zeigt title/Ersteller/Preis/Status + Prüfliste + Notiz + Buttons, **kein `description`, keine Fotos** → Bug „Beitrag nicht sichtbar".
- `admin/index.astro:57-60` — KPI `marketplaceItems` (Total, `stats.ts:42` zählt ungefiltert) — **kein Pending-Hinweis** → Bug „kein Hinweis in der Übersicht".
- `src/lib/mail.ts` — existierender Mail-Versand (DSA-Decision-Mail nutzt ihn) → wiederverwenden.
- RLS `marketplace_read`: sichtbar für andere nur `status='active''`; `marketplace_insert` = premium-only. Moderationsflow `pending → active|rejected` ist korrekt gebaut (Schema-Check `active|sold|pending|rejected`).

## Experten-Roster (sequenziell)

1. **Experte GLM 5.2 (Design-Denken)** — Output: kurze UI-Spec (Layout-JSON/Bullets) für 3 Elemente. Kein Code.
2. **Experte OpenCode BE (mimo-v2.6-pro)** — P2: API/Mail.
3. **Experte OpenCode FE (v4-flash `--variant max`)** — P3: Astro-UI. Stille-Exit → Retry 1 → MiMo.
4. **Minerva (delegate_task, QA)** — P4: Test-Matrix mit harten Beweisen (curl/SQL/IMAP), ✅/❌-Report.
5. **Hermes (Ops)** — P5 Deploy (Skill `carp24-deployment`), P6 Closure. Kein Code durch Hermes.

---

## P0 — GO-Gates klären (Philipp, vor Start)

1. Admin-Zusatz-Mail an `info@einfach-online.dev` bei jeder neuen Pending-Anzeige? (Empfehlung: JA, 5-Zeilen-Ergänzung im Notify-Endpoint; Badge allein reicht aber auch.)
2. Ablehnungs-Mail Begründung = Admin-Notiz, Fallback-Text „Leider erfüllt die Anzeige unsere Richtlinien nicht." — OK?

**GO Philipp = P1 startet.**

---

## P1 — Design über STITCH (wie immer) + Abnahme durch Philipp 🚦

**🔴 DESIGN-SCHUTZ (Philipp 08.10.): „darf nicht zu viel vom jetzigen Design abweichen" — NUR die neuen Elemente werden implementiert, 1:1 im bestehenden Stil (gleiche Klassen/Tokens wie die live existierenden Admin-Karten/Badges/Toasts). Stitch = Platzierungs- und Wortlaut-Referenz KEIN Redesign. AUSDRÜCKLICH NICHT übernommen:** Footer-Umbau/Copyright-Zeilen, Bottom-Navigation (mobil), „DRINGEND"-Tag + Banner-Subtext (Badge bleibt schlicht wie `maintenance-badge`), erfundene Modul-Umbauten (Wartungsmodus/Kontaktanfragen/KPI-Raster bleiben exakt wie live), erfundene Überschriften („KURATORISCHE PRÜFUNG" etc.), User/Avatar-Details. Umfang = nur das, was Philipp gemeldet hat: (a) Pending-Badge/Hinweis in der Übersicht, (b) Beschreibung+Fotos in der BESTEHENDEN Moderations-Karte (behebt „Beitrag nicht sichtbar"+"Vorschau kaputt"), (c) grüne „In Prüfung"-Meldung im bestehenden Meldungs-Stil nach dem Absenden, (d) die 3 Mails (kein Design-Einfluss). Admin-Zusatz-Mail = NEIN (Badge reicht) — außer Philipp will sie.

**Harte Regel (Skill `stitch-design-to-build`):** Screens-first, **Abnahme vor Build** — kein Code vor Philipps OK. Design-System `assets/9ae0bc7fe13b44e49da8fbee7c9a32be` (Carp24 Editorial) EXPLIZIT setzen. Prompt = nur Struktur/Inhalt (KEINE Hex-Codes/Fonts), ALLE UI-TEXTE AUF DEUTSCH. Screens SEQUENZIELL (kein Parallel-Providerstau), HTML+PNG sofort herunterladen (URLs laufen ab, `=s0` für Vollauflösung), Vision-Selbstcheck (8-Punkte-Checkliste) VOR der Abnahme.

**Screen 1 — Desktop „Admin Content-Moderation Marktplatz"** (Kern): bestehende Card-Sprache (`content.astro:212+`) 1:1 als Basis (Titel+Status-Badge „PRÜFUNG"/„ABGELEHNT", Meta Ersteller · Preis · Kategorie · Datum, Löschen-Button) + NEU: Beschreibung (whitespace-pre-wrap) + Foto-Reihe (max 3, `aspect-square object-cover rounded-lg`, Klick = Vollbild) + Fehler-Placeholder „Vorschau nicht verfügbar" als gezeigter Zustand bei einer Kachel + bestehende PRÜFLISTE (Checkboxes) + Notiz-Textarea + Buttons „Freigeben"/„Ablehnen".
**Screen 2 — Desktop „Admin Übersicht mit Pending-Hinweis"**: bestehendes KPI-Karten-Raster (`index.astro:50-64`, u.a. „Marktplatz-Anzeigen") 1:1 + NEU: auffälliges Badge/Banner „{N} Anzeigen prüfen" mit Link-Charakter auf die Moderation.
**Screen 3 — MOBILE „Marktplatz Formular — Erfolgszustand"**: bestehendes ANZEIGE-ERSTELLEN-Formular (`marktplatz.astro`: TITEL, PREIS, BESCHREIBUNG, KATEGORIE, FOTO mit „BILD AUSWÄHLEN", Foto-Einwilligungs-Checkbox, „VERÖFFENTLICHEN") + NEU: grüne Erfolgsmeldung „In Prüfung – deine Anzeige wird geprüft. Du bekommst eine E-Mail mit dem Ergebnis."

**Ablauf:** generieren (sequenziell) → HTML+PNG sichern (`web/design/screens/`) → Vision-Selbstcheck (UI-Sprache DE, Typo, Bilder, Layout, Fokus erkennbar, Note) → **PNGs + Link an Philipp → explizites OK** → P2/P3. Plan-/Auftrags-Freigabe ersetzt KEINE Design-Freigabe!

---

## P2 — Backend (OpenCode BE mimo-v2.6-pro, 4 Tasks, je 1 Commit)

> AUSFÜHREN-MODUS (in jedes Briefing): „Du bist KEIN Planer. Datei SOFORT per cat-Heredoc schreiben, fertig. NIEMALS den Auftrag als Plan/Steps präsentieren. Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets."

### P2.1 — Notify-Endpoint „Anzeige eingegangen" + Mail
**Files:** Create `web/src/pages/api/marketplace/submitted.ts` (Pattern: Auth-Check + Admin-Muster aus `api/admin/content.ts:18-35`, Mail via `src/lib/mail.ts`).
**Briefing-Vertrag:** POST `{ item_id }`. Prüfen: authentifiziert (locals-Pattern wie `content.ts:18`), Item via `supabaseAdmin.from("marketplace_items").select("id, user_id, title").eq("id", item_id).single()`, `item.user_id === auth.uid()` sonst 403 `{ error: "Nicht erlaubt" }`, sonst 404. Bei OK: Mail an User-E-Mail (via `supabaseAdmin.auth.admin.getUserById(item.user_id)`) — Betreff „Deine Anzeige wird geprüft – carp24 Marktplatz", Body: Titel + „Deine Anzeige ist bei uns eingegangen und wird geprüft (DSGVO/Foto-Check). Du bekommst Bescheid, sobald sie freigegeben oder abgelehnt wurde." Signatur wie DSA-Decision-Mail. Antwort `{ ok: true }`. Fehlerformat `{ error: "Interner Fehler" }`.
**Commit:** `feat(marketplace): Notify-Endpoint + Eingangs-Mail (pending)`.

### P2.2 — Decision-Mails Freigabe/Ablehnung
**Files:** Modify `web/src/pages/api/admin/content.ts:636-683` (NUR der POST-Block approve|reject).
**Briefing-Vertrag:** Nach `status`-Update (679-683) User-Mail holen (`getUserById(user_id)` des Items — Item vorher mit `select("user_id, title")` laden) + Mail senden: approve → Betreff „Deine Anzeige wurde freigegeben", Body Titel + „…ist jetzt auf dem Marktplatz sichtbar: https://carp24.org/marktplatz"; reject → Betreff „Deine Anzeige wurde abgelehnt", Body Titel + **Begründung = `body.note` (Fallback „Leider erfüllt die Anzeige unsere Richtlinien nicht.")** + „Du kannst eine überarbeitete Anzeige neu einreichen." Mail-Fehler: `console.error`, Response bleibt Erfolg (Moderation darf nicht an Mail scheitern).
**Commit:** `feat(marketplace): Entscheidungs-Mails Freigabe/Ablehnung (mit Begründung)`.

### P2.3 — Admin-Fetch: Inhalt + Fotos + signierte URLs
**Files:** Modify `web/src/pages/api/admin/content.ts:412` (Listen-Branch `type === "marketplace"` — NICHT der Export-Branch 202-237!).
**Briefing-Vertrag:** select erweitern: `id, user_id, title, description, price, category, photos, status, created_at`. Pro Item `photo_urls: string[]` erzeugen: für jeden Ref `r` → `adminClient.storage.from("catch-photos").createSignedUrl(r.slice(5), 3600)` (Pattern `rueckblick.astro:30-31`), `signedUrl.replace(process.env.PUBLIC_SUPABASE_URL || "http://supabase-kong:8000", "/supabase")`; fehlgeschlagene Refs → `null` im Array (Client zeigt Fehler-Placeholder). `display_name`-Mapping unverändert.
**Commit:** `feat(admin): Marktplatz-Liste mit description/photos/photo_urls`.

### P2.4 — Pending-Count in Stats
**Files:** Modify `web/src/pages/api/admin/stats.ts` (neben Z. 42) + Response-Feld.
**Briefing-Vertrag:** Zusätzlich `supabaseAdmin.from("marketplace_items").select("id", { count: "exact", head: true }).eq("status", "pending")` mitlaufen lassen, Response ergänzt um `pendingMarketplaceItems: <count>`. Bestehende Felder unverändert.
**Commit:** `feat(admin): pendingMarketplaceItems KPI`.

*(Optional P2.5: Export-Filename `chat.csv` → `marketplace.csv` in `content.ts:237` — 1 Zeile, nur wenn Philipp will.)*

---

## P3 — Frontend (OpenCode FE v4-flash `--variant max`, 3 Tasks, je 1 Commit)

### P3.1 — Admin-Detailkarte + Foto-Vorschau
**Files:** Modify `web/src/pages/admin/content.astro` `renderMarketplace()` (197-243) + `load()`-Mapping, wo `type === "marketplace"` geladen wird (373).
**Briefing-Vertrag:** Card nach P1-Spec erweitern: `item.description` (escHtml, whitespace-pre-wrap), `item.category` in der Meta-Zeile, Foto-Reihe aus `item.photo_urls` (je `<img class="aspect-square object-cover rounded-lg" loading="lazy">`, `<a href=url target="_blank" rel="noopener">`); URL `null`/fehlend → grauer Placeholder mit Text „Vorschau nicht verfügbar". AUSFÜHREN-MODUS. Bestehende Prüfliste/Buttons/Log unverändert.
**Commit:** `feat(admin): Marktplatz-Detailkarte mit Beschreibung + Foto-Vorschau`.

### P3.2 — Pending-Badge in der Übersicht
**Files:** Modify `web/src/pages/admin/index.astro` (Badge nahe Z. 57-60) + Fetch-Mapping (`data.pendingMarketplaceItems`).
**Briefing-Vertrag:** Badge nach P1-Spec: sichtbar nur wenn `pendingMarketplaceItems > 0`, Text „{N} Anzeigen prüfen", Link auf `/admin/content`, gleiche Badge-Sprache wie `maintenance-badge` (Z. 86).
**Commit:** `feat(admin): Pending-Hinweis Marktplatz in der Übersicht`.

### P3.3 — User-Feedback + Notify-Aufruf nach dem Absenden
**Files:** Modify `web/src/pages/marktplatz.astro` Submit-Callback (855-866).
**Briefing-Vertrag:** Nach erfolgreichem insert + Consent: (a) `fetch("/api/marketplace/submitted", { method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify({ item_id: res.data.id }) })` fire-and-forget (`.catch(console.error)`), (b) sichtbare Bestätigung VOR `location.reload()`: grüner Hinweis „In Prüfung – deine Anzeige wird geprüft. Du bekommst eine E-Mail mit dem Ergebnis." (Toast- oder Inline-Muster wie `showMpError`, aber Erfolgsfarbe), erst nach 800 ms `location.reload()`. Buttons bleiben disabled.
**Commit:** `feat(marktplatz): Bestätigung „wird geprüft" + Notify-Call`.

---

## P4 — QA (Minerva via `delegate_task`, selbstständig lesen + testen)

**Test-Matrix (harte Beweise, jede Zeile ✅/❌ + Command-Output):**
1. `POST /api/marketplace/submitted` mit eigenem `item_id` → 200 `{ok:true}` + **IMAP-Beweis** Eingangs-Mail (Pattern `c24_imap_verify.py`, Absender `info@einfach-online.dev`); mit fremdem `item_id` → 403.
2. Insert `pending` → Sichtbarkeit fremd: REST/RLS-Select fremder User = 0 Zeilen (SQL-Beweis).
3. `GET /api/admin/content?type=marketplace` enthält `description`, `photos`, `photo_urls` (längen-beweis).
4. Approve (Test-Item, Rollback am Ende!) → `status='active'` + `moderation_log` (decision/note) + **IMAP-Beweis** Freigabe-Mail + RLS fremd = 1 Zeile.
5. Reject mit `note="Testgrund"` → `status='rejected'` + Mail enthält **„Testgrund"** (IMAP-Beweis, Body-Grep) + RLS fremd = 0.
6. Regression: Foto-Upload-Pfad `uid/marketplace/` (grep dist), Premium-Checkbox-Grant (SQL-Check subscriptions), Smoke `/` `/login` `/marktplatz` `/premium` `/agb` = 200, `/admin/users` = 302.
7. `npx astro build` ✓, `docker logs` keine neuen Errors.
**Abgabe:** ✅/❌-Report als Datei `qa_marktplatz_moderation.md` (workspace) + Telegram-Zusammenfassung. **Minerva-Veto gilt: kein `[x]` ohne `✅ VERIFIZIERT`.**

---

## P5 — Deploy + Abnahme (Hermes, Skill `carp24-deployment`)

1. Backup LIVE: `cp -a /opt/carp24/dist /opt/carp24/dist.backup.20261008_modfix` + `docker tag carp24-app:latest carp24-app:rollback-20261008_modfix`.
2. `npx astro build` lokal → rsync src (Excludes: `node_modules`, `.env`, `dist/`) + rsync dist → `/opt/carp24/dist/`.
3. `docker build --no-cache -t carp24-app:latest .` → Container **RECREATE** (stop/rm/run mit `--env-file /opt/carp24/.env --network supabase_default -p 4321:4321`).
4. Verify Code im Container (grep-Marker **ohne Quote-Escaping** — Lektion von heute!) + Smoke-Loop + Logs.
5. **Philipp-Abnahme mobil:** Absenden → Meldung „wird geprüft" + Mail; Admin: Badge sichtbar, Detailkarte mit Fotos; Freigabe → Mail; Ablehnung → Mail mit Begründung.

## P6 — Closure (vor Session-Ende PFLICHT)

Prozessdateien: `SESSION_HOT_CONTEXT.md` (Block 47), `WAITING_ON_ME.md` (235/236 schließen mit Beweis), `TASK_CONTEXT.md` v47, Dashboards ×2, ggf. `OBSERVATIONS.md` (Fotos-fetch-Vergessen-Pattern) → Vault-Commit + `git show --stat`-Verify.

## Pitfalls (diese Session gelernt — verbindlich!)

- **Verify-Muster ohne Quote-Escaping** durch `ssh`+`sh -c` (heute False-Negative „Code nicht im Container") — immer `grep -F` mit einfachem Muster oder Zeile direkt ausgeben lassen.
- `foto:`-Präfix = 5 Zeichen → **`ref.slice(5)`** ist korrekt (kein Bug!).
- Absender IMMER `info@einfach-online.dev` (`noreply@carp24.org` → Zoho 553).
- OpenCode: Briefings ≤2KB, `cat … | opencode run --model …` mit `bg`+`process_manage wait`, nie `--prompt-file`; Self-Report prüfen (numstat, Umlaut-Drift, Read-Back, Build); V4-Flash Stille-Exit → 1 Retry → MiMo.
- Container-Verify braucht grep-Marker der WIRKLICH neu ist (z.B. `photo_urls`, `pendingMarketplaceItems`).
- Deploy = `--no-cache` + Container-Recreate (restart behält altes Image!).

## Risiken / Tradeoffs

- Mail nach Client-Insert = kleines Duplikat-Risiko bei Doppelklick → Buttons disabled + 800 ms Delay (akzeptabel, YAGNI statt Mail-Log-Tabelle).
- Signierte URLs laufen nach 3600 s ab → Admin-Seite bei längerem Offen-Sein neu laden (wie heute schon im Marktplatz).
- Kein Admin-Mail-Verteiler ohne P0-Entscheidung (Standard: Badge).
