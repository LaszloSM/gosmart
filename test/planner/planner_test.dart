// test/planner/planner_test.dart
// Los 3 casos de referencia del plan (Fase 5) sobre el grafo semilla.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/planner/fares.dart';
import 'package:gosmart/planner/graph.dart';
import 'package:gosmart/planner/planner.dart';
import 'package:latlong2/latlong.dart';

import 'fixture_graph.dart';

final _day = DateTime(2026, 10, 12, 9);
final _night = DateTime(2026, 10, 12, 22, 30);
final planner = TripPlanner(fixtureGraph);

void main() {
  test('caso 1: centro de Riohacha → una dirección de Maicao', () {
    final trips = planner.plan(PlanRequest(
      origin: const LatLng(11.5441, -72.9071),
      destination: const LatLng(11.3850, -72.2450),
      at: _day,
    ));
    expect(trips, isNotEmpty);
    final t = trips.first;
    expect(t.mainMode, anyOf(TransitMode.colectivo, TransitMode.intermunicipal));
    expect(t.legs.expand((l) => l.segmentIds), contains('troncal-30-40'));
    expect(t.fare.min, greaterThan(10000));
    // Termina en el destino pedido, no en la terminal.
    expect(t.legs.last.to, const LatLng(11.3850, -72.2450));
  });

  test('caso 2: un barrio de Riohacha → Universidad de La Guajira', () {
    final trips = planner.plan(PlanRequest(
      origin: const LatLng(11.5380, -72.9000),
      destination: const LatLng(11.5275, -72.8880),
      at: _day,
    ));
    final t = trips.first;
    expect(t.minutes, lessThan(30));
    expect(t.legs.length, lessThanOrEqualTo(3));
    expect(t.legs.expand((l) => l.segmentIds), isEmpty);
  });

  test('caso 3: Maicao → Terminal de Riohacha con la Troncal bloqueada usa el desvío', () {
    final req = PlanRequest(
      origin: const LatLng(11.3780, -72.2405),
      destination: const LatLng(11.5330, -72.9125),
      at: _day,
      roadStates: const {'troncal-30-40': RoadState.closed},
    );
    final trips = planner.plan(req);
    expect(trips, isNotEmpty);
    for (final t in trips) {
      expect(t.legs.expand((l) => l.segmentIds), isNot(contains('troncal-30-40')));
    }
    expect(trips.first.usesDetour, isTrue);
    expect(trips.first.legs.expand((l) => l.segmentIds),
        contains('desvio-albania-cuestecitas'));
  });

  test('sin bloqueo, Maicao → Riohacha va por la Troncal (más corta)', () {
    final t = planner.plan(PlanRequest(
      origin: const LatLng(11.3780, -72.2405),
      destination: const LatLng(11.5330, -72.9125),
      at: _day,
    )).first;
    expect(t.usesDetour, isFalse);
    expect(t.legs.expand((l) => l.segmentIds), contains('troncal-30-40'));
  });

  test('un retén suma tiempo y queda como advertencia', () {
    final t = planner.plan(PlanRequest(
      origin: const LatLng(11.5330, -72.9125),
      destination: const LatLng(11.3790, -72.2370),
      at: _day,
      roadStates: const {'troncal-40-50': RoadState.caution},
    )).first;
    expect(t.warnings, contains('troncal-40-50'));
  });

  test('de noche no ofrece colectivos que no operan', () {
    final trips = planner.plan(PlanRequest(
      origin: const LatLng(11.5330, -72.9125),
      destination: const LatLng(11.3780, -72.2405),
      at: _night,
    ));
    for (final t in trips) {
      expect(t.legs.map((l) => l.mode), isNot(contains(TransitMode.colectivo)));
    }
  });

  test('no inventa un mototaxi de 75 km', () {
    final trips = planner.plan(PlanRequest(
      origin: const LatLng(11.5441, -72.9071),
      destination: const LatLng(11.3780, -72.2405),
      at: _day,
      allowed: const {TransitMode.walk, TransitMode.mototaxi},
    ));
    expect(trips, isEmpty);
  });

  test('tarifa justa: rango redondeado a \$500 y recargo nocturno', () {
    final d = estimateFare(TransitMode.mototaxi, 3, at: _day);
    final n = estimateFare(TransitMode.mototaxi, 3, at: _night);
    expect(d.min % 500, 0);
    expect(d.max, greaterThan(d.min));
    expect(n.mid, greaterThan(d.mid));
    expect(estimateFare(TransitMode.colectivo, 3, at: _day), FareRange.zero);
  });
}
