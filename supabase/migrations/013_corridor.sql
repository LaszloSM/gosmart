-- 013_corridor.sql
-- Fase 4 · M1 Estado del corredor.
--
--   road_segments       la Troncal por tramos de km (y el desvío Albania–Cuestecitas)
--   road_reports        reportes con tipo cerrado; SIN campo de texto libre
--                       (regla ética: no se nombran personas ni comunidades)
--   road_report_votes   confirmación cruzada: "sigue ahí" / "ya no está"
--   road_status()       estado público por tramo (también para invitados)
--   road_patterns()     patrón histórico: cuántos bloqueos y a qué hora
--
-- Los reportes se crean y votan solo por RPC, con límite por usuario.
-- La confianza de un reporte = reputación del autor + confirmaciones − desmentidas.
-- Seguro de re-ejecutar.

-- ── Tramos ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS road_segments (
  id         TEXT PRIMARY KEY,                      -- 'troncal-00-10'
  name       TEXT NOT NULL,
  is_branch  BOOLEAN NOT NULL DEFAULT false,        -- desvío Albania–Cuestecitas
  km_from    NUMERIC(6,1) NOT NULL CHECK (km_from >= 0),
  km_to      NUMERIC(6,1) NOT NULL,
  -- Extremos aproximados para asignar un reporte por GPS al tramo más cercano.
  lat_from   DOUBLE PRECISION NOT NULL,
  lng_from   DOUBLE PRECISION NOT NULL,
  lat_to     DOUBLE PRECISION NOT NULL,
  lng_to     DOUBLE PRECISION NOT NULL,
  verified   BOOLEAN NOT NULL DEFAULT false,        -- false = trazado aproximado
  CHECK (km_to > km_from)
);

ALTER TABLE road_segments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS road_segments_public ON road_segments;
CREATE POLICY road_segments_public ON road_segments FOR SELECT USING (true);
DROP POLICY IF EXISTS road_segments_admin ON road_segments;
CREATE POLICY road_segments_admin ON road_segments
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON road_segments TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON road_segments TO authenticated;

-- Troncal Riohacha (km 0) → Maicao (~km 75) en tramos de ~10 km, y el desvío.
-- Coordenadas APROXIMADAS (verified=false) hasta el levantamiento de campo.
INSERT INTO road_segments (id, name, is_branch, km_from, km_to, lat_from, lng_from, lat_to, lng_to) VALUES
  ('troncal-00-10', 'Riohacha – salida a Maicao', false,  0, 10, 11.5440, -72.9070, 11.5050, -72.8250),
  ('troncal-10-20', 'Troncal km 10–20',            false, 10, 20, 11.5050, -72.8250, 11.4650, -72.7430),
  ('troncal-20-30', 'Troncal km 20–30',            false, 20, 30, 11.4650, -72.7430, 11.4250, -72.6600),
  ('troncal-30-40', 'Troncal km 30–40',            false, 30, 40, 11.4250, -72.6600, 11.3850, -72.5780),
  ('troncal-40-50', 'Cuatro Vías',                 false, 40, 50, 11.3850, -72.5780, 11.3450, -72.4950),
  ('troncal-50-60', 'Troncal km 50–60',            false, 50, 60, 11.3450, -72.4950, 11.3650, -72.4100),
  ('troncal-60-75', 'Llegada a Maicao',            false, 60, 75, 11.3650, -72.4100, 11.3780, -72.2400),
  ('desvio-albania-cuestecitas', 'Desvío Albania – Cuestecitas', true, 0, 25,
                                                                 11.1610, -72.5920, 11.2050, -72.6160)
ON CONFLICT (id) DO NOTHING;

-- ── Reportes ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS road_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  segment_id       TEXT NOT NULL REFERENCES road_segments(id),
  kind             TEXT NOT NULL CHECK (kind IN
                     ('bloqueo', 'reten', 'inundacion', 'hueco', 'accidente', 'despejado')),
  lat              DOUBLE PRECISION CHECK (lat BETWEEN -90 AND 90),
  lng              DOUBLE PRECISION CHECK (lng BETWEEN -180 AND 180),
  happened_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL,
  removed_at       TIMESTAMPTZ,                     -- moderación (admin)
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
  -- Sin columna de texto: no hay dónde nombrar a nadie.
);

CREATE INDEX IF NOT EXISTS road_reports_segment_idx
  ON road_reports(segment_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS road_reports_user_idx
  ON road_reports(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS road_report_votes (
  report_id   UUID NOT NULL REFERENCES road_reports(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  still_there BOOLEAN NOT NULL,                     -- true = confirma, false = ya no está
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (report_id, user_id)
);

ALTER TABLE road_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE road_report_votes ENABLE ROW LEVEL SECURITY;
-- El usuario ve sus propios reportes y votos; el público ve el agregado.
DROP POLICY IF EXISTS road_reports_own ON road_reports;
CREATE POLICY road_reports_own ON road_reports
  FOR SELECT USING (user_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS road_reports_admin ON road_reports;
CREATE POLICY road_reports_admin ON road_reports
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS road_votes_own ON road_report_votes;
CREATE POLICY road_votes_own ON road_report_votes
  FOR SELECT USING (user_id = auth.uid() OR is_admin());

REVOKE ALL ON road_reports, road_report_votes FROM anon;
REVOKE INSERT, DELETE ON road_reports FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON road_report_votes FROM authenticated;
GRANT SELECT, UPDATE ON road_reports TO authenticated;    -- UPDATE: la policy deja solo al admin
GRANT SELECT ON road_report_votes TO authenticated;

-- Cuánto vive un reporte sin confirmaciones.
CREATE OR REPLACE FUNCTION road_report_ttl(p_kind TEXT)
RETURNS INTERVAL AS $$
  SELECT CASE p_kind
    WHEN 'bloqueo'    THEN interval '4 hours'
    WHEN 'reten'      THEN interval '2 hours'
    WHEN 'accidente'  THEN interval '3 hours'
    WHEN 'inundacion' THEN interval '12 hours'
    WHEN 'hueco'      THEN interval '30 days'
    WHEN 'despejado'  THEN interval '2 hours'
  END
$$ LANGUAGE sql IMMUTABLE;

-- Reputación del reportante entre 0 y 1: de sus reportes votados, qué parte
-- confirmó la gente. Sin historial vale 0,5 (ni crédito ni castigo).
CREATE OR REPLACE FUNCTION road_reporter_reputation(p_user UUID)
RETURNS NUMERIC AS $$
  SELECT round((1 + count(*) FILTER (WHERE v.still_there))::numeric
               / (2 + count(v.*)), 3)
  FROM road_reports r
  LEFT JOIN road_report_votes v ON v.report_id = r.id
  WHERE r.user_id = p_user AND r.removed_at IS NULL
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Crear un reporte ─────────────────────────────────────────────────────────
-- Límites: 6 reportes por hora y uno por tramo y tipo cada 30 minutos.
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

  -- Reintento de la cola offline: devolver el mismo reporte.
  SELECT id INTO v_id FROM road_reports
  WHERE user_id = v_user AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM road_segments WHERE id = p_segment_id) THEN
    RAISE EXCEPTION 'unknown_segment' USING ERRCODE = '22023';
  END IF;
  IF road_report_ttl(p_kind) IS NULL THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22023';
  END IF;

  -- La hora del teléfono vale si llegó tarde por falta de señal, pero no
  -- más de 2 horas atrás ni en el futuro.
  v_at := least(now(), greatest(coalesce(p_happened_at, now()), now() - interval '2 hours'));

  IF (SELECT count(*) FROM road_reports
      WHERE user_id = v_user AND created_at > now() - interval '1 hour') >= 6 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '54000';
  END IF;
  IF EXISTS (SELECT 1 FROM road_reports
             WHERE user_id = v_user AND segment_id = p_segment_id AND kind = p_kind
               AND created_at > now() - interval '30 minutes') THEN
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

-- ── Votar: "sigue ahí" alarga la vida del reporte; "ya no está" la acorta ───
CREATE OR REPLACE FUNCTION vote_road_report(p_report_id UUID, p_still_there BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_user UUID := auth.uid();
  r      road_reports;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO r FROM road_reports WHERE id = p_report_id FOR UPDATE;
  IF r.id IS NULL OR r.removed_at IS NOT NULL OR r.expires_at <= now() THEN
    RAISE EXCEPTION 'report_not_active' USING ERRCODE = 'P0002';
  END IF;
  IF r.user_id = v_user THEN
    RAISE EXCEPTION 'cannot_vote_own' USING ERRCODE = '42501';
  END IF;

  INSERT INTO road_report_votes (report_id, user_id, still_there)
  VALUES (p_report_id, v_user, p_still_there)
  ON CONFLICT (report_id, user_id) DO UPDATE SET still_there = EXCLUDED.still_there,
                                                 created_at = now();

  IF p_still_there THEN
    UPDATE road_reports
    SET expires_at = greatest(expires_at, now() + road_report_ttl(kind))
    WHERE id = p_report_id;
  ELSIF (SELECT count(*) FILTER (WHERE NOT still_there)
         FROM road_report_votes WHERE report_id = p_report_id) >= 2 THEN
    -- Dos personas dicen que ya no está: se apaga.
    UPDATE road_reports SET expires_at = now() WHERE id = p_report_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION report_road(TEXT, TEXT, UUID, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION vote_road_report(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION report_road(TEXT, TEXT, UUID, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMPTZ) TO authenticated;
GRANT  EXECUTE ON FUNCTION vote_road_report(UUID, BOOLEAN) TO authenticated;
REVOKE EXECUTE ON FUNCTION road_reporter_reputation(UUID) FROM PUBLIC, anon;

-- ── Reportes activos con su confianza (base de road_status) ─────────────────
-- confianza = reputación del autor + 0,5 por confirmación − 0,5 por desmentida
CREATE OR REPLACE FUNCTION road_active_reports()
RETURNS TABLE (
  id UUID, segment_id TEXT, kind TEXT, happened_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ, confirmations INTEGER, denials INTEGER, confidence NUMERIC
) AS $$
  SELECT r.id, r.segment_id, r.kind, r.happened_at, r.expires_at,
         count(v.*) FILTER (WHERE v.still_there)::int,
         count(v.*) FILTER (WHERE NOT v.still_there)::int,
         road_reporter_reputation(r.user_id)
           + 0.5 * count(v.*) FILTER (WHERE v.still_there)
           - 0.5 * count(v.*) FILTER (WHERE NOT v.still_there)
  FROM road_reports r
  LEFT JOIN road_report_votes v ON v.report_id = r.id
  WHERE r.removed_at IS NULL AND r.expires_at > now()
  GROUP BY r.id
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Estado público por tramo ─────────────────────────────────────────────────
-- Cerrada: bloqueo o accidente con confianza ≥ 0,9 (un reportante nuevo necesita
-- que alguien más lo confirme; uno con buen historial, no).
-- Precaución: retén, inundación, hueco, o un cierre aún sin confianza.
-- Abierta: alguien reportó "despejado" después del último problema.
-- Sin datos: nadie ha reportado nada vigente. Nunca se inventa "abierta".
CREATE OR REPLACE FUNCTION road_status()
RETURNS TABLE (
  segment_id TEXT, name TEXT, is_branch BOOLEAN, km_from NUMERIC, km_to NUMERIC,
  state TEXT, reason TEXT, reports INTEGER, report_id UUID, updated_at TIMESTAMPTZ
) AS $$
  WITH a AS (SELECT * FROM road_active_reports()),
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
        WHEN 'accidente' THEN 'Accidente' END
    END,
    (SELECT count(*)::int FROM a WHERE a.segment_id = s.id),
    CASE WHEN p.id IS NOT NULL AND (c.at IS NULL OR p.happened_at >= c.at) THEN p.id END,
    greatest(p.happened_at, c.at)
  FROM road_segments s
  LEFT JOIN problem p ON p.segment_id = s.id
  LEFT JOIN clear c ON c.segment_id = s.id
  ORDER BY s.is_branch, s.km_from
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION road_active_reports() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION road_status() TO anon, authenticated;

-- ── Patrón histórico ("4 bloqueos en 3 meses, en la mañana") ────────────────
CREATE OR REPLACE FUNCTION road_patterns(p_days INTEGER DEFAULT 90)
RETURNS TABLE (segment_id TEXT, kind TEXT, total INTEGER, morning INTEGER,
               afternoon INTEGER, night INTEGER) AS $$
  SELECT r.segment_id, r.kind, count(*)::int,
    count(*) FILTER (WHERE extract(hour FROM r.happened_at AT TIME ZONE 'America/Bogota') BETWEEN 5 AND 11)::int,
    count(*) FILTER (WHERE extract(hour FROM r.happened_at AT TIME ZONE 'America/Bogota') BETWEEN 12 AND 18)::int,
    count(*) FILTER (WHERE extract(hour FROM r.happened_at AT TIME ZONE 'America/Bogota') NOT BETWEEN 5 AND 18)::int
  FROM road_reports r
  WHERE r.removed_at IS NULL
    AND r.kind IN ('bloqueo', 'inundacion', 'accidente')
    AND r.happened_at > now() - make_interval(days => least(greatest(p_days, 1), 365))
    -- Solo cuenta lo que alguien más confirmó: un reporte solitario no es patrón.
    AND EXISTS (SELECT 1 FROM road_report_votes v WHERE v.report_id = r.id AND v.still_there)
  GROUP BY r.segment_id, r.kind
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION road_patterns(INTEGER) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
