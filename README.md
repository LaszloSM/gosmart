# GoSmart — Setup & Runbook

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/<your-username>/gosmart.git
cd gosmart
flutter pub get
```

### 2. Create Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Choose a region close to Colombia (e.g., `us-east-1`)
3. Save your project URL and anon key

### 3. Apply database migrations

In Supabase Dashboard → SQL Editor, run these files IN ORDER:

```bash
# Option A: Supabase CLI (recommended)
supabase db push

# Option B: Manual (copy-paste in SQL Editor)
# 1. backend/migrations/001_schema.sql
# 2. backend/migrations/002_rls.sql
# 3. backend/migrations/003_functions.sql
```

Verify with `test/sql/integrity_check.sql` in SQL Editor.

### 4. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` with your real values:
```
SUPABASE_URL=https://xyzabcdef.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
STRIPE_PUBLISHABLE_KEY=pk_test_...
GOOGLE_MAPS_API_KEY=AIza...
```

### 5. Configure Supabase Edge Function secrets

In Supabase Dashboard → Edge Functions → Secrets:

```
GEMINI_API_KEY=your-gemini-key-from-aistudio.google.com
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

> ⚠️ These keys NEVER go in `.env` or the repo.
> Note: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically injected by
> Supabase into every Edge Function at runtime — you do NOT need to set them manually.

### 6. Deploy Edge Functions

```bash
# Install Supabase CLI if needed
npm install -g supabase

supabase login
supabase link --project-ref your-project-ref

# Deploy all functions
supabase functions deploy authorize
supabase functions deploy ai-chat
supabase functions deploy stripe-webhook
supabase functions deploy delete-account
```

### 7. Configure Stripe webhook

In [Stripe Dashboard](https://dashboard.stripe.com/test/webhooks) → Add endpoint:
- URL: `https://your-project-ref.supabase.co/functions/v1/stripe-webhook`
- Events: `payment_intent.succeeded`
- Copy the webhook signing secret → set as `STRIPE_WEBHOOK_SECRET`

### 8. Run the app

```bash
flutter run                          # Android emulator / connected device
flutter run -d "iPhone 15 Pro"       # iOS simulator
```

### 9. Test the NFC Simulator

1. Register an account in the app
2. Navigate to the NFC Simulator screen (`/debug/nfc-simulator`)
3. Select validator and amount → tap "Simular Tap NFC"
4. Verify balance decreases in Wallet screen

---

## Security checklist

- [ ] `.env` is in `.gitignore` (never committed)
- [ ] Supabase `service_role` key is ONLY in Edge Function secrets
- [ ] Stripe secret key is ONLY in Supabase secrets
- [ ] `GEMINI_API_KEY` is ONLY in Supabase secrets
- [ ] RLS is enabled on all tables (verify with integrity_check.sql)

## Key rotation

**Supabase keys** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`):
1. Supabase Dashboard → Settings → API → Reset anon key
2. Update `.env` locally
3. Update GitHub secret `SUPABASE_ANON_KEY` in repo Settings → Secrets
4. Redeploy Edge Functions (`supabase functions deploy`)
5. Inform all developers to pull `.env.example` and update `.env`

**Stripe keys** (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PUBLISHABLE_KEY`):
1. Stripe Dashboard → Developers → API keys → Roll key
2. Update `STRIPE_SECRET_KEY` in Supabase Dashboard → Edge Functions → Secrets
3. Update `STRIPE_PUBLISHABLE_KEY` in `.env` locally + GitHub secrets
4. Re-deploy `stripe-webhook` function
5. Test a Stripe sandbox payment to confirm webhook still works

**Gemini API key** (`GEMINI_API_KEY`):
1. Google AI Studio → Manage API keys → Revoke old key → Create new key
2. Update `GEMINI_API_KEY` in Supabase Dashboard → Edge Functions → Secrets
3. Re-deploy `ai-chat` function

---

# GoSmart — Flutter MVP

Universal transit card app with AI routing, NFC payments and multimodal transport planning.

## Stack

| Layer | Tech |
|-------|------|
| UI | Flutter 3.x (Material 3) |
| State | Provider / Riverpod |
| Navigation | `go_router` (or `Navigator 2.0`) |
| Backend | Supabase (Auth + DB + Realtime) |
| Maps | Google Maps Flutter + Mapbox fallback |
| NFC | `nfc_manager` |
| QR | `qr_flutter` + `mobile_scanner` |
| Auth | Supabase Auth (SMS OTP / Email) |
| AI | Claude API via `/ai/recommendations` |

---

## Project structure

```
gosmart/
├── lib/
│   ├── main.dart                   # App entry point
│   ├── theme/
│   │   ├── app_theme.dart          # MaterialApp theme
│   │   └── design_tokens.dart      # Colors, spacing, shadows, durations
│   ├── router/
│   │   └── app_router.dart         # All named routes
│   ├── widgets/                    # Reusable design system components
│   │   ├── gs_button.dart          # GSButton, GSIconButton
│   │   ├── gs_card.dart            # GSCard, GSModeChip, GSInfoCard, GSOptionCard
│   │   ├── gs_bottom_nav.dart      # GSBottomNav (4 tabs)
│   │   ├── gs_bottom_sheet.dart    # GSBottomSheet (draggable)
│   │   ├── gs_toast.dart           # GSToast, GSNotificationBanner
│   │   └── gs_text_field.dart      # GSTextField, GSSearchBar
│   └── screens/
│       ├── onboarding/             # Onboarding, Login, Register, SMS verify
│       ├── home/                   # Map + bottom panel
│       ├── route_planner/          # Origin/dest + 3 alternatives
│       ├── route_detail/           # Driver/option cards
│       ├── wallet/                 # Card, NFC/QR, top-up, controls
│       ├── history/                # Trips, tickets, receipts
│       ├── profile/                # Settings, privacy, support
│       ├── ai_chat/                # Conversational AI modal
│       └── payment_validation/     # Validator result (5 states)
├── design-tokens.json              # Design tokens (colors, spacing, radius…)
├── openapi.yaml                    # Full API contract
└── pubspec.yaml
```

---

## Getting started

### 1. Prerequisites

- Flutter SDK `>=3.2.0` — [install](https://flutter.dev/docs/get-started/install)
- Android Studio / Xcode
- A Supabase project — [supabase.com](https://supabase.com)

### 2. Clone & install

```bash
git clone <repo-url>
cd gosmart
flutter pub get
```

### 3. Environment variables

Create `.env` in the project root:

```env
SUPABASE_URL=https://xyzabcdef.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
GOOGLE_MAPS_API_KEY=your-google-maps-key
MAPBOX_ACCESS_TOKEN=your-mapbox-token
```

> **Never commit `.env`** — it is in `.gitignore`.

Load them in `main.dart` using `flutter_dotenv`:

```dart
await dotenv.load(fileName: ".env");
final supabaseUrl = dotenv.env['SUPABASE_URL']!;
final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
```

### 4. Supabase setup

Run these SQL migrations in your Supabase SQL editor:

```sql
-- Users (extended profile)
create table public.profiles (
  id uuid references auth.users primary key,
  name text,
  eco_points integer default 0,
  avatar_url text,
  created_at timestamptz default now()
);

-- Transit cards
create table public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles,
  number_masked text,
  balance numeric(10,2) default 0,
  currency text default 'USD',
  status text default 'active',
  nfc_enabled boolean default true,
  expires_at text,
  created_at timestamptz default now()
);

-- Transactions
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  card_id uuid references public.cards,
  type text,
  origin text,
  destination text,
  amount numeric(10,2),
  currency text default 'USD',
  status text,
  mode text,
  co2_kg numeric(6,3),
  validator_id text,
  created_at timestamptz default now()
);

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.cards enable row level security;
alter table public.transactions enable row level security;

create policy "own profile" on public.profiles
  for all using (auth.uid() = id);

create policy "own cards" on public.cards
  for all using (auth.uid() = user_id);

create policy "own transactions" on public.transactions
  for all using (
    card_id in (select id from public.cards where user_id = auth.uid())
  );
```

### 5. Android — Google Maps & NFC

In `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- NFC -->
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />

<!-- Google Maps -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}" />
```

In `android/app/build.gradle`, set `minSdkVersion 21`.

### 6. iOS — NFC & Location

In `ios/Runner/Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>GoSmart uses NFC to tap-to-pay at transit validators</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>GoSmart needs your location to show nearby stops and plan routes</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>GoSmart uses background location for live route tracking</string>
```

Add `Near Field Communication Tag Reading` capability in Xcode.

### 7. Run

```bash
# Android emulator
flutter run

# iOS simulator
flutter run -d "iPhone 15 Pro"

# With specific flavor
flutter run --dart-define=ENV=dev
```

---

## Design system

All tokens are mirrored in two places:

| File | Use |
|------|-----|
| `design-tokens.json` | Figma / Style Dictionary / CSS |
| `lib/theme/design_tokens.dart` | Flutter code |

### Key tokens

| Token | Value |
|-------|-------|
| `GSColors.primary` | `#2D5BFF` |
| `GSColors.eco` | `#3CB371` |
| `GSColors.bg` | `#F5F7FB` |
| `GSColors.textPrimary` | `#0B1226` |
| `GSRadius.lg` | `16px` (card radius) |
| `GSSize.touchTarget` | `44px` (WCAG min) |

---

## API

Full OpenAPI 3.1 contract in [`openapi.yaml`](./openapi.yaml).

### Key endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/auth/send-otp` | Send SMS code |
| `POST` | `/auth/verify-otp` | Verify → get JWT |
| `GET` | `/cards/{id}/balance` | Live balance |
| `POST` | `/routes` | Plan routes |
| `POST` | `/transactions/authorize` | Validator tap |
| `POST` | `/payments/recharge` | Top up card |
| `POST` | `/ai/recommendations` | AI routing query |

---

## Screens checklist

| Screen | States covered |
|--------|---------------|
| Onboarding | 3 slides, CTA |
| Login | Phone/email toggle, SMS verify, social |
| Register | Form + terms + OTP flow |
| Home | Map, mode selector, bottom panel, notifications |
| Route Planner | 3 alternatives (fastest/cheapest/eco), timeline |
| Route Detail | Driver cards, booking sheet |
| Wallet | NFC/QR toggle, card controls, top-up sheet |
| History | Trips tab (summary + list), tickets, receipts |
| Profile | Settings, privacy, card controls, support |
| AI Chat | Suggestions, bubbles, typing indicator |
| Payment Validation | 5 states: processing / authorized / insufficient / error / offline |

---

## Figma guide

Since the code is generated, import the design tokens to Figma via:

1. Install **Tokens Studio** plugin in Figma
2. Import `design-tokens.json`
3. Apply tokens to a blank Frame — all colors, radius and spacing will sync

### Prototype flow

```
Onboarding → Login → SMS Verify → Home
                ↓           ↓
            Register    Route Planner → Route Detail → Payment Validation
                                    ↓
                                  Wallet / History / Profile / AI Chat
```

---

## Accessibility

- All touch targets ≥ 44×44px (`GSSize.touchTarget`)
- Contrast ratio ≥ 4.5:1 (WCAG AA) for primary text
- `Semantics` wrappers on all interactive widgets
- Screen reader labels on icons and buttons
- `textScaleFactor` respected via `MediaQuery`
- i18n-ready: all strings can be extracted to ARB files

---

## Roadmap (post-MVP)

- [ ] Supabase Realtime for live balance updates
- [ ] Google Maps polyline rendering on route legs
- [ ] Riverpod state management (replace mock data)
- [ ] Push notifications (FCM / APNs)
- [ ] Offline mode with local SQLite cache
- [ ] Dark mode theme
- [ ] Accessibility audit (TalkBack / VoiceOver)
- [ ] Unit + widget tests
