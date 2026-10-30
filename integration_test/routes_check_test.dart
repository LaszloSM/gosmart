// integration_test/routes_check_test.dart
// Rutas a varios destinos en un Android de verdad (emulador de CI, contra el
// Supabase real y Google o el respaldo Photon). Por cada destino: se busca
// como lo haría una persona, se toma la primera sugerencia, se confirma el
// punto y se pide la ruta. Se comprueba que:
//   1. la ruta termina donde está el punto elegido (Google la pega a la vía);
//   2. el punto cae en la zona del lugar (radio amplio: atrapa errores gruesos
//      como terminar en otro barrio u otra ciudad, no la puerta exacta);
//   3. el destino de la ruta lleva el nombre que se eligió.
// Cada caso imprime "ROUTE ..." y un "STEP" para la captura del mapa.
// Antes, fluidez: arrastrar y hacer zoom en el mapa del inicio midiendo cada
// cuadro (FrameTiming). Se exige el tiempo de construcción en Dart (nuestro
// código); el de dibujo se informa, porque el emulador de CI dibuja por
// software y no se parece a un celular.
//
// Local: flutter test integration_test/routes_check_test.dart -d <emulador>
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gosmart/features/routes/place_confirm_screen.dart';
import 'package:gosmart/features/routes/route_planner_screen.dart';
import 'package:gosmart/main.dart' as app;
import 'package:gosmart/providers/active_route_provider.dart';
import 'package:gosmart/router/app_router.dart';
import 'package:gosmart/services/place_search.dart';
import 'package:gosmart/widgets/gs_list_row.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Destino: lo que se escribe, la zona donde debe caer y su radio.
/// Las zonas son aproximadas a propósito (centros conocidos de Riohacha y
/// Maicao): sirven para detectar un punto en el lugar equivocado.
class _Case {
  const _Case(this.query, this.area, this.radiusM);
  final String query;
  final LatLng area;
  final double radiusM;
}

const _cases = [
  // El caso con que empezó todo: la plaza está frente a la Catedral (punto
  // de la Catedral según Google en este mismo emulador).
  _Case('Plaza Almirante Padilla', LatLng(11.5518, -72.9092), 500),
  _Case('Universidad de La Guajira', LatLng(11.525, -72.882), 2500),
  _Case('Aeropuerto Almirante Padilla', LatLng(11.526, -72.926), 1500),
  _Case('Terminal de Transportes Riohacha', LatLng(11.533, -72.912), 2000),
  _Case('Muelle turístico Riohacha', LatLng(11.546, -72.907), 1200),
  _Case('Catedral Riohacha', LatLng(11.544, -72.907), 1200),
  _Case('Hospital Nuestra Señora de los Remedios', LatLng(11.540, -72.905), 2500),
  _Case('Calle 15 Riohacha', LatLng(11.538, -72.905), 4000),
  _Case('Parque Central Maicao', LatLng(11.378, -72.240), 2500),
];

double _meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final x = dLng * math.cos((a.latitude + b.latitude) * math.pi / 360);
  return r * math.sqrt(dLat * dLat + x * x);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rutas a varios destinos', (tester) async {
    final failed = <String>[];
    // ignore: avoid_print
    void log(String s) => print(s);
    void step(String name) => log('STEP $name ${DateTime.now().millisecondsSinceEpoch}');

    Future<void> wait(int seconds) async {
      for (var i = 0; i < seconds * 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<bool> waitFor(Finder f, {int seconds = 20}) async {
      for (var i = 0; i < seconds * 4; i++) {
        if (f.evaluate().isNotEmpty) return true;
        await tester.pump(const Duration(milliseconds: 250));
      }
      return f.evaluate().isNotEmpty;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    app.main();
    if (!await waitFor(find.text('¿A dónde vas?'), seconds: 60)) {
      fail('no cargó el inicio');
    }
    await wait(10);
    // ── Fluidez del mapa ──────────────────────────────────────────────────
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // Zona del mapa visible: arriba de la hoja "¿A dónde vas?".
    final center = Offset(screen.width / 2, screen.height * 0.32);
    step('mapa-antes');
    for (var i = 0; i < 6; i++) {
      final dir = i.isEven ? const Offset(1, 0.4) : const Offset(-1, -0.4);
      final g = await tester.startGesture(center);
      for (var k = 0; k < 20; k++) {
        await g.moveBy(dir * 12);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await wait(1);
    }
    for (var i = 0; i < 4; i++) {
      final out = i.isEven ? 1.0 : -1.0;
      final a = await tester.startGesture(center - const Offset(40, 0), pointer: 7);
      final b = await tester.startGesture(center + const Offset(40, 0), pointer: 8);
      for (var k = 0; k < 15; k++) {
        await a.moveBy(Offset(-6 * out, 0));
        await b.moveBy(Offset(6 * out, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await wait(2);
    }
    step('mapa-despues');
    await wait(2);
    // El emulador es lento: a veces toma el inicio de un arrastre como
    // pulsación larga y abre "¿Ir aquí?". Se cierra para seguir limpio.
    if (find.text('Cancelar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancelar').first);
      await wait(1);
    }
    SchedulerBinding.instance.removeTimingsCallback(collect);
    if (timings.length < 20) {
      log('FLUIDEZ solo ${timings.length} cuadros medidos: no se puede concluir');
    } else {
      List<double> ms(Duration Function(FrameTiming) f) =>
          timings.map((t) => f(t).inMicroseconds / 1000).toList()..sort();
      double pct(List<double> v, double p) => v[((v.length - 1) * p).round()];
      final build = ms((t) => t.buildDuration);
      final raster = ms((t) => t.rasterDuration);
      final slowBuild = build.where((x) => x > 16).length;
      log('FLUIDEZ ${timings.length} cuadros | construcción p50 ${pct(build, .5).toStringAsFixed(1)} ms, '
          'p90 ${pct(build, .9).toStringAsFixed(1)} ms, máx ${build.last.toStringAsFixed(1)} ms, '
          '>16 ms: $slowBuild | dibujo (emulador, software) p50 ${pct(raster, .5).toStringAsFixed(1)} ms, '
          'p90 ${pct(raster, .9).toStringAsFixed(1)} ms');
      if (pct(build, .9) > 16) {
        failed.add('fluidez: construcción p90 ${pct(build, .9).toStringAsFixed(1)} ms (> 16 ms)');
      }
    }

    final home = tester.element(find.text('¿A dónde vas?').first);
    final container = ProviderScope.containerOf(home);
    final router = GoRouter.of(home);

    for (final c in _cases) {
      final tag = c.query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      container.read(activeRouteProvider.notifier).state = null;
      router.push(AppRoutes.routePlanner);
      final field = find.widgetWithText(TextField, '¿A dónde vas?');
      if (!await waitFor(field)) {
        failed.add('${c.query}: no abrió el planificador');
        continue;
      }
      await tester.enterText(field.first, c.query);
      // Primera sugerencia de verdad: fila del planificador (no de la pantalla
      // de atrás durante la transición) que no sea un acceso fijo.
      const accesos = {'Elegir en el mapa', 'Pregúntale al asistente', 'Casa', 'Trabajo'};
      final first = find.descendant(
        of: find.byType(RoutePlannerScreen),
        matching: find.byWidgetPredicate(
            (w) => w is GSListRow && !accesos.contains(w.title)),
      );
      if (!await waitFor(first, seconds: 25)) {
        failed.add('${c.query}: sin sugerencias');
        log('ROUTE ${c.query} | sin sugerencias');
        router.pop();
        await wait(2);
        continue;
      }
      await wait(2); // que lleguen todas las capas (directorio + Google/Photon)
      if (first.evaluate().isEmpty) {
        failed.add('${c.query}: las sugerencias desaparecieron');
        router.pop();
        await wait(2);
        continue;
      }
      final chosen = tester.widget<GSListRow>(first.first);
      step('sugerencias-$tag');
      await tester.tap(first.first);

      if (!await waitFor(find.byType(PlaceConfirmScreen), seconds: 25)) {
        failed.add('${c.query}: no abrió la confirmación del punto');
        router.pop();
        await wait(2);
        continue;
      }
      final place = tester.widget<PlaceConfirmScreen>(find.byType(PlaceConfirmScreen)).place;
      final point = place.latLng!;
      await wait(8); // que el mapa nativo dibuje sus teselas antes de la captura
      step('punto-$tag');
      await wait(3);
      await tester.tap(find.text('Confirmar destino'));
      await wait(3);

      await tester.tap(find.text('Mototaxi').first, warnIfMissed: false);
      await wait(1);
      await tester.tap(find.text('Ver ruta'));
      var route = container.read(activeRouteProvider);
      for (var i = 0; i < 100 && route == null; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        route = container.read(activeRouteProvider);
      }
      if (route == null || route.legs.isEmpty || route.legs.last.points.isEmpty) {
        failed.add('${c.query}: no se armó la ruta');
        log('ROUTE ${c.query} | "${chosen.title}" | sin ruta');
        if (find.byType(PlaceConfirmScreen).evaluate().isEmpty &&
            find.text('Ver ruta').evaluate().isNotEmpty) {
          router.pop();
        }
        await wait(2);
        continue;
      }
      await wait(6);
      step('ruta-$tag');

      final end = route.legs.last.points.last;
      final toPoint = _meters(end, point);
      final toArea = _meters(point, c.area);
      final label = route.destinationLabel ?? '';
      // La sugerencia elegida debe ser lo buscado: la primera palabra que
      // distingue la búsqueda y sus números ("Calle 15") van en el nombre.
      final want = queryCore(c.query).split(' ');
      final got = queryCore(place.placeName).toLowerCase();
      // Del directorio vale por alias ("plaza almirante padilla" → Parque …).
      final missing = place.fromDirectory ? const <String>[] : [
        for (final w in want)
          if ((w == want.first || RegExp(r'^\d').hasMatch(w)) && !got.contains(w)) w,
      ];
      final problems = [
        if (missing.isNotEmpty)
          'se eligió "${place.placeName}", que no es lo buscado (falta: ${missing.join(', ')})',
        if (toPoint > 250) 'la ruta termina a ${toPoint.round()} m del punto elegido',
        if (toArea > c.radiusM) 'el punto cae a ${toArea.round()} m de la zona esperada',
        if (label != place.placeName) 'el destino dice "$label" y se eligió "${place.placeName}"',
      ];
      log('ROUTE ${c.query} | "${chosen.title}" (${chosen.subtitle}) | '
          'punto ${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)} | '
          'fin de ruta a ${toPoint.round()} m | zona a ${toArea.round()} m | '
          '${route.distanceKm.toStringAsFixed(1)} km${place.approximate ? ' | APROX' : ''} | '
          '${problems.isEmpty ? 'OK' : problems.join('; ')}');
      if (problems.isNotEmpty) failed.add('${c.query}: ${problems.join('; ')}');
    }

    log('RESULT ${failed.isEmpty ? 'OK' : failed.join(' | ')}');
    expect(failed, isEmpty, reason: 'destinos con la ruta en el lugar equivocado');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
