## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/faenge/[id].astro, design/screens/fang-detail-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: faenge/[id].astro — Fang-Detail-Deltas (Screen fang-detail-light-de-final.html)

Lies ZUERST per cat design/screens/fang-detail-light-de-final.html (Label/Werte/Back-Bereich Z.157-175) und übernimm die Design-Absicht 1:1.

### Deltas (WICHTIG alle umsetzen):
1. **Detail-Labels:** `font-label-sm text-label-sm uppercase text-secondary` → `font-mono text-xs uppercase text-primary/70 tracking-widest` (Screen)
2. **Detail-Werte:** `text-body-lg` → `font-headline-md text-headline-md text-on-surface` (Screen)
3. **Zurück-Link:** Farbe `text-secondary` → `text-primary`, Arrow-Char (←) → Inline-SVG-Pfeil (kleines Arrow-Back-SVG, 16px), hover-Effekt `hover:opacity-80 transition-opacity` ergänzen

NUR diese Änderungen. Datenlogik (Wasser-Temp-Anzeige etc.) unangetastet.

## VERIFIKATION
grep -c "font-mono text-xs uppercase text-primary/70\|font-headline-md text-headline-md" web/src/pages/faenge/[id].astro → ≥2
grep -c "text-secondary" web/src/pages/faenge/[id].astro → Zurück-Link-Stelle ersetzt (andere text-secondary Vorkommen ok)

## COMMIT
Ein Commit: git add "web/src/pages/faenge/[id].astro" && git commit -m "Design: fang-detail LIGHT-Screen-1:1 (Labels/Werte/Back-Link)"
