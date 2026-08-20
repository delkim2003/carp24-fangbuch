# Seed-Referenz: Top-25 Karpfen-Gewässer Österreich (Task 1.5)
# Koordinaten aus OpenStreetMap-Näherung (gerundet) — für Start-Seed, Nutzer ergänzen via Photon
# Tabellenname: public.waters (id uuid DEFAULT gen_random_uuid(), name text, lat numeric, lng numeric, type text, public boolean DEFAULT false, owner_id uuid NULL)
# type = 'lake' | 'river' | 'gravelpit' | 'pond' | 'reservoir'

INSERT INTO public.waters (name, lat, lng, type, public, owner_id) VALUES
('Neusiedler See',        47.833, 16.750, 'lake',      true, NULL),
('Silbersee Villach',     46.609, 13.905, 'lake',      true, NULL),
('Faaker See',            46.580, 13.920, 'lake',      true, NULL),
('Ossiacher See',         46.670, 13.970, 'lake',      true, NULL),
('Wörthersee',            46.620, 14.160, 'lake',      true, NULL),
('Traunsee',              47.870, 13.790, 'lake',      true, NULL),
('Attersee',              47.910, 13.540, 'lake',      true, NULL),
('Mondsee',               47.820, 13.380, 'lake',      true, NULL),
('Wolfgangsee',           47.750, 13.400, 'lake',      true, NULL),
('Hallstätter See',       47.570, 13.660, 'lake',      true, NULL),
('Grundlsee',             47.630, 13.830, 'lake',      true, NULL),
('Altausseer See',        47.640, 13.790, 'lake',      true, NULL),
('Zeller See',            47.320, 12.800, 'lake',      true, NULL),
('Mittersill-Stausee',    47.280, 12.480, 'reservoir', true, NULL),
('Donau Altwasser Linz',  48.290, 14.280, 'river',     true, NULL),
('Donau Altwasser Wien',  48.200, 16.430, 'river',     true, NULL),
('Marchfeldkanal',        48.260, 16.570, 'river',     true, NULL),
('Lobau Altwässer',       48.180, 16.510, 'river',     true, NULL),
('Mur Altarm Graz',       47.070, 15.450, 'river',     true, NULL),
('Güssinger Teich',       47.060, 16.320, 'pond',      true, NULL),
('Pöllauer Teich',        47.300, 15.830, 'pond',      true, NULL),
('Fischbacher Teiche',    47.310, 15.650, 'pond',      true, NULL),
('Kumberger Teich',       47.120, 15.950, 'pond',      true, NULL),
('Stubenberger See',      47.240, 15.790, 'pond',      true, NULL),
('Kiesgrube Pischelsdorf',47.170, 15.840, 'gravelpit', true, NULL);

-- Seed-Fänge (18) für Statistik-Studio (Task 1.5 / 1.10a) — user_id NULL? NEIN: catches.user_id NOT NULL!
-- WICHTIG: catches braucht user_id (NOT NULL) + species (species_enum) + catch_ts + weight_kg + photos (ARRAY NOT NULL) + draft + client_uuid
-- => Seed-Fänge NACH einem echten Test-User anlegen (via API-Signup), dann SQL-INSERT mit dessen user_id.
