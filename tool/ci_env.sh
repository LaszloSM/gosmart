#!/usr/bin/env bash
# CI: arma .env (y google-services.json) desde los secrets de GitHub.
# SUPABASE_URL se limpia y, si no es https://<ref>.supabase.co, se usa el del
# proyecto; sin SUPABASE_ANON_KEY se saca del proyecto con SUPABASE_ACCESS_TOKEN.
# Luego tool/check_keys.sh informa (sin fallar) si las claves responden.
# Entorno: PROJECT_REF y los secrets (ver ci.yml).
set -euo pipefail
cd "$(dirname "$0")/.."
SUPABASE_URL=$(printf '%s' "${SUPABASE_URL:-}" | tr -d '[:space:]'); SUPABASE_URL=${SUPABASE_URL%/}
if ! [[ "$SUPABASE_URL" =~ ^https://[a-z0-9]+\.supabase\.co$ ]]; then
  [ -n "$SUPABASE_URL" ] && echo "::warning::El secret SUPABASE_URL no es https://<ref>.supabase.co; uso https://$PROJECT_REF.supabase.co."
  SUPABASE_URL="https://$PROJECT_REF.supabase.co"
fi
export SUPABASE_URL
SUPABASE_ANON_KEY=$(printf '%s' "${SUPABASE_ANON_KEY:-}" | tr -d '[:space:]')
if [ -z "$SUPABASE_ANON_KEY" ] && [ -n "${SUPABASE_ACCESS_TOKEN:-}" ] && command -v supabase >/dev/null; then
  SUPABASE_ANON_KEY=$({ supabase projects api-keys --project-ref "$PROJECT_REF" --reveal -o json 2>/dev/null ||
    supabase projects api-keys --project-ref "$PROJECT_REF" -o json; } |
    jq -r '[.[] | select(.name == "anon")][0].api_key // empty') || true
fi
export SUPABASE_ANON_KEY
if [ -n "$SUPABASE_ANON_KEY" ]; then echo "::add-mask::$SUPABASE_ANON_KEY"; echo "Supabase: $SUPABASE_URL (anon key listo)"
else echo "::warning::Sin SUPABASE_ANON_KEY: el APK no se conectará a Supabase."; fi
bash tool/write_env.sh > .env
bash tool/check_keys.sh
if [ -n "${GOOGLE_SERVICES_JSON:-}" ]; then
  printf '%s' "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
  echo "Push activado (google-services.json desde secrets)."
fi
# SHA-1 de la firma (fija, android/keystore/gosmart-demo.jks): es el que va en
# la restricción "Apps de Android" de la llave de Google Maps.
keytool -list -v -keystore android/keystore/gosmart-demo.jks -storepass gosmart-demo 2>/dev/null |
  grep -m1 'SHA1:' | sed 's/^[[:space:]]*/Firma de la app (com.example.gosmart) /' || true
