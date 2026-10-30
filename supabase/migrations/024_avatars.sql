-- 024_avatars.sql
-- Bucket `avatars` para la foto de perfil. La app sube a '<user_id>/avatar.jpg'
-- (ProfileService.uploadAvatar) y guarda la URL pública en profiles.avatar_url,
-- pero el bucket nunca se creó: subir la foto fallaba siempre.
-- Lectura pública (la URL va en la app); cada usuario escribe solo su carpeta.
-- Solo existe en Supabase (storage); en Postgres sin storage no hace nada.
-- Seguro de re-ejecutar.

DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NULL THEN
    RETURN;
  END IF;
  -- 2 MB y solo imágenes: la app ya la reduce a 512 px antes de subir.
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
  ON CONFLICT (id) DO UPDATE
    SET public = true,
        file_size_limit = EXCLUDED.file_size_limit,
        allowed_mime_types = EXCLUDED.allowed_mime_types;

  -- Subir con upsert pide leer, crear y actualizar: las tres solo en '<uid>/...'.
  EXECUTE 'DROP POLICY IF EXISTS avatars_own_select ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS avatars_own_insert ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS avatars_own_update ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS avatars_own_delete ON storage.objects';
  EXECUTE $p$
    CREATE POLICY avatars_own_select ON storage.objects
      FOR SELECT TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
  EXECUTE $p$
    CREATE POLICY avatars_own_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
  EXECUTE $p$
    CREATE POLICY avatars_own_update ON storage.objects
      FOR UPDATE TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
      WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
  EXECUTE $p$
    CREATE POLICY avatars_own_delete ON storage.objects
      FOR DELETE TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
END $$;
