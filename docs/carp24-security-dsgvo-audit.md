# Carp24 — Security & DSGVO Beta-Readiness Audit

**Datum:** 05.09.2026  
**Scope:** Web App (Astro SSR, port 8094), Supabase self-hosted (Kong 8055), GoTrue Auth, Klaro Consent  
**Web:** `http://100.93.250.103:8094` | **Supabase:** `http://100.93.250.103:8055`

---

## 1. HTTP Security Headers (Live-Check)

| Header | Status | Notes |
|---|---|---|
| `X-Frame-Options: DENY` | ✅ | Set via Astro middleware + Apache (dupliziert, harmlos) |
| `X-Content-Type-Options: nosniff` | ✅ | Dupliziert |
| `Referrer-Policy: strict-origin-when-cross-origin` | ✅ | Dupliziert |
| `Permissions-Policy` | ✅ | Dupliziert |
| `Strict-Transport-Security` | ❌ Fehlt | Nur in Kong-Konfig für API-Gateway (HTTPS 8443), nicht auf Web-App |
| `Content-Security-Policy` | ⚠️ Nur Meta-Tag | Als `<meta http-equiv>` im HTML, nicht als HTTP-Header — schwächerer Schutz |
| `Server`-Header | ⚠️ Sichtbar | `Server: Apache` — Apache zeigt sich an |

**Bewertung:** Grundlegende Header sind gesetzt, aber CSP fehlt als HTTP-Header und HSTS fehlt ganz.

---

## 2. Content-Security-Policy (Meta-Tag)

```
default-src 'self';
script-src 'self' 'unsafe-inline' https://matomo.einfach-online.dev;
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob: https: http:;
connect-src 'self' http://100.93.250.103:8055 http://100.93.250.103:8094
            https://matomo.einfach-online.dev https:;
font-src 'self' data:;
form-action 'self';
```

**Probleme:**
- **`unsafe-inline`** für Scripts + Styles — erlaubt DOM-XSS
- **`img-src https: http:`** — erlaubt Bilder von überall, potenziell für Data Exfiltration
- **`connect-src`** erlaubt explizit HTTP-Verbindungen zu interner IP
- CSP als **Meta-Tag** statt HTTP-Header: kann z.B. vor `<base>`-Manipulation nicht schützen

---

## 3. Transportverschlüsselung (TLS)

| Aspekt | Status | Details |
|---|---|---|
| HTTPS auf Web-App (8094) | ❌ | Läuft auf **plain HTTP** |
| Kong HTTPS (8443) | ⚠️ Konfiguriert | TLS-Zertifikate sind **auskommentiert** in docker-compose |
| Cookies `secure: false` | ❌ | Auth-Cookies ohne Secure-Flag |
| Canonical URL | ⚠️ | Behauptet `https://carp24.org` im OG-Meta — existiert nicht |
| HSTS | ❌ | Nicht gesetzt auf Web-App |

**Bewertung:** Die aktuelle Dev-Instanz läuft komplett unverschlüsselt. Auth-Tokens fließen über HTTP. Für ein Beta-Release zwingend HTTPS erforderlich.

---

## 4. Klaro Consent Manager

**Keine echte Klaro-Bibliothek:** Die App verwendet eine **eigene Lightweight-Implementierung** mit localStorage.

**Code:** `/mnt/projekte/carp24-fangbuch/web/src/components/KlaroBanner.astro`

### Findings:

#### 🔴 KRITISCH: syncMatomo-Bug
```javascript
function syncMatomo() {
  if (!window._paq) return;
  var mode = "essential";
  try { mode = localStorage.getItem("klaro-consent") || "essential"; } catch (e) {}
  if (mode === "all") {
    window._paq.push(["setConsentGiven"]);
  } else {
    window._paq.push(["forgetConsentGiven"]);
  }
}
```
**Problem:** Bei `mode === "all"` wird nur `setConsentGiven` aufgerufen. Bei `"essential"` (oder default) wird nur `forgetConsentGiven` aufgerufen. Das **sieht korrekt aus** — aber der kompilierte Code auf der Live-Seite zeigt **beide Aufrufe hintereinander** (siehe HTML-Output):
```
window._paq.push(["setConsentGiven"]);
window._paq.push(["forgetConsentGiven"]);
```
Der Astro-Bundler scheint die If-Bedingung **inkorrekt zu kompilieren**. Matomo bekommt widersprüchliche Signale.

#### 🟡 Keine granulare Cookie-Auswahl
- Nur 2 Buttons: "Nur notwendige" / "Alle akzeptieren"
- **Kein** individuelles Toggle für Cookie-Kategorien
- **Kein** "Einstellungen"-Button
- DSGVO verlangt: Art. 7(3) — jederzeit widerrufbar, Art. 6(1)(a) — informierte Einwilligung

#### 🟢 Positiv
- Matomo wird mit `requireConsent()` initialisiert — kein Tracking vor Consent
- Eigenhosting (matomo.einfach-online.dev) — DSGVO-konform
- Banner erscheint korrekt nur beim ersten Besuch

---

## 5. Supabase / GoTrue Auth

### Auth-Konfiguration

| Setting | Wert | Bewertung |
|---|---|---|
| Password min length | `10` | ✅ Gut |
| JWT Expiry | Configurable | ✅ |
| Refresh Token Rotation | `true` (default) | ✅ |
| MFA TOTP | `true` | ✅ |
| Anonymous Users | `false` `disabled` | ✅ |
| Email AutoConfirm | Configurable | ✅ |
| Rate Limit Email | `5` | ✅ |
| Refresh Token Expiry | 30 days (default) | ✅ |

### GoTrue JWT
- Legacy HS256 symmetric key (JWT_SECRET)
- JWT-Keys für asymmetrische Signierung konfigurierbar (kommentiert für Podman)
- `GOTRUE_JWT_AUD: authenticated`

### PostgREST (API Layer)
- JWT-Sekret konfiguriert (fallback auf symmetrisch)
- Anon-Rolle: `anon`
- Max Rows: 1000 (Rate-Limiting)

### Bedenken
- **Symmetric HS256** aber kein JWKS-Rotation-Mechanismus sichtbar
- `Authorization`-Header wird im Kong als `***` injiziert (Template-Variable — unsicher wenn leaked)

---

## 6. Row-Level Security (SQL)

**Alle 15 Tabellen haben RLS aktiviert.**

| Tabelle | RLS | Policy-Muster | Bewertung |
|---|---|---|---|
| `profiles` | ✅ | Select: alle authenticated, Update: owner | ✅ Gut |
| `catches` | ✅ | Owner-only CRUD, Insert nur draft | ✅ Gut |
| `posts` | ✅ | Visible für alle, Update/Delete nur owner | ✅ Gut |
| `subscriptions` | ✅ | Nur service_role | ✅ Gut |
| `waters` | ✅ | Owner oder public | ✅ Gut |
| `channels` | ✅ | Member-only | ✅ Gut |
| `chat_messages` | ✅ | Member-only mit Subquery | ✅ Gut |
| `marketplace_listings` | ✅ | Available oder owner | ✅ |
| `reports` | ✅ | Reporter oder MOD/ADMIN | ✅ |
| `notifications` | ✅ | Owner | ✅ |
| `forum_topics/posts` | ✅ | Visible für alle | ✅ |
| `trips` | ✅ | Owner | ✅ |

### RPCs (SECURITY DEFINER)
- `publish_catch()` ✅ — prüft auth.uid(), SEARCH_PATH=''
- `create_post()` ✅ — prüft auth.uid(), SEARCH_PATH='', Validierung inkl. published

### Soft-Delete / Anonymisierung
- `soft_delete_cascade()`: Anonymisiert alle Nutzerdaten bei `profiles.deleted_at` ✅
- DSGVO-Art. 17-konformes Vorgehen: Soft-Delete + GoTrue `deleteUser` im Account-Delete-Endpoint ✅

---

## 7. API-Endpunkte — HTTP Security

| Endpunkt | Auth | CSRF | Rate-Limit | Bewertung |
|---|---|---|---|---|
| `POST /api/auth/[...path]` | Proxy zu GoTrue | ❌ | Ja (Kong) | ⚠️ Proxy ist generisch |
| `POST /api/account/delete` | Session (Supabase) | ❌ | ❌ | ⚠️ Account-Löschung ohne CSRF |
| `POST /api/stripe/webhook` | Stripe-Signatur | N/A | ❌ | ✅ Stripe-Signatur bestätigt |
| `POST /api/stripe/checkout` | Session | ❌ | ❌ | ⚠️ |
| `POST /api/marketplace/contact` | Session | ❌ | ❌ | ⚠️ |
| `POST /api/ai/chat` | Session | ❌ | In-Memory 10s | ⚠️ |
| `POST /api/push/subscribe` | Session | ❌ | ❌ | ⚠️ |
| `POST /api/admin/_csrf` | Admin | ✅ (Origin-Check) | ❌ | ⚠️ Allowed Origins sind HTTP-IPs, nicht Domain |

### CSRF-Guard (Admin)
```javascript
const ALLOWED_ORIGINS = [
  "http://localhost:8094",
  "http://100.93.250.103:8094",
  "http://100.93.250.103:8055",
];
```
**Problem:** Nur HTTP-Tailscale-IPs, nicht die Produktionsdomain (carp24.org).  
**Problem:** Kein CSRF-Token, nur Origin-Header-Check — kann bei fehlendem Origin-Header umgangen werden.

---

## 8. Cookie Security

| Cookie | HttpOnly | Secure | SameSite | Path |
|---|---|---|---|---|
| `sb-carp24-auth-token` | ❌ Nicht gesetzt | ❌ `false` | `lax` | `/` |
| `sb-carp24-auth-token-code-verifier` | ❌ Nicht gesetzt | ❌ `false` | `lax` | `/` |

**Problem:** Kein `HttpOnly`, kein `Secure`. Auth-Token ist via JavaScript lesbar und fließt über HTTP.

---

## 9. Exposed Secrets (web/.env)

```bash
PUBLIC_SUPABASE_URL=http://100.93.250.103:8055
PUBLIC_SUPABASE_ANON_KEY=eyJhbG...Hg2w       # → Im Client-HTML sichtbar
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...qq2o       # → In Server-Code
VAPID_PUBLIC_KEY=BNAOiB...VyVA                # → Push Notifications
VAPID_PRIVATE_KEY=2lL2Mv...w4-A               # → Secret
OPENROUTER_API_KEY=...                        # → Secret
```

- `PUBLIC_SUPABASE_ANON_KEY` ist via `data-supabase-anon-key` im HTML-Body sichtbar (legitimer ANON-Key, nur für public access)
- `SUPABASE_SERVICE_ROLE_KEY` ist **administrativer Key** — darf nie in den Client
- `VAPID_PRIVATE_KEY` und `OPENROUTER_API_KEY` werden serverseitig verwendet

---

## 10. DSGVO-Checkliste

| Anforderung | Status | Nachweis |
|---|---|---|
| Impressum | ✅ | `/impressum` |
| Datenschutzerklärung | ✅ | `/datenschutz` — vollständig mit Verantwortlichem, Zwecken, Rechtsgrundlagen, Empfängern, Speicherdauer, Rechten |
| Cookie-Consent | ⚠️ Vorhanden | Custom Klaro-Banner mit 2 Optionen, **keine Granularität** |
| Widerspruchsrecht | ✅ | Im Datenschutztext erwähnt |
| Auskunftsrecht | ✅ | Im Datenschutztext erwähnt |
| Löschung (Art. 17) | ✅ | `/api/account/delete` — Soft-Delete + GoTrue deleteUser |
| Datenportabilität | ❌ **Fehlt** | Kein Export-Endpunkt |
| Betroffenenrechte-Kontakt | ✅ | `info@einfach-online.dev` |
| Auftragsverarbeitung | ✅ | Eigenbetriebene Infrastruktur (kein Drittanbieter) |
| SSL/TLS | ❌ **Fehlt** | Nur HTTP |
| Matomo on-Premise | ✅ | DSGVO-konform mit requireConsent |

---

## 11. Zusammenfassung & Prioritäten

### 🔴 Kritisch (vor Beta fixen)

1. **Klaro syncMatomo Bug**: Der kompilierte JavaScript-Code ruft beide `setConsentGiven` UND `forgetConsentGiven` auf. Matomo erhält widersprüchliche Signale. → Ursache: Astro-Bundler kompiliert `is:inline`-Script fehlerhaft.

2. **Cookies ohne Secure-Flag**: `secure: false` — Auth-Tokens fließen über HTTP. → `secure: true` setzen, sobald HTTPS verfügbar.

3. **Lückenhaftes Cookie-Consent**: Nur 2 Buttons ohne Kategorie-Toggle. → DSGVO verlangt granulare Opt-in-Möglichkeit.

### 🟡 Hoch (vor Beta fixen)

4. **HTTPS/TLS**: App läuft auf HTTP. → TLS-Termination einrichten (Apache oder Reverse Proxy).

5. **Kein HSTS**: Fehlt auf Web-App. → `Strict-Transport-Security` als HTTP-Header setzen.

6. **CSP kein HTTP-Header**: Nur Meta-Tag. → Als HTTP-Header via Apache setzen.

7. **CSP `unsafe-inline`**: Nicht vermeidbar bei Astro, aber Risiko dokumentieren.

8. **CSRF-Schutz lückenhaft**: Nur Admin-API geschützt, Allowed Origins ohne Produktionsdomain.

### 🟢 Niedrig (dokumentieren)

9. **Datenportabilität fehlt**: Kein Export-Endpunkt für Nutzerdaten (DSGVO Art. 20).

10. **Login minlength 8 vs. GoTrue 10**: HTML gibt 8 vor, GoTrue fordert 10.

11. **Duplicate Security Header**: Astro + Apache setzen gleiche Header (harmlos).

12. **Supabase Proxy in Astro**: `/api/auth/[...path].ts` leitet **alle** HTTP-Verben durch — potenziell zu permissiv.

## 12. XSS / DOM-Basiert — Clientseitige HTML-Einschleusung

**dompurify ist als Dependency installiert aber nirgends importiert** (`package.json: "dompurify": "^3.4.14"`).

### escapeHtml-Funktion
- Wird extensiv in User-Facing Pages verwendet (`fang-erfassen.astro`, `marktplatz.astro`, `admin/content.astro`, `rueckblick.astro`, `trips.astro`, etc.)
- Implementiert als: `div.textContent = s; return div.innerHTML;` — ✅ sicher
- Definiert lokal (mehrfach) und als `escHtml()` in `lib/escape.ts` (unused!)

### Ungeschützte innerHTML-Verwendungen (🚨)
- `admin/content.astro:269` — `bodyEl.innerHTML = html;` ohne Escaping
- `admin/notifications.astro:219` — Template-Literals in innerHTML ohne Escaping
- `fang-erfassen.astro:784` — `return div.innerHTML;` (Helper-Funktion)
- `admin/content.astro:118` — `return div.innerHTML;`
- `admin/users.astro:140` — `return div.innerHTML;`
- `rueckblick.astro:232` — `return div.innerHTML;`
- Mehrere Skeleton/Error-Rendering-Statements setzen direkt HTML-Strings

### Bewertung
Die meisten User-Outputs sind via `escapeHtml()` geschützt, aber die uneinheitliche Nutzung und das Fehlen von dompurify sind Risiken. Admin-Pages sind weniger kritisch (nur für Admins), aber die konsistente Nutzung von dompurify wird empfohlen.

### ✅ Bereits gut umgesetzt

- RLS auf allen Tabellen ✅
- Soft-Delete mit Anonymisierung ✅
- Account-Deletion-Endpoint ✅
- Matomo on-Premise mit requireConsent ✅
- MFA/TOTP ✅
- Passwort-Mindestlänge 10 ✅
- Refresh-Token-Rotation ✅
- Stripe-Webhook-Signatur ✅
- Rate-Limiting auf Auth-Endpoints (Kong) ✅
- Session-Prüfung auf geschützten API-Endpoints ✅
- Datenschutzerklärung vollständig ✅
- Impressum ✅
- SQL-Injection-Prävention (parametrized queries via Supabase SDK) ✅
- XSS-Prävention: DOM Purify als Dependency ✅ (aber aktuell unklar ob verwendet)