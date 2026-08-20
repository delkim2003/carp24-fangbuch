-- 0005_catches_user_id_trigger.sql
-- SECURITY-HÄRTUNG (E2E-Test 20.08.):
-- Client darf user_id NICHT selbst setzen (IDOR-Risiko: User A könnte Fang für User B anlegen).
-- Trigger setzt user_id IMMER auf auth.uid() — Client-POSTs ohne user_id funktionieren, 
-- Manipulation wird überschrieben. Dies macht den Privatgewässer-Flow (Fang ohne waters_id)
-- erst möglich, weil der Client keine user_id mitschicken muss.

CREATE OR REPLACE FUNCTION public.set_catch_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  NEW.user_id := auth.uid();
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS set_catch_user_id_trg ON public.catches;
CREATE TRIGGER set_catch_user_id_trg
  BEFORE INSERT ON public.catches
  FOR EACH ROW
  EXECUTE FUNCTION public.set_catch_user_id();

COMMENT ON TRIGGER set_catch_user_id_trg ON public.catches IS 'Erzwingt user_id = auth.uid() — verhindert IDOR, ermöglicht Fang-POST ohne user_id';
