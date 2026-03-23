# AI Route Planning + Address Autocomplete — Design Spec

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan.

**Goal:** Replace heuristic route cards in the AI chat with real Mapbox data + "Ver en mapa" button; add address autocomplete to the simplified route planner.

**Architecture:** New `GeocodingService` (Mapbox Geocoding API v5); `AiService` enhanced to extract destination, geocode, call Directions, inject real data; `AiMessage` gains `routeResults`; route planner simplified (no 3 cards) with autocomplete on destination field.

**Tech Stack:** Flutter/Dart, Mapbox Geocoding API v5, Mapbox Directions API v5 (existing), Groq llama-3.3-70b (existing), Riverpod, `http` package (existing), `MAPBOX_PUBLIC_TOKEN` (existing).

---

## Scope

- **A. Address autocomplete:** Destination field in route planner shows live suggestions while typing (Mapbox Geocoding)
- **B. Simplified route planner:** Remove 3 route cards; single Mapbox call using `selectedModeProvider` profile
- **C. Real route data in AI chat:** Replace heuristic routes with real Mapbox data; add "Ver en mapa" button

**Out of scope:** Origin autocomplete, saved recent destinations, multi-stop routes.

---

## Files

### New files
| File | Responsibility |
|------|---------------|
| `lib/models/geocode_suggestion.dart` | Data class: `{placeName, fullAddress, latLng}` |
| `lib/services/geocoding_service.dart` | Mapbox Geocoding API v5 — `search(query, {proximity})` → `List<GeocodeSuggestion>` |

### Modified files
| File | Changes |
|------|---------|
| `lib/models/ai_models.dart` | Add `routeResults: List<RouteResult?>?` to `AiMessage`; add import for `route_result.dart` |
| `lib/services/ai_service.dart` | Extract destination from query, geocode, call Directions x3, inject real data into prompt; populate `routeResults` |
| `lib/providers/ai_conversation_provider.dart` | Forward `selectedMode` param to `AiService.sendMessage()` |
| `lib/features/routes/route_planner_screen.dart` | Remove 3 route cards ListView; add autocomplete to destination field; cancel `_debounce` in `dispose()` |
| `lib/features/ai_chat/ai_chat_screen.dart` | Pass `selectedMode` to provider; render "Ver en mapa" button + profile chips when `message.routeResults != null` |

---

## GeocodingService

**Endpoint:** `GET https://api.mapbox.com/geocoding/v5/mapbox.places/{query}.json`

**Parameters:**
- `access_token`: `Env.mapboxToken`
- `country=co` — restrict to Colombia
- `language=es` — Spanish results
- `limit=5`
- `proximity={lng},{lat}` — user's current position (when available) to bias nearby results

**Model:**
```dart
// lib/models/geocode_suggestion.dart
import 'package:latlong2/latlong.dart';

class GeocodeSuggestion {
  final String placeName;     // short name, e.g. "Unicentro"
  final String fullAddress;   // full display, e.g. "Unicentro, Bogotá, Colombia"
  final LatLng latLng;

  const GeocodeSuggestion({
    required this.placeName,
    required this.fullAddress,
    required this.latLng,
  });
}
```

**Service:**
```dart
// lib/services/geocoding_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/env.dart';
import '../models/geocode_suggestion.dart';

class GeocodingService {
  static const _base = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Returns up to 5 address suggestions for [query].
  /// [proximity]: optional LatLng to bias results toward user location.
  /// Returns [] if token empty, query < 3 chars, or any error.
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? proximity}) async {
    final token = Env.mapboxToken;
    if (token.isEmpty || query.trim().length < 3) return [];
    try {
      final encoded = Uri.encodeComponent(query.trim());
      var url = '$_base/$encoded.json?access_token=$token&country=co&language=es&limit=5';
      if (proximity != null) {
        url += '&proximity=${proximity.longitude},${proximity.latitude}';
      }
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];
      return features.map((f) {
        final coords = (f['geometry']['coordinates'] as List);
        return GeocodeSuggestion(
          placeName: f['text'] as String? ?? '',
          fullAddress: f['place_name'] as String? ?? '',
          latLng: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
        );
      }).toList();
    } catch (e) {
      debugPrint('[GeocodingService] search error: $e');
      return [];
    }
  }

  /// Geocodes a single address. Returns the first result or null.
  Future<GeocodeSuggestion?> geocodeFirst(String query, {LatLng? proximity}) async {
    final results = await search(query, proximity: proximity);
    return results.isEmpty ? null : results.first;
  }
}

final geocodingService = GeocodingService();
```

---

## Route Planner — Simplified + Autocomplete

### Removed
- The entire `ListView` of 3 route cards (`_buildCard` calls for walking/driving/cycling)
- `_results: List<RouteResult?>` state
- The `Future.wait` of 3 Directions calls in `_search()`
- `_parseDestination()` (raw lat,lng parsing)
- `_selectRoute()` (no more card selection)
- `_RouteOption`, `_Step`, `_RouteCard`, `_StatBadge` private classes (no longer used)

### Added — autocomplete on destination field

New state:
```dart
List<GeocodeSuggestion> _suggestions = [];
LatLng? _destLatLng;           // set when user picks a suggestion
Timer? _debounce;
```

Import `dart:async` and `../../services/geocoding_service.dart` and `../../models/geocode_suggestion.dart`.

In `initState`: `_destCtrl.addListener(_onDestChanged);`

In `dispose`: `_debounce?.cancel();` (added before `_destCtrl.dispose()`)

`_onDestChanged`:
```dart
void _onDestChanged() {
  final text = _destCtrl.text.trim();
  if (text.length < 3) {
    setState(() => _suggestions = []);
    return;
  }
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    final results = await geocodingService.search(text, proximity: _originLatLng);
    if (mounted) setState(() => _suggestions = results);
  });
  // Clear stored LatLng when user edits the field manually
  if (_destLatLng != null) setState(() => _destLatLng = null);
}
```

Suggestions UI — shown below `_LocationInputs` card, above mode indicator, only when `_suggestions.isNotEmpty`:
```dart
if (_suggestions.isNotEmpty)
  Container(
    margin: const EdgeInsets.fromLTRB(GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
    decoration: BoxDecoration(
      color: GSColors.surface,
      borderRadius: BorderRadius.circular(GSRadius.md),
      border: Border.all(color: GSColors.border),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: GSColors.border),
      itemBuilder: (_, i) {
        final s = _suggestions[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined, size: 18, color: GSColors.accent),
          title: Text(s.placeName,
              style: const TextStyle(fontSize: 14, color: GSColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(s.fullAddress,
              style: const TextStyle(fontSize: 12, color: GSColors.textSecondary)),
          onTap: () {
            _destCtrl.removeListener(_onDestChanged); // avoid re-triggering
            _destCtrl.text = s.placeName;
            _destCtrl.addListener(_onDestChanged);
            setState(() { _destLatLng = s.latLng; _suggestions = []; });
          },
        );
      },
    ),
  ),
```

### Updated `_search()`
```dart
Future<void> _search() async {
  final messenger = ScaffoldMessenger.of(context); // capture before async gaps
  if (_originLatLng == null) {
    GSToast.showWithMessenger(messenger,
        message: 'Obteniendo ubicación, espera un momento...');
    return;
  }

  LatLng? destLatLng = _destLatLng;
  if (destLatLng == null) {
    // Try to geocode whatever is in the field
    final suggestion = await geocodingService.geocodeFirst(
        _destCtrl.text.trim(), proximity: _originLatLng);
    if (!mounted) return;
    if (suggestion == null) {
      GSToast.showWithMessenger(messenger,
          message: 'Destino no encontrado. Selecciona una sugerencia.');
      return;
    }
    destLatLng = suggestion.latLng;
    setState(() => _destLatLng = destLatLng);
  }

  setState(() => _loading = true);
  final profile = routeProfileFor(ref.read(selectedModeProvider));
  final result = await directionsService.getRoute(
      origin: _originLatLng!, destination: destLatLng!, profile: profile);
  if (!mounted) return;
  setState(() => _loading = false);
  if (result != null) {
    ref.read(activeRouteProvider.notifier).state = result;
    context.pop(); // go back to home map
  } else {
    GSToast.showWithMessenger(messenger, message: 'No se pudo calcular la ruta.');
  }
}
```

---

## AiMessage — New Field

```dart
class AiMessage {
  // ... existing fields ...
  /// Real Mapbox polylines for "Ver en mapa". Nullable items = failed profile.
  final List<RouteResult?>? routeResults;

  const AiMessage({
    // ... existing params ...
    this.routeResults,
  });
}
```

Import `'../models/route_result.dart'` in `ai_models.dart`.

**Type is `List<RouteResult?>?`** — outer null means no real data (heuristic fallback); inner nulls mean one profile failed (chip shows "No disponible" and "Ver en mapa" is disabled for that option).

---

## AiService — Real Route Data

### Destination extraction
New helper `_extractDestination(String query)`:

Uses an ordered list of specific → general patterns. Patterns stop at punctuation/end-of-string to avoid over-capture:

```dart
String? _extractDestination(String query) {
  // Ordered: most specific first
  final patterns = [
    RegExp(r'(?:de .+? a|llegar a|llevarme a|ir a|viajar a)\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
    RegExp(r'\bpara\s+(?:ir a\s+)?(.+?)(?:[,?!]|$)', caseSensitive: false),
    RegExp(r'\bhasta\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
    RegExp(r'\bal\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(query);
    if (m != null) return m.group(1)?.trim();
  }
  return null;
}
```

Note: The broad `a (.+)` pattern is intentionally excluded — too many false positives in Spanish.

### Updated `sendMessage()`
```dart
Future<AiMessage> sendMessage({
  required String query,
  List<ConversationTurn>? history,
  Map<String, double>? userLocation,   // existing — {lat, lng}
  String? selectedMode,                // NEW — value from selectedModeProvider
  String? context,
}) async { ... }
```

### Enhanced route flow inside `sendMessage()`
When `_routePattern.hasMatch(query)`:
1. Call `_extractDestination(query)` → `destString`
2. If `destString != null` and `userLocation != null`:
   - `proximity = LatLng(userLocation['lat']!, userLocation['lng']!)`
   - `await geocodingService.geocodeFirst(destString, proximity: proximity)` → `destSuggestion`
3. If `destSuggestion != null`:
   - Call `Future.wait([walking, driving, cycling])` → `List<RouteResult?>`
   - Build real route prompt block (see below)
   - `routeResults = [walkingResult, drivingResult, cyclingResult]`
4. Fallback (destination not extracted OR geocoding failed): use `_heuristicRoutes(now)`, `routeResults = null`

Real route prompt block:
```
DATOS REALES DE RUTA (Mapbox):
Destino: [destSuggestion.placeName] ([destSuggestion.fullAddress])
- Caminando: [walkMin] min, [walkKm] km  (o "no disponible")
- En auto/bus: [driveMin] min, [driveKm] km  (o "no disponible")
- En bici: [bikeMin] min, [bikeKm] km  (o "no disponible")
Modo preseleccionado: [selectedMode ?? 'Auto']
Presenta las 3 opciones brevemente. Recomienda la mejor según el modo y condiciones de tráfico.
Al final menciona: "Toca 'Ver en mapa' para aplicar la ruta."
```

### `AiMessage` returned with `routeResults`
```dart
return AiMessage(
  role: 'assistant',
  content: text,
  timestamp: DateTime.now(),
  latencyMs: latencyMs,
  source: 'groq',
  routes: _routePattern.hasMatch(query) ? _heuristicRoutes(now) : null,
  routeResults: routeResults, // null if heuristic fallback
);
```

---

## AiConversationProvider — Forward selectedMode

The provider's `send()` method must accept and forward `selectedMode`:

```dart
// Current signature (approximate):
Future<void> send(String message) async {
  // ...
  final reply = await aiService.sendMessage(query: message, history: ...);
  // ...
}

// New signature:
Future<void> send(String message, {String? selectedMode}) async {
  // ...
  final reply = await aiService.sendMessage(
    query: message,
    history: ...,
    userLocation: ...,
    selectedMode: selectedMode,  // forwarded
  );
  // ...
}
```

The AI chat screen calls: `ref.read(aiConversationProvider.notifier).send(text, selectedMode: ref.read(selectedModeProvider))`

---

## AI Chat Screen — "Ver en mapa"

Read the current `ai_chat_screen.dart` to find the message bubble builder. When an assistant message has `routeResults != null`, append below the message text:

```dart
// Per-message selected route index (widget state, not provider)
// Defaults to index matching driving (1) since it's the most common
int _routeIndexFor(AiMessage msg) {
  // If selectedMode maps to cycling → index 2, else → 1 (driving)
  // walking (index 0) is always available as a fallback
  return 1; // default: driving/bus
}
```

```dart
// Route chips row
Padding(
  padding: const EdgeInsets.only(top: GSSpacing.s3),
  child: Wrap(
    spacing: GSSpacing.s2,
    children: List.generate(3, (i) {
      final r = message.routeResults![i];
      final labels = ['Caminando', 'Auto/Bus', 'Bici'];
      final icons = [Icons.directions_walk_rounded, Icons.directions_bus_rounded, Icons.pedal_bike_rounded];
      final label = r != null ? '${labels[i]} · ${r.durationMin} min' : '${labels[i]} · N/D';
      return ChoiceChip(
        avatar: Icon(icons[i], size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _selectedRouteIdx == i,
        onSelected: r != null ? (_) => setState(() => _selectedRouteIdx = i) : null,
      );
    }),
  ),
),
// Ver en mapa button
Padding(
  padding: const EdgeInsets.only(top: GSSpacing.s2),
  child: GSButton(
    label: 'Ver en mapa',
    leadingIcon: Icons.map_rounded,
    onPressed: message.routeResults![_selectedRouteIdx] != null
        ? () {
            ref.read(activeRouteProvider.notifier).state =
                message.routeResults![_selectedRouteIdx];
            context.go(AppRoutes.home);
          }
        : null,
  ),
),
```

`_selectedRouteIdx` is state on the `_AiChatScreenState` (or a per-message map). Defaults to index 1 (driving/bus).

> **Note on navigation:** `context.go(AppRoutes.home)` replaces the full navigation stack. The user cannot press back to return to the chat from the map. This is intentional — after applying a route, the user should interact with the map, not the chat.

---

## Data Flow

```
User types "cómo llego al Parque de la 93"
  → _routePattern matches ("cómo llego")
  → _extractDestination() → "Parque de la 93"  (pattern: "al (.+)")
  → geocodingService.geocodeFirst("Parque de la 93", proximity: userLatLng)
  → GeocodeSuggestion{placeName: "Parque de la 93", latLng: (4.67, -74.05)}
  → Future.wait([walking, driving, cycling]) → [RouteResult?, RouteResult?, RouteResult?]
  → Build enriched prompt with real times
  → Groq: "Tienes 3 opciones: caminando 22 min, en bus 9 min (recomendado), en bici 14 min..."
  → AiMessage{content: text, routes: heuristic, routeResults: [walk, drive, bike]}
  → Chat UI: text + chips (real times) + "Ver en mapa"
  → User taps "Ver en mapa" → activeRouteProvider = drive → context.go(home) → polyline drawn
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Mapbox token empty | Autocomplete shows nothing; `_search()` toast "Token Mapbox no configurado" |
| Geocoding returns no results | Suggestions list empty (no UI error) |
| User taps "Buscar" without picking suggestion | `geocodeFirst` on field text; if null → toast "Destino no encontrado" |
| Directions fails for one profile | `routeResults[i] = null`; chip shows "N/D" and is disabled |
| Destination not extractable from AI query | Falls back to heuristic `routes`, `routeResults = null`, no "Ver en mapa" |
| GPS unavailable | `proximity = null`; geocoding still works, less biased |
| `_debounce` fires after widget disposed | Guarded by `if (mounted)` check in callback |

---

## User Flow

### Route planner (simplified)
1. User opens `/routes` → sees origin ("Mi ubicación") + empty destination field
2. Types "Par" → 300ms debounce → suggestions: "Parque de la 93, Bogotá", "Parque Simón Bolívar…"
3. Taps "Parque de la 93" → field fills, `_destLatLng` stored, suggestions disappear
4. Taps "Buscar ruta" → single Mapbox call with `selectedModeProvider` profile → polyline drawn → `context.pop()` to home map

### AI chat route planning
1. User types "cómo llego al Centro Comercial Santafé"
2. AI detects route intent, geocodes "Centro Comercial Santafé", gets real Mapbox data
3. AI responds: "Tienes 3 opciones: caminando 42 min, en bus 18 min (recomendado), en bici 25 min..."
4. Below the message: chips (Caminando · 42 min, Auto/Bus · 18 min ✓, Bici · 25 min) + "Ver en mapa"
5. User taps chip to change selection, taps "Ver en mapa" → `context.go(home)` with polyline applied
