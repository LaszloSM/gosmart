// lib/providers/active_route_provider.dart
// Holds the route currently drawn on the home map.
// Set by route_planner_screen when user selects a route.
// Reset to null when user closes the route banner.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_result.dart';

final activeRouteProvider = StateProvider<RouteResult?>((ref) => null);

/// Destino seleccionado por long-press en el mapa (para pasar al route planner)
final pendingDestinationProvider = StateProvider<LatLng?>((ref) => null);
