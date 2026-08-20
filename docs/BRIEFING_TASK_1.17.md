# BRIEFING — Task 1.17: Barrierefreiheit (WCAG 2.2 AA) (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen.

## Ziel
WCAG-2.2-AA-Pass über das gesamte Frontend: Skip-Link, Fokus-Styles, Screenreader-Verknüpfungen (aria), Formular-Fehler-Meldungen, Tastatur-Navigation. **0 kritische axe-Fehler** (axe-Test macht der Hauptagent danach selbst via Playwright).

## IST-Zustand (verifiziert — das fehlt)
- **Kein Skip-Link** im Layout → muss rein
- `focus-visible` existiert minimal in global.css (1 Treffer) → erweitern, konsistent über ALLE interaktiven Elemente
- Formular-Fehlerboxen existieren (`#form-error`, `#submit-error` in fang-erfassen; `#login-error` in login), aber **NICHT mit Inputs verknüpft** (kein `aria-describedby`, kein `role="alert"`)
- Header hat aria-labels (4), Footer (1) — prüfen/ergänzen
- Statistik-Studio-Chips setzen `aria-pressed` bereits — prüfen, ob `aria-label`/Fokus sichtbar

## Deliverables (in web/)

### 1. `web/src/layouts/Layout.astro` (PATCH)
- **Skip-Link** direkt nach `<body>` (VOR Header): `<a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:bg-primary focus:text-white focus:px-6 focus:py-3 focus:rounded-full font-nav-item text-nav-item uppercase tracking-widest">Zum Inhalt springen</a>`
- `<main id="main-content" tabindex="-1" ...>` — bestehendes main-Element um id + tabindex ergänzen (für Fokus-Ziel)

### 2. `web/src/styles/global.css` (PATCH — Fokus-Styles)
- **Globale Fokus-Sichtbarkeit** ergänzen (nach bestehenden focus-visible-Regeln):
  ```css
  :focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
    border-radius: 4px;
  }
  a:focus-visible, button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible, [tabindex]:focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
  }
  ```
  (Nur ergänzen, nichts Bestehendes entfernen — prüfe ob eine globale `:focus-visible`-Regel schon existiert und erweitere sie, statt doppelt zu definieren.)

### 3. Formular-Fehler-Verknüpfung (PATCH)
**`web/src/pages/login.astro`:**
- `#login-error` → `role="alert" aria-live="polite"` ergänzen
- `#email` + `#password` → `aria-describedby="login-error"` NICHT nötig wenn Fehler global — stattdessen: Fehlerbox `role="alert"` reicht. ABER: nach Fehleranzeige Fokus auf Fehlerbox setzen? Nein — einfacher: `aria-live="polite"` + `role="alert"` auf der Box.
- Gleiches für `#reg-hint` (role="status")

**`web/src/pages/fang-erfassen.astro`:**
- `#form-error` + `#submit-error` → `role="alert" aria-live="polite"` ergänzen
- Prüfe die Eingabefelder: die wichtigsten Pflichtfelder (Gewicht, Art) bekommen `aria-describedby` auf ihre Fehlermeldungs-Elemente — WENN es pro-Feld-Fehler gibt. Wenn die Fehler global sind (eine Box), reicht `role="alert"` + `aria-live`.

### 4. `web/src/components/Header.astro` + `web/src/components/Footer.astro` (PATCH — Labels)
- Prüfe: alle Icon-Buttons haben `aria-label` (Burger hat es, Profil-Icon hat es). Ergänze falls ein Icon-Link/Button ohne aria-label ist (z.B. Footer-Social-Icons, Logo-Link → `aria-label="Carp24 Startseite"`).
- Footer: Social-Links (falls vorhanden) → aria-label mit Plattformnamen.

### 5. `web/src/pages/statistik.astro` (PATCH — Chips/ARIA)
- Chips haben `aria-pressed` — **prüfen, ob beim aktiven Zustand auch ein sichtbarer Fokus bleibt** (nicht nur Farbwechsel). Die Klasse `bg-primary text-white` ist ok, aber Fokus-Ring muss sichtbar sein (globaler :focus-visible regelt das).
- **Drill-down-Links** sind `<a>` mit Inhalt — ok.
- Mond-Balken + Druck-Bänder sind `<button>` — haben `aria-pressed` — gut.

### 6. `web/src/pages/dashboard.astro` + `web/src/pages/faenge.astro` + `web/src/pages/404.astro` (PRÜFEN — nur Fixes, wenn nötig)
- Alt-Texte auf dekorativen SVGs: `aria-hidden="true"` wo rein dekorativ (bereits oft da — prüfen)
- Bilder: `alt`-Attribute vorhanden?
- Heading-Reihenfolge: h1 → h2 → h3 durchgängig? (kein h1-Sprung)
- Nur echte Fehler fixen, nichts umbauen.

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen, komplette Seiten neu schreiben (nur gezielte Patches!)
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Keine kompletten Datei-Rewrites** — gezielte, minimale Patches! (Ausnahme: nichts)
- **Bestehende Funktionalität NICHT brechen** (kein Umbau von Layout/Logik — nur a11y-Ergänzungen)
- Kein `import.meta.env` in is:inline neu einführen.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "Zum Inhalt springen" /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro   # MUSS ≥1
grep -c "main-content" /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro          # MUSS ≥1
grep -c ':focus-visible' /mnt/projekte/carp24-fangbuch/web/src/styles/global.css           # MUSS ≥1 (erweitert)
grep -c 'role="alert"' /mnt/projekte/carp24-fangbuch/web/src/pages/login.astro             # MUSS ≥1
grep -c 'role="alert"' /mnt/projekte/carp24-fangbuch/web/src/pages/fang-erfassen.astro     # MUSS ≥1
grep -c 'aria-live="polite"' /mnt/projekte/carp24-fangbuch/web/src/pages/login.astro       # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/                        # MUSS 0
```
Playwright-axe (0 kritische Fehler) + Tastatur-Rundgang macht der Hauptagent NACH deinem Lauf.
