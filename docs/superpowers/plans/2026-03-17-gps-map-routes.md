# GPS + Map Route Display — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the user's real GPS position on the home map and draw Mapbox-powered route polylines when a route is selected in the route planner.

**Architecture:** Add `geolocator ^13.0.0` for device GPS; call Mapbox Directions API v5 (walking/driving/cycling) for real polylines; store active route in `activeRouteProvider` (Riverpod StateProvider); render with `PolylineLayer` in home map; convert `_AppMap` to `ConsumerStatefulWidget` so it can watch both providers directly.

**Tech Stack:** Flutter/Dart, geolocator ^13.0.0, Mapbox Directions REST API v5, flutter_map PolylineLayer, Riverpod StateProvider/FutureProvider, http (already in pubspec), latlong2 (already in pubspec).

**Spec:** `docs/superpowers/specs/2026-03-17-gps-map-routes-design.md`

---

## Chunk 1: Foundation — Dependencies, Model, Services, Providers

### Task 1: Add geolocator dependency and Android permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add geolocator to pubspec.yaml**

In `pubspec.yaml`, after the `latlong2` line, add:

```yaml
  # GPS location
  geolocator: ^13.0.0
```

Also update the comment on the `http` line (minor cleanup):
```yaml
  # HTTP client (Groq AI + Mapbox Directions REST calls)
  http: ^1.2.0
```

- [ ] **Step 2: Add location permissions to AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, add these two lines immediately **before** the `<application` tag (after the existing `INTERNET` permission line):

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 3: Install dependency**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart"
flutter pub get
```

Expected output: contains `geolocator 13.x.x` in the dependency list. No errors.

- [ ] **Step 4: Verify no analysis errors**

```bash
flutter analyze
```

Expected: no errors (warnings about unused imports are okay for now).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: add geolocator dependency and Android location permissions"
```

---

### Task 2: Create RouteResult model

**Files:**
- Create: `lib/models/route_result.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/models/route_result.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/design_tokens.dart';

/// A single segment of a route (e.g. the full walking polyline).
/// In Subsystem A, RouteResult always contains exactly one RouteLeg.
class RouteLeg {
  final String mode;        // 'walk' | 'bus' | 'bike'
  final List<LatLng> points; // polyline coords from Mapbox
  final Color color;
  final int durationMin;
  final double distanceKm;

  const RouteLeg({
    required this.mode,
    required this.points,
    required this.color,
    required this.durationMin,
    required this.distanceKm,
  });
}

/// The active route shown on the home map.
class RouteResult {
  final List<RouteLeg> legs; // always 1 leg in Subsystem A
  final double distanceKm;
  final int durationMin;
  final String profile; // 'walking' | 'driving' | 'cycling'

  const RouteResult({
    required this.legs,
    required this.distanceKm,
    required this.durationMin,
    required this.profile,
  });
}

/// Maps a Mapbox profile to a RouteLeg mode, color, and card label.
/// Single source of truth — do not duplicate this mapping elsewhere.
class RouteProfile {
  static const walking = 'walking';
  static const driving = 'driving';
  static const cycling = 'cycling';

  static String modeFor(String profile) => switch (profile) {
        driving => 'bus',
        cycling => 'bike',
        _ => 'walk',
      };

  static Color colorFor(String profile) => switch (profile) {
        driving => const Color(0xFFFF8C00), // orange
        cycling => GSColors.eco,            // green
        _ => GSColors.accent,              // teal
      };

  static IconData iconFor(String profile) => switch (profile) {
        driving => Icons.directions_bus_rounded,
        cycling => Icons.pedal_bike_rounded,
        _ => Icons.directions_walk_rounded,
      };

  static String labelFor(String profile) => switch (profile) {
        driving => 'En bus · más rápida',
        cycling => 'En bici · eco',
        _ => 'A pie · más barata',
      };
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/models/route_result.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/models/route_result.dart
git commit -m "feat: add RouteResult and RouteLeg models with profile mapping"
```

---

### Task 3: Create LocationService

**Files:**
- Create: `lib/services/location_service.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Returns the device's current GPS position.
  /// Returns null if permission is denied, timed out, or any error occurs.
  /// Callers are responsible for their own fallback (e.g. default to Bogotá).
  Future<LatLng?> getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}

final locationService = LocationService();
```

> **Note on geolocator v13 API:** `getCurrentPosition` takes a `locationSettings` parameter (not `desiredAccuracy` or `timeLimit` directly). `LocationSettings` accepts `accuracy` and `timeLimit`.

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/services/location_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/location_service.dart
git commit -m "feat: add LocationService wrapping geolocator with null-on-failure"
```

---

### Task 4: Create DirectionsService

**Files:**
- Create: `lib/services/directions_service.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/services/directions_service.dart
// Calls Mapbox Directions API v5 to get real route polylines.
// Returns null on any error (empty token, network failure, non-200 response).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/env.dart';
import '../models/route_result.dart';

class DirectionsService {
  static const _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  /// Fetches a route from Mapbox Directions API.
  /// [profile]: 'walking' | 'driving' | 'cycling'
  /// Returns null if token is missing, network fails, or API returns non-200.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    final token = Env.mapboxToken;
    if (token.isEmpty) return null;

    // Mapbox expects coordinates as "lng,lat" (longitude first).
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';

    final uri = Uri.parse(
      '$_baseUrl/$profile/$coords'
      '?geometries=geojson&overview=full&access_token=$token',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[DirectionsService] ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords2 = geometry['coordinates'] as List;

      // Mapbox returns [lng, lat] — convert to LatLng(lat, lng).
      final points = coords2
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final distanceKm = ((route['distance'] as num).toDouble()) / 1000;
      final durationMin = ((route['duration'] as num).toDouble() / 60).round();

      final leg = RouteLeg(
        mode: RouteProfile.modeFor(profile),
        points: points,
        color: RouteProfile.colorFor(profile),
        durationMin: durationMin,
        distanceKm: distanceKm,
      );

      return RouteResult(
        legs: [leg],
        distanceKm: distanceKm,
        durationMin: durationMin,
        profile: profile,
      );
    } catch (e) {
      debugPrint('[DirectionsService] error: $e');
      return null;
    }
  }
}

final directionsService = DirectionsService();
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/services/directions_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/directions_service.dart
git commit -m "feat: add DirectionsService using Mapbox Directions API v5"
```

---

### Task 5: Create Riverpod providers

**Files:**
- Create: `lib/providers/location_provider.dart`
- Create: `lib/providers/active_route_provider.dart`

- [ ] **Step 1: Create location_provider.dart**

```dart
// lib/providers/location_provider.dart
// FutureProvider — fires once, used for initial map center.
// Returns null if GPS is unavailable; callers fall back to Bogotá.
// For FAB re-center, call locationService.getCurrentPosition() directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

final locationProvider = FutureProvider<LatLng?>((ref) async {
  return locationService.getCurrentPosition();
});
```

- [ ] **Step 2: Create active_route_provider.dart**

```dart
// lib/providers/active_route_provider.dart
// Holds the route currently drawn on the home map.
// Set by route_planner_screen when user selects a route.
// Reset to null when user closes the route banner.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';

final activeRouteProvider = StateProvider<RouteResult?>((ref) => null);
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/providers/location_provider.dart lib/providers/active_route_provider.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/location_provider.dart lib/providers/active_route_provider.dart
git commit -m "feat: add locationProvider and activeRouteProvider"
```

---

## Chunk 2: UI — Home Map + Route Planner

### Task 6: Upgrade home map — GPS dot, FAB, PolylineLayer, route banner

**Files:**
- Modify: `lib/features/home/home_screen.dart`

The current `_AppMap` (lines 589–654) is a plain `StatefulWidget`. We replace it entirely. The parent `HomeScreen` and all other widgets in the file stay unchanged.

- [ ] **Step 1: Add missing imports at the top of home_screen.dart**

After the existing imports, add:

```dart
import 'package:flutter_map/flutter_map.dart'; // already imported
import 'package:flutter_riverpod/flutter_riverpod.dart'; // already imported
import '../../core/env.dart'; // already imported
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../services/location_service.dart';
```

Only add lines that aren't already present. Check the top of the file first — `flutter_map`, `flutter_riverpod`, and `env.dart` are already imported.

- [ ] **Step 2: Replace the `_AppMap` widget (lines 588–654)**

Replace the entire block from `// ─── Real Map` comment through the closing `}` of `_AppMapState.build()` with:

```dart
// ─── Real Map with GPS + Mapbox tiles + route polylines ───────────────────────

class _AppMap extends ConsumerStatefulWidget {
  const _AppMap();

  @override
  ConsumerState<_AppMap> createState() => _AppMapState();
}

class _AppMapState extends ConsumerState<_AppMap>
    with SingleTickerProviderStateMixin {
  static const _bogota = LatLng(4.7110, -74.0721);

  late final MapController _mapController;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  LatLng _userPosition = _bogota;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Resolve GPS after first frame (avoids calling async in initState).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pos = await locationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _userPosition = pos);
        _mapController.move(pos, 14);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _recenter() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _userPosition = pos);
      _mapController.move(pos, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute = ref.watch(activeRouteProvider);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userPosition,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: Env.mapboxToken.isNotEmpty
                  ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x'
                      '?access_token=${Env.mapboxToken}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileSize: Env.mapboxToken.isNotEmpty ? 512 : 256,
              zoomOffset: Env.mapboxToken.isNotEmpty ? -1 : 0,
              userAgentPackageName: 'com.gosmart.app',
              maxNativeZoom: 19,
            ),
            // Route polylines (shown when a route is active)
            if (activeRoute != null)
              PolylineLayer(
                polylines: activeRoute.legs
                    .map((leg) => Polyline(
                          points: leg.points,
                          strokeWidth: 5.0,
                          color: leg.color,
                        ))
                    .toList(),
              ),
            // Destination pin (shown when a route is active)
            if (activeRoute != null && activeRoute.legs.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: activeRoute.legs.last.points.last,
                    width: 32,
                    height: 32,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                ],
              ),
            // User location marker (blue pulsing dot)
            MarkerLayer(
              markers: [
                Marker(
                  point: _userPosition,
                  width: 60,
                  height: 60,
                  child: _PulsingMarker(pulse: _pulse, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),

        // FAB — re-center on user position
        Positioned(
          right: GSSpacing.s4,
          bottom: GSSpacing.s4,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: GSColors.primary,
            onPressed: _recenter,
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
        ),

        // Active route banner
        if (activeRoute != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _RouteBanner(route: activeRoute),
          ),
      ],
    );
  }
}

class _RouteBanner extends ConsumerWidget {
  const _RouteBanner({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s5, vertical: GSSpacing.s3),
      decoration: const BoxDecoration(
        color: GSColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
      ),
      child: Row(
        children: [
          Icon(RouteProfile.iconFor(route.profile),
              color: RouteProfile.colorFor(route.profile), size: 20),
          const SizedBox(width: GSSpacing.s3),
          Text(
            '${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () =>
                ref.read(activeRouteProvider.notifier).state = null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update `_PulsingMarker` to accept a color parameter**

Find the existing `_PulsingMarker` class and update its signature and usage:

```dart
class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({required this.pulse, this.color = GSColors.accent});
  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: pulse,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.40),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/home/home_screen.dart
```

Expected: no errors. There may be warnings if `RouteProfile` import is not yet needed — that's fine.

- [ ] **Step 5: Smoke test on Chrome**

```bash
flutter run -d chrome
```

Open the home screen. The map should:
- Show GPS permission popup in browser
- Center on your real location (or Bogotá if GPS denied)
- Show a blue pulsing dot instead of teal
- Show the ⊕ FAB button bottom-right

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat: home map — GPS blue dot, FAB recenter, PolylineLayer, route banner"
```

---

### Task 7: Upgrade route planner — GPS origin, real Mapbox routes, route selection

**Files:**
- Modify: `lib/features/routes/route_planner_screen.dart`

The current file is a pure mock with static `_options`. We rewrite `_RoutePlannerScreenState` to support GPS + real API calls, while keeping all existing widget classes (`_LocationInputs`, `_RouteCard`, `_StatBadge`, `_PulsingMarker`) unchanged.

- [ ] **Step 1: Replace the screen state class**

Replace the entire block from `class RoutePlannerScreen` through the end of `_RoutePlannerScreenState` (lines 1–119) with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../services/location_service.dart';
import '../../services/directions_service.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();

  LatLng? _originLatLng;
  List<RouteResult?> _results = [null, null, null]; // walking, driving, cycling
  bool _loading = false;
  String _selected = RouteProfile.walking;

  // Mock steps shown on route cards (visual only — real legs are in RouteResult)
  static const _mockSteps = {
    RouteProfile.walking: [
      _Step('Walk', '', Icons.directions_walk_rounded, GSColors.walk),
    ],
    RouteProfile.driving: [
      _Step('Bus', '', Icons.directions_bus_rounded, GSColors.bus),
    ],
    RouteProfile.cycling: [
      _Step('Bici', '', Icons.pedal_bike_rounded, GSColors.bike),
    ],
  };

  @override
  void initState() {
    super.initState();
    _resolveOrigin();
  }

  Future<void> _resolveOrigin() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _originLatLng = pos;
        _originCtrl.text = 'Mi ubicación';
      });
    }
  }

  /// Parses a "lat,lng" string. Returns null if invalid.
  LatLng? _parseDestination(String text) {
    final parts = text.trim().split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _search() async {
    if (_originLatLng == null) {
      final messenger = ScaffoldMessenger.of(context);
      GSToast.showWithMessenger(messenger,
          message: 'Obteniendo ubicación, espera un momento...');
      return;
    }

    final destLatLng = _parseDestination(_destCtrl.text);
    if (destLatLng == null) {
      final messenger = ScaffoldMessenger.of(context);
      GSToast.showWithMessenger(messenger,
          message: 'Formato inválido. Usa: lat,lng  (ej: 4.6097,-74.0817)');
      return;
    }

    setState(() => _loading = true);

    final results = await Future.wait([
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.walking),
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.driving),
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.cycling),
    ]);

    if (mounted) setState(() { _results = results; _loading = false; });
  }

  void _selectRoute(String profile, int index) {
    setState(() => _selected = profile);
    final route = _results[index];
    if (route != null) {
      ref.read(activeRouteProvider.notifier).state = route;
      context.pop(); // back to Home — map draws the route
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Planificar Ruta'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Preguntar IA',
            onPressed: () => context.push(AppRoutes.aiChat),
          ),
        ],
      ),
      body: Column(
        children: [
          _LocationInputs(originCtrl: _originCtrl, destCtrl: _destCtrl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
            child: GSButton(
              label: _loading ? 'Buscando...' : 'Buscar ruta',
              onPressed: _loading ? null : _search,
              leadingIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: GSSpacing.s4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s5, vertical: GSSpacing.s2),
              children: [
                _buildCard(RouteProfile.walking, 0,
                    icon: Icons.directions_walk_rounded,
                    iconColor: GSColors.accent),
                const SizedBox(height: GSSpacing.s3),
                _buildCard(RouteProfile.driving, 1,
                    icon: Icons.directions_bus_rounded,
                    iconColor: const Color(0xFFFF8C00)),
                const SizedBox(height: GSSpacing.s3),
                _buildCard(RouteProfile.cycling, 2,
                    icon: Icons.pedal_bike_rounded,
                    iconColor: GSColors.eco),
                const SizedBox(height: GSSpacing.s6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String profile, int index,
      {required IconData icon, required Color iconColor}) {
    final result = _results[index];
    final timeStr = result != null ? '${result.durationMin} min' : '—';
    final distStr = result != null
        ? '${result.distanceKm.toStringAsFixed(1)} km'
        : '—';

    return _RouteCard(
      option: _RouteOption(
        id: profile,
        label: RouteProfile.labelFor(profile),
        icon: icon,
        iconColor: iconColor,
        time: timeStr,
        cost: distStr,
        co2: '',
        steps: _mockSteps[profile] ?? [],
      ),
      isSelected: _selected == profile,
      onTap: () => _selectRoute(profile, index),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/routes/route_planner_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Smoke test on Chrome**

```bash
flutter run -d chrome
```

Navigate to Route Planner:
- Origin field should show "Mi ubicación" (or empty if GPS denied)
- Type a destination as `lat,lng` (e.g. `4.6097,-74.0817` for Aeropuerto El Dorado)
- Tap "Buscar ruta" — should call Mapbox API and show real duration/distance
- Select a route — should pop back to Home with route drawn on map
- Route banner should appear above nav bar with duration + km
- Tapping ✕ closes the banner

- [ ] **Step 4: Commit**

```bash
git add lib/features/routes/route_planner_screen.dart
git commit -m "feat: route planner — GPS origin, real Mapbox routes, route selection draws on map"
```

---

### Task 8: Update CLAUDE.md and push

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update dependencies table in CLAUDE.md**

Add geolocator to the Dependencies table:

```markdown
| `geolocator` | ^13.0.0 | Device GPS location (Android + Web) |
```

- [ ] **Step 2: Add new providers to the State Management table**

Add these two rows:

```markdown
| `locationProvider` | `FutureProvider<LatLng?>` | One-shot GPS position for map center |
| `activeRouteProvider` | `StateProvider<RouteResult?>` | Route currently drawn on home map |
```

- [ ] **Step 3: Add new services to the Directory Structure**

In the `services/` section of the directory tree, add:

```
│   ├── location_service.dart     # GPS via geolocator — returns LatLng? (null if unavailable)
│   ├── directions_service.dart   # Mapbox Directions API v5 — walking/driving/cycling polylines
```

- [ ] **Step 4: Commit and push**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with GPS/directions services, providers, geolocator dep"
git push origin main
```

Expected: push succeeds, 7 new commits on main since last push.

---

## Verification Checklist

After all tasks are complete, verify end-to-end:

- [ ] `flutter analyze` — zero errors
- [ ] App opens → GPS popup in Chrome → map centers on real position with blue dot
- [ ] FAB ⊕ button visible → tapping it re-centers the map
- [ ] Route Planner opens → origin shows "Mi ubicación"
- [ ] Type `4.6097,-74.0817` as destination → tap "Buscar ruta" → 3 cards show real min/km values
- [ ] Select a card → pops to Home → colored polyline drawn on map
- [ ] Route banner shows duration + distance → ✕ closes it and clears the polyline
- [ ] With empty token: Mapbox token removed → cards show "—" times (OSM tiles still work)
- [ ] GPS denied → origin field empty → user can type manually → search still works
