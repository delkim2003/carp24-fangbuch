-- 0056_report_mails.sql — B1c: Mail-Versand-Log (DSA Art. 16 Nachweis) fuer Admin Panel
-- Jeder Mail-Versand (Empfangsbestaetigung ack / Entscheidung decision) wird pro Report geloggt.

CREATE TABLE IF NOT EXISTS public.report_mails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.content_reports(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('ack','decision')),
  status text NOT NULL CHECK (status IN ('sent','failed')),
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS report_mails_report_id_idx ON public.report_mails (report_id);

ALTER TABLE public.report_mails ENABLE ROW LEVEL SECURITY;
-- Keine Policies = nur service_role (Admin-API) sieht/schreibt. User kriegen KEINEN Zugriff (Mail-Log = personenbezogen):
REVOKE ALL ON public.report_mails FROM anon, authenticated;
