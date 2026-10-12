// test/widget/route_planner_test.dart
// Planificador: modos locales y placa en blanco hasta elegir destino.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/routes/route_planner_screen.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/favorites_provider.dart';
import 'package:gosmart/providers/selected_mode_provider.dart';
import 'package:gosmart/theme/app_theme.dart';

void main() {
  testWidgets('ofrece los modos locales y cambia la selección',
      (tester) async {
    final container = ProviderContainer(overrides: [
      isGuestProvider.overrideWithValue(true),
      currentUserProvider.overrideWithValue(null),
      favoritePlacesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: AppTheme.light, home: const RoutePlannerScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¿A DÓNDE VAS?'), findsOneWidget);
    expect(find.text('Mototaxi'), findsOneWidget);
    expect(find.text('Metro'), findsNothing);
    expect(find.text('Bici'), findsNothing);
    expect(container.read(selectedModeProvider), 'Mototaxi');

    await tester.tap(find.text('Taxi'));
    await tester.pump();
    expect(container.read(selectedModeProvider), 'Taxi');
  });
}
