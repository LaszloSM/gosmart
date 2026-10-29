// test/widget/ride_panel_test.dart
// Tramo en mototaxi al estilo InDrive: proponer tarifa, ver ofertas con
// quién ofrece y seguir al conductor (sin red: modo de vista previa).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/widgets/leg_panels.dart';
import 'package:gosmart/features/trip/widgets/trip_visuals.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/providers/wallet_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

const _leg = TripLegRow(
  id: 'l', seq: 0, mode: 'mototaxi', status: LegStatus.awaitingDispatch,
  toLabel: 'Universidad de La Guajira',
  from: LatLng(11.5441, -72.9071), to: LatLng(11.5262, -72.8740),
  fareMin: 5000, fareMax: 5000,
);

Widget _panel(RideRequest? r, {List<RideOffer> offers = const [], AssignedDriver? driver}) =>
    ProviderScope(
      overrides: [walletBalanceProvider.overrideWithValue(37500)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true, size: Size(412, 915)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: RideLegPanel(
                  leg: _leg, preview: (request: r, offers: offers, driver: driver, paid: false)),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('propones la tarifa y el botón la refleja', (tester) async {
    await tester.pumpWidget(_panel(null));
    await tester.pumpAndSettle();
    expect(find.text('Pedir mototaxi por \$5.000'), findsOneWidget);
    await tester.tap(find.text('+\$1.000'));
    await tester.pumpAndSettle();
    expect(find.text('Pedir mototaxi por \$6.000'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
  });

  testWidgets('las ofertas dicen quién, a cuánto está y la diferencia', (tester) async {
    final r = RideRequest(id: 'r', service: 'mototaxi', status: RideStatus.open,
        offeredFare: 5000, expiresAt: DateTime.now().add(const Duration(minutes: 2)));
    await tester.pumpWidget(_panel(r, offers: const [
      RideOffer(id: 'o', fare: 5500, firstName: 'Wilmer', rating: 4.8, pickupKm: 0.6, etaMin: 3),
    ]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Un conductor te hizo una oferta'), findsOneWidget);
    expect(find.text('Wilmer'), findsOneWidget);
    expect(find.textContaining('a 3 min · 600 m'), findsOneWidget);
    expect(find.text('+\$500'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);
  });

  testWidgets('el conductor viene con minutos y placa', (tester) async {
    final r = RideRequest(id: 'r', service: 'mototaxi', status: RideStatus.accepted,
        offeredFare: 5000, agreedFare: 5500, expiresAt: DateTime.now());
    await tester.pumpWidget(_panel(r,
        driver: const AssignedDriver(firstName: 'Wilmer', service: 'mototaxi', plate: 'ABC12D',
            at: LatLng(11.5470, -72.9040))));
    await tester.pumpAndSettle();
    expect(find.text('Wilmer viene por ti'), findsOneWidget);
    expect(find.textContaining('Llega en unos'), findsOneWidget);
    expect(find.text('\$5.500'), findsOneWidget);
  });

  test('minutos y distancias cortas', () {
    expect(etaMinutes(const LatLng(11.5441, -72.9071), const LatLng(11.5441, -72.9071)), 1);
    expect(shortDistance(0.64), '640 m');
    expect(shortDistance(1.26), '1,3 km');
  });
}
