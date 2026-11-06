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

/// Cuántos lugares con nombre se pueden guardar (además de Casa y Trabajo).
/// El servidor lo revalida (025_mvp_real.sql, trigger favorite_places_guard).
const kMaxSavedPlaces = 10;

/// Largo máximo del nombre de un lugar.
const kSavedPlaceNameMax = 40;

/// Lugares con nombre propio ("Donde mi mamá", "Gimnasio"), por uso.
final customPlacesProvider = Provider<List<FavoritePlace>>((ref) {
  final places = ref.watch(favoritePlacesProvider).valueOrNull ?? [];
  return [
    for (final p in places)
      if (p.type == FavoritePlaceType.custom) p
  ];
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

  /// Guarda un lugar con nombre. Con [id] lo actualiza (renombrar o
  /// cambiar la dirección). Devuelve null si salió bien, o el mensaje que
  /// hay que mostrar.
  Future<String?> saveNamedPlace({
    String? id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return 'Entra a tu cuenta para guardar lugares.';
    final clean = name.trim();
    if (clean.isEmpty) return 'Ponle un nombre al lugar.';
    if (clean.length > kSavedPlaceNameMax) {
      return 'El nombre puede tener hasta $kSavedPlaceNameMax letras.';
    }
    if (id == null && ref.read(customPlacesProvider).length >= kMaxSavedPlaces) {
      return 'Ya tienes $kMaxSavedPlaces lugares guardados. Borra uno para agregar otro.';
    }
    state = const AsyncLoading();
    try {
      final row = {
        'name': clean,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (id == null) {
        await GoSmartSupabase.client.from('favorite_places').insert({
          ...row,
          'user_id': user.id,
          'type': 'custom',
        });
      } else {
        await GoSmartSupabase.client
            .from('favorite_places')
            .update(row)
            .eq('id', id)
            .eq('user_id', user.id);
      }
      ref.invalidate(favoritePlacesProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      if (e.toString().contains('saved_places_limit')) {
        return 'Ya tienes $kMaxSavedPlaces lugares guardados. Borra uno para agregar otro.';
      }
      return 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
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
