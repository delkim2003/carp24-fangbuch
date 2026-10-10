-- 0060_marketplace_messaging.sql
-- Nachrichtenzentrale: marketplace_messages reaktivieren (P2.1 des Plans 2026-10-08_173243)
-- 1) FK auf AKTUELLE Item-Tabelle fixen (vorher: Alt-Tabelle marketplace_listings)
-- 2) read_at + Längen-CHECK + Indizes
-- 3) Altbestand aus marketplace_contacts migrieren (idempotent)

-- 1) FK-Fix
ALTER TABLE marketplace_messages DROP CONSTRAINT IF EXISTS marketplace_messages_listing_id_fkey;
ALTER TABLE marketplace_messages
  ADD CONSTRAINT marketplace_messages_listing_id_fkey
  FOREIGN KEY (listing_id) REFERENCES marketplace_items(id) ON DELETE CASCADE;

-- 2) read_at + CHECK + Indizes
ALTER TABLE marketplace_messages ADD COLUMN IF NOT EXISTS read_at timestamptz;

ALTER TABLE marketplace_messages DROP CONSTRAINT IF EXISTS marketplace_messages_message_check;
ALTER TABLE marketplace_messages
  ADD CONSTRAINT marketplace_messages_message_check
  CHECK (char_length(message) >= 3 AND char_length(message) <= 2000);

CREATE INDEX IF NOT EXISTS idx_marketplace_messages_to_user_read
  ON marketplace_messages (to_user, read_at);
CREATE INDEX IF NOT EXISTS idx_marketplace_messages_thread
  ON marketplace_messages (listing_id, from_user, to_user);

-- 3) Altbestand marketplace_contacts -> marketplace_messages (idempotent)
INSERT INTO marketplace_messages (listing_id, from_user, to_user, message, created_at)
SELECT c.item_id, c.from_user, c.to_user, c.message, c.created_at
FROM marketplace_contacts c
WHERE EXISTS (SELECT 1 FROM marketplace_items i WHERE i.id = c.item_id)
  AND NOT EXISTS (
    SELECT 1 FROM marketplace_messages m
    WHERE m.listing_id = c.item_id
      AND m.from_user = c.from_user
      AND m.to_user = c.to_user
      AND m.created_at = c.created_at
  );
