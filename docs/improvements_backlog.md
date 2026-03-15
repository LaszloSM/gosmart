# GoSmart — Improvements Backlog
> Generado: 2026-03-14 | Revisión de código (video no disponible en filesystem)
> Agentes responsables: architecture-transformer · premium-ui-designer · llm-integration-specialist

---

## Prioridad CRÍTICA (bloquean funcionalidad real en demo)

### #1 🔴 [BUG] Card provider query rompe UI al bloquear tarjeta
**Agente:** architecture-transformer
**Archivo:** `lib/providers/card_provider.dart:29`
**Descripción:** La query filtra `.eq('status', 'active')`. Al bloquear la tarjeta (status → 'locked'), el provider devuelve `null`. La wallet muestra `$0 COP` y la tarjeta aparece como "desbloqueada" porque `card?.isLocked ?? false = false`. El lock toggle **no funciona visualmente**.
**Por qué importa:** El jurado verá que bloquear la tarjeta parece no hacer nada.
**Criterio de aceptación:** Después de bloquear, la tarjeta muestra `BLOQUEADA` con fondo gris. Al desbloquear, vuelve al gradiente azul-violeta.
**Fix:** `.eq('status', 'active')` → `.neq('status', 'cancelled')`
**Estado:** ✅ APLICADO en este ciclo

---

### #2 🔴 [BUG] Botón "Pagar" en Wallet no hace nada
**Agente:** architecture-transformer
**Archivo:** `lib/features/wallet/wallet_screen.dart:363`
**Descripción:** `onTap: () {}` — el CTA más importante de la pantalla de billetera está muerto. Un usuario que intenta pagar no recibe feedback ni navegación.
**Por qué importa:** Es el flujo central del prototipo (pago NFC). Crítico para demo.
**Criterio de aceptación:** Tapping "Pagar" navega a `PaymentValidationScreen` que ejecuta la autorización real.
**Fix:** `onTap: () => context.push(AppRoutes.paymentValidation)`
**Estado:** ✅ APLICADO en este ciclo

---

### #3 🔴 [BUG] PaymentValidationScreen simula con `Future.delayed` en lugar de llamar al Edge Function
**Agente:** architecture-transformer + llm-integration-specialist
**Archivo:** `lib/features/payment/payment_validation_screen.dart:36-42`
**Descripción:** `_simulateValidation()` solo espera 3 segundos y siempre retorna `authorized`. No llama a `cardService.authorize()`. El jurado puede ver "AUTORIZADO" incluso con saldo $0.
**Por qué importa:** Toda la lógica de autorización (Edge Function + RLS) está implementada pero nunca se llama desde el flujo de pago principal.
**Criterio de aceptación:** Tras pulsar "Pagar", la pantalla llama al Edge Function `authorize`, y mapea `AuthorizeStatus` → estado visual correcto (`authorized`/`insufficient`/`error`).
**Fix:** Convertir a ConsumerStatefulWidget + llamar `cardService.authorize()` en `initState`.
**Estado:** ✅ APLICADO en este ciclo

---

## Prioridad ALTA (visibles en demo, impacto UX notable)

### #4 🟠 Avatar estático en Home + Profile no muestra foto real
**Agente:** premium-ui-designer
**Archivos:** `lib/features/home/home_screen.dart:201`, `lib/features/profile/profile_screen.dart:373`
**Descripción:** El avatar en Home siempre es un icono genérico aunque el profile tenga `avatarUrl`. La pantalla de Perfil sí usa `avatarUrl`, pero Home no.
**Criterio de aceptación:** El CircleAvatar en la top bar del Home carga `profileAsync.valueOrNull?.avatarUrl` igual que Profile.

### #5 🟠 Saludo en Home no varía por hora del día
**Agente:** premium-ui-designer
**Archivo:** `lib/features/home/home_screen.dart:215`
**Descripción:** Siempre muestra "Hola 👋". Aplicaciones como Uber muestran "Buenos días", "Buenas tardes", etc.
**Criterio de aceptación:** `_greeting()` helper retorna saludo según `DateTime.now().hour`.

### #6 🟠 NFC Simulator no es accesible desde UI principal
**Agente:** architecture-transformer
**Archivo:** `lib/features/wallet/wallet_screen.dart`, `lib/features/profile/profile_screen.dart`
**Descripción:** La ruta `/debug/nfc-simulator` existe pero ningún botón/tile navega a ella. Para demostraciones el evaluador necesita acceder.
**Criterio de aceptación:** Un tile "Simulador NFC (Debug)" en la sección "Soporte" de Profile Screen navega a la pantalla.

### #7 🟠 Demo switcher visible en PaymentValidation en producción
**Agente:** premium-ui-designer
**Archivo:** `lib/features/payment/payment_validation_screen.dart:54`
**Descripción:** `if (true) _DemoSwitcher(...)` — el switcher de estados siempre visible. Con el real authorize conectado, esto debe ocultarse o convertirse en un menú de debug accesible solo vía variable de entorno.
**Criterio de aceptación:** `_DemoSwitcher` oculto en release, visible solo si `kDebugMode == true`.

---

## Prioridad MEDIA (polish y completitud para entrega)

### #8 🟡 Recharge button muestra snackbar "próximamente"
**Agente:** llm-integration-specialist
**Archivo:** `lib/features/wallet/wallet_screen.dart:62`
**Descripción:** `_showRechargeSnackbar` no navega a ningún flujo de recarga. La integración Stripe existe (`stripe-webhook` Edge Function).
**Criterio de aceptación:** El botón "Recargar" navega a un bottom sheet con el widget de Stripe o, como mínimo, muestra un GSBottomSheet con monto pre-seleccionado y CTA "Pagar con tarjeta".

### #9 🟡 Tabs "Tickets" y "Recibos" en History son empty states vacíos
**Agente:** premium-ui-designer
**Archivo:** `lib/features/history/history_screen.dart:107,113`
**Descripción:** No muestran ninguna acción sugerida ni CTA relevante.
**Criterio de aceptación:** Cada tab vacío incluye un botón de acción (p. ej. "Solicitar ticket" → routePlanner).

### #10 🟡 Trip count en Profile Stats usa solo la primera página (máx 20)
**Agente:** architecture-transformer
**Archivo:** `lib/features/profile/profile_screen.dart:417`
**Descripción:** `l.length` cuenta los items en memoria del `transactionListProvider`, no el total real en DB. Si el usuario tiene >20 viajes, el contador es incorrecto.
**Criterio de aceptación:** Consulta `count` directo a Supabase (`select('count')`) para obtener el total real.

### #11 🟡 Mapa mock no muestra ubicación real ni Mapbox/GMaps ✅ APLICADO
**Agente:** architecture-transformer
**Archivo:** `lib/features/home/home_screen.dart:554`
**Descripción:** `_MockMap` con `CustomPainter` nunca llama a la API de mapas aunque `GOOGLE_MAPS_API_KEY` está configurada en `.env`. Para la entrega el mapa debería ser real o al menos integrar `google_maps_flutter`.
**Criterio de aceptación:** Reemplazar `_MockMap` con `GoogleMap` widget (o `flutter_map` con OpenStreetMap como fallback gratuito) mostrando la ubicación actual.

### #12 🟡 `if (true)` hardcodeado en PaymentValidation es code smell
**Agente:** senior-code-reviewer
**Archivo:** `lib/features/payment/payment_validation_screen.dart:54`
**Descripción:** `if (true) _DemoSwitcher(...)` — el flag nunca es false. Debe ser `if (kDebugMode)`.
**Criterio de aceptación:** `import 'package:flutter/foundation.dart'` + reemplazar `true` por `kDebugMode`.

---

## Restricciones recordadas
- No tocar secretos (`.env`, Supabase secrets)
- No cambiar estructura DB sin migración reversible
- Mantener `USE_MOCKS` env toggle (pendiente de implementar)
- 0 errores en `flutter analyze` (alcanzado en ciclo anterior)
