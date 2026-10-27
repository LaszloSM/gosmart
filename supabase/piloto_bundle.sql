-- GoSmart · migraciones 008–020 + semilla de lugares (generado por tool/bundle_migrations.sh)
-- Requiere 001–007 aplicadas antes. Seguro de correr más de una vez.

-- ===================== supabase/migrations/008_wallet_mock.sql =====================
-- 008_wallet_mock.sql
-- Wallet simulado para GoSmart (proyecto académico — sin pagos reales)

CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  balance INTEGER DEFAULT 10000 CHECK (balance >= 0),
  card_number TEXT UNIQUE,
  card_status TEXT DEFAULT 'active' CHECK (card_status IN ('active', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('recharge', 'trip', 'refund', 'bonus')),
  amount INTEGER NOT NULL,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_user ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_wallet ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_created ON wallet_transactions(created_at DESC);

-- Genera número de tarjeta GoSmart simulado
CREATE OR REPLACE FUNCTION generate_gosmart_card_number()
RETURNS TEXT AS $$
BEGIN
  RETURN 'GS-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0') || '-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0') || '-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Crea wallet automáticamente al registrarse un nuevo usuario
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wallets (user_id, card_number, balance)
  VALUES (NEW.id, generate_gosmart_card_number(), 10000)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_wallet_create ON auth.users;
CREATE TRIGGER on_auth_user_wallet_create
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- RPC para recarga segura (evita race conditions)
CREATE OR REPLACE FUNCTION recharge_wallet(
  p_user_id UUID,
  p_amount INTEGER,
  p_description TEXT DEFAULT 'Recarga de saldo'
)
RETURNS TABLE (new_balance INTEGER, transaction_id UUID) AS $$
DECLARE
  v_wallet_id UUID;
  v_new_balance INTEGER;
  v_txn_id UUID;
BEGIN
  SELECT id, balance INTO v_wallet_id, v_new_balance
  FROM wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  v_new_balance := v_new_balance + p_amount;

  IF v_new_balance < 0 THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  UPDATE wallets SET balance = v_new_balance, updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, type, amount, description)
  VALUES (
    v_wallet_id,
    CASE WHEN p_amount >= 0 THEN 'recharge' ELSE 'trip' END,
    p_amount,
    p_description
  )
  RETURNING id INTO v_txn_id;

  RETURN QUERY SELECT v_new_balance, v_txn_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own wallet" ON wallets;
CREATE POLICY "Users can view own wallet" ON wallets
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own wallet" ON wallets;
CREATE POLICY "Users can update own wallet" ON wallets
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own wallet_transactions" ON wallet_transactions;
CREATE POLICY "Users can view own wallet_transactions" ON wallet_transactions
  FOR SELECT USING (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert own wallet_transactions" ON wallet_transactions;
CREATE POLICY "Users can insert own wallet_transactions" ON wallet_transactions
  FOR INSERT WITH CHECK (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );


-- ===================== supabase/migrations/009_favorites_history.sql =====================
-- 009_favorites_history.sql
-- Lugares favoritos e historial de viajes

CREATE TABLE IF NOT EXISTS favorite_places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  type TEXT DEFAULT 'custom' CHECK (type IN ('home', 'work', 'custom')),
  icon TEXT DEFAULT 'location_on',
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Solo un "home" y un "work" por usuario
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_home_per_user
  ON favorite_places(user_id) WHERE type = 'home';
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_work_per_user
  ON favorite_places(user_id) WHERE type = 'work';

CREATE TABLE IF NOT EXISTS trip_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  origin_name TEXT NOT NULL,
  origin_address TEXT,
  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  destination_name TEXT NOT NULL,
  destination_address TEXT,
  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,
  mode TEXT NOT NULL,
  duration_min INTEGER,
  distance_km DOUBLE PRECISION,
  cost_cop INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorite_places(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_history_user ON trip_history(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_history_created ON trip_history(created_at DESC);

-- Función para incrementar use_count al usar un favorito
CREATE OR REPLACE FUNCTION increment_favorite_use(p_favorite_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE favorite_places
  SET use_count = use_count + 1, updated_at = NOW()
  WHERE id = p_favorite_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE favorite_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own favorites" ON favorite_places;
CREATE POLICY "Users manage own favorites" ON favorite_places
  FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own trip_history" ON trip_history;
CREATE POLICY "Users manage own trip_history" ON trip_history
  FOR ALL USING (auth.uid() = user_id);


-- ===================== supabase/migrations/010_wallet_hardening.sql =====================
-- 010_wallet_hardening.sql
-- Billetera como único modelo de dinero, sin huecos de seguridad.
--
-- Problemas que corrige de 008_wallet_mock.sql:
--   1. recharge_wallet(p_user_id, ...) es SECURITY DEFINER y recibe el usuario
--      desde el cliente: cualquiera podía cargar o descontar la billetera de otro.
--   2. La policy "Users can update own wallet" permitía fijar el propio saldo.
--   3. La policy de INSERT en wallet_transactions permitía inventar movimientos.
--
-- Desde ahora el saldo solo cambia por RPCs que leen auth.uid() en el servidor.
-- Seguro de re-ejecutar.

-- ── Policies: solo lectura para el usuario ───────────────────────────────────
DROP POLICY IF EXISTS "Users can update own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can insert own wallet_transactions" ON wallet_transactions;

-- ── Idempotencia: reintentos offline no duplican movimientos (decisión E6) ───
ALTER TABLE wallet_transactions
  ADD COLUMN IF NOT EXISTS idempotency_key UUID;
CREATE UNIQUE INDEX IF NOT EXISTS wallet_transactions_idempotency_key_idx
  ON wallet_transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ── recharge_wallet queda solo para el servidor (service_role) ───────────────
REVOKE EXECUTE ON FUNCTION recharge_wallet(UUID, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;

-- ── Recarga simulada (hasta que llegue Wompi en la Fase 7) ───────────────────
-- Usa auth.uid(); el cliente no puede elegir de quién es la billetera.
-- Montos entre $1.000 y $200.000 COP. Mismo idempotency_key → mismo resultado.
CREATE OR REPLACE FUNCTION wallet_recharge_simulated(
  p_amount INTEGER,
  p_idempotency_key UUID
)
RETURNS TABLE (new_balance INTEGER, transaction_id UUID) AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_wallet_id   UUID;
  v_balance     INTEGER;
  v_existing_id UUID;
  v_txn_id      UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount < 1000 OR p_amount > 200000 THEN
    RAISE EXCEPTION 'invalid_amount' USING ERRCODE = '22023';
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'wallet_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- Reintento del mismo pedido: devolver lo ya hecho sin volver a sumar.
  SELECT id INTO v_existing_id
  FROM wallet_transactions
  WHERE idempotency_key = p_idempotency_key AND wallet_id = v_wallet_id;
  IF v_existing_id IS NOT NULL THEN
    RETURN QUERY SELECT v_balance, v_existing_id;
    RETURN;
  END IF;

  v_balance := v_balance + p_amount;

  UPDATE wallets SET balance = v_balance, updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, type, amount, description, idempotency_key, metadata)
  VALUES (v_wallet_id, 'recharge', p_amount, 'Recarga simulada', p_idempotency_key,
          jsonb_build_object('simulated', true))
  RETURNING id INTO v_txn_id;

  RETURN QUERY SELECT v_balance, v_txn_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION wallet_recharge_simulated(INTEGER, UUID) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION wallet_recharge_simulated(INTEGER, UUID) TO authenticated;

-- ── Billetera para usuarios que se registraron antes del trigger de 008 ──────
INSERT INTO wallets (user_id, card_number, balance)
SELECT u.id, generate_gosmart_card_number(), 10000
FROM auth.users u
LEFT JOIN wallets w ON w.user_id = u.id
WHERE w.id IS NULL
ON CONFLICT (user_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/011_roles_safety.sql =====================
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


-- ===================== supabase/migrations/012_places_directory.sql =====================
-- 012_places_directory.sql
-- Directorio propio de referencias (gazetteer): cómo la gente nombra los
-- lugares en Riohacha y Maicao ("el muelle", "frente al Éxito", "la terminal").
-- Es lo primero que consulta el buscador; Google/Mapbox va después (Fase 3, D8).
-- Lectura pública (también invitados); escritura solo admin.
-- Seguro de re-ejecutar.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Minúsculas y sin tildes, sin depender de la extensión unaccent (que no es
-- IMMUTABLE y no sirve en columnas generadas).
CREATE OR REPLACE FUNCTION gs_norm(t TEXT)
RETURNS TEXT AS $$
  SELECT regexp_replace(
    lower(translate(coalesce(t, ''), 'ÁÉÍÓÚÜÑáéíóúüñ', 'aeiouunaeiouun')),
    '\s+', ' ', 'g')
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

-- Concatena nombre y alias. Función propia porque array_to_string no es
-- IMMUTABLE y la columna generada lo exige.
CREATE OR REPLACE FUNCTION gs_place_text(p_name TEXT, p_aliases TEXT[])
RETURNS TEXT AS $$
  SELECT gs_norm(p_name || ' ' || coalesce(array_to_string(p_aliases, ' '), ''))
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

CREATE TABLE IF NOT EXISTS places (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 120),
  aliases     TEXT[] NOT NULL DEFAULT '{}',
  city        TEXT NOT NULL CHECK (city IN ('riohacha', 'maicao', 'corredor', 'otro')),
  kind        TEXT NOT NULL DEFAULT 'referencia'
              CHECK (kind IN ('referencia', 'barrio', 'terminal', 'paradero',
                              'comercio', 'institucion', 'salud', 'educacion',
                              'turismo', 'via')),
  lat         DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN 10.0 AND 12.6),
  lng         DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -73.8 AND -71.0),
  -- false = coordenada aproximada, pendiente de verificar en campo (Fase 1).
  verified    BOOLEAN NOT NULL DEFAULT false,
  source      TEXT NOT NULL DEFAULT 'admin'
              CHECK (source IN ('campo', 'admin', 'osm', 'semilla')),
  search_text TEXT GENERATED ALWAYS AS (gs_place_text(name, aliases)) STORED,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (city, name)
);

CREATE INDEX IF NOT EXISTS places_search_trgm_idx
  ON places USING gin (search_text gin_trgm_ops);

ALTER TABLE places ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS places_public_read ON places;
CREATE POLICY places_public_read ON places FOR SELECT USING (true);
DROP POLICY IF EXISTS places_admin_write ON places;
CREATE POLICY places_admin_write ON places
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

GRANT SELECT ON places TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON places TO authenticated;  -- la policy deja solo al admin

-- Búsqueda difusa: tolera tildes, errores de tecleo y orden de palabras.
-- Con p_lat/p_lng, a igual parecido gana lo más cercano.
CREATE OR REPLACE FUNCTION search_places(
  p_query TEXT,
  p_lat   DOUBLE PRECISION DEFAULT NULL,
  p_lng   DOUBLE PRECISION DEFAULT NULL,
  p_limit INTEGER DEFAULT 8
)
RETURNS TABLE (
  id        UUID,
  name      TEXT,
  city      TEXT,
  kind      TEXT,
  lat       DOUBLE PRECISION,
  lng       DOUBLE PRECISION,
  verified  BOOLEAN,
  score     REAL
) AS $$
  WITH q AS (SELECT gs_norm(p_query) AS t)
  SELECT p.id, p.name, p.city, p.kind, p.lat, p.lng, p.verified,
         greatest(word_similarity(q.t, p.search_text),
                  similarity(q.t, p.search_text))::REAL AS score
  FROM places p, q
  WHERE char_length(q.t) >= 2
    -- Umbral 0.4 explícito: el de <% (0.6) deja fuera errores de tecleo comunes.
    -- El directorio tiene cientos de filas, no millones: el índice ayuda al LIKE.
    AND (word_similarity(q.t, p.search_text) >= 0.4
         OR p.search_text LIKE '%' || q.t || '%')
  ORDER BY
    score DESC,
    CASE WHEN p_lat IS NULL THEN 0
         ELSE (p.lat - p_lat)^2 + ((p.lng - p_lng) * cos(radians(p_lat)))^2 END,
    p.name
  LIMIT least(greatest(coalesce(p_limit, 8), 1), 20)
$$ LANGUAGE sql STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION search_places(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/013_corridor.sql =====================
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


-- ===================== supabase/migrations/014_transport_graph.sql =====================
-- 014_transport_graph.sql
-- Fase 5 · Grafo de transporte para el planificador en el celular (D6).
--   graph_nodes   puntos donde se sube o baja: terminales, paraderos, puntos de colectivo
--   graph_edges   servicios entre puntos: modo, minutos, espera, tarifa mín/máx,
--                 tramos de la Troncal que recorre (para bloqueos), si opera de noche
--   fare_rules    tarifa de referencia por modo (mototaxi/taxi), provisional
--   graph_snapshot()  todo en un JSON para guardarlo en el teléfono
-- Lectura pública; escritura solo admin. SEMILLA APROXIMADA (verified=false)
-- hasta el levantamiento de campo (Fase 1). Seguro de re-ejecutar.

CREATE TABLE IF NOT EXISTS graph_nodes (
  id        TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  kind      TEXT NOT NULL DEFAULT 'paradero'
            CHECK (kind IN ('paradero', 'terminal', 'punto_colectivo', 'cruce')),
  city      TEXT,
  lat       DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN 10.0 AND 12.6),
  lng       DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -73.8 AND -71.0),
  verified  BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS graph_edges (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_node     TEXT NOT NULL REFERENCES graph_nodes(id) ON DELETE CASCADE,
  to_node       TEXT NOT NULL REFERENCES graph_nodes(id) ON DELETE CASCADE,
  mode          TEXT NOT NULL CHECK (mode IN
                  ('walk', 'colectivo', 'transpadilla', 'intermunicipal', 'mototaxi', 'taxi')),
  minutes       INTEGER NOT NULL CHECK (minutes > 0),
  wait_minutes  INTEGER NOT NULL DEFAULT 0 CHECK (wait_minutes >= 0),
  fare_min      INTEGER NOT NULL DEFAULT 0 CHECK (fare_min >= 0),
  fare_max      INTEGER NOT NULL DEFAULT 0,
  segment_ids   TEXT[] NOT NULL DEFAULT '{}',
  night_ok      BOOLEAN NOT NULL DEFAULT true,
  verified      BOOLEAN NOT NULL DEFAULT false,
  CHECK (fare_max >= fare_min),
  CHECK (from_node <> to_node),
  UNIQUE (from_node, to_node, mode)
);

CREATE TABLE IF NOT EXISTS fare_rules (
  mode         TEXT PRIMARY KEY CHECK (mode IN ('mototaxi', 'taxi')),
  base         INTEGER NOT NULL,
  per_km       INTEGER NOT NULL,
  minimum      INTEGER NOT NULL DEFAULT 0,
  night_factor NUMERIC(3,2) NOT NULL DEFAULT 1.20,
  verified     BOOLEAN NOT NULL DEFAULT false,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE graph_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE graph_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE fare_rules  ENABLE ROW LEVEL SECURITY;
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['graph_nodes', 'graph_edges', 'fare_rules'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_public', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR SELECT USING (true)', t || '_public', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_admin', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR ALL USING (is_admin()) WITH CHECK (is_admin())',
                   t || '_admin', t);
    EXECUTE format('GRANT SELECT ON %I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON %I TO authenticated', t);
  END LOOP;
END $$;

-- ── Semilla (igual a test/planner/fixture_graph.dart) ────────────────────────
INSERT INTO graph_nodes (id, name, kind, city, lat, lng) VALUES
  ('rio-centro',     'Parque Padilla',            'paradero', 'riohacha', 11.5441, -72.9071),
  ('rio-terminal',   'Terminal de Riohacha',      'terminal', 'riohacha', 11.5330, -72.9125),
  ('rio-uniguajira', 'Universidad de La Guajira', 'paradero', 'riohacha', 11.5275, -72.8880),
  ('mai-terminal',   'Terminal de Maicao',        'terminal', 'maicao',   11.3790, -72.2370),
  ('mai-centro',     'Centro de Maicao',          'paradero', 'maicao',   11.3780, -72.2405),
  ('cuestecitas',    'Cuestecitas',               'cruce',    'corredor', 11.2050, -72.6160),
  ('albania',        'Albania',                   'punto_colectivo', 'corredor', 11.1610, -72.5920)
ON CONFLICT (id) DO NOTHING;

-- Cada servicio en ambos sentidos; los tramos se invierten en el regreso.
WITH s(a, b, mode, minutes, wait, fmin, fmax, segs, night) AS (VALUES
  ('rio-centro',   'rio-uniguajira', 'transpadilla',   20, 10,  2500,  2500, '{}'::text[], true),
  ('rio-centro',   'rio-terminal',   'transpadilla',   10, 10,  2500,  2500, '{}'::text[], true),
  ('rio-terminal', 'mai-centro',     'colectivo',      70, 20, 12000, 15000,
     '{troncal-00-10,troncal-10-20,troncal-20-30,troncal-30-40,troncal-40-50,troncal-50-60,troncal-60-75}'::text[], false),
  ('rio-terminal', 'mai-terminal',   'intermunicipal', 75, 30, 13000, 16000,
     '{troncal-00-10,troncal-10-20,troncal-20-30,troncal-30-40,troncal-40-50,troncal-50-60,troncal-60-75}'::text[], true),
  ('rio-terminal', 'cuestecitas',    'intermunicipal', 60, 30, 12000, 15000, '{}'::text[], true),
  ('cuestecitas',  'albania',        'colectivo',      20, 15,  4000,  5000, '{desvio-albania-cuestecitas}'::text[], true),
  ('albania',      'mai-terminal',   'colectivo',      40, 15,  8000, 10000, '{}'::text[], true),
  ('mai-terminal', 'mai-centro',     'walk',            5,  0,     0,     0, '{}'::text[], true)
)
INSERT INTO graph_edges (from_node, to_node, mode, minutes, wait_minutes, fare_min, fare_max, segment_ids, night_ok)
SELECT a, b, mode, minutes, wait, fmin, fmax, segs, night FROM s
UNION ALL
SELECT b, a, mode, minutes, wait, fmin, fmax,
       ARRAY(SELECT x FROM unnest(segs) WITH ORDINALITY u(x, i) ORDER BY i DESC), night FROM s
ON CONFLICT (from_node, to_node, mode) DO NOTHING;

INSERT INTO fare_rules (mode, base, per_km, minimum) VALUES
  ('mototaxi', 2000,  700, 3000),
  ('taxi',     4000, 1300, 7000)
ON CONFLICT (mode) DO NOTHING;

-- ── Todo el grafo en un JSON (para guardarlo y planear sin señal) ───────────
CREATE OR REPLACE FUNCTION graph_snapshot()
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'nodes', coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM graph_nodes n), '[]'),
    'edges', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'from_node', e.from_node, 'to_node', e.to_node, 'mode', e.mode,
                 'minutes', e.minutes, 'wait_minutes', e.wait_minutes,
                 'fare_min', e.fare_min, 'fare_max', e.fare_max,
                 'segment_ids', e.segment_ids, 'night_ok', e.night_ok,
                 'verified', e.verified) ORDER BY e.from_node, e.to_node, e.mode)
               FROM graph_edges e), '[]'),
    'fare_rules', coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM fare_rules f), '[]'),
    'generated_at', now()
  )
$$ LANGUAGE sql STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION graph_snapshot() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/015_dispatch.sql =====================
-- 015_dispatch.sql
-- Fase 6 · Despacho estilo InDrive, colectivos con cupos y viaje encadenado.
--
--   app_flags            interruptores (dispatch_enabled) para apagar el despacho en el piloto
--   driver_locations     última posición del conductor disponible
--   ride_requests        el pasajero pide mototaxi/taxi con una tarifa sugerida
--   ride_offers          contraofertas de conductores
--   colectivo_departures salidas publicadas por conductores de colectivo
--   seat_reservations    cupos reservados
--   trips / trip_legs    viaje encadenado con máquina de estados
--
-- D7: aceptar una solicitud y reservar un cupo son RPCs con bloqueo de fila.
-- Gana uno solo; el otro recibe 'already_taken' / 'no_seats'.
-- Sin PostGIS: distancias con gs_km() (haversine). Seguro de re-ejecutar.

-- ── Interruptores ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_flags (
  key        TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE app_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_flags_public ON app_flags;
CREATE POLICY app_flags_public ON app_flags FOR SELECT USING (true);
DROP POLICY IF EXISTS app_flags_admin ON app_flags;
CREATE POLICY app_flags_admin ON app_flags FOR ALL USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON app_flags TO anon, authenticated;
GRANT INSERT, UPDATE ON app_flags TO authenticated;
INSERT INTO app_flags (key, enabled) VALUES ('dispatch_enabled', true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION flag_on(p_key TEXT) RETURNS BOOLEAN AS $$
  SELECT coalesce((SELECT enabled FROM app_flags WHERE key = p_key), false)
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Distancia en km (haversine). IMMUTABLE para usarla en filtros.
CREATE OR REPLACE FUNCTION gs_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
                                 lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
  SELECT 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

-- Conductor aprobado y disponible del servicio dado (o cualquiera si NULL).
CREATE OR REPLACE FUNCTION is_active_driver(p_service TEXT DEFAULT NULL)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM drivers
                 WHERE user_id = auth.uid() AND status = 'approved' AND available
                   AND (p_service IS NULL OR service = p_service))
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Posición del conductor ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id  UUID PRIMARY KEY REFERENCES drivers(user_id) ON DELETE CASCADE,
  lat        DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng        DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -180 AND 180),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_locations_own ON driver_locations;
CREATE POLICY driver_locations_own ON driver_locations
  FOR SELECT USING (driver_id = auth.uid());
REVOKE ALL ON driver_locations FROM anon;
GRANT SELECT ON driver_locations TO authenticated;

CREATE OR REPLACE FUNCTION driver_ping(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
RETURNS VOID AS $$
BEGIN
  IF NOT is_active_driver() THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO driver_locations (driver_id, lat, lng, updated_at)
  VALUES (auth.uid(), p_lat, p_lng, now())
  ON CONFLICT (driver_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Solicitudes y contraofertas ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ride_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service          TEXT NOT NULL CHECK (service IN ('mototaxi', 'taxi')),
  origin_lat       DOUBLE PRECISION NOT NULL,
  origin_lng       DOUBLE PRECISION NOT NULL,
  origin_label     TEXT CHECK (char_length(origin_label) <= 120),
  dest_lat         DOUBLE PRECISION NOT NULL,
  dest_lng         DOUBLE PRECISION NOT NULL,
  dest_label       TEXT CHECK (char_length(dest_label) <= 120),
  offered_fare     INTEGER NOT NULL CHECK (offered_fare BETWEEN 1000 AND 500000),
  status           TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'accepted', 'in_progress', 'completed', 'cancelled', 'expired')),
  driver_id        UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  agreed_fare      INTEGER,
  trip_leg_id      UUID,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL DEFAULT now() + interval '3 minutes',
  accepted_at      TIMESTAMPTZ,
  finished_at      TIMESTAMPTZ,
  UNIQUE (passenger_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS ride_requests_open_idx ON ride_requests(service, status, expires_at);

CREATE TABLE IF NOT EXISTS ride_offers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id  UUID NOT NULL REFERENCES ride_requests(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  fare        INTEGER NOT NULL CHECK (fare BETWEEN 1000 AND 500000),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (request_id, driver_id)
);

ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ride_requests_parties ON ride_requests;
CREATE POLICY ride_requests_parties ON ride_requests
  FOR SELECT USING (passenger_id = auth.uid() OR driver_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS ride_offers_parties ON ride_offers;
CREATE POLICY ride_offers_parties ON ride_offers
  FOR SELECT USING (driver_id = auth.uid() OR is_admin() OR EXISTS (
    SELECT 1 FROM ride_requests r WHERE r.id = request_id AND r.passenger_id = auth.uid()));
REVOKE ALL ON ride_requests, ride_offers FROM anon;
REVOKE INSERT, UPDATE, DELETE ON ride_requests, ride_offers FROM authenticated;
GRANT SELECT ON ride_requests, ride_offers TO authenticated;

CREATE OR REPLACE FUNCTION request_ride(
  p_service TEXT,
  p_origin_lat DOUBLE PRECISION, p_origin_lng DOUBLE PRECISION, p_origin_label TEXT,
  p_dest_lat DOUBLE PRECISION, p_dest_lng DOUBLE PRECISION, p_dest_label TEXT,
  p_offered_fare INTEGER,
  p_idempotency_key UUID,
  p_trip_leg_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user UUID := auth.uid();
  v_id   UUID;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  IF NOT flag_on('dispatch_enabled') THEN
    RAISE EXCEPTION 'dispatch_disabled' USING ERRCODE = '55000';
  END IF;
  SELECT id INTO v_id FROM ride_requests WHERE passenger_id = v_user AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  -- Una solicitud abierta a la vez; las vencidas no cuentan.
  UPDATE ride_requests SET status = 'expired'
  WHERE passenger_id = v_user AND status = 'open' AND expires_at <= now();
  IF EXISTS (SELECT 1 FROM ride_requests WHERE passenger_id = v_user AND status = 'open') THEN
    RAISE EXCEPTION 'request_already_open' USING ERRCODE = '55000';
  END IF;
  IF gs_km(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng) > 60 THEN
    RAISE EXCEPTION 'too_far' USING ERRCODE = '22023';
  END IF;
  INSERT INTO ride_requests (passenger_id, service, origin_lat, origin_lng, origin_label,
                             dest_lat, dest_lng, dest_label, offered_fare, idempotency_key, trip_leg_id)
  VALUES (v_user, p_service, p_origin_lat, p_origin_lng, left(p_origin_label, 120),
          p_dest_lat, p_dest_lng, left(p_dest_label, 120), p_offered_fare, p_idempotency_key, p_trip_leg_id)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Solicitudes abiertas cerca, para un conductor disponible del mismo servicio.
-- Solo lo necesario para decidir: nunca el teléfono ni el nombre completo.
CREATE OR REPLACE FUNCTION nearby_requests(
  p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION, p_radius_km DOUBLE PRECISION DEFAULT 3)
RETURNS TABLE (id UUID, origin_label TEXT, dest_label TEXT, pickup_km NUMERIC,
               trip_km NUMERIC, offered_fare INTEGER, expires_at TIMESTAMPTZ, my_offer INTEGER) AS $$
  SELECT r.id, r.origin_label, r.dest_label,
         round(gs_km(p_lat, p_lng, r.origin_lat, r.origin_lng)::numeric, 1),
         round(gs_km(r.origin_lat, r.origin_lng, r.dest_lat, r.dest_lng)::numeric, 1),
         r.offered_fare, r.expires_at,
         (SELECT o.fare FROM ride_offers o WHERE o.request_id = r.id AND o.driver_id = auth.uid())
  FROM ride_requests r
  JOIN drivers d ON d.user_id = auth.uid()
  WHERE is_active_driver()
    AND r.status = 'open' AND r.expires_at > now()
    AND r.service = d.service
    AND r.passenger_id <> auth.uid()
    AND gs_km(p_lat, p_lng, r.origin_lat, r.origin_lng) <= least(greatest(p_radius_km, 0.5), 10)
  ORDER BY 4, r.created_at
  LIMIT 20
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- D7: el primero que bloquea la fila gana.
CREATE OR REPLACE FUNCTION accept_ride(p_request_id UUID)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT is_active_driver(r.service) THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  IF r.passenger_id = auth.uid() THEN RAISE EXCEPTION 'own_request' USING ERRCODE = '42501'; END IF;
  IF r.status <> 'open' OR r.expires_at <= now() THEN
    RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000';
  END IF;
  -- Un conductor, un viaje a la vez.
  IF EXISTS (SELECT 1 FROM ride_requests WHERE driver_id = auth.uid()
             AND status IN ('accepted', 'in_progress')) THEN
    RAISE EXCEPTION 'driver_busy' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = 'accepted', driver_id = auth.uid(), agreed_fare = offered_fare, accepted_at = now()
  WHERE id = p_request_id RETURNING * INTO r;
  UPDATE ride_offers SET status = 'rejected' WHERE request_id = p_request_id AND status = 'pending';
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION counter_offer(p_request_id UUID, p_fare INTEGER)
RETURNS UUID AS $$
DECLARE
  r ride_requests;
  v_id UUID;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id;
  IF r.id IS NULL OR r.status <> 'open' OR r.expires_at <= now() THEN
    RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000';
  END IF;
  IF NOT is_active_driver(r.service) THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO ride_offers (request_id, driver_id, fare)
  VALUES (p_request_id, auth.uid(), p_fare)
  ON CONFLICT (request_id, driver_id) DO UPDATE SET fare = EXCLUDED.fare, created_at = now(), status = 'pending'
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- El pasajero elige una contraoferta. Mismo bloqueo que accept_ride.
CREATE OR REPLACE FUNCTION accept_offer(p_offer_id UUID)
RETURNS ride_requests AS $$
DECLARE
  o ride_offers;
  r ride_requests;
BEGIN
  SELECT * INTO o FROM ride_offers WHERE id = p_offer_id;
  IF o.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO r FROM ride_requests WHERE id = o.request_id FOR UPDATE;
  IF r.passenger_id <> auth.uid() THEN RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501'; END IF;
  IF r.status <> 'open' THEN RAISE EXCEPTION 'already_taken' USING ERRCODE = '55000'; END IF;
  IF o.status <> 'pending' THEN RAISE EXCEPTION 'offer_gone' USING ERRCODE = '55000'; END IF;
  IF EXISTS (SELECT 1 FROM ride_requests WHERE driver_id = o.driver_id
             AND status IN ('accepted', 'in_progress')) THEN
    RAISE EXCEPTION 'driver_busy' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = 'accepted', driver_id = o.driver_id, agreed_fare = o.fare, accepted_at = now()
  WHERE id = r.id RETURNING * INTO r;
  UPDATE ride_offers SET status = CASE WHEN id = p_offer_id THEN 'accepted' ELSE 'rejected' END
  WHERE request_id = r.id AND status = 'pending';
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Avance del viaje: el conductor recoge y termina; cualquiera de los dos cancela.
CREATE OR REPLACE FUNCTION ride_transition(p_request_id UUID, p_to TEXT)
RETURNS ride_requests AS $$
DECLARE
  r ride_requests;
  v_me UUID := auth.uid();
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_me IS DISTINCT FROM r.passenger_id AND v_me IS DISTINCT FROM r.driver_id THEN
    RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501';
  END IF;
  IF NOT (
       (r.status = 'open'        AND p_to = 'cancelled'   AND v_me = r.passenger_id)
    OR (r.status = 'accepted'    AND p_to = 'in_progress' AND v_me = r.driver_id)
    OR (r.status = 'accepted'    AND p_to = 'cancelled')
    OR (r.status = 'in_progress' AND p_to = 'completed'   AND v_me = r.driver_id)
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  UPDATE ride_requests
  SET status = p_to,
      finished_at = CASE WHEN p_to IN ('completed', 'cancelled') THEN now() END
  WHERE id = p_request_id RETURNING * INTO r;
  RETURN r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Dónde viene mi conductor: solo para el pasajero de ese viaje aceptado.
-- DROP primero: 017 le agrega columnas y CREATE OR REPLACE no puede quitarlas
-- al volver a correr todo en orden.
DROP FUNCTION IF EXISTS ride_driver_view(UUID);
CREATE FUNCTION ride_driver_view(p_request_id UUID)
RETURNS TABLE (first_name TEXT, service TEXT, plate TEXT, vehicle TEXT,
               lat DOUBLE PRECISION, lng DOUBLE PRECISION, seen_at TIMESTAMPTZ) AS $$
  SELECT split_part(d.full_name, ' ', 1), d.service, v.plate,
         trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')),
         l.lat, l.lng, l.updated_at
  FROM ride_requests r
  JOIN drivers d ON d.user_id = r.driver_id
  LEFT JOIN vehicles v ON v.driver_id = d.user_id
  LEFT JOIN driver_locations l ON l.driver_id = d.user_id
  WHERE r.id = p_request_id AND r.passenger_id = auth.uid()
    AND r.status IN ('accepted', 'in_progress')
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Colectivos: salidas y cupos ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colectivo_departures (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id    UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  from_node    TEXT NOT NULL REFERENCES graph_nodes(id),
  to_node      TEXT NOT NULL REFERENCES graph_nodes(id),
  -- Hora estimada: el colectivo sale cuando se llena; esto es una referencia.
  depart_at    TIMESTAMPTZ NOT NULL,
  seats_total  SMALLINT NOT NULL CHECK (seats_total BETWEEN 1 AND 30),
  seats_taken  SMALLINT NOT NULL DEFAULT 0,
  fare         INTEGER NOT NULL CHECK (fare BETWEEN 1000 AND 200000),
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'full', 'departed', 'cancelled')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (seats_taken BETWEEN 0 AND seats_total),
  CHECK (from_node <> to_node)
);
CREATE INDEX IF NOT EXISTS colectivo_departures_route_idx
  ON colectivo_departures(from_node, to_node, status, depart_at);

CREATE TABLE IF NOT EXISTS seat_reservations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  departure_id     UUID NOT NULL REFERENCES colectivo_departures(id) ON DELETE CASCADE,
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seats            SMALLINT NOT NULL CHECK (seats BETWEEN 1 AND 4),
  status           TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'cancelled', 'boarded')),
  trip_leg_id      UUID,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (passenger_id, idempotency_key)
);

ALTER TABLE colectivo_departures ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_reservations ENABLE ROW LEVEL SECURITY;
-- Las salidas abiertas las ve cualquiera (también invitados, para planear).
DROP POLICY IF EXISTS departures_public ON colectivo_departures;
CREATE POLICY departures_public ON colectivo_departures FOR SELECT USING (true);
DROP POLICY IF EXISTS reservations_parties ON seat_reservations;
CREATE POLICY reservations_parties ON seat_reservations
  FOR SELECT USING (passenger_id = auth.uid() OR is_admin() OR EXISTS (
    SELECT 1 FROM colectivo_departures d WHERE d.id = departure_id AND d.driver_id = auth.uid()));
GRANT SELECT ON colectivo_departures TO anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON colectivo_departures, seat_reservations FROM authenticated;
REVOKE ALL ON seat_reservations FROM anon;
GRANT SELECT ON seat_reservations TO authenticated;

CREATE OR REPLACE FUNCTION publish_departure(
  p_from TEXT, p_to TEXT, p_depart_at TIMESTAMPTZ, p_seats SMALLINT, p_fare INTEGER)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT is_active_driver('colectivo') AND NOT is_active_driver('intermunicipal') THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  IF p_depart_at < now() - interval '10 minutes' OR p_depart_at > now() + interval '24 hours' THEN
    RAISE EXCEPTION 'invalid_time' USING ERRCODE = '22023';
  END IF;
  INSERT INTO colectivo_departures (driver_id, from_node, to_node, depart_at, seats_total, fare)
  VALUES (auth.uid(), p_from, p_to, p_depart_at, p_seats, p_fare)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- D7: bloquear la salida, revisar cupos y reservar en una sola transacción.
CREATE OR REPLACE FUNCTION reserve_seat(
  p_departure_id UUID, p_seats SMALLINT, p_idempotency_key UUID, p_trip_leg_id UUID DEFAULT NULL)
RETURNS UUID AS $$
DECLARE
  d colectivo_departures;
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT id INTO v_id FROM seat_reservations
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  SELECT * INTO d FROM colectivo_departures WHERE id = p_departure_id FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF d.driver_id = auth.uid() THEN RAISE EXCEPTION 'own_departure' USING ERRCODE = '42501'; END IF;
  IF d.status <> 'open' OR d.seats_taken + p_seats > d.seats_total THEN
    RAISE EXCEPTION 'no_seats' USING ERRCODE = '55000';
  END IF;
  INSERT INTO seat_reservations (departure_id, passenger_id, seats, idempotency_key, trip_leg_id)
  VALUES (p_departure_id, auth.uid(), p_seats, p_idempotency_key, p_trip_leg_id)
  RETURNING id INTO v_id;
  UPDATE colectivo_departures
  SET seats_taken = seats_taken + p_seats,
      status = CASE WHEN seats_taken + p_seats >= seats_total THEN 'full' ELSE status END
  WHERE id = p_departure_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cancel_reservation(p_reservation_id UUID)
RETURNS VOID AS $$
DECLARE
  s seat_reservations;
BEGIN
  SELECT * INTO s FROM seat_reservations WHERE id = p_reservation_id AND passenger_id = auth.uid();
  IF s.id IS NULL OR s.status <> 'reserved' THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  PERFORM 1 FROM colectivo_departures WHERE id = s.departure_id FOR UPDATE;
  UPDATE seat_reservations SET status = 'cancelled' WHERE id = s.id;
  UPDATE colectivo_departures
  SET seats_taken = seats_taken - s.seats,
      status = CASE WHEN status = 'full' THEN 'open' ELSE status END
  WHERE id = s.departure_id AND status IN ('open', 'full');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Viaje encadenado ─────────────────────────────────────────────────────────
-- Nota: 001 creó una tabla `trips` vieja (sin uso); por eso estas se llaman
-- chained_trips / trip_legs.
CREATE TABLE IF NOT EXISTS chained_trips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  origin_label  TEXT CHECK (char_length(origin_label) <= 120),
  dest_label    TEXT CHECK (char_length(dest_label) <= 120),
  status        TEXT NOT NULL DEFAULT 'planned'
                CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
  idempotency_key UUID NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (passenger_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS trip_legs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id      UUID NOT NULL REFERENCES chained_trips(id) ON DELETE CASCADE,
  seq          SMALLINT NOT NULL CHECK (seq >= 0),
  mode         TEXT NOT NULL CHECK (mode IN
                 ('walk', 'mototaxi', 'taxi', 'colectivo', 'transpadilla', 'intermunicipal')),
  from_label   TEXT, to_label TEXT,
  -- Puntos del grafo (014) cuando el tramo sale de un paradero/terminal.
  from_node    TEXT REFERENCES graph_nodes(id) ON DELETE SET NULL,
  to_node      TEXT REFERENCES graph_nodes(id) ON DELETE SET NULL,
  from_lat DOUBLE PRECISION, from_lng DOUBLE PRECISION,
  to_lat   DOUBLE PRECISION, to_lng   DOUBLE PRECISION,
  minutes      INTEGER,
  fare_min     INTEGER NOT NULL DEFAULT 0,
  fare_max     INTEGER NOT NULL DEFAULT 0,
  agreed_fare  INTEGER,
  status       TEXT NOT NULL DEFAULT 'planned'
               CHECK (status IN ('planned', 'awaiting_dispatch', 'in_progress', 'completed', 'failed', 'cancelled')),
  driver_id    UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  started_at   TIMESTAMPTZ,
  ended_at     TIMESTAMPTZ,
  UNIQUE (trip_id, seq)
);

ALTER TABLE chained_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_legs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chained_trips_own ON chained_trips;
CREATE POLICY chained_trips_own ON chained_trips
  FOR SELECT USING (passenger_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS trip_legs_own ON trip_legs;
CREATE POLICY trip_legs_own ON trip_legs
  FOR SELECT USING (is_admin() OR driver_id = auth.uid() OR EXISTS (
    SELECT 1 FROM chained_trips t WHERE t.id = trip_id AND t.passenger_id = auth.uid()));
REVOKE ALL ON chained_trips, trip_legs FROM anon;
REVOKE INSERT, UPDATE, DELETE ON chained_trips, trip_legs FROM authenticated;
GRANT SELECT ON chained_trips, trip_legs TO authenticated;

-- Crea el viaje con sus tramos (del planificador del celular).
-- p_legs: [{mode, from_label, to_label, from_node?, to_node?, from_lat, from_lng, to_lat, to_lng,
--           minutes, fare_min, fare_max}]
CREATE OR REPLACE FUNCTION create_trip(
  p_origin TEXT, p_dest TEXT, p_legs JSONB, p_idempotency_key UUID)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  l JSONB;
  i INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT id INTO v_id FROM chained_trips
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  IF jsonb_typeof(p_legs) <> 'array' OR jsonb_array_length(p_legs) NOT BETWEEN 1 AND 8 THEN
    RAISE EXCEPTION 'invalid_legs' USING ERRCODE = '22023';
  END IF;
  -- Un viaje en curso a la vez: los planeados anteriores se cancelan.
  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE passenger_id = auth.uid() AND status = 'planned';
  IF EXISTS (SELECT 1 FROM chained_trips WHERE passenger_id = auth.uid() AND status = 'in_progress') THEN
    RAISE EXCEPTION 'trip_in_progress' USING ERRCODE = '55000';
  END IF;

  INSERT INTO chained_trips (passenger_id, origin_label, dest_label, idempotency_key)
  VALUES (auth.uid(), left(p_origin, 120), left(p_dest, 120), p_idempotency_key)
  RETURNING id INTO v_id;
  FOR l IN SELECT * FROM jsonb_array_elements(p_legs) LOOP
    INSERT INTO trip_legs (trip_id, seq, mode, from_label, to_label, from_node, to_node,
                           from_lat, from_lng, to_lat, to_lng, minutes, fare_min, fare_max)
    VALUES (v_id, i, l->>'mode', left(l->>'from_label', 120), left(l->>'to_label', 120),
            (SELECT id FROM graph_nodes WHERE id = l->>'from_node'),
            (SELECT id FROM graph_nodes WHERE id = l->>'to_node'),
            (l->>'from_lat')::float8, (l->>'from_lng')::float8,
            (l->>'to_lat')::float8, (l->>'to_lng')::float8,
            (l->>'minutes')::int, coalesce((l->>'fare_min')::int, 0), coalesce((l->>'fare_max')::int, 0));
    i := i + 1;
  END LOOP;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Máquina de estados de un tramo. El estado del viaje se deriva:
--   algún tramo en curso o esperando → in_progress; todos terminados → completed.
--   Un tramo 'failed' deja el viaje en curso: la app replanea desde ahí.
CREATE OR REPLACE FUNCTION trip_leg_transition(p_leg_id UUID, p_to TEXT, p_agreed_fare INTEGER DEFAULT NULL)
RETURNS trip_legs AS $$
DECLARE
  l trip_legs;
  t chained_trips;
  v_trip_status TEXT;
BEGIN
  SELECT * INTO l FROM trip_legs WHERE id = p_leg_id FOR UPDATE;
  IF l.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO t FROM chained_trips WHERE id = l.trip_id FOR UPDATE;
  IF t.passenger_id <> auth.uid() THEN RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501'; END IF;
  IF t.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'trip_closed' USING ERRCODE = '55000';
  END IF;
  IF NOT (
       (l.status = 'planned'           AND p_to IN ('awaiting_dispatch', 'in_progress', 'cancelled'))
    OR (l.status = 'awaiting_dispatch' AND p_to IN ('in_progress', 'failed', 'cancelled'))
    OR (l.status = 'in_progress'       AND p_to IN ('completed', 'failed'))
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '55000';
  END IF;
  -- Los tramos van en orden: no se empieza uno con anteriores sin cerrar.
  IF p_to IN ('awaiting_dispatch', 'in_progress') AND EXISTS (
       SELECT 1 FROM trip_legs WHERE trip_id = l.trip_id AND seq < l.seq
         AND status IN ('planned', 'awaiting_dispatch', 'in_progress')) THEN
    RAISE EXCEPTION 'previous_leg_open' USING ERRCODE = '55000';
  END IF;

  UPDATE trip_legs
  SET status = p_to,
      agreed_fare = coalesce(p_agreed_fare, agreed_fare),
      started_at = CASE WHEN p_to = 'in_progress' THEN now() ELSE started_at END,
      ended_at = CASE WHEN p_to IN ('completed', 'failed', 'cancelled') THEN now() ELSE ended_at END
  WHERE id = p_leg_id RETURNING * INTO l;

  SELECT CASE
    WHEN bool_and(status IN ('completed', 'cancelled')) AND bool_or(status = 'completed') THEN 'completed'
    WHEN bool_and(status = 'cancelled') THEN 'cancelled'
    WHEN bool_or(status IN ('awaiting_dispatch', 'in_progress', 'completed', 'failed')) THEN 'in_progress'
    ELSE 'planned' END
  INTO v_trip_status FROM trip_legs WHERE trip_id = l.trip_id;
  UPDATE chained_trips SET status = v_trip_status, updated_at = now() WHERE id = l.trip_id;
  RETURN l;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cancel_trip(p_trip_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE chained_trips SET status = 'cancelled', updated_at = now()
  WHERE id = p_trip_id AND passenger_id = auth.uid() AND status IN ('planned', 'in_progress');
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  UPDATE trip_legs SET status = 'cancelled', ended_at = now()
  WHERE trip_id = p_trip_id AND status IN ('planned', 'awaiting_dispatch');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Permisos de las RPCs ─────────────────────────────────────────────────────
DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'driver_ping(double precision,double precision)',
    'request_ride(text,double precision,double precision,text,double precision,double precision,text,integer,uuid,uuid)',
    'nearby_requests(double precision,double precision,double precision)',
    'accept_ride(uuid)', 'counter_offer(uuid,integer)', 'accept_offer(uuid)',
    'ride_transition(uuid,text)', 'ride_driver_view(uuid)',
    'publish_departure(text,text,timestamp with time zone,smallint,integer)',
    'reserve_seat(uuid,smallint,uuid,uuid)', 'cancel_reservation(uuid)',
    'create_trip(text,text,jsonb,uuid)', 'trip_leg_transition(uuid,text,integer)',
    'cancel_trip(uuid)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/016_payments.sql =====================
-- 016_payments.sql
-- Fase 7 · Pago por tramo + recibo único (D5).
--
--   Cada tramo se paga al cerrarse: con saldo (billetera → billetera del
--   conductor), por QR (el conductor genera un cobro, el pasajero lo paga) o
--   en efectivo (el conductor confirma que lo recibió). El viaje entrega UN
--   recibo con el desglose. No hay retención de dinero de terceros.
--
--   charges          cobro creado por el conductor (lo que va en el QR)
--   leg_payments     cada pago, idempotente
--   wallet_topups    recargas por Wompi (sandbox); las acredita solo el webhook
--
-- Bloqueo de billeteras siempre en el mismo orden (por id) para no trabarse.
-- Seguro de re-ejecutar.

-- La billetera ahora también recibe ganancias del conductor.
ALTER TABLE wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE wallet_transactions ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type IN ('recharge', 'trip', 'refund', 'bonus', 'earning'));

-- ── Cobros (QR del conductor) ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS charges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id   UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  amount      INTEGER NOT NULL CHECK (amount BETWEEN 500 AND 500000),
  ride_request_id UUID REFERENCES ride_requests(id) ON DELETE SET NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid', 'cancelled', 'expired')),
  paid_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + interval '15 minutes'
);
ALTER TABLE charges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS charges_parties ON charges;
CREATE POLICY charges_parties ON charges
  FOR SELECT USING (driver_id = auth.uid() OR paid_by = auth.uid() OR is_admin());
REVOKE ALL ON charges FROM anon;
REVOKE INSERT, UPDATE, DELETE ON charges FROM authenticated;
GRANT SELECT ON charges TO authenticated;

-- ── Pagos ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leg_payments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id        UUID REFERENCES drivers(user_id) ON DELETE SET NULL,
  amount           INTEGER NOT NULL CHECK (amount > 0),
  method           TEXT NOT NULL CHECK (method IN ('wallet', 'qr', 'cash')),
  status           TEXT NOT NULL CHECK (status IN ('paid', 'cash_pending', 'cash_confirmed', 'refunded')),
  ride_request_id  UUID REFERENCES ride_requests(id) ON DELETE SET NULL,
  charge_id        UUID REFERENCES charges(id) ON DELETE SET NULL,
  trip_leg_id      UUID REFERENCES trip_legs(id) ON DELETE SET NULL,
  idempotency_key  UUID NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at     TIMESTAMPTZ,
  UNIQUE (passenger_id, idempotency_key)
);
-- Un viaje de mototaxi se paga una sola vez.
CREATE UNIQUE INDEX IF NOT EXISTS leg_payments_ride_once
  ON leg_payments(ride_request_id) WHERE ride_request_id IS NOT NULL AND status <> 'refunded';

ALTER TABLE leg_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS leg_payments_parties ON leg_payments;
CREATE POLICY leg_payments_parties ON leg_payments
  FOR SELECT USING (passenger_id = auth.uid() OR driver_id = auth.uid() OR is_admin());
REVOKE ALL ON leg_payments FROM anon;
REVOKE INSERT, UPDATE, DELETE ON leg_payments FROM authenticated;
GRANT SELECT ON leg_payments TO authenticated;

-- Mueve saldo de una billetera a otra, bloqueando ambas en orden fijo.
-- Uso interno (no se expone al cliente).
CREATE OR REPLACE FUNCTION _wallet_transfer(
  p_from_user UUID, p_to_user UUID, p_amount INTEGER, p_desc TEXT, p_meta JSONB)
RETURNS VOID AS $$
DECLARE
  w_from wallets;
  w_to   wallets;
BEGIN
  PERFORM 1 FROM wallets WHERE user_id IN (p_from_user, p_to_user) ORDER BY id FOR UPDATE;
  SELECT * INTO w_from FROM wallets WHERE user_id = p_from_user;
  SELECT * INTO w_to   FROM wallets WHERE user_id = p_to_user;
  IF w_from.id IS NULL OR w_to.id IS NULL THEN
    RAISE EXCEPTION 'wallet_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF w_from.card_status <> 'active' THEN
    RAISE EXCEPTION 'wallet_blocked' USING ERRCODE = '55000';
  END IF;
  IF w_from.balance < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance' USING ERRCODE = '55000';
  END IF;
  UPDATE wallets SET balance = balance - p_amount, updated_at = now() WHERE id = w_from.id;
  UPDATE wallets SET balance = balance + p_amount, updated_at = now() WHERE id = w_to.id;
  INSERT INTO wallet_transactions (wallet_id, type, amount, description, metadata)
  VALUES (w_from.id, 'trip', -p_amount, p_desc, p_meta),
         (w_to.id, 'earning', p_amount, p_desc, p_meta);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _wallet_transfer(UUID, UUID, INTEGER, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- Marca el tramo del viaje encadenado con lo que se pagó.
CREATE OR REPLACE FUNCTION _note_leg_fare(p_leg UUID, p_amount INTEGER)
RETURNS VOID AS $$
  UPDATE trip_legs SET agreed_fare = p_amount WHERE id = p_leg;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON FUNCTION _note_leg_fare(UUID, INTEGER) FROM PUBLIC, anon, authenticated;

-- Pagar el viaje de mototaxi/taxi aceptado: con saldo o en efectivo.
CREATE OR REPLACE FUNCTION pay_ride(p_request_id UUID, p_method TEXT, p_idempotency_key UUID)
RETURNS leg_payments AS $$
DECLARE
  r ride_requests;
  p leg_payments;
BEGIN
  SELECT * INTO p FROM leg_payments
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF p.id IS NOT NULL THEN RETURN p; END IF;

  SELECT * INTO r FROM ride_requests WHERE id = p_request_id FOR UPDATE;
  IF r.id IS NULL OR r.passenger_id <> auth.uid() THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
  END IF;
  IF r.status NOT IN ('in_progress', 'completed') OR r.driver_id IS NULL THEN
    RAISE EXCEPTION 'not_payable' USING ERRCODE = '55000';
  END IF;
  IF EXISTS (SELECT 1 FROM leg_payments WHERE ride_request_id = r.id AND status <> 'refunded') THEN
    RAISE EXCEPTION 'already_paid' USING ERRCODE = '55000';
  END IF;
  IF p_method NOT IN ('wallet', 'cash') THEN
    RAISE EXCEPTION 'invalid_method' USING ERRCODE = '22023';
  END IF;

  IF p_method = 'wallet' THEN
    PERFORM _wallet_transfer(auth.uid(), r.driver_id, r.agreed_fare,
      'Viaje en ' || r.service, jsonb_build_object('ride_request_id', r.id));
  END IF;
  INSERT INTO leg_payments (passenger_id, driver_id, amount, method, status,
                            ride_request_id, trip_leg_id, idempotency_key)
  VALUES (auth.uid(), r.driver_id, r.agreed_fare, p_method,
          CASE WHEN p_method = 'cash' THEN 'cash_pending' ELSE 'paid' END,
          r.id, r.trip_leg_id, p_idempotency_key)
  RETURNING * INTO p;
  IF r.trip_leg_id IS NOT NULL THEN PERFORM _note_leg_fare(r.trip_leg_id, r.agreed_fare); END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- El conductor confirma que recibió el efectivo.
CREATE OR REPLACE FUNCTION confirm_cash(p_payment_id UUID)
RETURNS leg_payments AS $$
DECLARE
  p leg_payments;
BEGIN
  UPDATE leg_payments SET status = 'cash_confirmed', confirmed_at = now()
  WHERE id = p_payment_id AND driver_id = auth.uid() AND status = 'cash_pending'
  RETURNING * INTO p;
  IF p.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- QR: el conductor crea un cobro; el pasajero lo paga con su saldo.
CREATE OR REPLACE FUNCTION create_charge(p_amount INTEGER, p_ride_request_id UUID DEFAULT NULL)
RETURNS charges AS $$
DECLARE
  c charges;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM drivers WHERE user_id = auth.uid() AND status = 'approved') THEN
    RAISE EXCEPTION 'not_active_driver' USING ERRCODE = '42501';
  END IF;
  INSERT INTO charges (driver_id, amount, ride_request_id)
  VALUES (auth.uid(), p_amount, p_ride_request_id) RETURNING * INTO c;
  RETURN c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Lo que el pasajero ve al escanear: monto y a quién, antes de pagar.
CREATE OR REPLACE FUNCTION charge_preview(p_charge_id UUID)
RETURNS TABLE (amount INTEGER, driver_first_name TEXT, plate TEXT, status TEXT) AS $$
  SELECT c.amount, split_part(d.full_name, ' ', 1),
         (SELECT v.plate FROM vehicles v WHERE v.driver_id = d.user_id LIMIT 1),
         CASE WHEN c.status = 'open' AND c.expires_at <= now() THEN 'expired' ELSE c.status END
  FROM charges c JOIN drivers d ON d.user_id = c.driver_id
  WHERE c.id = p_charge_id
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION pay_charge(p_charge_id UUID, p_idempotency_key UUID,
                                      p_trip_leg_id UUID DEFAULT NULL)
RETURNS leg_payments AS $$
DECLARE
  c charges;
  p leg_payments;
  v_leg UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501'; END IF;
  SELECT * INTO p FROM leg_payments
  WHERE passenger_id = auth.uid() AND idempotency_key = p_idempotency_key;
  IF p.id IS NOT NULL THEN RETURN p; END IF;

  SELECT * INTO c FROM charges WHERE id = p_charge_id FOR UPDATE;
  IF c.id IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002'; END IF;
  IF c.driver_id = auth.uid() THEN RAISE EXCEPTION 'own_charge' USING ERRCODE = '42501'; END IF;
  IF c.status <> 'open' OR c.expires_at <= now() THEN
    RAISE EXCEPTION 'charge_closed' USING ERRCODE = '55000';
  END IF;
  -- Solo se liga a un tramo propio.
  SELECT l.id INTO v_leg FROM trip_legs l JOIN chained_trips t ON t.id = l.trip_id
  WHERE l.id = p_trip_leg_id AND t.passenger_id = auth.uid();

  PERFORM _wallet_transfer(auth.uid(), c.driver_id, c.amount, 'Pago con QR',
                           jsonb_build_object('charge_id', c.id));
  UPDATE charges SET status = 'paid', paid_by = auth.uid() WHERE id = c.id;
  INSERT INTO leg_payments (passenger_id, driver_id, amount, method, status, charge_id,
                            ride_request_id, trip_leg_id, idempotency_key)
  VALUES (auth.uid(), c.driver_id, c.amount, 'qr', 'paid', c.id,
          c.ride_request_id, v_leg, p_idempotency_key)
  RETURNING * INTO p;
  IF v_leg IS NOT NULL THEN PERFORM _note_leg_fare(v_leg, c.amount); END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── Recibo único del viaje (D5) ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trip_receipt(p_trip_id UUID)
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'trip_id', t.id,
    'origin', t.origin_label,
    'destination', t.dest_label,
    'status', t.status,
    'created_at', t.created_at,
    'legs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'seq', l.seq, 'mode', l.mode, 'from', l.from_label, 'to', l.to_label,
        'status', l.status,
        'paid', coalesce((SELECT sum(p.amount) FROM leg_payments p
                          WHERE p.trip_leg_id = l.id AND p.status IN ('paid', 'cash_confirmed', 'cash_pending')), 0),
        'methods', coalesce((SELECT jsonb_agg(DISTINCT p.method) FROM leg_payments p
                             WHERE p.trip_leg_id = l.id AND p.status <> 'refunded'), '[]'),
        'reference_min', l.fare_min, 'reference_max', l.fare_max
      ) ORDER BY l.seq) FROM trip_legs l WHERE l.trip_id = t.id), '[]'),
    'total_paid', coalesce((
      SELECT sum(p.amount) FROM leg_payments p JOIN trip_legs l ON l.id = p.trip_leg_id
      WHERE l.trip_id = t.id AND p.status IN ('paid', 'cash_confirmed', 'cash_pending')), 0)
  )
  FROM chained_trips t
  WHERE t.id = p_trip_id AND t.passenger_id = auth.uid()
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Recargas por Wompi (sandbox) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallet_topups (
  reference   TEXT PRIMARY KEY,                 -- la ponemos nosotros: gs_<uuid>
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount      INTEGER NOT NULL CHECK (amount BETWEEN 1000 AND 500000),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'error')),
  provider_id TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at  TIMESTAMPTZ
);
ALTER TABLE wallet_topups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallet_topups_own ON wallet_topups;
CREATE POLICY wallet_topups_own ON wallet_topups FOR SELECT USING (user_id = auth.uid());
REVOKE ALL ON wallet_topups FROM anon;
REVOKE INSERT, UPDATE, DELETE ON wallet_topups FROM authenticated;
GRANT SELECT ON wallet_topups TO authenticated;

-- Solo el servidor (Edge Function con service_role) crea y liquida recargas.
CREATE OR REPLACE FUNCTION wallet_topup_create(p_user UUID, p_amount INTEGER)
RETURNS TEXT AS $$
DECLARE
  v_ref TEXT := 'gs_' || replace(gen_random_uuid()::text, '-', '');
BEGIN
  INSERT INTO wallet_topups (reference, user_id, amount) VALUES (v_ref, p_user, p_amount);
  RETURN v_ref;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Idempotente: el webhook puede llegar varias veces; se acredita una sola.
CREATE OR REPLACE FUNCTION wallet_topup_settle(
  p_reference TEXT, p_status TEXT, p_amount INTEGER, p_provider_id TEXT)
RETURNS TEXT AS $$
DECLARE
  t wallet_topups;
  w wallets;
BEGIN
  SELECT * INTO t FROM wallet_topups WHERE reference = p_reference FOR UPDATE;
  IF t.reference IS NULL THEN RETURN 'unknown_reference'; END IF;
  IF t.status <> 'pending' THEN RETURN 'already_settled'; END IF;
  IF p_status = 'APPROVED' THEN
    IF p_amount <> t.amount THEN
      UPDATE wallet_topups SET status = 'error', provider_id = p_provider_id, settled_at = now()
      WHERE reference = p_reference;
      RETURN 'amount_mismatch';
    END IF;
    SELECT * INTO w FROM wallets WHERE user_id = t.user_id FOR UPDATE;
    UPDATE wallets SET balance = balance + t.amount, updated_at = now() WHERE id = w.id;
    INSERT INTO wallet_transactions (wallet_id, type, amount, description, metadata)
    VALUES (w.id, 'recharge', t.amount, 'Recarga con Wompi',
            jsonb_build_object('reference', t.reference, 'provider_id', p_provider_id));
    UPDATE wallet_topups SET status = 'approved', provider_id = p_provider_id, settled_at = now()
    WHERE reference = p_reference;
    RETURN 'approved';
  END IF;
  UPDATE wallet_topups
  SET status = CASE WHEN p_status IN ('DECLINED', 'VOIDED') THEN 'declined' ELSE 'error' END,
      provider_id = p_provider_id, settled_at = now()
  WHERE reference = p_reference;
  RETURN 'declined';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION wallet_topup_create(UUID, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION wallet_topup_settle(TEXT, TEXT, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION wallet_topup_create(UUID, INTEGER) TO service_role;
GRANT  EXECUTE ON FUNCTION wallet_topup_settle(TEXT, TEXT, INTEGER, TEXT) TO service_role;

INSERT INTO app_flags (key, enabled) VALUES ('wompi_enabled', false) ON CONFLICT (key) DO NOTHING;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'pay_ride(uuid,text,uuid)', 'confirm_cash(uuid)',
    'create_charge(integer,uuid)', 'charge_preview(uuid)',
    'pay_charge(uuid,uuid,uuid)', 'trip_receipt(uuid)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/017_trust_admin.sql =====================
-- 017_trust_admin.sql
-- Fase 8 · Confianza + panel admin.
--
--   ride_ratings        calificación en las dos direcciones (1–5 y etiquetas cerradas)
--   Impago: con 2 viajes confirmados sin pagar (el conductor marcó 'no_pago' y no
--   hay pago registrado), el pasajero no puede pedir más viajes.
--   Admin: quitar reportes, ver documentos, métricas para Instramd y la Alcaldía.
-- Seguro de re-ejecutar.

CREATE TABLE IF NOT EXISTS ride_ratings (
  request_id  UUID NOT NULL REFERENCES ride_requests(id) ON DELETE CASCADE,
  rater_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ratee_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars       SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
  -- Etiquetas cerradas: sin texto libre (nadie escribe insultos ni datos).
  tags        TEXT[] NOT NULL DEFAULT '{}' CHECK (tags <@ ARRAY[
                'puntual', 'amable', 'manejo_seguro', 'vehiculo_limpio',
                'no_llego', 'cobro_de_mas', 'manejo_peligroso', 'no_pago', 'grosero']::text[]),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (request_id, rater_id)
);
ALTER TABLE ride_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ride_ratings_own ON ride_ratings;
CREATE POLICY ride_ratings_own ON ride_ratings
  FOR SELECT USING (rater_id = auth.uid() OR is_admin());
REVOKE ALL ON ride_ratings FROM anon;
REVOKE INSERT, UPDATE, DELETE ON ride_ratings FROM authenticated;
GRANT SELECT ON ride_ratings TO authenticated;

CREATE OR REPLACE FUNCTION rate_ride(p_request_id UUID, p_stars SMALLINT, p_tags TEXT[] DEFAULT '{}')
RETURNS VOID AS $$
DECLARE
  r ride_requests;
  v_ratee UUID;
BEGIN
  SELECT * INTO r FROM ride_requests WHERE id = p_request_id;
  IF r.id IS NULL OR r.status <> 'completed' THEN
    RAISE EXCEPTION 'not_rateable' USING ERRCODE = '55000';
  END IF;
  IF auth.uid() = r.passenger_id THEN v_ratee := r.driver_id;
  ELSIF auth.uid() = r.driver_id THEN v_ratee := r.passenger_id;
  ELSE RAISE EXCEPTION 'not_yours' USING ERRCODE = '42501';
  END IF;
  -- 'no_pago' solo lo marca el conductor; 'no_llego' solo el pasajero.
  IF auth.uid() = r.passenger_id AND 'no_pago' = ANY(p_tags) THEN
    RAISE EXCEPTION 'invalid_tag' USING ERRCODE = '22023';
  END IF;
  IF auth.uid() = r.driver_id AND 'no_llego' = ANY(p_tags) THEN
    RAISE EXCEPTION 'invalid_tag' USING ERRCODE = '22023';
  END IF;
  IF r.finished_at < now() - interval '7 days' THEN
    RAISE EXCEPTION 'too_late' USING ERRCODE = '55000';
  END IF;
  INSERT INTO ride_ratings (request_id, rater_id, ratee_id, stars, tags)
  VALUES (p_request_id, auth.uid(), v_ratee, p_stars, coalesce(p_tags, '{}'))
  ON CONFLICT (request_id, rater_id) DO UPDATE
    SET stars = EXCLUDED.stars, tags = EXCLUDED.tags, created_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Promedio y cantidad de calificaciones recibidas (solo con 3 o más se muestra).
CREATE OR REPLACE FUNCTION user_rating(p_user UUID)
RETURNS TABLE (avg_stars NUMERIC, total INTEGER) AS $$
  SELECT CASE WHEN count(*) >= 3 THEN round(avg(stars)::numeric, 1) END, count(*)::int
  FROM ride_ratings WHERE ratee_id = p_user
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Viajes que el conductor marcó 'no_pago' y de verdad no tienen pago.
CREATE OR REPLACE FUNCTION unpaid_rides(p_user UUID)
RETURNS INTEGER AS $$
  SELECT count(DISTINCT rr.id)::int
  FROM ride_ratings rt
  JOIN ride_requests rr ON rr.id = rt.request_id
  WHERE rr.passenger_id = p_user
    AND rt.rater_id = rr.driver_id
    AND 'no_pago' = ANY(rt.tags)
    AND NOT EXISTS (SELECT 1 FROM leg_payments p
                    WHERE p.ride_request_id = rr.id AND p.status IN ('paid', 'cash_confirmed'))
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION ride_requests_block_unpaid()
RETURNS TRIGGER AS $$
BEGIN
  IF unpaid_rides(NEW.passenger_id) >= 2 THEN
    RAISE EXCEPTION 'blocked_unpaid' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS ride_requests_block_unpaid ON ride_requests;
CREATE TRIGGER ride_requests_block_unpaid
  BEFORE INSERT ON ride_requests
  FOR EACH ROW EXECUTE FUNCTION ride_requests_block_unpaid();

-- La vista del conductor para el pasajero ahora trae su calificación.
DROP FUNCTION IF EXISTS ride_driver_view(UUID);
CREATE FUNCTION ride_driver_view(p_request_id UUID)
RETURNS TABLE (first_name TEXT, service TEXT, plate TEXT, vehicle TEXT,
               lat DOUBLE PRECISION, lng DOUBLE PRECISION, seen_at TIMESTAMPTZ,
               rating NUMERIC, ratings INTEGER) AS $$
  SELECT split_part(d.full_name, ' ', 1), d.service, v.plate,
         trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')),
         l.lat, l.lng, l.updated_at, ur.avg_stars, ur.total
  FROM ride_requests r
  JOIN drivers d ON d.user_id = r.driver_id
  LEFT JOIN vehicles v ON v.driver_id = d.user_id
  LEFT JOIN driver_locations l ON l.driver_id = d.user_id
  LEFT JOIN LATERAL user_rating(d.user_id) ur ON true
  WHERE r.id = p_request_id AND r.passenger_id = auth.uid()
    AND r.status IN ('accepted', 'in_progress')
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ── Admin ────────────────────────────────────────────────────────────────────
-- Conductores por revisar, con lo que hace falta para decidir.
CREATE OR REPLACE FUNCTION admin_driver_queue()
RETURNS TABLE (user_id UUID, full_name TEXT, cedula TEXT, phone TEXT, service TEXT,
               zone TEXT, status TEXT, plate TEXT, documents TEXT[], created_at TIMESTAMPTZ) AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT d.user_id, d.full_name, d.cedula, d.phone, d.service, d.zone, d.status,
         (SELECT v.plate FROM vehicles v WHERE v.driver_id = d.user_id LIMIT 1),
         coalesce((SELECT array_agg(dd.kind ORDER BY dd.kind) FROM driver_documents dd
                   WHERE dd.driver_id = d.user_id), '{}'),
         d.created_at
  FROM drivers d
  ORDER BY (d.status = 'pending') DESC, d.created_at;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Moderar: quitar un reporte vial (falso, o que señala a alguien).
CREATE OR REPLACE FUNCTION admin_remove_report(p_report_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  UPDATE road_reports SET removed_at = now() WHERE id = p_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_recent_reports(p_hours INTEGER DEFAULT 48)
RETURNS TABLE (id UUID, segment_id TEXT, kind TEXT, happened_at TIMESTAMPTZ,
               expires_at TIMESTAMPTZ, removed BOOLEAN, confirmations INTEGER, denials INTEGER) AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.segment_id, r.kind, r.happened_at, r.expires_at, r.removed_at IS NOT NULL,
         (SELECT count(*)::int FROM road_report_votes v WHERE v.report_id = r.id AND v.still_there),
         (SELECT count(*)::int FROM road_report_votes v WHERE v.report_id = r.id AND NOT v.still_there)
  FROM road_reports r
  WHERE r.created_at > now() - make_interval(hours => least(greatest(p_hours, 1), 720))
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Métricas del piloto (sin datos personales): para Instramd y la Alcaldía.
CREATE OR REPLACE FUNCTION admin_metrics(p_days INTEGER DEFAULT 7)
RETURNS JSONB AS $$
DECLARE
  v_since TIMESTAMPTZ := now() - make_interval(days => least(greatest(p_days, 1), 365));
  v JSONB;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin_only' USING ERRCODE = '42501'; END IF;
  SELECT jsonb_build_object(
    'days', p_days,
    'reports', (SELECT count(*) FROM road_reports WHERE created_at > v_since),
    'reports_confirmed', (SELECT count(DISTINCT r.id) FROM road_reports r
                          JOIN road_report_votes v ON v.report_id = r.id AND v.still_there
                          WHERE r.created_at > v_since),
    'reports_removed', (SELECT count(*) FROM road_reports WHERE created_at > v_since AND removed_at IS NOT NULL),
    -- Minutos medianos entre el reporte y su primera confirmación.
    'minutes_to_confirm', (SELECT round(percentile_cont(0.5) WITHIN GROUP (
                              ORDER BY extract(epoch FROM fv.first_at - r.created_at) / 60)::numeric, 1)
                           FROM road_reports r
                           JOIN LATERAL (SELECT min(v.created_at) AS first_at FROM road_report_votes v
                                         WHERE v.report_id = r.id AND v.still_there) fv ON fv.first_at IS NOT NULL
                           WHERE r.created_at > v_since),
    'rides_requested', (SELECT count(*) FROM ride_requests WHERE created_at > v_since),
    'rides_accepted', (SELECT count(*) FROM ride_requests WHERE created_at > v_since AND accepted_at IS NOT NULL),
    'rides_completed', (SELECT count(*) FROM ride_requests WHERE created_at > v_since AND status = 'completed'),
    'median_seconds_to_accept', (SELECT round(percentile_cont(0.5) WITHIN GROUP (
                                   ORDER BY extract(epoch FROM accepted_at - created_at))::numeric)
                                 FROM ride_requests WHERE created_at > v_since AND accepted_at IS NOT NULL),
    'seats_reserved', (SELECT coalesce(sum(seats), 0) FROM seat_reservations
                       WHERE created_at > v_since AND status <> 'cancelled'),
    'payments_cop', (SELECT coalesce(sum(amount), 0) FROM leg_payments
                     WHERE created_at > v_since AND status IN ('paid', 'cash_confirmed')),
    'sos_events', (SELECT count(*) FROM sos_events WHERE created_at > v_since),
    'drivers_approved', (SELECT count(*) FROM drivers WHERE status = 'approved'),
    'drivers_pending', (SELECT count(*) FROM drivers WHERE status = 'pending'),
    'trips_completed', (SELECT count(*) FROM chained_trips WHERE created_at > v_since AND status = 'completed')
  ) INTO v;
  RETURN v;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'rate_ride(uuid,smallint,text[])', 'user_rating(uuid)', 'ride_driver_view(uuid)',
    'admin_driver_queue()', 'admin_remove_report(uuid)', 'admin_recent_reports(integer)',
    'admin_metrics(integer)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION unpaid_rides(UUID) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/migrations/018_push.sql =====================
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


-- ===================== supabase/migrations/019_signup_fix.sql =====================
-- 019_signup_fix.sql
-- Arreglo: al crear un usuario, Supabase Auth corre los triggers de auth.users
-- con su propio rol (supabase_auth_admin) y search_path "auth". El trigger de
-- la billetera (008) no era SECURITY DEFINER ni fijaba el search_path, así que
-- no encontraba public.wallets y el alta fallaba con "Database error creating
-- new user". Ahora corre como dueño, con nombres calificados.
-- Seguro de re-ejecutar.

CREATE OR REPLACE FUNCTION public.generate_gosmart_card_number()
RETURNS TEXT AS $$
BEGIN
  RETURN 'GS-' ||
    lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
    lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
    lpad(floor(random() * 10000)::text, 4, '0');
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id, card_number, balance)
  VALUES (NEW.id, public.generate_gosmart_card_number(), 10000)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.create_wallet_for_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_wallet_create ON auth.users;
CREATE TRIGGER on_auth_user_wallet_create
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_wallet_for_new_user();


-- ===================== supabase/migrations/020_fares.sql =====================
-- 020_fares.sql
-- Precio único por tramo (en vez de un rango).
-- Taxi: tarifa oficial de Riohacha, Instramd Resolución 0922 de 2025:
--   $6.300 el primer km y $1.300 por km adicional o fracción; recargo nocturno.
-- Mototaxi: informal, sin tarifa oficial: tarifa SUGERIDA (el pasajero puede
--   ofrecer otra al pedir). Colectivo e intermunicipal: el pasaje de la ruta.
-- Seguro de re-ejecutar.

ALTER TABLE fare_rules ADD COLUMN IF NOT EXISTS included_km NUMERIC(4,1) NOT NULL DEFAULT 0;
ALTER TABLE fare_rules ADD COLUMN IF NOT EXISTS round_to INTEGER NOT NULL DEFAULT 500;

INSERT INTO fare_rules (mode, base, per_km, included_km, minimum, night_factor, round_to, verified)
VALUES ('taxi', 6300, 1300, 1, 6300, 1.15, 100, true),
       ('mototaxi', 3000, 500, 2, 3000, 1.20, 500, false)
ON CONFLICT (mode) DO UPDATE SET
  base = EXCLUDED.base, per_km = EXCLUDED.per_km, included_km = EXCLUDED.included_km,
  minimum = EXCLUDED.minimum, night_factor = EXCLUDED.night_factor,
  round_to = EXCLUDED.round_to, verified = EXCLUDED.verified, updated_at = now();

-- Pasajes de ruta: un solo valor (el que se cobra hoy, aproximado).
UPDATE graph_edges SET fare_min = fare_max WHERE fare_min <> fare_max;

NOTIFY pgrst, 'reload schema';


-- ===================== supabase/seed/places_seed.sql =====================
-- supabase/seed/places_seed.sql
-- Semilla mínima del directorio para probar el buscador antes del
-- levantamiento de campo (Fase 1). TODAS las coordenadas son aproximadas
-- (source='semilla', verified=false) y la app las muestra como "aprox.".
-- Reemplazar con datos de campo; no usar como verdad.
INSERT INTO places (name, aliases, city, kind, lat, lng, source, verified) VALUES
  ('Muelle Turístico de Riohacha', '{el muelle,muelle}', 'riohacha', 'turismo', 11.5449, -72.9075, 'semilla', false),
  ('Parque Almirante Padilla', '{parque padilla,la plaza}', 'riohacha', 'referencia', 11.5441, -72.9071, 'semilla', false),
  ('Catedral Nuestra Señora de los Remedios', '{la catedral}', 'riohacha', 'referencia', 11.5443, -72.9066, 'semilla', false),
  ('Malecón de Riohacha', '{la playa,el malecon,la primera}', 'riohacha', 'turismo', 11.5452, -72.9040, 'semilla', false),
  ('Aeropuerto Almirante Padilla', '{aeropuerto}', 'riohacha', 'terminal', 11.5262, -72.9260, 'semilla', false),
  ('Terminal de Transportes de Riohacha', '{la terminal,terminal}', 'riohacha', 'terminal', 11.5330, -72.9125, 'semilla', false),
  ('Universidad de La Guajira', '{uniguajira,la universidad}', 'riohacha', 'educacion', 11.5275, -72.8880, 'semilla', false),
  ('Parque Central de Maicao', '{el parque,la plaza}', 'maicao', 'referencia', 11.3780, -72.2405, 'semilla', false),
  ('Mezquita Omar Ibn Al-Khattab', '{la mezquita}', 'maicao', 'referencia', 11.3825, -72.2420, 'semilla', false),
  ('Terminal de Maicao', '{la terminal,terminal}', 'maicao', 'terminal', 11.3790, -72.2370, 'semilla', false),
  ('Cuatro Vías', '{cuatro vias,las cuatro vias}', 'corredor', 'via', 11.3270, -72.5550, 'semilla', false),
  ('Cuestecitas', '{}', 'corredor', 'via', 11.2050, -72.6160, 'semilla', false)
ON CONFLICT (city, name) DO NOTHING;

NOTIFY pgrst, 'reload schema';
