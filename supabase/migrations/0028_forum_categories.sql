ALTER TABLE public.forum_threads ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'allgemein';
