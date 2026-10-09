-- 0061: marketplace_messages UPDATE-Policy (P5/P6-Fix 09.10.2026)
-- Luecke: mode=read (read_at-Update durch Empfaenger) lieferte stets 0 Zeilen,
-- da keine UPDATE-Policy existierte -> Unread-Badges blieben dauerhaft stehen.
-- Fix 1: Empfaenger darf eigene eingehende Nachrichten updaten (to_user = auth.uid()).
-- Fix 2: Spalten-Lock — per User-Client ist NUR read_at aenderbar (kein Umschreiben
--        fremder Message-Bodies via direkten PostgREST-Zugriff).

DROP POLICY IF EXISTS marketplace_messages_update_recipient ON public.marketplace_messages;
CREATE POLICY marketplace_messages_update_recipient ON public.marketplace_messages
  FOR UPDATE TO authenticated
  USING (to_user = auth.uid())
  WITH CHECK (to_user = auth.uid());

REVOKE UPDATE ON public.marketplace_messages FROM authenticated;
GRANT UPDATE (read_at) ON public.marketplace_messages TO authenticated;
