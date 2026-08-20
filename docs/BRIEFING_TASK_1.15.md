# BRIEFING — Task 1.15: 404 + Offline-Seiten (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen. Dateien werden KOMPLETT ÜBERSCHRIEBEN.

## Ziel
1) Custom 404-Seite im Carp24-Stil (statt Astro-Default), 2) Offline-Fallback über Service Worker (SW), damit die App ohne Netz nutzbar bleibt (passt zu Offline-Sync aus 1.6b).

## Deliverables (in web/)

### 1. `web/src/pages/404.astro` (NEU — KOMPLETT)
- Astro-Route: Datei heißt `404.astro` → automatisch für alle nicht-existierenden Routen (SSR + statisch).
- Layout: `import Layout from "../layouts/Layout.astro"` + `<Layout title="Carp24 – Seite nicht gefunden">` (kein active-Prop)
- Inhalt (Carp24-Editorial-Stil, wie Empty-State aus faenge.astro):
  - Zentriert (`flex flex-col items-center justify-center text-center py-24`):
  - Große Zahl `404` als `text-display-lg text-primary` (oder `text-[120px] font-bold` — designgerecht)
  - Headline: `SEITE NICHT GEFUNDEN` (text-headline-lg text-on-surface)
  - Text: `Die Seite existiert nicht oder wurde verschoben.` (text-body-lg text-on-surface-variant)
  - Karpfen-Silhouette-SVG (dasselbe wie im Empty-State von faenge.astro/dashboard.astro verwenden — gleiche Icon-Grafik)
  - Zwei CTAs:
    - `ZUM FANGBUCH` → `/faenge` (bg-primary text-white rounded-full px-8 py-4 min-h-12)
    - `STARTSEITE` → `/` (border border-primary/40 text-on-surface rounded-full px-8 py-4 min-h-12)
- Kein `<script>` nötig.

### 2. `web/public/sw.js` (NEU — KOMPLETT, Vanilla Service Worker)
- **Kein Workbox, keine Dependency** — Vanilla SW (passt zur Vanilla-IndexedDB aus 1.6b).
- Verhalten:
  - **Install:** Cache `CORE_CACHE = "carp24-core-v1"` öffnen. Da Astro-Build-Hashes unbekannt sind, cache beim `fetch` (runtime caching) — NICHT precache-Listen hartcoden (Hashes ändern sich bei jedem Build!).
  - **Fetch-Handler:**
    - Nur `GET` + `http(s)` behandeln
    - **Navigations-Requests** (`request.mode === "navigate"`): Netzwerk zuerst (cache-first wäre falsch für SSR-Daten) → bei Erfolg Antwort in Cache `PAGE_CACHE = "carp24-pages-v1"` speichern und zurückgeben; **bei Netzwerkfehler**: zuletzt gecachte Seite zurückgeben, wenn vorhanden; sonst **Offline-Fallback** (`/offline` — siehe unten)
    - **Statische Assets** (`/_astro/`, `/assets/`): cache-first mit network-fallback (Runtime-Cache `ASSET_CACHE = "carp24-assets-v1"`)
    - **API-Requests** (`:8055` / `/rest/` / `/auth/`): NIE cachen, direkt durchreichen (Daten aktuell halten)
  - **Activate:** alte Caches (`carp24-core-v*`, `carp24-pages-v*`, `carp24-assets-v*` mit anderer Version) löschen → `clients.claim()`
- WICHTIG: SW nur im Produktions-Deploy sinnvoll (http://100.93.250.103:8094). Registrierung siehe unten.

### 3. `web/src/pages/offline.astro` (NEU — KOMPLETT)
- Statische Seite für den Offline-Fallback (wird vom SW bei Navigationsfehler geliefert).
- Layout: `import Layout from "../layouts/Layout.astro"` + `<Layout title="Carp24 – Offline" bare>` — **Achtung:** Wenn das Layout Header/Footer mitlädt, braucht es deren Assets (die evtl. auch nicht gecacht sind). Verwende `bare`-Prop (Layout unterstützt `bare` — siehe Layout.astro, `{!bare && <Header/>}`), damit die Seite OHNE Header/Footer auskommt → maximale Offline-Chance.
- Inhalt (zentriert wie 404):
  - Icon: WLAN-off-Symbol (SVG, stroke=currentColor, z.B. `<path d="M1 1l22 22M16.72 11.06A10.94 10.94 0 0 1 19 12.55M5 12.55a10.94 10.94 0 0 1 5.17-2.39M10.71 5.05A16 16 0 0 1 22.58 9M1.42 9a15.91 15.91 0 0 1 4.7-2.88M8.53 16.11a6 6 0 0 1 6.95 0"/>` + X-Linie) — passende lucide-artige Linien
  - Headline: `OFFLINE` (text-headline-lg text-on-surface)
  - Text: `Keine Verbindung zum Netzwerk. Deine Fänge werden lokal gespeichert und später synchronisiert.` (text-body-lg text-on-surface-variant)
  - Hinweis auf Offline-Queue: `Offline erfasste Fänge warten in der Warteschlange.` (text-body-md text-on-surface-variant)
  - Button: `ERNEUT VERSUCHEN` (border border-primary/40 text-on-surface rounded-full px-8 py-4 min-h-12) mit `onclick="location.reload()"` (is:inline erlaubt)
  - Link: `ZUM FANGBUCH` → `/faenge` falls erreichbar

### 4. `web/src/layouts/Layout.astro` (PATCH — SW-Registrierung)
- Im bestehenden gebündelten `<script>`-Block (der error-tracker-Init enthält) ergänzen:
  ```js
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  }
  ```
- Nur im Browser (Client-Script), kein SSR-Aufruf.

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/layouts/Layout.astro, web/src/pages/faenge.astro (für die Silhouette-SVG-Referenz), web/src/pages/dashboard.astro
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede neue Datei MUSS vollständig geschrieben werden. Keine Diffs, keine Snippets.**
- **Keine Precache-Listen mit Build-Hashes** (die ändern sich!) — nur Runtime-Caching.
- **API nie cachen** — nur Seiten/Assets.
- Offline-Seite mit `bare`-Layout (ohne Header/Footer) — sonst braucht sie Netz.
- SW-Registrierung im gebündelten Script (NICHT is:inline für den import-Teil — aber die Registrierung selbst ist plain JS und kann im bestehenden gebündelten Script stehen).

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "404" /mnt/projekte/carp24-fangbuch/web/src/pages/404.astro   # MUSS ≥1
grep -c "SEITE NICHT GEFUNDEN" /mnt/projekte/carp24-fangbuch/web/src/pages/404.astro   # MUSS ≥1
grep -c "serviceWorker" /mnt/projekte/carp24-fangbuch/web/public/sw.js   # MUSS ≥1 (bzw. self.addEventListener)
grep -c "offline" /mnt/projekte/carp24-fangbuch/web/src/pages/offline.astro   # MUSS ≥1
grep -c 'serviceWorker.register' /mnt/projekte/carp24-fangbuch/web/src/layouts/Layout.astro   # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/ /mnt/projekte/carp24-fangbuch/web/public/   # MUSS 0
```
Server-Start + 404-/Offline-Test macht der Hauptagent NACH deinem Lauf.
