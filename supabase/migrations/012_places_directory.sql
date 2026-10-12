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
