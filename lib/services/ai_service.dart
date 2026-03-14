// lib/services/ai_service.dart
import '../core/supabase_client.dart';

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? routes;

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
  });
}

class AiService {
  final _client = GoSmartSupabase.client;

  Future<AiMessage> sendMessage({
    required String query,
    Map<String, double>? userLocation,
    String? context,
  }) async {
    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'query': query,
        if (userLocation != null) 'user_location': userLocation,
        if (context != null) 'context': context,
      },
    );

    final raw = response.data;
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return AiMessage(
      role: 'assistant',
      content: data['reply'] as String? ??
          'Lo siento, el asistente no está disponible. Intenta de nuevo en unos minutos.',
      timestamp: DateTime.now(),
      routes: data['routes'] != null
          ? List<Map<String, dynamic>>.from(data['routes'] as List)
          : null,
    );
  }
}

final aiService = AiService();
