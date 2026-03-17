-- backend/migrations/007_fix_embedding_dim.sql
-- Cambia la dimension de embeddings de 1536 (OpenAI) a 384 (sentence-transformers local).
-- Ejecutar en Supabase SQL Editor ANTES de correr load_supabase.py.

-- 1. Eliminar indice HNSW si existe (no puede quedar con dimension incorrecta)
DROP INDEX IF EXISTS idx_embeddings_hnsw;

-- 2. Cambiar columna al nuevo tamano
ALTER TABLE colombia_kg_embeddings DROP COLUMN IF EXISTS embedding;
ALTER TABLE colombia_kg_embeddings ADD COLUMN embedding vector(384);

-- 3. Recrear funcion RPC con vector(384)
DROP FUNCTION IF EXISTS match_colombia_kg(vector, int, text, text[], float);

CREATE OR REPLACE FUNCTION match_colombia_kg(
  query_embedding      vector(384),
  match_count          INT     DEFAULT 5,
  city_filter          TEXT    DEFAULT NULL,
  type_filter          TEXT[]  DEFAULT NULL,
  similarity_threshold FLOAT   DEFAULT 0.65
)
RETURNS TABLE (
  id             UUID,
  canonical_name TEXT,
  type           TEXT,
  city           TEXT,
  department     TEXT,
  lat            DOUBLE PRECISION,
  lon            DOUBLE PRECISION,
  embed_text     TEXT,
  metadata       JSONB,
  similarity     FLOAT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    k.id, k.canonical_name, k.type, k.city, k.department,
    k.lat, k.lon, k.embed_text, k.metadata,
    1 - (e.embedding <=> query_embedding) AS similarity
  FROM colombia_kg_embeddings e
  JOIN colombia_kg k ON k.id = e.entity_id
  WHERE
    (city_filter IS NULL OR LOWER(k.city) = LOWER(city_filter))
    AND (type_filter IS NULL OR k.type = ANY(type_filter))
    AND (1 - (e.embedding <=> query_embedding)) >= similarity_threshold
  ORDER BY e.embedding <=> query_embedding
  LIMIT LEAST(match_count, 20);
END;
$$;

GRANT EXECUTE ON FUNCTION match_colombia_kg(vector, int, text, text[], float) TO anon;

-- 4. Recrear helper create_hnsw_index (la sintaxis HNSW es dimension-agnostica)
CREATE OR REPLACE FUNCTION create_hnsw_index() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_embeddings_hnsw
    ON colombia_kg_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)';
END;
$$;
GRANT EXECUTE ON FUNCTION create_hnsw_index() TO service_role;

NOTIFY pgrst, 'reload schema';
