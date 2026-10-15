#!/usr/bin/env bash
# Revisa en CI que las claves funcionen, sin imprimirlas: llama a Google
# (Places API New y Routes API) con cada clave que haya, y a la Edge Function
# `maps` desplegada con el anon key. Solo informa; nunca hace fallar el build.
# Entorno: GOOGLE_MAPS_API_KEY, GOOGLE_MAPS_SERVER_KEY, SUPABASE_URL, SUPABASE_ANON_KEY.
set -uo pipefail
out=${GITHUB_STEP_SUMMARY:-/dev/stdout}
say() { echo "$1"; echo "$1" >> "$out"; }

# Error de Google en una línea (status + mensaje); el mensaje no trae la clave.
gerr() { jq -r 'if .error then "\(.error.status // .error.code): \(.error.message)" else "ok" end' 2>/dev/null || echo "respuesta rara"; }

google() { # nombre clave
  local name=$1 key=$2
  if [ -z "$key" ]; then say "- $name: no está en los secrets"; return; fi
  [[ "$key" == AIza* ]] || say "- $name: no empieza por AIza (¿es una clave de Google Maps?)"
  local p r
  p=$(curl -s -X POST https://places.googleapis.com/v1/places:autocomplete \
    -H "X-Goog-Api-Key: $key" -H 'Content-Type: application/json' \
    -d '{"input":"Riohacha","includedRegionCodes":["co"]}' | gerr)
  r=$(curl -s -X POST https://routes.googleapis.com/directions/v2:computeRoutes \
    -H "X-Goog-Api-Key: $key" -H 'X-Goog-FieldMask: routes.duration' -H 'Content-Type: application/json' \
    -d '{"origin":{"location":{"latLng":{"latitude":11.5444,"longitude":-72.9072}}},"destination":{"location":{"latLng":{"latitude":11.3780,"longitude":-72.2390}}},"travelMode":"DRIVE"}' | gerr)
  say "- $name → Places (New): $p"
  say "- $name → Routes: $r"
}

say "### Claves"
google GOOGLE_MAPS_API_KEY "${GOOGLE_MAPS_API_KEY:-}"
google GOOGLE_MAPS_SERVER_KEY "${GOOGLE_MAPS_SERVER_KEY:-}"
say "(El mapa del celular usa Maps SDK for Android con GOOGLE_MAPS_API_KEY; eso no se puede probar desde aquí.)"

if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  fn() {
    curl -s -X POST "$SUPABASE_URL/functions/v1/maps" \
      -H "Authorization: Bearer $SUPABASE_ANON_KEY" -H "apikey: $SUPABASE_ANON_KEY" \
      -H 'Content-Type: application/json' -d "$1" |
      jq -r 'if .error then "error \(.error)" elif .items then "ok (\(.items|length) sugerencias)" elif .route then "ok (ruta)" else (tostring|.[0:120]) end' 2>/dev/null || echo "sin respuesta JSON"
  }
  say "- Edge Function maps → buscar: $(fn '{"action":"autocomplete","input":"Riohacha"}')"
  say "- Edge Function maps → ruta: $(fn '{"action":"route","from":{"lat":11.5444,"lng":-72.9072},"to":{"lat":11.378,"lng":-72.239},"mode":"drive"}')"
else
  say "- Edge Function maps: sin SUPABASE_URL / SUPABASE_ANON_KEY, no se probó"
fi
exit 0
