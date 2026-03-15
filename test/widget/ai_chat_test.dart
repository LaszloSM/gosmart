// test/widget/ai_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/ai_chat/ai_chat_screen.dart';
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
  group('AiChatScreen', () {
    testWidgets('renders GoSmart AI title', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pump();

      expect(find.text('GoSmart AI'), findsOneWidget);
    });

    testWidgets('shows welcome message from notifier', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pump();

      expect(find.textContaining('asistente GoSmart'), findsOneWidget);
    });

    testWidgets('send button is present', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
