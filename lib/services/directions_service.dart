// lib/services/directions_service.dart
// Ruta por calles con Google Routes API, a través de la Edge Function `maps`.
// Devuelve null ante cualquier error (sin clave, sin red, sin ruta).
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import 'geocoding_service.dart';

class DirectionsService {
  DirectionsService({MapsInvoke? invoke}) : _invoke = invoke ?? invokeMaps;
  final MapsInvoke _invoke;

  /// [profile]: RouteProfile.walking (a pie) o driving (mototaxi, taxi, carro).
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    try {
      final data = await _invoke({
        'action': 'route',
        'from': {'lat': origin.latitude, 'lng': origin.longitude},
        'to': {'lat': destination.latitude, 'lng': destination.longitude},
        'mode': profile == RouteProfile.walking ? 'walk' : 'drive',
      });
      final r = data['route'] as Map? ?? const {};
      final points = [
        for (final p in r['points'] as List? ?? const [])
          LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      if (points.length < 2) return null;

      final distanceKm = ((r['distance_m'] as num?) ?? 0).toDouble() / 1000;
      final durationMin = (((r['duration_s'] as num?) ?? 0) / 60).round();
      final leg = RouteLeg(
        mode: RouteProfile.modeFor(profile),
        points: points,
        color: RouteProfile.colorFor(profile),
        durationMin: durationMin,
        distanceKm: distanceKm,
      );
      return RouteResult(
        legs: [leg],
        distanceKm: distanceKm,
        durationMin: durationMin,
        profile: profile,
      );
    } catch (e) {
      debugPrint('[DirectionsService] error: $e');
      return null;
    }
  }
}

final directionsService = DirectionsService();
