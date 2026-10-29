-- supabase/tests/023_driver_earnings_test.sql (después de 022_offer_cards_test.sql)
\set ON_ERROR_STOP on
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
CREATE TEMP TABLE IF NOT EXISTS t23 (k TEXT PRIMARY KEY, id UUID, n INTEGER);
GRANT ALL ON t23 TO PUBLIC;

SET ROLE authenticated;
-- Antes: lo que ya tenía Moto 2
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
INSERT INTO t23 SELECT 'before', NULL, today_total FROM driver_earnings();
INSERT INTO t23 SELECT 'before_trips', NULL, today_trips FROM driver_earnings();

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  INSERT INTO t23 VALUES ('req', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 7000, gen_random_uuid()), NULL);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t23 WHERE k = 'req'));
  PERFORM ride_transition((SELECT id FROM t23 WHERE k = 'req'), 'in_progress');
  PERFORM ride_transition((SELECT id FROM t23 WHERE k = 'req'), 'completed');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE p leg_payments;
BEGIN
  -- En efectivo (la pasajera de prueba ya gastó su saldo en otras pruebas)
  p := pay_ride((SELECT id FROM t23 WHERE k = 'req'), 'cash', gen_random_uuid());
  INSERT INTO t23 VALUES ('pay', p.id, NULL);
  -- La pasajera no es conductora: sus ganancias son cero
  IF (SELECT week_trips FROM driver_earnings()) <> 0 THEN RAISE EXCEPTION '1: la pasajera tiene viajes'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE e RECORD;
BEGIN
  -- El efectivo cuenta cuando el conductor confirma que lo recibió
  SELECT * INTO e FROM driver_earnings();
  IF e.today_total <> (SELECT n FROM t23 WHERE k = 'before') THEN RAISE EXCEPTION '2: contó efectivo sin confirmar'; END IF;
  PERFORM confirm_cash((SELECT id FROM t23 WHERE k = 'pay'));
  SELECT * INTO e FROM driver_earnings();
  IF e.today_cash < 7000 THEN RAISE EXCEPTION '2: efectivo %', e.today_cash; END IF;
  IF e.today_total - (SELECT n FROM t23 WHERE k = 'before') <> 7000 THEN
    RAISE EXCEPTION '2: hoy suma %', e.today_total;
  END IF;
  IF e.today_trips - (SELECT n FROM t23 WHERE k = 'before_trips') <> 1 THEN
    RAISE EXCEPTION '2: viajes %', e.today_trips;
  END IF;
  IF e.week_total < e.today_total OR e.week_trips < e.today_trips THEN RAISE EXCEPTION '2: semana < hoy'; END IF;
END $$;

RESET ROLE;
\echo '023 driver earnings: OK'
