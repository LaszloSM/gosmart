// lib/planner/graph.dart
// Grafo de transporte de la región (tablas `graph_nodes` / `graph_edges`,
// migración 014). Puro Dart: el planificador corre en el celular (D6),
// igual con o sin señal, sobre la copia guardada del grafo.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum TransitMode {
  walk('A pie'),
  mototaxi('Mototaxi'),
  taxi('Taxi'),
  colectivo('Colectivo'),
  transpadilla('TransPadilla'),
  intermunicipal('Intermunicipal');

  const TransitMode(this.label);
  final String label;

  static TransitMode? fromName(String? n) {
    for (final m in values) {
      if (m.name == n) return m;
    }
    return null;
  }

  /// Puerta a puerta: se pide donde estés (no tiene paradas).
  bool get isOnDemand =>
      this == TransitMode.mototaxi || this == TransitMode.taxi;
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.name,
    required this.at,
    this.kind = 'paradero',
    this.city,
  });
  final String id;
  final String name;
  final LatLng at;
  final String kind;
  final String? city;

  factory GraphNode.fromJson(Map<String, dynamic> j) => GraphNode(
        id: j['id'] as String,
        name: j['name'] as String,
        at: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        kind: j['kind'] as String? ?? 'paradero',
        city: j['city'] as String?,
      );
}

class GraphEdge {
  const GraphEdge({
    required this.from,
    required this.to,
    required this.mode,
    required this.minutes,
    required this.fareMin,
    required this.fareMax,
    this.segmentIds = const [],
    this.nightOk = true,
    this.waitMinutes = 0,
  });

  final String from;
  final String to;
  final TransitMode mode;

  /// Minutos en movimiento.
  final int minutes;

  /// Espera típica en el punto (llenado del colectivo, frecuencia del bus).
  final int waitMinutes;
  final int fareMin;
  final int fareMax;

  /// Tramos de `road_segments` que recorre (para bloqueos).
  final List<String> segmentIds;

  /// false = no opera de noche (21:00–5:00).
  final bool nightOk;

  factory GraphEdge.fromJson(Map<String, dynamic> j) => GraphEdge(
        from: j['from_node'] as String,
        to: j['to_node'] as String,
        mode: TransitMode.fromName(j['mode'] as String?) ?? TransitMode.walk,
        minutes: (j['minutes'] as num).toInt(),
        waitMinutes: (j['wait_minutes'] as num?)?.toInt() ?? 0,
        fareMin: (j['fare_min'] as num?)?.toInt() ?? 0,
        fareMax: (j['fare_max'] as num?)?.toInt() ?? 0,
        segmentIds: [
          for (final s in (j['segment_ids'] as List?) ?? const []) s as String
        ],
        nightOk: j['night_ok'] as bool? ?? true,
      );
}

class TransportGraph {
  TransportGraph({required List<GraphNode> nodes, required List<GraphEdge> edges})
      : nodes = {for (final n in nodes) n.id: n},
        _out = {} {
    for (final e in edges) {
      if (this.nodes.containsKey(e.from) && this.nodes.containsKey(e.to)) {
        (_out[e.from] ??= []).add(e);
      }
    }
  }

  final Map<String, GraphNode> nodes;
  final Map<String, List<GraphEdge>> _out;

  List<GraphEdge> edgesFrom(String id) => _out[id] ?? const [];

  factory TransportGraph.fromJson(Map<String, dynamic> j) => TransportGraph(
        nodes: [
          for (final n in (j['nodes'] as List? ?? const []))
            GraphNode.fromJson(Map<String, dynamic>.from(n as Map))
        ],
        edges: [
          for (final e in (j['edges'] as List? ?? const []))
            GraphEdge.fromJson(Map<String, dynamic>.from(e as Map))
        ],
      );

  bool get isEmpty => nodes.isEmpty;
}

/// Distancia en línea recta, en km.
double haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}
