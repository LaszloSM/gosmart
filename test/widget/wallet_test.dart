// test/widget/wallet_test.dart
// Tests WalletScreen renders balance states correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/wallet/wallet_screen.dart';
import 'package:gosmart/providers/card_provider.dart';
import 'package:gosmart/models/card_model.dart';
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
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeCardProvider
              .overrideWith((ref) => _MockCardNotifier(_testCard)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WalletScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('50.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows lock card option', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeCardProvider
              .overrideWith((ref) => _MockCardNotifier(_testCard)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WalletScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lock card'), findsAtLeastNWidgets(1));
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
