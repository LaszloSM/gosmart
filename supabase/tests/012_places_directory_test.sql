-- supabase/tests/012_places_directory_test.sql
-- Requiere: stub, _profiles_fixture, 011, 012 y supabase/seed/places_seed.sql.
\set ON_ERROR_STOP on

SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);

-- 1. Alias popular y sin tilde: "el muelle" encuentra el Muelle Turístico
DO $$
DECLARE r RECORD;
BEGIN
  SELECT * INTO r FROM search_places('el muelle') LIMIT 1;
  IF r.name <> 'Muelle Turístico de Riohacha' THEN RAISE EXCEPTION '1: primero fue %', r.name; END IF;
  IF r.verified THEN RAISE EXCEPTION '1: la semilla no debe venir verificada'; END IF;
END $$;

-- 2. Tildes y mayúsculas no importan; error de tecleo tolerado
DO $$
DECLARE r RECORD;
BEGIN
  SELECT * INTO r FROM search_places('UNIVERSIDAD DE LA GUAJIRA') LIMIT 1;
  IF r.name <> 'Universidad de La Guajira' THEN RAISE EXCEPTION '2a: %', r.name; END IF;
  SELECT * INTO r FROM search_places('mesquita') LIMIT 1;
  IF r.name IS DISTINCT FROM 'Mezquita Omar Ibn Al-Khattab' THEN RAISE EXCEPTION '2b: %', r.name; END IF;
END $$;

-- 3. "la terminal" existe en ambas ciudades: gana la cercana
DO $$
DECLARE r RECORD;
BEGIN
  SELECT * INTO r FROM search_places('la terminal', 11.378, -72.240) LIMIT 1;
  IF r.city <> 'maicao' THEN RAISE EXCEPTION '3a: desde Maicao salió %', r.city; END IF;
  SELECT * INTO r FROM search_places('la terminal', 11.544, -72.907) LIMIT 1;
  IF r.city <> 'riohacha' THEN RAISE EXCEPTION '3b: desde Riohacha salió %', r.city; END IF;
END $$;

-- 4. Consultas vacías o de una letra no devuelven todo el directorio
DO $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM search_places('a');
  IF n <> 0 THEN RAISE EXCEPTION '4: una letra devolvió % filas', n; END IF;
  SELECT count(*) INTO n FROM search_places('', NULL, NULL, 500);
  IF n <> 0 THEN RAISE EXCEPTION '4: vacío devolvió % filas', n; END IF;
END $$;

-- 5. Un usuario normal no puede escribir en el directorio
RESET ROLE;
INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-0000000000d4', 'dani@test.co') ON CONFLICT DO NOTHING;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d4', false);
DO $$
DECLARE n INT;
BEGIN
  BEGIN
    INSERT INTO places (name, city, lat, lng) VALUES ('Mi casa', 'riohacha', 11.5, -72.9);
    RAISE EXCEPTION '5: un usuario agregó un lugar';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE places SET lat = 11.0 WHERE name = 'Cuestecitas';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION '5: un usuario movió un lugar'; END IF;
END $$;
RESET ROLE;

\echo '012_places_directory_test: OK'
