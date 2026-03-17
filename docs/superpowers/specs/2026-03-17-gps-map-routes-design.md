# GPS + Map Route Display — Design Spec

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan.

**Goal:** Show the user's real GPS position on the home map and draw Mapbox-powered route polylines on the map when a route is selected in the route planner.

**Architecture:** Add `geolocator` for device position, call Mapbox Directions API (3 profiles: walking/driving/cycling) for real polylines, store the active route in a Riverpod provider, and render it with `PolylineLayer` in the home map.

**Tech Stack:** Flutter/Dart, `geolocator ^13.0.0`, Mapbox Directions REST API v5, `flutter_map` PolylineLayer, Riverpod StateProvider/FutureProvider, existing `Env.mapboxToken`.

---

## Scope

This spec covers **Subsystem A** only:
- GPS location on the home map
- Route drawing on the home map after route selection

**Out of scope:** Route planner intelligence (fast/eco/cheap combinations), driver/ride-hailing system — these are separate future specs.

---

## Files

### New files
| File | Responsibility |
|------|---------------|
| `lib/services/location_service.dart` | Wraps geolocator; exposes `getCurrentPosition()` → `LatLng`; fallback to Bogotá on error/timeout |
| `lib/services/directions_service.dart` | Calls Mapbox Directions API v5; returns `RouteResult` with polylines and legs |
| `lib/models/route_result.dart` | Data model: list of `RouteLeg` (mode, color, points) and summary (distance, duration) |
| `lib/providers/location_provider.dart` | `FutureProvider<LatLng>` — current device position |
| `lib/providers/active_route_provider.dart` | `StateProvider<RouteResult?>` — route currently displayed on map |

### Modified files
| File | Changes |
|------|---------|
| `lib/features/home/home_screen.dart` | Add `PolylineLayer`, blue user dot marker, FAB re-center button, active route banner with close button; listen to `locationProvider` and `activeRouteProvider` |
| `lib/features/routes/route_planner_screen.dart` | Auto-fill origin from GPS; call `DirectionsService` for real routes; on route select → set `activeRouteProvider` → pop to Home |
| `pubspec.yaml` | Add `geolocator: ^13.0.0` |
| `android/app/src/main/AndroidManifest.xml` | Add `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` permissions |
| `CLAUDE.md` | Document new providers, services, and geolocator dependency |

---

## Models

### `RouteResult`
```dart
class RouteResult {
  final List<RouteLeg> legs;      // segments with polyline per mode
  final double distanceKm;
  final int durationMin;
  final String profile;           // 'walking' | 'driving' | 'cycling'
}

class RouteLeg {
  final String mode;              // 'walk' | 'bus' | 'bike'
  final List<LatLng> points;      // polyline coordinates from Mapbox
  final Color color;              // teal=walk, orange=bus/driving, green=cycling
  final int durationMin;
  final double distanceKm;
}
```

---

## Services

### `LocationService`
```dart
class LocationService {
  static const _bogota = LatLng(4.7110, -74.0721);

  Future<LatLng> getCurrentPosition() async {
    // 1. Check permission — request if not granted
    // 2. Get position with timeout 10s
    // 3. Return LatLng(position.latitude, position.longitude)
    // 4. On any error/denied → return _bogota fallback
  }
}

final locationService = LocationService();
```

### `DirectionsService`
```dart
// Mapbox Directions API v5
// GET https://api.mapbox.com/directions/v5/mapbox/{profile}/{lng,lat};{lng,lat}
//     ?geometries=geojson&overview=full&access_token=TOKEN

class DirectionsService {
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,      // 'walking' | 'driving' | 'cycling'
  }) async {
    // 1. Build URL with coords and token
    // 2. GET request via http package (already in pubspec)
    // 3. Parse response: routes[0].geometry.coordinates → List<LatLng>
    //    routes[0].duration → durationMin
    //    routes[0].distance → distanceKm
    // 4. Return RouteResult with single leg
    // 5. On error → return null
  }
}

final directionsService = DirectionsService();
```

---

## Providers

```dart
// lib/providers/location_provider.dart
final locationProvider = FutureProvider<LatLng>((ref) async {
  return locationService.getCurrentPosition();
});

// lib/providers/active_route_provider.dart
final activeRouteProvider = StateProvider<RouteResult?>((ref) => null);
```

---

## Home Map Changes

### User location dot
- Replace the current teal pulsing marker (hardcoded Bogotá) with a **blue pulsing dot** at the user's real GPS position
- Center `MapOptions.initialCenter` on GPS position (via `locationProvider`)
- Keep pulsing animation — same `AnimationController` logic

### FAB re-center button
- Floating action button bottom-right of the map
- Icon: `Icons.my_location`
- On tap: animate map camera to current GPS position
- Uses `MapController` (add `late final MapController _mapController` to state)

### PolylineLayer
- Listen to `activeRouteProvider`
- When non-null: render `PolylineLayer` with legs as colored polylines
  - `strokeWidth: 5.0`
  - Colors: teal (#00D4AA) for walk, orange for driving/bus, green for cycling
- When null: no layer rendered

### Active route banner
- When `activeRouteProvider` is non-null: show a bottom banner above the nav bar
- Shows: profile icon + "X min · Y km" + ✕ close button
- Close button: `ref.read(activeRouteProvider.notifier).state = null`

---

## Route Planner Changes

### Origin auto-fill
- On screen init: read `locationProvider` → populate origin `TextEditingController` with coordinates (or reverse geocode display name if possible — optional)
- If GPS unavailable: origin field empty, user types manually

### Real route search
- On "Buscar ruta" tap:
  1. Call `DirectionsService.getRoute()` for each of 3 profiles in parallel
  2. Show real duration/distance from API response (replace hardcoded values)
  3. Display 3 cards: walking (a pie / más barata), driving (más rápida), cycling (eco)
- If API fails: show error toast, keep existing mock data as fallback

### On route select
```dart
// When user taps a route card:
ref.read(activeRouteProvider.notifier).state = selectedRoute;
context.pop(); // back to Home — map draws the route
```

---

## Permissions

### Android (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### Web (Chrome)
No changes to `web/index.html` needed — browser shows its own permission popup automatically when `geolocator` calls `Geolocator.getCurrentPosition()`.

### iOS (if ever needed)
`Info.plist` key: `NSLocationWhenInUseUsageDescription` — out of scope for now.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| GPS permission denied | Fallback to Bogotá; no crash; FAB still shows |
| GPS timeout (>10s) | Fallback to Bogotá |
| Mapbox token empty | `DirectionsService` returns null; route planner shows mock data |
| Mapbox API error (non-200) | Returns null; GSToast error message |
| No internet | GPS may work (cached); Directions returns null; toast shown |

---

## User Flow Summary

1. App opens → GPS requested → map centers on real user position (blue dot)
2. User taps planificador → origin auto-filled with GPS coords
3. User enters destination → taps "Buscar" → 3 real Mapbox routes shown
4. User selects a route → `activeRouteProvider` set → pops to Home
5. Home map shows route polyline with color per mode + bottom banner
6. User taps ✕ on banner → route cleared → map back to normal

---

## Out of Scope (Future Specs)

- Subsystem B: Smart route planner (real fast/eco/cheap using transit data + driver availability)
- Subsystem C: Driver/ride-hailing system (request → accept → track → cancel)
- Reverse geocoding of GPS coordinates to address names
- Real-time location tracking during trip navigation
