// lib/planner/planner.dart
// Planificador puerta a puerta (Fase 5, D6): Dijkstra sobre el grafo de la
// región, en el celular. Origen y destino cualquiera se "enganchan" a los
// puntos cercanos a pie o en mototaxi/taxi. El costo pondera tiempo, plata,
// transbordos y el estado de la vía: un tramo cerrado no se usa, uno en
// precaución suma tiempo. De noche se descartan los servicios que no operan.
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';

import '../models/corridor_status.dart' show RoadState;
import 'fares.dart';
import 'graph.dart';

class PlanRequest {
  const PlanRequest({
    required this.origin,
    required this.destination,
    required this.at,
    this.allowed = const {
      TransitMode.walk,
      TransitMode.mototaxi,
      TransitMode.taxi,
      TransitMode.colectivo,
      TransitMode.transpadilla,
      TransitMode.intermunicipal,
    },
    this.roadStates = const {},
    this.originName = 'Tu ubicación',
    this.destinationName = 'Tu destino',
  });

  final LatLng origin;
  final LatLng destination;
  final DateTime at;
  final Set<TransitMode> allowed;

  /// Estado por `road_segments.id` (de `road_status`).
  final Map<String, RoadState> roadStates;
  final String originName;
  final String destinationName;
}

class PlannedLeg {
  const PlannedLeg({
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.from,
    required this.to,
    required this.minutes,
    required this.waitMinutes,
    required this.fare,
    required this.distanceKm,
    this.segmentIds = const [],
  });

  final TransitMode mode;
  final String fromName;
  final String toName;
  final LatLng from;
  final LatLng to;
  final int minutes;
  final int waitMinutes;
  final FareRange fare;
  final double distanceKm;
  final List<String> segmentIds;

  String get instruction => switch (mode) {
        TransitMode.walk => 'Camina hasta $toName',
        TransitMode.mototaxi => 'Toma un mototaxi hasta $toName',
        TransitMode.taxi => 'Toma un taxi hasta $toName',
        TransitMode.colectivo => 'Colectivo en $fromName hasta $toName',
        TransitMode.transpadilla => 'TransPadilla en $fromName hasta $toName',
        TransitMode.intermunicipal => 'Bus intermunicipal en $fromName hasta $toName',
      };
}

class PlannedTrip {
  const PlannedTrip({
    required this.legs,
    this.warnings = const [],
    this.usesDetour = false,
  });

  final List<PlannedLeg> legs;

  /// Tramos en precaución que cruza ("Retén · Cuatro Vías").
  final List<String> warnings;

  /// true si evita un cierre por el desvío Albania–Cuestecitas.
  final bool usesDetour;

  int get minutes =>
      legs.fold(0, (s, l) => s + l.minutes + l.waitMinutes);
  FareRange get fare => legs.fold(FareRange.zero, (s, l) => s + l.fare);
  double get distanceKm => legs.fold(0.0, (s, l) => s + l.distanceKm);

  /// Modo principal: el tramo más largo que no es a pie.
  TransitMode get mainMode =>
      legs
          .where((l) => l.mode != TransitMode.walk)
          .sorted((a, b) => b.distanceKm.compareTo(a.distanceKm))
          .firstOrNull
          ?.mode ??
      TransitMode.walk;

  String get signature => legs.map((l) => '${l.mode.name}:${l.toName}').join('>');
}

/// Cómo pesa cada cosa. "Rápido" valora más el tiempo; "barato", la plata.
class PlanWeights {
  const PlanWeights({
    this.copPerMinute = 100,
    this.transferMinutes = 5,
    this.cautionMinutes = 15,
  });
  final double copPerMinute;
  final int transferMinutes;
  final int cautionMinutes;

  static const fastest = PlanWeights(copPerMinute: 400);
  static const balanced = PlanWeights();
  static const cheapest = PlanWeights(copPerMinute: 25);
}

class TripPlanner {
  TripPlanner(this.graph, {this.fareRules = defaultFareRules});

  final TransportGraph graph;
  final Map<TransitMode, FareRule> fareRules;

  // Enganche: a pie hasta 1,2 km; en mototaxi/taxi hasta 12 km.
  static const walkKmMax = 1.2;
  static const rideKmMax = 12.0;
  static const walkKmh = 4.5;
  static const rideKmh = 22.0;

  /// La calle no es línea recta: factor de rodeo típico urbano.
  static const detour = 1.3;

  static const _origin = '__origin__';
  static const _dest = '__dest__';

  /// Hasta [max] alternativas distintas (rápida, equilibrada, barata).
  List<PlannedTrip> plan(PlanRequest req, {int max = 3}) {
    final out = <PlannedTrip>[];
    for (final w in const [PlanWeights.balanced, PlanWeights.fastest, PlanWeights.cheapest]) {
      final t = _best(req, w);
      if (t != null && !out.any((o) => o.signature == t.signature)) out.add(t);
      if (out.length >= max) break;
    }
    out.sort((a, b) => a.minutes.compareTo(b.minutes));
    return out;
  }

  PlannedTrip? _best(PlanRequest req, PlanWeights w) {
    final night = isNight(req.at);
    final nodes = <String, GraphNode>{
      ...graph.nodes,
      _origin: GraphNode(id: _origin, name: req.originName, at: req.origin),
      _dest: GraphNode(id: _dest, name: req.destinationName, at: req.destination),
    };

    // Aristas virtuales de enganche (origen → puntos, puntos → destino, directo).
    List<GraphEdge> access(String id) {
      final p = nodes[id]!.at;
      final res = <GraphEdge>[];
      void link(String to, LatLng q) {
        final km = haversineKm(p, q) * detour;
        if (km <= walkKmMax && req.allowed.contains(TransitMode.walk)) {
          res.add(GraphEdge(
              from: id, to: to, mode: TransitMode.walk,
              minutes: (km / walkKmh * 60).ceil(), fareMin: 0, fareMax: 0));
        }
        if (km > 0.6 && km <= rideKmMax) {
          for (final m in const [TransitMode.mototaxi, TransitMode.taxi]) {
            if (!req.allowed.contains(m)) continue;
            final f = estimateFare(m, km, at: req.at, rules: fareRules);
            res.add(GraphEdge(
                from: id, to: to, mode: m,
                minutes: (km / rideKmh * 60).ceil(),
                waitMinutes: m == TransitMode.mototaxi ? 3 : 6,
                fareMin: f.min, fareMax: f.max));
          }
        }
      }

      if (id == _origin) {
        for (final n in graph.nodes.values) {
          link(n.id, n.at);
        }
        link(_dest, req.destination);
      } else if (id != _dest) {
        link(_dest, req.destination);
      }
      return res;
    }

    double cost(GraphEdge e, TransitMode? prev) {
      final fareMid = (e.fareMin + e.fareMax) / 2;
      var c = e.minutes + e.waitMinutes + fareMid / w.copPerMinute;
      if (prev != null && prev != e.mode && e.mode != TransitMode.walk &&
          prev != TransitMode.walk) {
        c += w.transferMinutes;
      }
      for (final s in e.segmentIds) {
        if (req.roadStates[s] == RoadState.caution) c += w.cautionMinutes;
      }
      return c;
    }

    bool usable(GraphEdge e) {
      if (!req.allowed.contains(e.mode)) return false;
      if (night && !e.nightOk) return false;
      return !e.segmentIds.any((s) => req.roadStates[s] == RoadState.closed);
    }

    // Dijkstra sobre (nodo, modo con que se llegó): así se cobra el transbordo.
    final dist = <String, double>{};
    final prevOf = <String, (String, GraphEdge)>{};
    String key(String n, TransitMode? m) => '$n|${m?.name ?? ''}';
    final queue = PriorityQueue<(double, String, TransitMode?)>(
        (a, b) => a.$1.compareTo(b.$1));
    dist[key(_origin, null)] = 0;
    queue.add((0, _origin, null));
    String? goal;

    while (queue.isNotEmpty) {
      final (d, n, m) = queue.removeFirst();
      final k = key(n, m);
      if (d > (dist[k] ?? double.infinity)) continue;
      if (n == _dest) {
        goal = k;
        break;
      }
      final edges = [
        ...access(n),
        if (n != _origin && n != _dest) ...graph.edgesFrom(n).where(usable),
      ];
      for (final e in edges) {
        // No encadenar dos tramos a pie ni dos "puerta a puerta" seguidos.
        if (m == TransitMode.walk && e.mode == TransitMode.walk) continue;
        if (m != null && m.isOnDemand && e.mode.isOnDemand) continue;
        final nd = d + cost(e, m);
        final nk = key(e.to, e.mode);
        if (nd < (dist[nk] ?? double.infinity)) {
          dist[nk] = nd;
          prevOf[nk] = (k, e);
          queue.add((nd, e.to, e.mode));
        }
      }
    }
    if (goal == null) return null;

    // Reconstruir y unir tramos seguidos del mismo modo.
    final path = <GraphEdge>[];
    for (var k = goal; prevOf.containsKey(k); k = prevOf[k]!.$1) {
      path.add(prevOf[k]!.$2);
    }
    final edges = path.reversed.toList();
    final legs = <PlannedLeg>[];
    for (final e in edges) {
      final a = nodes[e.from]!, b = nodes[e.to]!;
      final km = haversineKm(a.at, b.at) * (e.mode == TransitMode.walk ? detour : 1.15);
      final last = legs.lastOrNull;
      if (last != null && last.mode == e.mode && !e.mode.isOnDemand) {
        legs[legs.length - 1] = PlannedLeg(
          mode: e.mode, fromName: last.fromName, toName: b.name,
          from: last.from, to: b.at,
          minutes: last.minutes + e.minutes, waitMinutes: last.waitMinutes,
          fare: last.fare + FareRange(e.fareMin, e.fareMax),
          distanceKm: last.distanceKm + km,
          segmentIds: [...last.segmentIds, ...e.segmentIds],
        );
      } else {
        legs.add(PlannedLeg(
          mode: e.mode, fromName: a.name, toName: b.name, from: a.at, to: b.at,
          minutes: e.minutes, waitMinutes: e.waitMinutes,
          fare: FareRange(e.fareMin, e.fareMax), distanceKm: km,
          segmentIds: e.segmentIds,
        ));
      }
    }

    final crossed = {for (final l in legs) ...l.segmentIds};
    return PlannedTrip(
      legs: legs,
      warnings: [
        for (final s in crossed)
          if (req.roadStates[s] == RoadState.caution) s,
      ],
      usesDetour: crossed.any((s) => s.startsWith('desvio')) &&
          req.roadStates.values.contains(RoadState.closed),
    );
  }
}
