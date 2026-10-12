-- supabase/tests/017_trust_admin_test.sql
-- Requiere lo mismo que 016_payments_test.sql, aplicado antes.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000a03', 'moroso@test.co'),
  ('00000000-0000-0000-0000-0000000000ad', 'admin2@test.co')
ON CONFLICT DO NOTHING;
UPDATE profiles SET role = 'admin' WHERE id = '00000000-0000-0000-0000-0000000000ad';
-- Liberar conductores de pruebas anteriores
UPDATE ride_requests SET status = 'completed', finished_at = now()
WHERE status IN ('accepted', 'in_progress', 'open');

CREATE TEMP TABLE IF NOT EXISTS t17 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t17 TO PUBLIC;

-- Un viaje completo del moroso con Moto 2, sin pagar
CREATE OR REPLACE FUNCTION pg_temp.ride_unpaid(k TEXT) RETURNS VOID AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', true);
  INSERT INTO t17 VALUES (k, request_ride('mototaxi', 11.5441, -72.9071, 'P', 11.53, -72.91, 'T', 4000, gen_random_uuid()));
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', true);
  PERFORM accept_ride((SELECT id FROM t17 WHERE t17.k = ride_unpaid.k));
  PERFORM ride_transition((SELECT id FROM t17 WHERE t17.k = ride_unpaid.k), 'in_progress');
  PERFORM ride_transition((SELECT id FROM t17 WHERE t17.k = ride_unpaid.k), 'completed');
END $$ LANGUAGE plpgsql;

SET ROLE authenticated;
SELECT pg_temp.ride_unpaid('r1');
SELECT pg_temp.ride_unpaid('r2');

-- 1. El pasajero no puede marcar 'no_pago'; el conductor sí
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', false);
DO $$ BEGIN
  BEGIN
    PERFORM rate_ride((SELECT id FROM t17 WHERE k = 'r1'), 5::smallint, '{no_pago}');
    RAISE EXCEPTION '1: el pasajero usó no_pago';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  PERFORM rate_ride((SELECT id FROM t17 WHERE k = 'r1'), 5::smallint, '{puntual,amable}');
  -- Etiqueta inventada: no
  BEGIN
    PERFORM rate_ride((SELECT id FROM t17 WHERE k = 'r2'), 1::smallint, '{es_un_ladron}');
    RAISE EXCEPTION '1: aceptó una etiqueta libre';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- 2. Dos impagos confirmados bloquean nuevas solicitudes
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM rate_ride((SELECT id FROM t17 WHERE k = 'r1'), 1::smallint, '{no_pago}');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', false);
DO $$ BEGIN
  -- con uno solo todavía puede pedir
  INSERT INTO t17 VALUES ('ok', request_ride('mototaxi', 11.54, -72.90, 'P', 11.53, -72.91, 'T', 4000, gen_random_uuid()));
  PERFORM ride_transition((SELECT id FROM t17 WHERE k = 'ok'), 'cancelled');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM rate_ride((SELECT id FROM t17 WHERE k = 'r2'), 1::smallint, '{no_pago}');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', false);
DO $$ BEGIN
  BEGIN
    PERFORM request_ride('mototaxi', 11.54, -72.90, 'P', 11.53, -72.91, 'T', 4000, gen_random_uuid());
    RAISE EXCEPTION '2: un moroso pidió viaje';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  -- 3. Paga uno de los dos (en saldo) y se desbloquea
  PERFORM pay_ride((SELECT id FROM t17 WHERE k = 'r2'), 'wallet', gen_random_uuid());
  PERFORM request_ride('mototaxi', 11.54, -72.90, 'P', 11.53, -72.91, 'T', 4000, gen_random_uuid());
END $$;

-- 4. Solo un admin ve la cola de conductores y las métricas
DO $$ BEGIN
  BEGIN
    PERFORM admin_metrics(7);
    RAISE EXCEPTION '4: un pasajero vio métricas';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000ad', false);
DO $$
DECLARE m JSONB; n INT;
BEGIN
  m := admin_metrics(7);
  IF (m->>'rides_completed')::int < 2 THEN RAISE EXCEPTION '4: métricas %', m; END IF;
  IF m ? 'passenger_id' THEN RAISE EXCEPTION '4: métricas con datos personales'; END IF;
  SELECT count(*) INTO n FROM admin_driver_queue();
  IF n < 3 THEN RAISE EXCEPTION '4: cola de conductores %', n; END IF;
END $$;
RESET ROLE;

\echo '017_trust_admin_test: OK'
