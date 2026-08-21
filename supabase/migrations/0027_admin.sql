-- Admin-Moderation: resolved-Infos für content_reports
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS resolved_at timestamptz;
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
