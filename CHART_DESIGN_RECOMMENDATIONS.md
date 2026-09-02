# Chart-Design: Carp24 Statistik-Studio

> Analyse der aktuellen statistik.astro + Stitch-Design-Vergleich
> Datum: 03.09.2026

---

## 1. Gewichtsverlauf (uPlot Line) — Bestehende Config, nachschärfen

**Aktueller Zustand:** uPlot Linie mit 2 Serien (Ø Gewicht + Max Gewicht), Monatsachse.
**Problemzone:** Fehlende Tooltips, kein Cursor/Crosshair, keine responsive resize, keine Dark-Mode-Propagation.

### Ziel-Config

```js
const opts = {
  width: el.clientWidth,
  height: 280,
  cursor: {
    show: true,
    lock: false,
    drag: { x: true, y: false },
  },
  select: { show: false, top: 0, left: 0, width: 0, height: 0 },
  legend: { show: true },
  tooltip: {
    mount: tooltipEl,
    body: (idx, series, data) => {
      const d = new Date(data[0][idx] * 1000);
      const dateStr = d.toLocaleDateString('de-DE', { month: 'long', year: 'numeric' });
      return `<strong>${dateStr}</strong><br>
        Ø ${data[1][idx].toFixed(1)} kg<br>
        Max ${data[2][idx].toFixed(1)} kg`;
    },
  },
  axes: [
    {
      stroke: CSS.onSurfaceVar,
      grid: { stroke: CSS.outline, width: 0.5 },
      font: '12px "Source Sans 3", sans-serif',
      values: (_u, vals) => vals.map(v => {
        const d = new Date(v * 1000);
        return d.toLocaleDateString('de-DE', { month: 'short', year: '2-digit' });
      }),
    },
    {
      stroke: CSS.onSurfaceVar,
      grid: { stroke: CSS.outline, width: 0.5 },
      font: '12px "Source Sans 3", sans-serif',
    },
  ],
  series: [
    {},
    {
      label: 'Ø Gewicht',
      stroke: '#6c7a57',
      fill: '#6c7a5718',
      width: 2,
      points: { show: true, size: 4, stroke: '#6c7a57', fill: '#fff', width: 2 },
    },
    {
      label: 'Max Gewicht',
      stroke: '#bdcca4',
      width: 2,
      dash: [6, 3],
      points: { show: true, size: 3, stroke: '#bdcca4', fill: '#fff', width: 1.5 },
    },
  ],
};
```

### Farben (Light ↔ Dark via CSS-Variablen)

| Token | Light | Dark |
|-------|-------|------|
| Avg-Linie | `--color-primary-container` (#6c7a57) | `--color-primary-fixed-dim` (#a4b68c) |
| Avg-Fill | gleiche Farbe + 18 | gleiche Farbe + 18 |
| Max-Linie | `--color-primary-fixed-dim` (#bdcca4) | `--color-primary` (#546140) |
| Max-Dash | gleiche | gleiche |
| Grid | `--color-outline-variant` | `--color-outline-variant` (dark) |
| Text | `--color-on-surface-variant` | `--color-on-surface-variant` (dark) |

### Responsive

```js
// ResizeObserver im script
const ro = new ResizeObserver(() => {
  if (verlaufUplot) verlauUplot.setSize({ width: el.clientWidth, height: 280 });
});
ro.observe(el);
```

---

## 2. Fänge nach Gewässer — uPlot ENTFERNEN, CSS-Horizontalbars

**Aktueller Fehler:** uPlot mit `height: data.length * 36` — skaliert katastrophal bei vielen Gewässern.

**Stitch-Design zeigt:** CSS horizontale Balken (kein uPlot). Gleiches Pattern wie die Bedingungen-Matrix.

### Alternative: HTML-Horizontalbars + Show More

```html
<div id="gewaesserChart" class="gewaesser-list">
  <!-- Dynamisch generiert via renderGewaesser() -->
  <!-- Jedes Item: Label | Bar-Track | Count -->
</div>
```

```css
.gewaesser-list { display: flex; flex-direction: column; gap: 0.5rem; }
.gewaesser-row { display: flex; align-items: center; gap: 0.75rem; }
.gewaesser-label { width: 160px; text-align: right; white-space: nowrap;
  overflow: hidden; text-overflow: ellipsis; font-size: 0.85rem;
  color: var(--color-on-surface-variant); }
.gewaesser-bar-track { flex: 1; height: 24px; background: var(--color-surface-container);
  border-radius: 12px; overflow: hidden; }
.gewaesser-bar-fill { height: 100%; border-radius: 12px;
  background: var(--color-primary-container); transition: width 0.4s ease; }
.gewaesser-count { width: 40px; font-weight: 600; font-size: 0.85rem;
  color: var(--color-on-surface); text-align: right; }
```

**Top N + "Weitere":** Zeige Top 8, bei Klick auf "N weitere anzeigen" (Button) den Rest expandieren.

```js
function renderGewaesser(data) {
  const sorted = [...data].sort((a,b) => b.catch_count - a.catch_count);
  const top = sorted.slice(0, 8);
  const rest = sorted.slice(8);
  let html = top.map(...).join('');
  if (rest.length) {
    html += `<button class="gewaesser-show-more"
      onclick="this.parentElement.innerHTML += '${rest.map(...).join('')}'; this.remove()">
      + ${rest.length} weitere anzeigen</button>`;
  }
  el.innerHTML = html;
}
```

**Kein uPlot für diesen Chart.** Das Pattern aus Bedingungen-Matrix (CSS) wird hier 1:1 verwendet.

---

## 3. Donut Chart — Fischverteilung (NEU)

**Stitch-Design:** Donut mit zentralem Wert + Legende.
**Aktuell:** Fehlt komplett.

**Vorschlag: uPlot Pie-Plugin oder simples SVG-Donut.**

uPlot hat kein natives Pie — Optionen:

### Option A: Eigenes SVG-Donut (empfohlen, 0 Dependencies)

```js
function renderDonut(data, containerId) {
  const total = data.reduce((s, d) => s + d.count, 0);
  const colors = ['#6c7a57', '#bdcca4', '#e7e5b4', '#617a7c', '#45483f', '#a3b18a'];
  let cumPct = 0;
  const arcs = data.map((d, i) => {
    const pct = d.count / total;
    const start = cumPct;
    cumPct += pct * 100;
    // SVG arcs via stroke-dasharray
    const r = 60, circ = 2 * Math.PI * r;
    const offset = circ * (1 - pct);
    return `<circle cx="0" cy="0" r="${r}" fill="none" stroke="${colors[i % colors.length]}"
      stroke-width="24" stroke-dasharray="${circ}" stroke-dashoffset="${offset}"
      transform="rotate(-90)" style="transition: stroke-dashoffset 0.5s"/>`;
  });
  return `<div class="donut">
    <svg viewBox="-80 -80 160 160">${arcs.join('')}</svg>
    <div class="donut-center">${total}</div>
  </div>`;
}
```

### Option B: Chart.js (nur für den Pie, kein uPlot Pie)
- Lädt 63KB extra — für einen Pie übertrieben.
- **Option A bevorzugt.**

**Legende** unter dem Donut:
```
🟩 Spiegel 40%   🟩 Schuppen 32%   🟨 Leder 11%   🟦 Amur 9%
```

---

## 4. Monats-Balken — Fänge pro Monat (NEU)

**Stitch-Design:** Vertikale Balken: 12 Monate (J, F, M, A, M, J, J, A, S, O, N, D).

**Vorschlag: uPlot Bars (einfach) oder CSS-HTML-Bars.**

Option: CSS-HTML-Bars (leichter, kein extra Graphentyp):

```js
function renderMonthlyBars(data) {
  const max = Math.max(...data.map(d => d.count));
  const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
  let bars = '';
  data.forEach((d, i) => {
    const h = (d.count / max) * 100;
    bars += `<div class="month-bar-wrapper">
      <div class="month-bar" style="height: ${h}%"></div>
      <span class="month-label">${months[i]}</span>
    </div>`;
  });
  el.innerHTML = `<div class="month-bars">${bars}</div>`;
}
```

Farben: Balken = `--color-primary-container`, Hover = `--color-primary`.
Höhe: fix 180px.

---

## 5. Bedingungen-Matrix (bleibt gleich)

- Horizontale CSS-Bars ✓ (bereits korrekt implementiert)
- Feinheiten: Farben konsistent zu Gewässer-Bars machen
- Höhe der Bar-Tracks: 20px (current) → 24px (Design)

---

## 6. Kombi-Cards

- Grid-Layout stimmt mit Design überein
- Feinheiten:
  - Design zeigt: **Bait-Typ** als Überschrift, darunter **Art · Fänge · Ø**
  - Aktuell: Zeigt Fänge + Ø im Header, Bedingungen in der Label-Zeile
  - Layout angleichen: Bait-Name fett oben, Details als `span`-Chain mit Dot-Separatoren

---

## 7. Farbpalette (Zusammenfassung)

### Light Mode
| Verwendung | Farbe | Token |
|-----------|-------|-------|
| Primäre Balken/Linien | `#6c7a57` | `--color-primary-container` |
| Sekundäre Linien | `#bdcca4` | `--color-primary-fixed-dim` |
| Track-Hintergrund | `#ebf0e1` | `--color-surface-container` |
| Gridlinien | `#c6c8bc` | `--color-outline-variant` |
| Text (primär) | `#181d14` | `--color-on-surface` |
| Text (sekundär) | `#45483f` | `--color-on-surface-variant` |
| Card-Hintergrund | `#dfe4d6` | `--color-surface-variant` |
| Tertiär-Akzent | `#617a7c` | `--color-tertiary-container` |
| Donut-Segmente | `#6c7a57, #bdcca4, #e7e5b4, #617a7c, #45483f, #a3b18a` | — |

### Dark Mode
| Verwendung | Farbe | Token |
|-----------|-------|-------|
| Primäre Balken/Linien | `#a4b68c` | `--color-primary-fixed-dim` |
| Sekundäre Linien | `#546140` | `--color-primary` |
| Track-Hintergrund | `#262824` | `--color-surface-container-high` |
| Gridlinien | `#45463f` | `--color-outline-variant` |
| Text (primär) | `#e2decc` | `--color-on-surface` |
| Text (sekundär) | `#c6c2b1` | `--color-on-surface-variant` |
| Card-Hintergrund | `#1c1d1a` | `--color-surface-container` |

---

## 8. Tooltips + Cursor (uPlot)

**Alle uPlot-Charts brauchen:**
1. `cursor: { show: true, drag: { x: true } }` — Crosshair bei Hover
2. Eigener Tooltip-Element (im HTML vorhalten, per `dy`/`dx` positionieren)
3. `tooltip` Plugin oder manuelle `setCursor`-Handler

### Tooltip-Container (einmalig im HTML)
```html
<div id="chartTooltip" class="chart-tooltip" style="display:none;
  position:fixed; pointer-events:none; z-index:999"></div>
```

```css
.chart-tooltip {
  background: var(--color-surface-container-lowest);
  border: 1px solid var(--color-outline-variant);
  border-radius: 8px;
  padding: 0.5rem 0.75rem;
  font-family: "Source Sans 3", sans-serif;
  font-size: 0.8rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.12);
  color: var(--color-on-surface);
}
```

---

## 9. Responsive Verhalten

| Breakpoint | Verhalten |
|-----------|-----------|
| >1024px | 3-Spalten-Charts (Mond/Wetter/Monate) nebeneinander |
| 768–1024px | 2 Spalten, Gewässer-Chart volle Breite |
| <768px | 1 Spalte, Gewässer-Bars Label auf 120px reduziert |
| <480px | KPIs 2×2, Charts gestapelt, Filter als Drawer |

---

## 10. Summary: Was muss sich ändern?

1. **Gewichtsverlauf (uPlot)** — Tooltips + Cursor + ResizeObserver + Dark-Mode-Farben
2. **Gewässer** — uPlot raus → CSS-Horizontalbars mit Top-N + "Weitere"
3. **Donut (Fischverteilung)** — NEU bauen (SVG-Donut)
4. **Monatsbalken** — NEU bauen (CSS-Vericalbars)
5. **Bedingungen-Matrix** — Kosmetik (Höhe, Farben konsistent)
6. **Kombi-Cards** — Layout an Design angleichen
7. **Tooltip-System** — Einmaliges Tooltip-Element + uPlot-Integration
8. **Responsive** — ResizeObserver für uPlot + Breakpoint-Logik

---

## 11. Konkrete uPlot-Configs (für Code)

Siehe angehängtes JSON.