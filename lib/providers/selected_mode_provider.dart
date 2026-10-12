import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';

/// Modos de transporte locales de Riohacha, Maicao y la Troncal.
/// Se eligen en el planificador. Mototaxi por defecto: es el más usado.
const travelModes = [
  'Mototaxi',
  'Taxi',
  'Colectivo',
  'TransPadilla',
  'Intermunicipal',
  'A pie',
  'Carro',
];

final selectedModeProvider = StateProvider<String>((ref) => 'Mototaxi');

/// Modo → perfil de Mapbox Directions. Única fuente de este mapeo.
String routeProfileFor(String mode) => switch (mode) {
      'A pie' => RouteProfile.walking,
      _ => RouteProfile.driving, // mototaxi, taxi y carro van por la vía
    };

/// true si el modo se planea con PublicTransportService (paradas + tramos).
bool isPublicTransport(String mode) =>
    const {'Colectivo', 'TransPadilla', 'Intermunicipal'}.contains(mode);

IconData modeIconFor(String mode) => switch (mode) {
      'Mototaxi' => Icons.two_wheeler_rounded,
      'Taxi' => Icons.local_taxi_rounded,
      'Colectivo' => Icons.airport_shuttle_rounded,
      'TransPadilla' => Icons.directions_bus_rounded,
      'Intermunicipal' => Icons.directions_bus_filled_rounded,
      'A pie' => Icons.directions_walk_rounded,
      _ => Icons.directions_car_rounded,
    };
