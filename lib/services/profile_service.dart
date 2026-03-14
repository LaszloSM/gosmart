import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/profile_model.dart';

class ProfileService {
  final _client = GoSmartSupabase.client;

  /// Fetches the profile row for the currently authenticated user.
  Future<ProfileModel> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return ProfileModel.fromMap(data, email: user.email ?? '');
  }

  /// Updates name and/or phone on the profiles table.
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim().isEmpty ? null : phone.trim();

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  /// Changes the authenticated user's password via Supabase Auth.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

/// Singleton instance used across the app.
final profileService = ProfileService();
