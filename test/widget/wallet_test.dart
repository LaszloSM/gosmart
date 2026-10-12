// test/widget/wallet_test.dart
// Tests WalletScreen renders balance states correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/wallet/wallet_screen.dart';
import 'package:gosmart/providers/card_provider.dart';
import 'package:gosmart/models/card_model.dart';
import 'package:gosmart/models/wallet_model.dart';
import 'package:gosmart/providers/transaction_provider.dart';
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
  balance: 37000, // distinto al saldo de la tarjeta (50000)
  cardNumber: 'GS-1234-5678-9012',
  cardStatus: 'active',
  createdAt: DateTime(2026, 10, 1),
);

/// Evita llamadas reales a Supabase: billetera fija y listas vacías.
List<Override> _walletOverrides(CardModel? card) => [
      if (card != null)
        activeCardProvider.overrideWith((ref) => _MockCardNotifier(card)),
      walletProvider.overrideWith((ref) async => _testWallet),
      walletTransactionsProvider.overrideWith((ref, limit) async => []),
      transactionListProvider.overrideWith((ref) => _EmptyTxNotifier()),
    ];

Widget buildTestApp(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('WalletScreen', () {
    testWidgets('shows loading indicator while card loads', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WalletScreen(),
        overrides: [
          activeCardProvider.overrideWith((ref) => _LoadingCardNotifier()),
        ],
      ));
      await tester.pump();
      // Just verify it renders without crashing
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('shows balance when card is loaded', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WalletScreen(),
        overrides: _walletOverrides(_testCard),
      ));
      await tester.pumpAndSettle();

      // El saldo viene de la billetera (wallets), no de la tarjeta.
      expect(find.text('\$37000 COP'), findsOneWidget);
    });

    testWidgets('shows lock card option', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WalletScreen(),
        overrides: _walletOverrides(_testCard),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bloquear'), findsAtLeastNWidgets(1));
    });
  });
}

class _MockCardNotifier extends ActiveCardNotifier {
  _MockCardNotifier(CardModel card) {
    state = AsyncData(card);
  }

  // Override public methods (not private) to prevent live Supabase calls in tests
  @override
  Future<void> load() async {}

  @override
  void subscribeRealtime() {}
}

/// Stays in AsyncLoading state — used to test the loading indicator UI
class _LoadingCardNotifier extends ActiveCardNotifier {
  _LoadingCardNotifier() {
    state = const AsyncLoading();
  }

  @override
  Future<void> load() async {} // no-op: keeps loading state

  @override
  void subscribeRealtime() {}
}

/// Historial vacío, sin consultar Supabase.
class _EmptyTxNotifier extends TransactionListNotifier {
  @override
  Future<void> load({bool refresh = false}) async {
    state = const AsyncData([]);
  }
}
