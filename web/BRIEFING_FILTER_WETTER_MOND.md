# Fix-Briefing: Statistik-Filter nach Wetter + Monddaten

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/web/ (src/, public/, astro.config.mjs)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm install
- KEINE Analyse-Ausflüge. Baue sofort.

## Kontext
- Astro 7 + Tailwind v4, Tokens in src/styles/global.css — NICHT anfassen
- Datei: src/pages/dashboard.astro — existiert BEREITS mit 5 Charts (FÄNGE PRO MONAT, GEWICHTS-VERLAUF, TOP-GEWÄSSER, TOP-FÄNGE, BISS-ZEITEN) + Chart-Toggle-Buttons + Inline-Script
- Ziel: Die Statistik-Seite soll die Daten NACH WETTER und MOND-PHASE filtern können

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei.astro << 'ENDOFFILE'
...Code...
ENDOFFILE
JEDER Write-Aufruf schlägt fehl.

## TASK: src/pages/dashboard.astro erweitern

### Bestehende Struktur BEHALTEN (5 Charts + Toggle-Buttons + Inline-Script + Stat-Cards + Recent)
Erweitere OHNE die bestehende Funktionalität zu brechen.

### NEU 1: Filter-Leiste "WETTER" (unter den Stat-Cards, über der Chart-Auswahl)
- Label "WETTER" (font-label-sm text-label-sm uppercase text-secondary)
- 4 Filter-Buttons als Toggle-Gruppe (wie die Sortierung in faenge: flex-wrap, aktiv = bg-surface-container-high text-secondary rounded, inaktiv = text-on-surface-variant):
  - "ALLE" (Standard, aktiv), "SONNIG", "BEWÖLKT", "REGEN", "STURM"
  - type="button", font-nav-item text-nav-item uppercase, min-h-11

### NEU 2: Filter-Leiste "MOND" (direkt unter WETTER)
- Label "MOND" (font-label-sm text-label-sm uppercase text-secondary)
- 5 Toggle-Buttons: "ALLE" (Standard, aktiv), "NEUMOND", "ZUNEHMEND", "VOLLMOND", "ABNEHMEND"
  - gleiche Optik wie WETTER

### NEU 3: Filter-Script
Erweitere das bestehende Inline-Script:
- Beim Klick auf Wetter-Button: `data-filter`-Attribut am body/Container setzen, aktiven Button markieren (active-Klassen wechseln)
- Beim Klick auf Mond-Button: gleiche Logik
- Die Charts reagieren: Jeder Chart-Block bekommt ein `data-weather` und `data-moon` Attribut mit passenden Werten (z.B. Balken im FÄNGE-PRO-MONAT-Chart: manche Monate sonnig, manche bewölkt/regen)
- Filterlogik: Zeigt nur Balken/Datenpunkte, deren data-Attribute mit der Auswahl übereinstimmen. Bei "ALLE" alles zeigen.
- Einfache JS-Implementierung (kein Framework): `document.querySelectorAll('[data-weather]')` + style.display togglen, Balken-Opacity reduzieren statt entfernen (Opacity 20% für gefilterte)

### Datensatz (Beispieldaten für Filter-Effekt):
FÄNGE PRO MONAT mit Wetter/Mond (Beispiel):
- Mär: pct 16, wetter bewölkt, mond neumond
- Apr: pct 33, wetter regen, mond zunehmend
- Mai: pct 25, wetter sonnig, mond vollmond
- Jun: pct 50, wetter sonnig, mond zunehmend
- Jul: pct 80, wetter sonnig, mond vollmond
- Aug: pct 100, wetter sonnig, mond neumond
- Sep: pct 75, wetter bewölkt, mond abnehmend
- Okt: pct 50, wetter regen, mond zunehmend
- Nov: pct 33, wetter sturm, mond neumond
- Dez: pct 16, wetter bewölkt, mond abnehmend

GEWICHTS-VERLAUF (12 Monate Jan-Dez, Werte 12.4, 14.1, 13.8, 16.2, 18.5, 19.1, 21.4, 20.8, 19.2, 17.5, 16.0, 15.2):
- Jan bewölkt neumond, Feb regen zunehmend, Mär sonnig vollmond, Apr bewölkt abnehmend, Mai sonnig zunehmend, Jun sonnig vollmond, Jul sonnig neumond, Aug sonnig abnehmend, Sep bewölkt vollmond, Okt regen zunehmend, Nov sturm neumond, Dez bewölkt abnehmend

TOP-GEWÄSSER (Silbersee 28, Linch Hill 19, Donau Altarm 14, Waldweiher 11):
- Silbersee sonnig vollmond, Linch Hill bewölkt zunehmend, Donau regen abnehmend, Waldweiher sonnig neumond

BISS-ZEITEN (24h, Werte 2,1,1,1,2,6,9,8,4,3,2,2,3,4,5,4,3,3,6,8,10,7,4,2):
- Frühe Stunden (0-8): bewölkt neumond
- Mittag (9-16): sonnig zunehmend
- Abend (17-23): bewölkt vollmond

### Visuelle Filter-Änderung:
- Balken/Datenpunkte die NICHT zur Filterauswahl passen: `opacity-20` (nicht hidden)
- Passende bleiben voll sichtbar
- Bei "ALLE" (Standard): alles voll sichtbar
- Filter wirkt NUR auf den aktuell sichtbaren Chart (der per Chart-Toggle gewählte)

## Konsistenz
- KEINE neuen Hex-Farben, KEINE externen Fonts/CDN
- Alle neuen Buttons: min-h-11 (Touch-Target)
- Mobile: Filter-Leisten wrappen (flex-wrap), Labels + Buttons einspaltig
- Farben nur aus global.css

## Definition of Done
- dashboard.astro hat 2 Filter-Leisten (WETTER + MOND) + erweitertes Script
- Filter-Klick verändert die Balken-Opacity (sichtbar geprüft via Console)
- NUR DANN: `cd /mnt/projekte/carp24-fangbuch/web && npm run build` ausführen und Ergebnis melden
