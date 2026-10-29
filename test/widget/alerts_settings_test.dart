// test/widget/alerts_settings_test.dart
// Alertas al estilo Waze y Configuración: la hoja de reportar, las
// preferencias por tipo y el selector de tema.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/alerts/report_sheet.dart';
import 'package:gosmart/features/settings/alert_settings_screen.dart';
import 'package:gosmart/features/settings/settings_screen.dart';
import 'package:gosmart/models/map_alert.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/corridor_provider.dart';
import 'package:gosmart/providers/map_alerts_provider.dart';
import 'package:gosmart/providers/settings_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {bool guest = true, List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [
        isGuestProvider.overrideWith((ref) => guest),
        currentUserProvider.overrideWithValue(null),
        roadSegmentsProvider.overrideWith((ref) async => const []),
        ...extra,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true, size: Size(412, 915)),
          child: child,
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Pantalla de teléfono (412 × 915), no la de 800 × 600 por defecto.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('reportar sin cuenta pide entrar', (tester) async {
    await tester.pumpWidget(_wrap(
        Scaffold(body: ReportSheet(locate: () async => const LatLng(11.544, -72.907)))));
    await tester.pumpAndSettle();
    expect(find.text('Entra para reportar'), findsOneWidget);
    expect(find.text('Trancón'), findsNothing);
  });

  testWidgets('con cuenta muestra los 8 tipos; Despejado solo en la Troncal',
      (tester) async {
    await tester.pumpWidget(_wrap(
        Scaffold(
            body: SingleChildScrollView(
                child: ReportSheet(locate: () async => const LatLng(11.544, -72.907)))),
        guest: false));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué ves en la vía?'), findsOneWidget);
    expect(find.text('Se reporta donde estás ahora'), findsOneWidget);
    for (final k in AlertKind.all) {
      expect(find.text(k.label), findsOneWidget, reason: k.label);
    }
    expect(find.text('Vía despejada'), findsNothing);
    // Un toque elige; publicar pide confirmar (nada se publica por un roce).
    expect(find.text('Elige qué ves'), findsOneWidget);
    await tester.tap(find.text('Trancón'));
    await tester.pumpAndSettle();
    expect(find.text('Reportar trancón'), findsOneWidget);
  });

  testWidgets('cada tipo: ocultar, ver o avisar; lo oculto sale del mapa',
      (tester) async {
    phone(tester);
    late ProviderContainer c;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      c = ProviderScope.containerOf(context);
      return const AlertSettingsScreen();
    })));
    await tester.pumpAndSettle();
    final kindRow = find.ancestor(
        of: find.text('Retén'),
        matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_KindRow'));
    final hide = find.descendant(of: kindRow, matching: find.text('Ocultar'));
    await tester.ensureVisible(hide);
    await tester.pumpAndSettle();
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(c.read(alertPrefsProvider)['reten']!.show, isFalse);
    expect(c.read(alertPrefsProvider)['reten']!.warn, isFalse);
    // "Ver" sin aviso: se ve pero no avisa.
    await tester.tap(find.descendant(of: kindRow, matching: find.text('Ver')));
    await tester.pumpAndSettle();
    expect(c.read(alertPrefsProvider)['reten']!.show, isTrue);
    expect(c.read(alertPrefsProvider)['reten']!.warn, isFalse);
    await tester.tap(find.descendant(of: kindRow, matching: find.text('Ocultar')));
    await tester.pumpAndSettle();
    // Lo oculto deja de pintarse en el mapa.
    c.read(mapAlertsProvider.notifier).state = AsyncData([
      MapAlert(id: 'r', kind: AlertKind.reten, at: const LatLng(11.5, -72.9), happenedAt: DateTime(2026)),
      MapAlert(id: 't', kind: AlertKind.trancon, at: const LatLng(11.5, -72.9), happenedAt: DateTime(2026)),
    ]);
    expect(c.read(visibleAlertsProvider).map((a) => a.id), ['t']);
  });

  testWidgets('el tema se elige con las tres tarjetas', (tester) async {
    late ProviderContainer c;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      c = ProviderScope.containerOf(context);
      return const SettingsScreen();
    })));
    await tester.pumpAndSettle();
    expect(find.text('Sistema'), findsOneWidget);
    expect(c.read(themeModeProvider), ThemeMode.system);
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode_v1'), 'dark');
  });
}
