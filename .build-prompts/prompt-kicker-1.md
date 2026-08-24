## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/lib/i18n.ts, web/src/pages/rueckblick.astro, web/src/pages/trips.astro, design/screens/rueckblick-light-de-final.html, design/screens/trips-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit am Ende), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei << 'ENDOFFILE'
...KOMPLETTER DATEIINHALT...
ENDOFFILE
Das ist der EINZIGE Weg der funktioniert. JEDER Write-Aufruf wird fehlschlagen.

## AUFGABE: Kicker-Fix Teil 1 (i18n + rueckblick + trips)

Hintergrund: Die Klassen font-kicker/text-kicker sind in global.css NICHT definiert (rendern ungestylt). Die abgenommenen LIGHT-Screens zeigen den Kicker als font-label-sm text-label-sm (Small-Label-Stil). Ziel: Kicker auf Screen-Stil umstellen + i18n-Keys.

### 1. web/src/lib/i18n.ts — 4 neue Keys NACH Zeile 20 (nach dem bestehenden "kicker"-Key) einfügen:
"kicker.rueckblick": { de: "SAISON-RESUMEE", en: "SEASON REVIEW" },
"kicker.trips": { de: "ANGEL-REISEN", en: "FISHING TRIPS" },
"kicker.chat": { de: "Community", en: "Community" },
"kicker.marktplatz": { de: "COMMUNITY", en: "COMMUNITY" },
NUR diese 4 Keys hinzufügen — sonst NICHTS an i18n.ts ändern.

### 2. web/src/pages/rueckblick.astro — Kicker an BEIDEN Stellen (Z.69 eingeloggt-Header und Z.79 Titelbereich):
- Klassen: font-kicker text-kicker text-secondary tracking-widest → font-label-sm text-label-sm text-primary tracking-widest
- Text: t("kicker") → t("kicker.rueckblick")
- data-de={t("kicker", "de")} data-en={t("kicker", "en")} → data-de={t("kicker.rueckblick", "de")} data-en={t("kicker.rueckblick", "en")}
- ALLE anderen Klassen/Struktur der Zeile beibehalten (mb-2 etc.)

### 3. web/src/pages/trips.astro — Kicker an BEIDEN Stellen (Z.78 ausgeloggt und Z.88 eingeloggt):
- Klassen: font-kicker text-kicker text-secondary tracking-widest → font-label-sm text-label-sm text-primary tracking-widest
- Text: t("kicker") → t("kicker.trips")
- data-de/data-en entsprechend auf kicker.trips

### Referenz (Design-Absicht): In design/screens/rueckblick-light-de-final.html und trips-light-de-final.html per cat die Kicker-Zeile (SAISON-RESUMEE / ANGEL-REISEN) ansehen — Klassenset font-label-sm text-label-sm übernehmen.

## VERIFIKATION
- grep -n "kicker.rueckblick\|kicker.trips" web/src/lib/i18n.ts → beide Keys vorhanden
- grep -n "font-kicker" web/src/pages/rueckblick.astro web/src/pages/trips.astro → 0 Treffer
- grep -n "t(\"kicker\")" web/src/pages/rueckblick.astro web/src/pages/trips.astro → 0 Treffer

## COMMIT
Ein Commit:
git add web/src/lib/i18n.ts web/src/pages/rueckblick.astro web/src/pages/trips.astro
git commit -m "Design: Kicker-Fix Teil 1 — i18n Keys kicker.rueckblick/trips + Screen-Stil (font-label-sm)"
