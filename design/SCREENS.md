# carp24 — Stitch Design-Übersicht (D1, 19.08.2026)

**Projekt:** Stitch `carp24-fangbuch` (projects/14881501037157667439)
**Design-System:** Tactical Carp Ledger (Militär: Oliv #6C7A57, Dark #131411/#1A1F16, Sand #D4C9A8, JetBrains Mono, 44px Touch)

## Kern-Screens Phase 1 (Build-Scope, R4-28)

| # | Screen | Stitch-Prompt | Status |
|---|--------|---------------|--------|
| S1 | Onboarding | Logo, Slogan, 3 Beispiel-Fänge, Freemium-Hinweis 50, LOS GEHT'S | ⏳ generiert |
| S2 | Login/Registrierung | E-Mail+Passwort, Registrieren, Logo | ⏳ generiert |
| S3 | Fang-Formular <20s | Chips, Gewicht Komma, Gewässer, Foto HEIC, Notiz, SPEICHERN | ⏳ generiert |
| S4 | Fangliste | Liste, Filter, FAB + FANG, Empty-State | ⏳ generiert |
| S5 | Fang-Detail | Foto groß, Gewicht mono, Wetter-Snapshot, Edit/Delete | ⏳ generiert |
| S6 | Dashboard | Gewichts-Verlauf, Monats-Chart, Top-Fänge, Statistik-Boxen | ⏳ generiert |
| S7 | Profil/Konto | Export Art.20, Datenschutz, Impressum, Gefahrenzone Löschen | ⏳ generiert |
| S8 | Paywall/Pro | 50-Grenze, Pro-Features, 4,99-6,99 €, JETZT PRO | ⏳ generiert |

## Später (D1 designt, Build nach PMF)

- S9 Marktplatz · S10 Board/Share · S11 Chat · S12 Forum · S13 Impressum/Datenschutz · S14 Offline/Queue-Banner

## Workflow (Skill stitch-mcp-usage)

1. Screens generieren (läuft)
2. HTML-Referenzen + Screenshots per curl laden (`file`-Beweis)
3. Dev-Server-Vorschau servieren (curl 200)
4. **Philipp-Abnahme (D2)** — Link, auf OK warten
5. ERST DANN Build 1:1 (D4)
