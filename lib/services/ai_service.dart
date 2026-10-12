// lib/services/ai_service.dart
// GoSmart AI — cliente delgado de la Edge Function `ai-chat` (Groq vive en el servidor).
// Flujo: query → ai-chat → (si la IA pide plan_trip: planificador local → ai-chat)
// → respuesta + rutas del planificador para "Ver en el mapa".

import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:latlong2/latlong.dart';

import '../core/supabase_client.dart';
import '../core/telemetry.dart';
import '../models/ai_models.dart';
import '../models/route_result.dart';
import '../models/traffic_model.dart';
import 'traffic_service.dart';
import 'trip_tool.dart';

const _fallbackReply =
    'El asistente no está disponible ahora. Puedes planear tu viaje desde el mapa.';

// ─────────────────────────────────────────────────────────────────────────────
// Intent detection
// ─────────────────────────────────────────────────────────────────────────────

/// Pregunta por el tráfico: se agrega la franja horaria como contexto.
final _trafficPattern = RegExp(
  r'tráfico|trafico|trancón|trancon|hora pico|congestión|congestion|'
  r'demorar|demoro|tránsito|transito|vías están|movilidad hoy',
  caseSensitive: false,
);

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
  // Public API
  // ---------------------------------------------------------------------------

  /// Herramienta plan_trip (corre en el celular). Inyectable en pruebas.
  TripTool tripTool = TripTool();

  Future<AiMessage> sendMessage({
    required String query,
    List<ConversationTurn>? history,
    Map<String, double>? userLocation,
    LatLng? userLatLng,
    String? selectedMode,
    String? context,
  }) async {
    final resolvedLatLng = userLatLng ??
        (userLocation != null
            ? LatLng(
                userLocation['lat'] ?? userLocation['latitude'] ?? 0,
                userLocation['lng'] ?? userLocation['longitude'] ?? 0,
              )
            : null);
    final now = DateTime.now();
    final t0 = now.millisecondsSinceEpoch;

    final clientContext = [
      if (resolvedLatLng != null)
        'Ubicación del usuario: lat=${resolvedLatLng.latitude.toStringAsFixed(4)}, '
            'lng=${resolvedLatLng.longitude.toStringAsFixed(4)}',
      if (selectedMode != null) 'Modo elegido en la app: $selectedMode',
      if (_trafficPattern.hasMatch(query)) _buildTrafficContext(now),
    ].join('\n');

    final body = <String, dynamic>{
      'query': query,
      'history': (history ?? [])
          .take(6)
          .map((t) => {'role': t.role, 'content': t.content})
          .toList(),
      'client_context': clientContext,
    };

    try {
      var data = await _invoke(body);
      List<RouteResult>? routes;

      // La IA pidió planear: se planea aquí y se le devuelve el resultado (D6).
      final call = data['tool_call'];
      if (data['source'] == 'tool_call' &&
          call is Map &&
          call['name'] == 'plan_trip') {
        final outcome = await tripTool
            .run(Map<String, dynamic>.from(call['args'] as Map? ?? const {}));
        if (outcome.routes.isNotEmpty) routes = outcome.routes;
        body['tool_messages'] = [
          ...(data['tool_messages'] as List? ?? const []),
          {
            'role': 'tool',
            'tool_call_id': call['id'],
            'content': jsonEncode(outcome.result),
          },
        ];
        data = await _invoke(body);
      }

      final latencyMs = DateTime.now().millisecondsSinceEpoch - t0;
      final text = data['content'] as String?;
      final ok = data['source'] == 'groq';
      if (!ok) Telemetry.degraded('groq', '${data['error'] ?? 'bad_payload'}');

      return AiMessage(
        role: 'assistant',
        content: (text == null || text.trim().isEmpty) ? _fallbackReply : text,
        timestamp: DateTime.now(),
        latencyMs: latencyMs,
        source: ok ? 'groq' : 'cache',
        // Las rutas vienen del planificador, no del modelo: sirven aunque
        // la IA falle en la segunda vuelta.
        routeResults: routes,
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

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _supabase.functions
        .invoke('ai-chat', body: body)
        .timeout(const Duration(seconds: 20));
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  AiMessage _unavailable() => AiMessage(
        role: 'assistant',
        content: _fallbackReply,
        timestamp: DateTime.now(),
        source: 'cache',
      );
}

final aiService = AiService();
