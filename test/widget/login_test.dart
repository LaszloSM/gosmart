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
    testWidgets('renders phone input by default', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome\nback!'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('shows email and password fields when email tab selected',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap the Email tab
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows validation error when phone is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap send button without filling phone
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('Try Demo button is present', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Try Demo'), findsOneWidget);
    });
  });
}
