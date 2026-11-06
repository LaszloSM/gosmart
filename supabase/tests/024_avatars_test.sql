-- supabase/tests/024_avatars_test.sql
-- Requiere: stub. Crea un `storage` mínimo (lo que Supabase trae de fábrica:
-- buckets, objects con RLS y foldername) y aplica 024 encima, dos veces.
\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS storage;
CREATE TABLE IF NOT EXISTS storage.buckets (
  id                 TEXT PRIMARY KEY,
  name               TEXT NOT NULL,
  public             BOOLEAN DEFAULT false,
  file_size_limit    BIGINT,
  allowed_mime_types TEXT[]
);
CREATE TABLE IF NOT EXISTS storage.objects (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id TEXT REFERENCES storage.buckets(id),
  name      TEXT NOT NULL,
  UNIQUE (bucket_id, name)
);
CREATE OR REPLACE FUNCTION storage.foldername(name TEXT) RETURNS TEXT[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;

\ir ../migrations/024_avatars.sql
\ir ../migrations/024_avatars.sql

-- 1. El bucket existe, es público y solo acepta imágenes chicas
DO $$
DECLARE b RECORD;
BEGIN
  SELECT * INTO b FROM storage.buckets WHERE id = 'avatars';
  IF b IS NULL THEN RAISE EXCEPTION '1: no hay bucket avatars'; END IF;
  IF NOT b.public THEN RAISE EXCEPTION '1: avatars debe ser público (la URL va en la app)'; END IF;
  IF b.file_size_limit > 2097152 THEN RAISE EXCEPTION '1: límite %', b.file_size_limit; END IF;
  IF NOT 'image/jpeg' = ANY (b.allowed_mime_types) THEN RAISE EXCEPTION '1: sin image/jpeg'; END IF;
END $$;

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'ana@test.co'),
  ('00000000-0000-0000-0000-0000000000b2', 'beto@test.co')
ON CONFLICT DO NOTHING;

-- 2. Ana sube y reemplaza su foto (lo que hace el upsert de la app)
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
INSERT INTO storage.objects (bucket_id, name)
  VALUES ('avatars', '00000000-0000-0000-0000-0000000000a1/avatar.jpg');
DO $$
DECLARE n INT;
BEGIN
  UPDATE storage.objects SET name = name
   WHERE bucket_id = 'avatars' AND name = '00000000-0000-0000-0000-0000000000a1/avatar.jpg';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION '2: Ana no pudo reemplazar su foto (% filas)', n; END IF;
END $$;

-- 3. Beto no puede subir a la carpeta de Ana, ni reemplazar ni borrar su foto
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', false);
DO $$
DECLARE n INT;
BEGIN
  BEGIN
    INSERT INTO storage.objects (bucket_id, name)
      VALUES ('avatars', '00000000-0000-0000-0000-0000000000a1/otra.jpg');
    RAISE EXCEPTION '3: Beto subió a la carpeta de Ana';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE storage.objects SET name = '00000000-0000-0000-0000-0000000000a1/x.jpg'
   WHERE bucket_id = 'avatars';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION '3: Beto cambió % fotos ajenas', n; END IF;
  DELETE FROM storage.objects WHERE bucket_id = 'avatars';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION '3: Beto borró % fotos ajenas', n; END IF;
  -- Su propia carpeta sí
  INSERT INTO storage.objects (bucket_id, name)
    VALUES ('avatars', '00000000-0000-0000-0000-0000000000b2/avatar.jpg');
END $$;

-- 4. Sin sesión no se sube nada
RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
BEGIN
  INSERT INTO storage.objects (bucket_id, name) VALUES ('avatars', 'x/avatar.jpg');
  RAISE EXCEPTION '4: un invitado subió una foto';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END $$;
RESET ROLE;

\echo 024_avatars_test OK
