# BRIEFING — Task 1.11: Impressum + Datenschutz (carp24)

## 🔴 BAUE SOFORT — KEINE ANALYSE, kein Erkunden, kein langes Lesen. Dateien werden KOMPLETT ÜBERSCHRIEBEN.

## Ziel
Zwei statische Rechtsseiten `/impressum` und `/datenschutz` bauen (Beta-Pflicht) + Footer-Links aktivieren. Texte sind final — **wortwörtlich übernehmen**, kein Umschreiben.

## Deliverables (in web/)

### 1. `web/src/pages/impressum.astro` (NEU — KOMPLETT)
Layout wie andere Seiten: `import Layout from "../layouts/Layout.astro"` + `<Layout title="Carp24 – Impressum">`. Inhalt (NICHT verlinkt mit anderer Navigation — kein active-Prop):

**Impressum** (text-headline-lg text-primary mb-lg) — dann Abschnitte in editorialem Stil (max-w-3xl, text-body-md text-on-surface-variant, Abschnitts-Headlines font-label-sm uppercase tracking-widest text-on-surface):

1. **MEDIENINHABER & VERANTWORTLICHER** — Philipp Schlemmer, Ungerdorf 279/4, 8200 Gleisdorf, Österreich
2. **KONTAKT** — E-Mail: info@einfach-online.dev · Web: carp24.org
3. **UNTERNEHMENSGEGENSTAND** — Betrieb eines digitalen Fangbuchs („Carp24") für Karpfenangler: Aufzeichnung von Fängen, Gewässern und Wetterbedingungen, Statistik-Auswertung sowie Community-Funktionen.
4. **HINWEIS GEMÄSS § 25 MEDIENG** — Inhaber der Website: Philipp Schlemmer (Anschrift siehe oben).
5. **HAFTUNG FÜR INHALTE** — Die Inhalte dieser Website wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen. Als Diensteanbieter sind wir für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich.
6. **HAFTUNG FÜR LINKS** — Unser Angebot enthält Links zu externen Websites Dritter, auf deren Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen. Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich.
7. **URHEBERRECHT** — Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem Urheberrecht. Beiträge Dritter sind als solche gekennzeichnet. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers.
8. **EU-STREITSCHLICHTUNG** — Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: https://ec.europa.eu/consumers/odr/. Unsere E-Mail-Adresse findest du oben im Impressum.
9. **VERBRAUCHERSTREITBEILEGUNG** — Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.

### 2. `web/src/pages/datenschutz.astro` (NEU — KOMPLETT)
Layout wie oben. Inhalt:

**Datenschutzerklärung** (text-headline-lg text-primary mb-lg) — Abschnitte:

1. **VERANTWORTLICHER** — Philipp Schlemmer, Ungerdorf 279/4, 8200 Gleisdorf, Österreich. Kontakt: info@einfach-online.dev
2. **WELCHE DATEN VERARBEITEN WIR?**
   - Kontodaten: E-Mail-Adresse, Anzeigename (für Registrierung/Login)
   - Fangbuch-Daten: Art, Gewicht, Länge, Gewässer, Koordinaten (nur private Gewässer), Notizen
   - Community-Daten: Forenbeiträge, Chat-Nachrichten, Marktplatz-Inserate
   - Abo-Daten (optional): Zahlungsstatus über Stripe (wir speichern keine Kreditkartendaten)
3. **WOFÜR UND AUF WELCHER GRUNDLAGE?** (Tabelle: Zweck | Rechtsgrundlage)
   - Vertragserfüllung (Fangbuch, Community) | Art. 6(1)(b) DSGVO
   - Sicherheit & Betrieb (Logs, Monitoring) | Art. 6(1)(f) DSGVO
   - KI-Chatbot (optional, mit Zustimmung) | Art. 6(1)(a) DSGVO
   - Werbung/Analyse (optional, mit Zustimmung) | Art. 6(1)(a) DSGVO
4. **WER BEKOMMT DEINE DATEN?**
   - Andere Nutzer (nur was du öffentlich teilst: Forum, Marktplatz)
   - Dienstleister: Google (Backups, verschlüsselt), später Stripe (Zahlungen), MailerSend (E-Mails), Mistral (KI-Chatbot) — jeweils mit AVV
   - Keine Datenverkäufe.
5. **SPEICHERDAUER & LÖSCHUNG**
   - Daten bleiben bis zur Kontolöschung
   - Kontolöschung = vollständige Anonymisierung aller Inhalte (Automatik)
   - Steuerlich relevante Abodaten: 3 Jahre
   - Du kannst Löschung jederzeit im Dashboard oder per E-Mail anfordern
6. **DEINE RECHTE** — Auskunft (Art. 15) · Berichtigung (Art. 16) · Löschung (Art. 17) · Einschränkung (Art. 18) · Datenübertragbarkeit (Art. 20) · Widerspruch (Art. 21) · Beschwerde bei der österreichischen Datenschutzbehörde (Art. 77). Kontakt für alle Rechte: info@einfach-online.dev
7. **COOKIES & EINWILLIGUNG** — Beim ersten Besuch erscheint ein Consent-Banner (Klaro): Notwendig (immer aktiv): Login, Sicherheit · Statistik (optional): anonyme Nutzungsanalyse · Marketing (optional): Werbung · KI-Funktionen (optional): Chatbot. Einwilligung kann jederzeit widerrufen werden.
8. **SICHERHEIT** — TLS-Verschlüsselung, RLS-Datenbankzugriff, verschlüsselte Backups, regelmäßige Überwachung.

### 3. `web/src/components/Footer.astro` (PATCH — Links aktivieren)
- `href="#"` bei Impressum → `/impressum`
- `href="#"` bei Datenschutz → `/datenschutz`
- AGB-Link (falls vorhanden mit `#`): auf `/impressum` zeigen lassen ODER Label entfernen (kein eigener AGB-Task in 1B) — wenn der Footer einen AGB-Link hat, lasse ihn auf `/impressum` zeigen und ändere das Label NICHT (oder wenn klar getrennt: AGB ebenfalls auf /impressum).

## ARBEITSBEREICH (STRENG)
- Du arbeitest NUR in: /mnt/projekte/carp24-fangbuch/web/
- Du liest NUR: web/src/components/Footer.astro
- VERBOTEN: andere Verzeichnisse, git, Server starten, curl, npm install, Build ausführen
- KEINE Analyse-Ausflüge. Baue sofort.

## WICHTIG
- **Jede neue Datei MUSS vollständig geschrieben werden. Keine Diffs, keine Snippets.**
- Texte WORTWÖRTLICH übernehmen (Rechtstexte, keine kreativen Freiheiten).
- Kein `<script>` nötig (statische Seiten).

## VERIFIKATION (NUR Statik — keine Server)
```bash
grep -c "Philipp Schlemmer" /mnt/projekte/carp24-fangbuch/web/src/pages/impressum.astro   # MUSS ≥1
grep -c "Ungerdorf 279/4" /mnt/projekte/carp24-fangbuch/web/src/pages/impressum.astro      # MUSS ≥1
grep -c "info@einfach-online.dev" /mnt/projekte/carp24-fangbuch/web/src/pages/impressum.astro  # MUSS ≥1
grep -c "Art. 6(1)(b) DSGVO" /mnt/projekte/carp24-fangbuch/web/src/pages/datenschutz.astro  # MUSS ≥1
grep -c "Datenschutzbehörde" /mnt/projekte/carp24-fangbuch/web/src/pages/datenschutz.astro  # MUSS ≥1
grep -c 'href="/impressum"' /mnt/projekte/carp24-fangbuch/web/src/components/Footer.astro   # MUSS ≥1
grep -c 'href="/datenschutz"' /mnt/projekte/carp24-fangbuch/web/src/components/Footer.astro # MUSS ≥1
grep -rn "%PUBLIC_\|%VITE_" /mnt/projekte/carp24-fangbuch/web/src/   # MUSS 0
```
Server-Start + Routen-Check macht der Hauptagent NACH deinem Lauf.
