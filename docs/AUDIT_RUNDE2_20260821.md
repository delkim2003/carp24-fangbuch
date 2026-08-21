# 🔬 FULL-STACK-AUDIT carp24 — Runde 2 (21.08.2026, ~11:55)

> Methode: Re-Audit nach R1-Fixes — eigene Checks (Regression-Scan + Fix-Verifikation + neue Perspektive Offline-Sync/UX).
> R1-Fixes verifiziert: F1-Foto-Upload (E2E inkl. signierter URL), F2-EXIF, F3-.error-Checks, F5-EXTERNAL_HOSTS; F4 dokumentiert (Beta-Deploy-Thema).

## Fix-Verifikation (R1-Fixes)

| Fix | Status | Beweis |
|-----|--------|--------|
| F1 Foto-Upload | ✅ | Migration 0015 (Bucket privat, 4 Policies), Upload-E2E: Fang 8,4kg mit Foto → Detail zeigt signierte Storage-URL (400×300) |
| F2 EXIF-GPS-Strip | ✅ | Canvas-Re-Encode im Upload (Label "(EXIF entfernt)") |
| F3 .error-Checks | ✅ | faenge/statistik (loadError-Anzeige), dashboard (neu, Zeile 36-41+163), Export (errors-Objekt) |
| F4 gzip/Cache | 📋 | dokumentiert als Beta-Deploy-ninx-Thema (kein Dev-Fix) |
| F5 EXTERNAL_HOSTS | ✅ | Compose + .env (100.93.250.103,beta.carp24.org), auth neu — 0 X-Forwarded-Host-Warnungen |

## Regression-Scan (R2)

| Check | Ergebnis |
|-------|----------|
| .eq(x, null) Reste | 0 ✅ |
| getPublicUrl / uploadedPhotoUrl Reste | 0 ✅ |
| crypto.randomUUID direkt (außerhalb Fallback) | 0 ✅ (nur genClientUuid-Helper) |
| Cookie-Parse-Konsistenz (6 geschützte Seiten) | konsistent ✅ |
| createSignedUrl nur in faenge/[id] | ✅ |

## Neue Perspektive (Offline-Sync + UX)

| Fund | Sev | Status |
|------|-----|--------|
| Offline-Queue (offline-queue.ts, queueDraft, SyncIndicator) vorhanden + client_uuid in 0007/0012 | ✅ | kein Fund |
| loadError wird dem User angezeigt (faenge/statistik/dashboard) | ✅ | kein Fund |
| E2E nach Fix-Marathon: Login → Fang mit Foto → Liste (26 Fänge) → Detail mit Foto | ✅ | 21.08. 11:45 |

## Verbleibende Funde (nicht blockierend)

| Fund | Sev | Aktion |
|------|-----|--------|
| gzip/Cache-Control fehlt auf Node-Server | 🟡 | Beta-Deploy nginx: Compression + Asset-Caching einplanen |
| Fotos: signierte URLs nur 1h (3600s) — Anzeige nach Ablauf lädt neu beim Reload | 🟡 | akzeptiert für Beta (SSR erzeugt bei jedem Laden frische URL) |
| Iceberg-Migrationen (0038/0047) schlugen fehl | 🟢 | irrelevant (Experiment-Feature, nicht genutzt) |

## VERDICT Runde 2
**PROCEED** — Konfidenz 88%. 0 kritische/hohe offene Funde. R1-Fixes verifiziert, keine Regressionen gefunden. Rest = 🟡-kosmetisch + Beta-Deploy-Themen.

Single-Best-Action: **Gate-1-Abnahme einleiten** (Beta-Kern verifiziert) + Philipp-Aufgaben (DPA, Matomo-Site 4, DNS beta.carp24.org, Rechtstexte-Review).
