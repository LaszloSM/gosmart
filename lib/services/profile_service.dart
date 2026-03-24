import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Updates profile fields on the profiles table.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? cedula,
    String? city,
    String? birthDate,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (phone != null) {
      updates['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (cedula != null) {
      updates['cedula'] = cedula.trim().isEmpty ? null : cedula.trim();
    }
    if (city != null) {
      updates['city'] = city.trim().isEmpty ? null : city.trim();
    }
    if (birthDate != null) {
      updates['birth_date'] = birthDate;
    }
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  /// Uploads a photo to the "avatars" Supabase Storage bucket and returns
  /// the public URL, or null on failure.
  Future<String?> uploadAvatar(String userId, String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await GoSmartSupabase.client.storage
          .from('avatars')
          .uploadBinary(
            '$userId/avatar.jpg',
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final url = GoSmartSupabase.client.storage
          .from('avatars')
          .getPublicUrl('$userId/avatar.jpg');

      return url;
    } catch (e) {
      debugPrint('[ProfileService] uploadAvatar error: $e');
      return null;
    }
  }

  /// Changes the authenticated user's password via Supabase Auth.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

/// Singleton instance used across the app.
final profileService = ProfileService();
