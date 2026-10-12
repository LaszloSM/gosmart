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
- M4 Pago (QR; NFC a futuro para transporte público)
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
| NFC | **Pospuesto (D3).** El cobro va por **QR**. Queda como visión: **NFC para transporte público** (TransPadilla, metro y validadores en general). La tabla `cards` se conserva como abstracción para esos validadores. NFC entre celulares y Tap to Pay bancario: no se implementan. |
| IA | Groq gratis con function calling, desde la Edge Function `ai-chat`. La key sale del APK. **Modelo `llama-3.1-8b-instant`** para elegir herramientas, y el 70B solo como respaldo (E1). Prompt corto: el contexto del mapa no se mete en cada mensaje; la IA lo pide con `search_place`. |

## Verdades declaradas para la sustentación
- **Pago (D5):** cada tramo se paga al cerrarse y el viaje entrega **un solo recibo** con desglose. El pago único con retención se pospone, porque retener dinero de terceros exige figura regulada (Superfinanciera).
- El conductor completo es lo más caro del semestre por el arranque en frío. Mitigación: piloto con 10–20 conductores reclutados en campo y zonas acotadas.
- Las skills de diseño **impeccable** (pbakaus, Apache 2.0), **taste-skill** (Leonxlnx, MIT) y **Emil Kowalski** (emilkowalski/skills, MIT) están instaladas en `.claude/skills/` desde el 2026-10-12 y gobiernan la Fase 2. El primer sistema de diseño (arena + mar, Atkinson) se descartó por plano: taste-skill lo marca como paleta "cream + espresso" por defecto e impeccable como "pantalla gris con un acento".

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
  - Se cargan en una tabla `places` con búsqueda difusa (`pg_trgm`) y alias.
  - **Se eliminan pgvector, los embeddings de HuggingFace (`retrieval.ts`) y `pipeline/embed.py` (E3).**
- **Prueba rápida de Google:** 30 direcciones y referencias reales. Lo que Google no encuentre entra al directorio propio.
- **Pipeline:** `pipeline/ingest_osm.py` pasa a un bbox de La Guajira e incluye `bus_stop` y la red vial, solo para el grafo de transporte.
- **Herramienta de captura:** una pantalla interna de admin o un formulario que exporte a CSV, más un script de carga.

## Fase 2 · Rediseño total de la interfaz (corregida 2026-10-12)
**Decisión del usuario:** rediseño desde cero de toda la app: colores, tipografía, botones, componentes e interfaz. No queda nada visual protegido; se conservan la función, el contenido, el modo invitado y las reglas de accesibilidad de `PRODUCT.md`.

**Las tres skills y qué aporta cada una:**
| Skill | Para qué se usa | Cuándo |
|---|---|---|
| **impeccable** | Proceso: `PRODUCT.md` → mundo visual (tirada de direcciones) → contrato de dirección → construcción → revisión final → `DESIGN.md` escrito desde lo construido. Reglas Android/Material 3 y el piso de calidad (`craft-floor`). Comandos: `critique`, `audit`, `polish`, `harden`, `onboard`, `clarify`. | Antes, durante y al cierre de cada pantalla |
| **taste-skill** (+ `redesign-skill`) | Lista de "AI tells" prohibidos: paleta crema+espresso, un solo acento sobre gris, tarjetas iguales, etiquetas pequeñas sobre títulos, CTA duplicados, botones que se parten, placeholder como etiqueta. Protocolo de rediseño "overhaul" y estados completos (cargando, vacío, error, presión). | Auditoría antes de tocar cada pantalla y chequeo previo al commit |
| **Emil Kowalski** (`emil-design-eng`, `animate`, `review-animations`) | Movimiento y sensación: ¿debe animarse?, ease-out fuerte `cubic(0.23,1,0.32,1)`, menos de 300 ms, presión a 0.97, nunca desde escala 0, salidas más rápidas que entradas, nada en acciones repetidas, "quitar animaciones" del sistema. Revisión en tabla Antes/Después/Por qué. | Cada componente interactivo y una revisión de movimiento por pantalla |

**Hecho (2026-10-12):**
- `PRODUCT.md` escrito y confirmado (impeccable init).
- Tirada de direcciones en modo Operate. Corrió **degradada**: el servidor de impeccable no se alcanza desde el contenedor, así que no hubo rivales del catálogo ni tableros de calidad. Se presentaron 3 opciones por chat y el usuario eligió **"Rótulo de colectivo"**.
- Contrato de dirección en `.impeccable/surfaces/lib-main-dart.md` (seed `f3f70ca1`).

**Mundo "Rótulo de colectivo":**
- Los letreros de ruta pintados en el parabrisas de colectivos y busetas de la costa.
- **Paleta:** shell en ultramar de carrocería `#1B3A8C`, fondo lámina fría `#EEF1F5`, placas blancas, tinta `#111827`. Una franja fucsia `#C2185B` marca solo lo seleccionado. Rojo, ámbar y verde siguen siendo solo para el estado de la vía. Todo el texto principal pasa de 7:1.
- **Tipografía:** Barlow Condensed 700/800 para placas y títulos; Barlow 400–700 para el cuerpo; cifras tabulares en precios, km y horas. OFL, empaquetadas.
- **Gesto distintivo:** `GSRoutePlate`. Cada destino, tramo, viaje y movimiento es una placa de ruta legible a cinco metros. "¿A dónde vas?" es una placa en blanco que se "pinta" con el destino.
- **Controles:** los nativos de Material 3. El mundo aporta solo tipografía, paleta, densidad y la placa; nunca disfraz de bus.
- **Radios:** 4/8/12. Sin degradados, sin vidrio, sin tarjetas por defecto.
- **Movimiento:** presión 0.97 en 120 ms; cambio de texto de placa con fundido y desplazamiento de 8 dp en 200 ms; hojas de 250 ms al entrar y 200 ms al salir; nada al cambiar de pestaña.

**Avance (2026-10-12, noche):** construidos en el mundo nuevo la base (tokens, tema, fuentes,
`GSRoutePlate`, `GSButton`, barra inferior, campos, hojas, `GSListRow`, `GSEmptyState`, `GSToast`),
inicio, perfil, planificador + detalle de ruta, billetera, asistente, login, registro, SMS, intro,
permiso de ubicación y splash. De paso se quitaron funciones falsas (interruptores sin efecto,
"Próximamente", "Iniciar viaje" y el pago NFC que siempre fallaba) y se corrigieron fallas reales
(fechas que lanzaban excepción, SMS sin +57, consentimientos siempre en false, celular del registro
que se perdía, sin forma de elegir el modo). Revisión final de impeccable en un agente nuevo: "fix" → dos rondas de arreglos → **ship**.
Revisión de movimiento de Emil: "Block" → arreglada (pestañas sin animación, ease-out en la hoja,
volver más rápido que entrar, "quitar animaciones" en todo). `DESIGN.md` reescrito por el
documentador desde lo construido. **Modo nocturno hecho** como esquema propio (paleta `GSPalette.dark`, todo texto ≥ 7:1,
carrocería separada de la marca). Falta solo el estilo nocturno del mapa (Fase 3, Google Maps).

**Orden de construcción (code-led, una pantalla por entrega):**
1. **Base:** tokens, tema, fuentes, `GSRoutePlate`, `GSButton`, barra inferior, campos y hojas.
2. **Perfil** (partir sus 1.115 líneas).
3. **Inicio:** Línea del corredor sobre la barra ultramar y la placa "¿A dónde vas?".
4. **Planificador y detalle de ruta:** tramos como placas encadenadas (`GSLegTimeline`, `GSFareRange`).
5. **Billetera:** recibo y movimientos como placas.
6. **Asistente de IA.**
7. **Login, registro, intro y permiso de ubicación** (`impeccable onboard`).
8. **Estados DS2** de cada pantalla (`impeccable harden`).
9. **Modo nocturno** como esquema propio, no invertido.

**Cierre de cada entrega:**
- `flutter analyze` y tests.
- Capturas renderizadas: teléfono a 360 dp, texto al 130% y prueba de "quitar animaciones".
- Revisión final de impeccable en un agente nuevo, sin el historial de la construcción.
- Revisión de movimiento de Emil.
- Chequeo previo de taste-skill.
- Al terminar el mundo, el documentador de impeccable reescribe `DESIGN.md` desde lo construido (hecho el 2026-10-12).

**Se mantiene de la versión anterior de esta fase:** arquitectura de información (DS1), modo invitado (DS3), modo conductor de una mano (DS6: 72 dp, 2 acciones por pantalla), accesibilidad (DS7), tono (DS8), modos de transporte locales y los componentes nuevos (`GSPlacePicker`, `GSLegTimeline`, `GSFareRange`, `GSSosButton`, `GSReportSheet`, `GSOfflineBanner`, `GSDriverRequestCard`).

**Se elimina:** la paleta arena/mar y Atkinson Hyperlegible (DS4). El prototipo en Figma ya no es requisito: el mundo es code-led y se verifica con capturas y la revisión final.

**Pendiente de verificar:** la legibilidad real de Barlow al sol y en un teléfono de gama media.

## Fase 3 · Núcleo: roles, mapa, offline, seguridad básica (semanas 5–8)
> **Estado (2026-10-12):** hecha salvo push (FCM). Offline con SharedPreferences en vez de drift. Detalle en `docs/ESTADO_IMPLEMENTACION.md`.

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
- **Degradación con aviso (D8):** si Groq agota su cuota o falla, la app sigue con el planificador y el buscador normal. Si Google falla o agota su cuota, se usa el directorio propio y el pin. En ambos casos hay un aviso claro al usuario y el error se registra en Sentry con el servicio y el código.
- **Manifiesto:** agregar permisos de cámara (QR), notificaciones y ubicación en segundo plano.

## Fase 4 · M1 Estado del corredor + WhatsApp (semanas 7–10)
> **Estado (2026-10-12):** hecha (migración 013, pestaña Reportar, `public_web/via.html`). Sin alertas push.

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
> **Estado (2026-10-12):** hecha (014, `lib/planner/`, IA con herramientas). Los 3 casos de referencia pasan sobre la semilla aproximada. Sin voz ni predicción de despacho.

- **Grafo** (`graph_nodes`, `graph_edges`) con modo, tiempo, costo mínimo y máximo, riesgo y segmento.
- **Puerta a puerta:**
  - El origen y el destino arbitrarios se **enganchan** a los nodos cercanos, buscando por radio con PostGIS.
  - El primer y el último tramo se resuelven a pie o en mototaxi/taxi, con la ruta calle a calle de Directions.
- **Planificador:**
  - Dijkstra/A* con costo ponderado y penalizaciones por bloqueos, noche, lluvia y vías deterioradas.
  - **Corre solo en el celular (D6)**, en Dart, sobre el grafo cacheado en `drift`. Es un solo planificador, igual con o sin señal.
  - La IA en `ai-chat` devuelve la llamada a la herramienta `plan_trip`; el celular la ejecuta y le devuelve el resultado a la IA.
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
> **Estado (2026-10-12):** hecha (015, pestaña Viaje, modo conductor). D7 probado con carrera real. Sin replaneo automático ni PDF.

- **Despacho estilo InDrive:**
  - El pasajero solicita, con una tarifa sugerida por el estimador.
  - Se avisa por Realtime/push a los conductores disponibles en radio (`ST_DWithin`).
  - **Ubicación del conductor (E2):** si está libre, cada 30 s y solo a la base de datos, para buscar por cercanía. En viaje, cada 5 s por Broadcast, solo al canal privado de ese viaje. Con eso cabe en los 2M de mensajes/mes del plan gratis.
  - El conductor acepta o contraoferta; el pasajero confirma.
  - **Aceptar una solicitud y reservar un cupo de colectivo son RPCs atómicas con bloqueo de fila (D7)**, siguiendo el patrón de `recharge_wallet`. Gana uno solo. Hay un test que simula dos aceptaciones o reservas simultáneas.
  - Timeouts y reasignación.
- **Colectivo:** el conductor publica su salida y sus puestos, y los pasajeros reservan un cupo.
- **Viaje encadenado:**
  - `trips` + `trip_legs`, con la máquina de estados en una función SQL: `planned → leg_in_progress → awaiting_dispatch → … → completed/cancelled`.
  - Replaneo dinámico ante un bloqueo, un cupo perdido o un tramo fallido.
- **Trazabilidad:**
  - Cada tramo registra conductor, ruta, hora y tarifa.
  - Historial del conductor exportable a PDF como prueba de ingresos.
- **Offline (E6):** el servidor manda. Cada acción offline lleva un `idempotency_key` y se envía al volver la señal. Si el servidor la rechaza por estado inválido, el celular descarta su versión, muestra el estado real y avisa.

## Fase 7 · M4 Pago unificado (semanas 13–16)
> **Estado (2026-10-12):** hecha en sandbox (016, QR, efectivo, recibo único, Edge Function `wompi`). Wompi sin probar contra el sandbox real.

- **Billetera real:** recarga con Wompi sandbox (Edge Function + webhook) y bono de bienvenida.
- **Cobro del conductor:**
  1. QR del conductor: el pasajero paga con saldo o con deep link a Nequi/Bre-B.
  2. Efectivo confirmado al cerrar.
  - NFC: pospuesto (D3). Se reutilizará la lógica de `backend/functions/authorize` cuando lleguen los validadores de transporte público.
- **Pago por tramo + recibo único (D5):** cada tramo se cobra al cerrarse, con una RPC atómica y su `idempotency_key`. El viaje genera un solo recibo con el desglose.

## Fase 8 · M5 Confianza + panel admin (semanas 15–17)
> **Estado (2026-10-12):** hecha (017, calificaciones, impago, `/admin`). Edición de rutas/tarifas/lugares aún en Supabase.

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
> **Estado (2026-10-12):** preparado, no ejecutado: `docs/PILOTO.md` y `docs/NO_IMPLEMENTADO.md`.

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
- `lib/features/rides/`: despacho, cupos de colectivo y tramos del viaje, con vistas de pasajero y conductor y una sola máquina de estados (E4).
- `lib/features/corridor/`
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
- **Pruebas SQL (E5):** Supabase local + pgTAP en GitHub Actions en cada push. Cubren doble cobro, concurrencia (dos aceptaciones o reservas simultáneas) y RLS entre usuarios.
- Prueba offline: modo avión a mitad del viaje y sincronización correcta.
- Prueba de gestos del mapa en un Android de gama media: pellizcar, arrastrar, rotar, el pin central y el modo seguir, sin saltos visibles.
- Demo end-to-end con 2 Android (pasajero + conductor): los 3 casos de referencia, el cobro QR, un choque simulado de despacho, y un link de WhatsApp abierto en un teléfono sin la app.
- Al cerrar cada fase se actualiza `CLAUDE.md`.


## Revisión CEO (gstack /plan-ceo-review) · 2026-10-12
**Modo:** SCOPE REDUCTION (D1). Revisión a nivel de estrategia. No hubo voz externa: Codex no está instalado y por eso no hay cobertura cruzada.

**Decisiones**

| ID | Decisión | Respuesta |
|---|---|---|
| D2 | Despacho InDrive | Se mantiene |
| D3 | NFC entre celulares | Pospuesto; NFC queda para transporte público a futuro |
| D4 | Panel admin Flutter Web | Se mantiene |
| D5 | Pago único con retención | Pospuesto; pago por tramo + recibo único |
| D6 | Planificador | Solo en el celular |
| D7 | Choques en despacho y cupos | RPC atómica + test de choque |
| D8 | Cuotas Groq/Google agotadas | Degradar con aviso + registro |

**Verificado contra el repo**
- El mapa arranca en Bogotá: `home_screen.dart:681`.
- La key de Groq va dentro del cliente: `env.dart:18`.
- La billetera es local en SharedPreferences: `wallet_mock_provider.dart:3`. `CLAUDE.md` dice lo contrario y hay que corregirlo.
- `trips` y `trip_history` no se usan en `lib/`.
- Las migraciones están partidas en dos carpetas.
- No hay permisos de cámara ni de notificaciones.
- Solo hay 6 tests en `test/`.

**Hallazgos por sección**
1. **Arquitectura.** Supabase es el punto único de falla: se pausa a los 7 días y no tiene backups; ya está mitigado en el plan. La duplicación del planificador se resolvió con D6. Realtime del plan gratis aguanta unas 200 conexiones, suficiente para el piloto.
2. **Errores.** Faltaba qué pasa cuando se agotan las cuotas; resuelto con D8. Falta definir errores para: webhook de Wompi, push fallido, conflicto de sincronización offline y proyecto Supabase pausado. Todos deben mostrar un aviso y quedar en Sentry.
3. **Seguridad.**
   - RLS en cada tabla nueva.
   - Documentos de conductores en un bucket privado.
   - Links de viaje compartido con token que expira.
   - Páginas públicas de WhatsApp con límite de peticiones.
   - Keys de Google restringidas al paquete de la app.
   - La ubicación del conductor solo es visible para el pasajero de su viaje.
   - Un reporte falso de "retén" puede estigmatizar; por eso hay categorías cerradas y confirmación cruzada.
4. **Datos y bordes.**
   - Choques en despacho y cupos: resuelto con D7.
   - La cola offline puede reenviar reportes y cobros; se previene con `idempotency_key` en todo lo que escribe.
5. **Calidad.** Hay que partir las pantallas gigantes antes de tocarlas (ya está en la Fase 0).
6. **Tests.** Se agregan los tests de choque de D7 y los de degradación de D8.
7. **Rendimiento.** Hay que cachear las respuestas de Places y Routes para no gastar cuota. El planificador local responde en milisegundos.
8. **Observabilidad.**
   - Sentry desde la Fase 0.
   - El panel admin muestra: reportes confirmados, éxito del despacho, fallas de la IA y cuota usada.
9. **Despliegue.**
   - Migraciones en orden.
   - Track de prueba interna en Google Play.
   - El despacho detrás de un interruptor (flag) para apagarlo si falla en el piloto.
10. **Trayectoria.** Se conserva `cards` para el futuro NFC de transporte público. Cambiar de mapa más adelante se facilita si todo el código del mapa vive en un solo widget.
11. **Diseño.** Falta el mapa de estados (cargando, vacío, error, offline) por pantalla. Se recomienda correr `/plan-design-review` antes de codificar.

**Diferenciación frente a Waze.** Waze ya tiene reportes de vías cerradas. GoSmart se diferencia por:
- Colectivos y TransPadilla.
- Seguridad (retenes, SOS, compartir viaje).
- El patrón de bloqueos del corredor.
- WhatsApp.

Hay que decirlo en la sustentación.

**Riesgo abierto.** Con el despacho y el admin dentro, el plan sigue apretado para 18 semanas. Si en la semana 10 no está el caso de referencia 1, se recorta el admin primero.

## Revisión de ingeniería (gstack /plan-eng-review) · 2026-10-12
**Alcance:** se acepta tal cual, con la estructura más pequeña (E4). La revisión fue a nivel de plan. No hubo voz externa porque Codex no está instalado.

**Decisiones**

| ID | Decisión | Respuesta |
|---|---|---|
| E1 | Cuota Groq gratis (~100K tokens/día en el 70B, según fuentes de terceros; verificar en la consola) | `llama-3.1-8b-instant` + prompt corto; el 70B solo como respaldo |
| E2 | Mensajes de Realtime (2M/mes gratis) | Conductor libre: cada 30 s a la DB. En viaje: cada 5 s por Broadcast privado |
| E3 | Embeddings de HuggingFace + pgvector | Se eliminan; se usa `pg_trgm` + alias |
| E4 | Estructura del código | `features/rides` reúne despacho, cupos y tramos |
| E5 | Tests SQL | Supabase local + pgTAP en CI |
| E6 | Conflictos offline | El servidor manda + idempotency_key + aviso |

**Arquitectura**
```
 Celular (Flutter)                                  Supabase (gratis)
 ┌───────────────────────────────┐   HTTPS/RPC   ┌──────────────────────────────┐
 │ UI pasajero / conductor / admin│──────────────▶│ Postgres+PostGIS + RLS        │
 │ PlannerService (Dart, D6)      │◀──Broadcast── │  RPC atómicas (D7, E6)        │
 │ drift: grafo, places, corredor │               │  road_reports / trips / legs  │
 │        viaje activo, SyncQueue │──Edge Fn────▶ │ ai-chat ──▶ Groq 8b (E1)      │
 │ google_maps_flutter            │               │ share-page (HTML WhatsApp)    │
 └──────┬─────────────────────────┘               │ wompi-webhook                 │
        │ Places / Routes (cuota diaria)          └──────────────────────────────┘
        ▼
   Google Maps Platform        Sentry (errores)        FCM (push)
```
**Ciclo de la IA (D6 + E1):** el celular envía los mensajes a `ai-chat`. `ai-chat` devuelve las llamadas a herramientas. El celular ejecuta `plan_trip` localmente y reenvía el resultado. `ai-chat` redacta la respuesta. La key nunca sale del servidor. Si Groq responde 429 o falla, el celular muestra el planificador manual (D8).

**Hallazgos**
- [P1] (9/10) `backend/functions/ai-chat/retrieval.ts:67`: los embeddings dependen de la API de HuggingFace, que en el plan gratis tiene arranque en frío. Resuelto con E3.
- [P1] (7/10) Cuota de Groq: el plan original no cabía en el límite diario. Resuelto con E1. Verificar el límite real en console.groq.com.
- [P1] (8/10) Realtime: 20 conductores cada 5 s suman ~3,4M mensajes/mes, más que los 2M gratis. Resuelto con E2.
- [P2] (9/10) `lib/providers/card_provider.dart:45`: hay un canal Realtime por usuario sobre `cards`. Hay que cerrarlo con `ref.onDispose` al migrar, para no gastar conexiones (el plan gratis tiene un tope de 200).
- [P2] (8/10) `test/widget/wallet_test.dart` prueba la billetera mock. Hay que reescribirlo cuando se reemplace `wallet_mock_provider` (Fase 0); si no, CI queda en rojo.
- [P2] (7/10) Ubicación en segundo plano (conductor y compartir viaje): necesita un servicio en primer plano de Android con notificación visible (`geolocator`, configuración foreground). Sin eso, Android corta el GPS al bloquear la pantalla.
- [P2] (7/10) Places Autocomplete cobra por sesión. Para ahorrar: debounce de 300 ms, mínimo 3 letras, session tokens y buscar primero en el directorio propio.
- [P3] (8/10) El grafo en el celular necesita versión: `graph_version` en el servidor; el celular descarga completo solo si cambió. El grafo pesa menos de 1 MB.
- [P3] (8/10) Índices GIST en todas las columnas `geography` nuevas y un índice trigram en `places.name`/`aliases`.

**Mapa de cobertura (propuesto)**
```
CÓDIGO                                    FLUJOS DE USUARIO
[+] PlannerService (Dart)                 [+] Planear viaje puerta a puerta
  ├─ [GAP] enganche origen/destino a nodos   ├─ [GAP][→E2E] 3 casos de referencia
  ├─ [GAP] Dijkstra con penalizaciones       └─ [GAP] Troncal bloqueada → desvío
  └─ [GAP] sin ruta posible → mensaje      [+] Despacho
[+] RPC accept_ride / reserve_seat          ├─ [GAP][→E2E] pedir → aceptar → cerrar → cobrar
  ├─ [GAP] pgTAP: 2 aceptaciones a la vez   └─ [GAP] nadie acepta → timeout → reasignar
  └─ [GAP] pgTAP: último cupo disputado    [+] Offline
[+] RPC close_leg_and_charge                ├─ [GAP] acción offline rechazada → aviso
  ├─ [GAP] pgTAP: idempotency_key repetido  └─ [GAP] reporte duplicado en reintento
  └─ [GAP] saldo insuficiente             [+] Reportes viales
[+] trip state machine (SQL)                ├─ [GAP] confirmación cruzada sube confianza
  └─ [GAP] pgTAP: transición inválida       └─ [GAP] expiración del reporte
[+] ai-chat                                [+] Degradación (D8)
  └─ [GAP][→EVAL] 30 frases → herramienta     ├─ [GAP] Groq 429 → planificador manual
                                             └─ [GAP] Places falla → directorio + pin
EXISTENTE: 6 tests (ai_models, ai_conversation_provider, login, ai_chat, wallet★, widget★)
Por retirar o reescribir: test/widget/wallet_test.dart (mock), test/widget_test.dart (smoke)
```

**Modos de falla críticos (sin rescate hoy):** proyecto Supabase pausado; webhook de Wompi perdido; push no entregado. Cada uno necesita:
- un mensaje visible al usuario;
- un registro en Sentry;
- para Wompi, reconciliación diaria contra su API.

## Revisión de diseño (gstack /plan-design-review) · 2026-10-12
**Calificación:** 5/10 → 9/10. Fue solo texto: el diseñador visual de gstack necesita una API key de OpenAI que esta sesión no tiene. No hubo segunda opinión (el usuario la declinó).

| ID | Pasada | Decisión |
|---|---|---|
| DS1 | Arquitectura de información (6→9) | Inicio: corredor → ¿A dónde vas? → mapa |
| DS2 | Estados (2→9) | Tabla completa de estados (abajo) |
| DS3 | Recorrido (5→9) | Modo invitado; la cuenta se pide al actuar |
| DS4 | Riesgo de diseño genérico (5→8) | ~~Atkinson Hyperlegible Next~~ → reemplazada el 2026-10-12 por el mundo "Rótulo de colectivo" (Barlow + Barlow Condensed) |
| DS5 | Sistema de diseño (2→8) | `DESIGN.md` único + `/design-consultation` |
| DS6 | Accesibilidad (4→9) | Modo conductor de una mano |
| DS7 | Accesibilidad | Texto 200%, contraste 7:1, TalkBack, color+ícono |
| DS8 | Sin resolver | Tuteo cercano, corto y local |

**Pantalla de inicio (pasajero)**
```
┌──────────────────────────────────────┐
│ ● Troncal Riohacha–Maicao: ABIERTA   │  1. Estado del corredor (ícono+texto+color)
│   Actualizado hace 4 min · 12 reportes│
├──────────────────────────────────────┤
│                                      │
│          [ mapa Google, gestos ]     │  3. Mapa de fondo
│      ┌──────────────────────────┐    │
│      │ 🔍 ¿A dónde vas?          │    │  2. Acción principal
│      └──────────────────────────┘    │
│        Casa · Trabajo · Recientes    │
├──────────────────────────────────────┤
│ Inicio  Viaje  Reportar  Billetera  Yo│  Navegación (5 destinos)
└──────────────────────────────────────┘
```

**Tabla de estados (DS2)**

| Función | Cargando | Vacío | Error | Éxito | Parcial | Sin señal |
|---|---|---|---|---|---|---|
| Estado del corredor | Franja con el último estado guardado + "actualizando" | "Sin reportes hoy en la Troncal" + botón Reportar | Último estado + "No pudimos actualizar" | Estado + hora + nº de reportes | Tramo sin datos: "Sin información del km X" | Último estado con su hora, en gris |
| Buscar lugar | Resultados del directorio al instante; Google aparece debajo | "No encontramos 'X'. Fija el punto en el mapa" + botón pin | Solo directorio + pin (D8) | Lista con referencia y barrio | Solo directorio | Solo directorio local + pin |
| Planear viaje | Esqueleto de tramos (no un spinner) | "No hay ruta posible ahora" + motivo (bloqueo, hora) + alternativa | Mensaje claro + botón reintentar | Itinerario: tiempo, rango de precio y tramos | Ruta con un tramo "sin dato de tarifa" | Planifica con el grafo local; avisa la fecha de los datos |
| Pedir mototaxi | "Buscando conductor…" con radio en el mapa y botón cancelar | "Nadie disponible a 2 km. Te avisamos" + "Ver colectivos" | "No se pudo enviar. Reintentar" | Conductor, placa, foto y llegada | Contraoferta: aceptar o rechazar | Botón deshabilitado + "Necesitas señal para pedir" |
| Viaje en curso | — | — | Tramo fallido → replaneo sugerido | Tramo cerrado + recibo | Esperando despacho del colectivo: rango de salida | Estado local + "Se sincroniza al volver la señal" |
| Billetera | Saldo guardado + "actualizando" | "Aún no tienes movimientos" + Recargar | "Recarga no confirmada. Te avisamos" | Saldo + movimientos | Recarga pendiente marcada | Saldo guardado con su hora |
| Reportar | Envío optimista | — | "Guardado; se enviará luego" | "Gracias. 2 personas más lo confirmaron" | Reporte sin confirmar | En cola, con ícono de reloj |

**Recorrido (storyboard)**

| Paso | Qué hace el usuario | Qué siente | Qué lo resuelve |
|---|---|---|---|
| 1 | Abre un link de WhatsApp: "bloqueo km 42" | Duda: ¿es verdad? | Página web con hora, confirmaciones y mapa, sin instalar |
| 2 | Instala y abre la app | Impaciencia | Sin registro: ve el corredor en 1 s (DS3) |
| 3 | Escribe "al Palacio de Justicia de Maicao" | Esperanza | Itinerario con desvío, tiempo y rango de precio |
| 4 | Pide mototaxi al terminal | Ahora sí confía | La cuenta se pide aquí, en 1 paso |
| 5 | Viaja por el corredor | Inseguridad | Compartir viaje + SOS siempre visibles |
| 6 | Llega y paga | Alivio | Recibo único con el desglose de tramos |

**No entra en esta revisión:** mockups visuales (sin API key) y la paleta exacta, que se define con `/design-consultation` en la Fase 2.

## GSTACK REVIEW REPORT
| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---|---|---|
| CEO | /plan-ceo-review | Alcance y estrategia | 1 | issues_open | D1–D8 tomadas; errores de la sección 2 por definir en la implementación |
| Eng | /plan-eng-review | Arquitectura y tests | 1 | clean | 9 hallazgos; E1–E6 tomadas |
| Design | /plan-design-review | UI/UX | 1 | clean | 5/10 → 9/10; DS1–DS8 tomadas; mockups pendientes (sin API key) |
| Outside voice | codex | Segunda opinión | 0 | unavailable | Codex no instalado |

VERDICT: plan listo para empezar la Fase 0; correr /design-consultation al inicio de la Fase 2.

NO UNRESOLVED DECISIONS
