# BRIEFING — Task 1.4a: 2FA-UI (TOTP) + Sitzungs-Verwaltung (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen. Dateien werden KOMPLETT ÜBERSCHRIEBEN.

## Ziel
Zwei-Faktor-Authentifizierung (TOTP) + Sessions-Verwaltung im Frontend, komplett auf den offiziellen Supabase-MFA-APIs und den neuen RPCs `list_my_sessions`/`revoke_my_session`. **Kein Eigenbau-Auth, keine Mocks.**

**Produktentscheidung (verbindlich, von Philipp gewählt):** Recovery-Codes sind in GoTrue NICHT verfügbar (offiziell belegt, `/recovery_codes` → 404). Stattdessen: **ein 2. TOTP-Faktor als Backup** (User kann ein zweites Gerät enrollen, Limit 10 Faktoren — offizieller Supabase-Weg).

## Backend-APIs (VERBINDLICH — live verifiziert)
### Supabase-MFA (supabase.auth.mfa, offiziell, live im Stack GoTrue v2.189):
- `enroll({ factorType: "totp", friendlyName: "..." })` → `data.totp.qr_code` (SVG-String!) + `data.id` (factorId), `data.totp.uri`
- `challengeAndVerify({ factorId, code })` → verifiziert 6-stelligen Code, hebt Session auf AAL2
- `unenroll({ factorId })` → Faktor entfernen
- `listFactors()` → `data.totp` (Array mit `id`, `friendly_name`, `status`: "verified"/"unverified")
- `getAuthenticatorAssuranceLevel()` → `data.currentLevel` ("aal1"/"aal2"), `data.nextLevel`
- **WICHTIG (Doku):** Unverified Faktoren laufen nach ~5 Min ab → QR + Code-Eingabe auf dem SELBEN Screen.

### Eigene RPCs (Migration 0013, live verifiziert):
- `supabase.rpc("list_my_sessions")` → Array: `{ session_id, created_at, last_used, aal_level, user_agent, ip, is_aal2 }`
- `supabase.rpc("revoke_my_session", { p_session_id })` → löscht NUR eigene Session
- **Aktuelle Session erkennen:** JWT-`sid`-Claim aus `session.access_token` dekodieren (Base64url, payload.sid) — markiere diese Zeile als „AKTUELLES GERÄT", erlaube das Abmelden trotzdem (führt danach zum Logout/Refresh).

## Deliverables (in web/)

### 1. `web/src/pages/login.astro` (KOMPLETT ÜBERSCHREIBEN — bestehende Struktur + TOTP-Erweiterung)
Behalte das bestehende Layout (E-Mail/Passwort/Registrieren, is:inline-Script mit dataset-Env — funktioniert so!). **Ergänze den 2FA-Login-Flow:**
- Nach erfolgreichem `signInWithPassword`: **NICHT sofort weiterleiten!** Stattdessen:
  1. `await sb.auth.mfa.getAuthenticatorAssuranceLevel()` → wenn `currentLevel === "aal1"` UND `nextLevel === "aal2"` (MFA aktiv):
     - Login-Formular ausblenden, **TOTP-Screen einblenden** („Zwei-Faktor-Authentifizierung" + 6-stelliges Code-Input `inputmode="numeric" pattern="[0-9]{6}" maxlength="6"` + „BESTÄTIGEN"-Button + „Abbrechen" → zurück)
     - `const { data: factors } = await sb.auth.mfa.listFactors()` → **ersten verified TOTP-Faktor** nehmen (`factors.totp.find(f => f.status === "verified")`)
     - `await sb.auth.mfa.challengeAndVerify({ factorId, code })` → bei Erfolg: `window.location.href = "/faenge"` (Ziel wie bisher)
     - Bei Fehler: Fehlermeldung („Code ungültig oder abgelaufen") anzeigen, Input leeren, erneut versuchen
  - Wenn kein MFA aktiv (`nextLevel !== "aal2"` oder kein verified Faktor): direkt `window.location.href = "/faenge"` wie bisher
- TOTP-Code-Feld sauber styled wie die anderen Inputs (min-h-12, rounded-lg, border-primary/20)
- `aria-live="polite"` auf Fehlermeldungen

### 2. `web/src/pages/profil.astro` (KOMPLETT ÜBERSCHREIBEN — Mock raus!)
Das aktuelle profil.astro ist ein **reines Mockup** (Lukas Wagner, hartcodierte Stats 72/21,4/5). Neu:

**Frontmatter (SSR, wie faenge.astro):**
- `import { supabase } from "../lib/supabase-client"` + `getSession()`
- **Auth-Guard:** keine Session → Login-CTA (Muster aus dashboard.astro/statistik.astro)
- Mit Session: `supabase.from("catches").select("weight_kg, catch_ts, water_name").eq("deleted_at", null).eq("draft", false)` → **echte Stats** für die 3 Karten: FÄNGE (Anzahl), SCHWERSTER FANG (max weight_kg, DE-Komma + KG), GEWÄSSER (distinct water_name count)
- User-Daten aus Session: `session.user.email` + `session.user.created_at` („MITGLIED SEIT {Monat Jahr}") — KEIN hartcodierter Name. Wenn `user_metadata.full_name` existiert, das als Anzeigename, sonst E-Mail-Prefix.

**Sicherheits-Sektion (NEU — das Herzstück von 1.4a):**
Zwischen „Einstellungen" und „Gefahrenzone" ein Block „SICHERHEIT" (font-label-sm uppercase) mit:
- **Zwei-Faktor-Authentifizierung (TOTP)**:
  - Status-Zeile: „2FA STATUS" + Badge `AKTIV` (bg-primary text-white) / `INAKTIV` (bg-surface-container-highest)
  - **Aktivieren-Flow (wenn inaktiv):** Button „2FA AKTIVIEREN" → Enrollment-Panel (im selben Screen, NICHT neue Seite):
    - `enroll({ factorType: "totp", friendlyName: "carp24 Angler" })` → QR-Code als `<img src="data:image/svg+xml;base64,...">` (SVG base64-encoden) + Setup-Code (`data.totp.uri`) als Monospace-Text
    - 6-stelliges Code-Input + „FERTIGSTELLEN" → `challengeAndVerify({ factorId, code })` → Erfolg: Panel schließen, Status AKTIV, Faktor in Liste
    - Hinweis: „Scanne den QR-Code mit Google Authenticator oder einer kompatiblen App."
  - **Faktoren-Liste (wenn aktiv):** `listFactors()` → für jeden verified TOTP-Faktor: `friendly_name` + „ERSTES GERÄT"/„BACKUP-GERÄT" (Index-basiert) + „ENTFERNEN"-Button → `unenroll({ factorId })` mit Bestätigungsdialog (`window.confirm`)
  - **Backup-Gerät hinzufügen:** Button „BACKUP-GERÄT HINZUFÜGEN" → gleicher Enrollment-Flow (zweiter Faktor = Recovery, offizieller Weg!)
  - AAL2-Hinweis: „Nach der Aktivierung fragt dich der Login nach einem 6-stelligen Code."
- **Aktive Sitzungen (Sessions-Liste)**:
  - `supabase.rpc("list_my_sessions")` → Liste mit `user_agent` (nur erster Teil bis "(" — z.B. "curl/8.18.0" ODER "Mozilla/5.0 (X11; Linux…" → parsen: „Linux Chrome"-artige Kurzbeschreibung), `ip`, `last_used` (DE-Datum), AAL-Badge (`aal2` → „2FA", sonst „Passwort")
  - Jede Zeile: Gerät-Info + „ABMELDEN"-Button → `revoke_my_session({ p_session_id })` → Zeile entfernen. **Aktuelle Session (JWT sid):** Badge „AKTUELL" + nach Abmelden `sb.auth.signOut()` + Redirect `/login`
  - Leer-Zustand: „Keine aktiven Sitzungen"
  - **Doppelter Hinweis:** Session-Liste ist eine Eigenbau-UI auf offiziellen GoTrue-Daten (`auth.sessions`) — kein Security-Eigenbau.

**Behalte aus dem Mockup:** Einstellungen (Einheiten/Sprache/Benachrichtigungen — reine UI), Daten-Export (Button), Datenschutz/Impressum-Links, PRO-Status-Karte, ABMELDEN (aus Header-Logic übernehmen: `sb.auth.signOut()`). **Ersetze:** Stats hartcodiert → echt, Name → Session, Füge Sicherheits-Sektion ein. Kein `Lukas Wagner`, keine `72`/`21,4`/`5` als Konstanten!

**Client-Script:** gebündeltes `<script>` (NICHT is:inline — import aus lib/supabase-client) für: Enrollment-Flow (QR + Code), unenroll, Backup-Faktor, Sessions-Refresh + Revoke, Logout. Initiale SSR-Daten (Sessions + Faktoren) im Frontmatter laden und als `set:html` JSON-Script oder data-Attribute übergeben — kein Blinken.

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/**, design/screens/profile.html (falls vorhanden)
- VERBOTEN: supabase/migrations/, infra/, /tmp, git, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- **KEINE Mocks!** Keine hartcodierten Namen/Stats/Sessions. Alles aus Session/RPCs/DB.
- **`import.meta.env` NIE in `is:inline`-Scripts.** login.astro nutzt das bestehende dataset-Muster (funktioniert); profil.astro nutzt gebündeltes Script.
- **Unverified Faktoren laufen nach ~5 Min ab** → Enrollment-Panel + Code-Eingabe auf demselben Screen.
- Numeric-Felder von PostgREST kommen als STRING → IMMER `Number(...)`.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "mfa.enroll\|mfa.challengeAndVerify\|mfa.unenroll\|mfa.listFactors\|getAuthenticatorAssuranceLevel" /mnt/projekte/carp24-fangbuch/web/src/pages/profil.astro   # MUSS ≥3 (Enrollment + Verify + mind. 1 weitere)
grep -c "list_my_sessions\|revoke_my_session" /mnt/projekte/carp24-fangbuch/web/src/pages/profil.astro   # MUSS ≥2
grep -c "challengeAndVerify\|listFactors\|getAuthenticatorAssuranceLevel" /mnt/projekte/carp24-fangbuch/web/src/pages/login.astro   # MUSS ≥1 (TOTP-Login!)
grep -c "Lukas Wagner\|MITGLIED SEIT MÄRZ 2024\|value: \"72\"\|21,4\|value: \"5\"" /mnt/projekte/carp24-fangbuch/web/src/pages/profil.astro   # MUSS 0 (kein Mock!)
grep -c "createClient" /mnt/projekte/carp24-fangbuch/web/src/lib/supabase-client.ts   # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/   # MUSS 0
```
Server-Start + E2E macht der Hauptagent NACH deinem Lauf.
