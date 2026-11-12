-- 026_quick_ride_history.sql
-- Pedir en un toque e historial completo (plan: docs/MVP_SALIDA.md).
--   1. quick_ride: crea el viaje de un tramo (mototaxi o taxi), lo pone a
--      esperar y publica la solicitud en UNA llamada atómica. Antes eran
--      tres pantallas y tres botones (Ver viaje → Iniciar viaje → Pedir).
--   2. ride_raise_fare: subir la tarifa mientras se busca (como InDrive), sin
--      cancelar ni volver a pedir. Reinicia los 3 minutos de búsqueda.
--   3. my_trip_history / my_trip_detail / my_ride_detail: TODOS los viajes,
--      también cancelados, sin aceptar y los hechos como conductor, con lo
--      que muestra el detalle (conductor, placa, tarifa, pago, motivo).
-- Seguro de re-ejecutar.

-- ── 1. Pedir en un toque ────────────────────────────────────────────────────
-- Viajes de un solo tramo (mototaxi o taxi) que quedaron "en curso" porque la
-- app se cerró: si la carrera terminó y se pagó, el tramo se cierra hecho; si
-- nadie la tomó (vencida o cancelada), el viaje se cancela. Así no bloquean
-- el siguiente pedido con 'trip_in_progress'.
CREATE OR REPLACE FUNCTION _settle_quick_trips(p_user UUID)
RETURNS VOID AS $$
DECLARE
  t RECORD;
  r ride_requests;
BEGIN
  FOR t IN
    SELECT c.id, l.id AS leg_id, l.status AS leg_status
    FROM chained_trips c JOIN trip_legs l ON l.trip_id = c.id
    WHERE c.passenger_id = p_user AND c.status = 'in_progress'
      AND l.mode IN ('mototaxi', 'taxi')
      AND (SELECT count(*) FROM trip_legs x WHERE x.trip_id = c.id) = 1
    FOR UPDATE OF c
  LOOP
    SELECT * INTO r FROM ride_requests
    WHERE trip_leg_id = t.leg_id ORDER BY created_at DESC LIMIT 1;
    IF r.id IS NOT NULL AND r.status = 'completed' AND EXISTS (
         SELECT 1 FROM leg_payments p WHERE p.ride_request_id = r.id
           AND p.status IN ('paid', 'cash_pending', 'cash_confirmed')) THEN
      UPDATE trip_legs SET status = 'completed', agreed_fare = coalesce(r.agreed_fare, agreed_fare),
             started_at = coalesce(started_at, r.accepted_at), ended_at = coalesce(r.finished_at, now())
      WHERE id = t.leg_id;
      UPDATE chained_trips SET status = 'completed', updated_at = now() WHERE id = t.id;
    ELSIF t.leg_status = 'awaiting_dispatch' AND (r.id IS NULL
          OR r.status IN ('cancelled', 'expired')
          OR (r.status = 'open' AND r.expires_at <= now())) THEN
      IF r.status = 'open' THEN
        UPDATE ride_requests SET status = 'expired' WHERE id = r.id;
      END IF;
      UPDATE trip_legs SET status = 'cancelled', ended_at = now() WHERE id = t.leg_id;
      UPDATE chained_trips SET status = 'cancelled', updated_at = now() WHERE id = t.id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _settle_quick_trips(UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION quick_ride(
  p_service TEXT,
  p_origin_lat DOUBLE PRECISION, p_origin_lng DOUBLE PRECISION, p_origin_label TEXT,
  p_dest_lat DOUBLE PRECISION, p_dest_lng DOUBLE PRECISION, p_dest_label TEXT,
  p_fare INTEGER,
  p_minutes INTEGER,
  p_idempotency_key UUID
)
RETURNS JSONB AS $$
DECLARE
  v_trip UUID;
  v_leg  trip_legs;
  v_req  UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  IF p_service NOT IN ('mototaxi', 'taxi') THEN
    RAISE EXCEPTION 'invalid_service' USING ERRCODE = '22023';
  END IF;
  -- Reintento con la misma llave: devuelve lo mismo (sin segundo viaje).
  SELECT r.id, l.trip_id INTO v_req, v_trip
  FROM ride_requests r JOIN trip_legs l ON l.id = r.trip_leg_id
  WHERE r.passenger_id = auth.uid() AND r.idempotency_key = p_idempotency_key;
  IF v_req IS NOT NULL THEN
    RETURN jsonb_build_object('trip_id', v_trip, 'request_id', v_req);
  END IF;

  PERFORM _settle_quick_trips(auth.uid());
  v_trip := create_trip(
    coalesce(p_origin_label, 'Punto de recogida'),
    coalesce(p_dest_label, 'Destino'),
    jsonb_build_array(jsonb_build_object(
      'mode', p_service,
      'from_label', p_origin_label, 'to_label', p_dest_label,
      'from_lat', p_origin_lat, 'from_lng', p_origin_lng,
      'to_lat', p_dest_lat, 'to_lng', p_dest_lng,
      'minutes', p_minutes, 'fare_min', p_fare, 'fare_max', p_fare)),
    p_idempotency_key);
  SELECT * INTO v_leg FROM trip_legs WHERE trip_id = v_trip ORDER BY seq LIMIT 1;
  IF v_leg.status = 'planned' THEN
    PERFORM trip_leg_transition(v_leg.id, 'awaiting_dispatch');
  END IF;
  v_req := request_ride(p_service, p_origin_lat, p_origin_lng, p_origin_label,
                        p_dest_lat, p_dest_lng, p_dest_label, p_fare,
                        p_idempotency_key, v_leg.id);
  RETURN jsonb_build_object('trip_id', v_trip, 'request_id', v_req);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2. Subir la tarifa mientras se busca ────────────────────────────────────
CREATE OR REPLACE FUNCTION ride_raise_fare(p_request_id UUID, p_fare INTEGER)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL OR r.passenger_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
  END IF;
  IF r.status <> 'open' THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  IF p_fare IS NULL OR p_fare <= r.offered_fare OR p_fare > 500000 THEN
    RAISE EXCEPTION 'invalid_fare' USING ERRCODE = '22023';
  END IF;
  UPDATE ride_requests
  SET offered_fare = p_fare,
      -- Vencida o no, otros 3 minutos con el precio nuevo.
      expires_at = now() + interval '3 minutes'
  WHERE id = p_request_id RETURNING * INTO r;
  -- Ofertas por debajo del precio nuevo ya no tienen sentido.
  UPDATE ride_offers SET status = 'rejected'
  WHERE request_id = p_request_id AND status = 'pending' AND fare < p_fare;
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 3. Historial ────────────────────────────────────────────────────────────
-- Nombre de pila de una persona (nunca el nombre completo ni el teléfono).
CREATE OR REPLACE FUNCTION _first_name(p_user UUID)
RETURNS TEXT AS $$
  SELECT nullif(split_part(coalesce(
    (SELECT d.full_name FROM drivers d WHERE d.user_id = p_user),
    (SELECT p.name FROM profiles p WHERE p.id = p_user)), ' ', 1), '')
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _first_name(UUID) FROM PUBLIC, anon, authenticated;

-- Una solicitud con lo que la persona puede ver de ella.
CREATE OR REPLACE FUNCTION _ride_card(r ride_requests, p_as_driver BOOLEAN)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'id', r.id,
    'service', r.service,
    'status', r.status,
    'offered_fare', r.offered_fare,
    'agreed_fare', r.agreed_fare,
    'created_at', r.created_at,
    'accepted_at', r.accepted_at,
    'finished_at', r.finished_at,
    'cancel_reason', r.cancel_reason,
    'cancelled_by', r.cancelled_by,
    'origin', r.origin_label,
    'destination', r.dest_label,
    'from', jsonb_build_object('lat', r.origin_lat, 'lng', r.origin_lng),
    'to', jsonb_build_object('lat', r.dest_lat, 'lng', r.dest_lng),
    -- La otra persona del viaje: nombre de pila y, del conductor, su vehículo.
    'other_name', CASE WHEN p_as_driver THEN _first_name(r.passenger_id)
                       WHEN r.driver_id IS NOT NULL THEN _first_name(r.driver_id) END,
    'plate', CASE WHEN NOT p_as_driver AND r.driver_id IS NOT NULL THEN
               (SELECT v.plate FROM vehicles v WHERE v.driver_id = r.driver_id
                ORDER BY v.created_at LIMIT 1) END,
    'vehicle', CASE WHEN NOT p_as_driver AND r.driver_id IS NOT NULL THEN
               (SELECT nullif(trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')), '')
                FROM vehicles v WHERE v.driver_id = r.driver_id ORDER BY v.created_at LIMIT 1) END,
    'paid', coalesce((SELECT sum(p.amount) FROM leg_payments p
                      WHERE p.ride_request_id = r.id
                        AND p.status IN ('paid', 'cash_pending', 'cash_confirmed')), 0),
    'pay_method', (SELECT p.method FROM leg_payments p
                   WHERE p.ride_request_id = r.id AND p.status <> 'refunded'
                   ORDER BY p.created_at DESC LIMIT 1),
    'my_stars', (SELECT rr.stars FROM ride_ratings rr
                 WHERE rr.request_id = r.id AND rr.rater_id = auth.uid())
  )
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _ride_card(ride_requests, BOOLEAN) FROM PUBLIC, anon, authenticated;

-- Todos los viajes de la persona, del más nuevo al más viejo:
--   kind 'trip' = viaje como pasajero (chained_trips, con todos sus estados)
--   kind 'ride' = viaje hecho como conductor (ride_requests que tomó)
CREATE OR REPLACE FUNCTION my_trip_history(p_offset INTEGER DEFAULT 0, p_limit INTEGER DEFAULT 20)
RETURNS JSONB AS $$
  WITH me AS (SELECT auth.uid() AS id),
  trips AS (
    SELECT t.created_at AS at, jsonb_build_object(
      'kind', 'trip',
      'id', t.id,
      'status', t.status,
      'created_at', t.created_at,
      'ended_at', CASE WHEN t.status IN ('completed', 'cancelled') THEN t.updated_at END,
      'origin', t.origin_label,
      'destination', t.dest_label,
      'modes', coalesce((SELECT jsonb_agg(l.mode ORDER BY l.seq) FROM trip_legs l
                         WHERE l.trip_id = t.id), '[]'),
      'from', (SELECT jsonb_build_object('lat', l.from_lat, 'lng', l.from_lng) FROM trip_legs l
               WHERE l.trip_id = t.id AND l.from_lat IS NOT NULL ORDER BY l.seq LIMIT 1),
      'to', (SELECT jsonb_build_object('lat', l.to_lat, 'lng', l.to_lng) FROM trip_legs l
             WHERE l.trip_id = t.id AND l.to_lat IS NOT NULL ORDER BY l.seq DESC LIMIT 1),
      'total_paid', coalesce((SELECT sum(p.amount) FROM leg_payments p
                              JOIN trip_legs l ON l.id = p.trip_leg_id
                              WHERE l.trip_id = t.id
                                AND p.status IN ('paid', 'cash_pending', 'cash_confirmed')), 0),
      'requests', (SELECT count(*) FROM ride_requests r JOIN trip_legs l ON l.id = r.trip_leg_id
                   WHERE l.trip_id = t.id),
      -- La solicitud más reciente: la que dice cómo terminó y con quién.
      'last_ride', (SELECT _ride_card(r, false) FROM ride_requests r
                    JOIN trip_legs l ON l.id = r.trip_leg_id
                    WHERE l.trip_id = t.id
                    ORDER BY (r.driver_id IS NOT NULL) DESC, r.created_at DESC LIMIT 1)
    ) AS item
    FROM chained_trips t, me WHERE t.passenger_id = me.id
  ),
  rides AS (
    SELECT r.created_at AS at,
           _ride_card(r, true) || jsonb_build_object('kind', 'ride') AS item
    FROM ride_requests r, me WHERE r.driver_id = me.id
  )
  SELECT coalesce(jsonb_agg(item ORDER BY at DESC), '[]')
  FROM (
    SELECT * FROM (SELECT * FROM trips UNION ALL SELECT * FROM rides) u
    ORDER BY at DESC
    OFFSET greatest(coalesce(p_offset, 0), 0)
    LIMIT least(greatest(coalesce(p_limit, 20), 1), 50)
  ) page
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Detalle de un viaje como pasajero: tramos y cada intento de pedirlo.
CREATE OR REPLACE FUNCTION my_trip_detail(p_trip_id UUID)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'kind', 'trip',
    'id', t.id,
    'status', t.status,
    'created_at', t.created_at,
    'ended_at', CASE WHEN t.status IN ('completed', 'cancelled') THEN t.updated_at END,
    'origin', t.origin_label,
    'destination', t.dest_label,
    'total_paid', coalesce((SELECT sum(p.amount) FROM leg_payments p
                            JOIN trip_legs l ON l.id = p.trip_leg_id
                            WHERE l.trip_id = t.id
                              AND p.status IN ('paid', 'cash_pending', 'cash_confirmed')), 0),
    'legs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', l.id, 'seq', l.seq, 'mode', l.mode, 'status', l.status,
        'from_label', l.from_label, 'to_label', l.to_label,
        'from', CASE WHEN l.from_lat IS NOT NULL THEN
                  jsonb_build_object('lat', l.from_lat, 'lng', l.from_lng) END,
        'to', CASE WHEN l.to_lat IS NOT NULL THEN
                jsonb_build_object('lat', l.to_lat, 'lng', l.to_lng) END,
        'minutes', l.minutes, 'fare_min', l.fare_min, 'fare_max', l.fare_max,
        'agreed_fare', l.agreed_fare, 'started_at', l.started_at, 'ended_at', l.ended_at,
        'rides', coalesce((SELECT jsonb_agg(_ride_card(r, false) ORDER BY r.created_at)
                           FROM ride_requests r WHERE r.trip_leg_id = l.id), '[]')
      ) ORDER BY l.seq) FROM trip_legs l WHERE l.trip_id = t.id), '[]')
  )
  FROM chained_trips t
  WHERE t.id = p_trip_id AND t.passenger_id = auth.uid()
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Detalle de un viaje hecho como conductor.
CREATE OR REPLACE FUNCTION my_ride_detail(p_request_id UUID)
RETURNS JSONB AS $$
  SELECT _ride_card(r, true) || jsonb_build_object('kind', 'ride')
  FROM ride_requests r
  WHERE r.id = p_request_id AND r.driver_id = auth.uid()
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'quick_ride(text,double precision,double precision,text,double precision,double precision,text,integer,integer,uuid)',
    'ride_raise_fare(uuid,integer)',
    'my_trip_history(integer,integer)',
    'my_trip_detail(uuid)',
    'my_ride_detail(uuid)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
