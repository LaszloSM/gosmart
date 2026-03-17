// lib/models/route_result.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/design_tokens.dart';

/// A single segment of a route (e.g. the full walking polyline).
/// In Subsystem A, RouteResult always contains exactly one RouteLeg.
class RouteLeg {
  final String mode;        // 'walk' | 'bus' | 'bike'
  final List<LatLng> points; // polyline coords from Mapbox
  final Color color;
  final int durationMin;
  final double distanceKm;

  const RouteLeg({
    required this.mode,
    required this.points,
    required this.color,
    required this.durationMin,
    required this.distanceKm,
  });
}

/// The active route shown on the home map.
class RouteResult {
  final List<RouteLeg> legs; // always 1 leg in Subsystem A
  final double distanceKm;
  final int durationMin;
  final String profile; // 'walking' | 'driving' | 'cycling'

  const RouteResult({
    required this.legs,
    required this.distanceKm,
    required this.durationMin,
    required this.profile,
  });
}

/// Maps a Mapbox profile to a RouteLeg mode, color, and card label.
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
        driving => const Color(0xFFFF8C00), // orange
        cycling => GSColors.eco,            // green
        _ => GSColors.accent,              // teal
      };

  static IconData iconFor(String profile) => switch (profile) {
        driving => Icons.directions_bus_rounded,
        cycling => Icons.pedal_bike_rounded,
        _ => Icons.directions_walk_rounded,
      };

  static String labelFor(String profile) => switch (profile) {
        driving => 'En bus · más rápida',
        cycling => 'En bici · eco',
        _ => 'A pie · más barata',
      };
}
