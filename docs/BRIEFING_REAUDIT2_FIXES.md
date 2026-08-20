# BRIEFING — Re-Audit-Fixes Runde 2 (carp24): P1 Doppel-Sync + P2 Race + P3 Cleanup

## 🔴 BAUE SOFORT — gezielte Patches, KEINE kompletten Rewrites.

## Kontext
Re-Audit mit 3 neuen Perspektiven fand echte Funde. Sicherheitskritische/kosmetische Fixes sind bereits erledigt (XSS, active-Prop, tote Links, PNG-Logo). Du übernimmst die **Logik-Fixes**:

## 1. 🔴 P1 — DOPPEL-SYNC bei Online-Rückkehr (Race → Duplikate!)
**Dateien:** `web/src/components/SyncIndicator.astro` + `web/src/pages/fang-erfassen.astro` + `web/src/lib/offline-queue.ts`
**Problem (verifiziert):** Beide Dateien registrieren einen eigenen `window.addEventListener('online', ...)` (SyncIndicator Z126-131, fang-erfassen Z634-636) und rufen unabhängig `syncDrafts()`/`syncDraftsNow()` auf. Bei gleichzeitigem Fire lesen beide denselben IndexedDB-Draft-Stand, rufen `sync_catch` doppelt auf → **Duplikate**.
**Fix (zentraler Mutex in offline-queue.ts):**
- In `web/src/lib/offline-queue.ts`: globale `let syncing = false;` + exportiere `syncDraftsOnce(): Promise<boolean>` die:
  - bei `syncing === true` sofort `false` returned (nicht blockieren)
  - sonst `syncing = true` setzt, den Sync ausführt, in `finally` `syncing = false`
- **SyncIndicator.astro:** online-Listener nutzt die importierte `syncDraftsOnce` (oder den äquivalenten Mutex-Pfad) — KEINE eigene parallele Sync-Logik mehr.
- **fang-erfassen.astro:** online-Listener (Z634) entfernen ODER auf denselben `syncDraftsOnce`-Pfad umstellen. WICHTIG: Nach Formular-Submit beim Offline-Fall darf der sofortige Sync weiterhin laufen — der geht über die lokale Funktion, aber dann nur über `syncDraftsOnce` (Mutex) statt parallelem Aufruf.
- **Ziel:** Es gibt GENAU EINEN aktiven Sync zur selben Zeit (Mutex), auch wenn beide Listener feuern.

## 2. 🟠 P2 — RACE-CONDITION in Statistik-Filtern (refreshAll)
**Datei:** `web/src/pages/statistik.astro`
**Problem (verifiziert):** `refreshAll()` hat kein AbortController/Request-Sequenz-Tracking. Bei schnellem Klick auf mehrere Chips laufen mehrere RPC-Calls parallel — ein langsamer alter Request kann nach einem neueren eintreffen und die UI mit veralteten Daten überschreiben.
**Fix (last-request-Tracking):**
- Modul-Level `let refreshSeq = 0;` (oder AbortController, aber einfacher: Sequenz)
- In `refreshAll()`: `const mySeq = ++refreshSeq;` am Anfang. Nach jedem `await` (vor dem Rendern): `if (mySeq !== refreshSeq) return;` — verwirft veraltete Antworten.
- Mindestens für die asynchronen RPC-Ergebnisse vor dem DOM-Update prüfen.

## 3. 🟡 P3 — Toter Form-Error (fang-erfassen)
**Datei:** `web/src/pages/fang-erfassen.astro`
**Problem:** `<div id="form-error">` existiert (Z27) + wird in hideMessages() ausgeblendet, aber es gibt KEINE showFormError()-Implementierung — Validierungsfehler landen korrekt in `#submit-error`. Das `#form-error`-Element ist tot.
**Fix:** Das tote `#form-error`-Div **entfernen** (und die hideMessages()-Referenz darauf) ODER — wenn es für einen Zweck gedacht war — implementieren. Empfehlung: entfernen (submit-error übernimmt).

## 4. 🟡 P3 — Doppelte Helfer-Funktionen (Code-Qualität)
**Dateien:** `web/src/pages/fang-erfassen.astro` (Z624 `escapeHtml`) + `web/src/pages/statistik.astro` (Z525 `escHtml`)
**Fix (minimal, ohne Refactoring-Risiko):** Erstelle `web/src/lib/escape.ts` mit einer exportierten `escHtml(s: string): string` (gleiche Implementierung wie bestehende — übernimmt die aus statistik.astro). Nutze sie in BEIDEN Seiten (Import + Aufrufe ersetzen). **VORSICHT:** Nur die Funktion ersetzen, KEINE anderen Teile der Seiten anfassen. Wenn du unsicher bist wegen Duplicate-Name-Kollisionen (escHtml heißt in fang-erfassen `escapeHtml`), benenne um: Beide Seiten importieren `escHtml` aus der neuen lib.

## 5. 🟡 P3 — Empty-State-Zähler redundant (faenge)
**Datei:** `web/src/pages/faenge.astro`
**Problem:** Wenn 0 Fänge: Zähler „0 FÄNGE GESAMT" + „NOCH KEINE FÄNGE" redundant.
**Fix:** Zähler-Zeile nur anzeigen wenn `count > 0` (oder im Empty-State ausblenden).

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/lib/offline-queue.ts, web/src/components/SyncIndicator.astro, web/src/pages/fang-erfassen.astro, web/src/pages/statistik.astro, web/src/pages/faenge.astro
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Patche sofort.

## WICHTIG
- **Minimale, gezielte Patches** — bestehende Funktionalität NICHT brechen.
- **Der Offline-Flow (Formular offline speichern → später syncen) MUSS funktionieren** — nicht kaputt machen durch Mutex! Der Mutex verhindert nur parallele Läufe, nicht den eigentlichen Sync.
- Kein neues `import.meta.env` in is:inline.

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "syncDraftsOnce\|syncing" /mnt/projekte/carp24-fangbuch/web/src/lib/offline-queue.ts   # MUSS ≥1
grep -c "syncDraftsOnce" /mnt/projekte/carp24-fangbuch/web/src/components/SyncIndicator.astro   # MUSS ≥1 (Listener nutzt Mutex)
grep -c "refreshSeq\|mySeq" /mnt/projekte/carp24-fangbuch/web/src/pages/statistik.astro          # MUSS ≥1
grep -c "form-error" /mnt/projekte/carp24-fangbuch/web/src/pages/fang-erfassen.astro             # MUSS 0 (toter Error entfernt)
grep -c "escHtml" /mnt/projekte/carp24-fangbuch/web/src/lib/escape.ts                           # MUSS ≥1
grep -c "from \"../lib/escape\"" /mnt/projekte/carp24-fangbuch/web/src/pages/statistik.astro     # MUSS ≥1
grep -c "from \"../lib/escape\"" /mnt/projekte/carp24-fangbuch/web/src/pages/fang-erfassen.astro # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/                              # MUSS 0
```
Der Hauptagent baut + deployed + testet danach (inkl. Online/Offline-Verhalten).
