-- supabase/tests/010_wallet_hardening_test.sql
-- Pruebas de la billetera endurecida. Cualquier fallo aborta con RAISE EXCEPTION.
-- Requiere: _supabase_stub.sql, 008_wallet_mock.sql y 010_wallet_hardening.sql aplicados.
\set ON_ERROR_STOP on

-- Usuarios de prueba (el trigger de 008 les crea billetera con $10.000)
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.co'),
  ('00000000-0000-0000-0000-00000000000b', 'beto@test.co')
ON CONFLICT DO NOTHING;

GRANT SELECT ON wallets, wallet_transactions TO authenticated;
GRANT UPDATE ON wallets TO authenticated;
GRANT INSERT ON wallet_transactions TO authenticated;

-- Todo lo siguiente corre como Ana, usuaria autenticada
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);

-- 1. Recarga propia suma y deja un movimiento
DO $$
DECLARE r RECORD;
BEGIN
  SELECT * INTO r FROM wallet_recharge_simulated(5000, '11111111-1111-1111-1111-111111111111');
  IF r.new_balance <> 15000 THEN RAISE EXCEPTION '1: saldo esperado 15000, fue %', r.new_balance; END IF;
END $$;

-- 2. Mismo idempotency_key no vuelve a sumar (reintento offline, E6)
DO $$
DECLARE r RECORD; n INT;
BEGIN
  SELECT * INTO r FROM wallet_recharge_simulated(5000, '11111111-1111-1111-1111-111111111111');
  IF r.new_balance <> 15000 THEN RAISE EXCEPTION '2: el reintento sumó dos veces (saldo %)', r.new_balance; END IF;
  SELECT count(*) INTO n FROM wallet_transactions;
  IF n <> 1 THEN RAISE EXCEPTION '2: se esperaban 1 movimientos visibles, hubo %', n; END IF;
END $$;

-- 3. Montos fuera de rango se rechazan
DO $$
BEGIN
  BEGIN
    PERFORM wallet_recharge_simulated(999999, gen_random_uuid());
    RAISE EXCEPTION '3: aceptó un monto mayor al límite';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM wallet_recharge_simulated(-5000, gen_random_uuid());
    RAISE EXCEPTION '3: aceptó un monto negativo';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;

-- 4. El cliente ya no puede llamar recharge_wallet para cargar la billetera de Beto
DO $$
BEGIN
  BEGIN
    PERFORM recharge_wallet('00000000-0000-0000-0000-00000000000b', 50000, 'robo');
    RAISE EXCEPTION '4: un usuario pudo ejecutar recharge_wallet';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 5. Ana no puede fijar su saldo ni inventar movimientos (RLS sin policies de escritura)
DO $$
DECLARE n INT;
BEGIN
  UPDATE wallets SET balance = 999999;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION '5: el usuario pudo cambiar su saldo'; END IF;
  BEGIN
    INSERT INTO wallet_transactions (wallet_id, type, amount)
    SELECT id, 'bonus', 1000000 FROM wallets;
    RAISE EXCEPTION '5: el usuario pudo insertar un movimiento';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 6. Ana solo ve su propia billetera
DO $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM wallets;
  IF n <> 1 THEN RAISE EXCEPTION '6: Ana ve % billeteras', n; END IF;
END $$;

-- 7. Sin sesión no hay recarga
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
BEGIN
  BEGIN
    PERFORM wallet_recharge_simulated(5000, gen_random_uuid());
    RAISE EXCEPTION '7: recargó sin sesión';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;
\echo 'OK 010_wallet_hardening: 7 pruebas'
