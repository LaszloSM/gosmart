// test/models/dispatch_models_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/widgets/leg_panels.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/models/route_result.dart';
import 'package:gosmart/services/dispatch_service.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> _leg(int seq, String mode, String status) =>
    {'id': 'l$seq', 'seq': seq, 'mode': mode, 'status': status,
     'fare_min': 3000, 'fare_max': 5000};

void main() {
  test('el tramo actual es el primero sin cerrar, aunque lleguen desordenados', () {
    final t = ChainedTrip.fromJson({
      'id': 't', 'status': 'in_progress',
      'trip_legs': [
        _leg(2, 'walk', 'planned'),
        _leg(0, 'mototaxi', 'completed'),
        _leg(1, 'colectivo', 'awaiting_dispatch'),
      ],
    });
    expect(t.legs.map((l) => l.seq), [0, 1, 2]);
    expect(t.currentLeg?.id, 'l1');
    expect(t.isFinished, isFalse);
  });

  test('tarifa sugerida: el medio del rango, redondeado a \$500', () {
    final l = TripLegRow.fromJson(_leg(0, 'mototaxi', 'planned'));
    expect(suggestedFare(l), 4000);
    final noRange = TripLegRow.fromJson(
        {'id': 'x', 'seq': 0, 'mode': 'taxi', 'status': 'planned'});
    expect(suggestedFare(noRange), 5000);
  });

  test('una solicitud abierta pero vencida ya no está viva', () {
    final r = RideRequest.fromJson({
      'id': 'r', 'service': 'mototaxi', 'status': 'open', 'offered_fare': 5000,
      'expires_at': DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
    });
    expect(r.isLive(DateTime.now()), isFalse);
  });

  test('el tramo del planificador viaja completo a create_trip', () {
    const leg = RouteLeg(
      mode: 'bus', points: [LatLng(11.53, -72.91), LatLng(11.38, -72.24)],
      color: Colors.blue, durationMin: 90, distanceKm: 75,
      transitMode: 'colectivo', fromLabel: 'Terminal de Riohacha',
      toLabel: 'Centro de Maicao', fromNode: 'rio-terminal', toNode: 'mai-centro',
      fareMin: 12000, fareMax: 15000,
    );
    final p = DispatchService.legPayload(leg);
    expect(p['mode'], 'colectivo');
    expect(p['from_node'], 'rio-terminal');
    expect(p['to_lat'], 11.38);
    expect(p['fare_max'], 15000);
    // Una ruta por calles sin modo del planificador se toma como mototaxi.
    const plain = RouteLeg(mode: 'bus', points: [], color: Colors.blue,
        durationMin: 10, distanceKm: 3);
    expect(DispatchService.legPayload(plain)['mode'], 'mototaxi');
  });

  test('los errores del servidor se traducen a palabras', () {
    expect(const DispatchException('already_taken').message,
        contains('Otro conductor'));
    expect(() => DispatchException.rethrowFrom(Exception('x no_seats y')),
        throwsA(isA<DispatchException>().having((e) => e.code, 'code', 'no_seats')));
  });
}
