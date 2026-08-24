# CARP24 — PLAN: LIGHT-SCREEN-1:1-BUILD (12 Seiten) — v3 (R1+R2 eingearbeitet)

> **Auftrag (Philipp, 24.08.):** „leg los aber plane das vorher und lass das abnehmen von audit experten"
> **Ziel:** Die 12 neuen Stitch-LIGHT-Screens (abgenommen, `design/screens/*-light-de-final.html`, Commit `26df541`) sind die VERBINDLICHE Design-Referenz. Die bestehenden Astro-Seiten werden exakt daran angeglichen (1:1), ohne Feature-Änderungen und ohne neue Erfindungen.
> **Modell (Philipp, 24.08.):** **DeepSeek V4 Flash max** (`opencode run --model "openrouter/~deepseek/deepseek-v4-flash-latest" --variant max`; `--variant` ist EIGENES Flag).
> **Status:** v1 → R1 (3 Exp.) → v2 → R2 (3 Exp., `deleg_9798ee72`) → **Plan v3** → R3-Verifikation → FINAL.

## 1. Ausgangslage (verifiziert 24.08.)

- Live-App (`web/`, Astro 7.2.4 + Tailwind 4.3.3 + Supabase) ist **bereits Light** mit DS-Tokens; Dark-Mode via `data-theme`.
- **🔴 VERIFIZIERT (R1):** `font-kicker`/`text-kicker` in 6 Live-Seiten verwendet, aber **NICHT in global.css definiert** → Kicker rendern ungestylt (grep `kicker` in `web/src/styles/` = 0).
- **🔴 VERIFIZIERT (R2): Kicker-Matrix korrigiert** — Nur **5 Screens haben einen Kicker**: rueckblick („SAISON-RESUMEE"), trips („ANGEL-REISEN"), chat („Community"), marktplatz („COMMUNITY"), assistent („CARP24", hartcodiert). Die anderen 7 Screens (dashboard, fangbuch, fang-detail, profil, premium, board, forum) haben **KEINEN** Kicker (grep-Beweis: nur Logo-„carp24"-Treffer).
- **Konsequenz (R2, KRITISCH):** Live-`forum.astro` hat einen `font-kicker`-Kicker („PASSION. FISHING. COMMUNITY."), aber der forum-Screen hat KEINEN → **Kicker im Forum ENTFERNEN**, nicht stylen.
- Bekannte Stitch-Eigenheiten (toleriert, NICHT übernehmen): Footer „© 2024", Datum „24.10.2026", Nav-Link „START", „LINIENDIAGRAMM PLATZHALTER".

## 2. Scope-Entscheidung (R1+R2-bestätigt)

**Build = Design-Feinabgleich der bestehenden Seiten auf die Screens.** KEIN Neu-Build, KEIN Daten-/Backend-Umbau, KEINE Feature-Änderung. Ausgenommen: Kicker-Styling/-Entfernung (R1-F2, R2-Matrix) und i18n-Kicker-Keys (R1-F4).

**Nicht in Scope:** i18n über Kicker hinaus, CSV/Export, Backend, Paywall, Marktplatz-Chips, Stitch-DS-Font-Mutation.

## 3. KICKER-MATRIX (verbindlich, R2-verifiziert)

| Seite | Screen-Kicker? | Text (Screen) | Live-Kicker? | Aktion |
|-------|----------------|---------------|--------------|--------|
| dashboard | ❌ | — | ❌ | keine Kicker-Aktion |
| faenge | ❌ | — | ❌ | keine Kicker-Aktion |
| faenge/[id] | ❌ | — | ❌ | keine Kicker-Aktion |
| rueckblick | ✅ | SAISON-RESUMEE | ✅ (ungestylt) | auf Screen-Stil umstellen |
| trips | ✅ | ANGEL-REISEN | ✅ (ungestylt) | auf Screen-Stil umstellen |
| profil | ❌ | — | ❌ | keine Kicker-Aktion |
| premium | ❌ | — | ❌ | keine Kicker-Aktion |
| board | ❌ | — | ❌ | keine Kicker-Aktion |
| forum | ❌ | — | ✅ (ungestylt) | **Kicker ENTFERNEN** (R2-KRITISCH) |
| chat | ✅ | Community | ✅ (ungestylt) | auf Screen-Stil umstellen |
| assistent | ✅ | CARP24 | ✅ (ungestylt) | auf Screen-Stil umstellen (hartcodiert, kein i18n) |
| marktplatz | ✅ | COMMUNITY | ✅ (ungestylt) | auf Screen-Stil umstellen |

**Screen-Kicker-Klassenset (aus Screens, R1/R2-verifiziert):** `font-label-sm text-label-sm uppercase tracking-widest`, Farbe pro Seite aus Screen (`text-primary` bei rueckblick/chat). Umsetzung: EINE der beiden Optionen je Seite — (a) `--font-kicker`/`--text-kicker`-Tokens in `@theme` definieren ODER (b) Live-Klassen auf das Screen-Klassenset umstellen. **Empfehlung (R2): Option (b)** — direkter Screen-1:1, kein neues Token nötig; `font-kicker`-Klassen werden überall ersetzt (bzw. bei forum entfernt).

## 4. Screen→Page-Mapping + Delta-Kandidaten (R2-korrigiert)

| # | Screen | Astro-Seite | Delta-Kandidaten (R2-verifiziert) |
|---|--------|-------------|-----------------------------------|
| D1 | dashboard-light | `dashboard.astro` | KEIN Kicker → Live bereits 1:1; nur Sichtprüfung |
| D2 | fangbuch-light | `faenge.astro` | **Titel-Klassen**: Screen `font-headline-lg-mobile md:font-headline-lg` vs Live `text-display-lg`; **Button-Farbe**: Screen `bg-primary` vs Live `bg-primary-container`; Zähler prüfen |
| D3 | fang-detail-light | `faenge/[id].astro` | **Detail-Labels**: Screen `font-mono text-primary/70` vs Live `font-label-sm text-secondary`; Zurück-Link-Stil |
| D4 | rueckblick-light | `rueckblick.astro` | Kicker auf Screen-Stil (SAISON-RESUMEE) |
| D5 | trips-light | `trips.astro` | Kicker auf Screen-Stil (ANGEL-REISEN); Formular-Labels prüfen |
| D6 | profil-light | `profil.astro` | kein Kicker; KPIs/Badge-Grid gegen Screen prüfen |
| D7 | premium-light | `premium.astro` | kein Kicker; Status-Badge/Lock-Icons gegen Screen prüfen |
| D8 | board-light | `board.astro` | kein Kicker; Zähler- und Card-Styling gegen Screen (R2: Screen nutzt `font-label-sm text-label-sm text-on-surface-variant` für Zähler) |
| D9 | forum-light | `forum.astro` | **Kicker ENTFERNEN**; Chips-Labels gegen Screen |
| D10 | chat-light | `chat.astro` | Kicker auf Screen-Stil (Community); Bubble-Styling |
| D11 | assistent-light | `assistent.astro` | Kicker auf Screen-Stil (CARP24); Willkommens-Bubble |
| D12 | marktplatz-light | `marktplatz.astro` | Kicker auf Screen-Stil (COMMUNITY); KEINE Chips bauen |

**Jede Seite bekommt einen `data-testid`-Anker + visuellen Check gegen das Abnahme-PNG.**

## 5. Build-Methode

- **Modell:** `opencode run --model "openrouter/~deepseek/deepseek-v4-flash-latest" --variant max`.
- **Task 0 (VOR Build): Prompt-Files vorbereiten** (R2-Empfehlung): pro Seite/Pro Seite ein Prompt-Template als Datei unter `/mnt/projekte/carp24-fangbuch/.build-prompts/<seite>.md` mit: ARBEITSBEREICH-Sektion (nur `web/src/`), „KEINE Analyse-Ausflüge", „🚫 WRITE-TOOL KAPUTT → Shell-Heredoc", `cat design/screens/<screen>-light-de-final.html`-Read-Anweisung, Scope-Guard (keine statistik.astro/i18n-Dateien außer Kicker-Keys), Commit-Message-Vorgabe.
- **NICHT erfinden:** Texte/Labels/Strukturen 1:1 aus der Referenz; KEINE neuen Sektionen.
- 1 Commit pro Seite; nach jedem Lauf `git status` + `git diff --stat HEAD~1`.

## 6. Reihenfolge (Batches, R2-korrigiert)

- **Batch A.0 — KICKER-FIX (Pre-Condition G0.5):** global.css @theme-Erweiterung ODER Live-Klassen-Umstellung gemäß Kicker-Matrix (Sektion 3); Forum-Kicker entfernen.
- **Batch A (Kicker+Header):** rueckblick → trips → chat → assistent → marktplatz (Kicker-Styling) + forum (Kicker-Entfernung)
- **Batch B (Detail-Deltas):** faenge (Titel/Button) → fang-detail (Labels) → board (Zähler/Cards) → premium/profil (Sichtprüfung gegen Screen)
- **Batch C (Konsistenz):** dashboard (nur Sichtprüfung) + Rest-Feinschliff
- Nach jedem Batch: `npm run build` + Preview + Sichtprüfung gegen Abnahme-PNG.

## 7. QA-Gates (R2-verschärft)

| Gate | Aktion | Ausstieg |
|------|--------|----------|
| G0 | Plan-Review-Before-Build | 2+ Experten OK, 3. nur Mini-Fixes → Plan FINAL |
| G0.5 | Kicker-Fix verifiziert | `grep -rn "font-kicker\|text-kicker" web/src/` = 0 (alle umgestellt/entfernt) ODER `--font-kicker` in global.css vorhanden; Forum ohne Kicker |
| G1 | Nach jedem Seiten-Build | `npm run build` grün; Commit sauber; **`git diff -- web/src/pages/statistik.astro` LEER**; keine i18n-Änderungen außer Kicker-Keys |
| G1.5 | Scope-Check je Lauf | `git diff --stat HEAD~1`: nur erwartete Datei + global.css + Kicker-Keys; sonst Zurücksetzen |
| G2 | Nach jedem Batch | `astro preview` + Sichtprüfung gegen Abnahme-PNG; **Dark-Mode-Sichtprüfung** |
| G3 | E2E-Smoke (12 Seiten) | 12 Routen: 200 OK + `data-testid` sichtbar (Login für geschützte) |
| G4 | Abnahme | Philipp prüft Preview-Links → Go-Live (`systemctl restart carp24-web`) |

## 8. Test-Matrix (12 Seiten, R1-F5)

| Seite | data-testid-Anker | Zustände |
|-------|-------------------|----------|
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
| /marktplatz | `mp-active-list` | eingeloggt Pro (Lock-Empty Free) |

Zusätzlich: Login-Flow, statistik-Regression (G1-Hard-Rule), Dark-Mode je Seite, Desktop 1280px-Sichtprüfung.

## 9. Entscheidungen (entschieden)

- **O1:** KEIN „START"-Link (Live hat keine /start-Route; Screen-Detail wird nicht gefolgt).
- **O2:** Marktplatz-Kategorie-Chips NICHT bauen (keine Filter-Funktion); Feature-Lücke in `docs/` dokumentieren.
- **O3:** i18n-Kicker-Keys pro Seite NUR für Seiten mit Screen-Kicker: `kicker.rueckblick`=„SAISON-RESUMEE", `kicker.trips`=„ANGEL-REISEN", `kicker.chat`=„Community", `kicker.marktplatz`=„COMMUNITY". assistent „CARP24" bleibt hartcodiert. Forum-Kicker wird ENTFERNT (kein Key). Generischer `kicker`-Key bleibt für Startseite.

## 10. Risiken & Regeln

1. Keine Erfindungen; tolerierte Stitch-Eigenheiten nicht übernehmen.
2. Keine Feature-Änderung (Backend/Paywall/CSV/Chips bleiben).
3. Kein Overengineering (Dashboard = nur Sichtprüfung).
4. OpenCode-Pitfalls: Write-Tool-Verbot, Shell-Heredoc, ARBEITSBEREICH, `--variant max` als eigenes Flag, Referenz projekt-intern per `cat`.
5. Kicker-Fix (G0.5) = Pre-Condition, NICHT optional.
6. Dark-Mode nicht brechen (global.css-Tokens).
7. Deployment erst nach G4; Preview-Server nach Tests killen.

## 11. Fix-Bilanz (R1+R2 → v3)

| Fund | Runde | Schwere | Status in v3 |
|------|-------|---------|--------------|
| F1 Dashboard-Kicker-Delta falsch | R1 | 🟡 | ✅ Sektion 4 D1 |
| F2 Kicker-CSS-Klassen fehlen | R1 | 🔴 | ✅ G0.5 + Sektion 3 |
| F3 O1 unzureichend | R1 | 🟠 | ✅ O1 entschieden |
| F4 O3 Kicker-Keys | R1 | 🟠 | ✅ O3 entschieden (4 Keys) |
| F5 Test-Matrix dünn | R1 | 🟠 | ✅ Sektion 8 |
| F6 statistik-Guard | R1 | 🟡 | ✅ G1 (Pfad korrigiert R2) |
| F7 O2 bereits entschieden | R1 | 🟢 | ✅ O2 entschieden |
| R2-1 G1-Pfad falsch | R2 | 🟡 | ✅ `git diff -- web/src/pages/statistik.astro` |
| R2-2 G0.5 nur eine Option | R2 | 🟡 | ✅ Sektion 3 beide Optionen + Empfehlung (b) |
| R2-3 Board/Forum-Mapping falsch | R2 | 🔴 | ✅ Sektion 3 Kicker-Matrix + D8/D9 |
| R2-4 Kicker-i18n 6→4 Keys | R2 | 🟠 | ✅ O3 |
| R2-5 Detail-Deltas D2/D3/D8 | R2 | 🟠 | ✅ Sektion 4 (Titel-Klassen, Button-Farbe, Labels) |
| R2-6 Prompt-Files als Task 0 | R2 | 🟡 | ✅ Sektion 5 Task 0 |
