// lib/providers/wallet_provider.dart
//
// Billetera GoSmart en Supabase (tablas `wallets` y `wallet_transactions`).
// Es el único modelo de dinero de la app. El saldo solo cambia por RPC en el
// servidor (010_wallet_hardening.sql); RLS limita la lectura al usuario actual.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'auth_provider.dart';


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

/// true si se puede pagar con saldo: solo con Wompi encendido (recargas
/// reales). Apagado = solo efectivo (025_mvp_real.sql lo exige también en el
/// servidor). Sin red o con error: false (nunca se ofrece saldo de prueba).
final walletPaymentsProvider = FutureProvider<bool>((ref) async {
  try {
    final row = await GoSmartSupabase.client
        .from('app_flags')
        .select('enabled')
        .eq('key', 'wompi_enabled')
        .maybeSingle();
    return row?['enabled'] as bool? ?? false;
  } catch (_) {
    return false;
  }
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
  // La recarga simulada se quitó (025_mvp_real.sql): solo Wompi suma saldo,
  // por paymentService.wompiCheckout. Este notifier queda para el estado de
  // carga de la pantalla de la billetera.
}

final walletNotifierProvider =
    AsyncNotifierProvider<WalletNotifier, void>(WalletNotifier.new);
