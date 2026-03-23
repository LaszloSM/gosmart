// lib/services/public_transport_service.dart
// Planificación de rutas de transporte público usando datos de colombia_kg (Supabase)
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../core/supabase_client.dart';
import '../models/route_result.dart';
import 'directions_service.dart';

class PublicTransportService {

  Future<RouteResult?> planRoute({
    required LatLng origin,
    required LatLng destination,
    required String mode, // 'Bus', 'Metro', 'BRT', 'Cable'
  }) async {
    try {
      // 1. Encontrar estaciones cercanas
      final nearOrigin = await _findNearestStation(origin, mode);
      final nearDest   = await _findNearestStation(destination, mode);

      // 2. Si no hay estaciones, fallback a caminata completa
      if (nearOrigin == null || nearDest == null) {
        debugPrint('[PublicTransportService] No stations found for $mode, falling back to walking');
        return await directionsService.getRoute(
          origin: origin,
          destination: destination,
          profile: 'walking',
        );
      }

      // 3. Si la estación origen y destino son la misma, fallback a caminata
      if (_haversineDistance(nearOrigin.latLng, nearDest.latLng) < 0.1) {
        return await directionsService.getRoute(
          origin: origin,
          destination: destination,
          profile: 'walking',
        );
      }

      // 4. Leg 1: Caminata usuario → estación origen
      final walkToStation = await directionsService.getRoute(
        origin: origin,
        destination: nearOrigin.latLng,
        profile: 'walking',
      );

      // 5. Leg de tránsito: estación → estación (línea recta aproximada)
      final transitDuration = _estimateTransitTime(nearOrigin.latLng, nearDest.latLng);
      final transitDistance = _haversineDistance(nearOrigin.latLng, nearDest.latLng);
      final transitProfile = _mapboxProfileFor(mode);
      final transitLeg = RouteLeg(
        mode: RouteProfile.modeFor(transitProfile),
        points: _straightLinePoints(nearOrigin.latLng, nearDest.latLng),
        color: RouteProfile.colorFor(transitProfile),
        durationMin: transitDuration,
        distanceKm: transitDistance,
        instruction: 'Toma ${_modeName(mode)} hasta ${nearDest.name}',
        lineId: mode,
      );

      // 6. Leg 2: Caminata estación destino → destino final
      final walkFromStation = await directionsService.getRoute(
        origin: nearDest.latLng,
        destination: destination,
        profile: 'walking',
      );

      // 7. Combinar todos los legs
      final allLegs = <RouteLeg>[
        if (walkToStation != null) ...walkToStation.legs,
        transitLeg,
        if (walkFromStation != null) ...walkFromStation.legs,
      ];

      final totalDuration = allLegs.fold(0, (s, l) => s + l.durationMin);
      final totalDistance = allLegs.fold(0.0, (s, l) => s + l.distanceKm);

      return RouteResult(
        legs: allLegs,
        distanceKm: totalDistance,
        durationMin: totalDuration,
        profile: transitProfile,
        estimatedCostCop: _publicFare(mode),
        category: 'public',
      );
    } catch (e) {
      debugPrint('[PublicTransportService] error: $e');
      return null;
    }
  }

  // Encuentra la estación más cercana a un punto usando colombia_kg.
  // El schema real de colombia_kg tiene columnas directas: lat, lon, type, canonical_name.
  // Los tipos válidos son: 'station', 'stop', 'terminal' (definidos en 006_colombia_kg.sql).
  Future<_KgStation?> _findNearestStation(LatLng point, String mode) async {
    try {
      final types = _typesFor(mode);

      // Consultar Supabase: estaciones del tipo indicado (límite 100)
      final results = await GoSmartSupabase.client
          .from('colombia_kg')
          .select('canonical_name, type, lat, lon')
          .inFilter('type', types)
          .limit(100);

      if (results.isEmpty) return null;

      // Encontrar la más cercana usando Haversine en Dart
      _KgStation? closest;
      double minDist = double.infinity;

      for (final row in results) {
        final lat = (row['lat'] as num?)?.toDouble();
        final lon = (row['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        // Validar que esté dentro de Colombia
        if (lat < -5 || lat > 14 || lon < -82 || lon > -66) continue;

        final stationLatLng = LatLng(lat, lon);
        final dist = _haversineDistance(point, stationLatLng);
        if (dist < minDist) {
          minDist = dist;
          closest = _KgStation(
            name: (row['canonical_name'] as String?) ?? 'Estación',
            latLng: stationLatLng,
            type: (row['type'] as String?) ?? mode,
          );
        }
      }

      // Solo retornar si la estación está a menos de 10km
      return (minDist < 10.0) ? closest : null;
    } catch (e) {
      debugPrint('[PublicTransportService] _findNearestStation error: $e');
      return null;
    }
  }

  // Mapeo de modo de transporte a tipos del schema colombia_kg.
  // Tipos válidos en 006_colombia_kg.sql: 'station', 'stop', 'terminal'.
  List<String> _typesFor(String mode) => switch (mode) {
    'Metro'  => ['station'],
    'Cable'  => ['station'],
    'BRT'    => ['station', 'terminal'],
    _        => ['stop', 'terminal'],  // Bus e Intermunicipal
  };

  String _mapboxProfileFor(String mode) => switch (mode) {
    'Bici'  => 'cycling',
    'A pie' => 'walking',
    _       => 'driving',
  };

  String _modeName(String mode) => switch (mode) {
    'Metro'         => 'el Metro',
    'Cable'         => 'el Metrocable',
    'BRT'           => 'el TransMilenio/BRT',
    'Intermunicipal'=> 'el bus intermunicipal',
    _               => 'el Bus',
  };

  int _publicFare(String mode) => switch (mode) {
    'Metro'          => 3400,
    'Cable'          => 0,    // integrado con Metro
    'BRT'            => 3000, // TransMilenio / MIO
    'Intermunicipal' => 15000,
    _                => 2800, // SITP / colectivo
  };

  // Haversine distance en km
  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLon = sin(dLon / 2);
    final x = sinLat * sinLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinLon * sinLon;
    return 2 * R * asin(sqrt(x));
  }

  double _toRad(double deg) => deg * pi / 180;

  // Tiempo estimado de tránsito (más rápido que a pie, menos que auto)
  int _estimateTransitTime(LatLng a, LatLng b) {
    final dist = _haversineDistance(a, b);
    // Velocidad promedio en ciudad: ~20 km/h + 5 min de espera
    return (dist / 20 * 60 + 5).round().clamp(3, 120);
  }

  // Puntos de línea recta para el leg de tránsito
  List<LatLng> _straightLinePoints(LatLng from, LatLng to) {
    const steps = 10;
    return List.generate(
      steps + 1,
      (i) => LatLng(
        from.latitude + (to.latitude - from.latitude) * i / steps,
        from.longitude + (to.longitude - from.longitude) * i / steps,
      ),
    );
  }
}

class _KgStation {
  final String name;
  final LatLng latLng;
  final String type;
  const _KgStation({required this.name, required this.latLng, required this.type});
}

final publicTransportService = PublicTransportService();
