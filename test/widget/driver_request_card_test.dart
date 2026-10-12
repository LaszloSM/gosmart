// test/widget/driver_request_card_test.dart
// DS6: dos acciones grandes (72 dp) y sin datos personales del pasajero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/driver/driver_work_panel.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_button.dart';

void main() {
  testWidgets('aceptar y ofrecer, ambos de 72 dp', (tester) async {
    var accepted = false, countered = false;
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
            onAccept: () => accepted = true,
            onCounter: () => countered = true,
          ),
        ),
      ),
    ));
    expect(find.text('Recoger a 0.4 km · viaje de 3.2 km'), findsOneWidget);
    final accept = find.widgetWithText(GSButton, 'Aceptar \$5.000');
    final offer = find.widgetWithText(GSButton, 'Ofrecer \$6.000');
    expect(tester.getSize(accept).height, greaterThanOrEqualTo(72));
    expect(tester.getSize(offer).height, greaterThanOrEqualTo(72));
    await tester.tap(accept);
    await tester.tap(offer);
    expect(accepted && countered, isTrue);
  });
}
