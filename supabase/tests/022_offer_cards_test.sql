-- supabase/tests/022_offer_cards_test.sql (después de 021_map_alerts_test.sql)
\set ON_ERROR_STOP on
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
CREATE TEMP TABLE IF NOT EXISTS t22 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t22 TO PUBLIC;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  INSERT INTO t22 VALUES ('req', request_ride('mototaxi', 11.5441, -72.9071, 'Parque', 11.53, -72.91, 'Uni', 5000, gen_random_uuid()));
END $$;

-- Moto 2 está a ~1 km y ofrece $6.000
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM driver_ping(11.5531, -72.9071);
  PERFORM counter_offer((SELECT id FROM t22 WHERE k = 'req'), 6000);
  -- El conductor no ve las tarjetas (son del pasajero)
  IF EXISTS (SELECT 1 FROM ride_offer_cards((SELECT id FROM t22 WHERE k = 'req'))) THEN
    RAISE EXCEPTION '1: el conductor ve las tarjetas';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$
DECLARE c RECORD;
BEGIN
  SELECT * INTO c FROM ride_offer_cards((SELECT id FROM t22 WHERE k = 'req'));
  IF c.id IS NULL THEN RAISE EXCEPTION '2: la pasajera no ve la oferta'; END IF;
  IF c.fare <> 6000 OR c.first_name <> 'Moto' THEN RAISE EXCEPTION '2: oferta rara % %', c.fare, c.first_name; END IF;
  IF c.pickup_km NOT BETWEEN 0.8 AND 1.2 THEN RAISE EXCEPTION '2: distancia %', c.pickup_km; END IF;
  IF c.eta_min NOT BETWEEN 3 AND 6 THEN RAISE EXCEPTION '2: eta %', c.eta_min; END IF;
END $$;

-- Otra persona no ve nada
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM ride_offer_cards((SELECT id FROM t22 WHERE k = 'req'))) THEN
    RAISE EXCEPTION '3: un tercero ve las tarjetas';
  END IF;
END $$;

-- Aceptada la oferta, ya no hay tarjetas pendientes
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  PERFORM accept_offer((SELECT c.id FROM ride_offer_cards((SELECT id FROM t22 WHERE k = 'req')) c));
  IF EXISTS (SELECT 1 FROM ride_offer_cards((SELECT id FROM t22 WHERE k = 'req'))) THEN
    RAISE EXCEPTION '4: siguen tarjetas tras aceptar';
  END IF;
END $$;

RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE status IN ('open', 'accepted', 'in_progress');
\echo '022 offer cards: OK'
