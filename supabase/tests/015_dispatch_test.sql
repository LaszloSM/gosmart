-- supabase/tests/015_dispatch_test.sql
-- Requiere: stub, _profiles_fixture, 011–015.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000a01', 'pasajera@test.co'),
  ('00000000-0000-0000-0000-000000000d01', 'moto1@test.co'),
  ('00000000-0000-0000-0000-000000000d02', 'moto2@test.co'),
  ('00000000-0000-0000-0000-000000000d03', 'colectivo@test.co'),
  ('00000000-0000-0000-0000-000000000a02', 'pasajero2@test.co')
ON CONFLICT DO NOTHING;

-- Conductores aprobados por el servidor.
INSERT INTO drivers (user_id, full_name, cedula, phone, service, zone, status, available) VALUES
  ('00000000-0000-0000-0000-000000000d01', 'Moto Uno', '1000001', '+573000000001', 'mototaxi', 'riohacha', 'approved', true),
  ('00000000-0000-0000-0000-000000000d02', 'Moto Dos', '1000002', '+573000000002', 'mototaxi', 'riohacha', 'approved', true),
  ('00000000-0000-0000-0000-000000000d03', 'Cole Tres', '1000003', '+573000000003', 'colectivo', 'corredor', 'approved', true)
ON CONFLICT (user_id) DO NOTHING;
INSERT INTO vehicles (driver_id, kind, plate) VALUES
  ('00000000-0000-0000-0000-000000000d01', 'moto', 'AAA11A') ON CONFLICT DO NOTHING;

CREATE TEMP TABLE IF NOT EXISTS t_ids (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t_ids TO PUBLIC;

SET ROLE authenticated;

-- 1. La pasajera pide un mototaxi; reintento = misma solicitud; no dos abiertas
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE a UUID; b UUID;
BEGIN
  a := request_ride('mototaxi', 11.5441, -72.9071, 'Parque Padilla', 11.5275, -72.8880,
                    'Uniguajira', 5000, '44444444-4444-4444-4444-444444444444');
  b := request_ride('mototaxi', 11.5441, -72.9071, 'Parque Padilla', 11.5275, -72.8880,
                    'Uniguajira', 5000, '44444444-4444-4444-4444-444444444444');
  IF a <> b THEN RAISE EXCEPTION '1: el reintento creó otra solicitud'; END IF;
  INSERT INTO t_ids VALUES ('req', a);
  BEGIN
    PERFORM request_ride('mototaxi', 11.5, -72.9, 'x', 11.52, -72.88, 'y', 5000, gen_random_uuid());
    RAISE EXCEPTION '1: aceptó dos solicitudes abiertas';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  BEGIN
    PERFORM accept_ride(a);
    RAISE EXCEPTION '1: una pasajera aceptó un viaje';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 2. Moto 2 la ve cerca y contraoferta; ve solo etiquetas y distancias
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE r RECORD; v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  SELECT * INTO r FROM nearby_requests(11.545, -72.906) WHERE id = v_req;
  IF r.id IS NULL THEN RAISE EXCEPTION '2: no ve la solicitud cercana'; END IF;
  IF r.pickup_km > 0.5 THEN RAISE EXCEPTION '2: distancia rara %', r.pickup_km; END IF;
  PERFORM counter_offer(v_req, 6000);
  -- No ve la tabla cruda de solicitudes ajenas
  IF EXISTS (SELECT 1 FROM ride_requests) THEN RAISE EXCEPTION '2: ve solicitudes crudas'; END IF;
  -- Lejos (Maicao) ya no la ve
  IF EXISTS (SELECT 1 FROM nearby_requests(11.378, -72.240) WHERE id = v_req) THEN
    RAISE EXCEPTION '2: la ve desde Maicao';
  END IF;
END $$;

-- 3. Moto 1 acepta la tarifa sugerida; Moto 2 llega tarde (D7, secuencial)
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
DO $$
DECLARE r ride_requests; v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  r := accept_ride(v_req);
  IF r.driver_id <> auth.uid() OR r.agreed_fare <> 5000 THEN RAISE EXCEPTION '3: aceptación rara'; END IF;
  PERFORM driver_ping(11.546, -72.905);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  BEGIN
    PERFORM accept_ride(v_req);
    RAISE EXCEPTION '3: dos conductores aceptaron';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
END $$;

-- 4. La pasajera ve a su conductor (primer nombre, placa, posición); nadie más
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE v RECORD; v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  SELECT * INTO v FROM ride_driver_view(v_req);
  IF v.first_name <> 'Moto' OR v.plate <> 'AAA11A' OR v.lat IS NULL THEN
    RAISE EXCEPTION '4: vista del conductor %', v;
  END IF;
  -- La pasajera no puede terminar el viaje (lo hace el conductor)
  BEGIN
    PERFORM ride_transition(v_req, 'completed');
    RAISE EXCEPTION '4: la pasajera cerró el viaje';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  IF EXISTS (SELECT 1 FROM ride_driver_view(v_req)) THEN RAISE EXCEPTION '4: otro ve al conductor'; END IF;
END $$;

-- 5. El conductor recoge y termina
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
DO $$
DECLARE r ride_requests; v_req UUID;
BEGIN
  SELECT id INTO v_req FROM t_ids WHERE k = 'req';
  r := ride_transition(v_req, 'in_progress');
  r := ride_transition(v_req, 'completed');
  IF r.status <> 'completed' OR r.finished_at IS NULL THEN RAISE EXCEPTION '5: no cerró'; END IF;
END $$;

-- 6. Contraoferta elegida por el pasajero
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE a UUID;
BEGIN
  a := request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Terminal', 4000, gen_random_uuid());
  INSERT INTO t_ids VALUES ('req2', a);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE o UUID;
BEGIN
  o := counter_offer((SELECT id FROM t_ids WHERE k = 'req2'), 5500);
  INSERT INTO t_ids VALUES ('offer', o);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE r ride_requests;
BEGIN
  r := accept_offer((SELECT id FROM t_ids WHERE k = 'offer'));
  IF r.agreed_fare <> 5500 OR r.driver_id <> '00000000-0000-0000-0000-000000000d02' THEN
    RAISE EXCEPTION '6: contraoferta mal aplicada';
  END IF;
END $$;

-- 7. Interruptor: con el despacho apagado no se puede pedir
RESET ROLE;
UPDATE app_flags SET enabled = false WHERE key = 'dispatch_enabled';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
BEGIN
  BEGIN
    PERFORM request_ride('taxi', 11.5, -72.9, 'x', 11.52, -72.88, 'y', 8000, gen_random_uuid());
    RAISE EXCEPTION '7: pidió con el despacho apagado';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
END $$;
RESET ROLE;
UPDATE app_flags SET enabled = true WHERE key = 'dispatch_enabled';
SET ROLE authenticated;

-- 8. Colectivo: 2 cupos; la reserva llena la salida; nadie se pasa
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d03', false);
DO $$
DECLARE d UUID;
BEGIN
  d := publish_departure('rio-terminal', 'mai-centro', now() + interval '30 minutes', 2::smallint, 14000);
  INSERT INTO t_ids VALUES ('dep', d);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE r UUID; r2 UUID;
BEGIN
  r := reserve_seat((SELECT id FROM t_ids WHERE k = 'dep'), 1::smallint, '55555555-5555-5555-5555-555555555555');
  r2 := reserve_seat((SELECT id FROM t_ids WHERE k = 'dep'), 1::smallint, '55555555-5555-5555-5555-555555555555');
  IF r <> r2 THEN RAISE EXCEPTION '8: el reintento reservó dos veces'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE st TEXT;
BEGIN
  BEGIN
    PERFORM reserve_seat((SELECT id FROM t_ids WHERE k = 'dep'), 2::smallint, gen_random_uuid());
    RAISE EXCEPTION '8: reservó más cupos de los que hay';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  PERFORM reserve_seat((SELECT id FROM t_ids WHERE k = 'dep'), 1::smallint, gen_random_uuid());
  SELECT status INTO st FROM colectivo_departures WHERE id = (SELECT id FROM t_ids WHERE k = 'dep');
  IF st <> 'full' THEN RAISE EXCEPTION '8: no quedó llena (%)', st; END IF;
END $$;

-- 9. Viaje encadenado: orden de tramos y estado derivado
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE t UUID; l0 UUID; l1 UUID; st TEXT;
BEGIN
  t := create_trip('Parque Padilla', 'Centro de Maicao', '[
    {"mode":"mototaxi","from_label":"Parque","to_label":"Terminal","minutes":8,"fare_min":3000,"fare_max":5000},
    {"mode":"colectivo","from_label":"Terminal","to_label":"Maicao","minutes":70,"fare_min":12000,"fare_max":15000}
  ]'::jsonb, gen_random_uuid());
  SELECT id INTO l0 FROM trip_legs WHERE trip_id = t AND seq = 0;
  SELECT id INTO l1 FROM trip_legs WHERE trip_id = t AND seq = 1;
  BEGIN
    PERFORM trip_leg_transition(l1, 'in_progress');
    RAISE EXCEPTION '9: empezó el tramo 2 antes del 1';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  PERFORM trip_leg_transition(l0, 'awaiting_dispatch');
  SELECT status INTO st FROM chained_trips WHERE id = t;
  IF st <> 'in_progress' THEN RAISE EXCEPTION '9: viaje quedó %', st; END IF;
  PERFORM trip_leg_transition(l0, 'in_progress', 4500);
  PERFORM trip_leg_transition(l0, 'completed');
  BEGIN
    PERFORM trip_leg_transition(l0, 'in_progress');
    RAISE EXCEPTION '9: reabrió un tramo terminado';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  PERFORM trip_leg_transition(l1, 'in_progress');
  PERFORM trip_leg_transition(l1, 'completed');
  SELECT status INTO st FROM chained_trips WHERE id = t;
  IF st <> 'completed' THEN RAISE EXCEPTION '9: viaje final %', st; END IF;
END $$;
RESET ROLE;

\echo '015_dispatch_test: OK'
