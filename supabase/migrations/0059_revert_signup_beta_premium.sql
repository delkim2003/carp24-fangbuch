-- 0059_revert_signup_beta_premium.sql
-- Korrektur 08.10. (Philipp): "neue User sollen NICHT automatisch Premium sein".
-- Entfernt den Signup-Trigger aus 0057 wieder. Neue User = free (kein Auto-Premium).
-- Marktplatz-Zugang wird ENTKOPPELT davon geregelt (siehe Entscheidung "alle frei").
-- Bestehende source='admin'-Subs bleiben unangetastet.

DROP TRIGGER IF EXISTS trg_signup_beta_premium ON public.profiles;
DROP FUNCTION IF EXISTS public.grant_signup_beta_premium();
DELETE FROM public.subscriptions WHERE source = 'trial';

-- ROLLBACK (zurueck zu Auto-Premium): 0057_signup_beta_premium.sql erneut ausfuehren.
