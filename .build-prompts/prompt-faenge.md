## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/faenge.astro, design/screens/fangbuch-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: faenge.astro — Fangbuch-Deltas (Screen fangbuch-light-de-final.html)

Lies ZUERST per cat design/screens/fangbuch-light-de-final.html (Titelbereich Z.156-160) und übernimm die Design-Absicht 1:1.

### Deltas (WICHTIG alle umsetzen):
1. **Titel-Klassen:** `text-display-lg` → `font-headline-lg-mobile md:font-headline-lg text-headline-lg-mobile md:text-headline-lg` (Screen-Klassenset)
2. **Button NEUER FANG:** `bg-primary-container text-on-primary-container font-nav-item text-nav-item` → `bg-primary text-on-primary font-label-sm text-label-sm` (Screen)
3. **Zähler:** `font-nav-item text-nav-item text-secondary` → `font-label-sm text-label-sm text-on-surface-variant` (Screen)

NUR diese 3 Klassen-Umstellungen. KEINE anderen Änderungen, KEINE neuen Elemente, Datenlogik unangetastet.

## VERIFIKATION
grep -n "text-display-lg\|bg-primary-container\|font-nav-item text-nav-item text-secondary" web/src/pages/faenge.astro → erwartete 0 Treffer für die ersetzten Stellen
grep -c "font-headline-lg-mobile\|bg-primary font-label-sm\|font-label-sm text-label-sm text-on-surface-variant" web/src/pages/faenge.astro → ≥3

## COMMIT
Ein Commit: git add web/src/pages/faenge.astro && git commit -m "Design: faenge LIGHT-Screen-1:1 (Titel/Button/Zähler-Klassen)"
