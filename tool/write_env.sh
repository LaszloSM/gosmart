#!/usr/bin/env bash
# Arma el .env de la app en CI: parte de .env.example y reemplaza cada clave
# que venga en el entorno (secrets de GitHub). Lo que no venga queda de ejemplo.
# Uso: SUPABASE_URL=... SUPABASE_ANON_KEY=... tool/write_env.sh > .env
set -euo pipefail
cd "$(dirname "$0")/.."
while IFS= read -r line; do
  key="${line%%=*}"
  if [[ "$line" =~ ^[A-Z_]+= ]] && [ -n "${!key:-}" ]; then
    printf '%s=%s\n' "$key" "${!key}"
  else
    printf '%s\n' "$line"
  fi
done < .env.example
