// lib/providers/card_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/card_model.dart';

/// The active card for the current user.
/// Refreshes automatically via Supabase Realtime.
final activeCardProvider =
    StateNotifierProvider<ActiveCardNotifier, AsyncValue<CardModel?>>((ref) {
  return ActiveCardNotifier();
});

class ActiveCardNotifier extends StateNotifier<AsyncValue<CardModel?>> {
  ActiveCardNotifier() : super(const AsyncLoading()) {
    load();
    subscribeRealtime();
  }

  RealtimeChannel? _channel;

  // Non-private so subclasses in tests can override without Dart's
  // library-privacy restriction blocking the @override.
  Future<void> load() async {
    try {
      final data = await GoSmartSupabase.client
          .from('cards')
          .select()
          .neq('status', 'cancelled')
          .order('created_at')
          .limit(1)
          .maybeSingle();

      state = AsyncData(data != null ? CardModel.fromMap(data) : null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void subscribeRealtime() {
    final userId = GoSmartSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = GoSmartSupabase.client
        .channel('public:cards:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              state = AsyncData(CardModel.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  Future<void> refresh() => load();

  Future<void> toggleLock(String cardId, bool locked) async {
    final newStatus = locked ? 'locked' : 'active';
    await GoSmartSupabase.client
        .from('cards')
        .update({'status': newStatus})
        .eq('id', cardId);
    await load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
