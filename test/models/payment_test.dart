// test/models/payment_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/receipt_screen.dart';
import 'package:gosmart/services/payment_service.dart';
import 'package:gosmart/theme/app_theme.dart';

const _id = '3f2b9c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e';

void main() {
  test('el QR de cobro solo acepta el formato de GoSmart', () {
    expect(chargeIdFromQr(chargeQrData(_id)), _id);
    expect(chargeIdFromQr('https://banco.co/pagar?x=1'), isNull);
    expect(chargeIdFromQr('gosmart:pay:no-es-uuid'), isNull);
  });

  test('errores de pago en palabras', () {
    expect(const PaymentException('insufficient_balance').message, contains('saldo'));
    expect(() => PaymentException.from(Exception('ERROR: charge_closed')),
        throwsA(isA<PaymentException>().having((e) => e.code, 'code', 'charge_closed')));
  });

  test('métodos del recibo', () {
    expect(paymentMethodLabel(['wallet', 'cash']), 'saldo + efectivo');
    expect(paymentMethodLabel([]), 'Sin pago registrado');
  });

  testWidgets('el recibo muestra cada tramo y el total', (tester) async {
    final r = TripReceipt.fromJson({
      'trip_id': 't', 'origin': 'Parque Padilla', 'destination': 'Centro de Maicao',
      'created_at': '2026-10-12T14:00:00Z', 'total_paid': 18500,
      'legs': [
        {'mode': 'mototaxi', 'to': 'Terminal de Riohacha', 'paid': 4500, 'methods': ['qr']},
        {'mode': 'colectivo', 'to': 'Centro de Maicao', 'paid': 14000, 'methods': ['cash']},
      ],
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ReceiptScreen(tripId: 't', load: (_) async => r),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mototaxi hasta Terminal de Riohacha'), findsOneWidget);
    expect(find.text('Pagado con QR'), findsOneWidget);
    expect(find.text('Pagado con efectivo'), findsOneWidget);
    expect(find.text('\$18.500'), findsOneWidget);
  });
}
