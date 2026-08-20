# BRIEFING — Task 1.3: Supabase-Anbindung (carp24, Phase 1B)

## Ziel
Supabase-Client im Astro-Frontend verdrahten: `src/lib/supabase-client.ts` + `@supabase/supabase-js` + CSP/DOMPurify + Klaro-Banner-Test. **Grundlage für ALLE folgenden 1B-Tasks (1.5b, 1.6b, 1.8, 1.10b).**

## Projekt
- Pfad: `/mnt/projekte/carp24-fangbuch/web/`
- Stack: Astro 7.2.4 + Tailwind v4 (bereits installiert), Branch `sprint-1`
- Backend: Supabase self-hosted auf `http://100.93.250.103:8055` (Kong), Migrationen 0001–0012 applied

## Credentials (NUR zur Build-Zeit, NIE committen!)
- Supabase-URL: aus `/tmp/carp24_supabase_creds.txt` Zeile `SUPABASE_URL=`
- Anon-Key: aus `/tmp/carp24_supabase_creds.txt` Zeile `SUPABASE_ANON_KEY=`
- **Die echten Werte kommen beim BUILD in `.env` (web/.env, gitignored) — nicht in Code committen!**

## Deliverable (PFLICHT-Dateien)
1. **`web/src/lib/supabase-client.ts`** — createClient mit:
   - `import.meta.env.PUBLIC_SUPABASE_URL` + `import.meta.env.PUBLIC_SUPABASE_ANON_KEY` (Astro-Standard)
   - Export `supabase` + Typ-Helfer (auth, from)
   - Fallback: wirft klaren Fehler wenn env fehlt (kein Silent-Fail)
2. **`web/.env`** (gitignored) + **`web/.env.example`** (committed, Platzhalter) — PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY
3. **`web/package.json`** — `@supabase/supabase-js` in dependencies (npm install)
4. **`web/.gitignore`** — `.env` sicherstellen
5. **CSP-Update** in `web/src/layouts/Layout.astro` oder `astro.config.mjs` (falls vorhanden): erlaube `connect-src` zu Supabase-Host (`http://100.93.250.103:8055` Dev; in Prod https carp24.org)
6. **DOMPurify**: `npm install dompurify` — Client-Bibliothek für sanitized Rendering (wird in 1.5b/1.8 für Gewässer-Freitext/Notizen genutzt)

## DoD (Definition of Done — MUSS erfüllt sein)
- [ ] `grep -rn "createClient" web/src/` → ≥1 Treffer in supabase-client.ts
- [ ] `grep -rn "@supabase/supabase-js" web/package.json` → Treffer
- [ ] `npm run build` fehlerfrei (im web/-Ordner)
- [ ] supabase-client.ts importiert OHNE Fehler (Astro-Check)
- [ ] `.env` ist in .gitignore
- [ ] Kein echtes Secret in git (pre-commit: `grep -r "eyJhbGci" web/src/` → 0 Treffer)

## WICHTIGE REGELN
- **Jede Datei MUSS vollständig überschrieben werden. Keine Diffs, keine Snippets.**
- KEINE Hermes-Skills laden, KEIN /tmp für Build-Output (nur Referenz-Creds aus /tmp OK)
- Referenzen ins Projekt: `design/screens/*.html` für Design-Style (nur falls nötig)
- NUR OpenRouter-Auth nutzen (Produkt-KI = Mistral direkt ist NICHT Thema hier)
- Nach Build: Diff-/Inhalts-Verifikation durch den Hauptagent — dein Selbst-Report zählt NICHT als Beweis

## Verifikation (führe danach aus und melde Ergebnisse)
```bash
cd /mnt/projekte/carp24-fangbuch/web
grep -rn "createClient" src/ | head -5
grep "@supabase/supabase-js" package.json
npm run build 2>&1 | tail -5
cd /mnt/projekte/carp24-fangbuch && grep -rn "eyJhbGci" web/src/ | head -3 || echo "Kein Secret in src ✓"
```
