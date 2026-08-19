# carp24-fangbuch — Design System & Screens (D1 HELL v1)

## Brand
- Slogan: PASSION. FISHING. COMMUNITY.
- Produkt: Digitales Fangbuch für Karpfenangler (Mobile-First, PWA)
- Vibe: **Premium Tactical LIGHT** — angelehnt an unser Logo (Beige/Khaki + Oliv + Karpfen-Braun). Hell, warm, robust, nicht langweilig. Kein Dark-Theme.

## Logo
Das offizielle carp24-Logo: rundes Badge mit Karpfen + Slogan im Bogen + "carp24.org" unten. Dominante Logo-Farben: Beige/Khaki #CCCA9B, Olivgrün #6C7A57, Karpfen-Braun #B29A76. In jedem Screen sichtbar: groß auf Login/Onboarding/Profil, klein in der Top-Bar überall sonst. Nie verzerren, nie einfärben.

## Farben (Hell-Theme — aus BRANDING.md abgeleitet)
- Hell-Sand Basis-BG: #E8E0C8 (Hell-Beige, warm)
- Khaki-Karte: #CCCA9B (Logo-Ring-Farbe)
- Primary-Action: #6C7A57 (Olivgrün, Logo-Banner) · Hover: #8FA98A
- Text: #1A1F16 (fast schwarz, Kontrast ≥4.5:1 auf Beige)
- Sekundär-Text: #5A5A56 (Grau, neutral)
- Tarn-Akzent/Outline: #4A5338 (dunkles Oliv für 1px-Konturen)
- Karpfen-Braun (warme Akzente/CTA-Sekundär): #B29A76
- Wasser-Blau (dezent, Icons): #7B9496
- Weiß #FFFFFF nur für Foto-Karten/Overlays

Regel: HELL = #E8E0C8/#CCCA9B BG + #1A1F16 Text. Primary #6C7A57. Konturen 1px #4A5338. Kein schwarzer Vollbild-Hintergrund.

## Typo
- Headings: Inter bold · Body: Inter · Daten/Gewicht/Wetter: JetBrains Mono
- Labels mono uppercase mit Buchstabenabstand

## Design-Sprache
- Matte Flächen, warme Beige-/Khaki-Töne, Cards 4-8px Radius, 1px-Oliv-Konturen (#4A5338), dezente weiche Schatten (hell)
- Fotos: helle, freundliche Karpfen-/Wasser-Motive mit warmem Ton; Bild-Karten mit weißem/hellem Rahmen (Polaroid-artig)
- Dezente Wellen-Linien als Sektionstrenner (SVG 1px #7B9496, 30% Opacity), Wasser-Icons in #7B9496
- Data-Tags (z.B. GEWICHT 12,5 KG) mit 1px-Oliv-Border auf #E8E0C8, Status-Punkte (Grün #8FA98A / Sand-Warnung / Rot)
- Emotional: warm, premium, lebendig — "sonniger Morgen am Wasser", kein Militär-Dunkel

## Screens (Kern Phase 1, Mobile 390px)
S1 Onboarding: Logo groß, Slogan zweizeilig, 3 Beispiel-Fang-Karten (Foto + Gewicht mono), 50-Fänge-Tag (Oliv), LOS GEHT'S (Oliv)
S2 Login: Logo prominent, E-Mail+Passwort (weiße Felder, 1px-Oliv-Border), ANMELDEN (Oliv), REGISTRIEREN, Passwort-vergessen
S3 Fang-Formular: Chips (aktiv Oliv, inaktiv Weiß+Contour), Gewicht groß mono (Komma), Gewässer+Geo, Foto HEIC, Notiz, SPEICHERN (Oliv)
S4 Fangliste: Karten (Foto-Thumbnail, Gewicht mono groß, Art/Gewässer/Datum), Filter-Chips, FAB + FANG (Oliv), Empty-State mit Karpfen-Silhouette
S5 Fang-Detail: Foto groß (weißer Rahmen), Gewicht riesig mono, Data-Tags, Wetter-Karte (hell, ehrlich), BEARBEITEN (Khaki-Outline)/LÖSCHEN (Rot-Outline)
S6 Dashboard: 3 Statistik-Boxen (ANZAHL/DURCHSCHNITT/BEST, Khaki-Karten), Gewichts-Chart (Oliv-Linie auf hell), Monats-Balken, Top-3
S7 Profil: Logo/Avatar, Name/E-Mail, DATEN EXPORTIEREN (Art.20), DATENSCHUTZ, IMPRESSUM, Gefahrenzone KONTO LÖSCHEN (Rot-Outline)
S8 Paywall: Lock-Icon (Wasser-Blau), PRO WERDEN, 50-Grenze, Features mit Checkmarks, 4,99 €/MONAT, JETZT PRO (Oliv), FAGG-Hinweis

## Regeln
- Logo IMMER sichtbar · HELL-Basis, kein Dark-Vollbild · Keine Emojis · Mobile 390px · 44px Touch
