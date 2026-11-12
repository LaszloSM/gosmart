// test/widget/trip_history_cancel_test.dart
// Historial de viajes (páginas, estado, lo pagado) y cancelar con motivo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/trip_history_screen.dart';
import 'package:gosmart/features/trip/widgets/cancel_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/trip/trip_detail_screen.dart';
import 'package:gosmart/models/trip_history.dart';
import 'package:gosmart/theme/app_theme.dart';

HistoryItem _trip(int i, String status) => HistoryItem.fromJson({
      'kind': 'trip',
      'id': 't$i',
      'status': status,
      'origin': 'Parque Padilla',
      'destination': 'Destino $i',
      'created_at':
          DateTime(2026, 11, 6, 15, 40).subtract(Duration(days: i)).toIso8601String(),
      'modes': ['mototaxi'],
      'from': {'lat': 11.5444, 'lng': -72.9072},
      'to': {'lat': 11.53, 'lng': -72.91},
      'total_paid': status == 'completed' ? 6000 : 0,
      'requests': 1,
      'last_ride': {
        'id': 'r$i',
        'service': 'mototaxi',
        'status': status == 'completed' ? 'completed' : 'cancelled',
        'offered_fare': 6000,
        'agreed_fare': status == 'completed' ? 6000 : null,
        'other_name': status == 'completed' ? 'Carlos' : null,
        'plate': status == 'completed' ? 'ABC12D' : null,
        'cancelled_by': status == 'completed' ? null : 'passenger',
      },
    });

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
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: AppTheme.light,
      home: TripHistoryScreen(load: (offset) async {
        asked.add(offset);
        if (offset > 0) return [];
        return [
          for (var i = 0; i < 20; i++)
            _trip(i, i.isEven ? 'completed' : 'cancelled')
        ];
      }),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Destino 0'), findsOneWidget);
    // Estado, con quién y placa; los cancelados también salen.
    expect(find.text('Completado · Carlos · ABC12D'), findsWidgets);
    expect(find.text('Cancelado'), findsWidgets);
    expect(find.text('Pedir de nuevo'), findsWidgets);
    expect(find.text(r'$6.000'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(asked, [0, 20]);
  });

  testWidgets('historial vacío invita a planear', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: AppTheme.light,
      home: TripHistoryScreen(load: (_) async => []),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes viajes'), findsOneWidget);
  });

  test('estado en palabras: nadie aceptó, cancelado por el conductor, no se pidió', () {
    HistoryItem withRide(Map<String, dynamic> ride, {int requests = 1}) =>
        HistoryItem.fromJson({
          'kind': 'trip', 'id': 'x', 'status': 'cancelled',
          'requests': requests, 'last_ride': ride,
        });
    expect(withRide({'id': 'r', 'status': 'expired', 'offered_fare': 5000}).statusText.$1,
        'Nadie aceptó');
    expect(
        withRide({'id': 'r', 'status': 'cancelled', 'cancelled_by': 'driver', 'offered_fare': 5000})
            .statusText.$1,
        'Cancelado por el conductor');
    expect(HistoryItem.fromJson({'kind': 'trip', 'id': 'y', 'status': 'cancelled', 'requests': 0})
            .statusText.$1,
        'No se pidió');
    final asDriver = HistoryItem.fromJson({
      'kind': 'ride', 'id': 'z', 'service': 'taxi', 'status': 'completed',
      'offered_fare': 9000, 'agreed_fare': 9000, 'other_name': 'Ana',
    });
    expect(asDriver.asDriver, isTrue);
    expect(asDriver.price, 9000);
    expect(asDriver.canRepeat, isFalse);
  });

  testWidgets('detalle estilo InDrive: conductor, placa, pago, horas y motivo',
      (tester) async {
    final item = _trip(0, 'completed');
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: AppTheme.light,
      home: TripDetailScreen(
        item: item,
        showMap: false,
        load: (_) async => TripDetail.fromJson({
          'kind': 'trip', 'id': 't0', 'status': 'completed',
          'origin': 'Parque Padilla', 'destination': 'Uniguajira',
          'total_paid': 7000,
          'legs': [
            {
              'seq': 0, 'mode': 'mototaxi', 'status': 'completed',
              'from': {'lat': 11.5444, 'lng': -72.9072}, 'to': {'lat': 11.53, 'lng': -72.91},
              'rides': [
                {'id': 'a', 'service': 'mototaxi', 'status': 'expired', 'offered_fare': 6000,
                 'created_at': '2026-11-06T15:30:00'},
                {'id': 'b', 'service': 'mototaxi', 'status': 'completed', 'offered_fare': 7000,
                 'agreed_fare': 7000, 'other_name': 'Carlos', 'plate': 'ABC12D',
                 'vehicle': 'Bajaj roja', 'pay_method': 'cash', 'my_stars': 5,
                 'created_at': '2026-11-06T15:34:00', 'accepted_at': '2026-11-06T15:36:00',
                 'finished_at': '2026-11-06T15:50:00'},
              ],
            }
          ],
        }),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Carlos'), findsWidgets);
    expect(find.text('ABC12D'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Intentos (2)'), findsOneWidget);
    expect(find.text('Nadie aceptó a tiempo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ver recibo'), 200);
    expect(find.text('Pedir de nuevo'), findsOneWidget);
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
