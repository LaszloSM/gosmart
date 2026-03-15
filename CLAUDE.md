# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected Android device
flutter run

# Run on specific device
flutter run -d <device-id>          # e.g. flutter devices to list
flutter run -d "iPhone 15 Pro"      # iOS simulator

# Build
flutter build apk                   # Android APK
flutter build ios                   # iOS (requires macOS + Xcode)

# Analyze / lint
flutter analyze

# Tests
flutter test                        # All tests
flutter test test/widget_test.dart  # Single test file

# Code generation (Riverpod annotations, if used)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

### State management — Riverpod 2.x (manual, no code gen)

All providers live in `lib/providers/`. Pattern: `StateNotifierProvider` with `AsyncValue<T>` for async data.

- `auth_provider.dart` — `authSessionProvider` (StreamProvider) + `currentUserProvider` (derives from session)
- `card_provider.dart` — `activeCardProvider`: loads user's active card, subscribes to Supabase Realtime for live balance
- `transaction_provider.dart` — `transactionListProvider`: paginated (20/page), supports `loadMore()`
- `profile_provider.dart` — `profileProvider`: user profile with `load()`, `updateProfile()`, `updatePassword()`

### Backend — Supabase only

- `lib/core/supabase_client.dart` — singleton `GoSmartSupabase.client` (initialized once in `main()`)
- `lib/core/env.dart` — typed access to `.env` via `flutter_dotenv`; app crashes on startup if any required key is missing
- Services in `lib/services/` are plain Dart classes (not providers); each has a top-level singleton (`final authService = AuthService()`)
- Edge Functions in `backend/functions/`: `authorize`, `ai-chat`, `stripe-webhook`, `delete-account`
- DB migrations in `backend/migrations/` must be applied in order (001 → 002 → 003) via Supabase SQL Editor

### Navigation — GoRouter

All routes are constants in `AppRoutes` (in `lib/router/app_router.dart`). Auth redirect is handled by `_StreamChangeNotifier` bridging the Supabase auth stream to GoRouter's `refreshListenable`. Always use `AppRoutes.*` constants instead of string literals.

### Design system

All visual constants (`GSColors`, `GSSpacing`, `GSRadius`, `GSShadow`, `GSSize`, `GSDuration`) live in `lib/theme/design_tokens.dart`. These mirror `design-tokens.json` (used for Figma sync). Reusable widgets in `lib/widgets/` are prefixed `GS*`:

- `GSButton`, `GSIconButton`
- `GSCard`, `GSInfoCard`, `GSOptionCard`, `GSModeChip`
- `GSTextField`, `GSSearchBar`
- `GSBottomNav`, `GSBottomSheet`
- `GSToast` — use `GSToast.showWithMessenger(messenger, ...)` after async gaps to avoid BuildContext lint errors

### Android-specific requirements

- `MainActivity.kt` must extend `FlutterFragmentActivity` (required by `flutter_stripe`)
- Both `values/styles.xml` and `values-night/styles.xml` must use `Theme.MaterialComponents` parent
- `INTERNET` permission must be present in `AndroidManifest.xml`

## Environment

Copy `.env.example` to `.env` and fill in:
```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=eyJ...
STRIPE_PUBLISHABLE_KEY=pk_test_...
GOOGLE_MAPS_API_KEY=AIza...
```

Edge Function secrets (set in Supabase Dashboard → Edge Functions → Secrets, never in `.env`):
`GEMINI_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`

## Key Patterns

**Consuming providers in screens:** Use `ConsumerWidget` or `ConsumerStatefulWidget`. For one-shot operations (button taps), use `ref.read(provider.notifier).method()`. For reactive UI, use `ref.watch(provider)`.

**Safe toasts after async gaps:**
```dart
final messenger = ScaffoldMessenger.of(context);
await someAsyncOperation();
GSToast.showWithMessenger(messenger, message: 'Done');
```

**Supabase queries:** RLS policies on `profiles`, `cards`, `transactions` filter by `auth.uid()` automatically — no need to add user ID filters manually. The `handle_new_user` DB trigger auto-creates a profile + card row on signup.

**Transport mode colors:** Use `GSColors.car/taxi/bus/bike/walk/metro` for mode-specific tinting (defined in design tokens).
