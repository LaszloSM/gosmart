# GoSmart UI Quick Wins Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply 6 glassmorphism-style UI polish improvements (bottom nav, wallet card, quick actions, home header, skeleton loaders, payment success animation) without touching business logic or routing.

**Architecture:** Each QW is a self-contained change to one or two files. A shared token foundation (Chunk 1) is required before any QW. QW-1 also requires `extendBody: true` on three screens — those prereqs are bundled with QW-1. Every chunk ends with `flutter analyze` passing clean.

**Tech Stack:** Flutter 3.x, Dart, Riverpod 2.x, `dart:ui` (BackdropFilter), `dart:math` (particle geometry)

**Spec:** `docs/superpowers/specs/2026-03-14-ui-quickwins-design.md`

---

## Chunk 1: Design Tokens Foundation

**Files:**
- Modify: `lib/theme/design_tokens.dart` (append new abstract classes)
- Create: `design/quickwins/design-tokens.json`

---

### Task 1: Add GSGlass, GSGradient, GSAnimDuration, GSColors.cardGold to design_tokens.dart

**Files:**
- Modify: `lib/theme/design_tokens.dart`

- [ ] **Step 1: Open `lib/theme/design_tokens.dart` and append the following block at the end of the file (after `GSSize`)**

```dart
abstract class GSGlass {
  static const double blur = 20;
  static const double backgroundOpacity = 0.72;
  static const double borderOpacity = 0.18;
  static const double borderWidth = 1.0;
}

abstract class GSGradient {
  static List<Color> get accentPill => [GSColors.accent, GSColors.accentAlt];
  static List<Color> get cardGloss =>
      [Colors.white.withValues(alpha: 0.08), Colors.transparent];
  static List<Color> get avatarRing => [GSColors.accent, GSColors.accentAlt];
}

abstract class GSAnimDuration {
  static const countUp = Duration(milliseconds: 800);
  static const checkmarkStroke = Duration(milliseconds: 600);
  static const particleBurst = Duration(milliseconds: 700);
  static const int skeletonStagger = 80; // ms per item
  static const pillSlide = Duration(milliseconds: 200);
}
```

- [ ] **Step 2: Add `cardGold` to `GSColors` (inside the existing `abstract class GSColors`, after the `metro` line)**

```dart
  // ── Card ───────────────────────────────────────────────────────────────────
  static const cardGold = Color(0xFFC9A84C);
```

- [ ] **Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/theme/design_tokens.dart
git commit -m "feat(tokens): add GSGlass, GSGradient, GSAnimDuration, GSColors.cardGold"
```

---

### Task 2: Create design/quickwins/design-tokens.json

**Files:**
- Create: `design/quickwins/design-tokens.json`

- [ ] **Step 1: Create the JSON mirror file**

```json
{
  "colors": {
    "accent": "#00D4AA",
    "accentAlt": "#6C63FF",
    "accentLight": "#E6FAF6",
    "accentAltLight": "#EEEDFF",
    "success": "#2ED573",
    "cardGold": "#C9A84C",
    "surface": "#FFFFFF",
    "bg": "#F5F6FA",
    "border": "#E8ECF2",
    "textPrimary": "#1A1A2E",
    "textSecondary": "#8F9BB3",
    "textDisabled": "#C5CCD9"
  },
  "glass": {
    "blur": 20,
    "backgroundOpacity": 0.72,
    "borderOpacity": 0.18,
    "borderWidth": 1.0
  },
  "gradient": {
    "accentPill": ["#00D4AA", "#6C63FF"],
    "cardGloss": ["rgba(255,255,255,0.08)", "rgba(255,255,255,0.00)"],
    "avatarRing": ["#00D4AA", "#6C63FF"]
  },
  "animDuration": {
    "countUp": 800,
    "checkmarkStroke": 600,
    "particleBurst": 700,
    "skeletonStaggerPerItem": 80,
    "pillSlide": 200
  },
  "shadow": {
    "glassNav": "0 -4px 24px rgba(0,212,170,0.08)",
    "cardGlow": "0 8px 32px rgba(108,99,255,0.24)"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add design/quickwins/design-tokens.json
git commit -m "feat(design): add quickwins design-tokens.json mirror"
```

---

## Chunk 2: QW-1 — Bottom Nav Glassmorphism

**Files:**
- Modify: `lib/widgets/gs_bottom_nav.dart`
- Modify: `lib/features/wallet/wallet_screen.dart` (extendBody: true only)
- Modify: `lib/features/history/history_screen.dart` (extendBody: true only)
- Modify: `lib/features/profile/profile_screen.dart` (extendBody: true only)

---

### Task 3: Add extendBody: true to the three Scaffolds that don't have it

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`
- Modify: `lib/features/history/history_screen.dart`
- Modify: `lib/features/profile/profile_screen.dart`

- [ ] **Step 1: In each of the three files, find `return Scaffold(` and add `extendBody: true,` as the first property**

In `wallet_screen.dart`, `history_screen.dart`, and `profile_screen.dart`:
```dart
// Before:
return Scaffold(
  body: ...

// After:
return Scaffold(
  extendBody: true,
  body: ...
```

Note: `home_screen.dart` already has `extendBody: true` — do NOT modify it.

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/wallet/wallet_screen.dart lib/features/history/history_screen.dart lib/features/profile/profile_screen.dart
git commit -m "fix(scaffold): add extendBody: true for BackdropFilter blur support"
```

---

### Task 4: Replace GSBottomNav with glass + gradient pill + always-visible labels

**Files:**
- Modify: `lib/widgets/gs_bottom_nav.dart`

- [ ] **Step 1: Replace the entire file with the following**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Glass bottom navigation bar.
/// Active tab: gradient pill (teal→violet) with icon + label.
/// Inactive tabs: icon + label (9sp, muted).
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.route_rounded, label: 'Viajes'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Billetera'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GSGlass.blur,
          sigmaY: GSGlass.blur,
        ),
        child: Container(
          height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: GSColors.surface.withValues(alpha: GSGlass.backgroundOpacity),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: GSGlass.borderOpacity),
                width: GSGlass.borderWidth,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: List.generate(
                _items.length,
                (index) => Expanded(
                  child: _NavTile(
                    item: _items[index],
                    isActive: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: GSAnimDuration.pillSlide,
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? GSSpacing.s3 : GSSpacing.s2,
              vertical: GSSpacing.s1,
            ),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(GSRadius.full),
                    gradient: LinearGradient(
                      colors: GSGradient.accentPill,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  )
                : const BoxDecoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: GSSize.iconLg,
                  color: isActive ? Colors.white : GSColors.textDisabled,
                ),
                if (isActive) ...[
                  const SizedBox(width: GSSpacing.s1),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (!isActive)
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: GSColors.textDisabled,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Visual verification checklist**

Run the app (`flutter run`) and verify:
- [ ] Bottom nav has a frosted/blurred appearance over the map on the Home screen
- [ ] Active tab shows a teal→violet gradient pill with white icon + white label
- [ ] Inactive tabs show a small gray label (9sp) below the icon
- [ ] Transitioning between tabs animates the pill smoothly (200ms)
- [ ] On Wallet/History/Profile screens the nav still shows (extendBody working)

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/gs_bottom_nav.dart
git commit -m "feat(nav): glass bottom nav with gradient pill and persistent labels"
```

---

## Chunk 3: QW-2 + QW-3 — Wallet Card Premium + Action Rail

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`

---

### Task 5: Add _ChipWidget, _AnimatedBalance, gloss overlay, and outer glow to the wallet card

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`

- [ ] **Step 1: Read the current `_buildCardSection` method in `wallet_screen.dart` and identify the existing `boxShadow` inside the card's `BoxDecoration`**

The card currently has a `BoxDecoration` with a `boxShadow` (using `GSShadow.card` or similar). Remove that shadow — the outer glow wrapper replaces it.

- [ ] **Step 2: Add the three private helper widgets at the bottom of the file (before the closing `}`)**

```dart
/// Decorative chip on the wallet card.
class _ChipWidget extends StatelessWidget {
  const _ChipWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSRadius.sm),
        border: Border.all(color: GSColors.cardGold, width: 1),
        gradient: LinearGradient(
          colors: [
            GSColors.cardGold.withValues(alpha: 0.6),
            GSColors.cardGold.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// Balance with count-up animation from 0 to [amount].
class _AnimatedBalance extends StatelessWidget {
  const _AnimatedBalance({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: GSAnimDuration.countUp,
      curve: Curves.easeOut,
      builder: (_, value, __) => Text(
        '\$${value.toStringAsFixed(0)} COP',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Wrap the existing card widget in an outer glow Container + ClipRRect, add gloss overlay Stack, replace balance Text with _AnimatedBalance, add _ChipWidget**

Find the card's root widget in `_buildCardSection` (the `Container` or `AnimatedContainer` with the gradient). Wrap it:

```dart
// OUTER: glow wrapper (replaces the removed boxShadow)
Container(
  margin: const EdgeInsets.symmetric(
    horizontal: GSSpacing.s4,
    vertical: GSSpacing.s3,
  ),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(GSRadius.xl),
    boxShadow: [
      BoxShadow(
        color: GSColors.accentAlt.withValues(alpha: 0.24),
        blurRadius: 32,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(GSRadius.xl),
    child: Stack(
      children: [
        // Layer 1: existing gradient card (keep all existing content, just remove its boxShadow)
        _existingCardContent(),
        // Layer 2: gloss overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: GSGradient.cardGloss,
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
)
```

Inside the existing card content:
- Add `const _ChipWidget()` in the top-left of the card (alongside the existing card icon)
- Replace the balance `Text` widget with `_AnimatedBalance(amount: card.balance.toDouble())`

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Visual verification checklist**

- [ ] Card has a soft violet glow beneath it (blurRadius 32)
- [ ] A gold-bordered chip appears in the top-left of the card
- [ ] Balance animates from $0 to the actual value on screen load (800ms)
- [ ] A diagonal gloss sheen is visible on the card surface (top-left lighter)

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/wallet_screen.dart
git commit -m "feat(wallet): premium card — outer glow, gloss overlay, chip, animated balance"
```

---

### Task 6: Replace three separate action tiles with unified action rail

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`

- [ ] **Step 1: Find the `_buildQuickActions` method (or equivalent) that renders the Recargar/Pagar/Bloquear row**

The current code renders three separate `Card`/`GSCard` widgets in a `Row`. Replace the entire method body with:

```dart
Widget _buildQuickActions({
  required VoidCallback onRecargar,
  required VoidCallback onPagar,
  required VoidCallback onBloquear,
  required bool isLocked,
}) {
  final actions = [
    _QuickAction(
      icon: Icons.add_circle_outline_rounded,
      label: 'Recargar',
      color: GSColors.accent,
      onTap: onRecargar,
    ),
    _QuickAction(
      icon: Icons.qr_code_rounded,
      label: 'Pagar',
      color: GSColors.accentAlt,
      onTap: onPagar,
    ),
    _QuickAction(
      icon: isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
      label: isLocked ? 'Desbloquear' : 'Bloquear',
      color: isLocked ? GSColors.success : GSColors.error,
      onTap: onBloquear,
    ),
  ];

  return GSCard(
    padding: EdgeInsets.zero,
    child: IntrinsicHeight(
      child: Row(
        children: List.generate(
          actions.length * 2 - 1,
          (i) {
            if (i.isOdd) {
              return const VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
              );
            }
            final action = actions[i ~/ 2];
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: action.onTap,
                  splashColor: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(GSRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GSSpacing.s4,
                      horizontal: GSSpacing.s2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            action.icon,
                            color: action.color,
                            size: GSSize.iconLg,
                          ),
                        ),
                        const SizedBox(height: GSSpacing.s1),
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GSColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Add the `_QuickAction` data class at the bottom of the file**

```dart
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
```

- [ ] **Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Visual verification checklist**

- [ ] Three actions appear inside a single rounded card
- [ ] Thin vertical dividers separate actions
- [ ] Tapping an action shows a colored ripple
- [ ] Lock/Unlock icon and label reflect the current card state

- [ ] **Step 5: Commit**

```bash
git add lib/features/wallet/wallet_screen.dart
git commit -m "feat(wallet): unified action rail — single card with dividers and ripple feedback"
```

---

## Chunk 4: QW-4 — Home Header Avatar Ring + Greeting

**Files:**
- Modify: `lib/features/home/home_screen.dart`

---

### Task 7: Update _greeting() and add avatar ring with initials fallback

**Files:**
- Modify: `lib/features/home/home_screen.dart`

- [ ] **Step 1: Find and replace the existing `_greeting()` method**

```dart
// REPLACE the existing _greeting() — do NOT add a second one
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12) return 'Buenos días';
  if (hour >= 12 && hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}
```

Note: cutoff changes from `< 18` to `< 19` for "tardes", and `>= 6` lower bound added for "días". This is intentional.

- [ ] **Step 2: Add `_initials()` helper method near `_greeting()`**

```dart
String _initials(String? fullName) {
  if (fullName == null || fullName.isEmpty) return '?';
  final parts = fullName.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
```

- [ ] **Step 3: Find the avatar widget in the home screen top bar and replace with the gradient ring version**

Find where `CircleAvatar` is rendered for the user's photo. Replace with:

```dart
Container(
  padding: const EdgeInsets.all(2.5),
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      colors: GSGradient.avatarRing,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: CircleAvatar(
    radius: (GSSize.avatarMd / 2) - 2.5,
    backgroundColor: GSColors.accentLight,
    backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
    child: photoUrl == null
        ? Text(
            _initials(userName),
            style: const TextStyle(
              color: GSColors.accentAlt,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          )
        : null,
  ),
)
```

Where `photoUrl` and `userName` come from `ref.watch(profileProvider)` (already consumed in this screen).

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Visual verification checklist**

- [ ] Avatar shows a teal→violet gradient ring around the photo/initials
- [ ] When no photo URL: initials in violet text on teal-light background
- [ ] Greeting says "Buenos días" between 6–11h, "Buenas tardes" 12–18h, "Buenas noches" 19–5h

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat(home): avatar gradient ring, initials fallback, updated greeting cutoffs"
```

---

## Chunk 5: QW-5 — Staggered Skeleton Loaders

**Files:**
- Modify: `lib/widgets/gs_skeleton_loader.dart`
- Modify: `lib/features/wallet/wallet_screen.dart` (use GSCardSkeleton(height: 200))

---

### Task 8: Add StaggeredSkeletonList to gs_skeleton_loader.dart

**Files:**
- Modify: `lib/widgets/gs_skeleton_loader.dart`

- [ ] **Step 1: Append `StaggeredSkeletonList` at the end of `gs_skeleton_loader.dart`**

```dart
/// Renders [itemCount] skeleton items with a staggered fade-in entrance.
/// Each item fades in [GSAnimDuration.skeletonStagger]ms after the previous.
///
/// Usage:
/// ```dart
/// StaggeredSkeletonList(
///   itemCount: 5,
///   itemBuilder: (_) => const GSTransactionSkeleton(),
/// )
/// ```
class StaggeredSkeletonList extends StatefulWidget {
  const StaggeredSkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  State<StaggeredSkeletonList> createState() => _StaggeredSkeletonListState();
}

class _StaggeredSkeletonListState extends State<StaggeredSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final totalMs =
        400 + widget.itemCount * GSAnimDuration.skeletonStagger;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs =
        400 + widget.itemCount * GSAnimDuration.skeletonStagger;
    return Column(
      children: List.generate(widget.itemCount, (i) {
        final startFraction =
            (i * GSAnimDuration.skeletonStagger) / totalMs;
        final endFraction =
            ((i * GSAnimDuration.skeletonStagger) + 400) / totalMs;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: Interval(
              startFraction.clamp(0.0, 1.0),
              endFraction.clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ),
          child: widget.itemBuilder(i),
        );
      }),
    );
  }
}
```

Note: `GSAnimDuration.skeletonStagger` is an `int`, so multiply by `int`, then pass to `Duration(milliseconds: ...)`.

Note on mixin choice: `_StaggeredSkeletonListState` uses `SingleTickerProviderStateMixin` because this widget owns exactly one `AnimationController`. The spec's note about using `TickerProviderStateMixin` applies only to `payment_validation_screen.dart` (which has two controllers) — it does NOT apply here.

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/gs_skeleton_loader.dart
git commit -m "feat(skeleton): add StaggeredSkeletonList with per-item fade entrance"
```

---

### Task 9: Use StaggeredSkeletonList in wallet_screen.dart + fix card skeleton height

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`

- [ ] **Step 1: In `wallet_screen.dart`, find where the card is shown in loading state**

Replace any `GSCardSkeleton()` or `GSSkeletonLoader(height: ...)` used for the wallet card with:

```dart
const GSCardSkeleton(height: 200)
```

The wallet card renders at 200px — the skeleton must match.

- [ ] **Step 2: Find the transaction list loading state in `wallet_screen.dart`**

Replace any `Column` of repeated `GSTransactionSkeleton()` with:

```dart
StaggeredSkeletonList(
  itemCount: 5,
  itemBuilder: (_) => const GSTransactionSkeleton(),
)
```

- [ ] **Step 3: Verify the import for `gs_skeleton_loader.dart` covers `StaggeredSkeletonList`**

`StaggeredSkeletonList` lives in `gs_skeleton_loader.dart` alongside `GSCardSkeleton` and `GSTransactionSkeleton`. If `wallet_screen.dart` already imports that file (which it likely does, since it uses `GSCardSkeleton`), no new import is needed — `StaggeredSkeletonList` is exported from the same file. Only add the import if it is genuinely absent:

```dart
import '../../widgets/gs_skeleton_loader.dart';
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Visual verification checklist**

- [ ] On slow connection / loading state: wallet card skeleton is ~200px tall (same height as real card)
- [ ] Transaction skeletons appear one by one with 80ms stagger instead of all at once

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/wallet_screen.dart
git commit -m "feat(wallet): use StaggeredSkeletonList and correct card skeleton height (200px)"
```

---

## Chunk 6: QW-6 — Payment Success Animation

**Files:**
- Modify: `lib/features/payment/payment_validation_screen.dart`

---

### Task 10: Add AnimatedCheckmark and AnimatedParticleBurst, wire to authorized state

**Files:**
- Modify: `lib/features/payment/payment_validation_screen.dart`

- [ ] **Step 1: Add `import 'dart:math' show cos, sin, pi;` at the top of the file (after existing imports)**

```dart
import 'dart:math' show cos, sin, pi;
```

- [ ] **Step 2: Change `SingleTickerProviderStateMixin` to `TickerProviderStateMixin` in the state class**

```dart
// Before:
    with SingleTickerProviderStateMixin {

// After:
    with TickerProviderStateMixin {
```

- [ ] **Step 3: Add `_successCtrl` AnimationController alongside `_pulseCtrl` in the state class**

```dart
late final AnimationController _pulseCtrl;   // existing — no changes
late final AnimationController _successCtrl; // new
```

- [ ] **Step 4: Initialize `_successCtrl` in `initState` (after `_pulseCtrl` init)**

```dart
_successCtrl = AnimationController(
  vsync: this,
  duration: GSAnimDuration.particleBurst,
);
```

- [ ] **Step 5: Dispose `_successCtrl` in `dispose`**

```dart
@override
void dispose() {
  _pulseCtrl.dispose();
  _successCtrl.dispose();
  super.dispose();
}
```

- [ ] **Step 6: Trigger `_successCtrl.forward(from: 0)` when transitioning to `authorized` state**

Find the `setState` call where `_state = PaymentValidationState.authorized` is set. Add the trigger immediately after:

```dart
setState(() {
  _state = PaymentValidationState.authorized;
  // ... existing field assignments ...
});
_successCtrl.forward(from: 0); // trigger success animation
```

- [ ] **Step 7: Append the three animation widgets at the bottom of the file**

```dart
// ─── Payment success animation widgets ───────────────────────────────────────

class _AnimatedCheckmark extends StatelessWidget {
  const _AnimatedCheckmark({
    required this.controller,
    this.size = 64,
    required this.color,
  });

  final AnimationController controller;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        size: Size(size, size),
        painter: _CheckmarkPainter(
          progress: CurvedAnimation(
            parent: controller,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
          ).value,
          color: color,
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.3);

    final metrics = path.computeMetrics().first;
    final drawn = metrics.extractPath(0, metrics.length * progress);

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

class _AnimatedParticleBurst extends StatelessWidget {
  const _AnimatedParticleBurst({
    required this.controller,
    this.size = 200,
  });

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        size: Size(size, size),
        painter: _ParticleBurstPainter(
          progress: CurvedAnimation(
            parent: controller,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ).value,
        ),
      ),
    );
  }
}

class _ParticleBurstPainter extends CustomPainter {
  const _ParticleBurstPainter({required this.progress});

  final double progress;
  static const _count = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final distance = 60 * Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * pi;
      final color = i.isEven ? GSColors.success : GSColors.accent;

      canvas.save();
      canvas.translate(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 4, height: 12),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress;
}
```

- [ ] **Step 8: Extract `_buildAuthorizedState()` method and call it from the authorized branch**

Add this private method to `_PaymentValidationScreenState` (alongside the other `_build*` methods that render each state):

```dart
Widget _buildAuthorizedState() {
  return SizedBox(
    width: 200,
    height: 200,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Ripple background
        AnimatedBuilder(
          animation: _successCtrl,
          builder: (_, __) {
            final t = CurvedAnimation(
              parent: _successCtrl,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ).value;
            return Container(
              width: 60 + 100 * t,
              height: 60 + 100 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GSColors.success.withValues(alpha: 0.12 * (1 - t)),
              ),
            );
          },
        ),
        // Particles
        _AnimatedParticleBurst(controller: _successCtrl),
        // Checkmark
        _AnimatedCheckmark(
          controller: _successCtrl,
          color: GSColors.success,
        ),
      ],
    ),
  );
}
```

Then find the existing `authorized` case in the state's build switch/if-else and replace the static icon widget with a call to `_buildAuthorizedState()`.

- [ ] **Step 9: Run flutter analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 10: Visual verification checklist**

Run the app and trigger a payment (or use the dev demo switcher on the screen):
- [ ] On "Authorized" state: a green ripple expands outward from center
- [ ] Checkmark strokes in (not appears instantly) over ~600ms
- [ ] 12 colored particles burst radially outward and fade
- [ ] On "Processing" state: existing pulse animation unchanged
- [ ] On "Insufficient" / "Error" states: no success animation plays

- [ ] **Step 11: Commit**

```bash
git add lib/features/payment/payment_validation_screen.dart
git commit -m "feat(payment): animated checkmark stroke + particle burst on authorized state"
```

---

## Final Verification

- [ ] **Run full analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Run all widget tests**

```bash
flutter test
```

Expected: All existing tests pass (no regressions).

- [ ] **Final commit if anything was missed**

```bash
git add -A
git status
# Only commit if there are unstaged relevant changes
```
