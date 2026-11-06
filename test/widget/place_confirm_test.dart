// test/widget/place_confirm_test.dart
// Confirmar el punto en el mapa: el lugar elegido vuelve con su punto; si la
// persona mueve el mapa, vuelve el punto nuevo con su dirección; también se
// abre encima de una hoja (Casa/Trabajo) y devuelve el resultado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gosmart/features/routes/place_confirm_screen.dart';
import 'package:gosmart/models/geocode_suggestion.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

const _plaza = GeocodeSuggestion(
  placeName: 'Parque Almirante Padilla',
  fullAddress: 'Cl. 2 #7, Riohacha',
  latLng: LatLng(11.5448, -72.9079),
  featureType: 'poi',
  fromDirectory: true,
);

/// Un GoRouter mínimo: inicio con un botón que abre la confirmación.
GoRouter _router(
  PlaceConfirmRequest request,
  void Function(GeocodeSuggestion?) onResult, {
  bool fromSheet = false,
  Future<String?> Function(LatLng)? reverse,
}) {
  Future<void> open(BuildContext context) async =>
      onResult(await context.push<GeocodeSuggestion>('/confirm', extra: request));
  return GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => fromSheet
                ? showModalBottomSheet<void>(
                    context: context,
                    builder: (sheet) => ElevatedButton(
                        onPressed: () => open(sheet), child: const Text('Guardar')),
                  )
                : open(context),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/confirm',
      builder: (_, state) {
        final r = state.extra! as PlaceConfirmRequest;
        return PlaceConfirmScreen(
            place: r.place,
            title: r.title,
            actionLabel: r.actionLabel,
            reverse: reverse);
      },
    ),
  ]);
}

void main() {
  testWidgets('sin mover el mapa, vuelve el mismo lugar con su punto',
      (tester) async {
    GeocodeSuggestion? result;
    var done = false;
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(const PlaceConfirmRequest(_plaza), (r) {
        result = r;
        done = true;
      }),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Confirma el destino'), findsOneWidget);
    expect(find.text('Parque Almirante Padilla'), findsOneWidget);
    expect(find.textContaining('aproximada'), findsNothing);

    await tester.tap(find.text('Confirmar destino'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result!.placeName, 'Parque Almirante Padilla');
    expect(result!.latLng, _plaza.latLng);
    expect(result!.approximate, isFalse);
  });

  testWidgets('volver sin confirmar devuelve null', (tester) async {
    GeocodeSuggestion? result = _plaza;
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(const PlaceConfirmRequest(_plaza), (r) => result = r),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('un lugar aproximado lo dice antes de confirmar', (tester) async {
    const approx = GeocodeSuggestion(
      placeName: 'Terminal de Maicao',
      fullAddress: 'Maicao',
      latLng: LatLng(11.379, -72.237),
      fromDirectory: true,
      approximate: true,
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(const PlaceConfirmRequest(approx), (_) {}),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ubicación aproximada'), findsOneWidget);
  });

  testWidgets('al mover el mapa, vuelve el punto nuevo con su dirección',
      (tester) async {
    GeocodeSuggestion? result;
    LatLng? asked;
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(const PlaceConfirmRequest(_plaza), (r) => result = r,
          reverse: (p) async {
        asked = p;
        return 'Cl. 1 #8-20, Riohacha';
      }),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Arrastrar el mapa unos 200 px (a zoom 17,5 son más de 30 m).
    final map = find.byType(PlaceConfirmScreen);
    final gesture = await tester.startGesture(tester.getCenter(map) - const Offset(0, 120));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(asked, isNotNull);
    expect(find.text('Cl. 1 #8-20, Riohacha'), findsOneWidget);
    await tester.tap(find.text('Confirmar destino'));
    await tester.pumpAndSettle();
    expect(result!.placeName, 'Cl. 1 #8-20, Riohacha');
    expect(result!.latLng, isNot(_plaza.latLng));
  });

  testWidgets('se abre encima de la hoja de Casa y devuelve el punto',
      (tester) async {
    GeocodeSuggestion? result;
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(
        const PlaceConfirmRequest(_plaza,
            title: 'Confirma tu casa', actionLabel: 'Guardar este punto'),
        (r) => result = r,
        fromSheet: true,
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma tu casa'), findsOneWidget);
    await tester.tap(find.text('Guardar este punto'));
    await tester.pumpAndSettle();
    expect(result?.latLng, _plaza.latLng);
    // La hoja sigue ahí debajo, lista para cerrar al guardar.
    expect(find.text('Guardar'), findsOneWidget);
  });
}
