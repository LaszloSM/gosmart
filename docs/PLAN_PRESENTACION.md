# Plan a la presentación · 12 días (7 al 18 de noviembre de 2026)

Meta: presentar GoSmart funcionando de verdad, con un pasajero y un conductor reales,
sin nada simulado. Pagos en efectivo. Todo lo que dice "tú" lo hace Laszlo; lo de
código ya está en la rama `claude/busy-albattani-26cf1n`.

## Días 1–2 (7–8 nov) · Dejar el servidor real

- [ ] Fusionar la rama a `main` (PR) cuando el CI esté verde.
- [ ] Google Cloud: subir las **cuotas diarias** de *Routes API (ComputeRoutes)* y
      *Places API (New)*. El CI del 30 de octubre mostró `RESOURCE_EXHAUSTED`: por eso las
      rutas salían rectas. Con el crédito mensual de Google no se paga en un piloto.
- [ ] Crear una clave solo para el servidor (Routes + Places, sin restricción de app) y
      guardarla en GitHub como `GOOGLE_MAPS_SERVER_KEY`.
- [ ] Actions → *Supabase deploy* (aplica `025_mvp_real.sql`, copia secrets, despliega `maps`).
- [ ] En el registro del job "Build APK", buscar `Edge Function maps → ruta: … ok (ruta)`.
- [ ] Firebase (push): proyecto, `GOOGLE_SERVICES_JSON`, `FCM_SERVICE_ACCOUNT`,
      `PUSH_WEBHOOK_SECRET`; volver a correr *Supabase deploy*. Sin esto, un conductor con la
      app cerrada no se entera de pedidos (con la app abierta sí).

## Días 3–4 (9–10 nov) · Cuentas reales

- [ ] Tu cuenta como admin (input `admin_email` del deploy).
- [ ] 2 a 3 conductores reales (amigos, familia o mototaxistas conocidos) se registran
      desde la app, suben documentos y los apruebas en `/admin`.
- [ ] Revisar `/admin` → Ajustes: *Despacho* encendido; *Pagos con saldo (Wompi)* apagado.

## Días 5–8 (11–14 nov) · Prueba de campo en Riohacha

Con dos celulares (uno pasajero, uno conductor), 10 viajes cortos:
- [ ] Pedir mototaxi → ofertas → aceptar → llega → recoge → termina → paga en efectivo →
      el conductor confirma el efectivo → los dos califican.
- [ ] Cancelar antes de que acepten (solo confirma) y después (pide motivo). Ver el motivo en
      `/admin` → Métricas.
- [ ] Conductor conectado con la pantalla apagada 5 minutos: su punto debe seguir moviéndose
      en el celular del pasajero.
- [ ] GPS apagado, permiso negado, bajo techo: la app dice qué falta y el botón lo arregla.
- [ ] Rutas por la vía en mototaxi, taxi, colectivo, TransPadilla e intermunicipal.
- [ ] Guardar 3 lugares con nombre y pedir un viaje desde uno.
- [ ] Ver el historial y abrir un recibo.
- [ ] Anotar cada falla con captura y mandármela: la corrijo en el día.

## Días 9–10 (15–16 nov) · Correcciones y APK final

- [ ] Correcciones de la prueba de campo.
- [ ] APK de release del CI instalado en los dos celulares de la presentación.
- [ ] Capturas para las diapositivas (`flutter test tool/screenshots/review_shots_test.dart`).

## Días 11–12 (17–18 nov) · Ensayo y presentación

- [ ] Ensayar el guion de abajo dos veces, una con datos móviles (no solo wifi).
- [ ] Plan B: video grabado del recorrido completo por si falla la señal en el salón.

## Guion de la demo (8 minutos, dos celulares)

1. **Inicio (pasajero).** Mapa con tu punto azul; bajar la hoja para ver el mapa entero,
   subirla para los servicios. Alertas de la vía como en Waze.
2. **Planear.** "¿A dónde vas?" → un lugar guardado → la ruta sale por la vía, con precio
   sugerido.
3. **Pedir mototaxi.** Propones tarifa; en el otro celular (conductor conectado) llega la
   solicitud; el conductor acepta o contraoferta; en el pasajero aparece **al instante**.
4. **El viaje.** El conductor se mueve en el mapa del pasajero con hora de llegada.
5. **Cancelar (opcional).** Mostrar que pide motivo cuando ya aceptaron.
6. **Pagar.** Efectivo; el conductor confirma; los dos califican; recibo en el historial.
7. **Admin.** Conductores verificados, reportes, métricas y cancelaciones por motivo.
8. **Cierre.** Lo que viene: pagos digitales con Wompi, tarjeta de transporte universal.

## Lo que hay que decir con honestidad si preguntan

- Pagos: en efectivo por ahora; los digitales requieren un aliado vigilado por la
  Superfinanciera para guardar dinero de terceros.
- Datos de la vía, lugares y tarifas de colectivo: semilla aproximada, se afinan en campo.
- Notificaciones con la app cerrada: dependen de Firebase (paso de los días 1–2).
