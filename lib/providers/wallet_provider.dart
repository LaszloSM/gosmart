// lib/providers/wallet_provider.dart
//
// Billetera GoSmart en Supabase (tablas `wallets` y `wallet_transactions`).
// Es el único modelo de dinero de la app. El saldo solo cambia por RPC en el
// servidor (010_wallet_hardening.sql); RLS limita la lectura al usuario actual.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/supabase_client.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'auth_provider.dart';

const _uuid = Uuid();

/// Billetera del usuario actual (null sin sesión o si aún no existe).
final walletProvider = FutureProvider<Wallet?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final row = await GoSmartSupabase.client
      .from('wallets')
      .select('id, user_id, balance, card_number, card_status, created_at, updated_at')
      .maybeSingle();
  return row == null ? null : Wallet.fromJson(row);
});

/// Saldo actual (0 si no disponible).
final walletBalanceProvider = Provider<int>((ref) {
  return ref.watch(walletProvider).valueOrNull?.balance ?? 0;
});

/// Últimos movimientos de la billetera, más recientes primero.
final walletTransactionsProvider =
    FutureProvider.family<List<WalletTransactionModel>, int>(
  (ref, limit) async {
    final wallet = await ref.watch(walletProvider.future);
    if (wallet == null) return [];

    final rows = await GoSmartSupabase.client
        .from('wallet_transactions')
        .select('id, wallet_id, type, amount, description, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(WalletTransactionModel.fromJson).toList();
  },
);

class WalletNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Recarga simulada hasta que llegue Wompi (Fase 7).
  /// Un `idempotency_key` por intento: si la red reintenta, no se suma dos veces.
  Future<bool> recharge(int amount) async {
    if (ref.read(currentUserProvider) == null) return false;

    state = const AsyncLoading();
    try {
      await GoSmartSupabase.client.rpc('wallet_recharge_simulated', params: {
        'p_amount': amount,
        'p_idempotency_key': _uuid.v4(),
      });
      ref.invalidate(walletProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      debugPrint('[WalletNotifier] recharge failed: $e');
      state = AsyncError(e, st);
      return false;
    }
  }
}

final walletNotifierProvider =
    AsyncNotifierProvider<WalletNotifier, void>(WalletNotifier.new);
