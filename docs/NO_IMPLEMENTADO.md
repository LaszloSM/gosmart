# Lo que no se implementó · 2026-10-12

Dos grupos: lo que el plan ya dejaba por fuera (decisiones), y lo que se quedó corto en esta
construcción. Cada punto dice por qué y qué haría falta.

## Fuera del alcance por decisión

| Qué | Por qué | Qué haría falta |
|---|---|---|
| Tap to Pay bancario y NFC entre celulares (D3) | Exige certificación con adquirentes | Alianza con un adquirente; la tabla `cards` y `backend/functions/authorize` quedan para los validadores de transporte público |
| Pago único con retención (D5) | Retener dinero de terceros exige figura regulada (Superfinanciera) | Aliado vigilado (p. ej. una SEDPE). Hoy cada tramo se paga al cerrarse |
| Dinero real en custodia | Mismo motivo | Igual que arriba; hoy el saldo es de prueba |
| Modo SMS para conductores sin smartphone | Requiere pasarela SMS de pago | Proveedor SMS + parser de comandos |
| Wayuunaiki | Debe hacerse con la comunidad, no traducido a máquina | Trabajo con traductores wayuu |
| Integración formal con empresas de transporte | Depende de acuerdos | Convenios y una API para horarios |
| Otros municipios | Alcance del MVP | Cargar tramos, lugares y grafo de cada municipio |
| HCE en iOS | Restricciones de Apple | Programa de Apple para NFC |

## Se quedó corto en esta construcción

| Qué | Estado | Qué falta |
|---|---|---|
| **Push (FCM)** | No hecho | Proyecto Firebase, `google-services.json`, `firebase_messaging`, tabla de tokens y una Edge Function que envíe: solicitudes al conductor con la app cerrada, alertas de vía a quien tiene un viaje que cruza un tramo afectado |
| Datos de campo (Fase 1) | Semilla aproximada | Levantar 300+ lugares por ciudad, tramos de la Troncal, rutas de TransPadilla, tarifas reales y tiempos de llenado de colectivos |
| Responsable y contacto en la política de datos | `[PENDIENTE]` visible | Nombre o razón social, correo, revisión de un abogado |
| drift (SQLite) para offline | Se usó SharedPreferences | Solo si el volumen crece (miles de lugares) |
| Places Autocomplete y Routes API de Google | El buscador usa directorio + Mapbox | Pasar `ProviderPlaceSearch` a Places y el trazado calle a calle a Routes, con cuotas diarias |
| Realtime en lugar de consultas cada 4–5 s | Consultas periódicas | Canales de Supabase Realtime en solicitudes y viajes |
| Replaneo automático ante un tramo fallido | Manual (cancelar y planear de nuevo) | Al marcar `failed`, planear desde la posición actual y añadir tramos |
| Historial del conductor en PDF | No hecho | Generar PDF de `leg_payments` del conductor |
| Voz en el asistente | No hecho | `speech_to_text` |
| Predicción de despacho por histórico | No hecho | Usar reservas y llenado histórico de `colectivo_departures` |
| Editar rutas, tarifas y lugares en el panel | Se hace en Supabase | Formularios en `/admin` |
| Avisos oficiales del concesionario | No hecho | Fuente oficial y una tarea que los cargue como reportes de admin |
| Página web pública con límite de peticiones | Usa la anon key directa | Si crece el tráfico, pasar por una Edge Function con límite |
