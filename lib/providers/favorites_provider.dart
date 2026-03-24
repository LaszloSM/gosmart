// lib/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/favorite_place.dart';
import 'auth_provider.dart';

/// Todos los lugares favoritos del usuario, ordenados por uso
final favoritePlacesProvider = FutureProvider<List<FavoritePlace>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  try {
    final response = await GoSmartSupabase.client
        .from('favorite_places')
        .select()
        .eq('user_id', user.id)
        .order('use_count', ascending: false);

    return (response as List)
        .map((json) =>
            FavoritePlace.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Casa del usuario (null si no configurada)
final homePlaceProvider = Provider<FavoritePlace?>((ref) {
  final places = ref.watch(favoritePlacesProvider).valueOrNull ?? [];
  try {
    return places.firstWhere((p) => p.type == FavoritePlaceType.home);
  } catch (_) {
    return null;
  }
});

/// Trabajo del usuario (null si no configurado)
final workPlaceProvider = Provider<FavoritePlace?>((ref) {
  final places = ref.watch(favoritePlacesProvider).valueOrNull ?? [];
  try {
    return places.firstWhere((p) => p.type == FavoritePlaceType.work);
  } catch (_) {
    return null;
  }
});

/// Top 5 lugares más usados
final topFavoritePlacesProvider = Provider<List<FavoritePlace>>((ref) {
  final places = ref.watch(favoritePlacesProvider).valueOrNull ?? [];
  return places.take(5).toList();
});

/// Notifier para CRUD de favoritos
class FavoritesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Agrega o actualiza un lugar favorito
  Future<bool> addOrUpdatePlace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    FavoritePlaceType type = FavoritePlaceType.custom,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncLoading();

    try {
      if (type != FavoritePlaceType.custom) {
        // Para casa/trabajo: upsert por user_id (solo uno por tipo)
        final existing = await GoSmartSupabase.client
            .from('favorite_places')
            .select('id')
            .eq('user_id', user.id)
            .eq('type', type.name)
            .maybeSingle();

        if (existing != null) {
          await GoSmartSupabase.client
              .from('favorite_places')
              .update({
                'name': type == FavoritePlaceType.home ? 'Casa' : 'Trabajo',
                'address': address,
                'latitude': latitude,
                'longitude': longitude,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existing['id'] as String)
              .eq('user_id', user.id);
        } else {
          await GoSmartSupabase.client.from('favorite_places').insert({
            'user_id': user.id,
            'name': type == FavoritePlaceType.home ? 'Casa' : 'Trabajo',
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'type': type.name,
          });
        }
      } else {
        await GoSmartSupabase.client.from('favorite_places').insert({
          'user_id': user.id,
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'type': 'custom',
        });
      }

      ref.invalidate(favoritePlacesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  /// Elimina un lugar favorito
  Future<bool> removePlace(String placeId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncLoading();

    try {
      await GoSmartSupabase.client
          .from('favorite_places')
          .delete()
          .eq('id', placeId)
          .eq('user_id', user.id);

      ref.invalidate(favoritePlacesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  /// Incrementa el contador de uso (al navegar hacia ese lugar)
  Future<void> incrementUseCount(String placeId) async {
    try {
      await GoSmartSupabase.client.rpc('increment_favorite_use', params: {
        'p_favorite_id': placeId,
      });
      ref.invalidate(favoritePlacesProvider);
    } catch (_) {}
  }
}

final favoritesNotifierProvider =
    AsyncNotifierProvider<FavoritesNotifier, void>(
  FavoritesNotifier.new,
);
