// lib/providers/dispatch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dispatch_models.dart';
import '../services/dispatch_service.dart';
import 'auth_provider.dart';

/// Viaje encadenado en curso o planeado; null si no hay (o es invitado).
final activeTripProvider = FutureProvider<ChainedTrip?>((ref) async {
  if (ref.watch(currentUserProvider) == null) return null;
  return dispatchService.activeTrip();
});

/// Interruptor del despacho (app_flags.dispatch_enabled).
final dispatchEnabledProvider =
    FutureProvider<bool>((ref) => dispatchService.dispatchEnabled());
