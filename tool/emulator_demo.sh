#!/usr/bin/env bash
# Corre la demo (integration_test/demo_flow_test.dart) en el emulador de CI y
# toma una captura cada 3 s con adb (adb sí ve el mapa nativo de Google).
# Deja en shots-named/ una captura por paso + steps.txt.
# Entorno: DEMO_PASSWORD (opcional).
set -uo pipefail
PKG=com.example.gosmart
adb wait-for-device
adb shell settings put secure location_mode 3 >/dev/null 2>&1 || true
adb shell cmd location set-location-enabled true >/dev/null 2>&1 || true
mkdir -p shots shots-named

# En segundo plano: GPS en el Parque Padilla (Riohacha), permisos en cuanto la
# app quede instalada (el diálogo del sistema no se puede tocar desde la prueba)
# y una captura cada 3 s.
(
  while true; do
    adb emu geo fix -72.9071 11.5441 >/dev/null 2>&1
    for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do
      adb shell pm grant "$PKG" "android.permission.$p" >/dev/null 2>&1
    done
    adb exec-out screencap -p > "shots/$(date +%s%3N).png" 2>/dev/null
    sleep 3
  done
) &
BG=$!

flutter test integration_test/demo_flow_test.dart -d emulator-5554 \
  --dart-define=DEMO_PASSWORD="${DEMO_PASSWORD:-}" 2>&1 | tee test.log
status=${PIPESTATUS[0]}
sleep 4
kill "$BG" 2>/dev/null

grep -E 'STEP |RESULT ' test.log | sed 's/^.*\(STEP\|RESULT\)/\1/' > steps.txt
cat steps.txt
# Una captura por paso: la primera tomada después del paso.
python3 - <<'PY'
import os, re, shutil
shots = sorted(int(f[:-4]) for f in os.listdir('shots') if f.endswith('.png') and os.path.getsize('shots/' + f) > 10000)
n = 0
for line in open('steps.txt'):
    m = re.match(r'STEP (\S+) (\d+)', line)
    if not m:
        continue
    name, t = m.group(1), int(m.group(2))
    after = [s for s in shots if s >= t]
    if after:
        n += 1
        shutil.copy(f'shots/{after[0]}.png', f'shots-named/{n:02d}-{name}.png')
print(f'{n} capturas por paso de {len(shots)} tomadas')
PY
cp steps.txt test.log shots-named/ 2>/dev/null
exit "$status"
