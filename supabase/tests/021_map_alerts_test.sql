-- supabase/tests/021_map_alerts_test.sql
-- Alertas del mapa (Waze): reportes en la ciudad sin tramo, tipos nuevos y
-- la consulta pública map_alerts(). Requiere: stub, fixture, 011, 013, 018 y 021.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000021a1', 'ana21@test.co'),
  ('00000000-0000-0000-0000-0000000021b2', 'beto21@test.co')
ON CONFLICT DO NOTHING;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000021a1', false);
CREATE TEMP TABLE IF NOT EXISTS t21 (id UUID);
GRANT ALL ON t21 TO PUBLIC;
DO $$
DECLARE v UUID;
BEGIN
  -- 1. Hueco en una calle de Riohacha: sin tramo, con punto.
  v := report_road(NULL, 'hueco', '21000000-0000-0000-0000-000000000001', 11.5380, -72.9130);
  INSERT INTO t21 VALUES (v);
  -- 2. Tipos nuevos
  PERFORM report_road(NULL, 'trancon', '21000000-0000-0000-0000-000000000002', 11.5440, -72.9070);
  PERFORM report_road('troncal-20-30', 'obra', '21000000-0000-0000-0000-000000000003');
  -- 3. Sin tramo y sin punto: no
  BEGIN
    PERFORM report_road(NULL, 'hueco', gen_random_uuid());
    RAISE EXCEPTION '3: aceptó un reporte sin lugar';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  -- 4. Fuera de La Guajira: no
  BEGIN
    PERFORM report_road(NULL, 'hueco', gen_random_uuid(), 4.6, -74.08);
    RAISE EXCEPTION '4: aceptó un reporte en Bogotá';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  -- 5. El mismo tipo a 50 m en menos de 30 min: duplicado
  BEGIN
    PERFORM report_road(NULL, 'hueco', gen_random_uuid(), 11.5383, -72.9131);
    RAISE EXCEPTION '5: aceptó un duplicado a 50 m';
  EXCEPTION WHEN program_limit_exceeded THEN NULL;
  END;
  -- 6. Tipo inválido
  BEGIN
    PERFORM report_road(NULL, 'ovni', gen_random_uuid(), 11.53, -72.91);
    RAISE EXCEPTION '6: aceptó un tipo inválido';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;
RESET ROLE;

-- 7. Un invitado ve las alertas con su punto, sin saber quién reportó.
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
DECLARE n INT; r RECORD;
BEGIN
  SELECT count(*) INTO n FROM map_alerts(11.4, -73.0, 11.7, -72.8)
  WHERE kind IN ('hueco', 'trancon');
  IF n < 2 THEN RAISE EXCEPTION '7: se esperaban 2 alertas de ciudad, hubo %', n; END IF;
  SELECT * INTO r FROM map_alerts() WHERE kind = 'obra' LIMIT 1;
  IF r.lat IS NULL OR r.segment_name IS NULL THEN
    RAISE EXCEPTION '7: la alerta de tramo no tomó el punto medio del tramo';
  END IF;
  IF EXISTS (SELECT 1 FROM map_alerts() WHERE mine) THEN
    RAISE EXCEPTION '7: un invitado ve "mine"';
  END IF;
  -- Fuera del rectángulo no sale.
  SELECT count(*) INTO n FROM map_alerts(11.0, -72.5, 11.2, -72.3);
  IF n <> 0 THEN RAISE EXCEPTION '7: salieron % alertas fuera del rectángulo', n; END IF;
END $$;
RESET ROLE;

-- 8. Beto vota "ya no está" y lo ve en my_vote; Ana ve "mine".
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000021b2', false);
SELECT vote_road_report((SELECT id FROM t21), false);
DO $$
DECLARE r RECORD;
BEGIN
  SELECT * INTO r FROM map_alerts() WHERE id = (SELECT id FROM t21);
  IF r.my_vote IS DISTINCT FROM false OR r.denials <> 1 THEN
    RAISE EXCEPTION '8: el voto no se refleja (% %)', r.my_vote, r.denials;
  END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000021a1', false);
DO $$
BEGIN
  IF NOT (SELECT mine FROM map_alerts() WHERE id = (SELECT id FROM t21)) THEN
    RAISE EXCEPTION '8: Ana no ve su reporte como suyo';
  END IF;
END $$;
RESET ROLE;

-- 9. El estado de la Troncal no cambia por reportes de ciudad; la obra del
-- tramo sí lo pone en precaución.
DO $$
BEGIN
  IF (SELECT state FROM road_status() WHERE segment_id = 'troncal-20-30') <> 'caution' THEN
    RAISE EXCEPTION '9: la obra no puso precaución';
  END IF;
  IF (SELECT count(*) FROM road_status()) <> 8 THEN
    RAISE EXCEPTION '9: cambió el número de tramos';
  END IF;
  IF EXISTS (SELECT 1 FROM push_targets_for_report((SELECT id FROM t21))) THEN
    RAISE EXCEPTION '9: un reporte de ciudad tendría push';
  END IF;
END $$;

\echo '021 map alerts: OK'
