# SEO & GEO (Stand 10/2026)

Umgesetzt im SEO+GEO-Train (Commit `0d699f5`), audit- und gegenbewiesen.

## Umgesetzt

- **Kanonisierung (SBA):** alle internen `href` in einheitlicher Slash-Form (61 Stellen inkl. JS-Selektoren wie `a[href="/profil"]`), `canonical` + `og:url` normalisiert = **eine URL-Form pro Seite** (keine self-canonical-Duplikate mehr). Middleware-Exempt-Checks laufen über `normalizedPath` — `/login/` liefert 200 statt 302 (das war ein echter SEO-Bug).
- **llms.txt** (`public/llms.txt`, verlinkt per `<link rel="llms.txt">`) = KI-Crawler-Index: Answer-First-Kurzantworten zu Mondphase, Fangplätzen, CSV-Import, Voraussetzungen, Kündigung, Datenexport. **Nur belegte Fakten** (Adresse aus Impressum, Preise werden verlinkt statt beziffert, Offline-Fähigkeit korrekt: Internetverbindung nötig).
- **FAQPage JSON-LD** auf der Startseite = 1:1-Spiegel der 6 sichtbaren Q&A-Paare („Fragen, die am Wasser aufkommen"). Strukturierte Daten spiegeln IMMER sichtbaren Text — nie erfinden!
- **Unique Descriptions:** 23/23 Seiten mit individuellen `description`-Meta (vorher 19 Duplikate).
- **Open Graph / Twitter:** `og-carp24.png` (1200×630, Badge auf #0B0C0B) als Share-Image (SVG funktioniert bei WhatsApp/FB nicht zuverlässig), `og:locale` de_AT, `og:image:alt`, twitter:card `summary_large_image`.
- **JSON-LD `SoftwareApplication`** (Layout, ohne `offers` — keine Preise erfinden = kein Fake-Rich-Result) neben Organization/WebSite.
- **Sitemap** (`public/sitemap.xml`, manuell): 7 öffentliche URLs (Start, Login, Impressum, Datenschutz, AGB, Über, Premium). **Bewusst ohne auth-gated Seiten** — die zeigen nur das Gate-h1, indexieren bringt nichts.
- **Favicons:** Badge-Branding (`favicon.svg` + `favicon.ico` 16/32/48) statt Astro-Scaffold.
- **Titles:** 23/23 unique (war schon gut).
- **robots.txt:** solide (Allow Login/Impressum, Disallow /admin /api /profil /login-gated-Bereiche /_next /static).

## Prinzipien (für künftige Inhalte)

1. JSON-LD spiegelt sichtbaren Text (Manifest-Regel: divergierende Quellen = Verstoß).
2. „exactly one h1" pro SSR-Request — Ternary-Gates (`{!session ? <h1>Gate</h1> : <h1>Content</h1>}`) sind korrekt, auch wenn der Quelltext zwei h1 zeigt.
3. GEO = Answer-First + llms.txt + Frage-Headings — Content-Design bleibt unangetastet.
4. Wartungsmodus: robots.txt + sitemap.xml bleiben 200 (Exempt = wichtige Ausnahme!).

## Offen / Beobachtet

- `support@carp24.de` (FAQ) vs. Domain `.org` — Adressen-Klärung steht aus (llms.txt/FAQ spiegeln die Quelle, nicht „repariert").
- Social-Shares Live prüfen (og-Image-Rendern bei WhatsApp/Telegram).
- Zukunft: Blog/Content-Sektion mit Question-Headings (Fragen aus der Zielgruppe) wäre der nächste GEO-Booster.
