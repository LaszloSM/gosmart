-- supabase/demo/demo.sql
-- Datos de DEMOSTRACIÓN para presentar el MVP (no es una migración: no va en
-- piloto_bundle.sql). Lo aplica Actions → "Supabase deploy" con demo_data.
-- Seguro de re-ejecutar: borra y vuelve a crear solo lo de las cuentas demo.
--
-- Cuentas (las crea el workflow con la API de Auth; contraseña = secret DEMO_PASSWORD):
--   pasajero@example.com   Viajera con saldo, Casa/Trabajo, contactos e historial
--   conductor@example.com  Mototaxista aprobado en Riohacha (acepta solo, ver abajo)
--   colectivo@example.com  Colectivero aprobado Riohacha ↔ Maicao (publica salidas)
--
-- "Conductor de demo": con el interruptor demo_autodriver, cualquier mototaxi o
-- taxi que se pida lo acepta un conductor demo a los ~8 s; recoge a los 30 s y
-- termina a los 60 s, moviéndose en el mapa. Así se presenta con un solo celular.
-- Todos los datos son sintéticos (DATOS DE EJEMPLO); los tramos de la vía son
-- aproximados.

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION demo_user(p_role TEXT)
RETURNS UUID AS $$
  SELECT id FROM auth.users WHERE lower(email) = CASE p_role
    WHEN 'pasajero'  THEN 'pasajero@example.com'
    WHEN 'conductor' THEN 'conductor@example.com'
    WHEN 'colectivo' THEN 'colectivo@example.com'
  END
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth;
REVOKE EXECUTE ON FUNCTION demo_user(TEXT) FROM PUBLIC, anon, authenticated;

INSERT INTO app_flags (key, enabled) VALUES ('demo_autodriver', false)
ON CONFLICT (key) DO NOTHING;

-- ── Conductor de demo ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION demo_autodriver_tick()
RETURNS VOID AS $$
DECLARE
  r     ride_requests;
  v_drv UUID;
  t     DOUBLE PRECISION;
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_at  TIMESTAMPTZ;
BEGIN
  IF NOT flag_on('demo_autodriver') THEN RETURN; END IF;

  -- 1. Aceptar lo pedido hace más de 8 s (si no lo tomó un conductor real).
  FOR r IN
    SELECT * FROM ride_requests
    WHERE status = 'open' AND expires_at > now()
      AND created_at < now() - interval '8 seconds'
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT d.user_id INTO v_drv FROM drivers d
    WHERE d.user_id IN (demo_user('conductor'))
      AND d.service = r.service AND d.status = 'approved'
      AND d.user_id <> r.passenger_id
      AND NOT EXISTS (SELECT 1 FROM ride_requests x WHERE x.driver_id = d.user_id
                      AND x.status IN ('accepted', 'in_progress'))
    LIMIT 1;
    -- Taxi: el mismo conductor demo sirve (para la demo no hay otro).
    IF v_drv IS NULL AND r.service = 'taxi' THEN
      SELECT demo_user('conductor') INTO v_drv
      WHERE NOT EXISTS (SELECT 1 FROM ride_requests x WHERE x.driver_id = demo_user('conductor')
                        AND x.status IN ('accepted', 'in_progress'));
    END IF;
    CONTINUE WHEN v_drv IS NULL OR v_drv = r.passenger_id;
    UPDATE ride_requests
    SET status = 'accepted', driver_id = v_drv, agreed_fare = offered_fare, accepted_at = now()
    WHERE id = r.id;
    UPDATE ride_offers SET status = 'rejected' WHERE request_id = r.id AND status = 'pending';
    -- Arranca a ~700 m del punto de recogida.
    INSERT INTO driver_locations (driver_id, lat, lng, updated_at)
    VALUES (v_drv, r.origin_lat + 0.005, r.origin_lng + 0.004, now())
    ON CONFLICT (driver_id) DO UPDATE
      SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = now();
  END LOOP;

  -- 2. Viene a recoger (30 s) y luego lleva al destino (60 s).
  FOR r IN
    SELECT * FROM ride_requests
    WHERE status IN ('accepted', 'in_progress')
      AND driver_id IN (demo_user('conductor'))
    FOR UPDATE SKIP LOCKED
  LOOP
    IF r.status = 'accepted' THEN
      t := least(1, extract(epoch FROM now() - r.accepted_at) / 30);
      v_lat := r.origin_lat + 0.005 * (1 - t);
      v_lng := r.origin_lng + 0.004 * (1 - t);
      IF t >= 1 THEN
        UPDATE ride_requests SET status = 'in_progress' WHERE id = r.id;
      END IF;
    ELSE
      v_at := r.accepted_at + interval '30 seconds';
      t := least(1, greatest(0, extract(epoch FROM now() - v_at) / 60));
      v_lat := r.origin_lat + (r.dest_lat - r.origin_lat) * t;
      v_lng := r.origin_lng + (r.dest_lng - r.origin_lng) * t;
      IF t >= 1 THEN
        UPDATE ride_requests SET status = 'completed', finished_at = now() WHERE id = r.id;
      END IF;
    END IF;
    UPDATE driver_locations SET lat = v_lat, lng = v_lng, updated_at = now()
    WHERE driver_id = r.driver_id;
  END LOOP;

  -- 3. El conductor demo confirma el efectivo que le pagan.
  UPDATE leg_payments SET status = 'cash_confirmed', confirmed_at = now()
  WHERE status = 'cash_pending' AND driver_id IN (demo_user('conductor'))
    AND created_at < now() - interval '5 seconds';

  -- 4. Siempre hay salidas de colectivo en las próximas horas (ambos sentidos).
  UPDATE colectivo_departures SET status = 'departed'
  WHERE driver_id = demo_user('colectivo') AND status IN ('open', 'full')
    AND depart_at < now() - interval '10 minutes';
  INSERT INTO colectivo_departures (driver_id, from_node, to_node, depart_at, seats_total, seats_taken, fare)
  SELECT demo_user('colectivo'), f, t2, h, 5, (extract(minute FROM h)::int / 30 + extract(hour FROM h)::int) % 4, 14000
  FROM (VALUES ('rio-terminal', 'mai-centro'), ('mai-centro', 'rio-terminal')) AS route(f, t2),
       generate_series(date_trunc('hour', now()) + interval '30 minutes',
                       date_trunc('hour', now()) + interval '4 hours', interval '30 minutes') AS h
  WHERE demo_user('colectivo') IS NOT NULL
    AND h > now()
    AND NOT EXISTS (SELECT 1 FROM colectivo_departures c
                    WHERE c.driver_id = demo_user('colectivo')
                      AND c.from_node = route.f AND c.to_node = route.t2 AND c.depart_at = h);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION demo_autodriver_tick() FROM PUBLIC, anon, authenticated;

-- ── Datos de las cuentas demo ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION demo_seed(p_scenario TEXT DEFAULT 'normal')
RETURNS TEXT AS $$
DECLARE
  v_pas UUID := demo_user('pasajero');
  v_drv UUID := demo_user('conductor');
  v_col UUID := demo_user('colectivo');
  v_wal UUID;
  v_req UUID;
  v_rep UUID;
  i     INT;
BEGIN
  IF v_pas IS NULL OR v_drv IS NULL OR v_col IS NULL THEN
    RETURN 'faltan cuentas demo (pasajero/conductor/colectivo @example.com)';
  END IF;

  UPDATE profiles SET name = 'Yeinis Epiayú', city = 'Riohacha' WHERE id = v_pas;
  UPDATE profiles SET name = 'Wilmer Uriana', city = 'Riohacha' WHERE id = v_drv;
  UPDATE profiles SET name = 'Rafael Pushaina', city = 'Maicao' WHERE id = v_col;

  -- Conductores aprobados (como postgres: el guard deja escribir el estado).
  INSERT INTO drivers (user_id, full_name, cedula, phone, service, zone, license_number,
                       license_expires, payout_kind, payout_key, status, available, reviewed_at)
  VALUES (v_drv, 'Wilmer Uriana', '1118800001', '+573001110001', 'mototaxi', 'riohacha',
          'LIC0001', current_date + 400, 'nequi', '3001110001', 'approved', true, now()),
         (v_col, 'Rafael Pushaina', '1118800002', '+573001110002', 'colectivo', 'corredor',
          'LIC0002', current_date + 400, 'nequi', '3001110002', 'approved', true, now())
  ON CONFLICT (user_id) DO UPDATE
    SET status = 'approved', available = true, service = EXCLUDED.service, zone = EXCLUDED.zone;
  INSERT INTO vehicles (driver_id, kind, plate, brand, model, color, seats) VALUES
    (v_drv, 'moto', 'GSD12A', 'AKT', 'NKD 125', 'Roja', 1),
    (v_col, 'carro', 'GSD345', 'Chevrolet', 'Sail', 'Blanco', 5)
  ON CONFLICT (plate) DO NOTHING;
  INSERT INTO driver_locations (driver_id, lat, lng, updated_at)
  VALUES (v_drv, 11.5455, -72.9050, now()), (v_col, 11.5330, -72.9125, now())
  ON CONFLICT (driver_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = now();

  -- Pasajera: Casa y Trabajo, un contacto de emergencia.
  DELETE FROM favorite_places WHERE user_id = v_pas;
  INSERT INTO favorite_places (user_id, name, address, latitude, longitude, type, icon, use_count) VALUES
    (v_pas, 'Casa', 'Barrio Los Almendros, Riohacha', 11.5395, -72.9010, 'home', 'home', 12),
    (v_pas, 'Trabajo', 'Universidad de La Guajira', 11.5275, -72.8880, 'work', 'work', 9),
    (v_pas, 'Terminal', 'Terminal de Riohacha', 11.5330, -72.9125, 'custom', 'directions_bus', 4);
  INSERT INTO emergency_contacts (user_id, name, phone, relation)
  VALUES (v_pas, 'Mamá', '+573001234567', 'Mamá')
  ON CONFLICT (user_id, phone) DO NOTHING;

  -- Billetera: saldo y movimientos de los últimos días (simulados).
  SELECT id INTO v_wal FROM wallets WHERE user_id = v_pas;
  IF v_wal IS NOT NULL THEN
    -- Todo lo de la pasajera vuelve al punto de partida (también lo de las pruebas).
    DELETE FROM wallet_transactions WHERE wallet_id = v_wal;
    INSERT INTO wallet_transactions (wallet_id, type, amount, description, metadata, created_at) VALUES
      (v_wal, 'recharge', 50000, 'Recarga de saldo (simulada)', '{"demo":true}', now() - interval '6 days'),
      (v_wal, 'trip', -5000, 'Viaje en mototaxi · Centro → Uniguajira', '{"demo":true}', now() - interval '5 days'),
      (v_wal, 'trip', -14000, 'Colectivo Riohacha → Maicao', '{"demo":true}', now() - interval '3 days'),
      (v_wal, 'trip', -4000, 'Viaje en mototaxi · Terminal → Casa', '{"demo":true}', now() - interval '1 day'),
      (v_wal, 'recharge', 20000, 'Recarga de saldo (simulada)', '{"demo":true}', now() - interval '20 hours');
    -- Saldo = bono de bienvenida (si no quedó como movimiento) + movimientos.
    UPDATE wallets SET updated_at = now(), balance = greatest(0,
      (SELECT coalesce(sum(amount), 0) FROM wallet_transactions WHERE wallet_id = v_wal)
      + CASE WHEN EXISTS (SELECT 1 FROM wallet_transactions WHERE wallet_id = v_wal AND type = 'bonus')
             THEN 0 ELSE 10000 END)
    WHERE id = v_wal;
  END IF;

  -- Los viajes de las pruebas automáticas no quedan en el historial.
  DELETE FROM leg_payments WHERE passenger_id = v_pas
    AND idempotency_key <> 'dddddddd-0000-0000-0000-000000000002';
  DELETE FROM ride_requests WHERE passenger_id = v_pas
    AND idempotency_key <> 'dddddddd-0000-0000-0000-000000000001';
  -- Un viaje de mototaxi ya terminado y calificado (aparece en el historial).
  IF NOT EXISTS (SELECT 1 FROM ride_requests WHERE passenger_id = v_pas
                 AND idempotency_key = 'dddddddd-0000-0000-0000-000000000001') THEN
    INSERT INTO ride_requests (passenger_id, service, origin_lat, origin_lng, origin_label,
                               dest_lat, dest_lng, dest_label, offered_fare, status, driver_id,
                               agreed_fare, idempotency_key, created_at, expires_at, accepted_at, finished_at)
    VALUES (v_pas, 'mototaxi', 11.5441, -72.9071, 'Parque Padilla', 11.5275, -72.8880,
            'Universidad de La Guajira', 5000, 'completed', v_drv, 5000,
            'dddddddd-0000-0000-0000-000000000001', now() - interval '5 days',
            now() - interval '5 days', now() - interval '5 days', now() - interval '5 days' + interval '14 minutes')
    RETURNING id INTO v_req;
    INSERT INTO leg_payments (passenger_id, driver_id, amount, method, status, ride_request_id,
                              idempotency_key, created_at)
    VALUES (v_pas, v_drv, 5000, 'wallet', 'paid', v_req,
            'dddddddd-0000-0000-0000-000000000002', now() - interval '5 days');
    INSERT INTO ride_ratings (request_id, rater_id, ratee_id, stars, tags) VALUES
      (v_req, v_pas, v_drv, 5, '{}'), (v_req, v_drv, v_pas, 5, '{}')
    ON CONFLICT DO NOTHING;
  END IF;
  -- Ningún viaje encadenado abierto que estorbe al iniciar uno en vivo.
  UPDATE trip_legs SET status = 'cancelled'
  WHERE status IN ('planned', 'awaiting_dispatch', 'in_progress')
    AND trip_id IN (SELECT id FROM chained_trips WHERE passenger_id IN (v_pas, v_drv, v_col)
                    AND status IN ('planned', 'in_progress'));
  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE passenger_id IN (v_pas, v_drv, v_col) AND status IN ('planned', 'in_progress');
  -- Nada abierto que estorbe al pedir en vivo.
  UPDATE ride_requests SET status = 'cancelled', finished_at = now()
  WHERE (passenger_id IN (v_pas, v_drv, v_col) OR driver_id IN (v_drv, v_col))
    AND status IN ('open', 'accepted', 'in_progress');

  -- Estado de la vía: todo con vigencia de 7 días para que dure hasta la demo.
  DELETE FROM road_reports WHERE user_id IN (v_pas, v_drv, v_col);
  INSERT INTO road_reports (user_id, segment_id, kind, happened_at, expires_at, idempotency_key)
  SELECT v_col, s.id, 'despejado', now() - interval '20 minutes', now() + interval '7 days',
         md5('demo-clear-' || s.id)::uuid
  FROM road_segments s;
  INSERT INTO road_reports (user_id, segment_id, kind, happened_at, expires_at, idempotency_key) VALUES
    (v_drv, 'troncal-20-30', 'reten', now() - interval '12 minutes', now() + interval '7 days',
     md5('demo-reten')::uuid),
    (v_pas, 'desvio-albania-cuestecitas', 'hueco', now() - interval '15 minutes', now() + interval '7 days',
     md5('demo-hueco')::uuid);
  -- Alertas en las calles de Riohacha (como Waze): puntos reales del centro y
  -- del sur. Coordenadas aproximadas; sin tramo no tocan el estado de la Troncal.
  INSERT INTO road_reports (user_id, segment_id, kind, lat, lng, happened_at, expires_at, idempotency_key) VALUES
    (v_pas, NULL, 'hueco',   11.5360, -72.9115, now() - interval '2 days',    now() + interval '7 days', md5('demo-city-hueco-1')::uuid),
    (v_drv, NULL, 'hueco',   11.5298, -72.9046, now() - interval '5 hours',   now() + interval '7 days', md5('demo-city-hueco-2')::uuid),
    (v_col, NULL, 'trancon', 11.5432, -72.9078, now() - interval '9 minutes', now() + interval '7 days', md5('demo-city-trancon')::uuid),
    (v_drv, NULL, 'reten',   11.5245, -72.8990, now() - interval '25 minutes',now() + interval '7 days', md5('demo-city-reten')::uuid),
    (v_pas, NULL, 'peligro', 11.5401, -72.9002, now() - interval '40 minutes',now() + interval '7 days', md5('demo-city-peligro')::uuid),
    (v_col, NULL, 'obra',    11.5333, -72.9170, now() - interval '3 days',    now() + interval '7 days', md5('demo-city-obra')::uuid);
  IF p_scenario = 'bloqueo' THEN
    INSERT INTO road_reports (user_id, segment_id, kind, happened_at, expires_at, idempotency_key)
    VALUES (v_col, 'troncal-40-50', 'bloqueo', now() - interval '10 minutes', now() + interval '7 days',
            md5('demo-bloqueo')::uuid)
    RETURNING id INTO v_rep;
    -- Dos confirmaciones: con eso la confianza pasa de 0,9 y el tramo sale "Cerrada".
    INSERT INTO road_report_votes (report_id, user_id, still_there) VALUES
      (v_rep, v_pas, true), (v_rep, v_drv, true);
  END IF;
  -- Historial para el patrón ("bloqueos en 3 meses, en la mañana"): ya vencidos.
  -- Cuentan solo los confirmados por alguien más; 7 a. m. hora de Colombia.
  FOR i IN 1..4 LOOP
    INSERT INTO road_reports (user_id, segment_id, kind, happened_at, expires_at, idempotency_key)
    VALUES (v_col, 'troncal-40-50', 'bloqueo',
            (date_trunc('day', now() AT TIME ZONE 'America/Bogota') - (i * 17 || ' days')::interval
              + interval '7 hours') AT TIME ZONE 'America/Bogota',
            (date_trunc('day', now() AT TIME ZONE 'America/Bogota') - (i * 17 || ' days')::interval
              + interval '11 hours') AT TIME ZONE 'America/Bogota',
            md5('demo-hist-' || i)::uuid)
    RETURNING id INTO v_rep;
    INSERT INTO road_report_votes (report_id, user_id, still_there) VALUES (v_rep, v_pas, true);
  END LOOP;

  INSERT INTO app_flags (key, enabled) VALUES ('dispatch_enabled', true), ('demo_autodriver', true)
  ON CONFLICT (key) DO UPDATE SET enabled = true, updated_at = now();
  PERFORM demo_autodriver_tick();
  RETURN 'demo lista (' || p_scenario || ')';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION demo_seed(TEXT) FROM PUBLIC, anon, authenticated;

-- ── Programar el conductor de demo cada 5 s (pg_cron de Supabase) ───────────
DO $do$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'gosmart-demo-driver';
  PERFORM cron.schedule('gosmart-demo-driver', '5 seconds', 'SELECT public.demo_autodriver_tick()');
  RAISE NOTICE 'pg_cron: conductor de demo programado cada 5 s';
EXCEPTION WHEN others THEN
  RAISE WARNING 'pg_cron no disponible (%): el conductor de demo solo avanza al llamar demo_autodriver_tick()', SQLERRM;
END
$do$;
