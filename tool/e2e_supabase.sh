#!/usr/bin/env bash
# Prueba de punta a punta contra el Supabase real, con las cuentas demo.
# Hace lo mismo que la app: lee la vía, el grafo y los lugares, busca con Google
# (función maps), entra como pasajera, pide un mototaxi que acepta el conductor
# de demo (pg_cron), lo paga con saldo, lo califica, reserva un cupo de
# colectivo y entra como conductor. No imprime claves ni tokens.
# Entorno: SUPABASE_URL, SUPABASE_ANON_KEY, DEMO_PASSWORD.
set -uo pipefail
U=${SUPABASE_URL%/}
A=$SUPABASE_ANON_KEY
out=${GITHUB_STEP_SUMMARY:-/dev/null}
fails=0
ok()   { echo "✅ $1"; echo "- ✅ $1" >> "$out"; }
bad()  { echo "❌ $1"; echo "- ❌ $1" >> "$out"; fails=$((fails + 1)); }
check() { if [ "$2" = "1" ]; then ok "$1"; else bad "$1 — $3"; fi; }

# rpc <token|anon> <función> <json>
rpc() {
  local tok=$1; [ "$tok" = anon ] && tok=$A
  curl -s -X POST "$U/rest/v1/rpc/$2" -H "apikey: $A" -H "Authorization: Bearer $tok" \
    -H 'Content-Type: application/json' -d "$3"
}
get() { curl -s "$U/rest/v1/$2" -H "apikey: $A" -H "Authorization: Bearer $1"; }
login() {
  curl -s -X POST "$U/auth/v1/token?grant_type=password" -H "apikey: $A" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg e "$1" --arg p "$DEMO_PASSWORD" '{email:$e,password:$p}')" | jq -r '.access_token // empty'
}
uuid() { cat /proc/sys/kernel/random/uuid; }

echo "### Prueba de punta a punta (Supabase real)" >> "$out"

# ── Lo público (modo invitado) ───────────────────────────────────────────────
r=$(rpc anon road_status '{}')
n=$(echo "$r" | jq 'length' 2>/dev/null || echo 0)
check "Estado de la vía: $n tramos ($(echo "$r" | jq -r '[.[].state] | group_by(.) | map("\(.[0]) \(length)") | join(", ")' 2>/dev/null))" \
  "$([ "$n" -ge 8 ] && echo 1)" "$(echo "$r" | head -c 200)"
r=$(rpc anon graph_snapshot '{}')
check "Grafo de transporte: $(echo "$r" | jq '.edges | length' 2>/dev/null) conexiones" \
  "$(echo "$r" | jq -e '.edges | length > 5' >/dev/null 2>&1 && echo 1)" "$(echo "$r" | head -c 200)"
r=$(rpc anon search_places '{"p_query":"terminal","p_lat":11.54,"p_lng":-72.9,"p_limit":5}')
check "Directorio de lugares: \"terminal\" → $(echo "$r" | jq -r 'map(.name) | join(", ")' 2>/dev/null)" \
  "$(echo "$r" | jq -e 'length > 0' >/dev/null 2>&1 && echo 1)" "$(echo "$r" | head -c 200)"
r=$(curl -s -X POST "$U/functions/v1/maps" -H "apikey: $A" -H "Authorization: Bearer $A" \
  -H 'Content-Type: application/json' -d '{"action":"autocomplete","input":"Hospital Riohacha"}')
check "Google Places (función maps): $(echo "$r" | jq '.items | length' 2>/dev/null) sugerencias" \
  "$(echo "$r" | jq -e '.items | length > 0' >/dev/null 2>&1 && echo 1)" "$(echo "$r" | head -c 200)"
r=$(curl -s -X POST "$U/functions/v1/maps" -H "apikey: $A" -H "Authorization: Bearer $A" \
  -H 'Content-Type: application/json' \
  -d '{"action":"route","from":{"lat":11.5441,"lng":-72.9071},"to":{"lat":11.5275,"lng":-72.888},"mode":"drive"}')
check "Google Routes (función maps): ruta Centro → Uniguajira" \
  "$(echo "$r" | jq -e '.route' >/dev/null 2>&1 && echo 1)" "$(echo "$r" | head -c 200)"
r=$(curl -s -X POST "$U/functions/v1/maps" -H "apikey: $A" -H "Authorization: Bearer $A" \
  -H 'Content-Type: application/json' -d '{"action":"reverse","at":{"lat":11.5441,"lng":-72.9071}}')
check "Dirección de un punto (Parque Padilla): $(echo "$r" | jq -r '"\(.address // .error) [\(.source // "-"); Geocoding API: \(.geocode_status // "OK")]"' 2>/dev/null)" \
  "$(echo "$r" | jq -e '.address' >/dev/null 2>&1 && echo 1)" "$(echo "$r" | head -c 200)"
r=$(curl -s -X POST "$U/functions/v1/ai-chat" -H "apikey: $A" -H "Authorization: Bearer $A" \
  -H 'Content-Type: application/json' -d '{"query":"¿Cómo está la Troncal hacia Maicao?","history":[]}')
check "Asistente (Groq): responde ($(echo "$r" | jq -r '.source // "?"' 2>/dev/null))" \
  "$(echo "$r" | jq -e '.source == "groq" or .source == "tool_call"' >/dev/null 2>&1 && echo 1)" \
  "$(echo "$r" | jq -c '{source,error}' 2>/dev/null || echo "$r" | head -c 200)"

if [ -z "${DEMO_PASSWORD:-}" ]; then
  bad "Sin DEMO_PASSWORD: no se probó nada con cuenta"
  exit 1
fi

# ── Pasajera ─────────────────────────────────────────────────────────────────
P=$(login pasajero@example.com)
check "Entrar como pasajera (pasajero@example.com)" "$([ -n "$P" ] && echo 1)" "login falló"
[ -z "$P" ] && exit 1
r=$(get "$P" 'wallets?select=balance')
check "Billetera: saldo \$$(echo "$r" | jq -r '.[0].balance' 2>/dev/null)" \
  "$(echo "$r" | jq -e '.[0].balance >= 0' >/dev/null 2>&1 && echo 1)" "$r"
r=$(get "$P" 'favorite_places?select=name,type')
check "Lugares guardados: $(echo "$r" | jq -r 'map(.name) | join(", ")' 2>/dev/null)" \
  "$(echo "$r" | jq -e 'length >= 2' >/dev/null 2>&1 && echo 1)" "$r"

req=$(rpc "$P" request_ride "$(jq -n --arg k "$(uuid)" '{p_service:"mototaxi",p_origin_lat:11.5441,p_origin_lng:-72.9071,p_origin_label:"Parque Padilla",p_dest_lat:11.5275,p_dest_lng:-72.888,p_dest_label:"Universidad de La Guajira",p_offered_fare:5000,p_idempotency_key:$k}')" | jq -r '. // empty' 2>/dev/null)
check "Pedir mototaxi" "$([[ "$req" =~ ^[0-9a-f-]{36}$ ]] && echo 1)" "$req"
status() { get "$P" "ride_requests?select=status&id=eq.$req" | jq -r '.[0].status'; }
wait_for() { # estado, segundos
  local i; for ((i = 0; i < $2; i += 3)); do [ "$(status)" = "$1" ] && return 0; sleep 3; done; return 1
}
if [[ "$req" =~ ^[0-9a-f-]{36}$ ]]; then
  if wait_for accepted 30; then
    ok "El conductor de demo aceptó (pg_cron funcionando)"
    v=$(rpc "$P" ride_driver_view "$(jq -n --arg r "$req" '{p_request_id:$r}')")
    check "La pasajera ve al conductor: $(echo "$v" | jq -r '.[0] | "\(.first_name) · \(.plate)"' 2>/dev/null)" \
      "$(echo "$v" | jq -e '.[0].lat' >/dev/null 2>&1 && echo 1)" "$v"
    if wait_for in_progress 45; then
      ok "La recogió (en viaje)"
      p=$(rpc "$P" pay_ride "$(jq -n --arg r "$req" --arg k "$(uuid)" '{p_request_id:$r,p_method:"wallet",p_idempotency_key:$k}')")
      check "Pagar el viaje con saldo (\$$(echo "$p" | jq -r '.amount' 2>/dev/null))" \
        "$(echo "$p" | jq -e '.status == "paid"' >/dev/null 2>&1 && echo 1)" "$p"
      if wait_for completed 75; then
        ok "Viaje terminado"
        r=$(rpc "$P" rate_ride "$(jq -n --arg r "$req" '{p_request_id:$r,p_stars:5,p_tags:[]}')")
        check "Calificar al conductor (5 estrellas)" "$([ -z "$r" ] || [ "$r" = "null" ] || [ "$r" = '""' ] && echo 1)" "$r"
      else bad "El viaje no terminó a tiempo (estado: $(status))"; fi
    else bad "No pasó a 'en viaje' (estado: $(status))"; fi
  else
    bad "Nadie aceptó en 30 s (estado: $(status)). ¿Está pg_cron activo y el interruptor demo_autodriver?"
    rpc "$P" ride_transition "$(jq -n --arg r "$req" '{p_request_id:$r,p_to:"cancelled"}')" >/dev/null
  fi
fi

dep=$(get "$A" 'colectivo_departures?select=id,depart_at,seats_total,seats_taken&status=eq.open&from_node=eq.rio-terminal&order=depart_at&limit=1')
d=$(echo "$dep" | jq -r '.[0].id // empty')
check "Salidas de colectivo Riohacha → Maicao (próxima: $(echo "$dep" | jq -r '.[0].depart_at // "-"'))" \
  "$([ -n "$d" ] && echo 1)" "$dep"
if [ -n "$d" ]; then
  s=$(rpc "$P" reserve_seat "$(jq -n --arg d "$d" --arg k "$(uuid)" '{p_departure_id:$d,p_seats:1,p_idempotency_key:$k}')" | jq -r '. // empty')
  check "Reservar un cupo" "$([[ "$s" =~ ^[0-9a-f-]{36}$ ]] && echo 1)" "$s"
  [[ "$s" =~ ^[0-9a-f-]{36}$ ]] && rpc "$P" cancel_reservation "$(jq -n --arg s "$s" '{p_reservation_id:$s}')" >/dev/null \
    && ok "Cancelar la reserva"
fi

# ── Conductor ────────────────────────────────────────────────────────────────
C=$(login conductor@example.com)
check "Entrar como conductor (conductor@example.com)" "$([ -n "$C" ] && echo 1)" "login falló"
if [ -n "$C" ]; then
  r=$(get "$C" 'drivers?select=status,service,available')
  check "Conductor aprobado: $(echo "$r" | jq -r '.[0] | "\(.service), \(.status)"' 2>/dev/null)" \
    "$(echo "$r" | jq -e '.[0].status == "approved"' >/dev/null 2>&1 && echo 1)" "$r"
  r=$(rpc "$C" nearby_requests '{"p_lat":11.5441,"p_lng":-72.9071}')
  check "Solicitudes cercanas (consulta del conductor)" \
    "$(echo "$r" | jq -e 'type == "array"' >/dev/null 2>&1 && echo 1)" "$r"
fi

echo
if [ "$fails" -eq 0 ]; then echo "Todo OK"; else echo "$fails pruebas fallaron"; fi
exit "$fails"
