# CLAUDE.md — GoSmart

GoSmart is a Colombian urban-mobility app (Flutter/Dart) backed by Supabase.
Universal transport card with NFC, AI assistant, route planning, and Stripe recharges.

## Commands

```bash
# Install / sync dependencies
flutter pub get

# Run on connected Android device (primary target)
flutter run

# Run on specific device
flutter devices                             # list available devices
flutter run -d <device-id>

# Build
flutter build apk                           # Android APK
flutter build apk --release                 # signed release APK

# Lint / analyze
flutter analyze

# Tests
flutter test                                # all tests
flutter test test/widget_test.dart          # single file

# Code generation (only needed if adding Riverpod @riverpod annotations)
dart run build_runner build --delete-conflicting-outputs
```

## Environment Setup

Copy `.env.example` to `.env`. **All four keys are required at startup** (app crashes if missing):

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=eyJ...
STRIPE_PUBLISHABLE_KEY=pk_test_...
GOOGLE_MAPS_API_KEY=AIza...
```

Required for AI assistant (app shows "not configured" if absent):

```
GROQ_API_KEY=gsk_...          # AI — free tier at https://console.groq.com (no credit card)
```

Optional:

```
MAP_PROVIDER=google            # 'google' (default) or 'osm' for OpenStreetMap
```

> **Gemini is NOT used.** The AI uses Groq `llama-3.3-70b-versatile` directly from Flutter —
> free, no credit card, 1,000 req/day. `GEMINI_API_KEY` kept in env for reference only.

Edge Function secrets (Supabase Dashboard → Edge Functions → Secrets, never in `.env`):
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `GROQ_API_KEY` (para la Edge Function ai-chat)

## Database Migrations

Run all migrations in order in Supabase SQL Editor. Each is safe to re-run (IF NOT EXISTS guards).

| File | Description |
|------|-------------|
| `001_schema.sql` | Tables: profiles, cards, transactions, trips, validators, operators, payment_methods, recharges |
| `002_rls.sql` | Row-Level Security policies — all tables filter by `auth.uid()` automatically |
| `003_functions.sql` | DB functions: `handle_new_user` trigger (auto-creates profile + card on signup), `fn_eco_points` |
| `004_ai_latency_log.sql` | `ai_latency_log` table — telemetry for AI response times |
| `005_profile_extra_fields.sql` | Adds `phone`, `cedula`, `city`, `birth_date` to profiles — **required for profile editing** |
| `006_colombia_kg.sql` | RAG Colombia KG: `colombia_kg`, `colombia_kg_aliases`, `colombia_kg_embeddings` (vector 384), `rag_fallback_log`. Requires pgvector. |
| `007_fix_embedding_dim.sql` | Cambia `colombia_kg_embeddings.embedding` de `vector(1536)` a `vector(384)` y recrea RPC `match_colombia_kg`. Correr **antes** de `load_supabase.py`. |

After running 005+, PostgREST reloads automatically via `NOTIFY pgrst, 'reload schema'`.

> **PGRST204 error** = a column referenced in code doesn't exist in DB yet → run the
> missing migration.

## Architecture

### Directory Structure

```
lib/
├── core/
│   ├── env.dart                  # Typed access to .env via flutter_dotenv
│   └── supabase_client.dart      # GoSmartSupabase.client singleton (initialized once in main)
├── features/                     # Screen-level UI (one folder per feature)
│   ├── ai_chat/                  # AI assistant chat UI
│   ├── auth/                     # Onboarding, login, register, SMS OTP
│   ├── history/                  # Transaction history
│   ├── home/                     # Main home screen (balance, quick actions)
│   ├── nfc_simulator/            # Debug NFC simulator (LOCAL MOCK — no Edge Function)
│   ├── payment/                  # Payment validation screen
│   ├── profile/                  # User profile + edit sheets
│   ├── routes/                   # Route planner + route detail
│   └── wallet/                   # Wallet / recharge screen
├── models/                       # Pure data classes (no Flutter dependencies)
│   ├── ai_models.dart            # AiMessage, ConversationTurn, RouteOption, Leg
│   ├── authorize_result.dart     # NFC authorization result
│   ├── card_model.dart           # CardModel
│   ├── profile_model.dart        # ProfileModel (includes cedula, city, birthDate)
│   └── transaction_model.dart    # TransactionModel
├── providers/                    # Riverpod StateNotifierProviders
│   ├── ai_conversation_provider.dart
│   ├── auth_provider.dart
│   ├── card_provider.dart
│   ├── profile_provider.dart
│   └── transaction_provider.dart
├── router/
│   └── app_router.dart           # GoRouter config + AppRoutes constants
├── services/                     # Plain Dart classes (each has a top-level singleton)
│   ├── ai_service.dart           # Groq REST API calls
│   ├── auth_service.dart
│   ├── card_service.dart
│   └── profile_service.dart
├── theme/
│   ├── app_theme.dart            # MaterialApp ThemeData
│   └── design_tokens.dart        # GSColors, GSSpacing, GSRadius, GSShadow, GSSize, etc.
├── widgets/                      # Reusable GS* components
└── main.dart                     # App entry point — initializes Supabase, dotenv, Stripe
```

### State Management — Riverpod 2.x (manual, no code gen)

All providers in `lib/providers/`. Pattern: `StateNotifierProvider<Notifier, AsyncValue<T>>`.

| Provider | State | Notes |
|----------|-------|-------|
| `authSessionProvider` | `StreamProvider` | Supabase auth stream |
| `currentUserProvider` | derived from session | |
| `activeCardProvider` | `AsyncValue<CardModel>` | Supabase Realtime for live balance |
| `transactionListProvider` | `AsyncValue<List<TransactionModel>>` | paginated (20/page), `loadMore()` |
| `profileProvider` | `AsyncValue<ProfileModel>` | load(), updateProfile(), updatePassword() |
| `aiConversationProvider` | conversation history | |

**Critical state pattern** — `updateProfile()` preserves previous state on error:
```dart
Future<void> updateProfile({...}) async {
  final previous = state;
  try {
    await profileService.updateProfile(...);
    await load();
  } catch (e, st) {
    state = previous;   // NEVER let the header show "Error" on failed save
    Error.throwWithStackTrace(e, st);
  }
}
```

### Backend — Supabase

- **Auth**: email/password + phone OTP. `handle_new_user` trigger auto-creates `profiles` + `cards` row on every new signup.
- **RLS**: All user tables (`profiles`, `cards`, `transactions`, `trips`) filter by `auth.uid()` — never add manual user ID filters in queries.
- **Edge Functions** (Deno/TypeScript in `backend/functions/`):
  - `authorize` — NFC payment authorization (NOT currently deployed; simulator uses local mock)
  - `ai-chat` — Legacy Gemini Edge Function (NOT used; AI service calls Groq directly from Flutter)
  - `stripe-webhook` — Stripe payment webhook
  - `delete-account` — GDPR account deletion
- **Realtime**: `activeCardProvider` subscribes to `cards` table changes for live balance updates.

### AI Service — Groq + RAG Colombia

`lib/services/ai_service.dart` flujo completo (sin Edge Function):

```
1. _fetchKgContext(query) → ilike search en colombia_kg → top 5 entidades relevantes
2. Inyectar entidades como contexto en el system prompt
3. POST https://api.groq.com/openai/v1/chat/completions
   Model: llama-3.3-70b-versatile | Max tokens: 600 | Temperature: 0.65 | Timeout: 20s
4. Devuelve AiMessage con source: 'groq'
```

- **Topic-restricted**: system prompt prohíbe responder temas ajenos a transporte/GoSmart
- **KG context**: busca barrios, estaciones, municipios relevantes antes de llamar a Groq
- Si `GROQ_API_KEY` está vacío → mensaje "no configurado" (sin crash)
- Sin `ai_latency_log` (el check constraint de source no incluye 'groq'; se puede ampliar si se necesita telemetría)

### RAG Colombia — Knowledge Graph

7,648 entidades de Colombia en Supabase (barrios, estaciones, municipios, departamentos).
Embeddings 384-dim con `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` (local, gratis).

**Pipeline** (`pipeline/`): ejecutar en orden para actualizar el KG:
```bash
cd pipeline
python -m pip install -r requirements.txt   # incluye sentence-transformers
python ingest_dane.py          # 132 entidades DANE (33 dept + 99 municipios)
python ingest_osm.py           # ~7,500 estaciones + barrios de OSM (tarda ~10 min)
python merge_dedupe.py         # dedup → kg_canonical.jsonl
python build_chunks.py         # genera embed_text por entidad
python embed.py                # embeddings locales 384-dim (~3 min)
# Aplicar 007_fix_embedding_dim.sql en Supabase SQL Editor
python load_supabase.py        # carga en Supabase + índice HNSW
python validate.py             # precision@1 ≥ 80%, precision@3 ≥ 85%, fallback < 10%
```

**Edge Function `ai-chat`** (desplegada, NO llamada por Flutter directamente):
- Usa Groq + FTS + pgvector para RAG server-side
- Threshold semántico: 0.35 (calibrado para MiniLM 384-dim)
- Para redesplegar: `npx supabase functions deploy ai-chat --no-verify-jwt`

### Navigation — GoRouter

All route paths are constants in `AppRoutes` (`lib/router/app_router.dart`).
Auth redirect re-evaluates automatically on every Supabase auth stream event via `_StreamChangeNotifier`.

**Always use `AppRoutes.*` constants, never raw strings.**

```dart
AppRoutes.home             // '/home'
AppRoutes.wallet           // '/wallet'
AppRoutes.history          // '/history'
AppRoutes.profile          // '/profile'
AppRoutes.aiChat           // '/ai-chat'
AppRoutes.routePlanner     // '/routes'
AppRoutes.routeDetail      // '/routes/detail'
AppRoutes.paymentValidation // '/payment-validation'
AppRoutes.nfcSimulator     // '/debug/nfc-simulator'
```

### Design System

All visual constants in `lib/theme/design_tokens.dart`. Never hardcode colors, spacing, or radii.

```dart
// Colors
GSColors.primary       // #1A1A2E — dark navy (backgrounds)
GSColors.accent        // #00D4AA — teal (CTAs, active states)
GSColors.accentAlt     // #6C63FF — violet (eco points, card gradients)
GSColors.eco           // #3CB371 — green (eco/sustainability)

// Transport mode colors
GSColors.bus / .metro / .bike / .walk / .taxi / .car

// Spacing scale (use these, never raw numbers)
GSSpacing.s1=4  s2=8  s3=12  s4=16  s5=20  s6=24  s8=32

// Radii
GSRadius.sm=8  .md=12  .lg=16  .xl=20  .xxl=28  .full=9999
GSRadius.cardRadius / .buttonRadius / .sheetRadius

// Sizes
GSSize.bottomNav=72   GSSize.topBar=56   GSSize.touchTarget=44
```

**Reusable widgets** (all in `lib/widgets/`, prefixed `GS*`):
- `GSButton`, `GSIconButton`
- `GSCard`, `GSInfoCard`, `GSOptionCard`, `GSModeChip`
- `GSTextField`, `GSSearchBar`
- `GSBottomNav`, `GSBottomSheet`
- `GSToast`, `GSSkeletonLoader`, `GSEmptyState`

## Key Patterns

**Consuming providers (screens use ConsumerWidget or ConsumerStatefulWidget):**
```dart
// Reactive (rebuilds on state change)
final profile = ref.watch(profileProvider);

// One-shot (button tap, no rebuild)
ref.read(profileProvider.notifier).updateProfile(name: 'New Name');
```

**Safe toasts after async gaps** (avoids `use_build_context_synchronously` lint error):
```dart
final messenger = ScaffoldMessenger.of(context);
await someAsyncOperation();
GSToast.showWithMessenger(messenger, message: 'Done');
```

**Bottom nav scroll padding** — always add nav + safe area below scrollable content:
```dart
SizedBox(height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom + GSSpacing.s4)
```

**Layout overflow prevention** — in Row children with dynamic text, wrap the text Column in `Expanded` and add `maxLines + overflow`:
```dart
Row(children: [
  Icon(...),
  SizedBox(width: GSSpacing.s3),
  Expanded(
    child: Column(children: [
      Text(label),
      Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
    ]),
  ),
])
```

**Date picker in Spanish** — requires `flutter_localizations` in `MaterialApp.router`:
```dart
final date = await showDatePicker(
  context: context,
  locale: const Locale('es'),
  ...
);
```

## Models

### ProfileModel (`lib/models/profile_model.dart`)

Fields: `id`, `name`, `email`, `phone?`, `avatarUrl?`, `ecoPoints`, `cedula?`, `city?`, `birthDate?`

> **Cédula is immutable once set.** Check `(profile.cedula ?? '').isNotEmpty` before allowing edit.
> Pass `cedula: null` to `updateProfile()` when the field is locked to avoid overwriting.
> `birth_date` is stored as `DATE` in Postgres and parsed via `DateTime.tryParse()` in `fromMap()`.

### CardModel

Status values: `'active'` | `'locked'` | `'suspended'` | `'lost'`
Currency: `'cop'` | `'usd'` | `'eur'`

### NFC Simulator (`lib/features/nfc_simulator/`)

**The `authorize` Edge Function is NOT deployed.** The simulator uses a local mock:
- `card.status == 'locked'` → CARD_LOCKED
- `card.balance < amount` → INSUFFICIENT_BALANCE
- Otherwise → authorized (simulated TX ID: `sim-XXXXXXXX`)
- 700ms simulated latency
- Shows banner: "Simulación local · No afecta el saldo real"

## Android Requirements

- `MainActivity.kt` must extend `FlutterFragmentActivity` (required by `flutter_stripe`)
- Both `values/styles.xml` and `values-night/styles.xml` must use `Theme.MaterialComponents` parent
- `INTERNET` permission must be present in `AndroidManifest.xml`

## Dependencies (pubspec.yaml)

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.5.0 | Backend, auth, realtime |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^13.2.0 | Navigation |
| `flutter_dotenv` | ^5.1.0 | `.env` loading |
| `flutter_stripe` | ^10.1.1 | Stripe payments |
| `flutter_nfc_kit` | ^3.4.0 | NFC hardware access |
| `qr_flutter` | ^4.1.0 | QR code rendering |
| `google_fonts` | ^6.2.1 | Typography |
| `flutter_map` | ^7.0.2 | OpenStreetMap (no API key) |
| `http` | ^1.2.0 | Direct REST calls (Groq AI) |
| `intl` | ^0.20.2 | Date formatting, localization |
| `flutter_localizations` | sdk | Spanish date picker support |
| `uuid` | ^4.3.3 | Idempotency keys for NFC |

## Common Gotchas

- **PGRST204** "Could not find column X": Column doesn't exist in DB → run the relevant migration in Supabase SQL Editor.
- **`AsyncValue.error` in header**: Never call `load()` inside a catch block without restoring previous state — the `error:` case in `profile_screen.dart` shows "Usuario" (not "Error").
- **`use_build_context_synchronously`**: Never use `context` after `await`. Cache `ScaffoldMessenger.of(context)` before the async call.
- **`flutter_localizations` + `intl` version conflict**: `flutter_localizations` requires `intl ^0.20.x`. If you see a version conflict, bump `intl` in `pubspec.yaml`.
- **`google_generative_ai` SDK**: Do NOT use — Gemini models return 404 or quota errors with the project key. AI uses Groq instead.
- **GoRouter `extra` param**: Data passed via `extra` is lost on deep link or browser refresh — only use it for in-session navigation (e.g., `SmsVerifyScreen` phone number).
- **Supabase Realtime**: `activeCardProvider` holds an active subscription. Dispose it properly or use `ref.onDispose`.
- **`idempotency_key` on transactions**: Always generate a UUID before NFC tap, not after — the key must be sent with the authorization request, not generated from the response.
