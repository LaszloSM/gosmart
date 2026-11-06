-- supabase/tests/025_mvp_real_test.sql (después de 023_driver_earnings_test.sql)
-- Cancelar con motivo, cancel_trip que suelta al conductor y sin conductor de demo.
\set ON_ERROR_STOP on
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
UPDATE chained_trips SET status = 'completed' WHERE status IN ('planned', 'in_progress');
-- Nada de la demo queda.
DO $$ BEGIN
  IF to_regproc('demo_autodriver_tick') IS NOT NULL THEN RAISE EXCEPTION '0: sigue la demo'; END IF;
  IF EXISTS (SELECT 1 FROM app_flags WHERE key = 'demo_autodriver') THEN
    RAISE EXCEPTION '0: sigue el interruptor de demo';
  END IF;
END $$;
-- En Supabase los usuarios ya tienen estos permisos (RLS filtra); el stub no.
DO $$ BEGIN
  IF to_regclass('public.favorite_places') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON favorite_places TO authenticated;
  END IF;
END $$;
CREATE TEMP TABLE IF NOT EXISTS t24 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t24 TO PUBLIC;

SET ROLE authenticated;

-- 1. Abierta: la pasajera cancela sin motivo.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE r ride_requests; v UUID;
BEGIN
  v := request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 6000, gen_random_uuid());
  r := ride_cancel(v);
  IF r.status <> 'cancelled' OR r.cancelled_by <> 'passenger' THEN RAISE EXCEPTION '1: no canceló'; END IF;
  r := ride_cancel(v);  -- idempotente
END $$;

-- 2. Aceptada: sin motivo no se puede (ni por la vía vieja); con motivo sí.
DO $$ BEGIN
  INSERT INTO t24 VALUES ('req', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 6000, gen_random_uuid()));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN PERFORM accept_ride((SELECT id FROM t24 WHERE k = 'req')); END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE r ride_requests;
BEGIN
  BEGIN
    PERFORM ride_cancel((SELECT id FROM t24 WHERE k = 'req'));
    RAISE EXCEPTION '2: canceló sin motivo';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM ride_transition((SELECT id FROM t24 WHERE k = 'req'), 'cancelled');
    RAISE EXCEPTION '2: la vía vieja canceló sin motivo';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM ride_cancel((SELECT id FROM t24 WHERE k = 'req'), 'lo_que_sea');
    RAISE EXCEPTION '2: aceptó un motivo inventado';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  r := ride_cancel((SELECT id FROM t24 WHERE k = 'req'), 'driver_late');
  IF r.status <> 'cancelled' OR r.cancel_reason <> 'driver_late' THEN RAISE EXCEPTION '2: sin motivo guardado'; END IF;
END $$;

-- 3. En curso: ya no se cancela.
DO $$ BEGIN
  INSERT INTO t24 VALUES ('req3', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 6000, gen_random_uuid()));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t24 WHERE k = 'req3'));
  PERFORM ride_transition((SELECT id FROM t24 WHERE k = 'req3'), 'in_progress');
  BEGIN
    PERFORM ride_cancel((SELECT id FROM t24 WHERE k = 'req3'), 'other');
    RAISE EXCEPTION '3: canceló un viaje en curso';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  PERFORM ride_transition((SELECT id FROM t24 WHERE k = 'req3'), 'completed');
END $$;

-- 4. cancel_trip con conductor en camino: pide motivo y suelta la solicitud.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE v_trip UUID; v_leg UUID;
BEGIN
  v_trip := create_trip('Parque', 'Uni', jsonb_build_array(jsonb_build_object(
    'mode', 'mototaxi', 'from_label', 'Parque', 'to_label', 'Uni',
    'from_lat', 11.5441, 'from_lng', -72.9071, 'to_lat', 11.53, 'to_lng', -72.91,
    'minutes', 8, 'fare_min', 5000, 'fare_max', 7000)), gen_random_uuid());
  SELECT id INTO v_leg FROM trip_legs WHERE trip_id = v_trip;
  INSERT INTO t24 VALUES ('trip', v_trip);
  INSERT INTO t24 VALUES ('req4', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 6000, gen_random_uuid(), v_leg));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
DO $$ BEGIN PERFORM accept_ride((SELECT id FROM t24 WHERE k = 'req4')); END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$ BEGIN
  BEGIN
    PERFORM cancel_trip((SELECT id FROM t24 WHERE k = 'trip'));
    RAISE EXCEPTION '4: canceló el viaje sin motivo';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  PERFORM cancel_trip((SELECT id FROM t24 WHERE k = 'trip'), 'changed_plans');
  IF (SELECT status FROM ride_requests WHERE id = (SELECT id FROM t24 WHERE k = 'req4')) <> 'cancelled' THEN
    RAISE EXCEPTION '4: el conductor sigue asignado';
  END IF;
  IF (SELECT status FROM chained_trips WHERE id = (SELECT id FROM t24 WHERE k = 'trip')) <> 'cancelled' THEN
    RAISE EXCEPTION '4: el viaje no quedó cancelado';
  END IF;
END $$;

-- 5. Lugares con nombre: máximo 10 (Casa y Trabajo aparte).
DO $$
BEGIN
  IF to_regclass('public.favorite_places') IS NULL THEN RETURN; END IF;
  INSERT INTO favorite_places (user_id, name, address, latitude, longitude, type)
  SELECT auth.uid(), 'Lugar ' || g, 'Dir', 11.5, -72.9, 'custom' FROM generate_series(1, 10) g;
  INSERT INTO favorite_places (user_id, name, address, latitude, longitude, type)
  VALUES (auth.uid(), 'Casa', 'Dir', 11.5, -72.9, 'home');
  BEGIN
    INSERT INTO favorite_places (user_id, name, address, latitude, longitude, type)
    VALUES (auth.uid(), 'Once', 'Dir', 11.5, -72.9, 'custom');
    RAISE EXCEPTION '5: guardó 11 lugares';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'saved_places_limit' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE favorite_places SET name = '  ' WHERE user_id = auth.uid() AND name = 'Lugar 1';
    RAISE EXCEPTION '5: aceptó un nombre vacío';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  -- Renombrar uno de los 10 sí se puede.
  UPDATE favorite_places SET name = 'Donde mi mamá' WHERE user_id = auth.uid() AND name = 'Lugar 1';
END $$;

RESET ROLE;
-- 6. Solo efectivo con Wompi apagado.
UPDATE app_flags SET enabled = false WHERE key = 'wompi_enabled';
INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000a25', 'nueva@test.co')
ON CONFLICT DO NOTHING;
DO $$ BEGIN
  IF (SELECT balance FROM wallets WHERE user_id = '00000000-0000-0000-0000-000000000a25') <> 0 THEN
    RAISE EXCEPTION '6: la cuenta nueva trae bono de prueba';
  END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  INSERT INTO t24 VALUES ('req6', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 6000, gen_random_uuid()));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t24 WHERE k = 'req6'));
  PERFORM ride_transition((SELECT id FROM t24 WHERE k = 'req6'), 'in_progress');
  PERFORM ride_transition((SELECT id FROM t24 WHERE k = 'req6'), 'completed');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE p leg_payments;
BEGIN
  BEGIN
    PERFORM pay_ride((SELECT id FROM t24 WHERE k = 'req6'), 'wallet', gen_random_uuid());
    RAISE EXCEPTION '6: pagó con saldo sin Wompi';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN
    IF SQLERRM <> 'wallet_disabled' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM wallet_recharge_simulated(5000, gen_random_uuid());
    RAISE EXCEPTION '6: hubo recarga simulada';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  p := pay_ride((SELECT id FROM t24 WHERE k = 'req6'), 'cash', gen_random_uuid());
  IF p.status <> 'cash_pending' THEN RAISE EXCEPTION '6: efectivo no quedó pendiente'; END IF;
END $$;

RESET ROLE;
SELECT '025_mvp_real: OK';
