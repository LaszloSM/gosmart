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
