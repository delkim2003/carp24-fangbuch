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

## P3 — Frontend via OpenCode (v4-flash --variant max) ⏳
FE-1 content.astro: Beschreibung + Foto-Reihe in bestehender Karte. FE-2 index.astro Pending-Badge + marktplatz.astro „In Prüfung"-Meldung + Notify-Call.

## P4 — Minerva QA (Test-Matrix, IMAP/SQL/RLS-Beweise) ⏳
## P5 — Deploy LIVE (Backup, --no-cache, RECREATE, Code-Im-Container-Verify, Smoke) + mobile Abnahme durch Philipp ⏳
## P6 — Session-Closure + Vault-Commit ⏳
