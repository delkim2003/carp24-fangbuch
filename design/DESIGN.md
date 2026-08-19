# carp24-fangbuch — Design System & Screens (D0/D1)

## Brand
- Slogan: PASSION. FISHING. COMMUNITY.
- Produkt: Digitales Fangbuch für Karpfenangler (Mobile-First, PWA, offline-fähig)
- Look: Militär/Tactical — Grün + Sand, robust, reduziert, "am Wasser stationiert"

## Farbpalette (Militär: Grün + Sand)
- Dark-Olive (Primär-BG): #1A1F16 (dunkles Militärgrün)
- Olivgrün (Primary-Action): #6C7A57
- Sand (Text/Akzente): #D4C9A8
- Hell-Sand (Hell-Theme-BG): #E8E0C8
- Tarn-Akzent (Sekundär): #4A5338
- Coyote/Tarn-Braun: #8B7355 (warme Akzente)
- Tactical-Grau: #5A5A56 (neutral)
- Signal-Grün (Erfolg/Hover): #8FA98A

Regel: Dark = #1A1F16 BG + #D4C9A8 Text. Kontrast: Text auf Sand = #1A1F16 (>=4.5:1). Primary-Action = #6C7A57. Kein reines Schwarz/Weiß.

## Typografie
- Headings: serifenlos, fett, leicht technisch (Inter/Source Sans)
- Body: serifenlos, normal
- Daten/Mono (Gewicht, Wetter): system-mono — Tactical-Look
- Slogan exakt: PASSION. FISHING. COMMUNITY.

## Design-Sprache (Militär/Tactical)
- Eckige bis leicht abgerundete Cards (3-6px), keine weichen Blasen
- Dünne Konturen (1px, #6C7A57/#4A5338) statt Schatten
- Labels wie militärische Markierungen: mono, uppercase, Abstand
- Status: Grün = OK, Sand = Warnung, Rot = Fehler (minimal)
- Kein Gloss, kein Gradient — matte Flächen, robust
- Weißraum ja, aber "diszipliniert"

## Screens (Kern Phase 1, Mobile-First 390px, auch 768/1280)

### S1 — Login/Registrierung
E-Mail + Passwort, Registrierung-Link, Logo-Badge oben (Sand auf Oliv). Dark-Olive, minimale Konturen, Touch-Targets 44px+.

### S2 — Fangliste (Hauptansicht)
Liste: Gewicht (mono, fett), Fischart, Gewässer, Datum, Foto-Thumbnail. Filter (Art/Gewässer/Zeitraum), FAB "+ Fang" unten rechts (Oliv). Empty-State: "NOCH KEINE FÄNGE" (uppercase mono) + "Lege deinen ersten Fang an".

### S3 — Fang-Formular (<20s)
Chips Fischart (Karpfen, Spiegelkarpfen, Amur, Wels, Hecht, Andere) — aktiv = Oliv gefüllt. Gewicht (Komma-Parsing 12,5 kg, mono), Länge optional. Gewässer (Auswahl + manuell + Geo), Foto (HEIC→WebP, EXIF-Strip). Notiz (max 1000), Datum/Uhrzeit. Validierung sichtbar (Sand-Warnung), "SPEICHERN" prominent (Oliv, uppercase).

### S4 — Erfolg + Wetter
Erfolg: "FANG GESPEICHERT" (uppercase), grün. Wetter-Snapshot (Open-Meteo ≤24h) als Daten-Karte (mono, tactical), ehrlich gekennzeichnet, Fallback.

### S5 — Dashboard (Basis)
Gewichts-Verlauf (Linie Oliv/Sand), Monats-Chart, Top-Fänge. Statistiken (Anzahl, Durchschnitt, Best) als Daten-Boxen mit mono-Labels.

### S6 — Offline/Queue-Hinweis
Banner: "OFFLINE — Fang wird lokal gespeichert" (Sand, Kontur). Draft-Queue (warten: N Fänge) — mono.

### S7 — Profil/Konto
Anzeigename, E-Mail, Kontolöschung (DSGVO Art.17), Export (Art.20 Phase 1). Gefahrenzone (Löschen) in Rot-Braun, klar abgesetzt.

## Stil-Regeln
- Militär/Tactical: Grün + Sand, matte Flächen, Konturen statt Schatten, mono-Labels
- Minimalistisch: kein Overdesign, keine Emojis, keine Spielereien
- Mobile-First: 390px Basis, Finger-freundlich (min 44px Touch)
