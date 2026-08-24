-- 0035_trips_user_id_index.sql — Performance-Index für trips.user_id
--
-- RLS-Policies filtern nach user_id = auth.uid(); ohne Index erfolgt
-- Seq-Scan bei vielen Trips pro User. Index beschleunigt SELECT/UPDATE/DELETE.
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
