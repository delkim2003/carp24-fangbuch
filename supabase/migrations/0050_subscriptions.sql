-- 0050_subscriptions.sql — Subscriptions-Tabelle für Stripe-Abonnements (bereits vorhanden)
-- Speichert den aktuellen Abo-Status jedes PRO-Users.
-- Wird vom Stripe-Webhook (webhook.ts) über upsert geschrieben.
--
-- Schema:
--   id                uuid PK (gen_random_uuid)
--   user_id           uuid FK→profiles(id), UNIQUE (ein Abo pro User)
--   plan              plan enum ('FREE'|'PRO'), default 'FREE'
--   stripe_customer   text (Stripe customer ID)
--   status            text, CHECK (ACTIVE|CANCELED|PAST_DUE)
--   cancel_at_period_end boolean
--   active_until      timestamptz (current_period_end aus Stripe)
--   created_at        timestamptz default now()
--   updated_at        timestamptz default now() (trigger set_updated_at)

-- Diese Migration wird als Referenz vorgehalten. Die Tabelle existiert bereits
-- und wurde durch eine frühere Migration oder manuelle Erstellung angelegt.
-- Bei Ausführung auf einer frischen Datenbank wird die Tabelle angelegt:
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan plan NOT NULL DEFAULT 'FREE',
  stripe_customer text,
  status text CHECK (status = ANY (ARRAY['ACTIVE'::text, 'CANCELED'::text, 'PAST_DUE'::text])),
  cancel_at_period_end boolean,
  active_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_user_id_idx ON public.subscriptions(user_id);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.subscriptions FROM anon, authenticated;
GRANT ALL ON public.subscriptions TO service_role;

-- Trigger: updated_at automatisch setzen (via bestehender Funktion)
DROP TRIGGER IF EXISTS subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();