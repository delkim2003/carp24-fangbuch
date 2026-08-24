## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/profil.astro, design/screens/profil-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: profil.astro — Profil-Deltas (Screen profil-light-de-final.html)

Lies ZUERST per cat design/screens/profil-light-de-final.html (Kopf/KPI/Data-Management Z.159-243) und übernimm die Design-Absicht 1:1.

### Deltas (WICHTIG alle umsetzen):
1. **Name (h1):** `text-display-lg` → `font-headline-lg text-headline-lg` (Screen)
2. **KPI-Zahlen:** `text-headline-lg text-on-surface` → `font-display-lg text-display-lg text-primary` (Screen: display-lg + primary-Farbe)
3. **KPI-Cards:** `bg-surface-container-high border border-primary/40 rounded-2xl` → `bg-surface-variant rounded-xl border border-primary/20` (Screen)
4. **Data-Management-Layout:** gestapelte divs untereinander → Grid `grid grid-cols-1 md:grid-cols-2 gap-gutter` (Screen Z.221-243: 2 Cards nebeneinander)

### NICHT ANFASSEN (Abweichungen, dokumentiert):
- Einheiten-Toggle bleibt (kein Select-Umbau)
- Badge-Grid (Live-Feature) bleibt — Screen zeigt es nicht, Live gewinnt

NUR diese 4 Deltas. KEINE Feature-Änderung.

## VERIFIKATION
grep -c "font-headline-lg text-headline-lg\|font-display-lg text-display-lg text-primary\|bg-surface-variant rounded-xl\|md:grid-cols-2 gap-gutter" web/src/pages/profil.astro → ≥4

## COMMIT
Ein Commit: git add web/src/pages/profil.astro && git commit -m "Design: profil LIGHT-Screen-1:1 (Name/KPI/Cards/Data-Grid)"
