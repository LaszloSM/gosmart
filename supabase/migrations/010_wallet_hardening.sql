-- 010_wallet_hardening.sql
-- Billetera como único modelo de dinero, sin huecos de seguridad.
--
-- Problemas que corrige de 008_wallet_mock.sql:
--   1. recharge_wallet(p_user_id, ...) es SECURITY DEFINER y recibe el usuario
--      desde el cliente: cualquiera podía cargar o descontar la billetera de otro.
--   2. La policy "Users can update own wallet" permitía fijar el propio saldo.
--   3. La policy de INSERT en wallet_transactions permitía inventar movimientos.
--
-- Desde ahora el saldo solo cambia por RPCs que leen auth.uid() en el servidor.
-- Seguro de re-ejecutar.

-- ── Policies: solo lectura para el usuario ───────────────────────────────────
DROP POLICY IF EXISTS "Users can update own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can insert own wallet_transactions" ON wallet_transactions;

-- ── Idempotencia: reintentos offline no duplican movimientos (decisión E6) ───
ALTER TABLE wallet_transactions
  ADD COLUMN IF NOT EXISTS idempotency_key UUID;
CREATE UNIQUE INDEX IF NOT EXISTS wallet_transactions_idempotency_key_idx
  ON wallet_transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ── recharge_wallet queda solo para el servidor (service_role) ───────────────
REVOKE EXECUTE ON FUNCTION recharge_wallet(UUID, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;

-- ── Recarga simulada (hasta que llegue Wompi en la Fase 7) ───────────────────
-- Usa auth.uid(); el cliente no puede elegir de quién es la billetera.
-- Montos entre $1.000 y $200.000 COP. Mismo idempotency_key → mismo resultado.
CREATE OR REPLACE FUNCTION wallet_recharge_simulated(
  p_amount INTEGER,
  p_idempotency_key UUID
)
RETURNS TABLE (new_balance INTEGER, transaction_id UUID) AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_wallet_id   UUID;
  v_balance     INTEGER;
  v_existing_id UUID;
  v_txn_id      UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount < 1000 OR p_amount > 200000 THEN
    RAISE EXCEPTION 'invalid_amount' USING ERRCODE = '22023';
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'wallet_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- Reintento del mismo pedido: devolver lo ya hecho sin volver a sumar.
  SELECT id INTO v_existing_id
  FROM wallet_transactions
  WHERE idempotency_key = p_idempotency_key AND wallet_id = v_wallet_id;
  IF v_existing_id IS NOT NULL THEN
    RETURN QUERY SELECT v_balance, v_existing_id;
    RETURN;
  END IF;

  v_balance := v_balance + p_amount;

  UPDATE wallets SET balance = v_balance, updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, type, amount, description, idempotency_key, metadata)
  VALUES (v_wallet_id, 'recharge', p_amount, 'Recarga simulada', p_idempotency_key,
          jsonb_build_object('simulated', true))
  RETURNING id INTO v_txn_id;

  RETURN QUERY SELECT v_balance, v_txn_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION wallet_recharge_simulated(INTEGER, UUID) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION wallet_recharge_simulated(INTEGER, UUID) TO authenticated;

-- ── Billetera para usuarios que se registraron antes del trigger de 008 ──────
INSERT INTO wallets (user_id, card_number, balance)
SELECT u.id, generate_gosmart_card_number(), 10000
FROM auth.users u
LEFT JOIN wallets w ON w.user_id = u.id
WHERE w.id IS NULL
ON CONFLICT (user_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
