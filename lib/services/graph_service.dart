// lib/services/graph_service.dart
// Trae el grafo de transporte (`graph_snapshot`, migración 014) y lo guarda en
// el teléfono: el planificador funciona igual sin señal (D6).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase_client.dart';
import '../planner/fares.dart';
import '../planner/graph.dart';

class GraphBundle {
  const GraphBundle(this.graph, this.fareRules, {this.isCached = false});
  final TransportGraph graph;
  final Map<TransitMode, FareRule> fareRules;
  final bool isCached;

  static GraphBundle fromJson(Map<String, dynamic> j, {bool cached = false}) {
    final rules = <TransitMode, FareRule>{...defaultFareRules};
    for (final r in (j['fare_rules'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(r as Map);
      final mode = TransitMode.fromName(m['mode'] as String?);
      if (mode == null) continue;
      rules[mode] = FareRule(
        base: (m['base'] as num).toInt(),
        perKm: (m['per_km'] as num).toInt(),
        minimum: (m['minimum'] as num?)?.toInt() ?? 0,
        nightFactor: (m['night_factor'] as num?)?.toDouble() ?? 1.2,
      );
    }
    return GraphBundle(TransportGraph.fromJson(j), rules, isCached: cached);
  }
}

class GraphService {
  static const _cacheKey = 'transport_graph_v1';

  Future<GraphBundle> load() async {
    try {
      final res = await GoSmartSupabase.client.rpc('graph_snapshot');
      final json = Map<String, dynamic>.from(res as Map);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(json));
      } catch (_) {}
      return GraphBundle.fromJson(json);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) rethrow;
      return GraphBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>,
          cached: true);
    }
  }
}

final graphService = GraphService();
