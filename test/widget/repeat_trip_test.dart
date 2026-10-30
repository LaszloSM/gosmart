// test/widget/repeat_trip_test.dart
// "Repetir" un viaje del historial: el planificador abre con el mismo origen
// y destino exactos (como Uber) y el GPS no reemplaza el origen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gosmart/features/routes/route_planner_screen.dart';
import 'package:gosmart/features/trip/trip_screen.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/providers/active_route_provider.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/dispatch_provider.dart';
import 'package:gosmart/providers/favorites_provider.dart';
import 'package:gosmart/router/app_router.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

final _row = {
  'id': 't1',
  'status': 'completed',
  'created_at': '2026-10-29T15:00:00Z',
  'origin_label': 'Parque Padilla',
  'dest_label': 'Universidad de La Guajira',
  // Desordenados a propósito: cuenta el orden de seq.
  'trip_legs': [
    {'seq': 1, 'from_lat': 11.53, 'from_lng': -72.90, 'to_lat': 11.5275, 'to_lng': -72.8880},
    {'seq': 0, 'from_lat': 11.5448, 'from_lng': -72.9079, 'to_lat': 11.53, 'to_lng': -72.90},
  ],
};

void main() {
  test('el historial toma el inicio del primer tramo y el final del último', () {
    final t = RecentTrip.fromRow(_row);
    expect(t.origin, const LatLng(11.5448, -72.9079));
    expect(t.dest, const LatLng(11.5275, -72.8880));
    expect(t.canRepeat, isTrue);
    final sinTramos = RecentTrip.fromRow({..._row, 'trip_legs': []});
    expect(sinTramos.canRepeat, isFalse);
  });

  testWidgets('Repetir abre el planificador con los dos puntos del viaje',
      (tester) async {
    final container = ProviderContainer(overrides: [
      activeTripProvider.overrideWith((ref) async => null),
      isGuestProvider.overrideWithValue(false),
      currentUserProvider.overrideWithValue(null),
      favoritePlacesProvider.overrideWith((ref) async => []),
      recentTripsProvider.overrideWith((ref) async => [RecentTrip.fromRow(_row)]),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: AppRoutes.trip, routes: [
      GoRoute(path: AppRoutes.trip, builder: (_, __) => const TripScreen()),
      GoRoute(path: AppRoutes.routePlanner, builder: (_, __) => const RoutePlannerScreen()),
      GoRoute(path: AppRoutes.receipt, builder: (_, __) => const SizedBox()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Repetir', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // El planificador consumió el plan y muestra los dos puntos.
    expect(container.read(pendingPlanProvider), isNull);
    expect(find.text('Parque Padilla'), findsOneWidget);
    expect(find.text('Universidad de La Guajira'), findsWidgets);
    // Con los dos puntos ya ofrece las opciones con tiempo y precio.
    expect(find.text('Elige cómo ir'), findsOneWidget);
  });
}
