// test/widget/driver_home_test.dart
// Modo conductor: cada estado del registro dice qué sigue, sin fingir viajes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/driver/driver_home_screen.dart';
import 'package:gosmart/models/driver_model.dart';
import 'package:gosmart/providers/driver_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_button.dart';

Widget _app(DriverProfile? d) => ProviderScope(
      overrides: [
        myDriverProvider.overrideWith((ref) async => d),
        driverEarningsProvider.overrideWith((ref) async =>
            const DriverEarnings(todayTotal: 23000, todayTrips: 4, todayCash: 8000)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const DriverHomeScreen()),
    );

DriverProfile _d(String status, {bool available = false, bool docs = false}) =>
    DriverProfile.fromJson({
      'user_id': 'u',
      'full_name': 'Ana Pérez',
      'cedula': '1118555444',
      'phone': '+573001234567',
      'service': 'mototaxi',
      'zone': 'riohacha',
      'status': status,
      'available': available,
      'vehicles': [
        {'plate': 'ABC12D', 'kind': 'moto', 'seats': 1}
      ],
      'driver_documents': docs
          ? [for (final k in requiredDriverDocuments) {'kind': k}]
          : [],
    });

void main() {
  testWidgets('sin registro invita a registrarse', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('Registrarme'), findsOneWidget);
  });

  testWidgets('pendiente sin documentos: dice que faltan y no deja ponerse disponible',
      (tester) async {
    await tester.pumpWidget(_app(_d('pending')));
    await tester.pumpAndSettle();
    expect(find.text('Faltan documentos'), findsOneWidget);
    expect(find.text('Ponerme disponible'), findsNothing);
    expect(find.text('Licencia de conducción'), findsOneWidget);
  });

  testWidgets('pendiente completo: en revisión', (tester) async {
    await tester.pumpWidget(_app(_d('pending', docs: true)));
    await tester.pumpAndSettle();
    expect(find.text('En revisión'), findsOneWidget);
  });

  testWidgets('aprobado: consola con Conectarme de 72 dp y lo de hoy arriba',
      (tester) async {
    await tester.pumpWidget(_app(_d('approved', docs: true)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Estás desconectado'), findsOneWidget);
    final btn = find.widgetWithText(GSButton, 'Conectarme');
    expect(btn, findsOneWidget);
    expect(tester.getSize(btn).height, greaterThanOrEqualTo(72));
    // Cobrar y el menú van arriba, no compiten en la zona del pulgar.
    expect(find.byTooltip('Cobrar con QR'), findsOneWidget);
    expect(find.byTooltip('Menú del conductor'), findsOneWidget);
    expect(find.text('\$23.000'), findsOneWidget);
    expect(find.textContaining('Placa ABC12D'), findsOneWidget);
  });

  testWidgets('el menú lleva a ganancias y al modo pasajero', (tester) async {
    await tester.pumpWidget(_app(_d('approved', docs: true)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.byTooltip('Menú del conductor'));
    await tester.pumpAndSettle();
    expect(find.text('Ganancias'), findsOneWidget);
    expect(find.text('Cambiar a modo pasajero'), findsOneWidget);
    await tester.tap(find.text('Hoy y los últimos 7 días'));
    await tester.pumpAndSettle();
    expect(find.text('Últimos 7 días'), findsOneWidget);
    expect(find.textContaining('\$15.000 por la app'), findsOneWidget);
  });
}
