-- Community-Board: is_public-Spalte + öffentliche Lesbarkeit
ALTER TABLE public.catches ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT false;

-- Öffentliche Fänge lesbar für eingeloggte User (Board-Ansicht)
CREATE POLICY "catches_public_read" ON public.catches
  FOR SELECT TO authenticated
  USING (is_public = true AND deleted_at IS NULL);

-- Öffentliche Fänge lesbar für anonyme User (falls gewünscht)
CREATE POLICY "catches_public_read_anon" ON public.catches
  FOR SELECT TO anon
  USING (is_public = true AND deleted_at IS NULL);
