// lib/providers/transaction_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/transaction_model.dart';

const _pageSize = 20;

final transactionListProvider = StateNotifierProvider<
    TransactionListNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionListNotifier();
});

class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  TransactionListNotifier() : super(const AsyncLoading()) {
    load();
  }

  int _offset = 0;
  bool _hasMore = true;

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      state = const AsyncLoading();
    }

    try {
      // RLS policy on transactions already filters by user's cards — no join needed
      final data = await GoSmartSupabase.client
          .from('transactions')
          .select('*')
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final items = (data as List)
          .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
          .toList();

      _hasMore = items.length == _pageSize;
      _offset += items.length;

      final current = refresh ? <TransactionModel>[] :
          (state.valueOrNull ?? []);
      state = AsyncData([...current, ...items]);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    await load();
  }
}

/// Returns the total number of transactions for the current user.
/// Uses a COUNT query so it's accurate regardless of pagination.
final tripCountProvider = FutureProvider<int>((ref) async {
  return GoSmartSupabase.client
      .from('transactions')
      .count(CountOption.exact);
});
