#!/usr/bin/env bash
# Junta las migraciones 008–023 y la semilla de lugares en un solo archivo
# para pegarlo de una vez en el SQL Editor de Supabase (todas son re-ejecutables).
# Uso: tool/bundle_migrations.sh > supabase/piloto_bundle.sql
set -euo pipefail
cd "$(dirname "$0")/.."
echo "-- GoSmart · migraciones 008–023 + semilla de lugares (generado por tool/bundle_migrations.sh)"
echo "-- Requiere 001–007 aplicadas antes. Seguro de correr más de una vez."
for f in supabase/migrations/0{08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23}_*.sql supabase/seed/places_seed.sql; do
  echo
  echo "-- ===================== $f ====================="
  cat "$f"
  echo
done
echo "NOTIFY pgrst, 'reload schema';"
