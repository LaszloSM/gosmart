# GoSmart UI Overhaul — Design Spec
**Date:** 2026-03-14
**Status:** Approved
**Goal:** Elevate the GoSmart Flutter prototype to professional quality resembling modern mobility apps (Uber/InDrive/Bolt) for academic presentation.

---

## 1. Scope & Constraints

- **Not production:** Academic presentation only — no App Store release.
- **Timeline:** More than one week available.
- **Must preserve:** All existing working features (auth, wallet, history, profile, GoRouter navigation, Riverpod providers, Supabase backend).
- **Map:** Static PNG image with gradient overlay (no Google Maps SDK).
- **Creative freedom:** Full — identity, colors, typography can all be updated.
- **Dark mode:** Out of scope. Only light theme is defined and tested.

---

## 2. Design System

### Color Palette — Token Remapping

The existing `GSColors` class is fully replaced. Explicit mapping from old tokens to new:

| New Token | Hex | Old Token Equivalent | Usage |
|-----------|-----|----------------------|-------|
| `primary` | `#1A1A2E` | was `textPrimary` / dark backgrounds | Dark navy — backgrounds, headers |
| `accent` | `#00D4AA` | replaces old `primary` (`#2D5BFF`) as interactive color | CTAs, active indicators, highlights |
| `accentAlt` | `#6C63FF` | replaces old `primaryHover` | Secondary actions, eco points, gradients |
| `accentLight` | `#E6FAF6` | replaces old `primaryLight` | Accent tint backgrounds |
| `surface` | `#FFFFFF` | same as old `surface` | Cards, sheets, inputs |
| `surfaceDark` | `#F5F6FA` | same as old `surface2` | Section backgrounds |
| `border` | `#E8ECF2` | same as old `border` | Dividers, input borders |
| `textPrimary` | `#1A1A2E` | same as old `textPrimary` | Main text |
| `textSecondary` | `#8F9BB3` | same as old `textSecondary` | Subtitles, labels, placeholders |
| `textDisabled` | `#C5CCD9` | same as old `textDisabled` | Disabled text |
| `bg` | `#F5F6FA` | same as old `bg` | App background |
| `eco` | `#3CB371` | same as old `eco` | Eco features |
| `ecoLight` | `#E8F5EE` | same as old `ecoLight` | Eco tint backgrounds |
| `error` | `#FF4757` | same as old `error` | Errors, danger actions |
| `errorLight` | `#FFF0F1` | same as old `errorLight` | Error tint |
| `success` | `#2ED573` | same as old `success` | Confirmations |
| `warning` | `#FFA502` | same as old `warning` | Warnings |
| `info` | `#3498DB` | same as old `info` | Informational |

**Critical rule:** Any existing widget that used `GSColors.primary` as a foreground color on white now uses `GSColors.accent`. The new `GSColors.primary` is only used on dark surfaces or as a background color.

Transport mode colors remain unchanged: `car`, `taxi`, `bus`, `bike`, `walk`, `metro`.

### Typography

**Font:** `Inter` applied via `GoogleFonts.interTextTheme(base)` in `app_theme.dart`. This applies Inter to the entire Material `TextTheme` without needing per-widget overrides.

```dart
// In app_theme.dart — apply Inter globally
textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
  // override specific styles below
),
```

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| displayLarge | 32px | Bold (w700) | Hero headlines |
| displayMedium | 28px | Bold (w700) | Screen titles |
| headlineLarge | 24px | SemiBold (w600) | Section headers |
| headlineMedium | 20px | SemiBold (w600) | Card titles |
| bodyLarge | 16px | Regular (w400) | Body text |
| bodyMedium | 14px | Regular (w400) | Secondary body |
| labelLarge | 14px | Medium (w500) | Button labels |
| labelSmall | 12px | Medium (w500) | Badges, captions |

### Spacing & Radius

Existing `GSSpacing` tokens preserved (s1–s16).

Radius tokens — update values in `design_tokens.dart`:
- `GSRadius.sm` = 8px (unchanged)
- `GSRadius.md` = 12px (unchanged)
- `GSRadius.lg` = 16px (unchanged)
- `GSRadius.xl` = 20px (unchanged)
- `GSRadius.xxl` = **28px** (updated from 24px — used for bottom sheets)
- `GSRadius.full` = 9999px (unchanged)

### Shadows

Cards: `BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 4))` — `0 4px 20px rgba(0,0,0,0.08)`.
Accent button: `BoxShadow(color: Color(0x5900D4AA), blurRadius: 24, offset: Offset(0, 8))` — accent glow.

---

## 3. Architecture

### Directory Reorganization

Screens move from `lib/screens/` to `lib/features/` organized by domain. No logic changes — only file location and import paths updated. `lib/screens/` directory is deleted after all moves.

**Complete file mapping:**

| Old path | New path |
|----------|----------|
| `lib/screens/home/home_screen.dart` | `lib/features/home/home_screen.dart` |
| `lib/screens/wallet/wallet_screen.dart` | `lib/features/wallet/wallet_screen.dart` |
| `lib/screens/history/history_screen.dart` | `lib/features/history/history_screen.dart` |
| `lib/screens/profile/profile_screen.dart` | `lib/features/profile/profile_screen.dart` |
| `lib/screens/onboarding/onboarding_screen.dart` | `lib/features/auth/onboarding_screen.dart` |
| `lib/screens/onboarding/login_screen.dart` | `lib/features/auth/login_screen.dart` |
| `lib/screens/onboarding/register_screen.dart` | `lib/features/auth/register_screen.dart` |
| `lib/screens/onboarding/sms_verify_screen.dart` | `lib/features/auth/sms_verify_screen.dart` |
| `lib/screens/route_planner/route_planner_screen.dart` | `lib/features/routes/route_planner_screen.dart` |
| `lib/screens/route_detail/route_detail_screen.dart` | `lib/features/routes/route_detail_screen.dart` |
| `lib/screens/ai_chat/ai_chat_screen.dart` | `lib/features/ai_chat/ai_chat_screen.dart` |
| `lib/screens/payment_validation/payment_validation_screen.dart` | `lib/features/payment/payment_validation_screen.dart` |
| `lib/screens/nfc_simulator/nfc_auth_simulator_screen.dart` | `lib/features/nfc_simulator/nfc_auth_simulator_screen.dart` |

After moving, `app_router.dart` is updated with all new import paths. All `AppRoutes.*` constants remain unchanged.

```
lib/
├── core/                          # Unchanged
├── models/                        # Unchanged
├── services/                      # Unchanged
├── providers/                     # Unchanged
├── router/                        # Updated imports only
├── theme/
│   ├── design_tokens.dart         # Updated — new palette + radius values
│   └── app_theme.dart             # Updated — Material 3 with new identity + Inter
├── widgets/                       # Updated — GS* components refined
└── features/
    ├── auth/
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   ├── onboarding_screen.dart
    │   └── sms_verify_screen.dart
    ├── home/
    │   └── home_screen.dart
    ├── wallet/
    │   └── wallet_screen.dart
    ├── history/
    │   └── history_screen.dart
    ├── profile/
    │   └── profile_screen.dart
    ├── routes/
    │   ├── route_planner_screen.dart
    │   └── route_detail_screen.dart
    ├── ai_chat/
    │   └── ai_chat_screen.dart
    ├── payment/
    │   └── payment_validation_screen.dart
    └── nfc_simulator/
        └── nfc_auth_simulator_screen.dart
```

---

## 4. Navigation

### Bottom Navigation Bar

Redesigned `GSBottomNav` — white background, `accent` (#00D4AA) active indicator pill, label visible only on active tab. Inactive tabs: icon only.

| Index | Label | Icon | Navigates to |
|-------|-------|------|--------------|
| 0 | Inicio | `home_rounded` | `AppRoutes.home` |
| 1 | Viajes | `route_rounded` | `AppRoutes.history` (trip history, renamed label only) |
| 2 | Billetera | `account_balance_wallet_rounded` | `AppRoutes.wallet` |
| 3 | Perfil | `person_rounded` | `AppRoutes.profile` |

> Tab 1 keeps routing to `AppRoutes.history` (same as existing behavior). The label changes from "Tickets" to "Viajes" to be more intuitive. No route logic changes.

---

## 5. Screen Designs

### 5.1 Onboarding Screen
- Full-screen background: dark navy (`#1A1A2E`) with subtle radial gradient
- Transport illustration: `assets/images/onboarding_illustration.png` (PNG asset)
- GoSmart logo + tagline centered
- Two CTAs: "Iniciar sesión" (accent button full-width) + "Registrarse" (outline button full-width)

### 5.2 Login Screen
- White background, safe area padding
- Logo centered at top
- "Bienvenido de nuevo" headline (displayMedium)
- Toggle: SMS / Email — pill-shaped segmented control with accent active state
- Input fields: `GSTextField` with 20px radius, accent focus border color
- Primary CTA full-width (accent color)
- Social login row (Google, Apple) — placeholder `OutlinedButton` with icon
- "¿No tienes cuenta? Regístrate" link at bottom

### 5.3 Register Screen
- Same white layout
- Fields: Nombre completo, Teléfono, Email, Contraseña
- Consent checkbox row (terms + privacy tappable links)
- Submit button with loading state (existing `GSButton` loading variant)

### 5.4 Home Screen
- **Background:** `assets/images/map_placeholder.png` displayed full-screen with `BoxFit.cover` + gradient overlay `LinearGradient(transparent → #1A1A2E)` at bottom 40%
- **Top bar (Stack overlay on map):** Semi-transparent frosted card (`Color(0xCCFFFFFF)` + blur if available, else white with 0.85 opacity), avatar circle left + "Hola, {name}" (from `profileProvider`), notification bell with red dot right
- **Bottom sheet (DraggableScrollableSheet):**
  - `minChildSize: 0.12`, `maxChildSize: 0.85`, `initialChildSize: 0.45`
  - Pill drag handle (accent color)
  - Search bar: "¿A dónde vas?" — large, rounded (navigates to `AppRoutes.routePlanner`)
  - Transport mode chips: horizontal scrollable `SingleChildScrollView` row — Car, Taxi, Bus, Bike, Metro
  - Stats row: Balance (`activeCardProvider`) + Eco Points (`profileProvider`) in side-by-side `GSInfoCard`
  - "Viajes recientes" section: reads `transactionListProvider`, shows last 3 items as compact `ListTile`-style rows with mode icon + description + amount. If loading → 3 skeleton rows. If empty → "Sin viajes recientes" caption.
  - AI Chat promo card: accent-to-accentAlt gradient card, "Planifica con IA →" CTA

### 5.5 Wallet Screen
- **Physical card component:**
  - `Container` with gradient `#1A1A2E → #6C63FF`, `borderRadius: 20px`, aspect ratio ~1.6
  - Chip icon SVG (golden color), "GoSmart" logo top-right, card number last 4 digits masked
  - Balance large and bold (white text), "Saldo disponible" label
  - Lock badge: red pill "Bloqueada" / green pill "Activa"
- **Quick actions row:** 3 equal-width tappable cards (Recargar, Pagar, Bloquear) with icon + label
- **Recent transactions:** Last 5 inline list with mode icon circle + description + amount + date. If loading → skeleton. If empty → "Sin transacciones" empty state.
- **Card controls section:** Lock/unlock toggle with label, "Reportar pérdida" danger link

### 5.6 History Screen
- **Tabs:** `TabBar` styled as pill segmented control (Viajes / Tickets / Recibos)
- **Monthly summary card:** Total COP spent this month + trip count (from `transactionListProvider`)
- **Transaction list (`transactionListProvider`):**
  - Each item: mode icon circle (color = `GSColors.[mode]`), route description, amount right-aligned, date + status badge
  - Status badge colors: Completado=success, Pendiente=warning, Cancelado=error
  - Pagination: "Cargar más" button at list bottom (calls `loadMore()`)
- **Empty state:** Icon + "No tienes viajes aún" + "Empieza tu primer viaje" CTA

### 5.7 Profile Screen
- **Header:** Container with gradient `#1A1A2E → #6C63FF` (120px height), avatar 80px circle with `accent` border (3px), camera icon overlay. Name (headlineMedium, white) + email (bodyMedium, white70) below avatar.
- **Stats row:** "X Viajes" + "X Puntos Eco" inline chips (from `transactionListProvider` count + `profileProvider`)
- **Settings sections:** `GSCard` containers per group, 20px radius, items as `ListTile` with leading icon, title, trailing chevron or switch.
  - Cuenta: Información personal (opens bottom sheet), Notificaciones (Switch), Idioma
  - Seguridad: Cambiar contraseña (opens bottom sheet), Login biométrico (Switch), Política de privacidad
  - Tarjeta: Bloquear tarjeta (navigates to wallet), Reportar pérdida
  - Soporte: Centro de ayuda, Chat en vivo, Calificar app
- **Logout button:** `GSButton(variant: danger)` full-width with logout icon
- **Version:** "GoSmart v1.0.0" — `labelSmall`, centered, `textSecondary`

### 5.8 Route Planner Screen
- Two `GSTextField` stacked: "Desde" / "Hasta" + swap `IconButton` between
- Date + passengers row
- Mode selector chips (same as home)
- "Buscar rutas" `GSButton` primary full-width

### 5.9 Route Detail Screen
- Route header card: From → To, estimated time, total distance
- `ListView` of `GSOptionCard` (existing, refinished with new colors)
- Sticky bottom "Reservar ahora" CTA

---

## 6. Loading States

Every screen using async data implements three states via `AsyncValue.when()`:

| State | Implementation |
|-------|---------------|
| Loading | `GSSkeletonLoader` widget — custom `AnimatedContainer` shimmer |
| Error | `GSErrorCard` — error icon + message + "Reintentar" button |
| Empty | `GSEmptyState` — icon + message + optional CTA |

### Skeleton Loader Specification

`GSSkeletonLoader` is a new reusable widget in `lib/widgets/gs_skeleton_loader.dart`:
- Animated shimmer: `LinearGradient` cycling left-to-right using `AnimationController` (1200ms loop)
- Colors: `[Color(0xFFE8ECF2), Color(0xFFF5F6FA), Color(0xFFE8ECF2)]`
- API: `GSSkeletonLoader(width: double, height: double, radius: double)`
- Composition: `GSTransactionSkeleton` (row with circle + lines), `GSCardSkeleton` (full card shape)

Applied:
- Home "Viajes recientes": 3× `GSTransactionSkeleton` rows
- Wallet transactions: 5× `GSTransactionSkeleton` rows
- Wallet balance card: `GSCardSkeleton`
- Profile header: shimmer avatar + name line
- History list: 5× `GSTransactionSkeleton` rows

---

## 7. UX Micro-interactions

- **Button press:** `GSButton` wraps child in `GestureDetector` + `AnimatedScale` (scale 0.97, duration 100ms, `Curves.easeIn`) — does not use `ScaleTransition`.
- **Page transitions:** GoRouter `CustomTransitionPage` with slide+fade (300ms, `Curves.easeInOut`) applied globally via `pageBuilder` in router.
- **Bottom sheet:** Existing `DraggableScrollableSheet` spring physics unchanged.
- **Mode chip selection:** Existing `GSModeChip` scale + shadow animation unchanged, accent color applied to active state.
- **Toast notifications:** Existing `GSToast` — no changes needed.

---

## 8. Static Map Asset

**Source:** Download OpenStreetMap static tile:
- URL: `https://tile.openstreetmap.org/13/2048/2730.png` (Bogotá city center, zoom 13)
- Or use a pre-composed city map PNG (800×600px minimum)
- Stored at: `assets/images/map_placeholder.png`
- Registered in `pubspec.yaml` under `flutter: assets:`

**Implementation:**
```dart
Stack(children: [
  Image.asset('assets/images/map_placeholder.png', fit: BoxFit.cover,
    width: double.infinity, height: double.infinity),
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xFF1A1A2E)],
        stops: [0.4, 1.0],
      ),
    ),
  ),
])
```

Animated location pin: `AnimatedContainer` pulsing circle (existing CustomPaint logic converted to positioned overlay on the Stack).

---

## 9. Implementation Phases

### Phase 1 — Design System & Tokens (safest first)
1. Update `design_tokens.dart` — new color palette (token remap table above), update `GSRadius.xxl` to 28px
2. Update `app_theme.dart` — `GoogleFonts.interTextTheme`, new `ColorScheme`, button/input themes
3. Update `GS*` widgets — apply new colors (accent replaces primary for interactive elements), new shadows, new border radii

> At end of Phase 1: app compiles and runs. All existing screens pick up new colors automatically. Some may look inconsistent — that is expected and fixed in Phase 3.

### Phase 2 — Architecture Reorganization
1. Create `lib/features/` subdirectory tree
2. Move each screen file (see complete mapping table in Section 3)
3. Update all import statements in moved files
4. Update `app_router.dart` with new import paths
5. Verify `flutter analyze` passes with 0 errors before proceeding

> Move all files in one commit. Do not start Phase 3 until the build is green.

### Phase 3 — Screen Reconstruction (one screen at a time)
Order: Home → Wallet → History → Profile → Auth (Onboarding, Login, Register) → Route Planner → Route Detail

For each screen:
1. Apply new layout per Section 5 spec
2. Connect existing providers (no provider changes)
3. Apply `GSSkeletonLoader` on async states
4. Verify screen on small (360px) and large (412px) width

### Phase 4 — Polish
1. Add `GSSkeletonLoader` and `GSEmptyState` widgets to `lib/widgets/`
2. Implement `AnimatedScale` on `GSButton`
3. Add `CustomTransitionPage` to GoRouter for slide+fade transitions
4. Download and add `assets/images/map_placeholder.png`
5. Update `pubspec.yaml` assets section
6. Responsiveness audit across all screens
7. `flutter analyze` — zero warnings

---

## 10. Packages

No new packages required. Existing:
- `google_fonts` — Inter via `GoogleFonts.interTextTheme()`
- `intl` — COP currency formatting

Optional (low risk, adds production-grade shimmer):
- `shimmer: ^3.0.0` — if `GSSkeletonLoader` custom implementation feels rough

---

## 11. Out of Scope

- Google Maps SDK integration
- Real NFC payments
- Social login (Google/Apple)
- Push notifications backend
- Dark mode / dark theme
- Production deployment
- New Riverpod providers (all data from existing providers)
