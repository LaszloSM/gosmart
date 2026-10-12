import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/planner/planner.dart';
import 'package:gosmart/planner/to_route.dart';
import 'package:latlong2/latlong.dart';

import 'fixture_graph.dart';

void main() {
  test('el viaje planeado pasa a la ruta con rango de tarifa y aviso de desvío', () {
    const closed = CorridorStatus(segments: [
      CorridorSegment(id: 'troncal-30-40', name: 'Troncal km 30–40',
          kmFrom: 30, kmTo: 40, state: RoadState.closed, reason: 'Bloqueo'),
    ]);
    final trip = TripPlanner(fixtureGraph).plan(PlanRequest(
      origin: const LatLng(11.3780, -72.2405),
      destination: const LatLng(11.5330, -72.9125),
      at: DateTime(2026, 10, 12, 9),
      roadStates: const {'troncal-30-40': RoadState.closed},
    )).first;
    final r = routeFromTrip(trip, corridor: closed);
    expect(r.legs.length, trip.legs.length);
    expect(r.fareMin, trip.fare.min);
    expect(r.fareMax, greaterThanOrEqualTo(r.fareMin!));
    expect(r.notes.first, contains('desvío Albania–Cuestecitas'));
    expect(r.legs.where((l) => l.mode != 'walk').first.lineId, isNotNull);
  });
}
