// lib/services/ai_service.dart
import 'dart:async'; // required for unawaited()
import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../models/ai_models.dart';

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source; // 'gemini' | 'heuristic' | 'cache'

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
  });
}

class AiService {
  final _client = GoSmartSupabase.client;

  Future<AiMessage> sendMessage({
    required String query,
    List<ConversationTurn>? history,
    Map<String, double>? userLocation,
    String? context,
  }) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;

    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'query': query,
        if (history != null && history.isNotEmpty)
          'history': history.map((t) => t.toJson()).toList(),
        if (userLocation != null) 'user_location': userLocation,
        if (context != null) 'context': context,
      },
    );

    final t2 = DateTime.now().millisecondsSinceEpoch;
    final raw = response.data;
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    final backendMs = data['latency_ms'] as int?;
    final source = data['source'] as String? ?? 'gemini';
    final totalMs = t2 - t0;

    // Fire-and-forget latency log — dev/profile builds only, never blocks UI
    if (kDebugMode || kProfileMode) {
      unawaited(_logLatency(
        totalMs: totalMs,
        backendMs: backendMs,
        source: source,
        intent: data['intent'] as String?,
      ));
    }

    final routesRaw = data['routes'] as List?;
    return AiMessage(
      role: 'assistant',
      content: data['reply'] as String? ??
          'Lo siento, el asistente no está disponible. Intenta de nuevo en unos minutos.',
      timestamp: DateTime.now(),
      routes: routesRaw
          ?.map((r) => RouteOption.fromJson(r as Map<String, dynamic>))
          .toList(),
      latencyMs: backendMs,
      source: source,
    );
  }

  Future<void> _logLatency({
    required int totalMs,
    int? backendMs,
    required String source,
    String? intent,
  }) async {
    try {
      await _client.from('ai_latency_log').insert({
        'total_ms': totalMs,
        if (backendMs != null) 'backend_ms': backendMs,
        'source': source,
        if (intent != null) 'intent': intent,
      });
    } catch (e) {
      // Telemetry must never crash the app
      debugPrint('[AiService] latency log failed: $e');
    }
  }
}

final aiService = AiService();
