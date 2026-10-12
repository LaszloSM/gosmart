-- supabase/tests/011_roles_safety_test.sql
-- Roles, conductores, contactos, SOS y viaje compartido.
-- Requiere: _supabase_stub.sql, _profiles_fixture.sql y 011_roles_safety.sql.
\set ON_ERROR_STOP on

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'ana@test.co'),
  ('00000000-0000-0000-0000-0000000000b2', 'beto@test.co'),
  ('00000000-0000-0000-0000-0000000000c3', 'admin@test.co')
ON CONFLICT DO NOTHING;

-- El primer admin lo nombra el servidor (sin auth.uid()).
UPDATE profiles SET role = 'admin' WHERE id = '00000000-0000-0000-0000-0000000000c3';
UPDATE profiles SET name = 'Ana María Pérez' WHERE id = '00000000-0000-0000-0000-0000000000a1';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);

-- 1. Ana no puede subirse a admin
DO $$
BEGIN
  BEGIN
    UPDATE profiles SET role = 'admin' WHERE id = auth.uid();
    RAISE EXCEPTION '1: una pasajera se volvió admin';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- pero sí edita su nombre
  UPDATE profiles SET name = 'Ana María Pérez' WHERE id = auth.uid();
END $$;

-- 2. Registro de conductora: queda pendiente aunque mande 'approved'
DO $$
DECLARE s TEXT;
BEGIN
  INSERT INTO drivers (user_id, full_name, cedula, phone, service, zone, status, available)
  VALUES (auth.uid(), 'Ana María Pérez', '1118555444', '+573001234567',
          'mototaxi', 'riohacha', 'approved', false);
  SELECT status INTO s FROM drivers WHERE user_id = auth.uid();
  IF s <> 'pending' THEN RAISE EXCEPTION '2: el registro quedó como %', s; END IF;
END $$;

-- 3. No puede ponerse disponible ni aprobarse sola
DO $$
BEGIN
  BEGIN
    UPDATE drivers SET available = true WHERE user_id = auth.uid();
    RAISE EXCEPTION '3: disponible sin aprobación';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE drivers SET status = 'approved' WHERE user_id = auth.uid();
    RAISE EXCEPTION '3: se aprobó sola';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM admin_review_driver(auth.uid(), 'approved', NULL);
    RAISE EXCEPTION '3: llamó la revisión de admin';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 4. Vehículo: la placa se normaliza; una placa inválida se rechaza
DO $$
DECLARE pl TEXT;
BEGIN
  INSERT INTO vehicles (driver_id, kind, plate) VALUES (auth.uid(), 'moto', 'abc 12d');
  SELECT plate INTO pl FROM vehicles WHERE driver_id = auth.uid();
  IF pl <> 'ABC12D' THEN RAISE EXCEPTION '4: placa guardada como %', pl; END IF;
  BEGIN
    INSERT INTO vehicles (driver_id, kind, plate) VALUES (auth.uid(), 'carro', 'XYZ');
    RAISE EXCEPTION '4: aceptó una placa inválida';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- 5. Documentos: solo en su carpeta del bucket
DO $$
BEGIN
  INSERT INTO driver_documents (driver_id, kind, storage_path)
  VALUES (auth.uid(), 'licencia', auth.uid()::text || '/licencia.jpg');
  BEGIN
    INSERT INTO driver_documents (driver_id, kind, storage_path)
    VALUES (auth.uid(), 'soat', '00000000-0000-0000-0000-0000000000b2/soat.jpg');
    RAISE EXCEPTION '5: documento en carpeta ajena';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- 6. Contactos: celular +57 y máximo 5
DO $$
BEGIN
  BEGIN
    INSERT INTO emergency_contacts (user_id, name, phone) VALUES (auth.uid(), 'Mamá', '3001112233');
    RAISE EXCEPTION '6: aceptó un celular sin +57';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  FOR i IN 1..5 LOOP
    INSERT INTO emergency_contacts (user_id, name, phone)
    VALUES (auth.uid(), 'Contacto ' || i, '+57300111223' || i);
  END LOOP;
  BEGIN
    INSERT INTO emergency_contacts (user_id, name, phone) VALUES (auth.uid(), 'Sexto', '+573009999999');
    RAISE EXCEPTION '6: aceptó un sexto contacto';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- 7. SOS idempotente y sin borrar
DO $$
DECLARE n INT;
BEGIN
  INSERT INTO sos_events (user_id, lat, lng, channels, idempotency_key)
  VALUES (auth.uid(), 11.544, -72.907, '{whatsapp}', '22222222-2222-2222-2222-222222222222')
  ON CONFLICT (user_id, idempotency_key) DO NOTHING;
  INSERT INTO sos_events (user_id, lat, lng, channels, idempotency_key)
  VALUES (auth.uid(), 11.544, -72.907, '{whatsapp}', '22222222-2222-2222-2222-222222222222')
  ON CONFLICT (user_id, idempotency_key) DO NOTHING;
  SELECT count(*) INTO n FROM sos_events;
  IF n <> 1 THEN RAISE EXCEPTION '7: el reintento duplicó el SOS (%)', n; END IF;
  BEGIN
    DELETE FROM sos_events;
    RAISE EXCEPTION '7: se pudo borrar un SOS';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 8. Compartir viaje: token largo, vista pública solo con primer nombre
CREATE TEMP TABLE IF NOT EXISTS t_share (token TEXT);
GRANT ALL ON t_share TO PUBLIC;
DO $$
DECLARE r RECORD; v RECORD;
BEGIN
  SELECT * INTO r FROM trip_share_start('Terminal de Maicao', 'Colectivo', 4, 11.54, -72.90);
  IF char_length(r.token) < 64 THEN RAISE EXCEPTION '8: token corto'; END IF;
  INSERT INTO t_share VALUES (r.token);
  IF NOT trip_share_update(r.token, 11.40, -72.60) THEN RAISE EXCEPTION '8: no actualizó'; END IF;
  SELECT * INTO v FROM trip_share_view(r.token);
  IF v.first_name <> 'Ana' THEN RAISE EXCEPTION '8: nombre expuesto: %', v.first_name; END IF;
  IF v.state <> 'active' OR v.last_lng <> -72.60 THEN RAISE EXCEPTION '8: vista incorrecta'; END IF;
  BEGIN
    PERFORM trip_share_start('x', NULL, 48);
    RAISE EXCEPTION '8: aceptó 48 horas';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    UPDATE trip_shares SET expires_at = now() + interval '30 days';
    RAISE EXCEPTION '8: extendió su link por fuera de la RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 9. Beto no ve nada de Ana ni puede mover su viaje compartido
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', false);
DO $$
DECLARE n INT; t TEXT;
BEGIN
  SELECT count(*) INTO n FROM drivers;            IF n <> 0 THEN RAISE EXCEPTION '9: ve conductores ajenos'; END IF;
  SELECT count(*) INTO n FROM emergency_contacts; IF n <> 0 THEN RAISE EXCEPTION '9: ve contactos ajenos'; END IF;
  SELECT count(*) INTO n FROM sos_events;         IF n <> 0 THEN RAISE EXCEPTION '9: ve SOS ajenos'; END IF;
  SELECT count(*) INTO n FROM trip_shares;        IF n <> 0 THEN RAISE EXCEPTION '9: ve viajes ajenos'; END IF;
  SELECT token INTO t FROM t_share;
  IF trip_share_update(t, 0, 0) THEN RAISE EXCEPTION '9: movió el viaje de Ana'; END IF;
  IF trip_share_stop(t) THEN RAISE EXCEPTION '9: detuvo el viaje de Ana'; END IF;
END $$;

-- 10. Anónimo: lee la vista pública por token, pero no la tabla
RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
DECLARE t TEXT; v RECORD;
BEGIN
  SELECT token INTO t FROM t_share;
  SELECT * INTO v FROM trip_share_view(t);
  IF v.state <> 'active' THEN RAISE EXCEPTION '10: vista anónima falló'; END IF;
  SELECT * INTO v FROM trip_share_view('token-que-no-existe-0000000000000000');
  IF v.state IS NOT NULL THEN RAISE EXCEPTION '10: token falso devolvió datos'; END IF;
  BEGIN
    PERFORM 1 FROM trip_shares;
    RAISE EXCEPTION '10: anónimo leyó trip_shares';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

-- 11. Admin aprueba: Ana pasa a conductora y ya puede ponerse disponible
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c3', false);
DO $$
DECLARE r drivers; role_now TEXT;
BEGIN
  r := admin_review_driver('00000000-0000-0000-0000-0000000000a1', 'approved', NULL);
  IF r.status <> 'approved' THEN RAISE EXCEPTION '11: no quedó aprobada'; END IF;
END $$;
RESET ROLE;
DO $$
DECLARE role_now TEXT;
BEGIN
  SELECT role INTO role_now FROM profiles WHERE id = '00000000-0000-0000-0000-0000000000a1';
  IF role_now <> 'driver' THEN RAISE EXCEPTION '11: rol quedó en %', role_now; END IF;
END $$;

-- 12. Si la conductora cambia su licencia, vuelve a revisión y deja de estar disponible
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
DO $$
DECLARE r RECORD;
BEGIN
  UPDATE drivers SET available = true WHERE user_id = auth.uid();
  UPDATE drivers SET license_number = 'NEW12345' WHERE user_id = auth.uid();
  SELECT status, available INTO r FROM drivers WHERE user_id = auth.uid();
  IF r.status <> 'pending' OR r.available THEN
    RAISE EXCEPTION '12: siguió aprobada (%, %)', r.status, r.available;
  END IF;
END $$;
RESET ROLE;

\echo '011_roles_safety_test: OK'
