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
