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

---

## 2. Design System

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#1A1A2E` | Backgrounds, headers, card text |
| `accent` | `#00D4AA` | CTAs, active indicators, highlights |
| `accentAlt` | `#6C63FF` | Secondary actions, eco points, gradients |
| `surface` | `#FFFFFF` | Cards, sheets, inputs |
| `surfaceDark` | `#F5F6FA` | Section backgrounds |
| `textPrimary` | `#1A1A2E` | Main text |
| `textSecondary` | `#8F9BB3` | Subtitles, labels, placeholders |
| `error` | `#FF4757` | Errors, danger actions |
| `success` | `#2ED573` | Confirmations, success states |
| `warning` | `#FFA502` | Warnings |

Transport mode colors remain: `car`, `taxi`, `bus`, `bike`, `walk`, `metro`.

### Typography

**Font:** `Inter` via `google_fonts` package (already in pubspec.yaml).

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| displayLarge | 32px | Bold | Hero headlines |
| displayMedium | 28px | Bold | Screen titles |
| headlineLarge | 24px | SemiBold | Section headers |
| headlineMedium | 20px | SemiBold | Card titles |
| bodyLarge | 16px | Regular | Body text |
| bodyMedium | 14px | Regular | Secondary body |
| labelLarge | 14px | Medium | Button labels |
| labelSmall | 12px | Medium | Badges, captions |

### Spacing & Radius

Existing `GSSpacing` tokens preserved. Additional:
- Card border radius: `20px` (GSRadius.xl)
- Bottom sheet radius: `28px` (GSRadius.xxl)
- Chip radius: `999px` (GSRadius.full)

### Shadows

Cards: `0 4px 20px rgba(0,0,0,0.08)` — soft floating effect.
Primary button: `0 8px 24px rgba(0,212,170,0.35)` — accent glow.

---

## 3. Architecture

### Directory Reorganization

Screens move from `lib/screens/` to `lib/features/` organized by domain. No logic changes — only file location and import paths updated.

```
lib/
├── core/                          # Unchanged
├── models/                        # Unchanged
├── services/                      # Unchanged
├── providers/                     # Unchanged
├── router/                        # Updated imports only
├── theme/
│   ├── design_tokens.dart         # Updated — new palette + Inter
│   └── app_theme.dart             # Updated — Material 3 with new identity
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
    └── nfc_simulator/
        └── nfc_auth_simulator_screen.dart
```

### Router

`app_router.dart` updated with new import paths. All `AppRoutes.*` constants unchanged.

---

## 4. Navigation

### Bottom Navigation Bar

Redesigned `GSBottomNav` — white background, `accent` active indicator, label visible only on active tab.

| Index | Label | Icon |
|-------|-------|------|
| 0 | Inicio | `home_rounded` |
| 1 | Viajes | `route_rounded` |
| 2 | Billetera | `account_balance_wallet_rounded` |
| 3 | Perfil | `person_rounded` |

Navigation style: Pill-shaped active indicator under icon + label. Inactive tabs show icon only.

---

## 5. Screen Designs

### 5.1 Onboarding Screen
- Full-screen background: dark navy (`#1A1A2E`) with subtle radial gradient
- City/transport illustration (PNG asset, included locally)
- GoSmart logo + tagline centered
- Two CTAs: "Iniciar sesión" (accent button) + "Registrarse" (outline button)

### 5.2 Login Screen
- White background
- Logo + "Bienvenido" headline
- Toggle: SMS / Email — pill-shaped segmented control
- Input fields with Inter font, 20px border radius, accent focus border
- Primary CTA full-width
- Social login row (Google, Apple) — placeholder buttons
- "¿No tienes cuenta? Regístrate" link

### 5.3 Register Screen
- Same clean white layout as login
- Fields: Nombre, Teléfono, Email, Contraseña
- Terms checkbox with tappable links
- Submit button with loading state

### 5.4 Home Screen
- **Background:** Static map PNG (OpenStreetMap tile, stored in assets/) with bottom gradient overlay `#1A1A2E → transparent`
- **Top bar (overlay on map):** Avatar + "Hola, {name}" greeting left, notification bell right. Semi-transparent card background.
- **Bottom sheet:**
  - Pill handle
  - Search bar: "¿A dónde vas?" — large, prominent, rounded (navigates to route planner)
  - Transport mode chips: horizontal scrollable row (Car, Taxi, Bus, Bike, Metro)
  - Stats row: Balance card + Eco Points card side by side
  - "Viajes recientes" section: last 3 transactions compact list
  - AI Chat promo card: accent gradient, "Planifica con IA" CTA

### 5.5 Wallet Screen
- **Physical card component:**
  - Gradient: `#1A1A2E → #6C63FF` (dark navy to violet)
  - Chip icon (golden), card number masked, GoSmart logo
  - Balance displayed large and bold
  - Lock status badge
- **Quick actions row:** Recargar, Pagar, Bloquear — icon + label, tappable
- **Recent transactions:** Last 5 inline with mode icon + amount + date
- **Card controls section:** Lock/unlock toggle, report lost

### 5.6 History Screen
- **Tab bar:** Pill-style segmented tabs (Viajes / Tickets / Recibos)
- **Monthly summary:** Total spent this month, trip count
- **Transaction cards:**
  - Mode icon with color-coded background (GSColors.car/bus/etc.)
  - Route or description
  - Amount right-aligned
  - Date + status badge (Completado / Pendiente / Cancelado)
- **Empty state:** Illustrated empty state with message

### 5.7 Profile Screen
- **Header:** Navy gradient background, large circular avatar (80px) with accent border + camera overlay icon, name, email below
- **Stats row:** Total trips, Eco points — inline chips
- **Settings sections (white cards, 20px radius):**
  - Cuenta: Info personal, Notificaciones (toggle), Idioma
  - Seguridad: Cambiar contraseña, Login biométrico (toggle), Política de privacidad
  - Tarjeta: Bloquear tarjeta, Reportar pérdida
  - Soporte: Centro de ayuda, Chat en vivo, Calificar app
- **Logout button:** Full-width, danger red, with icon
- **Version:** Small centered caption at bottom

### 5.8 Route Planner Screen
- Search fields: From / To with swap button
- Date + passengers picker
- Mode selector chips
- "Buscar rutas" CTA button

### 5.9 Route Detail Screen
- Route summary header (From → To, estimated time)
- Driver/option cards (GSOptionCard refined)
- "Reservar" CTA

---

## 6. Loading States

Every screen implements three states via `AsyncValue.when()`:

| State | Implementation |
|-------|---------------|
| Loading | Skeleton loader (shimmer effect using animated container) |
| Error | Error card with retry button |
| Empty | Illustrated empty state with descriptive message |

**Skeleton loader pattern:** Animated shimmer widget using `AnimatedContainer` + gradient animation. Applied to: transaction list, balance card, profile info.

---

## 7. UX Micro-interactions

- Button press: `ScaleTransition` (scale 0.97 on press)
- Page transitions: Slide + fade (300ms, `Curves.easeInOut`)
- Bottom sheet: Spring physics drag
- Mode chip selection: Scale + shadow animation (existing GSModeChip enhanced)
- Toast notifications: Slide in from bottom + auto-dismiss

---

## 8. Static Map Asset

- Source: OpenStreetMap static tile (pre-downloaded PNG, ~200KB)
- Stored at: `assets/images/map_placeholder.png`
- Displayed with `BoxFit.cover` + gradient overlay
- Animated location pin: pulsing circle animation (existing CustomPaint replaced with Image + overlay)

---

## 9. Implementation Phases

### Phase 1 — Design System (Day 1-2)
1. Update `design_tokens.dart` — new palette, Inter font tokens
2. Update `app_theme.dart` — Material 3 with new colors + Inter
3. Update all `GS*` widgets — new styling

### Phase 2 — Architecture Reorganization (Day 2-3)
1. Create `lib/features/` directory structure
2. Move all screens from `lib/screens/` to `lib/features/`
3. Update `app_router.dart` imports

### Phase 3 — Screen Reconstruction (Day 3-7)
Order: Home → Wallet → History → Profile → Auth screens → Route screens

### Phase 4 — Polish (Day 7+)
1. Loading states + skeleton loaders
2. Micro-interactions + transitions
3. Empty states
4. Static map asset integration
5. Responsiveness audit

---

## 10. Packages

No new packages required beyond existing. Leverage:
- `google_fonts` (already in pubspec) — activate Inter
- `intl` (already in pubspec) — currency/date formatting

Optional additions (low risk):
- `shimmer: ^3.0.0` — production-grade skeleton loaders (alternative to custom animation)

---

## 11. Out of Scope

- Google Maps SDK integration
- Real NFC payments
- Social login (Google/Apple)
- Push notifications backend
- Production deployment
