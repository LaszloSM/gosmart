-- supabase/migrations/021_map_alerts.sql
-- Alertas en el mapa como Waze: cualquiera reporta donde está, en la Troncal o
-- en las calles de Riohacha y Maicao, y todos las ven como pines en el mapa.
--   * road_reports.segment_id pasa a ser opcional: sin tramo, el reporte vale
--     por su punto (lat/lng) y no cambia el estado de la Troncal.
--   * Tipos nuevos: trancón, peligro en la vía (objeto, animal) y obra.
--   * map_alerts(): pública, devuelve las alertas vigentes dentro de un
--     rectángulo con su punto, su edad y sus votos. Nunca devuelve quién reportó.
-- Re-ejecutable.

ALTER TABLE road_reports ALTER COLUMN segment_id DROP NOT NULL;

ALTER TABLE road_reports DROP CONSTRAINT IF EXISTS road_reports_kind_check;
ALTER TABLE road_reports ADD CONSTRAINT road_reports_kind_check CHECK (kind IN
  ('bloqueo', 'reten', 'inundacion', 'hueco', 'accidente', 'despejado',
   'trancon', 'peligro', 'obra'));

-- Sin tramo hace falta el punto: un reporte tiene que estar en algún lado.
ALTER TABLE road_reports DROP CONSTRAINT IF EXISTS road_reports_where_check;
ALTER TABLE road_reports ADD CONSTRAINT road_reports_where_check
  CHECK (segment_id IS NOT NULL OR (lat IS NOT NULL AND lng IS NOT NULL));

CREATE INDEX IF NOT EXISTS road_reports_active_point_idx
  ON road_reports(expires_at) WHERE removed_at IS NULL;

CREATE OR REPLACE FUNCTION road_report_ttl(p_kind TEXT)
RETURNS INTERVAL AS $$
  SELECT CASE p_kind
    WHEN 'bloqueo'    THEN interval '4 hours'
    WHEN 'reten'      THEN interval '2 hours'
    WHEN 'accidente'  THEN interval '3 hours'
    WHEN 'inundacion' THEN interval '12 hours'
    WHEN 'hueco'      THEN interval '30 days'
    WHEN 'despejado'  THEN interval '2 hours'
    WHEN 'trancon'    THEN interval '1 hour'
    WHEN 'peligro'    THEN interval '6 hours'
    WHEN 'obra'       THEN interval '7 days'
  END
$$ LANGUAGE sql IMMUTABLE;

-- Distancia aproximada en metros (equirectangular): sobra para 150 m.
CREATE OR REPLACE FUNCTION gs_meters(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
                                     lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
  SELECT 6371000 * sqrt(power(radians(lat2 - lat1), 2)
         + power(radians(lng2 - lng1) * cos(radians((lat1 + lat2) / 2)), 2))
$$ LANGUAGE sql IMMUTABLE;

-- ── Crear un reporte (misma firma que 013; el tramo ahora es opcional) ───────
-- Límites: 6 por hora; uno por tramo y tipo cada 30 min; sin tramo, uno por
-- tipo a menos de 150 m cada 30 min.
CREATE OR REPLACE FUNCTION report_road(
  p_segment_id      TEXT,
  p_kind            TEXT,
  p_idempotency_key UUID,
  p_lat             DOUBLE PRECISION DEFAULT NULL,
  p_lng             DOUBLE PRECISION DEFAULT NULL,
  p_happened_at     TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user UUID := auth.uid();
  v_id   UUID;
  v_at   TIMESTAMPTZ;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_id FROM road_reports
  WHERE user_id = v_user AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  IF p_segment_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM road_segments WHERE id = p_segment_id) THEN
    RAISE EXCEPTION 'unknown_segment' USING ERRCODE = '22023';
  END IF;
  IF p_segment_id IS NULL AND (p_lat IS NULL OR p_lng IS NULL) THEN
    RAISE EXCEPTION 'location_required' USING ERRCODE = '22023';
  END IF;
  -- Solo La Guajira y alrededores.
  IF p_lat IS NOT NULL AND (p_lat NOT BETWEEN 10.3 AND 12.6 OR p_lng NOT BETWEEN -73.7 AND -71.0) THEN
    RAISE EXCEPTION 'out_of_region' USING ERRCODE = '22023';
  END IF;
  IF road_report_ttl(p_kind) IS NULL THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22023';
  END IF;

  v_at := least(now(), greatest(coalesce(p_happened_at, now()), now() - interval '2 hours'));

  IF (SELECT count(*) FROM road_reports
      WHERE user_id = v_user AND created_at > now() - interval '1 hour') >= 6 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '54000';
  END IF;
  IF p_segment_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM road_reports
       WHERE user_id = v_user AND segment_id = p_segment_id AND kind = p_kind
         AND created_at > now() - interval '30 minutes') THEN
    RAISE EXCEPTION 'duplicate_report' USING ERRCODE = '54000';
  END IF;
  IF p_segment_id IS NULL AND EXISTS (
       SELECT 1 FROM road_reports
       WHERE user_id = v_user AND kind = p_kind AND lat IS NOT NULL
         AND created_at > now() - interval '30 minutes'
         AND gs_meters(lat, lng, p_lat, p_lng) < 150) THEN
    RAISE EXCEPTION 'duplicate_report' USING ERRCODE = '54000';
  END IF;

  INSERT INTO road_reports (user_id, segment_id, kind, lat, lng, happened_at,
                            expires_at, idempotency_key)
  VALUES (v_user, p_segment_id, p_kind, p_lat, p_lng, v_at,
          v_at + road_report_ttl(p_kind), p_idempotency_key)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Estado de la Troncal: los tipos nuevos cuentan como precaución ──────────
-- (los reportes sin tramo no entran: el JOIN es por tramo).
CREATE OR REPLACE FUNCTION road_status()
RETURNS TABLE (
  segment_id TEXT, name TEXT, is_branch BOOLEAN, km_from NUMERIC, km_to NUMERIC,
  state TEXT, reason TEXT, reports INTEGER, report_id UUID, updated_at TIMESTAMPTZ
) AS $$
  WITH a AS (SELECT * FROM road_active_reports() WHERE segment_id IS NOT NULL),
  problem AS (
    SELECT DISTINCT ON (a.segment_id) a.*,
      CASE WHEN a.kind IN ('bloqueo', 'accidente') AND a.confidence >= 0.9 THEN 3
           ELSE 2 END AS severity
    FROM a WHERE a.kind <> 'despejado'
    ORDER BY a.segment_id,
      CASE WHEN a.kind IN ('bloqueo', 'accidente') AND a.confidence >= 0.9 THEN 3 ELSE 2 END DESC,
      a.confidence DESC, a.happened_at DESC
  ),
  clear AS (
    SELECT segment_id, max(happened_at) AS at FROM a
    WHERE kind = 'despejado' GROUP BY segment_id
  )
  SELECT s.id, s.name, s.is_branch, s.km_from, s.km_to,
    CASE
      WHEN p.id IS NOT NULL AND (c.at IS NULL OR p.happened_at >= c.at)
        THEN CASE p.severity WHEN 3 THEN 'closed' ELSE 'caution' END
      WHEN c.at IS NOT NULL THEN 'open'
      ELSE 'unknown'
    END,
    CASE WHEN p.id IS NOT NULL AND (c.at IS NULL OR p.happened_at >= c.at)
      THEN CASE p.kind
        WHEN 'bloqueo' THEN 'Bloqueo' WHEN 'reten' THEN 'Retén'
        WHEN 'inundacion' THEN 'Inundación' WHEN 'hueco' THEN 'Huecos'
        WHEN 'accidente' THEN 'Accidente' WHEN 'trancon' THEN 'Trancón'
        WHEN 'peligro' THEN 'Peligro en la vía' WHEN 'obra' THEN 'Obra' END
    END,
    (SELECT count(*)::int FROM a WHERE a.segment_id = s.id),
    CASE WHEN p.id IS NOT NULL AND (c.at IS NULL OR p.happened_at >= c.at) THEN p.id END,
    greatest(p.happened_at, c.at)
  FROM road_segments s
  LEFT JOIN problem p ON p.segment_id = s.id
  LEFT JOIN clear c ON c.segment_id = s.id
  ORDER BY s.is_branch, s.km_from
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION road_status() TO anon, authenticated;

-- ── Alertas del mapa (públicas) ──────────────────────────────────────────────
-- Las vigentes dentro del rectángulo, menos "despejado" (no es una alerta) y
-- las que la gente ya desmintió más de lo que confirmó. El punto es el del
-- reporte o, si no tiene, la mitad de su tramo. mine / my_vote solo dicen
-- algo a quien pregunta con su sesión.
CREATE OR REPLACE FUNCTION map_alerts(
  p_min_lat DOUBLE PRECISION DEFAULT 10.3,
  p_min_lng DOUBLE PRECISION DEFAULT -73.7,
  p_max_lat DOUBLE PRECISION DEFAULT 12.6,
  p_max_lng DOUBLE PRECISION DEFAULT -71.0
)
RETURNS TABLE (
  id UUID, kind TEXT, lat DOUBLE PRECISION, lng DOUBLE PRECISION,
  segment_id TEXT, segment_name TEXT, happened_at TIMESTAMPTZ, expires_at TIMESTAMPTZ,
  confirmations INTEGER, denials INTEGER, mine BOOLEAN, my_vote BOOLEAN
) AS $$
  SELECT * FROM (
    SELECT r.id, r.kind,
      coalesce(r.lat, (s.lat_from + s.lat_to) / 2) AS lat,
      coalesce(r.lng, (s.lng_from + s.lng_to) / 2) AS lng,
      r.segment_id, s.name AS segment_name, r.happened_at, r.expires_at,
      (SELECT count(*)::int FROM road_report_votes v
       WHERE v.report_id = r.id AND v.still_there) AS confirmations,
      (SELECT count(*)::int FROM road_report_votes v
       WHERE v.report_id = r.id AND NOT v.still_there) AS denials,
      coalesce(r.user_id = auth.uid(), false) AS mine,
      (SELECT v.still_there FROM road_report_votes v
       WHERE v.report_id = r.id AND v.user_id = auth.uid()) AS my_vote
    FROM road_reports r
    LEFT JOIN road_segments s ON s.id = r.segment_id
    WHERE r.removed_at IS NULL AND r.expires_at > now() AND r.kind <> 'despejado'
  ) x
  WHERE x.lat BETWEEN p_min_lat AND p_max_lat
    AND x.lng BETWEEN p_min_lng AND p_max_lng
    AND x.denials <= x.confirmations + 1
  ORDER BY x.happened_at DESC
  LIMIT 300
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION map_alerts(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  TO anon, authenticated;

-- Los avisos push de la vía son para quien va por la Troncal: un reporte en
-- una calle de la ciudad (sin tramo) no despierta a nadie.
CREATE OR REPLACE FUNCTION push_targets_for_report(p_report_id UUID)
RETURNS TABLE (token TEXT) AS $$
  SELECT DISTINCT t.token
  FROM road_reports rep
  JOIN chained_trips ct ON ct.status = 'in_progress'
  JOIN trip_legs l ON l.trip_id = ct.id AND l.mode IN ('colectivo', 'intermunicipal')
                  AND l.status IN ('planned', 'awaiting_dispatch', 'in_progress')
  JOIN push_tokens t ON t.user_id = ct.passenger_id
  WHERE rep.id = p_report_id
    AND rep.segment_id IS NOT NULL
    AND rep.kind IN ('bloqueo', 'accidente', 'inundacion', 'reten')
    AND ct.passenger_id <> rep.user_id
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION push_targets_for_report(UUID) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION push_targets_for_report(UUID) TO service_role;

NOTIFY pgrst, 'reload schema';
