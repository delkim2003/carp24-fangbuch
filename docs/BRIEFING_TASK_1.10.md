# BRIEFING — Task 1.10: Basis-Dashboard (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen. Die Datei wird KOMPLETT ÜBERSCHRIEBEN.

## Ziel
`web/src/pages/dashboard.astro` auf **echte Supabase-Daten** umbauen (KEINE Beispieldaten!): Stat-Karten, Monats-Chart, Gewichts-Verlauf, Top-Fänge. Der aktuelle Mock (hartkodierte `const stats`, `catches`-Array ab Zeile 164, komplettes „Statistik-Studio"-Mock mit Client-Chart-Renderer) wird ENTFERNT — das Statistik-Studio gehört zu Task 1.10b (später, NICHT hier bauen).

## Backend-Kontrakt (VERBINDLICH — live)
### catches-Tabelle (RLS: User sieht NUR eigene Fänge)
Felder: `id (uuid)`, `client_uuid`, `user_id`, `catch_ts (timestamptz)`, `species (enum: SPIEGEL|LEDER|SCHUPPEN|AMUR|ANDERE)`, `weight_kg (numeric)`, `length_cm (numeric?)`, `bait (text?)`, `method (text?)`, `notes (text?)`, `photos (text[]?)`, `lat/lng (numeric?)`, `water_name (text?)`, `water_id (uuid?)`, `draft (bool)`, `weather (jsonb?)`, `weather_auto (bool)`, `deleted_at (timestamptz?)`

### Abfrage (identisch mit faenge.astro — SSR im Frontmatter!)
```ts
import { supabase } from "../lib/supabase-client";
const { data: { session } } = await supabase.auth.getSession();
let catches: any[] = [];
if (session) {
  const { data } = await supabase.from("catches").select("*").eq("deleted_at", null).order("catch_ts", { ascending: false });
  catches = data ?? [];
}
```
- KEINE onMount/Client-Fetch nötig — SSR macht das serverseitig, Charts als STATISCHES SVG im Template rendern (kein is:inline-JS für Charts nötig!)
- Numeric-Felder kommen als STRING von PostgREST → IMMER `Number(...)` vor Berechnungen
- `draft` NICHT filtern (publizierte Fänge sind draft=false; die Query wie oben reicht — RLS + deleted_at)

## Design-Referenz (VERBINDLICH)
`design/screens/dashboard.html` (abgenommenes Carp24-Editorial-Design). Die gebauten Seiten verwenden Tailwind-Klassen aus global.css, NICHT die design-eigenen Klassen (`khaki-card`, `olive-hairline` → ersetzt durch `bg-surface-container-high border border-primary/40 rounded-2xl` usw. — Muster aus faenge.astro/dashboard-Mock übernehmen).

Aufbau:
1. Kopf: `Petri Heil, Angler` (text-display-lg text-primary) + Untertitel `Dein Überblick für die Saison {aktuelles Jahr}.` + Button `NEUER FANG EINTRAGEN` (Link /fang-erfassen, Stil wie im Mock)
2. 4 Stat-Karten (grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-gutter), Karte: `bg-surface-container-high border border-primary/40 rounded-2xl p-lg flex flex-col justify-between min-h-32`, Label `font-nav-item text-nav-item text-primary-container uppercase tracking-widest`, Wert `text-display-lg text-primary`:
   - `GESAMT FÄNGE` → Anzahl aller Fänge
   - `SCHWERSTER FANG` → max weight_kg, Format `"21,4"` + `<span class="text-headline-md"> KG</span>`
   - `FÄNGE DIESES JAHR` → Anzahl Fänge mit catch_ts im aktuellen Jahr
   - `AKTIVE GEWÄSSER` → Anzahl DISTINCT water_name (nicht-null)
3. Grid `grid grid-cols-1 lg:grid-cols-3 gap-gutter`:
   - **Links (lg:col-span-2):** Karte `bg-surface-container-high border border-primary/40 rounded-2xl p-lg` mit H3 `FÄNGE PRO MONAT` (font-nav-item text-nav-item text-primary-container uppercase tracking-widest) → **Balken-Chart als statisches SVG**: ein Balken pro Monat (chronologisch, Monatsnamen DE: Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez), Balkenhöhe proportional zur Anzahl (`height = count/maxCount * 100%`), Balken `fill="var(--color-primary-container)"`, Y-Wert über jedem Balken (font-label-sm), X-Labels unter den Balken. Nur Monate mit Daten anzeigen. Wenn maxCount=0 → leerer Zustand.
   - **Rechts (lg:col-span-1):** Karte mit H3 `TOP FÄNGE` → **Top 5 Fänge nach weight_kg (absteigend)**, Zeilen im Design-Stil: `flex items-center gap-4 p-4 border-b` (letzte ohne border), links Gewicht prominent `font-mono text-display-sm text-primary font-bold` (Format `"18,4 KG"` DE-Komma), darunter `font-nav-item text-label-sm text-on-surface-variant uppercase` = Fischart-DE + ` • ` + Gewässer • Datum-Kurz (`font-body-md text-label-sm text-[#7B9496]`, Format `"Waldsee • 12. Okt"`)
4. **GEWICHTS-VERLAUF** (volle Breite, gleiche Karten-Klasse): H3 `GEWICHTS-VERLAUF` → **Linien-Chart als statisches SVG**: ein Punkt pro Fang, chronologisch nach catch_ts aufsteigend, Y = weight_kg (kg). Polyline `fill="none" stroke="var(--color-primary)" stroke-width="2.5"`, Punkte als `<circle r="3.5" fill="var(--color-primary)">`, dezente Grid-Linien (stroke var(--color-outline) opacity 0.25), Y-Achsen-Labels (kg), X-Labels: Datum-Kurz (z.B. `12. Okt`) nur bei jedem N-ten Punkt (bei ≤10 Fängen jeden, sonst ~5-6 Labels gleichmäßig). min-h ~300px.

## Deliverable (EINZIGE Datei)
### web/src/pages/dashboard.astro (KOMPLETT ÜBERSCHREIBEN — kein Mock!)
- Layout: `import Layout from "../layouts/Layout.astro";` + `<Layout title="Carp24 – Dashboard" active="statistik">`
- Auth-Guard wie faenge.astro: keine Session → Login-CTA (Text `Melde dich an, um deine Statistik zu sehen.` + `ANMELDEN`-Button → /login)
- Keine Session-Daten → KEINE Charts (Guard davor)
- Empty-State: wenn 0 Fänge → `NOCH KEINE FÄNGE` + Karpfen-Silhouette + `ERSTEN FANG EINTRAGEN`-Button (Muster aus faenge.astro Empty-State, Zeilen 52-59)
- Daten-AGGREGATION im Frontmatter (serverseitig, TS):
  - total, heaviest (Fang-Objekt), thisYear, activeWaters (Set)
  - monthly: Map Monat-Index → count, chronologisch sortiert, nur Monate mit Daten
  - top5: sort by weight_kg desc, slice(0,5)
  - trend: sort by catch_ts asc → SVG-Punkte
- Species-Mapping DE: `SPIEGEL→Spiegelkarpfen, LEDER→Lederkarpfen, SCHUPPEN→Schuppenkarpfen, AMUR→Amurkarpfen, ANDERE→Andere`
- DE-Formatierung: Gewicht `weight_kg.toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + " KG"`; Datum kurz: `new Date(catch_ts).toLocaleDateString("de-DE", { day: "2-digit", month: "short" })` → `"12. Okt."` (Punkt entfernen → `"12. Okt"`)
- `min-h-12`/`min-h-11` Buttons/Selects beibehalten (Accessibility), `aria-hidden="true"` auf dekorativen SVGs
- KEIN `<script>`-Block nötig (alles SSR). Falls doch JS nötig: `is:inline` + Env NIE direkt — body[data-supabase-*] (Layout macht das schon).

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/dashboard.html
- VERBOTEN: /etc, andere Projekte, supabase/migrations/, infra/, /tmp, drush, Shell-Schleifen, Bash-Subshells, git-Operationen, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- **KEINE Beispieldaten hartcoden!** Das `catches`-Array + `const stats`-Mock MÜSSEN weg. Das Statistik-Studio-Mock (Selects, Filter-Buttons, data-filter-group, studio-chart, der ganze Chart-Renderer-JS) MUSS KOMPLETT ENTFERNT werden — gehört zu 1.10b.
- Daten kommen NUR aus Supabase via `supabase.from("catches")`.
- Charts als statisches SSR-SVG (kein Client-JS), damit Build+SSR sauber bleiben.
- Zahlformat DE (Komma), wie oben definiert.

## VERIFIKATION (NUR Statik — keine Server)
```bash
# WICHTIG: Der Code nutzt DOPPELTE Quotes im from-Aufruf: supabase.from("catches") — Greps entsprechend!
grep -c 'from("catches")' /mnt/projekte/carp24-fangbuch/web/src/pages/dashboard.astro          # MUSS ≥1
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts           # MUSS ≥1
grep -c "studio-chart\|data-filter-group\|statistik-studio" /mnt/projekte/carp24-fangbuch/web/src/pages/dashboard.astro  # MUSS 0 sein (Mock-Studio raus — gehört zu 1.10b!)
grep -c "Silbersee\|Linch Hill\|Donau Altarm\|Waldweiher\|catchRelease" /mnt/projekte/carp24-fangbuch/web/src/pages/dashboard.astro # MUSS 0 sein (kein Mock!)
# GESAMT FÄNGE ist der ECHTE Label (bleibt!) — NICHT als Mock-Marker prüfen.
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
