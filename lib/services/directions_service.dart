// lib/services/directions_service.dart
// Calls Mapbox Directions API v5 to get real route polylines.
// Returns null on any error (empty token, network failure, non-200 response).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/env.dart';
import '../models/route_result.dart';

class DirectionsService {
  static const _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  /// Fetches a route from Mapbox Directions API.
  /// [profile]: 'walking' | 'driving' | 'cycling'
  /// Returns null if token is missing, network fails, or API returns non-200.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    final token = Env.mapboxToken;
    if (token.isEmpty) return null;

    // Mapbox expects coordinates as "lng,lat" (longitude first).
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';

    final uri = Uri.parse(
      '$_baseUrl/$profile/$coords'
      '?geometries=geojson&overview=full&access_token=$token',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[DirectionsService] ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords2 = geometry['coordinates'] as List;

      // Mapbox returns [lng, lat] — convert to LatLng(lat, lng).
      final points = coords2
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final distanceKm = ((route['distance'] as num).toDouble()) / 1000;
      final durationMin = ((route['duration'] as num).toDouble() / 60).round();

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
