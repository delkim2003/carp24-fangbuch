# 🎣 Carp24 — Premium/Monetization System Design

> **Erstellt:** 05.09.2026  
> **Zielgruppe:** Deutschsprachige Karpfenangler (AT/DE)  
> **Entwickler:** Philipp (Solo, Einzelfirma einfach-online.dev)  
> **Stack:** Astro 5 SSR + Supabase Self-Hosted + Stripe  
> **Status:** ALPHA — Stripe-Integration vorhanden (Checkout + Webhook), Pro-Gating roh

---

## 1. Executive Summary

Carp24 hat ein rudimentäres Premium-System: `profiles.is_pro` (bool), Stripe-Checkout für ein Einzel-Abo, Webhook, eine Premium-Seite mit 3 Feature-Karten. Die `subscriptions`-Tabelle wird nicht vom Webhook befüllt. Es gibt kein Feature-Gating in Pages/API, kein Billing-Portal, kein Trial, keine Staffelung.

Dieser Entwurf definiert ein **vollständiges, produktionsreifes Monetarisierungssystem** für den deutschsprachigen Markt mit Fokus auf:
- **Einfachheit** (Solo-Developer — kein Team-/Family-Plan)
- **DSGVO-Konformität** (Stripe-AVV, keine Speicherung von Zahlungsdaten)
- **Angler-typische Wertargumente** (Statistik-Studio, KI-Assistent, Export, Marktplatz)
- **Typisch deutscher Premium-Preis** (4,99 €/Monat, 49,99 €/Jahr)

---

## 2. Preismodell (2-Tier)

| | **FREE** | **PRO** |
|---|---|---|
| **Preis** | € 0 | € 4,99/Monat · € 49,99/Jahr (≈ 4,17 €/Mo) |
| **Fänge erfassen** | ✅ unbegrenzt | ✅ unbegrenzt |
| **Dashboard** | ✅ | ✅ |
| **Statistik (Basics)** | ✅ (letzte 30 Tage) | ✅ (alle Daten) |
| **Wetterdaten** | ✅ pro Fang | ✅ pro Fang |
| **Fotos** | max 3 pro Fang | ✅ unbegrenzt |
| **Gewässer-Verwaltung** | ✅ | ✅ |
| **Fangbuch-Export (CSV)** | ✅ | ✅ |
| **CSV-Import** | ❌ (500/Limit Free) | ✅ (5000/Lauf) |
| **Jahres-Rückblick** | ❌ | ✅ |
| **Trips** | ❌ | ✅ |
| **Community-Board** | ✅ lesen · ❌ teilen | ✅ lesen + teilen |
| **Forum** | ✅ lesen · ❌ schreiben | ✅ lesen + schreiben |
| **Chat** | ❌ | ✅ |
| **Statistik-Studio (Wetter-Muster, Luftdruck, Wind, Mondphase)** | ❌ | ✅ vollständig |
| **KI-Assistent** | ❌ | ✅ (50 Anfragen/Tag) |
| **Marktplatz** | ❌ | ✅ |
| **Badges** | ✅ | ✅ |
| **Push-Benachrichtigungen** | ❌ | ✅ |
| **Datenexport (JSON)** | ✅ | ✅ |
| **Account-Löschung** | ✅ | ✅ |

### 2.1 Pricing Rationale

- **4,99 €/Monat** entspricht dem unteren Ende deutscher Nischen-SaaS (Angler-Portal ~5–10 €)
- **Jahres-Abo ~16% Rabatt** (49,99 statt 59,88) reduziert Churn
- **Kein Lifetime / kein Family** — Solo-Dev kann Support nicht skalieren
- **Kein kostenloser Trial** (zunächst) — der Free-Tier ist bereits sehr generös (unbegrenzte Fänge). Später: 14-Tage-Trial via Stribe `trial_period_days`

---

## 3. Datenmodell (Erweiterungen)

### 3.1 Bestehend: `public.profiles`

```sql
-- Bereits vorhanden
is_pro     boolean NOT NULL DEFAULT false
role       text    NOT NULL DEFAULT 'USER' CHECK (role IN ('USER','MODERATOR','ADMIN'))
```

### 3.2 Bestehend: `public.subscriptions` (wird reaktiviert)

```sql
-- Bereits vorhanden, aber NICHT vom Webhook befüllt
CREATE TABLE public.subscriptions (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid        UNIQUE NOT NULL REFERENCES public.profiles(id),
  plan                 public.plan NOT NULL DEFAULT 'FREE',
  stripe_customer      text,                -- Stripe customer_id
  status               text        CHECK (status IN ('ACTIVE','CANCELED','PAST_DUE','INCOMPLETE')),
  cancel_at_period_end boolean,
  active_until         timestamptz,          -- current_period_end
  trial_ends_at        timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
```

**Fix:** Der Webhook muss bei `checkout.session.completed` NICHT nur `profiles.is_pro` setzen, sondern auch `subscriptions` upserten.

### 3.3 Neu: `public.subscription_events` (Erweiterung von `stripe_events`)

```sql
-- Bestehende Tabelle um Felder erweitern
ALTER TABLE public.stripe_events
  ADD COLUMN IF NOT EXISTS user_id       uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS details       jsonb;
```

### 3.4 Neu: `public.pro_features` (Feature-Flags pro User/Tier — optional)

Nicht nötig — Feature-Gating erfolgt über `is_pro`-bool + Serverseiten-Check.  
Für künftige A/B-Tests oder Feature-Rollouts: Feature-Flag-Tabelle analog `feature_flags` aber user-spezifisch.

### 3.5 Neu: Migration 0050 — `subscriptions` reaktivieren

Erforderliche Migration (siehe Anhang A):  
- `subscriptions`-Trigger bei `profiles`-Erstellung (Default-Eintrag FREE)  
- Index auf `subscriptions.stripe_customer`  
- Webhook schreibt in `subscriptions` statt nur in `profiles`

---

## 4. Feature-Gating (Implementierung)

### 4.1 Strategie

Dreistufig:
1. **Server-seitig (Astro SSR)** — Pages + API-Routen prüfen `profile.is_pro`  
2. **Client-seitig** — UI blendet Pro-Features aus oder zeigt Locks  
3. **Supabase RLS** — Für DB-Zugriff (optional, z.B. Chat-Nachrichten nur für Pro)

### 4.2 Helper: `lib/subscription.ts`

Erstelle `/web/src/lib/subscription.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";

export type PlanTier = "FREE" | "PRO" | "ADMIN";

export interface SubscriptionInfo {
  tier: PlanTier;
  isPro: boolean;
  isAdmin: boolean;
  subscription?: {
    stripeCustomer: string | null;
    status: string | null;
    cancelAtPeriodEnd: boolean;
    activeUntil: string | null;
  };
}

export async function getSubscriptionInfo(
  supabase: SupabaseClient,
  userId: string
): Promise<SubscriptionInfo> {
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_pro, role")
    .eq("id", userId)
    .single();

  const isAdmin = profile?.role === "ADMIN";
  const isPro = isAdmin || profile?.is_pro === true;
  const tier: PlanTier = isAdmin ? "ADMIN" : isPro ? "PRO" : "FREE";

  let subscription = undefined;
  if (isPro && !isAdmin) {
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("stripe_customer, status, cancel_at_period_end, active_until")
      .eq("user_id", userId)
      .single();
    if (sub) {
      subscription = {
        stripeCustomer: sub.stripe_customer,
        status: sub.status,
        cancelAtPeriodEnd: sub.cancel_at_period_end,
        activeUntil: sub.active_until,
      };
    }
  }

  return { tier, isPro, isAdmin, subscription };
}

// Feature-Check: Kompakt für Pages + Middleware
export function requirePro(profile: { is_pro: boolean; role: string }): boolean {
  return profile.role === "ADMIN" || profile.is_pro === true;
}
```

### 4.3 Feature-Gating pro Page/Feature

| Feature | Gate | Wo geprüft |
|---------|------|-----------|
| `/statistik` Insights-Tiefe | `isPro || isAdmin` | Server (Astro page) — max 30 Tage bei Free |
| `/rueckblick` | `requirePro()` | Server — Redirect zu `/premium` bei Free |
| `/trips` | `requirePro()` | Server — Redirect zu `/premium` bei Free |
| `/chat` | `requirePro()` | Server — Redirect zu `/premium` bei Free |
| `/assistent` KI-Anfragen | `requirePro()` | Server — API-Endpoint prüft |
| `/marktplatz` anzeigen/verkaufen | `requirePro()` | Server — API-Endpoint prüft |
| `POST /api/ai/chat` | `requirePro()` | Server — 403 wenn Free |
| `POST /api/push/subscribe` | `requirePro()` | Server — 403 wenn Free |
| Forum schreiben (neuer Thread/Post) | `requirePro()` | API-Route prüft |
| Board teilen (public toggle) | `requirePro()` | API-Route prüft |
| CSV-Import > 500 Zeilen | `requirePro()` | API-Route prüft |
| Fotos > 3 pro Fang | `requirePro()` | API-Route prüft |
| Chat-UI / Chat-Senden | `requirePro()` | Server + Client |

### 4.4 Middleware Pattern

In `middleware.ts` — **nur für Premium-Seiten**, nicht für Kern-Features:

```ts
// Premium-Seiten, die eine Weiterleitung erfordern
const premiumPages = ["/rueckblick", "/trips", "/chat"];

if (premiumPages.includes(pathname)) {
  const profile = await getProfile(supabase, userId);
  if (!requirePro(profile)) {
    return Astro.redirect("/premium");
  }
}
```

Für API-Routen → einfache 403-Response:

```ts
if (!requirePro(profile)) {
  return new Response(JSON.stringify({ error: "Premium-Feature." }), {
    status: 403,
  });
}
```

---

## 5. Stripe-Integration (Produktionsreif)

### 5.1 Bestehende Probleme fixen

| Problem | Fix |
|---------|-----|
| `checkout.ts` hat nur `STRIPE_PRICE_ID` (env) — kein Multi-Plan | `.env` → `STRIPE_MONTHLY_PRICE_ID` + `STRIPE_YEARLY_PRICE_ID` |
| Webhook schreibt nur `profiles.is_pro` — nie in `subscriptions` | Webhook → `subscriptions` upsert mit allen Stripe-Details |
| Kein Billing-Portal | Neuer Endpoint `POST /api/stripe/portal` |
| Kein `customer.subscription.updated`-Grace-Period-Handling | Webhook → `subscriptions.status` aktualisieren |
| Keine idempotente Webhook-Wiederholung mit Details | `stripe_events.details` jsonb speichert Payload |

### 5.2 Benötigte Env-Vars

```bash
# Stripe (Produktion)
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_MONTHLY_PRICE_ID=price_monthly_...
STRIPE_YEARLY_PRICE_ID=price_yearly_...

# Stripe (Test)
# STRIPE_SECRET_KEY=sk_test_...
# STRIPE_WEBHOOK_SECRET=whsec_test_...
# STRIPE_MONTHLY_PRICE_ID=price_test_monthly_...
# STRIPE_YEARLY_PRICE_ID=price_test_yearly_...
```

### 5.3 Endpoints

#### `POST /api/stripe/checkout`
- **Input:** `{ priceId: "monthly" | "yearly" }`
- **Output:** `{ url: string }` → redirect zu Stripe Checkout
- **Verbesserung:** `allow_promotion_codes: true`, `customer_creation: "always"`, `tax_id_collection: { enabled: true }`

#### `POST /api/stripe/portal`
- **Input:** `{}`
- **Output:** `{ url: string }` → redirect zu Stripe Customer Portal
- **Neu:** Erstellt Billing-Portal-Session für Abo-Verwaltung (Upgrade/Downgrade/Kündigung)

#### `POST /api/stripe/webhook`
- **Events:** `checkout.session.completed` → `customer.subscription.updated` → `customer.subscription.deleted` → `invoice.paid` → `invoice.payment_failed`
- **Idempotenz:** via `stripe_events.id` (bereits vorhanden)
- **Audit-Log:** Jedes Event mit user_id + details in `stripe_events` speichern

### 5.4 Stripe-Produktkonfiguration (im Stripe-Dashboard)

```
Produkt: "Carp24 Pro"
  - Monat: 4,99 € (preis_monthly_ID)
  - Jahr: 49,99 € (preis_yearly_ID)
```

---

## 6. UI/UX: Premium-Seite (überarbeiten)

### 6.1 Aktuelle Premium-Seite (`premium.astro`)

Hat 3 Feature-Karten (KI, Marktplatz, Insights). **Muss erweitert werden:**

**Neue Premium-Seite (Wireframe):**

```
┌─────────────────────────────────────────────────────┐
│                    PREMIUM                          │
│                  Dein Status: FREE                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ Monat    │  │ Jahr     │  │          │         │
│  │ 4,99 €   │  │ 49,99 €  │  │ POPULÄR  │         │
│  │ mtl.     │  │ ≈4,17/Mo │  │           │         │
│  │ [JETZT]  │  │ [JETZT]  │  │           │         │
│  └──────────┘  └──────────┘  └──────────┘         │
│                                                     │
│  Feature-Vergleich (Tabelle):                      │
│  ┌──────────────────┬──────┬──────┐               │
│  │ Feature          │ FREE │ PRO  │               │
│  ├──────────────────┼──────┼──────┤               │
│  │ Fänge erfassen   │  ✅  │ ✅   │               │
│  │ Statistik (30d)  │  ✅  │ ✅   │               │
│  │ Jahres-Rückblick │  ❌  │ ✅   │               │
│  │ KI-Assistent     │  ❌  │ ✅   │               │
│  │ Chat             │  ❌  │ ✅   │               │
│  │ Marktplatz       │  ❌  │ ✅   │               │
│  │ Trips            │  ❌  │ ✅   │               │
│  │ ...              │  ❌  │ ✅   │               │
│  └──────────────────┴──────┴──────┘               │
│                                                     │
│  [Bei Free: Upgrade-Button]                         │
│  [Bei Pro: "Du bist Premium" + Portal-Link]         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 6.2 Premium-Badge in Header

- **Free-User:** Kein Badge
- **Pro-User:** Kleiner PRO-Badge (amber/gold) neben dem Namen
- **Admin:** ADMIN-Badge (rot/tertiary)

### 6.3 Lock-UI-Komponente

Neue Komponente `PremiumLock.astro`:

```astro
---
interface Props {
  feature: string; // i18n-key
  isPro: boolean;
}
---
{#if !isPro}
  <div class="relative">
    <div class="blur-sm pointer-events-none"><slot /></div>
    <div class="absolute inset-0 flex items-center justify-center bg-surface/80">
      <a href="/premium" class="...">
        🔒 Premium-Feature — Jetzt freischalten
      </a>
    </div>
  </div>
{/if}
```

---

## 7. Admin-Bereich: Revenue-Dashboard (erweitern)

### 7.1 Aktuell (`/admin/revenue`)
- 3 KPIs (Pro-User, Free-User, Pro-Quote)
- Stripe-Event-Übersicht
- Pro-User-Liste

### 7.2 Erweiterung

| Metrik | Quelle | Implementierung |
|--------|--------|-----------------|
| **MRR (Monthly Recurring Revenue)** | Stripe-API → `stripe.subscriptions.list({status: "active"})` × Preis | Neue API-Route `/api/admin/mrr` |
| **Churn-Rate (letzte 30 Tage)** | `subscriptions` cancelled/letzten Monat aktiv | SQL `WHERE status = 'CANCELED' AND updated_at > now() - 30d` |
| **Conversion-Rate** | Pro-User ÷ Gesamt-User × 100 | Bereits vorhanden |
| **Revenue-Chart (Monatsverlauf)** | Gruppierte Stripe-Invoice-Daten | Aggregiert aus `stripe_events` |
| **Kündigungsgrund-Sammlung** | Stripe-Checkout `cancel_url` mit Survey | N/A (später) |

---

## 8. E-Mail-Benachrichtigungen (Transaktional)

### 8.1 Automatisierte E-Mails

| Event | Empfänger | Inhalt |
|-------|-----------|--------|
| Abo aktiviert | User | "Dein Carp24 Pro ist aktiv!" |
| Abo gekündigt | User | "Dein Abo läuft am [Datum] aus." |
| Zahlung fehlgeschlagen | User | "Zahlung fehlgeschlagen — aktualisiere deine Zahlungsdaten." |
| Trial endet in 3 Tagen | User | "Dein Test läuft bald ab." (später) |

**Hinweis:** E-Mails vorerst via Stripe (Stripe sendet selbst Rechnungs-E-Mails) + einfache `console.log`-Benachrichtigung im Webhook. Später: SMTP über den bestehenden Mailer.

---

## 9. DSGVO/Rechtliche Aspekte

| Thema | Status | Aktion |
|-------|--------|--------|
| **AVV Stripe** | ❌ Fehlt | Stripe-DPA abschließen (Stripe bietet Standard-DPA) |
| **UST** | ⚠️ Kleinunternehmer | Philipp ist österr. Kleinunternehmer (§ 6 Abs. 1 Z 27 UStG) → Netto-Preise + "Kein Ausweis der USt" |
| **Preisangabe** | ⚠️ Prüfen | "4,99 €/Monat inkl. gesetzlicher USt" — abhängig von Kleinunternehmer-Regel |
| **Widerrufsrecht** | ⚠️ Prüfen | Bei digitalen Diensten erlischt Widerruf mit Zustimmung (§ 312g Abs. 2 Nr. 1 BGB/§ 18 Abs. 1 Z 11 FAGG) |
| **PCI-DSS** | ✅ Kein Problem | Stripe Checkout = kein Karten-Durchgriff |
| **Datenspeicherung** | ✅ Keine Zahlungsdaten | Stripe managed alles |

---

## 10. Implementierungs-Reihenfolge

| Phase | Tasks | Aufwand |
|-------|-------|---------|
| **0** | DB-Migration: subscriptions reaktivieren, Index, Trigger | 0,5 Tag |
| **1** | Stripe-Fixes: Multi-Price Checkout, Portal-Endpoint, Webhook schreibt subscriptions | 1 Tag |
| **2** | Libs: `subscription.ts`, `requirePro`-Helper | 0,5 Tag |
| **3** | Feature-Gating: Premium-Seiten (rueckblick, trips, chat, assistent, marktplatz, forum-write) | 1 Tag |
| **4** | Premium-Seite: Vergleichstabelle, Jahres/Monats-Toggle, Portal-Link | 1 Tag |
| **5** | Premium-UI: Lock-Komponenten, Badges, Header-Indikator | 0,5 Tag |
| **6** | Admin-Revenue: MRR, Churn, Revenue-Chart | 1 Tag |
| **7** | E-Mail-Benachrichtigungen (Webhook → User-E-Mail via Supabase) | 0,5 Tag |
| **8** | DSGVO: AVV Stripe, USt-Hinweise | Administrativ |
| **9** | E2E-Tests: Checkout → is_pro, Portal → Kündigung, Feature-Locks | 0,5 Tag |
| | **Gesamt** | **~6,5 Tage** |

---

## 11. Risiken & Entscheidungen

| Risiko | Wahrscheinlichkeit | Mitigation |
|--------|-------------------|------------|
| Stripe nicht konfigurierbar (fehlende Keys) | Mittel | `.env`-Placeholder + 503-Fallback (bereits vorhanden) |
| Churn zu hoch bei 4,99 € | Niedrig | Preis ist unterer Marktpreis; Jahres-Rabatt reduziert Churn |
| Free-User fühlen sich eingeschränkt | Mittel | Free-Tier ist generös (unbegrenzte Fänge); Locks sind klar kommuniziert |
| AVV-Stripe nicht rechtzeitig | Mittel | Stripe-DPA ist Standard-Formular; sofort abschließen |
| USt/Kleinunternehmer korrekt? | Niedrig | Philipp's Steuerberater klärt |

---

## Anhang A: Migration 0050 SQL (Skizze)

```sql
-- 0050_subscriptions_v2.sql
-- Reaktiviert die subscriptions-Tabelle und integriert sie in den Premium-Flow

-- 1. Sicherstellen, dass subscriptions existiert
-- (bereits in 0001_init.sql erstellt, aber sicherheitshalber)

-- 2. Default-Subscription für alle existierenden profiles
INSERT INTO public.subscriptions (user_id, plan, status)
SELECT p.id, 'FREE', 'ACTIVE'
FROM public.profiles p
WHERE p.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.subscriptions s WHERE s.user_id = p.id);

-- 3. Trigger: Bei neuem profile → subscriptions-Eintrag
CREATE OR REPLACE FUNCTION public.handle_new_profile()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id, plan, status)
  VALUES (NEW.id, 'FREE', 'ACTIVE');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created ON public.profiles;
CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_profile();

-- 4. Index für Stripe-Customer-ID
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer
  ON public.subscriptions (stripe_customer);

-- 5. RLS: User kann eigene subscription lesen
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own" ON public.subscriptions
  FOR SELECT
  USING (auth.uid() = user_id);

-- 6. Funktion: Pro-Status für schnelle Middleware-Checks
-- (kein Full-Join nötig, profiles.is_pro reicht)
```

---

## Anhang B: Stripe Webhook v2 (Skizze)

```ts
// Kernlogik für den erweiterten Webhook

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const email = session.customer_email || session.customer_details?.email;
  const subscription = session.subscription as string;
  const customer = session.customer as string;

  if (!email) return;

  const user = await findUserByEmail(email, supabaseAdmin);
  if (!user) return;

  // Subscription-Details von Stripe abrufen
  const sub = await stripe.subscriptions.retrieve(subscription);

  await supabaseAdmin.from("profiles").update({ is_pro: true }).eq("id", user.id);
  
  await supabaseAdmin.from("subscriptions").upsert({
    user_id: user.id,
    plan: "PRO",
    stripe_customer: customer,
    status: mapStatus(sub.status),
    cancel_at_period_end: sub.cancel_at_period_end ?? false,
    active_until: sub.current_period_end
      ? new Date(sub.current_period_end * 1000).toISOString()
      : null,
    updated_at: new Date().toISOString(),
  });
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  // Suche via customer → email → user
  // Aktualisiere subscriptions.status + active_until
  // Setze is_pro=false wenn canceled/past_due/unpaid
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  // is_pro → false
  // subscriptions.status → 'CANCELED'
}

async function handleInvoicePaid(invoice: Stripe.Invoice) {
  // Optional: Letzten Zahlungserfolg loggen
}

async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  // `subscriptions.status` → 'PAST_DUE'
  // E-Mail-Benachrichtigung planen
}
```

---

## Anhang C: `POST /api/stripe/portal` (Skizze)

```ts
import Stripe from "stripe";

export const POST = async ({ request, cookies }) => {
  // ... Auth-Check (wie in checkout.ts) ...

  const stripe = new Stripe(secretKey);

  // Customer aus der subscription ermitteln
  const { data: sub } = await supabase
    .from("subscriptions")
    .select("stripe_customer")
    .eq("user_id", user.id)
    .single();

  if (!sub?.stripe_customer) {
    return new Response(JSON.stringify({ error: "Kein aktives Abo." }), { status: 400 });
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: sub.stripe_customer,
    return_url: `${origin}/profil`,
  });

  return new Response(JSON.stringify({ url: session.url }), { status: 200 });
};
```

---

## Änderungsnachweis

| Datum | Version | Änderung |
|-------|---------|----------|
| 05.09.2026 | 1.0 | Erstentwurf — Vollständiges Premium/Monetization-Design |