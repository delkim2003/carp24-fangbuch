-- 0002_seed_waters.sql
-- Seed: Top-25 Karpfen-Gewässer Österreich (idempotent)
-- Koordinaten unverändert aus seed_waters_reference.sql

INSERT INTO public.waters (name, lat, lng, type, public, owner_id)
SELECT v.name, v.lat, v.lng, v.type, v.public, NULL
FROM (VALUES
  ('Neusiedler See',        47.833, 16.750, 'lake',      true),
  ('Silbersee Villach',     46.609, 13.905, 'lake',      true),
  ('Faaker See',            46.580, 13.920, 'lake',      true),
  ('Ossiacher See',         46.670, 13.970, 'lake',      true),
  ('Wörthersee',            46.620, 14.160, 'lake',      true),
  ('Traunsee',              47.870, 13.790, 'lake',      true),
  ('Attersee',              47.910, 13.540, 'lake',      true),
  ('Mondsee',               47.820, 13.380, 'lake',      true),
  ('Wolfgangsee',           47.750, 13.400, 'lake',      true),
  ('Hallstätter See',       47.570, 13.660, 'lake',      true),
  ('Grundlsee',             47.630, 13.830, 'lake',      true),
  ('Altausseer See',        47.640, 13.790, 'lake',      true),
  ('Zeller See',            47.320, 12.800, 'lake',      true),
  ('Mittersill-Stausee',    47.280, 12.480, 'reservoir', true),
  ('Donau Altwasser Linz',  48.290, 14.280, 'river',     true),
  ('Donau Altwasser Wien',  48.200, 16.430, 'river',     true),
  ('Marchfeldkanal',        48.260, 16.570, 'river',     true),
  ('Lobau Altwässer',       48.180, 16.510, 'river',     true),
  ('Mur Altarm Graz',       47.070, 15.450, 'river',     true),
  ('Güssinger Teich',       47.060, 16.320, 'pond',      true),
  ('Pöllauer Teich',        47.300, 15.830, 'pond',      true),
  ('Fischbacher Teiche',    47.310, 15.650, 'pond',      true),
  ('Kumberger Teich',       47.120, 15.950, 'pond',      true),
  ('Stubenberger See',      47.240, 15.790, 'pond',      true),
  ('Kiesgrube Pischelsdorf',47.170, 15.840, 'gravelpit', true)
) AS v(name, lat, lng, type, public)
WHERE NOT EXISTS (
  SELECT 1 FROM public.waters w WHERE w.name = v.name
);
