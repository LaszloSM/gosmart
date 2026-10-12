// test/widget/driver_request_card_test.dart
// La tarjeta informa (sin datos personales); las acciones van en la zona del pulgar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/driver/driver_work_panel.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_button.dart';

void main() {
  testWidgets('tarifa, distancias con coma decimal y elegible al tocar', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DriverRequestCard(
            request: NearbyRequest(
              id: 'r', pickupKm: 0.4, tripKm: 3.2, offeredFare: 5000,
              expiresAt: DateTime.now().add(const Duration(minutes: 2)),
              originLabel: 'Parque Padilla', destLabel: 'Uniguajira',
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    expect(find.text('Recoger a 0,4 km · viaje de 3,2 km'), findsOneWidget);
    expect(find.byType(GSButton), findsNothing);
    await tester.tap(find.text('Desde Parque Padilla'));
    expect(tapped, isTrue);
  });

  testWidgets('el botón de conductor mide 72 dp y no se corta al 200 %', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: Center(
            child: GSButton(
              label: 'Sí, recibí \$15.000',
              size: GSButtonSize.driver,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(GSButton));
    expect(size.height, greaterThanOrEqualTo(72));
    final text = tester.widget<Text>(find.text('Sí, recibí \$15.000'));
    expect(text.maxLines, 2);
  });
}
