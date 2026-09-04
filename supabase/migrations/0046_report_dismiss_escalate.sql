-- Report-Management: Dismiss/Escalate-Felder + escalated-Status
ALTER TABLE public.content_reports DROP CONSTRAINT IF EXISTS content_reports_status_check;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_status_check
  CHECK (status IN ('open','resolved','dismissed','escalated'));
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS dismissed_at timestamptz;
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS dismissed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS escalated_at timestamptz;
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS escalated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;