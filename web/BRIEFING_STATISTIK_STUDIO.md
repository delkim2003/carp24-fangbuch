# Build-Briefing: Statistik-Studio (Herzstück von Carp24)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/web/ (src/, public/, astro.config.mjs)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm install
- KEINE Analyse-Ausflüge. Baue sofort.

## Kontext
- Astro 7 + Tailwind v4, Tokens in src/styles/global.css (@theme + components) — NICHT anfassen
- Farben nur aus global.css: bg-surface-container-high, text-primary, text-primary-container, border-primary/40, text-on-surface, text-on-surface-variant, text-tertiary, text-secondary, bg-primary-container, text-error, bg-surface-container-lowest
- Fonts: Headlines text-display-lg/text-headline-md (Source Serif), Mono-Labels font-nav-item text-nav-item uppercase tracking-widest (JetBrains Mono), Body text-body-md
- Logo: /assets/logo_carp24_badge.webp (Header existiert bereits)
- Datei: src/pages/dashboard.astro — WIRD KOMPLETT NEU GESCHRIEBEN

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei.astro << 'ENDOFFILE'
...Code...
ENDOFFILE
JEDER Write-Aufruf schlägt fehl.

## 🎯 ZIEL: Statistik-Studio (Pivot-Prinzip)
Der Nutzer wählt Dimension (X-Achse), Kennzahl (Y-Achse), Serie (Farbaufteilung) und Filter → der Chart wird dynamisch aus den Fang-Daten aggregiert. ALLE Kombinationen möglich.

## 📊 DATENMODELL (im Frontend als Array, Beispieldaten)
```js
const catches = [
  {
    datum: "2025-10-12", uhrzeit: "18:30",
    art: "Spiegelkarpfen", gewicht: 18.4, laenge: 92,
    gewaesser: "Silbersee",
    wassertemperatur: 14.2,       // manuell eingetragen
    lufttemperatur: 11.3,         // API (Open-Meteo)
    luftdruck: 1008,              // API (hPa)
    wind: 12,                     // API (km/h)
    wetterlage: "sonnig",         // API (WMO→klar/sonnig/bewoelkt/regen/sturm)
    mondphase: "zunehmend",       // API (neumond/zunehmend/vollmond/abnehmend)
    koeder: "Boilie",             // aus Notizen
    catchRelease: true,
  },
  // ... weitere 15-20 Beispiel-Fänge (unterschiedliche Monate, Gewässer, Arten, Wetter, Mond)
];
```
Mindestens 18 Fänge über das Jahr verteilt (2025-01 bis 2025-12), 4 verschiedene Gewässer (Silbersee, Linch Hill, Donau Altarm, Waldweiher), 4 Arten (Karpfen, Spiegelkarpfen, Schuppenkarpfen, Graskarpfen), Gewichte 8-24 kg, Längen 70-105 cm, alle 5 Wetterlagen und alle 4 Mondphasen vorkommend.

## 🏗️ UI-AUFBAU (Seite /dashboard)

### 1. Header-Zeile (behalten): "Petri Heil, Angler" + "Dein Überblick für die Saison 2026." + NEUER FANG EINTRAGEN-Button

### 2. Stat-Cards (4, wie bisher): GESAMT FÄNGE 72, SCHWERSTER KARPFEN 21,4 KG, FÄNGE DIESES JAHR 18, AKTIVE GEWÄSSER 5

### 3. STATISTIK-STUDIO Card (das Herzstück):
```
┌──────────────────────────────────────────────┐
│ STATISTIK-STUDIO                              │
│                                               │
│ [X-ACHSE ▾] [KENNZAHL ▾] [SERIE ▾]           │
│                                               │
│ [GLOBAL-FILTER: Zeitraum ▾] [Gewässer ▾]     │
│ [Fischart ▾] [Wetter ▾] [Mond ▾]              │
│                                               │
│ ┌───────────────────────────────────────────┐ │
│ │           (SVG-Chart Bereich)             │ │
│ │                                           │ │
│ └───────────────────────────────────────────┘ │
│ [Als Tabelle anzeigen] [Chart-Typ ▾]          │
└──────────────────────────────────────────────┘
```

### 4. SELECTS (Styled wie bestehende Formulare):
- X-ACHSE (font-label-sm Label + select wie in faenge): "Monat", "Gewässer", "Fischart", "Wetterlage", "Mondphase", "Uhrzeit (Stunde)", "Wochentag"
- KENNZAHL: "Anzahl Fänge", "Ø-Gewicht (kg)", "Max-Gewicht (kg)", "Ø-Länge (cm)", "Summe Gewicht (kg)"
- SERIE (Optional, "Keine" als Standard): "Keine", "Fischart", "Gewässer", "Mondphase", "Wetterlage"
- CHART-TYP: "Auto", "Balken", "Linie", "Scatter", "Heatmap" (Auto wählt sinnvoll)

### 5. GLOBAL-FILTER (Buttons wie bestehende Toggle-Gruppen):
- ZEITRAUM: "ALLE", "2025", "2024" (wenn Daten vorhanden)
- GEWÄSSER: "ALLE", "SILBERSEE", "LINCH HILL", "DONAU ALTARM", "WALDWEIHER"
- FISCHART: "ALLE", "KARPFEN", "SPIEGELKARPFEN", "SCHUPPENKARPFEN", "GRASKARPFEN"
- WETTER: "ALLE", "SONNIG", "BEWÖLKT", "REGEN", "STURM"
- MOND: "ALLE", "NEUMOND", "ZUNEHMEND", "VOLLMOND", "ABNEHMEND"
- Aktiv = bg-surface-container-high text-secondary rounded, inaktiv = text-on-surface-variant
- Alle min-h-11, flex-wrap

### 6. CHART-RENDERING (SVG, NUR Standard-JS — KEINE Chart-Lib, KEIN externes CDN):
Aggregations-Logik (client-seitig in <script is:inline>):
1. Filter anwenden (Zeitraum, Gewässer, Art, Wetter, Mond)
2. Nach X-Achse gruppieren (Monat→Mär, Gewässer→Silbersee, etc.)
3. Kennzahl berechnen (count/avg/max/sum)
4. Wenn Serie ≠ Keine: gruppe zusätzlich nach Serie aufteilen → gestapelte/nebeneinander Balken oder mehrere Linien
5. SVG rendern (viewBox, responsive w-full h-auto, min-h-[300px]):
   - BALKEN: <rect> pro Gruppe, fill = series-Farbe (primär für "Keine", ansonsten Farbpalette aus Tokens: primary-container, tertiary, secondary, error)
   - LINIE: <polyline> + Punkte (Stroke primary, fill primary-container)
   - SCATTER: <circle> pro Fang (x=Dimension, y=Kennzahl-Wert), fill primary-container/70, stroke primary
   - HEATMAP: <rect> Raster (x=Dimension, y=Serie), Farbintensität via fill-opacity, Legende mit Farbstufen
   - Achsen: X-Labels (font-label-sm, fill on-surface-variant), Y-Grid-Linien (stroke outline/20)
6. "ALS TABELLE ANZEIGEN" Toggle: zeigt die aggregierten Daten als <table> (Dimension | Serie | Kennzahl)

### 7. Kein Zustand der alten Charts mehr — komplett neu

## KONSISTENZ
- Alle Selects: bg-surface-container-lowest border border-primary/20 rounded-md py-2 px-3 text-body-md appearance-none min-h-11
- Labels: font-label-sm text-label-sm uppercase text-secondary
- Card: bg-surface-container-high border border-primary/40 rounded-2xl p-lg
- Card-Titel: font-nav-item text-nav-item text-primary-container uppercase tracking-widest mb-6
- Mobile: Selects/Filter 1-spaltig (flex-col), Chart SVG w-full
- KEINE Hex-Farben außerhalb global.css, KEINE externen Fonts/CDN/Chart-Libs

## DEFINITION OF DONE
- dashboard.astro komplett neu: Studio-UI + 18+ Beispieldaten + Aggregations-JS + SVG-Charts (Balken/Linie/Scatter/Heatmap) + Tabellen-Toggle
- Chart reagiert auf Select-Änderungen (X/Kennzahl/Serie/Typ) und Filter-Buttons
- NUR DANN: `cd /mnt/projekte/carp24-fangbuch/web && npm run build` ausführen und Ergebnis melden
