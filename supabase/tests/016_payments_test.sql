-- supabase/tests/016_payments_test.sql
-- Requiere: stub, _profiles_fixture, 008, 010, 011–016 y 015_dispatch_test.sql
-- (reusa sus usuarios y conductores). Cada usuario arranca con $10.000.
\set ON_ERROR_STOP on

-- Supabase da SELECT por defecto; el stub no.
GRANT SELECT ON wallets, wallet_transactions TO authenticated;

CREATE TEMP TABLE IF NOT EXISTS t_pay (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t_pay TO PUBLIC;

CREATE OR REPLACE FUNCTION pg_temp.bal(p UUID) RETURNS INT AS $$
  SELECT balance FROM wallets WHERE user_id = p $$ LANGUAGE sql;

-- Viaje nuevo: pasajera A01 con Moto 1 (D01), tarifa 5.000
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  INSERT INTO t_pay VALUES ('req', request_ride('mototaxi', 11.5441, -72.9071, 'P', 11.53, -72.91,
    'T', 5000, gen_random_uuid()));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', false);
-- D01 quedó ocupado en el test de carrera de 015 si se corrió; lo liberamos.
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE driver_id = '00000000-0000-0000-0000-000000000d01'
  AND status IN ('accepted', 'in_progress');
SET ROLE authenticated;
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t_pay WHERE k = 'req'));
  PERFORM ride_transition((SELECT id FROM t_pay WHERE k = 'req'), 'in_progress');
END $$;

-- 1. Paga con saldo: sale de la pasajera y entra al conductor, una sola vez
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
RESET ROLE;
CREATE TEMP TABLE t_bal AS SELECT
  pg_temp.bal('00000000-0000-0000-0000-000000000a01') AS a,
  pg_temp.bal('00000000-0000-0000-0000-000000000d01') AS d;
GRANT ALL ON t_bal TO PUBLIC;
SET ROLE authenticated;
DO $$
DECLARE p leg_payments; p2 leg_payments;
BEGIN
  p := pay_ride((SELECT id FROM t_pay WHERE k = 'req'), 'wallet', '66666666-6666-6666-6666-666666666666');
  p2 := pay_ride((SELECT id FROM t_pay WHERE k = 'req'), 'wallet', '66666666-6666-6666-6666-666666666666');
  IF p.id <> p2.id THEN RAISE EXCEPTION '1: el reintento cobró dos veces'; END IF;
  BEGIN
    PERFORM pay_ride((SELECT id FROM t_pay WHERE k = 'req'), 'wallet', gen_random_uuid());
    RAISE EXCEPTION '1: cobró el mismo viaje con otra llave';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
END $$;
RESET ROLE;
DO $$
DECLARE b RECORD;
BEGIN
  SELECT * INTO b FROM t_bal;
  IF pg_temp.bal('00000000-0000-0000-0000-000000000a01') <> b.a - 5000 THEN RAISE EXCEPTION '1: saldo pasajera'; END IF;
  IF pg_temp.bal('00000000-0000-0000-0000-000000000d01') <> b.d + 5000 THEN RAISE EXCEPTION '1: saldo conductor'; END IF;
END $$;

-- 2. Saldo insuficiente: no se mueve nada
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE c charges;
BEGIN
  c := create_charge(500000);
  INSERT INTO t_pay VALUES ('big', c.id);
  c := create_charge(3000);
  INSERT INTO t_pay VALUES ('qr', c.id);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE before INT; pv RECORD;
BEGIN
  SELECT balance INTO before FROM wallets WHERE user_id = auth.uid();
  BEGIN
    PERFORM pay_charge((SELECT id FROM t_pay WHERE k = 'big'), gen_random_uuid());
    RAISE EXCEPTION '2: pagó sin saldo';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  IF (SELECT balance FROM wallets WHERE user_id = auth.uid()) <> before THEN
    RAISE EXCEPTION '2: el saldo cambió tras un pago fallido';
  END IF;
  -- 3. QR: ve monto y primer nombre antes de pagar; paga una vez
  SELECT * INTO pv FROM charge_preview((SELECT id FROM t_pay WHERE k = 'qr'));
  IF pv.amount <> 3000 OR pv.driver_first_name <> 'Moto' THEN RAISE EXCEPTION '3: preview %', pv; END IF;
  PERFORM pay_charge((SELECT id FROM t_pay WHERE k = 'qr'), gen_random_uuid());
  BEGIN
    PERFORM pay_charge((SELECT id FROM t_pay WHERE k = 'qr'), gen_random_uuid());
    RAISE EXCEPTION '3: pagó dos veces el mismo QR';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  IF (SELECT balance FROM wallets WHERE user_id = auth.uid()) <> before - 3000 THEN
    RAISE EXCEPTION '3: saldo tras QR';
  END IF;
END $$;

-- 4. Nadie puede llamar la transferencia interna ni acreditar recargas
DO $$
BEGIN
  BEGIN
    PERFORM _wallet_transfer('00000000-0000-0000-0000-000000000a01', auth.uid(), 9000, 'robo', '{}');
    RAISE EXCEPTION '4: transferencia directa permitida';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM wallet_topup_settle('gs_x', 'APPROVED', 100000, 'x');
    RAISE EXCEPTION '4: acreditó una recarga desde el cliente';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 5. Efectivo: queda pendiente hasta que el conductor confirma
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
RESET ROLE;
UPDATE ride_requests SET status = 'completed' WHERE driver_id = '00000000-0000-0000-0000-000000000d02'
  AND status IN ('accepted', 'in_progress');
SET ROLE authenticated;
DO $$ BEGIN
  INSERT INTO t_pay VALUES ('req2', request_ride('mototaxi', 11.5441, -72.9071, 'P', 11.53, -72.91,
    'T', 4000, gen_random_uuid()));
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ BEGIN
  PERFORM accept_ride((SELECT id FROM t_pay WHERE k = 'req2'));
  PERFORM ride_transition((SELECT id FROM t_pay WHERE k = 'req2'), 'in_progress');
  PERFORM ride_transition((SELECT id FROM t_pay WHERE k = 'req2'), 'completed');
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE p leg_payments;
BEGIN
  p := pay_ride((SELECT id FROM t_pay WHERE k = 'req2'), 'cash', gen_random_uuid());
  IF p.status <> 'cash_pending' THEN RAISE EXCEPTION '5: efectivo quedó %', p.status; END IF;
  INSERT INTO t_pay VALUES ('cash', p.id);
  BEGIN
    PERFORM confirm_cash(p.id);
    RAISE EXCEPTION '5: el pasajero confirmó su propio efectivo';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$
DECLARE p leg_payments;
BEGIN
  p := confirm_cash((SELECT id FROM t_pay WHERE k = 'cash'));
  IF p.status <> 'cash_confirmed' THEN RAISE EXCEPTION '5: no confirmó'; END IF;
END $$;
RESET ROLE;

-- 6. Wompi: el webhook acredita una sola vez y rechaza montos distintos
DO $$
DECLARE ref TEXT; ref2 TEXT; before INT; r TEXT;
BEGIN
  before := pg_temp.bal('00000000-0000-0000-0000-000000000a02');
  ref := wallet_topup_create('00000000-0000-0000-0000-000000000a02', 20000);
  r := wallet_topup_settle(ref, 'APPROVED', 20000, 'w1');
  IF r <> 'approved' THEN RAISE EXCEPTION '6: %', r; END IF;
  r := wallet_topup_settle(ref, 'APPROVED', 20000, 'w1');
  IF r <> 'already_settled' THEN RAISE EXCEPTION '6: segundo webhook %', r; END IF;
  IF pg_temp.bal('00000000-0000-0000-0000-000000000a02') <> before + 20000 THEN
    RAISE EXCEPTION '6: acreditó mal';
  END IF;
  ref2 := wallet_topup_create('00000000-0000-0000-0000-000000000a02', 20000);
  r := wallet_topup_settle(ref2, 'APPROVED', 99000, 'w2');
  IF r <> 'amount_mismatch' THEN RAISE EXCEPTION '6: aceptó monto distinto (%)', r; END IF;
END $$;

-- 7. Recibo único del viaje con desglose
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE t UUID; l UUID; c UUID; rc JSONB;
BEGIN
  t := create_trip('Parque', 'Terminal', '[{"mode":"mototaxi","from_label":"Parque","to_label":"Terminal","fare_min":3000,"fare_max":5000}]'::jsonb, gen_random_uuid());
  SELECT id INTO l FROM trip_legs WHERE trip_id = t;
  INSERT INTO t_pay VALUES ('trip', t), ('leg', l);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d02', false);
DO $$ DECLARE ch charges; BEGIN
  ch := create_charge(4500); INSERT INTO t_pay VALUES ('qr2', ch.id);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', false);
DO $$
DECLARE rc JSONB;
BEGIN
  PERFORM pay_charge((SELECT id FROM t_pay WHERE k = 'qr2'), gen_random_uuid(), (SELECT id FROM t_pay WHERE k = 'leg'));
  rc := trip_receipt((SELECT id FROM t_pay WHERE k = 'trip'));
  IF (rc->>'total_paid')::int <> 4500 THEN RAISE EXCEPTION '7: total %', rc->>'total_paid'; END IF;
  IF rc->'legs'->0->'methods'->>0 <> 'qr' THEN RAISE EXCEPTION '7: método %', rc->'legs'->0->'methods'; END IF;
END $$;
-- Otro usuario no ve ese recibo
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', false);
DO $$ BEGIN
  IF trip_receipt((SELECT id FROM t_pay WHERE k = 'trip')) IS NOT NULL THEN
    RAISE EXCEPTION '7: recibo ajeno visible';
  END IF;
END $$;
RESET ROLE;

\echo '016_payments_test: OK'
