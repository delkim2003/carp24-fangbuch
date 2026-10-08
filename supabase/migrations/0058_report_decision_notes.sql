-- 0058_report_decision_notes.sql
-- Fuegt optionale Admin-Begruendungen (Notizen) zu Meldungsentscheidungen hinzu.

ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS resolved_note text;

ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS dismissed_note text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'content_reports_resolved_note_check'
      AND conrelid = 'public.content_reports'::regclass
  ) THEN
    ALTER TABLE public.content_reports
      ADD CONSTRAINT content_reports_resolved_note_check
      CHECK (char_length(resolved_note) <= 1000);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'content_reports_dismissed_note_check'
      AND conrelid = 'public.content_reports'::regclass
  ) THEN
    ALTER TABLE public.content_reports
      ADD CONSTRAINT content_reports_dismissed_note_check
      CHECK (char_length(dismissed_note) <= 1000);
  END IF;
END
$$;

-- ROLLBACK:
-- ALTER TABLE public.content_reports DROP COLUMN IF EXISTS resolved_note, dismissed_note;