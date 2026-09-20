# 🧪 Carp24 Beta Test Plan
**Stand:** 20.09.2026 | **URL:** https://carp24.org (LIVE) | **DEV:** http://100.93.250.103:8094

---

## STATUS LEGEND
- ⬜ = Nicht getestet
- ✅ = Bestanden
- ❌ = Fehler gefunden
- ⚠️ = Teilweise OK (Hinweise beachten)

---

## 1. AUTHENTIFIZIERUNG

### 1.1 Login
| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 1 | `/login` laden | Login-Formular zeigt E-Mail + Passwort | ⬜ | ⬜ |
| 2 | Falsches Passwort | Fehlermeldung "Ungültige Anmeldedaten" | ⬜ | ⬜ |
| 3 | Korrekter Login (info@einfach-online.dev) | Redirect zu `/dashboard` | ⬜ | ⬜ |
| 4 | Session-Cookie gesetzt | `sb-carp24-auth-token` vorhanden | ⬜ | ⬜ |

### 1.2 Registrierung
| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 5 | `/login` → Registrierung wechseln | Registrierungsformular | ⬜ | ⬜ |
| 6 | Neue Registrierung | E-Mail-Bestätigung erforderlich (oder Auto-Confirm) | ⬜ | ⬜ |

### 1.3 Passwort vergessen
| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 7 | `/passwort-vergessen` laden | Formular mit E-Mail | ⬜ | ⬜ |
| 8 | E-Mail eingeben | Reset-Link gesendet (oder Hinweis) | ⬜ | ⬜ |

### 1.4 Logout
| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 9 | Logout klicken | Redirect zu `/login`, Cookie gelöscht | ⬜ | ⬜ |

### 1.5 Session-Schutz
| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 10 | Nicht eingeloggt → `/dashboard` | Redirect zu `/login` | ⬜ | ⬜ |
| 11 | Nicht eingeloggt → `/faenge` | Redirect zu `/login` | ⬜ | ⬜ |
| 12 | Nicht eingeloggt → `/board` | Redirect zu `/login` ODER öffentlich | ⬜ | ⬜ |

---

## 2. FANG ERSTELLEN (`/fang-erfassen`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 13 | Seite laden | Formular mit allen Feldern | ⬜ | ⬜ |
| 14 | Fischart wählen (Chips) | SPIEGEL, LEDER, SCHUPPEN, AMUR, ANDERE | ⬜ | ⬜ |
| 15 | Gewicht eingeben | Dezimalzahl (z.B. 12.5) | ⬜ | ⬜ |
| 16 | Länge eingeben | cm | ⬜ | ⬜ |
| 17 | Gewässer eingeben | Autocomplete-Vorschläge | ⬜ | ⬜ |
| 18 | Köder eingeben | Text | ⬜ | ⬜ |
| 19 | Montage eingeben | Text | ⬜ | ⬜ |
| 20 | Datum/Zeit ändern | Date-Picker funktioniert | ⬜ | ⬜ |
| 21 | GPS-Koordinaten | Auto-Lokalisierung oder Karte | ⬜ | ⬜ |
| 22 | Wassertemperatur eingeben | °C | ⬜ | ⬜ |
| 23 | Notizen eingeben | Textarea | ⬜ | ⬜ |
| 24 | **Foto aufnehmen (Mobile)** | Kamera öffnet sich | ⬜ | ⬜ |
| 25 | **Foto aus Galerie** | Datei-Upload funktioniert | ⬜ | ⬜ |
| 26 | **Foto-Upload** | WebP-Konvertierung, Upload zu Supabase Storage | ⬜ | ⬜ |
| 27 | **Foto-Vorschau** | Bild wird nach Upload angezeigt | ⬜ | ⬜ |
| 28 | Catch & Release Checkbox | Toggle funktioniert | ⬜ | ⬜ |
| 29 | Öffentlich teilen Checkbox | Toggle funktioniert | ⬜ | ⬜ |
| 30 | **Speichern** | Fang wird erstellt, Redirect zu `/faenge` | ⬜ | ⬜ |
| 31 | **Wetter-Daten** | Temp, Wind, Luftdruck, Wetter-Text, Mondphase | ⬜ | ⬜ |
| 32 | 50-Fang-Limit (Free) | Hinweis "Limit erreicht" nach 50 Fängen | ⬜ | ⬜ |
| 33 | Mobile Responsive | Alle Felder erreichbar, nichts überlappt | ⬜ | ⬜ |

---

## 3. FANG-LISTE (`/faenge`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 34 | Seite laden | Eigene Fänge werden gelistet | ⬜ | ⬜ |
| 35 | **Fotos angezeigt** | Bilder laden korrekt (Signed URLs) | ⬜ | ⬜ |
| 36 | Fischart + Gewicht | Korrekt angezeigt | ⬜ | ⬜ |
| 37 | Datum formatiert | Lesbares Format | ⬜ | ⬜ |
| 38 | Gewässer-Name | Angezeigt oder "Unbekanntes Gewässer" | ⬜ | ⬜ |
| 39 | Klick auf Fang → Detail | `/faenge/[id]` öffnet sich | ⬜ | ⬜ |
| 40 | Mobile Responsive | Cards layout korrekt | ⬜ | ⬜ |

---

## 4. FANG-DETAIL (`/faenge/[id]`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 41 | Seite laden | Alle Fang-Daten angezeigt | ⬜ | ⬜ |
| 42 | **Foto angezeigt** | Bild lädt korrekt | ⬜ | ⬜ |
| 43 | Wetter-Daten | Temp, Wind, Druck, Mond, Wetter-Text | ⬜ | ⬜ |
| 44 | Koordinaten | Auf Karte oder als Text | ⬜ | ⬜ |
| 45 | **Bearbeiten-Button** | "BEARBEITEN" oben rechts sichtbar | ⬜ | ⬜ |
| 46 | "Zurück" → Liste | `/faenge` | ⬜ | ⬜ |
| 47 | Mobile Responsive | Layout korrekt | ⬜ | ⬜ |

---

## 5. FANG BEARBEITEN (`/faenge/[id]/bearbeiten`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 48 | Seite laden | Formular mit vorausgefüllten Werten | ⬜ | ⬜ |
| 49 | **Bestehendes Foto** | Wird angezeigt (Signed URL) | ⬜ | ⬜ |
| 50 | Felder ändern | Alle Felder editierbar | ⬜ | ⬜ |
| 51 | **Foto ersetzen** | Neues Foto hochladen möglich | ⬜ | ⬜ |
| 52 | Catch & Release | Checkbox funktioniert | ⬜ | ⬜ |
| 53 | Öffentlich teilen | Checkbox funktioniert | ⬜ | ⬜ |
| 54 | **Speichern** | Änderungen gespeichert, Redirect Detail | ⬜ | ⬜ |
| 55 | RLS-Schutz | Nur eigene Fänge editierbar | ⬜ | ⬜ |
| 56 | Mobile Responsive | Formular korrekt | ⬜ | ⬜ |

---

## 6. COMMUNITY-BOARD (`/board`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 57 | Seite laden | Öffentliche Fänge gelistet | ⬜ | ⬜ |
| 58 | **Fotos angezeigt** | Bilder laden (Server-side Signed URLs) | ⬜ | ⬜ |
| 59 | Anzahl "Öffentliche Fänge" | Korrekte Zahl | ⬜ | ⬜ |
| 60 | "+ Neuer Fang" Button | Link zu `/fang-erfassen` | ⬜ | ⬜ |
| 61 | Klick auf Fang → Detail | `/faenge/[id]` | ⬜ | ⬜ |
| 62 | "Melden" Button | Report-Formular öffnet sich | ⬜ | ⬜ |
| 63 | Mobile Responsive | Grid → 1 Spalte auf Mobile | ⬜ | ⬜ |

---

## 7. PREMIUM (`/premium`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 64 | Seite laden | Pricing 4,99€/Mo, 49,99€/Jahr | ⬜ | ⬜ |
| 65 | Free vs Pro Tabelle | Features vergleichbar | ⬜ | ⬜ |
| 66 | CTA Button | "Jetzt upgraden" oder Stripe-Link | ⬜ | ⬜ |
| 67 | Mobile Responsive | Layout korrekt | ⬜ | ⬜ |

---

## 8. DASHBOARD (`/dashboard`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 68 | Seite laden | Statistiken, Charts | ⬜ | ⬜ |
| 69 | Fang-Statistik | Gewichtsverlauf, Fangzahlen | ⬜ | ⬜ |
| 70 | Premium-Lock | Premium-Features gesperrt für Free-User | ⬜ | ⬜ |

---

## 9. STATISTIK (`/statistik`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 71 | Seite laden | Charts & Daten | ⬜ | ⬜ |
| 72 | Gewichtsverlauf | Line-Chart | ⬜ | ⬜ |
| 73 | Bedingungen | Wetter-Korrelation | ⬜ | ⬜ |

---

## 10. PROFIL (`/profil`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 74 | Seite laden | Benutzerdaten | ⬜ | ⬜ |
| 75 | Display-Name ändern | Wird gespeichert | ⬜ | ⬜ |
| 76 | Passwort ändern | Funktioniert | ⬜ | ⬜ |
| 77 | Account löschen | Bestätigung → Löschung | ⬜ | ⬜ |

---

## 11. TRIPS (`/trips`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 78 | Seite laden | Trip-Liste | ⬜ | ⬜ |
| 79 | Neuen Trip erstellen | Formular | ⬜ | ⬜ |
| 80 | Trip zuweisen | Fang → Trip | ⬜ | ⬜ |

---

## 12. AI-ASSISTENT (`/assistent`, `/chat`)

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 81 | `/assistent` laden | Chat-Interface | ⬜ | ⬜ |
| 82 | Frage stellen | AI-Antwort | ⬜ | ⬜ |
| 83 | Premium-Limit | Free: 5/Monat, Pro: unlimited | ⬜ | ⬜ |

---

## 13. RECHTLICHES

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 84 | `/impressum` | Impressum vollständig | ⬜ | ⬜ |
| 85 | `/datenschutz` | DSGVO-konform | ⬜ | ⬜ |
| 86 | `/agb` | AGB vorhanden | ⬜ | ⬜ |
| 87 | Footer-Links | Alle 3 verlinkt | ⬜ | ⬜ |

---

## 14. NAVIGATION & LAYOUT

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 88 | Header/Sidebar | Logo, Navigation, Menü | ⬜ | ⬜ |
| 89 | Footer | Links, Copyright | ⬜ | ⬜ |
| 90 | 404-Seite | `/nonexistent` → 404 | ⬜ | ⬜ |
| 91 | Light Mode | Standard-Theme | ⬜ | ⬜ |
| 92 | i18n DE/EN | Sprachumschaltung | ⬜ | ⬜ |

---

## 15. PERFORMANCE & SICHERHEIT

| # | Test | Erwartung | LIVE | DEV |
|---|------|-----------|------|-----|
| 93 | Lighthouse Mobile | Performance > 80 | ⬜ | ⬜ |
| 94 | HTTPS | Zertifikat gültig | ⬜ | ⬜ |
| 95 | CSP-Header | Keine unsafe-eval | ⬜ | ⬜ |
| 96 | CSRF-Schutz | checkOrigin: false (Supabase Proxy) | ⬜ | ⬜ |
| 97 | RLS-Policies | Nur eigene Daten sichtbar/editierbar | ⬜ | ⬜ |
| 98 | Service-Client | Nur server-side, nie im Browser | ⬜ | ⬜ |

---

## 16. KNOWN ISSUES (bereits gefixt, verifizieren!)

| # | Issue | Fix | Verifiziert LIVE? |
|---|-------|-----|-------------------|
| K1 | Foto-Display (Signed URL) | PUBLIC_SUPABASE_URL | ⬜ |
| K2 | Foto-Upload 403 | checkOrigin: false | ⬜ |
| K3 | publish_catch Ambiguität | DB Migration | ⬜ |
| K4 | is_published Spalte fehlt | DB Migration | ⬜ |
| K5 | catch_release Spalte fehlt | DB Migration | ⬜ |
| K6 | Edit-Seite Speichern (RLS) | API mit Service Client | ⬜ |
| K7 | Board-Fotos | Server-side Signed URLs | ⬜ |
| K8 | Weather 401 | Service Client für DB | ⬜ |
| K9 | Mobile Fischart/Gewässer | mb-2xl Gap | ⬜ |

---

## TEST-REIHENFOLGE (Empfohlen)

1. **Auth** (1-12) — Basis, alles andere hängt davon ab
2. **Fang erstellen** (13-33) — Kern-Feature
3. **Fang-Liste + Detail** (34-47) — Anzeige
4. **Fang bearbeiten** (48-56) — NEU, kritisch
5. **Board** (57-63) — Community
6. **Known Issues** (K1-K9) — Verifizieren
7. **Rest** (Dashboard, Stats, Premium, Legal)

---

## TEST-TOOLS

- **Mobile:** Echtes iPhone/Android (kein Emulator)
- **Browser:** Safari iOS + Chrome Android
- **Network:** 5G/WiFi + Slow 3G (Foto-Upload)
- **Accounts:** info@einfach-online.dev (Free, 29 Fänge)

---

*Generiert: 20.09.2026 16:55 CEST*
