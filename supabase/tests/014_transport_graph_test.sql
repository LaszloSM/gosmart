-- supabase/tests/014_transport_graph_test.sql
\set ON_ERROR_STOP on
SET ROLE anon;
DO $$
DECLARE s JSONB; n INT; segs TEXT[];
BEGIN
  s := graph_snapshot();
  IF jsonb_array_length(s->'nodes') <> 7 THEN RAISE EXCEPTION '1: nodos %', jsonb_array_length(s->'nodes'); END IF;
  IF jsonb_array_length(s->'edges') <> 16 THEN RAISE EXCEPTION '1: aristas %', jsonb_array_length(s->'edges'); END IF;
  -- El regreso Maicao → Riohacha recorre la Troncal al revés
  SELECT segment_ids INTO segs FROM graph_edges
  WHERE from_node = 'mai-terminal' AND to_node = 'rio-terminal';
  IF segs[1] <> 'troncal-60-75' THEN RAISE EXCEPTION '2: regreso empieza en %', segs[1]; END IF;
  -- Toda arista de la Troncal apunta a tramos que existen
  SELECT count(*) INTO n FROM graph_edges e, unnest(e.segment_ids) sid
  WHERE NOT EXISTS (SELECT 1 FROM road_segments r WHERE r.id = sid);
  IF n <> 0 THEN RAISE EXCEPTION '3: % tramos inexistentes', n; END IF;
  BEGIN
    INSERT INTO graph_nodes (id, name, lat, lng) VALUES ('x', 'x', 11.5, -72.9);
    RAISE EXCEPTION '4: un invitado escribió en el grafo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;
\echo '014_transport_graph_test: OK'
