// lib/services/ai_service.dart
// GoSmart AI — Groq llama-3.3-70b + RAG desde Supabase KG (directo desde Flutter).
// Flujo: query → buscar entidades en colombia_kg → contexto → Groq → respuesta

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../models/ai_models.dart';

const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model   = 'llama-3.3-70b-versatile';

const _systemBase = '''
Eres el asistente de movilidad de GoSmart, una app colombiana de transporte inteligente.
Tu ÚNICO propósito es ayudar con transporte, movilidad urbana y la app GoSmart en Colombia.

REGLA ABSOLUTA: Si el usuario pregunta sobre algo que NO sea transporte, movilidad, rutas,
barrios/ciudades en contexto de viaje, tarifas o la app GoSmart, responde SOLO:
"Solo puedo ayudarte con temas de transporte y movilidad en Colombia. ¿En qué ciudad o ruta te puedo ayudar?"

CONOCIMIENTO DE TRANSPORTE:
- Bogotá: TransMilenio (BRT), SITP, ciclovías, taxis, InDriver
- Medellín: Metro (Líneas A/B), Metroplús, Tranvía de Ayacucho, Metrocable (J/K/L/M/H)
- Cali: MIO (Masivo Integrado de Occidente)
- Barranquilla: Transmetro
- Cartagena: buses, taxis, mototaxis
- Bucaramanga: Metrolínea
- Pereira: Megabús
- Riohacha y La Guajira: transporte intermunicipal, buses urbanos, mototaxis
- Resto de Colombia: sistemas de buses urbanos locales, taxis, intermunicipal

COMPORTAMIENTO:
- Responde en español, claro y amigable
- Usa el CONTEXTO DE LUGARES si está disponible para dar información precisa del lugar
- Para rutas: da opciones (más rápida, más barata) con tiempos y tarifas aproximadas
- Si no sabes algo con certeza, dilo y sugiere Google Maps o Moovit
- Nunca inventes rutas o tarifas
''';

const _fallbackReply =
    'Lo siento, no pude conectarme. Verifica tu conexión e intenta de nuevo.';

class AiService {
  final _supabase = GoSmartSupabase.client;

  /// Busca entidades relevantes en el KG de Supabase y las convierte en contexto.
  Future<String> _fetchKgContext(String query) async {
    try {
      // Extraer palabras clave (>3 chars, sin stopwords básicas)
      const stopwords = {'para', 'como', 'desde', 'hasta', 'quiero', 'saber',
          'cual', 'la', 'el', 'los', 'las', 'una', 'que', 'mas', 'corta',
          'ruta', 'llegar', 'ir', 'al', 'del', 'con', 'por', 'en', 'de', 'a'};
      final keywords = query
          .toLowerCase()
          .replaceAll(RegExp(r'[¿?¡!,.]'), '')
          .split(' ')
          .where((w) => w.length > 3 && !stopwords.contains(w))
          .take(4)
          .toList();

      if (keywords.isEmpty) return '';

      // Buscar en canonical_name con ilike para cada keyword
      final results = <Map<String, dynamic>>[];
      for (final kw in keywords.take(2)) {
        final res = await _supabase
            .from('colombia_kg')
            .select('canonical_name, type, city, department, embed_text')
            .ilike('canonical_name', '%$kw%')
            .limit(4);
        results.addAll(List<Map<String, dynamic>>.from(res));
      }

      if (results.isEmpty) return '';

      // Deduplicar por canonical_name
      final seen = <String>{};
      final unique = results.where((e) => seen.add(e['canonical_name'] as String)).take(5).toList();

      final lines = unique.map((e) {
        final city = e['city'] ?? e['department'] ?? 'Colombia';
        return '- ${e['canonical_name']} (${e['type']}, $city): ${e['embed_text']}';
      }).join('\n');

      return '\nCONTEXTO DE LUGARES RELEVANTES:\n$lines\n';
    } catch (e) {
      debugPrint('[AiService] KG lookup failed: $e');
      return '';
    }
  }

  Future<AiMessage> sendMessage({
    required String query,
    List<ConversationTurn>? history,
    Map<String, double>? userLocation,
    String? context,
  }) async {
    final key = Env.groqApiKey;
    if (key.isEmpty) {
      return AiMessage(
        role: 'assistant',
        content: 'Asistente no configurado. Agrega GROQ_API_KEY en el .env.',
        timestamp: DateTime.now(),
        source: 'cache',
      );
    }

    final t0 = DateTime.now().millisecondsSinceEpoch;

    // Buscar contexto en KG en paralelo con la preparación del request
    final kgContext = await _fetchKgContext(query);
    final systemPrompt = _systemBase + kgContext;

    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...((history ?? []).take(8).map((t) => {'role': t.role, 'content': t.content})),
        {'role': 'user', 'content': query},
      ];

      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 600,
          'temperature': 0.65,
        }),
      ).timeout(const Duration(seconds: 20));

      final latencyMs = DateTime.now().millisecondsSinceEpoch - t0;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['choices'] as List?)
            ?.firstOrNull?['message']?['content'] as String?
            ?? _fallbackReply;

        return AiMessage(
          role: 'assistant',
          content: text,
          timestamp: DateTime.now(),
          latencyMs: latencyMs,
          source: 'groq',
        );
      } else {
        debugPrint('[AiService] Groq ${response.statusCode}: ${response.body}');
        return AiMessage(
          role: 'assistant',
          content: _fallbackReply,
          timestamp: DateTime.now(),
          source: 'cache',
        );
      }
    } on TimeoutException {
      return AiMessage(
        role: 'assistant',
        content: _fallbackReply,
        timestamp: DateTime.now(),
        source: 'cache',
      );
    } catch (e) {
      debugPrint('[AiService] error: $e');
      return AiMessage(
        role: 'assistant',
        content: _fallbackReply,
        timestamp: DateTime.now(),
        source: 'cache',
      );
    }
  }
}

final aiService = AiService();
