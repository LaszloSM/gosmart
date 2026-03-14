// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = GoSmartSupabase.client;

  /// Sign up with email + password
  /// The handle_new_user trigger creates profile + card automatically
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required bool consentGeo,
    required bool consentAi,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'consent_geo': consentGeo,
        'consent_ai_data': consentAi,  // must match profiles.consent_ai_data column
      },
    );
    return response;
  }

  /// Sign in with email + password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Verify phone OTP
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Delete account and all data (Ley 1581 — right to erasure)
  /// Calls the delete-account Edge Function which uses service_role to
  /// call supabase.auth.admin.deleteUser() — cascades to all user data.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account', body: {});
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
}

final authService = AuthService();
