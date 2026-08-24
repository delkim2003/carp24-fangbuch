## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/marktplatz.astro, design/screens/marktplatz-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: marktplatz.astro — Marktplatz-Card-Deltas (Screen marktplatz-light-de-final.html)

Lies ZUERST per cat design/screens/marktplatz-light-de-final.html (Button Z.146, Cards Z.163-176) und übernimm die Design-Absicht 1:1. Der Kicker ist BEREITS umgestellt (font-mono, nicht anfassen).

### Deltas (WICHTIG alle umsetzen):
1. **Button NEUE ANZEIGE (Z.132):** `bg-primary-container text-on-primary-container` → `bg-primary text-on-primary` (Screen)
2. **Card-BG (Z.297, die mp-active-list Karten im JS-Template):** `bg-surface-container-high border-primary/40` → `bg-[#ccca9b]/15 border-primary/40` (Khaki-Tint, R4-Entscheidung)
3. **Card-Titel:** `text-headline-sm` → `font-headline-md text-headline-md` (Screen)
4. **Card-Preis:** `font-mono text-display-sm text-primary font-bold` → `font-mono text-lg text-primary font-medium` (Screen: deutlich kleiner)

### NICHT ANFASSEN:
- Kategorie-Chips (werden NICHT gebaut, O2)
- Formular, Nachrichten-Logik, Supabase-Anbindung

NUR diese 4 Deltas. Wenn die Card-Klassen im JS-Template (renderItem-Funktion) stehen, dort ändern — exakt dieselben Klassen wie im Server-HTML.

## VERIFIKATION
grep -c "bg-\[#ccca9b\]/15\|font-headline-md text-headline-md\|font-mono text-lg text-primary font-medium\|bg-primary text-on-primary" web/src/pages/marktplatz.astro → ≥4

## COMMIT
Ein Commit: git add web/src/pages/marktplatz.astro && git commit -m "Design: marktplatz LIGHT-Screen-1:1 (Button/Cards/Titel/Preis)"
