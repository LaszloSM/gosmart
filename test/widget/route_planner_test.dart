// test/widget/route_planner_test.dart
// Planificador estilo Uber/InDrive: se escribe el destino (y, si se quiere, la
// recogida); con los dos puntos salen los modos con precio y, para mototaxi y
// taxi, "Pedir" en un toque con la tarifa que se va a ofrecer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/routes/route_planner_screen.dart';
import 'package:gosmart/providers/active_route_provider.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/favorites_provider.dart';
import 'package:gosmart/providers/selected_mode_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('abre escribiendo el destino; la recogida se puede cambiar',
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

    expect(find.text('¿A dónde vas?'), findsOneWidget); // título
    expect(find.text('Recoger en'), findsOneWidget);
    expect(find.text('Elegir en el mapa'), findsOneWidget);
    // Sin los dos puntos todavía no hay botón de pedir.
    expect(find.textContaining('Pedir'), findsNothing);

    // Tocar "Recoger en" deja escribir la dirección de recogida a mano.
    await tester.tap(find.text('Recoger en'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Usar mi ubicación actual'), findsOneWidget);
  });

  testWidgets('con los dos puntos: modos con precio y Pedir en un toque',
      (tester) async {
    final container = ProviderContainer(overrides: [
      isGuestProvider.overrideWithValue(false),
      currentUserProvider.overrideWithValue(null),
      favoritePlacesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    container.read(pendingPlanProvider.notifier).state = const PlannerPreset(
      origin: LatLng(11.5444, -72.9072),
      originLabel: 'Parque Padilla',
      dest: LatLng(11.5275, -72.8880),
      destLabel: 'Universidad de La Guajira',
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: AppTheme.light, home: const RoutePlannerScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Elige cómo ir'), findsOneWidget);
    expect(container.read(selectedModeProvider), 'Mototaxi');
    // El botón dice cuánto se va a ofrecer: no hay otra pantalla de "oferta".
    expect(find.textContaining(r'Pedir mototaxi · $'), findsOneWidget);
    // Nunca una hora de llegada: duración en rango.
    expect(find.textContaining('Llegas'), findsNothing);
    expect(find.textContaining('llegas'), findsNothing);

    await tester.tap(find.text('Taxi'));
    await tester.pump();
    expect(container.read(selectedModeProvider), 'Taxi');
    expect(find.textContaining(r'Pedir taxi · $'), findsOneWidget);
  });
}
