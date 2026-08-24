# CARP24 — PLAN: LIGHT-SCREEN-1:1-BUILD (12 Seiten) — v5 FINAL (R1-R4 eingearbeitet, Build-FREIGEGEBEN)

> **Auftrag (Philipp, 24.08.):** „leg los aber plane das vorher und lass das abnehmen von audit experten"
> **Ziel:** Die 12 Stitch-LIGHT-Screens (abgenommen, `design/screens/*-light-de-final.html`, Commit `26df541`) sind VERBINDLICHE Design-Referenz. Bestehende Astro-Seiten werden exakt angeglichen (1:1), ohne Feature-Änderungen, ohne Erfindungen.
> **Modell (Philipp):** **DeepSeek V4 Flash max** (`opencode run --model "openrouter/~deepseek/deepseek-v4-flash-latest" --variant max`).
> **Status:** v1 → R1 (3 Exp.) → v2 → R2 (3 Exp.) → v3 → R3 (3 Exp., Detail-Funde, 95% Konfidenz) → **v4** → finale R4-Verifikation → FINAL.

## 1. Ausgangslage (verifiziert)

- Live-App Light mit DS-Tokens; Dark-Mode via `data-theme`.
- 🔴 `font-kicker`/`text-kicker` in 6 Live-Seiten, **nicht in global.css definiert** (grep=0) → Kicker ungestylt.
- **Kicker-Matrix (R2/R3-verifiziert):** Nur 5 Screens mit Kicker: rueckblick (SAISON-RESUMEE), trips (ANGEL-REISEN), chat (Community), marktplatz (Sonderfall: `font-mono text-sm`, KEIN Standard-Kicker), assistent (CARP24 hartcodiert). Forum: Live-Kicker ENTFERNEN.
- Stitch-Klassen (`bg-khaki`, `hairline-all`, `font-mono-sm`, `backdrop-blur`, `#E8E0C8`-Background) sind **Stitch-Implementationsdetails** → Design-ABSICHT mit Astro-Tokens/Tailwind-Utilities umsetzen, NICHT 1:1 kopieren. Abnahme-PNGs sind der visuelle Maßstab.
- Bekannte Stitch-Eigenheiten (nicht übernehmen): Footer „© 2024", Nav „START", „LINIENDIAGRAMM PLATZHALTER", `#E8E0C8`-Background-Override (global.css `#f6fbec`-Token ist maßgeblich).

## 2. Scope

**Build = 1:1-Design-Angleichung** (Kicker + Detail-Deltas). KEIN Neu-Build, KEIN Backend, KEINE Feature-Änderung. **Ausnahmen/Abweichungen (dokumentiert):**
- **D6 profil Einheiten:** Screen nutzt `<select>`, Live hat Toggle-Switch → FUNKTIONAL → **Toggle bleibt** (kein Feature-Umbau), dokumentieren.
- **D6 profil Badge-Grid:** Live-Feature vorhanden, Screen zeigt es nicht → **Live-Badge-Grid bleibt** (Screen in diesem Detail NICHT folgen).
- **D11 assistent Icons:** Screen nutzt Material-Symbols-Font → **Inline-SVG** (keine External-Font, DSGVO/Asset).
- **D7 premium Hintergrund:** Screen `#E8E0C8` → **global.css-Token bleibt** (Abnahme-PNG ist Maßstab).

**Nicht in Scope:** i18n über Kicker hinaus, CSV/Export, Paywall, Marktplatz-Chips (O2), Stitch-DS-Font-Mutation.

## 3. KICKER-MATRIX (verbindlich)

| Seite | Screen-Kicker? | Text/Klassen | Live | Aktion |
|-------|----------------|--------------|------|--------|
| dashboard | ❌ | — | ❌ | keine |
| faenge | ❌ | — | ❌ | keine |
| faenge/[id] | ❌ | — | ❌ | keine |
| rueckblick | ✅ | SAISON-RESUMEE, `font-label-sm text-label-sm text-primary` | ✅ ungestylt | Screen-Stil |
| trips | ✅ | ANGEL-REISEN, `font-label-sm text-label-sm` | ✅ ungestylt | Screen-Stil |
| profil | ❌ | — | ❌ | keine |
| premium | ❌ | — | ❌ | keine |
| board | ❌ | — | ❌ | keine |
| forum | ❌ | — | ✅ ungestylt | **ENTFERNEN** |
| chat | ✅ | Community, `font-label-sm text-label-sm text-primary tracking-[0.15em]` | ✅ ungestylt | Screen-Stil |
| assistent | ✅ | CARP24, `font-label-sm text-label-sm text-primary tracking-[0.2em]` | ✅ ungestylt | Screen-Stil (hartcodiert) |
| marktplatz | ✅ (Sonderfall) | COMMUNITY, `font-mono text-sm tracking-widest text-secondary uppercase` | ✅ ungestylt | Screen-Stil (font-mono!) |

Umsetzung: Live-`font-kicker text-kicker text-secondary tracking-widest` → Screen-Klassen pro Seite ersetzen; forum: Kicker-Zeile komplett entfernen. i18n: 4 neue Keys (`kicker.rueckblick`, `kicker.trips`, `kicker.chat`, `kicker.marktplatz`); assistent hartcodiert; generischer `kicker`-Key nur noch für Startseite.

## 4. DETAIL-DELTAS PRO SEITE (R3-Gegenprüfer, 95% Konfidenz, Datei-Beweise)

> WICHTIG = sichtbare Design-Abweichung. Umsetzung mit Astro-Tokens; Abnahme-PNG als Maßstab.

**D2 faenge (fangbuch-light vs faenge.astro):**
1. WICHTIG Titel: Screen `font-headline-lg-mobile md:font-headline-lg text-headline-lg-mobile md:text-headline-lg` vs Live `text-display-lg` → Screen-Klassen.
2. WICHTIG Button NEUER FANG: Screen `bg-primary text-on-primary font-label-sm text-label-sm` vs Live `bg-primary-container text-on-primary-container font-nav-item text-nav-item` → Screen-Klassen.
3. WICHTIG Zähler: Screen `font-label-sm text-label-sm text-on-surface-variant` vs Live `font-nav-item text-nav-item text-secondary`.

**D3 fang-detail (fang-detail-light vs faenge/[id].astro):**
1. WICHTIG Labels: Screen `font-mono text-xs uppercase text-primary/70 tracking-widest` vs Live `font-label-sm text-label-sm text-secondary`.
2. WICHTIG Werte: Screen `font-headline-md text-headline-md text-on-surface` vs Live `text-body-lg`.
3. WICHTIG Zurück-Link: Screen `text-primary` + Arrow-Icon (SVG) + hover vs Live `text-secondary` + ←; Farbe auf primary, Icon als Inline-SVG.

**D6 profil (profil-light vs profil.astro):**
1. WICHTIG Name: Screen `font-headline-lg text-headline-lg` vs Live `text-display-lg`.
2. WICHTIG KPI-Zahlen: Screen `font-display-lg text-display-lg text-primary` vs Live `text-headline-lg text-on-surface` (Farbe primary).
3. WICHTIG KPI-Cards: Screen `bg-surface-variant rounded-xl border (primary/20)` vs Live `bg-surface-container-high border-primary/40 rounded-2xl` → Screen-Token.
4. WICHTIG Data-Management: Screen 2-spaltig (`grid md:grid-cols-2`) vs Live gestapelt → Grid-Layout.
5. ABWEICHUNG Einheiten-Toggle: bleibt (siehe Scope).
6. ABWEICHUNG Badge-Grid: Live-Feature bleibt (siehe Scope).

**D7 premium (premium-light vs premium.astro):**
1. WICHTIG H1: Screen `text-primary` vs Live `text-on-surface`.
2. WICHTIG Upgrade-Button: Screen `bg-primary-container hover:bg-primary text-on-primary-container font-nav-item text-nav-item` vs Live `bg-primary hover:bg-primary-container text-on-primary font-label-sm text-label-sm` → vertauscht fixen (Screen-Klassen).
3. KOSMETISCH Feature-Cards: Screen `bg-surface-container/60 backdrop-blur-sm` + hover vs Live ohne → nur falls einfach.
4. ABWEICHUNG Hintergrund: bleibt (Scope).

**D8 board (board-light vs board.astro):**
1. WICHTIG Zähler: Screen `font-label-sm text-label-sm text-on-surface-variant` vs Live `font-nav-item text-nav-item text-secondary`.
2. WICHTIG Card-BG: Screen `bg-surface-variant border-primary/20` vs Live `bg-surface-container-high border-primary/40`.
3. WICHTIG Gewicht: Screen `font-mono text-headline-lg font-semibold text-primary` vs Live `font-mono text-display-sm font-bold` → headline-lg.

**D10 chat (chat-light vs chat.astro):**
1. WICHTIG Kicker: → Sektion 3 (font-label-sm text-primary tracking-[0.15em]).
2. WICHTIG Button: Screen `font-label-sm text-label-sm` vs Live `font-nav-item text-nav-item`.
3. WICHTIG Input: Screen `rounded-full` + border + `bg-surface/50` vs Live `rounded border-b bg-surface-container-lowest`.
4. WICHTIG Bubble-Name: Screen `font-mono text-[11px] uppercase text-primary` vs Live `font-label-sm text-secondary`.
5. KOSMETISCH Bubble-Shape `rounded-tl-sm`/`rounded-tr-sm` + shadow-sm → übernehmen falls einfach.

**D11 assistent (assistent-light vs assistent.astro):**
1. WICHTIG Kicker: → Sektion 3 (font-label-sm text-primary tracking-[0.2em]).
2. WICHTIG AI-Avatar: Screen 32px div mit Robot-Icon → Inline-SVG-Avatar vor Willkommens-Bubble.
3. WICHTIG Willkommens-Bubble: Screen `bg-surface-variant rounded-2xl rounded-tl-sm border border-primary/10 shadow-sm` vs Live `bg-surface-container-lowest rounded-xl` → Screen-Tokens.
4. WICHTIG Button: Screen `font-label-sm text-label-sm` + Send-Icon (Inline-SVG) + `h-[52px]` vs Live `font-nav-item text-nav-item` ohne Icon.

**D12 marktplatz (marktplatz-light vs marktplatz.astro):**
1. WICHTIG Kicker: Sonderfall `font-mono text-sm tracking-widest text-secondary uppercase` (NICHT font-label-sm).
2. WICHTIG Button NEUE ANZEIGE: Screen `bg-primary text-on-primary` vs Live `bg-primary-container text-on-primary-container`.
3. WICHTIG Card-BG: Screen khaki `rgba(204,202,155,0.15)` + `border #4A5338/40` vs Live `bg-surface-container-high border-primary/40` → mit Astro-Tokens umsetzen.
4. WICHTIG Card-Titel: Screen `font-headline-md text-headline-md` vs Live `text-headline-sm`.
5. WICHTIG Card-Preis: Screen `font-mono text-lg font-medium` vs Live `font-mono text-display-sm font-bold` → text-lg (deutlich kleiner).
6. Chips: NICHT bauen (O2).

**D1 dashboard:** kein Kicker, Struktur 1:1 → nur Sichtprüfung.
**D4 rueckblick / D5 trips:** nur Kicker (Sektion 3); Rest gegen Screen prüfen (R3: keine weiteren WICHTIG-Funde).

## 5. Build-Methode

- Modell: `opencode run --model "openrouter/~deepseek/deepseek-v4-flash-latest" --variant max`.
- **Task 0:** `.build-prompts/<seite>.md` pro Seite mit PROMPT-TEMPLATE (R4-fixiert):
  1. **ARBEITSBEREICH:** „Du arbeitest NUR in /mnt/projekte/carp24-fangbuch/web/. Du liest NUR: <ziel-datei>, design/screens/<screen>-light-de-final.html, web/src/styles/global.css. VERBOTEN: andere Projekte, /tmp, git-Operationen, statistik.astro, Änderungen an i18n.ts außer den 4 Kicker-Keys, Shell-Schleifen."
  2. **WRITE-TOOL-VERBOT:** „🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT! Schreibe per Shell-Heredoc: cat > /pfad/datei << 'ENDOFFILE' … ENDOFFILE"
  3. **READ:** „Lies ZUERST cat design/screens/<screen>-light-de-final.html und übernimm die relevanten Klassen/Struktur 1:1 (Design-Absicht), übersetze Stitch-Spezialklassen (bg-khaki, hairline-all, font-mono-sm) in Astro-Tokens/Arbitrary-Values."
  4. **DELTAS:** exakte Liste aus Sektion 4 (WICHTIG alle; KOSMETISCH nur falls einfach; ABWEICHUNG nicht anfassen).
  5. **DARK-MODE:** „Ändere keine global.css-Tokens und keine data-theme-Logik; Dark-Mode muss funktionieren."
  6. **VERIFIKATION:** „Führe am Ende npm run build aus (im web/ Ordner) — muss grün sein. KEINE Server-Starts, KEIN /tmp."
  7. **COMMIT:** „Ein Commit: git add <dateien>; git commit -m 'Design: <seite> LIGHT-Screen-1:1 (Delta: …)'"
- **D12.3-Khaki-Mapping (R4-entschieden):** `bg-khaki rgba(204,202,155,0.15)` → `bg-[#ccca9b]/15` (Tailwind arbitrary value), Border `#4A5338/40` → `border-primary/40`.
- 1 Commit pro Seite; `git status` + `git diff --stat HEAD~1` nach jedem Lauf.

## 6. Reihenfolge

- **Batch A.0 — KICKER-FIX (G0.5):** 5 Seiten Screen-Stil (rueckblick, trips, chat, assistent, marktplatz) + forum-Entfernung + 4 i18n-Keys.
- **Batch A — Kicker+Community:** A.0-Seiten fertigstellen, forum.
- **Batch B — Detail-Deltas:** faenge → fang-detail → profil → premium → board → chat → assistent → marktplatz.
- **Batch C — Konsistenz:** dashboard Sichtprüfung + Rest.
- Nach jedem Batch: `npm run build` + Preview + Sichtprüfung gegen Abnahme-PNG (je Seite).

## 7. QA-Gates

| Gate | Aktion | Ausstieg |
|------|--------|----------|
| G0 | Plan-Review | 2+ OK, 3. nur Mini → FINAL |
| G0.5 | Kicker-Fix | `grep -rn "font-kicker\|text-kicker" web/src/` = 0 ODER Token definiert; `grep -rn 't("kicker")' web/src/pages/` trifft NUR index.astro (generischer Key) — alle anderen Seiten nutzen `t("kicker.xxx")`; Forum ohne Kicker; marktplatz-Kicker-Zeile hat `data-de`/`data-en` |
| G1 | Pro Seiten-Build | `npm run build` grün; Commit sauber; `git diff -- web/src/pages/statistik.astro` LEER; i18n nur Kicker-Keys |
| G1.5 | Scope-Check | `git diff --stat HEAD~1`: nur erwartete Datei + global.css + Kicker-Keys |
| G2 | Pro Batch | Preview + Sichtprüfung vs Abnahme-PNG + Dark-Mode |
| G3 | E2E-Smoke 12 Seiten | 200 OK + data-testid sichtbar (Login für geschützte) |
| G4 | Abnahme | Philipp prüft → Go-Live (`systemctl restart carp24-web`) |

## 8. Test-Matrix (mit Kicker-Erwartung, R3)

| Seite | data-testid | Kicker-Erwartung | Zustände |
|-------|-------------|------------------|----------|
| /dashboard | `dashboard-kpis` | KEIN Kicker | eingeloggt (Daten/Empty) |
| /faenge | `fangbuch-liste` | KEIN Kicker | eingeloggt (Daten/Empty) |
| /faenge/[id] | `fang-detail-wetter` | KEIN Kicker | eingeloggt (Fund/404) |
| /rueckblick | `rueckblick-kpis` | SAISON-RESUMEE | eingeloggt (Jahr/Empty) |
| /trips | `trips-liste` | ANGEL-REISEN | eingeloggt (Daten/Empty) |
| /profil | `profil-kpis` | KEIN Kicker | eingeloggt |
| /premium | `premium-features` | KEIN Kicker | eingeloggt/ausgeloggt |
| /board | `board-grid` | KEIN Kicker | eingeloggt (Daten/Empty) |
| /forum | `forum-threads` | KEIN Kicker (entfernt) | eingeloggt (Daten/Empty) |
| /chat | `chat-messages` | Community | eingeloggt |
| /assistent | `ai-chat` | CARP24 | eingeloggt |
| /marktplatz | `mp-active-list` | COMMUNITY (mono) | eingeloggt Pro (Lock-Empty Free) |

## 9. Entscheidungen (entschieden)

- O1: kein START-Link; O2: Chips nicht bauen (Feature-Lücke dokumentieren); O3: 4 Kicker-Keys + assistent hartcodiert + forum entfernt.
- **Neu (R3):** D6-Einheiten-Toggle bleibt, D6-Badge-Grid bleibt, D7-Hintergrund bleibt, D11-Icons als Inline-SVG, Stitch-Klassen → Astro-Tokens.

## 10. Risiken & Regeln

1. Keine Erfindungen; Stitch-Klassen nicht 1:1 (Astro-Tokens).
2. Keine Feature-Änderung (Ausnahmen Scope).
3. Kein Overengineering (KOSMETISCH-Deltas nur falls einfach).
4. OpenCode-Pitfalls (Write-Tool, Heredoc, ARBEITSBEREICH, `--variant max`, cat-Read).
5. Kicker-Fix = Pre-Condition G0.5.
6. Dark-Mode nicht brechen.
7. Deployment erst nach G4; Preview-Server killen.

## 11. Fix-Bilanz (R1→R3, alle verankert)

R1: F1-F7 ✅ | R2: 6 Funde ✅ (Kicker-Matrix, G1-Pfad, G0.5, i18n 4 Keys, Deltas, Prompt-Files) | R3: (a) G0.5 + `t("kicker")`-Check ✅ Sektion 7, (b) Test-Matrix Kicker-Erwartung ✅ Sektion 8, (c) **Detail-Deltas komplettiert** ✅ Sektion 4 (D2×3, D3×3, D6×4+2 Abweichungen, D7×2+1 kosm, D8×3, D10×4+2 kosm, D11×4, D12×5) — aus Gegenprüfer-Report (95%).
