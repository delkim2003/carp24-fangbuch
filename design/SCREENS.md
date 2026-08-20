# carp24 — Stitch Design-Übersicht (D1, 19.08.2026 — aktualisiert 20.08.2026)

**Projekt:** Stitch `carp24 Premium Digital Logbook` (projects/18051329713568778931) — AKTUELL
**Design-System:** **Carp24 Editorial (LIGHT)** — Warm Sand #E8E0C8/#f6fbec, Khaki #CCCA9B, Olive #6C7A57, Water Blue #7B9496, Dark Moss #1A1F16; Source Serif 4 (Headlines), Source Sans 3 (Body), JetBrains Mono (Labels, UPPERCASE, Letter-Spacing)

> ⚠️ Verworfen: „Tactical Carp Ledger" (Dark-Militär #131411) — Philipp: „Dark ist immer schwierig" → LIGHT.
> ⚠️ Alt-ID `14881501037157667439` (carp24-fangbuch) nicht mehr gültig — verbindliche Quelle: list_projects/get_project.

## Kern-Screens Phase 1 (Build-Scope, R4-28)

| # | Screen | Stitch-Prompt | Status |
|---|--------|---------------|--------|
| S1 | Onboarding | Logo, Slogan, 3 Beispiel-Fänge, Freemium-Hinweis 50, LOS GEHT'S | ✅ generiert (Desktop+Mobile) |
| S2 | Login/Registrierung | E-Mail+Passwort, Registrieren, Logo | ✅ generiert |
| S3 | Fang-Formular <20s | Chips, Gewicht Komma, Gewässer, Foto HEIC, Notiz, SPEICHERN | ✅ generiert |
| S4 | Fangliste | Liste, Filter, FAB + FANG, Empty-State | ✅ generiert |
| S5 | Fang-Detail | Foto groß, Gewicht mono, Wetter-Snapshot, Edit/Delete | ✅ generiert |
| S6 | Dashboard | Gewichts-Verlauf, Monats-Chart, Top-Fänge, Statistik-Boxen | ✅ generiert |
| S6b | **Statistik-Studio (Bedingungs-UI)** | **Condition-Chips (Mond/Luftdruck/Wind/Wetter/Gewässer/Art/Köder/Zeit), Result-Cards, Mond+Druck-Visualisierung, Drill-down, Korrelation — 1.10b-Herzstück** | ✅ generiert (20.08., direkte API) |
| S7 | Profil/Konto | Export Art.20, Datenschutz, Impressum, Gefahrenzone Löschen | ✅ generiert |
| S8 | Paywall/Pro | 50-Grenze, Pro-Features, 4,99-6,99 €, JETZT PRO | ✅ generiert |

**Lokale Referenzen:** `design/screens/` (onboarding-desktop/mobile, login, catch-form, catch-list, catch-detail, dashboard, profile, paywall — .html + .png)

## Später (D1 designt, Build nach PMF)

- S9 Marktplatz · S10 Board/Share · S11 Chat · S12 Forum · S13 Impressum/Datenschutz · S14 Offline/Queue-Banner

## Workflow (Skill stitch-mcp-usage — NIE durch Proxy!)

1. **Direkt per Google-API generieren** (`stitch-direct.sh`, OAuth-Token) — Proxy verschluckt Antworten
2. HTML-Referenzen + Screenshots per curl laden (`file`-Beweis)
3. Dev-Server-Vorschau servieren (curl 200)
4. **Philipp-Abnahme (D2)** — Link, auf OK warten
5. ERST DANN Build 1:1 (D4)

## Verbindungs-Check (bei Problemen)

- gcloud: `~/.hermes/profiles/agentur-berater/home/.stitch-mcp/google-cloud-sdk/bin/gcloud`
- ADC: `~/.hermes/profiles/agentur-berater/home/.config/gcloud/application_default_credentials.json` (Quota api-project-1005187117241)
- `export HOME=/home/philipp/.hermes/profiles/agentur-berater/home` VOR gcloud-Aufrufen
- Details: Skill `stitch-mcp-usage` → `references/carp24-stitch-projekt-ids.md`
