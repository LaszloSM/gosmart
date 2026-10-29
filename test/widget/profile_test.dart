// test/widget/profile_test.dart
// Perfil rediseñado: placa con el nombre, solo opciones que funcionan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/profile/profile_screen.dart';
import 'package:gosmart/models/profile_model.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/profile_provider.dart';
import 'package:gosmart/theme/app_theme.dart';

class _FakeProfile extends ProfileNotifier {
  _FakeProfile(this.profile);
  final ProfileModel? profile;

  @override
  Future<void> load() async {
    state = profile == null
        ? AsyncError(Exception('sin red'), StackTrace.empty)
        : AsyncData(profile!);
  }
}

Widget _app(ProfileModel? p) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => _FakeProfile(p)),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    );

const _p = ProfileModel(
  id: 'u',
  name: 'Yeinis Epiayú',
  email: 'yeinis@correo.co',
  ecoPoints: 135,
  cedula: '1124038745',
  city: 'Riohacha',
);

void main() {
  testWidgets('muestra el nombre en la placa y el resumen de datos',
      (tester) async {
    await tester.pumpWidget(_app(_p));
    await tester.pumpAndSettle();
    expect(find.text('Yeinis Epiayú'), findsOneWidget);
    expect(find.text('Cédula •••• 8745 · Riohacha'), findsOneWidget);
    expect(find.text('135 eco-puntos'), findsOneWidget);
  });

  testWidgets('no ofrece interruptores ni enlaces que no hacen nada',
      (tester) async {
    await tester.pumpWidget(_app(_p));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Notificaciones'), findsNothing);
    expect(find.text('Login biométrico'), findsNothing);
  });

  testWidgets('si falla la carga, ofrece reintentar sin mostrar "Error"',
      (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tu perfil'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('abre la hoja de datos con la cédula bloqueada', (tester) async {
    await tester.pumpWidget(_app(_p));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Ya está registrada y no se puede cambiar.'),
        findsOneWidget);
  });
}
