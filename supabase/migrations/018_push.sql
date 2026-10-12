-- 018_push.sql
-- Push con FCM (Fase 3/4/6): tokens por dispositivo y a quién avisar.
-- El envío lo hace la Edge Function `push`, disparada por Database Webhooks
-- (INSERT en ride_requests y road_reports). Seguro de re-ejecutar.

CREATE TABLE IF NOT EXISTS push_tokens (
  token       TEXT PRIMARY KEY CHECK (char_length(token) BETWEEN 20 AND 4096),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform    TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS push_tokens_user_idx ON push_tokens(user_id);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_tokens_own ON push_tokens;
CREATE POLICY push_tokens_own ON push_tokens FOR SELECT USING (user_id = auth.uid());
REVOKE ALL ON push_tokens FROM anon;
REVOKE INSERT, UPDATE, DELETE ON push_tokens FROM authenticated;
GRANT SELECT ON push_tokens TO authenticated;

-- Un token es de un solo usuario: si cambia de cuenta en el mismo teléfono, se reasigna.
CREATE OR REPLACE FUNCTION register_push_token(p_token TEXT, p_platform TEXT DEFAULT 'android')
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  INSERT INTO push_tokens (token, user_id, platform, updated_at)
  VALUES (p_token, auth.uid(), p_platform, now())
  ON CONFLICT (token) DO UPDATE SET user_id = auth.uid(), platform = EXCLUDED.platform, updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION unregister_push_token(p_token TEXT)
RETURNS VOID AS $$
  DELETE FROM push_tokens WHERE token = p_token AND user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- Conductores disponibles del servicio, vistos hace menos de 10 min a ≤ 3 km.
CREATE OR REPLACE FUNCTION push_targets_for_request(p_request_id UUID)
RETURNS TABLE (token TEXT) AS $$
  SELECT t.token
  FROM ride_requests r
  JOIN drivers d ON d.service = r.service AND d.status = 'approved' AND d.available
  JOIN driver_locations l ON l.driver_id = d.user_id AND l.updated_at > now() - interval '10 minutes'
  JOIN push_tokens t ON t.user_id = d.user_id
  WHERE r.id = p_request_id AND r.status = 'open'
    AND d.user_id <> r.passenger_id
    AND gs_km(l.lat, l.lng, r.origin_lat, r.origin_lng) <= 3
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Viajeros con un viaje en curso por la Troncal (colectivo o intermunicipal)
-- cuando entra un reporte que cierra o complica la vía.
CREATE OR REPLACE FUNCTION push_targets_for_report(p_report_id UUID)
RETURNS TABLE (token TEXT) AS $$
  SELECT DISTINCT t.token
  FROM road_reports rep
  JOIN chained_trips ct ON ct.status = 'in_progress'
  JOIN trip_legs l ON l.trip_id = ct.id AND l.mode IN ('colectivo', 'intermunicipal')
                  AND l.status IN ('planned', 'awaiting_dispatch', 'in_progress')
  JOIN push_tokens t ON t.user_id = ct.passenger_id
  WHERE rep.id = p_report_id
    AND rep.kind IN ('bloqueo', 'accidente', 'inundacion', 'reten')
    AND ct.passenger_id <> rep.user_id
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION unregister_push_token(TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) TO authenticated;
GRANT  EXECUTE ON FUNCTION unregister_push_token(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION push_targets_for_request(UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION push_targets_for_report(UUID) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION push_targets_for_request(UUID) TO service_role;
GRANT  EXECUTE ON FUNCTION push_targets_for_report(UUID) TO service_role;

NOTIFY pgrst, 'reload schema';
