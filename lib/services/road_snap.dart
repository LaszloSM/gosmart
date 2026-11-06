// lib/services/road_snap.dart
// Trazado por la vía: el planificador (colectivo, TransPadilla,
// intermunicipal) y el viaje encadenado conocen solo el inicio y el fin de
// cada tramo, y el mapa los pintaba en línea recta. Aquí cada tramo recto se
// cambia por el trazado calle a calle de Google Routes (Edge Function `maps`):
// a pie por andenes, lo demás por la vía. Si Google no responde, el tramo se
// queda recto (mejor una referencia que nada) y se reintenta la próxima vez.
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import 'directions_service.dart';

typedef LegRouter = Future<List<LatLng>?> Function(
    LatLng from, LatLng to, bool walking);

class RoadSnapper {
  RoadSnapper({LegRouter? route}) : _route = route ?? _google;
  final LegRouter _route;

  /// Trazados ya pedidos (la misma ruta no se paga dos veces).
  final _cache = <String, List<LatLng>>{};

  static Future<List<LatLng>?> _google(LatLng a, LatLng b, bool walking) async {
    final r = await directionsService.getRoute(
      origin: a,
      destination: b,
      profile: walking ? RouteProfile.walking : RouteProfile.driving,
    );
    final pts = r?.legs.firstOrNull?.points;
    return pts == null || pts.length < 2 ? null : pts;
  }

  static String _key(LatLng a, LatLng b, bool w) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}>'
      '${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}|$w';

  /// El tramo por la vía, o el mismo tramo si ya trae trazado o falla.
  Future<RouteLeg> snapLeg(RouteLeg leg) async {
    if (leg.points.length != 2) return leg; // ya viene calle a calle
    final a = leg.points.first, b = leg.points.last;
    // Puntos casi iguales: nada que trazar.
    if (const Distance().as(LengthUnit.Meter, a, b) < 30) return leg;
    final walking = (leg.transitMode ?? leg.mode) == 'walk';
    final key = _key(a, b, walking);
    final cached = _cache[key];
    if (cached != null) return leg.withPoints(cached);
    try {
      final pts =
          await _route(a, b, walking).timeout(const Duration(seconds: 10));
      if (pts == null) return leg;
      // Que el dibujo empiece y termine justo en los puntos del tramo.
      final full = [a, ...pts, b];
      _cache[key] = full;
      return leg.withPoints(full);
    } catch (_) {
      return leg;
    }
  }

  /// Todos los tramos a la vez.
  Future<RouteResult> snap(RouteResult route) async {
    if (route.legs.every((l) => l.points.length != 2)) return route;
    final legs = await Future.wait(route.legs.map(snapLeg));
    return route.withLegs(legs);
  }
}

final roadSnapper = RoadSnapper();
