-- 016_payments.sql
-- Fase 7 · Pago por tramo + recibo único (D5).
--
--   Cada tramo se paga al cerrarse: con saldo (billetera → billetera del
--   conductor), por QR (el conductor genera un cobro, el pasajero lo paga) o
--   en efectivo (el conductor confirma que lo recibió). El viaje entrega UN
--   recibo con el desglose. No hay retención de dinero de terceros.
--
--   charges          cobro creado por el conductor (lo que va en el QR)
--   leg_payments     cada pago, idempotente
--   wallet_topups    recargas por Wompi (sandbox); las acredita solo el webhook
--
-- Bloqueo de billeteras siempre en el mismo orden (por id) para no trabarse.
-- Seguro de re-ejecutar.

-- La billetera ahora también recibe ganancias del conductor.
ALTER TABLE wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE wallet_transactions ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type IN ('recharge', 'trip', 'refund', 'bonus', 'earning'));

-- ── Cobros (QR del conductor) ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS charges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id   UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  amount      INTEGER NOT NULL CHECK (amount BETWEEN 500 AND 500000),
  ride_request_id UUID REFERENCES ride_requests(id) ON DELETE SET NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid', 'cancelled', 'expired')),
  paid_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + interval '15 minutes'
);
ALTER TABLE charges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS charges_parties ON charges;
CREATE POLICY charges_parties ON charges
  FOR SELECT USING (driver_id = auth.uid() OR paid_by = auth.uid() OR is_admin());
REVOKE ALL ON charges FROM anon;
REVOKE INSERT, UPDATE, DELETE ON charges FROM authenticated;
GRANT SELECT ON charges TO authenticated;

-- ── Pagos ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leg_payments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id        UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  amount           INTEGER NOT NULL CHECK (amount > 0),
  method           TEXT NOT NULL CHECK (method IN ('wallet', 'qr', 'cash')),
  status           TEXT NOT NULL CHECK (status IN ('paid', 'cash_pending', 'cash_confirmed', 'refunded')),
  ride_request_id  UUID REFERENCES ride_requests(id) ON DELETE SET NULL,
  charge_id        UUID REFERENCES charges(id) ON DELETE SET NULL,
  trip_leg_id      UUID REFERENCES trip_legs(id) ON DELETE SET NULL,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at     TIMESTAMPTZ,
  UNIQUE (passenger_id, idempotency_key)
);
-- Un viaje de mototaxi se paga una sola vez.
CREATE UNIQUE INDEX IF NOT EXISTS leg_payments_ride_once
  ON leg_payments(ride_request_id) WHERE ride_request_id IS NOT NULL AND status <> 'refunded';

ALTER TABLE leg_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS leg_payments_parties ON leg_payments;
CREATE POLICY leg_payments_parties ON leg_payments
  FOR SELECT USING (passenger_id = auth.uid() OR driver_id = auth.uid() OR is_admin());
REVOKE ALL ON leg_payments FROM anon;
REVOKE INSERT, UPDATE, DELETE ON leg_payments FROM authenticated;
GRANT SELECT ON leg_payments TO authenticated;

-- Mueve saldo de una billetera a otra, bloqueando ambas en orden fijo.
-- Uso interno (no se expone al cliente).
CREATE OR REPLACE FUNCTION _wallet_transfer(
  p_from_user UUID, p_to_user UUID, p_amount INTEGER, p_desc TEXT, p_meta JSONB)
RETURNS VOID AS $$
DECLARE
  w_from wallets;
  w_to   wallets;
BEGIN
  PERFORM 1 FROM wallets WHERE user_id IN (p_from_user, p_to_user) ORDER BY id FOR UPDATE;
  SELECT * INTO w_from FROM wallets WHERE user_id = p_from_user;
  SELECT * INTO w_to   FROM wallets WHERE user_id = p_to_user;
  IF w_from.id IS NULL OR w_to.id IS NULL THEN
    RAISE EXCEPTION 'wallet_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF w_from.card_status <> 'active' THEN
    RAISE EXCEPTION 'wallet_blocked' USING ERRCODE = '55000';
  END IF;
  IF w_from.balance < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance' USING ERRCODE = '55000';
  END IF;
  UPDATE wallets SET balance = balance - p_amount, updated_at = now() WHERE id = w_from.id;
  UPDATE wallets SET balance = balance + p_amount, updated_at = now() WHERE id = w_to.id;
  INSERT INTO wallet_transactions (wallet_id, type, amount, description, metadata)
  VALUES (w_from.id, 'trip', -p_amount, p_desc, p_meta),
         (w_to.id, 'earning', p_amount, p_desc, p_meta);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _wallet_transfer(UUID, UUID, INTEGER, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- Marca el tramo del viaje encadenado con lo que se pagó.
CREATE OR REPLACE FUNCTION _note_leg_fare(p_leg UUID, p_amount INTEGER)
RETURNS VOID AS $$
  UPDATE trip_legs SET agreed_fare = p_amount WHERE id = p_leg;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _note_leg_fare(UUID, INTEGER) FROM PUBLIC, anon, authenticated;

-- Pagar el viaje de mototaxi/taxi aceptado: con saldo o en efectivo.
CREATE OR REPLACE FUNCTION pay_ride(p_request_id UUID, p_method TEXT, p_idempotency_key UUID)
RETURNS leg_payments AS $$
DECLARE
  r ride_requests;
  p leg_payments;
BEGIN
  SELECT * INTO p FROM leg_payments
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF p.id IS NOT NULL THEN RETURN p; END IF;

  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL OR r.passenger_id <> auth.uid() THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
  END IF;
  IF r.status NOT IN ('in_progress', 'completed') OR r.driver_id IS NULL THEN
    RAISE EXCEPTION 'not_payable' USING ERRCODE = '55000';
  END IF;
  IF EXISTS (SELECT 1 FROM leg_payments WHERE ride_request_id = r.id AND status <> 'refunded') THEN
    RAISE EXCEPTION 'already_paid' USING ERRCODE = '55000';
  END IF;
  IF p_method NOT IN ('wallet', 'cash') THEN
    RAISE EXCEPTION 'invalid_method' USING ERRCODE = '22023';
  END IF;

  IF p_method = 'wallet' THEN
    PERFORM _wallet_transfer(auth.uid(), r.driver_id, r.agreed_fare,
      'Viaje en ' || r.service, jsonb_build_object('ride_request_id', r.id));
  END IF;
  INSERT INTO leg_payments (passenger_id, driver_id, amount, method, status,
                            ride_request_id, trip_leg_id, idempotency_key)
  VALUES (auth.uid(), r.driver_id, r.agreed_fare, p_method,
          CASE WHEN p_method = 'cash' THEN 'cash_pending' ELSE 'paid' END,
          r.id, r.trip_leg_id, p_idempotency_key)
  RETURNING * INTO p;
  IF r.trip_leg_id IS NOT NULL THEN PERFORM _note_leg_fare(r.trip_leg_id, r.agreed_fare); END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- El conductor confirma que recibió el efectivo.
CREATE OR REPLACE FUNCTION confirm_cash(p_payment_id UUID)
RETURNS leg_payments AS $$
DECLARE
  p leg_payments;
BEGIN
  UPDATE leg_payments SET status = 'cash_confirmed', confirmed_at = now()
  WHERE id = p_payment_id AND driver_id = auth.uid() AND status = 'cash_pending'
  RETURNING * INTO p;
  IF p.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- QR: el conductor crea un cobro; el pasajero lo paga con su saldo.
CREATE OR REPLACE FUNCTION create_charge(p_amount INTEGER, p_ride_request_id UUID DEFAULT NULL)
RETURNS charges AS $$
DECLARE
  c charges;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM drivers WHERE user_id = auth.uid() AND status = 'approved') THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO charges (driver_id, amount, ride_request_id)
  VALUES (auth.uid(), p_amount, p_ride_request_id) RETURNING * INTO c;
  RETURN c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Lo que el pasajero ve al escanear: monto y a quién, antes de pagar.
CREATE OR REPLACE FUNCTION charge_preview(p_charge_id UUID)
RETURNS TABLE (amount INTEGER, driver_first_name TEXT, plate TEXT, status TEXT) AS $$
  SELECT c.amount, split_part(d.full_name, ' ', 1),
         (SELECT v.plate FROM vehicles v WHERE v.driver_id = d.user_id LIMIT 1),
         CASE WHEN c.status = 'open' AND c.expires_at <= now() THEN 'expired' ELSE c.status END
  FROM charges c JOIN drivers d ON d.user_id = c.driver_id
  WHERE c.id = p_charge_id
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION pay_charge(p_charge_id UUID, p_idempotency_key UUID,
                                      p_trip_leg_id UUID DEFAULT NULL)
RETURNS leg_payments AS $$
DECLARE
  c charges;
  p leg_payments;
  v_leg UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT * INTO p FROM leg_payments
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF p.id IS NOT NULL THEN RETURN p; END IF;

  SELECT * INTO c FROM charges WHERE id = p_charge_id FOR UPDATE;
  IF c.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF c.driver_id = auth.uid() THEN RAISE EXCEPTION 'own_charge' USING ERRCODE = '42501'; END IF;
  IF c.status <> 'open' OR c.expires_at <= now() THEN
    RAISE EXCEPTION 'charge_closed' USING ERRCODE = '55000';
  END IF;
  -- Solo se liga a un tramo propio.
  SELECT l.id INTO v_leg FROM trip_legs l JOIN chained_trips t ON t.id = l.trip_id
  WHERE l.id = p_trip_leg_id AND t.passenger_id = auth.uid();

  PERFORM _wallet_transfer(auth.uid(), c.driver_id, c.amount, 'Pago con QR',
                           jsonb_build_object('charge_id', c.id));
  UPDATE charges SET status = 'paid', paid_by = auth.uid() WHERE id = c.id;
  INSERT INTO leg_payments (passenger_id, driver_id, amount, method, status, charge_id,
                            ride_request_id, trip_leg_id, idempotency_key)
  VALUES (auth.uid(), c.driver_id, c.amount, 'qr', 'paid', c.id,
          c.ride_request_id, v_leg, p_idempotency_key)
  RETURNING * INTO p;
  IF v_leg IS NOT NULL THEN PERFORM _note_leg_fare(v_leg, c.amount); END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Recibo único del viaje (D5) ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trip_receipt(p_trip_id UUID)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'trip_id', t.id,
    'origin', t.origin_label,
    'destination', t.dest_label,
    'status', t.status,
    'created_at', t.created_at,
    'legs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'seq', l.seq, 'mode', l.mode, 'from', l.from_label, 'to', l.to_label,
        'status', l.status,
        'paid', coalesce((SELECT sum(p.amount) FROM leg_payments p
                          WHERE p.trip_leg_id = l.id AND p.status IN ('paid', 'cash_confirmed', 'cash_pending')), 0),
        'methods', coalesce((SELECT jsonb_agg(DISTINCT p.method) FROM leg_payments p
                             WHERE p.trip_leg_id = l.id AND p.status <> 'refunded'), '[]'),
        'reference_min', l.fare_min, 'reference_max', l.fare_max
      ) ORDER BY l.seq) FROM trip_legs l WHERE l.trip_id = t.id), '[]'),
    'total_paid', coalesce((
      SELECT sum(p.amount) FROM leg_payments p JOIN trip_legs l ON l.id = p.trip_leg_id
      WHERE l.trip_id = t.id AND p.status IN ('paid', 'cash_confirmed', 'cash_pending')), 0)
  )
  FROM chained_trips t
  WHERE t.id = p_trip_id AND t.passenger_id = auth.uid()
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Recargas por Wompi (sandbox) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallet_topups (
  reference   TEXT PRIMARY KEY,                 -- la ponemos nosotros: gs_<uuid>
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount      INTEGER NOT NULL CHECK (amount BETWEEN 1000 AND 500000),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'error')),
  provider_id TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at  TIMESTAMPTZ
);
ALTER TABLE wallet_topups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallet_topups_own ON wallet_topups;
CREATE POLICY wallet_topups_own ON wallet_topups FOR SELECT USING (user_id = auth.uid());
REVOKE ALL ON wallet_topups FROM anon;
REVOKE INSERT, UPDATE, DELETE ON wallet_topups FROM authenticated;
GRANT SELECT ON wallet_topups TO authenticated;

-- Solo el servidor (Edge Function con service_role) crea y liquida recargas.
CREATE OR REPLACE FUNCTION wallet_topup_create(p_user UUID, p_amount INTEGER)
RETURNS TEXT AS $$
DECLARE
  v_ref TEXT := 'gs_' || replace(gen_random_uuid()::text, '-', '');
BEGIN
  INSERT INTO wallet_topups (reference, user_id, amount) VALUES (v_ref, p_user, p_amount);
  RETURN v_ref;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Idempotente: el webhook puede llegar varias veces; se acredita una sola.
CREATE OR REPLACE FUNCTION wallet_topup_settle(
  p_reference TEXT, p_status TEXT, p_amount INTEGER, p_provider_id TEXT)
RETURNS TEXT AS $$
DECLARE
  t wallet_topups;
  w wallets;
BEGIN
  SELECT * INTO t FROM wallet_topups WHERE reference = p_reference FOR UPDATE;
  IF t.reference IS NULL THEN RETURN 'unknown_reference'; END IF;
  IF t.status <> 'pending' THEN RETURN 'already_settled'; END IF;
  IF p_status = 'APPROVED' THEN
    IF p_amount <> t.amount THEN
      UPDATE wallet_topups SET status = 'error', provider_id = p_provider_id, settled_at = now()
      WHERE reference = p_reference;
      RETURN 'amount_mismatch';
    END IF;
    SELECT * INTO w FROM wallets WHERE user_id = t.user_id FOR UPDATE;
    UPDATE wallets SET balance = balance + t.amount, updated_at = now() WHERE id = w.id;
    INSERT INTO wallet_transactions (wallet_id, type, amount, description, metadata)
    VALUES (w.id, 'recharge', t.amount, 'Recarga con Wompi',
            jsonb_build_object('reference', t.reference, 'provider_id', p_provider_id));
    UPDATE wallet_topups SET status = 'approved', provider_id = p_provider_id, settled_at = now()
    WHERE reference = p_reference;
    RETURN 'approved';
  END IF;
  UPDATE wallet_topups
  SET status = CASE WHEN p_status IN ('DECLINED', 'VOIDED') THEN 'declined' ELSE 'error' END,
      provider_id = p_provider_id, settled_at = now()
  WHERE reference = p_reference;
  RETURN 'declined';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION wallet_topup_create(UUID, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION wallet_topup_settle(TEXT, TEXT, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION wallet_topup_create(UUID, INTEGER) TO service_role;
GRANT  EXECUTE ON FUNCTION wallet_topup_settle(TEXT, TEXT, INTEGER, TEXT) TO service_role;

INSERT INTO app_flags (key, enabled) VALUES ('wompi_enabled', false) ON CONFLICT (key) DO NOTHING;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'pay_ride(uuid,text,uuid)', 'confirm_cash(uuid)',
    'create_charge(integer,uuid)', 'charge_preview(uuid)',
    'pay_charge(uuid,uuid,uuid)', 'trip_receipt(uuid)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
