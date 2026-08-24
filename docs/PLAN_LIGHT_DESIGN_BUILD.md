# CARP24 — PLAN: LIGHT-SCREEN-1:1-BUILD (12 Seiten) — v2 (R1 eingearbeitet)

> **Auftrag (Philipp, 24.08.):** „leg los aber plane das vorher und lass das abnehmen von audit experten"
> **Ziel:** Die 12 neuen Stitch-LIGHT-Screens (abgenommen, `design/screens/*-light-de-final.html`, Commit `26df541`) sind die VERBINDLICHE Design-Referenz. Die bestehenden Astro-Seiten werden exakt daran angeglichen (1:1), ohne Feature-Änderungen und ohne neue Erfindungen.
> **Modell (Philipp, 24.08.):** **DeepSeek V4 Flash max** (`openrouter/~deepseek/deepseek-v4-flash-latest` + eigenes Flag `--variant max`) — NICHT GLM 5.2.
> **Status:** Plan v1 → R1-Audit (3 Experten, `deleg_7f3a15bf`, 2× AENDERN + 1× Pre-Condition, alle Funde VERIFIZIERT) → **Plan v2** → R2-Audit → Plan FINAL → Build.

## 1. Ausgangslage (verifiziert 24.08.)

- Die Live-App (`web/`, Astro 7.2.4 + Tailwind 4.3.3 + Supabase) ist **bereits Light** gebaut: `global.css` enthält DS-Tokens (`--color-primary #546140`, Source Serif 4), Tailwind-Utilities mappen darauf, Dark-Mode via `data-theme`.
- **12 Screens generiert + committet** (`26df541`), alle 1:1 aus Live-Code nachgebaut.
- **🔴 VERIFIZIERTER FUND (R1-F2, alle 3 Experten unabhängig):** `font-kicker`/`text-kicker` ist in **6 Live-Seiten** (`rueckblick`, `trips`, `forum`, `chat`, `assistent`, `marktplatz`) verwendet, aber in `global.css`/Tailwind-`@theme` **NICHT definiert** → diese Kicker rendern aktuell UNGESTYLT. Grep-Beweis: `grep -rn "kicker" web/src/styles/` = 0 Treffer.
- **VERIFIZIERT (R1-F1):** `dashboard-light-de-final.html` hat **KEINEN Kicker** (grep=0) — Header springt direkt zu „Petri Heil, Angler". Kein Kicker-Delta für Dashboard.
- **VERIFIZIERT (R1-F4):** i18n hat nur EINEN generischen Key `kicker` = „PASSION. FISHING. COMMUNITY." — Screens zeigen pro Seite ANDERE Kicker-Texte (Rückblick „SAISON-RESUMEE", Marktplatz/Chat/Board „COMMUNITY").
- Bekannte Stitch-Eigenheiten (toleriert, NICHT übernehmen): Footer „© 2024", Datum „24.10.2026", Nav-Link „START", „LINIENDIAGRAMM PLATZHALTER".

## 2. Scope-Entscheidung (R1-bestätigt: korrekt abgegrenzt)

**Build = Design-Feinabgleich der bestehenden Seiten auf die Screens.** KEIN Neu-Build, KEIN Daten-/Backend-Umbau, KEINE Feature-Änderung. Ausgenommen: Kicker-Styling-Fix (F2) und i18n-Kicker-Keys (F4) — beide gehören zum 1:1-Ziel, da die Screens Kicker zeigen.

**Nicht in Scope:** i18n-Erweiterung über Kicker hinaus, CSV/Export-Logik, Backend, Paywall-Logik, Marktplatz-Kategorie-Chips (F7), Stitch-DS-Font-Mutation (global.css ist maßgeblich).

## 3. Screen→Page-Mapping + Delta-Kandidaten (R1-korrigiert)

| # | Screen (Referenz) | Astro-Seite | Delta-Kandidaten (R1-verifiziert) |
|---|-------------------|-------------|-----------------------------------|
| D1 | dashboard-light | `dashboard.astro` | **KEIN Kicker** (F1: Screen hat keinen) → Live ist bereits 1:1; nur Sichtprüfung |
| D2 | fangbuch-light | `faenge.astro` | Kicker fehlt (Screen: prüfen ob Kicker da); Zähler prüfen |
| D3 | fang-detail-light | `faenge/[id].astro` | Kicker fehlt (Screen prüfen); Zurück-Link-Stil prüfen |
| D4 | rueckblick-light | `rueckblick.astro` | Kicker DA aber ungestylt (F2); Screen nutzt `font-label-sm text-label-sm text-primary` für „SAISON-RESUMEE" — auf Screen-Stil umstellen |
| D5 | trips-light | `trips.astro` | Kicker DA aber ungestylt (F2); Formular-Labels prüfen |
| D6 | profil-light | `profil.astro` | Kicker fehlt (Screen prüfen); Badges-Grid prüfen |
| D7 | premium-light | `premium.astro` | Kicker fehlt (Screen prüfen — R1: kein Kicker vor PREMIUM); Lock-Icons prüfen |
| D8 | board-light | `board.astro` | Kicker fehlt; „COMMUNITY"-Kicker (Screen) vs Live; Zähler „N ÖFFENTLICHE FÄNGE" prüfen |
| D9 | forum-light | `forum.astro` | Kicker DA aber ungestylt (F2); Chips-Labels prüfen |
| D10 | chat-light | `chat.astro` | Kicker DA aber ungestylt (F2); „COMMUNITY"-Kicker prüfen; Bubble-Styling prüfen |
| D11 | assistent-light | `assistent.astro` | Kicker DA aber ungestylt (F2); Willkommens-Bubble prüfen |
| D12 | marktplatz-light | `marktplatz.astro` | Kicker DA aber ungestylt (F2); Kategorie-Chips NICHT bauen (F7) |

**Jede Seite bekommt im Build einen `data-testid`-Anker + visuellen Check gegen das Abnahme-PNG.**

## 4. Build-Methode (R1-fixiert)

- **Modell (Philipp-Vorgabe):** `opencode run --model "openrouter/~deepseek/deepseek-v4-flash-latest" --variant max` (Frontend/Design-Feinabgleich; `--variant` ist EIGENES Flag, nie in den Modell-String).
- JEDER Prompt enthält: ARBEITSBEREICH-Sektion (nur `web/src/`), „KEINE Analyse-Ausflüge", „🚫 WRITE-TOOL KAPUTT → Shell-Heredoc", Referenz-Pfad zur projekt-internen Screen-Datei (`design/screens/<screen>-light-de-final.html`).
- **Read-Strategie (R1-Empfehlung):** Im Prompt anweisen, die Referenz-Datei ZUERST mit `cat` zu lesen und die relevanten Sektionen (Header/Kicker/Titel/Sektionstitel) 1:1 zu übernehmen — nicht aus dem Gedächtnis beschreiben.
- **NICHT erfinden:** Exakte Texte/Labels/Strukturen aus der Referenz übernehmen, KEINE neuen Sektionen.
- Jede Seite einzeln, 1 Commit pro Seite, nach jedem Lauf `git status` + `git diff --stat HEAD~1`.
- **Hard Rule (F6):** `git diff -- web/src/pages/statistik.astro` MUSS nach jedem Lauf leer sein; bei Änderung → Build abbrechen, zurücksetzen. statistik.astro ist 904 Z. eigenständig und wird NICHT angefasst.

## 5. Reihenfolge (Batches, R1-fixiert)

- **Batch A.0 — KICKER-FIX (PRE-CONDITION, R1-F2):** In `global.css` `@theme` definieren: `--font-kicker: "JetBrains Mono", monospace; --text-kicker: 12px; --text-kicker--line-height: 16px; --text-kicker--letter-spacing: 0.1em; --text-kicker--font-weight: 500;` — ODER (Screen-1:1, Empfehlung): alle 6 Live-Kicker von `font-kicker text-kicker text-secondary` auf das **Screen-Klassenset** `font-label-sm text-label-sm uppercase tracking-widest` umstellen (Rückblick-Screen nutzt `text-primary`; Farbe pro Seite gegen Screen prüfen). Entscheidung im Build-Briefing pro Seite.
- **Batch A (Kicker+Header, 6 Seiten):** dashboard (nur Sichtprüfung) → faenge → fang-detail → profil → premium → board
- **Batch B (Community-Deltas):** marktplatz (KEIN Chips-Bau, nur Kicker-Styling) → chat (Bubble-Styling) → forum (Chips-Labels) → board (Zähler)
- **Batch C (Konsistenz-Feinschliff):** rueckblick → trips → assistent — nur wo Screen abweicht
- Nach jedem Batch: `npm run build` + Preview + Sichtprüfung gegen Abnahme-PNG.

## 6. QA-Gates (R1-verschärft)

| Gate | Aktion | Ausstieg |
|------|--------|----------|
| G0 | Plan-Review-Before-Build | 2+ Experten OK, 3. nur Mini-Fixes → Plan FINAL |
| G0.5 | Kicker-CSS-Vorbereitung | `grep -rn "kicker" web/src/styles/` > 0 (Token oder Umstellung committet) |
| G1 | Nach jedem Seiten-Build | `npm run build` grün; Commit sauber (nur Source-Files); **`git diff --statistik.astro` LEER**; keine i18n.ts-Änderungen außer Kicker-Keys |
| G1.5 | Scope-Check je Lauf | `git diff --stat HEAD~1`: nur erwartete Datei + global.css + i18n-Kicker-Keys; sonst Zurücksetzen |
| G2 | Nach jedem Batch | `astro preview` + Sichtprüfung gegen Abnahme-PNG; **Dark-Mode-Sichtprüfung** (data-theme-Toggle) |
| G3 | E2E-Smoke (12 Seiten) | Jede der 12 Routen: 200 OK + `data-testid`-Anker sichtbar (Login als e2e-User für geschützte Seiten) |
| G4 | Abnahme | Philipp prüft Preview-Links → Go-Live (`systemctl restart carp24-web`) |

## 7. Test-Matrix (R1-F5: auf 12 Seiten erweitert)

Pro Seite (12 Einträge): `data-testid`-Anker + Dark-Mode-Check + Empty/Daten-Zustand:

| Seite | data-testid-Anker (Vorschlag) | Zustände |
|-------|-------------------------------|----------|
| /dashboard | `dashboard-kpis` | eingeloggt (Daten/Empty) |
| /faenge | `fangbuch-liste` | eingeloggt (Daten/Empty) |
| /faenge/[id] | `fang-detail-wetter` | eingeloggt (Fund/404) |
| /rueckblick | `rueckblick-kpis` | eingeloggt (Jahr/Empty) |
| /trips | `trips-liste` | eingeloggt (Daten/Empty) |
| /profil | `profil-kpis` | eingeloggt |
| /premium | `premium-features` | eingeloggt/ausgeloggt |
| /board | `board-grid` | eingeloggt (Daten/Empty) |
| /forum | `forum-threads` | eingeloggt (Daten/Empty) |
| /chat | `chat-messages` | eingeloggt |
| /assistent | `ai-chat` | eingeloggt |
| /marktplatz | `mp-active-list` | eingeloggt Pro (Lock-Empty für Free) |

Zusätzlich: Login-Flow, statistik.astro-Regression (G1-Hard-Rule), Dark-Mode je Seite, responsive Sichtprüfung (Desktop 1280px maßgeblich).

## 8. Entscheidungen (R1: O1/O2/O3 ENTSCHIEDEN)

- **O1 ENTSCHIEDEN:** KEIN „START"-Link in der Nav. Live-App hat keine `/start`-Route; Screen-Referenz wird in diesem Detail NICHT gefolgt (dokumentierter Widerspruch, R1-F3).
- **O2 ENTSCHIEDEN:** Marktplatz-Kategorie-Chips (ALLE/RUTE/BOILIES/ROLLE/ZUBEHOER/ANDERE) werden **NICHT gebaut** — keine Filter-Funktion im Live-Code. Feature-Lücke in `docs/` dokumentieren (R1-F7).
- **O3 ENTSCHIEDEN:** **Pro Seite eigener i18n-Kicker-Key** (`kicker.rueckblick` = „SAISON-RESUMEE", `kicker.marktplatz` = „COMMUNITY", etc. — Texte exakt aus den Screens); generischer `kicker`-Key bleibt Fallback für Seiten ohne Screen-Kicker (R1-F4). Nur Seiten MIT Screen-Kicker bekommen Keys.

## 9. Risiken & Regeln (R1-aktualisiert)

1. **Keine Erfindungen:** Screen-Datei ist Referenz; tolerierte Stitch-Eigenheiten NICHT übernehmen.
2. **Keine Feature-Änderung:** Backend/Paywall/CSV/Marktplatz-Chips bleiben unangetastet.
3. **Kein Overengineering:** Wo Live-Code bereits 1:1 zum Screen ist → keine Änderung (Dashboard = nur Sichtprüfung).
4. **OpenCode-Pitfalls:** Write-Tool-Verbot, Shell-Heredoc, ARBEITSBEREICH, kein Explore-Mode, Referenz projekt-intern, `--variant max` als eigenes Flag.
5. **Kicker-CSS (F2) = Pre-Condition G0.5** — NICHT optional.
6. **Dark-Mode:** Umbau darf `data-theme`-Dark-Mode nicht brechen (global.css-Tokens).
7. **Deployment:** Erst nach G4-Abnahme; Preview-Server nach Tests killen (Zombie-Prävention).

## 10. R1-Funde → Fix-Bilanz

| Fund | Schwere | Status |
|------|---------|--------|
| F1 Delta-Overestimation Dashboard-Kicker | 🟡 | ✅ v2: D1 korrigiert |
| F2 Kicker-CSS-Klassen fehlen | 🔴 | ✅ v2: G0.5 + Batch A.0 |
| F3 O1 unzureichend begründet | 🟠 | ✅ v2: ENTSCHIEDEN |
| F4 O3 Kicker-Keys unentschieden | 🟠 | ✅ v2: ENTSCHIEDEN (i18n pro Seite) |
| F5 Test-Matrix zu dünn | 🟠 | ✅ v2: 12 Einträge + Dark-Mode + data-testid |
| F6 statistik.astro-Guard schwach | 🟡 | ✅ v2: Hard Rule + G1.5 |
| F7 O2 bereits entschieden | 🟢 | ✅ v2: ENTSCHIEDEN |
| (E1/E2) Modell GLM → DeepSeek V4 Flash max | — | ✅ v2: Philipp-Vorgabe |
