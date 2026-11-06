-- 025_mvp_real.sql
-- Hacia el MVP de salida: nada simulado en los viajes.
--   1. Fuera el "conductor de demo" (demo_autodriver): aceptaba solo cualquier
--      mototaxi o taxi pedido y lo movía en el mapa. Se apaga, se desprograma
--      su tarea de pg_cron y se borran sus funciones.
--   2. Cancelar con motivo (como InDrive/Uber): motivos cerrados, sin texto
--      libre. Si ya hay conductor asignado, el motivo es obligatorio.
--   3. cancel_trip también cancela la solicitud de mototaxi/taxi del tramo (antes
--      el conductor seguía viniendo) y pide motivo si ya la aceptó alguien.
--   4. Lugares guardados con nombre: máximo 10 por persona (además de Casa y
--      Trabajo), nombre de 1 a 40 caracteres.
--   5. Solo efectivo mientras Wompi esté apagado (app_flags.wompi_enabled):
--      no se paga con saldo ni con QR de saldo, no hay recarga simulada y las
--      cuentas nuevas empiezan con $0 (sin bono de prueba).
--   6. Tiempo real: ride_requests y ride_offers en la publicación de
--      Supabase Realtime (la app reacciona al instante; RLS sigue filtrando).
--   7. admin_cancellations(días): cancelaciones por motivo y por quién.
-- Seguro de re-ejecutar.

-- ── 1. Sin conductor de demo ────────────────────────────────────────────────
UPDATE app_flags SET enabled = false WHERE key = 'demo_autodriver';
DELETE FROM app_flags WHERE key = 'demo_autodriver';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    EXECUTE $q$SELECT cron.unschedule(jobid) FROM cron.job
               WHERE jobname = 'gosmart-demo-driver'$q$;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron: %', SQLERRM;
END $$;

DROP FUNCTION IF EXISTS demo_autodriver_tick();
DROP FUNCTION IF EXISTS demo_seed(TEXT);
DROP FUNCTION IF EXISTS demo_user(TEXT);

-- Las cuentas de ejemplo (conductores y pasajera inventados) no pueden
-- aparecer como ofertas reales: se borran con todo lo suyo (ON DELETE CASCADE).
DO $$
BEGIN
  DELETE FROM auth.users
  WHERE lower(email) IN ('pasajero@example.com', 'conductor@example.com', 'colectivo@example.com');
EXCEPTION WHEN OTHERS THEN
  -- Si algo las sigue referenciando, al menos que no puedan conducir.
  RAISE NOTICE 'cuentas demo: %', SQLERRM;
  UPDATE drivers SET status = 'suspended'
  WHERE user_id IN (SELECT id FROM auth.users WHERE lower(email) IN
    ('pasajero@example.com', 'conductor@example.com', 'colectivo@example.com'));
END $$;

-- ── 2. Cancelar con motivo ──────────────────────────────────────────────────
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS cancelled_by TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ride_requests_cancel_reason_chk') THEN
    ALTER TABLE ride_requests ADD CONSTRAINT ride_requests_cancel_reason_chk CHECK (
      cancel_reason IS NULL OR cancel_reason IN (
        -- pasajero
        'driver_late', 'driver_not_moving', 'driver_asked', 'wrong_address',
        'changed_plans', 'found_other', 'price_changed', 'unsafe',
        -- conductor
        'passenger_no_show', 'passenger_asked', 'vehicle_problem', 'unsafe_pickup',
        -- los dos
        'other'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ride_requests_cancelled_by_chk') THEN
    ALTER TABLE ride_requests ADD CONSTRAINT ride_requests_cancelled_by_chk
      CHECK (cancelled_by IS NULL OR cancelled_by IN ('passenger', 'driver'));
  END IF;
END $$;

-- Cancelar una solicitud. Abierta (nadie la tomó): solo el pasajero, motivo
-- opcional. Aceptada (el conductor ya viene): pasajero o conductor, motivo
-- obligatorio. En curso o terminada: no se cancela.
CREATE OR REPLACE FUNCTION ride_cancel(p_request_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
  v_me UUID := auth.uid();
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_me IS DISTINCT FROM r.passenger_id AND v_me IS DISTINCT FROM r.driver_id THEN
    RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501';
  END IF;
  IF r.status = 'cancelled' THEN RETURN r; END IF;  -- idempotente
  IF NOT ((r.status = 'open' AND v_me = r.passenger_id) OR r.status = 'accepted') THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  IF r.status = 'accepted' AND p_reason IS NULL THEN
    RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
  END IF;
  UPDATE ride_requests
  SET status = 'cancelled', finished_at = now(),
      cancel_reason = p_reason,
      cancelled_by = CASE WHEN v_me = r.passenger_id THEN 'passenger' ELSE 'driver' END
  WHERE id = p_request_id RETURNING * INTO r;
  -- Ofertas pendientes de otros conductores: ya no aplican.
  UPDATE ride_offers SET status = 'rejected'
  WHERE request_id = p_request_id AND status = 'pending';
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- La vía vieja (sin motivo) ya no puede cancelar algo aceptado: así nadie
-- cancela a un conductor que viene en camino sin decir por qué.
CREATE OR REPLACE FUNCTION ride_transition(p_request_id UUID, p_to TEXT)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
  v_me UUID := auth.uid();
BEGIN
  IF p_to = 'cancelled' THEN
    RETURN ride_cancel(p_request_id, NULL);
  END IF;
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_me IS DISTINCT FROM r.passenger_id AND v_me IS DISTINCT FROM r.driver_id THEN
    RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501';
  END IF;
  IF NOT (
       (r.status = 'accepted'    AND p_to = 'in_progress' AND v_me = r.driver_id)
    OR (r.status = 'in_progress' AND p_to = 'completed'   AND v_me = r.driver_id)
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = p_to,
      finished_at = CASE WHEN p_to = 'completed' THEN now() END
  WHERE id = p_request_id RETURNING * INTO r;
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 3. Cancelar el viaje completo ───────────────────────────────────────────
DROP FUNCTION IF EXISTS cancel_trip(UUID);
CREATE OR REPLACE FUNCTION cancel_trip(p_trip_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
  v_req UUID;
BEGIN
  PERFORM 1 FROM chained_trips
  WHERE id = p_trip_id AND passenger_id = auth.uid() AND status IN ('planned', 'in_progress')
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;

  -- Con un conductor ya en camino hace falta el motivo.
  IF p_reason IS NULL AND EXISTS (
    SELECT 1 FROM ride_requests r JOIN trip_legs l ON l.id = r.trip_leg_id
    WHERE l.trip_id = p_trip_id AND r.status = 'accepted'
  ) THEN
    RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
  END IF;

  -- Las solicitudes abiertas o aceptadas de sus tramos se cancelan también.
  FOR v_req IN
    SELECT r.id FROM ride_requests r JOIN trip_legs l ON l.id = r.trip_leg_id
    WHERE l.trip_id = p_trip_id AND r.status IN ('open', 'accepted')
  LOOP
    PERFORM ride_cancel(v_req, p_reason);
  END LOOP;

  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE id = p_trip_id;
  UPDATE trip_legs SET status = 'cancelled', ended_at = now()
  WHERE trip_id = p_trip_id AND status IN ('planned', 'awaiting_dispatch');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY['ride_cancel(uuid,text)', 'cancel_trip(uuid,text)',
                           'ride_transition(uuid,text)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

-- ── 4. Lugares guardados: máximo 10 con nombre ──────────────────────────────
-- (favorite_places es de 009; en la base de pruebas de CI sin 009 se salta.)
CREATE OR REPLACE FUNCTION favorite_places_guard()
RETURNS TRIGGER AS $$
BEGIN
  NEW.name := btrim(NEW.name);
  IF char_length(NEW.name) NOT BETWEEN 1 AND 40 THEN
    RAISE EXCEPTION 'bad_name' USING ERRCODE = '22023';
  END IF;
  IF NEW.type = 'custom' AND (TG_OP = 'INSERT' OR OLD.type IS DISTINCT FROM 'custom') THEN
    -- Bloquea las filas de la persona para que dos inserciones a la vez no
    -- pasen las dos del límite.
    PERFORM 1 FROM favorite_places WHERE user_id = NEW.user_id FOR UPDATE;
    IF (SELECT count(*) FROM favorite_places
        WHERE user_id = NEW.user_id AND type = 'custom') >= 10 THEN
      RAISE EXCEPTION 'saved_places_limit' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DO $$
BEGIN
  IF to_regclass('public.favorite_places') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS favorite_places_guard ON favorite_places;
    CREATE TRIGGER favorite_places_guard
      BEFORE INSERT OR UPDATE ON favorite_places
      FOR EACH ROW EXECUTE FUNCTION favorite_places_guard();
  END IF;
END $$;

-- ── 5. Solo efectivo ───────────────────────────────────────────────────────
-- Pagos con saldo (wallet, qr) solo con Wompi encendido: sin recargas reales
-- el saldo no es dinero.
CREATE OR REPLACE FUNCTION leg_payments_cash_only()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.method IN ('wallet', 'qr') AND NOT flag_on('wompi_enabled') THEN
    RAISE EXCEPTION 'wallet_disabled' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS leg_payments_cash_only ON leg_payments;
CREATE TRIGGER leg_payments_cash_only
  BEFORE INSERT ON leg_payments
  FOR EACH ROW EXECUTE FUNCTION leg_payments_cash_only();

-- La misma regla en la transferencia (antes de mirar el saldo), para que el
-- error sea "pagos con saldo apagados" y no "saldo insuficiente".
CREATE OR REPLACE FUNCTION _wallet_transfer(
  p_from_user UUID, p_to_user UUID, p_amount INTEGER, p_desc TEXT, p_meta JSONB)
RETURNS VOID AS $$
DECLARE
  w_from wallets;
  w_to   wallets;
BEGIN
  -- Solo efectivo (025): sin Wompi el saldo no es dinero real.
  IF NOT flag_on('wompi_enabled') THEN
    RAISE EXCEPTION 'wallet_disabled' USING ERRCODE = '55000';
  END IF;
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

-- La recarga simulada ya no existe: solo Wompi (wallet_topup_*) suma saldo.
CREATE OR REPLACE FUNCTION wallet_recharge_simulated(p_amount INTEGER, p_idempotency_key UUID)
RETURNS TABLE (new_balance INTEGER, transaction_id UUID) AS $$
BEGIN
  RAISE EXCEPTION 'simulated_disabled' USING ERRCODE = '55000';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Sin bono de bienvenida de prueba: las billeteras nuevas empiezan en $0.
ALTER TABLE wallets ALTER COLUMN balance SET DEFAULT 0;
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wallets (user_id, card_number, balance)
  VALUES (NEW.id, generate_gosmart_card_number(), 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 6. Tiempo real ─────────────────────────────────────────────────────────
DO $$
DECLARE t TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RETURN;  -- Postgres sin Supabase (pruebas de CI)
  END IF;
  FOREACH t IN ARRAY ARRAY['ride_requests', 'ride_offers'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- ── 7. Cancelaciones para el panel admin ────────────────────────────────────
-- Cuántas, por motivo y por quién (sin datos personales).
CREATE OR REPLACE FUNCTION admin_cancellations(p_days INTEGER DEFAULT 7)
RETURNS TABLE (reason TEXT, cancelled_by TEXT, total BIGINT) AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
    SELECT coalesce(r.cancel_reason, 'sin_motivo'), coalesce(r.cancelled_by, 'passenger'), count(*)
    FROM ride_requests r
    WHERE r.status = 'cancelled'
      AND r.finished_at > now() - make_interval(days => greatest(1, least(p_days, 90)))
    GROUP BY 1, 2
    ORDER BY 3 DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION admin_cancellations(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_cancellations(INTEGER) TO authenticated;

NOTIFY pgrst, 'reload schema';
