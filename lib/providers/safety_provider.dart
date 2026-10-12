// lib/providers/safety_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_contact.dart';
import '../services/location_service.dart';
import '../services/safety_service.dart';
import 'auth_provider.dart';

/// Contactos de emergencia del usuario. Vacío para invitados.
final emergencyContactsProvider =
    FutureProvider<List<EmergencyContact>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return safetyService.listContacts();
});

/// Viaje compartido en curso (null si no se está compartiendo).
/// Mientras la app está abierta, sube la posición cada minuto.
class TripShareNotifier extends StateNotifier<TripShare?> {
  TripShareNotifier() : super(null);

  Timer? _timer;
  static const _interval = Duration(minutes: 1);

  Future<TripShare> start({
    required String destination,
    String? mode,
  }) async {
    final at = await locationService.getCurrentPosition();
    final share = await safetyService.startShare(
        destination: destination, mode: mode, at: at);
    state = share;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _push());
    return share;
  }

  Future<void> _push() async {
    final s = state;
    if (s == null) return;
    if (!s.isActive) return _clear();
    final at = await locationService.getCurrentPosition();
    if (at == null) return;
    try {
      final ok = await safetyService.updateShare(s.token, at);
      // false = el servidor ya lo dio por terminado (expiró o se detuvo).
      if (!ok) _clear();
    } catch (_) {
      // Sin señal: se reintenta en el siguiente minuto.
    }
  }

  Future<void> stop() async {
    final s = state;
    _clear();
    if (s != null) await safetyService.stopShare(s.token);
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final tripShareProvider =
    StateNotifierProvider<TripShareNotifier, TripShare?>(
        (ref) => TripShareNotifier());
