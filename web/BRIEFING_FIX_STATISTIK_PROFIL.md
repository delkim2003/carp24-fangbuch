# Fix-Briefing: Dashboard → Statistik-Seite + Profil vervollständigen

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/web/ (src/, ref/, public/, astro.config.mjs)
- VERBOTEN: /etc, andere Projekte, /tmp, Shell-Schleifen, git, npm install
- KEINE Analyse-Ausflüge. Baue sofort.

## Projekt-Kontext
- Astro 7 + Tailwind v4, Design-Tokens in src/styles/global.css (@theme) — NICHT anfassen
- Fonts lokal, Logo: /assets/logo_carp24_badge.webp
- Farben nur aus global.css (bg-surface-container-high, text-primary, text-primary-container, border-primary/40, text-on-surface, text-on-surface-variant, text-tertiary, text-secondary, bg-primary-container, text-error)
- Referenz-Designs: ref/dashboard.html (Dashboard), ref/profile.html (Profil)
- Sprache: DEUTSCH, Mono-Labels UPPERCASE (font-nav-item text-nav-item), Headlines Source Serif (text-display-lg, text-headline-md)

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei.astro << 'ENDOFFILE'
...Code...
ENDOFFILE
JEDER Write-Aufruf schlägt fehl.

## TASK 1: src/pages/dashboard.astro — ECHTE Statistik-Seite

Mache aus dem Dashboard eine Statistik-Seite, auf der der Nutzer VERSCHIEDENE Statistiken selbst visualisieren kann. Behalte Header/Greeting/Neu-Fang-Button.

### Stat-Cards (oben, unverändert behalten)
4 Cards: GESAMT FÄNGE 72, SCHWERSTER KARPFEN 21,4 KG, FÄNGE DIESES JAHR 18, AKTIVE GEWÄSSER 5

### NEU: Chart-Auswahl (Interaktiv)
Unter den Stat-Cards eine Chart-Auswahl-Leiste (Button-Gruppe wie Sortierung in faenge):
- Buttons (font-nav-item text-nav-item uppercase, aktiv = bg-surface-container-high text-secondary rounded, inaktiv = text-on-surface-variant):
  "FÄNGE PRO MONAT", "GEWICHTS-VERLAUF", "TOP-GEWÄSSER", "TOP-FÄNGE", "BISS-ZEITEN"
- Kleines Inline-Script (is:inline): Klick auf Button → zeigt den passenden Chart-Block (display togglen), Button aktiv/inaktiv wechseln

### 5 Chart-Blöcke (jeweils in eigenem div, nur einer sichtbar, Standard = FÄNGE PRO MONAT):
1. **FÄNGE PRO MONAT** (wie bisher): Balken Mär-Dez (16, 33, 25, 50, 80, 100, 75, 50, 33, 16%)
2. **GEWICHTS-VERLAUF**: Liniendiagramm als CSS — 12 Monatspunkte (Jan-Dez), Werte 12.4, 14.1, 13.8, 16.2, 18.5, 19.1, 21.4, 20.8, 19.2, 17.5, 16.0, 15.2 kg; Punkte + Polyline via SVG (viewBox 0 0 600 200), Stroke primary, Punkte primary-container, darunter Monats-Labels
3. **TOP-GEWÄSSER**: Horizontale Balken mit Gewässer-Namen + Zahl: Silbersee 28, Linch Hill 19, Donau Altarm 14, Waldweiher 11 (Balken bg-primary-container, Breite % von max)
4. **TOP-FÄNGE**: Rangliste (1-3) mit Foto-Thumbnails (assets/stitch/dashboard-1.jpg, catch-list-0.jpg, onboarding-2.jpg — Import mit ?url) + Gewicht + Art + Gewässer: 21,4 KG KARPFEN Stausee, 18,5 KG KARPFEN Waldsee, 14,2 KG KARPFEN Flussbiegung
5. **BISS-ZEITEN**: 24h-Stunden-Balken (0-23h), Peaks früh 5-8 Uhr und abends 18-22 Uhr (z.B. Werte: 2,1,1,1,2,6,9,8,4,3,2,2,3,4,5,4,3,3,6,8,10,7,4,2 — % von max 100)

### Letzte Fänge (rechts/unten, unverändert behalten)
3 Recent-Catches mit Thumbnails (bestehende Imports trophyPhoto/carpPhoto wiederverwenden, für 3. Eintrag onboarding-2.jpg importieren)

## TASK 2: src/pages/profil.astro — Einstellungen vervollständigen

Behalte: Avatar/Name/Mitglied-seit, Stat-Cards, Einheiten, Sprache, Benachrichtigungen, Pro-Status, Abmelden.

### NEU nach "Benachrichtigungen" (vor dem Ende der Einstellungen-Spalte, gleicher Stil py-6 border-b border-primary/20):
1. **DATEN-EXPORT (Art. 20 DSGVO)** — Zeile mit Titel "Daten-Export" + Beschreibung "ALLE PERSONENBEZOGENEN DATEN (JSON + CSV)" + Button "EXPORTIEREN" (border border-primary-container text-primary-container font-label-sm text-label-sm uppercase px-6 py-3 rounded-full min-h-11)
2. **DATENSCHUTZ** — Link-Zeile: Titel "Datenschutz" + Beschreibung "UNSERE DATENSCHUTZERKLÄRUNG LESEN" + Chevron-Icon rechts (Link href="#" target="_blank")
3. **IMPRESSUM** — Link-Zeile: Titel "Impressum" + Beschreibung "RECHTLICHE ANGABEN" + Chevron-Icon rechts (href="#")
4. **GEFAHRENZONE (rot)** — eigener Block mt-8: Titel "GEFAHRENZONE" (text-error), Karte bg-error/5 border border-error/30 rounded-2xl p-6: Beschreibung "KONTO UND ALLE DATEN UNWIDERRUFLICH LÖSCHEN" + Button "KONTO LÖSCHEN" (border border-error text-error font-label-sm text-label-sm uppercase px-6 py-3 rounded-full min-h-11)

## Konsistenz (Pflicht)
- Alle Charts im gleichen Card-Stil: bg-surface-container-high border border-primary/40 rounded-2xl p-lg
- Chart-Titel: font-nav-item text-nav-item text-primary-container uppercase tracking-widest mb-6
- Mobile: Charts 1-spaltig, Chart-Auswahl-Buttons wrappen (flex-wrap), SVG responsive (w-full h-auto)
- KEINE neuen Hex-Farben, KEINE externen Fonts/CDN
- Buttons im Chart-Toggle: type="button"

## Definition of Done
- dashboard.astro: 5 Chart-Blöcke + Auswahl-Leiste + Inline-Script, Standard = FÄNGE PRO MONAT
- profil.astro: 4 neue Einstellungen (Export, Datenschutz, Impressum, Gefahrenzone)
- NUR DANN: `cd /mnt/projekte/carp24-fangbuch/web && npm run build` ausführen und Ergebnis melden
