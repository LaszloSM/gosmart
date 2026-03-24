// lib/providers/wallet_mock_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'auth_provider.dart';

/// Wallet simulado del usuario actual. Devuelve null si no existe la tabla.
final walletMockProvider = FutureProvider<WalletMock?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final response = await GoSmartSupabase.client
        .from('wallets')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return WalletMock.fromJson(response as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Saldo actual del wallet (0 si no disponible)
final walletMockBalanceProvider = Provider<int>((ref) {
  return ref.watch(walletMockProvider).valueOrNull?.balance ?? 0;
});

/// Historial de transacciones del wallet mock (paginado)
final walletMockTransactionsProvider =
    FutureProvider.family<List<WalletTransactionModel>, int>(
  (ref, limit) async {
    final wallet = ref.watch(walletMockProvider).valueOrNull;
    if (wallet == null) return [];

    try {
      final response = await GoSmartSupabase.client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', wallet.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) =>
              WalletTransactionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// Notifier para acciones del wallet mock
class WalletMockNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Recarga el saldo (mock — sin cobro real)
  Future<bool> recharge(int amount, {String? description}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncLoading();

    try {
      await GoSmartSupabase.client.rpc('recharge_wallet', params: {
        'p_user_id': user.id,
        'p_amount': amount,
        'p_description': description ?? 'Recarga de saldo',
      });

      ref.invalidate(walletMockProvider);
      ref.invalidate(walletMockTransactionsProvider(20));

      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  bool hasSufficientBalance(int amount) {
    return ref.read(walletMockBalanceProvider) >= amount;
  }
}

final walletMockNotifierProvider =
    AsyncNotifierProvider<WalletMockNotifier, void>(
  WalletMockNotifier.new,
);
