# Task 1.3 — carp24 Astro-Grundgerüst + 8 Screens (Mobile-First)

## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: /mnt/projekte/carp24-fangbuch/web/ (src/, ref/, public/, astro.config.mjs, package.json)
- VERBOTEN: /etc lesen, andere Projekte, /tmp, Shell-Schleifen, Bash-Subshells, git-Operationen, drush, npm install
- KEINE Analyse-Ausflüge. Baue sofort.

## Projekt
- Astro 7 (SSG, output static), Tailwind CSS v4 (@tailwindcss/vite in astro.config.mjs, `@import "tailwindcss"` in src/styles/global.css)
- Design-Tokens KOMPLETT in src/styles/global.css (@theme + Typo-Klassen) — NICHT anfassen, NICHT erweitern
- Fonts lokal in public/fonts/ (Source Serif 4, Source Sans 3, JetBrains Mono) — KEINE Google-Fonts-URLs, kein externer Font-Import
- Echtes Logo: public/assets/logo_carp24_badge.png + .svg — IMMER verwenden, NIE Platzhalter erfinden
- Sprache: Deutsch (de)

## Referenzen (PFLICHT-1:1-Quellen)
Die Stitch-Designs liegen als HTML unter ref/ — baue die Screens 1:1 nach diesen Klassen/Strukturen/Farben. NIE eigene CSS erfinden, NIE Stitch-Tailwind-CDN-Konfiguration übernehmen (Tokens sind schon in global.css).
- ref/onboarding.html → Startseite (index)
- ref/login.html → /login
- ref/catch-form.html → /fang-erfassen
- ref/catch-list.html → /faenge
- ref/catch-detail.html → /faenge/[id]
- ref/dashboard.html → /dashboard
- ref/profile.html → /profil
- ref/paywall.html → /premium

## WICHTIG: Mobile-First-Umbau (Kundenvorgabe!)
Die Referenzen sind DESKTOP-Designs. Baue sie MOBILE-FIRST responsive um:
- Mobile (Basis, <768px): EIN-SPALTIG, kompakt, Touch-Targets ≥44px, Burger-Menü
- Desktop (≥768px, md:): Layout wie in der Referenz (mehrspaltig, Desktop-Nav sichtbar)
- Header: Logo-Badge links, Desktop-Nav (md:flex) + Mobile-Burger (md:hidden) mit offen/zu-Toggle via kleinem Inline-Script
- NIE `hidden md:flex` für die Mobile-Nav — in Tailwind v4: Mobile-Nav `max-md:flex` ODER klassisch `md:hidden` für Burger

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei.astro << 'ENDOFFILE'
...Code...
ENDOFFILE
Das ist der EINZIGE Weg der funktioniert. JEDER Write-Aufruf schlägt fehl.

## Zu bauen (REIHENFOLGE)

### 1. src/components/Header.astro
- Sticky Header, bg-surface/90 backdrop-blur, border-b outline/20
- Links: Logo-Badge (h-10 w-auto object-contain) + Wortmarke "Carp24" (font-headline-md text-primary)
- Desktop-Nav (md:flex): Fangbuch, Statistik, Preis — text-nav-item uppercase tracking-widest, active border-b primary
- Rechts: Sign In Link (text-nav-item)
- Mobile: Burger-Button (md:hidden, 44px Touch), Mobile-Panel mit Links

### 2. src/components/Footer.astro
- Fußzeile: "© 2026 Carp24. All rights reserved." + Links (Impressum, Datenschutz) als Platzhalter (#)

### 3. src/components/KlaroBanner.astro
- Minimaler DSGVO-Consent-Banner (Klaro-Stil): Text "Wir nutzen Cookies..." + Buttons "Nur notwendige" / "Alle akzeptieren"
- KEIN Cookie setzen vor Consent, Banner fixed bottom, z-50
- Einfaches Inline-Script: Button-Klick → Banner ausblenden (localStorage marker "klaro-consent")

### 4. src/pages/index.astro (Onboarding)
1:1 nach ref/onboarding.html — Header, Hero (Slogan "PASSION. FISHING. COMMUNITY."), 3 Beispiel-Fänge, Freemium-Hinweis (50 Fänge gratis), CTA "LOS GEHT'S" → /login. Mobile-First umsetzen.

### 5. src/pages/login.astro
1:1 nach ref/login.html — Logo, E-Mail+Passwort, "Anmelden"/"Registrieren" Buttons.

### 6. src/pages/fang-erfassen.astro
1:1 nach ref/catch-form.html — Formular: Datum, Gewässer, Art, Gewicht kg, Länge cm, Wassertemperatur, Lufttemperatur, Foto-Upload (Dashed-Border), Notiz, Catch-and-Release-Toggle, SPEICHERN-Button. Formular-Buttons: type="button" (noch kein Backend).

### 7. src/pages/faenge.astro (Liste)
1:1 nach ref/catch-list.html — Suche + Filter (Art, Gewässer, Sortierung), Fang-Zeilen mit Thumbnail, "Fang hinzufügen" CTA.

### 8. src/pages/faenge/[id].astro (Detail)
1:1 nach ref/catch-detail.html — Hero-Foto, Art als Headline, Metadaten (Gewicht, Länge, Datum, Gewässer, Wassertemperatur, Lufttemperatur), Catch-and-Release-Badge, Notizen, Edit/Delete/Share Buttons, Seitenleiste mit kleinen Stats. Astro: `export function getStaticPaths()` mit 3 Beispiel-Fängen.

### 9. src/pages/dashboard.astro
1:1 nach ref/dashboard.html — 4 Stat-Cards (Gesamt-Fänge, Größter Karpfen, Fänge dieses Jahr, Aktive Gewässer), Balken-Chart Fänge pro Monat (CSS-basiert, keine Chart-Lib), Recent-Catches-Liste, "Fang hinzufügen" CTA.

### 10. src/pages/profil.astro
1:1 nach ref/profile.html — Avatar, Name, Mitglied seit, Stats, Einstellungen (Einheiten kg/lbs, Sprache, Benachrichtigungen), Subscription-Status, Logout.

### 11. src/pages/premium.astro (Paywall)
1:1 nach ref/paywall.html — "UPGRADE TO PREMIUM", Free vs. Premium Pricing-Cards (Premium hervorgehoben), Monatlich/Jährlich Toggle, Upgrade-Button, Hinweis 50-Fänge-Grenze.

## Konsistenz (Pflicht)
- Header + Footer auf ALLEN Seiten identisch
- Alle Farben AUSSCHLIESSLICH aus global.css-Tokens (bg-surface, text-on-surface, bg-primary, text-primary, border-outline/20, bg-surface-container, etc.) — NIE rohe Hex-Werte in Komponenten
- Bilder: Stitch-Platzhalter-Fotos in den Referenzen sind remote (lh3.googleusercontent.com) — ersetze sie durch lokale SVG-Platzhalter im carp24-Stil (dezente Fisch-Silhouette auf Khaki #CCCA9B) unter src/assets/ ODER lass die img-Tags mit grauem Platzhalter-Background + aria-label. KEINE Unsplash-URLs. KEINE externen Bilder.
- Icons: inline SVG (stroke="currentColor", aria-hidden="true"), kein Icon-CDN

## Definition of Done
- Alle 11 Dateien geschrieben (3 Komponenten + Layout.astro aktualisiert + 8 Pages)
- Layout.astro: importiert global.css + Header + Footer + KlaroBanner
- KEIN externer Font/CDN/Icon-Link in den Dateien
- KEINE raw Hex-Farben außerhalb global.css
- Danach NUR: `cd /mnt/projekte/carp24-fangbuch/web && npm run build` ausführen und melden ob der Build fehlerfrei läuft. KEINE weiteren Schritte.
