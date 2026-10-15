// test/widget/trip_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/trip_screen.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/dispatch_provider.dart';
import 'package:gosmart/theme/app_theme.dart';

Widget _app(ChainedTrip? t) => ProviderScope(
      overrides: [
        activeTripProvider.overrideWith((ref) async => t),
        isGuestProvider.overrideWithValue(false),
        recentTripsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const TripScreen()),
    );

void main() {
  testWidgets('sin viaje invita a planear', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('Sin viaje en curso'), findsOneWidget);
  });

  testWidgets('muestra la cadena de tramos y lo que toca ahora', (tester) async {
    final t = ChainedTrip.fromJson({
      'id': 't', 'status': 'in_progress',
      'origin_label': 'Parque Padilla', 'dest_label': 'Centro de Maicao',
      'trip_legs': [
        {'id': 'a', 'seq': 0, 'mode': 'mototaxi', 'status': 'completed',
         'to_label': 'Terminal de Riohacha'},
        {'id': 'b', 'seq': 1, 'mode': 'walk', 'status': 'planned',
         'to_label': 'Punto de colectivos', 'minutes': 4},
      ],
    });
    await tester.pumpWidget(_app(t));
    await tester.pumpAndSettle();
    expect(find.text('Centro de Maicao'), findsOneWidget);
    expect(find.text('Hecho · hasta Terminal de Riohacha'), findsOneWidget);
    expect(find.textContaining('Camina hasta Punto de colectivos'), findsOneWidget);
    expect(find.text('Ya llegué'), findsOneWidget);
  });
}
