import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel>> {
  ProfileNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await profileService.fetchProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates profile fields, then refreshes state.
  /// If the reload fails after a successful update, the previous state is
  /// preserved so the UI never shows a stale error banner.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? cedula,
    String? city,
    String? birthDate,
  }) async {
    final previous = state;
    try {
      await profileService.updateProfile(
        name: name,
        phone: phone,
        cedula: cedula,
        city: city,
        birthDate: birthDate,
      );
      await load();
    } catch (e, st) {
      // Restore previous data so the header never shows "Error"
      state = previous;
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Changes the user's password. Throws on failure so callers can show errors.
  Future<void> updatePassword(String newPassword) async {
    await profileService.updatePassword(newPassword);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel>>(
  (ref) => ProfileNotifier(),
);
