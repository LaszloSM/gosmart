// lib/providers/dispatch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/dispatch_models.dart';
import '../models/trip_history.dart';
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

/// Los 3 viajes más recientes del historial completo (026), para la pestaña
/// Viaje sin viaje en curso. Vacío para invitados o sin señal.
final recentHistoryProvider = FutureProvider<List<HistoryItem>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  try {
    return await dispatchService.history(limit: 3);
  } catch (_) {
    return const [];
  }
});

/// Lugares de viajes anteriores (destinos y, si cambian, orígenes), del más
/// nuevo al más viejo, para "Recientes" en el planificador.
final recentPlacesProvider =
    FutureProvider<List<({String label, LatLng at})>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  try {
    final items = await dispatchService.history(limit: 10);
    return [
      for (final h in items)
        if (!h.asDriver && h.to != null && (h.destLabel ?? '').isNotEmpty)
          (label: h.destLabel!, at: h.to!),
    ];
  } catch (_) {
    return const [];
  }
});
