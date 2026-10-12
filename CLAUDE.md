# CLAUDE.md — GoSmart

GoSmart is a mobility app (Flutter/Dart) backed by Supabase, scoped to the MVP for
Riohacha, Maicao and the Troncal del Caribe corridor (La Guajira, Colombia).
Plan and decisions: `docs/PLAN_MVP_GUAJIRA.md`. Long-term vision: universal transport card.

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

Copy `.env.example` to `.env` (it is also declared as an asset, so `flutter test` needs it).
Required at startup (app crashes if missing):

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_MAPS_API_KEY=AIza...
```

Optional:

```
SENTRY_DSN=                    # empty = no error reporting (lib/core/telemetry.dart)
MAP_PROVIDER=google            # 'google' (default) or 'osm' for OpenStreetMap
MAPBOX_PUBLIC_TOKEN=pk.eyJ... # Mapbox public token; if empty, map falls back to OSM
```

> **No AI key in the app.** Groq is called only from the Edge Function `ai-chat`.
> Stripe was removed; recharges are simulated until Wompi (Fase 7).

Edge Function secrets (Supabase Dashboard → Edge Functions → Secrets, never in `.env`):
`GROQ_API_KEY` (ai-chat). GitHub Actions secrets for `supabase-maintenance.yml`:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL` (all optional; steps skip if absent).

## Database Migrations

All migrations live in `supabase/migrations/`. Run them in order in the Supabase SQL Editor. Each is safe to re-run (IF NOT EXISTS guards).

| File | Description |
|------|-------------|
| `001_schema.sql` | Tables: profiles, cards, transactions, trips, validators, operators, payment_methods, recharges |
| `002_rls.sql` | Row-Level Security policies — all tables filter by `auth.uid()` automatically |
| `003_functions.sql` | DB functions: `handle_new_user` trigger (auto-creates profile + card on signup), `fn_eco_points` |
| `004_ai_latency_log.sql` | `ai_latency_log` table — telemetry for AI response times |
| `005_profile_extra_fields.sql` | Adds `phone`, `cedula`, `city`, `birth_date` to profiles — **required for profile editing** |
| `006_colombia_kg.sql` | RAG Colombia KG: `colombia_kg`, `colombia_kg_aliases`, `colombia_kg_embeddings` (vector 384), `rag_fallback_log`. Requires pgvector. |
| `007_fix_embedding_dim.sql` | Cambia `colombia_kg_embeddings.embedding` de `vector(1536)` a `vector(384)` y recrea RPC `match_colombia_kg`. Correr **antes** de `load_supabase.py`. |
| `008_wallet_mock.sql` | Tables: `wallets` (balance INTEGER, card_number, card_status), `wallet_transactions`. RPCs: `recharge_wallet` (row-locking), `generate_gosmart_card_number`. Trigger: `create_wallet_for_new_user` (auto-creates wallet with $10,000 COP welcome balance on signup). |
| `009_favorites_history.sql` | Tables: `favorite_places` (unique partial index per home/work per user), `trip_history`. RPC: `increment_favorite_use`. |
| `010_wallet_hardening.sql` | **Security fix for 008.** Drops user UPDATE on `wallets` and INSERT on `wallet_transactions`; revokes `recharge_wallet` from clients; adds `idempotency_key`; new RPC `wallet_recharge_simulated(p_amount, p_idempotency_key)` that uses `auth.uid()`. Backfills wallets for older users. |

**SQL tests:** `supabase/tests/` runs on a plain Postgres 16 (CI job `sql-tests`). `_supabase_stub.sql`
fakes roles, `auth.users` and `auth.uid()` (read from `request.jwt.claim.sub`).
Locally: apply the stub, then the migrations, then the `*_test.sql` file with `psql -v ON_ERROR_STOP=1`.

After running 005+, PostgREST reloads automatically via `NOTIFY pgrst, 'reload schema'`.

> **PGRST204 error** = a column referenced in code doesn't exist in DB yet → run the
> missing migration.

## Architecture

### Directory Structure

```
lib/
├── core/
│   ├── env.dart                  # Typed access to .env via flutter_dotenv
│   ├── region.dart               # GSRegion: Riohacha/Maicao centers + La Guajira bbox
│   ├── telemetry.dart            # Optional Sentry; Telemetry.degraded(service, code)
│   └── supabase_client.dart      # GoSmartSupabase.client singleton (initialized once in main)
├── features/                     # Screen-level UI (one folder per feature)
│   ├── ai_chat/                  # AI assistant chat UI
│   ├── auth/                     # Login, register, SMS OTP
│   ├── history/                  # Transaction history
│   ├── home/                     # Inicio: Línea del corredor → mapa → hoja "¿A dónde vas?"
│   │   └── widgets/              # HomeMap, HomeSheetContent, CorridorDetailSheet, QuickPlacesRow
│   ├── nfc_simulator/            # Debug NFC simulator (LOCAL MOCK — no Edge Function)
│   ├── onboarding/               # IntroScreen (3 slides), LocationPermissionScreen
│   ├── payment/                  # Payment validation screen
│   ├── profile/                  # User profile + edit sheets
│   ├── routes/                   # Route planner + route detail
│   ├── splash/                   # SplashScreen — animated logo, onboarding routing
│   └── wallet/                   # Wallet / recharge screen (Supabase `wallets`)
├── models/                       # Pure data classes (no Flutter dependencies)
│   ├── ai_models.dart            # AiMessage, ConversationTurn, RouteOption, Leg
│   ├── authorize_result.dart     # NFC authorization result
│   ├── card_model.dart           # CardModel
│   ├── corridor_status.dart      # CorridorStatus, CorridorSegment, RoadState (Línea del corredor)
│   ├── favorite_place.dart       # FavoritePlace, FavoritePlaceType (home/work/custom)
│   ├── profile_model.dart        # ProfileModel (includes cedula, city, birthDate)
│   ├── transaction_model.dart    # TransactionModel
│   ├── wallet_model.dart         # Wallet (table `wallets`; SEPARATE from CardModel)
│   ├── wallet_transaction_model.dart # WalletTransactionModel, WalletTxType enum
│   └── geocode_suggestion.dart   # Address suggestion from Mapbox Geocoding: placeName, fullAddress, latLng
├── providers/                    # Riverpod StateNotifierProviders
│   ├── ai_conversation_provider.dart
│   ├── auth_provider.dart
│   ├── card_provider.dart
│   ├── corridor_provider.dart    # corridorStatusProvider (hoy noData; Fase 4 → road_status)
│   ├── favorites_provider.dart   # FavoritePlace CRUD + home/work/top derived providers
│   ├── profile_provider.dart
│   ├── transaction_provider.dart
│   └── wallet_provider.dart      # Wallet balance, transactions, simulated recharge RPC
├── router/
│   └── app_router.dart           # GoRouter config + AppRoutes constants
├── services/                     # Plain Dart classes (each has a top-level singleton)
│   ├── ai_service.dart           # Thin client of the ai-chat Edge Function
│   ├── auth_service.dart
│   ├── card_service.dart
│   ├── profile_service.dart
│   ├── location_service.dart     # GPS via geolocator — returns LatLng? (null if unavailable)
│   ├── directions_service.dart   # Mapbox Directions API v5 — walking/driving/cycling polylines
│   └── geocoding_service.dart    # Mapbox Geocoding API v5 — address search for Colombia (returns GeocodeSuggestion)
├── theme/
│   ├── app_theme.dart            # MaterialApp ThemeData
│   └── design_tokens.dart        # GSColors, GSSpacing, GSRadius, GSShadow, GSSize, etc.
├── widgets/                      # Reusable GS* components
└── main.dart                     # App entry point — initializes dotenv, Supabase, Sentry (optional)
```

### State Management — Riverpod 2.x (manual, no code gen)

All providers in `lib/providers/`. Pattern: `StateNotifierProvider<Notifier, AsyncValue<T>>`.

| Provider | State | Notes |
|----------|-------|-------|
| `authSessionProvider` | `StreamProvider` | Supabase auth stream |
| `currentUserProvider` | derived from session | |
| `isGuestProvider` | `Provider<bool>` | true without session (guest mode, DS3) |
| `corridorStatusProvider` | `FutureProvider<CorridorStatus>` | Returns `CorridorStatus.noData()` until road reports exist (Fase 4). Never fake a state |
| `activeCardProvider` | `AsyncValue<CardModel>` | Supabase Realtime for live balance |
| `transactionListProvider` | `AsyncValue<List<TransactionModel>>` | paginated (20/page), `loadMore()` |
| `profileProvider` | `AsyncValue<ProfileModel>` | load(), updateProfile(), updatePassword() |
| `aiConversationProvider` | conversation history | |
| `locationProvider` | `FutureProvider<LatLng?>` | One-shot GPS position for initial map center |
| `activeRouteProvider` | `StateProvider<RouteResult?>` | Route currently drawn on home map |
| `selectedModeProvider` | `StateProvider<String>` | Travel mode selected on home ('Auto' default) |
| `walletProvider` | `FutureProvider<Wallet?>` | Wallet row from Supabase (RLS: own wallet only) |
| `walletBalanceProvider` | `Provider<int>` | Current balance, 0 if unavailable |
| `walletNotifierProvider` | `AsyncNotifierProvider` | recharge(amount) calls `wallet_recharge_simulated` with a fresh idempotency key |
| `walletTransactionsProvider` | `FutureProvider.family<..., int>` | Latest wallet transactions (pass limit) |
| `favoritesNotifierProvider` | `AsyncNotifierProvider` | addOrUpdatePlace(), removePlace(), incrementUseCount() |
| `homePlaceProvider` | `Provider<FavoritePlace?>` | Derived — filters favoritePlaces by type=home |
| `workPlaceProvider` | `Provider<FavoritePlace?>` | Derived — filters favoritePlaces by type=work |
| `topFavoritePlacesProvider` | `Provider<List<FavoritePlace>>` | Top 3 by use_count |

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
  - `ai-chat` — Groq proxy used by `AiService` (model `llama-3.1-8b-instant`, falls back to 70b on 429/5xx)
  - `delete-account` — account deletion
- **Realtime**: `activeCardProvider` subscribes to `cards` table changes for live balance updates.

### AI Service — Edge Function `ai-chat`

```
Flutter AiService                       Edge Function ai-chat (Deno)
  query + history + client_context  ──▶  normalize (Riohacha/Maicao) → FTS on colombia_kg_aliases
  (location, traffic, Mapbox route)      → short system prompt → Groq 8b (70b fallback)
  ◀── { content, source: 'groq'|'error'|'system', model, error, latency_ms }
```

- The Groq key never ships in the APK. On any failure the app shows a fallback and calls
  `Telemetry.degraded(service, code)`; the planner keeps working (decision D8).
- No embeddings: HuggingFace/pgvector search was removed from ai-chat (decision E3).
- Tests: `cd backend/functions/ai-chat && deno test normalizer_test.ts` (CI job `edge-functions`).

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
AppRoutes.splash           // '/splash'           ← initialLocation (first screen)
AppRoutes.intro            // '/intro'            ← onboarding slides (first launch only)
AppRoutes.locationPermission // '/location-permission' ← GPS permission request
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

**Onboarding flow** (controlled by `SharedPreferences` key `onboarding_complete`):
- First launch: `/splash` → `/intro` → `/location-permission` → `/home` (guest)
- Returning user: `/splash` → `/home` (with or without session)
- **Guest mode (DS3):** public pages are splash, intro, location-permission, auth pages,
  `/home`, `/routes`, `/routes/detail` and `/ai-chat`. Anything else redirects to login.
  Actions that need an account (saving Casa/Trabajo, eco-points, wallet, reports, rides)
  check `isGuestProvider` and send the user to `AppRoutes.login`.

### Design System

**`DESIGN.md` (repo root) is the source of truth** for color, type, spacing and motion.
Read it before any visual or UI work and ask the user before departing from it; when
reviewing or QA-ing UI, flag code that doesn't match it. Key rules: light theme first
(readable in sun), one brand color `primary` #0B4A57, `road-*` colors only for road
status (always with icon + text), Atkinson Hyperlegible Next/Mono bundled offline,
48px touch targets (72px in driver mode), no cards by default.

`lib/theme/design_tokens.dart` mirrors DESIGN.md. Never hardcode colors, spacing, or radii.
New code uses the DESIGN.md names; the old names (`accent`, `primary`, `eco`, `success`…)
are aliases kept so existing screens compile — `GSColors.primary` is now the **sand
background**, not a dark color, so never put it behind white text.

```dart
GSColors.brand / .onBrand / .brandTint      // mar profundo #0B4A57 + white text
GSColors.background / .surface / .surfaceSunken
GSColors.text / .textMuted / .line
GSColors.roadOpen / .roadCaution(+Tint) / .roadClosed(+Tint) / .roadUnknown  // road status ONLY
GSFonts.sans / GSFonts.mono                 // bundled in assets/fonts (OFL)
GSCurve.enter / .exit / .move               // DESIGN.md motion
GSSize.touchTarget=48  GSSize.touchTargetDriver=72  GSSize.corridorLine=56

// Transport mode colors (current code; Fase 2 replaces metro/bike with local modes)
GSColors.bus / .metro / .bike / .walk / .taxi / .car

// Spacing scale (use these, never raw numbers)
GSSpacing.s1=4  s2=8  s3=12  s4=16  s5=20  s6=24  s8=32

// Radii (DESIGN.md caps at 16; xl/xxl are aliases of lg)
GSRadius.sm=6  .md=10  .lg=16  .full=9999
GSRadius.cardRadius / .buttonRadius / .sheetRadius

// Sizes
GSSize.bottomNav=72   GSSize.topBar=56
```

**Reusable widgets** (all in `lib/widgets/`, prefixed `GS*`):
- `GSButton`, `GSIconButton`
- `GSCard`, `GSInfoCard`, `GSOptionCard`, `GSModeChip`
- `GSCorridorLine` — DESIGN.md corridor line (56 px); state always icon + word, time in mono
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

- `MainActivity.kt` extends `FlutterFragmentActivity` (was required by `flutter_stripe`; kept for future payment SDKs)
- Both `values/styles.xml` and `values-night/styles.xml` must use `Theme.MaterialComponents` parent
- `INTERNET` permission must be present in `AndroidManifest.xml`

## Dependencies (pubspec.yaml)

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.5.0 | Backend, auth, realtime |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^13.2.0 | Navigation |
| `flutter_dotenv` | ^5.1.0 | `.env` loading |
| `flutter_nfc_kit` | ^3.4.0 | NFC hardware access |
| `qr_flutter` | ^4.1.0 | QR code rendering |
| `flutter_map` | ^7.0.2 | Map tiles — Mapbox dark-v11 (with `MAPBOX_PUBLIC_TOKEN`) or OSM fallback |
| `geolocator` | ^13.0.0 | Device GPS location (Android + Web) |
| `http` | ^1.2.0 | Direct REST calls (Groq AI) |
| `intl` | ^0.20.2 | Date formatting, localization |
| `flutter_localizations` | sdk | Spanish date picker support |
| `uuid` | ^4.3.3 | Idempotency keys for NFC |
| `shared_preferences` | ^2.2.2 | Persist `onboarding_complete` flag across launches |
| `sentry_flutter` | ^8.14.2 | Optional error reporting (`SENTRY_DSN`) |

## Common Gotchas

- **PGRST204** "Could not find column X": Column doesn't exist in DB → run the relevant migration in Supabase SQL Editor.
- **`AsyncValue.error` in header**: Never call `load()` inside a catch block without restoring previous state — the `error:` case in `profile_screen.dart` shows "Usuario" (not "Error").
- **`use_build_context_synchronously`**: Never use `context` after `await`. Cache `ScaffoldMessenger.of(context)` before the async call.
- **`flutter_localizations` + `intl` version conflict**: `flutter_localizations` requires `intl ^0.20.x`. If you see a version conflict, bump `intl` in `pubspec.yaml`.
- **`google_generative_ai` SDK**: Do NOT use — Gemini models return 404 or quota errors with the project key. AI uses Groq instead.
- **GoRouter `extra` param**: Data passed via `extra` is lost on deep link or browser refresh — only use it for in-session navigation (e.g., `SmsVerifyScreen` phone number).
- **Supabase Realtime**: `activeCardProvider` holds an active subscription. Dispose it properly or use `ref.onDispose`.
- **`idempotency_key` on transactions**: Always generate a UUID before NFC tap, not after — the key must be sent with the authorization request, not generated from the response.
- **`GSButton` API**: Use `isLoading:` (not `loading:`), `isFullWidth:` (not `fullWidth:`). Variant: `GSButtonVariant.outline / .ghost / .primary`.
- **`GeocodingService`**: Method is `.search(query)` (not `.suggest()`). Returns `List<GeocodeSuggestion>`.
- **Wallet vs cards**: `wallets` / `wallet_transactions` (`walletProvider`) is the money model. `cards` / `activeCardProvider` is only the card UI (lock/NFC, future public-transport validators). Never write balances from the client; use RPCs.
- **`AnimatedDefaultTextStyle` / `DefaultTextStyle` replace the inherited style**: always set `fontFamily: GSFonts.sans`, or the text falls back to Roboto.
- **Fonts are bundled** (`pubspec.yaml` → `fonts:`); there is no `google_fonts` package and no runtime font download.
- **`GSCard` wraps its child in a transparent `Material`** so `ListTile`s inside it render ripples (newer Flutter asserts otherwise).
