# BRIEFING — Task 1.10b: Statistik-Studio-Frontend (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen. Dateien werden KOMPLETT ÜBERSCHRIEBEN.

## Ziel
Das **Statistik-Studio** (Philipps Herzstück) als neue Route `/statistik` bauen: Bedingungs-UI (Chips, UND-Logik, beliebig kombinierbar) auf der fertigen 1.10a-API. **ECHTE Daten aus den RPC-Funktionen — KEINE Beispieldaten, KEINE hartcodierten Gewässer/Arten/Köder!** Das alte Statistik-Studio-Mock in `dashboard.astro` wurde in Task 1.10 bereits entfernt.

## Backend-API-Kontrakt (VERBINDLICH — live, Migration 0009)
Alle 3 Funktionen sind `SECURITY DEFINER`, erfordern Auth (`auth.uid()`), EXECUTE nur für authenticated. Aufruf via `supabase.rpc("<fn>", { p_filters: {...} })`. **WICHTIG:** Der Parameter heißt `p_filters` und MUSS als Key im Argument-Objekt stehen.

### Filter-Keys (jede Bedingung einzeln ODER beliebig kombinierbar, UND-Logik):
| Key | Werte | Bedeutung |
|-----|-------|-----------|
| `mond` | exakt `neumond` / `zunehmend` / `vollmond` / `abnehmend` | moon_text aus weather jsonb |
| `druck_bucket` | `<1005` / `1005-1015` / `>= 1015` | Luftdruck-Bucket (Achtung: Output nutzt `>= 1015`!) |
| `wind_bucket` | `<5` / `5-10` / `10-20` / `20+` | Wind-Bucket |
| `wetter` | Text (z.B. `sonnig`) | ILIKE Teilstring auf weather_text |
| `gewaesser` | Text | ILIKE Teilstring auf water_name (auch privat!) |
| `art` | enum-Wert ODER Text | species::text exakt ODER species_custom ILIKE |
| `koeder` | Text (z.B. `Boilie`) | ILIKE Teilstring auf bait |
| `monat` | 1-12 (Zahl) | Monat aus catch_ts |
| `uhrzeit_bucket` | `0-6` / `6-12` / `12-18` / `18-24` | Stunde aus catch_ts |

NICHT anbieten (nicht in API): wassertemperatur, lufttemperatur, jahr, zeitraum (optional später).

### Funktion 1: `stats_conditions(p_filters jsonb DEFAULT '{}')` → jsonb
```jsonc
{
  "total": { "fangzahl": int, "avg_gewicht": numeric, "max_gewicht": numeric, "sum_gewicht": numeric },
  "buckets": {
    "mond":      { "vollmond": { "fangzahl": int, "avg_gewicht": numeric }, "neumond": {...}, ... },
    "druck":     { ">= 1015": {...}, "1005-1015": {...}, "<1005": {...} },
    "wind":      { "5-10": {...}, ... },
    "wetter":    { "sonnig": {...}, "bewölkt": {...}, ... },
    "gewaesser": { "Wörthersee": {...}, "Vereinsteich Musterhausen": {...}, ... },
    "uhrzeit":   { "6-12": {...}, ... },
    "monat":     { "Mär": {...}, "Apr": {...}, ... },   // to_char 'TMMon' — DE Monatsnamen!
    "art":       { "SPIEGEL": {...}, "ANDERE": {...}, ... },  // species enum ODER custom
    "koeder":    { "Boilie": {...}, ... }
  }
}
```

### Funktion 2: `stats_drilldown(p_filters jsonb DEFAULT '{}')` → TABLE
Spalten: `id (uuid)`, `catch_ts (timestamptz)`, `water_name (text)`, `species (text)` (custom-fallback), `weight_kg (numeric)`, `length_cm (numeric)`, `bait (text)`, `weather (jsonb)` — sortiert catch_ts DESC.

### Funktion 3: `stats_beste_kombis(p_filters jsonb DEFAULT '{}', p_limit int DEFAULT 5)` → TABLE
Spalten: `kombi (text)` (Format `"mond=vollmond + druck=>= 1015"`), `fangzahl (int)`, `avg_gewicht (numeric)`. Nur Kombis mit fangzahl ≥ 2.

## Design-Referenz (VERBINDLICH — Layout, nicht Bucket-Werte!)
`design/screens/statistik-studio.html` (abgenommenes Stitch-Design, Light „Carp24 Editorial").
Gebaute Seiten nutzen Tailwind-Klassen aus global.css (var(--color-*)), NICHT die design-eigenen `khaki-card`/`hairline-b` (→ `bg-surface-container-high border border-primary/40 rounded-2xl` etc. — Muster aus dashboard.astro/faenge.astro).

**Layout (aus dem Design übernehmen):**
1. Header: `Statistik-Studio` (text-display-lg text-primary) + Untertitel `Kombiniere Bedingungen frei — finde deine besten Fang-Momente.`
2. Grid `lg:grid-cols-12`: **Bedingungen-Karte (lg:col-span-8)** + **Metrik-Karten & Korrelation (lg:col-span-4)**
3. **Bedingungen-Karte:** Titel `Bedingungen` + Button `ZURÜCKSETZEN` (rechts, oberhalb). Darunter je Dimension eine Zeile: Label (MOND, LUFTDRUCK, WIND, WETTER, GEWÄSSER, ART, KÖDER, MONAT, UHRZEIT) + Chip-Reihe (rounded-full, border-primary/40; aktiv = `bg-primary text-white`, inaktiv = `text-on-surface-variant hover:bg-primary hover:text-white`). **Chips dynamisch aus `stats_conditions({}).buckets.<dim>` generieren** — Werte + Fangzahl-Anzeige (z.B. `VOLLMOND (5)`)! KEINE hartcodierten Werte.
4. **Mondphasen-Visualisierung (khaki-card):** 4 vertikale Balken (NEUMOND, ZUNEHMEND, VOLLMOND, ABNEHMEND), Höhe proportional zu fangzahl/maxFangzahl, `fill="var(--color-primary)"` + opacity-Varianten, Label `NEU (6)` unter jedem Balken. Klickbar → setzt mond-Filter.
5. **Luftdruck-Visualisierung:** horizontale Bänder für die API-Buckets `<1005` / `1005-1015` / `>= 1015` (NICHT die Design-Labels 1010!), Breite proportional, Label links. Klickbar → setzt druck_bucket-Filter.
6. **Metrik-Karten (rechts):** `GESAMT FÄNGE` (fangzahl) + `Ø GEWICHT` (avg_gewicht, DE-Komma + KG) + Karte `BESTE KOMBINATION` (Top-1 aus stats_beste_kombis, als Pill `bg-primary text-white rounded-full`).
7. **Beste Kombinationen-Liste (rechts):** stats_beste_kombis Ergebnis: Zeile `kombi` (font-label-sm font-bold) + `N Fänge (Ø X kg)` (text-on-surface-variant) + Fortschritts-Balken (w-16 h-2 bg-primary/20, Füllung proportional zum Ø-Gewicht relativ zum Max).
8. **Drill-down-Liste (volle Breite unten):** `Fänge mit diesen Bedingungen` (font-headline-md) → stats_drilldown Ergebnis als Karten-Zeilen: Gewicht prominent `font-mono text-primary text-lg` (DE-Komma + KG), `species (DE-Mapping) • water_name • Datum` (Format `12.05.2024`), Wetter-Tags als Pill `bg-[#7B9496]/10 text-[#7B9496] font-label-sm text-[10px] px-2 py-1 rounded-full` (MOND-Text, Wetter-Text, Luftdruck aus weather jsonb). Link zu `/faenge/{id}`.
9. **Aktive Bedingungen als zusammengefasste Zeile** oberhalb der Drill-down-Liste (z.B. `VOLLMOND + >= 1015 hPa + Boilie`), mit `×`-Entfernen.

## Deliverables (in web/)
### 1. `web/src/pages/statistik.astro` (NEU — KOMPLETT)
- Layout: `import Layout from "../layouts/Layout.astro"` + `<Layout title="Carp24 – Statistik" active="statistik">`
- **Auth-Guard im Frontmatter** (wie faenge.astro): keine Session → Login-CTA (`Melde dich an, um deine Statistik zu sehen.` + ANMELDEN → /login)
- **Initiale Daten im Frontmatter (SSR)** via `import { supabase } from "../lib/supabase-client"`: `stats_conditions({})`, `stats_drilldown({})`, `stats_beste_kombis({}, 5)` → erste Render-Ausgabe serverseitig (kein leeres Blinken)
- **Interaktivität als gebündeltes Client-`<script>`** (OHNE `is:inline` — damit `import` funktioniert und Env korrekt ersetzt wird!):
  ```html
  <script>
    import { supabase } from "../lib/supabase-client";
    // ... Client-Logik
  </script>
  ```
  Client-Logik: `state = { mond: null, druck_bucket: null, wind_bucket: null, wetter: null, gewaesser: null, art: null, koeder: null, monat: null, uhrzeit_bucket: null }` → `buildFilters()` (nur gesetzte Werte) → bei jedem Chip-Klick/ZURÜCKSETZEN: `stats_conditions`, `stats_drilldown`, `stats_beste_kombis` parallel abrufen → Charts, Chips, Metriken, Korrelation, Drill-down neu rendern (innerHTML). Bucket-Klick (Mondbalken/Druckband) setzt Filter + re-rendert. Fehlerzustand: RPC-Fehler sichtbar machen.
- Species-Mapping DE: `SPIEGEL→Spiegelkarpfen, LEDER→Lederkarpfen, SCHUPPEN→Schuppenkarpfen, AMUR→Amurkarpfen, ANDERE→Andere` (custom-fallback: species kommt schon als Text zurück)
- DE-Formatierung: Gewicht `Number(w).toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + " KG"`; Datum `new Date(ts).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" })` → `12.05.2024`
- `min-h-11`/`min-h-12` Buttons, `aria-hidden="true"` auf dekorativen SVGs, `aria-pressed` auf Chips

### 2. `web/src/components/Header.astro` (PATCH — Navigation)
- `navItems`: `{ key: "statistik", label: "Statistik", href: "/statistik" }` (statt /dashboard)

### 3. `web/src/pages/dashboard.astro` (PATCH — Link zum Studio)
- Im Kopfbereich (neben `NEUER FANG EINTRAGEN`) einen zweiten Button/Link `ZUM STATISTIK-STUDIO` → `/statistik` (Stil: `border border-primary/40 text-primary rounded-full px-6 py-3 font-nav-item text-nav-item uppercase tracking-widest hover:bg-primary hover:text-white transition-colors min-h-12`)

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/statistik-studio.html
- VERBOTEN: /etc, andere Projekte, supabase/migrations/, infra/, /tmp, drush, Shell-Schleifen, Bash-Subshells, git-Operationen, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.** (Ausnahme: Header/dashboard sind gezielte kleine Patches — dürfen als gezielte Edits erfolgen.)
- **KEINE Beispieldaten hartcoden!** Chips/Listen kommen NUR aus den RPC-Buckets. Keine `Silbersee`, `Boilie`, `Waldsee` als String im Code!
- **Backend-Bucket-Grenzen gelten:** Luftdruck `<1005 / 1005-1015 / >= 1015` — NICHT die Design-Labels `<1010`!
- **`import.meta.env` NIE in `is:inline`-Scripts** — deshalb gebündeltes Script (import aus lib/supabase-client) verwenden.
- Numeric-Felder von PostgREST kommen als STRING → IMMER `Number(...)`.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c 'rpc("stats_conditions"\|rpc("stats_drilldown"\|rpc("stats_beste_kombis"' /mnt/projekte/carp24-fangbuch/web/src/pages/statistik.astro   # MUSS ≥3 (alle 3 Funktionen)
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts   # MUSS ≥1
grep -c 'href: "/statistik"' /mnt/projekte/carp24-fangbuch/web/src/components/Header.astro   # MUSS ≥1
grep -c "Silbersee\|Waldsee\|Boilie\|Linch Hill\|Donau Altarm\|Waldweiher" /mnt/projekte/carp24-fangbuch/web/src/pages/statistik.astro   # MUSS 0 (kein Mock!)
grep -c "is:inline" /mnt/projekte/carp24-fangbuch/web/src/pages/statistik.astro   # DARF NICHT fürs Haupt-Script verwendet werden (gebündeltes <script>)
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/   # MUSS 0 (Platzhalter-Falle!)
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
