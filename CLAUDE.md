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
MAP_PROVIDER=google            # 'google' (default) or 'osm'. Google only if GOOGLE_MAPS_API_KEY starts with AIza; else OSM tiles
SHARE_BASE_URL=                # public_web on GitHub Pages; empty = share sends a Maps point
```

> **No AI key in the app.** Groq is called only from the Edge Function `ai-chat`.
> Stripe was removed; recharges are simulated until Wompi (Fase 7).

Edge Function secrets (Supabase Dashboard → Edge Functions → Secrets, never in `.env`):
`GROQ_API_KEY` (ai-chat); `GOOGLE_MAPS_SERVER_KEY` (maps: Places API New + Routes API; the deploy
workflow falls back to `GOOGLE_MAPS_API_KEY`); `WOMPI_PUBLIC_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET`
(wompi, sandbox; deploy with `--no-verify-jwt` because Wompi's webhook has no JWT). Real top-ups
only when `app_flags.wompi_enabled` is true; otherwise the simulated recharge stays. **Everything runs from GitHub (the user has no local setup):** Actions → `Supabase deploy` (`supabase-deploy.yml`) applies migrations (`supabase/piloto_bundle.sql`, regenerate with `tool/bundle_migrations.sh`; CI checks it is current), sets the admin by email, copies Edge Function secrets from GitHub secrets, deploys the functions and creates the push webhooks (`supabase/push_webhooks.sql`, pg_net). CI's APK gets `.env` from secrets via `tool/write_env.sh` and `GOOGLE_SERVICES_JSON`. GitHub Actions secrets for `supabase-maintenance.yml`:
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
| `011_roles_safety.sql` | `profiles.role` (passenger/driver/admin; trigger impide subirse de rol), `drivers` (solo admin aprueba vía `admin_review_driver`), `driver_documents` + bucket privado `driver-docs`, `vehicles`, `emergency_contacts` (+57, máx. 5), `sos_events` (idempotente), `trip_shares` + RPCs `trip_share_start/update/stop/view`. Sin PostGIS. |
| `012_places_directory.sql` | `places` gazetteer (name + aliases, city, kind, lat/lng, `verified`), `gs_norm()` (sin tildes), trigram index, public RPC `search_places(q, lat, lng, limit)`. Seed (approximate, unverified): `supabase/seed/places_seed.sql`. |
| `013_corridor.sql` | `road_segments` (Troncal por km + desvío, coords aprox.), `road_reports` (tipos cerrados, SIN texto libre), `road_report_votes`. RPCs: `report_road` (límite 6/h, 1 por tramo+tipo/30 min, idempotente), `vote_road_report`, públicas `road_status()` y `road_patterns()`. Cerrada exige confianza ≥ 0,9 (reputación + confirmaciones). |
| `014_transport_graph.sql` | `graph_nodes`, `graph_edges` (modo, minutos, espera, tarifa mín/máx, `segment_ids` de la Troncal, `night_ok`), `fare_rules`; RPC pública `graph_snapshot()`. Semilla aproximada = `test/planner/fixture_graph.dart`. |
| `015_dispatch.sql` | `app_flags` (`dispatch_enabled`), `driver_locations`, `ride_requests` + `ride_offers` (InDrive), `colectivo_departures` + `seat_reservations`, `chained_trips` + `trip_legs` (la `trips` de 001 no se usa). RPCs atómicas con `FOR UPDATE` (D7): `accept_ride`, `accept_offer`, `reserve_seat`; además `request_ride`, `nearby_requests`, `counter_offer`, `ride_transition`, `ride_driver_view`, `publish_departure`, `create_trip`, `trip_leg_transition`, `cancel_trip`, `driver_ping`. Carrera real: `supabase/tests/015_race_test.sh`. |
| `016_payments.sql` | Pago por tramo (D5): `charges` (QR del conductor), `leg_payments` (idempotente; un viaje se paga una vez), `wallet_topups` (Wompi). RPCs: `pay_ride` (saldo o efectivo), `confirm_cash`, `create_charge`, `charge_preview`, `pay_charge`, `trip_receipt`; solo servidor: `wallet_topup_create/settle`. Transferencias con `_wallet_transfer` (bloqueo en orden). Tipo de movimiento nuevo: `earning`. |
| `017_trust_admin.sql` | `ride_ratings` (1–5 + etiquetas cerradas, sin texto libre), bloqueo por 2 impagos confirmados (trigger en `ride_requests`), `user_rating`, `ride_driver_view` con calificación; admin: `admin_driver_queue`, `admin_recent_reports`, `admin_remove_report`, `admin_metrics` (sin datos personales). |
| `018_push.sql` | `push_tokens` + `register_push_token`; `push_targets_for_request` (conductores disponibles ≤ 3 km, vistos hace < 10 min) y `push_targets_for_report` (viajeros en la Troncal), solo service_role. |
| `010_wallet_hardening.sql` | **Security fix for 008.** Drops user UPDATE on `wallets` and INSERT on `wallet_transactions`; revokes `recharge_wallet` from clients; adds `idempotency_key`; new RPC `wallet_recharge_simulated(p_amount, p_idempotency_key)` that uses `auth.uid()`. Backfills wallets for older users. |

**SQL tests:** `supabase/tests/` runs on a plain Postgres 16 (CI job `sql-tests`). `_supabase_stub.sql`
fakes roles, `auth.users` and `auth.uid()` (read from `request.jwt.claim.sub`).
Locally: apply the stub, then the migrations, then the `*_test.sql` file with `psql -v ON_ERROR_STOP=1`.
`001_schema.sql` needs PostGIS (not in CI): tests for 011+ load `_profiles_fixture.sql` instead.

**Public web** (`public_web/`, GitHub Pages via `pages.yml`): `via.html` shows `road_status()` (what
the WhatsApp share of the corridor links to); `viaje.html#t=<token>` shows a shared
trip by calling `trip_share_view` with the anon key. Supabase Edge Functions can't serve HTML on
`*.supabase.co`, so public pages live here. App env `SHARE_BASE_URL` points to it (empty = the
message carries only a Google Maps point).

After running 005+, PostgREST reloads automatically via `NOTIFY pgrst, 'reload schema'`.

> **PGRST204 error** = a column referenced in code doesn't exist in DB yet → run the
> missing migration.

## Architecture

### Directory Structure

```
lib/
├── core/
│   ├── env.dart                  # Typed access to .env via flutter_dotenv
│   ├── money.dart                # formatCop(37000) → "$37.000" (signed: "+$10.000" / "−$2.500")
│   ├── region.dart               # GSRegion: Riohacha/Maicao centers + La Guajira bbox
│   ├── telemetry.dart            # Optional Sentry; Telemetry.degraded(service, code)
│   ├── sync_queue.dart           # Offline write queue (SharedPreferences JSON), idempotency key per op
│   ├── safety_links.dart         # SOS/share texts, wa.me / sms: / tel:123 URIs (pure, tested)
│   └── supabase_client.dart      # GoSmartSupabase.client singleton (initialized once in main)
├── features/                     # Screen-level UI (one folder per feature)
│   ├── ai_chat/                  # AI assistant chat UI
│   ├── admin/                    # /admin (Fase 8): conductores + documentos, moderación, métricas, interruptores
│   ├── auth/                     # Login, register, SMS OTP
│   ├── driver/                   # Modo conductor (DS6, 72 dp): registro, documentos, disponible,
│   │                             #   driver_work_panel (solicitudes cercanas, viaje activo, salidas)
│   ├── legal/                    # Política Ley 1581 y términos (borrador con [PENDIENTE] visible)
│   ├── home/                     # Inicio: Línea del corredor → mapa → hoja "¿A dónde vas?"
│   │   └── widgets/              # HomeMap, MapView (Google Maps o flutter_map), HomeSheetContent, CorridorDetailSheet, QuickPlacesRow
│   ├── nfc_simulator/            # Debug NFC simulator (LOCAL MOCK — no Edge Function)
│   ├── onboarding/               # IntroScreen (3 slides), LocationPermissionScreen
│   ├── payment/                  # Payment validation screen
│   ├── profile/                  # User profile + edit sheets
│   ├── routes/                   # Route planner + route detail
│   ├── safety/                   # SOS sheet (123/WhatsApp/SMS), emergency contacts, trip sharing
│   ├── trust/                    # RateSheet: calificar después del viaje (pasajero y conductor)
│   ├── payments/                 # ScanPayScreen (pagar QR), ChargeScreen (cobrar QR)
│   ├── splash/                   # SplashScreen — animated logo, onboarding routing
│   ├── trip/                     # Pestaña Viaje: viaje encadenado; leg_panels (a pie, mototaxi InDrive, colectivo)
│   └── wallet/                   # Billetera: saldo, recargar/pagar, movimientos (ex-historial), tarjeta
│       └── widgets/              # BalanceHeader, WalletMovements, RechargeSheetContent, CardControls
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
│   └── geocode_suggestion.dart   # Place suggestion: placeName, fullAddress, latLng (null until resolved for Google), placeId
├── planner/                      # Planificador en el celular (D6), Dart puro
│   ├── graph.dart                # TransitMode, GraphNode/Edge, TransportGraph, haversineKm
│   ├── fares.dart                # estimateFare → FareRange (referencia, ±25 %, recargo nocturno)
│   ├── planner.dart              # TripPlanner.plan(PlanRequest) → PlannedTrip (Dijkstra, enganche, bloqueos)
│   └── to_route.dart             # PlannedTrip → RouteResult (rango de tarifa, avisos)
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
│   ├── directions_service.dart   # Google Routes via Edge Function `maps` — walk/drive polylines
│   ├── geocoding_service.dart    # Google Places (Autocomplete New + Details, session token) via `maps`; searchStrict() throws GeocodingException
│   ├── place_search.dart         # placeSearch: directory (places) first, then Google; resolve(s) gets coords on pick; limited = degraded (D8)
│   └── safety_service.dart       # emergency contacts, sos_events, trip_share_* RPCs
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
| `corridorStatusProvider` | `FutureProvider<CorridorStatus>` | `road_status()`; offline → last cached copy marked `isStale`; never cached → `noData()`. Never fake a state |
| `roadSegmentsProvider` | `FutureProvider<List<RoadSegmentGeo>>` | Segment geometry to place a report by GPS (`nearestSegment`) |
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
| `emergencyContactsProvider` | `FutureProvider<List<EmergencyContact>>` | Empty for guests |
| `tripShareProvider` | `StateNotifierProvider<…, TripShare?>` | start()/stop(); pushes location every minute while the app is open |
| `myDriverProvider` | `FutureProvider<DriverProfile?>` | Own driver row + vehicle + uploaded doc kinds; null = never registered |
| `transportGraphProvider` | `FutureProvider<GraphBundle>` | `graph_snapshot()` or the cached copy (planner works offline) |
| `activeTripProvider` | `FutureProvider<ChainedTrip?>` | Planned/in-progress chained trip with legs; null for guests |
| `dispatchEnabledProvider` | `FutureProvider<bool>` | `app_flags.dispatch_enabled` |
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
  - `push` — FCM HTTP v1 (JWT RS256 en `fcm.ts`, probado). Disparada por Database Webhooks en INSERT de
    `ride_requests` y `road_reports` con header `x-webhook-secret`. Secrets `FCM_SERVICE_ACCOUNT`,
    `PUSH_WEBHOOK_SECRET`. Sin ellos responde `skipped`.
  - `maps` — Google Places (Autocomplete New + Place Details) and Routes API proxy; the key never ships
    in the APK. Logic in `google.ts` (tested in `google_test.ts`, no remote imports). Deployed WITH JWT
    verification (the app's anon key is enough). Only points inside Colombia; errors return 200 +
    `{error}` so the app degrades with a notice. NOT verified against the real Google APIs from here.
  - `wompi` — checkout URL with integrity signature + webhook (checksum verified) → `wallet_topup_settle`.
    Signing in `signing.ts` (tested in `signing_test.ts`, no remote imports). NOT verified against the
    real sandbox from this environment.
- **Realtime**: `activeCardProvider` subscribes to `cards` table changes for live balance updates.

### AI Service — Edge Function `ai-chat` (function calling, Fase 5)

```
Flutter AiService                       Edge Function ai-chat (Deno)
  query + history + client_context  ──▶  KG context → Groq 8b (70b fallback) with TOOLS (tools.ts)
                                          server tools: get_corridor_status, search_place, estimate_fare
  ◀── { source: 'tool_call', tool_call: {id,name:'plan_trip',args}, tool_messages }
  TripTool runs the planner ON THE PHONE (D6), then calls again with
  tool_messages + {role:'tool', tool_call_id, content: summary JSON}  ──▶
  ◀── { content, source: 'groq'|'error'|'system', model, error, latency_ms }
```
`sanitizeToolMessages` only accepts assistant tool calls + matching tool replies (no injected
system/user turns). Routes for "Ver en el mapa" come from the planner, never from the model.

- The Groq key never ships in the APK. On any failure the app shows a fallback and calls
  `Telemetry.degraded(service, code)`; the planner keeps working (decision D8).
- No embeddings: HuggingFace/pgvector search was removed from ai-chat (decision E3).
- Tests: `cd backend/functions/ai-chat && deno test normalizer_test.ts tools_test.ts` (CI job
  `edge-functions`). `tools_test.ts` has no remote imports (runs where deno.land is blocked).

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
AppRoutes.history          // '/history' → redirects to /wallet (history lives in the wallet)
AppRoutes.profile          // '/profile'
AppRoutes.aiChat           // '/ai-chat'
AppRoutes.routePlanner     // '/routes'
AppRoutes.routeDetail      // '/routes/detail'
AppRoutes.paymentValidation // '/payment-validation'
AppRoutes.nfcSimulator     // '/debug/nfc-simulator'
AppRoutes.emergencyContacts // '/safety/contacts'  (needs account)
AppRoutes.trip             // '/trip'    (pestaña Viaje; needs account)
AppRoutes.report           // '/report'  (pestaña Reportar; needs account)
AppRoutes.receipt          // '/trip/receipt?id=<trip>'  recibo único (D5)
AppRoutes.scanPay          // '/pay/scan?leg=<leg>'      pagar el QR del conductor
AppRoutes.driverCharge     // '/driver/charge'           cobrar con QR
AppRoutes.admin            // '/admin'   (solo role=admin; el servidor revalida con is_admin())
AppRoutes.driver           // '/driver'  (modo conductor; needs account)
AppRoutes.driverSignup     // '/driver/signup'
AppRoutes.privacy / .terms // '/legal/privacy', '/legal/terms' (public)
```

**Onboarding flow** (controlled by `SharedPreferences` key `onboarding_complete`):
- First launch: `/splash` → `/intro` → `/location-permission` → `/home` (guest)
- Returning user: `/splash` → `/home` (with or without session)
- **Guest mode (DS3):** public pages are splash, intro, location-permission, auth pages,
  `/home`, `/routes`, `/routes/detail`, `/ai-chat`, `/trip`, `/report` and `/legal/*`. Anything else
  redirects to login.
  Actions that need an account (saving Casa/Trabajo, eco-points, wallet, reports, rides)
  check `isGuestProvider` and send the user to `AppRoutes.login`.

### Design System

**`DESIGN.md` (repo root) is the source of truth**: redesign of 2026-10-15, "familiar e intuitivo",
built to the craft level of InDrive, Google Maps, Nequi and Uber/DiDi (the user's choice, recorded
in PRODUCT.md). It replaces the old "rótulo de colectivo" world (Barlow Condensed, ultramar shell,
uppercase plates, fuchsia stripe): don't bring any of that back. Token sidecar: `.impeccable/design.json`.
Direction contract: `.impeccable/surfaces/lib-main-dart.md`. `lib/theme/design_tokens.dart` mirrors it.

**Design skills in `.claude/skills/`** (use them for every UI task): `impeccable` (process,
critique/audit/polish/harden, Android rules, `reference/craft-floor.md`), `taste-skill` + `redesign-skill`
(anti-slop, complete states), `emil-design-eng` + `animate` + `review-animations` (motion). Review
screenshots: `flutter test tool/screenshots/review_shots_test.dart` writes `.impeccable/review/`
(git-ignored; map tiles never load in tests).

World rules:
- White surfaces on a cool light grey (`#F4F6FA`) and white top and bottom bars.
- One brand blue, `GSColors.brand` `#0B4FC4`: primary buttons, selection, route, wallet balance card.
- Figtree 400–800, bundled as static instances, in sentence case with tabular figures for numbers.
- Pills for buttons, search, chips and avatars; radii 8/12/16/24 (cards 16, sheets 24).
- Soft tinted shadows only on things floating over the map.
- Red/amber/green (`road*`) only for road state, always with icon and word.
- Mode colours only for legs and markers: use `RouteLeg.liveColor`, never `leg.color` (that one is fixed at creation and goes dark at night).
- Contrast 7:1; 48 dp touch targets (72 in driver mode).
- Motion: press scale 0.97 in 120 ms `GSCurve.enter` (`GSPressable`, `GSButton`); sheets 250/200 ms; no tab-change animation; respect `MediaQuery.disableAnimations`.
- Large text up to 200 % with no mid-word breaks: use a single line with `FittedBox(scaleDown)` for short labels.
- Never show a made-up price: modes without a fare rule say "Precio en la ruta".

**Day and night:** `GSColors.*` are getters over the active palette (`GSPalette.light` / `.dark`);
`main.dart` applies it from the theme brightness and rebuilds the tree on change. Colors are NOT
`const`: never keep a color in a `static final` (it would freeze the first scheme). In tests,
call `GSColors.apply(...)` BEFORE building a widget tree whose colors you read.

```dart
GSColors.shell / .onShell / .onShellMuted     // bars: white by day, surface at night
GSColors.brand / .brandPressed / .onBrand / .onBrandMuted / .brandTint
GSColors.background / .surface / .surfaceSunken / .text / .textMuted / .line
GSColors.roadOpen / .roadCaution(+Tint) / .roadClosed(+Tint) / .roadUnknown  // road status ONLY
GSColors.bus / .taxi / .walk / .bike / .car                                    // legs and markers only
GSFonts.sans = .display = .mono = 'Figtree'; GSFonts.tabular for numbers
GSCurve.enter / .exit / .move    GSDuration.press / .fast / .sheetIn / .sheetOut
GSSpacing.s1=4 s2=8 s3=12 s4=16 s5=20 s6=24 s8=32    GSRadius.sm=8 .md=12 .lg=16 .xl=24 .full
GSShadow.float (over the map) / .sheet    GSSize.touchTarget=48 .touchTargetDriver=72 .button=52
```

**Reusable widgets** (all in `lib/widgets/`, prefixed `GS*`):
- `GSRoutePlate(text:, from:, detail:, leading:, isActive:, isPlaceholder:, size:)`: place/option card (old name kept)
- `GSPressable(onTap:, semanticLabel:, child:)`: anything tappable that isn't a button (0.97 press)
- `GSGroup(children:)`: rows in a white 16-radius card with inset dividers (Nequi/settings style)
- `GSButton` (pill, Figtree 700, press 0.97, min 48 dp), `GSIconButton`
- `GSCard`, `GSInfoCard`, `GSOptionCard`, `GSModeChip`
- `GSCorridorLine(floating:)`: corridor line; `floating: true` over the map on Home; state always icon + word
- `GSTextField`, `GSSearchBar`
- `GSBottomNav(current: GSNavTab.home|trip|report|wallet|profile)` — navigates by itself; 5 tabs (DS1)
- `GSBottomSheet`
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

**Bottom nav scroll padding** — screens use `Scaffold(extendBody: true, bottomNavigationBar: GSBottomNav…)`,
so the body's `MediaQuery.padding.bottom` ALREADY includes the nav height (it grows with large text).
Don't add `GSSize.bottomNav` again:
```dart
SizedBox(height: MediaQuery.of(context).padding.bottom + GSSpacing.s4)
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

Fields: `id`, `name`, `email`, `phone?`, `avatarUrl?`, `ecoPoints`, `cedula?`, `city?`, `birthDate?`, `role` (`isDriver`/`isAdmin`)

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
| `google_maps_flutter` | ^2.18 | Map when a Google key is set (native gestures, night style) |
| `flutter_map` | ^7.0.2 | Fallback map (OSM) when there is no Google key: tests, admin web |
| `geolocator` | ^13.0.0 | Device GPS location (Android + Web) |
| `intl` | ^0.20.2 | Date formatting, localization |
| `flutter_localizations` | sdk | Spanish date picker support |
| `uuid` | ^4.3.3 | Idempotency keys for NFC |
| `shared_preferences` | ^2.2.2 | Persist `onboarding_complete` flag across launches |
| `sentry_flutter` | ^9.0.0 | Optional error reporting (`SENTRY_DSN`); 8.x broke the APK build (Kotlin 1.6) |
| `url_launcher` | ^6.3 | WhatsApp/SMS/123, Wompi checkout |
| `mobile_scanner` | ^6.0 | Scan the driver's payment QR |
| `collection` | ^1.19 | PriorityQueue for the planner |

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
- **Place search**: screens use `placeSearch.search(q, near:)` (returns `PlaceSearchResult` with
  `items` and `limited`), not `geocodingService` directly. Directory rows with `verified=false` show "aprox.".
  Google suggestions come WITHOUT coordinates: call `placeSearch.resolve(s)` when the user picks one
  (null = show a notice). That closes the Google session, so typing is billed once per pick.
- **`GSChoicePlates<T>`** (`lib/widgets/gs_choice_plates.dart`): pick one of a few options as pills
  (driver signup). The planner uses `ModeSelector` (tiles) and, once both points exist, `ModeOptions` (rows with ~ETA and fare).
- **Driver status is server-only**: the client never writes `drivers.status`; a trigger rejects it and
  editing reviewed fields sends an approved driver back to `pending`.
- **Offline writes** go through `syncQueue.enqueue(SyncOp(kind, key, payload))` with the op's
  idempotency key; register a handler per kind (`safetyService.registerSyncHandlers`) in `main.dart`.
  Flushed at startup and on app resume. Drift was not used (no codegen); fine for small volumes.
- **Planner**: Colectivo/TransPadilla/Intermunicipal are planned locally with `TripPlanner` over
  `transportGraphProvider` + `corridorStatusProvider` (closed segments are never used). If you change
  the SQL seed graph, change `test/planner/fixture_graph.dart` too (the 3 reference cases run on it).
- **Dispatch** (`dispatchService`): never decide races on the client; call the RPC and show
  `DispatchException.message` ('already_taken', 'no_seats'…). Ride and driver screens poll (4–5 s)
  while open; there is no push yet, so a driver with the app closed gets no requests.
- **Payments**: a mototaxi/taxi leg closes only once paid (`pay_ride`, wallet or cash); QR charges are
  `gosmart:pay:<uuid>` (`chargeQrData` / `chargeIdFromQr`). Show `PaymentException.message`.
  The QR is always drawn on white (also at night) so any camera reads it.
- **Admin**: `flutter build web` compiles (checked 2026-10-12); the panel caps at 1200 px for desktop.
  First admin is set by SQL (`UPDATE profiles SET role='admin' WHERE id=…`); users can't self-promote.
- **Push is optional**: `Push.init()` (lib/core/push.dart) does nothing without Firebase; Gradle applies
  google-services only if `android/app/google-services.json` exists (git-ignored).
- **Map**: screens never import a map package; they use `MapView` + `MapViewController` (moveTo, fit).
  Google Maps when `useGoogleMaps` (key `AIza…` in `.env`, also read by Gradle into the manifest), with
  rotate/tilt/compass, `assets/map_styles/night.json` at night and camera bounds on La Guajira;
  otherwise flutter_map with OSM tiles (no Mapbox anymore). Neither was tried on a phone from here.
- **Money formatting**: always `formatCop()` and `GSFonts.mono` for amounts the user compares.
  No red/green for income/expense — the sign carries it (red/green are road-only).
- **`DateFormat(..., 'es')` throws** unless `initializeDateFormatting` ran (it doesn't in this app).
  Format Spanish dates by hand (see `WalletTransactionModel.formattedDate`).
- **`transactionListProvider` / table `transactions`**: no screen uses it since the wallet merge;
  kept for trips (Fase 6). Money movements come from `walletTransactionsProvider`.
- **Wallet vs cards**: `wallets` / `wallet_transactions` (`walletProvider`) is the money model. `cards` / `activeCardProvider` is only the card UI (lock/NFC, future public-transport validators). Never write balances from the client; use RPCs.
- **`AnimatedDefaultTextStyle` / `DefaultTextStyle` replace the inherited style**: always set `fontFamily: GSFonts.sans`, or the text falls back to Roboto.
- **Fonts are bundled** (`pubspec.yaml` → `fonts:` Figtree, static 400–800 made from the variable file with fontTools); no `google_fonts`, no runtime download.
- **`ThemeData(fontFamily:)` overrides every textTheme family**: the type scale is re-applied with
  `base.copyWith(textTheme: base.textTheme.merge(textTheme))` in `app_theme.dart`. Keep that.
- **Draw arrows with `Icons.arrow_forward_rounded`**, never a text glyph.
- **`GSCard` wraps its child in a transparent `Material`** so `ListTile`s inside it render ripples (newer Flutter asserts otherwise).
