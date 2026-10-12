# Preparación del piloto · Riohacha – Maicao

Lista para pasar de "compila y pasa pruebas" a "funciona en la calle". En orden.

## 1. Backend (una tarde)

1. En el SQL Editor de Supabase, correr en orden: `008`, `009`, `010`, `011`, `012`, `013`,
   `014`, `015`, `016`, `017` (todas son seguras de re-ejecutar).
2. Revisar que existe el bucket privado `driver-docs` (lo crea `011` si hay `storage`).
3. Nombrar el primer admin:
   `UPDATE profiles SET role = 'admin' WHERE id = '<uuid de tu usuario>';`
4. Secrets de Edge Functions: `GROQ_API_KEY`; para recargas reales en sandbox:
   `WOMPI_PUBLIC_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET`.
5. Desplegar: `npx supabase functions deploy ai-chat --no-verify-jwt`,
   `npx supabase functions deploy wompi --no-verify-jwt`, `delete-account`.
6. En Wompi (sandbox), la URL de eventos apunta a `https://<ref>.supabase.co/functions/v1/wompi`.
   Activar `wompi_enabled` en `/admin → Ajustes` solo después de una recarga de prueba exitosa.

## 2. Páginas públicas (15 minutos)

1. GitHub → Settings → Pages → fuente "GitHub Actions".
2. Secrets del repo: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
3. Correr el workflow "Public web". Poner la URL en `.env` como `SHARE_BASE_URL`.
4. Abrir `via.html` en un teléfono sin la app.

## 3. App

1. `.env` con `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_API_KEY` (restringida al paquete
   y a la huella SHA-1 de la app), `SHARE_BASE_URL`, `SENTRY_DSN` opcional.
2. En Google Cloud, cuotas diarias para Maps SDK (y Places/Routes cuando se usen).
3. `flutter build apk --release` con firma propia (hoy firma con la llave de depuración).
4. Cambiar `applicationId` (`com.example.gosmart`) antes de subir a Play.
5. Track de prueba interna en Google Play.

## 4. Datos de campo (Fase 1, lo más importante)

- Verificar en sitio cada lugar de la semilla y marcar `verified = true`.
- Medir los tramos de la Troncal (km reales y puntos) y corregir `road_segments`.
- Cargar el grafo real: paraderos de TransPadilla, puntos de colectivos, terminales,
  tiempos y tarifas por franja. Al cambiarlo, actualizar `test/planner/fixture_graph.dart`.
- Tarifas de mototaxi y taxi por zona en `fare_rules`.

## 5. Conductores

- Reclutar 10–20 en campo (mototaxi en Riohacha, colectivos en la Troncal).
- Aprobar desde `/admin` revisando documentos.
- Explicar que, sin push, deben tener la pantalla "Modo conductor" abierta para recibir viajes.

## 6. Pruebas en la calle (antes de abrir a más gente)

- Los 3 casos de referencia con dos teléfonos (pasajero y conductor).
- Un choque de despacho a propósito: dos conductores aceptando a la vez.
- Modo avión a mitad del viaje: reportar, pedir ayuda y volver a la señal.
- SOS real a un contacto de prueba, y el link de viaje abierto en otro teléfono.
- Gestos del mapa en un Android de gama media al sol.

## 7. Qué medir (en `/admin → Métricas`)

- Éxito del despacho (aceptados / pedidos) y segundos hasta aceptar.
- Reportes viales: cuántos, cuántos confirmados y minutos hasta la primera confirmación.
- Acierto del buscador: anotar en campo cuántas búsquedas encontraron el lugar a la primera.
- Avisos de ayuda (SOS) — cada uno se revisa a mano.

## Si algo falla en el piloto

- Despacho: `/admin → Ajustes → Despacho` lo apaga sin publicar una versión nueva.
- Recargas: apagar `wompi_enabled`; vuelve la recarga simulada.
- Un reporte vial falso: `/admin → Reportes → Quitar`.
