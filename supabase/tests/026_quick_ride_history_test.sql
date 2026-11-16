-- supabase/tests/026_quick_ride_history_test.sql (después de 025_mvp_real_test.sql)
-- Pedir en un toque, subir la tarifa buscando e historial completo.
\set ON_ERROR_STOP on
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
UPDATE chained_trips SET status = 'completed' WHERE status IN ('planned', 'in_progress');
UPDATE app_flags SET enabled = true WHERE key = 'dispatch_enabled';
INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000a26', 'rapida@test.co')
ON CONFLICT DO NOTHING;
CREATE TEMP TABLE IF NOT EXISTS t26 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t26 TO PUBLIC;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a26', false);

-- 1. Un toque: viaje + tramo esperando + solicitud abierta, y el reintento
--    con la misma llave no crea nada nuevo.
DO $$
DECLARE j JSONB; j2 JSONB; k UUID := gen_random_uuid(); l trip_legs; r ride_requests;
BEGIN
  j := quick_ride('mototaxi', 11.5441, -72.9071, 'Calle 15 # 10-20', 11.53, -72.91, 'Uniguajira', 6000, 9, k);
  j2 := quick_ride('mototaxi', 11.5441, -72.9071, 'Calle 15 # 10-20', 11.53, -72.91, 'Uniguajira', 6000, 9, k);
  IF j <> j2 THEN RAISE EXCEPTION '1: el reintento creó otro viaje'; END IF;
  SELECT * INTO l FROM trip_legs WHERE trip_id = (j->>'trip_id')::uuid;
  IF l.status <> 'awaiting_dispatch' OR l.mode <> 'mototaxi' OR l.fare_max <> 6000 THEN
    RAISE EXCEPTION '1: el tramo no quedó esperando (%/%/%)', l.status, l.mode, l.fare_max;
  END IF;
  SELECT * INTO r FROM ride_requests WHERE id = (j->>'request_id')::uuid;
  IF r.status <> 'open' OR r.trip_leg_id <> l.id OR r.origin_label <> 'Calle 15 # 10-20' THEN
    RAISE EXCEPTION '1: la solicitud no quedó abierta y ligada';
  END IF;
  IF (SELECT status FROM chained_trips WHERE id = (j->>'trip_id')::uuid) <> 'in_progress' THEN
    RAISE EXCEPTION '1: el viaje no quedó en curso';
  END IF;
  INSERT INTO t26 VALUES ('trip', (j->>'trip_id')::uuid), ('req', (j->>'request_id')::uuid);
  -- Servicio inventado: no.
  BEGIN
    PERFORM quick_ride('bus', 11.5441, -72.9071, 'A', 11.53, -72.91, 'B', 6000, 9, gen_random_uuid());
    RAISE EXCEPTION '1: aceptó un servicio inventado';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;

-- 2. Subir la tarifa buscando: solo hacia arriba y solo abierta.
RESET ROLE;
UPDATE ride_requests SET expires_at = now() + interval '10 seconds'
WHERE id = (SELECT id FROM t26 WHERE k = 'req');
SET ROLE authenticated;
DO $$
DECLARE r ride_requests;
BEGIN
  r := ride_raise_fare((SELECT id FROM t26 WHERE k = 'req'), 7000);
  IF r.offered_fare <> 7000 OR r.expires_at < now() + interval '2 minutes' THEN
    RAISE EXCEPTION '2: no subió o no reinició el reloj';
  END IF;
  BEGIN
    PERFORM ride_raise_fare((SELECT id FROM t26 WHERE k = 'req'), 6500);
    RAISE EXCEPTION '2: bajó la tarifa';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;
-- Otra persona no puede tocarla.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  BEGIN
    PERFORM ride_raise_fare((SELECT id FROM t26 WHERE k = 'req'), 9000);
    RAISE EXCEPTION '2: otra persona subió la tarifa';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
END $$;

-- 3. El conductor la toma y termina; la pasajera paga en efectivo.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t26 WHERE k = 'req'));
  PERFORM ride_transition((SELECT id FROM t26 WHERE k = 'req'), 'in_progress');
  PERFORM ride_transition((SELECT id FROM t26 WHERE k = 'req'), 'completed');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a26', false);
DO $$ BEGIN
  PERFORM pay_ride((SELECT id FROM t26 WHERE k = 'req'), 'cash', gen_random_uuid());
END $$;

-- 4. La app se cerró tras pagar (el tramo sigue "en curso"): pedir otro
--    cierra el anterior como hecho en vez de fallar con trip_in_progress.
--    El segundo se cancela buscando y también sale en el historial.
DO $$
DECLARE j JSONB;
BEGIN
  IF (SELECT status FROM chained_trips WHERE id = (SELECT id FROM t26 WHERE k = 'trip')) <> 'in_progress' THEN
    RAISE EXCEPTION '4: el viaje ya estaba cerrado (la prueba no prueba nada)';
  END IF;
  j := quick_ride('taxi', 11.5441, -72.9071, 'Casa', 11.55, -72.90, 'Terminal', 9000, 7, gen_random_uuid());
  IF (SELECT status FROM chained_trips WHERE id = (SELECT id FROM t26 WHERE k = 'trip')) <> 'completed' THEN
    RAISE EXCEPTION '4: el viaje pagado no se cerró';
  END IF;
  PERFORM cancel_trip((j->>'trip_id')::uuid);
  INSERT INTO t26 VALUES ('trip2', (j->>'trip_id')::uuid);
END $$;

-- 4b. Uno que nadie tomó (vencido) tampoco bloquea.
DO $$
DECLARE j JSONB;
BEGIN
  j := quick_ride('mototaxi', 11.5441, -72.9071, 'Casa', 11.55, -72.90, 'Mercado', 5000, 6, gen_random_uuid());
  INSERT INTO t26 VALUES ('trip3', (j->>'trip_id')::uuid);
END $$;
RESET ROLE;
UPDATE ride_requests SET expires_at = now() - interval '1 second'
WHERE trip_leg_id IN (SELECT id FROM trip_legs WHERE trip_id = (SELECT id FROM t26 WHERE k = 'trip3'));
SET ROLE authenticated;
DO $$
DECLARE j JSONB;
BEGIN
  j := quick_ride('mototaxi', 11.5441, -72.9071, 'Casa', 11.55, -72.90, 'Mercado', 5000, 6, gen_random_uuid());
  IF (SELECT status FROM chained_trips WHERE id = (SELECT id FROM t26 WHERE k = 'trip3')) <> 'cancelled' THEN
    RAISE EXCEPTION '4b: el vencido no se canceló';
  END IF;
  PERFORM cancel_trip((j->>'trip_id')::uuid);
  INSERT INTO t26 VALUES ('trip4', (j->>'trip_id')::uuid);
END $$;

-- 5. Historial: los dos, el más nuevo primero, con conductor, placa y pago.
DO $$
DECLARE h JSONB; first JSONB; second JSONB; d JSONB;
BEGIN
  h := my_trip_history(0, 20);
  IF jsonb_array_length(h) <> 4 THEN RAISE EXCEPTION '5: esperaba 4 viajes, hay %', jsonb_array_length(h); END IF;
  IF h->0->>'id' <> (SELECT id FROM t26 WHERE k = 'trip4')::text THEN
    RAISE EXCEPTION '5: el más nuevo no va primero';
  END IF;
  first := h->2; second := h->3;
  IF first->>'id' <> (SELECT id FROM t26 WHERE k = 'trip2')::text OR first->>'status' <> 'cancelled' THEN
    RAISE EXCEPTION '5: el cancelado no va antes del completado';
  END IF;
  IF first->'last_ride'->>'status' <> 'cancelled' OR first->'last_ride'->>'service' <> 'taxi' THEN
    RAISE EXCEPTION '5: no dice cómo terminó la solicitud';
  END IF;
  IF second->>'status' <> 'completed' OR (second->>'total_paid')::int <> 7000
     OR second->'last_ride'->>'other_name' <> 'Moto' OR second->'last_ride'->>'pay_method' <> 'cash' THEN
    RAISE EXCEPTION '5: el completado no trae pago/conductor: %', second;
  END IF;
  -- Paginado.
  IF jsonb_array_length(my_trip_history(3, 20)) <> 1 THEN RAISE EXCEPTION '5: offset'; END IF;
  -- Detalle con los intentos del tramo.
  d := my_trip_detail((SELECT id FROM t26 WHERE k = 'trip'));
  IF jsonb_array_length(d->'legs'->0->'rides') <> 1
     OR (d->'legs'->0->'rides'->0->>'agreed_fare')::int <> 7000 THEN
    RAISE EXCEPTION '5: el detalle no trae la solicitud: %', d;
  END IF;
END $$;

-- 6. Lo ajeno no se ve.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  IF my_trip_detail((SELECT id FROM t26 WHERE k = 'trip')) IS NOT NULL THEN
    RAISE EXCEPTION '6: otra persona ve el detalle';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(my_trip_history(0, 50)) e
             WHERE e->>'id' = (SELECT id FROM t26 WHERE k = 'trip')::text) THEN
    RAISE EXCEPTION '6: otra persona ve el viaje en su historial';
  END IF;
END $$;

-- 7. El conductor ve el viaje que hizo, con el nombre de pila de la pasajera.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE e JSONB;
BEGIN
  SELECT x INTO e FROM jsonb_array_elements(my_trip_history(0, 50)) x
  WHERE x->>'id' = (SELECT id FROM t26 WHERE k = 'req')::text;
  IF e IS NULL OR e->>'kind' <> 'ride' OR e->>'other_name' <> 'rapida' THEN
    RAISE EXCEPTION '7: el conductor no ve su viaje: %', e;
  END IF;
  IF my_ride_detail((SELECT id FROM t26 WHERE k = 'req')) IS NULL THEN
    RAISE EXCEPTION '7: sin detalle para el conductor';
  END IF;
END $$;

RESET ROLE;
SELECT '026_quick_ride_history: OK';
