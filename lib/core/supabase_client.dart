// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Single access point for the Supabase client.
/// Call [GoSmartSupabase.initialize] once in main().
class GoSmartSupabase {
  GoSmartSupabase._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  /// The global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
