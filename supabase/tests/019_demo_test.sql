-- supabase/tests/019_demo_test.sql
-- Datos de demo y conductor automático (supabase/demo/demo.sql).
-- Requiere: stub, _profiles_fixture, 008–018 y demo.sql.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-00000000de01', 'pasajero@example.com'),
  ('00000000-0000-0000-0000-00000000de02', 'conductor@example.com'),
  ('00000000-0000-0000-0000-00000000de03', 'colectivo@example.com'),
  ('00000000-0000-0000-0000-00000000de04', 'invitada@test.co')
ON CONFLICT DO NOTHING;

-- Dos veces: debe ser re-ejecutable.
SELECT demo_seed('bloqueo');
SELECT demo_seed('bloqueo');

DO $$
DECLARE s TEXT;
BEGIN
  SELECT state INTO s FROM road_status() WHERE segment_id = 'troncal-40-50';
  IF s <> 'closed' THEN RAISE EXCEPTION 'bloqueo: esperaba closed, salió %', s; END IF;
  SELECT state INTO s FROM road_status() WHERE segment_id = 'troncal-20-30';
  IF s <> 'caution' THEN RAISE EXCEPTION 'retén: esperaba caution, salió %', s; END IF;
  SELECT state INTO s FROM road_status() WHERE segment_id = 'troncal-60-75';
  IF s <> 'open' THEN RAISE EXCEPTION 'despejado: esperaba open, salió %', s; END IF;
  IF (SELECT count(*) FROM drivers WHERE status = 'approved' AND available
      AND user_id IN ('00000000-0000-0000-0000-00000000de02', '00000000-0000-0000-0000-00000000de03')) <> 2 THEN
    RAISE EXCEPTION 'conductores demo no quedaron aprobados';
  END IF;
  IF (SELECT count(*) FROM favorite_places WHERE user_id = '00000000-0000-0000-0000-00000000de01') <> 3 THEN
    RAISE EXCEPTION 'favoritos demo';
  END IF;
  IF (SELECT balance FROM wallets WHERE user_id = '00000000-0000-0000-0000-00000000de01') <> 57000 THEN
    RAISE EXCEPTION 'saldo demo: %', (SELECT balance FROM wallets WHERE user_id = '00000000-0000-0000-0000-00000000de01');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM colectivo_departures WHERE status = 'open' AND depart_at > now()
                 AND from_node = 'rio-terminal' AND to_node = 'mai-centro') THEN
    RAISE EXCEPTION 'no hay salidas de colectivo programadas';
  END IF;
  IF (SELECT total FROM road_patterns(90) WHERE segment_id = 'troncal-40-50' AND kind = 'bloqueo') < 4 THEN
    RAISE EXCEPTION 'sin historial para el patrón';
  END IF;
END $$;

-- Escenario normal: el bloqueo desaparece.
SELECT demo_seed('normal');
DO $$
BEGIN
  IF (SELECT state FROM road_status() WHERE segment_id = 'troncal-40-50') <> 'open' THEN
    RAISE EXCEPTION 'normal: troncal-40-50 debía quedar abierta';
  END IF;
END $$;

-- Conductor automático: una invitada pide un mototaxi.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000de04', false);
CREATE TEMP TABLE t_req AS
SELECT request_ride('mototaxi', 11.5441, -72.9071, 'Parque Padilla', 11.5275, -72.8880,
                    'Uniguajira', 5000, '55555555-5555-5555-5555-555555555555') AS id;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', false);

-- Recién pedido: todavía nadie (espera 8 s).
SELECT demo_autodriver_tick();
DO $$
BEGIN
  IF (SELECT status FROM ride_requests WHERE id = (SELECT id FROM t_req)) <> 'open' THEN
    RAISE EXCEPTION 'aceptó antes de tiempo';
  END IF;
END $$;

UPDATE ride_requests SET created_at = now() - interval '10 seconds' WHERE id = (SELECT id FROM t_req);
SELECT demo_autodriver_tick();
DO $$
DECLARE r ride_requests;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = (SELECT id FROM t_req);
  IF r.status <> 'accepted' OR r.driver_id <> '00000000-0000-0000-0000-00000000de02' OR r.agreed_fare <> 5000 THEN
    RAISE EXCEPTION 'no lo aceptó el conductor demo: % %', r.status, r.driver_id;
  END IF;
END $$;

-- La pasajera ve al conductor acercándose.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000de04', false);
DO $$
DECLARE v RECORD;
BEGIN
  SELECT * INTO v FROM ride_driver_view((SELECT id FROM t_req));
  IF v.plate IS DISTINCT FROM 'GSD12A' OR v.lat IS NULL THEN
    RAISE EXCEPTION 'la pasajera no ve al conductor demo';
  END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', false);

UPDATE ride_requests SET accepted_at = now() - interval '31 seconds' WHERE id = (SELECT id FROM t_req);
SELECT demo_autodriver_tick();
DO $$
BEGIN
  IF (SELECT status FROM ride_requests WHERE id = (SELECT id FROM t_req)) <> 'in_progress' THEN
    RAISE EXCEPTION 'no recogió a los 30 s';
  END IF;
END $$;

-- Paga en efectivo durante el viaje; el conductor demo lo confirma.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000de04', false);
SELECT pay_ride((SELECT id FROM t_req), 'cash', '66666666-6666-6666-6666-666666666666');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', false);
UPDATE leg_payments SET created_at = now() - interval '10 seconds'
WHERE ride_request_id = (SELECT id FROM t_req);

UPDATE ride_requests SET accepted_at = now() - interval '95 seconds' WHERE id = (SELECT id FROM t_req);
SELECT demo_autodriver_tick();
DO $$
BEGIN
  IF (SELECT status FROM ride_requests WHERE id = (SELECT id FROM t_req)) <> 'completed' THEN
    RAISE EXCEPTION 'no terminó a los 90 s';
  END IF;
  IF (SELECT status FROM leg_payments WHERE ride_request_id = (SELECT id FROM t_req)) <> 'cash_confirmed' THEN
    RAISE EXCEPTION 'no confirmó el efectivo';
  END IF;
END $$;

-- Con el interruptor apagado no hace nada.
UPDATE app_flags SET enabled = false WHERE key = 'demo_autodriver';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000de04', false);
CREATE TEMP TABLE t_req2 AS
SELECT request_ride('mototaxi', 11.5441, -72.9071, 'Parque Padilla', 11.5275, -72.8880,
                    'Uniguajira', 5000, '77777777-7777-7777-7777-777777777777') AS id;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', false);
UPDATE ride_requests SET created_at = now() - interval '20 seconds' WHERE id = (SELECT id FROM t_req2);
SELECT demo_autodriver_tick();
DO $$
BEGIN
  IF (SELECT status FROM ride_requests WHERE id = (SELECT id FROM t_req2)) <> 'open' THEN
    RAISE EXCEPTION 'aceptó con el interruptor apagado';
  END IF;
END $$;

\echo '019 demo: OK'
