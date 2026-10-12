// test/planner/trip_tool_test.dart
// plan_trip del asistente: corre en el celular y le devuelve a la IA cifras
// del planificador, o un error claro (nunca una ruta inventada).
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/planner/fares.dart';
import 'package:gosmart/services/graph_service.dart';
import 'package:gosmart/services/trip_tool.dart';
import 'package:latlong2/latlong.dart';

import 'fixture_graph.dart';

const _places = {
  'terminal de maicao': LatLng(11.3790, -72.2370),
  'uniguajira': LatLng(11.5275, -72.8880),
};

TripTool _tool({LatLng? here = const LatLng(11.5441, -72.9071),
    CorridorStatus corridor = const CorridorStatus.noData()}) =>
    TripTool(
      locate: () async => here,
      resolvePlace: (q, _) async {
        final at = _places[q.toLowerCase()];
        return at == null ? null : (name: q, at: at);
      },
      loadGraph: () async => GraphBundle(fixtureGraph, defaultFareRules),
      loadCorridor: () async => corridor,
      now: () => DateTime(2026, 10, 12, 9),
    );

void main() {
  test('planea desde la ubicación y devuelve opciones con cifras', () async {
    final out = await _tool().run({'destination': 'Terminal de Maicao'});
    final ops = out.result['opciones'] as List;
    expect(ops, isNotEmpty);
    expect((ops.first as Map)['tarifa_referencia'], contains('COP'));
    expect(out.routes, isNotEmpty);
    expect(out.routes.first.destinationLabel, 'Terminal de Maicao');
  });

  test('destino desconocido: lo dice, sin inventar', () async {
    final out = await _tool().run({'destination': 'Narnia'});
    expect(out.result['error'], 'destino_no_encontrado');
    expect(out.routes, isEmpty);
  });

  test('sin GPS y sin origen: pide ubicación', () async {
    final out = await _tool(here: null).run({'destination': 'Uniguajira'});
    expect(out.result['error'], 'sin_ubicacion');
  });

  test('con la Troncal cerrada avisa el desvío', () async {
    const closed = CorridorStatus(segments: [
      CorridorSegment(id: 'troncal-30-40', name: 'Troncal km 30–40',
          kmFrom: 30, kmTo: 40, state: RoadState.closed, reason: 'Bloqueo'),
    ]);
    final out = await _tool(corridor: closed)
        .run({'destination': 'Terminal de Maicao', 'mode': 'intermunicipal'});
    final first = (out.result['opciones'] as List).first as Map;
    expect(first['desvio'], isNotNull);
    // Solo en intermunicipal no hay desvío: lo combina y lo dice.
    expect(out.result['nota'], contains('se combinan modos'));
  });
}
