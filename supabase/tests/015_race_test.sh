#!/usr/bin/env bash
# supabase/tests/015_race_test.sh
# D7 con concurrencia real: dos conductores aceptan la misma solicitud y dos
# pasajeros piden el último cupo AL MISMO TIEMPO, en dos conexiones. La
# primera retiene el bloqueo 2 s; la segunda debe esperar y perder.
# Uso: 015_race_test.sh <base de datos con 015_dispatch_test.sql ya aplicado>
set -euo pipefail
DB="$1"
q() { psql -d "$DB" -v ON_ERROR_STOP=1 -qtAX "$@"; }

REQ=$(q -c "SET ROLE authenticated;
  SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000a01',false);
  SELECT request_ride('mototaxi',11.5441,-72.9071,'P',11.53,-72.91,'T',5000,gen_random_uuid());" | tail -1)

accept() {  # $1 = conductor, $2 = segundos que retiene el bloqueo
  q -c "BEGIN; SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub','$1',true);
    SELECT (accept_ride('$REQ')).driver_id; SELECT pg_sleep($2); COMMIT;" 2>&1
}
accept 00000000-0000-0000-0000-000000000d01 2 > /tmp/race_a.out &
sleep 0.5
accept 00000000-0000-0000-0000-000000000d02 0 > /tmp/race_b.out || true
wait
if ! grep -q 'already_taken' /tmp/race_b.out; then
  echo "FALLA: el segundo conductor no recibió already_taken: $(cat /tmp/race_b.out)"; exit 1
fi
WINNERS=$(q -c "SELECT count(*) FROM ride_requests WHERE id='$REQ' AND driver_id IS NOT NULL")
[ "$WINNERS" = "1" ] || { echo "FALLA: $WINNERS ganadores"; exit 1; }

# Último cupo: salida de 1 puesto, dos pasajeros a la vez.
DEP=$(q -c "SET ROLE authenticated;
  SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000d03',false);
  SELECT publish_departure('rio-terminal','mai-centro',now()+interval '1 hour',1::smallint,14000);" | tail -1)
reserve() {
  q -c "BEGIN; SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub','$1',true);
    SELECT reserve_seat('$DEP',1::smallint,gen_random_uuid()); SELECT pg_sleep($2); COMMIT;" 2>&1
}
reserve 00000000-0000-0000-0000-000000000a01 2 > /tmp/race_c.out &
sleep 0.5
reserve 00000000-0000-0000-0000-000000000a02 0 > /tmp/race_d.out || true
wait
grep -q 'no_seats' /tmp/race_d.out || { echo "FALLA: el segundo pasajero no recibió no_seats: $(cat /tmp/race_d.out)"; exit 1; }
TAKEN=$(q -c "SELECT seats_taken FROM colectivo_departures WHERE id='$DEP'")
[ "$TAKEN" = "1" ] || { echo "FALLA: cupos tomados $TAKEN"; exit 1; }
echo '015_race_test: OK'
