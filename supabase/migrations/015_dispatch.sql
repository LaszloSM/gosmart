-- 015_dispatch.sql
-- Fase 6 · Despacho estilo InDrive, colectivos con cupos y viaje encadenado.
--
--   app_flags            interruptores (dispatch_enabled) para apagar el despacho en el piloto
--   driver_locations     última posición del conductor disponible
--   ride_requests        el pasajero pide mototaxi/taxi con una tarifa sugerida
--   ride_offers          contraofertas de conductores
--   colectivo_departures salidas publicadas por conductores de colectivo
--   seat_reservations    cupos reservados
--   trips / trip_legs    viaje encadenado con máquina de estados
--
-- D7: aceptar una solicitud y reservar un cupo son RPCs con bloqueo de fila.
-- Gana uno solo; el otro recibe 'already_taken' / 'no_seats'.
-- Sin PostGIS: distancias con gs_km() (haversine). Seguro de re-ejecutar.

-- ── Interruptores ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_flags (
  key        TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE app_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_flags_public ON app_flags;
CREATE POLICY app_flags_public ON app_flags FOR SELECT USING (true);
DROP POLICY IF EXISTS app_flags_admin ON app_flags;
CREATE POLICY app_flags_admin ON app_flags FOR ALL USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON app_flags TO anon, authenticated;
GRANT INSERT, UPDATE ON app_flags TO authenticated;
INSERT INTO app_flags (key, enabled) VALUES ('dispatch_enabled', true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION flag_on(p_key TEXT) RETURNS BOOLEAN AS $$
  SELECT coalesce((SELECT enabled FROM app_flags WHERE key = p_key), false)
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Distancia en km (haversine). IMMUTABLE para usarla en filtros.
CREATE OR REPLACE FUNCTION gs_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
                                 lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
  SELECT 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

-- Conductor aprobado y disponible del servicio dado (o cualquiera si NULL).
CREATE OR REPLACE FUNCTION is_active_driver(p_service TEXT DEFAULT NULL)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM drivers
                 WHERE user_id = auth.uid() AND status = 'approved' AND available
                   AND (p_service IS NULL OR service = p_service))
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Posición del conductor ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id  UUID PRIMARY KEY REFERENCES drivers(user_id) ON DELETE CASCADE,
  lat        DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng        DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -180 AND 180),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_locations_own ON driver_locations;
CREATE POLICY driver_locations_own ON driver_locations
  FOR SELECT USING (driver_id = auth.uid());
REVOKE ALL ON driver_locations FROM anon;
GRANT SELECT ON driver_locations TO authenticated;

CREATE OR REPLACE FUNCTION driver_ping(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
RETURNS VOID AS $$
BEGIN
  IF NOT is_active_driver() THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO driver_locations (driver_id, lat, lng, updated_at)
  VALUES (auth.uid(), p_lat, p_lng, now())
  ON CONFLICT (driver_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Solicitudes y contraofertas ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ride_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service          TEXT NOT NULL CHECK (service IN ('mototaxi', 'taxi')),
  origin_lat       DOUBLE PRECISION NOT NULL,
  origin_lng       DOUBLE PRECISION NOT NULL,
  origin_label     TEXT CHECK (char_length(origin_label) <= 120),
  dest_lat         DOUBLE PRECISION NOT NULL,
  dest_lng         DOUBLE PRECISION NOT NULL,
  dest_label       TEXT CHECK (char_length(dest_label) <= 120),
  offered_fare     INTEGER NOT NULL CHECK (offered_fare BETWEEN 1000 AND 500000),
  status           TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'accepted', 'in_progress', 'completed', 'cancelled', 'expired')),
  driver_id        UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  agreed_fare      INTEGER,
  trip_leg_id      UUID,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL DEFAULT now() + interval '3 minutes',
  accepted_at      TIMESTAMPTZ,
  finished_at      TIMESTAMPTZ,
  UNIQUE (passenger_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS ride_requests_open_idx ON ride_requests(service, status, expires_at);

CREATE TABLE IF NOT EXISTS ride_offers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id  UUID NOT NULL REFERENCES ride_requests(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  fare        INTEGER NOT NULL CHECK (fare BETWEEN 1000 AND 500000),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (request_id, driver_id)
);

ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ride_requests_parties ON ride_requests;
CREATE POLICY ride_requests_parties ON ride_requests
  FOR SELECT USING (passenger_id = auth.uid() OR driver_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS ride_offers_parties ON ride_offers;
CREATE POLICY ride_offers_parties ON ride_offers
  FOR SELECT USING (driver_id = auth.uid() OR is_admin() OR EXISTS (
    SELECT 1 FROM ride_requests r WHERE r.id = request_id AND r.passenger_id = auth.uid()));
REVOKE ALL ON ride_requests, ride_offers FROM anon;
REVOKE INSERT, UPDATE, DELETE ON ride_requests, ride_offers FROM authenticated;
GRANT SELECT ON ride_requests, ride_offers TO authenticated;

CREATE OR REPLACE FUNCTION request_ride(
  p_service TEXT,
  p_origin_lat DOUBLE PRECISION, p_origin_lng DOUBLE PRECISION, p_origin_label TEXT,
  p_dest_lat DOUBLE PRECISION, p_dest_lng DOUBLE PRECISION, p_dest_label TEXT,
  p_offered_fare INTEGER,
  p_idempotency_key UUID,
  p_trip_leg_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user UUID := auth.uid();
  v_id   UUID;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  IF NOT flag_on('dispatch_enabled') THEN
    RAISE EXCEPTION 'dispatch_disabled' USING ERRCODE = '55000';
  END IF;
  SELECT id INTO v_id FROM ride_requests WHERE passenger_id = v_user AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  -- Una solicitud abierta a la vez; las vencidas no cuentan.
  UPDATE ride_requests SET status = 'expired'
  WHERE passenger_id = v_user AND status = 'open' AND expires_at <= now();
  IF EXISTS (SELECT 1 FROM ride_requests WHERE passenger_id = v_user AND status = 'open') THEN
    RAISE EXCEPTION 'request_already_open' USING ERRCODE = '55000';
  END IF;
  IF gs_km(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng) > 60 THEN
    RAISE EXCEPTION 'too_far' USING ERRCODE = '22023';
  END IF;
  INSERT INTO ride_requests (passenger_id, service, origin_lat, origin_lng, origin_label,
                             dest_lat, dest_lng, dest_label, offered_fare, idempotency_key, trip_leg_id)
  VALUES (v_user, p_service, p_origin_lat, p_origin_lng, left(p_origin_label, 120),
          p_dest_lat, p_dest_lng, left(p_dest_label, 120), p_offered_fare, p_idempotency_key, p_trip_leg_id)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Solicitudes abiertas cerca, para un conductor disponible del mismo servicio.
-- Solo lo necesario para decidir: nunca el teléfono ni el nombre completo.
CREATE OR REPLACE FUNCTION nearby_requests(
  p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION, p_radius_km DOUBLE PRECISION DEFAULT 3)
RETURNS TABLE (id UUID, origin_label TEXT, dest_label TEXT, pickup_km NUMERIC,
               trip_km NUMERIC, offered_fare INTEGER, expires_at TIMESTAMPTZ, my_offer INTEGER) AS $$
  SELECT r.id, r.origin_label, r.dest_label,
         round(gs_km(p_lat, p_lng, r.origin_lat, r.origin_lng)::numeric, 1),
         round(gs_km(r.origin_lat, r.origin_lng, r.dest_lat, r.dest_lng)::numeric, 1),
         r.offered_fare, r.expires_at,
         (SELECT o.fare FROM ride_offers o WHERE o.request_id = r.id AND o.driver_id = auth.uid())
  FROM ride_requests r
  JOIN drivers d ON d.user_id = auth.uid()
  WHERE is_active_driver()
    AND r.status = 'open' AND r.expires_at > now()
    AND r.service = d.service
    AND r.passenger_id <> auth.uid()
    AND gs_km(p_lat, p_lng, r.origin_lat, r.origin_lng) <= least(greatest(p_radius_km, 0.5), 10)
  ORDER BY 4, r.created_at
  LIMIT 20
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- D7: el primero que bloquea la fila gana.
CREATE OR REPLACE FUNCTION accept_ride(p_request_id UUID)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT is_active_driver(r.service) THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  IF r.passenger_id = auth.uid() THEN RAISE EXCEPTION 'own_request' USING ERRCODE = '42501'; END IF;
  IF r.status <> 'open' OR r.expires_at <= now() THEN
    RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000';
  END IF;
  -- Un conductor, un viaje a la vez.
  IF EXISTS (SELECT 1 FROM ride_requests WHERE driver_id = auth.uid()
             AND status IN ('accepted', 'in_progress')) THEN
    RAISE EXCEPTION 'driver_busy' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = 'accepted', driver_id = auth.uid(), agreed_fare = offered_fare, accepted_at = now()
  WHERE id = p_request_id RETURNING * INTO r;
  UPDATE ride_offers SET status = 'rejected' WHERE request_id = p_request_id AND status = 'pending';
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION counter_offer(p_request_id UUID, p_fare INTEGER)
RETURNS UUID AS $$
DECLARE
  r ride_requests;
  v_id UUID;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id;
  IF r.id IS NULL OR r.status <> 'open' OR r.expires_at <= now() THEN
    RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000';
  END IF;
  IF NOT is_active_driver(r.service) THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO ride_offers (request_id, driver_id, fare)
  VALUES (p_request_id, auth.uid(), p_fare)
  ON CONFLICT (request_id, driver_id) DO UPDATE SET fare = EXCLUDED.fare, created_at = now(), status = 'pending'
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- El pasajero elige una contraoferta. Mismo bloqueo que accept_ride.
CREATE OR REPLACE FUNCTION accept_offer(p_offer_id UUID)
RETURNS ride_requests AS $$
DECLARE
  o ride_offers;
  r ride_requests;
BEGIN
  SELECT * INTO o FROM ride_offers WHERE id = p_offer_id;
  IF o.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO r FROM ride_requests WHERE id = o.request_id FOR UPDATE;
  IF r.passenger_id <> auth.uid() THEN RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501'; END IF;
  IF r.status <> 'open' THEN RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000'; END IF;
  IF o.status <> 'pending' THEN RAISE EXCEPTION 'offer_gone' USING ERRCODE = '55000'; END IF;
  IF EXISTS (SELECT 1 FROM ride_requests WHERE driver_id = o.driver_id
             AND status IN ('accepted', 'in_progress')) THEN
    RAISE EXCEPTION 'driver_busy' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = 'accepted', driver_id = o.driver_id, agreed_fare = o.fare, accepted_at = now()
  WHERE id = r.id RETURNING * INTO r;
  UPDATE ride_offers SET status = CASE WHEN id = p_offer_id THEN 'accepted' ELSE 'rejected' END
  WHERE request_id = r.id AND status = 'pending';
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Avance del viaje: el conductor recoge y termina; cualquiera de los dos cancela.
CREATE OR REPLACE FUNCTION ride_transition(p_request_id UUID, p_to TEXT)
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
  IF NOT (
       (r.status = 'open'        AND p_to = 'cancelled'   AND v_me = r.passenger_id)
    OR (r.status = 'accepted'    AND p_to = 'in_progress' AND v_me = r.driver_id)
    OR (r.status = 'accepted'    AND p_to = 'cancelled')
    OR (r.status = 'in_progress' AND p_to = 'completed'   AND v_me = r.driver_id)
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = p_to,
      finished_at = CASE WHEN p_to IN ('completed', 'cancelled') THEN now() END
  WHERE id = p_request_id RETURNING * INTO r;
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Dónde viene mi conductor: solo para el pasajero de ese viaje aceptado.
CREATE OR REPLACE FUNCTION ride_driver_view(p_request_id UUID)
RETURNS TABLE (first_name TEXT, service TEXT, plate TEXT, vehicle TEXT,
               lat DOUBLE PRECISION, lng DOUBLE PRECISION, seen_at TIMESTAMPTZ) AS $$
  SELECT split_part(d.full_name, ' ', 1), d.service, v.plate,
         trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')),
         l.lat, l.lng, l.updated_at
  FROM ride_requests r
  JOIN drivers d ON d.user_id = r.driver_id
  LEFT JOIN vehicles v ON v.driver_id = d.user_id
  LEFT JOIN driver_locations l ON l.driver_id = d.user_id
  WHERE r.id = p_request_id AND r.passenger_id = auth.uid()
    AND r.status IN ('accepted', 'in_progress')
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Colectivos: salidas y cupos ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colectivo_departures (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id    UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  from_node    TEXT NOT NULL REFERENCES graph_nodes(id),
  to_node      TEXT NOT NULL REFERENCES graph_nodes(id),
  -- Hora estimada: el colectivo sale cuando se llena; esto es una referencia.
  depart_at    TIMESTAMPTZ NOT NULL,
  seats_total  SMALLINT NOT NULL CHECK (seats_total BETWEEN 1 AND 30),
  seats_taken  SMALLINT NOT NULL DEFAULT 0,
  fare         INTEGER NOT NULL CHECK (fare BETWEEN 1000 AND 200000),
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'full', 'departed', 'cancelled')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (seats_taken BETWEEN 0 AND seats_total),
  CHECK (from_node <> to_node)
);
CREATE INDEX IF NOT EXISTS colectivo_departures_route_idx
  ON colectivo_departures(from_node, to_node, status, depart_at);

CREATE TABLE IF NOT EXISTS seat_reservations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  departure_id     UUID NOT NULL REFERENCES colectivo_departures(id) ON DELETE CASCADE,
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seats            SMALLINT NOT NULL CHECK (seats BETWEEN 1 AND 4),
  status           TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'cancelled', 'boarded')),
  trip_leg_id      UUID,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (passenger_id, idempotency_key)
);

ALTER TABLE colectivo_departures ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_reservations ENABLE ROW LEVEL SECURITY;
-- Las salidas abiertas las ve cualquiera (también invitados, para planear).
DROP POLICY IF EXISTS departures_public ON colectivo_departures;
CREATE POLICY departures_public ON colectivo_departures FOR SELECT USING (true);
DROP POLICY IF EXISTS reservations_parties ON seat_reservations;
CREATE POLICY reservations_parties ON seat_reservations
  FOR SELECT USING (passenger_id = auth.uid() OR is_admin() OR EXISTS (
    SELECT 1 FROM colectivo_departures d WHERE d.id = departure_id AND d.driver_id = auth.uid()));
GRANT SELECT ON colectivo_departures TO anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON colectivo_departures, seat_reservations FROM authenticated;
REVOKE ALL ON seat_reservations FROM anon;
GRANT SELECT ON seat_reservations TO authenticated;

CREATE OR REPLACE FUNCTION publish_departure(
  p_from TEXT, p_to TEXT, p_depart_at TIMESTAMPTZ, p_seats SMALLINT, p_fare INTEGER)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT is_active_driver('colectivo') AND NOT is_active_driver('intermunicipal') THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  IF p_depart_at < now() - interval '10 minutes' OR p_depart_at > now() + interval '24 hours' THEN
    RAISE EXCEPTION 'invalid_time' USING ERRCODE = '22023';
  END IF;
  INSERT INTO colectivo_departures (driver_id, from_node, to_node, depart_at, seats_total, fare)
  VALUES (auth.uid(), p_from, p_to, p_depart_at, p_seats, p_fare)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- D7: bloquear la salida, revisar cupos y reservar en una sola transacción.
CREATE OR REPLACE FUNCTION reserve_seat(
  p_departure_id UUID, p_seats SMALLINT, p_idempotency_key UUID, p_trip_leg_id UUID DEFAULT NULL)
RETURNS UUID AS $$
DECLARE
  d colectivo_departures;
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT id INTO v_id FROM seat_reservations
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  SELECT * INTO d FROM colectivo_departures WHERE id = p_departure_id FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF d.driver_id = auth.uid() THEN RAISE EXCEPTION 'own_departure' USING ERRCODE = '42501'; END IF;
  IF d.status <> 'open' OR d.seats_taken + p_seats > d.seats_total THEN
    RAISE EXCEPTION 'no_seats' USING ERRCODE = '55000';
  END IF;
  INSERT INTO seat_reservations (departure_id, passenger_id, seats, idempotency_key, trip_leg_id)
  VALUES (p_departure_id, auth.uid(), p_seats, p_idempotency_key, p_trip_leg_id)
  RETURNING id INTO v_id;
  UPDATE colectivo_departures
  SET seats_taken = seats_taken + p_seats,
      status = CASE WHEN seats_taken + p_seats >= seats_total THEN 'full' ELSE status END
  WHERE id = p_departure_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cancel_reservation(p_reservation_id UUID)
RETURNS VOID AS $$
DECLARE
  s seat_reservations;
BEGIN
  SELECT * INTO s FROM seat_reservations WHERE id = p_reservation_id AND passenger_id = auth.uid();
  IF s.id IS NULL OR s.status <> 'reserved' THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  PERFORM 1 FROM colectivo_departures WHERE id = s.departure_id FOR UPDATE;
  UPDATE seat_reservations SET status = 'cancelled' WHERE id = s.id;
  UPDATE colectivo_departures
  SET seats_taken = seats_taken - s.seats,
      status = CASE WHEN status = 'full' THEN 'open' ELSE status END
  WHERE id = s.departure_id AND status IN ('open', 'full');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Viaje encadenado ─────────────────────────────────────────────────────────
-- Nota: 001 creó una tabla `trips` vieja (sin uso); por eso estas se llaman
-- chained_trips / trip_legs.
CREATE TABLE IF NOT EXISTS chained_trips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  origin_label  TEXT CHECK (char_length(origin_label) <= 120),
  dest_label    TEXT CHECK (char_length(dest_label) <= 120),
  status        TEXT NOT NULL DEFAULT 'planned'
                CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
  idempotency_key UUID NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (passenger_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS trip_legs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id      UUID NOT NULL REFERENCES chained_trips(id) ON DELETE CASCADE,
  seq          SMALLINT NOT NULL CHECK (seq >= 0),
  mode         TEXT NOT NULL CHECK (mode IN
                 ('walk', 'mototaxi', 'taxi', 'colectivo', 'transpadilla', 'intermunicipal')),
  from_label   TEXT, to_label TEXT,
  -- Puntos del grafo (014) cuando el tramo sale de un paradero/terminal.
  from_node    TEXT REFERENCES graph_nodes(id) ON DELETE SET NULL,
  to_node      TEXT REFERENCES graph_nodes(id) ON DELETE SET NULL,
  from_lat DOUBLE PRECISION, from_lng DOUBLE PRECISION,
  to_lat   DOUBLE PRECISION, to_lng   DOUBLE PRECISION,
  minutes      INTEGER,
  fare_min     INTEGER NOT NULL DEFAULT 0,
  fare_max     INTEGER NOT NULL DEFAULT 0,
  agreed_fare  INTEGER,
  status       TEXT NOT NULL DEFAULT 'planned'
               CHECK (status IN ('planned', 'awaiting_dispatch', 'in_progress', 'completed', 'failed', 'cancelled')),
  driver_id    UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  started_at   TIMESTAMPTZ,
  ended_at     TIMESTAMPTZ,
  UNIQUE (trip_id, seq)
);

ALTER TABLE chained_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_legs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chained_trips_own ON chained_trips;
CREATE POLICY chained_trips_own ON chained_trips
  FOR SELECT USING (passenger_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS trip_legs_own ON trip_legs;
CREATE POLICY trip_legs_own ON trip_legs
  FOR SELECT USING (is_admin() OR driver_id = auth.uid() OR EXISTS (
    SELECT 1 FROM chained_trips t WHERE t.id = trip_id AND t.passenger_id = auth.uid()));
REVOKE ALL ON chained_trips, trip_legs FROM anon;
REVOKE INSERT, UPDATE, DELETE ON chained_trips, trip_legs FROM authenticated;
GRANT SELECT ON chained_trips, trip_legs TO authenticated;

-- Crea el viaje con sus tramos (del planificador del celular).
-- p_legs: [{mode, from_label, to_label, from_node?, to_node?, from_lat, from_lng, to_lat, to_lng,
--           minutes, fare_min, fare_max}]
CREATE OR REPLACE FUNCTION create_trip(
  p_origin TEXT, p_dest TEXT, p_legs JSONB, p_idempotency_key UUID)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  l JSONB;
  i INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT id INTO v_id FROM chained_trips
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  IF jsonb_typeof(p_legs) <> 'array' OR jsonb_array_length(p_legs) NOT BETWEEN 1 AND 8 THEN
    RAISE EXCEPTION 'invalid_legs' USING ERRCODE = '22023';
  END IF;
  -- Un viaje en curso a la vez: los planeados anteriores se cancelan.
  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE passenger_id = auth.uid() AND status = 'planned';
  IF EXISTS (SELECT 1 FROM chained_trips WHERE passenger_id = auth.uid() AND status = 'in_progress') THEN
    RAISE EXCEPTION 'trip_in_progress' USING ERRCODE = '55000';
  END IF;

  INSERT INTO chained_trips (passenger_id, origin_label, dest_label, idempotency_key)
  VALUES (auth.uid(), left(p_origin, 120), left(p_dest, 120), p_idempotency_key)
  RETURNING id INTO v_id;
  FOR l IN SELECT * FROM jsonb_array_elements(p_legs) LOOP
    INSERT INTO trip_legs (trip_id, seq, mode, from_label, to_label, from_node, to_node,
                           from_lat, from_lng, to_lat, to_lng, minutes, fare_min, fare_max)
    VALUES (v_id, i, l->>'mode', left(l->>'from_label', 120), left(l->>'to_label', 120),
            (SELECT id FROM graph_nodes WHERE id = l->>'from_node'),
            (SELECT id FROM graph_nodes WHERE id = l->>'to_node'),
            (l->>'from_lat')::float8, (l->>'from_lng')::float8,
            (l->>'to_lat')::float8, (l->>'to_lng')::float8,
            (l->>'minutes')::int, coalesce((l->>'fare_min')::int, 0), coalesce((l->>'fare_max')::int, 0));
    i := i + 1;
  END LOOP;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Máquina de estados de un tramo. El estado del viaje se deriva:
--   algún tramo en curso o esperando → in_progress; todos terminados → completed.
--   Un tramo 'failed' deja el viaje en curso: la app replanea desde ahí.
CREATE OR REPLACE FUNCTION trip_leg_transition(p_leg_id UUID, p_to TEXT, p_agreed_fare INTEGER DEFAULT NULL)
RETURNS trip_legs AS $$
DECLARE
  l trip_legs;
  t chained_trips;
  v_trip_status TEXT;
BEGIN
  SELECT * INTO l FROM trip_legs WHERE id = p_leg_id FOR UPDATE;
  IF l.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO t FROM chained_trips WHERE id = l.trip_id FOR UPDATE;
  IF t.passenger_id <> auth.uid() THEN RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501'; END IF;
  IF t.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'trip_closed' USING ERRCODE = '55000';
  END IF;
  IF NOT (
       (l.status = 'planned'           AND p_to IN ('awaiting_dispatch', 'in_progress', 'cancelled'))
    OR (l.status = 'awaiting_dispatch' AND p_to IN ('in_progress', 'failed', 'cancelled'))
    OR (l.status = 'in_progress'       AND p_to IN ('completed', 'failed'))
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  -- Los tramos van en orden: no se empieza uno con anteriores sin cerrar.
  IF p_to IN ('awaiting_dispatch', 'in_progress') AND EXISTS (
       SELECT 1 FROM trip_legs WHERE trip_id = l.trip_id AND seq < l.seq
         AND status IN ('planned', 'awaiting_dispatch', 'in_progress')) THEN
    RAISE EXCEPTION 'previous_leg_open' USING ERRCODE = '55000';
  END IF;

  UPDATE trip_legs
  SET status = p_to,
      agreed_fare = coalesce(p_agreed_fare, agreed_fare),
      started_at = CASE WHEN p_to = 'in_progress' THEN now() ELSE started_at END,
      ended_at = CASE WHEN p_to IN ('completed', 'failed', 'cancelled') THEN now() ELSE ended_at END
  WHERE id = p_leg_id RETURNING * INTO l;

  SELECT CASE
    WHEN bool_and(status IN ('completed', 'cancelled')) AND bool_or(status = 'completed') THEN 'completed'
    WHEN bool_and(status = 'cancelled') THEN 'cancelled'
    WHEN bool_or(status IN ('awaiting_dispatch', 'in_progress', 'completed', 'failed')) THEN 'in_progress'
    ELSE 'planned' END
  INTO v_trip_status FROM trip_legs WHERE trip_id = l.trip_id;
  UPDATE chained_trips SET status = v_trip_status, updated_at = now() WHERE id = l.trip_id;
  RETURN l;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cancel_trip(p_trip_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE id = p_trip_id AND passenger_id = auth.uid() AND status IN ('planned', 'in_progress');
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  UPDATE trip_legs SET status = 'cancelled', ended_at = now()
  WHERE trip_id = p_trip_id AND status IN ('planned', 'awaiting_dispatch');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Permisos de las RPCs ─────────────────────────────────────────────────────
DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'driver_ping(double precision,double precision)',
    'request_ride(text,double precision,double precision,text,double precision,double precision,text,integer,uuid,uuid)',
    'nearby_requests(double precision,double precision,double precision)',
    'accept_ride(uuid)', 'counter_offer(uuid,integer)', 'accept_offer(uuid)',
    'ride_transition(uuid,text)', 'ride_driver_view(uuid)',
    'publish_departure(text,text,timestamp with time zone,smallint,integer)',
    'reserve_seat(uuid,smallint,uuid,uuid)', 'cancel_reservation(uuid)',
    'create_trip(text,text,jsonb,uuid)', 'trip_leg_transition(uuid,text,integer)',
    'cancel_trip(uuid)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
