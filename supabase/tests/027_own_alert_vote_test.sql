-- supabase/tests/027_own_alert_vote_test.sql (después de 021_map_alerts_test.sql)
-- El autor puede decir "Sigue ahí" (dura más, sin contar como confirmación)
-- o "Ya no está" (se quita al instante).
\set ON_ERROR_STOP on
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000027a1', 'autora27@test.co')
ON CONFLICT DO NOTHING;
CREATE TEMP TABLE IF NOT EXISTS t27 (k TEXT PRIMARY KEY, id UUID);
GRANT ALL ON t27 TO PUBLIC;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000027a1', false);
DO $$
DECLARE before TIMESTAMPTZ; after TIMESTAMPTZ; v UUID;
BEGIN
  v := report_road(NULL, 'obra', gen_random_uuid(), 11.5300, -72.9200);
  INSERT INTO t27 VALUES ('obra', v);
  SELECT expires_at INTO before FROM road_reports WHERE id = v;
  PERFORM vote_road_report(v, true);
  SELECT expires_at INTO after FROM road_reports WHERE id = v;
  IF after < before THEN RAISE EXCEPTION '1: "sigue ahí" acortó la alerta'; END IF;
  IF EXISTS (SELECT 1 FROM road_report_votes WHERE report_id = v) THEN
    RAISE EXCEPTION '1: el voto propio contó como confirmación';
  END IF;
  PERFORM vote_road_report(v, false);
  IF (SELECT expires_at FROM road_reports WHERE id = v) > now() THEN
    RAISE EXCEPTION '2: "ya no está" del autor no la quitó';
  END IF;
  -- Ya no está activa: votar de nuevo dice por qué.
  BEGIN
    PERFORM vote_road_report(v, true);
    RAISE EXCEPTION '3: votó una alerta vencida';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
END $$;
RESET ROLE;
SELECT '027_own_alert_vote: OK';
