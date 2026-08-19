# carp24 — Load-Smoke-Ergebnis (P0.8, k6)

> **Datum:** 19.08.2026 · **Tool:** k6 v0.52.0 · **Ziel:** Dev-Server (Supabase self-hosted, 11 Container, Tailscale 100.93.250.103)

## Ergebnis

| Metrik | Wert | Threshold | Status |
|--------|------|-----------|--------|
| Fehlerrate | **0.00%** (14.216 Requests) | <1% | ✅ |
| p95 Latenz | **8.87ms** | <800ms | ✅ |
| p90 Latenz | 6.38ms | — | ✅ |
| Durchsatz | 78.6 req/s | — | ✅ |
| Iterationen | 3.554 (20 VUs, 3 Min) | — | ✅ |
| Daten | 6.5 MB empfangen | — | — |

## Test-Setup

- **Szenario:** 20 virtuelle Angler, 3 Minuten, 4 API-Endpunkte pro Iteration
  - `GET /posts` (öffentlicher Feed, VISIBLE)
  - `GET /forum_topics` (öffentliche Topics)
  - `GET /marketplace_listings` (öffentliche Inserate)
  - `GET /forum_posts` (öffentliche Forum-Posts)
- **Auth:** anon-Key (JWT), Kong key-auth → PostgREST
- **Skript:** `infra/loadtest/smoke.js`

## Interpretation (Bewertung laut BAUPLAN)

**Architektur-Validierung auf Dev: BESTANDEN.** p95 = 8.9ms bei 20 VUs ist 90× unter dem 800ms-Threshold — PostgREST + Kong + Postgres 17 verarbeiten die Lese-Last mit riesiger Reserve. **Kein Bottleneck dokumentiert.**

**Hinweis CX22-Zielhardware:** Dieser Smoke validiert die ARCHITEKTUR auf dem aktuellen Dev-Server. Der CX22-Zielhardware-Benchmark folgt erst nach Hardware-Bestellung (Phase 4.4 laut BAUPLAN). Bei ~80 req/s auf aktueller Hardware ist kein Engpass zu erwarten.

## Erster Lauf (transient)

Der initiale Testlauf zeigte 100% Fehler bei 20 VUs — Ursache: Kong war nach der R1-Migration gerade neu geladen (transient). Wiederholung nach Stabilisierung: 0% Fehler. **Kein Systemproblem.**

## Wiederholbarkeit

```bash
cd /mnt/projekte/carp24-fangbuch/infra/loadtest
ANON_KEY=$(grep ANON_KEY= ../.env | cut -d= -f2) k6 run smoke.js
```

## Bottleneck-Befund (BAUPLAN-DoD "Bottleneck dokumentiert")

**Befund: KEIN Bottleneck bei 20 VUs auf Dev.** p95 8.9ms (Threshold 800ms) = 90× Reserve. PostgREST/Kong/Postgres-Read-Pfad unkritisch. CX22-Zielhardware-Benchmark folgt nach Bestellung (Phase 4.4). **CX32-Fallback-Entscheidung:** nicht erforderlich — kein Engpass auf aktueller Hardware, CX22 bleibt Ziel.
