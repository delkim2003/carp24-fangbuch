# 🔬 AUDIT PRODUKT-FEATURES-PLAN — Experten-Loop (21.08.2026)

> **Methode:** 3 Subagenten (Produkt/UX · Architektur · Security/DSGVO) dispatched → **3/3 im 900s-Timeout** (v4-flash, nur gelesen, keine Findings; bekannt aus Audit-R1) → **Fallback: Self-Audit mit den 3 Perspektiven** (Hermes, Kontext: gesamte Session + Vault-Doku).
> Basis: `docs/PRODUKT_FEATURES_PLAN_20260821.md` (v1).

## Findings

### P0 — blockierend (MUSS in Plan v2)

| # | Perspektive | Fund | Empfehlung |
|---|-------------|------|------------|
| P0-1 | Security | **Art-15/17 unvollständig:** Bestehender Datenexport (profil.astro) erfasst nur user/profiles/catches. Neue Features (Trips, Badges, Forum-Posts, Chat-Nachrichten, Marktplatz-Anzeigen, Push-Subs) wären beim Export/Löschung nicht erfasst → DSGVO-Verstoß | Plan: Export+Deletion um ALLE neuen Tabellen erweitern (eigener Task, DoD: E2E-Export enthält neue Daten) |
| P0-2 | Security | **DSA Notice-and-Action fehlt:** Forum/Chat/Marktplatz = User-Content. Es braucht Meldemöglichkeit + Betreiber-Löschung, nicht nur "Moderation" | Neue Migration `content_reports` (target_type, target_id, reason, status) + UI-Meldelink auf allen User-Content-Elementen + Admin-Ansicht |

### P1 — hoch

| # | Perspektive | Fund | Empfehlung |
|---|-------------|------|------------|
| P1-1 | Architektur | **OAuth (B1) konkretisieren:** GoTrue braucht `GOTRUE_SITE_URL`, `GOTRUE_EXTERNAL_REDIRECT_URL`, `GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID/SECRET` + Provider-Konsolen-Redirect auf `/auth/v1/callback` | Plan: Env-Liste + Redirect-Pfad explizit; Dev: Buttons sichtbar, Flow erst mit Creds (ist drin) |
| P1-2 | Architektur | **Realtime-Chat (C3) unvollständig:** Supabase-Realtime braucht `alter publication supabase_realtime add table chat_messages` + REPLICA IDENTITY FULL + Kanal-Auth (JWT im Authorization-Header) + Flood-Schutz | Plan: Realtime-Setup-Schritte + Rate-Limit (z.B. 1 msg/2s client-side + RLS) |
| P1-3 | Architektur | **Stripe (D2) unvollständig:** Webhook-Signatur (`STRIPE_WEBHOOK_SECRET`), Idempotenz (event.id in Tabelle), nur `checkout.session.completed` setzt is_pro | Plan: Webhook-Flow + Idempotenz-Tabelle `stripe_events` |
| P1-4 | Produkt | **Pro-Gating (D1) blockiert Alpha-Sicht:** Wenn Free-Locks vor Alpha aktiv, sieht Philipp nicht alles | Plan: D1 so bauen, dass Philipp (Admin-Flag) immer Pro sieht; Locks nur für nicht-Pro-User |
| P1-5 | Security | **AVV-Lücken:** Google/FB (B1) + Mistral/OpenRouter (E3) waren in 0.7 geplant; **Stripe (D2) fehlt komplett** | Plan: Stripe-AVV in DSGVO_AVV ergänzen, Abschluss VOR Aktivierung der Dienste |

### P2 — mittel

| # | Perspektive | Fund | Empfehlung |
|---|-------------|------|------------|
| P2-1 | Architektur | **Badge-Trigger-Muster:** Badge-Check nach publish/import — RPC-in-RPC kompliziert, Trigger-Nesting riskant | Empfehlung: eigenständige RPC `check_badges(user_id)` vom Client nach Speichern/Import aufrufen (einfach, kein Nesting) |
| P2-2 | Architektur | **CSV-Import:** `import_catches`-RPC muss publish_catch-Validierung duplizieren (lat/lng-CHECK, Pflichtfelder) + Badge-Trigger danach | Plan: Import = gemeinsame Validierungslogik (RPC-Aufruf publish_catch pro Zeile ODER eigene RPC mit gleichen Checks + check_badges) |
| P2-3 | Produkt | **Reihenfolge:** Badges (A3) sollte NACH CSV-Import (A1) kommen (Daten-Importeur-Badge) | Batch A: A1 → A3 → A2 → A4 (Rückblick unabhängig) |
| P2-4 | Security | **Privacy by Design (Community):** is_public-Fänge = Standortdaten (lat/lng) | Bei public-Teilen: Koordinaten runden (2 Dezimalstellen ≈ 1 km) oder verbergen; Gewässername optional |
| P2-5 | Architektur | **Marktplatz-Fotos:** catch-photos-Bucket wiederverwenden (privat, signed URLs) | Gleicher Bucket mit Pfad-Präfix `marketplace/` — keine neue Bucket-Infra |

### P3 — niedrig

| # | Perspektive | Fund | Empfehlung |
|---|-------------|------|------------|
| P3-1 | Produkt | Chat (C3) ist der aufwendigste UI-Block — vorher Community-Board (C1) validiert Muster | Reihenfolge C1 → C2 → C3 (Forum vor Chat, da statisch einfacher) |
| P3-2 | Produkt | i18n (E1) vor Push (E2): Sprachgerüst ist Basis für spätere Expansion | E1 → E2 (schon so) |
| P3-3 | Security | KI (E3): Prompt-Logging verbieten, Rate-Limit, UI-Hinweis "KI-generiert" | Plan: No-Log-Regel + Timeout + Opt-in-Text |

## VERDICT
**Plan v2 erforderlich (2× P0, 5× P1)** — aber keine Scope-Explosion: P0-1 (Export erweitern) + P0-2 (content_reports) sind additive Tasks, keine neuen Features. P1s konkretisieren bestehende Features. Build-Start nach Plan v2 mit A1.
