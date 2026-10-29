-- supabase/migrations/023_driver_earnings.sql
-- Ganancias del conductor (como el resumen de InDrive): hoy y últimos 7 días,
-- cuánto entró por la app (saldo o QR) y cuánto en efectivo confirmado, cuántos
-- viajes terminó y su calificación. Solo lo propio (auth.uid()).
-- Seguro de re-ejecutar.

DROP FUNCTION IF EXISTS driver_earnings();
CREATE FUNCTION driver_earnings()
RETURNS TABLE (today_total INTEGER, today_trips INTEGER, today_cash INTEGER,
               week_total INTEGER, week_trips INTEGER, week_cash INTEGER,
               rating NUMERIC, ratings INTEGER) AS $$
  WITH b AS (
    SELECT date_trunc('day', now() AT TIME ZONE 'America/Bogota') AT TIME ZONE 'America/Bogota' AS day0,
           now() - interval '7 days' AS week0
  ), p AS (
    SELECT lp.amount, lp.method, lp.created_at
    FROM leg_payments lp
    WHERE lp.driver_id = auth.uid() AND lp.status IN ('paid', 'cash_confirmed')
      AND lp.created_at >= (SELECT week0 FROM b)
  ), t AS (
    SELECT r.finished_at FROM ride_requests r
    WHERE r.driver_id = auth.uid() AND r.status = 'completed'
      AND r.finished_at >= (SELECT week0 FROM b)
  )
  SELECT
    coalesce((SELECT sum(amount) FROM p WHERE created_at >= (SELECT day0 FROM b)), 0)::INTEGER,
    (SELECT count(*) FROM t WHERE finished_at >= (SELECT day0 FROM b))::INTEGER,
    coalesce((SELECT sum(amount) FROM p WHERE method = 'cash' AND created_at >= (SELECT day0 FROM b)), 0)::INTEGER,
    coalesce((SELECT sum(amount) FROM p), 0)::INTEGER,
    (SELECT count(*) FROM t)::INTEGER,
    coalesce((SELECT sum(amount) FROM p WHERE method = 'cash'), 0)::INTEGER,
    ur.avg_stars, coalesce(ur.total, 0)::INTEGER
  FROM user_rating(auth.uid()) ur
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION driver_earnings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION driver_earnings() TO authenticated;

NOTIFY pgrst, 'reload schema';
