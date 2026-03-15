# GoSmart — Run & Validate Guide
> Versión: 2026-03-14 | Cubre los 3 patches críticos del primer ciclo

---

## Pre-requisitos
```bash
# 1. Copia y llena las variables de entorno
cp .env.example .env   # SUPABASE_URL, SUPABASE_ANON_KEY, STRIPE_PUBLISHABLE_KEY, GOOGLE_MAPS_API_KEY

# 2. Instala dependencias
flutter pub get

# 3. Verifica 0 issues
flutter analyze          # debe responder: "No issues found!"
```

---

## Correr la app

```bash
# Android (emulador o dispositivo)
flutter run

# Dispositivo específico
flutter devices          # listar IDs
flutter run -d <device-id>

# Web (Chrome) — Stripe requiere chrome
flutter run -d chrome
```

---

## Smoke Tests — Prueba manual paso a paso

### ✅ Flujo 1: Login → Home (base)
| Paso | Acción | Esperado |
|------|--------|----------|
| 1 | Abrir app | Pantalla onboarding con botones Login / Registrarse |
| 2 | Tap "Iniciar sesión" | Login screen con segmento Email/Teléfono |
| 3 | Ingresar email y contraseña válidos | Navega a Home con animación slide+fade |
| 4 | Home visible | Mapa mock + DraggableSheet + balance en GSInfoCard |
| 5 | Nav bar: Viajes → Historia → Billetera → Perfil | Navega entre tabs sin error |

---

### ✅ Flujo 2: Pagar (patch crítico #2 + #3)
| Paso | Acción | Esperado |
|------|--------|----------|
| 1 | Ir a Billetera (nav bar tab 3) | Tarjeta física con saldo real de Supabase |
| 2 | Tap "Pagar" (ícono QR) | Navega a `PaymentValidationScreen` |
| 3 | Pantalla muestra animación NFC pulsante | Estado "Procesando pago..." con spinner |
| 4 | Esperar ~2-5 s (llamada a Edge Function) | Estado cambia según respuesta real |
| 4a | Si saldo suficiente | "Pago Autorizado" con saldo restante real |
| 4b | Si saldo insuficiente | "Saldo Insuficiente" con monto disponible |
| 5 | Tap "Listo" | Vuelve a Billetera |
| 6 | Verificar saldo en Billetera | Balance actualizado (Realtime subscription) |

**Validación en Supabase Dashboard:**
- Tabla `transactions` → nuevo registro con `status='completed'`
- Tabla `cards` → `balance` decrementado en 2900

---

### ✅ Flujo 3: Bloquear/desbloquear tarjeta (patch crítico #1)
| Paso | Acción | Esperado |
|------|--------|----------|
| 1 | En Billetera, tap "Bloquear" | Toast "Tarjeta bloqueada" |
| 2 | Tarjeta visual | Gradiente cambia a gris + badge "BLOQUEADA" visible |
| 3 | Tap "Desbloquear" | Toast "Tarjeta desbloqueada" |
| 4 | Tarjeta visual | Gradiente azul-violeta restaurado + badge "Activa" |

> **ANTES del patch:** al bloquear, la tarjeta mostraba $0 y aparecía "desbloqueada". AHORA: muestra el estado real.

---

### ✅ Flujo 4: NFC Simulator (debug)
| Paso | Acción | Esperado |
|------|--------|----------|
| 1 | Ir a Perfil (nav bar tab 4) | Profile screen con SliverAppBar |
| 2 | Scroll hasta sección "Soporte" | Tile "Simulador NFC (Debug)" visible (solo en debug build) |
| 3 | Tap en tile | Navega a NFC Simulator con header naranja |
| 4 | Seleccionar validador y monto, tap "Simular Tap NFC" | Llama al Edge Function `authorize` y muestra resultado |

---

### ✅ Flujo 5: Editar perfil
| Paso | Acción | Esperado |
|------|--------|----------|
| 1 | En Perfil, tap ícono ✏️ | Bottom sheet "Información personal" |
| 2 | Cambiar nombre, tap "Guardar" | Toast success, nombre actualizado en SliverAppBar |
| 3 | Ir a Perfil → "Seguridad" → "Cambiar contraseña" | Bottom sheet con 2 campos |
| 4 | Ingresar ≥8 chars, confirmar, tap "Cambiar contraseña" | Toast success |

---

## Automated Smoke (Flutter test)

```bash
flutter test test/widget_test.dart
```

> Nota: actualmente solo existe el test widget por defecto. Los tests de integración están pendientes (backlog #10).

---

## Verificar Edge Functions en Supabase

```bash
# Logs en tiempo real (requiere Supabase CLI)
supabase functions serve authorize --env-file ./supabase/.env.local

# O revisar en Dashboard → Edge Functions → Logs
```

---

## Checklist de validación para entrega académica

- [ ] `flutter analyze` → **No issues found!**
- [ ] App inicia sin crash en emulador Android
- [ ] Login con email funciona → navega a Home
- [ ] Home muestra nombre del usuario (no "Bienvenido")
- [ ] Balance real en GSInfoCard de Home
- [ ] "Pagar" en Wallet navega a PaymentValidation
- [ ] PaymentValidation llama al Edge Function (ver log Supabase)
- [ ] Resultado de pago refleja saldo real (no simulado)
- [ ] Bloquear tarjeta → UI muestra estado "BLOQUEADA" (gradiente gris)
- [ ] Desbloquear → UI restaura gradiente azul-violeta
- [ ] NFC Simulator accesible desde Perfil (en debug build)
- [ ] Perfil editable (nombre + teléfono persiste en Supabase)
- [ ] Historial muestra transacciones reales con estados colored badges
- [ ] AI Chat responde (si GEMINI_API_KEY configurado en Supabase Secrets)
- [ ] `flutter analyze` → **No issues found!** (re-verificar tras últimos cambios)

---

## Blockers conocidos / Preguntas pendientes

1. **Region del proyecto Supabase** — necesaria si hay restricciones de CORS para el edge function `authorize` en web.
2. **GOOGLE_MAPS_API_KEY** — el mapa es mock (`CustomPainter`). Para integrar `google_maps_flutter`, el key debe tener Maps SDK for Android/iOS habilitado en GCP Console.
3. **Video de referencia** — `GoSmart - Google Chrome 2026-03-14 21-12-11.mp4` no se encontró en el filesystem. Si hay bugs específicos visibles en el video, compartirlos para priorizar.
