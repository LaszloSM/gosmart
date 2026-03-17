# Map Gestures + Travel Mode Integration — Design Spec

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan.

**Goal:** Enable all map gestures (like InDriver) and connect the travel mode selected on the home screen to the route planner so it pre-selects the matching route profile.

**Architecture:** One-line change to `InteractiveFlag` for full map interaction; new `selectedModeProvider` (StateProvider<String>) shared between home screen and route planner.

**Tech Stack:** Flutter/Dart, flutter_map InteractiveFlag.all, Riverpod StateProvider.

---

## Scope

- **A. Map gestures:** Enable all interactive flags on the home map
- **B. Travel mode provider:** New shared provider; home writes, planner reads

**Out of scope:** Route calculation logic, AI routes, address autocomplete — those are Subsystem 2.

---

## Files

### New files
| File | Responsibility |
|------|---------------|
| `lib/providers/selected_mode_provider.dart` | `StateProvider<String>` — currently selected travel mode ('Auto' default) |

### Modified files
| File | Changes |
|------|---------|
| `lib/features/home/home_screen.dart` | 1) `InteractiveFlag.all` on map; 2) mode chip `onTap` writes to `selectedModeProvider` |
| `lib/features/routes/route_planner_screen.dart` | Read `selectedModeProvider` on init to pre-select profile; show mode chip in header |
| `CLAUDE.md` | Add `selectedModeProvider` to providers table |

---

## Provider

```dart
// lib/providers/selected_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently selected travel mode from the home screen mode chips.
/// Values: 'Auto' | 'Taxi' | 'Bus' | 'Bici' | 'Metro'
final selectedModeProvider = StateProvider<String>((ref) => 'Auto');
```

---

## Mode → Route Profile Mapping

Single source of truth — defined once in `selected_mode_provider.dart`:

```dart
/// Maps a home-screen travel mode to a Mapbox Directions profile.
String routeProfileFor(String mode) => switch (mode) {
  'Bici' => RouteProfile.cycling,
  _      => RouteProfile.driving,  // Auto, Taxi, Bus, Metro all use driving profile
};
```

Import `route_result.dart` for `RouteProfile` constants.

---

## Home Screen Changes

### A. Map gestures — `_AppMapState.build()`

Change `InteractionOptions` from:
```dart
interactionOptions: const InteractionOptions(
  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
),
```
to:
```dart
interactionOptions: const InteractionOptions(
  flags: InteractiveFlag.all,
),
```

This enables: drag, fling/inertia, pinchZoom, pinchMove, doubleTapZoom, scrollWheelZoom (Chrome), rotate. No other changes needed.

### B. Mode chip writes to provider

The home screen already has `_selectedMode` local state and `_modes` list. The mode chip `onTap` currently calls `setState(() => _selectedMode = mode.label)`.

Change: home screen becomes a `ConsumerStatefulWidget` (or add `ref` access) so it can also write to `selectedModeProvider`.

Current `onTap`:
```dart
onTap: () => setState(() => _selectedMode = mode.label),
```

New `onTap`:
```dart
onTap: () {
  setState(() => _selectedMode = mode.label);
  ref.read(selectedModeProvider.notifier).state = mode.label;
},
```

> **Note:** `_HomeScreenState` already extends `ConsumerState` (it's a `ConsumerStatefulWidget`). Verify this before changing — if it's already Consumer, just add `ref.read(...)`. If it's plain `StatefulWidget`, convert it.

---

## Route Planner Changes

### Read provider on init

In `_RoutePlannerScreenState.initState()`, after `_resolveOrigin()`, read the selected mode and set `_selected` to the matching profile:

```dart
@override
void initState() {
  super.initState();
  _resolveOrigin();
  // Pre-select route profile based on home screen travel mode
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final mode = ref.read(selectedModeProvider);
    setState(() => _selected = routeProfileFor(mode));
  });
}
```

### Show mode indicator in header

Below the `_LocationInputs` widget and above the search button, add a small mode chip showing the current travel mode:

```dart
// Mode indicator chip
Consumer(builder: (context, ref, _) {
  final mode = ref.watch(selectedModeProvider);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
    child: Row(
      children: [
        Icon(_modeIconFor(mode), size: 16, color: GSColors.accent),
        const SizedBox(width: GSSpacing.s2),
        Text('Modo: $mode',
            style: const TextStyle(
                fontSize: 13,
                color: GSColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}),
```

Helper (private to route planner file):
```dart
IconData _modeIconFor(String mode) => switch (mode) {
  'Taxi'  => Icons.local_taxi_rounded,
  'Bus'   => Icons.directions_bus_rounded,
  'Bici'  => Icons.pedal_bike_rounded,
  'Metro' => Icons.subway_rounded,
  _       => Icons.directions_car_rounded, // Auto
};
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Provider not yet initialized | `routeProfileFor` defaults to `driving` — safe |
| User changes mode after planner opens | Chip shows stale value (live update not required — user can re-open planner) |

---

## User Flow

1. User opens app → home shows "Auto" selected (teal chip)
2. User taps "Bici" → chip turns teal, `selectedModeProvider` = 'Bici'
3. User opens route planner → header shows "Modo: Bici", cycling profile card is pre-selected
4. On the map: drag freely, double-tap to zoom, fling to scroll with inertia, scroll wheel on Chrome
