# 🚀 GoSmart — Aplicación Universal de Movilidad Urbana

> **Tarjeta de tránsito inteligente con IA, pagos NFC y planificación multimodal para ciudades colombianas.**

---

## 📋 Descripción General

**GoSmart** es una aplicación móvil (Flutter/Dart) que integra múltiples servicios de movilidad urbana en una única plataforma. Combina una tarjeta digital NFC, un asistente de IA conversacional, planificación de rutas inteligentes y gestión de pagos en tiempo real.

### Características Principales

✅ **Tarjeta de Tránsito Digital**
- NFC tap-to-pay en validadores de transporte
- Saldo en tiempo real vía Supabase Realtime
- Soporte para múltiples monedas (COP, USD, EUR)
- Estados: activa, bloqueada, suspendida, perdida

✅ **Asistente de IA Inteligente**
- Chatbot conversacional con Groq (llama-3.3-70b)
- Contexto geográfico local (RAG Colombia con 7,648 entidades)
- Recomendaciones de rutas optimizadas
- Respuestas restringidas a temas de movilidad

✅ **Planificador de Rutas Multimodal**
- 3 alternativas por consulta: más rápida, más económica, más eco-amigable
- Soporte: bus, metro, bicicleta, a pie, taxi
- Integración con Mapbox Directions API
- Cálculo de emisiones CO₂

✅ **Billetera Digital**
- Recarga de saldo vía Stripe
- Historial de transacciones pagado
- Eco-puntos por viajes sostenibles
- Control de métodos de pago

✅ **Historial y Análisis**
- Registro completo de viajes realizados
- Descarga de recibos y comprobantes
- Favoritos (Casa, Trabajo, Lugares custom)
- Estadísticas de uso

---

## 🛠️ Stack Tecnológico

### Frontend
| Componente | Tecnología | Versión |
|-----------|-----------|---------|
| Framework | Flutter | 3.2.0+ |
| Lenguaje | Dart | 3.2.0+ |
| State Management | Flutter Riverpod | 2.5.1 |
| Navegación | GoRouter | 13.2.0 |
| UI Kit | Material Design 3 | - |
| Fonts | Google Fonts | 6.2.1 |

### Backend & Servicios
| Servicio | Función | Proveedor |
|---------|---------|----------|
| Autenticación | Email/SMS OTP | Supabase Auth |
| Base de Datos | PostgreSQL | Supabase |
| Realtime | Suscripciones en vivo | Supabase Realtime |
| Edge Functions | Serverless Deno | Supabase Edge Functions |
| Storage | Archivos de usuario | Supabase Storage |
| Pagos | Transacciones monetarias | Stripe API |
| IA | LLM + Embeddings | Groq (llama-3.3-70b) + pgvector |
| Mapas | Tiles + Geocoding | Mapbox + OpenStreetMap |
| Localización | GPS | Geolocator |
| NFC | Lectura de tarjetas | flutter_nfc_kit |

### Base de Datos
- **Motor**: PostgreSQL 15+
- **Extensiones**: pgvector (embeddings 384-dim)
- **RLS**: Row-Level Security en todas las tablas de usuario
- **Realtime**: Supabase Realtime para live updates
- **Funciones**: Triggers, RPCs, políticas de seguridad

---

## 📁 Estructura del Proyecto

gosmart/
├── lib/
│   ├── core/
│   │   ├── env.dart                      # Configuración de variables de entorno
│   │   └── supabase_client.dart          # Cliente Supabase singleton
│   │
│   ├── features/                         # Pantallas y features
│   │   ├── ai_chat/                      # Asistente de IA conversacional
│   │   ├── auth/                         # Autenticación (login/register/OTP)
│   │   ├── home/                         # Pantalla principal
│   │   ├── wallet/                       # Billetera y recargas
│   │   ├── history/                      # Historial de transacciones
│   │   ├── profile/                      # Perfil de usuario
│   │   ├── routes/                       # Planificador y detalle de rutas
│   │   ├── payment/                      # Validación de pagos NFC
│   │   ├── nfc_simulator/                # Simulador NFC (debug)
│   │   ├── onboarding/                   # Introducción y permisos
│   │   └── splash/                       # Pantalla de carga
│   │
│   ├── models/                           # Modelos de datos (DTOs)
│   ├── providers/                        # Riverpod StateNotifierProviders
│   ├── services/                         # Servicios de negocio (singletons)
│   ├── router/                           # Configuración GoRouter
│   ├── theme/                            # Tokens y temas
│   ├── widgets/                          # Componentes reutilizables GS*
│   └── main.dart                         # Punto de entrada
│
├── backend/
│   ├── migrations/                       # Migraciones SQL
│   └── functions/                        # Edge Functions (Deno/TypeScript)
│
├── pipeline/                             # Pipeline de IA y embeddings
├── design/                               # Figma exports y tokens
├── test/                                 # Tests
├── assets/                               # Iconos, imágenes, animaciones
├── android/                              # Configuración Android
├── ios/                                  # Configuración iOS
├── web/                                  # Configuración Web
├── pubspec.yaml                          # Dependencias Flutter
├── .env.example                          # Template de variables
├── openapi.yaml                          # API contract
└── CLAUDE.md                             # Notas de arquitectura


---

## 🚀 Quick Start

### Requisitos Previos

- **Flutter SDK** `>=3.2.0` — [Instalar](https://flutter.dev/docs/get-started/install)
- **Dart** `>=3.2.0`
- **Android Studio** (para Android) o **Xcode** (para iOS)
- **Proyecto Supabase** — [supabase.com](https://supabase.com)
- **Claves API**:
  - Stripe (test/prod)
  - Google Maps (opcional, fallback a OSM)
  - Mapbox (geocoding + directions)
  - Groq (IA, free tier)

### 1. Clonar y Configurar

git clone https://github.com/LaszloSM/gosmart.git
cd gosmart
flutter pub get

### 2. Crear Proyecto Supabase

1. Ve a [supabase.com](https://supabase.com) → **New Project**
2. Elige región cercana a Colombia (ej: `us-east-1`)
3. Guarda tu **Project URL** y **Anon Key**

### 3. Aplicar Migraciones de Base de Datos

En el **SQL Editor** de Supabase Dashboard, corre en orden:

# Opción A: Supabase CLI (recomendado)
supabase db push

# Opción B: Manual (copia-pega en SQL Editor)
# 1. backend/migrations/001_schema.sql
# 2. backend/migrations/002_rls.sql
# 3. backend/migrations/003_functions.sql
# 4. backend/migrations/004_ai_latency_log.sql
# 5. backend/migrations/005_profile_extra_fields.sql
# 6. backend/migrations/006_colombia_kg.sql
# 7. backend/migrations/007_fix_embedding_dim.sql
# 8. backend/migrations/008_wallet_mock.sql
# 9. backend/migrations/009_favorites_history.sql

### 4. Configurar Variables de Entorno

Copia el archivo de ejemplo:
cp .env.example .env

Edita `.env` con tus valores reales:
SUPABASE_URL=https://xyzabcdef.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
STRIPE_PUBLISHABLE_KEY=pk_test_...
GOOGLE_MAPS_API_KEY=AIza...
MAPBOX_PUBLIC_TOKEN=pk.eyJ...
GROQ_API_KEY=gsk_...

**⚠️ Nunca commits `.env` — está en `.gitignore`**

### 5. Configurar Secretos de Edge Functions

En Supabase Dashboard → **Edge Functions → Secrets**, añade:

STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
GROQ_API_KEY=gsk_...

### 6. Desplegar Edge Functions

npm install -g supabase
supabase login
supabase link --project-ref your-project-ref

supabase functions deploy authorize
supabase functions deploy ai-chat
supabase functions deploy stripe-webhook
supabase functions deploy delete-account

### 7. Configurar Webhook de Stripe

En [Stripe Dashboard](https://dashboard.stripe.com/test/webhooks):
- Añade endpoint → URL: `https://your-project-ref.supabase.co/functions/v1/stripe-webhook`
- Eventos: `payment_intent.succeeded`
- Copia el signing secret → set como `STRIPE_WEBHOOK_SECRET`

### 8. Ejecutar la App

# Android (emulador o dispositivo conectado)
flutter run

# iOS (simulador)
flutter run -d "iPhone 15 Pro"

# Web
flutter run -d chrome

### 9. Probar el Simulador NFC

1. Registra una cuenta en la app
2. Navega a `/debug/nfc-simulator`
3. Selecciona validador y cantidad → "Simular Tap NFC"
4. Verifica que el saldo disminuye en la pantalla de Billetera

---

## 🗄️ Esquema de Base de Datos

### Tablas Principales

#### `profiles` (Perfiles de Usuario)
id (UUID) -- Referencias a auth.users
name (text) -- Nombre completo
email (text) -- Email
phone (text) -- Teléfono
avatar_url (text) -- URL del avatar
cedula (text) -- Cédula (inmutable)
city (text) -- Ciudad
birth_date (DATE) -- Fecha de nacimiento
eco_points (INTEGER) -- Puntos eco
created_at (timestamptz) -- Creación
updated_at (timestamptz) -- Última actualización

#### `cards` (Tarjetas de Tránsito)
id (UUID) -- PK
user_id (UUID) -- FK → profiles
number_masked (text) -- Número enmascarado (ej: ****1234)
balance (numeric) -- Saldo actual
currency (text) -- Moneda (COP, USD, EUR)
status (text) -- Estado (active, locked, suspended, lost)
nfc_enabled (boolean) -- NFC habilitado
expires_at (text) -- Fecha de expiración
created_at (timestamptz) -- Creación

#### `transactions` (Transacciones de Viaje)
id (UUID) -- PK
card_id (UUID) -- FK → cards
type (text) -- Tipo (trip, recharge, refund)
origin (text) -- Origen
destination (text) -- Destino
amount (numeric) -- Monto
currency (text) -- Moneda
status (text) -- Estado (completed, pending, failed)
mode (text) -- Modo de transporte
co2_kg (numeric) -- Emisiones CO₂
validator_id (text) -- ID del validador
created_at (timestamptz) -- Creación

#### `wallets` (Billeteras Mock)
id (UUID) -- PK
user_id (UUID) -- FK → profiles
balance (INTEGER) -- Saldo en centavos
card_number (text) -- Número de tarjeta generado
card_status (text) -- Estado (active, inactive)
created_at (timestamptz) -- Creación
updated_at (timestamptz) -- Actualización

#### `favorite_places` (Lugares Favoritos)
id (UUID) -- PK
user_id (UUID) -- FK → profiles
place_name (text) -- Nombre (ej: "Mi Casa")
place_type (text) -- Tipo (home, work, custom)
latitude (numeric) -- Latitud
longitude (numeric) -- Longitud
address (text) -- Dirección completa
use_count (INTEGER) -- Veces utilizado
created_at (timestamptz) -- Creación
updated_at (timestamptz) -- Actualización

#### `trip_history` (Historial de Viajes)
id (UUID) -- PK
user_id (UUID) -- FK → profiles
origin (text) -- Origen
destination (text) -- Destino
distance_km (numeric) -- Distancia en km
duration_min (INTEGER) -- Duración en minutos
modes (text[]) -- Modos usados (array)
cost (numeric) -- Costo total
eco_score (INTEGER) -- Puntuación eco (0-100)
created_at (timestamptz) -- Creación

#### `colombia_kg` (Knowledge Graph Colombia)
id (UUID) -- PK
entity_name (text) -- Nombre de entidad (barrio, estación, etc)
entity_type (text) -- Tipo (neighbourhood, station, municipality, etc)
latitude (numeric) -- Latitud
longitude (numeric) -- Longitud
city (text) -- Ciudad
department (text) -- Departamento
description (text) -- Descripción
created_at (timestamptz) -- Creación

### Row-Level Security (RLS)

Todas las tablas de usuario tienen políticas RLS que filtran automáticamente por `auth.uid()`:

CREATE POLICY "Usuarios ven su propio perfil"
  ON public.profiles FOR ALL
  USING (auth.uid() = id);

CREATE POLICY "Usuarios ven sus tarjetas"
  ON public.cards FOR ALL
  USING (auth.uid() = user_id);

---

## 🔌 Endpoints de la API

### Autenticación

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/auth/send-otp` | Enviar código SMS |
| `POST` | `/auth/verify-otp` | Verificar código → JWT |
| `POST` | `/auth/register` | Registro con email/contraseña |
| `POST` | `/auth/login` | Login |

### Tarjetas

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/cards/{id}` | Obtener tarjeta |
| `GET` | `/cards/{id}/balance` | Saldo en tiempo real |
| `PUT` | `/cards/{id}` | Actualizar estado |
| `POST` | `/cards/{id}/lock` | Bloquear tarjeta |

### Rutas

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/routes/plan` | Planificar ruta (3 alternativas) |
| `GET` | `/routes/history` | Historial de rutas |
| `GET` | `/routes/{id}` | Detalle de ruta |

### Transacciones

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/transactions/authorize` | Autorizar pago NFC |
| `GET` | `/transactions` | Listar transacciones (paginated) |
| `GET` | `/transactions/{id}` | Detalle de transacción |

### Billetera

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/wallet` | Obtener estado de billetera |
| `POST` | `/wallet/recharge` | Recargar vía Stripe |
| `GET` | `/wallet/transactions` | Historial (paginated) |

### IA

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/ai/chat` | Enviar mensaje al asistente |
| `GET` | `/ai/recommendations` | Recomendaciones de ruta |
| `POST` | `/ai/context` | Obtener contexto (RAG) |

### Lugares Favoritos

| Método | Path | Descripción |
|--------|------|-------------|
| `GET` | `/favorites` | Listar favoritos |
| `POST` | `/favorites` | Crear favorito |
| `PUT` | `/favorites/{id}` | Actualizar favorito |
| `DELETE` | `/favorites/{id}` | Eliminar favorito |

---

## 🏗️ Arquitectura

### Flujo de Autenticación

Login/Register
    ↓
SMS OTP (Supabase Auth)
    ↓
Trigger: handle_new_user()
    ├─ Crear fila en profiles
    └─ Crear fila en cards (tarjeta inicial)
    ↓
JWT Token → App
    ↓
Supabase Client configurado
    ↓
RLS Policies aplican automáticamente
    ↓
App Home (/home)

### Flujo de Pago NFC

Usuario en Home
    ↓
Navega a Validador
    ↓
Tap NFC
    ↓
flutter_nfc_kit detecta card
    ↓
POST /transactions/authorize
    ├─ Edge Function valida
    ├─ Chequea balance
    ├─ RLS filtra por user_id
    └─ Crea transacción
    ↓
Resultado: AUTHORIZED / INSUFFICIENT_BALANCE / ERROR
    ↓
GSToast muestra resultado
    ↓
Balance actualiza vía Supabase Realtime

### Flujo de IA (Groq + RAG)

Usuario abre Chat
    ↓
Escribe pregunta
    ↓
AiService.sendMessage()
    ├─ _fetchKgContext(query)
    │   ├─ Busca en colombia_kg (ilike)
    │   └─ Top 5 entidades relevantes
    ├─ Construye system prompt con contexto
    └─ POST https://api.groq.com/openai/v1/chat/completions
        ├─ Model: llama-3.3-70b-versatile
        ├─ Max tokens: 600
        ├─ Temperature: 0.65
        └─ Timeout: 20s
    ↓
Respuesta Groq
    ↓
Crea AiMessage (source: 'groq')
    ↓
Añade a conversación en estado Riverpod
    ↓
Pantalla re-renderiza con bubble nuevo

### Patrón State Management (Riverpod)

// Servicio (singleton)
final aiServiceProvider = Provider((ref) => AiService());

// Provider de estado (StateNotifierProvider)
final aiConversationProvider = StateNotifierProvider<
  AiConversationNotifier,
  List<AiMessage>
>((ref) {
  return AiConversationNotifier(ref.watch(aiServiceProvider));
});

// En pantalla (ConsumerWidget)
class AiChatScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(aiConversationProvider);
    
    return ListView(
      children: conversation.map((msg) => AiBubble(msg)).toList(),
    );
  }
}

---

## 🎨 Sistema de Diseño

### Tokens de Color

GSColors.primary          // #1A1A2E — Navy oscuro
GSColors.accent           // #00D4AA — Teal (CTAs)
GSColors.accentAlt        // #6C63FF — Violeta (eco)
GSColors.eco              // #3CB371 — Verde

// Modos de transporte
GSColors.bus              // #FF6B6B
GSColors.metro            // #4ECDC4
GSColors.bike             // #95E1D3
GSColors.walk             // #FFD93D
GSColors.taxi             // #FFA502
GSColors.car              // #A8E6CF

### Espaciado (Escala 4px)

GSSpacing.s1   // 4px
GSSpacing.s2   // 8px
GSSpacing.s3   // 12px
GSSpacing.s4   // 16px
GSSpacing.s5   // 20px
GSSpacing.s6   // 24px
GSSpacing.s8   // 32px

### Radios de Esquina

GSRadius.sm        // 8px
GSRadius.md        // 12px
GSRadius.lg        // 16px (cards)
GSRadius.xl        // 20px
GSRadius.xxl       // 28px
GSRadius.full      // 9999px (pills)

### Componentes GS*

- `GSButton` — Botón principal (4 variantes)
- `GSIconButton` — Botón con icono
- `GSCard` — Card reusable
- `GSModeChip` — Chip de modo transporte
- `GSTextField` — Input de texto
- `GSSearchBar` — Barra de búsqueda
- `GSBottomNav` — Navegación inferior (4 tabs)
- `GSBottomSheet` — Sheet draggable
- `GSToast` — Notificación emergente
- `GSSkeletonLoader` — Loading placeholder

---

## 🧪 Testing

### Ejecutar Tests

# Todos los tests
flutter test

# Un archivo específico
flutter test test/widget_test.dart

# Con cobertura
flutter test --coverage

---

## 🔐 Seguridad

### Checklist de Seguridad

- ✅ `.env` está en `.gitignore` (nunca commitear)
- ✅ Supabase `service_role` key solo en Edge Function secrets
- ✅ Stripe secret key solo en Supabase secrets
- ✅ `GROQ_API_KEY` solo en Supabase secrets
- ✅ RLS habilitado en todas las tablas de usuario

### Rotación de Claves

#### Claves Supabase (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
1. Dashboard Supabase → Settings → API → Reset anon key
2. Actualizar `.env` localmente
3. Re-desplegar Edge Functions
4. Informar a todos los devs

#### Claves Stripe
1. Stripe Dashboard → Developers → API keys → Roll key
2. Actualizar `STRIPE_SECRET_KEY` en Supabase Secrets
3. Actualizar `STRIPE_PUBLISHABLE_KEY` en `.env`
4. Re-desplegar `stripe-webhook` function
5. Probar webhook en sandbox

#### API Key Groq
1. Google AI Studio → Manage API keys → Revoke → Create new
2. Actualizar `GROQ_API_KEY` en Supabase Secrets
3. Re-desplegar `ai-chat` function
4. Probar chat en la app

---

## 📊 Telemetría & Logging

### Latencias de IA

Cada respuesta de IA se registra en `ai_latency_log`:

SELECT
  response_time_ms,
  source,
  model,
  tokens_used,
  created_at
FROM ai_latency_log
ORDER BY created_at DESC
LIMIT 100;

### Error Handling

Todos los servicios retornan `Future<T?>` (null en caso de error):

final profile = await profileService.loadProfile();
if (profile == null) {
  GSToast.show('Error cargando perfil');
  return;
}

---

## 🚀 Deployment

### Build APK (Android)

# Debug
flutter build apk

# Release (requiere keystore)
flutter build apk --release

### Build iOS

# Debug
flutter build ios --debug

# Release
flutter build ios --release

### Build Web

flutter build web --release

---

## 📚 Dependencias Principales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `supabase_flutter` | ^2.5.0 | Backend + Auth + Realtime |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^13.2.0 | Navegación |
| `flutter_stripe` | ^10.1.1 | Pagos |
| `flutter_nfc_kit` | ^3.4.0 | NFC |
| `flutter_map` | ^7.0.2 | Mapas |
| `geolocator` | ^13.0.0 | GPS |
| `http` | ^1.2.0 | HTTP requests (Groq) |
| `flutter_dotenv` | ^5.1.0 | Variables de entorno |

Ver `pubspec.yaml` para lista completa.

---

## 🛠️ Troubleshooting

### PGRST204 Error
**Síntoma**: "Could not find column X"
**Solución**: Correr la migración correspondiente en Supabase SQL Editor

### Balance no actualiza en tiempo real
**Síntoma**: Saldo no refleja cambio inmediato
**Causa**: Supabase Realtime no suscrito
**Solución**: Verificar que `activeCardProvider` está subscrito a cambios

### NFC Simulator no funciona
**Síntoma**: Tap NFC no registra
**Solución**: Verificar que estás en `/debug/nfc-simulator` y que la tarjeta tiene `nfc_enabled: true`

### AI responde "no configurado"
**Síntoma**: Chat muestra error
**Causa**: `GROQ_API_KEY` vacío
**Solución**: Añadir key en Supabase Edge Function Secrets

### Mapbox no carga
**Síntoma**: Mapa gris sin tiles
**Causa**: `MAPBOX_PUBLIC_TOKEN` inválido
**Solución**: Verificar token en `.env` o caerá a OpenStreetMap (fallback)

---

## 📖 Recursos

- [Flutter Docs](https://flutter.dev/docs)
- [Supabase Docs](https://supabase.com/docs)
- [Riverpod Guide](https://riverpod.dev)
- [GoRouter Docs](https://pub.dev/packages/go_router)
- [Stripe Flutter SDK](https://pub.dev/packages/flutter_stripe)
- [Groq API](https://console.groq.com)
- [Mapbox API](https://docs.mapbox.com)

---

## 📄 Licencia

Proyecto privado. Todos los derechos reservados.

---

**Última actualización**: 2026-04-16
**Versión**: 1.0.0+1
