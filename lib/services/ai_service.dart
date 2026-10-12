// lib/services/ai_service.dart
// GoSmart AI — cliente delgado de la Edge Function `ai-chat` (Groq vive en el servidor).
// Flujo: query → [ubicación + tráfico + ruta real como contexto] → ai-chat → respuesta + route cards

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:latlong2/latlong.dart';

import '../core/supabase_client.dart';
import '../core/telemetry.dart';
import '../models/ai_models.dart';
import '../models/route_result.dart';
import '../models/traffic_model.dart';
import 'geocoding_service.dart';
import 'directions_service.dart';
import 'location_service.dart';
import 'traffic_service.dart';

const _fallbackReply =
    'El asistente no está disponible ahora. Puedes planear tu viaje desde el mapa.';

// ─────────────────────────────────────────────────────────────────────────────
// Intent detection
// ─────────────────────────────────────────────────────────────────────────────

/// Route planning intent (triggers route cards + traffic context).
final _routePattern = RegExp(
  r'ruta|cómo llego|cómo voy|cuánto demoro|cuanto tardo|'
  r'cómo ir|cómo me voy|qué ruta|mejor ruta|transporte para ir',
  caseSensitive: false,
);

/// Traffic condition intent (triggers traffic context, no route cards).
final _trafficPattern = RegExp(
  r'tráfico|trafico|trancón|trancon|hora pico|congestión|congestion|'
  r'demorar|demoro|tránsito|transito|vías están|movilidad hoy',
  caseSensitive: false,
);

bool _isRouteOrTrafficQuery(String query) =>
    _routePattern.hasMatch(query) || _trafficPattern.hasMatch(query);

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AiService {
  final _supabase = GoSmartSupabase.client;

  /// Allows tests to inject a mock — production uses the global singleton.
  final ITrafficService _traffic;

  AiService({ITrafficService? trafficServiceOverride})
      : _traffic = trafficServiceOverride ?? trafficService;

  // ---------------------------------------------------------------------------
  // Traffic context injection (~55 tokens)
  // ---------------------------------------------------------------------------

  /// Builds a concise traffic block injected into the system prompt only for
  /// route or traffic queries. Keeps the token budget safe for other questions.
  ///
  String _buildTrafficContext(DateTime now) {
    final condition = _traffic.getCurrentCondition(now: now, zone: ZoneType.urban);
    final f = condition.factor;
    final periodEs = switch (f.period) {
      TrafficPeriod.morningRush => 'hora pico mañana (06:00–09:00)',
      TrafficPeriod.day         => 'flujo normal (09:00–17:00)',
      TrafficPeriod.eveningRush => 'hora pico tarde (17:00–20:00)',
      TrafficPeriod.night       => 'tráfico libre (20:00–06:00)',
    };
    return '''

CONDICIONES DE TRÁFICO ACTUALES:
- Estado: ${condition.label}
- Período: $periodEs
- Factor de duración: ${f.durationMultiplier}x
Ajusta los tiempos de viaje con este factor. No menciones el número directamente.
''';
  }

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

  // ---------------------------------------------------------------------------
  // Heuristic route builder (traffic-aware)
  // ---------------------------------------------------------------------------

  /// Builds three illustrative [RouteOption]s with traffic-adjusted times/fares.
  /// Attached to [AiMessage.routes] so the chat UI renders route cards.
  ///
  /// Valores de referencia para Riohacha (TransPadilla $3.000, mototaxi negociado).
  /// Se reemplazan por el planificador del grafo en la Fase 5.
  List<RouteOption> _heuristicRoutes(DateTime now) {
    final urbanFactor  = _traffic.getTrafficFactor(now: now, zone: ZoneType.urban);
    final centerFactor = _traffic.getTrafficFactor(now: now, zone: ZoneType.center);

    TrafficRouteMetadata buildMeta(TrafficFactor f) {
      final condition = _traffic.getCurrentCondition(now: now, zone: f.zone);
      final hex = f.durationMultiplier >= 1.40
          ? '#E53935'
          : f.durationMultiplier >= 1.15
              ? '#FB8C00'
              : '#43A047';
      return TrafficRouteMetadata(
        label: condition.label,
        durationMultiplier: f.durationMultiplier,
        colorHex: hex,
      );
    }

    return [
      RouteOption(
        id: 'h-fastest',
        type: 'fastest',
        totalDurationMin: _traffic.adjustDuration(15, urbanFactor),
        totalCostCop: _traffic.adjustFare(5000, urbanFactor),
        totalCo2Kg: 0.30,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          Leg(
            mode: 'taxi',
            line: 'Mototaxi',
            durationMin: _traffic.adjustDuration(15, urbanFactor),
            costCop: _traffic.adjustFare(5000, urbanFactor),
          ),
        ],
      ),
      RouteOption(
        id: 'h-cheapest',
        type: 'cheapest',
        totalDurationMin: _traffic.adjustDuration(35, urbanFactor),
        totalCostCop: 3000, // TransPadilla, pasaje fijo
        totalCo2Kg: 0.15,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          const Leg(mode: 'walk', durationMin: 8, costCop: 0),
          Leg(
            mode: 'bus',
            line: 'TransPadilla',
            durationMin: _traffic.adjustDuration(27, centerFactor),
            costCop: 3000,
          ),
        ],
      ),
      RouteOption(
        id: 'h-eco',
        type: 'eco',
        totalDurationMin: _traffic.adjustDuration(40, urbanFactor),
        totalCostCop: 3000,
        totalCo2Kg: 0.10,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          const Leg(mode: 'walk', durationMin: 15, costCop: 0),
          Leg(
            mode: 'bus',
            line: 'TransPadilla',
            durationMin: _traffic.adjustDuration(25, urbanFactor),
            costCop: 3000,
          ),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<AiMessage> sendMessage({
    required String query,
    List<ConversationTurn>? history,
    Map<String, double>? userLocation,
    LatLng? userLatLng,
    String? selectedMode,
    String? context,
  }) async {
    // Build location context string injected into the user message
    final resolvedLatLng = userLatLng ??
        (userLocation != null
            ? LatLng(
                userLocation['lat'] ?? userLocation['latitude'] ?? 0,
                userLocation['lng'] ?? userLocation['longitude'] ?? 0,
              )
            : null);
    final locationContext = resolvedLatLng != null
        ? 'Ubicación del usuario: lat=${resolvedLatLng.latitude.toStringAsFixed(4)}, lng=${resolvedLatLng.longitude.toStringAsFixed(4)}\n'
        : '';

    final now = DateTime.now();
    final t0  = now.millisecondsSinceEpoch;
    final isRouteOrTraffic = _isRouteOrTrafficQuery(query);

    // Real route data — only for route queries with an extractable destination.
    // locationService.getCurrentPosition() is called internally so callers don't
    // need to pass userLocation for this feature to work.
    List<RouteResult?>? routeResults;
    String realRouteBlock = '';
    if (_routePattern.hasMatch(query)) {
      final destString = _extractDestination(query);
      if (destString != null) {
        // Use passed userLatLng / userLocation if available, otherwise ask GPS
        LatLng? originLatLng = resolvedLatLng;
        originLatLng ??= await locationService.getCurrentPosition();

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

Datos reales de ruta (Mapbox):
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

    // Traffic context is synchronous — zero latency
    final trafficBlock = isRouteOrTraffic ? _buildTrafficContext(now) : '';
    final clientContext = locationContext + trafficBlock + realRouteBlock;

    try {
      final response = await _supabase.functions.invoke(
        'ai-chat',
        body: {
          'query': query,
          'history': (history ?? [])
              .take(6)
              .map((t) => {'role': t.role, 'content': t.content})
              .toList(),
          'client_context': clientContext,
        },
      ).timeout(const Duration(seconds: 20));

      final latencyMs = DateTime.now().millisecondsSinceEpoch - t0;
      final data = response.data;
      final text = data is Map ? data['content'] as String? : null;
      final ok = data is Map && data['source'] == 'groq';

      if (!ok) {
        Telemetry.degraded('groq', '${data is Map ? data['error'] : 'bad_payload'}');
      }

      // Route cards only for routing queries, not pure traffic questions
      // ("¿cómo está el trancón?" gets traffic context but no cards)
      final routes = _routePattern.hasMatch(query) ? _heuristicRoutes(now) : null;

      return AiMessage(
        role: 'assistant',
        content: text ?? _fallbackReply,
        timestamp: DateTime.now(),
        latencyMs: latencyMs,
        source: ok ? 'groq' : 'cache',
        routes: routes,
        routeResults: routeResults,
      );
    } on FunctionException catch (e) {
      Telemetry.degraded('ai-chat', 'http_${e.status}');
      return _unavailable();
    } on TimeoutException {
      Telemetry.degraded('ai-chat', 'timeout');
      return _unavailable();
    } catch (e) {
      Telemetry.degraded('ai-chat', e.runtimeType.toString());
      return _unavailable();
    }
  }

  AiMessage _unavailable() => AiMessage(
        role: 'assistant',
        content: _fallbackReply,
        timestamp: DateTime.now(),
        source: 'cache',
      );
}

final aiService = AiService();
