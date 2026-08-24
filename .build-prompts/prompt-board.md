## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/board.astro, design/screens/board-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: board.astro — Board-Deltas (Screen board-light-de-final.html)

Lies ZUERST per cat design/screens/board-light-de-final.html (Zähler Z.158, Cards Z.168-173) und übernimm die Design-Absicht 1:1.

### Deltas (WICHTIG alle umsetzen):
1. **Zähler (Z.80):** `font-nav-item text-nav-item text-secondary` → `font-label-sm text-label-sm text-on-surface-variant` (Screen)
2. **Card-BG (Z.114):** `bg-surface-container-high border border-primary/40` → `bg-surface-variant border border-primary/20` (Screen)
3. **Gewicht (Z.121):** `font-mono text-display-sm text-primary font-bold` → `font-mono text-headline-lg text-primary font-semibold` (Screen: headline-lg statt display-sm, semibold statt bold)

NUR diese 3 Klassen-Umstellungen. KEINE neuen Elemente.

## VERIFIKATION
grep -c "font-label-sm text-label-sm text-on-surface-variant\|bg-surface-variant border border-primary/20\|font-mono text-headline-lg text-primary font-semibold" web/src/pages/board.astro → ≥3

## COMMIT
Ein Commit: git add web/src/pages/board.astro && git commit -m "Design: board LIGHT-Screen-1:1 (Zähler/Card-BG/Gewicht)"
