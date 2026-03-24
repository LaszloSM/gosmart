// lib/services/ai_service.dart
// GoSmart AI — Groq llama-3.3-70b + RAG desde Supabase KG + traffic context.
// Flujo: query → KG lookup → [traffic context] → Groq → respuesta + route cards

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:latlong2/latlong.dart';

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../models/ai_models.dart';
import '../models/route_result.dart';
import '../models/traffic_model.dart';
import 'geocoding_service.dart';
import 'directions_service.dart';
import 'location_service.dart';
import 'traffic_service.dart';

const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model   = 'llama-3.3-70b-versatile';

const _systemBase = '''
Eres GoSmart AI, asistente experto en movilidad urbana de TODA Colombia. Conoces el transporte de todas las ciudades colombianas, desde las grandes capitales hasta municipios pequeños. Ayudas a usuarios a planificar viajes, conocer tarifas, rutas y horarios de transporte público y privado en todo el territorio nacional.

IDENTIDAD: Nombre GoSmart AI. Idioma SIEMPRE español colombiano (tuteo natural). Tono amigable y directo. Máximo 3 párrafos por respuesta. Máximo 1 emoji por respuesta si aplica.

SISTEMAS MASIVOS DE TRANSPORTE (tarifas 2024-2025 aproximadas):
• TransMilenio (Bogotá): \$3.000 COP tarifa plana. Integrado con SITP. Opera 4:30am–11:30pm.
• SITP (Bogotá): \$2.950 COP integrado con TransMilenio. Cubre toda la ciudad.
• Metro de Medellín (METRO): \$3.400 COP tarifa plana. Líneas A y B. Integrado con cables y Metroplús.
• Metrocable Medellín: mismo tiquete del Metro. Líneas J (Santo Domingo), K (Acevedo), L (Parque Arví), M (Villa Sierra), H (Oriente).
• Metroplús (Medellín y área metro): \$2.800 COP BRT. Rutas urbanas integradas al Metro.
• MIO (Cali): \$2.700 COP tarifa plana. BRT articulado en carriles exclusivos.
• Megabús (Pereira-Dosquebradas): \$2.500 COP. Sistema BRT del Eje Cafetero.
• Transmetro (Barranquilla-Soledad): \$2.400 COP. BRT articulado.
• Metrolínea (Bucaramanga-Floridablanca-Piedecuesta-Girón): \$2.300 COP. BRT área metropolitana.
• SETP Popayán (Sistema Estratégico de Transporte): ~\$2.200 COP. Autobuses articulados.
• SETP Santa Marta: ~\$2.200 COP. Rutas troncales y zonales.
• SETP Montería: ~\$2.000 COP. Sistema de transporte organizado.
• SETP Manizales (Metroplus): ~\$2.200 COP. Articulados + cables turísticos.
• SETP Pasto: ~\$2.000 COP.
• SETP Armenia: ~\$2.000 COP.
• Transambiental / Transcaribe (Cartagena): \$2.200 COP. BRT con terminales en el centro histórico.
• Cable aéreo de Manizales: transporte turístico y urbano, integrado con SETP.

CIUDADES SIN SISTEMA MASIVO (transporte urbano general):
• Riohacha (La Guajira): buses colectivos y mototaxis. Colectivo \$1.800–\$2.500 COP. Mototaxi urbano \$2.000–\$4.000 COP. Taxi ~\$5.000 COP base.
• Valledupar (Cesar): colectivos \$2.000 COP, mototaxis abundantes \$2.000–\$5.000 COP, taxis ~\$5.000 base.
• Sincelejo (Sucre): mototaxis \$2.000–\$4.000 COP, colectivos ~\$1.800 COP.
• Quibdó (Chocó): transporte fluvial (lanchas) y mototaxis. Lancha ~\$5.000–\$15.000 COP según ruta.
• Mocoa (Putumayo): mototaxis y colectivos intermunicipales. Mototaxi \$2.000–\$3.000 COP.
• Florencia (Caquetá): colectivos ~\$1.800 COP, mototaxis \$2.000–\$4.000 COP.
• San Andrés Islas: transporte en mototaxi (~\$3.000–\$6.000 COP), carro de alquiler, bus ~\$2.000 COP.
• Arauca, Yopal, Villavicencio, Neiva, Ibagué, Tunja: colectivos \$1.800–\$2.500 COP, mototaxis, taxis ~\$5.000–\$7.000 COP base.

TRANSPORTE PRIVADO / INFORMAL (nacional):
• Bus colectivo/buseta urbana: \$1.700–\$2.500 COP según ciudad.
• Mototaxi urbano: \$2.000–\$5.000 COP trayecto corto. Muy común en ciudades intermedias y costeras.
• Taxi Bogotá: banderazo ~\$5.000 + \$150 cada 100–150m.
• Taxi Medellín: banderazo ~\$4.500 COP.
• Taxi Cali/Barranquilla/Bucaramanga/Cartagena: banderazo ~\$4.500–\$5.500 COP.
• Taxi ciudades pequeñas: \$4.000–\$6.000 COP viaje corto.
• InDriver: precio negociado, disponible en Bogotá, Medellín, Cali, Barranquilla, Bucaramanga, Cúcuta, Cartagena, Santa Marta, Pereira, Manizales, Ibagué, Neiva y más de 30 ciudades de Colombia.
• Uber: disponible en Bogotá, Medellín, Cali, Barranquilla, Bucaramanga, Cartagena, Santa Marta, Pereira, Armenia, Manizales, Cúcuta.
• Beat/Cabify: Bogotá y Medellín principalmente.
• Picap (mototaxi app): disponible en varias ciudades intermedias.

TRANSPORTE INTERMUNICIPAL:
• Terminales de transporte: cada ciudad capital tiene terminal. Comprar tiquete en taquilla o apps como Redbus, Pinbus.
• Rutas más usadas: Bogotá-Medellín ~9h \$60.000–\$90.000 COP; Bogotá-Cali ~8h \$55.000–\$80.000 COP; Bogotá-Barranquilla ~20h \$80.000–\$120.000 COP; Medellín-Cartagena ~13h \$70.000–\$100.000 COP.
• Vuelos internos: Avianca, LATAM, Wingo, JetSmart, Ultra Air. Rutas frecuentes entre capitales.

TARJETAS DE PAGO:
• TuLlave/TuLlave+: tarjeta integrada Bogotá (TransMilenio + SITP).
• Cívica: Metro de Medellín y sistema SITVA (Metroplús, cables).
• MIOcard: Cali.
• Metroplus card: Bucaramanga.
• Recargables en Barranquilla, Pereira, Cartagena según el operador.
• GoSmart card: recarga en la app, pago NFC en sistemas compatibles.

REGLAS DE RESPUESTA:
1. Precio SIEMPRE en COP. Aclarar que son aproximados y pueden variar.
2. Conoces TODAS las ciudades de Colombia — nunca digas que no tienes información de una ciudad. Si no hay sistema masivo, describe el transporte informal (colectivos, mototaxis, taxis).
3. Si pide "lo más barato" → recomienda sistema masivo donde exista, si no colectivo/bus.
4. Si pide "lo más rápido" → evalúa taxi/InDriver/Uber vs. transporte masivo según distancia.
5. Sistemas masivos operan ~4:30am–11:30pm generalmente. Transporte informal/taxi disponible 24h.
6. Si el usuario da contexto RAG entre [CONTEXTO], úsalo como información primaria.
7. Si la pregunta NO es de transporte/movilidad, responde: "Soy especialista en movilidad — ¿te ayudo con tu ruta o transporte?"
8. Para ciudades pequeñas sin sistema BRT, siempre menciona mototaxi y colectivo como opciones principales.

FORMATO: Texto plano sin Markdown. Para listas usa "•" como viñeta. Sin asteriscos, sin #, sin **negrita**. Máximo 3 párrafos concisos.

## Respuestas cortas
Para preguntas simples (saludos, preguntas de precio, horario), responde en MÁXIMO 3-4 líneas.
Solo usa párrafos largos para rutas complejas que requieran pasos detallados.
''';

const _fallbackReply =
    'Lo siento, no pude conectarme. Verifica tu conexión e intenta de nuevo.';

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
  // KG context lookup (existing logic)
  // ---------------------------------------------------------------------------

  Future<String> _fetchKgContext(String query) async {
    try {
      const stopwords = {
        'para', 'como', 'desde', 'hasta', 'quiero', 'saber',
        'cual', 'la', 'el', 'los', 'las', 'una', 'que', 'mas', 'corta',
        'ruta', 'llegar', 'ir', 'al', 'del', 'con', 'por', 'en', 'de', 'a',
      };
      final keywords = query
          .toLowerCase()
          .replaceAll(RegExp(r'[¿?¡!,.]'), '')
          .split(' ')
          .where((w) => w.length > 3 && !stopwords.contains(w))
          .take(4)
          .toList();

      if (keywords.isEmpty) return '';

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

      final seen = <String>{};
      final unique = results
          .where((e) => seen.add(e['canonical_name'] as String))
          .take(5)
          .toList();

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

  // ---------------------------------------------------------------------------
  // Traffic context injection (~55 tokens)
  // ---------------------------------------------------------------------------

  /// Builds a concise traffic block injected into the system prompt only for
  /// route or traffic queries. Keeps the token budget safe for other questions.
  ///
  /// Token budget:
  ///   _systemBase ≈ 220t | KG context ≈ 80t | this block ≈ 55t
  ///   history (8 turns) ≈ 200t | user query ≈ 20t | total ≈ 575t
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
  /// Base values are Bogotá-centric estimates. Real routing requires a
  /// Directions API (tracked in the Subsystem B spec).
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
        totalDurationMin: _traffic.adjustDuration(35, urbanFactor),
        totalCostCop: _traffic.adjustFare(5950, urbanFactor),
        totalCo2Kg: 0.48,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          Leg(
            mode: 'metro',
            line: 'TransMilenio',
            durationMin: _traffic.adjustDuration(20, urbanFactor),
            costCop: 3100,
          ),
          Leg(
            mode: 'bus',
            line: 'SITP',
            durationMin: _traffic.adjustDuration(15, centerFactor),
            costCop: 2850,
          ),
        ],
      ),
      RouteOption(
        id: 'h-cheapest',
        type: 'cheapest',
        totalDurationMin: _traffic.adjustDuration(50, urbanFactor),
        totalCostCop: 2950, // SITP flat fare — no surge
        totalCo2Kg: 0.35,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          Leg(
            mode: 'bus',
            line: 'SITP',
            durationMin: _traffic.adjustDuration(50, urbanFactor),
            costCop: 2950,
          ),
        ],
      ),
      RouteOption(
        id: 'h-eco',
        type: 'eco',
        totalDurationMin: _traffic.adjustDuration(45, urbanFactor),
        totalCostCop: 2950, // SITP flat fare — bike leg is free
        totalCo2Kg: 0.12,
        trafficMetadata: buildMeta(urbanFactor),
        legs: [
          Leg(
            mode: 'bus',
            line: 'SITP',
            durationMin: _traffic.adjustDuration(30, urbanFactor),
            costCop: 2950,
          ),
          const Leg(mode: 'bike', durationMin: 15, costCop: 0),
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
    final key = Env.groqApiKey;
    if (key.isEmpty) {
      return AiMessage(
        role: 'assistant',
        content: 'Asistente no configurado. Agrega GROQ_API_KEY en el .env.',
        timestamp: DateTime.now(),
        source: 'cache',
      );
    }

    // Build location context string injected into the user message
    final resolvedLatLng = userLatLng ??
        (userLocation != null
            ? LatLng(
                userLocation['lat'] ?? userLocation['latitude'] ?? 0,
                userLocation['lng'] ?? userLocation['longitude'] ?? 0,
              )
            : null);
    final locationContext = resolvedLatLng != null
        ? '\n[UBICACIÓN ACTUAL DEL USUARIO: lat=${resolvedLatLng.latitude.toStringAsFixed(4)}, lng=${resolvedLatLng.longitude.toStringAsFixed(4)} — Colombia]\n'
        : '';
    final contextualQuery = '$locationContext$query';

    final now = DateTime.now();
    final t0  = now.millisecondsSinceEpoch;
    final isRouteOrTraffic = _isRouteOrTrafficQuery(query);

    // KG lookup first (async I/O)
    final kgContext = await _fetchKgContext(query);

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

    // Traffic context is synchronous — zero latency
    final trafficBlock = isRouteOrTraffic ? _buildTrafficContext(now) : '';
    final systemPrompt = _systemBase + kgContext + trafficBlock + realRouteBlock;

    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...((history ?? []).take(8).map((t) => {'role': t.role, 'content': t.content})),
        {'role': 'user', 'content': contextualQuery},
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

        // Route cards only for routing queries, not pure traffic questions
        // ("¿cómo está el trancón?" gets traffic context but no cards)
        final routes = _routePattern.hasMatch(query) ? _heuristicRoutes(now) : null;

        return AiMessage(
          role: 'assistant',
          content: text,
          timestamp: DateTime.now(),
          latencyMs: latencyMs,
          source: 'groq',
          routes: routes,
          routeResults: routeResults,
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
