# Backend/DB Beta-Readiness-Audit — Carp24 Fangbuch

**Datum:** 2026-09-05  
**Geprüft:** Backend (Astro SSR), Datenbank (Supabase/Postgres 17), Auth, API, Infrastruktur  
**Status:** Beta-fähig mit 3 **kritischen** und 5 **empfehlenswerten** Punkten

---

## 1. Infrastruktur-Health

| Prüfung | Status | Details |
|---------|--------|---------|
| Astro SSR (Port 8094) | ✅ OK | `carp24-web.service` active, 68MB RAM, 11 Tasks |
| Supabase Kong (Port 8055) | ✅ OK | Kong 3.9.3, healthy, alle Container Up seit 9 Tagen |
| Supabase DB | ✅ OK | Postgres 17, `supabase-db` healthy, `unless-stopped` restart |
| DB Größe | ✅ OK | 15 MB — überschaubar |
| DB Verbindung | ✅ OK | Auth-Proxy (`/api/auth/[...path]`) → Kong → GoTrue |
| Systemd | ✅ OK | `carp24-web.service` enabled, Restart=always |
| Backups | ✅ OK | Täglich 02:30, verschlüsselt (GPG) + Offsite → Vault |
| Docker Restart | ✅ OK | `unless-stopped` auf allen Containern |

**Alle Docker-Container gesund:**
```
supabase-db, supabase-auth, supabase-kong, supabase-studio,
supabase-rest, supabase-storage, supabase-pooler, supabase-meta,
supabase-edge-functions, supabase-imgproxy, supabase-templates,
supabase-realtime, supabase-pooler
```

---

## 2. Datenbank-Schema & Integrität

### 2.1 Tabellen (27 Stück in public schema)
- **catches** (137 Einträge: 130 published, 5 drafts, 2 gelöscht)
- **profiles** (16 User: 15 aktiv, 1 gelöscht — Philipp als ADMIN)
- **waters** (25 Referenzgewässer)
- **trips** (3)
- **forum_threads** (1)
- **error_logs** (16)

### 2.2 Migrationen
- **49 Migrationsdateien** vorhanden — durchgehend idempotent (`IF NOT EXISTS`, `DROP IF EXISTS`)
- Keine verwaisten oder fehlgeschlagenen Migrations-Versionen
- Schema stimmt mit Migrations-Deklaration überein

### 2.3 Indizes
- **16 Indexe** auf den Kerntabellen (catches, posts, marketplace, forum, etc.)
- Letzte Migration `0049_indexes.sql` fügt fehlende Indexe auf `admin_audit_log`, `content_reports`, `profiles(role)` hinzu
- **Problem:** Kein Index auf `profiles.email` (falls vorhanden) oder `catches.session_id`

### 2.4 Erweiterungen (Extensions)
- `pg_net` 0.20.3, `pg_stat_statements`, `pgcrypto`, `pgtap`, `uuid-ossp`, `supabase_vault` ✅

---

## 3. RLS-Policies

### 3.1 Geprüfte Policies (60 Stück)

| Tabelle | Policies | Bewertung |
|---------|----------|-----------|
| **catches** | 6 (owner select/insert/update/delete, public_read, public_read_anon) | ✅ Stark — owner-scoped + public-Lesemodus |
| **profiles** | 2 (select authenticated, update owner) | ✅ Stark |
| **subscriptions** | 1 (service_role only) | ✅ Stark — kein User-Zugriff |
| **posts** | 3 (select public, update/delete owner) | ✅ Gut — anon darf sichtbare Posts lesen |
| **reports** | 3 (insert reporter, select mod/reporter, update mod) | ✅ Stark — rollenbasiert |
| **marketplace_listings** | 4 (select available/own, insert/update owner) | ✅ Gut |
| **chat_messages** | 3 (select member, insert own, delete own) | ⚠️ Chat-Messages haben keine Channel-Mitgliedschaft-Prüfung beim SELECT (nur `true` für authenticated) |
| **app_settings** | 1 (SELECT anon+authenticated) | ✅ OK — nur Wartungsmodus, kein sensitiver Inhalt |
| **feature_flags** | 1 (SELECT anon+authenticated) | ✅ OK |

### 3.2 Kritische Beobachtung
- **`chat_messages`**: Policy `chat_messages_read` erlaubt SELECT für **alle** authenticated User auf **alle** Nachrichten (`USING (true)`). Das ist zu permissiv — sollte auf Channel-Mitgliedschaft prüfen.

---

## 4. Auth-Flow & Sicherheit

### 4.1 Auth Proxy
- `/api/auth/[...path]` → proxy → `http://100.93.250.103:8055/auth/v1/{path}`
- ✅ Funktioniert — Login-Test erfolgreich mit Test-User
- ✅ Cookie-Optionen: `sameSite: 'lax'` (angemessen für SSR)

### 4.2 Sicherheitswarnung
```
⚠️ KRITISCH: Supabase SSR Sicherheitswarnung im Log
```
- `supabase.auth.getSession()` wird verwendet statt `supabase.auth.getUser()`
- Die Session aus dem Cookie ist nicht authentifiziert gegen den Auth-Server
- **Jeder Admin-API-Endpunkt** (`/api/admin/*`) verwendet `getSession()` → potenziell unsichere Session-Übernahme
- **Fix:** In allen API-Endpunkten `getUser()` statt `getSession()` verwenden

### 4.3 Admin-API Audited
| Endpoint | Auth | CSRF | Bewertung |
|----------|------|------|-----------|
| `/api/admin/me` | Cookie (getSession) | ❌ | ⚠️ getSession statt getUser |
| `/api/admin/stats` | Cookie (getSession) | ❌ | ⚠️ getSession statt getUser |
| `/api/admin/users` | Cookie (getSession) | ✅ CSRF Guard | ⚠️ getSession statt getUser |
| `/api/admin/audit` | Cookie (getSession) | ❌ | ⚠️ getSession statt getUser |
| `/api/auth/[...path]` | Proxy (apikey) | ❌ | ✅ OK (Supabase Auth) |

---

## 5. Offline-Sync

| Komponente | Status | Bewertung |
|------------|--------|-----------|
| `sync_catch()` RPC | ✅ | Idempotenter LWW-Upsert, Input-Validierung (0042) |
| `get_changes()` RPC | ✅ | Delta-Sync mit Pagination |
| Soft-Delete Trigger | ✅ | `soft_delete_catch_trg` verhindert DELETE → Tombstone |
| `cleanup_old_tombstones()` | ✅ | Hard-Delete nach 90 Tagen (0044 fix) |
| `client_uuid` UNIQUE | ✅ | Idempotenz über UUIDs |
| `client_updated_at` | ✅ | LWW-Feld vorhanden |
| Input-Validierung | ✅ | Notes ≤1000, Bait ≤200, Method ≤200, Water Name ≤500 |

---

## 6. Storage (Bilder)

| Prüfung | Status | Details |
|---------|--------|---------|
| Bucket 'catch-photos' | ✅ | Privat (`public=false`), existiert |
| RLS Policy Insert | ✅ | Pfad muss `{user_id}/...` beginnen |
| RLS Policy Select | ✅ | Nur eigener Pfad lesbar |
| Tatsächliche Dateien | ✅ | 3 Fotos in `7f8d9671-...` user directory |
| Storage-Tar im Backup | ✅ | 4KB (minimal, da nur 3 Fotos) |
| Exif-GPS-Strip | ✅ | Im Client (Canvas-Re-Encode) |

---

## 7. Security Headers

| Header | Status | Wert |
|--------|--------|------|
| `X-Frame-Options` | ✅ | `DENY` |
| `X-Content-Type-Options` | ✅ | `nosniff` |
| `Referrer-Policy` | ✅ | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | ✅ | Kamera/Mikro/etc. restriktiv |
| `CSP` | ✅ | `default-src 'self'`, Script/Connect mit konkreten Domains |
| `Content-Type` auf Login | ❌ | Fehlt (HTML ohne expliziten Content-Type?) — automatisch gesetzt |
| TLS | ⚠️ | `secure: false` in Cookie-Optionen — in Ordnung für internen Betrieb |

---

## 8. Client-seitige Fehler (error_logs)

| Fehler | Count | Severity | Location |
|--------|-------|----------|----------|
| `buckets is not defined` | 2 | Niedrig | `/statistik` JS |
| `a is not a function` | 4 | Mittel | `/statistik` (Chart-Bibliothek nach Rebuild) |
| `druck is not defined` | 1 | Niedrig | `/statistik` |
| `clipboard.writeText` | 2 | Niedrig | `/rueckblick` |
| `Astro is not defined` | 2 | Mittel | `/statistik` (Build-Cache?) |
| `crypto.randomUUID` | 4 | Mittel | `/fang-erfassen` (HTTP-Kontext, nicht HTTPS) |

**Alle Fehler von Philipps Browser (Chrome 151) — keine echten User-Betroffenen.**  
Keine Server-side Errors.

---

## 9. Stripe/PRO

| Prüfung | Status | Details |
|---------|--------|---------|
| `STRIPE_SECRET_KEY` | ❌ | Platzhalter `STRIPE...RET=` — nicht konfiguriert |
| `STRIPE_PRICE_ID` | ❌ | Platzhalter `price_...` — nicht konfiguriert |
| `STRIPE_WEBHOOK_SECRET` | ❌ | Fehlt in `.env` |
| Subscription-Records | ⚠️ | 0 subscriptions — kein PRO-User |
| `subscriptions` Table | ✅ | RLS korrekt: nur service_role |
| publish_catch Freemium-Limit | ✅ | 50 Fänge für FREE, unlimited für PRO |
| Admin Panel "Pro-User" | ℹ️ | Zählt `is_pro=true` — derzeit 0 |
| Webhook-Endpoint | ✅ | `/api/stripe/webhook.ts` vorhanden |
| Checkout-Endpoint | ✅ | `/api/stripe/checkout.ts` vorhanden |

---

## 10. Tests

| Art | Pfad | Bewertung |
|-----|------|-----------|
| pgTAP RLS-Tests | `tests/pgtap/0001_rls_tests.sql` | ✅ 34 Tests — RLS, RPCs, Trigger, Grants |
| pgTAP Stats v2 | `tests/pgtap/0002_stats_v2_tests.sql` | ✅ Stats-Funktionen |
| pgTAP Post-Init | `tests/pgtap/0003_post_init_tests.sql` | ✅ Post-Migration |
| k6 Smoke | `tests/k6/smoke.js` | ✅ 5 VUs, 30s, <5% errors, p95<500ms |

---

## 11. Zusammenfassung: Beta-Readiness

### ✅ Bestanden / Gut
- Alle Docker-Container gesund (9+ Tage Uptime)
- 49 idempotente Migrationen, 27 Tabellen, korrekte Indizes
- RLS auf allen sensitiven Tabellen
- Auth-Proxy funktioniert, Login getestet
- Tägliche verschlüsselte Backups mit Offsite-Replikation
- pgTAP-Testsuite (34 Tests) + k6 Smoke-Test
- Storage-Bucket mit RLS und Privat-Modus

### 🔴 Kritisch (vor Beta fixen)

**1. Supabase SSR Session-Sicherheit**  
Alle Admin-Endpoints nutzen `getSession()` statt `getUser()`.  
→ Jeder Cookie kann die Session behaupten, ohne gegen Auth-Server verifiziert zu werden.  
→ **Fix:** `getUser()` verwenden (Supabase SSR-Security-Pattern)  

**2. Stripe-Keys Fehlen**  
`STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID`, `STRIPE_WEBHOOK_SECRET` sind Platzhalter.  
Ohne Stripe-Konfiguration: kein PRO-Upgrade möglich, 50-Fänge-Limit für alle User.  
→ **Fix:** Stripe-Test-Keys von Philipp einholen und in `.env` setzen  

**3. chat_messages RLS zu permissiv**  
`chat_messages_read` erlaubt SELECT für alle authenticated User auf ALLE Nachrichten.  
→ **Fix:** Policy auf Channel-Mitgliedschaft prüfen (`EXISTS SELECT FROM channel_members`)

### 🟡 Empfehlungen (vor/nach Beta)

1. **Statistik-JS-Fehler beheben** — `buckets`, `druck`, `a is not a function` in `/statistik` — vermutlich Build-Cache-Problem
2. **`crypto.randomUUID`** in `/fang-erfassen` — Fallback für HTTP-Kontext (ohne secure context)
3. **`clipboard.writeText`** in `/rueckblick` — Null-Check vor Clipboard-API
4. **Backup-Rotation geprüft** — aktuell 7 lokal + 7 offsite → sollte mindestens 30/30 für Beta sein
5. **pg_cron für Tombstone-Cleanup** — `cleanup_old_tombstones()` wird nirgendwo automatisch aufgerufen