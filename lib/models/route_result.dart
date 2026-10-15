// lib/models/route_result.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/design_tokens.dart';

/// A single segment of a route (e.g. the full walking polyline).
/// In Subsystem A, RouteResult always contains exactly one RouteLeg.
class RouteLeg {
  final String mode;        // 'walk' | 'bus' | 'bike'
  final List<LatLng> points; // polyline coords from Google Routes
  final Color color;
  final int durationMin;
  final double distanceKm;
  final String? instruction; // e.g. "Toma el Metro Línea A hasta Industriales"
  final String? lineId;      // e.g. "Ruta 1", "TransPadilla"

  /// Del planificador: modo ('mototaxi', 'colectivo'…), lugares, puntos del
  /// grafo y tarifa. Sirven para crear el viaje encadenado (Fase 6).
  final String? transitMode;
  final String? fromLabel;
  final String? toLabel;
  final String? fromNode;
  final String? toNode;
  final int fareMin;
  final int fareMax;

  /// Color del modo con la paleta ACTIVA (día o noche). Usar este y no
  /// [color], que se fija al crear la ruta y de noche queda oscuro.
  Color get liveColor => switch (transitMode ?? mode) {
        'walk' => GSColors.walk,
        'mototaxi' || 'taxi' => GSColors.taxi,
        'bike' => GSColors.bike,
        'car' => GSColors.car,
        _ => GSColors.bus,
      };

  /// Ícono o texto encima de [liveColor].
  Color get onLiveColor => GSColors.isDark ? GSColors.background : GSColors.onBrand;

  const RouteLeg({
    required this.mode,
    required this.points,
    required this.color,
    required this.durationMin,
    required this.distanceKm,
    this.instruction,
    this.lineId,
    this.transitMode,
    this.fromLabel,
    this.toLabel,
    this.fromNode,
    this.toNode,
    this.fareMin = 0,
    this.fareMax = 0,
  });
}

/// The active route shown on the home map.
class RouteResult {
  final List<RouteLeg> legs; // always 1 leg in Subsystem A
  final double distanceKm;
  final int durationMin;
  final String profile; // 'walking' | 'driving' | 'cycling'
  final int estimatedCostCop;  // estimated cost in Colombian pesos
  final String category;       // 'private' or 'public'
  /// Nombre del destino tal como lo eligió el usuario (para compartir el viaje).
  final String? destinationLabel;

  /// Rango de tarifa de referencia (planificador). null = sin rango.
  final int? fareMin;
  final int? fareMax;

  /// Avisos del planificador: desvío por bloqueo, tramos en precaución.
  final List<String> notes;

  const RouteResult({
    required this.legs,
    required this.distanceKm,
    required this.durationMin,
    required this.profile,
    this.estimatedCostCop = 0,
    this.category = 'private',
    this.destinationLabel,
    this.fareMin,
    this.fareMax,
    this.notes = const [],
  });

  RouteResult withDestination(String? label) => RouteResult(
        legs: legs,
        distanceKm: distanceKm,
        durationMin: durationMin,
        profile: profile,
        estimatedCostCop: estimatedCostCop,
        category: category,
        destinationLabel: label,
        fareMin: fareMin,
        fareMax: fareMax,
        notes: notes,
      );
}

/// Maps a route profile to a RouteLeg mode, color, and card label.
/// Single source of truth — do not duplicate this mapping elsewhere.
class RouteProfile {
  static const walking = 'walking';
  static const driving = 'driving';
  static const cycling = 'cycling';

  static String modeFor(String profile) => switch (profile) {
        driving => 'bus',
        cycling => 'bike',
        _ => 'walk',
      };

  static Color colorFor(String profile) => switch (profile) {
        driving => GSColors.bus,
        cycling => GSColors.bike,
        _ => GSColors.walk,
      };

  static IconData iconFor(String profile) => switch (profile) {
        driving => Icons.directions_bus_rounded,
        cycling => Icons.pedal_bike_rounded,
        _ => Icons.directions_walk_rounded,
      };

  static String labelFor(String profile) => switch (profile) {
        driving => 'Por la vía',
        cycling => 'En bici',
        _ => 'A pie · más barata',
      };
}
