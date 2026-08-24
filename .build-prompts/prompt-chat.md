## 🚫 ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/pages/chat.astro, design/screens/chat-light-de-final.html, web/src/styles/global.css
- VERBOTEN: andere Projekte, /tmp lesen, git-Operationen (außer add+commit), statistik.astro, Shell-Schleifen, Bash-Subshells, Analyse-Ausflüge
- KEINE Server-Starts, KEIN npm run build in diesem Run

## 🚫 WRITE-TOOL IST KAPUTT — NUTZE ES NICHT!
✅ STATTDESSEN: Schreibe Dateien per SHELL-Befehl: cat > /pfad/zur/datei << 'ENDOFFILE' ... ENDOFFILE

## AUFGABE: chat.astro — Chat-Bubble-Deltas (Screen chat-light-de-final.html)

Lies ZUERST per cat design/screens/chat-light-de-final.html (Input Z.212, Bubbles Z.171-192, Button Z.213) und übernimm die Design-Absicht 1:1. Der Kicker ist BEREITS umgestellt (nicht anfassen).

### Deltas (WICHTIG alle umsetzen):
1. **Senden-Button (Z.86):** `font-nav-item text-nav-item` → `font-label-sm text-label-sm` (Screen)
2. **Input (Z.80):** `rounded border-b bg-surface-container-lowest` → `rounded-full border border-primary/40 bg-surface/50` (Screen)
3. **Bubble-Name (Z.153):** `font-label-sm text-label-sm uppercase tracking-widest text-secondary` → `font-mono text-[11px] uppercase text-primary` (Screen)
4. **Bubble-Shape (KOSMETISCH, falls einfach):** eigene Bubbles `rounded-xl` → `rounded-xl rounded-tr-sm`, andere `rounded-xl` → `rounded-xl rounded-tl-sm`; optional `shadow-sm` ergänzen

NUR diese Änderungen am Chat-UI. Nachrichten-Logik (Send, Realtime) unangetastet.

## VERIFIKATION
grep -c "rounded-full border border-primary/40\|font-mono text-\[11px\] uppercase text-primary\|font-label-sm text-label-sm" web/src/pages/chat.astro → ≥3

## COMMIT
Ein Commit: git add web/src/pages/chat.astro && git commit -m "Design: chat LIGHT-Screen-1:1 (Button/Input/Bubble-Namen)"
