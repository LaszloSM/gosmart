-- 024_mvp_real.sql
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

NOTIFY pgrst, 'reload schema';
