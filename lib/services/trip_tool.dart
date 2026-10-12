// lib/services/trip_tool.dart
// La herramienta `plan_trip` del asistente corre aquí, en el celular (D6):
// resuelve los lugares, planea sobre el grafo guardado con el estado de la
// vía y le devuelve a la IA un resumen corto (la IA no inventa cifras).
import 'package:latlong2/latlong.dart';

import '../models/corridor_status.dart';
import '../models/route_result.dart';
import '../planner/graph.dart';
import '../planner/planner.dart';
import '../planner/to_route.dart';
import 'corridor_service.dart';
import 'graph_service.dart';
import 'location_service.dart';
import 'place_search.dart';

class TripToolOutcome {
  const TripToolOutcome(this.result, [this.routes = const []]);

  /// Lo que se le manda a la IA (JSON).
  final Map<String, dynamic> result;

  /// Rutas para "Ver en el mapa".
  final List<RouteResult> routes;
}

typedef PlaceResolver = Future<({String name, LatLng at})?> Function(
    String query, LatLng? near);

const _modeArg = {
  'mototaxi': TransitMode.mototaxi,
  'taxi': TransitMode.taxi,
  'colectivo': TransitMode.colectivo,
  'transpadilla': TransitMode.transpadilla,
  'intermunicipal': TransitMode.intermunicipal,
  'a_pie': TransitMode.walk,
};

/// "mi ubicación", "aquí", vacío → usar el GPS.
bool isHere(String? s) {
  final t = (s ?? '').trim().toLowerCase();
  return t.isEmpty ||
      const {'aqui', 'aquí', 'mi ubicacion', 'mi ubicación', 'donde estoy', 'acá', 'aca'}
          .contains(t);
}

/// Resumen para el modelo: pocas cifras, todas del planificador.
Map<String, dynamic> summarizeTrips(List<PlannedTrip> trips, {
  required String from,
  required String to,
  Map<String, String> segmentNames = const {},
}) {
  if (trips.isEmpty) return {'error': 'sin_ruta', 'desde': from, 'hasta': to};
  return {
    'desde': from,
    'hasta': to,
    'opciones': [
      for (final t in trips)
        {
          'modo_principal': t.mainMode.label,
          'minutos': t.minutes,
          'tarifa_referencia': t.fare.max == 0
              ? 'sin costo'
              : '${t.fare.min}-${t.fare.max} COP',
          'tramos': [
            for (final l in t.legs)
              '${l.mode.label} hasta ${l.toName} (${l.minutes + l.waitMinutes} min)'
          ],
          if (t.usesDetour) 'desvio': 'Evita el cierre por Albania–Cuestecitas',
          if (t.warnings.isNotEmpty)
            'precaucion': [for (final w in t.warnings) segmentNames[w] ?? w],
        }
    ],
  };
}

class TripTool {
  TripTool({
    PlaceResolver? resolvePlace,
    Future<LatLng?> Function()? locate,
    Future<GraphBundle> Function()? loadGraph,
    Future<CorridorStatus> Function()? loadCorridor,
    DateTime Function()? now,
  })  : _resolve = resolvePlace ?? _defaultResolve,
        _locate = locate ?? locationService.getCurrentPosition,
        _loadGraph = loadGraph ?? graphService.load,
        _loadCorridor = loadCorridor ?? _defaultCorridor,
        _now = now ?? DateTime.now;

  final PlaceResolver _resolve;
  final Future<LatLng?> Function() _locate;
  final Future<GraphBundle> Function() _loadGraph;
  final Future<CorridorStatus> Function() _loadCorridor;
  final DateTime Function() _now;

  static Future<({String name, LatLng at})?> _defaultResolve(
      String q, LatLng? near) async {
    final r = await placeSearch.search(q, near: near);
    if (r.items.isEmpty) return null;
    return (name: r.items.first.placeName, at: r.items.first.latLng);
  }

  static Future<CorridorStatus> _defaultCorridor() async {
    try {
      return await corridorService.fetchStatus();
    } catch (_) {
      return await corridorService.cachedStatus() ??
          const CorridorStatus.noData();
    }
  }

  Future<TripToolOutcome> run(Map<String, dynamic> args) async {
    final here = await _locate();
    final originArg = args['origin'] as String?;
    final destArg = (args['destination'] as String? ?? '').trim();
    if (destArg.isEmpty) {
      return const TripToolOutcome({'error': 'falta_destino'});
    }

    ({String name, LatLng at})? origin;
    if (isHere(originArg)) {
      if (here == null) return const TripToolOutcome({'error': 'sin_ubicacion'});
      origin = (name: 'Tu ubicación', at: here);
    } else {
      origin = await _resolve(originArg!, here);
      if (origin == null) {
        return TripToolOutcome({'error': 'origen_no_encontrado', 'origen': originArg});
      }
    }
    final dest = await _resolve(destArg, origin.at);
    if (dest == null) {
      return TripToolOutcome({'error': 'destino_no_encontrado', 'destino': destArg});
    }

    final GraphBundle bundle;
    try {
      bundle = await _loadGraph();
    } catch (_) {
      return const TripToolOutcome({'error': 'sin_grafo'});
    }
    final corridor = await _loadCorridor();
    final mode = _modeArg[args['mode']];
    final planner = TripPlanner(bundle.graph, fareRules: bundle.fareRules);
    List<PlannedTrip> planWith(Set<TransitMode> allowed) => planner.plan(
          PlanRequest(
            origin: origin!.at,
            destination: dest.at,
            at: _now(),
            allowed: allowed,
            roadStates: {
              for (final s in corridor.segments)
                if (s.id != null) s.id!: s.state,
            },
            originName: origin.name,
            destinationName: dest.name,
          ),
        );
    var trips = planWith(mode == null
        ? allTransitModes
        : {TransitMode.walk, TransitMode.mototaxi, mode});
    String? note;
    if (trips.isEmpty && mode != null) {
      // Solo con ese modo no se llega: se combinan modos y se dice.
      trips = planWith(allTransitModes);
      if (trips.isNotEmpty) note = 'Solo en ${mode.label} no se llega; se combinan modos.';
    }
    return TripToolOutcome(
      {
        ...summarizeTrips(trips, from: origin.name, to: dest.name, segmentNames: {
          for (final s in corridor.segments)
            if (s.id != null && s.name != null) s.id!: s.name!,
        }),
        if (note != null) 'nota': note,
      },
      [
        for (final t in trips)
          routeFromTrip(t, corridor: corridor).withDestination(dest.name)
      ],
    );
  }
}
