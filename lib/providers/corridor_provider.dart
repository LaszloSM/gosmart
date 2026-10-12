// lib/providers/corridor_provider.dart
// Estado de la Troncal para la Línea del corredor del inicio.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/telemetry.dart';
import '../models/corridor_status.dart';
import '../services/corridor_service.dart';

/// Estado público por tramo (`road_status`). Sin señal: el último guardado
/// marcado como viejo ("Sin señal. Último dato hace…"); si nunca hubo, "Sin
/// datos". Nunca se inventa un estado.
final corridorStatusProvider = FutureProvider<CorridorStatus>((ref) async {
  try {
    return await corridorService.fetchStatus();
  } catch (e) {
    Telemetry.degraded('supabase', 'road_status');
    return await corridorService.cachedStatus() ??
        const CorridorStatus.noData();
  }
});

/// Tramos con su trazado, para ubicar un reporte por GPS.
final roadSegmentsProvider = FutureProvider<List<RoadSegmentGeo>>(
    (ref) => corridorService.fetchSegments());
