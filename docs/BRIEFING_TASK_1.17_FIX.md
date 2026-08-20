# BRIEFING — Task 1.17-FIX: axe-Funde (carp24)

## 🔴 BAUE SOFORT — gezielte Patches, KEINE kompletten Rewrites. Jede Änderung minimal und abgegrenzt.

## Gefundene axe-Violations (live gemessen, Playwright + axe 4.10.2) — diese exakt fixen:

### 1. 🔴 SERIOUS — color-contrast (2.19:1 statt 3:1) — Logo-Text
**Datei:** `web/src/components/Header.astro`
**Problem:** `<span class="font-headline-md text-headline-md text-primary opacity-50 hidden md:block mr-auto">Carp24</span>` — `opacity-50` auf Primärfarbe ergibt 2.19:1 (zu blass).
**Fix:** `opacity-50` entfernen. Ersetze die Klasse durch `font-headline-md text-headline-md text-primary hidden md:block mr-auto` (oder falls der Blass-Effekt gewollt war: `text-on-surface-variant` verwenden statt opacity — aber **nicht** opacity auf text).

### 2. 🟠 MODERATE — landmark-no-duplicate-main + landmark-main-is-top-level + landmark-unique
**Dateien:** `web/src/layouts/Layout.astro` + alle Seiten, die ein eigenes `<main>` haben.
**Problem:** Layout rendert `<main id="main-content">` (mit Skip-Link-Ziel) UND die Seiten rendern ihr eigenes `<main>` → 2 main-Landmarks.
**Fix (minimal, im Layout):** Das äußere Layout-`main` in ein `<div>` umwandeln, NICHT in ein `<main>`:
- Von: `<main id="main-content" tabindex="-1" class="flex-grow flex flex-col">` 
- Zu: `<div id="main-content" tabindex="-1" class="flex-grow flex flex-col">` ... `</div>` (schließendes Tag mit anpassen!)
- **WICHTIG:** `id="main-content"` + `tabindex="-1"` BEHALTEN (Skip-Link-Ziel bleibt), nur das Element von `main` auf `div` ändern. Das innere `<main>` der Seiten bleibt das EINZIGE main-Landmark.
- Prüfe danach: Jede Seite hat GENAU EIN `<main>` (das aus der Seite selbst).

### 3. 🟠 MODERATE — region (Klaro-Banner außerhalb von Landmarks)
**Datei:** `web/src/components/KlaroBanner.astro`
**Problem:** Der Banner-Inhalt (`<p class="flex-1 ...">Wir nutzen Cookies...</p>` + Buttons) liegt in einem Container, der kein Landmark-Elternteil hat.
**Fix:** Den äußeren Container des Banners in ein `<footer>` mit `role="dialog"`-artiger Semantik NICHT überkomplizieren — minimal: das Banner-Wrapper-Element (das oberste Element in KlaroBanner.astro) erhält `role="region"` + `aria-label="Cookie-Einwilligung"`. Das macht den Inhalt zu einem Landmark.
  - Falls das oberste Element bereits ein `<div>` ist: `class="... fixed bottom-0 ..."` o.ä. → `role="region" aria-label="Cookie-Einwilligung"` ergänzen.
  - **Keine Logik-/Layout-Änderung.**

### 4. 🟠 MODERATE — heading-order (Startseite)
**Datei:** `web/src/pages/index.astro`
**Problem:** Heading-Sprung (h1 → h3 oder ähnlich).
**Fix:** Nur wenn es ein echter Fehler ist: die Zwischen-Überschriften-Ebenen korrigieren (h2 statt h3 o.ä.). Wenn es nur eine inkonsistente Klasse ist (z.B. `<h3>` mit `text-headline-md`), Ebene anpassen. **Nur echte Fehler fixen, kein Redesign.**

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen, komplette Seiten neu schreiben
- KEINE Analyse-Ausflüge. Patche sofort.

## WICHTIG
- **Minimale, gezielte Patches** — bestehende Funktionalität/Layout NICHT verändern außer den beschriebenen Punkten.
- Skip-Link-Funktionalität (`#main-content` + `tabindex="-1"`) muss erhalten bleiben.
- Kein neues `import.meta.env` in is:inline.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "opacity-50" /mnt/projekte/carp24-fangbuch/web/src/components/Header.astro   # MUSS 0 (oder auf non-text Element begrenzt)
grep -c '<main id="main-content"' /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro   # MUSS 0 (div statt main)
grep -c '<div id="main-content"' /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro   # MUSS ≥1
grep -c 'role="region"' /mnt/projekte/carp24-fangbuch/web/src/components/KlaroBanner.astro   # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/   # MUSS 0
```
Der Hauptagent führt danach den kompletten Playwright-axe-Lauf erneut aus — Ziel: 0 critical/serious + keine moderates.
