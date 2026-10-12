-- supabase/tests/018_push_test.sql (después de 017_trust_admin_test.sql)
\set ON_ERROR_STOP on
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
CREATE TEMP TABLE IF NOT EXISTS t18 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t18 TO PUBLIC;

SET ROLE authenticated;
-- Moto 1 disponible cerca del parque, con token
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
DO $$ BEGIN
  PERFORM driver_ping(11.5445, -72.9068);
  PERFORM register_push_token('tok-moto1-aaaaaaaaaaaaaaaa', 'android');
END $$;
-- Moto 2 disponible pero en Maicao
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM driver_ping(11.378, -72.240);
  PERFORM register_push_token('tok-moto2-bbbbbbbbbbbbbbbb', 'android');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  INSERT INTO t18 VALUES ('req', request_ride('mototaxi', 11.5441, -72.9071, 'P', 11.53, -72.91, 'T', 5000, gen_random_uuid()));
  -- Nadie puede leer los tokens ajenos ni pedir la lista de destinatarios
  IF EXISTS (SELECT 1 FROM push_tokens) THEN RAISE EXCEPTION '1: ve tokens ajenos'; END IF;
  BEGIN
    PERFORM push_targets_for_request((SELECT id FROM t18 WHERE k = 'req'));
    RAISE EXCEPTION '1: un cliente pidió destinatarios';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;
DO $$
DECLARE toks TEXT[];
BEGIN
  SELECT array_agg(token) INTO toks FROM push_targets_for_request((SELECT id FROM t18 WHERE k = 'req'));
  IF toks IS DISTINCT FROM ARRAY['tok-moto1-aaaaaaaaaaaaaaaa'] THEN
    RAISE EXCEPTION '2: destinatarios %', toks;
  END IF;
END $$;
-- Mismo teléfono, otra cuenta: el token se reasigna
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$ BEGIN PERFORM register_push_token('tok-moto2-bbbbbbbbbbbbbbbb', 'android'); END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT user_id FROM push_tokens WHERE token = 'tok-moto2-bbbbbbbbbbbbbbbb')
     <> '00000000-0000-0000-0000-000000000a02' THEN RAISE EXCEPTION '3: no reasignó'; END IF;
END $$;
\echo '018_push_test: OK'
