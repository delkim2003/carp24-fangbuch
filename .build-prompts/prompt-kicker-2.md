## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/chat.astro, web/src/pages/assistent.astro, web/src/pages/marktplatz.astro, web/src/pages/forum.astro, web/src/lib/i18n.ts, design/screens/chat-light-de-final.html, design/screens/assistent-light-de-final.html, design/screens/marktplatz-light-de-final.html, design/screens/forum-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit am Ende), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl:
cat > /pfad/zur/datei << 'ENDOFFILE'
...KOMPLETTER DATEIINHALT...
ENDOFFILE
Das ist der EINZIGE Weg der funktioniert. JEDER Write-Aufruf wird fehlschlagen.

## AUFGABE: Kicker-Fix Teil 2 (chat + assistent + marktplatz + forum)

Hintergrund: font-kicker/text-kicker ist in global.css NICHT definiert. Die Screens zeigen pro Seite einen anderen Kicker-Stil. Ziel: Screen-Stil übernehmen; im Forum den Kicker KOMPLETT ENTFERNEN (der forum-Screen hat keinen).

### 1. web/src/pages/chat.astro (Z.59, eine Stelle):
- Klassen: font-kicker text-kicker text-secondary tracking-widest → font-label-sm text-label-sm text-primary tracking-[0.15em]
- Text: t("kicker") → t("kicker.chat")
- data-de={t("kicker", "de")} data-en={t("kicker", "en")} → data-de={t("kicker.chat", "de")} data-en={t("kicker.chat", "en")}

### 2. web/src/pages/assistent.astro (Z.45, eine Stelle):
- Klassen: font-kicker text-kicker text-secondary tracking-widest → font-label-sm text-label-sm text-primary tracking-[0.2em]
- Text bleibt "CARP24" (hartcodiert, KEIN i18n-Key)
- data-de="CARP24" data-en="CARP24" bleiben

### 3. web/src/pages/marktplatz.astro (3 Stellen: Z.110 ausgeloggt, Z.120 Free-Lock, Z.129 eingeloggt):
- Klassen: font-kicker text-kicker text-secondary tracking-widest → font-mono text-sm text-secondary tracking-widest uppercase (Sonderfall: Screen nutzt font-mono text-sm!)
- Text: t("kicker") → t("kicker.marktplatz") an allen 3 Stellen
- data-de/data-en: auf t("kicker.marktplatz", "de")/("en") setzen — WICHTIG: die Kicker-Zeilen müssen data-de/data-en erhalten (R4-Fund: aktuell fehlend!)

### 4. web/src/pages/forum.astro — Kicker KOMPLETT ENTFERNEN (2 Stellen: Z.58 ausgeloggt und Z.67 eingeloggt):
- Die KOMPLETTE <p class="font-kicker ...">...t("kicker")...</p>-Zeile entfernen
- KEINE Ersatz-Zeile einfügen (der forum-Screen hat keinen Kicker)
- Auch die dazugehörigen mb-2-Abstände nicht kompensieren — einfach Zeile weg

### Referenz (Design-Absicht): In design/screens/chat-light-de-final.html, assistent-light-de-final.html, marktplatz-light-de-final.html, forum-light-de-final.html per cat die Titelbereiche ansehen.

## VERIFIKATION
- grep -n "kicker.chat\|kicker.marktplatz" web/src/lib/i18n.ts → beide Keys vorhanden
- grep -n "font-kicker\|text-kicker" web/src/pages/chat.astro web/src/pages/assistent.astro web/src/pages/marktplatz.astro web/src/pages/forum.astro → 0 Treffer
- grep -n "t(\"kicker\")" web/src/pages/forum.astro → 0 Treffer (komplett entfernt)
- grep -n "kicker" web/src/pages/marktplatz.astro → nur kicker.marktplatz-Aufrufe

## COMMIT
Ein Commit:
git add web/src/pages/chat.astro web/src/pages/assistent.astro web/src/pages/marktplatz.astro web/src/pages/forum.astro
git commit -m "Design: Kicker-Fix Teil 2 — chat/assistent/marktplatz Screen-Stil, forum Kicker entfernt"
