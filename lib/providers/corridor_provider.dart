// lib/providers/corridor_provider.dart
// Estado de la Troncal para la Línea del corredor del inicio.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/corridor_status.dart';

/// Hoy no hay backend de reportes viales (llega en la Fase 4 con la vista
/// `road_status`, de lectura pública para el modo invitado). Hasta entonces
/// se devuelve [CorridorStatus.noData] para no mostrar un estado inventado.
final corridorStatusProvider = FutureProvider<CorridorStatus>((ref) async {
  return const CorridorStatus.noData();
});
