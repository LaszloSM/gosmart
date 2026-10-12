-- 011_roles_safety.sql
-- Fase 3 · Núcleo: roles, conductores, vehículos y seguridad temprana.
--
--   profiles.role          passenger | driver | admin (el usuario NO se lo cambia)
--   drivers                registro del conductor; solo un admin lo aprueba
--   driver_documents       rutas en el bucket privado `driver-docs`
--   vehicles               placa colombiana normalizada, una por vehículo
--   emergency_contacts     hasta 5 por usuario, celular +57
--   sos_events             registro de cada SOS (idempotente para la cola offline)
--   trip_shares            link de solo lectura con token que expira
--
-- Sin PostGIS: lat/lng en DOUBLE PRECISION (las cercanías llegan en la Fase 6).
-- Seguro de re-ejecutar.

-- ── Rol en el perfil ─────────────────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'passenger';

DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
    CHECK (role IN ('passenger', 'driver', 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ¿El usuario de esta petición es admin? SECURITY DEFINER para no chocar
-- con la RLS de profiles al usarse dentro de otras policies.
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  )
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION is_admin() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION is_admin() TO anon, authenticated, service_role;

-- La policy profiles_own_all (002) deja al usuario editar su fila; este
-- trigger impide que se suba de rol. El servidor (sin auth.uid()) y un admin sí pueden.
CREATE OR REPLACE FUNCTION profiles_protect_role()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NULL OR is_admin() THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.role := 'passenger';
  ELSIF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'role_change_forbidden' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS profiles_protect_role ON profiles;
CREATE TRIGGER profiles_protect_role
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION profiles_protect_role();

-- ── Conductores ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS drivers (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name        TEXT NOT NULL CHECK (char_length(full_name) BETWEEN 3 AND 120),
  cedula           TEXT NOT NULL CHECK (cedula ~ '^[0-9]{5,12}$'),
  phone            TEXT NOT NULL CHECK (phone ~ '^\+57[0-9]{10}$'),
  service          TEXT NOT NULL
                   CHECK (service IN ('mototaxi', 'taxi', 'colectivo', 'intermunicipal')),
  zone             TEXT NOT NULL CHECK (zone IN ('riohacha', 'maicao', 'corredor')),
  license_number   TEXT CHECK (license_number ~ '^[0-9A-Z]{5,20}$'),
  license_expires  DATE,
  payout_kind      TEXT CHECK (payout_kind IN ('nequi', 'breb', 'daviplata')),
  payout_key       TEXT CHECK (char_length(payout_key) <= 80),
  status           TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  review_note      TEXT CHECK (char_length(review_note) <= 300),
  reviewed_at      TIMESTAMPTZ,
  reviewed_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  available        BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Solo un conductor aprobado puede ponerse disponible.
  CONSTRAINT drivers_available_only_approved CHECK (NOT available OR status = 'approved')
);

-- El conductor edita sus datos, pero no su verificación. Si cambia un dato
-- que el admin revisó, vuelve a revisión.
CREATE OR REPLACE FUNCTION drivers_guard()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  IF auth.uid() IS NULL OR is_admin() THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.status := 'pending';
    NEW.review_note := NULL;
    NEW.reviewed_at := NULL;
    NEW.reviewed_by := NULL;
    NEW.available := false;
    RETURN NEW;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     OR NEW.review_note IS DISTINCT FROM OLD.review_note
     OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
     OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by THEN
    RAISE EXCEPTION 'driver_review_forbidden' USING ERRCODE = '42501';
  END IF;
  IF OLD.status = 'approved' AND (
       NEW.full_name IS DISTINCT FROM OLD.full_name
    OR NEW.cedula IS DISTINCT FROM OLD.cedula
    OR NEW.service IS DISTINCT FROM OLD.service
    OR NEW.license_number IS DISTINCT FROM OLD.license_number
    OR NEW.license_expires IS DISTINCT FROM OLD.license_expires) THEN
    NEW.status := 'pending';
    NEW.available := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS drivers_guard ON drivers;
CREATE TRIGGER drivers_guard
  BEFORE INSERT OR UPDATE ON drivers
  FOR EACH ROW EXECUTE FUNCTION drivers_guard();

ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drivers_own_select ON drivers;
CREATE POLICY drivers_own_select ON drivers
  FOR SELECT USING (user_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS drivers_own_insert ON drivers;
CREATE POLICY drivers_own_insert ON drivers
  FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS drivers_own_update ON drivers;
CREATE POLICY drivers_own_update ON drivers
  FOR UPDATE USING (user_id = auth.uid() OR is_admin())
  WITH CHECK (user_id = auth.uid() OR is_admin());

-- Revisión del admin: aprueba o rechaza y ajusta el rol del perfil.
CREATE OR REPLACE FUNCTION admin_review_driver(
  p_user_id UUID,
  p_status  TEXT,
  p_note    TEXT DEFAULT NULL
)
RETURNS drivers AS $$
DECLARE
  v_row drivers;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('approved', 'rejected', 'suspended', 'pending') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
  END IF;

  UPDATE drivers
  SET status = p_status,
      review_note = p_note,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      available = CASE WHEN p_status = 'approved' THEN available ELSE false END
  WHERE user_id = p_user_id
  RETURNING * INTO v_row;

  IF v_row.user_id IS NULL THEN
    RAISE EXCEPTION 'driver_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- Un admin nunca pierde su rol por revisar su propio registro.
  UPDATE profiles
  SET role = CASE WHEN p_status = 'approved' THEN 'driver' ELSE 'passenger' END
  WHERE id = p_user_id AND role <> 'admin';

  RETURN v_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION admin_review_driver(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION admin_review_driver(UUID, TEXT, TEXT) TO authenticated;

-- ── Documentos del conductor (archivos en el bucket privado) ─────────────────
CREATE TABLE IF NOT EXISTS driver_documents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id     UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  kind          TEXT NOT NULL CHECK (kind IN
                  ('cedula', 'licencia', 'soat', 'tecnomecanica', 'tarjeta_propiedad', 'foto')),
  -- Ruta dentro del bucket: '<user_id>/<kind>-<n>.jpg'. Debe empezar por el dueño.
  storage_path  TEXT NOT NULL,
  uploaded_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT driver_documents_path_owner
    CHECK (storage_path LIKE driver_id::text || '/%'),
  UNIQUE (driver_id, kind)
);

ALTER TABLE driver_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_documents_own ON driver_documents;
CREATE POLICY driver_documents_own ON driver_documents
  FOR ALL USING (driver_id = auth.uid() OR is_admin())
  WITH CHECK (driver_id = auth.uid());

-- ── Vehículos ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vehicles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id   UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  kind        TEXT NOT NULL CHECK (kind IN ('moto', 'carro', 'camioneta', 'buseta')),
  -- Carro ABC123, moto ABC12D. Se guarda en mayúsculas y sin espacios.
  plate       TEXT NOT NULL CHECK (plate ~ '^[A-Z]{3}[0-9]{2}[0-9A-Z]$'),
  brand       TEXT CHECK (char_length(brand) <= 40),
  model       TEXT CHECK (char_length(model) <= 40),
  color       TEXT CHECK (char_length(color) <= 30),
  seats       SMALLINT NOT NULL DEFAULT 1 CHECK (seats BETWEEN 1 AND 30),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plate)
);

CREATE OR REPLACE FUNCTION vehicles_normalize_plate()
RETURNS TRIGGER AS $$
BEGIN
  NEW.plate := upper(regexp_replace(NEW.plate, '[^A-Za-z0-9]', '', 'g'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vehicles_normalize_plate ON vehicles;
CREATE TRIGGER vehicles_normalize_plate
  BEFORE INSERT OR UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION vehicles_normalize_plate();

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vehicles_own ON vehicles;
CREATE POLICY vehicles_own ON vehicles
  FOR ALL USING (driver_id = auth.uid() OR is_admin())
  WITH CHECK (driver_id = auth.uid());

-- ── Contactos de emergencia ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
  phone       TEXT NOT NULL CHECK (phone ~ '^\+57[0-9]{10}$'),
  relation    TEXT CHECK (char_length(relation) <= 40),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, phone)
);

CREATE INDEX IF NOT EXISTS emergency_contacts_user_idx ON emergency_contacts(user_id);

CREATE OR REPLACE FUNCTION emergency_contacts_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(*) FROM emergency_contacts WHERE user_id = NEW.user_id) >= 5 THEN
    RAISE EXCEPTION 'emergency_contacts_limit' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS emergency_contacts_limit ON emergency_contacts;
CREATE TRIGGER emergency_contacts_limit
  BEFORE INSERT ON emergency_contacts
  FOR EACH ROW EXECUTE FUNCTION emergency_contacts_limit();

ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS emergency_contacts_own ON emergency_contacts;
CREATE POLICY emergency_contacts_own ON emergency_contacts
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── SOS ──────────────────────────────────────────────────────────────────────
-- Se registra aunque el aviso salga por WhatsApp/SMS desde el teléfono.
-- idempotency_key: la cola offline puede reenviar el mismo SOS (decisión E6).
CREATE TABLE IF NOT EXISTS sos_events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lat              DOUBLE PRECISION CHECK (lat BETWEEN -90 AND 90),
  lng              DOUBLE PRECISION CHECK (lng BETWEEN -180 AND 180),
  accuracy_m       REAL CHECK (accuracy_m >= 0),
  channels         TEXT[] NOT NULL DEFAULT '{}',
  idempotency_key  UUID NOT NULL,
  happened_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

ALTER TABLE sos_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sos_events_own_select ON sos_events;
CREATE POLICY sos_events_own_select ON sos_events
  FOR SELECT USING (user_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS sos_events_own_insert ON sos_events;
CREATE POLICY sos_events_own_insert ON sos_events
  FOR INSERT WITH CHECK (user_id = auth.uid());
-- Sin UPDATE ni DELETE: un SOS no se borra desde el teléfono.

-- ── Compartir viaje ──────────────────────────────────────────────────────────
-- El token viaja en el link de WhatsApp; quien lo tenga ve destino y última
-- posición hasta que expire o el usuario lo detenga. Nada más.
CREATE TABLE IF NOT EXISTS trip_shares (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token              TEXT NOT NULL UNIQUE CHECK (char_length(token) >= 32),
  destination_label  TEXT CHECK (char_length(destination_label) <= 120),
  mode_label         TEXT CHECK (char_length(mode_label) <= 40),
  last_lat           DOUBLE PRECISION CHECK (last_lat BETWEEN -90 AND 90),
  last_lng           DOUBLE PRECISION CHECK (last_lng BETWEEN -180 AND 180),
  last_seen_at       TIMESTAMPTZ,
  expires_at         TIMESTAMPTZ NOT NULL,
  stopped_at         TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS trip_shares_user_idx ON trip_shares(user_id, created_at DESC);

ALTER TABLE trip_shares ENABLE ROW LEVEL SECURITY;
-- El dueño lee los suyos; escribir solo por las RPCs de abajo.
DROP POLICY IF EXISTS trip_shares_own_select ON trip_shares;
CREATE POLICY trip_shares_own_select ON trip_shares
  FOR SELECT USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION trip_share_start(
  p_destination TEXT,
  p_mode        TEXT DEFAULT NULL,
  p_hours       INTEGER DEFAULT 4,
  p_lat         DOUBLE PRECISION DEFAULT NULL,
  p_lng         DOUBLE PRECISION DEFAULT NULL
)
RETURNS TABLE (token TEXT, expires_at TIMESTAMPTZ) AS $$
DECLARE
  v_user  UUID := auth.uid();
  v_token TEXT;
  v_exp   TIMESTAMPTZ;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_hours IS NULL OR p_hours < 1 OR p_hours > 12 THEN
    RAISE EXCEPTION 'invalid_hours' USING ERRCODE = '22023';
  END IF;
  -- Un compartir activo a la vez: el anterior se detiene.
  UPDATE trip_shares s SET stopped_at = now()
  WHERE s.user_id = v_user AND s.stopped_at IS NULL AND s.expires_at > now();

  -- 2 UUID v4 = 244 bits aleatorios, sin depender de pgcrypto.
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  v_exp := now() + make_interval(hours => p_hours);

  INSERT INTO trip_shares (user_id, token, destination_label, mode_label,
                           last_lat, last_lng, last_seen_at, expires_at)
  VALUES (v_user, v_token, left(p_destination, 120), left(p_mode, 40),
          p_lat, p_lng, CASE WHEN p_lat IS NOT NULL THEN now() END, v_exp);

  RETURN QUERY SELECT v_token, v_exp;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION trip_share_update(
  p_token TEXT,
  p_lat   DOUBLE PRECISION,
  p_lng   DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
DECLARE
  v_n INTEGER;
BEGIN
  UPDATE trip_shares
  SET last_lat = p_lat, last_lng = p_lng, last_seen_at = now()
  WHERE token = p_token
    AND user_id = auth.uid()
    AND stopped_at IS NULL
    AND expires_at > now();
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION trip_share_stop(p_token TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_n INTEGER;
BEGIN
  UPDATE trip_shares SET stopped_at = now()
  WHERE token = p_token AND user_id = auth.uid() AND stopped_at IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Lectura pública por token (la usa la página web de WhatsApp).
-- Solo el primer nombre de quien comparte; nunca correo, cédula ni teléfono.
CREATE OR REPLACE FUNCTION trip_share_view(p_token TEXT)
RETURNS TABLE (
  first_name        TEXT,
  destination_label TEXT,
  mode_label        TEXT,
  last_lat          DOUBLE PRECISION,
  last_lng          DOUBLE PRECISION,
  last_seen_at      TIMESTAMPTZ,
  expires_at        TIMESTAMPTZ,
  state             TEXT
) AS $$
  SELECT
    NULLIF(split_part(trim(coalesce(p.name, '')), ' ', 1), ''),
    s.destination_label,
    s.mode_label,
    CASE WHEN s.stopped_at IS NULL AND s.expires_at > now() THEN s.last_lat END,
    CASE WHEN s.stopped_at IS NULL AND s.expires_at > now() THEN s.last_lng END,
    s.last_seen_at,
    s.expires_at,
    CASE
      WHEN s.stopped_at IS NOT NULL THEN 'stopped'
      WHEN s.expires_at <= now() THEN 'expired'
      ELSE 'active'
    END
  FROM trip_shares s
  LEFT JOIN profiles p ON p.id = s.user_id
  WHERE s.token = p_token
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION trip_share_start(TEXT, TEXT, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION trip_share_update(TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION trip_share_stop(TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION trip_share_start(TEXT, TEXT, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT  EXECUTE ON FUNCTION trip_share_update(TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT  EXECUTE ON FUNCTION trip_share_stop(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION trip_share_view(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION trip_share_view(TEXT) TO anon, authenticated, service_role;

-- ── Permisos de tabla (Supabase ya da algunos por defecto; aquí quedan explícitos) ──
REVOKE ALL ON drivers, driver_documents, vehicles, emergency_contacts, sos_events, trip_shares FROM anon;
GRANT SELECT, INSERT, UPDATE ON drivers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON driver_documents, vehicles, emergency_contacts TO authenticated;
REVOKE UPDATE, DELETE ON sos_events FROM authenticated;
GRANT SELECT, INSERT ON sos_events TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON trip_shares FROM authenticated;
GRANT SELECT ON trip_shares TO authenticated;

-- ── Bucket privado para documentos (solo existe en Supabase) ─────────────────
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('driver-docs', 'driver-docs', false)
  ON CONFLICT (id) DO UPDATE SET public = false;

  EXECUTE 'DROP POLICY IF EXISTS driver_docs_own ON storage.objects';
  -- Cada conductor solo toca su carpeta '<user_id>/...'; el admin lee todo.
  EXECUTE $p$
    CREATE POLICY driver_docs_own ON storage.objects
      FOR ALL TO authenticated
      USING (bucket_id = 'driver-docs'
             AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin()))
      WITH CHECK (bucket_id = 'driver-docs'
             AND (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
END $$;

NOTIFY pgrst, 'reload schema';
