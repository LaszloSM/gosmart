// lib/providers/driver_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_model.dart';
import '../services/driver_service.dart';
import 'auth_provider.dart';

/// Registro de conductor del usuario; null si nunca se registró.
final myDriverProvider = FutureProvider<DriverProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return driverService.fetchMine(user.id);
});
