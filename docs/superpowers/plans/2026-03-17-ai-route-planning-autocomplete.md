# AI Route Planning + Address Autocomplete — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace heuristic route cards in the AI chat with real Mapbox data + "Ver en mapa" button; add address autocomplete to the simplified route planner (remove the 3 static route cards).

**Architecture:** New `GeocodingService` (Mapbox Geocoding API v5, same token); `AiService` enhanced with `_extractDestination()` + real Directions calls; `AiMessage` gains `routeResults: List<RouteResult?>?`; route planner simplified to autocomplete + single-profile search; chat screen renders live route chips + "Ver en mapa" button.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, Mapbox Geocoding API v5, Mapbox Directions API v5 (existing `DirectionsService`), Groq llama-3.3-70b (existing `AiService`), `http` package (already in pubspec), `dart:async` (Timer for debounce).

**Spec:** `docs/superpowers/specs/2026-03-17-ai-route-planning-autocomplete-design.md`

---

## Chunk 1: Foundation — Models and GeocodingService

### Task 1: Create GeocodeSuggestion model

**Files:**
- Create: `lib/models/geocode_suggestion.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/models/geocode_suggestion.dart
import 'package:latlong2/latlong.dart';

/// A single address suggestion returned by the Mapbox Geocoding API.
class GeocodeSuggestion {
  /// Short display name, e.g. "Parque de la 93".
  final String placeName;

  /// Full address string, e.g. "Parque de la 93, Bogotá, Colombia".
  final String fullAddress;

  /// Geographic coordinates.
  final LatLng latLng;

  const GeocodeSuggestion({
    required this.placeName,
    required this.fullAddress,
    required this.latLng,
  });
}
```

- [ ] **Step 2: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/models/geocode_suggestion.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/models/geocode_suggestion.dart
git commit -m "feat: add GeocodeSuggestion model"
```

---

### Task 2: Create GeocodingService

**Files:**
- Create: `lib/services/geocoding_service.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/services/geocoding_service.dart
// Mapbox Geocoding API v5 — address search for Colombia.
// Uses the same MAPBOX_PUBLIC_TOKEN as DirectionsService and TileLayer.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/env.dart';
import '../models/geocode_suggestion.dart';

class GeocodingService {
  static const _base = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Returns up to 5 address suggestions for [query].
  ///
  /// [proximity]: optional LatLng to bias results toward user location.
  /// Returns [] if token is empty, query has fewer than 3 chars, or any error.
  Future<List<GeocodeSuggestion>> search(
    String query, {
    LatLng? proximity,
  }) async {
    final token = Env.mapboxToken;
    if (token.isEmpty || query.trim().length < 3) return [];

    try {
      final encoded = Uri.encodeComponent(query.trim());
      var url =
          '$_base/$encoded.json?access_token=$token&country=co&language=es&limit=5';
      if (proximity != null) {
        url += '&proximity=${proximity.longitude},${proximity.latitude}';
      }

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('[GeocodingService] ${res.statusCode}: ${res.body}');
        return [];
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      return features.map((f) {
        final coords = f['geometry']['coordinates'] as List;
        return GeocodeSuggestion(
          placeName: f['text'] as String? ?? '',
          fullAddress: f['place_name'] as String? ?? '',
          latLng: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('[GeocodingService] search error: $e');
      return [];
    }
  }

  /// Geocodes a single address string. Returns the first result or null.
  Future<GeocodeSuggestion?> geocodeFirst(
    String query, {
    LatLng? proximity,
  }) async {
    final results = await search(query, proximity: proximity);
    return results.isEmpty ? null : results.first;
  }
}

final geocodingService = GeocodingService();
```

- [ ] **Step 2: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/services/geocoding_service.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/services/geocoding_service.dart
git commit -m "feat: add GeocodingService (Mapbox Geocoding API v5)"
```

---

### Task 3: Add routeResults to AiMessage

**Files:**
- Modify: `lib/models/ai_models.dart`

Current `AiMessage` (lines 29-45):
```dart
class AiMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source;

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
  });
}
```

- [ ] **Step 1: Add import at top of ai_models.dart**

Add after the comment at line 1:
```dart
import '../models/route_result.dart';
```

- [ ] **Step 2: Add routeResults field to AiMessage**

Find the `AiMessage` class and add the new field and constructor param:

```dart
class AiMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source;
  /// Real Mapbox polylines for "Ver en mapa".
  /// Outer null = no real route data (heuristic fallback used).
  /// Inner null = that specific profile (walking/driving/cycling) failed.
  /// Index 0 = walking, 1 = driving, 2 = cycling.
  final List<RouteResult?>? routeResults;

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
    this.routeResults,
  });
}
```

- [ ] **Step 3: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/models/ai_models.dart
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/models/ai_models.dart
git commit -m "feat: add routeResults field to AiMessage for real Mapbox polylines"
```

---

## Chunk 2: AiService + AiConversationProvider

### Task 4: Enhance AiService with real route data

**Files:**
- Modify: `lib/services/ai_service.dart`

Three changes:
1. Add imports for `GeocodingService`, `DirectionsService`, `RouteResult`
2. Add `_extractDestination()` helper
3. Update `sendMessage()` to accept `selectedMode` and inject real route data

- [ ] **Step 1: Add imports**

At the top of `ai_service.dart`, after the existing imports, add:
```dart
import 'package:latlong2/latlong.dart';
import '../models/route_result.dart';
import 'geocoding_service.dart';
import 'directions_service.dart';
import 'location_service.dart';
```

- [ ] **Step 2: Add _extractDestination() helper**

Add this method to the `AiService` class, after `_buildTrafficContext()`:

```dart
// ---------------------------------------------------------------------------
// Destination extraction from natural-language query
// ---------------------------------------------------------------------------

/// Extracts a destination string from a route-planning query.
///
/// Uses ordered patterns from most to least specific.
/// The broad "a (.+)" fallback is intentionally excluded to avoid false
/// positives in Spanish (e.g. "cuánto tarda a pie" → "pie").
///
/// Returns the extracted destination string, or null if none found.
String? _extractDestination(String query) {
  final patterns = [
    // "de X a Y" — captures Y (the destination)
    RegExp(r'de .+? a\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
    // "llegar a", "llevarme a", "ir a", "viajar a"
    RegExp(r'(?:llegar a|llevarme a|ir a|viajar a)\s+(.+?)(?:[,?!]|$)',
        caseSensitive: false),
    // "para ir a X" or "para X"
    RegExp(r'\bpara\s+(?:ir a\s+)?(.+?)(?:[,?!]|$)', caseSensitive: false),
    // "hasta X"
    RegExp(r'\bhasta\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
    // "al X" (al Centro, al aeropuerto)
    RegExp(r'\bal\s+(.+?)(?:[,?!]|$)', caseSensitive: false),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(query);
    if (m != null) {
      final captured = m.group(1)?.trim();
      if (captured != null && captured.isNotEmpty) return captured;
    }
  }
  return null;
}
```

- [ ] **Step 3: Update sendMessage() signature**

Find the `sendMessage` method signature and add `selectedMode`:

Current:
```dart
Future<AiMessage> sendMessage({
  required String query,
  List<ConversationTurn>? history,
  Map<String, double>? userLocation,
  String? context,
}) async {
```

Replace with:
```dart
Future<AiMessage> sendMessage({
  required String query,
  List<ConversationTurn>? history,
  Map<String, double>? userLocation,
  String? selectedMode,
  String? context,
}) async {
```

- [ ] **Step 4: Add real route data logic inside sendMessage()**

Find this line inside `sendMessage()`:
```dart
final kgContext = await _fetchKgContext(query);
```

After that line, add the real route data block:
```dart
// Real route data — only for route queries with an extractable destination.
// locationService.getCurrentPosition() is called internally so callers don't
// need to pass userLocation for this feature to work.
List<RouteResult?>? routeResults;
String realRouteBlock = '';
if (_routePattern.hasMatch(query)) {
  final destString = _extractDestination(query);
  if (destString != null) {
    // Use passed userLocation if available, otherwise ask GPS
    LatLng? originLatLng;
    if (userLocation != null) {
      originLatLng = LatLng(
        userLocation['lat'] ?? userLocation['latitude'] ?? 0,
        userLocation['lng'] ?? userLocation['longitude'] ?? 0,
      );
    } else {
      originLatLng = await locationService.getCurrentPosition();
    }

    if (originLatLng != null) {
      final destSuggestion = await geocodingService.geocodeFirst(
        destString,
        proximity: originLatLng,
      );
      if (destSuggestion != null) {
        final results = await Future.wait([
          directionsService.getRoute(
              origin: originLatLng,
              destination: destSuggestion.latLng,
              profile: RouteProfile.walking),
          directionsService.getRoute(
              origin: originLatLng,
              destination: destSuggestion.latLng,
              profile: RouteProfile.driving),
          directionsService.getRoute(
              origin: originLatLng,
              destination: destSuggestion.latLng,
              profile: RouteProfile.cycling),
        ]);
        routeResults = results; // [walking?, driving?, cycling?]

        final walkR = results[0];
        final driveR = results[1];
        final bikeR = results[2];
        final walkStr = walkR != null ? '${walkR.durationMin} min, ${walkR.distanceKm.toStringAsFixed(1)} km' : 'no disponible';
        final driveStr = driveR != null ? '${driveR.durationMin} min, ${driveR.distanceKm.toStringAsFixed(1)} km' : 'no disponible';
        final bikeStr = bikeR != null ? '${bikeR.durationMin} min, ${bikeR.distanceKm.toStringAsFixed(1)} km' : 'no disponible';

        realRouteBlock = '''

DATOS REALES DE RUTA (Mapbox):
Destino: ${destSuggestion.placeName} (${destSuggestion.fullAddress})
- Caminando: $walkStr
- En auto/bus: $driveStr
- En bici: $bikeStr
Modo preseleccionado por el usuario: ${selectedMode ?? 'Auto'}
Presenta las 3 opciones brevemente. Recomienda la mejor según el modo y condiciones de tráfico.
Al final de tu respuesta agrega exactamente esta línea: "Toca 'Ver en mapa' para aplicar la ruta."
''';
      }
    }
  }
}
```

- [ ] **Step 5: Inject realRouteBlock into systemPrompt**

Find:
```dart
final systemPrompt = _systemBase + kgContext + trafficBlock;
```

Replace with:
```dart
final systemPrompt = _systemBase + kgContext + trafficBlock + realRouteBlock;
```

- [ ] **Step 6: Attach routeResults to the returned AiMessage**

Find the return statement inside the `if (response.statusCode == 200)` block:
```dart
return AiMessage(
  role: 'assistant',
  content: text,
  timestamp: DateTime.now(),
  latencyMs: latencyMs,
  source: 'groq',
  routes: routes,
);
```

Replace with:
```dart
return AiMessage(
  role: 'assistant',
  content: text,
  timestamp: DateTime.now(),
  latencyMs: latencyMs,
  source: 'groq',
  routes: routes,
  routeResults: routeResults,
);
```

- [ ] **Step 7: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/services/ai_service.dart
```

Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "feat: AiService extracts destination, fetches real Mapbox routes, injects real data into prompt"
```

---

### Task 5: Update AiConversationProvider to forward selectedMode

**Files:**
- Modify: `lib/providers/ai_conversation_provider.dart`

- [ ] **Step 1: Update send() signature**

Find:
```dart
Future<void> send(String query) async {
```

Replace with:
```dart
Future<void> send(String query, {String? selectedMode}) async {
```

- [ ] **Step 2: Forward selectedMode to aiService.sendMessage()**

Find inside `send()`:
```dart
final reply = await aiService.sendMessage(
  query: trimmed,
  history: state.history,
);
```

Replace with:
```dart
final reply = await aiService.sendMessage(
  query: trimmed,
  history: state.history,
  selectedMode: selectedMode,
);
```

- [ ] **Step 3: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/providers/ai_conversation_provider.dart
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/ai_conversation_provider.dart
git commit -m "feat: forward selectedMode from AiConversationProvider to AiService"
```

---

## Chunk 3: UI — Route Planner + AI Chat

### Task 6: Simplify route planner with autocomplete

**Files:**
- Modify: `lib/features/routes/route_planner_screen.dart`

This is a significant rewrite of the screen. The current screen has:
- `_results: List<RouteResult?>` (3 profiles)
- `_selected: String` profile selector
- `_parseDestination()` — raw lat,lng parser
- `_selectRoute()` — card selection handler
- A `ListView` with 3 `_buildCard()` calls
- Private classes: `_RouteOption`, `_Step`, `_RouteCard`, `_StatBadge`

**New screen keeps:**
- `_originCtrl`, `_destCtrl`, `_originLatLng`
- `_loading`, `_resolveOrigin()`
- The `_LocationInputs` widget (unchanged)
- The mode indicator chip (already added in Subsystem 1)

**New screen adds:**
- `_suggestions: List<GeocodeSuggestion>`, `_destLatLng: LatLng?`, `Timer? _debounce`
- `_onDestChanged()` with debounce
- Autocomplete suggestions ListView
- Updated `_search()` — single profile, uses `_destLatLng`

- [ ] **Step 1: Add new imports**

At the top of `route_planner_screen.dart`, after existing imports, add:
```dart
import 'dart:async';
import '../../models/geocode_suggestion.dart';
import '../../services/geocoding_service.dart';
```

- [ ] **Step 2: Replace state variables**

Find and replace the state variables at the top of `_RoutePlannerScreenState`:

Current:
```dart
final _originCtrl = TextEditingController();
final _destCtrl   = TextEditingController();

LatLng? _originLatLng;
List<RouteResult?> _results = [null, null, null]; // walking, driving, cycling
bool _loading = false;
String _selected = RouteProfile.walking;
```

Replace with:
```dart
final _originCtrl = TextEditingController();
final _destCtrl   = TextEditingController();

LatLng? _originLatLng;
LatLng? _destLatLng;
List<GeocodeSuggestion> _suggestions = [];
Timer? _debounce;
bool _loading = false;
```

- [ ] **Step 3: Update initState()**

Current `initState()`:
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

Replace with:
```dart
@override
void initState() {
  super.initState();
  _resolveOrigin();
  _destCtrl.addListener(_onDestChanged);
}
```

- [ ] **Step 4: Update dispose()**

Current:
```dart
@override
void dispose() {
  _originCtrl.dispose();
  _destCtrl.dispose();
  super.dispose();
}
```

Replace with:
```dart
@override
void dispose() {
  _debounce?.cancel();
  _destCtrl.removeListener(_onDestChanged);
  _originCtrl.dispose();
  _destCtrl.dispose();
  super.dispose();
}
```

- [ ] **Step 5: Add _onDestChanged() method**

Add after `_resolveOrigin()`:
```dart
void _onDestChanged() {
  final text = _destCtrl.text.trim();
  // Clear stored LatLng whenever user edits the field manually
  if (_destLatLng != null) {
    setState(() => _destLatLng = null);
  }
  if (text.length < 3) {
    setState(() => _suggestions = []);
    return;
  }
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    final results = await geocodingService.search(
        text, proximity: _originLatLng);
    if (mounted) setState(() => _suggestions = results);
  });
}
```

- [ ] **Step 6: Replace _search() method**

Find and replace the entire `_search()` method:

```dart
Future<void> _search() async {
  final messenger = ScaffoldMessenger.of(context);
  if (_originLatLng == null) {
    GSToast.showWithMessenger(messenger,
        message: 'Obteniendo ubicación, espera un momento...');
    return;
  }

  LatLng? destLatLng = _destLatLng;
  if (destLatLng == null) {
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
    context.pop();
  } else {
    GSToast.showWithMessenger(messenger,
        message: 'No se pudo calcular la ruta.');
  }
}
```

- [ ] **Step 7: Remove _selectRoute() method**

Delete the entire `_selectRoute()` method:
```dart
void _selectRoute(String profile, int index) {
  setState(() => _selected = profile);
  final route = _results[index];
  if (route != null) {
    ref.read(activeRouteProvider.notifier).state = route;
    context.pop();
  }
}
```

- [ ] **Step 8: Replace build() body**

Find the `build()` method's `body:` section. Replace the full `body:` widget with:

```dart
body: Column(
  children: [
    _LocationInputs(originCtrl: _originCtrl, destCtrl: _destCtrl),
    // Autocomplete suggestions
    if (_suggestions.isNotEmpty)
      Container(
        margin: const EdgeInsets.fromLTRB(
            GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.md),
          border: Border.all(color: GSColors.border),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: GSColors.border),
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined,
                  size: 18, color: GSColors.accent),
              title: Text(s.placeName,
                  style: const TextStyle(
                      fontSize: 14,
                      color: GSColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(s.fullAddress,
                  style: const TextStyle(
                      fontSize: 12, color: GSColors.textSecondary)),
              onTap: () {
                _destCtrl.removeListener(_onDestChanged);
                _destCtrl.text = s.placeName;
                _destCtrl.addListener(_onDestChanged);
                setState(() {
                  _destLatLng = s.latLng;
                  _suggestions = [];
                });
              },
            );
          },
        ),
      ),
    // Mode indicator
    Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
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
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
      child: GSButton(
        label: _loading ? 'Buscando...' : 'Buscar ruta',
        onPressed: _loading ? null : _search,
        leadingIcon: Icons.search_rounded,
      ),
    ),
    const SizedBox(height: GSSpacing.s4),
  ],
),
```

- [ ] **Step 9: Remove unused private classes and methods**

Delete from the file:
- `_parseDestination()` method (lines ~55-63 — raw lat,lng parser, replaced by geocoding)
- `_buildCard()` method
- `_RouteOption` class
- `_Step` class
- `_RouteCard` class
- `_StatBadge` class

Keep: `_LocationInputs` (unchanged).

- [ ] **Step 10: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/features/routes/route_planner_screen.dart
```

Expected: No issues found.

- [ ] **Step 11: Commit**

```bash
git add lib/features/routes/route_planner_screen.dart
git commit -m "feat: simplify route planner — autocomplete destination, single-profile search, remove 3 cards"
```

---

### Task 7: Add "Ver en mapa" to AI chat screen

**Files:**
- Modify: `lib/features/ai_chat/ai_chat_screen.dart`

Three changes:
1. Add new imports
2. Update `_send()` to pass `selectedMode`
3. Convert `_MessageBubble` to `ConsumerStatefulWidget` and add route chips + "Ver en mapa"

- [ ] **Step 1: Add imports**

At the top of `ai_chat_screen.dart`, after existing imports, add:
```dart
import 'package:go_router/go_router.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/gs_button.dart';
```

- [ ] **Step 2: Update _send() to pass selectedMode**

Find in `_AiChatScreenState`:
```dart
await ref.read(aiConversationProvider.notifier).send(msg);
```

Replace with:
```dart
await ref.read(aiConversationProvider.notifier).send(
  msg,
  selectedMode: ref.read(selectedModeProvider),
);
```

- [ ] **Step 3: Convert _MessageBubble to ConsumerStatefulWidget**

The current `_MessageBubble` is a `StatelessWidget`. Replace the entire class with a `ConsumerStatefulWidget` that has local `_selectedRouteIdx` state and can access `ref` for `activeRouteProvider`.

Replace:
```dart
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
```

With:
```dart
class _MessageBubble extends ConsumerStatefulWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  /// Index into message.routeResults: 0=walking, 1=driving, 2=cycling.
  /// Defaults to 1 (driving/bus) as the most common urban mode.
  int _selectedRouteIdx = 1;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
```

> **Note:** After this change, all references inside `build()` to `message` must use `widget.message` or the local `message` variable assigned above. Use the local `message` variable for cleaner code.

- [ ] **Step 4: Add route chips and "Ver en mapa" button inside _MessageBubbleState.build()**

Inside the `Column` children of the assistant message bubble (after the heuristic route card block), find:
```dart
// Route card
if (message.routes != null &&
    message.routes!.isNotEmpty) ...[
  const SizedBox(height: GSSpacing.s2),
  _RouteQuickCard(
      routes: message.routes!,
      isEstimated: isEstimated),
],
```

After that block (still inside the `Column` children), add:
```dart
// Real route chips + "Ver en mapa" button
if (message.routeResults != null) ...[
  const SizedBox(height: GSSpacing.s3),
  Wrap(
    spacing: GSSpacing.s2,
    runSpacing: GSSpacing.s2,
    children: List.generate(3, (i) {
      final r = message.routeResults![i];
      const labels = ['Caminando', 'Auto/Bus', 'Bici'];
      const icons = [
        Icons.directions_walk_rounded,
        Icons.directions_bus_rounded,
        Icons.pedal_bike_rounded,
      ];
      final label = r != null
          ? '${labels[i]} · ${r.durationMin} min'
          : '${labels[i]} · N/D';
      return ChoiceChip(
        avatar: Icon(icons[i], size: 14),
        label: Text(label,
            style: const TextStyle(fontSize: 12)),
        selected: _selectedRouteIdx == i,
        onSelected: r != null
            ? (_) => setState(() => _selectedRouteIdx = i)
            : null,
      );
    }),
  ),
  const SizedBox(height: GSSpacing.s2),
  GSButton(
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
],
```

- [ ] **Step 5: Verify**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze lib/features/ai_chat/ai_chat_screen.dart
```

Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai_chat/ai_chat_screen.dart
git commit -m "feat: add real route chips and 'Ver en mapa' button to AI chat"
```

---

## Chunk 4: Final verification and docs

### Task 8: Full analysis and CLAUDE.md update

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full project analysis**

```bash
cd "c:\Users\User\Desktop\proyecto TI\gosmart" && flutter analyze
```

Expected: No issues found. If there are issues, fix them before proceeding.

- [ ] **Step 2: Add new services/models to CLAUDE.md**

In `CLAUDE.md`, find the Architecture > Directory Structure section. Under `services/`, add:
```
│   ├── geocoding_service.dart    # Mapbox Geocoding API v5 — address search for Colombia
```

Under `models/`, add:
```
│   ├── geocode_suggestion.dart   # Address suggestion: placeName, fullAddress, latLng
```

Find the State Management providers table. After `activeRouteProvider`, `selectedModeProvider` is already there. No changes needed.

- [ ] **Step 3: Commit CLAUDE.md**

```bash
git add CLAUDE.md
git commit -m "docs: add GeocodingService and GeocodeSuggestion to CLAUDE.md"
```

- [ ] **Step 4: Push**

```bash
git push origin main
```

---

## Verification Checklist

After all tasks complete:

- [ ] Route planner: typing 3+ chars in destination → suggestions appear
- [ ] Route planner: tapping a suggestion fills the field and stores LatLng
- [ ] Route planner: "Buscar ruta" draws a route on the home map using the selected mode
- [ ] Route planner: no 3 route cards visible anywhere
- [ ] AI chat: "cómo llego al Parque de la 93" → response includes real times + chips + "Ver en mapa"
- [ ] AI chat: "Ver en mapa" button applies route to home map
- [ ] AI chat: chips can be tapped to switch between walking/driving/cycling
- [ ] AI chat: messages without route data show no chips/button (normal chat unaffected)
- [ ] `flutter analyze` — zero errors
