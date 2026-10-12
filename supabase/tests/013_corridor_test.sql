-- supabase/tests/013_corridor_test.sql
-- Requiere: stub, _profiles_fixture, 011 y 013.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000e1', 'eva@test.co'),
  ('00000000-0000-0000-0000-0000000000f2', 'fer@test.co'),
  ('00000000-0000-0000-0000-0000000000f3', 'gus@test.co')
ON CONFLICT DO NOTHING;

-- 1. Sin reportes, todo "Sin datos" (nunca se inventa "abierta"), visible para invitados
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM road_status() WHERE state <> 'unknown';
  IF n <> 0 THEN RAISE EXCEPTION '1: hay % tramos con estado sin reportes', n; END IF;
  SELECT count(*) INTO n FROM road_status();
  IF n <> 8 THEN RAISE EXCEPTION '1: se esperaban 8 tramos, hubo %', n; END IF;
  BEGIN
    PERFORM report_road('troncal-30-40', 'bloqueo', gen_random_uuid());
    RAISE EXCEPTION '1: un invitado reportó';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- 2. Eva reporta un bloqueo: sin confirmar queda en precaución, no cerrada
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
CREATE TEMP TABLE IF NOT EXISTS t_rep (id UUID);
GRANT ALL ON t_rep TO PUBLIC;
DO $$
DECLARE r RECORD; v_id UUID; v_again UUID;
BEGIN
  v_id := report_road('troncal-30-40', 'bloqueo', '33333333-3333-3333-3333-333333333333', 11.4, -72.6);
  INSERT INTO t_rep VALUES (v_id);
  -- 3. Reintento offline: mismo id, sin duplicar
  v_again := report_road('troncal-30-40', 'bloqueo', '33333333-3333-3333-3333-333333333333');
  IF v_again <> v_id THEN RAISE EXCEPTION '3: el reintento creó otro reporte'; END IF;
  SELECT * INTO r FROM road_status() WHERE segment_id = 'troncal-30-40';
  IF r.state <> 'caution' OR r.reason <> 'Bloqueo' THEN
    RAISE EXCEPTION '2: estado %, motivo %', r.state, r.reason;
  END IF;
  -- 4. No puede repetir el mismo tipo en el mismo tramo a los pocos minutos
  BEGIN
    PERFORM report_road('troncal-30-40', 'bloqueo', gen_random_uuid());
    RAISE EXCEPTION '4: aceptó un reporte duplicado';
  EXCEPTION WHEN program_limit_exceeded THEN NULL;
  END;
  -- 5. Ni votarse a sí misma
  BEGIN
    PERFORM vote_road_report(v_id, true);
    RAISE EXCEPTION '5: votó su propio reporte';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- 6. No puede escribir directo en la tabla
  BEGIN
    INSERT INTO road_reports (user_id, segment_id, kind, expires_at, idempotency_key)
    VALUES (auth.uid(), 'troncal-00-10', 'bloqueo', now() + interval '1 day', gen_random_uuid());
    RAISE EXCEPTION '6: insertó sin pasar por la RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 7. Límite: 6 reportes por hora
DO $$
DECLARE segs TEXT[] := ARRAY['troncal-00-10','troncal-10-20','troncal-20-30','troncal-40-50','troncal-50-60'];
BEGIN
  FOR i IN 1..5 LOOP
    PERFORM report_road(segs[i], 'hueco', gen_random_uuid());
  END LOOP;
  BEGIN
    PERFORM report_road('troncal-60-75', 'hueco', gen_random_uuid());
    RAISE EXCEPTION '7: aceptó un séptimo reporte en la hora';
  EXCEPTION WHEN program_limit_exceeded THEN NULL;
  END;
END $$;

-- 8. Fer confirma: ahora sí, cerrada
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f2', false);
DO $$
DECLARE r RECORD; v_id UUID;
BEGIN
  SELECT id INTO v_id FROM t_rep;
  PERFORM vote_road_report(v_id, true);
  SELECT * INTO r FROM road_status() WHERE segment_id = 'troncal-30-40';
  IF r.state <> 'closed' THEN RAISE EXCEPTION '8: con confirmación quedó %', r.state; END IF;
  -- Fer no ve el reporte crudo ni quién lo hizo
  IF EXISTS (SELECT 1 FROM road_reports) THEN RAISE EXCEPTION '8: ve reportes ajenos'; END IF;
END $$;

-- 9. Fer y Gus dicen "ya no está": el reporte se apaga
DO $$
DECLARE v_id UUID;
BEGIN
  SELECT id INTO v_id FROM t_rep;
  PERFORM vote_road_report(v_id, false);
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f3', false);
DO $$
DECLARE r RECORD; v_id UUID;
BEGIN
  SELECT id INTO v_id FROM t_rep;
  PERFORM vote_road_report(v_id, false);
  SELECT * INTO r FROM road_status() WHERE segment_id = 'troncal-30-40';
  IF r.state <> 'unknown' THEN RAISE EXCEPTION '9: tras dos desmentidas quedó %', r.state; END IF;
  -- 10. Gus reporta "despejado": el tramo pasa a abierta con evidencia
  PERFORM report_road('troncal-30-40', 'despejado', gen_random_uuid());
  SELECT * INTO r FROM road_status() WHERE segment_id = 'troncal-30-40';
  IF r.state <> 'open' THEN RAISE EXCEPTION '10: con despejado quedó %', r.state; END IF;
  -- 11. Un retén nuevo después del despejado vuelve a precaución
  PERFORM report_road('troncal-30-40', 'reten', gen_random_uuid());
  SELECT * INTO r FROM road_status() WHERE segment_id = 'troncal-30-40';
  IF r.state <> 'caution' OR r.reason <> 'Retén' THEN RAISE EXCEPTION '11: %', r.state; END IF;
END $$;

-- 12. La hora del teléfono no puede ser de hace días ni del futuro
DO $$
DECLARE at TIMESTAMPTZ; v UUID;
BEGIN
  v := report_road('troncal-00-10', 'inundacion', gen_random_uuid(), NULL, NULL, now() - interval '3 days');
END $$;
RESET ROLE;
DO $$
DECLARE at TIMESTAMPTZ;
BEGIN
  SELECT happened_at INTO at FROM road_reports WHERE kind = 'inundacion';
  IF at < now() - interval '2 hours 1 minute' THEN RAISE EXCEPTION '12: aceptó hora vieja %', at; END IF;
END $$;

-- 13. Regla ética: road_reports no tiene ninguna columna de texto libre
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'road_reports' AND data_type = 'text'
               AND column_name NOT IN ('segment_id', 'kind')) THEN
    RAISE EXCEPTION '13: road_reports tiene un campo de texto libre';
  END IF;
END $$;

\echo '013_corridor_test: OK'
