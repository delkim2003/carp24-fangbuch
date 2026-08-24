## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/premium.astro, design/screens/premium-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: premium.astro — Premium-Deltas (Screen premium-light-de-final.html)

Lies ZUERST per cat design/screens/premium-light-de-final.html (H1 Z.166, Upgrade-Button Z.221) und übernimm die Design-Absicht 1:1.

### Deltas (WICHTIG alle umsetzen):
1. **H1-Farbe:** `text-on-surface` → `text-primary` (Screen)
2. **Upgrade-Button (Z.131):** `bg-primary hover:bg-primary-container text-on-primary font-label-sm text-label-sm` → `bg-primary-container hover:bg-primary text-on-primary-container font-nav-item text-nav-item` (Screen — vertauscht fixen)

### NICHT ANFASSEN:
- Hintergrund (global.css-Token bleibt, Screen #E8E0C8 wird nicht übernommen)
- Feature-Cards (backdrop-blur nur falls ohne Risiko — sonst weglassen)

NUR diese 2 Deltas (KOSMETISCH nur falls trivial).

## VERIFIKATION
grep -c "text-primary" web/src/pages/premium.astro → H1-Stelle umgestellt
grep -c "bg-primary-container hover:bg-primary text-on-primary-container font-nav-item text-nav-item" web/src/pages/premium.astro → ≥1

## COMMIT
Ein Commit: git add web/src/pages/premium.astro && git commit -m "Design: premium LIGHT-Screen-1:1 (H1-Farbe, Upgrade-Button)"
