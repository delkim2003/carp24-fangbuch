-- ============================================================
-- 0015_storage_catch_photos.sql
-- FIX F1+F2 aus Full-Stack-Audit Runde 1 (21.08.2026)
-- Storage-Bucket 'catch-photos' existierte NICHT (Foto-Upload defekt)
-- DSGVO: Bucket PRIVAT (public=false), Zugriff nur eigene Fotos via RLS-Policies
-- Pfad-Konvention: {user_id}/{uuid}.jpg → Policies prüfen (storage.foldername(name))[1] = auth.uid()
-- EXIF-GPS-Strip passiert im Client (Canvas-Re-Encode) — siehe fang-erfassen.astro-Fix
-- ============================================================

-- Bucket anlegen (privat)
INSERT INTO storage.buckets (id, name, public)
VALUES ('catch-photos', 'catch-photos', false)
ON CONFLICT (id) DO NOTHING;

-- Eigene Fotos hochladen (Pfad muss mit eigener user_id beginnen)
DROP POLICY IF EXISTS catch_photos_insert_own ON storage.objects;
CREATE POLICY catch_photos_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'catch-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Eigene Fotos lesen
DROP POLICY IF EXISTS catch_photos_select_own ON storage.objects;
CREATE POLICY catch_photos_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'catch-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Eigene Fotos ersetzen
DROP POLICY IF EXISTS catch_photos_update_own ON storage.objects;
CREATE POLICY catch_photos_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'catch-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Eigene Fotos löschen
DROP POLICY IF EXISTS catch_photos_delete_own ON storage.objects;
CREATE POLICY catch_photos_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'catch-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- anon/öffentlich: KEINE Policies → Standard-Deny (RLS ist auf storage.objects aktiv)
-- SELECT count(*) FROM storage.buckets WHERE id='catch-photos';  -- Verifikation
-- SELECT policyname FROM pg_policies WHERE schemaname='storage' AND tablename='objects';
