#!/usr/bin/env bash
# Arma el .env de la app en CI: parte de .env.example y reemplaza cada clave
# que venga en el entorno (secrets de GitHub). Las claves de mapa/Sentry que no
# vengan quedan vacías; el resto queda de ejemplo.
# Uso: SUPABASE_URL=... SUPABASE_ANON_KEY=... tool/write_env.sh > .env
set -euo pipefail
cd "$(dirname "$0")/.."
while IFS= read -r line; do
  key="${line%%=*}"
  if [[ "$line" =~ ^[A-Z_]+= ]] && [ -n "${!key:-}" ]; then
    printf '%s=%s\n' "$key" "${!key}"
  elif [[ "$line" =~ ^(GOOGLE_MAPS_API_KEY|SENTRY_DSN|SHARE_BASE_URL)= ]]; then
    # Sin secret, vacío: una clave de ejemplo no sirve. Sin clave de Google,
    # el mapa es OpenStreetMap.
    printf '%s=\n' "$key"
  else
    printf '%s\n' "$line"
  fi
done < .env.example
