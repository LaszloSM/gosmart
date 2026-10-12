// test/widget/trust_admin_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/admin/admin_screen.dart';
import 'package:gosmart/features/trust/rate_sheet.dart';
import 'package:gosmart/models/profile_model.dart';
import 'package:gosmart/providers/profile_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_button.dart';

class _Fake extends ProfileNotifier {
  _Fake(this.p);
  final ProfileModel p;
  @override
  Future<void> load() async => state = AsyncData(p);
}

void main() {
  testWidgets('el panel admin se cierra para quien no es admin', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => _Fake(const ProfileModel(
            id: 'u', name: 'Ana', email: 'a@b.co'))),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const AdminScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SOLO ADMINISTRADORES'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('calificar pide estrellas; el pasajero no tiene "No pagó"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RateSheet(requestId: 'r', asDriver: false)),
    ));
    GSButton send() => tester.widget<GSButton>(find.widgetWithText(GSButton, 'Enviar'));
    expect(send().onPressed, isNull);
    expect(find.text('No pagó'), findsNothing);
    expect(find.text('Cobró de más'), findsOneWidget);
    await tester.tap(find.byTooltip('4 estrellas'));
    await tester.pump();
    expect(send().onPressed, isNotNull);
  });

  testWidgets('el conductor sí puede marcar "No pagó" y se le explica', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RateSheet(requestId: 'r', asDriver: true)),
    ));
    await tester.tap(find.text('No pagó'));
    await tester.pump();
    expect(find.textContaining('Con dos, no puede pedir'), findsOneWidget);
  });
}
