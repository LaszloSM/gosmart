// test/widget/wallet_test.dart
// Billetera unificada: saldo único en mono, movimientos y tarjeta.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/wallet/wallet_screen.dart';
import 'package:gosmart/models/card_model.dart';
import 'package:gosmart/models/wallet_model.dart';
import 'package:gosmart/models/wallet_transaction_model.dart';
import 'package:gosmart/providers/card_provider.dart';
import 'package:gosmart/providers/wallet_provider.dart';
import 'package:gosmart/theme/app_theme.dart';

const _testCard = CardModel(
  id: 'test-card-id',
  userId: 'test-user-id',
  numberMasked: '•••• •••• •••• 4242',
  balance: 50000.0,
  currency: 'COP',
  status: 'active',
  nfcEnabled: true,
  expiresAt: '12/28',
);

final _testWallet = Wallet(
  id: 'test-wallet-id',
  userId: 'test-user-id',
  balance: 37000,
  cardNumber: 'GS-1234-5678-9012',
  cardStatus: 'active',
  createdAt: DateTime(2026, 10, 1),
);

final _recharge = WalletTransactionModel(
  id: 'tx-1',
  walletId: 'test-wallet-id',
  type: WalletTxType.recharge,
  amount: 10000,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

Widget _app({
  FutureOr<Wallet?> Function()? wallet,
  List<WalletTransactionModel> txs = const [],
}) {
  return ProviderScope(
    overrides: [
      activeCardProvider.overrideWith((ref) => _MockCardNotifier(_testCard)),
      walletProvider.overrideWith((ref) async => (wallet ?? () => _testWallet)()),
      walletTransactionsProvider.overrideWith((ref, limit) async => txs),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const WalletScreen()),
  );
}

void main() {
  group('WalletScreen', () {
    testWidgets('muestra el saldo una sola vez, con separador de miles',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('\$37.000', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('GS-****-****-9012'), findsOneWidget);
    });

    testWidgets('mientras carga no se rompe', (tester) async {
      final pending = Completer<Wallet?>();
      await tester.pumpWidget(_app(wallet: () => pending.future));
      await tester.pump();
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(find.textContaining('\$37.000', findRichText: true),
          findsNothing);
      pending.complete(_testWallet);
      await tester.pumpAndSettle();
    });

    testWidgets('sin movimientos lo dice', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no tienes movimientos'), findsOneWidget);
    });

    testWidgets('lista movimientos con signo y monto en pesos',
        (tester) async {
      await tester.pumpWidget(_app(txs: [_recharge]));
      await tester.pumpAndSettle();
      expect(find.text('Recarga'), findsOneWidget);
      expect(find.text('+\$10.000'), findsOneWidget);
    });

    testWidgets('ofrece bloquear la tarjeta', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Bloquear tarjeta'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Bloquear tarjeta'), findsOneWidget);
    });
  });
}

class _MockCardNotifier extends ActiveCardNotifier {
  _MockCardNotifier(CardModel card) {
    state = AsyncData(card);
  }

  // Métodos públicos sobrescritos para no llamar a Supabase en los tests.
  @override
  Future<void> load() async {}

  @override
  void subscribeRealtime() {}
}
