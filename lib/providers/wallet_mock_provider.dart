// lib/providers/wallet_mock_provider.dart
//
// Wallet simulado 100% local (SharedPreferences).
// No requiere migración de Supabase — funciona inmediatamente para el demo.
// Los datos persisten entre reinicios de la app.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'auth_provider.dart';

// ─── Keys de SharedPreferences ────────────────────────────────────────────────

String _balanceKey(String uid) => 'wallet_balance_$uid';
String _cardKey(String uid) => 'wallet_card_$uid';
String _txKey(String uid) => 'wallet_transactions_$uid';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Genera o recupera el número de tarjeta GoSmart del usuario.
Future<String> _getOrCreateCardNumber(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _cardKey(uid);
  final existing = prefs.getString(key);
  if (existing != null) return existing;
  // Generar número GS-XXXX-XXXX-XXXX basado en uid
  final suffix = uid.replaceAll('-', '').substring(0, 12).toUpperCase();
  final num = 'GS-${suffix.substring(0, 4)}-${suffix.substring(4, 8)}-${suffix.substring(8, 12)}';
  await prefs.setString(key, num);
  return num;
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Wallet simulado del usuario actual (SharedPreferences).
final walletMockProvider = FutureProvider<WalletMock?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final prefs = await SharedPreferences.getInstance();
  final balance = prefs.getInt(_balanceKey(user.id)) ?? 10000; // $10,000 bienvenida
  final cardNumber = await _getOrCreateCardNumber(user.id);

  // Guardar balance inicial si es la primera vez
  if (!prefs.containsKey(_balanceKey(user.id))) {
    await prefs.setInt(_balanceKey(user.id), 10000);
  }

  return WalletMock(
    id: 'local-${user.id}',
    userId: user.id,
    balance: balance,
    cardNumber: cardNumber,
    cardStatus: 'active',
    createdAt: DateTime.now(),
  );
});

/// Saldo actual del wallet (0 si no disponible)
final walletMockBalanceProvider = Provider<int>((ref) {
  return ref.watch(walletMockProvider).valueOrNull?.balance ?? 0;
});

/// Historial de transacciones del wallet mock (paginado)
final walletMockTransactionsProvider =
    FutureProvider.family<List<WalletTransactionModel>, int>(
  (ref, limit) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];

    // Escuchar cambios en wallet para recargar transacciones también
    ref.watch(walletMockProvider);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_txKey(user.id));
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final all = list
          .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all.take(limit).toList();
    } catch (_) {
      return [];
    }
  },
);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class WalletMockNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Recarga el saldo (mock local — sin cobro real).
  Future<bool> recharge(int amount, {String? description}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncLoading();

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = prefs.getInt(_balanceKey(user.id)) ?? 0;
      final newBalance = currentBalance + amount;

      if (newBalance < 0) {
        state = const AsyncData(null);
        return false;
      }

      // Actualizar saldo
      await prefs.setInt(_balanceKey(user.id), newBalance);

      // Registrar transacción
      final txRaw = prefs.getString(_txKey(user.id));
      final txList = txRaw != null
          ? (jsonDecode(txRaw) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      txList.insert(0, {
        'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
        'wallet_id': 'local-${user.id}',
        'type': amount >= 0 ? 'recharge' : 'trip',
        'amount': amount,
        'description': description ?? (amount >= 0 ? 'Recarga de saldo' : 'Pago de viaje'),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Mantener máximo 50 transacciones
      final trimmed = txList.take(50).toList();
      await prefs.setString(_txKey(user.id), jsonEncode(trimmed));

      // Invalidar providers para refrescar UI
      ref.invalidate(walletMockProvider);
      ref.invalidate(walletMockTransactionsProvider(20));

      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  /// Descuenta saldo por un viaje (mock).
  Future<bool> payTrip(int amount, {required String routeDescription}) {
    return recharge(-amount, description: routeDescription);
  }

  bool hasSufficientBalance(int amount) {
    return ref.read(walletMockBalanceProvider) >= amount;
  }
}

final walletMockNotifierProvider =
    AsyncNotifierProvider<WalletMockNotifier, void>(
  WalletMockNotifier.new,
);
