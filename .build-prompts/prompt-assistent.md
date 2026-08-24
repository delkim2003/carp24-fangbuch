## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/assistent.astro, design/screens/assistent-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: assistent.astro — Assistent-Deltas (Screen assistent-light-de-final.html)

Lies ZUERST per cat design/screens/assistent-light-de-final.html (Avatar Z.254-256, Willkommens-Bubble Z.257-258, Button Z.311-313) und übernimm die Design-Absicht 1:1. Der Kicker ist BEREITS umgestellt (nicht anfassen).

### Deltas (WICHTIG alle umsetzen):
1. **AI-Avatar:** Vor der Willkommens-Bubble einen 32px-Container ergänzen mit Inline-SVG-Roboter-Icon (kein External-Font, kein Material-Symbols!) — z.B. abgerundetes Quadrat bg-surface-variant mit Robot-SVG (stroke=currentColor, text-primary)
2. **Willkommens-Bubble (Z.51-53):** `bg-surface-container-lowest rounded-xl px-4 py-3` → `bg-surface-variant rounded-2xl rounded-tl-sm px-5 py-4 border border-primary/10 shadow-sm` (Screen)
3. **Senden-Button (Z.71):** `font-nav-item text-nav-item` → `font-label-sm text-label-sm`, min-height `min-h-11` → `h-[52px]`, Inline-SVG-Send-Icon (Papierflieger, 16px) vor dem Text ergänzen

NUR diese Änderungen. KI-Logik (Fragen, Antworten) unangetastet.

## VERIFIKATION
grep -c "bg-surface-variant rounded-2xl rounded-tl-sm\|h-\[52px\]" web/src/pages/assistent.astro → ≥2
grep -c "svg" web/src/pages/assistent.astro → Avatar/Send-Icon-SVGs vorhanden

## COMMIT
Ein Commit: git add web/src/pages/assistent.astro && git commit -m "Design: assistent LIGHT-Screen-1:1 (Avatar/Bubble/Send-Button)"
