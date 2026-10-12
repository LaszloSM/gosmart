// test/widget/sos_sheet_test.dart
// La hoja de Ayuda: el 123 primero; contactos con un toque; invitado sin trampa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/safety/sos_sheet.dart';
import 'package:gosmart/models/emergency_contact.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/safety_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

Widget _app({required bool guest, List<EmergencyContact> contacts = const [],
    LatLng? at}) =>
    ProviderScope(
      overrides: [
        isGuestProvider.overrideWithValue(guest),
        currentUserProvider.overrideWithValue(null),
        emergencyContactsProvider.overrideWith((ref) async => contacts),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SosSheetContent(locate: () async => at),
          ),
        ),
      ),
    );

void main() {
  testWidgets('el 123 es lo primero y dice que es gratis', (tester) async {
    await tester.pumpWidget(_app(guest: true));
    await tester.pumpAndSettle();
    expect(find.text('Llamar al 123'), findsOneWidget);
    expect(find.textContaining('gratis'), findsOneWidget);
  });

  testWidgets('sin GPS avisa que el mensaje irá sin ubicación', (tester) async {
    await tester.pumpWidget(_app(guest: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin ubicación'), findsOneWidget);
  });

  testWidgets('con GPS confirma que la ubicación va en el mensaje',
      (tester) async {
    await tester.pumpWidget(_app(guest: true, at: const LatLng(11.5, -72.9)));
    await tester.pumpAndSettle();
    expect(find.text('Tu ubicación va en el mensaje'), findsOneWidget);
  });

  testWidgets('invitado: WhatsApp libre y la invitación a guardar contactos',
      (tester) async {
    await tester.pumpWidget(_app(guest: true));
    await tester.pumpAndSettle();
    expect(find.text('Avisar por WhatsApp'), findsOneWidget);
    expect(find.text('Guarda tus contactos de emergencia'), findsOneWidget);
  });

  testWidgets('con contactos: uno por fila y SMS a todos', (tester) async {
    await tester.pumpWidget(_app(guest: false, contacts: const [
      EmergencyContact(id: '1', name: 'Mamá', phone: '+573001112233'),
      EmergencyContact(id: '2', name: 'Carlos', phone: '+573004445566'),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp a Mamá'), findsOneWidget);
    expect(find.text('WhatsApp a Carlos'), findsOneWidget);
    expect(find.text('SMS a tus 2 contactos'), findsOneWidget);
    expect(find.text('300 111 2233'), findsOneWidget);
  });
}
