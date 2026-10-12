# GoSmart → MVP Riohacha–Maicao · Plan por fases

## Contexto
GoSmart hoy es una demo de una tarjeta NFC pensada para Bogotá y Medellín (13.5k líneas de Dart). En ese estado:
- El mapa arranca en Bogotá y Maicao no aparece.
- La IA (Groq) no usa function calling y su key va dentro del APK.
- Hay 3 modelos de dinero superpuestos: `cards`, `wallets` y un mock en SharedPreferences.
- Hay 2 tablas de viajes sin uso y 2 carpetas de migraciones.
- No hay conductor, reportes viales, offline, push ni política de privacidad.

El diagnóstico (17 problemáticas) muestra que el problema central del corredor es **la información**. El MVP se reorienta a:
- M1 Estado del corredor
- M2 IA + planificador
- M3 Viaje encadenado + seguridad
- M4 Pago (QR/NFC)
- M5 Confianza

La visión de largo plazo sigue siendo la **tarjeta universal de transporte** del país.

## Decisiones cerradas con el usuario
| Tema | Decisión |
|---|---|
| Alcance | Riohacha + Maicao + corredor. Albania–Cuestecitas solo como desvío. |
| Usuarios | Todos en el mismo plan: viajero del corredor, usuario urbano y conductor. |
| App | Flutter, una sola app con **modo pasajero / modo conductor / admin web** según el rol. |
| Backend gratis | Supabase free (Postgres+PostGIS, Auth, Realtime, Edge Functions, Storage). Límites: 500 MB, se pausa tras 7 días sin uso y no tiene backups automáticos. Se mitiga con un ping programado y un dump semanal en GitHub Actions. |
| Conductor | **Completo**: registro validado, disponibilidad, solicitudes en tiempo real estilo InDrive, cobro y cierre. |
| Origen/destino | **Cualquier punto → cualquier punto**: dirección, referencia, punto en el mapa o ubicación actual. Nada de rutas fijas entre lugares. |
| Mapa | **Google Maps** (`google_maps_flutter`). El mapa móvil es gratis e ilimitado, los gestos y la fluidez son los que todos conocen, y es el mejor buscando direcciones colombianas. La búsqueda (Places Autocomplete New) y las rutas (Routes API) cobran pasado un tope gratis mensual, así que se ponen cuotas diarias en Google Cloud para no pagar. Lo que se pierde: el mapa no se descarga offline; solo queda en caché lo ya visto. El viaje, el estado del corredor y el directorio sí funcionan offline con datos locales. |
| Ampliaciones | Compartir a WhatsApp; directorio de referencias; SOS y compartir viaje en el núcleo; `PRODUCT.md` + `DESIGN.md`. |
| Stripe | Se retira. Las recargas se hacen con **Wompi en sandbox** (gratis). En producción cobra comisión, lo cual se declara. |
| NFC | Se mantiene como vitrina de la visión, en **circuito cerrado**: HCE en el teléfono del pasajero y lectura en el teléfono del conductor, solo con saldo interno. El camino principal es el **QR**, porque muchos teléfonos de conductores no tienen NFC. Tap to Pay bancario queda documentado y no se implementa. |
| IA | Groq gratis con function calling, desde la Edge Function `ai-chat`. La key sale del APK. |

## Verdades declaradas para la sustentación
- El pago único repartido entre 3 conductores retiene dinero de terceros. En el MVP es **saldo simulado**; operarlo en real exige figura regulada (Superfinanciera).
- El conductor completo es lo más caro del semestre por el arranque en frío. Mitigación: piloto con 10–20 conductores reclutados en campo y zonas acotadas.
- Las skills gstack, impeccable, Emil Kowalski y taste no estaban instaladas. Se leyó su método público y se aplicó a mano. Si se instalan, la Fase 2 debe correr `/impeccable critique` y `/plan-design-review`.

## Fase 0 · Limpieza y cimientos (semanas 1–2)
- **Migraciones:** unificarlas en `supabase/migrations/`, moviendo `backend/migrations/001–007`.
- **Un solo modelo de dinero:**
  - Se conservan `wallets` y `wallet_transactions` (008).
  - Se elimina `lib/providers/wallet_mock_provider.dart`, que se reemplaza por un `wallet_provider.dart` real.
  - Se fusionan `transaction_model` y `wallet_transaction_model`.
  - `cards` pasa a ser un "medio NFC" que apunta a la billetera.
- **Quitar Bogotá, Medellín y TransMilenio:**
  - Archivos: `home_screen.dart:40,681`, `location_provider.dart`, `ai_chat_screen.dart:31-34`, `ai_service.dart`, `public_transport_service.dart`, `traffic_service.dart`, `profile_screen.dart:821`.
  - El centro por defecto pasa a ser Riohacha (11.544, -72.907).
- **Retirar Stripe:**
  - Archivos: `pubspec.yaml`, `lib/main.dart`, `lib/core/env.dart` y la función `stripe-webhook`.
  - El `nfc_simulator` queda solo en `kDebugMode`.
- **Partir las pantallas grandes** en widgets por sección: `home_screen` (1096 líneas), `profile_screen` (1115) y `wallet_screen` (932).
- **Seguridad y operación:**
  - Mover Groq a la Edge Function `backend/functions/ai-chat`.
  - Crash reporting gratis con Sentry o Crashlytics.
  - Ampliar `.github/workflows/ci.yml`: analyze, test y dump de la DB.
- **Auth gratis:** correo, Google Sign-In y magic link. El OTP por SMS cuesta (Twilio), así que queda opcional.

## Fase 1 · Campo, datos y prueba de mapa (semanas 1–4, en paralelo)
- **Levantamiento:**
  - Rutas y paraderos de TransPadilla.
  - Tarifas reales de mototaxi en 2026 por zona y hora, en ambas ciudades.
  - Terminales, empresas, horarios y tarifas intermunicipales.
  - Puntos de colectivos y **tiempos de llenado por franja**.
  - Caracterización urbana de Maicao.
  - Km críticos del corredor (tabla de bloqueos) y zonas de inundación.
- **Directorio de referencias (gazetteer):**
  - Más de 300 lugares por ciudad: nombre popular, alias y coordenada. Ejemplos: "la playa", "el muelle", "frente al Éxito", "Palacio de Justicia".
  - Se cargan en una tabla `places` con búsqueda difusa (`pg_trgm`) y como entidades del KG para la IA.
- **Prueba rápida de Google:** 30 direcciones y referencias reales. Lo que Google no encuentre entra al directorio propio.
- **Pipeline:** `pipeline/ingest_osm.py` pasa a un bbox de La Guajira e incluye `bus_stop` y la red vial, solo para el grafo de transporte.
- **Herramienta de captura:** una pantalla interna de admin o un formulario que exporte a CSV, más un script de carga.

## Fase 2 · Diseño UI/UX (semanas 2–5)
Se aplica el método de impeccable, taste y Emil Kowalski.

**Documentos fuente de verdad:**
- `PRODUCT.md`: audiencia, propósito, restricciones, voz y evidencia.
- `DESIGN.md`: tokens, tipografía, color, movimiento y componentes.

**Dirección visual:**
- **Modo claro primero**, legible a pleno sol, con neutros cálidos tintados del paisaje: arena, sal, mar.
- El **rojo, ámbar y verde se reservan para el estado de la vía**. La marca nunca los usa.
- Una tipografía legible (no Inter). Precios y tiempos en números grandes.
- Áreas táctiles de 48 px o más.
- Sin tarjetas dentro de tarjetas, sin degradados morados y sin iconos decorativos en baldosa. No usar iconografía wayuu como decoración.

**Movimiento:**
- Hojas de 200–300 ms con ease-out fuerte; las salidas, más rápidas que las entradas.
- Al presionar, escala a 0.97.
- Nada animado en acciones repetidas, como cambiar de pestaña o marcar el mapa.
- Respetar "reducir movimiento".

**Arquitectura de información:**
- **Pasajero:** Inicio (mapa + barra de estado del corredor + "¿A dónde vas?"), Viaje, Reportar, Billetera y Perfil.
- **Conductor:** Disponible/No, Solicitud entrante, Viaje activo, Cobrar (QR/NFC), Ingresos e historial. En colectivos se suma "Puestos ocupados".
- **Patrón central:** "el chat se transforma en mapa". El selector de origen y destino acepta texto libre, referencia, pin, ubicación actual y ubicación recibida por WhatsApp.

**Modos de transporte:**
- Se agregan mototaxi, colectivo, transpadilla, intermunicipal, taxi y a pie.
- Se quitan metro y bici de `GSColors` y de `selected_mode_provider`.

**Componentes:**
- Se reutilizan los `GS*`.
- Nuevos: `GSCorridorStatusBar`, `GSPlacePicker`, `GSLegTimeline`, `GSFareRange`, `GSSosButton`, `GSReportSheet`, `GSOfflineBanner` y `GSDriverRequestCard`.

**Entregable:** prototipo en Figma de las ~15 pantallas clave, con estados vacíos, de error y offline, antes de codificar.

## Fase 3 · Núcleo: roles, mapa, offline, seguridad básica (semanas 5–8)
- **Esquema:**
  - `profiles.role` y `drivers`: documentos, verificación, llave Bre-B/Nequi, vehículo y zona.
  - `vehicles`.
  - `emergency_contacts`.
  - Documentos en un bucket privado. RLS en todo.
- **Router:** shells por rol en `lib/router/app_router.dart`.
- **Mapa:** migrar de `flutter_map` a `google_maps_flutter`, con estilo JSON propio, que es gratis sin map ID.
  - Se reutiliza `location_service.dart`.
  - `directions_service.dart` pasa a la Routes API de Google.
  - `geocoding_service.dart` pasa a Places Autocomplete, detrás de una interfaz `PlaceSearch`: primero el directorio propio, luego Google y luego el pin.
- **Interacción del mapa, como en las apps de transporte típicas (requisito explícito):**
  - Pellizcar para acercar y alejar, arrastrar con un dedo y doble toque para acercar.
  - Rotar con dos dedos e inclinar, con un botón de brújula para volver al norte.
  - El SDK nativo de Google da estos gestos de fábrica, fluidos y nítidos a cualquier zoom.
  - Botón "mi ubicación" y modo seguir durante el viaje: la cámara sigue al usuario y se suelta cuando él mueve el mapa.
  - Selector de punto estilo Uber/InDrive: el pin queda fijo en el centro y el usuario mueve el mapa debajo; al soltar, muestra la referencia o dirección más cercana.
  - Animaciones de cámara para encuadrar toda la ruta y para pasar del chat al mapa.
  - Agrupación de marcadores (reportes, conductores, paraderos) al alejar.
  - Conductores moviéndose suavemente, con la posición interpolada.
  - Hoja inferior arrastrable sobre el mapa que no bloquea los gestos.
  - Límites de cámara a La Guajira y zoom mínimo/máximo.
- **Offline:**
  - `drift` (SQLite) con espejo de lugares, grafo, estado del corredor y viaje activo.
  - `SyncQueue` con reintentos.
  - Sin señal, el mapa muestra lo que quedó en caché y el resto de la app sigue funcionando con datos locales.
- **Seguridad temprana:**
  - **Compartir viaje** con un link web de solo lectura que usa un token con expiración.
  - **SOS:** WhatsApp/SMS a los contactos con la ubicación, más `tel:123` y el registro en `sos_events`.
- **Legal:**
  - Política de privacidad y autorización de tratamiento de datos (Ley 1581) al registrarse.
  - Términos y condiciones.
  - Declaración en Play de ubicación en segundo plano.
- **Push:** FCM.
- **Manifiesto:** agregar permisos de NFC, cámara (QR), notificaciones y ubicación en segundo plano.

## Fase 4 · M1 Estado del corredor + WhatsApp (semanas 7–10)
- **Tablas:**
  - `road_segments`: Troncal por km, vías urbanas clave y desvío Albania–Cuestecitas.
  - `road_reports`: tipo cerrado (bloqueo, retén, inundación, hueco, accidente), punto, confirmaciones, confianza y expiración.
  - La vista `road_status`.
- **Confirmación cruzada** ponderada por la reputación del reportante. Límite de reportes por usuario.
- **Regla ética codificada:** no hay campo para nombrar personas ni comunidades.
- **Patrones históricos** con SQL agregado, por ejemplo: "4 bloqueos en 3 meses, en la mañana".
- **Alertas push** a quien tenga un viaje que cruce un segmento afectado.
- **Compartir a WhatsApp:** cada reporte y el estado del corredor generan un link a una página web pública, servida por una Edge Function con vista HTML, que se ve sin instalar la app. Este es el motor de adopción.
- **Arranque:** un admin carga el estado inicial. Opcionalmente se integran avisos oficiales del concesionario.

## Fase 5 · M2 Planificador puerta a puerta + IA (semanas 9–13)
- **Grafo** (`graph_nodes`, `graph_edges`) con modo, tiempo, costo mínimo y máximo, riesgo y segmento.
- **Puerta a puerta:**
  - El origen y el destino arbitrarios se **enganchan** a los nodos cercanos, buscando por radio con PostGIS.
  - El primer y el último tramo se resuelven a pie o en mototaxi/taxi, con la ruta calle a calle de Directions.
- **Planificador:**
  - Dijkstra/A* con costo ponderado y penalizaciones por bloqueos, noche, lluvia y vías deterioradas.
  - Corre en una Edge Function, con una copia en Dart para el modo offline.
  - Reemplaza a `public_transport_service.dart`.
- **Tarifa justa:** rango por distancia × zona × hora para los tramos informales. En el intermunicipal, la tarifa publicada.
- **Predicción de despacho:** ocupación reportada + reservas + histórico. Se muestra como rango y calcula hacia atrás la hora de salida.
- **IA con function calling:**
  - Herramientas: `search_place`, `plan_trip`, `get_corridor_status`, `estimate_fare`, `get_dispatch_eta`, `create_chained_trip` y `request_ride`.
  - Se reutilizan `lib/models/ai_models.dart` (`RouteOption`, `Leg`) y `ai_conversation_provider`.
  - Voz con `speech_to_text`.
- **Hitos:** funcionan 3 casos de referencia de punta a punta:
  1. Centro de Riohacha (o la playa) → una dirección específica de Maicao.
  2. Un barrio de Riohacha → la Universidad de La Guajira.
  3. Maicao → la Terminal de Riohacha con la Troncal bloqueada (usa el desvío).

## Fase 6 · Conductor completo + viaje encadenado (semanas 11–15)
- **Despacho estilo InDrive:**
  - El pasajero solicita, con una tarifa sugerida por el estimador.
  - Se avisa por Realtime/push a los conductores disponibles en radio (`ST_DWithin`).
  - El conductor acepta o contraoferta; el pasajero confirma.
  - Timeouts y reasignación.
- **Colectivo:** el conductor publica su salida y sus puestos, y los pasajeros reservan un cupo.
- **Viaje encadenado:**
  - `trips` + `trip_legs`, con la máquina de estados en una función SQL: `planned → leg_in_progress → awaiting_dispatch → … → completed/cancelled`.
  - Replaneo dinámico ante un bloqueo, un cupo perdido o un tramo fallido.
- **Trazabilidad:**
  - Cada tramo registra conductor, ruta, hora y tarifa.
  - Historial del conductor exportable a PDF como prueba de ingresos.
- **Offline:** el estado del viaje vive local y se sincroniza al volver la señal.

## Fase 7 · M4 Pago unificado (semanas 13–16)
- **Billetera real:** recarga con Wompi sandbox (Edge Function + webhook) y bono de bienvenida.
- **Cobro del conductor:**
  1. QR del conductor: el pasajero paga con saldo o con deep link a Nequi/Bre-B.
  2. NFC (HCE ↔ lector) reutilizando `flutter_nfc_kit`, `backend/functions/authorize` y el `idempotency_key`.
  3. Efectivo confirmado al cerrar.
- **Pago único encadenado:**
  - Se retiene el total y se libera por tramo; si un tramo no ocurre, se reembolsa.
  - Se emite un solo recibo con desglose.
  - Todo con RPCs que bloquean filas, siguiendo el patrón de `recharge_wallet`.

## Fase 8 · M5 Confianza + panel admin (semanas 15–17)
- **Reputación:**
  - Calificación bidireccional.
  - Impago: con 2 confirmados se bloquea al pasajero.
  - Reputación del reportante vial.
- **Admin en Flutter Web** (mismo repo, ruta `/admin`):
  - Verificar conductores.
  - Gestionar rutas, tarifas y lugares del directorio.
  - Moderar reportes.
  - Métricas para Instramd y la Alcaldía de Maicao.

## Fase 9 · Piloto y sustentación (semanas 17–18)
- **Piloto en el corredor:** conductores reclutados, viajes reales.
- **Medición:**
  - Precisión del despacho.
  - Acierto del buscador.
  - Tiempo entre que se crea un reporte y se confirma.
- **Documento de lo no implementado:**
  - Tap to Pay bancario.
  - Modo SMS para conductores sin smartphone.
  - Wayuunaiki, a hacer con la comunidad.
  - Integración formal con empresas.
  - Otros municipios.
  - HCE en iOS.
  - Dinero real en custodia.

## Archivos críticos
**Existentes:**
- `lib/router/app_router.dart`
- `lib/theme/design_tokens.dart`
- `lib/services/ai_service.dart` (pasa a ser un cliente de `ai-chat`)
- `backend/functions/ai-chat/`
- `backend/functions/authorize/`
- `lib/services/public_transport_service.dart` (se reemplaza por `planner_service.dart`)
- `lib/services/geocoding_service.dart` (pasa detrás de `PlaceSearch`)
- `lib/providers/wallet_mock_provider.dart` (pasa a `wallet_provider.dart`)
- `lib/features/home/home_screen.dart` (cambia el mapa)
- `pipeline/ingest_osm.py`
- `android/app/src/main/AndroidManifest.xml`
- `.github/workflows/ci.yml`

**Nuevos:**
- `supabase/migrations/010+`
- `lib/features/driver/`
- `lib/features/corridor/`
- `lib/features/trip/`
- `lib/features/admin/`
- `lib/data/local/` (drift)
- `PRODUCT.md` y `DESIGN.md`

## Verificación
- En cada fase: `flutter analyze` y `flutter test`. Tests nuevos para:
  - La máquina de estados del viaje.
  - El planificador sobre un grafo de prueba, incluido el enganche puerta a puerta.
  - La confianza de los reportes.
  - La distribución y el reembolso del pago.
  - El despacho, con timeouts y contraoferta.
- Pruebas SQL de las RPCs: doble cobro, concurrencia y RLS entre usuarios.
- Prueba offline: modo avión a mitad del viaje y sincronización correcta.
- Prueba de gestos del mapa en un Android de gama media: pellizcar, arrastrar, rotar, el pin central y el modo seguir, sin saltos visibles.
- Demo end-to-end con 2 Android (pasajero + conductor): los 3 casos de referencia, el cobro QR y NFC, y un link de WhatsApp abierto en un teléfono sin la app.
- Al cerrar cada fase se actualiza `CLAUDE.md`.
