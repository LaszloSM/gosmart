# Map Gestures + Travel Mode Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable all map gestures (drag, fling, double-tap zoom, scroll wheel, pinch, rotate) and connect the home screen travel mode selector to the route planner so it pre-selects the matching route profile.

**Architecture:** New `selectedModeProvider` (StateProvider<String>) shared between home and planner; `InteractiveFlag.all` on the map; mode chip onTap writes to provider; route planner reads on init and shows a mode indicator chip.

**Tech Stack:** Flutter/Dart, flutter_map InteractiveFlag.all, Riverpod StateProvider.

**Spec:** `docs/superpowers/specs/2026-03-17-map-gestures-travel-mode-design.md`

---

## Chunk 1: All three tasks

### Task 1: Create selectedModeProvider

**Files:**
- Create: `lib/providers/selected_mode_provider.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/providers/selected_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';

/// Currently selected travel mode from the home screen mode chips.
/// Values: 'Auto' | 'Taxi' | 'Bus' | 'Bici' | 'Metro'
final selectedModeProvider = StateProvider<String>((ref) => 'Auto');

/// Maps a home-screen travel mode to a Mapbox Directions profile.
/// Single source of truth — do not duplicate this mapping elsewhere.
String routeProfileFor(String mode) => switch (mode) {
      'Bici' => RouteProfile.cycling,
      _ => RouteProfile.driving, // Auto, Taxi, Bus, Metro all use driving
    };

/// Returns the icon for a given travel mode label.
IconData modeIconFor(String mode) {
  // Import flutter/material.dart is via RouteProfile's indirect chain;
  // but IconData needs an explicit import. This file imports route_result.dart
  // which imports flutter/material.dart — so IconData is available.
  return switch (mode) {
    'Taxi' => const IconData(0xe4c0, fontFamily: 'MaterialIcons'), // local_taxi_rounded
    'Bus' => const IconData(0xe1d4, fontFamily: 'MaterialIcons'),  // directions_bus_rounded
    'Bici' => const IconData(0xe1b9, fontFamily: 'MaterialIcons'), // pedal_bike_rounded
    'Metro' => const IconData(0xe4e0, fontFamily: 'MaterialIcons'),// subway_rounded
    _ => const IconData(0xe1d0, fontFamily: 'MaterialIcons'),      // directions_car_rounded
  };
}
```

> **Note on IconData:** Using raw IconData codepoints is fragile. Use `Icons.*` constants instead — they are available because `route_result.dart` imports `package:flutter/material.dart`. Rewrite `modeIconFor` as:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';

/// Currently selected travel mode from the home screen mode chips.
/// Values: 'Auto' | 'Taxi' | 'Bus' | 'Bici' | 'Metro'
final selectedModeProvider = StateProvider<String>((ref) => 'Auto');

/// Maps a home-screen travel mode to a Mapbox Directions profile.
String routeProfileFor(String mode) => switch (mode) {
      'Bici' => RouteProfile.cycling,
      _ => RouteProfile.driving,
    };

/// Returns the icon for a given travel mode label.
IconData modeIconFor(String mode) => switch (mode) {
      'Taxi' => Icons.local_taxi_rounded,
      'Bus' => Icons.directions_bus_rounded,
      'Bici' => Icons.pedal_bike_rounded,
      'Metro' => Icons.subway_rounded,
      _ => Icons.directions_car_rounded,
    };
```

Use this second version (with `Icons.*`). The file imports are:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';
```

- [ ] **Step 2: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/providers/selected_mode_provider.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/selected_mode_provider.dart
git commit -m "feat: add selectedModeProvider and routeProfileFor helper"
```

---

### Task 2: Update home_screen.dart

**Files:**
- Modify: `lib/features/home/home_screen.dart`

Two changes needed:

**Change A — Map gestures:** Find `InteractionOptions` in `_AppMapState.build()` and change the flags.

Current (around line 659):
```dart
interactionOptions: const InteractionOptions(
  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
),
```

Replace with:
```dart
interactionOptions: const InteractionOptions(
  flags: InteractiveFlag.all,
),
```

**Change B — Mode chip writes to provider:**

1. Add import at the top of the file (after existing imports):
```dart
import '../../providers/selected_mode_provider.dart';
```

2. Find the mode chip `onTap` (around line 372-373):
```dart
onTap: () =>
    setState(() => _selectedMode = m.label),
```

Replace with:
```dart
onTap: () {
  setState(() => _selectedMode = m.label);
  ref.read(selectedModeProvider.notifier).state = m.label;
},
```

> `_HomeScreenState` already extends `ConsumerState<HomeScreen>` so `ref` is available directly.

- [ ] **Step 1: Add import**

Add `import '../../providers/selected_mode_provider.dart';` to the imports section of `lib/features/home/home_screen.dart`.

- [ ] **Step 2: Change InteractiveFlag**

Find and replace the `InteractionOptions` flags in `_AppMapState.build()` as shown above.

- [ ] **Step 3: Update mode chip onTap**

Find the mode chip `onTap` in `_HomeScreenState.build()` and replace it as shown above.

- [ ] **Step 4: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/features/home/home_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat: enable all map gestures and write travel mode to provider"
```

---

### Task 3: Update route_planner_screen.dart

**Files:**
- Modify: `lib/features/routes/route_planner_screen.dart`

Three changes:

**Change A — Import:**
```dart
import '../../providers/selected_mode_provider.dart';
```

**Change B — Pre-select profile on init:**

In `_RoutePlannerScreenState.initState()`, after the existing `_resolveOrigin()` call, add:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final mode = ref.read(selectedModeProvider);
  setState(() => _selected = routeProfileFor(mode));
});
```

Current `initState`:
```dart
@override
void initState() {
  super.initState();
  _resolveOrigin();
}
```

New `initState`:
```dart
@override
void initState() {
  super.initState();
  _resolveOrigin();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      final mode = ref.read(selectedModeProvider);
      setState(() => _selected = routeProfileFor(mode));
    }
  });
}
```

**Change C — Mode indicator chip in build():**

In `_RoutePlannerScreenState.build()`, between `_LocationInputs(...)` and the `Padding(...)` containing the search button, add:

```dart
// Mode indicator
Padding(
  padding: const EdgeInsets.fromLTRB(GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
  child: Row(
    children: [
      Icon(
        modeIconFor(ref.watch(selectedModeProvider)),
        size: 16,
        color: GSColors.accent,
      ),
      const SizedBox(width: GSSpacing.s2),
      Text(
        'Modo: ${ref.watch(selectedModeProvider)}',
        style: const TextStyle(
          fontSize: 13,
          color: GSColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
),
```

> `ref` is available because `_RoutePlannerScreenState` already extends `ConsumerState<RoutePlannerScreen>`.

- [ ] **Step 1: Add import**

Add `import '../../providers/selected_mode_provider.dart';` to the imports in `route_planner_screen.dart`.

- [ ] **Step 2: Update initState**

Add the `addPostFrameCallback` block to `initState` as shown above.

- [ ] **Step 3: Add mode indicator widget**

In `build()`, insert the mode indicator `Padding` widget between `_LocationInputs` and the search button `Padding`.

- [ ] **Step 4: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/features/routes/route_planner_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/routes/route_planner_screen.dart
git commit -m "feat: route planner pre-selects profile from travel mode, shows mode chip"
```

---

### Task 4: Update CLAUDE.md and push

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add selectedModeProvider to the State Management table**

Find the providers table and add after `activeRouteProvider`:
```
| `selectedModeProvider` | `StateProvider<String>` | Travel mode selected on home ('Auto' default) |
```

- [ ] **Step 2: Verify full project**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Commit and push**

```bash
git add CLAUDE.md
git commit -m "docs: add selectedModeProvider to CLAUDE.md"
git push origin main
```

---

## Verification Checklist

After all tasks complete:

- [ ] Map: drag freely, double-tap zooms, scroll wheel works in Chrome, fling has inertia
- [ ] Home: tapping "Bici" updates chip + sets `selectedModeProvider = 'Bici'`
- [ ] Route planner: opens with "Modo: Bici" indicator and cycling card pre-selected
- [ ] Home: tapping "Bus" then opening planner → shows "Modo: Bus" + driving card selected
- [ ] `flutter analyze` — zero errors
