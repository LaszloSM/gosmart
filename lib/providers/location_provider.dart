// lib/providers/location_provider.dart
// FutureProvider — fires once, used for initial map center.
// Returns null if GPS is unavailable; callers fall back to Bogotá.
// For FAB re-center, call locationService.getCurrentPosition() directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

final locationProvider = FutureProvider<LatLng?>((ref) async {
  return locationService.getCurrentPosition();
});
