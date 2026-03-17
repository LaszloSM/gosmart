# GPS + Map Route Display — Design Spec

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan.

**Goal:** Show the user's real GPS position on the home map and draw Mapbox-powered route polylines on the map when a route is selected in the route planner.

**Architecture:** Add `geolocator` for device position, call Mapbox Directions API (3 profiles: walking/driving/cycling) for real polylines, store the active route in a Riverpod provider, and render it with `PolylineLayer` in the home map.

**Tech Stack:** Flutter/Dart, `geolocator ^13.0.0`, Mapbox Directions REST API v5, `flutter_map` PolylineLayer, Riverpod StateProvider/FutureProvider, existing `Env.mapboxToken`.

**Platform targets:** Android (primary) + Chrome/Web. iOS is not a target platform for this spec — if the app is built for iOS in the future, add `NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist` and add a platform guard in `LocationService`.

---

## Scope

This spec covers **Subsystem A** only:
- GPS location on the home map
- Route drawing on the home map after route selection

**Out of scope:** Route planner intelligence (fast/eco/cheap with transit data), driver/ride-hailing system — these are separate future specs.

---

## Files

### New files
| File | Responsibility |
|------|---------------|
| `lib/services/location_service.dart` | Wraps geolocator; exposes `getCurrentPosition()` → `LatLng`; fallback to Bogotá on error/timeout |
| `lib/services/directions_service.dart` | Calls Mapbox Directions API v5; returns `RouteResult` with single-leg polyline |
| `lib/models/route_result.dart` | Data model: `RouteResult` + `RouteLeg` with explicit mode/color mapping |
| `lib/providers/location_provider.dart` | `FutureProvider<LatLng>` — initial device position for map center |
| `lib/providers/active_route_provider.dart` | `StateProvider<RouteResult?>` — route currently displayed on map |

### Modified files
| File | Changes |
|------|---------|
| `lib/features/home/home_screen.dart` | Add `PolylineLayer`, blue user dot marker, FAB re-center, active route banner; listen to `locationProvider` and `activeRouteProvider` |
| `lib/features/routes/route_planner_screen.dart` | Store GPS `LatLng` in state; call `DirectionsService` for real routes; on route select → set `activeRouteProvider` → pop to Home |
| `pubspec.yaml` | Add `geolocator: ^13.0.0` |
| `android/app/src/main/AndroidManifest.xml` | Add `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` permissions |
| `CLAUDE.md` | Document new providers, services, and geolocator dependency |

---

## Models

### `RouteResult` and `RouteLeg`

```dart
class RouteResult {
  final List<RouteLeg> legs;   // Always exactly 1 leg in Subsystem A
  final double distanceKm;
  final int durationMin;
  final String profile;        // Mapbox profile: 'walking' | 'driving' | 'cycling'
}

class RouteLeg {
  final String mode;           // Derived from Mapbox profile (see mapping below)
  final List<LatLng> points;   // Polyline coords from routes[0].geometry.coordinates
  final Color color;           // Derived from mode (see mapping below)
  final int durationMin;
  final double distanceKm;
}
```

**Mapbox profile → mode → color mapping (single source of truth):**

| Mapbox profile | `RouteLeg.mode` | `RouteLeg.color` | Card label |
|----------------|-----------------|------------------|------------|
| `'walking'`    | `'walk'`        | `GSColors.accent` (#00D4AA teal) | "A pie · más barata" |
| `'driving'`    | `'bus'`         | `Color(0xFFFF8C00)` (orange) | "En bus · más rápida" |
| `'cycling'`    | `'bike'`        | `GSColors.eco` (#3CB371 green) | "En bici · eco" |

> Note: `'driving'` profile approximates bus/car road corridors in Colombia. It is labeled "En bus" in the UI because GoSmart users take buses on those road networks. True per-line bus routing requires GTFS data (future Subsystem B).

**In Subsystem A, `RouteResult.legs` always contains exactly 1 `RouteLeg`** (the full route as one polyline). Multi-leg support (walk + transit + walk segments) is reserved for Subsystem B when GTFS data is available.

---

## Services

### `LocationService`

```dart
class LocationService {
  /// Returns real GPS position, or null if permission denied / timeout / error.
  /// Returns null (not a fallback LatLng) so callers can distinguish a real fix
  /// from a failure and decide their own fallback behavior.
  /// Call this directly (not via provider) for the FAB re-center button.
  Future<LatLng?> getCurrentPosition() async {
    // 1. Check LocationPermission via Geolocator.checkPermission()
    // 2. If denied → Geolocator.requestPermission()
    // 3. If permanently denied → return null
    // 4. Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 10))
    // 5. Return LatLng(position.latitude, position.longitude)
    // 6. On TimeoutException or any other error → return null
  }
}

final locationService = LocationService();
```

### `DirectionsService`

```dart
// Mapbox Directions API v5
// GET https://api.mapbox.com/directions/v5/mapbox/{profile}/{lng,lat};{lng,lat}
//     ?geometries=geojson&overview=full&access_token=TOKEN
//
// Coordinates order: LONGITUDE first, then LATITUDE (Mapbox convention).
// Response: routes[0].geometry.coordinates → [[lng, lat], ...]
//           routes[0].duration → seconds → convert to minutes
//           routes[0].distance → meters → convert to km

class DirectionsService {
  /// Returns null if token empty, network error, or API returns non-200.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,   // 'walking' | 'driving' | 'cycling'
  }) async {
    final token = Env.mapboxToken;
    if (token.isEmpty) return null;  // No token → caller uses mock data

    // 1. Build URL: coords as "{origin.lng},{origin.lat};{dest.lng},{dest.lat}"
    // 2. GET request via http.get() with 15s timeout
    // 3. If statusCode != 200 → return null
    // 4. Parse routes[0].geometry.coordinates → List<LatLng>
    //    (note: each coord is [lng, lat] → LatLng(lat, lng))
    // 5. Build RouteLeg from profile using the mapping table above
    // 6. Return RouteResult(legs: [leg], distanceKm, durationMin, profile)
    // 7. On any exception → return null
  }
}

final directionsService = DirectionsService();
```

---

## Providers

```dart
// lib/providers/location_provider.dart
// Used ONLY for the initial map center — fires once on creation.
// Returns LatLng? — null means GPS unavailable; callers fall back to Bogotá.
// For the FAB re-center button, call locationService.getCurrentPosition() directly.
final locationProvider = FutureProvider<LatLng?>((ref) async {
  return locationService.getCurrentPosition();
});

// lib/providers/active_route_provider.dart
final activeRouteProvider = StateProvider<RouteResult?>((ref) => null);
```

---

## Home Map Changes

### `_AppMap` becomes `ConsumerStatefulWidget`

Change `_AppMap` from `StatefulWidget` to `ConsumerStatefulWidget` (and `_AppMapState` from `State` to `ConsumerState`). This gives `_AppMapState` access to `ref.watch` for both `locationProvider` and `activeRouteProvider` without prop drilling from the parent `_HomeScreenState`.

### GPS state in `_AppMapState`

Add:
```dart
static const _bogota = LatLng(4.7110, -74.0721);
late final MapController _mapController;
LatLng _userPosition = _bogota; // updated when locationProvider resolves

@override
void initState() {
  super.initState();
  _mapController = MapController();
  // ... existing AnimationController setup ...
  // Resolve GPS position after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _userPosition = pos);
      _mapController.move(pos, 14);
    }
  });
}
```

Pass controller to `FlutterMap`:
```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: _userPosition,
    initialZoom: 14,
    ...
  ),
  ...
)
```

### User location dot
- Replace the current teal pulsing marker at hardcoded Bogotá with a **blue pulsing dot** at `_userPosition`
- Same `AnimationController` + `ScaleTransition` logic, color changed to `Colors.blue`
- Center `MapOptions.initialCenter` on `_userPosition`

### FAB re-center button
- `FloatingActionButton.small` positioned bottom-right inside the map `Stack`
- Icon: `Icons.my_location`, background `GSColors.primary`
- On tap:
  ```dart
  final pos = await locationService.getCurrentPosition(); // direct call, no provider
  setState(() => _userPosition = pos);
  _mapController.move(pos, 14);
  ```

### PolylineLayer
```dart
// Inside FlutterMap children, after MarkerLayer:
Consumer(builder: (context, ref, _) {
  final route = ref.watch(activeRouteProvider);
  if (route == null) return const SizedBox.shrink();
  return PolylineLayer(
    polylines: route.legs.map((leg) => Polyline(
      points: leg.points,
      strokeWidth: 5.0,
      color: leg.color,
    )).toList(),
  );
}),
```

### Active route banner
- Shown when `activeRouteProvider != null`, above the bottom nav bar
- Content: mode icon + "${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km" + ✕ IconButton
- ✕ tap: `ref.read(activeRouteProvider.notifier).state = null`
- Styled with `GSColors.primary` background, `GSColors.accent` icon

---

## Route Planner Changes

### Origin GPS state

Add to `_RoutePlannerScreenState`:
```dart
LatLng? _originLatLng;   // GPS position — used directly when calling DirectionsService
final _originCtrl = TextEditingController();
```

On `initState`:
```dart
locationService.getCurrentPosition().then((pos) {
  if (pos != null && mounted) {
    setState(() {
      _originLatLng = pos;
      _originCtrl.text = 'Mi ubicación';  // display label, not raw coords
    });
  }
  // If pos == null (GPS failed/denied): field stays empty, user types manually
});
```

"Mi ubicación" is only shown when `pos != null` (real GPS fix). If GPS fails, the origin field is empty and the user must type manually.

### Real route search

On "Buscar ruta" tap:
```dart
// Parse destination from text field as address string (Mapbox Geocoding is out of scope)
// For this spec: destination must be entered as "lat,lng" (e.g. "4.6097,-74.0817")
// or use a placeholder destination for testing.
// Real geocoding (address → coords) is deferred to Subsystem B.

// Guard: _originLatLng must be set before search
if (_originLatLng == null) {
  GSToast.show(context, message: 'Obteniendo ubicación, espera un momento...');
  return;
}

// Parse destination: validate before API call
final destLatLng = _parseDestination(_destCtrl.text);
if (destLatLng == null) {
  GSToast.show(context, message: 'Formato inválido. Usa: lat,lng (ej: 4.6097,-74.0817)');
  return;
}

final results = await Future.wait([
  directionsService.getRoute(origin: _originLatLng!, destination: destLatLng, profile: 'walking'),
  directionsService.getRoute(origin: _originLatLng!, destination: destLatLng, profile: 'driving'),
  directionsService.getRoute(origin: _originLatLng!, destination: destLatLng, profile: 'cycling'),
]);
// results[0] = walking (null if failed → show mock card)
// results[1] = driving (null if failed → show mock card)
// results[2] = cycling (null if failed → show mock card)
```

Helper to parse destination:
```dart
LatLng? _parseDestination(String text) {
  final parts = text.trim().split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}
```

Display 3 route cards using real `durationMin`/`distanceKm` from API when available.

> **Destination input:** In this subsystem the destination field accepts `"lat,lng"` format (comma-separated, latitude first). Display a hint text: `"Ej: 4.6097,-74.0817"`. Geocoding (convert address names to coords) is deferred to Subsystem B.

### On route select
```dart
ref.read(activeRouteProvider.notifier).state = selectedRoute;
context.pop(); // GoRouter pop → Home — map draws the route
```

---

## Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
Place before the `<application>` tag.

### Web (Chrome)
No changes needed. The browser handles the permission popup automatically when `Geolocator.getCurrentPosition()` is called. Works on `localhost` without HTTPS.

### iOS (not in scope)
Not a target platform for this spec. If iOS is ever added: `ios/Runner/Info.plist` needs `NSLocationWhenInUseUsageDescription`. Add a platform check in `LocationService` using `Platform.isIOS` if needed.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| GPS permission denied | Fallback to Bogotá silently; map still works; FAB visible |
| GPS timeout (>10s) | Fallback to Bogotá; no crash |
| `Env.mapboxToken` empty | `DirectionsService` returns null immediately; planner shows mock cards |
| Mapbox API error (non-200) | Returns null; GSToast "No se pudo calcular la ruta" |
| No internet | GPS may return cached; Directions returns null; toast shown |
| `_originLatLng` null at search time | Show toast "Obteniendo ubicación, espera un momento..."; abort search |
| Destination field empty on search | Show toast "Ingresa un destino"; abort search |
| Destination field contains invalid lat,lng | `_parseDestination()` returns null; show toast "Formato inválido. Usa: lat,lng"; abort search |

---

## User Flow Summary

1. App opens → GPS requested → map centers on real user position (blue dot)
2. User taps planificador → origin shows "Mi ubicación"; `_originLatLng` holds real coords
3. User enters destination as `lat,lng` → taps "Buscar" → 3 Mapbox routes fetched in parallel
4. User selects a route → `activeRouteProvider` set → pops to Home
5. Home map shows route polyline (teal/orange/green) + bottom banner with time/distance
6. User taps ✕ on banner → route cleared → map back to normal

---

## Out of Scope (Future Specs)

- Subsystem B: Smart route planner — real fast/eco/cheap with GTFS transit data, address geocoding, multi-leg routes
- Subsystem C: Driver/ride-hailing system (request → accept → track → cancel)
- Real-time location tracking during navigation
- `GOOGLE_MAPS_API_KEY`: present in `.env` for reference but not used by any service in this spec. Directions use Mapbox only.
