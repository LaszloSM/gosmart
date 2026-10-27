// test/widget/login_test.dart
// Tests the LoginScreen renders correctly and validates form input

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/auth/login_screen.dart';
import 'package:gosmart/theme/app_theme.dart';

Widget buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders email and password by default (no SMS provider yet)',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Entra a GoSmart'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Número de celular'), findsNothing);
    });

    testWidgets('shows phone input when phone tab selected', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Celular').first);
      await tester.pumpAndSettle();

      expect(find.text('Número de celular'), findsOneWidget);
      expect(find.text('Contraseña'), findsNothing);
    });

    testWidgets('shows validation error when phone is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Celular').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Enviar código'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un número válido'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty email login',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();
      // Los campos llevan la etiqueta encima: el botón puede quedar abajo.
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(find.text('Contraseña muy corta'), findsOneWidget);
    });
  });
}
