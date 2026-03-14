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
