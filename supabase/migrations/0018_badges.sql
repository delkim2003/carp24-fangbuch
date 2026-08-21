-- 0018_badges.sql — Gamification (A3)
CREATE TABLE IF NOT EXISTS public.badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text NOT NULL,
  icon text NOT NULL,
  sort int NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.user_badges (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id uuid NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, badge_id)
);

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "badges_read_all" ON public.badges FOR SELECT USING (true);
CREATE POLICY "user_badges_select_own" ON public.user_badges FOR SELECT TO authenticated USING (user_id = auth.uid());
GRANT SELECT ON public.badges TO anon, authenticated;
GRANT SELECT ON public.user_badges TO authenticated;

INSERT INTO public.badges (code, name, description, icon, sort) VALUES
  ('erster_fang',    'Erster Fang',       'Deinen ersten Fang erfasst',            '01', 1),
  ('zehn_faenge',    'Zehn Fänge',        '10 Fänge im Fangbuch',                  '10', 2),
  ('hundert_kg',     '100 Kilo',          '100 kg Gesamtgewicht',                  '100', 3),
  ('nachtfischer',   'Nachtfischer',      'Ein Fang zwischen 22 und 5 Uhr',        '☾', 4),
  ('fuenf_gewaesser','Vielwasser',        'Fänge an 5 verschiedenen Gewässern',    '≈', 5),
  ('sieben_fangtage','Woche voll',        'An 7 verschiedenen Tagen gefischt',     '7d', 6),
  ('foto_profi',     'Foto-Profi',        'Deinen ersten Fang mit Foto',           '✧', 7),
  ('regenfischer',   'Regenfischer',      'Ein Fang bei Tiefdruck (< 1000 hPa)',   '☂', 8),
  ('jahr_mitglied',  'Jahresmitglied',    '1 Jahr Mitglied bei CARP24',            '©', 9),
  ('import_pionier', 'Import-Pionier',    'Fänge per CSV importiert',              '⇢', 10)
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.check_badges(p_user_id uuid, p_imported boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_new jsonb := '[]'::jsonb;
  v_uid uuid := auth.uid();
  v_badge uuid;
BEGIN
  IF v_uid IS NULL OR v_uid <> p_user_id THEN
    RAISE EXCEPTION 'not authenticated or mismatch';
  END IF;

  -- erster_fang
  IF EXISTS (SELECT 1 FROM public.catches c WHERE c.user_id = p_user_id AND c.deleted_at IS NULL) THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'erster_fang';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','erster_fang');
    END IF;
  END IF;

  -- zehn_faenge
  IF (SELECT COUNT(*) FROM public.catches c WHERE c.user_id = p_user_id AND c.deleted_at IS NULL) >= 10 THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'zehn_faenge';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','zehn_faenge');
    END IF;
  END IF;

  -- hundert_kg
  IF (SELECT COALESCE(SUM(c.weight_kg), 0) FROM public.catches c WHERE c.user_id = p_user_id AND c.deleted_at IS NULL) >= 100 THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'hundert_kg';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','hundert_kg');
    END IF;
  END IF;

  -- nachtfischer
  IF EXISTS (
    SELECT 1 FROM public.catches c
    WHERE c.user_id = p_user_id AND c.deleted_at IS NULL
      AND EXTRACT(HOUR FROM c.catch_ts AT TIME ZONE 'Europe/Vienna') IN (22, 23, 0, 1, 2, 3, 4)
  ) THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'nachtfischer';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','nachtfischer');
    END IF;
  END IF;

  -- fuenf_gewaesser
  IF (SELECT COUNT(DISTINCT c.water_name) FROM public.catches c WHERE c.user_id = p_user_id AND c.deleted_at IS NULL AND c.water_name IS NOT NULL) >= 5 THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'fuenf_gewaesser';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','fuenf_gewaesser');
    END IF;
  END IF;

  -- sieben_fangtage
  IF (SELECT COUNT(DISTINCT c.catch_ts::date) FROM public.catches c WHERE c.user_id = p_user_id AND c.deleted_at IS NULL) >= 7 THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'sieben_fangtage';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','sieben_fangtage');
    END IF;
  END IF;

  -- foto_profi
  IF EXISTS (
    SELECT 1 FROM public.catches c
    WHERE c.user_id = p_user_id AND c.deleted_at IS NULL
      AND c.photos IS NOT NULL AND array_length(c.photos, 1) > 0
  ) THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'foto_profi';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','foto_profi');
    END IF;
  END IF;

  -- regenfischer: weather->>'pressure_hpa' < 1000
  IF EXISTS (
    SELECT 1 FROM public.catches c
    WHERE c.user_id = p_user_id AND c.deleted_at IS NULL
      AND c.weather IS NOT NULL
      AND (c.weather->>'pressure_hpa')::numeric < 1000
  ) THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'regenfischer';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','regenfischer');
    END IF;
  END IF;

  -- jahr_mitglied
  IF EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user_id AND u.created_at < now() - interval '365 days'
  ) THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'jahr_mitglied';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','jahr_mitglied');
    END IF;
  END IF;

  -- import_pionier
  IF p_imported THEN
    SELECT id INTO v_badge FROM public.badges WHERE code = 'import_pionier';
    IF v_badge IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges ub WHERE ub.user_id = p_user_id AND ub.badge_id = v_badge) THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, v_badge);
      v_new := v_new || jsonb_build_object('code','import_pionier');
    END IF;
  END IF;

  RETURN v_new;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.check_badges(uuid, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.check_badges(uuid, boolean) TO authenticated;
COMMENT ON FUNCTION public.check_badges(uuid, boolean) IS 'Gamification: vergibt fehlende Badges, gibt neu verdiente als JSONB zurueck. EXECUTE nur authenticated.';
