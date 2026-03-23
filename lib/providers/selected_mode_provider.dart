import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';

/// Currently selected travel mode from the home screen mode chips.
/// Values: 'Auto' | 'Taxi' | 'Bus' | 'Bici' | 'Metro'
final selectedModeProvider = StateProvider<String>((ref) => 'Auto');

/// Maps a home-screen travel mode to a Mapbox Directions profile.
/// Single source of truth — do not duplicate this mapping elsewhere.
String routeProfileFor(String mode) => switch (mode) {
      'Bici'  => RouteProfile.cycling,
      'A pie' => RouteProfile.walking,
      _ => RouteProfile.driving, // Auto, Taxi, Bus, Metro all use driving
    };

/// Returns true if the mode requires PublicTransportService (not Mapbox Directions directly).
bool isPublicTransport(String mode) =>
    const {'Bus', 'Metro', 'BRT', 'Cable', 'Intermunicipal'}.contains(mode);

/// Returns the icon for a given travel mode label.
IconData modeIconFor(String mode) => switch (mode) {
      'Taxi' => Icons.local_taxi_rounded,
      'Bus' => Icons.directions_bus_rounded,
      'Bici' => Icons.pedal_bike_rounded,
      'Metro' => Icons.subway_rounded,
      _ => Icons.directions_car_rounded,
    };
