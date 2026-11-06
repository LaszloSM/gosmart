// test/widget/trip_history_cancel_test.dart
// Historial de viajes (páginas, estado, lo pagado) y cancelar con motivo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/trip_history_screen.dart';
import 'package:gosmart/features/trip/widgets/cancel_sheet.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/theme/app_theme.dart';

ChainedTrip _trip(int i, String status) => ChainedTrip(
      id: 't$i',
      status: status,
      originLabel: 'Parque Padilla',
      destLabel: 'Destino $i',
      createdAt: DateTime(2026, 11, 6, 15, 40).subtract(Duration(days: i)),
      legs: [
        TripLegRow(
            id: 'l$i',
            seq: 0,
            mode: 'mototaxi',
            status: status == 'completed'
                ? LegStatus.completed
                : LegStatus.cancelled,
            agreedFare: 6000),
      ],
    );

void main() {
  test('fecha legible sin intl', () {
    final now = DateTime(2026, 11, 6, 18);
    expect(
        tripWhen(DateTime(2026, 11, 6, 9, 5), now: now), startsWith('Hoy, '));
    expect(
        tripWhen(DateTime(2026, 11, 5, 9, 5), now: now), startsWith('Ayer, '));
    expect(tripWhen(DateTime(2025, 3, 2, 9, 5), now: now),
        startsWith('2 mar 2025, '));
  });

  testWidgets('historial: lista, estado y lo pagado; pide la página siguiente',
      (tester) async {
    final asked = <int>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: TripHistoryScreen(load: (offset) async {
        asked.add(offset);
        if (offset > 0) return [];
        return [
          for (var i = 0; i < 20; i++)
            _trip(i, i.isEven ? 'completed' : 'cancelled')
        ];
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Destino 0'), findsOneWidget);
    expect(find.text('Completado'), findsWidgets);
    expect(find.text('Cancelado'), findsWidgets);
    expect(find.text(r'$6.000'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(asked, [0, 20]);
  });

  testWidgets('historial vacío invita a planear', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: TripHistoryScreen(load: (_) async => []),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes viajes'), findsOneWidget);
  });

  testWidgets('con conductor asignado, cancelar exige motivo', (tester) async {
    CancelChoice? got;
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            got = await showCancelSheet(context, driverAssigned: true);
            closed = true;
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final cancel = find.widgetWithText(InkWell, 'Sí, cancelar');
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(closed, isFalse, reason: 'sin motivo no cierra');
    expect(cancel, findsWidgets);

    await tester.tap(find.text('El conductor tarda mucho'));
    await tester.pump();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(got?.reason, 'driver_late');
  });

  testWidgets('sin conductor basta confirmar; "Seguir esperando" no cancela',
      (tester) async {
    final results = <CancelChoice?>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results
              .add(await showCancelSheet(context, driverAssigned: false)),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('El conductor tarda mucho'), findsNothing);
    await tester.tap(find.text('Seguir esperando'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(results.length, 2);
    expect(results[0], isNull);
    expect(results[1], isNotNull);
    expect(results[1]!.reason, isNull);
  });
}
