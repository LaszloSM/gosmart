-- backend/migrations/006_colombia_kg.sql
-- GoSmart RAG Colombia — Knowledge Graph tables
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Requires: pgvector available on all Supabase plans (2024+)
-- Run AFTER migrations 001-005

-- ── Extensión ─────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── Entidades canónicas ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name  TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN (
                    'station','stop','terminal','neighborhood',
                    'locality','municipality','department',
                    'street','landmark','poi')),
  city            TEXT,
  department      TEXT,
  lat             DOUBLE PRECISION,
  lon             DOUBLE PRECISION,
  embed_text      TEXT NOT NULL,
  metadata        JSONB DEFAULT '{}',
  source          TEXT CHECK (source IN ('osm','dane','manual')),
  canonical_score SMALLINT DEFAULT 100,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kg_city ON colombia_kg(city);
CREATE INDEX IF NOT EXISTS idx_kg_type ON colombia_kg(type);

-- ── Aliases ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg_aliases (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE,
  alias       TEXT NOT NULL,
  alias_type  TEXT NOT NULL CHECK (alias_type IN (
                'abbreviation','popular','official','typo')),
  UNIQUE (entity_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_aliases_fts ON colombia_kg_aliases
  USING gin(to_tsvector('spanish', alias));

-- ── Embeddings ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg_embeddings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE UNIQUE,
  embedding   vector(1536),
  created_at  TIMESTAMPTZ DEFAULT now()
);
-- IMPORTANT: Do NOT create HNSW index here.
-- Create it AFTER bulk load via load_supabase.py to avoid degraded index.

-- ── RLS — tablas de solo lectura pública ──────────────────────────────────────
ALTER TABLE colombia_kg            ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_aliases    ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read" ON colombia_kg            FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_aliases    FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_embeddings FOR SELECT USING (true);

-- ── Fallback log — solo escritura interna ────────────────────────────────────
CREATE TABLE IF NOT EXISTS rag_fallback_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_original   TEXT NOT NULL,
  query_normalized TEXT,
  city_detected    TEXT,
  top_similarity   FLOAT,
  fallback_reason  TEXT CHECK (fallback_reason IN (
                     'no_match','low_similarity','city_unknown','timeout')),
  created_at       TIMESTAMPTZ DEFAULT now()
);
-- anon no puede leer ni escribir — solo service role desde Edge Function
ALTER TABLE rag_fallback_log ENABLE ROW LEVEL SECURITY;

-- ── RPC de retrieval semántico ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION match_colombia_kg(
  query_embedding      vector(1536),
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

-- Permitir que anon key (Edge Function) ejecute la RPC
GRANT EXECUTE ON FUNCTION match_colombia_kg(vector, int, text, text[], float) TO anon;

-- Helper para crear índice HNSW desde Python (supabase-py no puede ejecutar DDL directo)
-- Llamado por load_supabase.py después del bulk load
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
