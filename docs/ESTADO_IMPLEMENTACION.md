# Estado de la implementación · 2026-10-12

Qué quedó hecho de cada fase de `PLAN_MVP_GUAJIRA.md`, cómo se verificó y qué **no** se
pudo verificar. Escrito para la sustentación: aquí no se exagera nada.

## Cómo se verificó

| Qué | Dónde | Resultado |
|---|---|---|
| `flutter analyze` | local y CI | sin avisos |
| `flutter test` (122 pruebas) | local y CI | en verde |
| Pruebas SQL (migraciones 010–017, cada una aplicada dos veces) | Postgres 16 local y CI | en verde |
| Carrera real D7 (dos conexiones a la vez) | `supabase/tests/015_race_test.sh`, local y CI | un solo ganador |
| Edge Functions (`ai-chat`, `wompi`) | `deno test` + `deno check`, CI | en verde |
| APK de Android | CI (`build-android`) | compila desde el arreglo de Sentry 9 |
| Flutter Web (panel admin) | `flutter build web`, local | compila |
| Páginas públicas (`via.html`, `viaje.html`) | Chromium sin pantalla, datos simulados | se ven bien de día y de noche |

## Lo que NO se ha verificado (y por qué)

- **La app en un teléfono real.** El entorno no tiene emulador ni dispositivo. Nadie ha tocado
  todavía los gestos del mapa, la cámara del QR ni el SOS en un Android de gama media.
- **Supabase real.** Las migraciones 011–017 se probaron en un Postgres local con un stub de
  Supabase (`_supabase_stub.sql`, `_profiles_fixture.sql`). En el proyecto real hay que
  correrlas en orden y revisar: el bucket `driver-docs`, las políticas de Storage y
  `NOTIFY pgrst`.
- **Google Maps.** El código está (`MapView`), pero sin clave no se ha visto un mapa de Google;
  el estilo nocturno no se ha mirado en pantalla.
- **Groq con herramientas.** El ciclo `plan_trip` se probó por partes (servidor sin red,
  cliente con dobles de prueba). No se ha hecho una conversación real con Groq.
- **Wompi.** Las firmas siguen la documentación pública y tienen pruebas, pero no se probaron
  contra el sandbox (sin llaves ni red hacia Wompi desde aquí).
- **Datos de campo.** Lugares, tramos de la Troncal, grafo de transporte y tarifas son una
  SEMILLA APROXIMADA (`verified=false`). La Fase 1 (levantamiento) no se ha hecho.
- **Push (FCM).** El código está (018, `lib/core/push.dart`, Edge Function `push`) y la firma
  del JWT tiene prueba, pero no hay proyecto de Firebase: no se ha enviado ninguna notificación
  real. Sin `google-services.json` la app funciona igual, sin push.

## Fase por fase

### Fase 0 · Limpieza — hecha
Migraciones unificadas, billetera única contra Supabase (010), Groq fuera del APK, Stripe
retirado, Bogotá/Medellín reemplazados, pantallas grandes partidas, Sentry opcional.

### Fase 1 · Campo y datos — **no hecha** (requiere trabajo de campo)
Hay tablas listas para recibir los datos (`places`, `road_segments`, `graph_nodes`,
`graph_edges`, `fare_rules`) y el panel admin para corregirlos. Faltan los datos reales.

### Fase 2 · Rediseño — hecha
Mundo "Rótulo de colectivo", día y noche, revisado con impeccable y Emil Kowalski.
El mapa nocturno de Google quedó como estilo JSON, sin verlo en pantalla.

### Fase 3 · Núcleo — hecha (push sin probar en vivo)
| Parte | Estado |
|---|---|
| Roles y conductor (011) | hecho; nadie se sube de rol solo |
| Registro de conductor y documentos | hecho; fotos al bucket privado |
| Contactos de emergencia, SOS, compartir viaje | hecho; el aviso sale del teléfono |
| Legal (Ley 1581, términos, eliminar cuenta) | borrador con `[PENDIENTE]` visible: falta responsable y correo |
| Buscador en capas (directorio → proveedor → pin) | hecho, con aviso de búsqueda limitada (D8) |
| Offline | cola de envíos (`SyncQueue`) y copia local del corredor y del grafo. **Sin drift**: se usó SharedPreferences (menos código, sin generación) |
| Google Maps | hecho detrás de `MapView`; sin verificar en teléfono |
| Push FCM | código listo y opcional; falta proyecto de Firebase para probarlo |
| Manifiesto | cámara, notificaciones, queries de url_launcher. Sin ubicación en segundo plano (a propósito) |

### Fase 4 · Estado del corredor — hecha
Reportes de tipo cerrado sin texto libre, confirmación cruzada con reputación, límite por
usuario, estado público, patrones, compartir a WhatsApp y `via.html`. Alerta push a viajeros
en la Troncal (sin probar en vivo).

### Fase 5 · Planificador + IA — hecha
Planificador en el celular (Dijkstra, enganche puerta a puerta, bloqueos y noche), tarifa
justa como rango, los 3 casos de referencia en pruebas, IA con herramientas (`plan_trip` corre
en el celular). Pendiente: voz (`speech_to_text`) y predicción de despacho por histórico.

### Fase 6 · Conductor + viaje encadenado — hecha
Despacho estilo InDrive con aceptación atómica (D7, probada con carrera real), contraofertas,
colectivos con cupos, viaje encadenado con máquina de estados en SQL, interruptor del despacho.
Las pantallas consultan cada 4–5 s mientras están abiertas (no hay push ni Realtime aún).
Pendiente: replaneo automático ante un tramo fallido; exportar el historial del conductor a PDF.

### Fase 7 · Pago — hecha (sandbox)
Pago por tramo con saldo, QR del conductor o efectivo confirmado; recibo único por viaje (D5);
recargas Wompi sandbox detrás de un interruptor. El dinero sigue siendo de prueba.

### Fase 8 · Confianza + admin — hecha
Calificaciones en las dos direcciones, bloqueo por dos impagos confirmados, reputación del
reportante, panel `/admin` (conductores con documentos, moderación, métricas, interruptores).
Pendiente: editar rutas, tarifas y lugares desde el panel (hoy se hace en Supabase).

### Fase 9 · Piloto — preparado, no ejecutado
Ver `PILOTO.md` y `NO_IMPLEMENTADO.md`.
