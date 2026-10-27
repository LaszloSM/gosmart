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
