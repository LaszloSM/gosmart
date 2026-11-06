// lib/providers/dispatch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dispatch_models.dart';
import '../services/dispatch_service.dart';
import '../services/payment_service.dart';
import 'auth_provider.dart';

/// Viaje encadenado en curso o planeado; null si no hay (o es invitado).
final activeTripProvider = FutureProvider<ChainedTrip?>((ref) async {
  if (ref.watch(currentUserProvider) == null) return null;
  return dispatchService.activeTrip();
});

/// Interruptor del despacho (app_flags.dispatch_enabled).
final dispatchEnabledProvider =
    FutureProvider<bool>((ref) => dispatchService.dispatchEnabled());

/// Últimos viajes cerrados (para ver su recibo).
final recentTripsProvider = FutureProvider((ref) async {
  if (ref.watch(currentUserProvider) == null) {
    return const <RecentTrip>[];
  }
  return paymentService.recentTrips();
});

/// Conductor del tramo en curso (lo publica el panel del tramo al consultar):
/// el mapa del viaje lo pinta y lo desliza entre una consulta y otra.
final tripDriverProvider = StateProvider<AssignedDriver?>((ref) => null);
