# MVP de salida · sin simulaciones · 2026-11-06

Objetivo: que GoSmart funcione con personas, conductores y dinero reales en Riohacha,
Maicao y la Troncal. Este documento dice qué quedó real en esta entrega, qué sigue
siendo simulado o sin probar, y las tareas para lanzar, en orden.

## 1. Qué se arregló en esta entrega

| Pedido | Qué se hizo | Dónde |
|---|---|---|
| Bajar la hoja "¿A dónde vas?" para ver el mapa (Waze) | Tres alturas: plegada (solo el buscador), en reposo y arriba. Tocar el asa sube o baja. Los botones flotantes siguen a la hoja | `home_screen.dart`, `home_sheet.dart` |
| Punto de ubicación y botón "Mi ubicación" | `LocationService` nuevo: revisa GPS y permiso, usa la última posición conocida al instante, espera hasta 15 s en alta precisión y luego cae a precisión de red. Publica cada posición para todas las pantallas. El punto azul nativo sale apenas hay permiso. El botón dice qué falta (GPS apagado, permiso) y abre el ajuste correcto. Al volver de los ajustes reintenta solo | `location_service.dart`, `home_map.dart`, `map_view.dart` |
| El planificador se quedaba "Buscando tu ubicación…" y luego "Sin ubicación" | Usa la posición que ya tenga el mapa, la afina en segundo plano, sigue al GPS y, si falla, explica el motivo con un botón (Activar GPS / Dar permiso / Abrir ajustes / Reintentar) | `route_planner_screen.dart` |
| Ubicación actual para pedir el viaje | El origen es tu ubicación real; el mapa del viaje muestra tu punto en vivo | `route_planner_screen.dart`, `trip_map.dart` |
| Varias direcciones con nombre, máximo 10 | "Mis lugares" (Perfil): Casa, Trabajo y hasta 10 con nombre. Se guardan buscando o con "Usar mi ubicación actual". Salen en la fila de accesos del inicio (mantener presionado = editar) y en el planificador. El límite lo hace cumplir también la base (trigger) | `features/places/`, `favorites_provider.dart`, `024_mvp_real.sql` |
| Ruta por la vía, no en línea recta | Todo tramo recto (planificador de colectivo/TransPadilla/intermunicipal, asistente, viaje encadenado) se cambia por el trazado de Google Routes: a pie por andenes, lo demás por la vía. Con caché | `road_snap.dart` |
| Cancelar con confirmación y motivo | Siempre se confirma. Si el conductor ya aceptó, hay que elegir un motivo (lista cerrada, como InDrive/Uber); el conductor tiene sus propios motivos. El servidor lo exige (`ride_cancel`, `cancel_trip`) | `cancel_sheet.dart`, `024_mvp_real.sql` |
| Fuera la simulación del viaje aceptado | Era el "conductor de demo" (`demo_autodriver` + pg_cron): aceptaba solo cualquier pedido y se movía en el mapa. La migración 024 lo apaga, desprograma la tarea, borra sus funciones y borra las cuentas `@example.com`. Se quitaron `supabase/demo/`, la prueba e2e y el workflow del emulador que dependían de él | `024_mvp_real.sql`, workflows |
| Historial de todos los viajes | Pantalla con todos tus viajes por tandas de 20: fecha, origen → destino, modos, estado y lo pagado; abre el recibo | `trip_history_screen.dart` (Perfil → Historial, o "Ver todos" en Viaje) |

Error encontrado de paso: **cancelar el viaje completo no cancelaba la solicitud al
conductor** (seguía viniendo). `cancel_trip` ahora la cancela.

## 2. Lo que sigue simulado o sin probar (verdad completa)

| Qué | Estado real | Riesgo para lanzar |
|---|---|---|
| **Saldo y recargas** | Recarga simulada (`wallet_recharge_simulated`) y bono de bienvenida de $10.000 (trigger de 008). Wompi está escrito pero apagado (`app_flags.wompi_enabled`) y nunca se probó contra el sandbox | **Alto.** Pagar "con saldo" hoy mueve dinero que no existe |
| Pago al conductor con saldo | Se acredita en su billetera, pero no se puede retirar | Alto: el conductor no ve plata real. Mientras tanto, solo efectivo |
| Google Routes / Places (`maps`) | Código y pruebas unitarias; nunca verificado contra Google desde aquí | **Alto:** sin `GOOGLE_MAPS_SERVER_KEY` las rutas vuelven a salir rectas y la búsqueda se limita al directorio |
| Push (FCM) | Código listo, sin Firebase configurado | **Alto:** con la app cerrada el conductor no se entera de pedidos |
| Despacho en vivo | Consultas cada 4–5 s, no Realtime | Medio: funciona, gasta datos y batería |
| GPS en segundo plano del conductor | Solo con la app abierta | Medio |
| Simulador NFC | Solo en builds de depuración | Ninguno en producción |
| Datos de campo | Lugares, tramos de la Troncal, rutas y tarifas son aproximados | Medio |
| Política de datos | `[PENDIENTE]` visible (responsable, contacto, abogado) | **Alto:** requisito legal (Ley 1581) |
| Nada de esto se probó en un celular real desde este entorno | — | Hay que hacer la prueba de campo (fase B) |

## 3. Tareas para el MVP de salida

### Fase A · Base real (bloquea todo lo demás)
1. Aplicar `024_mvp_real.sql` (Actions → *Supabase deploy*). Confirmar que `cron.job` ya no tiene `gosmart-demo-driver` y que no quedan cuentas `@example.com`.
2. Cargar `GOOGLE_MAPS_SERVER_KEY` con **Routes API** y **Places API (New)** habilitadas y facturación activa. Revisar el reporte de `tool/check_keys.sh` en el CI.
3. Firebase: crear proyecto, `GOOGLE_SERVICES_JSON`, `FCM_SERVICE_ACCOUNT`, `PUSH_WEBHOOK_SECRET` y desplegar los webhooks.
4. Aprobar a los primeros conductores reales desde `/admin` con sus documentos verificados.

### Fase B · Prueba de campo (2 celulares, 1 semana)
5. Pasajero y conductor reales en Riohacha: pedir, ofertar, aceptar, recoger, terminar, pagar en efectivo, calificar. Repetir cancelando con y sin conductor.
6. GPS: probar en interiores, con GPS apagado, con permiso negado y "solo esta vez". Medir cuánto tarda el primer punto.
7. Rutas: revisar que mototaxi, taxi, colectivo y a pie salgan por la vía en 10 viajes reales.
8. Anotar fallos en un issue por cada uno.

### Fase C · Dinero real
9. Decidir el modelo: **solo efectivo al lanzar** (recomendado) o recargas con Wompi.
10. Si es solo efectivo: ocultar "Pagar con saldo" y "Recargar" cuando `wompi_enabled` es falso, quitar el bono de $10.000 a cuentas nuevas y migrar los saldos de prueba a cero (con aviso).
11. Si es Wompi: cuenta de comercio, llaves de producción, probar en sandbox el ciclo completo (recarga → webhook → `wallet_topup_settle`), y resolver el retiro de los conductores (requiere aliado vigilado, ver NO_IMPLEMENTADO.md).

### Fase D · Confiabilidad
12. Realtime de Supabase en `ride_requests`/`ride_offers` en lugar de consultas cada 4 s.
13. Ubicación del conductor en segundo plano (servicio en primer plano de Android) mientras está conectado.
14. Replaneo automático si un tramo falla.
15. Sentry activo (`SENTRY_DSN`) y un tablero simple de viajes pedidos / aceptados / cancelados con su motivo (`ride_requests.cancel_reason`).

### Fase E · Legal y publicación
16. Completar la política de datos y los términos (responsable, correo, revisión de abogado).
17. Ficha de Play Store, firma de producción, prueba interna cerrada y luego abierta.
18. Soporte: un WhatsApp de atención y el proceso para reportes de seguridad (SOS).

## 4. Cómo verificar lo de esta entrega
- `flutter analyze` sin avisos y `flutter test` (153 pruebas) pasan.
- Pruebas SQL: `supabase/tests/024_mvp_real_test.sql` (cancelar con motivo, `cancel_trip` suelta al conductor, límite de 10 lugares, demo eliminada) más las existentes.
- En el celular: abrir el inicio con GPS apagado → el botón de ubicación ofrece "Activar"; al prender el GPS y volver, aparece el punto.
