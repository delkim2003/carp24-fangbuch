# 🔬 FULL-STACK-AUDIT carp24 — Runde 1 (21.08.2026, ~11:15)

> Methode: 3 Subagenten timeouteten (v4-flash, bekanntes Muster) → Audit selbst ausgeführt (mechanische Checks + read_file, statisch + curl, keine Browser-E2E).
> Scope: Frontend (13 Seiten), Backend (RLS, Edge Functions, GoTrue, Kong), Infra (Docker, Backup, Systemd), Security/DSGVO.

## Fund-Liste (verifiziert)

| # | Sev | Fund | Beweis |
|---|-----|------|--------|
| F1 | 🔴 | **Storage-Bucket `catch-photos` existiert NICHT** (0 Buckets, 0 Storage-Policies in DB) → Foto-Upload im Fang-Formular (`fang-erfassen.astro:496` upload + `:501` getPublicUrl) schlägt für jeden User fehl | `SELECT id,name,public FROM storage.buckets` → leer; `pg_policies WHERE schemaname='storage'` → leer |
| F2 | 🟠 | **EXIF-GPS beim Foto-Upload** — Fotos enthalten beim Fix von F1 automatisch Standort-Metadaten (EXIF-GPS), DSGVO-Standort-Leak (Plan-Thema, muss mit F1 zusammen gelöst werden: Canvas-Re-Encode verliert EXIF) | Upload-Code ohne Bild-Verarbeitung |
| F3 | 🟡 | **SSR-Queries ohne `.error`-Check**: `dashboard.astro:38`, `faenge.astro:42`, `faenge/[id].astro:43`, `profil.astro:42` + DSGVO-Export `profil.astro:587-596` — bei DB-Fehler stille leere Daten statt Fehler | grep `.from(` ohne `.error` in Frontmatter |
| F4 | 🟡 | **Kein gzip/Brotli + kein Cache-Control** auf Server-Antworten (Node-Server; `/` = 25 KB unkomprimiert, TTFB 2,6 ms) — Beta-Deploy auf nginx muss Compression + Asset-Caching setzen | `curl -sI /` ohne content-encoding/cache-control |
| F5 | 🟡 | **GOTRUE_MAILER_EXTERNAL_HOSTS**: `100.93.250.103` fehlt → X-Forwarded-Host-Warnung in auth-Logs (Log-Spam; bei Beta-Domain neu setzen) | `docker logs supabase-auth` |
| F6 | 🟢 | **Pre-commit-Secret-Scan installiert**, `.gitignore` deckt `.env/*.pem/*.key` ab; `docs/secrets.md` getrackt aber OHNE Werte (nur Hinweise) — kein Leak | `git ls-files | grep secret` + Inhalt geprüft |

## Positiv-Befunde (R1, verifiziert)

- **RLS komplett solide**: catches UPDATE nur Draft/deleted (Entitlement-Schutz), marketplace_messages 1:1 (from/to), chat_messages nur Channel-Member, posts = kuratierte Projektion (keine Koordinaten/Notizen), waters owner-or-public
- **GoTrue**: Refresh-Rotation=true, Password-Min-Length=10, MFA-TOTP aktiv, Rate-Limit-Email=5, DISABLE_SIGNUP steuerbar
- **Auth-Flows**: login/registrieren/statistik/fang-erfassen mit `.error`-Handling (role=alert), Logout mit Session-Revoke (revoke_my_session, REVOKE nur authenticated)
- **Infra**: 11/11 Container healthy, keine RestartCounts (carp24), systemd carp24-web Restart=always, Backup 21.08. 02:30 gelaufen (roles/config/storage .gpg), Disk 66%, Load 1.3
- **Secrets**: 0 Treffer im Git-Repo (echte Keys)

## Fix-Plan (sequentiell, ein Fix = ein Commit)

1. **F1+F2 (🔴+🟠): Storage-Bucket-Migration + Policies + EXIF-GPS-Strip**
   - Migration 0015: Bucket `catch-photos` (public=false) + Storage-Policies (authenticated: INSERT own path, SELECT own; keine anon-Reads)
   - Client-Fix fang-erfassen.astro: Upload via `createSignedUrl` (statt getPublicUrl) + Canvas-Re-Encode (JPEG 0.85, max 1600px) → EXIF (inkl. GPS) wird verworfen
   - Detailseiten/Vorschau: signierte URL bei Anzeige
2. **F3 (🟡): `.error`-Checks in 4 SSR-Seiten + Export** — leere/Fehler-Objekte mit Fehlertext
3. **F5 (🟡): GOTRUE_MAILER_EXTERNAL_HOSTS** um `100.93.250.103` ergänzen (1 Zeile .env)
4. **F4 (🟡): dokumentieren** als Beta-Deploy-Thema (nginx gzip/cache) — kein Dev-Server-Fix

## Verdict Runde 1
PAUSE (F1 blockiert Beta: Foto-Upload-Feature kaputt + DSGVO-Implikation) — Konfidenz 80%
Single-Best-Action: Storage-Bucket-Migration + Upload-Fix (EXIF-Strip) vor Beta-Deploy.
