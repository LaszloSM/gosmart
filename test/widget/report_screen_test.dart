// test/widget/report_screen_test.dart
// Reportar: dos toques, sin texto libre, el tramo sale del GPS si estás en la vía.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/corridor/report_screen.dart';
import 'package:gosmart/providers/corridor_provider.dart';
import 'package:gosmart/services/corridor_service.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/widgets/gs_button.dart';
import 'package:latlong2/latlong.dart';

const _segs = [
  RoadSegmentGeo(id: 'troncal-00-10', name: 'Riohacha – salida a Maicao',
      from: LatLng(11.544, -72.907), to: LatLng(11.505, -72.825)),
  RoadSegmentGeo(id: 'troncal-30-40', name: 'Troncal km 30–40',
      from: LatLng(11.425, -72.660), to: LatLng(11.385, -72.578)),
];

Widget _app(LatLng? at) => ProviderScope(
      overrides: [roadSegmentsProvider.overrideWith((ref) async => _segs)],
      child: MaterialApp(
          theme: AppTheme.light, home: ReportScreen(locate: () async => at)),
    );

GSButton _sendButton(WidgetTester t) =>
    t.widget<GSButton>(find.widgetWithText(GSButton, 'Enviar reporte'));

void main() {
  testWidgets('no hay campo de texto: solo tipo y lugar', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Bloqueo'), findsOneWidget);
    expect(find.text('Retén'), findsOneWidget);
    expect(find.text('Vía despejada'), findsOneWidget);
  });

  testWidgets('con GPS en la vía, el tramo queda elegido; falta el qué',
      (tester) async {
    await tester.pumpWidget(_app(const LatLng(11.40, -72.61)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Te ubicamos en este tramo'), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNull);
    await tester.tap(find.text('Bloqueo'));
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('sin GPS pide elegir el tramo', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('Sin GPS: elige el tramo.'), findsOneWidget);
    await tester.tap(find.text('Bloqueo'));
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);
    await tester.tap(find.text('Troncal km 30–40'));
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
  });
}
