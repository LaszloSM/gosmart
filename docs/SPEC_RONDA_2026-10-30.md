# Spec — Ronda 2026-10-30

Acordado con el usuario en una ronda de preguntas. Estado: **borrador para revisión**;
no se implementa nada hasta que el usuario lo apruebe.

Skills para la parte visual: `impeccable` (proceso, `reference/craft-floor.md`, reglas Android),
`emil-design-eng` + `animate` + `review-animations` (cámara y pines), `taste-skill` (estados completos).

---

## 1. Direcciones exactas (Plaza Almirante Padilla y demás) — HECHO

**Implementado (2026-10-30):**
- `placeSearch.resolve` ubica con Google todo lugar del directorio sin verificar ("<nombre>, <ciudad>",
  máx. 3 km del punto de la semilla); el aproximado solo queda si Google no responde.
- Segundo fallo encontrado y arreglado: el planificador se saltaba `resolve` si la sugerencia ya traía
  coordenadas (las del directorio), así que usaba el punto aproximado directamente.
- Pantalla `PlaceConfirmScreen` (`/routes/confirm`): pin fijo al centro, el mapa se mueve debajo; al
  soltar busca la dirección del punto nuevo. Se usa al elegir destino y al guardar Casa/Trabajo.
- Semilla: alias "plaza almirante padilla", "plaza padilla", "parque jose prudencio padilla",
  "plaza principal"; re-ejecutarla suma alias a las filas de la semilla. Prueba SQL 1b.
- `tool/verify_places.py` + workflow manual "Verificar lugares": compara la semilla con Google Places.
  Desde este contenedor no se pudo (OSM y Google sin clave bloqueados), así que **ninguna fila se marcó
  verificada todavía**.
- Pendiente del usuario: correr "Verificar lugares" y probar en el celular con Google Maps real.


**Problema encontrado en el código.** `LayeredPlaceSearch` pone el directorio propio (`places`)
antes que Google, e `isSamePlace` descarta la sugerencia de Google si tiene nombre parecido y está
a menos de 150 m. Los 12 lugares de `supabase/seed/places_seed.sql` tienen coordenadas
aproximadas (`verified = false`). Resultado: al elegir "Parque Almirante Padilla" gana el punto
aproximado y el pin cae en otro sitio. Le puede pasar a cualquier lugar de la semilla.

**Decisión: enfoque combinado.**

1. **Google manda en las coordenadas.** Cuando un lugar del directorio y uno de Google son el mismo,
   se queda la sugerencia de Google (coordenadas al resolver) y el nombre del directorio solo sirve como
   alias que ayuda a encontrarlo. Un lugar del directorio sin `verified` nunca reemplaza a Google.
2. **Alias locales.** Si la gente escribe "la plaza", el directorio traduce el alias a una consulta
   para Google ("Parque José Prudencio Padilla, Riohacha") y se usa el resultado de Google.
   Solo si Google no responde (`limited`) se usa la coordenada del directorio, marcada "aprox.".
3. **Verificar la semilla.** Revisar las 12 coordenadas una por una contra Google Places/OSM;
   marcar `verified = true` solo las comprobadas. Las que no se puedan verificar se quedan "aprox.".
4. **Pin de confirmación.** Al elegir un destino u origen, el mapa centra un pin que se puede
   arrastrar ("Ajusta el punto si hace falta" → "Confirmar"). Si el lugar es "aprox." el aviso es
   más visible.

**Criterios de aceptación**
- "Plaza Almirante Padilla", "Parque Padilla" y "la plaza" terminan en el parque real (± 30 m).
- Prueba unitaria: el directorio aproximado no pisa a Google; sin Google se usa el directorio con "aprox.".
- Sin red o sin clave: el buscador sigue funcionando con el directorio y lo avisa (D8).

## 2. Fluidez del mapa

**Síntomas reportados:** arrastrar y hacer zoom se traba; los movimientos automáticos de cámara
son bruscos.

**Sospecha a confirmar.** `map_view.dart` recalcula el tamaño de los pines en `onCameraMove` (cada cuadro)
y puede reconstruir el conjunto de marcadores mientras el dedo mueve el mapa.

**Plan**
- Cambiar el tamaño de los pines solo en `onCameraIdle` (o al cruzar un umbral, con histéresis), nunca por cuadro.
- Hacer caché de los `BitmapDescriptor` por tipo × tamaño; crear los `Set<Marker>`/polilíneas solo cuando
  cambian los datos (memoizados), no en cada `build`.
- Evitar `setState`/`ref.watch` que reconstruyan el `GoogleMap` mientras se mueve.
- Cámara: `animateCamera` con duraciones coherentes (`GSDuration`), sin saltos encadenados; respetar
  `disableAnimations`.
- Medir antes y después con el perfil de rendimiento (`flutter run --profile`) en el celular del usuario:
  el usuario lo prueba, porque aquí no hay dispositivo.

**Criterio:** arrastrar y hacer zoom sin saltos visibles en un Android de gama media; sin reconstrucciones
del mapa durante el gesto (comprobado con contadores en una prueba de widget).

## 3. Alertas en el mapa (estilo Waze)

**Problema reportado:** al alejar el mapa los pines siguen viéndose grandes; debería comportarse como Waze.

**Plan**
- Escala por zoom con umbrales revisados: lejos → punto pequeño o se oculta (en zoom de ciudad completa
  o menos); medio → ícono compacto; cerca → globo completo. Ajustar los cortes de `alertPinSizeFor`
  en el celular.
- Agrupar alertas cercanas cuando se amontonan (un globo con número) en zoom medio/lejano.
- La transición de tamaño se aplica al detenerse la cámara (ver punto 2), no durante el gesto.

**Criterio:** con el mapa alejado a la vista de Riohacha completa, las alertas no tapan calles; con zoom de
barrio se ven los globos completos.

## 4. Repetir viaje

**Decisión:** botón "Repetir" en cada viaje de **Viajes recientes** (pestaña Viaje), con el **mismo
origen y destino exactos**, como en Uber o InDrive.

**Lo que falta hoy.** `chained_trips` solo guarda `origin_label` y `dest_label` (texto), sin coordenadas.

**Plan**
- Migración nueva: `chained_trips.origin_lat/lng`, `dest_lat/lng` (nullable). `create_trip` las guarda.
  `recentTrips` las devuelve. Regenerar `piloto_bundle.sql`.
- "Repetir" abre el planificador con origen y destino ya puestos y calcula las opciones; la persona solo
  confirma. Si el tramo era mototaxi, se sugiere la tarifa ofrecida la vez anterior (editable).
- Viajes viejos sin coordenadas: "Repetir" busca por nombre y pide confirmar el punto (pin del punto 1).
- Se puede repetir un viaje completado o cancelado.

**Criterio:** del historial al planificador con las mismas opciones en 1 toque; prueba SQL de las columnas
nuevas; prueba de widget del botón.

## 5. Subir foto de perfil

**Problema encontrado.** `profile_service.dart` sube a un bucket `avatars` que **ninguna migración crea**.

**Plan**
- Migración: bucket `avatars` público solo de lectura; políticas para que cada usuario escriba y borre
  solo `"<su uid>/…"`.
- Comprimir y recortar antes de subir (máx. ~512 px, JPEG); evitar caché vieja con `?v=<timestamp>` en la URL.
- Estados completos: subiendo (progreso en el avatar), error con reintento, permiso de cámara/galería denegado.

**Criterio:** subir, cambiar y ver la foto tras reiniciar la app; otro usuario no puede sobrescribirla
(prueba SQL de políticas).

## 6. Recorrido de punta a punta: mototaxi/colectivo y pagos/billetera

El usuario no lo ha probado a fondo y pide que lo recorra yo y **arregle o complete lo que falte**.

**Mototaxi / colectivo** (`RideLegPanel`, `dispatchService`, RPC de 015/022):
pedir → ofertas → aceptar → conductor llegando → en viaje → pagar → calificar, en ambos lados
(pasajero y conductor), además de la reserva de puesto en colectivo y la cancelación.

**Pagos / billetera** (016): recarga simulada, `pay_ride` con saldo y en efectivo (`confirm_cash`),
QR de cobro (`create_charge` → `pay_charge`), recibo, saldo y movimientos actualizados.

**Cómo**
- Pruebas SQL nuevas de punta a punta en `supabase/tests/` (Postgres 16 de CI) que encadenan las RPC
  del flujo completo con dos usuarios (pasajero y conductor).
- Pruebas de widget de cada fase con `preview:` / datos simulados.
- Registro de hallazgos: cada falla encontrada con su arreglo y su prueba.

**Límite honesto:** aquí no hay celular ni Supabase real. Lo que dependa del dispositivo (GPS, cámara
para QR, Google Maps real) queda listado para que el usuario lo pruebe.

---

## Orden de trabajo propuesto

1. Direcciones exactas (1): es lo más grave, porque afecta todas las rutas.
2. Subir foto (5): arreglo corto y claro.
3. Fluidez del mapa + alertas (2 y 3): comparten la causa.
4. Repetir viaje (4): necesita una migración.
5. Recorrido de mototaxi y pagos (6).

Todo en una rama, con `flutter analyze`, `flutter test`, las pruebas SQL y las capturas
de `tool/screenshots` en verde antes de pedir PR.

## Fuentes consultadas

- Duración de las alertas de Waze (unos 60 min; "Ya no está" las quita). Son foros y wiki
  comunitaria, no hay regla oficial:
  [Wazeopedia](https://wazeopedia.waze.com/wiki/Commons/User:Imper1um/Overhaul/User_Manual/Waze_Client/Waze_Map/Reporting_Live_Issues),
  [foro Waze](https://www.waze.com/discuss/t/newbie-how-long-do-reported-hazards-remain-on-map/64592).
- Caché de bitmaps de marcadores en `google_maps_flutter`:
  [map_marker_cache](https://pub.dev/packages/map_marker_cache),
  [marker_widget](https://pub.dev/packages/marker_widget/versions/2.0.1/changelog).
- Parque José Prudencio Padilla (nombre oficial de la plaza):
  [Lonely Planet](https://www.nonprod.lonelyplanet.com/points-of-interest/parque-jose-prudencio-padilla/1585778).
