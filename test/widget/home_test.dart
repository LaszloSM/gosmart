// test/widget/home_test.dart
// Línea del corredor y hoja del inicio en modo invitado (DS1–DS3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/home/widgets/corridor_detail_sheet.dart';
import 'package:gosmart/features/home/widgets/home_sheet.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/favorites_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_corridor_line.dart';

Widget _app(Widget child, {bool guest = true}) => ProviderScope(
      overrides: [
        isGuestProvider.overrideWithValue(guest),
        currentUserProvider.overrideWithValue(null),
        favoritePlacesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('GSCorridorLine', () {
    testWidgets('sin datos muestra "Sin datos", nunca un estado inventado',
        (tester) async {
      await tester.pumpWidget(_app(
        const GSCorridorLine(status: CorridorStatus.noData()),
      ));
      expect(find.text('Riohacha'), findsOneWidget);
      expect(find.text('Maicao'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.text('Abierta'), findsNothing);
    });

    testWidgets('con un bloqueo muestra "Cerrada" y la hora', (tester) async {
      final status = CorridorStatus(
        segments: const [
          CorridorSegment(kmFrom: 0, kmTo: 40, state: RoadState.open),
          CorridorSegment(
              kmFrom: 40,
              kmTo: 44,
              state: RoadState.closed,
              reason: 'Bloqueo',
              reports: 3),
          CorridorSegment(kmFrom: 44, kmTo: 75, state: RoadState.open),
        ],
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await tester.pumpWidget(_app(GSCorridorLine(status: status)));
      expect(find.text('Cerrada'), findsOneWidget);
      expect(find.text('hace 5 min'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('el detalle sin datos lo dice con honestidad', (tester) async {
      await tester.pumpWidget(_app(
        const CorridorDetailSheet(status: CorridorStatus.noData()),
      ));
      expect(find.text('Aún no tenemos reportes de la vía'), findsOneWidget);
      expect(find.text('Sin actualizaciones todavía'), findsOneWidget);
    });
  });

  group('HomeSheetContent', () {
    testWidgets('invitado: ve "¿A dónde vas?" y la invitación a entrar',
        (tester) async {
      await tester.pumpWidget(_app(const HomeSheetContent()));
      await tester.pump();
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      expect(find.text('Agregar casa'), findsOneWidget);
      expect(find.text('Entrar o crear cuenta'), findsOneWidget);
    });

    testWidgets('con cuenta no muestra la invitación', (tester) async {
      await tester.pumpWidget(_app(const HomeSheetContent(), guest: false));
      await tester.pump();
      expect(find.text('Entrar o crear cuenta'), findsNothing);
    });
  });
}
