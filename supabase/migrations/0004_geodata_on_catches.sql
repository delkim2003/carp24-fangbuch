-- 0004_geodata_on_catches.sql
-- DENKFEHLER-KORREKTUR (Philipp, 20.08.2026):
-- Geodaten gehören an den FANG (Primärquelle für Wetter + Statistik), NICHT nur ans Gewässer.
-- Viele Gewässer sind privat (Vereinsteiche, gepachtete Seen) — existieren nicht in OSM/Photon.
-- => catches.lat/lng = Pflichtquelle; waters bleibt OPTIONALER Komfort (Seed + Suche).

ALTER TABLE public.catches
  ADD COLUMN IF NOT EXISTS lat numeric,
  ADD COLUMN IF NOT EXISTS lng numeric,
  ADD COLUMN IF NOT EXISTS water_name text;

COMMENT ON COLUMN public.catches.lat IS 'Geodaten des Fangs (GPS des Geräts ODER manuelle Eingabe/Karten-Pick) — Primärquelle für Wetter-Hook (Open-Meteo)';
COMMENT ON COLUMN public.catches.lng IS 'Geodaten des Fangs — Primärquelle für Wetter-Hook (Open-Meteo)';
COMMENT ON COLUMN public.catches.water_name IS 'Gewässer-Name als Freitext (auch privat) — waters.id optional, wenn öffentlich/erfasst';

-- CHECK: lat/lng entweder beide gesetzt oder keins (kein Halb-Zustand)
ALTER TABLE public.catches
  DROP CONSTRAINT IF EXISTS catches_latlng_pair;
ALTER TABLE public.catches
  ADD CONSTRAINT catches_latlng_pair CHECK (
    (lat IS NULL AND lng IS NULL) OR (lat IS NOT NULL AND lng IS NOT NULL)
  );

-- Index für Statistik/Wetter-Gruppierung nach Gewässer-Name
CREATE INDEX IF NOT EXISTS catches_water_name_idx ON public.catches (water_name);
