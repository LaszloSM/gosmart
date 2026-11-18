-- 027_own_alert_vote.sql
-- Votar la alerta propia (como Waze). Antes vote_road_report rechazaba al
-- autor ('cannot_vote_own') y la app decía "revisa tu conexión".
--   · "Sigue ahí" del autor: la alerta dura más (no cuenta como confirmación:
--     nadie sube su propia reputación).
--   · "Ya no está" del autor: se quita al instante (él la puso, él sabe).
-- Los demás votan igual que antes. Seguro de re-ejecutar.

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
    IF p_still_there THEN
      UPDATE road_reports
      SET expires_at = greatest(expires_at, now() + road_report_ttl(kind))
      WHERE id = p_report_id;
    ELSE
      UPDATE road_reports SET expires_at = now() WHERE id = p_report_id;
    END IF;
    RETURN;
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

REVOKE EXECUTE ON FUNCTION vote_road_report(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION vote_road_report(UUID, BOOLEAN) TO authenticated;

NOTIFY pgrst, 'reload schema';
