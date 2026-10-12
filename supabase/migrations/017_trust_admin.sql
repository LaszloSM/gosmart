-- 017_trust_admin.sql
-- Fase 8 · Confianza + panel admin.
--
--   ride_ratings        calificación en las dos direcciones (1–5 y etiquetas cerradas)
--   Impago: con 2 viajes confirmados sin pagar (el conductor marcó 'no_pago' y no
--   hay pago registrado), el pasajero no puede pedir más viajes.
--   Admin: quitar reportes, ver documentos, métricas para Instramd y la Alcaldía.
-- Seguro de re-ejecutar.

CREATE TABLE IF NOT EXISTS ride_ratings (
  request_id  UUID NOT NULL REFERENCES ride_requests(id) ON DELETE CASCADE,
  rater_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ratee_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars       SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
  -- Etiquetas cerradas: sin texto libre (nadie escribe insultos ni datos).
  tags        TEXT[] NOT NULL DEFAULT '{}' CHECK (tags <@ ARRAY[
                'puntual', 'amable', 'manejo_seguro', 'vehiculo_limpio',
                'no_llego', 'cobro_de_mas', 'manejo_peligroso', 'no_pago', 'grosero']::text[]),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (request_id, rater_id)
);
ALTER TABLE ride_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ride_ratings_own ON ride_ratings;
CREATE POLICY ride_ratings_own ON ride_ratings
  FOR SELECT USING (rater_id = auth.uid() OR is_admin());
REVOKE ALL ON ride_ratings FROM anon;
REVOKE INSERT, UPDATE, DELETE ON ride_ratings FROM authenticated;
GRANT SELECT ON ride_ratings TO authenticated;

CREATE OR REPLACE FUNCTION rate_ride(p_request_id UUID, p_stars SMALLINT, p_tags TEXT[] DEFAULT '{}')
RETURNS VOID AS $$
DECLARE
  r ride_requests;
  v_ratee UUID;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id;
  IF r.id IS NULL OR r.status <> 'completed' THEN
    RAISE EXCEPTION 'not_rateable' USING ERRCODE = '55000';
  END IF;
  IF auth.uid() = r.passenger_id THEN v_ratee := r.driver_id;
  ELSIF auth.uid() = r.driver_id THEN v_ratee := r.passenger_id;
  ELSE RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501';
  END IF;
  -- 'no_pago' solo lo marca el conductor; 'no_llego' solo el pasajero.
  IF auth.uid() = r.passenger_id AND 'no_pago' = ANY(p_tags) THEN
    RAISE EXCEPTION 'invalid_tag' USING ERRCODE = '22023';
  END IF;
  IF auth.uid() = r.driver_id AND 'no_llego' = ANY(p_tags) THEN
    RAISE EXCEPTION 'invalid_tag' USING ERRCODE = '22023';
  END IF;
  IF r.finished_at < now() - interval '7 days' THEN
    RAISE EXCEPTION 'too_late' USING ERRCODE = '55000';
  END IF;
  INSERT INTO ride_ratings (request_id, rater_id, ratee_id, stars, tags)
  VALUES (p_request_id, auth.uid(), v_ratee, p_stars, coalesce(p_tags, '{}'))
  ON CONFLICT (request_id, rater_id) DO UPDATE
    SET stars = EXCLUDED.stars, tags = EXCLUDED.tags, created_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Promedio y cantidad de calificaciones recibidas (solo con 3 o más se muestra).
CREATE OR REPLACE FUNCTION user_rating(p_user UUID)
RETURNS TABLE (avg_stars NUMERIC, total INTEGER) AS $$
  SELECT CASE WHEN count(*) >= 3 THEN round(avg(stars)::numeric, 1) END, count(*)::int
  FROM ride_ratings WHERE ratee_id = p_user
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Viajes que el conductor marcó 'no_pago' y de verdad no tienen pago.
CREATE OR REPLACE FUNCTION unpaid_rides(p_user UUID)
RETURNS INTEGER AS $$
  SELECT count(DISTINCT rr.id)::int
  FROM ride_ratings rt
  JOIN ride_requests rr ON rr.id = rt.request_id
  WHERE rr.passenger_id = p_user
    AND rt.rater_id = rr.driver_id
    AND 'no_pago' = ANY(rt.tags)
    AND NOT EXISTS (SELECT 1 FROM leg_payments p
                    WHERE p.ride_request_id = rr.id AND p.status IN ('paid', 'cash_confirmed'))
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION ride_requests_block_unpaid()
RETURNS TRIGGER AS $$
BEGIN
  IF unpaid_rides(NEW.passenger_id) >= 2 THEN
    RAISE EXCEPTION 'blocked_unpaid' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS ride_requests_block_unpaid ON ride_requests;
CREATE TRIGGER ride_requests_block_unpaid
  BEFORE INSERT ON ride_requests
  FOR EACH ROW EXECUTE FUNCTION ride_requests_block_unpaid();

-- La vista del conductor para el pasajero ahora trae su calificación.
DROP FUNCTION IF EXISTS ride_driver_view(UUID);
CREATE FUNCTION ride_driver_view(p_request_id UUID)
RETURNS TABLE (first_name TEXT, service TEXT, plate TEXT, vehicle TEXT,
               lat DOUBLE PRECISION, lng DOUBLE PRECISION, seen_at TIMESTAMPTZ,
               rating NUMERIC, ratings INTEGER) AS $$
  SELECT split_part(d.full_name, ' ', 1), d.service, v.plate,
         trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')),
         l.lat, l.lng, l.updated_at, ur.avg_stars, ur.total
  FROM ride_requests r
  JOIN drivers d ON d.user_id = r.driver_id
  LEFT JOIN vehicles v ON v.driver_id = d.user_id
  LEFT JOIN driver_locations l ON l.driver_id = d.user_id
  LEFT JOIN LATERAL user_rating(d.user_id) ur ON true
  WHERE r.id = p_request_id AND r.passenger_id = auth.uid()
    AND r.status IN ('accepted', 'in_progress')
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Admin ────────────────────────────────────────────────────────────────────
-- Conductores por revisar, con lo que hace falta para decidir.
CREATE OR REPLACE FUNCTION admin_driver_queue()
RETURNS TABLE (user_id UUID, full_name TEXT, cedula TEXT, phone TEXT, service TEXT,
               zone TEXT, status TEXT, plate TEXT, documents TEXT[], created_at TIMESTAMPTZ) AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT d.user_id, d.full_name, d.cedula, d.phone, d.service, d.zone, d.status,
         (SELECT v.plate FROM vehicles v WHERE v.driver_id = d.user_id LIMIT 1),
         coalesce((SELECT array_agg(dd.kind ORDER BY dd.kind) FROM driver_documents dd
                   WHERE dd.driver_id = d.user_id), '{}'),
         d.created_at
  FROM drivers d
  ORDER BY (d.status = 'pending') DESC, d.created_at;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Moderar: quitar un reporte vial (falso, o que señala a alguien).
CREATE OR REPLACE FUNCTION admin_remove_report(p_report_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  UPDATE road_reports SET removed_at = now() WHERE id = p_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_recent_reports(p_hours INTEGER DEFAULT 48)
RETURNS TABLE (id UUID, segment_id TEXT, kind TEXT, happened_at TIMESTAMPTZ,
               expires_at TIMESTAMPTZ, removed BOOLEAN, confirmations INTEGER, denials INTEGER) AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.segment_id, r.kind, r.happened_at, r.expires_at, r.removed_at IS NOT NULL,
         (SELECT count(*)::int FROM road_report_votes v WHERE v.report_id = r.id AND v.still_there),
         (SELECT count(*)::int FROM road_report_votes v WHERE v.report_id = r.id AND NOT v.still_there)
  FROM road_reports r
  WHERE r.created_at > now() - make_interval(hours => least(greatest(p_hours, 1), 720))
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Métricas del piloto (sin datos personales): para Instramd y la Alcaldía.
CREATE OR REPLACE FUNCTION admin_metrics(p_days INTEGER DEFAULT 7)
RETURNS JSONB AS $$
DECLARE
  v_since TIMESTAMPTZ := now() - make_interval(days => least(greatest(p_days, 1), 365));
  v JSONB;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  SELECT jsonb_build_object(
    'days', p_days,
    'reports', (SELECT count(*) FROM road_reports WHERE created_at > v_since),
    'reports_confirmed', (SELECT count(DISTINCT r.id) FROM road_reports r
                          JOIN road_report_votes v ON v.report_id = r.id AND v.still_there
                          WHERE r.created_at > v_since),
    'reports_removed', (SELECT count(*) FROM road_reports WHERE created_at > v_since AND removed_at IS NOT NULL),
    -- Minutos medianos entre el reporte y su primera confirmación.
    'minutes_to_confirm', (SELECT round(percentile_cont(0.5) WITHIN GROUP (
                              ORDER BY extract(epoch FROM fv.first_at - r.created_at) / 60)::numeric, 1)
                           FROM road_reports r
                           JOIN LATERAL (SELECT min(v.created_at) AS first_at FROM road_report_votes v
                                         WHERE v.report_id = r.id AND v.still_there) fv ON fv.first_at IS NOT NULL
                           WHERE r.created_at > v_since),
    'rides_requested', (SELECT count(*) FROM ride_requests WHERE created_at > v_since),
    'rides_accepted', (SELECT count(*) FROM ride_requests WHERE created_at > v_since AND accepted_at IS NOT NULL),
    'rides_completed', (SELECT count(*) FROM ride_requests WHERE created_at > v_since AND status = 'completed'),
    'median_seconds_to_accept', (SELECT round(percentile_cont(0.5) WITHIN GROUP (
                                   ORDER BY extract(epoch FROM accepted_at - created_at))::numeric)
                                 FROM ride_requests WHERE created_at > v_since AND accepted_at IS NOT NULL),
    'seats_reserved', (SELECT coalesce(sum(seats), 0) FROM seat_reservations
                       WHERE created_at > v_since AND status <> 'cancelled'),
    'payments_cop', (SELECT coalesce(sum(amount), 0) FROM leg_payments
                     WHERE created_at > v_since AND status IN ('paid', 'cash_confirmed')),
    'sos_events', (SELECT count(*) FROM sos_events WHERE created_at > v_since),
    'drivers_approved', (SELECT count(*) FROM drivers WHERE status = 'approved'),
    'drivers_pending', (SELECT count(*) FROM drivers WHERE status = 'pending'),
    'trips_completed', (SELECT count(*) FROM chained_trips WHERE created_at > v_since AND status = 'completed')
  ) INTO v;
  RETURN v;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'rate_ride(uuid,smallint,text[])', 'user_rating(uuid)', 'ride_driver_view(uuid)',
    'admin_driver_queue()', 'admin_remove_report(uuid)', 'admin_recent_reports(integer)',
    'admin_metrics(integer)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION unpaid_rides(UUID) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
