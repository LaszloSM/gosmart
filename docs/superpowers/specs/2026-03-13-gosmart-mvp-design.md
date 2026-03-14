# GoSmart MVP — Design Spec
**Date:** 2026-03-13
**Author:** Laszlo Sierra Mejia (CEO) + Claude Code
**Status:** Approved — Rev 2 (post spec-review fixes)

---

## 1. Contexto y objetivo

GoSmart es una startup colombiana (S.A.S.) que ofrece una tarjeta universal de transporte con IA para optimización de rutas. Compite con Tullave (Bogotá) y Cívica (Medellín) añadiendo interoperabilidad nacional, IA gratuita y puntos ecológicos.

**MVP goal:** app funcional que permita signup/login, ver saldo, simular tap en validador, recargar saldo (Stripe sandbox) y consultar rutas/chat con IA (Gemini Flash gratuito).

---

## 2. Decisiones de arquitectura

| Decisión | Elección | Razón |
|---|---|---|
| Backend | Supabase (Auth + DB + Realtime + Storage + Edge Functions) | Todo en una plataforma, sin servidores adicionales |
| Edge Functions | Deno/TypeScript | Nativo de Supabase, cold start bajo |
| IA | Gemini Flash 2.0 (free tier) | Sin costo, 1M tokens/día, suficiente para MVP |
| Pagos | Stripe global, `currency: cop` (minúsculas — requerido por Stripe) | Soporta Colombia, global, sandbox disponible |
| Mobile | Flutter + Riverpod + supabase_flutter | Ya existe el scaffold UI, se conecta |
| Maps | Google Maps Flutter (configurable a Mapbox) | Variable `MAP_PROVIDER` en .env |
| CI | GitHub Actions | Gratuito, build Android + tests |
| Repo | Un solo repo, backend dentro de `gosmart/` | Simplicidad para el equipo |

---

## 3. Estructura del repositorio

```
gosmart/
├── backend/
│   ├── migrations/
│   │   ├── 001_schema.sql          # Tablas + índices PostGIS
│   │   ├── 002_rls.sql             # Row Level Security policies
│   │   └── 003_functions.sql       # Triggers + funciones atómicas
│   └── functions/
│       ├── authorize/index.ts      # Validación NFC/QR atómica
│       ├── ai-chat/index.ts        # Gemini Flash intent + routing
│       └── stripe-webhook/index.ts # Recargas confirmadas
├── lib/
│   ├── core/
│   │   ├── supabase_client.dart
│   │   └── env.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── card_service.dart
│   │   ├── transaction_service.dart
│   │   └── ai_service.dart
│   ├── providers/              # Riverpod
│   │   ├── auth_provider.dart
│   │   ├── card_provider.dart
│   │   └── transaction_provider.dart
│   └── screens/               # ya existen, se conectan a providers
├── test/
│   ├── widget/
│   │   ├── login_test.dart
│   │   └── wallet_test.dart
│   └── sql/
│       └── integrity_check.sql
├── .github/
│   └── workflows/ci.yml
├── .env.example
└── openapi.yaml
```

---

## 4. Base de datos (Postgres + PostGIS)

### Tablas

```
profiles          — extiende auth.users: name, eco_points, consent_geo BOOLEAN DEFAULT false,
                    consent_ai_data BOOLEAN DEFAULT false, avatar_url, created_at
cards             — balance NUMERIC(12,2), currency TEXT DEFAULT 'cop', status, nfc_enabled,
                    user_id FK auth.users
transactions      — cobros/recargas/reembolsos: amount, type, status, co2_kg, validator_id,
                    idempotency_key TEXT UNIQUE (previene doble cobro)
trips             — origin/destination POINT (PostGIS), mode, route_id, eco_points_earned, user_id
operators         — empresas de transporte: name, city, country (solo lectura pública)
validators        — dispositivos físicos: id (VLD-BOG-001), operator_id, location POINT (solo lectura pública)
routes            — líneas: name, operator_id, mode (solo lectura pública)
stops             — location POINT, name, route_id (solo lectura pública)
eco_points_log    — user_id, trip_id, points, reason
payment_methods   — stripe_customer_id + stripe_pm_token (sin datos de tarjeta), user_id
recharges         — stripe_payment_intent_id TEXT UNIQUE, amount, status, card_id, processed_at
```

**Nota:** `ai_embeddings` (pgvector) está fuera del scope del MVP. Se documenta para post-MVP.
**Nota:** `currency` en `cards` y en Stripe debe ser siempre minúsculas `'cop'` o `'usd'`.

### Índices
- `stops.location` → `GIST` (PostGIS)
- `transactions(card_id, created_at DESC)` → historial paginado
- `cards(user_id)` → RLS eficiente
- `transactions.idempotency_key UNIQUE` → previene doble cobro en reintentos NFC
- `recharges.stripe_payment_intent_id UNIQUE` → previene doble crédito en reintentos Stripe

### RLS Policies (todas las tablas)

```sql
-- profiles:        auth.uid() = id
-- cards:           auth.uid() = user_id
-- transactions:    card_id IN (SELECT id FROM cards WHERE user_id = auth.uid())
-- trips:           auth.uid() = user_id
-- eco_points_log:  auth.uid() = user_id
-- payment_methods: auth.uid() = user_id
-- recharges:       card_id IN (SELECT id FROM cards WHERE user_id = auth.uid())

-- operators:   SELECT public (lectura pública, sin autenticación)
-- validators:  SELECT public
-- routes:      SELECT public
-- stops:       SELECT public
-- (INSERT/UPDATE/DELETE solo desde service_role en todos los anteriores)
```

### Funciones atómicas (003_functions.sql)

**`authorize_payment(p_card_id UUID, p_amount NUMERIC, p_validator_id TEXT, p_idempotency_key TEXT)`**
```sql
-- 1. Verifica idempotency_key: si ya existe, retorna el resultado previo (idempotente)
-- 2. BEGIN
-- 3. SELECT balance FROM cards WHERE id = p_card_id FOR UPDATE
-- 4. IF balance < p_amount → RAISE insufficient_balance
-- 5. IF status != 'active' → RAISE card_locked
-- 6. UPDATE cards SET balance = balance - p_amount
-- 7. INSERT INTO transactions (type='trip', amount=p_amount, idempotency_key=...)
-- 8. COMMIT
-- 9. RETURN { tx_id, remaining_balance, status='authorized' }
```

**`confirm_recharge(p_stripe_payment_intent_id TEXT, p_card_id UUID, p_amount NUMERIC)`**
```sql
-- 1. Verifica idempotencia: IF recharges.status = 'paid' WHERE stripe_payment_intent_id = X → return
-- 2. BEGIN
-- 3. UPDATE cards SET balance = balance + p_amount WHERE id = p_card_id
-- 4. UPDATE recharges SET status = 'paid', processed_at = now()
--    WHERE stripe_payment_intent_id = p_stripe_payment_intent_id
-- 5. INSERT INTO transactions (type='recharge', amount=p_amount, ...)
-- 6. COMMIT
```

**Nota:** NO hay trigger para actualizar balance en recargas. Solo `confirm_recharge()` lo hace. Esto elimina el riesgo de doble crédito.

**Trigger eco_points:** `AFTER INSERT ON trips` → suma puntos en `profiles.eco_points` si `mode IN ('bus','metro','bike')`.

---

## 5. Edge Functions

### `authorize` (POST /functions/v1/authorize)
```
Headers: Authorization: Bearer <JWT>
Input:   { card_id, validator_id, amount, route_id?, idempotency_key }
Flow:
  1. Extraer user_id del JWT (createClient con el token — NUNCA del body)
  2. Verificar que card_id pertenece al user_id del JWT
  3. Llamar authorize_payment() DB function (atómica)
  4. Publicar Realtime → canal `validators:{validator_id}`
  5. Return { status, tx_id, remaining_balance }
HTTP errors: 402 INSUFFICIENT_BALANCE, 403 CARD_LOCKED/UNAUTHORIZED, 404 NOT_FOUND
```

**Idempotencia NFC:** el cliente Flutter genera un UUID v4 para `idempotency_key` antes de enviar. Si el tap llega dos veces, la DB function retorna el resultado del primer cobro sin duplicar.

### `ai-chat` (POST /functions/v1/ai-chat)
```
Headers: Authorization: Bearer <JWT>
Input:   { query, user_location?, context? }
         — user_id se extrae SIEMPRE del JWT, nunca del body
Flow:
  1. Detect intent (route_query | balance_query | general)
  2. If route_query: calcular 3 rutas con heurística (A* simplificado en memoria)
  3. Build prompt con contexto de transporte colombiano + historial de contexto
  4. Call Gemini Flash API (GEMINI_API_KEY en Supabase secrets)
  5. Fallback si Gemini falla o quota agotada: respuesta de texto estático informativa
  6. Return { reply, routes?, intent }
Env:  GEMINI_API_KEY (Supabase secret — nunca en código)
```

### `stripe-webhook` (POST /functions/v1/stripe-webhook)
```
Input:   Stripe webhook event (raw body)
Flow:
  1. Verificar firma: stripe.webhooks.constructEvent(rawBody, signature, STRIPE_WEBHOOK_SECRET)
  2. Si firma inválida → return HTTP 400 (Stripe requiere 4xx para reintentar)
  3. On payment_intent.succeeded:
     a. Extraer card_id de metadata.card_id
     b. Llamar confirm_recharge() DB function (atómica + idempotente)
  4. Return HTTP 200
Env:  STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET (Supabase secrets)
```

**Idempotencia Stripe:** `confirm_recharge()` verifica si el `stripe_payment_intent_id` ya fue procesado antes de actualizar. Stripe puede reintentar webhooks múltiples veces.

---

## 6. Flutter — cambios al proyecto existente

### Dependencias a agregar (pubspec.yaml)
```yaml
supabase_flutter: ^2.x
flutter_riverpod: ^2.x
flutter_dotenv: ^5.x
flutter_nfc_kit: ^3.x
stripe_flutter: ^10.x
go_router: ^13.x
uuid: ^4.x   # para generar idempotency_key en cliente
```

### Migración de router
El `main.dart` actual usa `AppRouter.onGenerateRoute` con `MaterialApp`. Se migrará a `MaterialApp.router` con `GoRouter`. Las rutas existentes en `app_router.dart` se mapean 1:1 a `GoRoute`. El estado de sesión controla `redirect` automático (no autenticado → `/login`).

### Providers Riverpod
- `authProvider` — sesión Supabase, signup/login OTP o email+password
- `cardProvider` — tarjeta activa + balance con `supabase.channel('cards').on(...)` Realtime
- `transactionProvider` — historial paginado con lazy loading

### Pantallas a conectar (UI ya existe)
| Pantalla | Conexión |
|---|---|
| Login/Register | Supabase Auth (OTP SMS o email+password) |
| Home | cardProvider → balance real + mapa |
| Wallet | cardProvider → balance + lock/unlock (UPDATE cards SET status) |
| History | transactionProvider → lista real paginada |
| Payment Validation | authorize Edge Function → 5 estados UI |
| AI Chat | ai-chat Edge Function → Gemini Flash |
| Route Planner | ai-chat con intent route_query |

### NFCAuthSimulator (debug screen — nueva)
- Selector de `card_id`, `validator_id`, `amount`
- Genera `idempotency_key` UUID v4
- Llama `authorize` Edge Function
- Muestra resultado con Snackbar + estado de UI (5 estados del PaymentValidationScreen)

---

## 7. Seguridad y compliance

| Área | Medida |
|---|---|
| Credenciales | `.env` local + Supabase secrets. Nunca en código fuente ni en el repo. |
| `user_id` en Edge Functions | Siempre extraído del JWT — nunca del request body. |
| Ley 1581 (Habeas Data) | `consent_geo` + `consent_ai_data` en profiles. Aviso de privacidad en pantalla de registro. Mecanismo de eliminación de datos en pantalla de perfil (DELETE /auth/v1/user + cascade). |
| PCI (Stripe) | Flutter tokeniza con Stripe SDK. Backend nunca recibe ni almacena número de tarjeta. |
| RLS | Habilitado en todas las tablas. Políticas explícitas para lectura pública (operators, stops, etc.) y privada. |
| Stripe webhook | Verificación de firma con `STRIPE_WEBHOOK_SECRET`. Retorna HTTP 400 en firma inválida. |
| Idempotencia | `idempotency_key UNIQUE` en transactions (NFC). `stripe_payment_intent_id UNIQUE` en recharges. |
| Rotación de keys | README documenta: revocar en Supabase dashboard → actualizar GitHub secrets → revocar Stripe key → crear nueva. |

### Cumplimiento Ley 1581 en onboarding
1. Al registrarse: mostrar enlace a Política de Privacidad (PDF en Supabase Storage, público)
2. Checkbox explícito: "Acepto el tratamiento de mis datos de movilidad"
3. Checkbox separado (opcional): "Acepto compartir mi ubicación para rutas personalizadas" → `consent_geo`
4. Botón en Perfil → "Eliminar mi cuenta y datos" → DELETE en cascada

---

## 8. CI/CD (.github/workflows/ci.yml)

```yaml
Trigger: push / PR a main
Jobs:
  lint:   flutter analyze
  test:   flutter test
  build:  flutter build apk --release
          (SUPABASE_URL + SUPABASE_ANON_KEY como GitHub secrets para tests)
```

iOS no es scope del MVP CI. Se agrega post-MVP cuando se gestionen entitlements de NFC en Apple.

---

## 9. OpenAPI

La base URL del spec se actualiza para reflejar Supabase:
- **Prod:** `https://<project-ref>.supabase.co/functions/v1`
- **Local:** `http://localhost:54321/functions/v1`

---

## 10. Criterios de aceptación (MVP)

- [ ] Signup/login con Supabase Auth (OTP o email+password)
- [ ] Wallet muestra saldo real de la base de datos con actualización Realtime
- [ ] Tap en NFCAuthSimulator llama `authorize`, reduce balance atómicamente, sin doble cobro en reintentos
- [ ] Top-up con Stripe sandbox actualiza balance vía webhook (idempotente)
- [ ] Chat IA responde en español con Gemini Flash; si quota agotada, respuesta de fallback
- [ ] Consentimiento de datos mostrado en registro (Ley 1581)
- [ ] Tests básicos pasan en CI (GitHub Actions)
- [ ] `.env.example` sin valores reales, README con pasos de setup y rotación de keys

---

## 11. Fuera de scope (MVP)

- `ai_embeddings` / pgvector (post-MVP cuando haya historial de usuarios)
- Integración real con TM Bogotá / Metro Medellín (requiere convenios comerciales)
- NFC físico en producción (requiere certificación EMV/ISO 14443)
- App Store / Play Store deployment
- Push notifications (FCM/APNs)
- Modo offline con SQLite
- Dark mode
- iOS NFC entitlements (post-MVP)
