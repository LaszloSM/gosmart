// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

/// Current auth session — null when logged out
final authSessionProvider = StreamProvider<Session?>((ref) {
  return GoSmartSupabase.client.auth.onAuthStateChange.map((e) => e.session);
});

/// Current user — null when logged out
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider).value?.user;
});

/// Modo invitado (DS3): sin sesión se puede ver el corredor y planear;
/// la cuenta se pide al reportar, pedir mototaxi, reservar o pagar.
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) == null;
});
