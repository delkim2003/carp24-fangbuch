# Phasen-Doku — Marktplatz-Moderation Vollausbau (2026-10-08)

Plan: `.hermes/plans/2026-10-08_134606-marktplatz-moderation-vollausbau.md`
Design-Schutz (Philipp 08.10.): „darf nicht zu viel vom jetzigen Design abweichen" — NUR neue Elemente, 1:1 im bestehenden Stil. Kein Redesign.

## P1 — Design über Stitch ✅ (Abnahme Philipp: „Ok")
- Screen 1 `mod-marktplatz-card` (2560×2884): Moderations-Karte mit Beschreibung + Foto-Reihe (Fehlerkachel „Vorschau nicht verfügbar" = bewusster Teil des Konzepts). Vision-QA 8/10.
- Screen 2 `admin-uebersicht-badge` (2560×3306): Hinweis „N Anzeigen prüfen → Zur Moderation" (NUR dieses Element wird übernommen). Vision-QA 9/10.
- Screen 3 `mp-form-success-mobile` (780×3406): grüne „In Prüfung"-Meldung (NUR dieses Element). Vision-QA 9/10.
- Nicht übernommen (trotz Screen): Footer-Umbau, Bottom-Navigation, „DRINGEND"-Tag, Modul-/KPI-Umbauten.

## P2 — Backend via OpenCode (MiMo v2.6-pro) ✅
- BE-1 `93bc6de`: NEU `api/marketplace/submitted.ts` (POST {item_id}: 401/404/403/403/200, Eingangs-Mail „Deine Anzeige wird geprüft – carp24 Marktplatz") + `content.ts` Entscheidungs-Mails nach approve|reject (approve „wurde freigegeben" + Link /reject „wurde abgelehnt" + Begründung `body.note` || Fallback „Leider erfüllt die Anzeige unsere Richtlinien nicht."), Mailfehler nur console.error.
  Verify: numstat +34/−0 & +67/−0 (0 Deletionen), `sendMail(to,subject,text)` = Signatur aus `lib/mail.ts` ✓, Umlaut-Drift 0, echte Umlaute ✓.
- BE-2 `31a301c`: `content.ts` Listen-Branch `type==="marketplace"` — Select + description/category/photos/photo_urls (`foto:`-Ref → `createSignedUrl` 3600s, `/supabase`-Rewrite wie `rueckblick.astro`, Fehler → null) + `stats.ts` `pendingMarketplaceItems` (Promise am Promise.all-**ENDE**, Bestandsindizes unverschoben, Feld in `stats.pendingMarketplaceItems`).
  Verify: Diff vollständig gelesen, einzige Deletion = ersetzte Select-Zeile, Drift 0, Export-Branch unangetastet.
- ⚠️ Korrektur: MiMo `git add -A` committete Müll mit (infra/docker-compose.yml + .bak + design/screens) → `git reset` + sauberer Re-Commit `31a301c` (nur 2 Source-Dateien). **Briefings ab jetzt immer expliziten `git add <dateien>` vorschreiben.**

## P3 — Frontend via OpenCode (v4-flash --variant max) ✅
- FE-1 `3733e08` (content.astro): Meta-Zeile + category, Sektion BESCHREIBUNG (escHtml, leer → '–'), Sektion FOTOS (`flex gap-md`, `<a target="_blank">` + img w-28 h-28, null → graue Kachel „Vorschau nicht verfügbar", leer → „Keine Fotos"). Verify: +20/−1 (Deletion = ersetzte Meta-Zeile), Drift 0.
- FE-2 `008ec52` (index.astro + marktplatz.astro): Pending-Badge `#pending-badge-wrap` unter dem KPI-Grid (`stats.pendingMarketplaceItems` > 0 → Link /admin/content, „N Anzeigen prüfen" / Singular, Maintenance-Badge-Stil) + „In Prüfung"-Meldung (#mp-submit-error, bg-primary-container) + fire-and-forget Notify-POST `/api/marketplace/submitted`, reload nach 800 ms. Verify: +14/−0 & +12/−1 (Deletion = ersetzer reload), Drift 0.

## P4 — Minerva QA (Test-Matrix T1–T6) ✅ 🟢 GRÜN (5/6 ✅, 1 Anmerkung)
- T1 Build `Complete!` ✓ | T2 Dist-Beweise: alle Mail-/Feature-Strings im dist („Anzeigen prüfen" im Client-Bundle = korrekt, dynamisches JS) ✓ | T3 TS-Contracts (401/404/403/200/500, Betreff-Strings, Fallback, Promise=letztes Element) ✓ | T4 Umlaut-Drift 0 in allen 6 Dateien ✓ | T5 DB: status-CHECK `[active|sold|pending|rejected]`, moderation_log, `catch_photos_insert_own` = `(foldername(name))[1]=uid()` ✓ | T6 Routing-Smoke: POST submitted ohne Session → 401 JSON, GET stats → 401 JSON, keine Zombies ✓.
- IMAP-Beweise der 3 echten Mails: bewusst mit dem realen LIVE-Flow in P5 (Abnahme/Script-E2E), da Mailversand + Zoho erst live sinnvoll prüfbar.
## P5 — Deploy LIVE + E2E-Beweise ✅ (mobile Abnahme durch Philipp offen)
- Deploy 08.10.: Backup `dist.backup.20261008_moderation` (7.5M) + Image `rollback-20261008_moderation`, rsync src+dist, `docker build --no-cache` (Image `sha256:1ec67d99…`), Container RECREATE (Up, `supabase_default`). Code-Im-Container greppend bewiesen (`submitted_DsZO4mzn.mjs`, `stats_DEVxh4-U.mjs`, `content_R-FU8GE1.mjs`). Smoke: /, /login, /marktplatz, /premium, /agb = 200 in 0.1–0.25 s, /admin/* = 302, Logs sauber. LIVE-POST /api/marketplace/submitted ohne Session → 401 JSON.
- **E2E auf LIVE (Script `c24_e2e_moderation_20261008.sh`):** Test-User `info+e2emod…@einfach-online.dev` (plus-alias, echte Domain = Bounce-Disziplin) + role=ADMIN via Service-Key, 2 pending Items, Login 200 → submitted 200 `{ok:true}` → approve 200 `{status:active}` → reject 200 `{status:rejected}`. **IMAP-Beweis 3/3 angekommen:** „Deine Anzeige wird geprüft – carp24 Marktplatz", „Deine Anzeige wurde freigegeben", „Deine Anzeige wurde abgelehnt" (Zoho-INBOX). Body-Beweis: Ablehnungs-Mail enthält die individuelle Begründung (KEIN Fallback), Umlaute korrekt. Cleanup (DSGVO): moderation_log + Items + User + Profile gelöscht (204/200). Die 3 Test-Mails bleiben als Beweis im info-Postfach.
- Pitfall (gelernt): `PUBLIC_SUPABASE_URL` in `/opt/carp24/.env` = docker-intern (`http://supabase-kong:8000`) → Host-Scripte müssen `http://localhost:8055` (Kong) nutzen; sonst curl still leer.
- Offen: mobile Abnahme durch Philipp (Checkliste ausgeschickt).
## P6 — Session-Closure + Vault-Commit ⏳
