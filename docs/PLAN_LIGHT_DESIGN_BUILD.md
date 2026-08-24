# CARP24 — PLAN: LIGHT-SCREEN-1:1-BUILD (12 Seiten) — v1

> **Auftrag (Philipp, 24.08.):** „leg los aber plane das vorher und lass das abnehmen von audit experten"
> **Ziel:** Die 12 neuen Stitch-LIGHT-Screens (abgenommen, `design/screens/*-light-de-final.html`, Commit `26df541`) sind die VERBINDLICHE Design-Referenz. Die bestehenden Astro-Seiten werden exakt daran angeglichen (1:1), ohne Feature-Änderungen und ohne neue Erfindungen.
> **Status:** Plan v1 → Audit Runde 1 (3 Experten) → Plan vN FINAL → Build (OpenCode) → E2E → Abnahme.

## 1. Ausgangslage (verifiziert 24.08.)

- Die Live-App (`web/`, Astro + Supabase) ist **bereits Light** gebaut: `global.css` enthält alle DS-Tokens (`--color-primary #546140`, Source Serif 4 etc.), Tailwind-Utility-Klassen (`bg-surface-container-high`, `text-primary`) mappen darauf, Dark-Mode via `data-theme`-Toggle existiert.
- **12 Screens generiert + committet** (`26df541`): Dashboard, Fangbuch, Fang-Detail, Rückblick, Trips, Profil, Premium, Board, Forum, Chat, Assistent, Marktplatz. Alle 1:1 aus Live-Code nachgebaut (nichts erfunden), Deutsch, Carp24-Editorial-DS.
- **Kicker-Sektion fehlt in 6 Seiten** (Live-Code): `dashboard.astro`, `faenge.astro`, `faenge/[id].astro`, `board.astro`, `profil.astro`, `premium.astro` haben KEIN `font-kicker`; vorhanden in: `rueckblick`, `trips`, `forum`, `chat`, `assistent`, `marktplatz`.
- Bekannte Stitch-Eigenheiten (toleriert, NICHT in den Build übernehmen): Footer „© 2024", Datum „24.10.2026", Nav-Link „START" (Live-Nav hat kein Start), „LINIENDIAGRAMM PLATZHALTER".

## 2. Scope-Entscheidung

**Build = Design-Feinabgleich der bestehenden Seiten auf die Screens.** KEIN Neu-Build, KEIN Umbau der Datenlogik, KEINE Feature-Änderung. Pro Seite wird geprüft: Struktur/Sektionen/Labels/Abstände gegen die Screen-Referenz; Deltas werden als konkrete Änderungen umgesetzt. Supabase-Anbindung bleibt unangetastet (bereits da, Supabase-first erfüllt).

**Nicht in Scope:** i18n-Erweiterung, CSV/Export-Logik, Backend, Paywall-Logik, Stitch-DS-Font-Mutation (Public Sans statt JetBrains Mono — global.css ist maßgeblich).

## 3. Screen→Page-Mapping + Delta-Kandidaten

| # | Screen (Referenz) | Astro-Seite | Live-Status | Delta-Kandidaten (zu verifizieren) |
|---|-------------------|-------------|-------------|-----------------------------------|
| D1 | dashboard-light | `dashboard.astro` | Struktur identisch (KPIs, Balken, Top-Fänge, Verlauf) | Kicker fehlt; „Petri Heil"-Titel-Stil prüfen; Buttons-Position prüfen |
| D2 | fangbuch-light | `faenge.astro` | CatchCard-Liste + Erfolgs-Banner da | Kicker fehlt; Zähler „N FÄNGE GESAMT" prüfen |
| D3 | fang-detail-light | `faenge/[id].astro` | Foto, Info-Grid, Wetter-Snapshot, Wassertemperatur da | Kicker fehlt; Zurück-Link-Stil prüfen |
| D4 | rueckblick-light | `rueckblick.astro` | KPIs, Mond, Monate, Gewässer, Größte da | Kicker da („SAISON-RESUMEE"-Label prüfen); TEILEN-Button da |
| D5 | trips-light | `trips.astro` | Formular + Trip-Karten da | Kicker da; Formular-Labels prüfen |
| D6 | profil-light | `profil.astro` | Avatar, KPIs, Einstellungen, DSGVO da | Kicker fehlt; Badges-Grid prüfen (Daten geladen, Rendering?) |
| D7 | premium-light | `premium.astro` | Status-Badge, 3 Feature-Karten, Upgrade da | Kicker fehlt; Lock-Icons prüfen |
| D8 | board-light | `board.astro` | Grid + MELDEN + Koordinaten da | Kicker fehlt; „24 ÖFFENTLICHE FÄNGE"-Zähler prüfen |
| D9 | forum-light | `forum.astro` | Chips + Threads da | Kicker da; Chips-Labels prüfen |
| D10 | chat-light | `chat.astro` | Bubbles + Senden da | Kicker da; Bubbles-Design prüfen |
| D11 | assistent-light | `assistent.astro` | KI-Chat da | Kicker da; Willkommens-Bubble prüfen |
| D12 | marktplatz-light | `marktplatz.astro` | Anzeigen-Grid + Formular da | Kicker da; **Kategorie-Chips (ALLE/RUTE/BOILIES/ROLLE/ZUBEHOER/ANDERE) fehlen im Markup** — prüfen ob Feature fehlt |

**Jede Zeile bekommt im Build ein `data-testid`-Anker + visuellen Check gegen das Abnahme-PNG.**

## 4. Build-Methode (OpenCode, Regeln aus Skills)

- Modell: **GLM 5.2** (`openrouter/z-ai/glm-5.2`) für Frontend/Design-Feinabgleich (kein Backend).
- JEDER Prompt enthält: ARBEITSBEREICH-Sektion (nur `web/src/`), „KEINE Analyse-Ausflüge", „🚫 WRITE-TOOL KAPUTT → Shell-Heredoc", Referenz-Pfad zur projekt-internen Screen-Datei (`design/screens/<screen>-light-de-final.html` — projekt-intern, OpenCode kann sie lesen).
- **NICHT erfinden:** Exakte Texte/Labels/Strukturen aus der Referenz-Datei übernehmen, KEINE neuen Sektionen.
- Jede Seite einzeln, 1 Commit pro Seite, `git status` + `git diff --stat HEAD~1` nach jedem Lauf.
- Vor jedem Build: `git status` clean (Commit `26df541` ist Basis).

## 5. Reihenfolge (Batches)

- **Batch A (Kicker + Kopf, 6 Seiten):** dashboard → faenge → fang-detail → board → profil → premium (nur fehlende Kicker + Kopf-Deltas)
- **Batch B (Community-Deltas):** marktplatz (Kategorie-Chips prüfen/nachbauen), chat (Bubble-Styling), forum (Chips), board (Zähler)
- **Batch C (Konsistenz-Feinschliff):** rueckblick, trips, assistent — nur wo Screen abweicht
- Nach jedem Batch: Build (`npm run build`) + Preview + Sichtprüfung gegen Abnahme-PNG.

## 6. QA-Gates

| Gate | Aktion | Ausstieg |
|------|--------|----------|
| G0 | Plan-Review-Before-Build | 2+ Experten OK, 3. nur Mini-Fixes → Plan FINAL |
| G1 | Nach jedem Seiten-Build | `npm run build` grün, Commit sauber (nur Source-Files) |
| G2 | Nach jedem Batch | `astro preview` + Sichtprüfung gegen Abnahme-PNG (data-testid-Check) |
| G3 | E2E-Smoke (Login + 3 Kernseiten) | Login ok, statistik/faenge/dashboard rendern mit echten Daten |
| G4 | Abnahme | Philipp prüft Preview-Links, dann Go-Live (systemctl restart carp24-web) |

## 7. Risiken & Regeln

1. **Keine Erfindungen:** Screen-Datei ist Referenz; tolerierte Stitch-Eigenheiten NICHT übernehmen.
2. **Keine Feature-Änderung:** Backend/Paywall/CSV/i18n bleiben unangetastet (separate Tasks).
3. **Kein Overengineering:** Deltas sind klein; wo Live-Code bereits 1:1 zum Screen ist → keine Änderung.
4. **OpenCode-Pitfalls:** Write-Tool-Verbot, Shell-Heredoc, ARBEITSBEREICH, kein Explore-Mode, Referenz projekt-intern.
5. **Kicker-Klasse:** prüfen dass `font-kicker`/`text-kicker` im global.css definiert sind (falls nicht → als Teil von Batch A definieren, aber nur wenn Screens Kicker zeigen).
6. **Dark-Mode:** Umbau darf den `data-theme`-Dark-Mode nicht brechen (global.css-Tokens).
7. **Deployment:** Erst nach G4-Abnahme (`systemctl restart carp24-web`); Preview-Server nach Tests killen (Zombie-Prävention).

## 8. Offene Entscheidungen (für Audit/Philipp)

- O1: Soll die Nav (Header.astro) unverändert bleiben (kein „START"-Link aus den Screens)? → Empfehlung: JA, Live-Nav ist maßgeblich.
- O2: Marktplatz-Kategorie-Chips: fehlendes UI-Feature oder bewusst weggelassen? → prüfen ob es Filter-Funktion im Live-Code gibt; wenn nein: als UI-Chips ohne Funktion NICHT bauen (kein Fake), sondern als Feature-Lücke dokumentieren.
- O3: Kicker-Labels: exakte Texte aus Screens übernehmen (z.B. „SAISON-RESUMEE", „COMMUNITY") oder bestehende i18n-Keys nutzen?

## 9. Test-Matrix (G3-E2E)

- Login (e2e-User) → Dashboard: „Petri Heil" + 4 KPIs sichtbar
- /faenge: Liste mit echten Fängen (oder Empty-State)
- /statistik: 11 Dimensionen offen, Chips rendern (Regression! statistik.astro darf durch Umbau NICHT angefasst werden — nur falls nötig)
- Sichtprüfung: jedes Batch-PNG vs. Abnahme-PNG (12 Seiten)
